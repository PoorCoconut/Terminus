extends "res://systems/FSM/State.gd"
class_name StateBreak

# GROUND BRAKE: Brake held while grounded, moving, and NOT accelerating.
#  - Decelerates at PLAYER.BRAKE_DECEL
#  - Fills the Heat Gauge from your current speed (PLAYER.BRAKE_HEAT_MULTIPLIER)
#  - Plays the brake sfx + friction sparks
#  - Heat hitting 100% -> Overheat Malfunction launch (same as Anchor)

@onready var FRICTIONSPARK_PARTICLE := %Particle_FrictionSpark

func enterState():
	PLAYER.is_braking = true
	PLAYER.SFX_CHARGE.pitch_scale = randf_range(0.8, 1.2)
	PLAYER.SFX_CHARGE.play()
	FRICTIONSPARK_PARTICLE.emitting = true

func updateState(delta : float):
	if PLAYER.is_on_floor():
		var floor_normal = PLAYER.get_floor_normal()
		
		# If the floor normal is tilted then the player is on a slope
		if abs(floor_normal.x) > 0.1:
			transition.emit(self, "StunFall")
			return
	
	# Accelerate pressed -> back to running (Anchor gating lives in Charge)
	if Input.is_action_pressed("charge"):
		transition.emit(self, "Charge")
		return
	
	# Brake released, or fully stopped
	if not Input.is_action_pressed("break") or abs(PLAYER.velocity.x) <= 0.0:
		transition.emit(self, "Idle")
		return
	
	if !PLAYER.SFX_STEAM_SHORT.playing:
		PLAYER.SFX_STEAM_SHORT.pitch_scale = randf_range(0.8, 1.2)
		PLAYER.SFX_STEAM_SHORT.play()
	
	# Fill the gauge based on how fast they are currently sliding
	PLAYER.current_brake_gauge += abs(PLAYER.velocity.x) * PLAYER.BRAKE_HEAT_MULTIPLIER * delta
	
	# OVERHEAT MALFUNCTION
	if PLAYER.current_brake_gauge >= PLAYER.MAX_BRAKE_GAUGE:
		PLAYER.current_brake_gauge = PLAYER.MAX_BRAKE_GAUGE
		PLAYER.jump_kind = Player.JumpKind.OVERHEAT
		transition.emit(self, "Jump")
		return
	
	# Decelerate
	PLAYER.velocity.x = move_toward(PLAYER.velocity.x, 0, PLAYER.BRAKE_DECEL * delta)
	PLAYER.move_and_slide()
	
	if not PLAYER.is_on_floor():
		transition.emit(self, "Fall")

func exitState():
	PLAYER.is_braking = false
	PLAYER.SFX_CHARGE.stop()
	FRICTIONSPARK_PARTICLE.emitting = false
