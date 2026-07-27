class_name StackData
extends RefCounted

# A stack is a logical list of CardNodes plus a board position. Card nodes all
# live flat under the board's CardLayer; their draw order and on-screen offsets
# are derived from this structure every frame.

const Y_OFFSET := 38.0
const HEAD_GAP := 54.0  # first gap is wider: the bottom card's enlarged header is the whole-stack grab handle

var cards: Array = []             # of CardNode, index 0 = bottom
var base_pos := Vector2.ZERO
var work_recipe: Dictionary = {}  # active recipe def, {} when idle
var work_t := 0.0
var work_k := 0                   # how many cards from the top participate in work_recipe


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


func card_ids() -> Array:
	var out := []
	for c in cards:
		out.append(c.id)
	return out


func rect() -> Rect2:
	var h := CardNode.SIZE.y
	if cards.size() > 1:
		h += HEAD_GAP + Y_OFFSET * (cards.size() - 2)
	return Rect2(base_pos, Vector2(CardNode.SIZE.x, h))


func top_card_rect() -> Rect2:
	return Rect2(target_pos_for(cards.size() - 1), CardNode.SIZE)


func bottom_card_rect() -> Rect2:
	return Rect2(base_pos, CardNode.SIZE)


func target_pos_for(index: int) -> Vector2:
	if index <= 0:
		return base_pos
	return base_pos + Vector2(0, HEAD_GAP + Y_OFFSET * (index - 1))
