extends CharacterBody3D
class_name PlayerController

# Core movement settings
@export var walk_speed: float = 4.5
@export var run_speed: float = 8.0
@export var crouch_speed: float = 2.0
@export var jump_velocity: float = 5.0
@export var mouse_sensitivity: float = 0.004

# Combat settings
@export var melee_damage: float = 25.0
@export var melee_range: float = 2.0
@export var dodge_distance: float = 5.0
@export var dodge_cooldown: float = 0.8
@export var block_reduction: float = 0.5

# Camera settings
@export var lock_smoothing_speed: float = 12.0

# References
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var mesh_pivot: Node3D = $MeshPivot
@onready var player_mesh: MeshInstance3D = $MeshPivot/PlayerMesh
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var melee_area: Area3D = $MeleeArea
@onready var interaction_raycast: RayCast3D = $CameraPivot/InteractionRaycast
@onready var targeting_system: TargetingSystem = $TargetingSystem

# State variables
var is_in_combat: bool = false
var health: float = 100.0
var max_health: float = 100.0
var equipped_weapon: String = "fists"
var is_dead: bool = false
var can_capture_mouse: bool = true  # guards click-to-recapture (future pause-safe)

# Movement state
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Combat state
var is_attacking: bool = false
var is_dodging: bool = false
var is_blocking: bool = false
var can_dodge: bool = true

# Camera lock-on state
var lock_on_active: bool = false

# Input buffering
var input_buffer: Dictionary = {}
var buffer_window: float = 0.12

func _ready():
	capture_mouse()
	animation_tree.active = true
	
	# Add player to group for exclusion in targeting
	add_to_group("player")
	
	# Connect melee area
	melee_area.body_entered.connect(_on_melee_target_entered)
	melee_area.body_exited.connect(_on_melee_target_exited)
	
	# Set up interaction raycast
	interaction_raycast.target_position = Vector3(0, 0, -2)
	
	# Connect targeting system signals
	if targeting_system:
		targeting_system.target_acquired.connect(_on_target_acquired)
		targeting_system.target_lost.connect(_on_target_lost)
	
	print("Player initialized with targeting system")

func _input(event: InputEvent) -> void:
	# Don't process input if game is paused
	if get_tree().paused:
		return
		
	# Mouse capture toggle
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			release_mouse()
		else:
			capture_mouse()
		get_viewport().set_input_as_handled()
		return
	
	# Click to capture (only when allowed)
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED \
	and event is InputEventMouseButton and event.pressed \
	and can_capture_mouse:
		capture_mouse()
		get_viewport().set_input_as_handled()
		return

	
	# Mouse look - ONLY when not locked on
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if not lock_on_active:
			# Apply normal mouse look
			rotate_y(-event.relative.x * mouse_sensitivity)
			camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
			camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PI/2, PI/2)
		# If locked on, ignore mouse input entirely - prevents accumulation

func _unhandled_input(event: InputEvent) -> void:
	# Targeting controls
	if event.is_action_pressed("lock_on"):
		if targeting_system:
			targeting_system.toggle_lock_on()
	
	if event.is_action_pressed("cycle_target_right"):
		if targeting_system:
			targeting_system.cycle_target(1)
	
	if event.is_action_pressed("cycle_target_left"):
		if targeting_system:
			targeting_system.cycle_target(-1)
	
	# Buffer combat inputs
	if event.is_action_pressed("attack"):
		_buffer_input("attack")
	if event.is_action_pressed("dodge"):
		_buffer_input("dodge")
	if event.is_action_pressed("block"):
		_buffer_input("block")
	if event.is_action_pressed("interact"):
		_buffer_input("interact")

func _physics_process(delta: float) -> void:
	# Handle movement
	_handle_movement(delta)
	
	# Handle camera lock-on
	_update_camera_lock_on_simple(delta)
	
	# Handle combat mode toggle
	if Input.is_action_just_pressed("toggle_combat"):
		is_in_combat = not is_in_combat
	
	# Process buffered inputs (priority order)
	if _consume_buffered_input("dodge"):
		_try_dodge()
	elif _consume_buffered_input("attack"):
		_try_attack()
	elif _consume_buffered_input("block"):
		_toggle_block()
	elif _consume_buffered_input("interact"):
		_attempt_interaction()
	
	# Apply movement
	move_and_slide()
	
	# Update animations
	_update_animations(delta)
	
	# Update input buffer
	_update_input_buffer(delta)

# Uses Godot Built in look_at function
func _update_camera_lock_on_simple(_delta: float) -> void:
	if not targeting_system or not targeting_system.is_locked_on():
		if lock_on_active:
			lock_on_active = false
			print("Camera lock released")
		return
	
	if not lock_on_active:
		lock_on_active = true
		print("Camera lock engaged")
	
	var target = targeting_system.get_current_target()
	if not target:
		return
	
	# Simple approach: use look_at
	var target_pos = target.global_position
	print("DEBUG SIMPLE: Looking at ", target_pos)
	
	# Look at target (this rotates the entire player)
	look_at(target_pos, Vector3.UP)
	
	# Reset camera pivot to neutral
	camera_pivot.rotation.x = 0

