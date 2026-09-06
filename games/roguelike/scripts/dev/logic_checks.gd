extends RefCounted
## 自己検証から呼ぶ。生成と公開コマンドを通じて境界条件を確かめる。

const State = preload("res://scripts/run_state.gd")
const Dungeon = preload("res://scripts/dungeon.gd")
const Data = preload("res://scripts/game_data.gd")


static func run(check: Callable) -> void:
	_check_generation(check)
	var state: Node = State.new()
	state.save_enabled = false
	_check_commands(state, check)
	_check_items(state, check)
	_check_enemies(state, check)
	_check_finish(state, check)
	_check_records(state, check)
	state.free()


static func _check_generation(check: Callable) -> void:
	var first: RogueDungeon = Dungeon.new()
	var second: RogueDungeon = Dungeon.new()
	for seed_value: int in range(1, 41):
		for depth: int in range(1, 6):
			first.generate(seed_value, depth)
			second.generate(seed_value, depth)
			check.call(first.floor_cells == second.floor_cells, "同一seedと階で床が再現される")
			check.call(first.connected(), "全部屋と階段が連結する")
			check.call(first.rooms.size() >= 4 and first.rooms.size() <= 8, "部屋は4〜8個")
			check.call(first.entrance != first.stairs, "入口と階段が重ならない")
	first.generate(41, 1)
	var initial: Dictionary = first.explored.duplicate()
	first.update_visibility(first.stairs)
	check.call(first.visible.has(first.stairs), "階段付近の視界が更新される")
	check.call(first.explored.size() >= initial.size(), "探索済み領域が保持される")
	first.floor_cells = {Vector2i(1, 1): true, Vector2i(2, 2): true}
	check.call(not first.can_step(Vector2i(1, 1), Vector2i(2, 2)), "壁の角を斜めに抜けられない")


static func _arena(state: Node) -> void:
	state.start_run(1122)
	state.enemies.clear()
	state.ground_items.clear()
	state.dungeon.floor_cells.clear()
	state.dungeon.rooms.assign([Rect2i(1, 1, 12, 10)])
	for x: int in range(1, 13):
		for y: int in range(1, 11):
			state.dungeon.floor_cells[Vector2i(x, y)] = true
	state.player_pos = Vector2i(4, 4)
	state.dungeon.stairs = Vector2i(11, 9)
	state.dungeon.update_visibility(state.player_pos)


static func _check_commands(state: Node, check: Callable) -> void:
	_arena(state)
	check.call(state.move(Vector2i(1, 1)), "斜め移動できる")
	check.call(state.player_pos == Vector2i(5, 5) and state.turns == 1, "移動は1ターン")
	check.call(state.hunger == 99, "歩行で満腹度が減る")
	check.call(not state.move(Vector2i(2, 0)) and state.turns == 1, "2マス移動は拒否しターン不消費")
	state.hp = 40
	state.turns = 3
	state.wait_turn()
	check.call(state.hp == 41, "4ターンごとに自然回復")
	state.hunger = 0
	state.wait_turn()
	check.call(state.hp == 40, "空腹で毎ターンHP減少")
	state.player_pos = Vector2i(1, 1)
	var previous: int = state.turns
	check.call(not state.move(Vector2i.LEFT) and state.turns == previous, "壁移動はターン不消費")
	check.call(not state.descend(), "階段以外では降りられない")


static func _check_items(state: Node, check: Callable) -> void:
	_arena(state)
	state.inventory.assign(["herb", "food", "fire", "wand", "sunblade", "shield", "warp"])
	check.call(state.item_name("fire") == "朱色の巻物", "未識別巻物は仮名")
	state.hp = 10
	state.use_item(0)
	check.call(state.hp == 45 and not state.inventory.has("herb"), "回復薬を消費して回復")
	state.hunger = 20
	state.use_item(0)
	check.call(state.hunger == 80, "食料で満腹度回復")
	state.use_item(0)
	check.call(state.item_name("fire") == "烈火の巻物", "使用で識別")
	state.use_item(1)
	check.call(state.weapon == "sunblade" and state.attack_power() == 14, "武器装備で攻撃力上昇")
	state.drop_item(1)
	check.call(state.weapon == "" and state.ground_items.size() == 1, "捨てると装備解除し床へ")
	state.pickup()
	check.call(state.inventory.has("sunblade") and state.ground_items.is_empty(), "足元から拾い直せる")
	state.throw_item(state.inventory.find("sunblade"), Vector2i.RIGHT)
	check.call(not state.inventory.has("sunblade") and state.ground_items.size() == 1,
		"外れた投擲は着地点に残る")
	state.use_item(state.inventory.find("warp"))
	check.call(state.player_pos == state.dungeon.stairs, "帰路の巻物は階段へ移動")
	state.inventory.clear()
	for index: int in range(Data.PACK_LIMIT):
		state.inventory.append("food")
	state.ground_items.append({"pos": state.player_pos, "kind": "herb"})
	check.call(not state.pickup() and state.inventory.size() == Data.PACK_LIMIT, "持ち物上限を超えない")


