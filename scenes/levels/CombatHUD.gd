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
	visible = true
	if target_info: target_info.visible = false
	if crosshair: crosshair.visible = false

func bind_player(p: PlayerController) -> void:
	player = p
	if not player: return

	# Initial push
	set_health(player.health, player.max_health)
	set_stamina(player.stamina, player.max_stamina)
	_set_combat_state(player.is_in_combat)

	# Signals
	player.health_changed.connect(set_health)
	player.stamina_changed.connect(set_stamina)
	player.took_damage.connect(func(amount: float): show_damage_indicator(amount))
	player.combat_state_changed.connect(_set_combat_state)

	# Optional: if your player (or its targeting system) emits these:
	if "targeting_system" in player and player.targeting_system:
		player.targeting_system.target_acquired.connect(_on_target_acquired)
		player.targeting_system.target_lost.connect(_on_target_lost)
	elif player.has_signal("lockon_target_acquired"):
		player.lockon_target_acquired.connect(_on_target_acquired)
		player.lockon_target_lost.connect(_on_target_lost)

func set_health(current_health: float, max_health: float) -> void:
	if not health_bar or not health_text: return
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_text.text = str(int(current_health)) + " / " + str(int(max_health))
	var ratio := 0.0 if max_health <= 0.0 else current_health / max_health
	if ratio > 0.6:
		health_bar.modulate = Color.GREEN
	elif ratio > 0.3:
		health_bar.modulate = Color.YELLOW
	else:
		health_bar.modulate = Color.RED

func set_stamina(current: float, maxv: float) -> void:
	if not stamina_bar: return
	stamina_bar.max_value = maxv
	stamina_bar.value = current

func _set_combat_state(in_combat: bool) -> void:
	if not combat_indicator: return
	combat_indicator.visible = in_combat
	if in_combat:
		combat_indicator.text = "COMBAT"
		combat_indicator.modulate = Color.RED

func _on_target_acquired(target: Node3D):
	if target_info: target_info.visible = true
	if target_name: target_name.text = target.name
	if crosshair: crosshair.visible = true

func _on_target_lost():
	if target_info: target_info.visible = false
	if crosshair: crosshair.visible = false

# Floating damage indicator
func show_damage_indicator(amount: float):
	var damage_label := Label.new()
	damage_label.text = "-" + str(int(amount))
	damage_label.modulate = Color.RED
	damage_label.add_theme_font_size_override("font_size", 24)
	damage_label.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5,
		get_viewport().get_visible_rect().size.y * 0.4)
	add_child(damage_label)
	var tween = create_tween()
	tween.parallel().tween_property(damage_label, "position",
		damage_label.position + Vector2(randf_range(-50, 50), -100), 1.0)
	tween.parallel().tween_property(damage_label, "modulate", Color.TRANSPARENT, 1.0)
	tween.tween_callback(damage_label.queue_free)
