class_name DrainageRouting
extends RefCounted

## Deterministic drainage routing on a square height grid (R3). Pure and
## stateless: packed arrays in, new packed arrays out. Row-major, z outer.
##
## 1. Priority-flood with a small epsilon from the outlets (marked cells and
##    the grid boundary) gives depression-free routing heights; cells are
##    popped in the total key order (filled height, index), so the pop order
##    is a topological order (every receiver precedes its donors).
## 2. Receiver = steepest descent on the routing heights among the 8
##    neighbours earlier in that order. Marked cells are terminal (OUTLET).
##    A boundary cell drains inwards when it has an earlier interior
##    neighbour, otherwise it is terminal (EDGE): no flow runs along an edge.
## 3. Two crossing diagonal links inside one 2 x 2 block are resolved by
##    turning the later source's link into an orthogonal link within the
##    block, so flow lines never cross.
## 4. Contributing area (in cells) and the terminal cell of every cell.

const TERMINAL_NONE: int = 0
const TERMINAL_OUTLET: int = 1
const TERMINAL_EDGE: int = 2
const EPSILON_M: float = 0.0001
const NEIGHBOURS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]


static func _boundary(i: int, j: int, nx: int, nz: int) -> bool:
	return i == 0 or j == 0 or i == nx - 1 or j == nz - 1


## Route a grid. Reasons: ERR_ROUTING_INPUT (shape, size or non-finite height).
## Result: {is_valid, filled_m, receiver (-1 = terminal), terminal (TERMINAL_*),
## order (topological, downstream first), area_cells, outlet, reason_code}.
static func route(heights: PackedFloat64Array, nx: int, nz: int, step_m: float, outlets: PackedByteArray) -> Dictionary:
	var n: int = nx * nz
	if nx < 3 or nz < 3 or heights.size() != n or outlets.size() != n or not is_finite(step_m) or step_m <= 0.0:
		return {"is_valid": false, "reason_code": "ERR_ROUTING_INPUT"}
	for h: float in heights:
		if not is_finite(h):
			return {"is_valid": false, "reason_code": "ERR_ROUTING_INPUT"}
	var filled: PackedFloat64Array = heights.duplicate()
	var closed := PackedByteArray()
	closed.resize(n)
	var heap_keys := PackedFloat64Array()
	var heap_ids := PackedInt32Array()
	for c in range(n):
		if outlets[c] != 0 or _boundary(c % nx, c / nx, nx, nz):
			closed[c] = 1
			_push(heap_keys, heap_ids, filled[c], c)
	var order := PackedInt32Array()
	order.resize(n)
	var rank := PackedInt32Array()
	rank.resize(n)
	var popped: int = 0
	while heap_ids.size() > 0:
		var c: int = _pop(heap_keys, heap_ids)
		order[popped] = c
		rank[c] = popped
		popped += 1
		var ci: int = c % nx
		var cj: int = c / nx
		for offset: Vector2i in NEIGHBOURS:
			var i: int = ci + offset.x
			var j: int = cj + offset.y
			if i < 0 or j < 0 or i >= nx or j >= nz:
				continue
			var nb: int = j * nx + i
			if closed[nb] != 0:
				continue
			closed[nb] = 1
			filled[nb] = maxf(heights[nb], filled[c] + EPSILON_M)
			_push(heap_keys, heap_ids, filled[nb], nb)
	var receiver := PackedInt32Array()
	receiver.resize(n)
	var terminal := PackedByteArray()
	terminal.resize(n)
	var diagonal: float = step_m * sqrt(2.0)
	for c in range(n):
		receiver[c] = -1
		if outlets[c] != 0:
			terminal[c] = TERMINAL_OUTLET
			continue
		var ci: int = c % nx
		var cj: int = c / nx
		var on_edge: bool = _boundary(ci, cj, nx, nz)
		var best: int = -1
		var best_slope: float = -1.0
		for offset: Vector2i in NEIGHBOURS:
			var i: int = ci + offset.x
			var j: int = cj + offset.y
			if i < 0 or j < 0 or i >= nx or j >= nz:
				continue
			if on_edge and _boundary(i, j, nx, nz):
				continue
			var nb: int = j * nx + i
			if rank[nb] >= rank[c]:
				continue
			var slope: float = (filled[c] - filled[nb]) / (diagonal if offset.x != 0 and offset.y != 0 else step_m)
			if slope > best_slope or (slope == best_slope and rank[nb] < rank[best]):
				best = nb
				best_slope = slope
		if best < 0:
			terminal[c] = TERMINAL_EDGE
		else:
			receiver[c] = best
	_uncross(receiver, rank, nx, nz)
	var accumulated: Dictionary = accumulate(receiver, order)
	return {"is_valid": true, "filled_m": filled, "receiver": receiver, "terminal": terminal, "order": order, "area_cells": accumulated.area_cells, "outlet": accumulated.outlet, "reason_code": ""}


