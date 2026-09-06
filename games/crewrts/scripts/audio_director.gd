extends Node
## 場面の曲を交差フェードで切り替え、音声スレッドの終了まで再生を管理する。

const MUSIC_KEYS: Array[String] = ["title", "garden", "battle", "clear", "failed"]
const EFFECT_KEYS: Array[String] = [
	"whistle", "throw", "delivery", "defeat", "lost", "hit", "switch",
]
const MUSIC_DB: float = -11.0

var current_track: String = ""
var music_players: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var _streams: Dictionary = {}
var _active_player: int = 0
var _fade: Tween
var _initialized: bool = false
var _stopped: bool = false
var _enabled: bool = false
var _quit_after: int = 0
var _battle_until: int = 0


func setup() -> void:
	if _initialized:
		return
	_initialized = true
	_enabled = DisplayServer.get_name() != "headless"
	_read_quit_after()
	# 短時間の起動確認では、音声の解放前にエンジンが終了するので開始しない。
	if _quit_after > 0 and _quit_after <= 8:
		_enabled = false
	if not _enabled:
		return
	for key: String in MUSIC_KEYS:
		var stream: AudioStreamWAV = load("res://assets/audio/%s.wav" % key)
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
		_streams[key] = stream
	for index: int in range(2):
		var player := AudioStreamPlayer.new()
		player.volume_db = -50.0
		add_child(player)
		music_players.append(player)
	for key: String in EFFECT_KEYS:
		var player := AudioStreamPlayer.new()
		player.stream = load("res://assets/audio/%s.wav" % key)
		player.volume_db = -10.0 if key != "hit" else -17.0
		player.max_polyphony = 4
		add_child(player)
		sounds[key] = player


## 危険が去った後の猶予を実時間で更新するため非冪等。曲自体は同じ状態で再起動しない。
func update_state(model: Node) -> void:
	if not _enabled or _stopped:
		return
	var next_track: String = model.phase
	if model.phase == "playing":
		var danger: bool = false
		for enemy: Dictionary in model.enemies:
			if enemy.hp > 0.0 and model.leader.distance_to(enemy.position) < 9.0:
				danger = true
		for member: Dictionary in model.crew:
			if member.state == "attack":
				danger = true
		# 境界を行き来する際に曲が連続で切り替わらないよう、危険が去っても少し保つ。
		if danger:
			_battle_until = Time.get_ticks_msec() + 2400
		next_track = "battle" if Time.get_ticks_msec() < _battle_until else "garden"
	else:
		_battle_until = 0
	_set_track(next_track)


## 同じ場面へ繰り返し適用しても曲を再起動しない。
func _set_track(key: String) -> void:
	if current_track == key or not _streams.has(key):
		return
	current_track = key
	if is_instance_valid(_fade):
		_fade.kill()
	var outgoing: AudioStreamPlayer = music_players[_active_player]
	_active_player = 1 - _active_player
	var incoming: AudioStreamPlayer = music_players[_active_player]
	incoming.stop()
	incoming.stream = _streams[key]
	incoming.volume_db = -50.0
	incoming.play()
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(outgoing, "volume_db", -50.0, 0.55)
	_fade.tween_property(incoming, "volume_db", MUSIC_DB, 0.65)
	_fade.chain().tween_callback(outgoing.stop)


## 入力・出来事の発生ごとに音を重ねるため非冪等。
func play_event(event: String) -> void:
	if _enabled and not _stopped and sounds.has(event):
		sounds[event].play()


func stop_audio() -> void:
	if _stopped:
		return
	_stopped = true
	if is_instance_valid(_fade):
		_fade.kill()
	for player: AudioStreamPlayer in music_players:
		player.stop()
		player.stream = null
	for player: AudioStreamPlayer in sounds.values():
		player.stop()
		player.stream = null
	_streams.clear()


func _read_quit_after() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_args()
	for index: int in range(arguments.size()):
		if arguments[index] == "--quit":
			_quit_after = 1
		elif arguments[index] == "--quit-after" and index + 1 < arguments.size():
			_quit_after = maxi(0, arguments[index + 1].to_int())


func _process(_delta: float) -> void:
	if _enabled and not _stopped and _quit_after > 0:
		if Engine.get_process_frames() >= maxi(1, _quit_after - 8):
			stop_audio()
			# --quit-after は WM_CLOSE_REQUEST を通らない。残りのフレームで
			# AudioServer の削除キューも処理できるよう、音声スレッドの混合を先に待つ。
			if not OS.has_feature("web"):
				OS.delay_msec(150)


func _exit_tree() -> void:
	var was_playing: bool = _enabled and not _stopped
	stop_audio()
	# 即座の SceneTree.quit() でも、WAV 再生を音声スレッドが参照したまま破棄しない。
	if was_playing and not OS.has_feature("web"):
		OS.delay_msec(150)
