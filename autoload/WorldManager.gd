extends Node

signal scene_will_change(target_id: int)
signal scene_changed(current_id: int)
signal game_paused(paused: bool)  # reserved for the pause menu phase

enum SceneID {
	MAIN_MENU,
	TEST_LEVEL,
	# Add more as needed: HUB, DUNGEON_01, etc.
}

# Map your logical IDs to scene paths (edit these to match your project)
const SCENES := {
	SceneID.MAIN_MENU: "res://scenes/ui/main_menu.tscn",
	SceneID.TEST_LEVEL: "res://scenes/levels/test_level.tscn",
}

var _current_scene_id: int = -1
var _current_level: Node = null
var _is_loading: bool = false

# Persistent parent for the active level
var _level_root: Node3D

# Simple transition overlay
var _overlay_layer: CanvasLayer
var _fade_rect: ColorRect

func _ready() -> void:
	# Create a predictable parent for 3D levels
	_level_root = Node3D.new()
	_level_root.name = "LevelRoot"
	add_child(_level_root)

	# Build a simple fade overlay
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "TransitionOverlay"
	add_child(_overlay_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "Fade"
	_fade_rect.color = Color(0, 0, 0, 0) # transparent initially
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(_fade_rect)

	# Make sure the fade fills the screen and updates with resizes
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Optional: boot directly into a scene at startup (comment out if you prefer manual control)
	await request_scene_change(SceneID.MAIN_MENU)

func request_scene_change(target_id: int, with_transition: bool = true) -> void:
	if _is_loading:
		return
	if not SCENES.has(target_id):
		push_error("WorldManager: Unknown scene id: %s" % str(target_id))
		return
	var path: String = SCENES[target_id]
	_is_loading = true
	scene_will_change.emit(target_id)
	await _swap_scene(path, target_id, with_transition)
	_is_loading = false
	scene_changed.emit(target_id)

func reload_current_scene(with_transition: bool = true) -> void:
	if _current_scene_id == -1:
		return
	await request_scene_change(_current_scene_id, with_transition)

# -----------------------
# Internals
# -----------------------
func _fade_to(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", clamp(alpha, 0.0, 1.0), duration)
	await tween.finished

func _swap_scene(scene_path: String, target_id: int, with_transition: bool) -> void:
	if with_transition:
		await _fade_to(1.0, 0.2)  # Fade to black

	# Unload previous level (if any)
	if is_instance_valid(_current_level):
		_current_level.queue_free()
		_current_level = null
		# Let the tree process the free before loading the next scene
		await get_tree().process_frame

	# Load new scene (sync is fine; fade hides any micro-stutter)
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("WorldManager: Failed to load scene at path: %s" % scene_path)
		if with_transition:
			await _fade_to(0.0, 0.2)  # recover
		return

	var instance := packed.instantiate()
	_level_root.add_child(instance)
	_current_level = instance
	_current_scene_id = target_id

	if with_transition:
		await _fade_to(0.0, 0.2)  # Fade back in

# (Optional) Expose current info for UI or debug
func get_current_scene_id() -> int:
	return _current_scene_id

func is_loading() -> bool:
	return _is_loading
