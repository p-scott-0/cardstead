extends SceneTree

# Fast headless validation: data files parse and cross-reference cleanly,
# every script compiles, and the main scene loads.
# Run: godot --headless --path . --script res://tools/smoke_test.gd


func _initialize() -> void:
	var errs: Array = []

	var db = load("res://scripts/autoload/db.gd").new()
	errs.append_array(db.load_all())
	db.free()

	for dir_path in ["res://scripts", "res://scripts/autoload", "res://scripts/ui", "res://tools"]:
		var d := DirAccess.open(dir_path)
		if d == null:
			errs.append("Cannot open %s" % dir_path)
			continue
		for f in d.get_files():
			if not f.ends_with(".gd"):
				continue
			var path := "%s/%s" % [dir_path, f]
			var s = load(path)
			if s == null:
				errs.append("Failed to load %s" % path)
			elif s is GDScript and not (s as GDScript).can_instantiate():
				errs.append("Compile error in %s" % path)

	var scene = load("res://scenes/main.tscn")
	if scene == null or not (scene as PackedScene).can_instantiate():
		errs.append("main.tscn failed to load")

	if errs.is_empty():
		print("SMOKE PASS")
		quit(0)
	else:
		for e in errs:
			printerr("SMOKE: %s" % str(e))
		print("SMOKE FAIL (%d errors)" % errs.size())
		quit(1)
