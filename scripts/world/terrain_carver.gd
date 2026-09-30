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
const W_FAR: float = 45.0       ## Outer mountain flank (expanded 45m outer skirt)

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

const MountainMassifFieldClass = preload("res://scripts/world/mountain_massif_field.gd")

var world_seed: int = 184729
var mountain_weight: float = 0.5
var macro_noise: FastNoiseLite
var detail_noise: FastNoiseLite
var massif_field: RefCounted = null

func set_mountain_weight(mw: float) -> void:
	mountain_weight = clampf(mw, 0.0, 1.0)

# ==============================================================================
# INITIALIZATION & SETUP
# ==============================================================================

func _init(p_seed: int = 184729) -> void:
	setup(p_seed)

func setup(p_seed: int) -> void:
	world_seed = p_seed
	massif_field = MountainMassifFieldClass.new(world_seed)

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
	if massif_field != null:
		return massif_field.get_elevation(wx, wz)
	return macro_noise.get_noise_2d(wx, wz) * MACRO_NOISE_AMP

func get_detail_elevation(wx: float, wz: float) -> float:
	return detail_noise.get_noise_2d(wx, wz) * DETAIL_NOISE_AMP

# ==============================================================================
# MULTI-FACTOR PROFILE EVALUATION
# ==============================================================================

## Evaluates geological profile scores and classification for Left and Right sides.
## Returns a Dictionary with profile enums, target feature heights, and danger flags.
func evaluate_profile(pos: Vector3, binorm: Vector3, curv: float, p_mountain_weight: float = -1.0) -> Dictionary:
	var mw: float = p_mountain_weight if p_mountain_weight >= 0.0 else mountain_weight
	# 1. Macro slope gradient across the road corridor (+b points strictly RIGHT)
	var p_l: Vector3 = pos - binorm * 15.0
	var p_r: Vector3 = pos + binorm * 15.0
	var h_macro_l: float = get_macro_elevation(p_l.x, p_l.z)
	var h_macro_r: float = get_macro_elevation(p_r.x, p_r.z)
	var g_lat: float = clampf((h_macro_r - h_macro_l) / 30.0, -1.0, 1.0)

	# 2. Road curvature factor: curv > 0 = turning right (+b), inner curve is Right
	var kappa_eff: float = clampf(curv * 20.0, -1.0, 1.0)

	# 3. Seeded variation bias from world coordinates
	var b_seed: float = detail_noise.get_noise_2d(pos.x * 0.05, pos.z * 0.05)

	# 4. Multi-factor weighted scores (+kappa_eff creates inner rock cut on right)
	var score_r: float = 0.50 * g_lat + 0.35 * kappa_eff + 0.15 * b_seed
	var score_l: float = -0.50 * g_lat - 0.35 * kappa_eff + 0.15 * b_seed

	# In mountain zones (mountain_weight > 0.5), amplify relief so cuts/shelves appear even on straights
	if mw > 0.50:
		var mw_boost: float = (mw - 0.50) / 0.50 # 0.0 to 1.0
		var relief_bias: float = (1.0 if b_seed >= 0.0 else -1.0) * 0.28 * mw_boost
		score_r += relief_bias
		score_l -= relief_bias

	# 5. Classify profiles and determine feature heights
	var class_l: Dictionary = _classify_side_score(score_l, mw)
	var class_r: Dictionary = _classify_side_score(score_r, mw)

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

