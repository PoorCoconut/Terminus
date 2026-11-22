extends CharacterBody2D
class_name Player

signal gravity_flip_blocked # Emitted when a flip WOULD have happened but a lock stopped it

enum JumpKind { STANDARD, NEEDLE, OVERHEAT }
enum FlipTiming { APEX, IMMEDIATE, DELAYED }

@export_category("PLAYER MOVEMENT")
## Top running speed (px/s).
@export var SPEED : float = 100.0
## Speed gained per physics frame while Accelerate is held (not per second!).
@export var ACCELERATION : float = 100.0
## LEGACY: replaced by COAST_DECEL / BRAKE_DECEL below. Unused.
@export var FRICTION : float = 50.0
## Base gravity magnitude (px/s^2).
@export var GRAVITY : float = 500.0

@export_category("GROUND BRAKING")
## Horizontal deceleration (px/s^2) while grounded, NOT accelerating, and NOT braking.
## Higher = momentum dies faster after landing/anchor. Lower = longer slides.
@export var COAST_DECEL : float = 250.0
## Horizontal deceleration (px/s^2) while grounded, not accelerating, and Brake is held.
@export var BRAKE_DECEL : float = 700.0
## Minimum |velocity.x| for Brake to engage the Break state (heat, sparks, sfx).
@export var BRAKE_MIN_SPEED : float = 5.0
## Heat gained per (px/s of speed * second) while ground-braking. Faster slide = more heat.
@export var BRAKE_HEAT_MULTIPLIER : float = 2.5

@export_category("ANCHOR REQUIREMENTS")
## Minimum |velocity.x| you must be running at before Anchor is allowed.
@export var ANCHOR_MIN_SPEED : float = 80.0
## Seconds you must have been running at/above ANCHOR_MIN_SPEED before Anchor is allowed.
## Stops "hold Brake -> then tap Accelerate from standstill" from anchoring instantly.
@export var ANCHOR_MIN_RUN_TIME : float = 0.2

# JUMP VARIABLES (all speeds are magnitudes; direction comes from gravity_dir)
@export_category("JUMP")
## Standard Traversal Arc launch speed.
@export var JUMP_SPEED : float = 300.0
## Needle Thread launch speed (straight vertical).
@export var NEEDLE_JUMP_SPEED : float = 300.0
## Overheat launch speed (vertical).
@export var OVERHEAT_JUMP_SPEED : float = 520.0
## Overheat launch speed (horizontal, in facing direction).
@export var OVERHEAT_LAUNCH_SPEED_X : float = 250.0

# LEGACY (Terminal Friction charge-jump). Unused now, kept so nothing else breaks.
@export var JUMP_MIN_VELOCITY : float = -50.0
@export var JUMP_MAX_VELOCITY : float = -300.0
@export var MAX_CHARGE_TIME : float = 1.0
var jump_charge_strength : float = 0.0

@export_category("WALL BOUNCE")
@export var WALL_JUMP_VELX : float = 70
@export var WALL_JUMP_VELY : float = -80
@export var BOUNCE_FORCE_X : float = 50.0 # How far they bounce back
@export var BOUNCE_FORCE_Y : float = -10.0 
## Each CONSECUTIVE wall bounce keeps this fraction of the previous bounce's X force
## (1.0 = no decay, 0.6 = each bounce is 40% weaker, 0.0 = only the first bounce pushes).
@export_range(0.0, 1.0, 0.01) var BOUNCE_X_DECAY : float = 0.6
## Seconds without a wall bounce before the streak resets to full-strength bounces.
@export var BOUNCE_STREAK_RESET_TIME : float = 1.0
## Bounce X force can't be decayed below this fraction of the full force (0 = can fade to nothing).
@export_range(0.0, 1.0, 0.01) var BOUNCE_X_MIN_SCALE : float = 0.0

#FALL
@export_category("FALL SETTINGS")
@export var STUN_FALL_SPEED : float = 200

