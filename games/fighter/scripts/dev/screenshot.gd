extends SceneTree
## 実際の描画で代表画面を撮影する (headless では描画されないため、Makefile の screenshot target が
## --headless なしで起動する)。撮影した PNG は tmp/screenshot-<名前>.png に保存し、失敗したら quit(1) で終わる。
## ゲーム固有の状態作り (画面遷移・スコアの投入・操作の再現等) は _capture_scenes() に足す。
## autoload は --script 起動でも root から取得できる。


func _initialize() -> void:
	# BGM の autoload やゲーム側の SE が撮影中に鳴らないよう Master バスをミュートする
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	_run.call_deferred()


## 時間経過と物理で画面を進めるため、同じ実行中に重ねて呼び出さない。
func _run() -> void:
	if await _capture_scenes():
		quit(0)


## 撮影する画面の並び。雛形はメインシーン (タイトル) だけを撮る。失敗した撮影は _capture() が
## quit(1) 済みなので、false を受けたらそのまま抜ける。
func _capture_scenes() -> bool:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout
	if not await _capture("tmp/screenshot-title.png"):
		return false
	main.show_select()
	if not await _capture("tmp/screenshot-select.png"):
		return false
	main.start_match()
	main.intro = 0.0
	await create_timer(0.5).timeout
	main.previewing = true
	main.player.enabled = false
	main.cpu.enabled = false
	if not await _capture("tmp/screenshot-play.png"):
		return false
	for capture_group: Callable in [
		_capture_moves, _capture_combat, _capture_results, _capture_display
	]:
		if not await capture_group.call(main):
			return false
	main.queue_free()
	# 音声ミキサーが停止済みの再生リソースを解放する周期を待つ。
	await create_timer(0.2).timeout
	await process_frame
	return true


func _capture_moves(main: Control) -> bool:
	for stance: String in ["standing", "crouching", "air"]:
		for kind: String in ["lp", "hp", "lk", "hk"]:
			main.player.reset_fighter(Vector2(570, 570 if stance != "air" else 450))
			main.cpu.reset_fighter(Vector2(735, 570))
			main.player.enabled = true
			main.player.control(Vector2(0, 1 if stance == "crouching" else 0))
			main.player.start_attack(kind)
			main.player.attack_time = float(main.player.move_data.startup) + 0.03
			main.player.enabled = false
			main.player.queue_redraw()
			if not await _capture("tmp/screenshot-%s-%s.png" % [stance, kind]):
				return false
	return true


func _capture_combat(main: Control) -> bool:
	main.player.reset_fighter(Vector2(570, 570))
	main.cpu.reset_fighter(Vector2(710, 570))
	main.player.enabled = true
	main.cpu.enabled = true
	main.player.start_attack("hp")
	await create_timer(0.22).timeout
	main.player.enabled = false
	main.cpu.enabled = false
	if not await _capture("tmp/screenshot-hit.png"):
		return false
	main.player.reset_fighter(Vector2(1070, 570))
	main.cpu.reset_fighter(Vector2(1195, 570))
	main.player.facing = 1.0
	main.cpu.facing = -1.0
	main.effects.clear()
	main.feedback = ""
	main.cpu.control(Vector2(1, 0))
	main.player.enabled = true
	main.cpu.enabled = true
	main.player.start_attack("hp")
	await create_timer(0.23).timeout
	main.player.enabled = false
	main.cpu.enabled = false
	if not await _capture("tmp/screenshot-guard.png"):
		return false
	main.effects.clear()
	main.player.reset_fighter(Vector2(420, 570))
	main.cpu.reset_fighter(Vector2(900, 570))
	main.player.enabled = true
	main.player.start_attack("special")
	await create_timer(0.44).timeout
	main.player.enabled = false
	for projectile: Node in get_nodes_in_group("projectiles"):
		projectile.set_physics_process(false)
	if not await _capture("tmp/screenshot-special.png"):
		return false
	return true


func _capture_results(main: Control) -> bool:
	var state: Node = root.get_node("Match")
	main.effects.clear()
	main.feedback_time = 0.0
	for projectile: Node in get_nodes_in_group("projectiles"):
		projectile.queue_free()
	state.finish_round(0, 1000)
	main.cpu.health = 1000
	main.player.health = 0
	main.player.queue_redraw()
	if not await _capture("tmp/screenshot-ko.png"):
		return false
	state.wins.assign([2, 1])
	main._clear_arena()
	state.screen = state.Screen.RESULT
	if not await _capture("tmp/screenshot-victory.png"):
		return false
	state.wins.assign([0, 2])
	if not await _capture("tmp/screenshot-defeat.png"):
		return false
	main.show_title()
	if not await _capture("tmp/screenshot-return.png"):
		return false
	return true


func _capture_display(main: Control) -> bool:
	main.previewing = false
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_F11
	key.pressed = true
	Input.parse_input_event(key)
	await create_timer(0.5).timeout
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
		push_error("F11で全画面にならない")
		quit(1)
		return false
	if not await _capture("tmp/screenshot-fullscreen.png"):
		return false
	key.pressed = false
	Input.parse_input_event(key)
	await process_frame
	key.pressed = true
	Input.parse_input_event(key)
	await create_timer(0.5).timeout
	key.pressed = false
	Input.parse_input_event(key)
	return true


func _capture(path: String) -> bool:
	await process_frame
	await process_frame
	var status: Error = root.get_viewport().get_texture().get_image().save_png(path)
	if status != OK:
		push_error("スクリーンショット保存失敗: %s (%s)" % [path, error_string(status)])
		quit(1)
		return false
	print("screenshot: " + path)
	return true
