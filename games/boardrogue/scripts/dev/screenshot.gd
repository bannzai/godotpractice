extends SceneTree

var ui: Control
var run: Node
var failures: int = 0
var captures: String = "res://../../tmp/boardrogue-captures"

func _initialize() -> void:
	var dedicated_save: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--save-path=") and argument != "--save-path=" and argument != "--save-path=user://expedition.json":
			dedicated_save = true
	if not dedicated_save or DisplayServer.get_name() == "headless":
		push_error("描画環境と専用の --save-path が必要です")
		quit(2)
		return
	call_deferred("_capture")

func _capture() -> void:
	create_timer(45.0).timeout.connect(func() -> void: quit(2))
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i(1440, 900)
	ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	run = root.get_node("Run")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(captures))
	await _snap("01-title")
	await _click_action("help")
	await _snap("02-help")
	await _click_action("close")
	await _click_action("new")
	run.seed_value = 19
	await _snap("03-map")
	await _click_action("normal")
	await _snap("04-battle")
	# 固定seedの合法な初手を実際のクリック入力で進める。
	await _click_action("hand:0")
	await _click_action("cell:3")
	_check(not run.battle.board[3].is_empty(), "クリックによる配置")
	await _snap("05-deployed")
	await _click_action("reveal")
	_check(run.battle.board[3].face, "クリックによる登場")
	await _click_action("phase")
	await _click_action("cell:3")
	await _snap("06-attack-target")
	var hp_before: int = run.battle.hp[1]
	await _click_action("king")
	_check(run.battle.hp[1] < hp_before, "クリックによる敵王攻撃")
	await _snap("07-king-hit")
	await _click_action("phase")
	while ui.busy:
		await process_frame
	_check(run.battle.turn == 0, "CPUから自分へ手番が戻る")
	await _snap("08-enemy-response")
	await _click_action("deck")
	await _snap("09-deck")
	await _click_action("close")
	# 以下は画面の密度・五列・報酬・結果を検証する表示専用状態。
	run.screen = "map"
	run.choose_route(true)
	for index: int in range(10):
		run.battle.board[index] = {"id": ["blade", "archer", "bulwark", "shade", "champion"][index % 5], "side": 1 if index < 5 else 0, "face": index % 3 != 0, "moved": false, "attacked": false}
	ui.selected = 5
	run.battle.begin_attack()
	await _snap("10-five-columns")
	root.size = Vector2i(1152, 720)
	await _snap("10-small-window")
	root.size = Vector2i(1440, 900)
	run.battle.winner = 0
	run.finish_battle()
	await _snap("11-rare-reward")
	await _click_action("reward:0")
	_check(run.stage == 1 and run.deck.size() == 9, "報酬から次の道へ")
	run.screen = "victory"
	await _snap("12-victory")
	run.screen = "defeat"
	await _snap("13-defeat")
	ui.sound.toggle()
	await create_timer(0.3).timeout
	print("画面・クリック検証：失敗 %d" % failures)
	quit(0 if failures == 0 else 1)

func _click_action(action: String) -> void:
	await process_frame
	await process_frame
	for region: Dictionary in ui.regions:
		if region.action == action:
			var click: InputEventMouseButton = InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = region.rect.get_center()
			root.push_input(click)
			click = click.duplicate()
			click.pressed = false
			root.push_input(click)
			await process_frame
			return
	_check(false, "操作が見つからない: %s" % action)

func _snap(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(captures.path_join(label + ".png"))
	_check(error == OK, "撮影 %s" % label)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
	else:
		print("確認: %s" % message)
