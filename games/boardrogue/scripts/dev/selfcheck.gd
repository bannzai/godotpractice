extends SceneTree
## シーンとアセットクレジットの検証。実行方法は Makefile の selfcheck target を参照。
## release ビルドで assert が消えるため、明示的な判定と exit code で結果を返す。

const Catalog = preload("res://scripts/core/catalog.gd")
const Battle = preload("res://scripts/core/battle.gd")
const RunState = preload("res://scripts/core/run_state.gd")

var failed: bool = false
var checks: int = 0


func _initialize() -> void:
	if "--logic-only" in OS.get_cmdline_user_args():
		print("検証範囲: 盤面・ランロジックのみ")
	else:
		_check_scenes("res://scenes")
		_check_assets_credited()
	_check_catalog()
	_check_rules()
	_check_effects()
	_check_route()
	_check_save()
	_check_ai()
	_check_run()

	if failed:
		quit(1)
	else:
		print("selfcheck 検証数: %d" % checks)
		print("selfcheck OK")
		quit(0)


func _check(cond: bool, label: String) -> void:
	checks += 1
	if not cond:
		push_error("selfcheck FAIL: " + label)
		failed = true


## tree には入れず (autoload に依存する _ready を走らせず) インスタンス化だけを確認して free する
func _check_scenes(path: String) -> void:
	var directory: DirAccess = DirAccess.open(path)
	_check(directory != null, "シーン: %s を走査できる" % path)
	if directory == null:
		return
	for filename: String in directory.get_files():
		if filename.get_extension() != "tscn":
			continue
		var scene_path: String = path.path_join(filename)
		var scene: PackedScene = load(scene_path)
		_check(scene != null, "シーン: %s をロードできる" % scene_path)
		if scene == null:
			continue
		var instance: Node = scene.instantiate()
		_check(instance != null, "シーン: %s をインスタンス化できる" % scene_path)
		if instance != null:
			instance.free()
	for subdirectory: String in directory.get_directories():
		_check_scenes(path.path_join(subdirectory))


## selfcheck はソースツリーで実行する前提。エクスポート後の .import 実体だけの構成は対象外。
func _check_assets_credited() -> void:
	var credits: String = FileAccess.get_file_as_string("res://assets/CREDITS.md")
	_check(not credits.is_empty(), "CREDITS: assets/CREDITS.md を読み取れる")
	_check_asset_directory("res://assets", credits)


func _check_asset_directory(path: String, credits: String) -> void:
	var directory: DirAccess = DirAccess.open(path)
	_check(directory != null, "CREDITS: %s を走査できる" % path)
	if directory == null:
		return
	directory.include_hidden = true
	for filename: String in directory.get_files():
		if filename in ["CREDITS.md", ".gdignore"] or filename.get_extension() in ["import", "uid"]:
			continue
		_check(
			credits.contains(filename),
			"CREDITS: %s が assets/CREDITS.md に記録されていない" % path.path_join(filename)
		)
	for subdirectory: String in directory.get_directories():
		_check_asset_directory(path.path_join(subdirectory), credits)


func _check_catalog() -> void:
	_check(Catalog.CARDS.size() >= 12, "札12種類")
	var effects: Array[String] = ["anchor", "duelist", "infiltrate", "ranged", "reveal",
		"revenge", "guard", "siege", "heal", "aura", "insight", "terror"]
	for card_id: String in Catalog.CARDS:
		var card: Dictionary = Catalog.CARDS[card_id]
		_check(card.atk >= -2 and card.atk <= 5, card_id + " 攻撃力範囲")
		_check(card.rarity in [0, 1, 2] and card.effect in effects, card_id + " 効果とレア度")
		_check(not card.name.is_empty() and not card.text.is_empty(), card_id + " 説明")
	for opponent: String in Catalog.ENEMIES:
		_check(Catalog.valid_cards(Catalog.ENEMIES[opponent].deck, 8, 8), "敵デッキ整合")
		_check(Catalog.ENEMIES[opponent].lines.size() >= 5, "敵台詞5種")
	_check(Catalog.STARTER.size() == 8, "開始デッキ8枚")


func _empty_battle() -> BoardBattle:
	var battle: BoardBattle = Battle.new()
	battle.setup(Catalog.STARTER, "scout", 3, 17)
	battle.hands = [[], []]
	battle.decks = [[], []]
	battle.discards = [[], []]
	return battle


