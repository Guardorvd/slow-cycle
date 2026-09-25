class_name ChunkStreamer
extends Node3D

## Slow Cycle — Branch Streaming & Lifecycle Manager (FEAT-014.5)
## Manages the full lifecycle of road network branches (ACTIVE -> PRELOADED -> DORMANT -> UNLOADED).
## Features pure decoupled geometry preparation, budget-limited synchronous scene commit,
## deterministic seed derivation, ghost collision deactivation for dormant branches,
## and a physical 3D rollback safety envelope.

const RoadChunkClass = preload("res://scripts/world/road_chunk.gd")
const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")
const ForkDecisionModelClass = preload("res://scripts/world/fork_decision_model.gd")
const RoadMathClass = preload("res://scripts/world/road_math.gd")

# ==============================================================================
# ENUMS & CONSTANTS
# ==============================================================================

enum BranchState {
	ACTIVE = 0,     ## Current gameplay branch player is actively riding on
	PRELOADED = 1,  ## Geometry & collision fully committed & ready; ahead of player at fork
	DORMANT = 2,    ## Alternative unchosen branch; collisions disabled, retained within safety margin
	UNLOADED = 3    ## Completely removed from memory and scene tree
}

const AHEAD_DISTANCE: float = 350.0          ## Distance ahead on active branch to keep generated (m)
const BEHIND_DISTANCE: float = 65.0          ## Distance behind player to retain chunks (m)
const MAX_CHUNKS_PER_FRAME: int = 1          ## Live streaming rate limit to guarantee 60 FPS

@export var preload_distance: float = 100.0  ## Parametric preload distance for fork branches (m)
@export var first_fork_distance: float = 450.0 ## Distance to the first fork from start (m)
@export var fork_interval_dist: float = 700.0 ## Nominal distance between subsequent forks (~14 chunks)
@export var safety_corridor_margin: float = 70.0 ## 3D Euclidean safety distance from dormant path (m)
@export var fork_safety_radius: float = 30.0     ## 3D radius around fork origin where unload is forbidden (m)

# ==============================================================================
# INNER CLASSES: TOKENS & BRANCH CONTAINER
# ==============================================================================

class GenerationToken extends RefCounted:
	var generation_id: int = 0
	var branch_id: int = 0
	var chunk_id: int = 0

	func _init(gen: int, b_id: int, c_id: int) -> void:
		generation_id = gen
		branch_id = b_id
		chunk_id = c_id

class RoadBranch extends RefCounted:
	var branch_id: int = 0
	var fork_id: int = -1
	var branch_index: int = -1                  ## -1 = Trunk, 0 = Left, 1 = Right
	var state: int = BranchState.PRELOADED
	var generation_id: int = 1
	var road_path: RefCounted = null            ## RoadPathData
	var road_logic: RefCounted = null           ## RoadLogic
	var active_chunks: Dictionary = {}          ## chunk_id (int) -> RoadChunk
	var chunk_end_distances: Dictionary = {}    ## chunk_id (int) -> float
	var fork_node_pos: Vector3 = Vector3.ZERO
	var fork_node_tang: Vector3 = Vector3.FORWARD
	var fork_node_norm: Vector3 = Vector3.UP
	var decision_model: RefCounted = null       ## ForkDecisionModel (if this branch spawned a fork)
	var is_fork_spawned: bool = false
	var distance_at_last_fork: float = 0.0
	var last_closest_idx: int = 0
	var child_branch_ids: Array[int] = []
	var parent_branch_id: int = -1
	var needs_fork_transition: bool = false
	var transition_branch_index: int = -1

	func get_total_distance() -> float:
		if road_path and road_path.has_method("get_total_distance"):
			return road_path.get_total_distance()
		return 0.0

	func set_physics_enabled(enabled: bool) -> void:
		for chunk in active_chunks.values():
			if is_instance_valid(chunk) and chunk.has_method("set_physics_enabled"):
				chunk.set_physics_enabled(enabled)

