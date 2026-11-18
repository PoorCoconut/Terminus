extends CharacterBody2D
class_name Player

enum JumpKind { STANDARD, NEEDLE, OVERHEAT }

@export_category("PLAYER MOVEMENT")
@export var SPEED : float = 100.0
@export var ACCELERATION : float = 100.0
@export var FRICTION : float = 50.0
#@export var JUMP_VELOCITY : float = -100.0
@export var GRAVITY : float = 500.0

# JUMP VARIABLES (all speeds are magnitudes; direction comes from gravity_dir)
@export_category("JUMP")
@export var JUMP_SPEED : float = 300.0              # Standard Traversal Arc
@export var NEEDLE_JUMP_SPEED : float = 300.0       # Needle Thread (straight vertical)
@export var OVERHEAT_JUMP_SPEED : float = 520.0     # Overheat launch (vertical)
@export var OVERHEAT_LAUNCH_SPEED_X : float = 250.0 # Overheat launch (horizontal)
@export var AIR_BRAKE_DECEL : float = 400.0         # Mid-air Brake: px/s^2 of horizontal bleed

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

#FALL
@export_category("FALL SETTINGS")
@export var STUN_FALL_SPEED : float = 200

#HEAT GAUGE
@export_category("HEAT GAUGE")
@export var MAX_BRAKE_GAUGE : float = 100.0
@export var ANCHOR_HEAT_RATE : float = 60.0    # Heat per second while Anchored (~1.7s to overheat)
@export var GAUGE_COOLDOWN_RATE : float = 25.0 # How much gauge recovers per second

var current_brake_gauge : float = 0.0
var is_anchoring : bool = false  # Set by StateAnchor
var is_overheated : bool = false # True from Overheat launch until landing

#GRAVITY FLIP / ARC
var gravity_dir : float = 1.0 # 1 = pulled down the screen, -1 = pulled up the screen
var in_arc : bool = false     # True from jump until landing (suppresses stun-fall on deliberate falls)
var air_locked : bool = false # True during Overheat launch: no mid-air Brake
var jump_kind : JumpKind = JumpKind.STANDARD # Set by whoever transitions to "Jump"

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

func _physics_process(delta: float) -> void:
	# print("PLAYER VELOCITY X: ", velocity.x, ", Y: ", velocity.y)
	
	# Add the gravity (signed, so it works on the ceiling too).
	if not is_on_floor():
		velocity.y += GRAVITY * gravity_dir * delta
	move_and_slide()
	
	previous_velocity = velocity
	#Cooldown (only while NOT anchored)
	if current_brake_gauge > 0 and not is_anchoring:
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
	%Sprite.flip_v = gravity_dir < 0.0

# Call when an arc ends (landing / stun) to clear arc-only flags.
func end_arc() -> void:
	in_arc = false
	air_locked = false
	if is_overheated:
		is_overheated = false
		STEAM_PARTICLE.emitting = false
