extends "res://systems/FSM/State.gd"
class_name StateFall

#@export var PLAYER : Player

## Hard-land particle scene. Leave empty to reuse the one assigned on the StunFall state.
@export var LAND_PARTICLE_PATH : PackedScene
@onready var DUST_PARTICLE = %Particle_Dust

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
		
		# Landed on a slope after a gravity switch -> StunFall, so the player slides off.
		# (StunFall plays its own land sound/particles and clears the arc flags.)
		if PLAYER.SLOPE_SLIDE_AFTER_FLIP and PLAYER.switched_in_arc \
				and abs(PLAYER.get_floor_normal().x) > PLAYER.SLOPE_NORMAL_THRESHOLD:
			transition.emit(self, "StunFall")
			return
		
		# Landing after a gravity switch, hard enough -> StunFall-style landing effects
		if PLAYER.switched_in_arc and fall_speed_before_impact >= PLAYER.HARD_LAND_SPEED:
			_hard_land_effects()
		
		PLAYER.end_arc()
		
		# Landed: carry on running if Accelerate is still held
		# (Anchor is only entered from Charge, once the run-up requirements are met)
		if Input.is_action_pressed("charge"):
			transition.emit(self, "Charge")
		else:
			transition.emit(self, "Idle")

func _hard_land_effects() -> void:
	PLAYER.SFX_LAND.pitch_scale = randf_range(0.8, 1.2)
	PLAYER.SFX_LAND.play()
	
	# Short dust burst
	DUST_PARTICLE.emitting = true
	get_tree().create_timer(0.25).timeout.connect(func(): DUST_PARTICLE.emitting = false)
	
	# Land particle (own export, else borrow StunFall's)
	var scene : PackedScene = LAND_PARTICLE_PATH
	if scene == null:
		var stun = get_parent().get_node_or_null("StunFall")
		if stun != null:
			scene = stun.LAND_PARTICLE_PATH
	var world = get_tree().get_first_node_in_group("world")
	if scene != null and world != null:
		var p = scene.instantiate()
		p.global_position = PLAYER.global_position + Vector2(0.0, 5.0 * PLAYER.gravity_dir)
		p.rotation = 0.0 if PLAYER.gravity_dir > 0.0 else PI
		world.add_child(p)
