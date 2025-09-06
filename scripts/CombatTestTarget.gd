extends CharacterBody3D
class_name CombatTestTarget

# Enhanced Combat Test Target with Patrol AI

# ===== EXISTING COMBAT PROPERTIES =====
@export_group("Combat Settings")
@export var max_health: float = 50.0
@export var hit_flash_duration: float = 0.2
@export var knockback_force: float = 8.0
@export var stagger_duration: float = 0.4
@export var attack_damage: float = 15.0
@export var attack_range: float = 2.5
@export var attack_cooldown: float = 1.5
@export var attack_windup_time: float = 0.8
@export var attack_recovery_time: float = 0.5

# ===== NEW PATROL PROPERTIES =====
@export_group("Patrol Settings")
@export var patrol_speed: float = 2.0
@export var patrol_points: Array[Vector3] = []
@export var wait_time_at_point: float = 2.0
@export var detection_range: float = 8.0
@export var patrol_enabled: bool = true
@export var auto_generate_patrol: bool = true

# ===== EXISTING COMPONENT REFERENCES =====
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var health_bar: ProgressBar = $UI/HealthBar
@onready var damage_label: Label3D = $DamageLabel3D

# ===== NEW COMPONENT REFERENCES =====
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var detection_area: Area3D = $DetectionArea
@onready var detection_shape: CollisionShape3D = $DetectionArea/DetectionShape
@onready var attack_area: Area3D = $AttackArea
@onready var attack_shape: CollisionShape3D = $AttackArea/AttackShape

# ===== AI STATE SYSTEM =====
enum AIState {
	PATROL,
	WAITING,
	ALERT,
	COMBAT,
	STUNNED
}

var current_state: AIState = AIState.PATROL
var current_patrol_index: int = 0
var wait_timer: float = 0.0
var player_reference: Node3D = null
var original_position: Vector3

# ===== EXISTING COMBAT VARIABLES =====
var health: float
var original_material: Material
var hit_material: StandardMaterial3D
var is_staggered: bool = false
var attack_timer: float = 0.0
var is_attacking: bool = false
var attack_target: Node3D = null
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	# ===== EXISTING COMBAT INITIALIZATION =====
	health = max_health
	_setup_materials()
	_update_health_bar()
	
	# Create red hit flash material
	hit_material = StandardMaterial3D.new()
	hit_material.albedo_color = Color.RED
	hit_material.emission_enabled = true
	hit_material.emission = Color.RED * 0.3
	
	# ===== NEW PATROL INITIALIZATION =====
	original_position = global_position
	
	# Set up navigation agent
	if navigation_agent:
		navigation_agent.path_desired_distance = 0.5
		navigation_agent.target_desired_distance = 0.5
	
	# Set up detection area
	if detection_area and detection_shape:
		_setup_detection_area()
		detection_area.body_entered.connect(_on_player_detected)
		detection_area.body_exited.connect(_on_player_lost)
	
	# Set up patrol points
	if auto_generate_patrol and patrol_points.is_empty():
		_generate_default_patrol_points()
	
	# Start patrol after a brief delay for navigation to initialize
	call_deferred("_start_patrol")
	
	_setup_attack_area()

func _setup_detection_area():
	"""Set up the detection area for player awareness"""
	if detection_shape.shape == null:
		var sphere_shape = SphereShape3D.new()
		sphere_shape.radius = detection_range
		detection_shape.shape = sphere_shape
	else:
		# Update existing shape radius
		var shape = detection_shape.shape as SphereShape3D
		if shape:
			shape.radius = detection_range

func _generate_default_patrol_points():
	"""Generate default patrol points in a square around spawn"""
	var offset = 4.0
	patrol_points = [
		original_position + Vector3(offset, 0, 0),
		original_position + Vector3(offset, 0, offset),
		original_position + Vector3(-offset, 0, offset),
		original_position + Vector3(-offset, 0, -offset),
		original_position
	]
	print("Generated default patrol points for ", name)

