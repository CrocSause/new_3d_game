# File: scripts/ui/InteractionPrompt.gd
extends Control
class_name InteractionPrompt

@onready var prompt_label: Label = %PromptLabel
@onready var key_hint: Label = %KeyHint
@onready var background: NinePatchRect = %Background

var current_interactable: Node = null
var player: PlayerController = null

func _ready():
	# Hide initially
	visible = false
	
	# Find player reference
	_find_player_reference()
	
	# Set up default appearance
	if key_hint:
		key_hint.text = "[E]"

func _find_player_reference():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as PlayerController

func _process(_delta):
	if not player:
		return
	
	_check_for_interactables()

func _check_for_interactables():
	var raycast = player.interaction_raycast
	if not raycast:
		return
	
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider and collider.has_method("get_interaction_text"):
			_show_prompt(collider)
		else:
			_hide_prompt()
	else:
		_hide_prompt()

func _show_prompt(interactable: Node):
	if current_interactable == interactable:
		return  # Already showing this prompt
	
	current_interactable = interactable
	
	# Get interaction text from the object
	var interaction_text = ""
	if interactable.has_method("get_interaction_text"):
		interaction_text = interactable.get_interaction_text()
	else:
		interaction_text = "Interact"
	
	if prompt_label:
		prompt_label.text = interaction_text
	
	visible = true

func _hide_prompt():
	if current_interactable == null:
		return  # Already hidden
	
	current_interactable = null
	visible = false

# Call this to manually show a prompt (for cutscenes, etc.)
func show_custom_prompt(text: String, key: String = "[E]"):
	if prompt_label:
		prompt_label.text = text
	if key_hint:
		key_hint.text = key
	visible = true

func hide_custom_prompt():
	visible = false
