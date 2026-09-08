extends "res://scripts/dev/integration.gd"
## 24秒の本番操作を30fpsで録画する。状態は観測だけに使い、札・命・勝敗を書き換えない。
## 入力の時刻をフレーム番号で固定するため、実行ごとに1本のプレイ動画を作る。

var frame_limit: int = 720


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 1 or not arguments[0].is_valid_int():
		push_error("プレイ録画: フレーム数を -- <N> で渡してください")
		quit(2)
		return
	frame_limit = int(arguments[0])
	if frame_limit < 720 or frame_limit > 900:
		push_error("プレイ録画: 720〜900フレームを指定してください")
		quit(2)
		return
	if not await _setup(false):
		await _finish(false)
		return
	var success: bool = await _play()
	if not success or failed:
		await _finish(false)
		return
	await _at(frame_limit - 10)
	AudioStop.stop(root)
	print("demo OK")


func _play() -> bool:
	await _at(22)
	await _enter_seed()
	await _at(55)
	await _click("new")
	if not _check(session.screen == "map", "録画でタイトルから地図へ進む"):
		return false
	await _at(104)
	await _choose_kind("battle")
	if not _check(session.screen == "battle", "録画で戦闘へ進む"):
		return false
	await _at(147)
	await _click("hand-%d" % _strongest_hand())
	await _click("cell-7")
	if not await _idle():
		return false
	await _at(194)
	await _click("cell-7")
	await _click("cell-4")
	if not await _idle():
		return false
	return await _combat_and_result()


func _combat_and_result() -> bool:
	await _at(238)
	await _tap_button(JOY_BUTTON_Y)
	if not await _idle():
		return false
	await _at(350)
	await _tap_key(KEY_B)
	if not await _idle():
		return false
	if not await _attack_once():
		return false
	await _at(444)
	await _tap_key(KEY_E)
	if not await _idle():
		return false
	await _at(548)
	if session.screen == "battle":
		await _click("abandon")
		await _at(575)
		await _click("abandon")
	if not _check(session.screen == "result" and str(session.run.result) == "defeat",
			"録画で正規の断念操作から敗北結果へ進む"):
		return false
	await _at(657)
	await _tap_key(KEY_ENTER)
	return _check(session.screen == "title", "録画の最後にタイトルへ戻る") \
		and _check(_event_count("deploy", 0) > 0 and _event_count("move", 0) > 0,
			"録画で配置と移動が実行されている")


func _attack_once() -> bool:
	if not _check(session.screen == "battle", "攻撃前に戦闘が続いている"):
		return false
	for unit: Dictionary in session.board.units:
		if int(unit.side) != 0:
			continue
		var from: int = int(unit.pos)
		var targets: Array[int] = session.board.legal_targets(from)
		if targets.is_empty():
			continue
		var to: int = targets[0]
		var before: int = _event_count("attack", 0) + _event_count("king_hit", 0)
		await _click("cell-%d" % from)
		await _click("enemy-king" if to == -2 else "cell-%d" % to)
		if not await _idle():
			return false
		return _check(_event_count("attack", 0) + _event_count("king_hit", 0) > before,
			"録画で合法な攻撃が実行される")
	return _check(false, "録画の攻撃時点に合法な対象がある")


func _at(frame: int) -> void:
	while elapsed_frames < frame:
		await process_frame
