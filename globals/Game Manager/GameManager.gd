extends Node

var CURRENT_WORLD_STATE : String = "Nothing"
const SAVE_PATH : String = "user://savegame.json"

## TIMER & SAVE STATE
var elapsed_time : float = 0.0
var is_timer_running : bool = false
var saved_player_pos = null # Holds Vector2 or null

func _ready() -> void:
	load_game()
	print("GAME MANAGER LOADED!")

func _process(delta: float) -> void:
	if is_timer_running:
		elapsed_time += delta

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		stop_timer(true)

## TIMER CONTROLS
func start_timer() -> void:
	is_timer_running = true

func stop_timer(should_save: bool = true) -> void:
	is_timer_running = false
	if should_save:
		save_game()

func get_formatted_time() -> String:
	var total_seconds: int = int(elapsed_time)
	var hours: int = total_seconds / 3600
	var minutes: int = (total_seconds % 3600) / 60
	var seconds: int = total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]

## SAVE FILE LOGIC
func save_game(player_pos = null) -> void:
	if player_pos != null:
		saved_player_pos = player_pos
	
	var save_data = {
		"elapsed_time": elapsed_time
	}
	
	if saved_player_pos != null:
		save_data["player_x"] = saved_player_pos.x
		save_data["player_y"] = saved_player_pos.y
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data, "\t"))
	print("Game Saved!")

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found. Starting from the bottom!")
		elapsed_time = 0.0
		saved_player_pos = null
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var save_data = JSON.parse_string(file.get_as_text())
	
	if save_data:
		elapsed_time = save_data.get("elapsed_time", 0.0)
		if save_data.has("player_x") and save_data.has("player_y"):
			saved_player_pos = Vector2(save_data["player_x"], save_data["player_y"])

func delete_save() -> void:
	is_timer_running = false
	elapsed_time = 0.0
	saved_player_pos = null
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("Save file deleted!")

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

# Wrappers so your existing Player script calls still work seamlessly
func save_player_position(player_pos: Vector2) -> void:
	save_game(player_pos)

func load_player_position():
	return saved_player_pos

## Next Level Helper Functions
func load_next_level(next_level_path : String) -> void:
	await ScreenTransition.trans_in().finished
	LoadingScreen.load_level(next_level_path)

## Camera Helper Functions
func do_camera_shake(intensity:float, time:float):
	if get_tree().get_first_node_in_group("camera"):
		var camera = get_tree().get_first_node_in_group("camera")
		var camera_tween = get_tree().create_tween()
		camera_tween.tween_method(camera.startCameraShake, intensity, 1.0, time)
		camera.startCameraShake(intensity)
		await get_tree().create_timer(time).timeout
		if camera:
			camera.resetCameraOffset()

func move_camera_to_player(player_pos : Vector2):
	if get_tree().get_first_node_in_group("camera"):
		var camera = get_tree().get_first_node_in_group("camera")
		camera.moveCameraToEntity(player_pos)
