extends Node2D

# Bootstraps the whole game programmatically: board, camera, UI overlays,
# and the signal wiring between them. With `-- --sim-test` on the command
# line it instead runs the headless gameplay simulation and quits.

var board: Board
var cam: CameraRig
var hud: Hud
var menu: MainMenu
var summary: DaySummaryPopup
var book: RecipeBook


func _ready() -> void:
	randomize()
	_build_game()

	if "--sim-test" in OS.get_cmdline_user_args():
		menu.visible = false
		GameState.new_game()
		var runner: Node = load("res://tools/sim_runner.gd").new()
		add_child(runner)
		return

	menu.show_mode("boot")
	get_tree().paused = true


func _build_game() -> void:
	board = Board.new()
	board.name = "Board"
	add_child(board)

	cam = CameraRig.new()
	cam.name = "CameraRig"
	cam.board_size = Board.BOARD_SIZE
	cam.position = Board.BOARD_SIZE / 2.0
	cam.zoom = Vector2(0.75, 0.75)
	add_child(cam)
	board.camera = cam

	GameState.board = board
	GameState.camera = cam

	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)

	hud = Hud.new()
	hud.name = "Hud"
	ui.add_child(hud)

	summary = DaySummaryPopup.new()
	summary.name = "DaySummary"
	ui.add_child(summary)

	book = RecipeBook.new()
	book.name = "RecipeBook"
	ui.add_child(book)

	menu = MainMenu.new()
	menu.name = "MainMenu"
	ui.add_child(menu)

	board.board_changed.connect(func(): hud.update_coins(board.count_cards("coin")))
	GameState.day_ended.connect(summary.show_summary)
	GameState.run_over.connect(menu.show_game_over)

	summary.next_day_pressed.connect(func():
		summary.visible = false
		GameState.start_next_day())

	hud.recipes_pressed.connect(book.open_book)
	hud.menu_pressed.connect(func():
		GameState.pause_game()
		menu.show_mode("pause"))

	menu.new_game_pressed.connect(func():
		menu.visible = false
		summary.visible = false
		GameState.new_game())
	menu.continue_pressed.connect(func():
		if GameState.continue_game():
			menu.visible = false)
	menu.resume_pressed.connect(func():
		menu.visible = false
		GameState.resume_game())
