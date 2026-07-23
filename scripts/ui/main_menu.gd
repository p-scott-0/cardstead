class_name MainMenu
extends Control

# Boot menu, pause menu, and game-over screen in one overlay.

signal new_game_pressed
signal continue_pressed
signal resume_pressed

var _subtitle: Label
var _continue_btn: Button
var _resume_btn: Button
var _new_btn: Button
var _sound_btn: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.12, 0.08, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("22452f")
	sb.set_corner_radius_all(24)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 1, 1, 0.18)
	sb.content_margin_left = 60.0
	sb.content_margin_right = 60.0
	sb.content_margin_top = 40.0
	sb.content_margin_bottom = 40.0
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)

	var title := Label.new()
	title.text = "🃏 CARDSTEAD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", CardNode.get_emoji_font())
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("f2e8c9"))
	col.add_child(title)

	_subtitle = Label.new()
	_subtitle.text = "a tiny card village"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 24)
	_subtitle.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	col.add_child(_subtitle)

	_continue_btn = _make_button("▶ Continue")
	_continue_btn.pressed.connect(func(): continue_pressed.emit())
	col.add_child(_continue_btn)

	_resume_btn = _make_button("▶ Resume")
	_resume_btn.pressed.connect(func(): resume_pressed.emit())
	col.add_child(_resume_btn)

	_new_btn = _make_button("✦ New Game")
	_new_btn.pressed.connect(func(): new_game_pressed.emit())
	col.add_child(_new_btn)

	_sound_btn = _make_button("")
	_sound_btn.pressed.connect(_toggle_sound)
	col.add_child(_sound_btn)
	_update_sound_text()

	var version := Label.new()
	version.text = "v" + GameState.version()
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_size_override("font_size", 16)
	version.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	col.add_child(version)


func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 64)
	b.add_theme_font_override("font", CardNode.get_emoji_font())
	b.add_theme_font_size_override("font_size", 26)
	return b


func _toggle_sound() -> void:
	GameState.sound_on = not GameState.sound_on
	_update_sound_text()


func _update_sound_text() -> void:
	_sound_btn.text = "🔊 Sound: On" if GameState.sound_on else "🔇 Sound: Off"


func show_mode(mode: String) -> void:
	visible = true
	_update_sound_text()
	match mode:
		"boot":
			_subtitle.text = "a tiny card village"
			_continue_btn.visible = SaveMgr.has_save()
			_resume_btn.visible = false
			_new_btn.visible = true
			_sound_btn.visible = true
		"pause":
			_subtitle.text = "paused"
			_continue_btn.visible = false
			_resume_btn.visible = true
			_new_btn.visible = true
			_sound_btn.visible = true


func show_game_over(day: int) -> void:
	visible = true
	_subtitle.text = "Your village fell on day %d" % day
	_continue_btn.visible = false
	_resume_btn.visible = false
	_new_btn.visible = true
	_sound_btn.visible = false