func _unit(battle: BoardBattle, card_id: String, side: int, pos: Vector2i,
		face: bool = true) -> Dictionary:
	var unit: Dictionary = {"uid": battle.next_uid, "card": card_id, "side": side,
		"x": pos.x, "y": pos.y, "face": face, "moved": false,
		"attacked": false, "effect_used": false}
	battle.next_uid += 1
	battle.units.append(unit)
	return unit


func _check_rules() -> void:
	var battle: BoardBattle = Battle.new()
	battle.setup(Catalog.STARTER, "scout", 3, 17)
	_check(battle.hands[0].size() == 3 and battle.decks[0].size() == 5, "先攻ドローなし")
	var before: Dictionary = battle.snapshot()
	_check(not battle.setup(["unknown"], "scout", 3, 17), "未知の開始札を拒否")
	_check(not battle.setup(Catalog.STARTER, "unknown", 3, 17), "未知の相手を拒否")
	_check(not battle.setup(Catalog.STARTER, "scout", 4, 17), "不正盤面幅を拒否")
	_check(battle.snapshot() == before, "不正な再初期化で現局を壊さない")
	_check(not battle.deploy(0, Vector2i(0, 1)).ok, "敵陣への潜伏禁止")
	_check(not battle.deploy(-1, Vector2i(0, 2)).ok, "手札負インデックス拒否")
	_check(not battle.attack(1).ok and battle.snapshot() == before, "無効入力は状態不変")
	var event: Dictionary = battle.deploy(0, Vector2i(1, 2))
	_check(event.ok and not battle.unit_by_id(event.uid).face, "裏向き潜伏")
	_check(not battle.move_unit(event.uid, Vector2i(1, 1)).ok, "潜伏中は移動できない")
	_check(battle.reveal(event.uid).ok, "登場")
	_check(not battle.move_unit(event.uid, Vector2i(0, 1)).ok, "斜め移動禁止")
	_check(battle.move_unit(event.uid, Vector2i(1, 1)).ok, "隣接空きへ移動")
	_check(not battle.move_unit(event.uid, Vector2i(1, 0)).ok, "移動は1ターン1回")
	_check(battle.begin_battle().ok and not battle.can_attack(event.uid), "移動後は攻撃不可")
	_check(not battle.deploy(0, Vector2i(0, 2)).ok, "バトル中は潜伏禁止")
	_check(battle.end_turn().ok and battle.hands[1].size() == 4, "後攻初回ドロー")
	battle = _empty_battle()
	var ally: Dictionary = _unit(battle, "blade", 0, Vector2i(1, 2))
	var friend: Dictionary = _unit(battle, "shield", 0, Vector2i(0, 2), false)
	event = battle.swap_units(ally.uid, friend.uid)
	_check(event.ok, "表裏を問わず配置換え")
	_check(event.from == Vector2i(1, 2) and event.to == Vector2i(0, 2), "配置換えの主札の移動前後")
	_check(event.other_from == Vector2i(0, 2) and event.other_to == Vector2i(1, 2),
		"配置換えの相手札の移動前後")
	_check(not battle.swap_units(ally.uid, friend.uid).ok, "配置換えは1組のみ")
	battle = _empty_battle()
	ally = _unit(battle, "reed", 0, Vector2i(1, 1))
	var enemy: Dictionary = _unit(battle, "reed", 1, Vector2i(1, 0), false)
	battle.begin_battle()
	event = battle.attack(ally.uid, enemy.uid)
	_check(event.ok and battle.units.is_empty(), "同攻撃力は相討ち")
	_check(battle.discards[0] == ["reed"] and battle.discards[1] == ["reed"], "相討ち両捨て場")
	battle = _empty_battle()
	ally = _unit(battle, "bow", 0, Vector2i(1, 2))
	enemy = _unit(battle, "blade", 1, Vector2i(1, 1))
	battle.begin_battle()
	event = battle.attack(ally.uid, enemy.uid)
	_check(Battle.position(enemy) == Vector2i(1, 2), "守備側勝利も強制移動")
	_check(event.card == "bow" and event.target_card == "blade" and not event.target_was_hidden,
		"返り討ちでも攻撃札と対象札の種類を演出へ渡す")
	_check(event.king_damage_side == -1, "王の損害がない攻撃を区別")
	battle = _empty_battle()
	ally = _unit(battle, "blade", 0, Vector2i(1, 0))
	battle.begin_battle()
	event = battle.attack(ally.uid)
	_check(event.damage == 3 and battle.hp[1] == 7, "王への直接攻撃")
	_check(event.king_damage_side == 1 and event.target_card.is_empty()
		and not event.target_was_hidden, "王への直接攻撃の演出情報")
	_check(not battle.attack(ally.uid).ok, "攻撃は1回")
	battle.hp[1] = 3
	ally.attacked = false
	battle.attack(ally.uid)
	_check(battle.phase == "over" and battle.winner == 0, "王0で勝利")
	before = battle.snapshot()
	_check(not battle.end_turn().ok and battle.snapshot() == before, "終局後は状態不変")
	battle = _empty_battle()
	ally = _unit(battle, "wraith", 0, Vector2i(1, 0))
	battle.begin_battle()
	event = battle.attack(ally.uid)
	_check(event.damage == 0 and battle.hp[1] == 10, "負攻撃力で王回復しない")
	_check(event.king_damage_side == -1, "損害0では王被弾を演出しない")
	battle.discards[1] = ["blade", "reed"]
	battle.end_turn()
	_check(battle.hands[1].size() == 1 and battle.decks[1].size() == 1, "捨て場再循環")


