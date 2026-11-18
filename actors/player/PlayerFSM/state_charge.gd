extends "res://systems/FSM/State.gd"
class_name StateCharge

#@export var PLAYER : Player

func enterState():
	PLAYER.SFX_CHARGE.pitch_scale = randf_range(0.8, 1.2)
	PLAYER.SFX_CHARGE.play()

func updateState(_delta : float):
	# RELEASE ACCELERATE -> Standard Traversal Arc (keeps horizontal momentum)
	if not Input.is_action_pressed("charge"):
		PLAYER.jump_kind = Player.JumpKind.STANDARD
		transition.emit(self, "Jump")
		return
	
	# ACCELERATE + BRAKE -> Anchor
	if Input.is_action_pressed("break"):
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
