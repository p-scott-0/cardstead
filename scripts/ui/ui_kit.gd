class_name UiKit
extends RefCounted

# Shared UI styling: one Theme for every menu/popup so buttons and panels
# look consistent — rounded, cream buttons on dark felt-green panels.

const PANEL_BG := Color("264534")
const PANEL_BORDER := Color(1, 1, 1, 0.14)
const BTN_BG := Color("efe3c2")
const BTN_BG_HOVER := Color("f9f1da")
const BTN_BG_PRESSED := Color("d3c39b")
const BTN_TEXT := Color("35301f")

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.set_stylebox("normal", "Button", _button_box(BTN_BG))
	t.set_stylebox("hover", "Button", _button_box(BTN_BG_HOVER))
	t.set_stylebox("pressed", "Button", _button_box(BTN_BG_PRESSED, 2))
	t.set_stylebox("disabled", "Button", _button_box(Color(BTN_BG, 0.4)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(state, "Button", BTN_TEXT)
	t.set_color("font_pressed_color", "Button", Color(BTN_TEXT, 0.8))
	t.set_font_size("font_size", "Button", 26)
	_theme = t
	return t


static func _button_box(bg: Color, press_shift := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 26.0
	sb.content_margin_right = 26.0
	sb.content_margin_top = 12.0 + press_shift
	sb.content_margin_bottom = 12.0 - press_shift
	sb.border_width_bottom = 4 - press_shift
	sb.border_color = Color(0, 0, 0, 0.28)
	return sb


static func panel_box(radius := 28) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(2)
	sb.border_color = PANEL_BORDER
	sb.content_margin_left = 56.0
	sb.content_margin_right = 56.0
	sb.content_margin_top = 40.0
	sb.content_margin_bottom = 40.0
	return sb