func _check_effects() -> void:
	var battle: BoardBattle = _empty_battle()
	var ally: Dictionary = _unit(battle, "blade", 0, Vector2i(1, 1))
	var enemy: Dictionary = _unit(battle, "reed", 1, Vector2i(1, 0))
	battle.begin_battle()
	battle.attack(ally.uid, enemy.uid)
	_check(Battle.position(ally) == Vector2i(1, 1), "番兵は勝者の進軍を止める")
	_check(battle.attack_power(ally, true, true) == 4, "剣客は表向きへの攻撃力上昇")
	battle = _empty_battle()
	ally = _unit(battle, "veil", 0, Vector2i(1, 1))
	enemy = _unit(battle, "dragon", 1, Vector2i(1, 0))
	_check(battle.swap_units(ally.uid, enemy.uid).ok, "夜渡りは敵とも配置換え")
	battle = _empty_battle()
	ally = _unit(battle, "bow", 0, Vector2i(1, 1))
	_unit(battle, "shield", 1, Vector2i(1, 0))
	battle.begin_battle()
	_check(battle.attack(ally.uid).ok, "射手は間の札を越え2マス先の王を射る")
	battle = _empty_battle()
	ally = _unit(battle, "oracle", 0, Vector2i(1, 2))
	enemy = _unit(battle, "wraith", 1, Vector2i(1, 0), false)
	_check(battle.use_effect(ally.uid, enemy.uid).ok and enemy.face, "星読みで敵札を公開")
	_check(not battle.use_effect(ally.uid, enemy.uid).ok, "効果は各ターン1回")
	battle = _empty_battle()
	ally = _unit(battle, "dragon", 0, Vector2i(1, 1))
	enemy = _unit(battle, "wraith", 1, Vector2i(1, 0), false)
	battle.begin_battle()
	var event: Dictionary = battle.attack(ally.uid, enemy.uid)
	_check(battle.units.is_empty(), "潜伏亡霊が攻撃札を道連れ")
	_check(event.target_was_hidden and event.target_card == "wraith" and event.card == "dragon",
		"消えた潜伏札の正体を攻撃前の情報として保持")
	battle = _empty_battle()
	ally = _unit(battle, "shield", 0, Vector2i(1, 1))
	_check(battle.attack_power(ally, false) == 3, "衛士は守備時のみ加算")
	ally.card = "lancer"
	ally.y = 0
	battle.begin_battle()
	_check(battle.attack(ally.uid).damage == 4, "槍手は王ダメージ加算")
	battle = _empty_battle()
	ally = _unit(battle, "monk", 0, Vector2i(1, 2))
	battle.hp[0] = 9
	_check(battle.use_effect(ally.uid).ok and battle.hp[0] == 10, "灯守の王回復")
	_check(not battle.use_effect(ally.uid).ok, "回復上限と再使用拒否")
	battle = _empty_battle()
	ally = _unit(battle, "blade", 0, Vector2i(1, 2))
	var support: Dictionary = _unit(battle, "drummer", 0, Vector2i(0, 2))
	_check(battle.attack_power(ally, true) == 4, "隣接する味方に太鼓加算")
	support.face = false
	_check(battle.attack_power(ally, true) == 3, "潜伏太鼓に効果なし")
	battle = _empty_battle()
	ally = _unit(battle, "fox", 0, Vector2i(1, 2), false)
	battle.decks[0] = ["reed"]
	_check(battle.reveal(ally.uid).ok and battle.hands[0] == ["reed"], "白面登場で1枚引く")
	_check(not battle.reveal(ally.uid).ok, "登場再実行で追加ドローなし")
	battle = _empty_battle()
	ally = _unit(battle, "dragon", 0, Vector2i(1, 1))
	enemy = _unit(battle, "bow", 1, Vector2i(1, 0))
	battle.begin_battle()
	event = battle.attack(ally.uid, enemy.uid)
	_check(event.damage == 1, "墨龍の撃破追撃")
	_check(event.king_damage_side == 1 and event.to == Vector2i(1, 0),
		"撃破マスと王への追撃先を区別")
	_check(battle.hp[1] == 9, "追撃は敵王へ")


