class_name DaySummaryPopup
extends Control

# End-of-day report: who ate, who starved, button to start the next day.

signal next_day_pressed

var _title: Label
var _body: Label
var _eaten: Label
var _starved: Label
var _next_btn: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("2b3a55")
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 1, 1, 0.2)
	sb.content_margin_left = 50.0
	sb.content_margin_right = 50.0
	sb.content_margin_top = 34.0
	sb.content_margin_bottom = 34.0
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", CardNode.get_emoji_font())
	_title.add_theme_font_size_override("font_size", 42)
	col.add_child(_title)

	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_theme_font_override("font", CardNode.get_emoji_font())
	_body.add_theme_font_size_override("font_size", 24)
	_body.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	col.add_child(_body)

	_eaten = Label.new()
	_eaten.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eaten.add_theme_font_override("font", CardNode.get_emoji_font())
	_eaten.add_theme_font_size_override("font_size", 30)
	_eaten.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	col.add_child(_eaten)

	_starved = Label.new()
	_starved.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_starved.add_theme_font_size_override("font_size", 24)
	_starved.add_theme_color_override("font_color", Color("ff7a6b"))
	col.add_child(_starved)

	_next_btn = Button.new()
	_next_btn.custom_minimum_size = Vector2(300, 64)
	_next_btn.add_theme_font_size_override("font_size", 26)
	_next_btn.pressed.connect(func(): next_day_pressed.emit())
	col.add_child(_next_btn)


func show_summary(s: Dictionary) -> void:
	_title.text = "🌙 Day %d complete" % int(s.get("day", 1))
	_body.text = "%d villagers, %d babies fed" % [
		int(s.get("villagers", 0)), int(s.get("babies", 0))]
	var eaten: Dictionary = s.get("eaten", {})
	if eaten.is_empty():
		_eaten.text = "nothing was eaten"
	else:
		var parts: PackedStringArray = []
		for id in eaten:
			parts.append("%s ×%d" % [String(Db.card(id).get("icon", "?")), int(eaten[id])])
		_eaten.text = "ate:  " + "   ".join(parts)
	var n := int(s.get("starved", 0))
	_starved.text = "💀 %d starved!" % n if n > 0 else ""
	_starved.visible = n > 0
	_next_btn.text = "Start Day %d" % (int(s.get("day", 1)) + 1)
	visible = true
