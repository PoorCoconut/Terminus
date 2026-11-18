extends "res://systems/FSM/State.gd"
class_name StateCharge

#@export var PLAYER : Player

# Anchor gating: Brake only anchors if it was UP at some point during this run
# and we've been moving at ANCHOR_MIN_SPEED+ for ANCHOR_MIN_RUN_TIME.
var brake_armed : bool = false
var time_at_speed : float = 0.0

func enterState():
	brake_armed = not Input.is_action_pressed("break")
	time_at_speed = 0.0
	PLAYER.SFX_CHARGE.pitch_scale = randf_range(0.8, 1.2)
	PLAYER.SFX_CHARGE.play()

func updateState(delta : float):
	# RELEASE ACCELERATE -> Standard Traversal Arc (keeps horizontal momentum)
	if not Input.is_action_pressed("charge"):
		PLAYER.jump_kind = Player.JumpKind.STANDARD
		transition.emit(self, "Jump")
		return
	
	# ACCELERATE + BRAKE -> Anchor (only when already running fast enough)
	var braking = Input.is_action_pressed("break")
	if not braking:
		brake_armed = true
	if abs(PLAYER.velocity.x) >= PLAYER.ANCHOR_MIN_SPEED:
		time_at_speed += delta
	else:
		time_at_speed = 0.0
	if braking and brake_armed and time_at_speed >= PLAYER.ANCHOR_MIN_RUN_TIME:
		transition.emit(self, "Anchor")
		return
	
	var current_speed = abs(PLAYER.velocity.x)
	var is_moving_forward = sign(PLAYER.velocity.x) == sign(PLAYER.direction)
	
	# THE OVERSPEED CHECK (Coasting)
	if is_moving_forward and current_speed > PLAYER.SPEED:
		# If we are going faster than base speed, we slowly bleed speed 
		# back down to PLAYER.SPEED. We use a tiny fraction of acceleration 
		# so they keep their slope momentum for a long time!
		var coast_friction = PLAYER.ACCELERATION * 0.05 
		PLAYER.velocity.x = move_toward(PLAYER.velocity.x, PLAYER.direction * PLAYER.SPEED, coast_friction)
		
	else:
		# NORMAL CHARGE
		# Accelerate normally up to the base speed limit
		PLAYER.velocity.x = move_toward(PLAYER.velocity.x, PLAYER.direction * PLAYER.SPEED, PLAYER.ACCELERATION)
		
	PLAYER.move_and_slide()
	
	if PLAYER.velocity.length() <= 0.5 or PLAYER.is_on_wall():
		transition.emit(self, "Idle")
		return
	
	if not PLAYER.is_on_floor():
		transition.emit(self, "Fall")

func exitState():
	PLAYER.SFX_CHARGE.stop()
