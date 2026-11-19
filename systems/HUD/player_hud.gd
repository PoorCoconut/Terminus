extends Node2D

@onready var white_bar = %WhiteBar    # Bottom layer: black Under + white Progress
@onready var main_bar = %BarChaser    # Top layer: NO Under + white Progress (tinted)

@export var chase_speed: float = 1.5   # Lower = slower drain
@export var hold_duration: float = 0.5 # Seconds to pause at peak before draining

var hold_timer: float = 0.0
var fade_tween: Tween
var is_faded: bool = false

func _ready():
	white_bar.step = 0.0
	white_bar.rounded = false
	main_bar.step = 0.0
	main_bar.rounded = false
	Events.brake_gauge_updated.connect(_on_brake_gauge_updated)

func _process(delta: float):
	if hold_timer > 0.0:
		hold_timer -= delta
		return
	if white_bar.value > main_bar.value:
		var next_val = lerp(white_bar.value, main_bar.value, 1.0 - exp(-chase_speed * delta))
		if abs(next_val - main_bar.value) < 0.5:
			white_bar.value = main_bar.value
		else:
			white_bar.value = next_val

func _on_brake_gauge_updated(current_heat: float, max_heat: float):
	main_bar.max_value = max_heat
	white_bar.max_value = max_heat
	
	main_bar.value = current_heat
	main_bar.tint_progress = Color.GREEN.lerp(Color.RED, current_heat / max_heat)
	
	# While heat is rising, snap the white bar and reset the hang timer
	if current_heat >= white_bar.value:
		white_bar.value = current_heat
		hold_timer = hold_duration
	
	# Handle container fade
	var should_fade = current_heat < 50.0
	if should_fade != is_faded:
		is_faded = should_fade
		if fade_tween:
			fade_tween.kill()
		fade_tween = create_tween()
		var target_alpha = 0.3 if is_faded else 1.0
		fade_tween.tween_property($BarContainer, "modulate:a", target_alpha, 0.3)
