class_name TerrainCarver
extends RefCounted

## Slow Cycle — Mountain Terrain Carver (v1.0.0)
## Pure domain RefCounted class for road-centric mountain terrain generation.
## Evaluates multi-factor profile classification (macro mountain slope, road curvature,
## seeded noise) and generates an 8-vertex bounded cross-section conforming to RoadPathData.
## Strictly decoupled from bicycle physics, scene graph manipulation, and shaders.

# ==============================================================================
# ENUMS & CONSTANTS
# ==============================================================================

enum ProfileType {
	MEADOW = 0,  ## Gentle rolling meadow (|Score| <= 0.08)
	CUT = 1,     ## Uphill mountain rock cut (Score > 0.25)
	SHELF = 2,   ## Mountain ledge (CUT on one side, CLIFF/FILL on other)
	CLIFF = 3,   ## Sheer drop-off / gorge (Score < -0.25)
	FILL = 4     ## Natural embankment slope (-0.25 <= Score < -0.08)
}

# Cross-section lateral width dimensions (meters from road edge)
const W_SHOULDER: float = 0.8   ## Shoulder / drainage swale
const W_FEATURE: float = 4.5    ## Feature breakline (Cut face or Cliff lip)
const W_FAR: float = 20.0       ## Outer mountain flank

# Danger threshold for visual guard post placement (meters drop below shoulder)
const DANGER_DROP_THRESHOLD: float = 2.5

# Noise configuration constants
const MACRO_NOISE_FREQ: float = 0.004
const MACRO_NOISE_AMP: float = 16.0
const DETAIL_NOISE_FREQ: float = 0.030
const DETAIL_NOISE_AMP: float = 1.2

# ==============================================================================
# STATE & NOISE GENERATORS
# ==============================================================================

var world_seed: int = 184729
var macro_noise: FastNoiseLite
var detail_noise: FastNoiseLite

# ==============================================================================
# INITIALIZATION & SETUP
# ==============================================================================

func _init(p_seed: int = 184729) -> void:
	setup(p_seed)

func setup(p_seed: int) -> void:
	world_seed = p_seed

	macro_noise = FastNoiseLite.new()
	macro_noise.seed = world_seed
	macro_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	macro_noise.frequency = MACRO_NOISE_FREQ
	macro_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	macro_noise.fractal_octaves = 3
	macro_noise.fractal_lacunarity = 2.0
	macro_noise.fractal_gain = 0.5

	detail_noise = FastNoiseLite.new()
	detail_noise.seed = (world_seed + 54321) & 0x7FFFFFFF
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail_noise.frequency = DETAIL_NOISE_FREQ
	detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	detail_noise.fractal_octaves = 2
	detail_noise.fractal_lacunarity = 2.0
	detail_noise.fractal_gain = 0.5

# ==============================================================================
# WORLD-SPACE NOISE QUERIES (Zero Allocations)
# ==============================================================================

func get_macro_elevation(wx: float, wz: float) -> float:
	return macro_noise.get_noise_2d(wx, wz) * MACRO_NOISE_AMP

func get_detail_elevation(wx: float, wz: float) -> float:
	return detail_noise.get_noise_2d(wx, wz) * DETAIL_NOISE_AMP

# ==============================================================================
# MULTI-FACTOR PROFILE EVALUATION
# ==============================================================================

## Evaluates geological profile scores and classification for Left and Right sides.
## Returns a Dictionary with profile enums, target feature heights, and danger flags.
func evaluate_profile(pos: Vector3, binorm: Vector3, curv: float) -> Dictionary:
	# 1. Macro slope gradient across the road corridor (+b points strictly RIGHT)
	var p_l: Vector3 = pos - binorm * 15.0
	var p_r: Vector3 = pos + binorm * 15.0
	var h_macro_l: float = get_macro_elevation(p_l.x, p_l.z)
	var h_macro_r: float = get_macro_elevation(p_r.x, p_r.z)
	var g_lat: float = clampf((h_macro_r - h_macro_l) / 30.0, -1.0, 1.0)

	# 2. Road curvature factor (kappa > 0 = turning left, inner curve is Left)
	var kappa_eff: float = clampf(curv * 20.0, -1.0, 1.0)

	# 3. Seeded variation bias from world coordinates
	var b_seed: float = detail_noise.get_noise_2d(pos.x * 0.05, pos.z * 0.05)

	# 4. Multi-factor weighted scores
	var score_r: float = 0.50 * g_lat - 0.35 * kappa_eff + 0.15 * b_seed
	var score_l: float = -0.50 * g_lat + 0.35 * kappa_eff + 0.15 * b_seed

	# 5. Classify profiles and determine feature heights
	var class_l: Dictionary = _classify_side_score(score_l)
	var class_r: Dictionary = _classify_side_score(score_r)

	var danger_l: bool = class_l.delta_h < -DANGER_DROP_THRESHOLD
	var danger_r: bool = class_r.delta_h < -DANGER_DROP_THRESHOLD

	return {
		"left_profile": class_l.profile,
		"right_profile": class_r.profile,
		"left_delta_h": class_l.delta_h,
		"right_delta_h": class_r.delta_h,
		"score_left": score_l,
		"score_right": score_r,
		"danger_left": danger_l,
		"danger_right": danger_r
	}

