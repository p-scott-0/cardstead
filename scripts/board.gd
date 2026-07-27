class_name Board
extends Node2D

# The play field. Owns every stack, routes all touch input (drag cards, pan,
# pinch — forwarded to the camera), runs work timers, the soft push-apart,
# selling/buying, pack opening, feeding, and save serialization.

signal board_changed
signal recipe_completed(recipe_id: String)

const BOARD_SIZE := Vector2(3000, 2000)
const TAP_TIME_MS := 350
const TAP_DIST := 14.0
const SEPARATION_RATE := 6.0
const MAX_PUSH_STEP := 40.0
const PILE_MERGE_RADIUS := 300.0

var camera: CameraRig
var card_layer: Node2D
var sell_mat: MatNode
var buy_mat: MatNode
var stacks: Array = []  # of StackData; array order == draw order (later on top)

# --- input state ---
var dragged: StackData = null
var drag_touch := -1
var drag_offset := Vector2.ZERO
var drag_start_screen := Vector2.ZERO
var drag_start_ms := 0
var drag_moved := false
var pan_touch := -1
var pinch_touch := -1
var pinch_d0 := 1.0
var pinch_z0 := 1.0
var last_screen := {}  # touch index -> screen pos


func _ready() -> void:
	card_layer = Node2D.new()
	card_layer.name = "CardLayer"

	sell_mat = MatNode.new()
	sell_mat.kind = "sell"
	sell_mat.name = "SellMat"
	sell_mat.position = Vector2(360, 1620)
	add_child(sell_mat)

	buy_mat = MatNode.new()
	buy_mat.kind = "buy"
	buy_mat.name = "BuyMat"
	buy_mat.cost = int(Db.pack("basic_pack").get("cost", 3))
	buy_mat.position = Vector2(BOARD_SIZE.x - 360 - MatNode.MAT_SIZE.x, 1620)
	add_child(buy_mat)

	add_child(card_layer)


# ---------------------------------------------------------------- lifecycle

func setup_new_game() -> void:
	clear_board()
	var c := BOARD_SIZE / 2.0
	spawn_card("villager", c + Vector2(-420, -120))
	spawn_card("villager", c + Vector2(-240, 60))
	spawn_card("tree", c + Vector2(60, -200))
	spawn_card("rock", c + Vector2(260, -60))
	spawn_card("berry_bush", c + Vector2(20, 120))
	var berries := spawn_card("berry", c + Vector2(-500, 200))
	for i in 2:
		var extra := _new_card("berry")
		stack_of(berries).cards.append(extra)
	spawn_card("soil", c + Vector2(240, 220))
	var coin := spawn_card("coin", c + Vector2(-680, -40))
	for i in 2:
		var extra_coin := _new_card("coin")
		stack_of(coin).cards.append(extra_coin)
	spawn_card("card_pack", c + Vector2(480, -260))
	_snap_all_cards()
	emit_signal("board_changed")


func clear_board() -> void:
	for st in stacks:
		for c in st.cards:
			c.queue_free()
	stacks.clear()
	dragged = null
	drag_touch = -1
	pan_touch = -1
	pinch_touch = -1
	last_screen.clear()
	buy_mat.coins_parked = 0


func _snap_all_cards() -> void:
	for st in stacks:
		for i in st.cards.size():
			st.cards[i].position = st.target_pos_for(i)


# ---------------------------------------------------------------- spawning

func _new_card(id: String) -> CardNode:
	var def := Db.card(id)
	var card := CardNode.new()
	card_layer.add_child(card)
	card.setup(def)
	GameState.discover_card(id)
	return card


# `origin` (optional): where the card visually appears from — it slides to
# its resting spot and pops in, instead of blinking into existence.
func spawn_card(id: String, pos: Vector2, charges := -1, origin := Vector2.INF) -> CardNode:
	var card := _new_card(id)
	if charges >= 0:
		card.charges_left = charges
	var st := StackData.new()
	st.cards = [card]
	st.base_pos = clamp_to_board(pos)
	stacks.append(st)
	if origin.is_finite():
		card.position = origin
		_pop_in(card)
	else:
		card.position = st.base_pos
	recheck_stack(st)
	return card


