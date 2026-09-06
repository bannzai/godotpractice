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
	_check_playthrough(state, check)
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
	check.call(not first.line_of_sight(Vector2i(1, 1), Vector2i(2, 2)),
		"壁の角越しに視認・射撃できない")


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


static func _check_playthrough(state: Node, check: Callable) -> void:
	for seed_value: int in [1118, 1110]:
		var result: Dictionary = play_run(state, seed_value)
		print("通常初期値からの探索: %s" % JSON.stringify(result))
		check.call(result.status == "won" and result.floor == 5,
			"通常初期値・公開操作だけで最深階をクリアできる")
		check.call(int(result.kills) > 0 and int(result.items_used) > 0,
			"通常探索で戦闘と道具使用が成立する")
		check.call(str(result.cause).contains("生還" if seed_value == 1118 else "番人"),
			"通常探索で脱出・番人撃破の両方のクリアが成立する")


## 再現用botも公開操作のみを使う。探索を進めるため呼び出しごとに状態が変わる。
static func play_run(state: Node, seed_value: int) -> Dictionary:
	state.start_run(seed_value)
	var items_used: int = 0
	for command: int in range(1500):
		if state.status != "playing":
			break
		if state.player_pos == state.dungeon.stairs:
			state.descend()
			continue
		if _bot_use_item(state):
			items_used += 1
			continue
		var target: Vector2i = state.dungeon.stairs
		for item: Dictionary in state.ground_items:
			var useful: bool = (item.kind == "food" and state.hunger < 40) or (
				item.kind == "herb" and state.hp < 35) or item.kind in ["sunblade", "ironshield"]
			if useful and state.dungeon.explored.has(item.pos):
				target = item.pos
				break
		var direction: Vector2i = _route_direction(state, target)
		if direction == Vector2i.ZERO or not state.move(direction):
			break
	return {"seed": seed_value, "status": state.status, "floor": state.floor_number,
		"turns": state.turns, "hp": state.hp, "kills": state.kills,
		"items_used": items_used, "cause": state.result_cause}


static func _bot_use_item(state: Node) -> bool:
	for kind: String in ["herb", "food", "sunblade", "ironshield", "warp", "fire", "wand"]:
		var index: int = state.inventory.find(kind)
		if index < 0:
			continue
		var use: bool = false
		match kind:
			"herb":
				use = state.hp <= state.max_hp - 30
			"food":
				use = state.hunger <= 40
			"sunblade":
				use = state.weapon != kind
			"ironshield":
				use = state.shield != kind
			"warp":
				use = true
			"fire":
				use = state.enemies.any(func(enemy: Dictionary) -> bool:
					return state.dungeon.same_room(state.player_pos, enemy.pos))
			"wand":
				use = state.enemy_at(state.player_pos + state.facing) >= 0
		if use:
			return state.use_item(index)
	return false


static func _route_direction(state: Node, destination: Vector2i) -> Vector2i:
	var pending: Array[Vector2i] = [state.player_pos]
	var parent: Dictionary = {state.player_pos: state.player_pos}
	var offset: int = 0
	while offset < pending.size():
		var cell: Vector2i = pending[offset]
		offset += 1
		if cell == destination:
			break
		for direction: Vector2i in Dungeon.DIRECTIONS:
			var next: Vector2i = cell + direction
			if state.dungeon.can_step(cell, next) and not parent.has(next):
				parent[next] = cell
				pending.append(next)
	if not parent.has(destination):
		return Vector2i.ZERO
	var step: Vector2i = destination
	while parent[step] != state.player_pos:
		step = parent[step]
	return step - Vector2i(state.player_pos)
