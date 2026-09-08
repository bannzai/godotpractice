extends SceneTree
## 描画された画面へ実入力を配送し、操作から盤の更新までを検証する。

const Battle = preload("res://scripts/battle.gd")
var main: Control
var run: Node
var failures: int = 0


func _initialize() -> void:
	var dedicated_save: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--save-path=") and not argument.trim_prefix("--save-path=").is_empty():
			dedicated_save = argument != "--save-path=user://expedition.json"
	if not dedicated_save or DisplayServer.get_name() == "headless":
		push_error("描画環境と専用の --save-path が必要です")
		quit(2)
		return
	create_timer(45.0).timeout.connect(func() -> void:
		push_error("入力検証が45秒で完了しませんでした")
		quit(2))
	_start.call_deferred()


func _start() -> void:
	run = root.get_node("Run")
	main = load("res://scenes/main.tscn").instantiate() as Control
	root.add_child(main)
	await _frame()
	_fixture()
	run.battle.board[3] = _unit("blade", 0)
	run.battle.board[0] = _unit("scout", 1)
	await _frame()
	await _click("cell:3")
	_check(main.selected == 3, "マウスで自札を選択")
	await _click("phase")
	_check(run.battle.phase == "attack", "マウスで攻めに移行")
	await _click("cell:3")
	await _click("cell:0")
	_check(run.battle.board[3].is_empty() and run.battle.board[0].get("id") == "blade", "マウス攻撃で敵札を撃破し前進")
	_check(run.battle.discards[1] == ["scout"], "撃破した敵札が捨て場へ移る")
	_fixture()
	run.battle.hands[0] = ["blade"]
	await _frame()
	await _key(KEY_1)
	_check(main.hand_index == 0, "数字で手札を選択")
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	_check(run.battle.board[3].get("id") == "blade" and not run.battle.board[3].get("face", true), "矢印とEnterで伏せ配置")
	await _key(KEY_R)
	_check(run.battle.board[3].get("face", false), "Rで登場")
	await _key(KEY_SPACE)
	_check(run.battle.phase == "attack", "Spaceで攻めに移行")
	await _key(KEY_ENTER)
	_check(main.selected == 3, "Enterで盤上の自札を選択")
	await _key(KEY_K)
	_check(run.battle.hp[1] == 8, "Kで敵王へ攻撃力分のダメージ")
	_fixture()
	run.battle.hands[0] = ["blade"]
	await _frame()
	await _key(KEY_ESCAPE)
	_check(main.menu_open, "Escでメニューを開く")
	await _blocked_inputs()
	var was_enabled: bool = main.sound.enabled
	await _click("audio")
	_check(main.sound.enabled != was_enabled, "メニューで音を切り替える")
	await _key(KEY_ESCAPE)
	_check(not main.menu_open, "Escでメニューを閉じる")
	await _key(KEY_H)
	_check(main.help_open, "Hで手ほどきを開く")
	await _blocked_inputs()
	await _click("close")
	_check(not main.help_open, "マウスで手ほどきを閉じる")
	was_enabled = main.sound.enabled
	await _key(KEY_M)
	_check(main.sound.enabled != was_enabled, "Mで音を切り替える")
	print("入力経路検証: 失敗 %d" % failures)
	quit(0 if failures == 0 else 1)


func _fixture() -> void:
	run.battle = Battle.new()
	var player_cards: Array[String] = ["blade"]
	var enemy_cards: Array[String] = ["scout"]
	run.battle.setup(3, player_cards, enemy_cards, 51)
	run.screen = "battle"
	run.stage = 0
	main.hand_index = -1
	main.selected = -1
	main.focused_cell = 0
	main.busy = false
	main.help_open = false
	main.menu_open = false
	main.deck_open = false
	main.queue_redraw()


func _unit(id: String, side: int) -> Dictionary:
	return {"id": id, "side": side, "face": true, "moved": false, "attacked": false}


## 操作順を再現する回帰検証なので入力の配送は非冪等。
func _blocked_inputs() -> void:
	await _key(KEY_1)
	await _key(KEY_SPACE)
	await _point(Vector2(1254, 561))
	await _point(Vector2(345, 746))
	_check(run.battle.phase == "prepare" and main.hand_index == -1, "重ねた画面の背後にマウス・キー入力を通さない")


func _click(action: String) -> void:
	for region: Dictionary in main.regions:
		if region.action == action:
			await _point(region.rect.get_center())
			return
	_check(false, "クリック領域が存在: " + action)


## 押下と解放の組を配送するため非冪等。
func _point(at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await _frame()


## 押下と解放の組を配送するため非冪等。
func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await _frame()


func _frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw


## 検査失敗数を累積するため非冪等。
func _check(condition: bool, label: String) -> void:
	if condition:
		print("成功: " + label)
	else:
		failures += 1
		push_error("失敗: " + label)
