class_name RoadTerrainDeformer
extends RefCounted
## Pure, immutable station-quads, explicit stable ownership. Each owner
## constructs ONE height from natural ground; overlaps blend those heights.
const Policy = preload("res://scripts/world/region/road_synthesis_policy.gd")
var _segments: Array[Dictionary] = []
var _index: Dictionary = {}
var _query_index: Dictionary = {}
var _plane_index: Dictionary = {}
var _fine: Dictionary = {}
var _road_cells: Dictionary = {}
var _road_leaves: Dictionary = {}
var _cap_leaves: Dictionary = {}
var _boundary_points: Dictionary = {}
var _hydrology: RefCounted
var _errors: Array[String] = []
var _origin_x: float = 0.0
var _origin_z: float = 0.0

static func create(route: RefCounted, hydrology_field: RefCounted) -> Dictionary:
	var out := RoadTerrainDeformer.new()
	out._hydrology = hydrology_field
	var data: Dictionary = route.get_data()
	if hydrology_field == null or data.header.hydrology_signature != hydrology_field.get_plan_signature() or data.header.region_signature != hydrology_field.get_region_signature():
		return {"is_valid":false,"reason_code":"ERR_R7_SIGNATURE_MISMATCH","deformer":null}
	out._origin_x = data.header.origin_x_m
	out._origin_z = data.header.origin_z_m
	for p: Dictionary in data.pieces:
		var d: Dictionary = p.design
		var limits: Dictionary = p.intent.limits
		var st: Dictionary=p.intent.stations
		for i in range(st.s.size()):
			var k: int=d.s.bsearch(st.s[i])
			if k>=d.s.size() or d.s[k]!=st.s[i] or absf(st.y[i]-d.y[k])>0.01 or absf(st.delta_l[i]-d.fill_l[k])>0.01 or absf(st.delta_r[i]-d.fill_r[k])>0.01:
				return {"is_valid":false,"reason_code":"ERR_R7_INTENT_MISMATCH","deformer":null}
		var profile: Dictionary = out._ford_profile(d,p.intent)
		if not profile.is_valid:
			return {"is_valid":false,"reason_code":profile.reason_code,"deformer":null,"detail":profile.get("detail",{})}
		var shoulder: float = 0.75 if p.info.kind == "MOVEMENT" else limits.shoulder_m
		for k in range(d.s.size()):
			for sign: float in [-1.0,1.0]:
				var half: float=d.width[k]/2.0+shoulder
				var point := Vector2(d.x[k]-sign*half*d.tz[k],d.z[k]+sign*half*d.tx[k])
				var key := Vector2i(int(floor(point.x)),int(floor(point.y)))
				if not out._boundary_points.has(key): out._boundary_points[key]=[]
				if not point in out._boundary_points[key]: out._boundary_points[key].append(point)
		var patch: Dictionary = {}
		if p.info.kind == "MOVEMENT":
			var node: int = int(p.id.split(":")[1])
			for record: Dictionary in data.patches:
				if record.owner.node_id == node:
					patch = record.patch
		for k in range(d.s.size() - 1):
			if d.support[k] == Policy.Support.BRIDGE_DECK:
				return {"is_valid": false, "reason_code": "ERR_R7_BRIDGE_UNSUPPORTED", "deformer": null}
			var a := Vector2(d.x[k], d.z[k])
			var b := Vector2(d.x[k + 1], d.z[k + 1])
			var reach: float = maxf(d.width[k], d.width[k + 1]) / 2.0 + shoulder + limits.tie_max_m + 1.0
			var seg := {"id": p.id, "k": k, "d": d, "profile":profile,"a": a, "b": b, "n0": Vector2(-d.tz[k], d.tx[k]), "n1": Vector2(-d.tz[k + 1], d.tx[k + 1]), "shoulder": shoulder, "limits": limits, "patch": patch, "reach": reach, "first": k == 0, "last": k == d.s.size() - 2}
			var index: int = out._segments.size()
			out._segments.append(seg)
			var query_bounds: Rect2=_quad_bounds(a,b,seg.n0,seg.n1,reach,seg.first or seg.last)
			for j in range(int(floor(query_bounds.position.y/4)),int(floor(query_bounds.end.y/4))+1):
				for i in range(int(floor(query_bounds.position.x/4)),int(floor(query_bounds.end.x/4))+1):
					var key:=Vector2i(i,j)
					if not out._query_index.has(key): out._query_index[key]=[]
					out._query_index[key].append(index)
			var road_reach: float = maxf(d.width[k],d.width[k+1])/2.0+shoulder+1.0
			var plane_reach: float=maxf(d.width[k],d.width[k+1])/2.0+shoulder+0.001
			var plane_bounds: Rect2=_quad_bounds(a,b,seg.n0,seg.n1,plane_reach,false)
			for j in range(int(floor(plane_bounds.position.y/4)),int(floor(plane_bounds.end.y/4))+1):
				for i in range(int(floor(plane_bounds.position.x/4)),int(floor(plane_bounds.end.x/4))+1):
					var key:=Vector2i(i,j)
					if not out._plane_index.has(key): out._plane_index[key]=[]
					out._plane_index[key].append(index)
			for j in range(int(floor(minf(a.y,b.y)-road_reach)),int(floor(maxf(a.y,b.y)+road_reach))+1):
				for i in range(int(floor(minf(a.x,b.x)-road_reach)),int(floor(maxf(a.x,b.x)+road_reach))+1):
					out._road_leaves[Vector2i(i,j)] = true
			for j in range(int(floor((minf(a.y,b.y)-road_reach)/16.0)),int(floor((maxf(a.y,b.y)+road_reach)/16.0))+1):
				for i in range(int(floor((minf(a.x,b.x)-road_reach)/16.0)),int(floor((maxf(a.x,b.x)+road_reach)/16.0))+1):
					out._road_cells[Vector2i(i,j)]=true
			for j in range(int(floor((minf(a.y, b.y) - reach - 2.0) / 16.0)), int(floor((maxf(a.y, b.y) + reach + 2.0) / 16.0)) + 1):
				for i in range(int(floor((minf(a.x, b.x) - reach - 2.0) / 16.0)), int(floor((maxf(a.x, b.x) + reach + 2.0) / 16.0)) + 1):
					var cell := Vector2i(i, j)
					if not out._index.has(cell):
						out._index[cell] = []
					out._index[cell].append(index)
			# Refine the actual station-quad footprint, including radial end
			# caps and the approved 2 m guard. The broad search reference above
			# stays intact; an axis-aligned radius around every segment wasted
			# fine terrain cells along the longitudinal direction.
			var fine_bounds: Rect2=query_bounds.grow(2.0)
			for j in range(int(floor(fine_bounds.position.y/16)),int(floor(fine_bounds.end.y/16))+1):
				for i in range(int(floor(fine_bounds.position.x/16)),int(floor(fine_bounds.end.x/16))+1):
					out._fine[Vector2i(i,j)]=true
	for piece_index: int in [0,data.pieces.size()-1]:
		var d: Dictionary=data.pieces[piece_index].design
		var k: int=0 if piece_index==0 else d.s.size()-1
		var half: float=d.width[k]/2.0+0.75
		for j in range(int(floor(d.z[k]-half-1)),int(floor(d.z[k]+half+1))+1):
			for i in range(int(floor(d.x[k]-half-1)),int(floor(d.x[k]+half+1))+1):
				var longitudinal: float=absf((i+0.5-d.x[k])*d.tx[k]+(j+0.5-d.z[k])*d.tz[k])
				if longitudinal<1.5: out._cap_leaves[Vector2i(i,j)]=true
	print("R7_FINE_CELLS ",out._fine.size()," segments=",out._segments.size())
	return {"is_valid": true, "reason_code": "", "deformer": out}

