extends RefCounted
## 描画を使わず、選択・戦闘・保存の正常系と異常系を検証する。

const State: Script = preload("res://scripts/game_state.gd")
const Catalog: Script = preload("res://scripts/catalog.gd")
const Story: Script = preload("res://scripts/story.gd")


static func run(check: Callable) -> void:
	_check_catalog(check)
	_check_routes(check)
	_check_tutorial(check)
	_check_collection(check)
	_check_darkness(check)
	_check_police(check)
	_check_battle(check)
	_check_story_endings(check)
	_check_complete_run(check)
	_check_save(check)
	_check_archive(check)


static func _game(seed_value: int = 61) -> Node:
	var game: Node = State.new()
	game.save_path = ""
	game.new_run(seed_value)
	game.skip_tutorial()
	game.begin_journey()
	return game


static func _event(game: Node, kind: String, spirit_id: String = "child") -> void:
	game.mode = "event"
	game.current_node = {"kind": kind, "spirit": spirit_id, "story": 0}


static func _branch_for(game: Node, kind: String) -> int:
	for branch: int in range(game.route[game.depth].size()):
		if game.route[game.depth][branch].kind == kind:
			return branch
	return -1


static func _check_catalog(check: Callable) -> void:
	check.call(Catalog.SPIRITS.size() >= 12, "霊は12種以上")
	var rarities: Dictionary = {}
	var types: Dictionary = {}
	for id: String in Catalog.SPIRITS:
		var definition: Dictionary = Catalog.SPIRITS[id]
		rarities[definition.rarity] = true
		types[definition.type] = true
		check.call(Catalog.TYPES.has(definition.type), "霊の属性定義: " + id)
		check.call(Catalog.RARITIES.has(definition.rarity), "霊のレア度定義: " + id)
		check.call(Catalog.integer_between(definition.hp, 40, 160), "HPの範囲: " + id)
		check.call(Catalog.integer_between(definition.attack, 8, 35), "攻撃の範囲: " + id)
		check.call(Catalog.integer_between(definition.speed, 5, 35), "速さの範囲: " + id)
		check.call(definition.moves.size() == 2, "各霊は技を2つ持つ: " + id)
		check.call(Catalog.valid_spirit(Catalog.create_spirit(id, 1)), "生成個体の整合: " + id)
		for move_id: String in definition.moves:
			check.call(Catalog.MOVES.has(move_id), "技の参照先が存在する: " + id)
		check.call(Catalog.MOVES[definition.moves[0]].cost == 0, "通常技は霊気不要: " + id)
		check.call(Catalog.MOVES[definition.moves[1]].cost > 0, "固有技は霊気を消費: " + id)
	check.call(rarities.size() == 3 and types.size() == 3, "3属性・3レア度が揃う")
	for first: String in Catalog.TYPES:
		for second: String in Catalog.TYPES:
			var expected: float = 1.0 if first == second \
				else (2.0 if Catalog.ADVANTAGE[first] == second else 0.5)
			check.call(Catalog.matchup(first, second) == expected, "相性9通り: " + first + second)
	var child: Dictionary = Catalog.create_spirit("child", 1)
	var warrior: Dictionary = Catalog.create_spirit("warrior", 2)
	check.call(Catalog.damage(child, warrior, 0) == 24, "哀から怒の通常攻撃は24")
	check.call(Catalog.damage(child, warrior, 0, 30) == 30, "闇30で攻撃が25%増す")
	check.call(Catalog.create_spirit("unknown", 1).is_empty(), "未知の霊を生成しない")


