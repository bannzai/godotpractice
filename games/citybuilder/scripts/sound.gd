extends Node
## BGM と環境音の切替は同じ場面なら再開しない。SE は操作ごとの発音なので非冪等。

signal shutdown_finished

const ROOM_VOLUME_DB: Dictionary = {
	"title": -29.0,
	"town": -25.0,
	"city": -22.0,
	"result": -30.0,
}
const ROOM_PITCH: Dictionary = {
	"title": 0.90,
	"town": 1.00,
	"city": 1.08,
	"result": 0.86,
}

var music: AudioStreamPlayer
var room: AudioStreamPlayer
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
	room = AudioStreamPlayer.new()
	room.volume_db = -25
	add_child(room)
	for index: int in range(4):
		var player := AudioStreamPlayer.new()
		player.volume_db = -8
		add_child(player)
		effects.append(player)


func track(name: String) -> void:
	# headless は音声出力がなく、即終了時の WAV 再生保持も避ける。
	if shutting_down or DisplayServer.get_name() == "headless":
		return
	if current_track == name:
		return
	current_track = name
	music.stream = _looped_stream("res://assets/audio/" + name + ".wav")
	room.stream = _looped_stream("res://assets/audio/ambience.wav")
	_apply_mix()
	if not muted:
		music.play()
		room.play()
		has_played = true


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
	_apply_mix()


func _apply_mix() -> void:
	if not is_instance_valid(music) or not is_instance_valid(room):
		return
	music.volume_db = -80 if muted else -12
	room.volume_db = -80 if muted else float(ROOM_VOLUME_DB.get(current_track, -26.0))
	room.pitch_scale = float(ROOM_PITCH.get(current_track, 1.0))
	for player: AudioStreamPlayer in effects:
		player.volume_db = -80 if muted else -8


func _looped_stream(path: String) -> AudioStreamWAV:
	var stream: AudioStreamWAV = load(path)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream


func stop_all() -> void:
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	if is_instance_valid(room):
		room.stop()
		room.stream = null
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
