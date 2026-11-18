extends "res://systems/FSM/State.gd"
class_name StateIdle

#@export var PLAYER : Player

func enterState():
	pass

func updateState(delta : float):
	# Decelerating: Brake held = hard stop, otherwise gentle coast
	var decel = PLAYER.BRAKE_DECEL if Input.is_action_pressed("break") else PLAYER.COAST_DECEL
	PLAYER.velocity.x = move_toward(PLAYER.velocity.x, 0, decel * delta)
	determine_direction()
	
	if Input.is_action_pressed("charge"):
		transition.emit(self, "Charge")
	if !PLAYER.is_on_floor():
		transition.emit(self, "Fall")
	PLAYER.move_and_slide()

func determine_direction():
	if Input.is_action_pressed("look_left"):
		%Sprite.flip_h = true
		PLAYER.direction = -1
	elif Input.is_action_pressed("look_right"):
		%Sprite.flip_h = false
		PLAYER.direction = 1