static func _check_routes(check: Callable) -> void:
	var expected: Dictionary = {"grave": 3, "story": 5, "battle": 3, "living": 4,
		"rest": 4, "police": 3, "boss": 1}
	for seed_value: int in range(1, 65):
		var route: Array[Array] = State.generate_route(seed_value)
		check.call(route == State.generate_route(seed_value), "同じシードは同じ道: %d" % seed_value)
		check.call(route.size() == 12, "道は12層")
		var counts: Dictionary = {}
		var stories: Dictionary = {}
		for depth: int in route.size():
			check.call(route[depth].size() == (1 if depth == 11 else 2), "各辻の2分岐と最後の門")
			for node: Dictionary in route[depth]:
				counts[node.kind] = int(counts.get(node.kind, 0)) + 1
				if node.kind == "story":
					stories[node.story] = true
				if node.kind in ["grave", "living"]:
					var rarity: int = int(Catalog.spirit(node.spirit).rarity)
					check.call(rarity == 3 if node.kind == "living" else rarity < 3,
						"大霊は生物ノードでのみ獲得できる")
				check.call((node.kind == "boss") == (depth == 11), "全枝が12層目のボスへ到達可能")
		check.call(counts == expected, "ノード種の出現数を制約内に維持")
		check.call(stories.size() == 5, "一本道で出会える物語が5つあり重複しない")
	check.call(State.generate_route(61) != State.generate_route(62), "異なるシードで道が変わる")
	var game: Node = _game()
	check.call(not game.enter_node(-1) and not game.enter_node(2), "範囲外の枝を選べない")
	check.call(game.enter_node(0) and not game.enter_node(0), "選択済みノードを二重に消費しない")
	game.free()


static func _check_tutorial(check: Callable) -> void:
	var game: Node = State.new()
	game.save_path = ""
	game.new_run(61)
	check.call(game.tutorial_step == State.TUTORIAL_GRAVE,
		"新規ランは墓で霊を迎えるチュートリアルから始まる")
	game.begin_journey()
	var grave_branch: int = _branch_for(game, "grave")
	var other_branch: int = 1 - grave_branch
	check.call(game.tutorial_required_branch() == grave_branch,
		"最初の区画では生成済みルートの墓入口へ誘導する")
	check.call(not game.enter_node(other_branch) and game.mode == "map" and game.depth == 0
		and game.route_choices.is_empty() and game.last_message.contains("墓"),
		"最初の区画で墓以外を選ぶと理由を示して進行を消費しない")
	check.call(game.enter_node(grave_branch) and game.mode == "event",
		"誘導された墓へ入れる")
	var party_before: int = game.party.size()
	check.call(not game.choose_event(1) and game.mode == "event"
		and game.party.size() == party_before and game.darkness == 0
		and game.last_message.contains("まず墓"),
		"墓では霊を迎える以外の選択を理由付きで拒否する")
	check.call(game.choose_event(0) and game.mode == "map" and game.depth == 1
		and game.party.size() == party_before + 1
		and game.tutorial_step == State.TUTORIAL_BATTLE,
		"墓の霊を迎えると戦闘の案内へ進む")
	var battle_branch: int = _branch_for(game, "battle")
	other_branch = 1 - battle_branch
	check.call(game.tutorial_required_branch() == battle_branch,
		"二つ目の区画では生成済みルートの戦闘入口へ誘導する")
	check.call(not game.enter_node(other_branch) and game.mode == "map" and game.depth == 1
		and game.route_choices.size() == 1 and game.last_message.contains("迎えた霊"),
		"二つ目の区画で戦闘以外を選ぶと理由を示して進行を消費しない")
	check.call(game.enter_node(battle_branch) and game.mode == "battle",
		"誘導された戦闘へ入れる")
	game.enemies[0].hp = 1
	game.resolve_turn([0, 0, 0])
	check.call(game.mode == "map" and game.depth == 2
		and game.tutorial_step == State.TUTORIAL_COMPLETE,
		"最初の戦闘に勝つとチュートリアルが完了する")
	game.free()

	var skipped: Node = State.new()
	skipped.save_path = ""
	skipped.new_run(62)
	skipped.begin_journey()
	grave_branch = _branch_for(skipped, "grave")
	skipped.enter_node(grave_branch)
	check.call(skipped.skip_tutorial() and skipped.tutorial_step == State.TUTORIAL_COMPLETE,
		"イベント途中でもチュートリアルを飛ばせる")
	var skipped_snapshot: Dictionary = skipped._save_data().duplicate(true)
	check.call(skipped.skip_tutorial() and skipped._save_data() == skipped_snapshot,
		"完了済みチュートリアルのスキップは冪等")
	check.call(skipped.choose_event(1) and skipped.mode == "map" and skipped.depth == 1,
		"スキップ後はチュートリアルで拒否していた選択も行える")
	skipped.free()