func _start_patrol():
	"""Initialize patrol behavior"""
	if patrol_points.size() > 0 and patrol_enabled:
		current_state = AIState.PATROL
		_set_next_patrol_target()
		print(name, " started patrolling")

# ===== MODIFIED PHYSICS PROCESS =====
func _physics_process(delta):
	"""Handle physics and AI - extends your existing physics"""
	# ===== EXISTING PHYSICS =====
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Apply friction to horizontal movement (existing)
	if current_state != AIState.PATROL:  # Don't apply friction during patrol movement
		velocity.x = move_toward(velocity.x, 0.0, delta * 15.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 15.0)
	
	# ===== NEW AI BEHAVIOR =====
	_update_ai_state(delta)
	
	# ===== EXISTING PHYSICS =====
	move_and_slide()

# ===== NEW AI STATE MACHINE =====
func _update_ai_state(delta):
	"""Update AI behavior based on current state"""
	if not patrol_enabled:
		return
		
	match current_state:
		AIState.PATROL:
			_handle_patrol_state(delta)
		AIState.WAITING:
			_handle_waiting_state(delta)
		AIState.ALERT:
			_handle_alert_state(delta)
		AIState.COMBAT:
			_handle_combat_state(delta)
		AIState.STUNNED:
			_handle_stunned_state(delta)

func _handle_patrol_state(delta):
	"""Handle patrol movement between waypoints"""
	if is_staggered or not navigation_agent:
		return
	
	if navigation_agent.is_navigation_finished():
		# Reached patrol point
		current_state = AIState.WAITING
		wait_timer = wait_time_at_point
		print(name, " reached patrol point, waiting...")
		return
	
	# Move towards target
	var next_path_position = navigation_agent.get_next_path_position()
	var direction = (next_path_position - global_position).normalized()
	
	# Apply movement
	velocity.x = direction.x * patrol_speed
	velocity.z = direction.z * patrol_speed
	
	# Rotate to face movement direction
	if direction.length() > 0.1:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * 5.0)

func _handle_waiting_state(delta):
	"""Handle waiting at patrol points"""
	wait_timer -= delta
	
	# Reduce movement while waiting
	velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
	velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
	
	if wait_timer <= 0:
		_advance_to_next_patrol_point()
		current_state = AIState.PATROL

func _handle_alert_state(delta):
	"""Handle alert state when player detected"""
	# Stop movement during alert
	velocity.x = move_toward(velocity.x, 0.0, delta * 10.0)
	velocity.z = move_toward(velocity.z, 0.0, delta * 10.0)
	
	# Face the player if available
	if player_reference:
		var direction_to_player = (player_reference.global_position - global_position).normalized()
		var target_rotation = atan2(direction_to_player.x, direction_to_player.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * 8.0)

func _handle_combat_state(delta):
	"""Handle combat behavior with proper navigation"""
	if not player_reference:
		return
	
	var distance_to_player = global_position.distance_to(player_reference.global_position)
	
	# Move towards player if too far for attack
	if distance_to_player > attack_range and not is_attacking:
		if navigation_agent:
			navigation_agent.target_position = player_reference.global_position
			
			if navigation_agent.is_navigation_finished():
				print(name, " - Navigation says finished but distance is ", distance_to_player)
				print("NavigationAgent target: ", navigation_agent.target_position)
				print("Current position: ", global_position)
			else:
				var next_path_position = navigation_agent.get_next_path_position()
				var direction = (next_path_position - global_position).normalized()
				
				velocity.x = direction.x * patrol_speed * 1.5
				velocity.z = direction.z * patrol_speed * 1.5
		else:
			print(name, " - NavigationAgent3D is null!")
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 15.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 15.0)
	
	# Face the player
	var direction_to_player = (player_reference.global_position - global_position).normalized()
	var target_rotation = atan2(direction_to_player.x, direction_to_player.z)
	rotation.y = lerp_angle(rotation.y, target_rotation, delta * 8.0)
	
	_update_combat_behavior(delta)