#GRAVITY SWITCH (experiment with these!)
@export_category("GRAVITY SWITCH")
## Master toggle. OFF = gravity never flips (normal jump arcs) so you can A/B the feel.
@export var GRAVITY_SWITCH_ENABLED : bool = true
## WHEN gravity flips. APEX = at the peak of the jump (spec). IMMEDIATE = the moment you take off.
## DELAYED = FLIP_DELAY seconds after takeoff (or at the apex, whichever comes first).
@export var FLIP_TIMING : FlipTiming = FlipTiming.APEX
## DELAYED timing only: seconds after takeoff before the flip.
@export var FLIP_DELAY : float = 0.15
## Seconds of zero gravity "hang" right after an APEX flip (0 = none). Makes the flip readable.
@export var APEX_HANG_TIME : float = 0.0
## Gravity multiplier while inverted (1.0 = same as normal, 1.5 = falls faster toward the other surface).
@export var FLIPPED_GRAVITY_SCALE : float = 1.0
## Extra speed (px/s) kicked toward the new surface at the moment of the flip.
@export var FLIP_VELOCITY_KICK : float = 0.0
## Fraction of horizontal speed kept through the flip (1 = all, 0 = dead stop).
@export_range(0.0, 1.0, 0.05) var FLIP_HORIZONTAL_RETAIN : float = 1.0
## Camera shake intensity on flip (0 = none).
@export var FLIP_SHAKE : float = 0.0
## Flip the sprite vertically when gravity is inverted.
@export var FLIP_SPRITE : bool = true
## Landing speed (px/s) at or above which a landing after a gravity switch plays the
## hard-land dust, particles and sound (like a StunFall landing). Higher = rarer.
@export var HARD_LAND_SPEED : float = 250.0
## Landing on a slope after a gravity switch drops you into StunFall so you slide off it.
@export var SLOPE_SLIDE_AFTER_FLIP : bool = true
## How tilted the floor normal's X must be to count as a slope (0 = flat, 1 = vertical wall).
@export_range(0.0, 1.0, 0.01) var SLOPE_NORMAL_THRESHOLD : float = 0.1

#HEAT GAUGE
@export_category("HEAT GAUGE")
@export var MAX_BRAKE_GAUGE : float = 100.0
## Heat per second while Anchored (60 = ~1.7s to overheat).
@export var ANCHOR_HEAT_RATE : float = 60.0
## How much gauge recovers per second when not anchored.
@export var GAUGE_COOLDOWN_RATE : float = 25.0

var current_brake_gauge : float = 0.0
var is_anchoring : bool = false  # Set by StateAnchor
var is_braking : bool = false    # Set by StateBreak (ground brake)
var is_overheated : bool = false # True from Overheat launch until landing

#GRAVITY FLIP / ARC
var gravity_dir : float = 1.0 # 1 = pulled down the screen, -1 = pulled up the screen
var in_arc : bool = false     # True from jump until landing (suppresses stun-fall on deliberate falls)
var hang_timer : float = 0.0  # Counts down zero-gravity hang after an apex flip
var switched_in_arc : bool = false # Gravity was actually flipped during this arc
var jump_kind : JumpKind = JumpKind.STANDARD # Set by whoever transitions to "Jump"

#GRAVITY LOCKS (Gravity Anchor zones). >0 means flipping is disallowed.
var gravity_lock_count : int = 0

#WALL BOUNCE STREAK
var bounce_streak : int = 0
var _last_bounce_msec : int = -1000000
var _last_bounce_scale : float = 1.0

var direction : float = 1.0

#Helper Variables
var CURRENT_STATE
var previous_velocity : Vector2 = Vector2.ZERO

#PARTICLES [GLOBAL]
@onready var STEAM_PARTICLE := %Particle_Steam


#SFX
@onready var SFX_JUMP: AudioStreamPlayer = %sfx_jump
@onready var SFX_LAND: AudioStreamPlayer = %sfx_hardLand
@onready var SFX_CHARGE: AudioStreamPlayer = %sfx_charge
@onready var SFX_STEAM_SHORT: AudioStreamPlayer = %sfx_steamShort
@onready var SFX_STEAM_LONG: AudioStreamPlayer = %sfx_steamLong
@onready var SFX_WALL_BUMP: AudioStreamPlayer = %sfx_wallBump

func _ready() -> void:
	var saved_pos = GameManager.load_player_position()
	if saved_pos != null:
		global_position = GameManager.load_player_position()
	
	# Restore saved gravity (upside down) without the flip effects/state changes
	if GameManager.load_player_gravity() != gravity_dir:
		flip_gravity()

