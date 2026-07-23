extends Node

# Global run state: day cycle state machine, discovery tracking, and the
# glue between the board, save system, and UI.

signal day_ended(summary: Dictionary)
signal run_over(day: int)
signal discovery_changed

const DAY_LENGTH := 120.0

enum State { MENU, RUNNING, DAY_END, GAME_OVER }

var state: State = State.MENU
var day := 1
var day_time := 0.0
var discovered_cards := {}
var discovered_recipes := {}
var sound_on := true

var board: Board = null
var camera: CameraRig = null


func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


func _process(delta: float) -> void:
	# _process pauses automatically with the tree, so no pause check needed.
	if state != State.RUNNING or board == null:
		return
	day_time += delta
	if day_time >= DAY_LENGTH:
		_end_day()


func _end_day() -> void:
	state = State.DAY_END
	get_tree().paused = true
	var summary := board.day_end_feed()
	summary["day"] = day
	if int(summary["villagers"]) + int(summary["babies"]) <= 0:
		state = State.GAME_OVER
		SaveMgr.clear_save()
		emit_signal("run_over", day)
	else:
		SaveMgr.save_game()
		emit_signal("day_ended", summary)


func start_next_day() -> void:
	day += 1
	day_time = 0.0
	state = State.RUNNING
	get_tree().paused = false
	SaveMgr.save_game()


func new_game() -> void:
	day = 1
	day_time = 0.0
	discovered_cards = {}
	discovered_recipes = {}
	board.setup_new_game()
	if camera != null:
		camera.position = Board.BOARD_SIZE / 2.0
		camera.zoom = Vector2(0.75, 0.75)
	state = State.RUNNING
	get_tree().paused = false
	SaveMgr.save_game()


func continue_game() -> bool:
	var data := SaveMgr.load_game()
	if data.is_empty():
		return false
	day = int(data.get("day", 1))
	day_time = clampf(float(data.get("day_time", 0.0)), 0.0, DAY_LENGTH)
	sound_on = bool(data.get("sound", true))
	discovered_cards = {}
	for id in data.get("discovered", {}).get("cards", []):
		discovered_cards[id] = true
	discovered_recipes = {}
	for id in data.get("discovered", {}).get("recipes", []):
		discovered_recipes[id] = true
	board.deserialize(data.get("board", {}))
	if camera != null and data.has("camera"):
		var cam: Dictionary = data["camera"]
		camera.position = Vector2(float(cam.get("x", 1500)), float(cam.get("y", 1000)))
		var z := clampf(float(cam.get("zoom", 0.75)), CameraRig.MIN_ZOOM, CameraRig.MAX_ZOOM)
		camera.zoom = Vector2(z, z)
	state = State.RUNNING
	get_tree().paused = false
	emit_signal("discovery_changed")
	return true


func to_menu() -> void:
	if state == State.RUNNING:
		SaveMgr.save_game()
	state = State.MENU
	get_tree().paused = true


func pause_game() -> void:
	if state == State.RUNNING:
		get_tree().paused = true


func resume_game() -> void:
	if state == State.RUNNING:
		get_tree().paused = false


func discover_card(id: String) -> void:
	if not discovered_cards.has(id):
		discovered_cards[id] = true
		emit_signal("discovery_changed")


func discover_recipe(id: String) -> void:
	if not discovered_recipes.has(id):
		discovered_recipes[id] = true
		emit_signal("discovery_changed")
