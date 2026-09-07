extends Node
## 軍議の音楽と短い操作音を再生する。

var enabled: bool = true
var _music: AudioStreamPlayer
var _effects: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {
	"place": preload("res://assets/place.wav"),
	"attack": preload("res://assets/attack.wav"),
	"victory": preload("res://assets/victory.wav"),
	"defeat": preload("res://assets/defeat.wav"),
}


func _ready() -> void:
	_music = AudioStreamPlayer.new()
	var stream: AudioStreamWAV = preload("res://assets/music.wav").duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	_music.stream = stream
	_music.volume_db = -9.0
	add_child(_music)
	for index: int in range(4):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.volume_db = -8.0
		add_child(player)
		_effects.append(player)


func play_music() -> void:
	if enabled and is_instance_valid(_music) and not _music.playing:
		_music.play()


## 同じ出来事の再発でも音を鳴らすため、再生は冪等にしない。
func cue(kind: String) -> void:
	if not enabled or not _streams.has(kind):
		return
	for player: AudioStreamPlayer in _effects:
		if not player.playing:
			player.stream = _streams[kind] as AudioStream
			player.play()
			return


## 利用者が押すたびに状態を反転する操作なので冪等にしない。
func toggle() -> void:
	enabled = not enabled
	if enabled:
		play_music()
	else:
		_music.stop()
		for player: AudioStreamPlayer in _effects:
			player.stop()


func _exit_tree() -> void:
	# 即時終了では次のフレームを待てないため、音声スレッドの停止反映を同期で待つ。
	_music.stop()
	_music.stream = null
	for player: AudioStreamPlayer in _effects:
		player.stop()
		player.stream = null
	OS.delay_msec(60)
