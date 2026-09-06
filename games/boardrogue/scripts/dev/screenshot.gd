extends SceneTree
## 実入力の途中と描画専用の代表状態を撮影する。保存は検証用ファイルに隔離する。

const Gallery = preload("res://scripts/dev/gallery.gd")
const Catalog = preload("res://scripts/core/catalog.gd")

var main: Control
var run: Node
var failed: bool = false


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	_run.call_deferred()


# 撮影のため時間と入力を進める処理。重ねて呼ばない。
func _run() -> void:
	run = root.get_node("Run")
	run.save_path = "res://tmp/screenshot-save.json"
	run.stage = "title"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _capture_scenes()
	await main.sound.shutdown()
	main.queue_free()
	await process_frame
	print("screenshot OK" if not failed else "screenshot FAIL")
	quit(1 if failed else 0)


func _capture_scenes() -> void:
	await create_timer(0.6).timeout
	await _capture("title")
	await _click("help")
	await _capture("help")
	await _key(KEY_ESCAPE)
	main.seed_input.text = "31"
	await _click("start")
	await create_timer(0.7).timeout
	await _capture("map")
	await _click("route_0_0")
	await _wait_idle()
	await create_timer(0.4).timeout
	await _capture("battle-opening")
	await _click("hand_0")
	await _capture("hand-selected")
	await _click("cell_1_2")
	await _capture("deploy-mid")
	await _wait_idle()
	await _key(KEY_R)
	await create_timer(0.06).timeout
	await _capture("reveal-mid")
	await _wait_idle()
	await _click("move")
	await _click("cell_1_1")
	await create_timer(0.12).timeout
	await _capture("move-mid")
	await _wait_idle()
	await _capture("battle-moved")
	await _representative_scenes()
	await _galleries()


func _representative_scenes() -> void:
	# 盤面全体の表示密度・陣営・伏せ札・説明を調べる専用fixture。プレイ実績には使わない。
	_visit(4, "battle")
	_board_fixture()
	main._render()
	await create_timer(0.4).timeout
	await _capture("battle-five-columns")
	_visit(3, "general")
	main._render()
	main.effects.spawn("boss", Vector2(640, 265))
	main._show_boss_banner()
	await create_timer(0.35).timeout
	await _capture("general-entrance")
	await create_timer(1.3).timeout
	_visit(8, "final")
	_board_fixture()
	main._render()
	await create_timer(0.4).timeout
	await _capture("final-general")
	for kind: String in ["blade", "arrow", "hit", "death", "king", "reward", "heal"]:
		main.effects.spawn(kind, Vector2(640, 306), 4)
		await create_timer(0.15).timeout
		await _capture("effect-" + kind)
		await create_timer(1.15).timeout
	_visit(1, "reward")
	main._render()
	await create_timer(0.4).timeout
	await _capture("reward")
	_visit(3, "rest")
	main._render()
	await create_timer(0.4).timeout
	await _capture("rest")
	_visit(5, "shop")
	main._render()
	await create_timer(0.4).timeout
	await _capture("shop")
	run.collection.assign(Catalog.CARDS.keys())
	main._show_overlay("book")
	await _capture("encyclopedia")
	main._close_overlay()
	_visit(8, "final")
	# 勝敗の画面は合法AI同士の対局から作る。勝利seedを見つけるまで再現する。
	var won: bool = false
	for seed_number: int in range(60):
		run.battle.setup(run.deck, "final", 5, seed_number)
		for step: int in range(600):
			if run.battle.phase == "over":
				break
			run.battle.ai_step()
		if run.battle.winner == 0:
			won = true
			break
	_check(won, "合法AI対局から最終将軍の勝利結果を作る")
	run.resolve_battle()
	main._render()
	await create_timer(0.9).timeout
	await _capture("result-victory")
	run.new_run(31)
	run.choose_node(0)
	for step: int in range(600):
		if run.battle.phase == "over":
			break
		if run.battle.turn == 0:
			if run.battle.phase == "standby":
				run.battle.begin_battle()
			else:
				run.battle.end_turn()
		else:
			run.battle.ai_step()
	_check(run.battle.winner == 1, "敵の通常操作から敗北結果を作る")
	run.resolve_battle()
	main._render()
	await create_timer(0.9).timeout
	await _capture("result-defeat")


func _visit(depth: int, kind: String) -> void:
	run.new_run(31)
	run.depth = depth - 1
	for index: int in range(run.route[depth].size()):
		if run.route[depth][index].type == kind:
			run.choose_node(index)
			break
	main._clear_selection()
	if run.stage == "battle":
		main.speech = Catalog.ENEMIES[run.battle.enemy_id].lines.start


func _board_fixture() -> void:
	var ids: Array = Catalog.CARDS.keys()
	run.battle.units.clear()
	for index: int in range(12):
		var y: int = index / 3
		var side: int = 1 if y < 2 else 0
		run.battle.units.append(
			{
				"uid": index + 100,
				"card": ids[index],
				"x": index % 3 + 1,
				"y": y,
				"side": side,
				"face": index != 1,
				"moved": index == 7,
				"attacked": false,
				"effect_used": false
			}
		)
	main.selected_uid = 111
	main.detail_id = "dragon"


func _galleries() -> void:
	main.visible = false
	var gallery := Gallery.new()
	root.add_child(gallery)
	for group: String in ["cards", "people"]:
		for pose: String in ["idle", "move", "attack", "hurt", "death"]:
			for frame: int in [0, 2, 3]:
				gallery.show_pose(group, pose, frame)
				await _capture("gallery-%s-%s-%d" % [group, pose, frame])
	gallery.queue_free()
	await process_frame
	main.visible = true


func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png("res://tmp/screenshot-%s.png" % name)
	_check(error == OK, "画像保存 " + name)


func _click(name: String) -> void:
	var button: Control = main.content.find_child(name, true, false)
	if not _check(is_instance_valid(button), "クリック対象 " + name):
		return
	var point: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _wait_idle() -> void:
	for frame: int in range(1800):
		if not main.busy:
			return
		await process_frame
	_check(false, "演出終了の待ち時間を超過")


func _check(condition: bool, message: String) -> bool:
	if not condition:
		failed = true
		push_error(message)
	return condition
