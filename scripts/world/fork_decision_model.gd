class_name ForkDecisionModel
extends RefCounted

## Slow Cycle — Fork Topology & Branch Decision Model (v1.0.0)
## Evaluates bicycle rider intent approaching road bifurcations in mountain terrain.
## Uses a 4-phase state machine with exponential intent smoothing and commit hysteresis.
## Pure decision domain: does NOT steer the bicycle, modify kinematics, or search splines.

const RoadMathClass = preload("res://scripts/world/road_math.gd")

# ==============================================================================
# ENUMS & CONSTANTS
# ==============================================================================

enum ForkState {
	APPROACH = 0,         ## Rider > 50m upstream of fork
	FORK_PREVIEW = 1,     ## Preview zone [-50m .. -15m]: player weaves freely, lock forbidden
	FORK_COMMIT_ZONE = 2, ## Commit zone [-15m .. +15m]: active filtering and locking
	BRANCH_LOCKED = 3     ## Branch decision finalized and irreversible
}

enum BranchChoice {
	UNDECIDED = -1,
	LEFT = 0,
	RIGHT = 1
}

# Explicit spatial zone constants (relative to fork point along tangent)
const D_PREVIEW: float = 50.0       ## Upstream preview zone threshold (s = -50m)
const D_COMMIT: float = 15.0        ## Upstream commit zone threshold (s = -15m)
const D_LOCK_MIN: float = 8.0       ## Earliest physical commit threshold past fork (s = +8m)
const D_LOCK_HARD: float = 15.0     ## Point-of-no-return threshold past fork (s = +15m)

# Decision and filtering parameters
const CONFIDENCE_THRESHOLD: float = 0.65  ## Minimum |C| required for normal commit at s >= D_LOCK_MIN
const FALLBACK_THRESHOLD: float = 0.15    ## Minimum |C| for sign-based resolution at s >= D_LOCK_HARD
const TENDENCY_DEADBAND: float = 0.05     ## Deadband for raw instantaneous tendency
const FILTER_LAMBDA: float = 8.0          ## TUNABLE: low-pass filter rate (tau = 0.125s)

const W_DIST: float = 0.60          ## Lateral proximity weighting
const W_HEADING: float = 0.40       ## Planar heading alignment weighting

# ==============================================================================
# SIGNALS
# ==============================================================================

signal fork_preview_entered(fork_id: int, distance_to_fork: float)
signal branch_locked(fork_id: int, chosen_branch: int)
signal state_changed(previous_state: int, new_state: int)

# ==============================================================================
# FORK GEOMETRIC CONTEXT (Set once upon setup)
# ==============================================================================

var fork_node_id: int = -1
var fork_origin: Vector3 = Vector3.ZERO
var fork_tangent: Vector3 = Vector3.FORWARD
var fork_normal: Vector3 = Vector3.UP
var fork_binormal: Vector3 = Vector3.RIGHT
var divergence_angle_rad: float = 0.35  ## ~20 degrees default
var default_branch: int = BranchChoice.LEFT
var branch_divergence_length: float = 15.0
var branch_lateral_offset: float = 2.5

# ==============================================================================
# STATE VARIABLES
# ==============================================================================

var current_state: int = ForkState.APPROACH
var locked_branch: int = BranchChoice.UNDECIDED
var confidence_score: float = 0.0          ## Continuous intent: [-1.0 = LEFT .. +1.0 = RIGHT]
var instant_tendency: int = BranchChoice.UNDECIDED

# ==============================================================================
# INITIALIZATION & SETUP
# ==============================================================================

func _init() -> void:
	reset()

func reset() -> void:
	current_state = ForkState.APPROACH
	locked_branch = BranchChoice.UNDECIDED
	confidence_score = 0.0
	instant_tendency = BranchChoice.UNDECIDED

## Configures the decision model with explicit fork geometry and parameters
func setup(
	f_id: int,
	origin: Vector3,
	tangent: Vector3,
	normal: Vector3,
	div_angle_deg: float = 20.0,
	def_branch: int = BranchChoice.LEFT,
	div_length: float = 15.0,
	lat_offset: float = 2.5
) -> void:
	reset()
	fork_node_id = f_id
	fork_origin = origin
	fork_tangent = tangent.normalized() if not tangent.is_zero_approx() else Vector3.FORWARD
	fork_normal = normal.normalized() if not normal.is_zero_approx() else Vector3.UP

	var binorm: Vector3 = fork_tangent.cross(fork_normal)
	if binorm.is_zero_approx():
		fork_binormal = Vector3.RIGHT
	else:
		fork_binormal = binorm.normalized()

	divergence_angle_rad = deg_to_rad(absf(div_angle_deg))
	default_branch = def_branch
	branch_divergence_length = maxf(1.0, div_length)
	branch_lateral_offset = maxf(0.5, lat_offset)

## Convenience setup extracting geometry directly from a RoadForkNode
func setup_from_node(fork_node: RefCounted, def_branch: int = BranchChoice.LEFT) -> void:
	if fork_node == null:
		return
	var f_id: int = fork_node.node_id if "node_id" in fork_node else -1
	var pos: Vector3 = fork_node.position if "position" in fork_node else Vector3.ZERO
	var tang: Vector3 = fork_node.tangent if "tangent" in fork_node else Vector3.FORWARD
	var norm: Vector3 = fork_node.normal if "normal" in fork_node else Vector3.UP
	var div_deg: float = 20.0
	if "branch_previews" in fork_node and fork_node.branch_previews.size() > 0:
		var bp = fork_node.branch_previews[0]
		if "divergence_angle_deg" in bp and absf(bp.divergence_angle_deg) > 0.001:
			div_deg = absf(bp.divergence_angle_deg)
	setup(f_id, pos, tang, norm, div_deg, def_branch)

