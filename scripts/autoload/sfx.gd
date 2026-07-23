extends Node

# Tiny SFX pool. Streams are optional: missing files just no-op, so the game
# runs fine before assets are generated (and headless in CI).

const NAMES := ["place", "stack", "complete", "coin", "pack", "death"]
const POOL_SIZE := 8

var _streams := {}
var _players: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		var path := "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)


func play(sound: String, pitch := 1.0) -> void:
	if not GameState.sound_on:
		return
	if not _streams.has(sound):
		return
	for p in _players:
		if not p.playing:
			p.stream = _streams[sound]
			p.pitch_scale = pitch * randf_range(0.96, 1.05)
			p.play()
			return
