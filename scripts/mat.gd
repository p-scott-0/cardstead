class_name MatNode
extends Node2D

# A fixed drop zone drawn on the board: the sell mat converts sellable cards
# to coins, the buy mat collects coins and dispenses card packs.

const MAT_SIZE := Vector2(380, 250)

var kind := "sell"  # "sell" | "buy"
var cost := 3
var coins_parked := 0:
	set(v):
		coins_parked = v
		_update_labels()

var _title: Label
var _sub: Label


func zone() -> Rect2:
	return Rect2(position, MAT_SIZE)


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.18)
	sb.set_corner_radius_all(18)
	sb.border_color = Color(1, 1, 1, 0.25)
	sb.set_border_width_all(3)

	_title = Label.new()
	_title.position = Vector2(0, 40)
	_title.size = Vector2(MAT_SIZE.x, 90)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", CardNode.get_emoji_font())
	_title.add_theme_font_size_override("font_size", 60)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_sub = Label.new()
	_sub.position = Vector2(0, 150)
	_sub.size = Vector2(MAT_SIZE.x, 60)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_font_override("font", CardNode.get_emoji_font())
	_sub.add_theme_font_size_override("font_size", 26)
	_sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sub)

	_update_labels()


func _update_labels() -> void:
	if _title == null:
		return
	if kind == "sell":
		_title.text = "💰"
		_sub.text = "SELL — drop cards"
		_sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	else:
		_title.text = "🎴"
		_sub.text = "BUY PACK — %d/%d 🪙" % [coins_parked, cost]


# Sell-mat price preview while a stack hovers over the zone; -1 restores.
func preview(value: int) -> void:
	if kind != "sell" or _sub == null:
		return
	if value >= 0:
		_sub.text = "SELL for %d 🪙" % value
		_sub.add_theme_color_override("font_color", Color("f2cf5b"))
	else:
		_update_labels()


func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.2)
	sb.set_corner_radius_all(20)
	draw_style_box(sb, Rect2(Vector2.ZERO, MAT_SIZE))
	# stitched edge, matching the play-mat border
	var stitch := Rect2(Vector2.ZERO, MAT_SIZE).grow(-10.0)
	var col := Color("e8d9ae", 0.3)
	draw_dashed_line(stitch.position, Vector2(stitch.end.x, stitch.position.y), col, 2.5, 12.0)
	draw_dashed_line(Vector2(stitch.position.x, stitch.end.y), stitch.end, col, 2.5, 12.0)
	draw_dashed_line(stitch.position, Vector2(stitch.position.x, stitch.end.y), col, 2.5, 12.0)
	draw_dashed_line(Vector2(stitch.end.x, stitch.position.y), stitch.end, col, 2.5, 12.0)