# ==============================================================================
# STREAMER STATE
# ==============================================================================

var world_manager: Node3D
var shared_materials: Dictionary = {}
var shared_meshes: Dictionary = {}

var branches: Dictionary = {}                   ## branch_id (int) -> RoadBranch
var active_branch_id: int = 0
var next_branch_id: int = 1
var next_chunk_id: int = 0
var next_fork_id: int = 1

var last_chunk_gen_ms: float = 0.0
var last_chunk_timings: Dictionary = {}

# Backward compatibility properties
var road_path: RefCounted:
	get:
		var b = get_active_branch()
		return b.road_path if b else null
	set(val):
		var b = get_active_branch()
		if b:
			b.road_path = val

var road_logic: RefCounted:
	get:
		var b = get_active_branch()
		return b.road_logic if b else null
	set(val):
		var b = get_active_branch()
		if b:
			b.road_logic = val

var active_chunks: Dictionary:
	get:
		var b = get_active_branch()
		return b.active_chunks if b else {}

var chunk_end_distances: Dictionary:
	get:
		var b = get_active_branch()
		return b.chunk_end_distances if b else {}

# ==============================================================================
# INITIALIZATION & SETUP
# ==============================================================================

func setup(manager: Node3D, path: RefCounted, logic: RefCounted, mats: Dictionary, meshes: Dictionary) -> void:
	world_manager = manager
	shared_materials = mats
	shared_meshes = meshes

	# Ensure noise exists in shared_materials
	if not shared_materials.has("noise") or shared_materials["noise"] == null:
		var noise := FastNoiseLite.new()
		noise.seed = 184729
		shared_materials["noise"] = noise

	# Create initial trunk branch (Branch 0 = ACTIVE)
	var trunk := RoadBranch.new()
	trunk.branch_id = 0
	trunk.branch_index = -1
	trunk.state = BranchState.ACTIVE
	trunk.road_path = path
	trunk.road_logic = logic
	branches[0] = trunk
	active_branch_id = 0

	# Synchronously pre-generate starting window (initial 7 chunks ~350m)
	for i in range(7):
		_spawn_chunk_sync(trunk)

# ==============================================================================
# STREAMING UPDATE ENTRY POINT
# ==============================================================================

func update_streaming(player_pos: Vector3, player_vel: Vector3 = Vector3.ZERO, delta: float = 0.016) -> void:
	var active_branch: RoadBranch = get_active_branch()
	if active_branch == null or active_branch.road_path == null or active_branch.road_path.size() < 2:
		return

	if player_vel.is_zero_approx() and world_manager and "player" in world_manager and world_manager.player:
		if "velocity" in world_manager.player:
			player_vel = world_manager.player.velocity
		elif "linear_velocity" in world_manager.player:
			player_vel = world_manager.player.linear_velocity

	# 1. Update active forks intent evaluation
	_update_fork_decisions(player_pos, player_vel, delta)

	# 2. Track player position on active branch
	var r_path: RefCounted = active_branch.road_path
	var closest_idx: int = r_path.find_closest_index(player_pos, active_branch.last_closest_idx)
	active_branch.last_closest_idx = closest_idx
	var player_s: float = r_path.cumulative_distances[closest_idx]
	var total_s: float = active_branch.get_total_distance()

	# 3. Stream chunks ahead
	var spawned_count: int = 0
	var target_interval: float = first_fork_distance if active_branch.distance_at_last_fork == 0.0 else fork_interval_dist
	var dist_since_fork: float = total_s - active_branch.distance_at_last_fork

	if not active_branch.is_fork_spawned and (dist_since_fork + 50.0) >= target_interval and (total_s - player_s) < AHEAD_DISTANCE:
		_spawn_chunk_with_fork_widening(active_branch)
		_spawn_procedural_fork(active_branch)
		spawned_count += 1
	elif (total_s - player_s) < AHEAD_DISTANCE and spawned_count < MAX_CHUNKS_PER_FRAME:
		_spawn_chunk_sync(active_branch)
		spawned_count += 1

	# Keep preloaded alternative branch chunks generated ahead if rider is approaching fork
	for child_id in active_branch.child_branch_ids:
		var child_b: RoadBranch = branches.get(child_id, null)
		if child_b != null and child_b.state == BranchState.PRELOADED:
			var child_total_s: float = child_b.get_total_distance()
			if child_total_s < preload_distance and spawned_count < MAX_CHUNKS_PER_FRAME:
				_spawn_chunk_sync(child_b)
				spawned_count += 1

	# 4. Despawn historical chunks on active branch behind player
	_despawn_chunks_behind(active_branch, player_s - BEHIND_DISTANCE)

	# 5. Prune historical spline samples
	if r_path.has_method("prune_behind"):
		var pruned: int = r_path.prune_behind(player_s - 150.0)
		if pruned > 0:
			active_branch.last_closest_idx = maxi(0, active_branch.last_closest_idx - pruned)

	# 6. Safety envelope checks for dormant branches
	_update_dormant_branches_safety_envelope(player_pos, player_vel)

