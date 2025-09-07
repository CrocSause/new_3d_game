extends Node
## Plays looping menu music, hover/press SFX, and ducks music while Options is open.
## Godot 4.x

@export var music_stream: AudioStream
@export var hover_stream: AudioStream
@export var press_stream: AudioStream

@export var music_base_db: float = -6.0   # default loudness for menu music
@export var sfx_db: float = 0.0           # default loudness for UI SFX
@export var duck_db: float = -8.0         # how much to lower music when Options opens
@export var duck_time: float = 0.15       # seconds

@onready var music: AudioStreamPlayer = $MusicPlayer
@onready var hover: AudioStreamPlayer = $HoverSFX
@onready var press: AudioStreamPlayer = $PressSFX

var _duck_tween: Tween

func _ready() -> void:
	# Route to proper buses if available
	_route_or_warn(music, "Music")
	_route_or_warn(hover, "SFX")
	_route_or_warn(press, "SFX")

	# Assign streams if provided via Inspector
	if music_stream: music.stream = music_stream
	if hover_stream: hover.stream = hover_stream
	if press_stream: press.stream = press_stream

	# Set base volumes (Options sliders adjust at the bus level)
	music.volume_db = music_base_db
	hover.volume_db = sfx_db
	press.volume_db = sfx_db

	# Start music (loop if supported, else manual loop)
	if music.stream:
		_try_enable_loop(music)
		music.play()
	else:
		push_warning("MainMenuAudio: No music_stream assigned.")

	# Wire hover/press to ALL buttons under MainMenu
	_wire_buttons()

	# Duck music when Options popup opens, restore on close
	_wire_options_duck()

func _route_or_warn(p: AudioStreamPlayer, bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		push_warning("MainMenuAudio: Bus '%s' not found, using '%s'." % [bus_name, p.bus])
	else:
		p.bus = bus_name

func _try_enable_loop(p: AudioStreamPlayer) -> void:
	var s := p.stream
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	else:
		# Fallback manual loop
		p.finished.connect(func(): p.play(), CONNECT_ONE_SHOT)

func _wire_buttons() -> void:
	var root := get_parent()  # MainMenu
	if not root: return
	var buttons := root.find_children("", "Button", true, false)
	for b in buttons:
		var btn := b as Button
		if btn:
			btn.mouse_entered.connect(_on_btn_hover)
			btn.focus_entered.connect(_on_btn_hover) # controller focus also bleeps
			btn.pressed.connect(_on_btn_press)

func _wire_options_duck() -> void:
	var root := get_parent()
	if not (root is Control): return
	var pop: PopupPanel = null
	if root.has_node("%OptionsMenu"):
		pop = root.get_node("%OptionsMenu") as PopupPanel
	elif root.has_node("%Options"):
		pop = root.get_node("%Options") as PopupPanel
	if pop:
		pop.about_to_popup.connect(func(): _set_duck(true))
		pop.popup_hide.connect(func(): _set_duck(false))

func _on_btn_hover() -> void:
	if not hover.stream: return
	hover.stop()
	hover.play()

func _on_btn_press() -> void:
	if not press.stream: return
	press.stop()
	press.play()

func _set_duck(on: bool) -> void:
	if not music: return
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	var target := music_base_db + (duck_db if on else 0.0)
	_duck_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_duck_tween.tween_property(music, "volume_db", target, duck_time)