func _update_combat_behavior(delta):
	"""Handle combat attack logic"""
	if not player_reference or is_staggered:
		return
	
	# Update attack cooldown
	if attack_timer > 0:
		attack_timer -= delta
	
	# Check if player is in attack range
	var distance_to_player = global_position.distance_to(player_reference.global_position)
	
	if distance_to_player <= attack_range and attack_timer <= 0 and not is_attacking:
		_start_attack()

func _start_attack():
	"""Initiate an attack sequence"""
	if is_attacking or is_staggered:
		return
	
	is_attacking = true
	attack_target = player_reference
	attack_timer = attack_cooldown
	
	print(name, " starting attack!")
	
	# Visual wind-up (enemy prepares to attack)
	_show_attack_telegraph()
	
	# Attack sequence
	_execute_attack_sequence()

func _show_attack_telegraph():
	"""Visual indicator that enemy is about to attack"""
	# Flash orange to warn player
	var telegraph_material = StandardMaterial3D.new()
	telegraph_material.albedo_color = Color.ORANGE
	telegraph_material.emission_enabled = true
	telegraph_material.emission = Color.ORANGE * 0.5
	
	mesh.set_surface_override_material(0, telegraph_material)
	
	# Restore material after telegraph
	var tween = create_tween()
	tween.tween_interval(attack_windup_time * 0.7)  # Show telegraph for most of windup
	tween.tween_callback(_restore_material)

func _execute_attack_sequence():
	"""Execute the full attack sequence"""
	# Wind-up phase
	await get_tree().create_timer(attack_windup_time).timeout
	
	# Strike phase - deal damage if player still in range
	if attack_target and not is_staggered:
		_perform_attack_strike()
	
	# Recovery phase
	await get_tree().create_timer(attack_recovery_time).timeout
	
	is_attacking = false
	print(name, " attack complete")

# Modified _perform_attack_strike to check if player is alive
func _perform_attack_strike():
	"""Execute the actual damage dealing"""
	if not attack_target:
		return
	
	# Don't attack if player is dead
	if attack_target.has_method("is_alive") and not attack_target.is_alive():
		print(name, " stopping attack - player is dead")
		is_attacking = false
		current_state = AIState.WAITING
		return
	
	var distance_to_target = global_position.distance_to(attack_target.global_position)
	
	if distance_to_target <= attack_range:
		# Deal damage to player
		if attack_target.has_method("take_damage"):
			attack_target.take_damage(attack_damage)
			print(name, " hit player for ", attack_damage, " damage!")
		
		# Visual effect for successful hit
		_create_attack_effect()
	else:
		print(name, " attack missed - player out of range")

func _create_attack_effect():
	"""Create visual effect for successful attack"""
	# Simple screen shake could be handled by the player
	# For now, just flash red briefly
	var hit_material = StandardMaterial3D.new()
	hit_material.albedo_color = Color.RED
	hit_material.emission_enabled = true
	hit_material.emission = Color.RED * 0.3
	
	mesh.set_surface_override_material(0, hit_material)
	
	var effect_tween = create_tween()
	effect_tween.tween_interval(0.1)
	effect_tween.tween_callback(_restore_material)

func _setup_attack_area():
	"""Set up the attack area collision"""
	if not attack_area:
		return
		
	if not attack_shape.shape:
		var sphere_shape = SphereShape3D.new()
		sphere_shape.radius = attack_range
		attack_shape.shape = sphere_shape
	
	# Configure area
	attack_area.monitoring = false  # We don't need overlap detection for attacks
	attack_area.monitorable = false

func _handle_stunned_state(delta):
	"""Handle stunned state when taking damage"""
	# Reduce movement while stunned
	velocity.x = move_toward(velocity.x, 0.0, delta * 12.0)
	velocity.z = move_toward(velocity.z, 0.0, delta * 12.0)

func _set_next_patrol_target():
	"""Set the navigation target to the next patrol point"""
	if patrol_points.size() == 0 or not navigation_agent:
		return
	
	var target_point = patrol_points[current_patrol_index]
	navigation_agent.target_position = target_point
	print(name, " heading to patrol point ", current_patrol_index, " at ", target_point)

