extends Node
## 音声の参照はこのノードでまとめて解放する。

var music: AudioStreamPlayer
var cues: Array[AudioStreamPlayer] = []
var tracks: Dictionary = {}
var sounds: Dictionary = {}
var current: String = ""
var closed: bool = false
var enabled: bool = false


func _ready() -> void:
	enabled = AudioServer.get_driver_name() != "Dummy" \
		or not Engine.get_write_movie_path().is_empty()
	music = AudioStreamPlayer.new()
	music.volume_db = -12
	add_child(music)
	for name: String in ["title", "field", "dungeon", "boss", "result"]:
		var stream: AudioStreamWAV = load("res://assets/audio/%s.wav" % name)
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
		tracks[name] = stream
	for name: String in ["sword", "tool", "hurt", "door", "chest", "defeat"]:
		sounds[name] = load("res://assets/audio/%s.wav" % name)
	for i: int in range(6):
		var player := AudioStreamPlayer.new()
		player.volume_db = -15
		add_child(player)
		cues.append(player)


func set_track(name: String) -> void:
	if closed or name == current:
		return
	current = name
	music.stream = tracks[name]
	if enabled:
		music.play()


# 別々の入力・命中に対応する音なので、要求ごとに鳴らす。
func cue(name: String) -> void:
	if closed or not enabled:
		return
	for player: AudioStreamPlayer in cues:
		if not player.playing:
			player.stream = sounds[name]
			player.play()
			return


func shutdown() -> void:
	if closed:
		return
	closed = true
	for player: AudioStreamPlayer in cues + [music]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	tracks.clear()
	sounds.clear()
	if enabled and AudioServer.get_driver_name() != "Dummy" and not OS.has_feature("web"):
		OS.delay_msec(150)


func _exit_tree() -> void:
	shutdown()
