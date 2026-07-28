extends Node

# Captures the running game to user://screenshot.png and quits.
# Launched via: godot --path . -- --screenshot
# Lets visual changes be reviewed without deploying to a device.


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	for i in 45:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://screenshot.png")
	print("SCREENSHOT SAVED: ", ProjectSettings.globalize_path("user://screenshot.png"))
	get_tree().quit(0)
