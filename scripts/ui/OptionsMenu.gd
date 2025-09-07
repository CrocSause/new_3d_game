extends PopupPanel

# --- Node refs (exact paths; no Unique Name needed) ---
@onready var master_slider: HSlider = $Margin/VBox/MasterRow/MasterSlider
@onready var master_value:  Label   = $Margin/VBox/MasterRow/MasterValue

@onready var music_slider:  HSlider = $Margin/VBox/MusicRow/MusicSlider
@onready var music_value:   Label   = $Margin/VBox/MusicRow/MusicValue

@onready var sfx_slider:    HSlider = $Margin/VBox/SFXRow/SFXSlider
@onready var sfx_value:     Label   = $Margin/VBox/SFXRow/SFXValue

@onready var fullscreen_chk: CheckBox = $Margin/VBox/VideoRow/Fullscreen
@onready var vsync_chk:      CheckBox = $Margin/VBox/VideoRow/VSync

@onready var apply_btn: Button = $Margin/VBox/ButtonRow/ApplyButton
@onready var back_btn:  Button = $Margin/VBox/ButtonRow/BackButton

# --- Settings persistence ---
const CFG_PATH := "user://settings.cfg"

var _saved: Dictionary = {}   # last saved settings
var _work:  Dictionary = {}   # working (live preview) settings
var _dirty: bool = false

func _ready() -> void:
	about_to_popup.connect(_on_about_to_popup)
	popup_hide.connect(_on_popup_hide)

	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)

	fullscreen_chk.toggled.connect(_on_fullscreen_toggled)
	vsync_chk.toggled.connect(_on_vsync_toggled)

	apply_btn.pressed.connect(_on_apply_pressed)
	back_btn.pressed.connect(_on_back_pressed)

	apply_btn.focus_mode = Control.FOCUS_ALL
	back_btn.focus_mode = Control.FOCUS_ALL

# ---- Lifecycle ----
func _on_about_to_popup() -> void:
	_saved = _load_settings()
	_work = _saved.duplicate(true)
	_populate_controls_from(_work)
	_apply_settings(_work, true, true) # apply both video & audio live
	_set_dirty(false)

func _on_popup_hide() -> void:
	# Revert unsaved changes if closed via Esc/X
	if _dirty:
		_apply_settings(_saved, true, true)
	_work = _saved.duplicate(true)
	_set_dirty(false)

# ---- UI -> Working settings (live preview) ----
func _on_master_changed(v: float) -> void:
	_work["master"] = v
	_update_value_labels()
	_apply_settings(_work, false, true)
	_set_dirty(true)

func _on_music_changed(v: float) -> void:
	_work["music"] = v
	_update_value_labels()
	_apply_settings(_work, false, true)
	_set_dirty(true)

func _on_sfx_changed(v: float) -> void:
	_work["sfx"] = v
	_update_value_labels()
	_apply_settings(_work, false, true)
	_set_dirty(true)

func _on_fullscreen_toggled(pressed: bool) -> void:
	_work["fullscreen"] = pressed
	_apply_settings(_work, true, false)
	_set_dirty(true)

func _on_vsync_toggled(pressed: bool) -> void:
	_work["vsync"] = pressed
	_apply_settings(_work, true, false)
	_set_dirty(true)

func _on_apply_pressed() -> void:
	_save_settings(_work)
	_saved = _work.duplicate(true)
	_set_dirty(false)
	hide()

func _on_back_pressed() -> void:
	_apply_settings(_saved, true, true)
	_work = _saved.duplicate(true)
	_set_dirty(false)
	hide()

# ---- Helpers ----
func _populate_controls_from(s: Dictionary) -> void:
	master_slider.value = float(s.get("master", 0.8))
	music_slider.value  = float(s.get("music", 0.8))
	sfx_slider.value    = float(s.get("sfx", 0.8))
	_update_value_labels()
	fullscreen_chk.button_pressed = bool(s.get("fullscreen", false))
	vsync_chk.button_pressed      = bool(s.get("vsync", true))

func _update_value_labels() -> void:
	master_value.text = str(round(master_slider.value * 100.0)) + "%"
	music_value.text  = str(round(music_slider.value * 100.0)) + "%"
	sfx_value.text    = str(round(sfx_slider.value * 100.0)) + "%"

func _set_dirty(d: bool) -> void:
	_dirty = d
	apply_btn.text = ("Apply*" if d else "Apply")  # GDScript 4.x ternary

# ---- Apply settings live ----
func _apply_settings(s: Dictionary, apply_video: bool, apply_audio: bool) -> void:
	if apply_audio:
		_apply_bus_volume_safe("Master", float(s.get("master", 0.8)))
		_apply_bus_volume_safe("Music",  float(s.get("music", 0.8)))
		_apply_bus_volume_safe("SFX",    float(s.get("sfx", 0.8)))

	if apply_video:
		# Fullscreen
		var fullscreen := bool(s.get("fullscreen", false))
		var target_mode := (Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED)
		var win := get_window()
		if win and win.mode != target_mode:
			win.mode = target_mode

		# VSync
		var vsync_on := bool(s.get("vsync", true))
		var vsync_mode := (DisplayServer.VSYNC_ENABLED if vsync_on else DisplayServer.VSYNC_DISABLED)
		DisplayServer.window_set_vsync_mode(vsync_mode)

func _apply_bus_volume_safe(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		push_warning("Options: Audio bus '%s' not found. Skipping." % bus_name)
		return
	var v: float = clamp(linear, 0.0, 1.0)
	var db := linear_to_db(max(v, 0.0001))  # avoid -inf
	if v <= 0.0001:
		db = -80.0
	AudioServer.set_bus_volume_db(idx, db)
	AudioServer.set_bus_mute(idx, v <= 0.0001)

# ---- Persistence ----
func _load_settings() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)  # fine if file doesn’t exist
	return {
		"master":     float(cfg.get_value("audio", "master", 0.8)),
		"music":      float(cfg.get_value("audio", "music", 0.8)),
		"sfx":        float(cfg.get_value("audio", "sfx", 0.8)),
		"fullscreen": bool(cfg.get_value("video", "fullscreen", false)),
		"vsync":      bool(cfg.get_value("video", "vsync", true)),
	}

func _save_settings(s: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)  # keep existing keys if present
	cfg.set_value("audio", "master",     float(s.get("master", 0.8)))
	cfg.set_value("audio", "music",      float(s.get("music", 0.8)))
	cfg.set_value("audio", "sfx",        float(s.get("sfx", 0.8)))
	cfg.set_value("video", "fullscreen", bool(s.get("fullscreen", false)))
	cfg.set_value("video", "vsync",      bool(s.get("vsync", true)))
	cfg.save(CFG_PATH)