# ==============================================================================
# PROCEDURAL FORK SPAWNING & PRELOADING
# ==============================================================================

func _spawn_chunk_with_fork_widening(branch: RoadBranch) -> void:
	var r_path: RefCounted = branch.road_path
	var r_logic: RefCounted = branch.road_logic
	var start_idx: int = maxi(0, r_path.size() - 1)

	r_logic.plan_next_chunk()
	var end_idx: int = r_path.size() - 1

	# Apply C1 smoothstep widening (3.2m -> 6.5m) on the last 25m of this approach chunk
	var end_s: float = r_path.cumulative_distances[end_idx]
	for idx in range(start_idx, end_idx + 1):
		var s: float = r_path.cumulative_distances[idx]
		var s_rel: float = s - end_s # -50.0m to 0.0m
		var w: float = RoadMathClass.compute_fork_width(s_rel, 25.0, 3.2, 6.5)
		if idx < r_path.road_widths.size():
			r_path.road_widths[idx] = w

	var c_id: int = next_chunk_id
	next_chunk_id += 1

	var token := GenerationToken.new(branch.generation_id, branch.branch_id, c_id)
	var prep = RoadChunkClass.prepare_geometry_data(
		r_path, start_idx, end_idx, c_id, shared_materials, token, true, r_path.tangents[end_idx]
	)

	var chunk: Node3D = RoadChunkClass.new()
	add_child(chunk)
	var timings = chunk.commit(prep, shared_materials, shared_meshes)
	last_chunk_timings = timings
	last_chunk_gen_ms = timings.get("t_total", 0.0)

	branch.active_chunks[c_id] = chunk
	branch.chunk_end_distances[c_id] = end_s