# ==============================================================================
# PER-TICK EVALUATION (O(1) Scalar Arithmetic, Zero Heap Allocations)
# ==============================================================================

## Updates decision model based on current player position and velocity
func update(player_pos: Vector3, player_vel: Vector3, delta: float) -> void:
	# Irreversible contract: once locked, decision cannot change
	if current_state == ForkState.BRANCH_LOCKED:
		return

	# 1. Project into Fork-Local Reference Frame
	var r: Vector3 = player_pos - fork_origin
	var s: float = r.dot(fork_tangent)
	var x: float = r.dot(fork_binormal)

	# 2. State Machine Transitions based on Longitudinal Progress (s)
	var prev_state: int = current_state
	if s < -D_PREVIEW:
		current_state = ForkState.APPROACH
	elif s < -D_COMMIT:
		current_state = ForkState.FORK_PREVIEW
		if prev_state != ForkState.FORK_PREVIEW:
			fork_preview_entered.emit(fork_node_id, -s)
	else:
		current_state = ForkState.FORK_COMMIT_ZONE

	if prev_state != current_state:
		state_changed.emit(prev_state, current_state)

	# 3. Branch Centerline Lateral Positions x_L(s), x_R(s)
	var x_l: float = 0.0
	var x_r: float = 0.0
	if s <= 0.0:
		var w: float = RoadMathClass.compute_fork_width(s, 25.0, 4.0, 10.0)
		var half_offset: float = w * 0.25
		x_l = -half_offset
		x_r = half_offset
	else:
		var offset: float = RoadMathClass.compute_fork_branch_center_offset(
			s, branch_divergence_length, branch_lateral_offset
		)
		x_l = -2.5 - offset
		x_r = 2.5 + offset

	# 4. Lateral Distance Bias (S_dist in [-1.0 .. +1.0])
	# Standard convention: LEFT < 0, RIGHT > 0
	var d_l: float = absf(x - x_l)
	var d_r: float = absf(x - x_r)
	var denom_dist: float = maxf(0.5, d_l + d_r)
	var s_dist: float = (d_l - d_r) / denom_dist

	# 5. Planar Velocity Heading Alignment (S_heading in [-1.0 .. +1.0])
	var v_fwd: float = player_vel.dot(fork_tangent)
	var v_lat: float = player_vel.dot(fork_binormal)
	var v_planar: float = sqrt(v_fwd * v_fwd + v_lat * v_lat)

	var s_heading: float = 0.0
	var s_instant: float = 0.0
	if v_planar < 0.1:
		s_instant = s_dist
	else:
		var theta_vel: float = atan2(v_lat, maxf(0.1, v_fwd))
		var ref_ang: float = maxf(0.01, divergence_angle_rad)
		s_heading = clampf(theta_vel / ref_ang, -1.0, 1.0)
		s_instant = clampf(W_DIST * s_dist + W_HEADING * s_heading, -1.0, 1.0)

	# 6. Raw Instantaneous Tendency Output (Deadband Protected)
	if s_instant < -TENDENCY_DEADBAND:
		instant_tendency = BranchChoice.LEFT
	elif s_instant > TENDENCY_DEADBAND:
		instant_tendency = BranchChoice.RIGHT
	else:
		instant_tendency = BranchChoice.UNDECIDED

	# 7. Exponential Intent Smoothing (Low-pass Filter)
	var dt_clamped: float = clampf(delta, 0.0, 0.1)
	var alpha: float = 1.0 - exp(-FILTER_LAMBDA * dt_clamped)
	confidence_score += (s_instant - confidence_score) * alpha
	confidence_score = clampf(confidence_score, -1.0, 1.0)

	# 8. Commit Hysteresis & Lock Gate
	# In FORK_PREVIEW (s < -D_COMMIT), locking is strictly forbidden.
	# In FORK_COMMIT_ZONE:
	if current_state == ForkState.FORK_COMMIT_ZONE:
		# Condition A: Normal lock at s >= D_LOCK_MIN (+8m) with high confidence (|C| >= 0.65)
		if s >= D_LOCK_MIN and absf(confidence_score) >= CONFIDENCE_THRESHOLD:
			_lock_to_branch(BranchChoice.RIGHT if confidence_score > 0.0 else BranchChoice.LEFT)
		# Condition B: Hard-lock fallback at s >= D_LOCK_HARD (+15m) point-of-no-return
		elif s >= D_LOCK_HARD:
			if absf(confidence_score) >= FALLBACK_THRESHOLD:
				_lock_to_branch(BranchChoice.RIGHT if confidence_score > 0.0 else BranchChoice.LEFT)
			else:
				_lock_to_branch(default_branch)

func _lock_to_branch(choice: int) -> void:
	var old_state: int = current_state
	locked_branch = choice
	current_state = ForkState.BRANCH_LOCKED
	state_changed.emit(old_state, current_state)
	branch_locked.emit(fork_node_id, locked_branch)

# ==============================================================================
# GETTERS
# ==============================================================================

func get_state() -> int:
	return current_state

func get_locked_branch() -> int:
	return locked_branch

func get_confidence() -> float:
	return confidence_score

func get_instant_tendency() -> int:
	return instant_tendency

func is_locked() -> bool:
	return current_state == ForkState.BRANCH_LOCKED
