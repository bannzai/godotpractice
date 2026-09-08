extends SceneTree

const Battle = preload("res://scripts/battle.gd")
var run: Node
var failures: int = 0

func _initialize() -> void:
	call_deferred("_execute")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _execute() -> void:
	run = root.get_node("Run")
	if not run.save_path.begins_with("res://../../tmp/"):
		push_error("検証専用save-pathが必要")
		quit(1)
		return
	_test_checkpoint()
	_test_routes_and_rewards()
	_test_expeditions()
	print("遠征検証：失敗 %d" % failures)
	quit(1 if failures > 0 else 0)

func _write_save(data: Variant) -> void:
	var file: FileAccess = FileAccess.open(run.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	run.load_checkpoint()

func _test_checkpoint() -> void:
	run.new_run()
	_check(run.screen == "map" and run.stage == 0 and run.health == 10 and run.deck.size() == 8, "新規遠征")
	var original: Dictionary = run.saved.duplicate(true)
	run.screen = "title"
	run.deck.clear()
	run.health = 1
	run.load_checkpoint()
	run.resume_run()
	_check(run.screen == "map" and run.health == 10 and run.deck.size() == 8, "保存・復元")
	for field: String in ["version", "stage", "health", "seed", "victories", "deck"]:
		var corrupted: Dictionary = original.duplicate(true)
		corrupted[field] = "壊れた型"
		_write_save(corrupted)
		_check(run.saved.is_empty(), "保存の型拒否：" + field)
	for corrupted: Variant in [[], "文字列", {"version": 1}]:
		_write_save(corrupted)
		_check(run.saved.is_empty(), "不完全な保存拒否")
	for field: String in ["version", "stage", "health", "seed", "victories"]:
		var corrupted: Dictionary = original.duplicate(true)
		corrupted[field] = 1.5
		_write_save(corrupted)
		_check(run.saved.is_empty(), "小数の保存拒否：" + field)
	var invalid: Dictionary = original.duplicate(true)
	invalid.deck[0] = "存在しない札"
	_write_save(invalid)
	_check(run.saved.is_empty(), "不正札ID拒否")
	invalid = original.duplicate(true)
	invalid.victories = -1
	_write_save(invalid)
	_check(run.saved.is_empty(), "不正勝利数拒否")
	invalid = original.duplicate(true)
	invalid.stage = 1
	_write_save(invalid)
	_check(run.saved.is_empty(), "到達戦数・勝利数・デッキ枚数の矛盾拒否")
	_write_save(original)
	run.resume_run()
	print("保存復元・型/範囲/整合性の破損拒否を検証")

func _test_routes_and_rewards() -> void:
	run.new_run()
	run.choose_route(false)
	_check(run.battle.width == 3, "通常戦3列")
	var first: RefCounted = run.battle
	run.choose_route(true)
	_check(run.battle == first, "対戦中の再選択拒否")
	run.new_run()
	run.choose_route(true)
	_check(run.battle.width == 5, "精鋭戦5列")
	run.battle.winner = 0
	run.finish_battle()
	_check(run.screen == "reward" and run.rewards.size() == 3, "報酬3候補")
	for id: String in run.rewards:
		_check(Battle.CARDS[id].rare, "精鋭報酬は全候補レア")
	var wins: int = run.victories
	run.finish_battle()
	_check(run.victories == wins, "勝利の二重反映拒否")
	run.take_reward(-1)
	_check(run.screen == "reward", "無効報酬拒否")
	var count: int = run.deck.size()
	run.take_reward(0)
	run.take_reward(0)
	_check(run.deck.size() == count + 1 and run.stage == 1, "報酬1枚のみ")
	run.screen = "title"
	run.load_checkpoint()
	run.resume_run()
	_check(run.stage == 1 and run.victories == 1 and run.deck.size() == 9, "報酬後保存復元")
	run.choose_route(false)
	run.battle.winner = 1
	run.battle.hp[0] = 0
	run.finish_battle()
	run.load_checkpoint()
	run.resume_run()
	_check(run.screen == "defeat" and run.saved.is_empty(), "敗北遠征再開不可")
	print("分岐・報酬・重複操作拒否・敗北時保存消去を検証")

func _play_player() -> void:
	var battle: RefCounted = run.battle
	for cell: int in range(battle.width, battle.width * 2):
		var best: int = -1
		for hand_index: int in range(battle.hands[0].size()):
			var id: String = battle.hands[0][hand_index]
			if int(Battle.CARDS[id].cost) <= battle.energy and (best == -1 or int(Battle.CARDS[id].power) > int(Battle.CARDS[battle.hands[0][best]].power)):
				best = hand_index
		if best >= 0:
			battle.deploy(best, cell)
	for cell: int in range(battle.board.size()):
		battle.reveal(cell)
	battle.begin_attack()
	for cell: int in range(battle.board.size()):
		var targets: Array[int] = battle.legal_targets(cell)
		if targets.has(-1):
			battle.attack(cell, -1)
		elif not targets.is_empty():
			battle.attack(cell, targets[0])
	battle.end_turn()

func _test_expeditions() -> void:
	var victories: int = 0
	var defeats: int = 0
	for seed_value: int in range(100):
		run.new_run()
		run.seed_value = seed_value
		for stage_index: int in range(5):
			run.choose_route(false)
			_check(run.battle.width == (5 if stage_index == 4 else 3), "最終戦は5列")
			for turn_index: int in range(300):
				if run.battle.winner != -1:
					break
				if run.battle.turn == 0:
					_play_player()
				else:
					run.battle.play_enemy()
			_check(run.battle.winner != -1, "合法手対戦の決着")
			run.finish_battle()
			if run.screen == "defeat":
				defeats += 1
				break
			if run.screen == "victory":
				_check(stage_index == 4 and run.victories == 5 and run.saved.is_empty(), "5戦目制覇と保存消去")
				victories += 1
				break
			_check(run.screen == "reward", "途中勝利は報酬へ")
			var best: int = 0
			for index: int in range(run.rewards.size()):
				if int(Battle.CARDS[run.rewards[index]].power) > int(Battle.CARDS[run.rewards[best]].power):
					best = index
			run.take_reward(best)
	_check(victories > 0 and defeats > 0, "合法操作だけで制覇と敗北の両方へ到達")
	print("100シード遠征：制覇 %d / 敗北 %d" % [victories, defeats])
