extends SceneTree
## 通常の音声ドライバで、場面別 BGM の切替・ループと全 SE の実再生を検証する。

var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


# 実際に音を再生して時間経過を観測するため非冪等。
func _run() -> void:
	if AudioServer.get_driver_name() == "Dummy":
		push_error("音声の検証には通常の音声ドライバが必要です")
		quit(1)
		return
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var state: Node = root.get_node("RunState")
	await create_timer(0.7).timeout
	_check(main.audio.music.playing, "タイトル BGM が再生中")
	_check(AudioServer.get_bus_peak_volume_left_db(0, 0) > -90.0, "音声バスに出力がある")
	var track: AudioStreamWAV = main.audio.music.stream
	var initial_position: float = main.audio.music.get_playback_position()
	await create_timer(track.get_length()).timeout
	_check(main.audio.music.playing, "BGM が音源長を越えて再生される")
	_check(absf(main.audio.music.get_playback_position() - initial_position) < 0.3,
		"タイトル BGM が先頭へループする")
	for cue: String in main.audio.CUES:
		state.sound_requested.emit(cue)
		await process_frame
		var playing: bool = false
		for player: AudioStreamPlayer in main.audio.sound_players:
			if player.playing and player.stream == main.audio.sounds[cue]:
				playing = true
		_check(playing, cue + " の SE が実再生される")
		await create_timer(0.4).timeout
	state.start_run(77)
	await create_timer(0.7).timeout
	_check(main.audio.current_scene == "play" and main.audio.music.playing, "探索 BGM へ切替")
	state.elapsed = 570.0
	await create_timer(0.7).timeout
	_check(main.audio.current_scene == "boss" and main.audio.music.playing, "強敵 BGM へ切替")
	state.finish_run(true)
	await create_timer(0.7).timeout
	_check(main.audio.current_scene == "result" and main.audio.music.playing, "結果 BGM へ切替")
	state.return_title()
	await create_timer(0.7).timeout
	_check(main.audio.current_scene == "title" and main.audio.music.playing, "タイトル BGM へ復帰")
	main.audio.shutdown()
	_check(not main.audio.music.playing and main.audio.music.stream == null, "終了前の音声停止と解放")
	main.queue_free()
	await process_frame
	await process_frame
	if not failed:
		print("audiocheck OK")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error("audiocheck FAIL: " + label)
