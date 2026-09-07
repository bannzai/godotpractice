extends Node
## 音声の参照はこのノードでまとめて解放する。

var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var cues: Array[AudioStreamPlayer] = []
var tracks: Dictionary = {}
var ambient_tracks: Dictionary = {}
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
	ambience = AudioStreamPlayer.new()
	ambience.volume_db = -21
	add_child(ambience)
	for name: String in ["title", "field", "dungeon", "boss", "result"]:
		var stream: AudioStreamWAV = load("res://assets/audio/%s.wav" % name)
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
		tracks[name] = stream
	for name: String in ["coast", "forest", "marsh", "ruins"]:
		var stream: AudioStreamWAV = load("res://assets/audio/%s.wav" % name)
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
		ambient_tracks[name] = stream
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


func set_region(room: int) -> void:
	if closed:
		return
	var name: String = "ruins" if room >= 6 else (
		"marsh" if room == 3 else ("forest" if room in [2, 4] else "coast")
	)
	if ambience.stream == ambient_tracks[name]:
		return
	ambience.stream = ambient_tracks[name]
	if enabled:
		ambience.play()


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
	for player: AudioStreamPlayer in cues + [music, ambience]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	tracks.clear()
	ambient_tracks.clear()
	sounds.clear()
	if enabled and AudioServer.get_driver_name() != "Dummy" and not OS.has_feature("web"):
		OS.delay_msec(150)


func _exit_tree() -> void:
	shutdown()