func fine_cells() -> Dictionary:
	return _fine.duplicate()

static func _quad_bounds(a: Vector2,b: Vector2,n0: Vector2,n1: Vector2,reach: float,caps: bool) -> Rect2:
	if caps:
		return Rect2(Vector2(minf(a.x,b.x)-reach,minf(a.y,b.y)-reach),Vector2(absf(b.x-a.x)+2*reach,absf(b.y-a.y)+2*reach)).grow(0.01)
	var points: Array[Vector2]=[a-n0*reach,a+n0*reach,b-n1*reach,b+n1*reach]
	var bounds:=Rect2(points[0],Vector2.ZERO)
	for point: Vector2 in points: bounds=bounds.expand(point)
	# All station-quad coordinates are affine in each parameter. Their
	# extrema occur at corners; a centimetre covers float32 index rounding.
	return bounds.grow(0.01)

func diagnostics() -> Array[String]:
	return _errors.duplicate()

func _owns_road_point(lx: float,lz: float) -> bool:
	var cell := Vector2i(int(floor(lx/4)),int(floor(lz/4)))
	var candidates: Variant=_plane_index.get(cell)
	if candidates==null: return false
	var point := Vector2(lx,lz)
	for index: int in candidates:
		# Plane ownership depends only on the station quad. The natural-height
		# argument affects earthwork outside that plane and is unused here.
		var candidate: Dictionary = _candidate(_segments[index],point,0.0,true)
		if candidate.get("plane",false):
			return true
	return false

