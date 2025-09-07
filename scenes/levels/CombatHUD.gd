# File: scripts/ui/CombatHUD.gd
extends Control
class_name CombatHUD

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_text: Label = %HealthText
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var combat_indicator: Label = %CombatIndicator
@onready var target_info: Control = %TargetInfo
@onready var target_name: Label = %TargetName
@onready var crosshair: Control = %Crosshair

var player: PlayerController = null

func _ready():
	# Hide initially
	visible = true
	
	# Set up UI defaults
	health_bar.max_value = 100
	health_bar.value = 100
	stamina_bar.max_value = 100
	stamina_bar.value = 100
	
	# Hide targeting UI initially
	if target_info:
		target_info.visible = false
	
	# Find player reference
	_find_player_reference()

func _find_player_reference():
	# Look for player in the scene
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as PlayerController
		_connect_player_signals()

func _connect_player_signals():
	if not player:
		return
	
	# Connect to targeting system if available
	if player.targeting_system:
		player.targeting_system.target_acquired.connect(_on_target_acquired)
		player.targeting_system.target_lost.connect(_on_target_lost)

func _process(_delta):
	if not player:
		return
	
	# Update health
	_update_health_display()
	
	# Update stamina (placeholder - you'll need to add stamina to PlayerController)
	_update_stamina_display()
	
	# Update combat state indicator
	_update_combat_indicator()

func _update_health_display():
	if not health_bar or not health_text:
		return
	
	var current_health = player.health
	var max_health = player.max_health
	
	health_bar.max_value = max_health
	health_bar.value = current_health
	
	health_text.text = str(int(current_health)) + " / " + str(int(max_health))
	
	# Color coding for health bar
	if current_health / max_health > 0.6:
		health_bar.modulate = Color.GREEN
	elif current_health / max_health > 0.3:
		health_bar.modulate = Color.YELLOW
	else:
		health_bar.modulate = Color.RED

func _update_stamina_display():
	if not stamina_bar:
		return
	
	# Placeholder - you'll need to add stamina system to PlayerController
	# For now, show dodge cooldown as "stamina"
	var stamina_value = 100.0
	if not player.can_dodge:
		stamina_value = 30.0  # Low when dodge is on cooldown
	
	stamina_bar.value = stamina_value

func _update_combat_indicator():
	if not combat_indicator:
		return
	
	if player.is_in_combat:
		combat_indicator.text = "COMBAT"
		combat_indicator.modulate = Color.RED
		combat_indicator.visible = true
	else:
		combat_indicator.visible = false

func _on_target_acquired(target: Node3D):
	if not target_info or not target_name:
		return
	
	target_info.visible = true
	target_name.text = target.name
	
	# Show crosshair when locked on
	if crosshair:
		crosshair.visible = true

func _on_target_lost():
	if target_info:
		target_info.visible = false
	
	if crosshair:
		crosshair.visible = false

# Call this from other systems to show damage
func show_damage_indicator(amount: float):
	# Create floating damage text
	var damage_label = Label.new()
	damage_label.text = "-" + str(int(amount))
	damage_label.modulate = Color.RED
	damage_label.add_theme_font_size_override("font_size", 24)
	
	# Position near center of screen
	damage_label.position = Vector2(
		get_viewport().get_visible_rect().size.x * 0.5,
		get_viewport().get_visible_rect().size.y * 0.4
	)
	
	add_child(damage_label)
	
	# Animate damage text
	var tween = create_tween()
	tween.parallel().tween_property(damage_label, "position", 
		damage_label.position + Vector2(randf_range(-50, 50), -100), 1.0)
	tween.parallel().tween_property(damage_label, "modulate", Color.TRANSPARENT, 1.0)
	tween.tween_callback(damage_label.queue_free)