static func _check_collection(check: Callable) -> void:
	var game: Node = _game()
	_event(game, "grave", "doll")
	check.call(game.choose_event(0), "墓を荒らせる")
	check.call(game.party.size() == 4 and game.party[3].species == "doll", "4体目は控えに入る")
	check.call(game.darkness == 12 and "doll" in game.discovered, "墓で闇と図鑑を更新")
	check.call(not game.choose_event(0), "同じ墓で再獲得できない")
	check.call(game.swap_party(0, 3) and game.party[0].species == "doll", "控えから前衛へ交換")
	check.call(not game.swap_party(0, 2), "前衛同士を控えとして指定できない")
	_event(game, "living", "bride")
	game.choose_event(0)
	check.call(game.party.back().species == "bride" and game.darkness == 40,
		"生物ノードの表示された大霊を確実に獲得し闇28増加")
	game.party[0].hp = 1
	game.ether = 1
	_event(game, "rest")
	game.choose_event(0)
	check.call(game.darkness == 28 and game.party[0].hp == 49 and game.ether == 6,
		"休息は闇12減少・HP48・霊気5回復")
	game.free()


static func _check_darkness(check: Callable) -> void:
	var game: Node = _game()
	for row: Array in [[0, 0], [29, 0], [30, 1], [59, 1], [60, 2], [79, 2], [80, 3], [99, 3]]:
		game.darkness = row[0]
		check.call(game.darkness_stage() == row[1], "闇段階の境界 %d" % row[0])
	game.darkness = 90
	_event(game, "grave", "fox")
	game.choose_event(0)
	check.call(game.darkness == 100 and game.mode == "result" and game.ending == "darkness",
		"闇100は上限で止まり、闇堕ちの結果へ遷移")
	game.free()


static func _check_police(check: Callable) -> void:
	var game: Node = _game()
	game.ether = 0
	_event(game, "police")
	game.choose_event(0)
	check.call(game.party.size() == 3 and game.ether == 0 and game.relics == 1,
		"闇0の罰則は霊を奪わず霊気を負数にしない")
	game.darkness = 30
	_event(game, "police")
	game.choose_event(0)
	check.call(game.party.size() == 2, "闇30以上で霊1体没収")
	game.darkness = 80
	_event(game, "police")
	game.choose_event(0)
	check.call(game.party.is_empty() and game.mode == "result" and game.ending == "arrest",
		"闇80の最大罰則で残り2体を失い逮捕")
	game.new_run(61)
	game.darkness = 40
	var low_chance: float = game.escape_chance()
	game.darkness = 80
	check.call(game.escape_chance() < low_chance, "闇が高いほど逃走成功率は下がる")
	game.party.assign([Catalog.create_spirit("crow", 1)])
	var fast_chance: float = game.escape_chance()
	game.party.assign([Catalog.create_spirit("bell", 1)])
	check.call(game.escape_chance() < fast_chance, "前衛が速いほど逃走成功率が上がる")
	for success: bool in [true, false]:
		game.new_run(61)
		game.darkness = 40
		_event(game, "police")
		_seed_escape(game, success)
		game.choose_event(1)
		check.call(game.darkness == (32 if success else 40), "逃走成功時だけ闇8減少")
		check.call(game.party.size() == (3 if success else 2), "逃走失敗時は罰則で1体没収")
	game.free()


static func _seed_escape(game: Node, success: bool) -> void:
	for seed_value: int in 1000:
		game.rng.seed = seed_value
		var actual: bool = game.rng.randf() < game.escape_chance()
		if actual == success:
			game.rng.seed = seed_value
			return


