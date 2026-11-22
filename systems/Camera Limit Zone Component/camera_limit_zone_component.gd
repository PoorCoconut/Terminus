extends Area2D
class_name CameraLimitZone

# Camera room zones, now decided by WHERE THE PLAYER IS instead of enter/exit events.
#
# Why the old version bugged: body_entered only fires when you ENTER a zone. Bounce from
# zone A into overlapping zone B and back into A (still touching B), and A never fires
# "entered" again, so the camera stayed on B's limits while you were really in A.
#
# Now every zone registers itself, and once per physics frame ONE decision is made:
#   1. If the zone the camera is using still contains the player's position -> keep it
#      (so overlaps/edges can't flip-flop).
#   2. Otherwise switch to the zone that contains the player's position
#      (overlapping zones: the smallest one wins).
#   3. In a gap between zones, keep the current limits.

@onready var collision_shape : CollisionShape2D = $CollisionShape2D

static var _zones : Array[CameraLimitZone] = []
static var _current : CameraLimitZone = null # zone whose limits the camera is using
static var _last_tick_frame : int = -1

func _ready() -> void:
	if collision_shape.shape as RectangleShape2D == null:
		push_error("CameraLimitZone requires a RectangleShape2D! (" + str(get_path()) + ")")
	_zones.append(self)

func _exit_tree() -> void:
	_zones.erase(self)
	if _current == self:
		_current = null

func _physics_process(_delta: float) -> void:
	_tick() # every zone calls this, but only the first call each frame does any work

# World-space rectangle covered by this zone (accounts for node scale)
func get_world_rect() -> Rect2:
	var shape = collision_shape.shape as RectangleShape2D
	if shape == null:
		return Rect2()
	var size = shape.size * collision_shape.global_scale.abs()
	return Rect2(collision_shape.global_position - size * 0.5, size)

func _is_usable() -> bool:
	return monitoring and not collision_shape.disabled and collision_shape.shape is RectangleShape2D

func _contains(pos: Vector2) -> bool:
	return _is_usable() and get_world_rect().has_point(pos)

static func _tick() -> void:
	var frame = Engine.get_physics_frames()
	if frame == _last_tick_frame:
		return
	_last_tick_frame = frame
	
	if _zones.is_empty():
		return
	var player = _zones[0].get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var pos = player.global_position
	
	# 1. Hysteresis: still inside the zone we're using -> nothing to do
	if _current != null and is_instance_valid(_current) and _current._contains(pos):
		return
	
	# 2. Pick the zone that contains the player (smallest wins when they overlap)
	var best : CameraLimitZone = null
	var best_area = INF
	for z in _zones:
		if z._contains(pos):
			var r = z.get_world_rect()
			var area = r.size.x * r.size.y
			if area < best_area:
				best_area = area
				best = z
	
	# No zone contains the player and we have none yet (e.g. spawned in a gap): nearest one
	if best == null and _current == null:
		var best_dist = INF
		for z in _zones:
			if not z._is_usable():
				continue
			var r = z.get_world_rect()
			var dx = max(r.position.x - pos.x, 0.0, pos.x - r.end.x)
			var dy = max(r.position.y - pos.y, 0.0, pos.y - r.end.y)
			var dist = Vector2(dx, dy).length()
			if dist < best_dist:
				best_dist = dist
				best = z
	
	if best != null and best != _current:
		best._apply_to_camera()

func _apply_to_camera() -> void:
	var camera = get_viewport().get_camera_2d()
	if camera == null or not camera.has_method("apply_room_limits"):
		return # camera not ready yet -> _current stays unset, we retry next frame
	
	var r = get_world_rect()
	camera.apply_room_limits(int(r.position.x), int(r.end.x), int(r.position.y), int(r.end.y))
	_current = self
