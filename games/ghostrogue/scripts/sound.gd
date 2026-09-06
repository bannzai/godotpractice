extends Node
## 場面ごとの音声と終了時のミキサー解放を管理する。

signal shutdown_finished

const TRACKS: Array[String] = ["title", "map", "battle", "police", "boss", "result"]
const EFFECTS: Array[String] = [
	"attack", "hurt", "spirit", "step", "siren", "heartbeat", "acquire", "select",
	"transition", "dissolve", "heal"
]

var music: AudioStreamPlayer
var effects: Array[AudioStreamPlayer] = []
var current_track: String = ""
var muted: bool = false
var voice: int = 0
var shutting_down: bool = false
var shutdown_complete: bool = false
var has_played: bool = false
var drain_seconds: float = 0.16


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	drain_seconds = maxf(0.16, AudioServer.get_output_latency() * 2.0)
	music = AudioStreamPlayer.new()
	music.volume_db = -18
	add_child(music)
	for index: int in range(6):
		var player := AudioStreamPlayer.new()
		player.volume_db = -12
		add_child(player)
		effects.append(player)


func play_bgm(scene: String) -> void:
	if shutting_down or DisplayServer.get_name() == "headless" or scene not in TRACKS:
		return
	if current_track == scene and music.playing:
		return
	current_track = scene
	var stream: AudioStreamWAV = load("res://assets/audio/%s.wav" % scene)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	music.stream = stream
	if not muted:
		music.play()
		has_played = true


# 効果音は一回の出来事ごとに発音するため、呼び出し回数だけ音を重ねる。
func play_sfx(effect: String) -> void:
	if muted or shutting_down or DisplayServer.get_name() == "headless" or effect not in EFFECTS:
		return
	effects[voice].stream = load("res://assets/audio/%s.wav" % effect)
	effects[voice].play()
	has_played = true
	voice = (voice + 1) % effects.size()


func set_muted(value: bool) -> void:
	if muted == value:
		return
	muted = value
	if muted:
		stop_audio()
	elif not current_track.is_empty():
		play_bgm(current_track)


func stop_audio() -> void:
	if not is_instance_valid(music):
		return
	music.stop()
	music.stream = null
	for player: AudioStreamPlayer in effects:
		player.stop()
		player.stream = null


func stop_all() -> void:
	stop_audio()


func shutdown() -> void:
	if shutdown_complete:
		return
	if shutting_down:
		await shutdown_finished
		return
	shutting_down = true
	stop_audio()
	# stop() が音声スレッドへ反映されるまで、ツリーを保持して実時間を渡す。
	await get_tree().create_timer(drain_seconds, true, false, true).timeout
	for frame: int in range(3):
		await get_tree().process_frame
	shutdown_complete = true
	shutdown_finished.emit()


func _exit_tree() -> void:
	stop_audio()
	# --quit-after の終了通知では await でツリーを延命できないため同期して待つ。
	if has_played and not shutdown_complete:
		OS.delay_msec(int(ceil(drain_seconds * 1000.0)))