static func _error(reason: String) -> Dictionary:
	return {"is_valid": false, "reason_code": reason, "height_m": NAN, "kind": "INVALID", "owner": "", "lateral": INF, "half_width": 0.0}

## Invert the bilinear station quad: p = lerp(a,b,u)+t*lerp(n0,n1,u).
## End caps are radial extensions, with no plane ownership past the port.
func _candidate(seg: Dictionary, point: Vector2, h: float, ownership_only: bool=false) -> Dictionary:
	var rough_ab: Vector2=seg.b-seg.a
	var rough_u: float=(point-seg.a).dot(rough_ab)/rough_ab.length_squared()
	var rough_allowance: float=maxf(absf(seg.n0.dot(rough_ab)),absf(seg.n1.dot(rough_ab)))*seg.reach/rough_ab.length_squared()+0.002
	if (rough_u < -rough_allowance and not seg.first) or (rough_u>1.0+rough_allowance and not seg.last):
		return {}
	var d: Dictionary = seg.d
	var k: int = seg.k
	var ax: float=d.x[k]
	var az: float=d.z[k]
	var dx: float=d.x[k+1]-ax
	var dz: float=d.z[k+1]-az
	var nx0: float=-d.tz[k]
	var nz0: float=d.tx[k]
	var nx1: float=-d.tz[k+1]
	var nz1: float=d.tx[k+1]
	var squared: float=dx*dx+dz*dz
	var chord: float=sqrt(squared)
	var rx: float=point.x-ax
	var rz: float=point.y-az
	var u: float=(rx*dx+rz*dz)/squared
	# Conservative longitudinal bound of the bilinear quad. This rejects
	# unrelated station segments before inversion, without changing heights.
	var allowance: float=maxf(absf(nx0*dx+nz0*dz),absf(nx1*dx+nz1*dz))*seg.reach/squared+0.001
	if (u < -allowance and not seg.first) or (u > 1.0+allowance and not seg.last):
		return {}
	var t: float=(rx-dx*u)*nx0+(rz-dz*u)*nz0
	for iteration in range(4):
		var nx: float=lerpf(nx0,nx1,u)
		var nz: float=lerpf(nz0,nz1,u)
		var dux: float=dx+t*(nx1-nx0)
		var duz: float=dz+t*(nz1-nz0)
		var residual_x: float=ax+dx*u+nx*t-point.x
		var residual_z: float=az+dz*u+nz*t-point.y
		var determinant: float=dux*nz-duz*nx
		if absf(determinant) < 1e-8:
			return {}
		u -= (residual_x*nz-residual_z*nx)/determinant
		t -= (dux*residual_z-duz*residual_x)/determinant
	var outside: float = 0.0
	# Float32 Vector2 inversion has a sub-mm endpoint error at region scale.
	# Adjacent closed quads share the same endpoint, with explicit tolerance.
	if u >= -0.001/chord and u <= 1.0+0.001/chord:
		u = clampf(u,0.0,1.0)
	if u < 0.0 or u > 1.0:
		if not ((u < 0.0 and seg.first) or (u > 1.0 and seg.last)):
			return {}
		u = clampf(u, 0.0, 1.0)
		var nx: float=lerpf(nx0,nx1,u)
		var nz: float=lerpf(nz0,nz1,u)
		var norm: float=sqrt(nx*nx+nz*nz)
		# True endpoint-frame distance makes the cap radial. Extrapolated
		# station u is not a physical distance when its normals turn.
		outside=absf(((point.x-ax-dx*u)*nz-(point.y-az-dz*u)*nx)/norm)
		t=((point.x-ax-dx*u)*nx+(point.y-az-dz*u)*nz)/norm
	var width: float = lerpf(d.width[k], d.width[k + 1], u) / 2.0
	var half: float = width + seg.shoulder
	var distance: float = Vector2(maxf(absf(t) - half - 0.0005, 0.0), outside).length()
	if distance >= seg.limits.tie_max_m + 1.0:
		return {}
	if ownership_only:
		return {"plane":distance==0.0}
	var length: float = d.s[k + 1] - d.s[k]
	var y: float = (2*u*u*u - 3*u*u + 1)*d.y[k] + (u*u*u - 2*u*u + u)*length*d.grade[k] + (-2*u*u*u + 3*u*u)*d.y[k + 1] + (u*u*u - u*u)*length*d.grade[k + 1]
	y -= _profile_delta(seg.profile,d.s[k]+u*length)
	var bank: float = tan(deg_to_rad(lerpf(d.bank[k], d.bank[k + 1], u)))
	var edge: float = y - clampf(t, -half, half) * bank
	if not seg.patch.is_empty():
		var patch: Dictionary = seg.patch
		var plane: float = patch.y0 + patch.gx * (point.x - patch.centre_x) + patch.gz * (point.y - patch.centre_z)
		if distance == 0.0 and absf(plane - (y - t*bank)) > 0.01:
			return _error("ERR_R7_PATCH_MISMATCH")
		edge = plane if distance == 0.0 else edge
	var target: float = clampf(h, edge - 0.5 * distance, edge + distance)
	var active: bool = distance == 0.0
	var influence: float = maxf(0.0, 1.0 - distance / (seg.limits.tie_max_m + 1.0))
	if distance > seg.limits.tie_max_m and absf(target - h) > 0.001:
		return _error("ERR_R7_TIE_UNRESOLVED")
	return {"is_valid": true, "height_m": target, "lower":edge-0.5*distance,"upper":edge+distance,"plane": active, "road": active and absf(t) <= half, "owner": seg.id, "lateral": t, "half_width": width, "weight": influence * influence, "limits": seg.limits}

