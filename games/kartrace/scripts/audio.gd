class_name KartAudio
extends Node
## 場面別の曲と速度連動エンジン音。音声参照を終了前に解放する。

const SCENES: Array[String] = ["title", "race", "final", "results"]
const EFFECTS: Array[String] = [
	"item", "hit", "boost", "countdown", "finish", "select", "lap",
]

var current_scene: String = ""
var _music: AudioStreamPlayer
var _engine: AudioStreamPlayer
var _effects: Dictionary = {}
var _tracks: Dictionary = {}
var _initialized: bool = false
var _stopped: bool = false
var _enabled: bool = false
var _quit_after: int = 0


func _ready() -> void:
	_setup()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _setup() -> void:
	if _initialized:
		return
	_initialized = true
	_enabled = DisplayServer.get_name() != "headless"
	var arguments: PackedStringArray = OS.get_cmdline_args()
	for index: int in range(arguments.size()):
		if arguments[index] == "--quit":
			_quit_after = 1
		elif arguments[index] == "--quit-after" and index + 1 < arguments.size():
			_quit_after = maxi(0, arguments[index + 1].to_int())
	if _quit_after > 0 and _quit_after <= 8:
		_enabled = false
	if not _enabled:
		return
	_music = AudioStreamPlayer.new()
	_music.volume_db = -14.0
	add_child(_music)
	_engine = AudioStreamPlayer.new()
	_engine.stream = _load_loop("engine")
	_engine.volume_db = -27.0
	add_child(_engine)
	for key: String in SCENES:
		_tracks[key] = _load_loop(key)
	for key: String in EFFECTS:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = load("res://assets/audio/%s.wav" % key)
		player.volume_db = -10.0
		player.max_polyphony = 3
		add_child(player)
		_effects[key] = player


func _load_loop(key: String) -> AudioStreamWAV:
	var stream: AudioStreamWAV = load("res://assets/audio/%s.wav" % key)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	return stream


func set_scene(scene: String) -> void:
	_setup()
	if current_scene == scene or _stopped:
		return
	current_scene = scene
	if not _enabled:
		return
	_music.stop()
	if _tracks.has(scene):
		_music.stream = _tracks[scene]
		_music.play()
	if scene != "race" and scene != "final":
		_engine.stop()


## 出来事ごとに鳴らし直すため非冪等。
func play_sfx(sound: String) -> void:
	_setup()
	if _enabled and not _stopped and _effects.has(sound):
		_effects[sound].play()


func set_engine(speed_ratio: float) -> void:
	_setup()
	if not _enabled or _stopped:
		return
	var ratio: float = clampf(speed_ratio, 0.0, 1.5)
	if ratio <= 0.01:
		_engine.stop()
		return
	_engine.pitch_scale = 0.7 + ratio * 1.7
	_engine.volume_db = -30.0 + minf(ratio, 1.0) * 7.0
	if not _engine.playing:
		_engine.play()


func stop_all() -> void:
	if _stopped:
		return
	_stopped = true
	for child: Node in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	_tracks.clear()


func _process(_delta: float) -> void:
	if _enabled and not _stopped and _quit_after > 0:
		if Engine.get_process_frames() >= maxi(1, _quit_after - 8):
			stop_all()
			# 自動終了は close 通知を通らないため、音声スレッドに解放時間を与える。
			if not OS.has_feature("web"):
				OS.delay_msec(150)


func _exit_tree() -> void:
	var was_playing: bool = _enabled and not _stopped
	stop_all()
	if was_playing and not OS.has_feature("web"):
		OS.delay_msec(150)
