extends "res://systems/FSM/State.gd"
class_name StateJump

# One Jump state, three flavours. Whoever transitions here sets PLAYER.jump_kind first:
#   STANDARD - Standard Traversal Arc (keeps horizontal momentum)
#   NEEDLE   - Needle Thread (straight vertical, zero horizontal drift)
#   OVERHEAT - Overheat Malfunction (forced massive launch)

var jump_time : float = 0.0
var switched : bool = false # gravity already flipped during this jump

func enterState():
	jump_time = 0.0
	switched = false
	PLAYER.SFX_JUMP.pitch_scale = randf_range(0.8, 1.2)
	PLAYER.SFX_JUMP.play()
	PLAYER.in_arc = true
	
	# "Up" relative to current gravity (screen-up when gravity_dir = 1, screen-down when -1)
	var up : float = -PLAYER.gravity_dir
	
	match PLAYER.jump_kind:
		Player.JumpKind.NEEDLE:
			PLAYER.velocity.x = 0.0
			PLAYER.velocity.y = PLAYER.NEEDLE_JUMP_SPEED * up
		
		Player.JumpKind.OVERHEAT:
			PLAYER.is_overheated = true
			PLAYER.current_brake_gauge = 0.0
			PLAYER.velocity.x = PLAYER.direction * PLAYER.OVERHEAT_LAUNCH_SPEED_X
			PLAYER.velocity.y = PLAYER.OVERHEAT_JUMP_SPEED * up
			
			PLAYER.SFX_STEAM_LONG.pitch_scale = randf_range(0.9, 1.2)
			PLAYER.SFX_STEAM_LONG.play()
			PLAYER.STEAM_PARTICLE.amount = 30
			PLAYER.STEAM_PARTICLE.emitting = true
			GameManager.do_camera_shake(8.0, 0.4)
		
		_: # STANDARD - horizontal velocity is deliberately left alone
			PLAYER.velocity.y = PLAYER.JUMP_SPEED * up
	
	# IMMEDIATE timing: flip the instant we leave the ground
	if PLAYER.GRAVITY_SWITCH_ENABLED and PLAYER.FLIP_TIMING == Player.FlipTiming.IMMEDIATE:
		PLAYER.do_gravity_switch(false)
		switched = true

func updateState(delta : float):
	PLAYER.previous_velocity = PLAYER.velocity
	jump_time += delta
	
	#Ceiling Bump (the surface in the direction we're jumping)
	if PLAYER.is_on_ceiling():
		PLAYER.velocity.y = PLAYER.gravity_dir
	PLAYER.move_and_slide()
	
	if PLAYER.is_on_wall():
		var wall_normal = PLAYER.get_wall_normal()
		PLAYER.velocity.x = wall_normal.x * PLAYER.WALL_JUMP_VELX
		PLAYER.velocity.y = PLAYER.WALL_JUMP_VELY * PLAYER.gravity_dir
		
		PLAYER.SFX_WALL_BUMP.pitch_scale = randf_range(0.8, 1.2)
		PLAYER.SFX_WALL_BUMP.play()
		
		transition.emit(self, "StunFall")
		return
	
	# Gravity already flipped at takeoff (IMMEDIATE): we're just falling to the far surface
	if switched:
		transition.emit(self, "Fall")
		return
	
	# DELAYED timing: flip after FLIP_DELAY (mid-rise, velocity untouched)
	if PLAYER.GRAVITY_SWITCH_ENABLED and PLAYER.FLIP_TIMING == Player.FlipTiming.DELAYED \
			and jump_time >= PLAYER.FLIP_DELAY:
		PLAYER.do_gravity_switch(false)
		switched = true
		transition.emit(self, "Fall")
		return
	
	# THE APEX SHIFT: vertical velocity has hit zero -> invert gravity and fall
	# toward the opposite surface. (With the switch disabled it's a normal arc.)
	if PLAYER.velocity.y * PLAYER.gravity_dir >= 0.0:
		if PLAYER.GRAVITY_SWITCH_ENABLED:
			PLAYER.do_gravity_switch(true)
		else:
			PLAYER.velocity.y = 0.0
		transition.emit(self, "Fall")
		return
	
	#FALLBACK TO IDLE WHEN THIS BUG HAPPENS
	if PLAYER.is_on_floor():
		transition.emit(self, "Idle")
