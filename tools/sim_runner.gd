extends Node

# Headless gameplay integration test. Launched by main.gd when the game is
# started with: godot --headless --path . -- --sim-test
# Drives the real board (autoloads and all) through the core loop and quits
# with a nonzero exit code on any failure.

var checks := 0
var fails: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func check(cond: bool, label: String) -> void:
	checks += 1
	if not cond:
		fails.append(label)
		printerr("  FAIL: %s" % label)


func _run() -> void:
	seed(1234567)
	var b: Board = GameState.board

	# T1: data loaded
	check(Db.cards.size() >= 20, "T1 cards loaded")
	check(Db.recipe_index.size() == Db.recipes.size(), "T1 unique recipe signatures")

	# T2: villager chops tree -> 3 wood, tree exhausts
	b.clear_board()
	var v := b.spawn_card("villager", Vector2(500, 500))
	var t := b.spawn_card("tree", Vector2(900, 900))
	b.merge_stacks(b.stack_of(v), b.stack_of(t))
	var vs := b.stack_of(v)
	check(not vs.work_recipe.is_empty() and String(vs.work_recipe["id"]) == "chop_wood", "T2 chop_wood starts")
	b.simulate(6.5)
	check(b.count_cards("wood") == 1, "T2 first wood after 6s (got %d)" % b.count_cards("wood"))
	check(t.charges_left == 2, "T2 tree decremented (got %d)" % t.charges_left)
	b.simulate(13.0)
	check(b.count_cards("wood") == 3, "T2 three wood total (got %d)" % b.count_cards("wood"))
	check(b.count_cards("tree") == 0, "T2 tree exhausted")
	check(b.stack_of(v).work_recipe.is_empty(), "T2 villager idle after tree gone")

	# T3: changing stack contents restarts work with the new recipe
	b.clear_board()
	var v2 := b.spawn_card("villager", Vector2(500, 500))
	var w1 := b.spawn_card("wood", Vector2(900, 900))
	b.merge_stacks(b.stack_of(v2), b.stack_of(w1))
	check(String(b.stack_of(v2).work_recipe.get("id", "")) == "cut_stick", "T3 cut_stick starts")
	b.simulate(2.0)
	var w2 := b.spawn_card("wood", Vector2(1200, 900))
	b.merge_stacks(b.stack_of(v2), b.stack_of(w2))
	var s3 := b.stack_of(v2)
	check(String(s3.work_recipe.get("id", "")) == "saw_plank", "T3 switches to saw_plank")
	check(s3.work_t == 0.0, "T3 timer reset on change")
	b.simulate(8.5)
	check(b.count_cards("plank") == 1, "T3 plank produced")
	check(b.count_cards("wood") == 0, "T3 wood consumed")
	check(b.count_cards("stick") == 0, "T3 no stray stick")

	# T4: selling wood yields a coin; second sale merges into the coin stack
	b.clear_board()
	var mat_center: Vector2 = b.sell_mat.zone().get_center()
	var wA := b.spawn_card("wood", mat_center - CardNode.SIZE / 2.0)
	b._drop(b.stack_of(wA))
	check(b.count_cards("coin") == 1, "T4 sell wood -> 1 coin")
	check(b.count_cards("wood") == 0, "T4 wood gone")
	var wB := b.spawn_card("wood", mat_center - CardNode.SIZE / 2.0)
	b._drop(b.stack_of(wB))
	check(b.count_cards("coin") == 2, "T4 second coin")
	var coin_stacks := 0
	for st in b.stacks:
		if st.is_coin_stack():
			coin_stacks += 1
	check(coin_stacks == 1, "T4 coins auto-merge into one stack (got %d)" % coin_stacks)

	# T5: buying and opening a pack
	b.clear_board()
	var c1 := b.spawn_card("coin", Vector2(500, 500))
	for i in 2:
		var extra := b._new_card("coin")
		b.stack_of(c1).cards.append(extra)
	var cs := b.stack_of(c1)
	cs.base_pos = b.buy_mat.zone().get_center() - CardNode.SIZE / 2.0
	b._drop(cs)
	check(b.count_cards("coin") == 0, "T5 coins consumed")
	check(b.count_cards("card_pack") == 1, "T5 pack dispensed")
	check(b.buy_mat.coins_parked == 0, "T5 parked coins reset")
	var pack_stack: StackData = null
	for st in b.stacks:
		if st.top() != null and st.top().id == "card_pack":
			pack_stack = st
			break
	check(pack_stack != null, "T5 pack stack found")
	if pack_stack != null:
		b._open_pack(pack_stack)
	var total_cards := 0
	for st in b.stacks:
		total_cards += st.cards.size()
	check(total_cards == 3, "T5 pack opens into 3 cards (got %d)" % total_cards)
	check(b.count_cards("card_pack") == 0, "T5 pack card gone")

	# T6: feeding succeeds with enough food
	b.clear_board()
	b.spawn_card("villager", Vector2(500, 500))
	var berry1 := b.spawn_card("berry", Vector2(900, 500))
	var berry_extra := b._new_card("berry")
	b.stack_of(berry1).cards.append(berry_extra)
	var sum6: Dictionary = b.day_end_feed()
	check(int(sum6["starved"]) == 0, "T6 nobody starves")
	check(int(sum6["eaten_food"]) == 2, "T6 two food eaten")
	check(b.count_cards("villager") == 1, "T6 villager alive")
	check(b.count_cards("berry") == 0, "T6 berries eaten")

	# T7: starvation kills the villager
	b.clear_board()
	b.spawn_card("villager", Vector2(500, 500))
	b.spawn_card("berry", Vector2(900, 500))
	var sum7: Dictionary = b.day_end_feed()
	check(int(sum7["starved"]) == 1, "T7 one starved")
	check(b.count_cards("villager") == 0, "T7 villager died")

	# T8: save/load roundtrip is lossless
	b.clear_board()
	var v8 := b.spawn_card("villager", Vector2(600, 600))
	var t8 := b.spawn_card("tree", Vector2(1000, 600))
	b.merge_stacks(b.stack_of(v8), b.stack_of(t8))
	b.simulate(2.0)
	b.spawn_card("wood", Vector2(1400, 800))
	var c8 := b.spawn_card("coin", Vector2(1800, 800))
	b.stack_of(c8).cards.append(b._new_card("coin"))
	b.buy_mat.coins_parked = 1
	GameState.day = 3
	var d1: Dictionary = b.serialize()
	SaveMgr.save_game()
	var loaded: Dictionary = SaveMgr.load_game()
	check(int(loaded.get("day", -1)) == 3, "T8 day saved")
	b.deserialize(loaded.get("board", {}))
	var d2: Dictionary = b.serialize()
	check(JSON.stringify(d1) == JSON.stringify(d2), "T8 board roundtrip identical")
	var vs8: StackData = null
	for st in b.stacks:
		if not st.work_recipe.is_empty():
			vs8 = st
	check(vs8 != null and absf(vs8.work_t - 2.0) < 0.1, "T8 work timer restored")

	# T9: day cycle state machine
	b.clear_board()
	b.spawn_card("villager", Vector2(600, 600))
	var b9 := b.spawn_card("berry", Vector2(1000, 600))
	b.stack_of(b9).cards.append(b._new_card("berry"))
	GameState.state = GameState.State.RUNNING
	GameState.day = 1
	GameState.day_time = GameState.DAY_LENGTH - 0.05
	var got_summary := [false]
	GameState.day_ended.connect(func(_s): got_summary[0] = true)
	GameState._process(0.1)
	check(GameState.state == GameState.State.DAY_END, "T9 day ends")
	check(get_tree().paused, "T9 paused at day end")
	check(got_summary[0], "T9 summary emitted")
	GameState.start_next_day()
	check(GameState.day == 2, "T9 day advanced")
	check(not get_tree().paused, "T9 unpaused")

	# leave no test save behind
	SaveMgr.clear_save()

	# let queue_free'd cards actually free so exit is leak-clean
	get_tree().paused = false
	await get_tree().process_frame
	await get_tree().process_frame

	if fails.is_empty():
		print("SIM PASS (%d checks)" % checks)
		get_tree().quit(0)
	else:
		print("SIM FAIL (%d of %d checks failed)" % [fails.size(), checks])
		get_tree().quit(1)
