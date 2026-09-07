extends Node
## 場面BGM・環境音と操作SE。通常終了は停止後に数フレーム描画してからツリーを終了する。

var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var effects: Array[AudioStreamPlayer] = []
var current_cue: String = ""
var voice: int = 0
var has_played: bool = false
var muted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music = AudioStreamPlayer.new()
	music.volume_db = -13.0
	add_child(music)
	ambience = AudioStreamPlayer.new()
	ambience.volume_db = -18.0
	add_child(ambience)
	for index: int in range(4):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.volume_db = -8.0
		add_child(player)
		effects.append(player)


func play_music(cue: String) -> void:
	if not is_instance_valid(music) or muted or DisplayServer.get_name() == "headless":
		return
	if cue not in ["title", "stage", "battle", "result"]:
		return
	play_ambience()
	if cue == current_cue and music.playing:
		return
	current_cue = cue
	var stream: AudioStreamOggVorbis = load("res://assets/audio/%s.ogg" % cue)
	stream.loop = true
	music.stream = stream
	music.play()
	has_played = true


func play_ambience() -> void:
	if not is_instance_valid(ambience) or ambience.playing:
		return
	var stream: AudioStreamOggVorbis = load("res://assets/audio/ambience.ogg")
	stream.loop = true
	ambience.stream = stream
	ambience.play()


func play_sfx(cue: String) -> void:
	# 操作に対応する発音イベントなので、呼ぶたびに音を重ねる非冪等な関数。
	if effects.is_empty() or muted or DisplayServer.get_name() == "headless":
		return
	if cue not in ["attack", "heal", "level", "confirm", "fan"]:
		return
	effects[voice].stream = load("res://assets/audio/%s.ogg" % cue)
	effects[voice].play()
	voice = (voice + 1) % effects.size()
	has_played = true


func stop_audio() -> void:
	current_cue = ""
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	if is_instance_valid(ambience):
		ambience.stop()
		ambience.stream = null
	for player: AudioStreamPlayer in effects:
		player.stop()
		player.stream = null


func _exit_tree() -> void:
	stop_audio()
	# 強制フレーム終了はawaitで延命できない。ミキサーの停止処理を同期的に待つ。
	# Movie Makerでは停止後の描画フレームも必要なので専用録画側で先に停止する。
	if has_played:
		OS.delay_msec(int(maxf(0.15, AudioServer.get_output_latency() * 2.0) * 1000))
