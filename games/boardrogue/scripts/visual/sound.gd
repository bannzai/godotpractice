extends Node
## 場面別の音楽と操作音を所有し、終了前に音声サーバーの解放を待つ。

const MUSIC: Dictionary = {
	"title": preload("res://assets/audio/title.wav"),
	"map": preload("res://assets/audio/map.wav"),
	"battle": preload("res://assets/audio/battle.wav"),
	"boss": preload("res://assets/audio/boss.wav"),
	"result_win": preload("res://assets/audio/result_win.wav"),
	"result_loss": preload("res://assets/audio/result_loss.wav"),
}
const EFFECTS: Dictionary = {
	"card": preload("res://assets/audio/card.wav"),
	"blade": preload("res://assets/audio/blade.wav"),
	"arrow": preload("res://assets/audio/arrow.wav"),
	"drum": preload("res://assets/audio/drum.wav"),
	"hit": preload("res://assets/audio/hit.wav"),
	"reward": preload("res://assets/audio/reward.wav"),
}
const RELEASE_FRAMES: int = 16

var stopped: bool = false
var scene_key: String = ""
var _music_players: Array[AudioStreamPlayer] = []
var _effect_players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _fade: Tween
var _has_played: bool = false
var _released: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		stopped = true
	for stream: AudioStreamWAV in MUSIC.values():
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	for index: int in range(2):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_music_players.append(player)
	for index: int in range(8):
		var player := AudioStreamPlayer.new()
		player.volume_db = -10.0
		add_child(player)
		_effect_players.append(player)


func play_music(next_scene: String) -> void:
	if stopped or next_scene == scene_key or not MUSIC.has(next_scene):
		return
	scene_key = next_scene
	if _fade:
		_fade.kill()
	var previous: AudioStreamPlayer = _music_players[_active]
	_active = 1 - _active
	var incoming: AudioStreamPlayer = _music_players[_active]
	incoming.stop()
	incoming.stream = MUSIC[next_scene]
	incoming.volume_db = -50.0
	incoming.play()
	_has_played = true
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(incoming, "volume_db", -13.0, 0.45)
	_fade.tween_property(previous, "volume_db", -50.0, 0.45)
	_fade.chain().tween_callback(previous.stop)


# 効果音は入力イベントごとに鳴らすため非冪等。停止後の再開は防ぐ。
func play_sfx(key: String) -> void:
	if stopped or not EFFECTS.has(key):
		return
	for player: AudioStreamPlayer in _effect_players:
		if not player.playing:
			player.stream = EFFECTS[key]
			player.play()
			_has_played = true
			return


func stop_audio() -> void:
	stopped = true
	if _fade:
		_fade.kill()
		_fade = null
	for player: AudioStreamPlayer in _music_players + _effect_players:
		player.stop()
		player.stream = null


func shutdown() -> void:
	if _released:
		return
	stop_audio()
	# stop の同フレームでは音声スレッドが参照を保持する。録画もフレームを進める。
	for frame: int in range(RELEASE_FRAMES):
		await get_tree().process_frame
	await get_tree().create_timer(0.20, true, false, true).timeout
	_released = true


func _exit_tree() -> void:
	stop_audio()
	# --quit-after は終了前に await できないため、通常音声スレッドに停止処理時間を渡す。
	# Movie Maker は実時間待ちでは進まないため、録画側で終了前のフレームを確保する。
	if _has_played and not _released and Engine.get_write_movie_path().is_empty():
		OS.delay_msec(200)
