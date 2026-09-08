extends Node
## 場面の再指定は再生位置を保つ。効果音は入力イベントごとに発音する。

signal shutdown_finished

var music: AudioStreamPlayer
var effects: Array[AudioStreamPlayer] = []
var current_scene: String = ""
var voice: int = 0
var shutdown_started: bool = false
var shutdown_complete: bool = false
var has_played: bool = false
var drain_seconds: float = 0.12


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	drain_seconds = maxf(0.12, AudioServer.get_output_latency() * 2.0)
	music = AudioStreamPlayer.new()
	music.volume_db = -15.0
	add_child(music)
	for index: int in range(6):
		var player := AudioStreamPlayer.new()
		player.volume_db = -9.0
		add_child(player)
		effects.append(player)


func play_scene(scene: String) -> void:
	if shutdown_started or DisplayServer.get_name() == "headless" or current_scene == scene:
		return
	current_scene = scene
	var stream: AudioStreamWAV = load("res://assets/audio/%s.wav" % scene)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	music.stream = stream
	music.play()
	has_played = true


# 入力一回の発音として扱うため、反復呼び出しは別の音を重ねる。
func play_sfx(effect: String) -> void:
	if shutdown_started or DisplayServer.get_name() == "headless":
		return
	effects[voice].stream = load("res://assets/audio/%s.wav" % effect)
	effects[voice].play()
	has_played = true
	voice = (voice + 1) % effects.size()


func stop_audio() -> void:
	current_scene = ""
	if is_instance_valid(music):
		music.stop()
		music.stream = null
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
	stop_audio()
	# 停止は音声スレッドへの予約なので、ツリーを生かしたまま参照解放を待つ。
	await get_tree().create_timer(drain_seconds, true, false, true).timeout
	for frame: int in range(3):
		await get_tree().process_frame
	shutdown_complete = true
	shutdown_finished.emit()


func _exit_tree() -> void:
	stop_audio()
	# --quit-after の終了通知後は await できない。この経路だけ同期的に待つ。
	if has_played and not shutdown_complete:
		OS.delay_msec(int(ceil(drain_seconds * 1000.0)))