static func _check_battle(check: Callable) -> void:
	var game: Node = _game()
	_event(game, "battle", "child")
	game._start_battle("battle")
	game.enemies[0].hp = 1
	var initial_hp: int = game.party[0].hp
	var events: Array[Dictionary] = game.resolve_turn([0, 0, 0])
	check.call(events[0].actor_side == "party" and events[0].actor_uid == game.party[0].uid,
		"速さ順に行動し、同速は味方を優先")
	check.call(game.mode == "map" and game.party[0].hp == initial_hp, "先に倒した敵は反撃しない")
	_event(game, "battle", "moth")
	game._start_battle("battle")
	game.party.assign([Catalog.create_spirit("warrior", 1)])
	game.party[0].hp = 1
	events = game.resolve_turn([0])
	check.call(events[0].actor_side == "enemy", "速い敵は味方より先に攻撃する")
	check.call(game.party.is_empty() and game.ending == "lost", "最後の霊を失うと敗北")
	check.call(game.enemies[0].hp == Catalog.spirit("moth").hp, "倒れた味方は行動しない")
	game.new_run(61)
	_event(game, "battle", "monk")
	game._start_battle("battle")
	game.ether = 0
	var old_state: int = game.rng.state
	check.call(game.resolve_turn([1, 1, 1]).is_empty() and game.rng.state == old_state,
		"霊気不足はターンも乱数も消費しない")
	game.ether = 9
	game.enemies[0].hp = int(Catalog.spirit("monk").hp)
	game.resolve_turn([1, 0, 0])
	check.call(game.ether == 9, "固有技の霊気2を支払いターン終了時に2回復")
	game.new_run(61)
	_event(game, "police")
	game.choose_event(2)
	game.enemies[0].hp = 1
	game.resolve_turn([0, 0, 0])
	check.call(game.mode == "map" and game.darkness == 28, "警察戦の勝利で闇28増加")
	_event(game, "police")
	game.choose_event(2)
	game.party.assign([Catalog.create_spirit("bell", 1)])
	game.party[0].hp = 1
	game.resolve_turn([0])
	check.call(game.mode == "result" and game.ending == "arrest", "警察戦敗北は逮捕の結末")
	_check_reserves_and_wild(game, check)
	_check_invalid_commands(game, check)
	game.free()


static func _check_reserves_and_wild(game: Node, check: Callable) -> void:
	game.new_run(61)
	game.party.assign([Catalog.create_spirit("bell", 1), Catalog.create_spirit("bell", 2),
		Catalog.create_spirit("bell", 3), Catalog.create_spirit("crow", 4)])
	for unit: Dictionary in game.party.slice(0, 3):
		unit.hp = 1
	_event(game, "battle", "moth")
	game._start_battle("battle")
	var events: Array[Dictionary] = game.resolve_turn([0, 0, 0])
	check.call(game.party.size() == 3 and game.party[2].species == "crow", "消滅した前衛へ控えが繰り上がる")
	var reserve_attacked: bool = false
	var promoted: Dictionary = {}
	var previous_kind: String = ""
	for event: Dictionary in events:
		if event.kind == "attack" and event.actor_side == "party" and int(event.actor_uid) == 4:
			reserve_attacked = true
		if event.kind == "promoted":
			promoted = event.unit
			check.call(previous_kind == "lost", "控えの昇格イベントは消滅の直後に届く")
		previous_kind = event.kind
	check.call(not reserve_attacked, "交代直後の控えは同ターンに追加行動しない")
	check.call(promoted.get("uid") == 4 and promoted.get("species") == "crow",
		"表示側へ昇格した控えの個体とHPを渡す")
	game.party[2].hp = 1
	check.call(promoted.get("hp") == Catalog.spirit("crow").hp,
		"昇格時のHPは後続のダメージから独立したスナップショット")
	var wild_seen: bool = false
	for seed_value: int in range(1, 50):
		game.new_run(seed_value)
		game.darkness = 60
		_event(game, "battle", "monk")
		game._start_battle("battle")
		events = game.resolve_turn([1, 1, 1])
		for event: Dictionary in events:
			wild_seen = wild_seen or event.kind == "wild"
	check.call(wild_seen, "闇60以上で命令無視の暴走が発生する")
	game.new_run(61)
	game.darkness = 99
	_event(game, "police")
	game.choose_event(2)
	for enemy: Dictionary in game.enemies:
		enemy.hp = 1
	game.resolve_turn([0, 0, 0])
	check.call(game.mode == "result" and game.ending == "darkness" and game.darkness == 100,
		"警察戦勝利の闇増加で100に届いた場合は地図に戻らず闇堕ち")


static func _check_invalid_commands(game: Node, check: Callable) -> void:
	game.new_run(61)
	_event(game, "battle", "monk")
	game._start_battle("battle")
	var before: Dictionary = game._save_data().duplicate(true)
	for commands: Array in [[], [2, 0, 0], [1.5, 0, 0], ["1", 0, 0], [true, 0, 0]]:
		check.call(game.resolve_turn(commands).is_empty(), "不正な命令は空の結果を返す")
		check.call(game.party == before.party and game.enemies == before.enemies
			and game.ether == before.ether and game.turn == before.turn
			and str(game.rng.state) == before.rng_state, "不正命令でHP・霊気・ターン・乱数が変化しない")
	for target: int in [-1, 2]:
		check.call(game.resolve_turn([0, 0, 0], target).is_empty(), "範囲外の攻撃対象を拒否")
	check.call(game.ether == before.ether and game.turn == before.turn,
		"対象指定の誤りでターンを消費しない")


