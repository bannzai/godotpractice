extends SceneTree
## 本番 InputMap・UI を通して、実キー・パッド・マウス入力の結果を検査する。
## 入力列による結合検証なので非冪等。結果表示・同一フレームの建替えは明示した fixture を用いる。

const Catalog = preload("res://scripts/catalog.gd")

var main: Node
var run: Node
var failed: bool = false


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	root.size = Vector2i(1280, 720)
	run = root.get_node("Run")
	# 個人のセーブは上書きしない。結果と指南のfixtureは検証専用の保存先を使う。
	run.save_path = "res://tmp/integration-save.json"
	run.tutorial_save_path = "res://tmp/integration-tutorial.json"
	_remove_file(run.tutorial_save_path)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout
	_check(run.phase == "title", "起動時のタイトル")
	await _key(KEY_ENTER)
	_check(run.phase == "map", "Enter でタイトルから地図へ")
	await _key(KEY_ESCAPE)
	_check(run.phase == "title", "地図の Esc で表紙へ戻る")
	await _key(KEY_ENTER)
	await _key(KEY_ENTER)
	_check(run.phase == "play", "地図の Enter でゲーム開始")
	await _check_tutorial()
	await _check_tutorial_skip()
	await _check_keyboard_build()
	await _check_pad_build()
	await _check_stick()
	await _check_mouse_build()
	await _check_wave_and_speed()
	await _check_results()
	await _check_fullscreen()
	await _check_same_frame_rebuild()
	main.stop_audio()
	await create_timer(0.2).timeout
	main.queue_free()
	await process_frame
	if not failed:
		print("integration OK")
	quit(1 if failed else 0)


func _check_tutorial() -> void:
	_check(main.tutorial_active, "初回プレイで指南を表示")
	_check(main.tutorial_step == main.TutorialStep.SITE, "指南は地点選択から開始")
	_check("光る空き地点" in main.tutorial_text.text, "地点選択の次操作を場面内に表示")
	_check(main.build_button.disabled and "先に地点" in main.build_button.text,
		"指南中は手順外の建設を理由付きで無効化")
	_check(main.wave_button.disabled and "先に地点" in main.wave_button.text,
		"指南中は手順外の襲来を理由付きで無効化")
	await _key(KEY_RIGHT)
	_check(main.tutorial_step == main.TutorialStep.TOWER, "地点選択後は紋章盾の選択へ")
	_check(main.build_button.disabled and "先に紋章盾" in main.build_button.text,
		"紋章盾の選択前は建設を無効化")
	await _key(KEY_TAB)
	_check(main.tutorial_step == main.TutorialStep.BUILD, "塔盾選択後は建設へ")
	await process_frame
	_check("建設後の金貨" in main.detail.text, "建設前に残金をプレビュー")
	_check(main.tower_buttons[main.selected_kind].has_meta("tower_kind"),
		"塔ボタンを紋章画像と結び付けられる")
	var before: int = run.gold
	await _key(KEY_ENTER)
	_check(run.towers.size() == 1 and run.gold < before, "指南の実入力で塔を建設")
	_check(main.tutorial_step == main.TutorialStep.WAVE, "建設後は襲来開始へ")
	await process_frame
	_check(main.upgrade_button.disabled and main.sell_button.disabled,
		"指南完了前は強化と売却を無効化")
	_check("強化後" in main.detail.text and "売却後" in main.detail.text,
		"建設後に強化前後と売却後資金をプレビュー")
	_check("次の敵" in main.preview.text, "襲来前に次の敵をプレビュー")
	await _key(KEY_SPACE)
	_check(run.active and not main.tutorial_active, "襲来開始で指南を完了")
	_check(run.tutorial_seen and FileAccess.file_exists(run.tutorial_save_path),
		"指南の既読を保存")
	_reset_play_fixture()


func _check_tutorial_skip() -> void:
	run.to_title()
	run.tutorial_seen = false
	main._reset_board()
	main._show_phase()
	await _key(KEY_ENTER)
	await _key(KEY_ENTER)
	_check(main.tutorial_active, "未読なら再び指南を表示")
	await _key(KEY_Q)
	_check(not main.tutorial_active and run.tutorial_seen, "Q で指南をスキップ")
	_reset_play_fixture()


func _reset_play_fixture() -> void:
	run.new_run()
	main.selected_site = 0
	main.selected_kind = 0
	main.tutorial_active = false
	main.tutorial_step = main.TutorialStep.DONE
	main._reset_board()


