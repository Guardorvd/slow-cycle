class_name RegionWorld
extends Node3D

## PR1 runtime composition root of one procedural region scene. Composes the
## environment, the existing bicycle, HUD and fader with region content
## supplied by an owner of world geometry (M1: a FinalSurface slice; later
## the RegionStreamer over a RegionBake). Owns spawn placement, the duck-typed
## `request_bike_recovery(pos) -> Transform3D` used by BicycleController and
## recovery paths. Owns no generation math and never writes bicycle motion.

const SPAWN_CLEARANCE_M: float = 0.45
const RECOVERY_BACKOFF_M: float = 20.0

@export var bike_path: NodePath = NodePath("Bicycle")

var _recovery_paths: Array = []
var _content: Node3D


func get_bike() -> BicycleController:
	return get_node_or_null(bike_path) as BicycleController


## Region content (render, collision, water ...) is owned by the caller's
## node; this root only parents it.
func attach_content(content: Node3D) -> void:
	if _content != null and is_instance_valid(_content):
		_content.queue_free()
	_content = content
	add_child(content)


## World-space riding polylines (PackedVector3Array, ground heights) used for
## recovery: nearest point, stepped back along the path, facing along it.
func set_recovery_paths(paths: Array) -> void:
	_recovery_paths = paths.duplicate()


## Places the bicycle on ground point `ground` facing horizontal `direction`.
func spawn_bike(ground: Vector3, direction: Vector3) -> void:
	var bike: BicycleController = get_bike()
	if bike == null:
		return
	# The root stays at the world origin, so local equals world before entry.
	if bike.is_inside_tree():
		bike.global_transform = _pose(ground, direction)
	else:
		bike.transform = _pose(ground, direction)
	bike.velocity = Vector3.ZERO


static func _pose(ground: Vector3, direction: Vector3) -> Transform3D:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 1e-8:
		flat = Vector3.FORWARD
	return Transform3D(Basis.looking_at(flat.normalized(), Vector3.UP), ground + Vector3(0.0, SPAWN_CLEARANCE_M, 0.0))


func request_bike_recovery(query: Vector3) -> Transform3D:
	var best: float = INF
	var best_path: PackedVector3Array
	var best_i: int = -1
	for path: PackedVector3Array in _recovery_paths:
		for i in range(path.size()):
			var d: float = Vector2(path[i].x - query.x, path[i].z - query.z).length_squared()
			if d < best:
				best = d
				best_path = path
				best_i = i
	if best_i < 0:
		return Transform3D(Basis.IDENTITY, query + Vector3(0.0, 2.0, 0.0))
	# Step back along the path (towards lower index) by the backoff distance.
	var i: int = best_i
	var travelled: float = 0.0
	while i > 0 and travelled < RECOVERY_BACKOFF_M:
		travelled += best_path[i].distance_to(best_path[i - 1])
		i -= 1
	var j: int = mini(i + 1, best_path.size() - 1)
	var k: int = maxi(j - 1, 0)
	var direction: Vector3 = best_path[j] - best_path[k] if j != k else Vector3.FORWARD
	return _pose(best_path[i], direction)
