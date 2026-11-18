extends "res://systems/FSM/State.gd"
class_name StateFall

#@export var PLAYER : Player

func enterState(): 
	pass

func updateState(_delta : float):
	PLAYER.previous_velocity = PLAYER.velocity
	
	var fall_speed_before_impact = abs(PLAYER.velocity.y)
	
	# Stun only for UNintended falls (walking off a ledge). A gravity-flip arc
	# is a deliberate fall, so it never stuns on landing.
	if not PLAYER.in_arc and PLAYER.velocity.y * PLAYER.gravity_dir > PLAYER.STUN_FALL_SPEED:
		transition.emit(self, "StunFall")
		return
	
	PLAYER.move_and_slide()
	
	if PLAYER.is_on_wall():
		var wall_normal = PLAYER.get_wall_normal()
		if sign(PLAYER.previous_velocity.x) != sign(wall_normal.x) and PLAYER.previous_velocity.x != 0:
			var crash_speed = abs(PLAYER.previous_velocity.x)
			var raw_bounce = crash_speed * 0.4
			var final_bounce_force = clamp(raw_bounce, 10.0, PLAYER.BOUNCE_FORCE_X)
			PLAYER.velocity.x = wall_normal.x * final_bounce_force
			PLAYER.velocity.y = PLAYER.BOUNCE_FORCE_Y * PLAYER.gravity_dir
			
			
			PLAYER.SFX_WALL_BUMP.pitch_scale = randf_range(0.8, 1.2)
			PLAYER.SFX_WALL_BUMP.play()
			
			#StunFall
			transition.emit(self, "StunFall")
			return
	
	#Camera shake and idle transition
	if PLAYER.is_on_floor():
		var impact_force = fall_speed_before_impact - 5
		if impact_force > 0:
			var intensity = impact_force * 0.01 
			intensity = clamp(intensity, 0.0, 5.0) 
			GameManager.do_camera_shake(intensity, 0.3)
		
		PLAYER.end_arc()
		
		# Landed: carry on running if Accelerate is still held
		# (Anchor is only entered from Charge, once the run-up requirements are met)
		if Input.is_action_pressed("charge"):
			transition.emit(self, "Charge")
		else:
			transition.emit(self, "Idle")
