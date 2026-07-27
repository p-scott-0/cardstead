class_name CardNode
extends Node2D

# One card on the board. Pure custom drawing (rounded rects via StyleBoxFlat)
# plus a few Labels; no textures, no physics bodies. Input picking is handled
# centrally by the board, not per-card.

const SIZE := Vector2(140, 196)
const RADIUS := 12.0
const HEADER_H := 34.0
const HEADER_H_BIG := 50.0  # stack-head mode: enlarged header = whole-stack grab handle

const TYPE_COLORS := {
	"unit": Color("3f78c8"),
	"nature": Color("4c9a4c"),
	"resource": Color("9a6b4c"),
	"food": Color("c85050"),
	"building": Color("707c8c"),
	"special": Color("c8a03c"),
}

var id := ""
var def: Dictionary = {}
var charges_left := 0:
	set(v):
		charges_left = v
		queue_redraw()
var lifted := false
var stack_head := false

var _name_label: Label

var _sb_body: StyleBoxFlat
var _sb_header: StyleBoxFlat
var _sb_shadow: StyleBoxFlat

const EMOJI_FONT_PATH := "res://assets/fonts/TwemojiMozilla.ttf"

static var _emoji_font: Font


# Bundled color emoji font (COLR renders on every platform, unlike system
# emoji fonts — Apple Color Emoji draws blank in Godot on iOS, and Windows
# 10's Segoe UI Emoji predates several of our card glyphs). The default
# font is chained as fallback so letters and digits in mixed strings render.
static func get_emoji_font() -> Font:
	if _emoji_font == null:
		if ResourceLoader.exists(EMOJI_FONT_PATH):
			var f: FontFile = load(EMOJI_FONT_PATH)
			var fallbacks: Array[Font] = [ThemeDB.fallback_font]
			f.fallbacks = fallbacks
			_emoji_font = f
		else:
			var sf := SystemFont.new()
			sf.font_names = PackedStringArray([
				"Apple Color Emoji", "Segoe UI Emoji", "Noto Color Emoji"])
			_emoji_font = sf
	return _emoji_font


func setup(card_def: Dictionary) -> void:
	def = card_def
	id = String(def["id"])
	charges_left = int(def.get("charges", 0))
	_build_styles()
	_build_labels()
	queue_redraw()


func header_color() -> Color:
	return TYPE_COLORS.get(String(def.get("type", "resource")), Color.GRAY)


func set_lifted(v: bool) -> void:
	lifted = v
	scale = Vector2.ONE * (1.06 if v else 1.0)
	queue_redraw()


# Bottom card of a 2+ stack: bigger header band and name so the whole-stack
# grab area is obvious and easy to hit.
func set_stack_head(v: bool) -> void:
	if stack_head == v:
		return
	stack_head = v
	if _name_label != null:
		_name_label.size = Vector2(SIZE.x, (HEADER_H_BIG if v else HEADER_H) - 4.0)
		_name_label.add_theme_font_size_override("font_size", 25 if v else 19)
	queue_redraw()


func header_height() -> float:
	return HEADER_H_BIG if stack_head else HEADER_H


func _build_styles() -> void:
	_sb_body = StyleBoxFlat.new()
	_sb_body.bg_color = Color("f4efe2")
	_sb_body.set_corner_radius_all(int(RADIUS))
	_sb_body.border_color = Color("2b2b23", 0.85)
	_sb_body.set_border_width_all(2)

	_sb_header = StyleBoxFlat.new()
	_sb_header.bg_color = header_color()
	_sb_header.corner_radius_top_left = int(RADIUS)
	_sb_header.corner_radius_top_right = int(RADIUS)

	_sb_shadow = StyleBoxFlat.new()
	_sb_shadow.bg_color = Color(0, 0, 0, 0.24)
	_sb_shadow.set_corner_radius_all(int(RADIUS) + 2)


func _build_labels() -> void:
	_name_label = Label.new()
	_name_label.text = String(def.get("name", "?"))
	_name_label.position = Vector2(0, 2)
	_name_label.size = Vector2(SIZE.x, HEADER_H - 4)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 19)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

	var icon_label := Label.new()
	icon_label.text = String(def.get("icon", "?"))
	icon_label.position = Vector2(0, HEADER_H + 12)
	icon_label.size = Vector2(SIZE.x, 96)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_override("font", get_emoji_font())
	icon_label.add_theme_font_size_override("font_size", 64)
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon_label)

	if bool(def.get("sellable", false)) and int(def.get("sell", 0)) > 0:
		var sell_label := Label.new()
		sell_label.text = "%d🪙" % int(def["sell"])
		sell_label.position = Vector2(SIZE.x - 62, SIZE.y - 32)
		sell_label.size = Vector2(56, 26)
		sell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sell_label.add_theme_font_override("font", get_emoji_font())
		sell_label.add_theme_font_size_override("font_size", 16)
		sell_label.add_theme_color_override("font_color", Color("6a5c34"))
		sell_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sell_label)

	if int(def.get("food_value", 0)) > 0:
		var food_label := Label.new()
		food_label.text = "+%d🍽" % int(def["food_value"])
		food_label.position = Vector2(8, SIZE.y - 32)
		food_label.size = Vector2(70, 26)
		food_label.add_theme_font_override("font", get_emoji_font())
		food_label.add_theme_font_size_override("font_size", 16)
		food_label.add_theme_color_override("font_color", Color("9a3d3d"))
		food_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(food_label)


func _draw() -> void:
	var shadow_off := Vector2(0, 10) if lifted else Vector2(2, 5)
	draw_style_box(_sb_shadow, Rect2(shadow_off, SIZE))
	draw_style_box(_sb_body, Rect2(Vector2.ZERO, SIZE))
	draw_style_box(_sb_header, Rect2(Vector2.ZERO, Vector2(SIZE.x, header_height())))
	if int(def.get("charges", 0)) > 0:
		for i in charges_left:
			draw_circle(Vector2(16 + i * 14, SIZE.y - 16), 4.5, header_color())
