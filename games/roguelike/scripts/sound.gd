extends Node
## BGM の切替は同じ曲なら再開しない。SE は操作ごとの発音なので非冪等。

signal shutdown_finished

var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var effects: Array[AudioStreamPlayer] = []
var current_track: String = ""
var muted: bool = false
var voice: int = 0
var shutting_down: bool = false
var shutdown_started: bool = false
var shutdown_complete: bool = false
var has_played: bool = false
var drain_seconds: float = 0.12


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	drain_seconds = maxf(0.12, AudioServer.get_output_latency() * 2.0)
	music = AudioStreamPlayer.new()
	music.volume_db = -12
	add_child(music)
	ambience = AudioStreamPlayer.new()
	ambience.volume_db = -24
	add_child(ambience)
	for index: int in range(4):
		var player := AudioStreamPlayer.new()
		player.volume_db = -8
		add_child(player)
		effects.append(player)


func track(name: String) -> void:
	# headless は音声出力がなく、即終了時の WAV 再生保持も避ける。
	if shutting_down or DisplayServer.get_name() == "headless":
		return
	_set_ambience(name.begins_with("floor") or name == "boss")
	if current_track == name:
		return
	current_track = name
	var stream: AudioStreamWAV = load("res://assets/audio/" + name + ".wav")
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	music.stream = stream
	if not muted:
		music.play()
		has_played = true


func _set_ambience(enabled: bool) -> void:
	if enabled and ambience.stream == null:
		var stream: AudioStreamWAV = load("res://assets/audio/ambience.wav")
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		ambience.stream = stream
		if not muted:
			ambience.play()
			has_played = true
	elif not enabled and ambience.stream != null:
		ambience.stop()
		ambience.stream = null


# 入力イベントに対して一度発音するため、反復呼び出しでは別の音を重ねる。
func play(name: String) -> void:
	if muted or shutting_down or DisplayServer.get_name() == "headless":
		return
	effects[voice].stream = load("res://assets/audio/" + name + ".wav")
	effects[voice].play()
	has_played = true
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
	music.volume_db = -80 if muted else -12
	ambience.volume_db = -80 if muted else -24
	for player: AudioStreamPlayer in effects:
		player.volume_db = -80 if muted else -8


func stop_all() -> void:
	if not is_instance_valid(music):
		return
	music.stop()
	music.stream = null
	ambience.stop()
	ambience.stream = null
	for player: AudioStreamPlayer in effects:
		player.stop()
		player.stream = null


func shutdown() -> void:
	if shutdown_complete:
		return
	if shutdown_started:
		await shutdown_finished
		return
	shutdown_started = true
	shutting_down = true
	stop_all()
	# stop() は音声スレッドへ停止を予約する。ツリー解放より前に実時間と
	# フレームの両方を進め、AudioStreamPlaybackWAV の参照解放を待つ。
	await get_tree().create_timer(drain_seconds, true, false, true).timeout
	for frame: int in range(3):
		await get_tree().process_frame
	shutdown_complete = true
	shutdown_finished.emit()


func _exit_tree() -> void:
	stop_all()
	# --quit-after はエンジンが消費し、GDScript から終了期限を取得できない。
	# 終了通知後は await でツリーを延命できないため、この経路だけ同期して
	# 音声スレッドの停止を待つ。通常のウィンドウ終了は shutdown() を使う。
	if has_played and not shutdown_complete:
		OS.delay_msec(int(ceil(drain_seconds * 1000.0)))
