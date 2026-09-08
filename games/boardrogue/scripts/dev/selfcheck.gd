extends SceneTree

const Battle = preload("res://scripts/battle.gd")
var failures: int = 0

func _initialize() -> void:
	for columns: int in [3, 5]:
		_test_rules(columns)
		_test_enemy_steps(columns)
		_test_cpu(columns)
	print("戦闘検証：失敗 %d" % failures)
	quit(1 if failures > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _unit(id: String, side: int, face: bool = false) -> Dictionary:
	return {"id": id, "side": side, "face": face, "moved": false, "attacked": false}

func _test_rules(columns: int) -> void:
	var battle: RefCounted = Battle.new()
	var cards: Array[String] = ["blade", "blade", "blade", "blade"]
	battle.setup(columns, cards, cards, 3)
	_check(battle.board.size() == columns * 2, "盤幅")
	_check(battle.hands[0].size() == 3 and battle.hands[1].size() == 3, "初手3枚")
	_check(not battle.deploy(0, -1) and not battle.deploy(0, 0), "盤外・敵陣配置拒否")
	_check(battle.deploy(0, columns), "自陣配置")
	_check(not battle.deploy(0, columns), "重複配置拒否")
	_check(not battle.move_unit(columns, columns + 1), "伏せ札の移動拒否")
	battle.reveal(columns)
	_check(battle.move_unit(columns, columns + 1), "隣接移動")
	battle.begin_attack()
	_check(battle.legal_targets(columns + 1).is_empty(), "移動後攻撃拒否")
	_check(not battle.deploy(0, columns), "攻撃中の配置拒否")
	battle.setup(columns, cards, cards, 3)
	battle.board[columns] = _unit("blade", 0)
	battle.board[0] = _unit("blade", 1)
	battle.reveal(columns)
	battle.begin_attack()
	_check(battle.attack(columns, 0), "同値攻撃")
	_check(battle.board[columns].is_empty() and battle.board[0].is_empty(), "同値両者退場")
	_check(battle.discards[0].size() == 1 and battle.discards[1].size() == 1, "退場札の所有者")
	_check(battle.events.filter(func(event: Dictionary) -> bool: return event.kind == "reveal").size() == 2, "伏せ双方公開")
	battle.setup(columns, cards, cards, 3)
	battle.board[columns] = _unit("shade", 0)
	battle.board[0] = _unit("spear", 1)
	battle.reveal(columns)
	battle.begin_attack()
	_check(not battle.attack(columns, -1), "遮られた王攻撃拒否")
	_check(battle.attack(columns, 0) and battle.board[0].side == 0, "奇襲勝利と前進")
	_check(not battle.attack(0, -1), "同手番二回攻撃拒否")
	battle.setup(columns, cards, cards, 3)
	battle.board[columns] = _unit("champion", 0)
	battle.hp[1] = 5
	battle.reveal(columns)
	battle.begin_attack()
	_check(battle.attack(columns, -1) and battle.winner == 0 and battle.phase == "finished", "王撃破と決着")
	_check(not battle.end_turn(), "決着後手番変更拒否")
	battle.setup(columns, cards, cards, 3)
	battle.board[columns] = _unit("mender", 0)
	battle.hp[0] = 5
	_check(battle.reveal(columns) and battle.hp[0] == 6, "治癒公開")
	_check(not battle.reveal(columns) and battle.hp[0] == 6, "治癒一度のみ")
	battle.board[columns + 1] = _unit("blade", 0)
	_check(battle.swap_units(columns, columns + 1), "交換")
	_check(not battle.swap_units(columns, columns + 1), "交換一度のみ")
	battle.decks[1].clear()
	battle.discards[1] = ["archer"]
	battle.end_turn()
	_check(battle.hands[1].back() == "archer" and battle.discards[1].is_empty(), "捨て札再循環")
	battle.setup(columns, cards, cards, 3, 4)
	battle.board[columns] = _unit("mender", 0)
	battle.reveal(columns)
	_check(battle.hp[0] == 5, "遠征持越しの傷を回復")
	battle.hp[0] = 10
	battle.board[columns + 1] = _unit("mender", 0)
	battle.reveal(columns + 1)
	_check(battle.hp[0] == 10, "回復上限10")
	battle.board[columns + 2] = _unit("blade", 0)
	_check(not battle.swap_units(columns, columns + 2) and not battle.swapped, "非隣接交換拒否・権利維持")
	battle.begin_attack()
	_check(battle.legal_targets(columns + 2).is_empty(), "伏せ札の攻撃候補なし")
	_check(not battle.attack(columns + 2, -1) and not battle.board[columns + 2].face, "伏せ札攻撃拒否・非公開維持")
	battle.setup(columns, cards, cards, 3)
	battle.board[columns] = _unit("archer", 0)
	battle.board[0] = _unit("scout", 1)
	battle.reveal(columns)
	battle.begin_attack()
	battle.attack(columns, 0)
	_check(not battle.board[columns].is_empty() and battle.board[0].is_empty(), "射手は勝っても移動しない")
	var clash: Dictionary = battle.events.back()
	_check(clash.attacker.id == "archer" and clash.defender.id == "scout" and not clash.defender.face, "戦闘イベントに除去前の札状態を保持")
	battle.board[columns].face = false
	_check(clash.attacker.face, "戦闘イベントは盤の変更と独立")
	print("%d列：配置・移動・攻撃・伏せ・特殊能力・勝敗・再循環を確認" % columns)

func _test_cpu(columns: int) -> void:
	var cards: Array[String] = ["blade", "spear", "archer", "shade", "knight", "mender", "bulwark", "scout", "blade", "spear"]
	for seed_value: int in range(8):
		var battle: RefCounted = Battle.new()
		battle.setup(columns, cards, cards, seed_value)
		for step: int in range(200):
			if battle.winner != -1:
				break
			if battle.turn == 1:
				battle.play_enemy()
			else:
				for cell: int in range(columns, columns * 2):
					for hand_index: int in range(battle.hands[0].size()):
						if battle.deploy(hand_index, cell):
							break
				for cell: int in range(columns * 2):
					battle.reveal(cell)
				battle.begin_attack()
				for cell: int in range(columns * 2):
					var targets: Array[int] = battle.legal_targets(cell)
					if targets.has(-1):
						battle.attack(cell, -1)
					elif not targets.is_empty():
						battle.attack(cell, targets[0])
				battle.end_turn()
			_check(battle.energy >= 0 and battle.energy <= 3, "CPU資源境界")
			var total: int = 0
			for side: int in range(2):
				total += battle.hands[side].size() + battle.decks[side].size() + battle.discards[side].size()
			for unit: Dictionary in battle.board:
				if not unit.is_empty():
					total += 1
			_check(total == cards.size() * 2, "CPU対局の札保存")
		_check(battle.winner != -1, "CPU対局が決着：%d列 シード%d" % [columns, seed_value])
	print("%d列：CPUとの8対局の決着と札保存を確認" % columns)

func _test_enemy_steps(columns: int) -> void:
	var battle: RefCounted = Battle.new()
	var cards: Array[String] = ["blade", "blade", "blade", "blade"]
	battle.setup(columns, cards, cards, 20)
	_check(not battle.enemy_step(), "自手番でCPU操作拒否")
	battle.end_turn()
	var previous: int = battle.events.size()
	_check(battle.enemy_step() and battle.events.size() == previous + 1 and battle.events.back().kind == "deploy", "CPU一操作で一枚配置")
	battle.setup(columns, cards, cards, 20)
	battle.board[0] = _unit("bulwark", 1)
	battle.board[columns] = _unit("blade", 0)
	battle.board[1] = _unit("blade", 1)
	battle.end_turn()
	battle.energy = 0
	_check(battle.enemy_step() and not battle.board[0].face and battle.board[1].face, "対面のある守護札は伏せ、他の札は公開")
	_check(battle.enemy_step() and battle.phase == "attack", "公開完了後に攻撃段階")
	previous = battle.events.size()
	_check(battle.enemy_step() and battle.events.size() == previous + 1 and battle.events.back().kind == "king", "CPU一操作で王攻撃一回")
	_check(battle.enemy_step() and battle.turn == 0, "行動完了後に手番終了")
	battle.setup(columns, cards, cards, 20)
	battle.board[0] = _unit("bulwark", 1)
	battle.end_turn()
	battle.energy = 0
	_check(battle.enemy_step() and battle.board[0].face, "対面が空の守護札は公開")
	var stepped: RefCounted = Battle.new()
	battle.setup(columns, cards, cards, 21)
	stepped.setup(columns, cards, cards, 21)
	battle.end_turn()
	stepped.end_turn()
	battle.play_enemy()
	for step: int in range(40):
		if stepped.turn != 1 or stepped.winner != -1:
			break
		_check(stepped.enemy_step(), "CPU逐次操作が進む")
	_check(battle.board == stepped.board and battle.hp == stepped.hp and battle.hands == stepped.hands and battle.events == stepped.events and battle.turn == stepped.turn, "一括CPUと逐次CPUの状態・イベント一致")
