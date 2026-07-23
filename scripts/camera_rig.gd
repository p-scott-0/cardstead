class_name CameraRig
extends Camera2D

# Pan/zoom camera. The board forwards touches that didn't land on a card:
# one finger pans, two fingers pinch-zoom about the pinch midpoint, and the
# mouse wheel zooms on desktop. Position is soft-clamped to the board.

const MIN_ZOOM := 0.5
const MAX_ZOOM := 1.5
const EDGE_MARGIN := 120.0

var board_size := Vector2(3000, 2000)


func _ready() -> void:
	make_current()


func zoom_level() -> float:
	return zoom.x


func set_zoom_level(z: float, screen_anchor: Vector2) -> void:
	z = clampf(z, MIN_ZOOM, MAX_ZOOM)
	var before := screen_to_world(screen_anchor)
	zoom = Vector2(z, z)
	var after := screen_to_world(screen_anchor)
	position += before - after
	_clamp_position()


func pan_by_screen(rel: Vector2) -> void:
	position -= rel / zoom.x
	_clamp_position()


func screen_to_world(p: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * p


func _clamp_position() -> void:
	var half := get_viewport_rect().size / (2.0 * zoom.x)
	position.x = _soft_clamp(position.x, half.x - EDGE_MARGIN, board_size.x - half.x + EDGE_MARGIN)
	position.y = _soft_clamp(position.y, half.y - EDGE_MARGIN, board_size.y - half.y + EDGE_MARGIN)


static func _soft_clamp(v: float, lo: float, hi: float) -> float:
	if lo > hi:
		return (lo + hi) * 0.5
	return clampf(v, lo, hi)
