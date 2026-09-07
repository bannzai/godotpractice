extends RefCounted
## 状態遷移・消費・保存の契約を実イベント相当の操作で検証する。

const TEST_SAVE: String = "res://tmp/state-test.json"


static func run(state: Node) -> Array[String]:
	var failures: Array[String] = []
	state.new_game()
	_expect(state.mode == "play" and state.hp == 3 and state.room == 0, "初期状態", failures)
	_expect(not state.unlock_door("door"), "鍵なしで開錠不可", failures)
	_expect(state.open_chest("key", "key"), "小鍵の取得", failures)
	_expect(not state.open_chest("key", "key") and state.keys == 1, "宝箱の重複防止", failures)
	_expect(state.unlock_door("door") and state.keys == 0, "開錠で鍵を消費", failures)
	_expect(state.unlock_door("door") and state.keys == 0, "開錠済みの鍵は再消費しない", failures)
	state.open_chest("heart", "heart")
	_expect(state.max_hp == 4 and state.hp == 4, "ハート上限の増加", failures)
	state.open_chest("money", "coins")
	_expect(not state.spend(13) and state.coins == 12, "不足時の購入不可", failures)
	_expect(not state.spend(-1), "負の価格を拒否", failures)
	_expect(state.spend(10) and state.coins == 2, "購入で所持金を消費", failures)
	state.open_chest("boom", "boomerang")
	_expect(state.boomerang_owned and state.tool == "boomerang", "ブーメラン取得", failures)
	state.open_chest("bomb", "bombs")
	_expect(state.bombs_owned and state.bombs == 5, "爆弾取得", failures)
	state.set_flag("switch")
	state.set_flag("switch")
	_expect(state.has_flag("switch") and state.flags.size() == 1, "仕掛けの重複防止", failures)
	state.set_flag("map-owned")
	_expect(state.has_flag("map-owned"), "羊皮紙の地図を取得", failures)
	state.checkpoint = 7
	state.room = 11
	_expect(state.damage(99) and state.mode == "gameover", "体力ゼロでゲームオーバー", failures)
	state.retry()
	_expect(state.room == 7 and state.hp == 4 and state.mode == "play", "入口から再挑戦", failures)
	state.damage(-5)
	_expect(state.hp == 4, "負のダメージを無視", failures)
	state.damage(2)
	state.heal(1)
	_expect(state.hp == 3, "回復アイテムの効果", failures)
	_expect(state.save_game(TEST_SAVE), "保存に成功", failures)
	var saved: Dictionary = state.snapshot()
	state.new_game()
	_expect(state.load_game(TEST_SAVE), "保存データの復帰", failures)
	_expect(state.snapshot() == saved, "保存前後で全進行を維持", failures)
	_expect(state.has_flag("map-owned"), "保存後も羊皮紙の地図を維持", failures)
	_check_invalid(state, saved, failures)
	var file: FileAccess = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	if file != null:
		file.store_string("{broken save")
		file.close()
		_expect(not state.load_game(TEST_SAVE), "壊れたJSONを拒否", failures)
		_expect(state.snapshot() == saved, "壊れた保存から既存状態を保護", failures)
	else:
		failures.append("破損ファイルを作成できない")
	_expect(not state.load_game("res://tmp/missing-state-save.json"), "未保存で復帰不可", failures)
	state.open_chest("treasure", "treasure")
	_expect(state.mode == "ending" and state.has_flag("treasure"), "宝取得で結末へ", failures)
	state.new_game()
	_expect(state.opened.is_empty() and state.flags.is_empty(), "新規開始で進行を初期化", failures)
	return failures


static func _check_invalid(state: Node, saved: Dictionary, failures: Array[String]) -> void:
	var invalid: Array[Variant] = [null, [], {}, "save"]
	for pair: Array in [
		["schema", 2], ["room", 12], ["room", 1.5], ["hp", -1], ["hp", 24],
		["coins", "12"], ["keys", true], ["bombs_owned", 1], ["mode", "unknown"],
		["flags", {"switch": false}], ["opened", {"": true}], ["tool", "unknown"],
	]:
		var candidate: Dictionary = saved.duplicate(true)
		candidate[pair[0]] = pair[1]
		invalid.append(candidate)
	for candidate: Variant in invalid:
		_expect(not state.restore(candidate), "不正な型・値を拒否: %s" % str(candidate), failures)
		_expect(state.snapshot() == saved, "不正データで状態を変更しない", failures)
	var detached: Dictionary = state.snapshot()
	detached.flags["accidental"] = true
	_expect(not state.has_flag("accidental"), "保存用辞書の変更が状態に漏れない", failures)


static func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