func evaluate(lx: float, lz: float, h: float) -> Dictionary:
	var point := Vector2(lx, lz)
	var cell := Vector2i(int(floor(lx/16.0)), int(floor(lz/16.0)))
	var owners: Dictionary = {}
	var candidates: Array=_index.get(cell,[]) if _query_index.is_empty() else _query_index.get(Vector2i(int(floor(lx/4)),int(floor(lz/4))),[])
	for index: int in candidates:
		var c: Dictionary = _candidate(_segments[index], point, h)
		if c.is_empty():
			continue
		if not c.is_valid:
			return c
		if not owners.has(c.owner) or c.weight > owners[c.owner].weight:
			owners[c.owner] = c
	var keys: Array = owners.keys()
	keys.sort()
	var plane: Dictionary = {}
	var sum: float = 0.0
	var weights: float = 0.0
	var lower: float=-INF
	var upper: float=INF
	var natural_unchanged:=true
	for id: String in keys:
		var c: Dictionary = owners[id]
		natural_unchanged=natural_unchanged and c.height_m==h
		lower=maxf(lower,c.lower)
		upper=minf(upper,c.upper)
		if c.plane:
			if not plane.is_empty() and absf(plane.height_m - c.height_m) > 0.001:
				return _error("ERR_R7_OWNER_CONFLICT")
			if plane.is_empty() or (id.begins_with("move:") and not plane.owner.begins_with("move:")):
				plane = c
		sum += c.weight * c.height_m
		weights += c.weight
	if lower>upper+0.001:
		return _error("ERR_R7_OWNER_CONFLICT")
	var height: float = h if weights == 0.0 or natural_unchanged else sum / weights
	# Ownership and weights choose the authority. Bounds only constrain that
	# choice; mutually inconsistent construction requests reject explicitly.
	if lower<=upper:
		height=clampf(height,lower,upper)
	if not plane.is_empty():
		height = plane.height_m
	for id: String in keys:
		var c: Dictionary=owners[id]
		if height-h>c.limits.fill_max_m+0.001 or h-height>c.limits.cut_max_m+0.001:
			return _error("ERR_R7_INTENT_MISMATCH")
	var water: Dictionary = _hydrology.sample_water(lx+_origin_x, lz+_origin_z) if _hydrology != null and not owners.is_empty() else {"is_water": false}
	if water.is_water and absf(height - h) > 0.000001:
		# Wet earthwork meets the plane continuously, daylighting to unchanged
		# channel terrain. Dressing cannot fill >10 cm or close the water gap;
		# the riding plane additionally obeys the ford depth/clearance bounds.
		if height > h + 0.10 + 0.001 or height>=water.water_surface_m or (not plane.is_empty() and (water.water_surface_m-height>=Policy.FORD_MAX_DEPTH_M or water.water_surface_m-height<0.02)):
			var error: Dictionary = _error("ERR_R7_FORD_CHANNEL")
			error["target"] = height
			error["natural"] = h
			error["water"] = water.water_surface_m
			error["owner"] = plane.get("owner","earthwork")
			return error
	return {"is_valid": true, "reason_code": "", "height_m": height, "kind": "ROAD" if not plane.is_empty() else "TERRAIN", "owner": plane.get("owner", ""), "lateral": plane.get("lateral", INF), "half_width": plane.get("half_width", 0.0),"_wet":water.is_water}

