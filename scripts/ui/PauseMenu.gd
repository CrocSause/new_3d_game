extends Control
class_name PauseMenu

# Simple pause overlay - just a label and semi-transparent background
@onready var background: ColorRect = $Background
@onready var pause_label: Label = $PauseLabel

var is_paused: bool = false

func _ready():
	# Must work when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 10
	visible = false
	
	# Create background if it doesn't exist
	if not background:
		background = ColorRect.new()
		background.name = "Background"
		background.color = Color(0, 0, 0, 0.5)  # Semi-transparent black
		background.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(background)
		move_child(background, 0)  # Send to back
	
	# Create label if it doesn't exist
	if not pause_label:
		pause_label = Label.new()
		pause_label.name = "PauseLabel"
		pause_label.text = "PAUSED\nPress P to Resume"
		pause_label.add_theme_font_size_override("font_size", 48)
		pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pause_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(pause_label)

func _input(event: InputEvent):
	# Toggle pause on P key
	if event.is_action_pressed("pause"):  # We'll add this to Input Map
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause():
	set_pause_state(not is_paused)

func set_pause_state(paused: bool):
	if is_paused == paused:
		return
	
	is_paused = paused
	visible = paused
	get_tree().paused = paused
	
	if paused:
		# Don't change mouse mode - let player keep control
		print("Game paused (P to resume)")
	else:
		print("Game resumed")

# Public API
func force_unpause():
	if is_paused:
		set_pause_state(false)