func _generate_fork_arm_samples(
	branch: RoadBranch,
	branch_idx: int, # 0 = Left, 1 = Right
	fork_pos: Vector3,
	fork_tang: Vector3,
	fork_norm: Vector3,
	fork_binorm: Vector3,
	fork_heading: float,
	fork_slope: float,
	samples_count: int = 25,
	step_len: float = 2.0
) -> Array[Vector3]:
	var inner_verts: Array[Vector3] = []
	var r_path: RefCounted = branch.road_path
	var div_angle_deg: float = 14.0 if branch_idx == 0 else -14.0
	var w_start: float = 3.25
	var w_end: float = 1.8 if branch_idx == 0 else 3.2
	var seg_type: int = RoadPathDataClass.SegmentType.CRUISE_DOWNHILL

	var curr_pos: Vector3 = fork_pos + fork_binorm * (-1.625 if branch_idx == 0 else 1.625)
	var prev_pos: Vector3 = curr_pos
	var curr_tang: Vector3 = fork_tang
	var prev_tang: Vector3 = fork_tang

	for i in range(samples_count + 1):
		var t_norm: float = float(i) / float(samples_count)
		var curve_factor: float = smoothstep(0.0, 0.70, t_norm)
		var curr_heading: float = fork_heading + div_angle_deg * curve_factor
		var curr_w: float = lerpf(w_start, w_end, smoothstep(0.0, 1.0, t_norm))

		var h_rad: float = deg_to_rad(curr_heading)
		var s_rad: float = deg_to_rad(fork_slope)
		curr_tang = Vector3(
			sin(h_rad) * cos(s_rad),
			sin(s_rad),
			cos(h_rad) * cos(s_rad)
		).normalized()
		var curr_norm: Vector3 = RoadMathClass.compute_ortho_normal(curr_tang, 0.0)
		var curr_binorm: Vector3 = curr_tang.cross(curr_norm).normalized()

		if i > 0:
			var seg_chord: Vector3 = (prev_tang + curr_tang).normalized()
			curr_pos = prev_pos + seg_chord * step_len
		prev_pos = curr_pos
		prev_tang = curr_tang

		var curv: float = deg_to_rad(absf(div_angle_deg)) / 50.0

		if i == 0 and r_path.size() > 0 and r_path.points[-1].distance_to(curr_pos) < 0.01:
			if not r_path.road_widths.is_empty():
				r_path.road_widths[-1] = curr_w
		else:
			r_path.append_sample(
				curr_pos,
				curr_tang,
				curr_norm,
				fork_slope,
				curv,
				seg_type,
				0,
				0.0,
				50.0,
				curr_w
			)

		# Inner edge calculation
		var p_inner: Vector3
		if branch_idx == 0:
			p_inner = curr_pos + curr_binorm * (curr_w * 0.5)
		else:
			p_inner = curr_pos - curr_binorm * (curr_w * 0.5)

		inner_verts.append(p_inner)

	if branch.road_logic:
		branch.road_logic.last_point = curr_pos
		var last_idx: int = r_path.size() - 1
		branch.road_logic.last_tangent = r_path.tangents[last_idx]
		branch.road_logic.last_normal = r_path.normals[last_idx]
		branch.road_logic.current_heading_deg = fork_heading + div_angle_deg
		branch.road_logic.current_slope_deg = fork_slope

	return inner_verts