## Approved R7-F1: bounded vertical realization, retaining all R6 data.
## A scalar crown profile is constrained by the ENTIRE wet cross-section,
## exact depth/bed-fill limits and class grade/grade-change bounds. Cubic
## B-spline correction provides continuous derivatives and zero far effect.
func _ford_profile(d: Dictionary, intent: Dictionary) -> Dictionary:
	if intent.crossings.is_empty():
		return {"is_valid":true,"reason_code":"","delta":PackedFloat64Array(),"step":0.5}
	var step: float = 0.5
	var count: int = int(ceil(d.s[-1]/step))+1
	var original := PackedFloat64Array()
	var values := PackedFloat64Array()
	var lower := PackedFloat64Array()
	var upper := PackedFloat64Array()
	for i in range(count):
		var s: float = minf(d.s[-1],i*step)
		var k: int = clampi(d.s.bsearch(s)-1,0,d.s.size()-2)
		var length: float = d.s[k+1]-d.s[k]
		var u: float = (s-d.s[k])/length
		var y: float = (2*u*u*u-3*u*u+1)*d.y[k]+(u*u*u-2*u*u+u)*length*d.grade[k]+(-2*u*u*u+3*u*u)*d.y[k+1]+(u*u*u-u*u)*length*d.grade[k+1]
		var x: float = lerpf(d.x[k],d.x[k+1],u)
		var z: float = lerpf(d.z[k],d.z[k+1],u)
		var tx: float = lerpf(d.tx[k],d.tx[k+1],u)
		var tz: float = lerpf(d.tz[k],d.tz[k+1],u)
		var bank: float = tan(deg_to_rad(lerpf(d.bank[k],d.bank[k+1],u)))
		var half: float = lerpf(d.width[k],d.width[k+1],u)/2.0+intent.limits.shoulder_m
		var in_window := false
		for ref: Dictionary in intent.crossings:
			if s>=ref.wet_s0-35.0 and s<=ref.wet_s1+35.0:
				in_window=true
		var lo: float = y-0.35 if in_window else y
		var hi: float = y
		if in_window:
			var lateral_count: int = int(ceil(2.0*half/0.25))
			for t_index in range(lateral_count+1):
				var lateral: float = -half+2.0*half*t_index/lateral_count
				var water: Dictionary = _hydrology.sample_water(_origin_x+x-tz*lateral,_origin_z+z+tx*lateral)
				if water.is_water:
					var h: float = water.water_surface_m-water.depth_m
					lo = maxf(lo,water.water_surface_m-0.34+lateral*bank)
					hi = minf(hi,minf(h+0.08,water.water_surface_m-0.035)+lateral*bank)
		if lo>hi:
			return {"is_valid":false,"reason_code":"ERR_R7_FORD_CHANNEL","detail":{"s":s,"lower":lo,"upper":hi,"stage":"cross-section feasibility"}}
		original.append(y)
		values.append(hi)
		lower.append(lo)
		upper.append(hi)
	# Project onto the bounded crown, maximum grade and change of grade.
	# Fixed order/count makes the result deterministic; nonconvergence rejects.
	var grade_step: float = 0.086*step
	var bend: float = 0.017*step*step
	for iteration in range(10000):
		for i in range(count-1):
			var diff: float = values[i+1]-values[i]
			var excess: float = diff-clampf(diff,-grade_step,grade_step)
			values[i] += excess/2.0
			values[i+1] -= excess/2.0
		for i in range(1,count-1):
			var diff: float = values[i-1]-2.0*values[i]+values[i+1]
			var excess: float = diff-clampf(diff,-bend,bend)
			values[i-1] -= excess/6.0
			values[i] += excess/3.0
			values[i+1] -= excess/6.0
		for i in range(count):
			values[i] = clampf(values[i],lower[i],upper[i])
	var max_grade: float = 0.0
	var max_bend: float = 0.0
	for i in range(1,count):
		max_grade = maxf(max_grade,absf(values[i]-values[i-1])/step)
		if i<count-1:
			max_bend=maxf(max_bend,absf(values[i-1]-2*values[i]+values[i+1])/(step*step))
	# Conservative projection targets leave room for interpolation. Acceptance
	# below uses the actual retained class bounds, not solver residual alone.
	if max_grade>tan(deg_to_rad(5.0)) or max_bend>deg_to_rad(1.2):
		return {"is_valid":false,"reason_code":"ERR_R7_FORD_CHANNEL","detail":{"stage":"bounded profile convergence","max_grade":max_grade,"max_grade_change":max_bend}}
	var delta := PackedFloat64Array()
	var max_drop: float = 0.0
	for i in range(count):
		delta.append(original[i]-values[i])
		max_drop = maxf(max_drop,delta[i])
	print("R7_FORD_PROFILE controls=",count," max_grade=",max_grade," max_grade_change=",max_bend," max_drop=",max_drop)
	var profile := {"is_valid":true,"reason_code":"","delta":delta,"step":step}
	var maximum_grade: float = 0.0
	var maximum_change: float = 0.0
	for i in range(int(ceil(d.s[-1]/0.125))+1):
		var s: float = minf(d.s[-1],i*0.125)
		var k: int = clampi(d.s.bsearch(s)-1,0,d.s.size()-2)
		var length: float = d.s[k+1]-d.s[k]
		var u: float = (s-d.s[k])/length
		var grade: float = ((6*u*u-6*u)*d.y[k]+(-6*u*u+6*u)*d.y[k+1])/length+(3*u*u-4*u+1)*d.grade[k]+(3*u*u-2*u)*d.grade[k+1]
		var curvature: float = ((12*u-6)*d.y[k]+(-12*u+6)*d.y[k+1])/(length*length)+(6*u-4)*d.grade[k]/length+(6*u-2)*d.grade[k+1]/length
		grade -= _profile_derivative(profile,s,1)
		curvature -= _profile_derivative(profile,s,2)
		maximum_grade = maxf(maximum_grade,absf(rad_to_deg(atan(grade))))
		maximum_change = maxf(maximum_change,absf(rad_to_deg(curvature/(1+grade*grade))))
	if maximum_grade>5.0+0.00001 or maximum_change>1.2+0.00001:
		return {"is_valid":false,"reason_code":"ERR_R7_FORD_CHANNEL","detail":{"stage":"exact interpolant grade","grade_deg":maximum_grade,"grade_change_deg_per_m":maximum_change}}
	print("R7_FORD_INTERPOLANT grade_deg=",maximum_grade," grade_change_deg_per_m=",maximum_change)
	return profile

