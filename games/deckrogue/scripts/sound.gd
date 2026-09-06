extends Node
## BGM の切替は同じ曲なら再開しない。SE は操作ごとの発音なので非冪等。

var music: AudioStreamPlayer
var effects: Array[AudioStreamPlayer] = []
var current_track: String = ""
var muted: bool = false
var voice: int = 0


func _ready() -> void:
	music = AudioStreamPlayer.new()
	music.volume_db = -16
	add_child(music)
	for index: int in range(4):
		var player := AudioStreamPlayer.new()
		player.volume_db = -12
		add_child(player)
		effects.append(player)


func track(name: String) -> void:
	# headless は音声出力がなく、即終了時の WAV 再生保持も避ける。
	if DisplayServer.get_name() == "headless":
		return
	if current_track == name:
		return
	current_track = name
	var stream: AudioStreamWAV = load("res://assets/audio/" + name + ".wav")
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	music.stream = stream
	if not muted:
		music.play()


# 入力イベントに対して一度発音するため、反復呼び出しでは別の音を重ねる。
func play(name: String) -> void:
	if muted or DisplayServer.get_name() == "headless":
		return
	effects[voice].stream = load("res://assets/audio/" + name + ".wav")
	effects[voice].play()
	voice = (voice + 1) % effects.size()


func set_muted(value: bool) -> void:
	if muted == value:
		return
	muted = value
	if muted:
		stop_all()
	else:
		var previous: String = current_track
		current_track = ""
		if not previous.is_empty():
			track(previous)
	music.volume_db = -80 if muted else -16
	for player: AudioStreamPlayer in effects:
		player.volume_db = -80 if muted else -12


func stop_all() -> void:
	music.stop()
	music.stream = null
	for player: AudioStreamPlayer in effects:
		player.stop()
		player.stream = null


func _exit_tree() -> void:
	stop_all()