func _advance_to_next_patrol_point():
	"""Move to the next patrol point in sequence"""
	current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
	_set_next_patrol_target()

# ===== PLAYER DETECTION CALLBACKS =====
func _on_player_detected(body):
	"""Called when player enters detection range"""
	if body.is_in_group("player") or body.has_method("take_damage"):
		player_reference = body
		print(name, " detected player!")
		
		# Switch to combat state when player is detected
		if current_state == AIState.PATROL or current_state == AIState.WAITING:
			current_state = AIState.COMBAT
			print(name, " entering combat mode!")

func _on_player_lost(body):
	"""Called when player exits detection range"""
	if body == player_reference:
		print(name, " lost player")
		player_reference = null
		
		# Return to patrol after losing player
		if current_state == AIState.ALERT or current_state == AIState.COMBAT:
			current_state = AIState.PATROL
			_set_next_patrol_target()

# ===== EXISTING COMBAT METHODS (MODIFIED FOR AI INTEGRATION) =====
func _setup_materials():
	"""Set up original material if none exists"""
	if mesh.get_surface_override_material(0) == null:
		var material = StandardMaterial3D.new()
		material.albedo_color = Color.ORANGE
		material.roughness = 0.8
		mesh.set_surface_override_material(0, material)
	
	original_material = mesh.get_surface_override_material(0)

func take_damage(damage: float, attacker_position: Vector3 = Vector3.ZERO):
	"""Take damage with combat state handling"""
	health -= damage
	health = max(0, health)
	
	print(name, " took ", damage, " damage. Health: ", health)
	
	# Calculate knockback direction
	var knockback_direction = Vector3.ZERO
	if attacker_position != Vector3.ZERO:
		knockback_direction = (global_position - attacker_position).normalized()
		knockback_direction.y = 0
	else:
		knockback_direction = -global_transform.basis.z
	
	# Apply reactions
	_apply_knockback(knockback_direction)
	_trigger_stagger()
	_flash_red()
	_show_damage_number(damage)
	_screen_shake_effect()
	_update_health_bar()
	
	# Interrupt attack if taking damage
	if is_attacking:
		is_attacking = false
		print(name, " attack interrupted by damage!")
	
	# Switch to stunned state
	current_state = AIState.STUNNED
	
	if health <= 0:
		_handle_death()

func take_damage_from_player(damage: float, player_position: Vector3):
	"""Specialized damage function for player attacks"""
	take_damage(damage, player_position)

func _apply_knockback(direction: Vector3):
	"""Apply knockback force to the enemy"""
	if direction.length() > 0:
		velocity += direction * knockback_force
		velocity.y = min(velocity.y + 2.0, 5.0)

func _trigger_stagger():
	"""Make enemy stagger briefly, unable to act"""
	if is_staggered:
		return
	
	is_staggered = true
	
	# Visual stagger
	var tween = create_tween()
	tween.parallel().tween_property(mesh, "rotation", Vector3(-0.3, 0, 0), 0.1)
	tween.parallel().tween_property(mesh, "scale", Vector3(0.9, 1.1, 0.9), 0.1)
	
	await tween.finished
	
	var recovery_tween = create_tween()
	recovery_tween.parallel().tween_property(mesh, "rotation", Vector3.ZERO, stagger_duration - 0.1)
	recovery_tween.parallel().tween_property(mesh, "scale", Vector3.ONE, stagger_duration - 0.1)
	
	await recovery_tween.finished
	is_staggered = false
	
	# ===== NEW: RETURN TO PATROL AFTER STAGGER =====
	if current_state == AIState.STUNNED and health > 0:
		current_state = AIState.PATROL
		_set_next_patrol_target()