func _handle_movement(delta: float) -> void:
	# Get input
	var input_vec := Vector2(
		int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left")),
		int(Input.is_action_pressed("move_forward")) - int(Input.is_action_pressed("move_back"))
	).normalized()
	
	var run_held := Input.is_action_pressed("run")
	var crouch_held := Input.is_action_pressed("crouch")
	var jump_pressed := Input.is_action_just_pressed("jump")
	
	# Vertical movement
	if is_on_floor():
		if jump_pressed:
			velocity.y = jump_velocity
		else:
			velocity.y = min(velocity.y, 0.0)
	else:
		velocity.y -= gravity * delta
	
	# DON'T override horizontal movement during dodge
	if is_dodging:
		return
	
	# Horizontal movement (only when not dodging)
	var speed: float
	if crouch_held:
		speed = crouch_speed
	elif run_held:
		speed = run_speed
	else:
		speed = walk_speed
	
	# Convert input to world space
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	var movement_dir := (forward * input_vec.y + right * input_vec.x)
	
	if movement_dir.length() > 0.001:
		movement_dir = movement_dir.normalized() * speed
		velocity.x = movement_dir.x
		velocity.z = movement_dir.z
		
		# Rotate mesh in combat for animation flair, but face target when locked on
		if is_in_combat:
			var target_yaw: float
			
			if targeting_system and targeting_system.is_locked_on():
				# Face the locked target
				var target = targeting_system.get_current_target()
				if target:
					var direction_to_target = (target.global_position - global_position)
					direction_to_target.y = 0
					direction_to_target = direction_to_target.normalized()
					target_yaw = atan2(direction_to_target.x, direction_to_target.z)
			else:
				# Face movement direction
				target_yaw = atan2(movement_dir.x, movement_dir.z)
			
			mesh_pivot.rotation.y = lerp_angle(mesh_pivot.rotation.y, target_yaw, 15.0 * delta)
	else:
		velocity.x = 0
		velocity.z = 0

# Targeting system callbacks
func _on_target_acquired(target: Node3D) -> void:
	print("Target acquired: ", target.name)
	is_in_combat = true

func _on_target_lost() -> void:
	print("Target lost")
	await get_tree().create_timer(2.0).timeout
	if targeting_system and not targeting_system.is_locked_on():
		is_in_combat = false

func _try_attack() -> bool:
	if is_attacking or is_dodging:
		return false
	
	is_attacking = true
	_start_attack_animation()
	
	# Attack coroutine
	_attack_sequence()
	return true

func _attack_sequence() -> void:
	# Strike window timing
	await get_tree().create_timer(0.4).timeout
	_check_melee_targets()
	
	# Attack finish timing
	await get_tree().create_timer(0.4).timeout
	is_attacking = false

func _try_dodge() -> bool:
	if not can_dodge or is_dodging:
		print("Dodge blocked - can_dodge: ", can_dodge, ", is_dodging: ", is_dodging)
		return false
	
	print("Starting dodge...")
	is_dodging = true
	can_dodge = false
	
	# Get dodge direction based on current input
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	print("Input direction: ", input_dir)
	
	var dodge_direction: Vector3
	
	if input_dir.length() > 0.1:
		# Convert input to world space direction
		var forward := -global_transform.basis.z
		var right := global_transform.basis.x
		# Note: input_dir.y is negative for forward, so we negate it
		var world_dir: Vector3 = (forward * -input_dir.y + right * input_dir.x).normalized()
		dodge_direction = world_dir
		print("Dodge direction (input-based): ", dodge_direction)
	else:
		# No input - dodge backward
		dodge_direction = global_transform.basis.z
		print("Dodge direction (backward): ", dodge_direction)
	
	dodge_direction.y = 0
	dodge_direction = dodge_direction.normalized()
	
	# Apply immediate dodge velocity burst
	var dodge_velocity = dodge_direction * dodge_distance * 5.0
	velocity.x = dodge_velocity.x
	velocity.z = dodge_velocity.z
	print("Applied dodge velocity: ", Vector2(velocity.x, velocity.z))
	
	_start_dodge_animation()
	
	# Dodge sequence
	_dodge_sequence()
	return true

func _dodge_sequence() -> void:
	print("Dodge sequence started")
	# Apply friction during dodge so you don't slide forever
	var initial_dodge_time = 0.15  # Strong dodge movement
	var fade_time = 0.25          # Friction fade period
	
	await get_tree().create_timer(initial_dodge_time).timeout
	print("Initial dodge phase complete, starting fade...")
	
	# Gradually reduce dodge velocity
	var fade_tween = create_tween()
	fade_tween.tween_method(_apply_dodge_friction, 1.0, 0.0, fade_time)
	
	await fade_tween.finished
	print("Dodge movement complete")
	is_dodging = false
	
	# Dodge cooldown
	await get_tree().create_timer(dodge_cooldown).timeout
	print("Dodge cooldown complete")
	can_dodge = true

