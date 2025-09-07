# File: scripts/player/TargetingSystem.gd
extends Node3D
class_name TargetingSystem

@export var lock_range: float = 15.0
@export var indicator_height: float = 1.6

var current_target: Node3D = null
var indicator: MeshInstance3D = null

signal target_acquired(target: Node3D)
signal target_lost

func toggle_lock_on() -> void:
	if current_target and is_instance_valid(current_target):
		_clear_target()
	else:
		_acquire_new_target()

func cycle_target(direction: int) -> void:
	# Simple cycle - just find next/previous target
	var targets = _get_valid_targets()
	if targets.size() <= 1:
		return
	
	var current_index = -1
	if current_target and is_instance_valid(current_target):
		current_index = targets.find(current_target)
	
	var new_index: int
	if current_index == -1:
		new_index = 0
	else:
		new_index = (current_index + direction) % targets.size()
		if new_index < 0:
			new_index = targets.size() - 1
	
	if new_index < targets.size():
		_set_target(targets[new_index])

func is_locked_on() -> bool:
	return current_target != null and is_instance_valid(current_target)

func get_current_target() -> Node3D:
	if current_target and is_instance_valid(current_target):
		return current_target
	else:
		_clear_target()
		return null

func should_override_camera() -> bool:
	return false  # Disable camera override for now

func _acquire_new_target() -> void:
	var targets = _get_valid_targets()
	if targets.size() > 0:
		_set_target(targets[0])

func _get_valid_targets() -> Array[Node3D]:
	var valid_targets: Array[Node3D] = []
	var origin = global_position
	
	# Get all potential targets
	var all_enemies = get_tree().get_nodes_in_group("enemy")
	var all_targetable = get_tree().get_nodes_in_group("targetable")
	
	# Combine and deduplicate
	var all_targets = {}
	for enemy in all_enemies:
		if enemy != get_parent() and is_instance_valid(enemy) and enemy is Node3D:
			all_targets[enemy] = true
	for target in all_targetable:
		if target != get_parent() and is_instance_valid(target) and target is Node3D:
			all_targets[target] = true
	
	# Filter by range and validate
	for target in all_targets.keys():
		if not is_instance_valid(target):
			continue
		var target_node = target as Node3D
		if origin.distance_to(target_node.global_position) <= lock_range:
			valid_targets.append(target_node)
	
	# Sort by distance
	valid_targets.sort_custom(Callable(self, "_sort_by_distance"))
	return valid_targets

func _sort_by_distance(a: Node3D, b: Node3D) -> bool:
	if not is_instance_valid(a) or not is_instance_valid(b):
		return false
	var origin = global_position
	return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)

func _set_target(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	
	var was_locked = current_target != null
	_clear_target()
	
	current_target = target
	_create_indicator(target)
	
	if was_locked:
		print("Target changed to: ", target.name)
	else:
		target_acquired.emit(target)
		print("Locked onto: ", target.name)

func _create_indicator(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	
	# Simple indicator
	indicator = MeshInstance3D.new()
	var mesh = QuadMesh.new()
	mesh.size = Vector2.ONE * 0.6
	indicator.mesh = mesh
	
	# Simple material
	var mat = StandardMaterial3D.new()
	mat.flags_unshaded = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color.RED
	# Remove the problematic modulate line - not needed in Godot 4
	
	indicator.material_override = mat
	indicator.position = Vector3.UP * indicator_height
	
	# Add to target safely
	if target.has_method("add_child"):
		target.add_child(indicator)

func _clear_target() -> void:
	if indicator and is_instance_valid(indicator):
		indicator.queue_free()
	indicator = null
	
	if current_target:
		print("Lock-on cleared")
		current_target = null
		target_lost.emit()

func _physics_process(_delta: float) -> void:
	# Just validate current target
	if current_target and not is_instance_valid(current_target):
		_clear_target()
		return
	
	if current_target:
		var distance = global_position.distance_to(current_target.global_position)
		if distance > lock_range * 1.5:  # Give some buffer
			_clear_target()