static func _check_story_endings(check: Callable) -> void:
	check.call(Story.EVENTS.size() >= 5 and Story.ENDINGS.size() >= 3, "物語5つ以上・結末3つ以上")
	var game: Node = _game()
	for story_index: int in Story.EVENTS.size():
		for choice_index: int in [0, 1]:
			game.new_run(61)
			game.darkness = 30
			_event(game, "story")
			game.current_node.story = story_index
			check.call(game.choose_event(choice_index), "物語の全選択肢を選べる")
			check.call(game.darkness < 30 if choice_index == 0 else game.darkness > 30,
				"善良な選択は闇を減らし、非道な選択は闇を増す")
	for final_darkness: int in [20, 70]:
		game.new_run(61)
		game.depth = 11
		game.darkness = final_darkness
		game._start_battle("boss")
		game.enemies[0].hp = 1
		game.resolve_turn([0, 0, 0])
		check.call(game.mode == "result" and game.depth == 12, "ボス撃破で12層到達の結果")
		check.call(game.ending == ("saved" if final_darkness < 60 else "scarred"), "救済と傷跡の結末分岐")
	game.new_run(61)
	game.relics = 0
	_event(game, "story")
	game.current_node.story = 1
	check.call(not game.choose_event(0) and game.mode == "event" and game.darkness == 0,
		"持っていないお守りを物語で渡すことはできない")
	game.to_title()
	check.call(game.mode == "title", "結果からタイトルへ戻る")
	game.free()


