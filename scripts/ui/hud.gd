class_name Hud
extends Control

# Top bar: day counter + day progress + coin count on the left, recipe book
# and menu buttons on the right. Everything except the buttons ignores the
# mouse so board input passes through.

signal recipes_pressed
signal menu_pressed

var _day_label: Label
var _day_bar: ProgressBar
var _coins_label: Label
var _food_label: Label
var _margin: MarginContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiKit.theme()

	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_margin.add_child(row)

	var left := VBoxContainer.new()
	# tapping the timer block toggles the gameplay pause
	left.mouse_filter = Control.MOUSE_FILTER_STOP
	left.gui_input.connect(_on_timer_input)
	left.add_theme_constant_override("separation", 4)
	row.add_child(left)

	_day_label = Label.new()
	_day_label.text = "Day 1"
	_day_label.add_theme_font_size_override("font_size", 30)
	_day_label.add_theme_color_override("font_color", Color.WHITE)
	_day_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_day_label.add_theme_constant_override("shadow_offset_y", 2)
	_day_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_day_label)

	_day_bar = ProgressBar.new()
	_day_bar.custom_minimum_size = Vector2(260, 18)
	_day_bar.min_value = 0.0
	_day_bar.max_value = 1.0
	_day_bar.show_percentage = false
	_day_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.35)
	bg.set_corner_radius_all(9)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("f2cf5b")
	fill.set_corner_radius_all(9)
	_day_bar.add_theme_stylebox_override("background", bg)
	_day_bar.add_theme_stylebox_override("fill", fill)
	left.add_child(_day_bar)

	_coins_label = Label.new()
	_coins_label.text = "🪙 0    🃏 0"
	_coins_label.add_theme_font_override("font", CardNode.get_emoji_font())
	_coins_label.add_theme_font_size_override("font_size", 26)
	_coins_label.add_theme_color_override("font_color", Color.WHITE)
	_coins_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_coins_label)

	_food_label = Label.new()
	_food_label.text = "🍗 0 / 0"
	_food_label.add_theme_font_override("font", CardNode.get_emoji_font())
	_food_label.add_theme_font_size_override("font_size", 26)
	_food_label.add_theme_color_override("font_color", Color.WHITE)
	_food_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_food_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	var right := HBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_theme_constant_override("separation", 12)
	row.add_child(right)

	var recipes_btn := _make_button("📖 Recipes")
	recipes_btn.pressed.connect(func(): recipes_pressed.emit())
	right.add_child(recipes_btn)

	var menu_btn := _make_button("Menu")
	menu_btn.pressed.connect(func(): menu_pressed.emit())
	right.add_child(menu_btn)

	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)


func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(170, 58)
	b.add_theme_font_override("font", CardNode.get_emoji_font())
	b.add_theme_font_size_override("font_size", 22)
	return b


func _process(_delta: float) -> void:
	if GameState.time_paused:
		_day_label.text = "Day %d — paused" % GameState.day
		_day_bar.modulate = Color(0.6, 0.6, 0.6)
	else:
		_day_label.text = "Day %d" % GameState.day
		_day_bar.modulate = Color.WHITE
	_day_bar.value = clampf(GameState.day_time / GameState.DAY_LENGTH, 0.0, 1.0)


func _on_timer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		GameState.toggle_time_pause()
		accept_event()


func update_stats(board: Board) -> void:
	_coins_label.text = "🪙 %d    🃏 %d" % [board.count_cards("coin"), board.total_cards()]
	var fs := board.food_stats()
	_food_label.text = "🍗 %d / %d" % [fs.x, fs.y]
	_food_label.add_theme_color_override("font_color",
		Color("ff8a7a") if fs.x < fs.y else Color.WHITE)


func _apply_safe_area() -> void:
	# insets must be window-relative: the safe area is in global screen
	# coordinates, and on desktop the window can sit anywhere inside it
	var sa: Rect2i = DisplayServer.get_display_safe_area()
	var wp: Vector2i = DisplayServer.window_get_position()
	var ws: Vector2i = DisplayServer.window_get_size()
	var vs := get_viewport_rect().size
	var sx := vs.x / maxf(1.0, float(ws.x))
	var sy := vs.y / maxf(1.0, float(ws.y))
	var inset_left := maxf(0.0, float(sa.position.x - wp.x))
	var inset_top := maxf(0.0, float(sa.position.y - wp.y))
	var inset_right := maxf(0.0, float((wp.x + ws.x) - (sa.position.x + sa.size.x)))
	_margin.add_theme_constant_override("margin_left", int(inset_left * sx) + 34)
	_margin.add_theme_constant_override("margin_top", int(inset_top * sy) + 24)
	_margin.add_theme_constant_override("margin_right", int(inset_right * sx) + 34)
	_margin.add_theme_constant_override("margin_bottom", 24)