func _spawn_procedural_fork(parent_branch: RoadBranch) -> void:
	parent_branch.is_fork_spawned = true
	var fork_id: int = next_fork_id
	next_fork_id += 1

	var p_path: RefCounted = parent_branch.road_path
	var last_idx: int = p_path.size() - 1
	var fork_pos: Vector3 = p_path.points[last_idx]
	var fork_tang: Vector3 = p_path.tangents[last_idx]
	var fork_norm: Vector3 = p_path.normals[last_idx]
	var fork_binorm: Vector3 = p_path.binormals[last_idx]
	var fork_heading: float = parent_branch.road_logic.current_heading_deg
	var fork_slope: float = parent_branch.road_logic.current_slope_deg

	parent_branch.fork_node_pos = fork_pos
	parent_branch.fork_node_tang = fork_tang
	parent_branch.fork_node_norm = fork_norm
	parent_branch.distance_at_last_fork = p_path.cumulative_distances[last_idx]
	parent_branch.branch_index = 0
	parent_branch.needs_fork_transition = false

	# Setup Decision Model for this fork
	var model = ForkDecisionModelClass.new()
	model.setup(fork_id, fork_pos, fork_tang, fork_norm, 20.0, ForkDecisionModelClass.BranchChoice.LEFT)
	model.branch_locked.connect(_on_branch_locked.bind(parent_branch.branch_id))
	parent_branch.decision_model = model

	# Alternative branch: Right branch (branch_index = 1) created as PRELOADED branch
	var alt_branch := _create_alternative_fork_branch(fork_id, 1, parent_branch)
	alt_branch.branch_index = 1
	alt_branch.needs_fork_transition = false
	parent_branch.child_branch_ids = [alt_branch.branch_id]

	# 1. Generate diverging fork arm samples for Right branch (alt_branch)
	var right_inner_verts: Array[Vector3] = _generate_fork_arm_samples(
		alt_branch, 1, fork_pos, fork_tang, fork_norm, fork_binorm, fork_heading, fork_slope
	)

	# 2. Generate diverging fork arm samples for Left branch (parent_branch)
	var left_inner_verts: Array[Vector3] = _generate_fork_arm_samples(
		parent_branch, 0, fork_pos, fork_tang, fork_norm, fork_binorm, fork_heading, fork_slope
	)

	# 3. Spawn Chunk 0 for Left arm (parent_branch): builds left road + left outer terrain + Splitter Wedge + Sign
	var left_start_idx: int = maxi(0, parent_branch.road_path.size() - 26)
	var left_end_idx: int = parent_branch.road_path.size() - 1
	var c_id_l: int = next_chunk_id
	next_chunk_id += 1
	var token_l := GenerationToken.new(parent_branch.generation_id, parent_branch.branch_id, c_id_l)
	var fork_ctx_l := {
		"terrain_side_mask": 1,
		"wedge_opposite_inner_verts": right_inner_verts,
		"is_fork_arm": true
	}
	var prep_l = RoadChunkClass.prepare_geometry_data(
		parent_branch.road_path, left_start_idx, left_end_idx, c_id_l, shared_materials, token_l, true, fork_tang, fork_ctx_l
	)
	var chunk_l: Node3D = RoadChunkClass.new()
	add_child(chunk_l)
	chunk_l.commit(prep_l, shared_materials, shared_meshes)
	parent_branch.active_chunks[c_id_l] = chunk_l
	parent_branch.chunk_end_distances[c_id_l] = parent_branch.road_path.cumulative_distances[left_end_idx]

	# 4. Spawn Chunk 0 for Right arm (alt_branch): builds right road + right outer terrain
	var right_start_idx: int = 0
	var right_end_idx: int = alt_branch.road_path.size() - 1
	var c_id_r: int = next_chunk_id
	next_chunk_id += 1
	var token_r := GenerationToken.new(alt_branch.generation_id, alt_branch.branch_id, c_id_r)
	var fork_ctx_r := {
		"terrain_side_mask": 2,
		"is_fork_arm": true
	}
	var prep_r = RoadChunkClass.prepare_geometry_data(
		alt_branch.road_path, right_start_idx, right_end_idx, c_id_r, shared_materials, token_r, true, fork_tang, fork_ctx_r
	)
	var chunk_r: Node3D = RoadChunkClass.new()
	add_child(chunk_r)
	chunk_r.commit(prep_r, shared_materials, shared_meshes)
	alt_branch.active_chunks[c_id_r] = chunk_r
	alt_branch.chunk_end_distances[c_id_r] = alt_branch.road_path.cumulative_distances[right_end_idx]

	# 5. Preload 1 additional chunk for alt_branch (reaches 100m total preloaded)
	_spawn_chunk_sync(alt_branch)

