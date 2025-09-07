# File: scripts/TestLevel.gd
extends Node3D

@onready var player: PlayerController = $Player
@onready var hud: CombatHUD = $UILayer/CombatHud
@onready var prompt_ui: InteractionPrompt = $UILayer/InteractionPrompt

func _ready():
	if hud and player:
		hud.bind_player(player)
	if prompt_ui and player:
		prompt_ui.bind_player(player)

