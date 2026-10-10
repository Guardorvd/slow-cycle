class_name RoadCorridorGeometry
extends RefCounted

## R6 corridor geometry and precision boundary (ExecPlan §§4-5).
##
## Band: the R6 interpretation of an R5 RouteCorridor band. Region-local
## stations (world - int64 origin, subtracted in scalar float64), linearly
## interpolated asymmetric half-widths per segment with the R5 builder's left
## normal (-dz, +dx), and round caps of each side's half-width at interior
## station corners. Membership keeps longitudinal segment identity: queries
## carry a segment hint and search a bounded window, so a point never jumps to
## a distant loop segment. Clearance is the signed distance (m) inside.
##
## Natural: the only place R6 adds the region origin back for field queries.
## Exact queries go to the public R3/R4 fields; a lazily filled, world-anchored
## 8 m height lattice and the R4 16 m cost lattice serve candidate search
## only (final geometry is certified with exact queries). Water geometry for
## search comes from HydrologyPlan public channel / body records. Every field
## call is counted against the natural-query budget.

const Policy = preload("res://scripts/world/region/road_synthesis_policy.gd")
const RMath = preload("res://scripts/world/region/regional_road_math.gd")
const DOMAIN_M: float = 4096.0


class Band extends RefCounted:
	var xs := PackedFloat64Array()
	var zs := PackedFloat64Array()
	var hl := PackedFloat64Array()
	var hr := PackedFloat64Array()
	var dx := PackedFloat64Array()   # per segment unit direction
	var dz := PackedFloat64Array()
	var seg_len := PackedFloat64Array()
	var u := PackedFloat64Array()    # cumulative arc length per station
	var jnx := PackedFloat64Array()  # join bisector of left normals per station
	var jnz := PackedFloat64Array()
	var edge_id: int = -1

	func count() -> int:
		return xs.size()

	func length() -> float:
		return u[u.size() - 1]

	## Station arrays in region-local metres (from the corridor view; float64).
	static func from_corridor(corridor: Dictionary, origin_x: float, origin_z: float) -> Band:
		var band := Band.new()
		band.edge_id = corridor.edge_id
		for k in range(corridor.station_count):
			band.xs.append(corridor.x_m[k] - origin_x)
			band.zs.append(corridor.z_m[k] - origin_z)
			band.hl.append(corridor.half_left_m[k])
			band.hr.append(corridor.half_right_m[k])
		band._prepare()
		return band

	func _prepare() -> void:
		var n: int = xs.size()
		u.resize(n)
		u[0] = 0.0
		for k in range(n - 1):
			var ex: float = xs[k + 1] - xs[k]
			var ez: float = zs[k + 1] - zs[k]
			var length_k: float = sqrt(ex * ex + ez * ez)
			seg_len.append(length_k)
			dx.append(ex / length_k)
			dz.append(ez / length_k)
			u[k + 1] = u[k] + length_k
		for k in range(n):
			var ax: float = 0.0
			var az: float = 0.0
			if k > 0:
				ax += -dz[k - 1]
				az += dx[k - 1]
			if k < n - 1:
				ax += -dz[k]
				az += dx[k]
			var m: float = sqrt(ax * ax + az * az)
			jnx.append(ax / m if m > 1e-12 else 0.0)
			jnz.append(az / m if m > 1e-12 else 0.0)

	## [clearance_m, best segment, t, lateral_m]; clearance < 0 outside. The
	## window covers segments hint-window .. hint+window (hint < 0: all).
	func clearance(px: float, pz: float, hint: int = -1, window: int = 6) -> PackedFloat64Array:
		var n: int = xs.size()
		var lo: int = 0
		var hi: int = n - 2
		if hint >= 0:
			lo = maxi(0, hint - window)
			hi = mini(n - 2, hint + window)
		var best: float = -INF
		var best_seg: int = clampi(hint, 0, n - 2)
		var best_t: float = 0.0
		var best_lat: float = 0.0
		for k in range(lo, hi + 1):
			var rx: float = px - xs[k]
			var rz: float = pz - zs[k]
			var t: float = (rx * dx[k] + rz * dz[k]) / seg_len[k]
			var lat: float = -rx * dz[k] + rz * dx[k]
			if t >= 0.0 and t <= 1.0:
				var left: float = hl[k] + t * (hl[k + 1] - hl[k])
				var right: float = hr[k] + t * (hr[k + 1] - hr[k])
				var margin: float = minf(left - lat, lat + right)
				if margin > best:
					best = margin
					best_seg = k
					best_t = t
					best_lat = lat
		# Round caps at interior station corners (both neighbours in window).
		for k in range(maxi(lo, 1), mini(hi, n - 2) + 1):
			var rx: float = px - xs[k]
			var rz: float = pz - zs[k]
			var rho: float = sqrt(rx * rx + rz * rz)
			var side: float = rx * jnx[k] + rz * jnz[k]
			var margin: float = (hl[k] if side >= 0.0 else hr[k]) - rho
			if margin > best:
				best = margin
				best_seg = k
				best_t = 0.0
				best_lat = side
		return PackedFloat64Array([best, best_seg, best_t, best_lat])

	## Point and left normal on the reference at arc length s (clamped).
	func at_u(s: float) -> PackedFloat64Array:
		var n: int = xs.size()
		var target: float = clampf(s, 0.0, u[n - 1])
		var k: int = clampi(u.bsearch(target) - 1, 0, n - 2)
		var t: float = (target - u[k]) / seg_len[k]
		return PackedFloat64Array([xs[k] + t * (xs[k + 1] - xs[k]), zs[k] + t * (zs[k + 1] - zs[k]), -dz[k], dx[k], k])

	## Arc-length coordinate of the projection of a point (hinted window).
	func project_u(px: float, pz: float, hint: int = -1, window: int = 6) -> float:
		var n: int = xs.size()
		var lo: int = 0
		var hi: int = n - 2
		if hint >= 0:
			lo = maxi(0, hint - window)
			hi = mini(n - 2, hint + window)
		var best_d: float = INF
		var best_u: float = 0.0
		for k in range(lo, hi + 1):
			var t: float = clampf(((px - xs[k]) * dx[k] + (pz - zs[k]) * dz[k]) / seg_len[k], 0.0, 1.0)
			var qx: float = xs[k] + t * (xs[k + 1] - xs[k])
			var qz: float = zs[k] + t * (zs[k + 1] - zs[k])
			var d: float = (px - qx) * (px - qx) + (pz - qz) * (pz - qz)
			if d < best_d:
				best_d = d
				best_u = u[k] + t * seg_len[k]
		return best_u

	## Smoothed lattice axis between reference arc lengths u0 < u1 with station
	## spacing du: {x, z, nx, nz, u (reference arc), radius} as float64 arrays.
	## The axis is a search parameterisation only; membership is always tested
	## against this band.
	func axis(u0: float, u1: float, du: float, sx: float, sz: float, ex: float, ez: float, start_dir: Vector2 = Vector2.ZERO, end_dir: Vector2 = Vector2.ZERO) -> Dictionary:
		var fine := 4.0
		var count: int = maxi(2, ceili((u1 - u0) / fine))
		var px := PackedFloat64Array()
		var pz := PackedFloat64Array()
		var w := PackedFloat64Array()
		for i in range(count + 1):
			var p: PackedFloat64Array = at_u(u0 + (u1 - u0) * i / count)
			px.append(p[0])
			pz.append(p[1])
			w.append(1.0)
		px[0] = sx
		pz[0] = sz
		px[count] = ex
		pz[count] = ez
		w[0] = 1e9
		w[count] = 1e9
		# Optional port headings: the axis leaves / arrives along them, so the
		# lattice's first and last normals are perpendicular to the ports.
		if start_dir != Vector2.ZERO and count > 4:
			px[1] = sx + start_dir.x * fine
			pz[1] = sz + start_dir.y * fine
			w[1] = 1e9
		if end_dir != Vector2.ZERO and count > 4:
			px[count - 1] = ex - end_dir.x * fine
			pz[count - 1] = ez - end_dir.y * fine
			w[count - 1] = 1e9
		var lam := PackedFloat64Array()
		lam.resize(px.size())
		lam.fill(pow(24.0 / fine, 4.0))
		var fx: PackedFloat64Array = RMath.fair(px, w, lam)
		var fz: PackedFloat64Array = RMath.fair(pz, w, lam)
		var arc := PackedFloat64Array([0.0])
		for i in range(1, fx.size()):
			arc.append(arc[i - 1] + sqrt((fx[i] - fx[i - 1]) ** 2 + (fz[i] - fz[i - 1]) ** 2))
		var total: float = arc[arc.size() - 1]
		var stations: int = maxi(2, roundi(total / du))
		var result := {"x": PackedFloat64Array(), "z": PackedFloat64Array(), "nx": PackedFloat64Array(), "nz": PackedFloat64Array(), "radius": PackedFloat64Array(), "length": total}
		var j: int = 0
		for i in range(stations + 1):
			var target: float = total * i / stations
			while j < arc.size() - 2 and arc[j + 1] < target:
				j += 1
			var t: float = (target - arc[j]) / maxf(arc[j + 1] - arc[j], 1e-12)
			result.x.append(fx[j] + t * (fx[j + 1] - fx[j]))
			result.z.append(fz[j] + t * (fz[j + 1] - fz[j]))
		result.x[0] = sx
		result.z[0] = sz
		result.x[stations] = ex
		result.z[stations] = ez
		for i in range(stations + 1):
			var a: int = maxi(i - 1, 0)
			var b: int = mini(i + 1, stations)
			var tx: float = result.x[b] - result.x[a]
			var tz: float = result.z[b] - result.z[a]
			var m: float = sqrt(tx * tx + tz * tz)
			result.nx.append(-tz / m)
			result.nz.append(tx / m)
			var k: float = 0.0
			if i > 0 and i < stations:
				k = RMath.three_point_curvature(result.x[i - 1], result.z[i - 1], result.x[i], result.z[i], result.x[i + 1], result.z[i + 1])
			result.radius.append(1.0 / absf(k) if absf(k) > 1e-9 else INF)
		return result