func _physics_process(delta: float) -> void:
	# print("PLAYER VELOCITY X: ", velocity.x, ", Y: ", velocity.y)
	
	# Add the gravity (signed, so it works on the ceiling too).
	if hang_timer > 0.0:
		hang_timer -= delta # apex hang: no gravity
	elif not is_on_floor():
		var g = GRAVITY * (FLIPPED_GRAVITY_SCALE if gravity_dir < 0.0 else 1.0)
		velocity.y += g * gravity_dir * delta
	move_and_slide()
	
	previous_velocity = velocity
	#Cooldown (only while NOT anchored)
	if current_brake_gauge > 0 and not is_anchoring and not is_braking:
		STEAM_PARTICLE.amount = 2
		STEAM_PARTICLE.emitting = true
		
		
		current_brake_gauge -= GAUGE_COOLDOWN_RATE * delta
		
		
		if current_brake_gauge <= 1:
			current_brake_gauge = 0
			STEAM_PARTICLE.emitting = false
		
		current_brake_gauge = max(current_brake_gauge, 0.0) # Don't let it go below 0
	Events.brake_gauge_updated.emit(current_brake_gauge, MAX_BRAKE_GAUGE)

# ---------------------------------------------------------------- GRAVITY FLIP
# Flips the world's "down". up_direction is flipped too so is_on_floor() /
# is_on_ceiling() keep meaning "the surface I'm standing on" after the flip.
# Sprite uses flip_v (NOT scale.y / rotation) so screen-space X stays absolute:
# pressing Right always moves right on the monitor.
func flip_gravity() -> void:
	gravity_dir *= -1.0
	up_direction = Vector2(0.0, -gravity_dir)
	if FLIP_SPRITE:
		%Sprite.flip_v = gravity_dir < 0.0

# The full "gravity switch" with all the experiment settings applied.
# zero_vy = true when flipping at the apex (vertical speed is snapped to 0 first).
func do_gravity_switch(zero_vy : bool) -> void:
	flip_gravity()
	switched_in_arc = true
	velocity.x *= FLIP_HORIZONTAL_RETAIN
	if zero_vy:
		velocity.y = 0.0
		hang_timer = APEX_HANG_TIME
	velocity.y += FLIP_VELOCITY_KICK * gravity_dir
	if FLIP_SHAKE > 0.0:
		GameManager.do_camera_shake(FLIP_SHAKE, 0.2)

# Call when an arc ends (landing / stun) to clear arc-only flags.
func end_arc() -> void:
	in_arc = false
	switched_in_arc = false
	hang_timer = 0.0
	if is_overheated:
		is_overheated = false
		STEAM_PARTICLE.emitting = false

# ---------------------------------------------------------------- WALL BOUNCE STREAK
# Call ONCE per wall hit. Returns the multiplier to apply to that bounce's X force:
# 1.0 for the first bounce, then BOUNCE_X_DECAY^n for each consecutive one.
# The streak resets after BOUNCE_STREAK_RESET_TIME seconds without a bounce.
# Hits within 0.1s of each other count as the same bounce (no double-counting while
# still touching the wall).
func get_bounce_scale() -> float:
	var now = Time.get_ticks_msec()
	var since = now - _last_bounce_msec
	if since < 100:
		return _last_bounce_scale
	if since > BOUNCE_STREAK_RESET_TIME * 1000.0:
		bounce_streak = 0
	_last_bounce_scale = max(pow(BOUNCE_X_DECAY, bounce_streak), BOUNCE_X_MIN_SCALE)
	bounce_streak += 1
	_last_bounce_msec = now
	return _last_bounce_scale

# ---------------------------------------------------------------- GRAVITY LOCKS
# Zones call add/remove (a counter, so overlapping zones work correctly).
func add_gravity_lock() -> void:
	gravity_lock_count += 1

func remove_gravity_lock() -> void:
	gravity_lock_count = max(0, gravity_lock_count - 1)

func can_flip_gravity() -> bool:
	return GRAVITY_SWITCH_ENABLED and gravity_lock_count <= 0
