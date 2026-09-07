extends Node
## 曲の再生先を固定し、終了時の音声解放を集約する。

var music: AudioStreamPlayer
var effects: AudioStreamPlayer
var ambience: AudioStreamPlayer
var current: String = ""
var stopped: bool = false


func _ready() -> void:
	music = AudioStreamPlayer.new()
	music.volume_db = -14
	add_child(music)
	effects = AudioStreamPlayer.new()
	effects.volume_db = -9
	add_child(effects)
	ambience = AudioStreamPlayer.new()
	ambience.volume_db = -25
	add_child(ambience)


func track(id: String) -> void:
	if stopped or current == id or not is_instance_valid(music):
		return
	current = id
	music.stop()
	var stream := load("res://assets/audio/%s.wav" % id) as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	music.stream = stream
	music.play()


## 一回の操作音を鳴らすため非冪等。
func play(id: String) -> void:
	if stopped or not is_instance_valid(effects):
		return
	effects.stream = load("res://assets/audio/%s.wav" % id)
	effects.play()


func set_ambience(enabled: bool) -> void:
	if stopped or not is_instance_valid(ambience):
		return
	if enabled and not ambience.playing:
		var stream := load("res://assets/audio/rural_ambience.wav") as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		ambience.stream = stream
		ambience.play()
	elif not enabled and ambience.playing:
		ambience.stop()
		ambience.stream = null


func stop_audio() -> void:
	stopped = true
	for player: AudioStreamPlayer in [music, effects, ambience]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null


func _exit_tree() -> void:
	stop_audio()
	# stop は音声ミキサーへ解放を要求するため、その反映まで待つ。
	if not OS.has_feature("web") and not OS.has_feature("movie"):
		OS.delay_msec(150)