static func _check_save(check: Callable) -> void:
	var game: Node = _game()
	var loaded: Node = _game(62)
	var path: String = "res://tmp/logic-selfcheck.json"
	game.save_path = path
	check.call(game.save_game(), "ラン進行を保存できる")
	check.call(loaded.load_game(path), "タイトルからランを再開できる")
	check.call(loaded.route == game.route and loaded.party == game.party, "シードと霊の個体を復元")
	check.call(loaded.rng.state == game.rng.state, "乱数の64bit状態を精度損失なく復元")
	check.call(loaded.discovered == game.discovered, "図鑑を復元")
	check.call(loaded.tutorial_step == game.tutorial_step, "チュートリアル進行を復元")
	game.enter_node(0)
	check.call(game.save_game() and loaded.load_game(path)
		and loaded.current_node == game.current_node,
		"ノードイベントの途中で保存し、同じ選択肢から再開できる")
	game.choose_event(1)
	var battle_branch: int = 0 if game.route[1][0].kind == "battle" else 1
	game.enter_node(battle_branch)
	game.resolve_turn([0, 0, 0])
	check.call(game.save_game() and loaded.load_game(path), "戦闘途中でも保存再開できる")
	check.call(loaded.enemies == game.enemies and loaded.ether == game.ether, "敵HP・霊気を復元")
	if game.mode == "battle":
		check.call(game.resolve_turn([0, 0, 0]) == loaded.resolve_turn([0, 0, 0]),
			"再開後の次ターンの結果が保存前と完全に一致")
	var valid: Dictionary = game._save_data().duplicate(true)
	check.call(State._valid_save(valid), "自身の保存データは妥当")
	var legacy: Dictionary = valid.duplicate(true)
	legacy.version = 1
	legacy.erase("tutorial_step")
	check.call(State._valid_save(legacy), "version 1 の保存データを引き続き受け付ける")
	var legacy_file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy))
	legacy_file.close()
	loaded.tutorial_step = State.TUTORIAL_GRAVE
	check.call(loaded.load_game(path) and loaded.tutorial_step == State.TUTORIAL_COMPLETE,
		"version 1 の保存は案内済みとして安全に再開する")
	_check_broken_saves(valid, check)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{破損したJSON")
	file.close()
	var before: Array = loaded.party.duplicate(true)
	check.call(not loaded.load_game(path) and loaded.party == before, "壊れた保存は現在の状態を変更しない")
	game.save_path = ""
	game.free()
	loaded.free()


static func _check_complete_run(check: Callable) -> void:
	var game: Node = _game(61)
	var decisions: int = 0
	var priority: Dictionary = {"boss": 10, "rest": 9, "story": 8,
		"police": 7, "battle": 6, "grave": 3, "living": 1}
	while game.mode != "result" and decisions < 150:
		decisions += 1
		if game.mode == "map":
			var branch: int = 0
			for index: int in game.route[game.depth].size():
				if priority[game.route[game.depth][index].kind] > priority[game.route[game.depth][branch].kind]:
					branch = index
			game.enter_node(branch)
		elif game.mode == "event":
			game.choose_event(0)
		elif game.mode == "battle":
			var commands: Array[int] = []
			var available: int = game.ether
			for unit: Dictionary in game.party.slice(0, 3):
				var cost: int = Catalog.MOVES[Catalog.spirit(unit.species).moves[1]].cost
				commands.append(1 if available >= cost else 0)
				if available >= cost:
					available -= cost
			game.resolve_turn(commands)
	check.call(game.mode == "result" and game.ending == "saved" and game.depth == 12,
		"通常初期値と実際の選択だけで全12層を進み、ボスを倒して救済へ到達")
	game.free()


static func _check_broken_saves(valid: Dictionary, check: Callable) -> void:
	for alteration: Array in [["version", 3], ["mode", "unknown"], ["run_seed", 0],
		["depth", 1.5], ["depth", 13], ["darkness", 101], ["ether", -1], ["relics", "3"],
		["party", null], ["collected", ["unknown"]], ["route_choices", [3]],
		["rng_state", "1.5"], ["rng_state", "9223372036854775808"]]:
		var malformed: Dictionary = valid.duplicate(true)
		malformed[alteration[0]] = alteration[1]
		check.call(not State._valid_save(malformed), "破損した保存値を拒否: " + str(alteration[0]))
	for bad_hp: Variant in [0, -1, 9999, 1.5, "64"]:
		var malformed: Dictionary = valid.duplicate(true)
		malformed.party[0].hp = bad_hp
		check.call(not State._valid_save(malformed), "範囲外・非整数のHPを拒否")
	var duplicate: Dictionary = valid.duplicate(true)
	duplicate.party.append(duplicate.party[0].duplicate(true))
	check.call(not State._valid_save(duplicate), "個体IDの重複を拒否")
	var unknown: Dictionary = valid.duplicate(true)
	unknown.extra = true
	check.call(not State._valid_save(unknown), "未知の保存キーを拒否")
	var missing_tutorial: Dictionary = valid.duplicate(true)
	missing_tutorial.erase("tutorial_step")
	check.call(not State._valid_save(missing_tutorial), "version 2 はチュートリアル進行の欠落を拒否")
	var unknown_tutorial: Dictionary = valid.duplicate(true)
	unknown_tutorial.tutorial_step = "unknown"
	check.call(not State._valid_save(unknown_tutorial), "未知のチュートリアル進行を拒否")


static func _check_archive(check: Callable) -> void:
	var game: Node = _game(61)
	var desired: Array[String] = ["grave", "living", "police", "grave", "living", "story", "grave"]
	for kind: String in desired:
		var branch: int = 0 if game.route[game.depth][0].kind == kind else 1
		game.enter_node(branch)
		game.choose_event(1 if kind == "story" else 0)
	check.call(game.ending == "darkness", "通常操作の墓・生物取得で闇堕ちに到達")
	var path: String = "res://tmp/archive-selfcheck.json"
	check.call(game.save_game(path), "結果と図鑑を保存できる")
	var restarted: Node = State.new()
	restarted.save_path = path
	restarted._ready()
	check.call(restarted.mode == "title" and restarted.discovered == game.discovered,
		"アプリ再起動時はタイトルを維持し、過去ランの発見した霊を復元")
	check.call(not restarted.has_save() and not restarted.load_game(),
		"終了したランを続きから再開させない")
	restarted.new_run(62)
	for id: String in game.discovered:
		check.call(id in restarted.discovered, "新しいランでも既存の図鑑を失わない: " + id)
	game.free()
	restarted.free()