func _apply_dodge_friction(strength: float) -> void:
	# Gradually reduce horizontal velocity during dodge fade
	velocity.x *= (0.85 * strength + 0.15)  # Keep some momentum
	velocity.z *= (0.85 * strength + 0.15)
	
	# Debug output every few frames
	if Engine.get_process_frames() % 5 == 0:
		print("Friction applied - strength: ", strength, " velocity: ", Vector2(velocity.x, velocity.z))

func _toggle_block() -> void:
	if is_dodging or is_attacking:
		return
	
	is_blocking = not is_blocking
	
	if is_blocking:
		print("BLOCKING ACTIVE - Damage reduced by ", int(block_reduction * 100), "%")
	else:
		print("Blocking disabled")

func _check_melee_targets() -> void:
	var targets = melee_area.get_overlapping_bodies()
	for target in targets:
		if target.has_method("take_damage_from_player") and target != self:
			var damage = melee_damage
			match equipped_weapon:
				"pipe": damage *= 1.2
				"knife": damage *= 1.5
				"fists": damage *= 0.8
			target.take_damage_from_player(damage, global_position)
		elif target.has_method("take_damage") and target != self:
			var damage = melee_damage
			target.take_damage(damage)

func _attempt_interaction() -> void:
	if interaction_raycast.is_colliding():
		var collider = interaction_raycast.get_collider()
		if collider and collider.has_method("interact"):
			collider.interact(self)

func _update_animations(_delta: float) -> void:
	if not animation_tree:
		return
	
	# Movement blend
	var velocity_length = Vector2(velocity.x, velocity.z).length()
	var speed_ratio = clamp(velocity_length / walk_speed, 0.0, 1.0)
	animation_tree.set("parameters/movement_blend/blend_amount", speed_ratio)
	
	# Combat blend
	if not is_attacking and not is_dodging:
		animation_tree.set("parameters/combat_blend/blend_amount", 0.3 if is_in_combat else 0.0)

func _start_attack_animation() -> void:
	if animation_tree:
		animation_tree.set("parameters/combat_blend/blend_amount", 1.0)
		animation_tree.set("parameters/action_state/transition_request", "attack")

func _start_dodge_animation() -> void:
	if animation_tree:
		animation_tree.set("parameters/combat_blend/blend_amount", 1.0)
		animation_tree.set("parameters/action_state/transition_request", "dodge")

# Input buffering system
func _buffer_input(action: String) -> void:
	input_buffer[action] = buffer_window

func _consume_buffered_input(action: String) -> bool:
	if input_buffer.has(action) and input_buffer[action] > 0.0:
		input_buffer.erase(action)
		return true
	return false

func _update_input_buffer(delta: float) -> void:
	var to_remove: Array = []
	# iterate over a snapshot so erasing can't invalidate the iterator
	for action in input_buffer.keys().duplicate():
		input_buffer[action] -= delta
		if input_buffer[action] <= 0.0:
			to_remove.append(action)
	for action in to_remove:
		input_buffer.erase(action)

# Damage system
func take_damage(damage: float) -> void:
	if is_dead:
		return
		
	var reduced_damage = damage
	if is_blocking:
		reduced_damage = damage * block_reduction
		print("BLOCKED! Damage reduced from ", damage, " to ", reduced_damage)
	else:
		print("Hit for full damage: ", reduced_damage)
	
	health -= reduced_damage
	health = max(0, health)
	
	if health <= 0:
		_handle_death()

func _handle_death() -> void:
	if is_dead:
		return
		
	is_dead = true
	print("Player died!")
	
	# Clear targeting when dead
	if targeting_system:
		targeting_system._clear_target()
	
	# Disable player input and movement
	set_physics_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	
	# Visual death effect
	var death_tween = create_tween()
	death_tween.parallel().tween_property(mesh_pivot, "rotation", Vector3(-PI/2, 0, 0), 1.0)
	death_tween.parallel().tween_property(mesh_pivot, "scale", Vector3(1.0, 0.2, 1.0), 1.0)
	
	# Wait, then respawn (for testing)
	await get_tree().create_timer(3.0).timeout
	_respawn()

func _respawn():
	"""Respawn the player (basic implementation)"""
	health = max_health
	is_dead = false
	
	# Reset visual state
	mesh_pivot.rotation = Vector3.ZERO
	mesh_pivot.scale = Vector3.ONE
	
	# Re-enable systems
	set_physics_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)
	
	velocity = Vector3.ZERO
	print("Player respawned!")

func is_alive() -> bool:
	return not is_dead

func equip_weapon(weapon_name: String) -> void:
	equipped_weapon = weapon_name
	print("Equipped weapon: ", weapon_name)

func _on_melee_target_entered(_body) -> void:
	pass

func _on_melee_target_exited(_body) -> void:
	pass

func capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# Called by WorldManager in the future
func set_game_paused(paused: bool) -> void:
	can_capture_mouse = not paused
	if paused:
		release_mouse()
	else:
		# optional: auto-capture when resuming gameplay
		capture_mouse()

