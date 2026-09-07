extends SceneTree
## 実入力を本番の GUI に配送して、開始・地図・イベント・戦闘・結果・再開を検証する。
## シナリオは状態と時間を進めるため非冪等。検証用保存先は通常の user:// と分離する。

var main: Control
var run: Node
var failed: bool = false
var checks: int = 0
var scenario_elapsed: float = 0.0
var deadline_seconds: float = 120.0


func _initialize() -> void:
	_run_checks.call_deferred()


func _process(delta: float) -> bool:
	scenario_elapsed += delta
	if scenario_elapsed > deadline_seconds:
		push_error("検証シナリオが制限時間を超えた")
		quit(1)
	return false


func _load_main(save_name: String = "integration") -> void:
	root.size = Vector2i(1280, 720)
	run = root.get_node("GameState")
	run.save_path = "res://tmp/%s-save.json" % save_name
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await _settle()


func _run_checks() -> void:
	await _load_main()
	_check(run.mode == "title", "最初にタイトルを表示")
	_set_seed(20260907)
	await _click_name("StartRun")
	_check(run.mode == "intro", "マウスで新規の物語を開始")
	await _key(KEY_ENTER)
	await _settle()
	_check(run.mode == "map", "Enterで導入を閉じて地図へ進む")
	await _check_overlays()
	await _finish_natural_run()
	_check(run.mode == "result", "通常の選択と戦闘で結末へ到達")
	_check(run.ending == "darkness" and run.darkness == 100, "収集の代償が蓄積して闇堕ちの結末に到達")
	_check(run.collected.size() > 3, "実際の選択で初期の三体より多くの霊を集めた")
	await _click_name("ReturnTitle")
	_check(run.mode == "title", "結果のマウス操作でタイトルへ戻る")
	_set_seed(20260907)
	_button("StartRun").grab_focus()
	await _joy(JOY_BUTTON_A)
	await _settle()
	_check(run.mode == "intro", "ゲームパッド A で新規開始")
	await _joy(JOY_BUTTON_A)
	await _settle()
	_check(run.mode == "map", "ゲームパッド A で地図へ進む")
	await _click_name("SkipTutorial")
	_check(run.tutorial_step == run.TUTORIAL_COMPLETE, "案内を実クリックで飛ばせる")
	_button("Branch0").grab_focus()
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	var focused: Control = root.gui_get_focus_owner()
	_check(focused == _button("Branch1"), "方向パッドで右の道へフォーカス")
	await _joy(JOY_BUTTON_A)
	await _settle()
	_check(run.mode == "event", "方向パッド選択後の A で道へ入る")
	await _click_name("EventChoice0")
	await _check_battle_input()
	var saved_snapshot: Dictionary = _run_snapshot()
	await _key(KEY_ESCAPE)
	await _settle()
	_check(main.overlay == "pause", "Esc で休止メニューを開く")
	await _click_name("SaveTitle")
	_check(run.mode == "title", "休止メニューからランを保存してタイトルへ戻る")
	_check(is_instance_valid(_button("ResumeRun")), "保存されたランの再開ボタンがある")
	if is_instance_valid(_button("ResumeRun")):
		await _click_name("ResumeRun")
		_check(run.mode in ["event", "battle", "map"], "タイトルから保存したランを再開")
		_check(_run_snapshot() == saved_snapshot, "再開後の場所・闇・体力・敵・技資源が保存前と一致")
	await _check_reserve_promotion()
	await _finish_checks("integration OK")


func _check_overlays() -> void:
	await _click_name("OpenCodex")
	_check(is_instance_valid(_button("CloseOverlay")), "図鑑をマウスで開く")
	_button("CodexNext").grab_focus()
	await _joy(JOY_BUTTON_A)
	await _settle()
	_check(main.codex_page == 1, "ゲームパッド A で図鑑の次の頁へ進む")
	await _key(KEY_ESCAPE)
	_check(not is_instance_valid(_button("CloseOverlay")), "Esc で図鑑を閉じる")
	await _click_name("OpenParty")
	_check(is_instance_valid(_button("CloseOverlay")), "編成画面を開く")
	await _click_name("CloseOverlay")
	_check(not is_instance_valid(_button("CloseOverlay")), "編成画面を閉じる")


func _finish_natural_run(limit: int = 240) -> void:
	var checked_swap: bool = false
	for _step: int in range(limit):
		if run.mode == "result" or failed:
			return
		if not checked_swap and run.mode == "map" and run.party.size() >= 4:
			await _check_party_swap()
			checked_swap = true
		await _act_on_run()
	_check(false, "規定操作数以内にランが終了する")


func _check_party_swap() -> void:
	var original: int = run.party[0].uid
	var reserve: int = run.party[3].uid
	await _click_name("OpenParty")
	await _click_name("Front0")
	await _click_name("Reserve3")
	_check(run.party[0].uid == reserve and run.party[3].uid == original,
		"実クリックで前衛と控えを入れ替えられる")
	await _click_name("CloseOverlay")


func _run_snapshot() -> Dictionary:
	return {
		"mode": run.mode, "seed": run.run_seed, "depth": run.depth,
		"darkness": run.darkness, "ether": run.ether, "relics": run.relics,
		"party": run.party.duplicate(true), "enemies": run.enemies.duplicate(true),
		"turn": run.turn, "route_choices": run.route_choices.duplicate()
	}