func _check_keyboard_build() -> void:
	var initial_gold: int = run.gold
	var site: int = main.selected_site
	await _key(KEY_ENTER)
	_check(run.towers.size() == 1, "Enter で最初の塔を建設")
	_check(run.gold == initial_gold - int(Catalog.TOWERS.arrow.cost), "建設費を一度だけ消費")
	var after_build: int = run.gold
	await _key(KEY_ENTER)
	_check(run.towers.size() == 1 and run.gold == after_build, "建設済み地点への二重購入を拒否")
	_check("地点に塔があります" in main.notice.text, "建設できない具体的な理由を表示")
	_check(main.build_button.disabled and "地点に塔" in main.build_button.text,
		"占有地点の建設ボタンに不可理由を表示")
	await _key(KEY_U)
	var tower: Dictionary = run.tower_at(site)
	_check(not tower.is_empty() and tower.get("level") == 2, "U で塔を強化")
	_check(run.gold == after_build - Catalog.upgrade_cost("arrow", 1), "強化費を正しく消費")
	var before_sell: int = run.gold
	await _key(KEY_X)
	_check(run.tower_at(site).is_empty(), "X で売却")
	_check(run.gold == before_sell + Catalog.sell_value("arrow", 2), "強化費を含む売却額")
	var restored_gold: int = run.gold
	run.gold = 0
	main._update_hud(0.1)
	_check(main.build_button.disabled and "あと" in main.build_button.text,
		"資金不足の必要金額を建設ボタンに表示")
	run.gold = restored_gold
	main._update_hud(0.1)
	await _key(KEY_RIGHT)
	_check(main.selected_site != site, "右キーで建設地点を移動")
	await _key(KEY_LEFT)
	_check(main.selected_site == site, "左キーで建設地点へ戻る")


func _check_pad_build() -> void:
	var site: int = main.selected_site
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	_check(main.selected_site != site, "パッド十字キーで地点を移動")
	var kind: int = main.selected_kind
	await _pad(JOY_BUTTON_RIGHT_SHOULDER)
	_check(main.selected_kind == (kind + 1) % 4, "右肩で塔の種類を切り替え")
	var before: int = run.gold
	await _pad(JOY_BUTTON_A)
	_check(run.towers.size() == 1 and run.gold < before, "パッド A で建設を決定")
	site = main.selected_site
	before = run.gold
	var price: int = run.upgrade_price(site)
	await _pad(JOY_BUTTON_LEFT_SHOULDER)
	_check(run.gold == before - price, "左肩で選択塔を強化")
	var refund: int = run.sell_price(site)
	before = run.gold
	await _pad(JOY_BUTTON_B)
	_check(run.towers.is_empty() and run.gold == before + refund, "パッド B で売却")


func _check_mouse_build() -> void:
	var before: int = run.gold
	await _click(Catalog.SITES[4])
	_check(main.selected_site == 4, "マウスで建設地点を選択")
	_check(run.gold == before and run.tower_at(4).is_empty(), "地点の選択だけでは購入しない")
	await _click_button("建設")
	_check(not run.tower_at(4).is_empty() and run.gold < before, "マウスで選んだ地点へ建設")
	var tower_count: int = run.towers.size()
	await _click(Vector2(40, 610))
	_check(run.towers.size() == tower_count, "建設地点外のクリックで塔が増えない")


func _check_stick() -> void:
	for entry: Array in [[JOY_AXIS_LEFT_X, -1.0, -1, "左"],
		[JOY_AXIS_LEFT_X, 1.0, 1, "右"], [JOY_AXIS_LEFT_Y, -1.0, -1, "上"],
		[JOY_AXIS_LEFT_Y, 1.0, 1, "下"]]:
		var site: int = main.selected_site
		var motion := InputEventJoypadMotion.new()
		motion.axis = entry[0]
		motion.axis_value = entry[1]
		Input.parse_input_event(motion)
		await process_frame
		motion = InputEventJoypadMotion.new()
		motion.axis = entry[0]
		motion.axis_value = 0.0
		Input.parse_input_event(motion)
		await create_timer(0.2).timeout
		_check(main.selected_site == posmod(site + int(entry[2]), Catalog.SITES.size()),
			"左スティックの %s 入力が正しい方向へ地点を移動" % entry[3])


func _check_wave_and_speed() -> void:
	await _key(KEY_F)
	_check(run.speed == 3, "F で 3 倍速")
	await _pad(JOY_BUTTON_X)
	_check(run.speed == 1, "パッド X で 1 倍速へ戻る")
	await _pad(JOY_BUTTON_X)
	_check(run.speed == 3, "パッド X で 3 倍速")
	await _pad(JOY_BUTTON_Y)
	_check(run.active and run.wave == 1, "パッド Y でウェーブ開始")
	await _key(KEY_SPACE)
	_check(run.wave == 1, "進行中の Space でウェーブを二重開始しない")
	_check(not run.enemies.is_empty(), "本番フレーム更新で敵が出現")


