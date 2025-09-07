# File: scripts/ui/PauseMenu.gd
extends Control
class_name PauseMenu

@onready var resume_btn: Button = %ResumeButton
@onready var options_btn: Button = %OptionsButton  
@onready var main_menu_btn: Button = %MainMenuButton
@onready var quit_btn: Button = %QuitButton

var options_popup: PopupPanel = null
var is_paused: bool = false

func _ready():
	# CRITICAL: Set process mode to continue working when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Hide initially
	visible = false
	
	# Set higher process priority to intercept input first
	process_priority = 10
	
	# Resolve options popup
	if has_node("%OptionsMenu"):
		options_popup = %OptionsMenu
		# Make sure options popup also works when paused
		options_popup.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect buttons
	resume_btn.pressed.connect(_on_resume_pressed)
	options_btn.pressed.connect(_on_options_pressed)
	main_menu_btn.pressed.connect(_on_main_menu_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

func _input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):  # Use existing ui_cancel mapping
		if is_paused:
			# If paused, resume game
			_set_pause_state(false)
		else:
			# If not paused, pause game
			_set_pause_state(true)
		get_viewport().set_input_as_handled()

func toggle_pause():
	is_paused = !is_paused
	_set_pause_state(is_paused)

func _set_pause_state(paused: bool):
	is_paused = paused
	visible = paused
	
	print("Setting pause state to: ", paused)  # Debug output
	
	# Notify WorldManager
	if WorldManager:
		WorldManager.set_game_paused(paused)
	
	# Handle mouse cursor
	if paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		resume_btn.grab_focus()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Pause game tree (exclude UI processing)
	get_tree().paused = paused
	
	print("Game tree paused: ", get_tree().paused)  # Debug output
	print("PauseMenu visible: ", visible)  # Debug output

func _on_resume_pressed():
	_set_pause_state(false)

func _on_options_pressed():
	if options_popup:
		options_popup.popup_centered()

func _on_main_menu_pressed():
	_set_pause_state(false)
	WorldManager.request_scene_change(WorldManager.SceneID.MAIN_MENU)

func _on_quit_pressed():
	get_tree().quit()
