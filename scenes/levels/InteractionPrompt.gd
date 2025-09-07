# File: scripts/ui/InteractionPrompt.gd
extends Control
class_name InteractionPrompt

@onready var prompt_label: Label = %PromptLabel
@onready var key_hint: Label = %KeyHint
@onready var background: NinePatchRect = %Background

var current_interactable: Node = null
var player: PlayerController = null

func _ready():
	visible = false
	if key_hint: key_hint.text = "[E]"

func bind_player(p: PlayerController) -> void:
	player = p
	if not player: return
	player.interaction_target_changed.connect(_on_target_changed)

func _on_target_changed(target: Node) -> void:
	if target and target.has_method("get_interaction_text"):
		_show_prompt(target)
	else:
		_hide_prompt()

func _show_prompt(interactable: Node):
	if current_interactable == interactable: return
	current_interactable = interactable
	var interaction_text := "Interact"
	if interactable.has_method("get_interaction_text"):
		interaction_text = interactable.get_interaction_text()
	if prompt_label: prompt_label.text = interaction_text
	visible = true

func _hide_prompt():
	if current_interactable == null: return
	current_interactable = null
	visible = false

# Manual control (cutscenes, etc.)
func show_custom_prompt(text: String, key: String = "[E]"):
	if prompt_label: prompt_label.text = text
	if key_hint: key_hint.text = key
	visible = true

func hide_custom_prompt():
	visible = false