# Produced cards pool into a nearby pile of the same card (a stack made
# entirely of that card, not currently working); otherwise they spawn fresh
# beside their source.
func spawn_output(id: String, from_pos: Vector2) -> void:
	var pile := _find_pile(id, from_pos)
	if pile != null:
		var c := _new_card(id)
		c.position = from_pos
		pile.cards.append(c)
		_pop_in(c)
		recheck_stack(pile)
	else:
		spawn_card(id, find_free_spot(from_pos), -1, from_pos)


func _find_pile(id: String, near: Vector2) -> StackData:
	var best: StackData = null
	var best_d := PILE_MERGE_RADIUS
	for st: StackData in stacks:
		if st == dragged or st.is_empty() or not st.work_recipe.is_empty():
			continue
		var pure := true
		for c in st.cards:
			if c.id != id:
				pure = false
				break
		if not pure:
			continue
		var d := st.base_pos.distance_to(near)
		if d < best_d:
			best_d = d
			best = st
	return best


func _pop_in(card: CardNode) -> void:
	card.scale = Vector2(0.35, 0.35)
	var tw := card.create_tween()
	tw.tween_property(card, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func count_cards(id: String) -> int:
	var n := 0
	for st in stacks:
		for c in st.cards:
			if c.id == id:
				n += 1
	return n


func stack_of(card: CardNode) -> StackData:
	for st in stacks:
		if card in st.cards:
			return st
	return null


func clamp_to_board(p: Vector2) -> Vector2:
	return Vector2(
		clampf(p.x, 0.0, BOARD_SIZE.x - CardNode.SIZE.x),
		clampf(p.y, 0.0, BOARD_SIZE.y - CardNode.SIZE.y - 60.0))


func find_free_spot(near: Vector2) -> Vector2:
	var probe := near + Vector2(CardNode.SIZE.x + 24, 0)
	for ring in 4:
		var r := 90.0 + 120.0 * ring
		for k in 10:
			var ang := TAU * float(k) / 10.0 + ring * 0.35
			var p := clamp_to_board(near + Vector2(cos(ang), sin(ang)) * r)
			var rect := Rect2(p, CardNode.SIZE)
			var free := true
			for st in stacks:
				if st.rect().intersects(rect):
					free = false
					break
			if free:
				return p
	return clamp_to_board(probe + Vector2(randf_range(-40, 40), randf_range(-40, 40)))


# ---------------------------------------------------------------- recipes

# A stack works when the LARGEST group of cards counted from the top exactly
# matches a recipe. Whole-stack matches win (largest first); smaller suffixes
# let a villager on top of a pile of bushes forage the one beneath and keep
# going as they deplete.
func recheck_stack(st: StackData) -> void:
	st.work_recipe = {}
	st.work_t = 0.0
	st.work_k = 0
	if st.is_empty():
		return
	var ids := st.card_ids()
	for k in range(ids.size(), 0, -1):
		var sig := RecipeEngine.signature_of_ids(ids.slice(ids.size() - k))
		var r: Dictionary = Db.recipe_index.get(sig, {})
		if not r.is_empty():
			st.work_recipe = r
			st.work_k = k
			break
	for i in st.cards.size():
		st.cards[i].set_stack_head(i == 0 and st.cards.size() >= 2)
	queue_redraw()


func _complete_work(st: StackData) -> void:
	var r := st.work_recipe
	var k := st.work_k if st.work_k > 0 else st.cards.size()
	st.work_recipe = {}
	st.work_t = 0.0
	st.work_k = 0
	var keep: Array = r.get("keep", [])
	var dec: Array = r.get("decrement", [])
	var needed: Dictionary = (r["inputs"] as Dictionary).duplicate()
	var lower: Array = st.cards.slice(0, st.cards.size() - k)
	var suffix: Array = st.cards.slice(st.cards.size() - k)
	var remaining: Array = []
	var freed: Array = []
	for c in suffix:
		if int(needed.get(c.id, 0)) > 0:
			needed[c.id] = int(needed[c.id]) - 1
			if c.id in keep:
				remaining.append(c)
			elif c.id in dec:
				c.charges_left -= 1
				if c.charges_left <= 0:
					freed.append(c)
				else:
					remaining.append(c)
			else:
				freed.append(c)
		else:
			remaining.append(c)
	st.cards = lower + remaining
	for c in freed:
		c.queue_free()

	var outputs: Dictionary = r["outputs"]
	for out_id in outputs:
		for i in int(outputs[out_id]):
			spawn_output(String(out_id), st.base_pos)

	GameState.discover_recipe(String(r["id"]))
	Sfx.play("complete")
	if st.is_empty():
		stacks.erase(st)
	else:
		recheck_stack(st)
	emit_signal("recipe_completed", String(r["id"]))
	emit_signal("board_changed")


# ---------------------------------------------------------------- per-frame

func _process(delta: float) -> void:
	# freeze work and card easing while the day-end animation plays
	if GameState.state == GameState.State.DAY_END:
		return
	var any_work := false
	if not GameState.time_paused:
		for st in stacks:
			if st.work_recipe.is_empty() or st == dragged:
				continue
			any_work = true
			st.work_t += delta
			if st.work_t >= float(st.work_recipe["time"]):
				_complete_work(st)
				break  # stacks array mutated; catch the rest next frame
	if any_work:
		queue_redraw()

	for st: StackData in stacks:
		for i in st.cards.size():
			var c: CardNode = st.cards[i]
			var target := st.target_pos_for(i)
			var speed := 25.0 if st == dragged else 16.0
			c.position = c.position.lerp(target, clampf(delta * speed, 0.0, 1.0))


func _physics_process(delta: float) -> void:
	var n := stacks.size()
	for i in n:
		var a: StackData = stacks[i]
		if a == dragged:
			continue
		var ra := a.rect().grow(-8.0)
		for j in range(i + 1, n):
			var b: StackData = stacks[j]
			if b == dragged:
				continue
			var rb := b.rect().grow(-8.0)
			if not ra.intersects(rb):
				continue
			var ov_x := minf(ra.end.x, rb.end.x) - maxf(ra.position.x, rb.position.x)
			var ov_y := minf(ra.end.y, rb.end.y) - maxf(ra.position.y, rb.position.y)
			var dir := rb.get_center() - ra.get_center()
			if ov_x < ov_y:
				var s := signf(dir.x)
				if s == 0.0:
					s = 1.0
				var push_x := minf(ov_x, MAX_PUSH_STEP) * SEPARATION_RATE * delta
				a.base_pos.x -= s * push_x
				b.base_pos.x += s * push_x
			else:
				var s2 := signf(dir.y)
				if s2 == 0.0:
					s2 = 1.0
				var push_y := minf(ov_y, MAX_PUSH_STEP) * SEPARATION_RATE * delta
				a.base_pos.y -= s2 * push_y
				b.base_pos.y += s2 * push_y
	for st in stacks:
		st.base_pos = clamp_to_board(st.base_pos)


# Advance the whole board by `seconds` in fixed steps (used by the sim test).
func simulate(seconds: float, step := 1.0 / 30.0) -> void:
	var t := 0.0
	while t < seconds:
		_process(step)
		_physics_process(step)
		t += step


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	# felt background + border + subtle grid
	draw_rect(Rect2(Vector2.ZERO, BOARD_SIZE), Color("2c5941"))
	for gx in range(0, int(BOARD_SIZE.x) + 1, 250):
		draw_line(Vector2(gx, 0), Vector2(gx, BOARD_SIZE.y), Color(1, 1, 1, 0.03), 2.0)
	for gy in range(0, int(BOARD_SIZE.y) + 1, 250):
		draw_line(Vector2(0, gy), Vector2(BOARD_SIZE.x, gy), Color(1, 1, 1, 0.03), 2.0)
	draw_rect(Rect2(Vector2.ZERO, BOARD_SIZE), Color("1d3b2b"), false, 12.0)

	# work progress bars (only while a recipe is running)
	for st: StackData in stacks:
		if st.work_recipe.is_empty():
			continue
		var frac := clampf(st.work_t / float(st.work_recipe["time"]), 0.0, 1.0)
		var bar := Rect2(st.base_pos + Vector2(0, -20), Vector2(CardNode.SIZE.x, 12))
		draw_rect(bar.grow(2.0), Color(0, 0, 0, 0.4))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Color("f2cf5b"))