static func _profile_delta(profile: Dictionary, s: float) -> float:
	var controls: PackedFloat64Array = profile.delta
	if controls.is_empty():
		return 0.0
	var q: float = s/profile.step
	var i: int = int(floor(q))
	var u: float = q-i
	var weights: Array[float] = [(1-u)*(1-u)*(1-u)/6.0,(3*u*u*u-6*u*u+4)/6.0,(-3*u*u*u+3*u*u+3*u+1)/6.0,u*u*u/6.0]
	var value: float = 0.0
	for k in range(4):
		value += weights[k]*controls[clampi(i+k-1,0,controls.size()-1)]
	return value

static func _profile_derivative(profile: Dictionary,s: float,order: int) -> float:
	var controls: PackedFloat64Array = profile.delta
	var q: float = s/profile.step
	var i: int = int(floor(q))
	var u: float = q-i
	var weights: PackedFloat64Array = PackedFloat64Array([-0.5*(1-u)*(1-u),1.5*u*u-2*u,-1.5*u*u+u+0.5,0.5*u*u]) if order==1 else PackedFloat64Array([1-u,3*u-2,1-3*u,u])
	var value: float = 0.0
	for k in range(4):
		value += weights[k]*controls[clampi(i+k-1,0,controls.size()-1)]
	return value/pow(profile.step,order)
