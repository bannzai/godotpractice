extends Node
## 場面別の曲と出来事の効果音。音声スレッドが解放する時間を終了時に確保する。

const MUSIC: Array[String] = ["title", "day", "night", "clear", "failed"]
const SOUNDS: Array[String] = [
	"break_grass", "break_dirt", "break_stone", "break_sand", "break_wood",
	"break_leaves", "break_crystal", "place", "step", "attack", "hurt", "craft", "ui",
	"place_wood", "place_stone", "place_grass", "place_dirt", "place_sand",
	"place_leaves", "place_crystal", "step_wood", "step_stone", "step_grass",
	"step_dirt", "step_sand", "step_leaves", "step_crystal",
]

var current_track: String = ""
var _music: AudioStreamPlayer
var _sounds: Dictionary = {}
var _streams: Dictionary = {}
var _enabled: bool = false
var _initialized: bool = false
var _stopped: bool = false
var _quit_after: int = 0


func _ready() -> void:
	_setup()


func _setup() -> void:
	if _initialized:
		return
	_initialized = true
	var arguments: PackedStringArray = OS.get_cmdline_args()
	for index: int in range(arguments.size()):
		if arguments[index] == "--quit":
			_quit_after = 1
		elif arguments[index] == "--quit-after" and index + 1 < arguments.size():
			_quit_after = maxi(0, arguments[index + 1].to_int())
	_enabled = DisplayServer.get_name() != "headless"
	if _quit_after > 0 and _quit_after <= 8:
		_enabled = false
	if not _enabled:
		return
	_music = AudioStreamPlayer.new()
	_music.volume_db = -13.0
	add_child(_music)
	for key: String in MUSIC:
		var stream: AudioStreamWAV = load("res://assets/audio/%s.wav" % key)
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
		_streams[key] = stream
	for key: String in SOUNDS:
		var player := AudioStreamPlayer.new()
		player.stream = load("res://assets/audio/%s.wav" % key)
		player.volume_db = -18.0 if key.begins_with("step") else -9.0
		player.max_polyphony = 3
		add_child(player)
		_sounds[key] = player


func play_music(track: String) -> void:
	_setup()
	if not _enabled or _stopped or track == current_track or not _streams.has(track):
		return
	current_track = track
	_music.stop()
	_music.stream = _streams[track]
	_music.play()


## 入力や出来事ごとに発音するため非冪等。
func play_sfx(sound: String) -> void:
	if _enabled and not _stopped and _sounds.has(sound):
		_sounds[sound].play()


func stop_audio() -> void:
	if _stopped:
		return
	_stopped = true
	if is_instance_valid(_music):
		_music.stop()
		_music.stream = null
	for player: AudioStreamPlayer in _sounds.values():
		player.stop()
		player.stream = null
	_streams.clear()


func _process(_delta: float) -> void:
	if _enabled and not _stopped and _quit_after > 0:
		if Engine.get_process_frames() >= maxi(1, _quit_after - 8):
			stop_audio()
			if not OS.has_feature("web"):
				OS.delay_msec(150)


func _exit_tree() -> void:
	var was_playing: bool = _enabled and not _stopped
	stop_audio()
	if was_playing and not OS.has_feature("web"):
		OS.delay_msec(150)
