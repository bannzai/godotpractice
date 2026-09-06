extends Node
## 場面のクロスフェードと効果音を管理し、終了時は音声処理の解放を待つ。

const MUSIC: Dictionary = {
	"title": preload("res://assets/audio/bgm_title.wav"),
	"duel": preload("res://assets/audio/bgm_duel.wav"),
	"boss": preload("res://assets/audio/bgm_boss.wav"),
	"victory": preload("res://assets/audio/bgm_victory.wav"),
	"defeat": preload("res://assets/audio/bgm_defeat.wav"),
}
const EFFECTS: Dictionary = {
	"draw": preload("res://assets/audio/draw.wav"),
	"summon": preload("res://assets/audio/summon.wav"),
	"attack": preload("res://assets/audio/attack.wav"),
	"destroy": preload("res://assets/audio/destroy.wav"),
	"damage": preload("res://assets/audio/damage.wav"),
	"victory": preload("res://assets/audio/victory.wav"),
	"boost": preload("res://assets/audio/boost.wav"),
	"trap": preload("res://assets/audio/trap.wav"),
	"transition": preload("res://assets/audio/transition.wav"),
}
const RELEASE_FRAMES: int = 16
const MUSIC_VOLUME_DB: float = -11.0

var stopped: bool = false
var scene: String = ""
var music_players: Array[AudioStreamPlayer] = []
var effect_players: Array[AudioStreamPlayer] = []
var active_music: int = 0
var fade: Tween
var has_played: bool = false
var released: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		stopped = true
	for stream: AudioStreamWAV in MUSIC.values():
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	for index: int in range(2):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(player)
		music_players.append(player)
	for index: int in range(8):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.volume_db = -8.0
		add_child(player)
		effect_players.append(player)


func _exit_tree() -> void:
	stop_audio()
	# --quit-after は終了前に通知しない。通常の音声スレッドには停止処理の時間を渡す。
	# Movie Maker は実時間待ちで音声を処理しないため、録画側で終了前のフレームを確保する。
	if has_played and not released and Engine.get_write_movie_path().is_empty():
		OS.delay_msec(200)


func set_scene(next_scene: String) -> void:
	if stopped or next_scene == scene or not MUSIC.has(next_scene):
		return
	scene = next_scene
	if fade:
		fade.kill()
	var previous: AudioStreamPlayer = music_players[active_music]
	active_music = 1 - active_music
	var incoming: AudioStreamPlayer = music_players[active_music]
	incoming.stop()
	incoming.stream = MUSIC[next_scene]
	incoming.volume_db = -50.0
	incoming.play()
	has_played = true
	fade = create_tween().set_parallel(true)
	fade.tween_property(incoming, "volume_db", MUSIC_VOLUME_DB, 0.5)
	fade.tween_property(previous, "volume_db", -50.0, 0.5)
	fade.chain().tween_callback(previous.stop)


func play_effect(kind: String) -> void:
	# 効果音は操作イベントごとに再生するため非冪等。終了後の再開だけを防ぐ。
	if stopped or not EFFECTS.has(kind):
		return
	for player: AudioStreamPlayer in effect_players:
		if not player.playing:
			player.stream = EFFECTS[kind]
			player.play()
			has_played = true
			return


func stop_audio() -> void:
	if stopped and music_players.is_empty():
		return
	stopped = true
	if fade:
		fade.kill()
		fade = null
	for player: AudioStreamPlayer in music_players + effect_players:
		player.stop()
		player.stream = null
	set_process(false)


func shutdown() -> void:
	stop_audio()
	# AudioServer は stop と同フレームでは参照を手放さない。録画でもフレームを進める。
	for frame: int in range(RELEASE_FRAMES):
		await get_tree().process_frame
	await get_tree().create_timer(0.2, true, false, true).timeout
	released = true