static func _check_enemies(state: Node, check: Callable) -> void:
	_arena(state)
	state._spawn_enemy("chaser", Vector2i(5, 4))
	state.enemies[0].hp = 1
	state.xp = 15
	state.move(Vector2i.RIGHT)
	check.call(state.kills == 1 and state.level == 2, "撃破経験値でレベル上昇")
	check.call(state.player_pos == Vector2i(4, 4), "攻撃ではプレイヤーは移動しない")
	_arena(state)
	state._spawn_enemy("splitter", Vector2i(5, 4))
	state.move(Vector2i.RIGHT)
	check.call(state.enemies.size() == 2, "分裂敵は攻撃を受けると増える")
	_arena(state)
	state._spawn_enemy("sleeper", Vector2i(10, 4))
	state.wait_turn()
	check.call(state.enemies[0].pos == Vector2i(10, 4), "眠る敵は遠方では動かない")
	_arena(state)
	state._spawn_enemy("swift", Vector2i(8, 4))
	state.wait_turn()
	check.call(state.enemies[0].pos == Vector2i(6, 4), "素早い敵は2手移動")
	_arena(state)
	state._spawn_enemy("archer", Vector2i(8, 4))
	var previous_hp: int = state.hp
	state.wait_turn()
	check.call(state.hp < previous_hp and state.enemies[0].pos == Vector2i(8, 4), "射手は離れて攻撃")
	_arena(state)
	state._spawn_enemy("chaser", Vector2i(5, 4))
	state.enemies[0].hp = 100
	state.inventory.assign(["wand"])
	state.use_item(0)
	check.call(state.enemies[0].pos.x >= 7 and state.enemies[0].hp == 76, "杖は敵にダメージと吹き飛ばし")


static func _check_finish(state: Node, check: Callable) -> void:
	_arena(state)
	state.hp = 1
	state.hunger = 0
	state.wait_turn()
	check.call(state.status == "dead" and state.inventory.is_empty(), "死亡で持ち物喪失")
	check.call(not state.move(Vector2i.RIGHT), "終了後の操作は無効")
	state.start_run(1122)
	check.call(state.status == "playing" and state.hp == 55 and state.kills == 0, "再開で状態初期化")
	for depth: int in range(1, 5):
		state.player_pos = state.dungeon.stairs
		check.call(state.descend() and state.floor_number == depth + 1, "階段で次階へ")
	check.call(state.enemies.any(func(enemy: Dictionary) -> bool:
		return enemy.kind == "boss"), "最深階にボスが現れる")
	state.player_pos = state.dungeon.stairs
	check.call(state.escape() and state.status == "won", "最深階出口から脱出クリア")
	_arena(state)
	state._spawn_enemy("boss", Vector2i(5, 4))
	state.enemies[0].hp = 1
	state.move(Vector2i.RIGHT)
	check.call(state.status == "won" and state.kills == 1, "ボス撃破でもクリア")


static func _check_records(state: Node, check: Callable) -> void:
	check.call(state.record_from_value({"best_floor": 3.0}) == 3, "JSONの数値を解釈")
	check.call(state.record_from_value({"best_floor": 99}) == 5, "保存階の上限を補正")
	check.call(state.record_from_value({"best_floor": -1}) == 0, "負の保存階を補正")
	check.call(state.record_from_value({"best_floor": "5"}) == 0, "不正型の保存値は拒否")
	check.call(state.record_from_value([]) == 0, "破損した保存構造を拒否")
