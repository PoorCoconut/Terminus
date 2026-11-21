extends Node2D

@onready var cam : Camera2D = $WorldCameraComponent

func _ready() -> void:
	Events.file_deleted.connect(_update_camera)
	cam.enabled = GameManager.cam_enabled
	print("Game Manager cam enabled is: ", GameManager.cam_enabled)

func _on_camera_locker_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		cam.enabled = true

func _update_camera():
	print("camera disabled")
	cam.enabled = false