## Counted natural queries over the pre-road world (R3 HydrologySurface for
## height, R4 RideabilityField, R3 HydrologyField / HydrologyPlan for water).
class Natural extends RefCounted:
	var surface: RefCounted
	var rideability: RefCounted
	var hydro_field: RefCounted
	var origin_x: float = 0.0
	var origin_z: float = 0.0
	var queries: int = 0
	var ride_queries: int = 0
	var budget: int = Policy.MAX_NATURAL_QUERIES
	var _grid := PackedFloat64Array()
	var _grid_n: int = 0
	var _ride_cost := PackedFloat64Array()
	var _ride_flags := PackedInt32Array()
	var _ride_n: int = 0
	# Channel search segments (local m): ax, az, bx, bz, half_a, half_b, id, class, surface_a, surface_b
	var _seg := PackedFloat64Array()
	var _buckets: Array = []
	var _body_of := PackedInt32Array()
	var _channel_ends: Dictionary = {}
	const SEG_STRIDE: int = 10
	const BUCKET_M: float = 64.0
	const BUCKETS: int = 65

	static func create(surface_: RefCounted, rideability_: RefCounted, hydro_field_: RefCounted, hydrology_plan: RefCounted, origin_x_: float, origin_z_: float, budget_: int) -> Natural:
		var natural := Natural.new()
		natural.surface = surface_
		natural.rideability = rideability_
		natural.hydro_field = hydro_field_
		natural.origin_x = origin_x_
		natural.origin_z = origin_z_
		natural.budget = budget_
		natural._grid_n = int(DOMAIN_M / Policy.SEARCH_GRID_M) + 1
		natural._grid.resize(natural._grid_n * natural._grid_n)
		natural._grid.fill(NAN)
		natural._ride_n = int(DOMAIN_M / 16.0) + 1
		natural._ride_cost.resize(natural._ride_n * natural._ride_n)
		natural._ride_cost.fill(NAN)
		natural._ride_flags.resize(natural._ride_n * natural._ride_n)
		for cell in range(BUCKETS * BUCKETS):
			natural._buckets.append(PackedInt32Array())
		for c in range(hydrology_plan.get_channel_count()):
			var channel: Dictionary = hydrology_plan.get_channel(c)
			var last: int = channel.x_cm.size() - 1
			natural._channel_ends[channel.id] = PackedFloat64Array([channel.x_cm[0] / 100.0, channel.z_cm[0] / 100.0, channel.x_cm[1] / 100.0, channel.z_cm[1] / 100.0,
				channel.x_cm[last] / 100.0, channel.z_cm[last] / 100.0, channel.x_cm[last - 1] / 100.0, channel.z_cm[last - 1] / 100.0])
			for k in range(channel.x_cm.size() - 1):
				var s: int = natural._seg.size() / SEG_STRIDE
				natural._seg.append_array([channel.x_cm[k] / 100.0, channel.z_cm[k] / 100.0, channel.x_cm[k + 1] / 100.0, channel.z_cm[k + 1] / 100.0,
					channel.width_cm[k] / 200.0, channel.width_cm[k + 1] / 200.0, channel.id, channel.class, channel.surface_cm[k] / 100.0, channel.surface_cm[k + 1] / 100.0])
				var reach: float = maxf(channel.width_cm[k], channel.width_cm[k + 1]) / 200.0 + 8.0
				var i0: int = clampi(floori((minf(channel.x_cm[k], channel.x_cm[k + 1]) / 100.0 - reach) / BUCKET_M), 0, BUCKETS - 1)
				var i1: int = clampi(floori((maxf(channel.x_cm[k], channel.x_cm[k + 1]) / 100.0 + reach) / BUCKET_M), 0, BUCKETS - 1)
				var j0: int = clampi(floori((minf(channel.z_cm[k], channel.z_cm[k + 1]) / 100.0 - reach) / BUCKET_M), 0, BUCKETS - 1)
				var j1: int = clampi(floori((maxf(channel.z_cm[k], channel.z_cm[k + 1]) / 100.0 + reach) / BUCKET_M), 0, BUCKETS - 1)
				for j in range(j0, j1 + 1):
					for i in range(i0, i1 + 1):
						natural._buckets[j * BUCKETS + i].append(s)
		natural._body_of.resize(129 * 129)
		natural._body_of.fill(-1)
		for b in range(hydrology_plan.get_body_count()):
			var body: Dictionary = hydrology_plan.get_body(b)
			for cell: int in body.cells:
				natural._body_of[cell] = body.id
		return natural

	func exhausted() -> bool:
		return queries > budget

	static func in_domain(lx: float, lz: float) -> bool:
		return is_finite(lx) and is_finite(lz) and lx >= 0.0 and lz >= 0.0 and lx <= DOMAIN_M and lz <= DOMAIN_M

	## Exact natural (pre-road) surface height; NAN outside the region.
	func height(lx: float, lz: float) -> float:
		queries += 1
		var r: Dictionary = surface.sample_height(origin_x + lx, origin_z + lz)
		return r.height_m if r.is_valid else NAN

	func _grid_at(i: int, j: int) -> float:
		var k: int = j * _grid_n + i
		var h: float = _grid[k]
		if is_nan(h):
			h = height(i * Policy.SEARCH_GRID_M, j * Policy.SEARCH_GRID_M)
			_grid[k] = h
		return h

	## Search-grid height (bilinear on the world-anchored 8 m lattice).
	func height_search(lx: float, lz: float) -> float:
		var gx: float = clampf(lx, 0.0, DOMAIN_M) / Policy.SEARCH_GRID_M
		var gz: float = clampf(lz, 0.0, DOMAIN_M) / Policy.SEARCH_GRID_M
		var i: int = mini(floori(gx), _grid_n - 2)
		var j: int = mini(floori(gz), _grid_n - 2)
		var fx: float = gx - i
		var fz: float = gz - j
		var h00: float = _grid_at(i, j)
		var h10: float = _grid_at(i + 1, j)
		var h01: float = _grid_at(i, j + 1)
		var h11: float = _grid_at(i + 1, j + 1)
		return (h00 * (1.0 - fx) + h10 * fx) * (1.0 - fz) + (h01 * (1.0 - fx) + h11 * fx) * fz

	## Search-grid gradient (central difference over +-4 m on the search grid).
	func gradient_search(lx: float, lz: float) -> Vector2:
		var e: float = 4.0
		return Vector2((height_search(lx + e, lz) - height_search(lx - e, lz)) / (2.0 * e), (height_search(lx, lz + e) - height_search(lx, lz - e)) / (2.0 * e))

	func _ride_at(i: int, j: int) -> int:
		var k: int = j * _ride_n + i
		if is_nan(_ride_cost[k]):
			ride_queries += 1
			queries += 5
			var r: Dictionary = rideability.sample(origin_x + i * 16.0, origin_z + j * 16.0)
			_ride_cost[k] = r.cost if r.is_valid else 16.0
			_ride_flags[k] = r.reason_flags if r.is_valid else 0
		return k

	## R4 traversal cost bilinear on its 16 m lattice (search only).
	func ride_cost_search(lx: float, lz: float) -> float:
		var gx: float = clampf(lx, 0.0, DOMAIN_M) / 16.0
		var gz: float = clampf(lz, 0.0, DOMAIN_M) / 16.0
		var i: int = mini(floori(gx), _ride_n - 2)
		var j: int = mini(floori(gz), _ride_n - 2)
		var fx: float = gx - i
		var fz: float = gz - j
		var c00: float = _ride_cost[_ride_at(i, j)]
		var c10: float = _ride_cost[_ride_at(i + 1, j)]
		var c01: float = _ride_cost[_ride_at(i, j + 1)]
		var c11: float = _ride_cost[_ride_at(i + 1, j + 1)]
		return (c00 * (1.0 - fx) + c10 * fx) * (1.0 - fz) + (c01 * (1.0 - fx) + c11 * fx) * fz

	## Exact R4 sample (certification): the public RideabilityField answer.
	func ride_exact(lx: float, lz: float) -> Dictionary:
		ride_queries += 1
		queries += 5
		return rideability.sample(origin_x + lx, origin_z + lz)

	func water_exact(lx: float, lz: float) -> Dictionary:
		queries += 1
		return hydro_field.sample_water(origin_x + lx, origin_z + lz)

	func segment_crossings(ax: float, az: float, bx: float, bz: float) -> Dictionary:
		queries += 1
		return hydro_field.sample_segment_crossings(origin_x + ax, origin_z + az, origin_x + bx, origin_z + bz)

	## A pin within `radius` of a channel's first or last vertex (a channel tip,
	## where a crossing is geometrically degenerate): the point `inward` metres
	## into the channel from that tip; otherwise an empty array.
	func channel_tip_inward(channel_id: int, x: float, z: float, radius: float, inward: float) -> PackedFloat64Array:
		if not _channel_ends.has(channel_id):
			return PackedFloat64Array()
		var e: PackedFloat64Array = _channel_ends[channel_id]
		for o: int in [0, 4]:
			if Vector2(x - e[o], z - e[o + 1]).length() <= radius:
				var dx: float = e[o + 2] - e[o]
				var dz: float = e[o + 3] - e[o + 1]
				var length: float = sqrt(dx * dx + dz * dz)
				var step: float = minf(inward, 0.8 * length)
				return PackedFloat64Array([e[o] + dx / length * step, e[o + 1] + dz / length * step])
		return PackedFloat64Array()

	## Search water: nearest channel whose wetted half-width (+margin) covers
	## the point, from HydrologyPlan geometry: [channel id (-1 none), class,
	## distance to centreline, half width, channel dir x, dir z, surface];
	## body id via its 32 m lattice cells (nearest-lattice semantics as R3).
	func water_search(lx: float, lz: float, margin: float) -> PackedFloat64Array:
		var result := PackedFloat64Array([-1.0, -1.0, INF, 0.0, 0.0, 0.0, NAN, -1.0])
		if not in_domain(lx, lz):
			return result
		var bi: int = clampi(floori(lx / BUCKET_M), 0, BUCKETS - 1)
		var bj: int = clampi(floori(lz / BUCKET_M), 0, BUCKETS - 1)
		for s: int in _buckets[bj * BUCKETS + bi]:
			var o: int = s * SEG_STRIDE
			var ax: float = _seg[o]
			var az: float = _seg[o + 1]
			var ex: float = _seg[o + 2] - ax
			var ez: float = _seg[o + 3] - az
			var l2: float = ex * ex + ez * ez
			if l2 <= 0.0:
				continue
			var t: float = clampf(((lx - ax) * ex + (lz - az) * ez) / l2, 0.0, 1.0)
			var qx: float = ax + t * ex - lx
			var qz: float = az + t * ez - lz
			var d: float = sqrt(qx * qx + qz * qz)
			var half: float = _seg[o + 4] + t * (_seg[o + 5] - _seg[o + 4])
			if d <= half + margin and d - half < result[2] - result[3]:
				var l: float = sqrt(l2)
				result = PackedFloat64Array([_seg[o + 6], _seg[o + 7], d, half, ex / l, ez / l, _seg[o + 8] + t * (_seg[o + 9] - _seg[o + 8]), -1.0])
		var ci: int = clampi(roundi(lx / 32.0), 0, 128)
		var cj: int = clampi(roundi(lz / 32.0), 0, 128)
		result[7] = _body_of[cj * 129 + ci]
		return result