func _create_alternative_fork_branch(
	fork_id: int,
	branch_idx: int,
	parent_branch: RoadBranch
) -> RoadBranch:
	var b_id: int = next_branch_id
	next_branch_id += 1

	var b := RoadBranch.new()
	b.branch_id = b_id
	b.fork_id = fork_id
	b.branch_index = branch_idx
	b.parent_branch_id = parent_branch.branch_id
	b.state = BranchState.PRELOADED
	b.fork_node_pos = parent_branch.fork_node_pos
	b.fork_node_tang = parent_branch.fork_node_tang
	b.fork_node_norm = parent_branch.fork_node_norm

	var branch_path = RoadPathDataClass.new()
	branch_path.branch_id = b_id
	branch_path.fork_node_id = fork_id

	# Strictly deterministic child seed derivation
	var parent_seed: int = parent_branch.road_logic.world_seed
	var b_seed: int = hash([parent_seed, fork_id, branch_idx]) & 0x7FFFFFFF
	var b_logic = RoadLogicClass.new(b_seed, branch_path)

	b_logic.last_point = parent_branch.fork_node_pos
	b_logic.last_tangent = parent_branch.fork_node_tang
	b_logic.last_normal = parent_branch.fork_node_norm
	b_logic.current_heading_deg = parent_branch.road_logic.current_heading_deg
	b_logic.current_slope_deg = parent_branch.road_logic.current_slope_deg

	branch_path.truncate_to(0)
	b.road_path = branch_path
	b.road_logic = b_logic
	branches[b_id] = b
	return b

# ==============================================================================
# FORK DECISION EVALUATION & STATE TRANSITIONS
# ==============================================================================

func _update_fork_decisions(player_pos: Vector3, player_vel: Vector3, delta: float) -> void:
	for b in branches.values():
		if (b.state == BranchState.ACTIVE or b.state == BranchState.PRELOADED) and b.decision_model != null:
			if not b.decision_model.is_locked():
				var dist_to_fork: float = player_pos.distance_to(b.fork_node_pos)
				if dist_to_fork <= 75.0:
					b.decision_model.update(player_pos, player_vel, delta)

func _on_branch_locked(fork_id: int, chosen_choice: int, parent_branch_id: int) -> void:
	var parent: RoadBranch = branches.get(parent_branch_id, null)
	if parent == null or parent.child_branch_ids.is_empty():
		return

	var alt_branch_id: int = parent.child_branch_ids[0]
	var alt_branch: RoadBranch = branches.get(alt_branch_id, null)

	if chosen_choice == ForkDecisionModelClass.BranchChoice.RIGHT and alt_branch != null:
		# Player chose Right (the alternative branch)
		alt_branch.state = BranchState.ACTIVE
		alt_branch.distance_at_last_fork = 0.0
		alt_branch.is_fork_spawned = false

		# Parent branch remains solid and visible until distance threshold
		parent.state = BranchState.DORMANT
		parent.generation_id += 1

		active_branch_id = alt_branch_id
		if world_manager and "road_path" in world_manager:
			world_manager.road_path = alt_branch.road_path
	else:
		# Player chose Left (continued along primary active branch)
		if alt_branch != null:
			alt_branch.state = BranchState.DORMANT
			alt_branch.generation_id += 1

		# Reset fork spawned flag on active branch so next fork can spawn after interval
		parent.is_fork_spawned = false

	if parent.decision_model:
		parent.decision_model = null

# ==============================================================================
# PHYSICAL 3D ROLLBACK SAFETY ENVELOPE (DORMANT -> UNLOADED)
# ==============================================================================

func _update_dormant_branches_safety_envelope(player_pos: Vector3, player_vel: Vector3) -> void:
	var branches_to_unload: Array[int] = []

	for b_id: int in branches:
		var b: RoadBranch = branches[b_id]
		if b.state != BranchState.DORMANT:
			continue

		# Check 1: 3D Euclidean distance to fork origin (solid retention up to 80m)
		var dist_to_fork: float = player_pos.distance_to(b.fork_node_pos)
		if dist_to_fork <= fork_safety_radius or dist_to_fork < 80.0:
			continue # Player is still physically close to fork origin

		# Check 2: 3D Euclidean distance to dormant road corridor
		var min_corridor_dist: float = _compute_min_distance_to_branch(player_pos, b.road_path)
		if min_corridor_dist <= safety_corridor_margin:
			continue # Player is physically close to dormant road

		# Check 3: Airborne safety guard
		var is_airborne: bool = false
		if world_manager and "player" in world_manager and world_manager.player:
			if "is_airborne" in world_manager.player:
				is_airborne = world_manager.player.is_airborne
			elif "is_on_ground" in world_manager.player:
				is_airborne = not world_manager.player.is_on_ground()

		if is_airborne and not player_vel.is_zero_approx():
			var to_dormant: Vector3 = (b.fork_node_pos - player_pos).normalized()
			if player_vel.normalized().dot(to_dormant) > 0.3:
				continue # Airborne trajectory directed towards dormant branch

		# All safety invariants satisfied -> Transition to UNLOADED
		branches_to_unload.append(b_id)

	for id in branches_to_unload:
		_unload_branch(id)