func _classify_side_score(score: float) -> Dictionary:
	if score > 0.25:
		# Uphill rock cut
		var dh: float = 2.5 + (score - 0.25) * 6.5
		return { "profile": ProfileType.CUT, "delta_h": clampf(dh, 2.5, 6.5) }
	elif score < -0.25:
		# Sheer cliff precipice
		var dh: float = -4.0 + (score + 0.25) * 12.0
		return { "profile": ProfileType.CLIFF, "delta_h": clampf(dh, -16.0, -4.0) }
	elif score < -0.08:
		# Embankment fill slope
		var dh: float = -1.5 + (score + 0.08) * 8.0
		return { "profile": ProfileType.FILL, "delta_h": clampf(dh, -3.0, -1.0) }
	else:
		# Gentle rolling meadow
		var dh: float = score * 3.0
		return { "profile": ProfileType.MEADOW, "delta_h": clampf(dh, -1.2, 1.2) }

# ==============================================================================
# CROSS-SECTION GEOMETRY GENERATION
# ==============================================================================

## Computes the 8-vertex lateral cross section for a single road sample point.
## Output vertices: V0 (Left Far) .. V3 (Left Road) .. V4 (Right Road) .. V7 (Right Far).
## Guarantees V3 and V4 exactly match p - b * half_w and p + b * half_w.
func compute_cross_section(
	pt: Vector3,
	_tang: Vector3,
	norm: Vector3,
	binorm: Vector3,
	half_w: float,
	curv: float,
	_seg_type: int,
	dist: float
) -> Dictionary:
	var eval: Dictionary = evaluate_profile(pt, binorm, curv)

	var dh_left: float = eval.left_delta_h
	var dh_right: float = eval.right_delta_h

	# 1. Base lateral displacements along binormal
	var d_sh: float = half_w + W_SHOULDER
	var d_feat: float = d_sh + W_FEATURE
	var d_far: float = d_feat + W_FAR

	# Left side positions (-b)
	var pos_l_road: Vector3 = pt - binorm * half_w
	var pos_l_sh: Vector3 = pt - binorm * d_sh
	var pos_l_feat: Vector3 = pt - binorm * d_feat
	var pos_l_far: Vector3 = pt - binorm * d_far

	# Right side positions (+b)
	var pos_r_road: Vector3 = pt + binorm * half_w
	var pos_r_sh: Vector3 = pt + binorm * d_sh
	var pos_r_feat: Vector3 = pt + binorm * d_feat
	var pos_r_far: Vector3 = pt + binorm * d_far

	# 2. Detail and macro height sampling
	var h_far_l: float = get_macro_elevation(pos_l_far.x, pos_l_far.z) + get_detail_elevation(pos_l_far.x, pos_l_far.z)
	var h_feat_l: float = dh_left + get_detail_elevation(pos_l_feat.x, pos_l_feat.z) * 0.5
	var h_sh_l: float = -0.02 # Slight drainage dip

	var h_far_r: float = get_macro_elevation(pos_r_far.x, pos_r_far.z) + get_detail_elevation(pos_r_far.x, pos_r_far.z)
	var h_feat_r: float = dh_right + get_detail_elevation(pos_r_feat.x, pos_r_feat.z) * 0.5
	var h_sh_r: float = -0.02 # Slight drainage dip

	# 3. Final 3D Vertex positions
	# V3 and V4 have EXACT zero offset from road edge
	var v3: Vector3 = pos_l_road
	var v4: Vector3 = pos_r_road

	var v2: Vector3 = pos_l_sh + norm * h_sh_l
	var v1: Vector3 = pos_l_feat + norm * h_feat_l
	var v0: Vector3 = pos_l_far + norm * h_far_l

	var v5: Vector3 = pos_r_sh + norm * h_sh_r
	var v6: Vector3 = pos_r_feat + norm * h_feat_r
	var v7: Vector3 = pos_r_far + norm * h_far_r

	var vertices := PackedVector3Array([v0, v1, v2, v3, v4, v5, v6, v7])

	# 4. UV coordinates (normalized along corridor width and longitudinal distance)
	var v_coord: float = dist * 0.15
	var uvs := PackedVector2Array([
		Vector2(0.00, v_coord),
		Vector2(0.18, v_coord),
		Vector2(0.24, v_coord),
		Vector2(0.26, v_coord), # Left road edge
		Vector2(0.74, v_coord), # Right road edge
		Vector2(0.76, v_coord),
		Vector2(0.82, v_coord),
		Vector2(1.00, v_coord)
	])

	# Danger flags (bit 0 = left cliff, bit 1 = right cliff)
	var danger_mask: int = 0
	if eval.danger_left:
		danger_mask |= 1
	if eval.danger_right:
		danger_mask |= 2

	return {
		"vertices": vertices,
		"uvs": uvs,
		"danger_mask": danger_mask,
		"eval": eval,
		"shoulder_left_pos": v2,
		"shoulder_right_pos": v5
	}
