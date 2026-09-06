extends SceneTree
## 描画と入力経路を同じシーンで検証する。撮影用の状態投入は製品の操作には公開しない。

const Catalog := preload("res://scripts/card_catalog.gd")

var main: Control
var run: Node
var failed: bool = false


func _initialize() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	_run.call_deferred()


# 同じ進行に入力を重ねないよう、撮影を順に実行する。
func _run() -> void:
	if await _capture_scenes():
		print("入力と代表画面の検証 OK")
		quit(0)
	else:
		quit(1)


func _capture_scenes() -> bool:
	main = load("res://scenes/main.tscn").instantiate()
	run = root.get_node("Run")
	root.get_node("Sound").set_muted(true)
	root.add_child(main)
	await create_timer(0.5).timeout
	await _capture("title")
	await _key(KEY_ENTER)
	_check(run.phase == "map", "Enter でタイトルから開始")
	run.start_run(609)
	await _capture("map")
	await _joy(JOY_BUTTON_A)
	_check(run.phase == "battle", "ゲームパッド A でノード選択")
	await create_timer(0.08).timeout
	await _capture("draw")
	await create_timer(0.5).timeout
	await _capture("battle")
	var index: int = run.hand.find("strike")
	if index >= 0:
		main._play_card(index)
		await create_timer(0.12).timeout
		await _capture("play")
		await create_timer(0.11).timeout
		await _capture("damage")
		await create_timer(0.4).timeout
	var turn_before: int = run.turn
	await _key(KEY_E)
	await create_timer(0.07).timeout
	await _capture("discard")
	await create_timer(0.8).timeout
	_check(run.turn == turn_before + 1, "E でターン終了")
	await _joy(JOY_BUTTON_Y)
	_check(main.modal == "deck", "ゲームパッド Y でデッキ表示")
	await _capture("deck")
	await _joy(JOY_BUTTON_B)
	_check(main.modal.is_empty(), "ゲームパッド B で閉じる")
	await _key(KEY_M)
	_check(main.modal == "map", "M でマップ表示")
	await _capture("map-overlay")
	await _key(KEY_ESCAPE)
	await _capture_large_hand()
	await _complete_run()
	await _capture("victory")
	_check(run.phase == "result" and run.won, "通常操作でクリア結果に到達")
	main._return_title()
	await _joy(JOY_BUTTON_A)
	_check(run.phase == "map", "ゲームパッドで新しい巡礼を開始")
	run.choose_node(0)
	main.busy = true
	for _turn: int in range(100):
		if run.phase == "result":
			break
		run.end_turn()
	main.busy = false
	main._render(false)
	await _capture("defeat")
	_check(run.phase == "result" and not run.won, "敗北結果に到達")
	main._return_title()
	_check(run.phase == "title", "敗北からタイトルへ戻る")
	root.get_node("Sound").stop_all()
	main.queue_free()
	await create_timer(0.3).timeout
	return not failed


func _capture_large_hand() -> void:
	# 上級カードの長文と大量ドロー時だけは、表示専用の手札を投入して元に戻す。
	var previous: Array[String] = run.hand.duplicate()
	run.hand.assign(["fervor", "aegis", "focus", "insight", "renew", "charge",
		"expose", "smoke", "siphon"])
	main._render(false)
	await create_timer(0.1).timeout
	await _capture("large-hand")
	var first: Control = main.card_nodes[0]
	var motion := InputEventMouseMotion.new()
	motion.position = first.global_position + Vector2(70, 60)
	Input.parse_input_event(motion)
	await _capture("card-hover")
	var last: Control = main.card_nodes.back()
	last.grab_focus()
	await create_timer(0.1).timeout
	var scroll: ScrollContainer = last.get_parent().get_parent().get_parent()
	_check(scroll.scroll_horizontal > 0, "フォーカスで手札の末尾へスクロール")
	await _capture("hand-scrolled")
	run.hand.assign(previous)
	main._render(false)


func _complete_run() -> void:
	var seen: Array[String] = []
	for _step: int in range(800):
		if run.phase == "result":
			return
		var phase: String = run.phase
		if phase == "battle" and run.current_kind == "boss":
			phase = "boss"
		if phase not in seen:
			seen.append(phase)
			await create_timer(0.5).timeout
			await _capture(phase)
		main.busy = true
		match String(run.phase):
			"map": _choose_safe_node()
			"rest": run.rest()
			"event": run.resolve_event()
			"reward":
				var choice: int = -1
				for index: int in range(run.reward_cards.size()):
					if run.reward_cards[index] in ["heavy", "siphon", "aegis", "fervor", "bash"]:
						choice = index
				run.choose_reward(choice)
			"battle": _play_turn()
		main.busy = false
		main._render(false)
		await process_frame
	_check(false, "巡礼が規定操作数以内に終了する")


func _choose_safe_node() -> void:
	var row: Array = run.map_rows[run.floor_index + 1]
	for kind: String in ["rest", "event", "card", "battle", "elite", "boss"]:
		for index: int in range(row.size()):
			if row[index].kind == kind:
				run.choose_node(index)
				return


func _play_turn() -> void:
	for _limit: int in range(25):
		if run.phase != "battle":
			return
		var best: int = -1
		var best_score: float = -1.0
		for index: int in range(run.hand.size()):
			var card: Dictionary = Catalog.CARDS[run.hand[index]]
			if int(card.cost) > run.energy:
				continue
			var effects: Dictionary = card.effects
			var score: float = float(effects.get("damage", 0))
			score += float(effects.get("heal", 0)) + float(effects.get("draw", 0)) * 4
			score += float(effects.get("strength", 0)) * 8 + float(effects.get("armor", 0)) * 8
			if run.enemy.intent.kind == "attack" and run.block < int(run.enemy.intent.amount):
				score += float(effects.get("block", 0)) * 1.3
			score /= maxf(1.0, float(card.cost))
			if score > best_score:
				best = index
				best_score = score
		if best < 0:
			break
		run.play_card(best)
	if run.phase == "battle":
		run.end_turn()


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _joy(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		failed = true
		push_error(description)


func _capture(scene_name: String) -> void:
	await process_frame
	await process_frame
	var path: String = "tmp/screenshot-%s.png" % scene_name
	var status: Error = root.get_viewport().get_texture().get_image().save_png(path)
	_check(status == OK, "スクリーンショット保存: " + scene_name)
	print("screenshot: " + path)