func _check_route() -> void:
	for run_seed: int in range(100):
		var route: Array = RunState.generate_route(run_seed)
		_check(route == RunState.generate_route(run_seed), "同シード同経路")
		_check(route.size() == 9 and route.back()[0].type == "final", "9層の最後に将軍")
		var general_count: int = 0
		var paths: int = 1
		for layer: int in range(route.size()):
			_check(not route[layer].is_empty(), "各層に次の道がある")
			paths *= route[layer].size()
			for node: Dictionary in route[layer]:
				general_count += int(node.type == "general")
				_check(node.width == (3 if layer < 4 else 5), "中盤で盤面が拡大")
		_check(general_count == 2, "寄り道の将軍は2名")
		_check(paths == 256, "全256分岐の先が最後の将軍に接続")


func _check_save() -> void:
	var run: BoardRun = RunState.new()
	var resumed: BoardRun = RunState.new()
	run.save_path = "res://tmp/selfcheck-save.json"
	resumed.save_path = run.save_path
	run.new_run(709)
	_check(run.choose_node(0), "道選択")
	for index: int in range(12):
		run.battle.ai_step()
	_check(run.save_run(), "戦闘中をファイル保存")
	_check(resumed.load_run(), "ファイルから再開")
	if resumed.battle == null:
		run.free()
		resumed.free()
		return
	_check(run.snapshot() == resumed.snapshot(), "再開は手札・盤面・行動済みを保持")
	for index: int in range(30):
		var original_event: Dictionary = run.battle.ai_step()
		var resumed_event: Dictionary = resumed.battle.ai_step()
		_check(original_event == resumed_event, "再開後の敵AI・山札は同じ")
		_check(run.battle.snapshot() == resumed.battle.snapshot(), "再開後の状態再現")
	var good: Dictionary = run.snapshot()
	for key: String in good:
		var malformed: Dictionary = good.duplicate(true)
		malformed.erase(key)
		_check(not resumed.restore(malformed), "保存の必須項目欠落 " + key)
		_check(resumed.snapshot() == good, "壊れた保存で現在ランを変更しない")
	var malformed: Dictionary = good.duplicate(true)
	malformed.version = 999
	_check(not resumed.restore(malformed), "保存バージョン拒否")
	malformed = good.duplicate(true)
	malformed.battle.hands[0].append("missing")
	_check(not resumed.restore(malformed), "未知札拒否")
	malformed = good.duplicate(true)
	malformed.battle.hands[0].append("dragon")
	_check(not resumed.restore(malformed), "保存内札総数不一致を拒否")
	malformed = good.duplicate(true)
	malformed.battle.hands[1].append("dragon")
	_check(not resumed.restore(malformed), "敵側も保存内札総数不一致を拒否")
	malformed = good.duplicate(true)
	malformed.battle.hp = [100, 10]
	_check(not resumed.restore(malformed), "王HP範囲外拒否")
	malformed = good.duplicate(true)
	malformed.route[0][0].type = "final"
	_check(not resumed.restore(malformed), "生成経路と不一致を拒否")
	for key: String in good:
		for wrong_type: Variant in [null, false, [], {}, "不正"]:
			if typeof(wrong_type) == typeof(good[key]) and wrong_type == good[key]:
				continue
			malformed = good.duplicate(true)
			malformed[key] = wrong_type
			_check(not resumed.restore(malformed), "保存項目の型異常拒否 " + key)
	_check_nested_save(good, resumed)
	var file: FileAccess = FileAccess.open(run.save_path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	_check(not resumed.load_run() and resumed.snapshot() == good, "壊れたJSONを安全に拒否")
	_check(run.save_run() and resumed.load_run(), "破損後も次の正常保存で再開可")
	run.stage = "title"
	_check(not run.save_run() and resumed.load_run(), "タイトル復帰は既存保存を上書きしない")
	_check(resumed.snapshot() == good, "タイトル復帰後も局面から再開")
	run.free()
	resumed.free()


func _check_nested_save(good: Dictionary, resumed: BoardRun) -> void:
	for key: String in good.battle:
		for wrong_type: Variant in [null, false, [], {}, "不正"]:
			if typeof(wrong_type) == typeof(good.battle[key]) and wrong_type == good.battle[key]:
				continue
			var malformed: Dictionary = good.duplicate(true)
			malformed.battle[key] = wrong_type
			_check(not resumed.restore(malformed), "戦闘保存項目の型異常拒否 " + key)
	if good.battle.units.size() >= 2:
		var malformed: Dictionary = good.duplicate(true)
		malformed.battle.units[1].x = malformed.battle.units[0].x
		malformed.battle.units[1].y = malformed.battle.units[0].y
		_check(not resumed.restore(malformed), "同一マスの札重複を拒否")
		malformed = good.duplicate(true)
		malformed.battle.units[1].uid = malformed.battle.units[0].uid
		_check(not resumed.restore(malformed), "札ID重複を拒否")
	_check(resumed.snapshot() == good, "入れ子の破損でも現局は無変更")


func _check_ai() -> void:
	var completed: int = 0
	var victories: int = 0
	var maximum_actions: int = 0
	for opponent: String in Catalog.ENEMIES:
		for run_seed: int in range(12):
			var battle: BoardBattle = Battle.new()
			battle.setup(Catalog.STARTER, opponent, 3 if run_seed % 2 == 0 else 5, run_seed)
			var actions: int = 0
			while battle.phase != "over" and actions < 1800:
				_check(battle.ai_step().ok, "AIは公開操作で合法な行動だけを選ぶ")
				_check(Battle.valid_snapshot(battle.snapshot()), "AI行動後の盤面整合")
				_check(_card_count(battle, 0) == 8 and _card_count(battle, 1) == 8,
					"AI双方の全札枚数保存")
				actions += 1
			maximum_actions = maxi(maximum_actions, actions)
			completed += int(battle.phase == "over")
			victories += int(battle.winner == 0)
			_check(battle.phase == "over",
				"AI対局は有限手で終局 %s seed %d" % [opponent, run_seed])
	_check(completed == 48 and victories > 0, "全敵との対局完遂・プレイヤー勝利可能")
	print("AI対局: %d 局、プレイヤー勝利 %d、最大 %d 操作" % [completed, victories, maximum_actions])


func _check_run() -> void:
	var victories: int = 0
	var generals_beaten: int = 0
	for run_seed: int in range(16):
		var run: BoardRun = RunState.new()
		run.new_run(run_seed)
		var transitions: int = 0
		while run.stage != "result" and transitions < 50:
			_check(RunState.valid_snapshot(run.snapshot()), "ラン進行状態の整合")
			if run.stage == "map":
				_check(run.choose_node(_next_path(run, run_seed % 2 == 0)), "分岐を選べる")
			elif run.stage == "battle":
				var actions: int = 0
				while run.battle.phase != "over" and actions < 1800:
					run.battle.ai_step()
					actions += 1
				_check(run.battle.phase == "over", "ラン戦闘が終局")
				_check(run.resolve_battle(), "戦闘結果をランへ反映")
				_check(not run.resolve_battle(), "勝利報酬の二重処理禁止")
			elif run.stage == "reward":
				if run.current_node.type == "general":
					for card_id: String in run.reward_options:
						_check(Catalog.CARDS[card_id].rarity == 2, "将軍勝利はレア札報酬")
				var chosen: int = _best_card(run.reward_options)
				var card_id: String = run.reward_options[chosen]
				var old_count: int = run.deck.size()
				_check(run.take_reward(chosen), "報酬取得")
				_check(run.deck.size() == old_count + 1 and card_id in run.collection,
					"報酬はデッキと図鑑に残る")
				_check(not run.take_reward(0), "報酬二重取得禁止")
			elif run.stage == "rest":
				var old_hp: int = run.king_hp
				_check(run.rest() and run.king_hp == mini(10, old_hp + 4), "休息回復")
				_check(not run.rest(), "休息二重処理禁止")
			elif run.stage == "shop":
				var chosen: int = _best_card(run.shop_options)
				var card_id: String = run.shop_options[chosen]
				var price: int = Catalog.PRICES[Catalog.CARDS[card_id].rarity]
				var old_gold: int = run.gold
				var can_buy: bool = old_gold >= price
				_check(run.buy_card(chosen) == can_buy, "商人の所持金判定")
				_check(run.gold == old_gold - (price if can_buy else 0), "商人の支払額")
				run.leave_node()
			transitions += 1
		_check(run.stage == "result", "ランは勝敗結果へ到達")
		_check(RunState.valid_snapshot(run.snapshot()), "結果も保存可能")
		victories += int(run.won)
		generals_beaten += run.generals.count("general")
		run.free()
	_check(victories > 0 and generals_beaten > 0, "通常操作で最終勝利・寄り道将軍撃破に到達")
	print("ラン16回: 完走 %d、寄り道の将軍撃破 %d" % [victories, generals_beaten])
	_check_shop_and_abandon()


func _next_path(run: BoardRun, brave: bool) -> int:
	var choices: Array = run.route[run.depth + 1]
	var priorities: Array[String] = ["reward", "rest", "shop", "battle", "general", "final"]
	if brave:
		priorities = ["general", "reward", "shop", "rest", "battle", "final"]
	for kind: String in priorities:
		for index: int in range(choices.size()):
			if choices[index].type == kind:
				return index
	return 0


func _best_card(cards: Array[String]) -> int:
	var selected: int = 0
	for index: int in range(cards.size()):
		if Catalog.CARDS[cards[index]].atk > Catalog.CARDS[cards[selected]].atk:
			selected = index
	return selected


func _check_shop_and_abandon() -> void:
	var run: BoardRun = RunState.new()
	run.new_run(77)
	var initial: Dictionary = run.snapshot()
	_check(not run.choose_node(-1) and not run.choose_node(20), "不正分岐拒否")
	_check(not run.take_reward(0) and not run.buy_card(0), "異なる画面の操作を拒否")
	_check(not run.rest() and run.snapshot() == initial, "無効ラン操作は無変更")
	run.depth = 1
	run.current_node = run.route[1][0].duplicate()
	_check(run.choose_node(_find_kind(run.route[2], "shop")), "商人ノードへ入る")
	var old_count: int = run.deck.size()
	_check(run.remove_card(0) and run.gold == 20 and run.deck.size() == old_count - 1,
		"商人の札削除と支払い")
	_check(not run.remove_card(-1), "負インデックスの札削除拒否")
	run.gold = 0
	initial = run.snapshot()
	_check(not run.remove_card(0) and not run.buy_card(0), "所持金不足で購入・削除不可")
	_check(run.snapshot() == initial, "金不足の操作は無変更")
	_check(run.abandon() and not run.abandon(), "撤退は一度だけ")
	_check(RunState.valid_snapshot(run.snapshot()), "戦闘外の撤退結果を保存できる")
	run.new_run(88)
	_check(run.abandon() and RunState.valid_snapshot(run.snapshot()), "開始直後にも撤退可")
	run.free()


func _find_kind(nodes: Array, kind: String) -> int:
	for index: int in range(nodes.size()):
		if nodes[index].type == kind:
			return index
	return -1


func _card_count(battle: BoardBattle, side: int) -> int:
	var count: int = battle.hands[side].size() + battle.decks[side].size()
	count += battle.discards[side].size()
	for unit: Dictionary in battle.units:
		count += int(unit.side == side)
	return count
