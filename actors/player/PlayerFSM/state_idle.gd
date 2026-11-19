extends "res://systems/FSM/State.gd"
class_name StateIdle

#@export var PLAYER : Player

func enterState():
	pass

func updateState(delta : float):
	# Gentle coast. Holding Brake while still moving hands over to the Break state.
	PLAYER.velocity.x = move_toward(PLAYER.velocity.x, 0, PLAYER.COAST_DECEL * delta)
	determine_direction()
	
	if Input.is_action_pressed("charge"):
		transition.emit(self, "Charge")
	elif Input.is_action_pressed("break") and abs(PLAYER.velocity.x) > PLAYER.BRAKE_MIN_SPEED:
		transition.emit(self, "Break")
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