func _screen_shake_effect():
	"""Trigger screen shake effect"""
	var shake_tween = create_tween()
	var original_pos = mesh.position
	
	for i in range(6):
		var shake_offset = Vector3(
			randf_range(-0.1, 0.1),
			randf_range(-0.1, 0.1),
			randf_range(-0.1, 0.1)
		)
		shake_tween.parallel().tween_property(mesh, "position", original_pos + shake_offset, 0.05)
		shake_tween.parallel().tween_interval(0.05)
	
	shake_tween.tween_property(mesh, "position", original_pos, 0.1)

func _flash_red():
	"""Flash red when taking damage"""
	mesh.set_surface_override_material(0, hit_material)
	
	var tween = create_tween()
	tween.tween_interval(hit_flash_duration)
	tween.tween_callback(_restore_material)

func _restore_material():
	"""Restore original material after hit flash"""
	mesh.set_surface_override_material(0, original_material)

func _show_damage_number(damage: float):
	"""Show floating damage number"""
	damage_label.text = "-" + str(int(damage))
	damage_label.modulate = Color.YELLOW
	damage_label.outline_modulate = Color.BLACK
	damage_label.outline_size = 8
	
	var tween = create_tween()
	var random_x = randf_range(-0.5, 0.5)
	tween.parallel().tween_property(damage_label, "position", 
		damage_label.position + Vector3(random_x, 2.5, 0), 1.5)
	tween.parallel().tween_property(damage_label, "modulate", Color.TRANSPARENT, 1.5)
	tween.tween_callback(_reset_damage_label)

func _reset_damage_label():
	"""Reset damage label position and visibility"""
	damage_label.position = Vector3.ZERO
	damage_label.modulate = Color.TRANSPARENT

func _update_health_bar():
	"""Update health bar display"""
	if health_bar:
		health_bar.value = (health / max_health) * 100

func _handle_death():
	"""Handle target death with dramatic effect"""
	print(name, " destroyed!")
	
	# ===== NEW: DISABLE PATROL DURING DEATH =====
	patrol_enabled = false
	current_state = AIState.STUNNED
	
	var original_death_position = global_position
	
	# Create gray death material
	var death_material = StandardMaterial3D.new()
	death_material.albedo_color = Color.GRAY
	death_material.roughness = 1.0
	
	# Death animation
	var death_tween = create_tween()
	death_tween.parallel().tween_property(mesh, "rotation", Vector3(-PI/2, 0, 0), 0.5)
	death_tween.parallel().tween_property(mesh, "scale", Vector3(1.2, 0.1, 1.2), 0.5)
	death_tween.tween_callback(func(): mesh.set_surface_override_material(0, death_material))
	
	await death_tween.finished
	
	# Disable during death
	set_physics_process(false)
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	
	await get_tree().create_timer(3.0).timeout
	_respawn(original_death_position)

func _respawn(death_position: Vector3):
	"""Respawn the test target at original position"""
	print("Respawning ", name, "...")
	
	# ===== MODIFIED FOR PATROL =====
	global_position = original_position  # Respawn at original spawn point
	set_physics_process(true)
	
	health = max_health
	patrol_enabled = true
	current_state = AIState.PATROL
	current_patrol_index = 0
	
	# Restore collision and appearance
	collision_layer = 4
	collision_mask = 3
	visible = true
	mesh.visible = true
	
	mesh.rotation = Vector3.ZERO
	mesh.scale = Vector3.ONE
	mesh.position = Vector3.ZERO
	mesh.set_surface_override_material(0, original_material)
	
	velocity = Vector3.ZERO
	is_staggered = false
	player_reference = null
	
	_update_health_bar()
	
	# ===== NEW: RESTART PATROL =====
	call_deferred("_start_patrol")
	
	print(name, " respawned and resuming patrol!")

# ===== DEBUG FUNCTIONS =====
func add_patrol_point(point: Vector3):
	"""Add a patrol point at runtime"""
	patrol_points.append(point)

func clear_patrol_points():
	"""Clear all patrol points"""
	patrol_points.clear()

func toggle_patrol():
	"""Toggle patrol behavior on/off"""
	patrol_enabled = not patrol_enabled
	if not patrol_enabled:
		current_state = AIState.WAITING
	else:
		current_state = AIState.PATROL


