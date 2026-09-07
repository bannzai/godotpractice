extends Node
## 場面ごとの音声と終了時のミキサー解放を管理する。

signal shutdown_finished

const TRACKS: Array[String] = ["title", "map", "battle", "police", "boss", "result"]
const EFFECTS: Array[String] = [
	"attack", "hurt", "spirit", "step", "siren", "heartbeat", "acquire", "select",
	"transition", "dissolve", "heal"
]

var music: AudioStreamPlayer
var environment: AudioStreamPlayer
var heartbeat: AudioStreamPlayer
var effects: Array[AudioStreamPlayer] = []
var current_track: String = ""
var current_environment: String = ""
var current_heartbeat: String = ""
var environment_scene: String = ""
var environment_darkness: int = 0
var environment_district: int = 0
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
	environment = AudioStreamPlayer.new()
	environment.volume_db = -24
	add_child(environment)
	heartbeat = AudioStreamPlayer.new()
	heartbeat.volume_db = -32
	add_child(heartbeat)
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


## 同じ場面・闇・区画なら再生位置を保ち、環境音を重ね直さない。
func set_environment(scene: String, darkness: int, district: int = 0) -> void:
	environment_scene = scene
	environment_darkness = clampi(darkness, 0, 100)
	environment_district = clampi(district, 0, 11)
	if shutting_down or DisplayServer.get_name() == "headless":
		return
	var ambience_name: String = _ambience_for(scene, environment_district)
	if ambience_name != current_environment or not environment.playing:
		current_environment = ambience_name
		environment.stop()
		environment.stream = null
		if not ambience_name.is_empty():
			environment.stream = _looping_stream(
				"res://assets/external/audio/%s.ogg" % ambience_name
			)
			if not muted:
				environment.play()
				has_played = true
	var heartbeat_name: String = ""
	if scene not in ["title", "intro"]:
		heartbeat_name = "heartbeat-fast" if environment_darkness >= 60 else "heartbeat-slow"
	var restart_heartbeat: bool = not heartbeat_name.is_empty() and not heartbeat.playing
	if heartbeat_name != current_heartbeat or restart_heartbeat:
		current_heartbeat = heartbeat_name
		heartbeat.stop()
		heartbeat.stream = null
		if not heartbeat_name.is_empty():
			heartbeat.stream = _looping_stream(
				"res://assets/external/audio/%s.ogg" % heartbeat_name
			)
			if not muted:
				heartbeat.play()
				has_played = true
	heartbeat.volume_db = lerpf(-38.0, -13.0, float(environment_darkness) / 100.0)


func _ambience_for(scene: String, district: int) -> String:
	if scene == "map":
		return ["ambience-crickets", "ambience-wind", "electric-loop", "ambience-dog"][district % 4]
	if scene in ["grave", "graveyard", "rest"]:
		return "ambience-leaves"
	if scene in ["living", "house", "police"]:
		return "electric-loop"
	if scene in ["story", "battle", "boss"]:
		return "ambience-wind"
	if scene == "result":
		return "ambience-crickets"
	return ""


func _looping_stream(path: String) -> AudioStream:
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream


# 効果音は一回の出来事ごとに発音するため、呼び出し回数だけ音を重ねる。
func play_sfx(effect: String) -> void:
	if muted or shutting_down or DisplayServer.get_name() == "headless" or effect not in EFFECTS:
		return
	var path: String = "res://assets/audio/%s.wav" % effect
	if effect == "step":
		path = "res://assets/external/audio/ambience-steps.ogg"
	effects[voice].stream = load(path)
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
		set_environment(environment_scene, environment_darkness, environment_district)


func stop_audio() -> void:
	if not is_instance_valid(music):
		return
	music.stop()
	music.stream = null
	environment.stop()
	environment.stream = null
	heartbeat.stop()
	heartbeat.stream = null
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