## Contributing area (cells, including the cell itself) and terminal cell for
## a receiver forest given a topological order (receivers first).
static func accumulate(receiver: PackedInt32Array, order: PackedInt32Array) -> Dictionary:
	var n: int = receiver.size()
	var area := PackedInt32Array()
	area.resize(n)
	area.fill(1)
	for k in range(n - 1, -1, -1):
		var c: int = order[k]
		if receiver[c] >= 0:
			area[receiver[c]] += area[c]
	var outlet := PackedInt32Array()
	outlet.resize(n)
	for k in range(n):
		var c: int = order[k]
		outlet[c] = c if receiver[c] < 0 else outlet[receiver[c]]
	return {"area_cells": area, "outlet": outlet}


static func _uncross(receiver: PackedInt32Array, rank: PackedInt32Array, nx: int, nz: int) -> void:
	for j in range(nz - 1):
		for i in range(nx - 1):
			var a: int = j * nx + i
			var b: int = a + 1
			var c: int = a + nx
			var d: int = c + 1
			var first: bool = receiver[a] == d or receiver[d] == a
			var second: bool = receiver[b] == c or receiver[c] == b
			if not first or not second:
				continue
			var source_one: int = a if receiver[a] == d else d
			var source_two: int = b if receiver[b] == c else c
			# Redirect the later source to one of the other diagonal's cells
			# (both are orthogonal neighbours inside the block and earlier).
			var later: int = source_one if rank[source_one] > rank[source_two] else source_two
			var other: int = source_two if later == source_one else source_one
			var candidates: Array[int] = [other, receiver[other]]
			var li: int = later % nx
			var lj: int = later / nx
			var best: int = -1
			for candidate: int in candidates:
				if _boundary(li, lj, nx, nz) and _boundary(candidate % nx, candidate / nx, nx, nz):
					continue
				if rank[candidate] < rank[later] and (best < 0 or rank[candidate] < rank[best]):
					best = candidate
			if best >= 0:
				receiver[later] = best


static func _less(keys: PackedFloat64Array, ids: PackedInt32Array, a: int, b: int) -> bool:
	return keys[a] < keys[b] or (keys[a] == keys[b] and ids[a] < ids[b])


static func _push(keys: PackedFloat64Array, ids: PackedInt32Array, key: float, id: int) -> void:
	keys.append(key)
	ids.append(id)
	var k: int = keys.size() - 1
	while k > 0:
		var parent: int = (k - 1) / 2
		if not _less(keys, ids, k, parent):
			break
		_swap(keys, ids, k, parent)
		k = parent


static func _pop(keys: PackedFloat64Array, ids: PackedInt32Array) -> int:
	var top: int = ids[0]
	var last: int = keys.size() - 1
	keys[0] = keys[last]
	ids[0] = ids[last]
	keys.resize(last)
	ids.resize(last)
	var k: int = 0
	while true:
		var left: int = 2 * k + 1
		if left >= last:
			break
		var child: int = left
		if left + 1 < last and _less(keys, ids, left + 1, left):
			child = left + 1
		if not _less(keys, ids, child, k):
			break
		_swap(keys, ids, k, child)
		k = child
	return top


static func _swap(keys: PackedFloat64Array, ids: PackedInt32Array, a: int, b: int) -> void:
	var key: float = keys[a]
	keys[a] = keys[b]
	keys[b] = key
	var id: int = ids[a]
	ids[a] = ids[b]
	ids[b] = id
