extends RefCounted
class_name SurfaceOps
## GEN2-S S1: one list of ground operations over the design surface, with one
## composition rule (pure; no scene). The design surface (FinalSurface: natural
## ground + the road deformer, its math unchanged) answers the base height and
## the road planes; the operations above it are:
##   TRAIL     NATURAL trail band: material only, no height change;
##   BENCH     a trail's BENCH operation (TrailRealization, amendment A1):
##             the FinalSurface.trail_displacement() formula;
##   PLATFORM  SHAPED turn platform: flat disc at the design height of its
##             centre, smooth taper back to the ground.
## Priority: road plane > PLATFORM > BENCH > TRAIL > natural ground. Every
## operation has a world rectangle (its footprint + taper); a block is touched
## by the operations whose rectangles overlap it, so a changed operation
## rebuilds exactly the blocks of its old and new rectangles.

const Graph = preload("res://scripts/world/region/region_route_graph.gd")

enum Cover { GRASS = 0, ROAD = 1, ROUGH_ROAD = 2, TRAIL = 3 }
## Collision layers of the current bake (RegionBakeGround) per material: the
## bicycle reads grass / rough / road from these (unchanged contract).
const LAYERS: Array[int] = [4, 2, 2 | 16, 2 | 16]

var _surface: RefCounted
var _trails_surface: RefCounted
var _piece_class: Dictionary = {}
var _ops: Array = []


## `surface`: FinalSurface without trails (design). `trails`: realized
## TrailRealization records. `platforms`: [{id, centre: Vector2 (world),
## radius_m, taper_m}]. `piece_class`: road piece id -> RouteClass.
static func create(surface: RefCounted, trails: Array, platforms: Array, piece_class: Dictionary) -> Dictionary:
	var out := SurfaceOps.new()
	out._surface = surface
	out._trails_surface = surface.with_trails(trails)
	out._piece_class = piece_class
	var bounds: Dictionary = surface.get_bounds_m()
	var origin := Vector2(bounds.min_x, bounds.min_z)
	for trail: Dictionary in trails:
		var line: Dictionary = trail.line
		var reach: float = trail.half_width_m + 0.5
		out._ops.append({"kind": "TRAIL", "id": trail.id, "rect": _line_rect(line, 0, line.s.size() - 1, reach, origin)})
		for op: Dictionary in trail.get("operations", []):
			if op.kind != "BENCH":
				continue
			var k0: int = clampi(line.s.bsearch(op.s0_m) - 1, 0, line.s.size() - 1)
			var k1: int = clampi(line.s.bsearch(op.s1_m), 0, line.s.size() - 1)
			out._ops.append({"kind": "BENCH", "id": "%s/bench" % trail.id,
				"rect": _line_rect(line, k0, k1, trail.half_width_m + op.daylight_m + 0.5, origin)})
	for p: Dictionary in platforms:
		var h: Dictionary = surface.sample_surface(p.centre.x, p.centre.y)
		if not h.is_valid or h.kind == "ROAD":
			return {"is_valid": false, "reason_code": "ERR_SURFACE_PLATFORM_SITE", "detail": {"id": p.id, "kind": h.get("kind", "")}}
		var r: float = float(p.radius_m) + float(p.taper_m)
		out._ops.append({"kind": "PLATFORM", "id": p.id, "centre": p.centre, "radius_m": float(p.radius_m), "taper_m": float(p.taper_m),
			"height_m": float(h.height_m), "rect": Rect2(p.centre - Vector2(r, r), Vector2(2.0 * r, 2.0 * r))})
	return {"is_valid": true, "ops": out, "reason_code": ""}


static func _line_rect(line: Dictionary, k0: int, k1: int, reach: float, origin: Vector2) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for k in range(k0, k1 + 1):
		var p := Vector2(line.x[k], line.z[k]) + origin
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	return Rect2(lo - Vector2(reach, reach), hi - lo + Vector2(2.0 * reach, 2.0 * reach))


func operations() -> Array:
	return _ops.duplicate(true)


## Operations whose rectangles overlap `rect` (world), in list order.
func touching(rect: Rect2) -> Array:
	var out: Array = []
	for op: Dictionary in _ops:
		if op.rect.intersects(rect):
			out.append(op)
	return out


## Final height and material at a world point under the given operations
## (normally touching() of the point's block): {is_valid, height_m, material}.
func sample(x: float, z: float, ops: Array) -> Dictionary:
	var s: Dictionary = _surface.sample_surface(x, z)
	if not s.is_valid:
		return {"is_valid": false, "reason_code": s.reason_code}
	if s.kind == "ROAD":
		var rough: bool = int(_piece_class.get(s.owner, 0)) >= Graph.RouteClass.SINGLETRACK
		return {"is_valid": true, "height_m": float(s.height_m), "material": Cover.ROUGH_ROAD if rough else Cover.ROAD}
	var h: float = s.height_m
	var material: int = Cover.GRASS
	var p := Vector2(x, z)
	var on_platform: bool = false
	for op: Dictionary in ops:
		if not op.rect.has_point(p):
			continue
		match op.kind:
			"TRAIL":
				if material == Cover.GRASS and _trails_surface.trail_inside(x, z):
					material = Cover.TRAIL
			"BENCH":
				if not on_platform:
					h += _trails_surface.trail_displacement(x, z)
			"PLATFORM":
				var d: float = p.distance_to(op.centre)
				if d <= op.radius_m:
					h = op.height_m
					material = Cover.TRAIL
					on_platform = true
				elif d < op.radius_m + op.taper_m:
					var u: float = (d - op.radius_m) / op.taper_m
					h = lerpf(op.height_m, h, u * u * (3.0 - 2.0 * u))
					on_platform = true
	return {"is_valid": true, "height_m": h, "material": material}
