extends "res://systems/FSM/State.gd"
class_name StateAnchor

# THE ANCHOR: Accelerate + Brake held, grounded.
#  - velocity.x is clamped to 0 every frame
#  - Heat fills continuously while both inputs stay held
#  - Release Accelerate before 100%  -> Needle Thread (straight vertical jump)
#  - Heat reaches 100%               -> Overheat Malfunction (forced launch)
#  - Release Brake, keep Accelerate  -> back to Charge (running again)

@onready var FRICTIONSPARK_PARTICLE := %Particle_FrictionSpark

func enterState():
	PLAYER.is_anchoring = true
	PLAYER.velocity.x = 0.0
	PLAYER.SFX_CHARGE.pitch_scale = randf_range(0.8, 1.2)
	PLAYER.SFX_CHARGE.play()
	FRICTIONSPARK_PARTICLE.emitting = true

func updateState(delta : float):
	# Anchoring on a slope isn't allowed (same rule the old Break state had)
	if PLAYER.is_on_floor():
		var floor_normal = PLAYER.get_floor_normal()
		if abs(floor_normal.x) > 0.1:
			transition.emit(self, "StunFall")
			return
	
	# 1. NEEDLE THREAD: Accelerate released before overheat
	if not Input.is_action_pressed("charge"):
		PLAYER.jump_kind = Player.JumpKind.NEEDLE
		transition.emit(self, "Jump")
		return
	
	# 2. Brake released but still accelerating -> resume running
	if not Input.is_action_pressed("break"):
		transition.emit(self, "Charge")
		return
	
	# 3. Hold the line: clamp horizontal movement, route float into heat
	PLAYER.velocity.x = 0.0
	PLAYER.current_brake_gauge += PLAYER.ANCHOR_HEAT_RATE * delta
	
	if !PLAYER.SFX_STEAM_SHORT.playing:
		PLAYER.SFX_STEAM_SHORT.pitch_scale = randf_range(0.8, 1.2)
		PLAYER.SFX_STEAM_SHORT.play()
	
	# 4. OVERHEAT MALFUNCTION
	if PLAYER.current_brake_gauge >= PLAYER.MAX_BRAKE_GAUGE:
		PLAYER.current_brake_gauge = PLAYER.MAX_BRAKE_GAUGE
		PLAYER.jump_kind = Player.JumpKind.OVERHEAT
		transition.emit(self, "Jump")
		return
	
	PLAYER.move_and_slide()
	
	if not PLAYER.is_on_floor():
		transition.emit(self, "Fall")

func exitState():
	PLAYER.is_anchoring = false
	PLAYER.SFX_CHARGE.stop()
	FRICTIONSPARK_PARTICLE.emitting = false
