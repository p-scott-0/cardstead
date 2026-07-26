class_name RecipeBook
extends Control

# Scrollable list of every recipe; undiscovered ones show as ???.

var _rows: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("3a3125")
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 1, 1, 0.2)
	sb.content_margin_left = 40.0
	sb.content_margin_right = 40.0
	sb.content_margin_top = 30.0
	sb.content_margin_bottom = 30.0
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var title := Label.new()
	title.text = "📖 Recipe Book"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", CardNode.get_emoji_font())
	title.add_theme_font_size_override("font_size", 38)
	col.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 560)
	col.add_child(scroll)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(220, 58)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.pressed.connect(func(): visible = false)
	col.add_child(close_btn)


func open_book() -> void:
	for child in _rows.get_children():
		child.queue_free()
	for r in Db.recipes:
		var row := Label.new()
		row.add_theme_font_override("font", CardNode.get_emoji_font())
		row.add_theme_font_size_override("font_size", 22)
		if GameState.discovered_recipes.has(String(r["id"])):
			row.text = _format_recipe(r)
			row.add_theme_color_override("font_color", Color("f2e8c9"))
		else:
			row.text = "— ??? —"
			row.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
		_rows.add_child(row)
	visible = true


func _format_recipe(r: Dictionary) -> String:
	var ins: PackedStringArray = []
	for id in r["inputs"]:
		ins.append(_fmt_part(String(id), int(r["inputs"][id])))
	var outs: PackedStringArray = []
	for id in r["outputs"]:
		outs.append(_fmt_part(String(id), int(r["outputs"][id])))
	return "%s  →  %s   (%ss)" % [" + ".join(ins), " + ".join(outs), str(r["time"])]


static func _fmt_part(id: String, n: int) -> String:
	var def := Db.card(id)
	var label := "%s %s" % [String(def.get("icon", "")), String(def.get("name", id))]
	if n > 1:
		return "%d× %s" % [n, label]
	return label