func _check_results() -> void:
	# 結果からの操作だけを分離する fixture。勝敗条件の通常ロジックは selfcheck が検査する。
	print("結果操作の fixture: 敗北・勝利状態を設定し、入力からの遷移を検査")
	run.phase = "lose"
	run.active = false
	run.hp = 0
	await create_timer(0.2).timeout
	await _pad(JOY_BUTTON_A)
	_check(run.phase == "play" and run.hp == Catalog.MAX_HP, "敗北結果から A で再挑戦")
	_check(run.towers.is_empty() and run.gold == Catalog.START_GOLD and run.wave == 0,
		"再挑戦で塔・資金・ウェーブを初期化")
	run.phase = "win"
	await create_timer(0.2).timeout
	await _key(KEY_ESCAPE)
	_check(run.phase == "title", "勝利結果から Esc でタイトルへ戻る")
	await _click_first_button()
	_check(run.phase == "map", "タイトルのボタンを実クリックして地図へ")
	await _click_first_button()
	_check(run.phase == "play", "地図のボタンを実クリックして開始")
	run.phase = "win"
	await create_timer(0.2).timeout
	await _key(KEY_ENTER)
	_check(run.phase == "play", "勝利結果から Enter で再挑戦")
	run.phase = "lose"
	await create_timer(0.2).timeout
	await _pad(JOY_BUTTON_START)
	_check(run.phase == "title", "敗北結果から Start でタイトルへ戻る")


func _check_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var initial_mode: int = DisplayServer.window_get_mode()
	await _key(KEY_F11)
	await create_timer(1.2).timeout
	_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "F11 で全画面")
	await _key(KEY_F11)
	await create_timer(1.2).timeout
	_check(DisplayServer.window_get_mode() == initial_mode, "F11 でウィンドウへ復帰")


func _check_same_frame_rebuild() -> void:
	# 同じフレーム内のイベント競合を再現する状態操作 fixture。資金は通常の初期額を使う。
	print("建替えの fixture: 同一フレームに連弩を売却し、同じ地点へ臼砲を建設")
	run.new_run()
	_check(run.build(0, "arrow"), "建替え前の連弩を通常の資金で建設")
	for _frame: int in range(3):
		await process_frame
	_check(main.board.tower_nodes.has(0), "建替え前の塔の表示を生成")
	if not main.board.tower_nodes.has(0):
		return
	var old_actor: Node2D = main.board.tower_nodes[0]
	_check(old_actor.kind == "arrow", "建替え前は連弩の画像")
	_check(run.sell(0), "同一フレーム内で連弩を売却")
	_check(run.build(0, "mortar"), "同一フレーム内で臼砲を建設")
	for _frame: int in range(3):
		await process_frame
	_check(main.board.tower_nodes.has(0), "建替え後の塔の表示を生成")
	if main.board.tower_nodes.has(0):
		var replacement: Node2D = main.board.tower_nodes[0]
		_check(replacement != old_actor and replacement.kind == "mortar",
			"建替え後の表示を臼砲の新しいノードに置換")
	_check(is_instance_valid(old_actor) and old_actor.sprite.animation == "death",
		"売却された古い連弩は消滅アニメーションを再生")
	await create_timer(0.8).timeout
	_check(not is_instance_valid(old_actor), "消滅アニメーション後に古い連弩を解放")


func _click_first_button() -> void:
	for candidate: Node in main.find_children("*", "Button", true, false):
		var button: Button = candidate as Button
		if button.is_visible_in_tree() and not button.disabled:
			await _click(button.global_position + button.size * 0.5)
			return
	_check(false, "タイトルに操作可能なボタンがある")


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _click_button(caption: String) -> void:
	for candidate: Node in main.find_children("*", "Button", true, false):
		var button: Button = candidate as Button
		if button.is_visible_in_tree() and not button.disabled and caption in button.text:
			await _click(button.global_position + button.size * 0.5)
			return
	_check(false, "操作可能なボタンがある: " + caption)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await create_timer(0.08).timeout


func _pad(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await create_timer(0.08).timeout


func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await create_timer(0.08).timeout


func _check(condition: bool, description: String) -> void:
	if not condition:
		failed = true
		push_error("integration FAIL: " + description)
