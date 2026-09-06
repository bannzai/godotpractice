extends Node
## 場面ごとの楽曲と効果音の再生・解放を所有する。

const CUES: Array[String] = [
	"attack", "hurt", "level", "pickup", "heal", "boss", "result", "magnet", "ui"
]

var music: AudioStreamPlayer
var sound_players: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var tracks: Dictionary = {}
var current_scene: String = ""
var enabled: bool = false
var state: Node
var _music_players: Array[AudioStreamPlayer] = []
var _target_gain: float = 0.0
var _closed: bool = false
var _movie_quit_frame: int = 0


func setup(run_state: Node) -> void:
	if _closed:
		return
	if state != run_state and is_instance_valid(state):
		if state.sound_requested.is_connected(play_cue):
			state.sound_requested.disconnect(play_cue)
	state = run_state
	# Movie Maker は Dummy ドライバを使い、音を動画へ直接書き込む。
	enabled = (
		AudioServer.get_driver_name() != "Dummy" or not Engine.get_write_movie_path().is_empty()
	)
	if not Engine.get_write_movie_path().is_empty():
		# Godot は --quit-after をスクリプトへ渡さないため、Makefile の同じ値を受け取る。
		_movie_quit_frame = maxi(0, OS.get_environment("SURVIVORS_MOVIE_FRAMES").to_int())
	if _music_players.is_empty():
		for scene: String in ["title", "play", "boss", "result"]:
			var stream: AudioStreamWAV = load("res://assets/audio/bgm-%s.wav" % scene)
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
			tracks[scene] = stream
		for cue: String in CUES:
			sounds[cue] = load("res://assets/audio/%s.wav" % cue)
		for i: int in range(2):
			var player := AudioStreamPlayer.new()
			player.volume_linear = 0.0
			add_child(player)
			_music_players.append(player)
		music = _music_players[0]
		for i: int in range(8):
			var player := AudioStreamPlayer.new()
			# 最大音量の SE が 8 音重なっても、BGM と合計して振幅 1 未満に収める。
			player.volume_db = -17.0
			add_child(player)
			sound_players.append(player)
	if not state.sound_requested.is_connected(play_cue):
		state.sound_requested.connect(play_cue)
	set_scene(state.phase, state.boss_spawned)


func set_scene(phase: String, boss: bool = false) -> void:
	if _closed or _music_players.is_empty():
		return
	var next_scene: String = phase
	if phase in ["playing", "paused", "upgrade"]:
		next_scene = "boss" if boss else "play"
	if not tracks.has(next_scene):
		return
	_target_gain = db_to_linear(-17.0 if phase in ["paused", "upgrade"] else -10.0)
	if next_scene == current_scene:
		return
	current_scene = next_scene
	music = _music_players[1] if music == _music_players[0] else _music_players[0]
	music.stop()
	music.stream = tracks[next_scene]
	music.volume_linear = 0.0
	if enabled:
		music.play()


# 各要求は異なる操作・命中を表すため、同じ cue でも再生する。
func play_cue(cue: String) -> void:
	if _closed or not enabled or not sounds.has(cue):
		return
	for player: AudioStreamPlayer in sound_players:
		if not player.playing:
			player.stream = sounds[cue]
			player.play()
			return


# 再生中の曲を実時間に応じてクロスフェードするため非冪等。
func _process(delta: float) -> void:
	if _closed:
		return
	# オフライン録音は次の描画でしかミックスされないため、末尾に解放用の 2 フレームを残す。
	if _movie_quit_frame > 0 and Engine.get_process_frames() >= _movie_quit_frame - 2:
		shutdown()
		return
	for player: AudioStreamPlayer in _music_players:
		var target: float = _target_gain if player == music else 0.0
		player.volume_linear = move_toward(player.volume_linear, target, delta * 0.7)
		if player != music and is_zero_approx(player.volume_linear) and player.playing:
			player.stop()
			player.stream = null


func shutdown() -> void:
	if _closed:
		return
	_closed = true
	if is_instance_valid(state) and state.sound_requested.is_connected(play_cue):
		state.sound_requested.disconnect(play_cue)
	for player: AudioStreamPlayer in _music_players + sound_players:
		player.stop()
		player.stream = null
	sounds.clear()
	tracks.clear()
	# --quit-after では次フレームが来ないため、音声スレッドの停止反映をここで待つ。
	# Web の単一スレッドでは同期待機が再生処理も止めるため、ブラウザの解放に委ねる。
	if enabled and AudioServer.get_driver_name() != "Dummy" and not OS.has_feature("web"):
		var drain_seconds: float = AudioServer.get_time_to_next_mix() * 2.0 + 0.05
		OS.delay_msec(ceili(clampf(drain_seconds, 0.06, 0.20) * 1000))


func _exit_tree() -> void:
	shutdown()
