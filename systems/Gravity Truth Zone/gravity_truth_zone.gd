@tool
extends Area2D
class_name GravityTruthZone

## A zone where gravity has ONE truth: DOWN or UP (screen-space).
##  - Entering it with the OTHER gravity auto-flips the player to the truth, momentum kept.
##  - While inside, gravity can't be flipped away from the truth: trying to flip
##    just results in a normal hop (jump up, fall back to the same surface).
##  - Leaving the zone leaves the player in whatever gravity they have; flipping works again.
##
## SETUP: Area2D + CollisionShape2D child (any shape), attach this script, and make sure this
## Area2D's Collision MASK includes the layer the Player is on.

enum Truth { DOWN, UP }

## Which way gravity is pulled while in this zone (as seen on the monitor).
@export var truth : Truth = Truth.DOWN:
	set(value):
		if truth == value:
			return
		truth = value
		queue_redraw()
		_update_particles() # keeps the particles' direction in sync as you edit the inspector
		_force_players() # changing the truth at runtime re-forces anyone inside

## Optional: the CPUParticles2D to keep in sync with the truth. Leave empty to
## auto-find a node with the unique name %Particles.
@export var particles : CPUParticles2D:
	set(value):
		particles = value
		_update_particles()

## Also flip the particles' own `gravity` Y so they accelerate along the truth
## (only needed if your particles use the gravity property, not just direction).
@export var also_flip_particle_gravity : bool = false:
	set(value):
		also_flip_particle_gravity = value
		_update_particles()

## Turn the zone on/off at runtime. Off = no forcing and no lock.
@export var enabled : bool = true:
	set(value):
		if enabled == value:
			return
		enabled = value
		_refresh()

## Editor-only tint so you can see the zone while designing the level.
@export var down_color : Color = Color(0.2, 0.6, 1.0, 0.25):
	set(value):
		down_color = value
		queue_redraw()
@export var up_color : Color = Color(1.0, 0.3, 0.8, 0.25):
	set(value):
		up_color = value
		queue_redraw()

var _players : Array[Player] = []

func _ready() -> void:
	_apply_particles() # make sure they match even if the saved scene didn't
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _truth_dir() -> float:
	return 1.0 if truth == Truth.DOWN else -1.0

# Setters can fire while the scene is still loading (children don't exist yet): skip then.
func _update_particles() -> void:
	if is_node_ready():
		_apply_particles()

# DOWN -> direction.y = 1.0, UP -> direction.y = -1.0 (x is left as you set it)
func _apply_particles() -> void:
	var p : CPUParticles2D = particles
	if p == null:
		p = get_node_or_null("%Particles") as CPUParticles2D
	if p == null:
		return
	var d = _truth_dir()
	p.direction = Vector2(p.direction.x, d)
	if also_flip_particle_gravity:
		p.gravity = Vector2(p.gravity.x, abs(p.gravity.y) * d)

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var col = down_color if truth == Truth.DOWN else up_color
	for child in get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			var size : Vector2 = child.shape.size
			var center : Vector2 = child.position
			draw_rect(Rect2(center - size * 0.5, size), col)
			# Arrow showing the truth direction
			var d = _truth_dir()
			var h = min(size.y * 0.3, 24.0)
			var solid = Color(col.r, col.g, col.b, 0.9)
			draw_line(center + Vector2(0, -h * d), center + Vector2(0, h * d), solid, 2.0)
			draw_line(center + Vector2(0, h * d), center + Vector2(-h * 0.5, h * 0.4 * d), solid, 2.0)
			draw_line(center + Vector2(0, h * d), center + Vector2(h * 0.5, h * 0.4 * d), solid, 2.0)

func _on_body_entered(body: Node2D) -> void:
	if body is Player and enabled and not _players.has(body):
		_players.append(body)
		body.add_gravity_lock()          # no flipping away from the truth
		body.force_gravity(_truth_dir()) # auto-flip to the truth (keeps momentum)

func _on_body_exited(body: Node2D) -> void:
	if body is Player and _players.has(body):
		body.remove_gravity_lock()
		_players.erase(body)

func _force_players() -> void:
	if Engine.is_editor_hint():
		return
	for p in _players:
		if is_instance_valid(p):
			p.force_gravity(_truth_dir())

# `enabled` toggled: lock + force anyone inside / release anyone inside
func _refresh() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	if enabled:
		for body in get_overlapping_bodies():
			_on_body_entered(body)
	else:
		for p in _players.duplicate():
			if is_instance_valid(p):
				p.remove_gravity_lock()
		_players.clear()

# Zone deleted / level unloaded while the player is inside -> release the lock
func _exit_tree() -> void:
	for p in _players:
		if is_instance_valid(p):
			p.remove_gravity_lock()
	_players.clear()
