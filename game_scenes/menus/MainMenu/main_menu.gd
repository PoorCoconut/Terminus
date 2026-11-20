extends CanvasLayer

@onready var button_play: TextureButton = %Button_Play
@onready var button_settings: TextureButton = %Button_Settings
@onready var button_credits: Button = %Button_Credits
@onready var button_exit: Button = %Button_Exit

@onready var slider_ma_vol: HSlider = %Slider_MaVol
@onready var slider_mu_vol: HSlider = %Slider_MuVol
@onready var slider_s_vol: HSlider = %Slider_SVol

@onready var timer_label: Label = %TimerLabel
@export var player : Player

@export_file("*.tscn") var next_level_path : String

func _ready() -> void:
	show()
	slider_ma_vol.value = SettingsManager.master_vol
	slider_mu_vol.value = SettingsManager.music_vol
	slider_s_vol.value = SettingsManager.sfx_vol
	
	await get_tree().process_frame
	await get_tree().physics_frame
	
	get_tree().paused = true

func _process(_delta: float) -> void:
	timer_label.text = GameManager.get_formatted_time()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			resume_game()
		else:
			pause_game()

func pause_game() -> void:
	if player:
		GameManager.save_player_position(player.global_position)
	get_tree().paused = true
	GameManager.stop_timer(true)
	show()

func resume_game() -> void:
	hide()
	get_tree().paused = false
	GameManager.start_timer()

func _on_button_play_pressed() -> void:
	resume_game()

func _on_button_settings_pressed() -> void:
	%SettingsContainer.show()

func _on_button_credits_pressed() -> void:
	pass

func _on_button_exit_pressed() -> void:
	get_tree().quit()

func _on_back_button_pressed() -> void:
	%SettingsContainer.hide()
	%WarningLabel.hide()
	%NukeButton.hide()
	%ResetButton.show()

func _on_reset_button_pressed() -> void:
	%WarningLabel.show()
	%NukeButton.show()
	%ResetButton.hide()

func _on_slider_ma_vol_value_changed(value: float) -> void:
	SettingsManager.master_vol = value
	SettingsManager.save_settings()

func _on_slider_mu_vol_value_changed(value: float) -> void:
	SettingsManager.music_vol = value
	SettingsManager.save_settings()

func _on_slider_s_vol_value_changed(value: float) -> void:
	SettingsManager.sfx_vol = value
	SettingsManager.save_settings()

func _on_nuke_button_pressed() -> void:
	# 1. Reset confirmation UI
	%WarningLabel.hide()
	%NukeButton.hide()
	%ResetButton.show()
	
	# 2. Reset Audio
	SettingsManager.master_vol = 1.0
	SettingsManager.music_vol = 1.0
	SettingsManager.sfx_vol = 1.0
	SettingsManager.save_settings()
	
	slider_ma_vol.value = SettingsManager.master_vol
	slider_mu_vol.value = SettingsManager.music_vol
	slider_s_vol.value = SettingsManager.sfx_vol
	
	# 3. Reset Keybinds
	SettingsManager.reset_keybinds_to_default()
	
	# 4. Wipe save file, cached player position, AND GameManager.elapsed_time
	GameManager.delete_save()
	
	# 5. Reload the scene so the Player & Camera physically reset to the start
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_button_1080p_pressed() -> void:
	print("CLICKED 1080p BUTTON")
	DisplayServer.window_set_size(Vector2i(1980, 1080))

func _on_button_720p_pressed() -> void:
	print("CLICKED 720p BUTTON")
	DisplayServer.window_set_size(Vector2i(1280, 720))

func _on_button_540p_pressed() -> void:
	print("CLICKED 540p BUTTON")
	DisplayServer.window_set_size(Vector2i(990, 540))

func _on_button_windowed_pressed() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_button_fullscreen_pressed() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _on_button_exclusive_fullscreen_pressed() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

##CONTROLS SETTINGS AND STUFF
@onready var action_list_container : GridContainer = %RebindContainer
func _on_controls_reset_pressed() -> void:
	SettingsManager.reset_keybinds_to_default()
