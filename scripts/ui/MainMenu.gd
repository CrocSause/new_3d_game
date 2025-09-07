extends Control

@onready var start_btn: Button   = %StartButton
@onready var options_btn: Button = %OptionsButton
@onready var credits_btn: Button = %CreditsButton
@onready var quit_btn: Button    = %QuitButton

var options_popup: PopupPanel = null  # will be resolved in _ready()

const SAVE_PATH := "user://save_slot_0.save"

var _has_save: bool = false
var _start_popup: PopupMenu

func _ready() -> void:
	# Mouse visible on menus
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Resolve Options popup by unique name (supports either OptionsMenu or Options)
	if has_node("%OptionsMenu"):
		options_popup = %OptionsMenu
		options_popup.visible = false
		options_popup.hide()  # PopupPanel-specific hide method
		print("Options menu hidden on startup")
	elif has_node("%Options"):
		options_popup = %Options
	else:
		options_popup = null  # optional popup; safe if missing

	# Guard: ensure buttons exist (helpful if names changed)
	if start_btn == null: push_error("MainMenu: StartButton not found")
	if options_btn == null: push_error("MainMenu: OptionsButton not found")
	if credits_btn == null: push_error("MainMenu: CreditsButton not found")
	if quit_btn == null: push_error("MainMenu: QuitButton not found")

	# Connect button signals
	start_btn.pressed.connect(_on_start_pressed)
	options_btn.pressed.connect(_on_options_pressed)
	credits_btn.pressed.connect(_on_credits_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

	# Build the Start popup menu (used only when a save exists)
	_build_start_popup()

	# Detect save, update label/focus
	_refresh_start_state()

	# Default focus for controller/keyboard
	start_btn.grab_focus()

func _build_start_popup() -> void:
	_start_popup = PopupMenu.new()
	_start_popup.name = "StartPopup"
	add_child(_start_popup)
	# IDs: 0 = Continue, 1 = New Game
	_start_popup.add_item("Continue", 0)
	_start_popup.add_item("New Game", 1)
	_start_popup.hide()
	_start_popup.id_pressed.connect(_on_start_popup_id_pressed)

func _refresh_start_state() -> void:
	_has_save = FileAccess.file_exists(SAVE_PATH)
	if _has_save:
		start_btn.text = "CONTINUE"
	else:
		start_btn.text = "START GAME"

func _on_start_pressed() -> void:
	if _has_save:
		# Show popup centered with the two actions
		_start_popup.popup_centered_minsize(Vector2(220, 0))
	else:
		_start_new_game()

func _on_start_popup_id_pressed(id: int) -> void:
	match id:
		0:
			_continue_game()
		1:
			_start_new_game()

func _continue_game() -> void:
	# Placeholder: wire to your SaveSystem.load() later
	WorldManager.request_scene_change(WorldManager.SceneID.TEST_LEVEL)

func _start_new_game() -> void:
	# Optional: delete existing save if you want a clean start
	# if FileAccess.file_exists(SAVE_PATH):
	#     DirAccess.remove_absolute(SAVE_PATH)
	WorldManager.request_scene_change(WorldManager.SceneID.TEST_LEVEL)

func _on_options_pressed() -> void:
	if options_popup:
		options_popup.popup_centered()

func _on_credits_pressed() -> void:
	var text := "A solo project inspired by PS2-era classics.\n\n(Replace this with a proper credits panel later.)"
	get_tree().create_timer(0.01).timeout.connect(func(): OS.alert(text, "Credits"))

func _on_quit_pressed() -> void:
	get_tree().quit()