func _compute_min_distance_to_branch(pos: Vector3, path: RefCounted) -> float:
	if path == null or path.size() == 0:
		return INF
	var min_d: float = INF
	var pts: PackedVector3Array = path.points
	for i in range(pts.size()):
		var d: float = pos.distance_to(pts[i])
		if d < min_d:
			min_d = d
	return min_d

func _unload_branch(b_id: int) -> void:
	var b: RoadBranch = branches.get(b_id, null)
	if b == null:
		return

	b.state = BranchState.UNLOADED
	b.generation_id += 1

	for chunk: Node3D in b.active_chunks.values():
		if is_instance_valid(chunk):
			chunk.queue_free()

	b.active_chunks.clear()
	b.chunk_end_distances.clear()
	branches.erase(b_id)

# ==============================================================================
# CHUNK GENERATION & DISPATCH
# ==============================================================================

func _spawn_chunk_sync(branch: RoadBranch) -> void:
	var r_path: RefCounted = branch.road_path
	var r_logic: RefCounted = branch.road_logic
	var start_idx: int = maxi(0, r_path.size() - 1)

	r_logic.plan_next_chunk()
	var end_idx: int = r_path.size() - 1

	var c_id: int = next_chunk_id
	next_chunk_id += 1

	var token := GenerationToken.new(branch.generation_id, branch.branch_id, c_id)

	var prep = RoadChunkClass.prepare_geometry_data(
		r_path, start_idx, end_idx, c_id, shared_materials, token, false, branch.fork_node_tang
	)

	var chunk: Node3D = RoadChunkClass.new()
	add_child(chunk)
	var timings = chunk.commit(prep, shared_materials, shared_meshes)
	last_chunk_timings = timings
	last_chunk_gen_ms = timings.get("t_total", 0.0)

	var end_s: float = r_path.cumulative_distances[end_idx]
	branch.active_chunks[c_id] = chunk
	branch.chunk_end_distances[c_id] = end_s

func _despawn_chunks_behind(branch: RoadBranch, threshold_s: float) -> void:
	var ids_to_remove: Array[int] = []
	for id: int in branch.active_chunks:
		var end_s: float = branch.chunk_end_distances.get(id, 0.0)
		if end_s < threshold_s:
			ids_to_remove.append(id)

	for id in ids_to_remove:
		var chunk_node: Node3D = branch.active_chunks[id]
		branch.active_chunks.erase(id)
		branch.chunk_end_distances.erase(id)
		if is_instance_valid(chunk_node):
			chunk_node.queue_free()

# ==============================================================================
# PUBLIC GETTERS & DUCK-TYPING CONTRACT
# ==============================================================================

func get_active_branch() -> RoadBranch:
	return branches.get(active_branch_id, null)

func get_active_road_path() -> RefCounted:
	var b = get_active_branch()
	if b:
		return b.road_path
	return null

func get_active_chunk_count() -> int:
	var b = get_active_branch()
	if b:
		return b.active_chunks.size()
	return 0

func get_total_chunk_count() -> int:
	var total: int = 0
	for b in branches.values():
		total += b.active_chunks.size()
	return total

func get_active_branch_count() -> int:
	return branches.size()

func get_branch_state(b_id: int) -> int:
	var b: RoadBranch = branches.get(b_id, null)
	if b:
		return b.state
	return BranchState.UNLOADED
