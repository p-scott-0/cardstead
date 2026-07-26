class_name StackData
extends RefCounted

# A stack is a logical list of CardNodes plus a board position. Card nodes all
# live flat under the board's CardLayer; their draw order and on-screen offsets
# are derived from this structure every frame.

const Y_OFFSET := 38.0
const COIN_Y_OFFSET := 13.0

var cards: Array = []             # of CardNode, index 0 = bottom
var base_pos := Vector2.ZERO
var work_recipe: Dictionary = {}  # active recipe def, {} when idle
var work_t := 0.0


func size() -> int:
	return cards.size()


func is_empty() -> bool:
	return cards.is_empty()


func top():
	return cards.back() if not cards.is_empty() else null


func bottom():
	return cards[0] if not cards.is_empty() else null


func is_coin_stack() -> bool:
	return not cards.is_empty() and cards[0].id == "coin"


func y_offset() -> float:
	return COIN_Y_OFFSET if is_coin_stack() else Y_OFFSET


func card_ids() -> Array:
	var out := []
	for c in cards:
		out.append(c.id)
	return out


func rect() -> Rect2:
	var h := CardNode.SIZE.y + y_offset() * maxf(0.0, cards.size() - 1)
	return Rect2(base_pos, Vector2(CardNode.SIZE.x, h))


func top_card_rect() -> Rect2:
	return Rect2(target_pos_for(cards.size() - 1), CardNode.SIZE)


func bottom_card_rect() -> Rect2:
	return Rect2(base_pos, CardNode.SIZE)


func target_pos_for(index: int) -> Vector2:
	return base_pos + Vector2(0, y_offset() * index)