func _act_on_run() -> void:
	match String(run.mode):
		"map":
			await _click_name("Branch%d" % _preferred_branch())
		"event":
			await _click_name("EventChoice%d" % _preferred_event_choice())
		"battle":
			await _click_name("ResolveTurn")
		_:
			_check(false, "操作可能な場面: " + String(run.mode))


func _preferred_branch() -> int:
	var tutorial_branch: int = run.tutorial_required_branch()
	if tutorial_branch >= 0:
		return tutorial_branch
	for kind: String in ["living", "grave", "story", "police", "rest", "battle", "boss"]:
		for branch: int in range(run.route[run.depth].size()):
			if run.route[run.depth][branch].kind == kind:
				return branch
	return 0


func _preferred_event_choice() -> int:
	return 1 if run.current_node.kind == "story" else 0


func _check_battle_input() -> void:
	_check(run.mode == "map" and run.depth == 1, "最初のイベントを終えて二つ目の辻へ進む")
	for branch: int in range(run.route[run.depth].size()):
		if run.route[run.depth][branch].kind == "battle":
			_button("Branch%d" % branch).grab_focus()
			await _key(KEY_ENTER)
			await _settle()
			break
	_check(run.mode == "battle", "Enterで選んだ道から戦闘へ入る")
	if run.mode != "battle":
		return
	var turn_before: int = run.turn
	var hp_before: int = run.enemies[0].hp
	_button("Move0_1").grab_focus()
	await _joy(JOY_BUTTON_A)
	await _settle()
	await _click_name("ResolveTurn")
	_check(run.mode != "battle" or run.turn > turn_before, "実入力で技を選択し戦闘ターンを解決")
	_check(run.mode != "battle" or run.enemies[0].hp < hp_before, "選択した技で敵の体力が減る")


## 前衛喪失直後の表示を検証する固定条件。プレイ録画の初期状態には使用しない。
func _check_reserve_promotion() -> void:
	var catalog: Script = load("res://scripts/catalog.gd")
	main.busy = true
	run.new_run(20260907)
	run.skip_tutorial()
	run.begin_journey()
	run.depth = 1
	run.route_choices.assign([0])
	for branch: int in range(run.route[run.depth].size()):
		if run.route[run.depth][branch].kind == "battle":
			run.enter_node(branch)
			break
	run._gain_spirit("fox")
	run.party[0].hp = 1
	run.enemies.assign([catalog.create_spirit("crow", -1)])
	var lost_uid: int = run.party[0].uid
	var reserve_uid: int = run.party[3].uid
	# 最速の敵が先頭を攻撃する種を選び、確率に依存せず喪失直後の表示を通す。
	var probe := RandomNumberGenerator.new()
	for seed_value: int in range(1, 100):
		probe.seed = seed_value
		if probe.randi_range(0, 2) == 0:
			run.rng.seed = seed_value
			break
	main.moves.assign([0, 0, 0])
	main.target_index = 0
	main.busy = false
	main.render()
	await _settle()
	await _click(_button("ResolveTurn"), "控え昇格の戦闘ターン")
	var promoted: Node2D
	var limit: int = Time.get_ticks_msec() + 8000
	while main.busy and promoted == null and Time.get_ticks_msec() < limit:
		for actor: Node2D in main.actor_nodes:
			if int(actor.get_meta("uid", 0)) == reserve_uid:
				promoted = actor
				break
		if promoted == null:
			await process_frame
	_check(is_instance_valid(promoted), "前衛の喪失直後に控えのActorを表示")
	if is_instance_valid(promoted):
		_check(promoted.character_id == "fox" and promoted.animator.current_animation == "move",
			"控えの固有画像と移動アニメーションで前衛への登場を表現")
		_check(main._health_names[reserve_uid].text == catalog.spirit("fox").name,
			"昇格した霊の名前へ戦闘カードが切り替わる")
		_check(not main._health_bars.has(lost_uid) and main._health_bars.has(reserve_uid),
			"喪失した霊のHP表示が昇格した霊のIDへ切り替わる")
	await _settle()
	_check(run.party.size() == 3, "戦闘ターン完了後も喪失した前衛は復活しない")
	_check(main.actor_nodes.size() == 3, "戦闘の再描画後は生存している三体だけを表示")


func _set_seed(value: int) -> void:
	var field: Node = main.find_child("SeedInput", true, false)
	_check(field is LineEdit, "乱数シード入力欄がある")
	if field is LineEdit:
		field.text = str(value)


func _button(node_name: String) -> Button:
	var found: Node = main.find_child(node_name, true, false)
	return found as Button


func _click_name(node_name: String) -> void:
	await _click(_button(node_name), node_name)
	await _settle()


## マウス移動と押下・解放を別フレームで本番 Button に送る。
func _click(button: Button, description: String = "") -> void:
	if not is_instance_valid(button) or button.disabled or not button.is_visible_in_tree():
		_check(false, "クリック対象が操作可能: " + description)
		return
	var point: Vector2 = button.global_position + button.size * 0.5
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func _joy(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func _settle() -> void:
	var limit: int = Time.get_ticks_msec() + 15000
	while main.busy and Time.get_ticks_msec() < limit:
		await process_frame
	await process_frame
	await process_frame
	_check(not main.busy, "画面遷移と戦闘演出が完了")


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error(description)


func _finish_checks(marker: String) -> void:
	main.stop_audio()
	await create_timer(0.25).timeout
	main.queue_free()
	await process_frame
	await process_frame
	print("検証件数: %d" % checks)
	if not failed:
		print(marker)
	quit(1 if failed else 0)
