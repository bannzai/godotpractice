extends SceneTree
## 通常の音声ドライバで、BGM のループと各 SE の実再生を検証する。

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
	await create_timer(0.5).timeout
	_check(main.music.playing, "BGM が再生中")
	_check(AudioServer.get_bus_peak_volume_left_db(0, 0) > -90.0, "音声バスに出力がある")
	for cue: String in ["attack", "hurt", "level", "pickup"]:
		state.sound_requested.emit(cue)
		await process_frame
		var playing: bool = false
		for player: AudioStreamPlayer in main.sound_players:
			if player.playing and player.stream == main.sounds[cue]:
				playing = true
		_check(playing, cue + " の SE が実再生される")
		await create_timer(0.4).timeout
	await create_timer(23.0).timeout
	_check(main.music.playing and main.music.get_playback_position() < 5.0, "24 秒の BGM が終了せず先頭へループ")
	main.queue_free()
	await create_timer(0.2).timeout
	if not failed:
		print("audiocheck OK")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error("audiocheck FAIL: " + label)
