@tool
extends Area2D
class_name GravityAnchorZone

## While the player overlaps this zone, gravity can NOT be flipped.
## Jumping out of Charge behaves like a normal jump: up, then back down to the SAME surface.
##
## SETUP: Area2D + CollisionShape2D child (any shape), attach this script, and make sure this
## Area2D's Collision MASK includes the layer the Player is on.
##
## The check happens at the moment the flip WOULD occur (apex / takeoff / delay), so:
##  - jumping inside the zone, apex inside   -> no flip
##  - jumping from outside, apex inside      -> no flip
##  - jumping from inside, apex outside      -> flips as normal

## Turn the zone on/off at runtime (e.g. from a switch or a boss fight).
@export var enabled : bool = true:
	set(value):
		if enabled == value:
			return
		enabled = value
		_refresh_locks()

## Editor-only tint so you can see the zone while designing the level.
@export var editor_color : Color = Color(1.0, 0.45, 0.1, 0.25):
	set(value):
		editor_color = value
		queue_redraw()

var _locked_players : Array[Player] = []

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	for child in get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			var size : Vector2 = child.shape.size
			draw_rect(Rect2(child.position - size * 0.5, size), editor_color)

func _on_body_entered(body: Node2D) -> void:
	if body is Player and enabled and not _locked_players.has(body):
		body.add_gravity_lock()
		_locked_players.append(body)

func _on_body_exited(body: Node2D) -> void:
	if body is Player and _locked_players.has(body):
		body.remove_gravity_lock()
		_locked_players.erase(body)

# Apply/release the lock on players currently inside when `enabled` is toggled
func _refresh_locks() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	if enabled:
		for body in get_overlapping_bodies():
			_on_body_entered(body)
	else:
		for p in _locked_players.duplicate():
			p.remove_gravity_lock()
		_locked_players.clear()

# Zone deleted / level unloaded while the player is still inside -> release the lock
func _exit_tree() -> void:
	for p in _locked_players:
		if is_instance_valid(p):
			p.remove_gravity_lock()
	_locked_players.clear()