func _classify_side_score(score: float, mw: float = 0.5) -> Dictionary:
	var mw_amp: float = 1.0 + maxf(0.0, mw - 0.5) * 0.4
	if score > 0.25:
		# Uphill rock cut
		var dh: float = (2.5 + (score - 0.25) * 6.5) * mw_amp
		return { "profile": ProfileType.CUT, "delta_h": clampf(dh, 2.5, 7.5) }
	elif score < -0.25:
		# Sheer cliff precipice
		var dh: float = (-4.0 + (score + 0.25) * 12.0) * mw_amp
		return { "profile": ProfileType.CLIFF, "delta_h": clampf(dh, -18.0, -4.0) }
	elif score < -0.08:
		# Embankment fill slope
		var dh: float = -1.5 + (score + 0.08) * 8.0
		if mw > 0.5:
			dh -= (mw - 0.5) * 1.5
		return { "profile": ProfileType.FILL, "delta_h": clampf(dh, -4.0, -1.0) }
	else:
		# Gentle rolling meadow
		var dh: float = score * 3.0
		if mw > 0.65:
			var sign_dh: float = 1.0 if score >= 0.0 else -1.0
			dh = sign_dh * maxf(absf(dh), 1.5 * (mw - 0.65) / 0.35)
		return { "profile": ProfileType.MEADOW, "delta_h": clampf(dh, -1.8, 1.8) }

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
	dist: float,
	p_mountain_weight: float = -1.0
) -> Dictionary:
	var mw: float = p_mountain_weight if p_mountain_weight >= 0.0 else mountain_weight
	var eval: Dictionary = evaluate_profile(pt, binorm, curv, mw)

	var dh_left: float = eval.left_delta_h
	var dh_right: float = eval.right_delta_h

	# 1. Base lateral displacements along binormal with Smooth Adaptive Curvature Clamping
	# Continuously scale the inner skirt as curvature increases to prevent evolute crossing and tears
	var abs_k: float = absf(curv)
	var r_local: float = (1.0 / abs_k) if abs_k > 0.0001 else 9999.0
	var d_inner_target: float = minf(W_FAR, maxf(8.0, r_local * 0.70))

	# Smooth blending factor into turn (0.0 on straights, 1.0 when R <= 45m)
	var turn_blend: float = clampf((abs_k - 0.002) / (0.022 - 0.002), 0.0, 1.0)
	var d_clamped_inner: float = lerpf(W_FAR, d_inner_target, turn_blend)

	# Inner skirt clamping: when turning right (curv > 0), clamp right. When turning left (curv < 0), clamp left.
	var w_far_l: float = d_clamped_inner if curv < 0.0 else W_FAR
	var w_far_r: float = d_clamped_inner if curv > 0.0 else W_FAR

	# Strictly enforce monotonic ordering of offsets: half_w < d_sh < d_feat < d_far
	var total_w_l: float = half_w + W_SHOULDER + W_FEATURE + w_far_l
	var total_w_r: float = half_w + W_SHOULDER + W_FEATURE + w_far_r

	# Cap inner lateral span strictly under R_local * 0.80
	if curv > 0.001 and r_local < 900.0:
		total_w_r = minf(total_w_r, maxf(half_w + 3.5, r_local * 0.75))
	elif curv < -0.001 and r_local < 900.0:
		total_w_l = minf(total_w_l, maxf(half_w + 3.5, r_local * 0.75))

	var d_sh_l: float = half_w + minf(W_SHOULDER, (total_w_l - half_w) * 0.15)
	var d_feat_l: float = d_sh_l + minf(W_FEATURE, (total_w_l - d_sh_l) * 0.35)
	var d_far_l: float = total_w_l

	var d_sh_r: float = half_w + minf(W_SHOULDER, (total_w_r - half_w) * 0.15)
	var d_feat_r: float = d_sh_r + minf(W_FEATURE, (total_w_r - d_sh_r) * 0.35)
	var d_far_r: float = total_w_r

	# Left side positions (-b)
	var pos_l_road: Vector3 = pt - binorm * half_w
	var pos_l_sh: Vector3 = pt - binorm * d_sh_l
	var pos_l_feat: Vector3 = pt - binorm * d_feat_l
	var pos_l_far: Vector3 = pt - binorm * d_far_l

	# Right side positions (+b)
	var pos_r_road: Vector3 = pt + binorm * half_w
	var pos_r_sh: Vector3 = pt + binorm * d_sh_r
	var pos_r_feat: Vector3 = pt + binorm * d_feat_r
	var pos_r_far: Vector3 = pt + binorm * d_far_r

	# 2. Detail and macro height sampling
	var center_macro: float = get_macro_elevation(pt.x, pt.z)
	var center_detail: float = get_detail_elevation(pt.x, pt.z)
	var h_far_l: float = get_macro_elevation(pos_l_far.x, pos_l_far.z) - center_macro + get_detail_elevation(pos_l_far.x, pos_l_far.z) - center_detail
	var h_feat_l: float = dh_left + get_detail_elevation(pos_l_feat.x, pos_l_feat.z) * 0.5
	var h_sh_l: float = -0.02 # Slight drainage dip

	var h_far_r: float = get_macro_elevation(pos_r_far.x, pos_r_far.z) - center_macro + get_detail_elevation(pos_r_far.x, pos_r_far.z) - center_detail
	var h_feat_r: float = dh_right + get_detail_elevation(pos_r_feat.x, pos_r_feat.z) * 0.5
	var h_sh_r: float = -0.02 # Slight drainage dip

	# 3. Final 3D Vertex positions
	# Beveled Verge: terrain edge sits 3.5cm below physical road surface to eliminate Z-fighting
	const VERGE_STEP_HEIGHT: float = 0.035
	var v3: Vector3 = pos_l_road - norm * VERGE_STEP_HEIGHT
	var v4: Vector3 = pos_r_road - norm * VERGE_STEP_HEIGHT

	var v2: Vector3 = pos_l_sh + norm * (h_sh_l - VERGE_STEP_HEIGHT)
	var v1: Vector3 = pos_l_feat + norm * h_feat_l
	var v0: Vector3 = pos_l_far + norm * h_far_l

	var v5: Vector3 = pos_r_sh + norm * (h_sh_r - VERGE_STEP_HEIGHT)
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

	var offsets := PackedFloat32Array([-d_far_l, -d_feat_l, -d_sh_l, -half_w, half_w, d_sh_r, d_feat_r, d_far_r])

	return {
		"vertices": vertices,
		"offsets": offsets,
		"uvs": uvs,
		"danger_mask": danger_mask,
		"eval": eval,
		"shoulder_left_pos": v2,
		"shoulder_right_pos": v5
	}

## Precision Foliage Anchoring: computes exact 3D surface point on the cross-section
## at given lateral offset in meters (negative = Left, positive = Right).
static func get_surface_point_from_cross_section(cs: Dictionary, lat_offset: float) -> Vector3:
	var verts: PackedVector3Array = cs.get("vertices", PackedVector3Array())
	var offsets: PackedFloat32Array = cs.get("offsets", PackedFloat32Array())
	if offsets.is_empty() or verts.size() < 8:
		return cs.get("shoulder_left_pos", Vector3.ZERO)
	if lat_offset <= offsets[0]:
		return verts[0]
	if lat_offset >= offsets[7]:
		return verts[7]
	for seg in range(7):
		var o0: float = offsets[seg]
		var o1: float = offsets[seg + 1]
		if lat_offset >= o0 and lat_offset <= o1:
			var span: float = o1 - o0
			var t: float = (lat_offset - o0) / span if span > 0.0001 else 0.0
			return verts[seg].lerp(verts[seg + 1], t)
	return verts[3]
