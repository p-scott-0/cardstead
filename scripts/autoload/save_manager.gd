extends Node

# JSON save to user://. Writes go to a temp file first, then replace the real
# save, so a mid-write kill never corrupts the only copy. Saves fire on a
# 20-second autosave cadence, at day end, and on iOS backgrounding.

const SAVE_PATH := "user://save.json"
const TMP_PATH := "user://save.tmp.json"
const AUTOSAVE_SEC := 20.0
const SCHEMA := 1

var _accum := 0.0


func _process(delta: float) -> void:
	if GameState.state != GameState.State.RUNNING:
		return
	_accum += delta
	if _accum >= AUTOSAVE_SEC:
		_accum = 0.0
		save_game()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			if GameState.state == GameState.State.RUNNING:
				save_game()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(TMP_PATH)


func clear_save() -> void:
	for p in [SAVE_PATH, TMP_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func save_game() -> void:
	if GameState.board == null:
		return
	var data := {
		"schema": SCHEMA,
		"version": GameState.version(),
		"saved_at": int(Time.get_unix_time_from_system()),
		"day": GameState.day,
		"day_time": snappedf(GameState.day_time, 0.01),
		"sound": GameState.sound_on,
		"discovered": {
			"cards": GameState.discovered_cards.keys(),
			"recipes": GameState.discovered_recipes.keys(),
		},
		"board": GameState.board.serialize(),
	}
	if GameState.camera != null:
		data["camera"] = {
			"x": snappedf(GameState.camera.position.x, 0.1),
			"y": snappedf(GameState.camera.position.y, 0.1),
			"zoom": snappedf(GameState.camera.zoom_level(), 0.001),
		}
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[Save] Cannot open %s for writing" % TMP_PATH)
		return
	f.store_string(JSON.stringify(data))
	f.close()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	var err := DirAccess.rename_absolute(TMP_PATH, SAVE_PATH)
	if err != OK:
		push_error("[Save] Rename failed with error %d" % err)


func load_game() -> Dictionary:
	var path := SAVE_PATH
	if not FileAccess.file_exists(path):
		if FileAccess.file_exists(TMP_PATH):
			path = TMP_PATH  # crashed between remove and rename; tmp is newest
		else:
			return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_warning("[Save] Corrupt save discarded")
		return {}
	if int(parsed.get("schema", 0)) != SCHEMA:
		push_warning("[Save] Unknown save schema %s; ignoring" % str(parsed.get("schema")))
		return {}
	return parsed
