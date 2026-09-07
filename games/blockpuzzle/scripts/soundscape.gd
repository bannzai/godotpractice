class_name Soundscape
extends Node
## 場面別の旋律と効果音。終了処理ではストリーム参照も解放する。

const SCENES: Array[String] = ["title", "play", "danger", "result"]
const EFFECTS: Array[String] = [
	"move", "rotate", "land", "clear", "chain", "garbage", "victory", "defeat", "select",
]

var _music: AudioStreamPlayer
var _ambient: AudioStreamPlayer
var _effects: Array[AudioStreamPlayer] = []
var _scene: String = ""
var _next_voice: int = 0
var _has_played: bool = false
var _released: bool = false
var _stopped: bool = false


func set_scene(scene: String) -> void:
	if _stopped or DisplayServer.get_name() == "headless":
		return
	if scene not in SCENES or scene == _scene:
		return
	_ensure_players()
	if not _ambient.playing:
		var ambient_stream: AudioStreamWAV = load("res://assets/audio/ambient.wav")
		_configure_full_loop(ambient_stream)
		_ambient.stream = ambient_stream
		_ambient.volume_db = -25.0
		_ambient.play()
	_scene = scene
	_music.stop()
	var stream: AudioStreamWAV = load("res://assets/audio/bgm_%s.wav" % scene)
	_configure_full_loop(stream)
	_music.stream = stream
	_music.volume_db = -10.0
	_music.play()
	_has_played = true


## SE は操作のたびに発音するため、呼び出し回数に応じて再生する。
func play_sfx(effect: String, pitch: float = 1.0) -> void:
	if _stopped or DisplayServer.get_name() == "headless":
		return
	if effect not in EFFECTS:
		return
	_ensure_players()
	var player: AudioStreamPlayer = _effects[_next_voice]
	_next_voice = (_next_voice + 1) % _effects.size()
	player.stop()
	player.stream = load("res://assets/audio/%s.wav" % effect)
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.volume_db = -5.0
	player.play()
	_has_played = true


func stop_audio() -> void:
	_stopped = true
	_scene = ""
	if is_instance_valid(_music):
		_music.stop()
		_music.stream = null
	if is_instance_valid(_ambient):
		_ambient.stop()
		_ambient.stream = null
	for player: AudioStreamPlayer in _effects:
		if is_instance_valid(player):
			player.stop()
			player.stream = null


func shutdown() -> void:
	stop_audio()
	if is_inside_tree():
		# AudioServer の音声参照が解放されるまで、録画時にも描画フレームを進める。
		for frame: int in range(8):
			await get_tree().process_frame
		await get_tree().create_timer(0.2, true, false, true).timeout
	_released = true


func _ensure_players() -> void:
	if is_instance_valid(_music):
		return
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	add_child(_music)
	_ambient = AudioStreamPlayer.new()
	_ambient.name = "Ambient"
	add_child(_ambient)
	for i: int in range(8):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Effect%d" % i
		add_child(player)
		_effects.append(player)


static func _configure_full_loop(stream: AudioStreamWAV) -> void:
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)


func _exit_tree() -> void:
	stop_audio()
	# --quit-after は終了を事前通知しないため、通常音声スレッドの停止を待つ。
	# Movie Maker の音声は実時間では進まないので、撮影側で shutdown を待つ。
	if _has_played and not _released and Engine.get_write_movie_path().is_empty():
		OS.delay_msec(200)
