class_name ChunkStreamer
extends Node3D

const RoadChunkClass = preload("res://scripts/world/road_chunk.gd")

const AHEAD_DISTANCE: float = 350.0 ## Keep 350m of road generated in front
const BEHIND_DISTANCE: float = 65.0 ## Keep 65m of road behind player

var world_manager: Node3D
var road_path: RefCounted
var road_logic: RefCounted

var shared_materials: Dictionary = {}
var shared_meshes: Dictionary = {}

var active_chunks: Dictionary = {} # chunk_id -> RoadChunk
var chunk_end_distances: Dictionary = {} # chunk_id -> float

var next_chunk_id: int = 0
var last_chunk_gen_ms: float = 0.0
var last_closest_idx: int = 0

func setup(manager: Node3D, path: RefCounted, logic: RefCounted, mats: Dictionary, meshes: Dictionary) -> void:
	world_manager = manager
	road_path = path
	road_logic = logic
	shared_materials = mats
	shared_meshes = meshes

	# Pre-generate starting window (initial 7 chunks ~350m)
	for i in range(7):
		_spawn_next_chunk()

func update_streaming(player_pos: Vector3) -> void:
	if road_path.size() < 2:
		return

	var closest_idx: int = road_path.find_closest_index(player_pos, last_closest_idx)
	last_closest_idx = closest_idx
	var player_s: float = road_path.cumulative_distances[closest_idx]
	var total_s: float = road_path.get_total_distance()

	# 1. Spawn chunks ahead
	var spawn_guard: int = 0
	while (total_s - player_s) < AHEAD_DISTANCE and spawn_guard < 15:
		_spawn_next_chunk()
		total_s = road_path.get_total_distance()
		spawn_guard += 1

	# 2. Despawn chunks behind
	var ids_to_remove: Array[int] = []
	for id: int in active_chunks:
		var end_s: float = chunk_end_distances.get(id, 0.0)
		if end_s < (player_s - BEHIND_DISTANCE):
			ids_to_remove.append(id)

	for id in ids_to_remove:
		var chunk_node: Node3D = active_chunks[id]
		active_chunks.erase(id)
		chunk_end_distances.erase(id)
		chunk_node.queue_free()

	# 3. Prune historical spline samples further than 150m behind player
	if road_path and road_path.has_method("prune_behind"):
		var pruned: int = road_path.prune_behind(player_s - 150.0)
		if pruned > 0:
			last_closest_idx = maxi(0, last_closest_idx - pruned)

func _spawn_next_chunk() -> void:
	var start_idx: int = maxi(0, road_path.size() - 1)
	
	# Generate road logic samples for this chunk
	road_logic.plan_next_chunk()
	var end_idx: int = road_path.size() - 1

	if road_logic.has_method("is_last_chunk_valid") and not road_logic.is_last_chunk_valid():
		push_error("ChunkStreamer: chunk %d failed validity gate!" % next_chunk_id)

	var t_start: int = Time.get_ticks_usec()

	# Build and add RoadChunk node
	var chunk: Node3D = RoadChunkClass.new()
	add_child(chunk)
	chunk.build_chunk(road_path, start_idx, end_idx, next_chunk_id, shared_materials, shared_meshes)

	var t_end: int = Time.get_ticks_usec()
	last_chunk_gen_ms = float(t_end - t_start) / 1000.0

	var end_s: float = road_path.cumulative_distances[end_idx]
	active_chunks[next_chunk_id] = chunk
	chunk_end_distances[next_chunk_id] = end_s
	next_chunk_id += 1

func get_active_chunk_count() -> int:
	return active_chunks.size()