# ---------------------------------------------------------------- input

func to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos


func _unhandled_input(event: InputEvent) -> void:
	if GameState.state == GameState.State.DAY_END:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index, event.position)
	elif event is InputEventScreenDrag:
		_touch_move(event.index, event.position)
	elif event is InputEventMouseButton and event.pressed and camera != null:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.set_zoom_level(camera.zoom_level() * 1.12, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.set_zoom_level(camera.zoom_level() / 1.12, event.position)


func _hit_test(world_pos: Vector2) -> Dictionary:
	for si in range(stacks.size() - 1, -1, -1):
		var st: StackData = stacks[si]
		if st == dragged:
			continue
		# check cards top-down so the visually-topmost card wins
		for ci in range(st.cards.size() - 1, -1, -1):
			if Rect2(st.target_pos_for(ci), CardNode.SIZE).has_point(world_pos):
				return {"stack": st, "index": ci}
	return {}


func _touch_down(idx: int, spos: Vector2) -> void:
	last_screen[idx] = spos
	# second finger while panning starts a pinch
	if pan_touch != -1 and pinch_touch == -1 and idx != pan_touch and camera != null:
		pinch_touch = idx
		pinch_d0 = maxf(1.0, spos.distance_to(last_screen.get(pan_touch, spos)))
		pinch_z0 = camera.zoom_level()
		return
	if dragged != null:
		return  # one drag at a time; ignore extra fingers
	var hit := _hit_test(to_world(spos))
	if hit.is_empty():
		if pan_touch == -1:
			pan_touch = idx
		return
	_pickup(hit["stack"], hit["index"], idx, spos)


func _pickup(st: StackData, index: int, idx: int, spos: Vector2) -> void:
	var wpos := to_world(spos)
	var picked: StackData
	if index == 0:
		picked = st
	else:
		picked = StackData.new()
		picked.cards = st.cards.slice(index)
		st.cards = st.cards.slice(0, index)
		picked.base_pos = st.target_pos_for(index)
		stacks.append(picked)
		recheck_stack(st)
	recheck_stack(picked)  # refresh stack-head flags for the carried substack
	picked.work_recipe = {}
	picked.work_t = 0.0
	picked.work_k = 0
	dragged = picked
	drag_touch = idx
	drag_offset = wpos - picked.base_pos
	drag_start_screen = spos
	drag_start_ms = Time.get_ticks_msec()
	drag_moved = false
	_raise(picked)
	for c in picked.cards:
		c.set_lifted(true)


func _raise(st: StackData) -> void:
	stacks.erase(st)
	stacks.append(st)
	for c in st.cards:
		card_layer.move_child(c, card_layer.get_child_count() - 1)


func _touch_move(idx: int, spos: Vector2) -> void:
	var prev: Vector2 = last_screen.get(idx, spos)
	last_screen[idx] = spos
	if pinch_touch != -1 and (idx == pinch_touch or idx == pan_touch):
		_update_pinch()
		return
	if idx == pan_touch:
		if camera != null:
			camera.pan_by_screen(spos - prev)
		return
	if idx == drag_touch and dragged != null:
		if spos.distance_to(drag_start_screen) > TAP_DIST:
			drag_moved = true
		dragged.base_pos = clamp_to_board(to_world(spos) - drag_offset)
		var over_sell := sell_mat.zone().has_point(dragged.bottom_card_rect().get_center())
		sell_mat.preview(_stack_sell_value(dragged) if over_sell else -1)


func _update_pinch() -> void:
	if camera == null or pan_touch == -1 or pinch_touch == -1:
		return
	if not (last_screen.has(pan_touch) and last_screen.has(pinch_touch)):
		return
	var p1: Vector2 = last_screen[pan_touch]
	var p2: Vector2 = last_screen[pinch_touch]
	var d := maxf(1.0, p1.distance_to(p2))
	camera.set_zoom_level(pinch_z0 * d / pinch_d0, (p1 + p2) * 0.5)


func _touch_up(idx: int, spos: Vector2) -> void:
	last_screen.erase(idx)
	if idx == pinch_touch:
		pinch_touch = -1
		return
	if idx == pan_touch:
		if pinch_touch != -1:
			pan_touch = pinch_touch
			pinch_touch = -1
		else:
			pan_touch = -1
		return
	if idx == drag_touch and dragged != null:
		var is_tap := (Time.get_ticks_msec() - drag_start_ms) < TAP_TIME_MS and not drag_moved
		var st := dragged
		dragged = null
		drag_touch = -1
		_drop(st, is_tap)


# ---------------------------------------------------------------- dropping

func _stack_sell_value(st: StackData) -> int:
	var total := 0
	for c in st.cards:
		if bool(c.def.get("sellable", false)):
			total += int(c.def.get("sell", 0))
	return total


func total_cards() -> int:
	var n := 0
	for st: StackData in stacks:
		n += st.cards.size()
	return n


# x = food available on the board, y = food needed at day end
func food_stats() -> Vector2i:
	var have := 0
	var need := 0
	for st in stacks:
		for c in st.cards:
			have += int(c.def.get("food_value", 0))
			need += int(c.def.get("eats", 0))
	return Vector2i(have, need)


func _drop(st: StackData, is_tap := false) -> void:
	sell_mat.preview(-1)
	for c in st.cards:
		c.set_lifted(false)

	if is_tap and st.size() == 1 and st.top().id == "card_pack":
		_open_pack(st)
		return

	var center := st.bottom_card_rect().get_center()
	if sell_mat.zone().has_point(center):
		_sell_drop(st)
		emit_signal("board_changed")
		return
	if buy_mat.zone().has_point(center):
		_buy_drop(st)
		emit_signal("board_changed")
		return

	var target := _find_target(st)
	if target != null and _can_stack(target, st):
		target.cards.append_array(st.cards)
		stacks.erase(st)
		_raise(target)
		Sfx.play("stack")
		_buzz(15)
		recheck_stack(target)
	else:
		st.base_pos = clamp_to_board(st.base_pos)
		Sfx.play("place")
		recheck_stack(st)
	emit_signal("board_changed")


func merge_stacks(dst: StackData, src: StackData) -> void:
	if dst == src:
		return
	dst.cards.append_array(src.cards)
	stacks.erase(src)
	recheck_stack(dst)
	emit_signal("board_changed")


func _find_target(st: StackData) -> StackData:
	var my_rect := st.bottom_card_rect()
	var card_area := CardNode.SIZE.x * CardNode.SIZE.y
	for si in range(stacks.size() - 1, -1, -1):
		var cand: StackData = stacks[si]
		if cand == st:
			continue
		var overlap := my_rect.intersection(cand.top_card_rect())
		if overlap.size.x * overlap.size.y >= card_area * 0.25:
			return cand
	return null


func _can_stack(target: StackData, moving: StackData) -> bool:
	var t_top: CardNode = target.top()
	var m_bot: CardNode = moving.bottom()
	if t_top == null or m_bot == null:
		return false
	if t_top.id == "card_pack" or m_bot.id == "card_pack":
		return false
	if t_top.id == "coin" or m_bot.id == "coin":
		return t_top.id == "coin" and m_bot.id == "coin"
	return true


func _sell_drop(st: StackData) -> void:
	var total := 0
	var keepers: Array = []
	for c in st.cards:
		if bool(c.def.get("sellable", false)):
			total += int(c.def.get("sell", 0))
			c.queue_free()
		else:
			keepers.append(c)
	if total > 0:
		Sfx.play("coin")
		var coin_from := sell_mat.position + Vector2(MatNode.MAT_SIZE.x * 0.5 - CardNode.SIZE.x * 0.5, -CardNode.SIZE.y - 60)
		for i in total:
			spawn_output("coin", coin_from)
	if keepers.is_empty():
		stacks.erase(st)
	else:
		st.cards = keepers
		st.base_pos = clamp_to_board(sell_mat.position + Vector2(MatNode.MAT_SIZE.x + 40, 0))
		recheck_stack(st)


func _buy_drop(st: StackData) -> void:
	var all_coins := true
	for c in st.cards:
		if c.id != "coin":
			all_coins = false
			break
	if not all_coins:
		st.base_pos = clamp_to_board(buy_mat.position + Vector2(-CardNode.SIZE.x - 40, 0))
		recheck_stack(st)
		return
	buy_mat.coins_parked += st.cards.size()
	for c in st.cards:
		c.queue_free()
	stacks.erase(st)
	Sfx.play("coin")
	while buy_mat.coins_parked >= buy_mat.cost:
		buy_mat.coins_parked -= buy_mat.cost
		spawn_card("card_pack", buy_mat.position + Vector2(MatNode.MAT_SIZE.x * 0.5 - CardNode.SIZE.x * 0.5, -CardNode.SIZE.y - 40), -1, buy_mat.zone().get_center())
		Sfx.play("pack")


func _open_pack(st: StackData) -> void:
	var pack_def := Db.pack("basic_pack")
	var origin := st.base_pos
	var pack_card: CardNode = st.top()
	st.cards.erase(pack_card)
	pack_card.queue_free()
	if st.is_empty():
		stacks.erase(st)
	Sfx.play("pack")
	_buzz(20)
	var weights: Dictionary = pack_def.get("weights", {})
	for i in int(pack_def.get("count", 3)):
		var id := _weighted_pick(weights)
		var ang := -PI * 0.5 + (i - 1) * 0.55
		var p := clamp_to_board(origin + Vector2(cos(ang), sin(ang)) * 230.0)
		spawn_card(id, p, -1, origin)
	emit_signal("board_changed")


func _weighted_pick(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	if total <= 0.0:
		return "berry"
	var roll := randf() * total
	for k in weights:
		roll -= float(weights[k])
		if roll <= 0.0:
			return String(k)
	return String(weights.keys().back())


# ---------------------------------------------------------------- day cycle

# Decides who eats what and who starves, WITHOUT touching the board.
# Returns {eaten: [CardNode], victims: [CardNode], summary: Dictionary}.
func _plan_feed() -> Dictionary:
	var villagers: Array = []
	var babies: Array = []
	var foods: Array = []
	for st in stacks:
		for c in st.cards:
			if c.id == "villager":
				villagers.append(c)
			elif c.id == "baby":
				babies.append(c)
			elif int(c.def.get("food_value", 0)) > 0:
				foods.append(c)
	foods.sort_custom(func(a, b): return int(a.def["food_value"]) < int(b.def["food_value"]))

	var need := 0
	for v in villagers:
		need += int(v.def.get("eats", 2))
	for b in babies:
		need += int(b.def.get("eats", 1))

	var eaten: Array = []
	var eaten_food := 0
	var eaten_by_id := {}
	for f in foods:
		if need <= 0:
			break
		need -= int(f.def["food_value"])
		eaten_food += int(f.def["food_value"])
		eaten_by_id[f.id] = int(eaten_by_id.get(f.id, 0)) + 1
		eaten.append(f)

	var victims: Array = []
	while need > 0 and (babies.size() + villagers.size()) > 0:
		var victim: CardNode
		if babies.size() > 0:
			victim = babies.pop_back()
		else:
			victim = villagers.pop_back()
		need -= int(victim.def.get("eats", 2))
		victims.append(victim)

	return {
		"eaten": eaten,
		"victims": victims,
		"summary": {
			"villagers": villagers.size(),
			"babies": babies.size(),
			"eaten_food": eaten_food,
			"eaten_cards": eaten.size(),
			"eaten": eaten_by_id,
			"starved": victims.size(),
		},
	}


# Synchronous feed (sim tests + headless): apply the plan instantly.
func day_end_feed() -> Dictionary:
	var plan := _plan_feed()
	for c in plan["eaten"]:
		_remove_card(c)
	for v in plan["victims"]:
		_remove_card(v)
	if plan["victims"].size() > 0:
		Sfx.play("death")
		_buzz(120)
	emit_signal("board_changed")
	return plan["summary"]


# Animated feed: eaten cards shrink and drift up, starved units fade out,
# then the board is updated. Input and work timers are held during DAY_END.
func day_end_feed_animated() -> Dictionary:
	var plan := _plan_feed()
	var doomed: Array = plan["eaten"] + plan["victims"]
	if doomed.is_empty():
		emit_signal("board_changed")
		return plan["summary"]
	if plan["victims"].size() > 0:
		Sfx.play("death")
		_buzz(120)
	else:
		Sfx.play("place")
	var delay := 0.0
	var last_tween: Tween = null
	for c in doomed:
		var tint := Color(1.0, 0.45, 0.4) if c in plan["victims"] else Color(1, 1, 1)
		var tw: Tween = c.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(c, "modulate", Color(tint, 0.0), 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(c, "scale", Vector2(0.1, 0.1), 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(c, "position", c.position + Vector2(0, -60), 0.45)
		delay += 0.07
		last_tween = tw
	await last_tween.finished
	for c in doomed:
		_remove_card(c)
	emit_signal("board_changed")
	return plan["summary"]


func _remove_card(card: CardNode) -> void:
	var st := stack_of(card)
	if st == null:
		return
	st.cards.erase(card)
	card.queue_free()
	if st.is_empty():
		stacks.erase(st)
	else:
		recheck_stack(st)


func _buzz(ms: int) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


# ---------------------------------------------------------------- save/load

func serialize() -> Dictionary:
	var out_stacks := []
	for st in stacks:
		var cs := []
		for c in st.cards:
			var d := {"id": c.id}
			if int(c.def.get("charges", 0)) > 0:
				d["charges"] = c.charges_left
			cs.append(d)
		var s := {
			"x": snappedf(st.base_pos.x, 0.1),
			"y": snappedf(st.base_pos.y, 0.1),
			"cards": cs,
		}
		if not st.work_recipe.is_empty():
			s["work"] = {"recipe": String(st.work_recipe["id"]), "t": snappedf(st.work_t, 0.01)}
		out_stacks.append(s)
	return {"stacks": out_stacks, "buy_coins": buy_mat.coins_parked}


func deserialize(data: Dictionary) -> void:
	clear_board()
	buy_mat.coins_parked = int(data.get("buy_coins", 0))
	for s in data.get("stacks", []):
		var st := StackData.new()
		st.base_pos = clamp_to_board(Vector2(float(s.get("x", 0)), float(s.get("y", 0))))
		for cd in s.get("cards", []):
			var id := String(cd.get("id", ""))
			if not Db.has_card(id):
				push_warning("Save contains unknown card '%s'; skipped" % id)
				continue
			var card := _new_card(id)
			if cd.has("charges"):
				card.charges_left = int(cd["charges"])
			st.cards.append(card)
		if st.is_empty():
			continue
		stacks.append(st)
		recheck_stack(st)
		if s.has("work") and not st.work_recipe.is_empty():
			var w: Dictionary = s["work"]
			if String(w.get("recipe", "")) == String(st.work_recipe["id"]):
				st.work_t = clampf(float(w.get("t", 0.0)), 0.0, float(st.work_recipe["time"]))
	_snap_all_cards()
	emit_signal("board_changed")
