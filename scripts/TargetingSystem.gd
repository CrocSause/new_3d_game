# File: scripts/player/TargetingSystem.gd
extends Node3D
class_name TargetingSystem
# Handles Zelda-style lock‑on logic and visual indicators.

@export var lock_range: float = 25.0          # How far to search for targets
@export var indicator_height: float = 1.6     # Offset above target for the marker
@export var max_targets: int = 64             # Hard cap to avoid excessive allocations

var current_target: Node3D = null             # Target currently locked on
var indicator: MeshInstance3D = null          # Visual marker placed on the target
var potential_targets: Array[Node3D] = []     # Cache of targets found in last scan

const TARGET_GROUP := "targetable"            # All valid targets must be in this group
const ENEMY_GROUP := "enemy"
const NPC_GROUP := "npc"
const INTERACT_GROUP := "interactable"

func toggle_lock_on() -> void:
	# Locks onto closest target or clears existing lock.
	if current_target:
		_clear_target()
	else:
		_acquire_new_target()

func cycle_target(step: int) -> void:
	# Switch between cached targets (step = 1 for next, -1 for previous).
	if potential_targets.size() <= 1:
		return
	var idx := potential_targets.find(current_target)
	idx = posmod(idx + step, potential_targets.size())
	_set_target(potential_targets[idx])

func _acquire_new_target() -> void:
	potential_targets = _scan_for_targets()
	if potential_targets.is_empty():
		return
	_set_target(potential_targets[0])

func _scan_for_targets() -> Array[Node3D]:
	# Sphere query that ignores line of sight, useful for obscured targets.
	var space := get_world_3d().direct_space_state
	if space == null:
		push_warning("TargetingSystem: No physics space found")
		return []
	var sphere := SphereShape3D.new()
	sphere.radius = lock_range
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.transform.origin = global_position
	params.collide_with_bodies = true
	params.collide_with_areas = true
	params.exclude = [get_parent()]      # Skip player
	var results := space.intersect_shape(params, max_targets)
	var targets: Array[Node3D] = []
	for result in results:
		var body:= result.collider
		if body.is_in_group(TARGET_GROUP):
			targets.append(body)
	targets.sort_custom(self, "_sort_by_distance")
	return targets

func _sort_by_distance(a: Node3D, b: Node3D) -> bool:
	var origin := global_position
	return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)

func _set_target(target: Node3D) -> void:
	_clear_target()
	current_target = target
	current_target.tree_exited.connect(_on_target_removed)   # Auto-clear if target is deleted
	_create_indicator(target)
	set_physics_process(true)                               # Only process when locked

func _create_indicator(target: Node3D) -> void:
	# Simple billboarded quad as a marker; swap for your own texture/scene if desired.
	indicator = MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * 0.5
	indicator.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.unshaded = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	indicator.material_override = mat
	indicator.position = Vector3.UP * indicator_height
	target.add_child(indicator)
	_update_indicator_color(target)

func _update_indicator_color(target: Node3D) -> void:
	var mat := indicator.material_override as StandardMaterial3D
	if target.is_in_group(ENEMY_GROUP):
		mat.albedo_color = Color.RED
	elif target.is_in_group(NPC_GROUP):
		mat.albedo_color = Color.CYAN
	elif target.is_in_group(INTERACT_GROUP):
		mat.albedo_color = Color.YELLOW
	else:
		mat.albedo_color = Color.WHITE

func _on_target_removed() -> void:
	_clear_target()

func _clear_target() -> void:
	if indicator and indicator.is_inside_tree():
		indicator.queue_free()
	indicator = null
	if current_target and current_target.is_connected("tree_exited", Callable(self, "_on_target_removed")):
		current_target.tree_exited.disconnect(_on_target_removed)
	current_target = null
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	# Keeps player facing target; remove if undesired.
	if not current_target:
		set_physics_process(false)
		return
	var parent := get_parent() as Node3D
	if not parent or not is_instance_valid(current_target):
		_clear_target()
		return
	parent.look_at(current_target.global_position, Vector3.UP)
