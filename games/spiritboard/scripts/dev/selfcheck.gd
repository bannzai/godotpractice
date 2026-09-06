extends SceneTree
## シーンとアセットクレジットの検証。実行方法は Makefile の selfcheck target を参照。
## release ビルドで assert が消えるため、明示的な判定と exit code で結果を返す。

const Catalog: Script = preload("res://scripts/card_catalog.gd")
const Board: Script = preload("res://scripts/board_state.gd")
const SessionScript: Script = preload("res://scripts/session.gd")

var failed: bool = false


func _initialize() -> void:
	_check_catalog()
	_check_board_rules()
	_check_effects()
	_check_routes()
	_check_events()
	_check_save()
	_check_full_runs()
	if "--logic-only" not in OS.get_cmdline_user_args():
		_check_scenes("res://scenes")
		_check_assets_credited()

	if failed:
		quit(1)
	else:
		print("selfcheck OK")
		quit(0)


func _check(cond: bool, label: String) -> void:
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
	_check(Catalog.CARDS.size() >= 12, "12種以上の霊")
	var rarities: Array[int] = []
	for card_id: String in Catalog.CARDS:
		var card: Dictionary = Catalog.card(card_id)
		_check(int(card.atk) >= 1 and int(card.atk) <= 6, "攻撃力の範囲: " + card_id)
		_check(str(card.effect) in Catalog.EFFECTS, "効果を解決できる: " + card_id)
		_check(not str(card.description).is_empty(), "効果の説明: " + card_id)
		if int(card.rarity) not in rarities:
			rarities.append(int(card.rarity))
	_check(rarities.size() == 3, "レア度3段階")
	_check(Catalog.STARTER.size() == 8, "開始デッキ8枚")
	for opponent: String in Catalog.ENEMIES:
		_check(Catalog.enemy(opponent).lines.size() >= 5, "相手の台詞5種以上: " + opponent)


func _fixture(width: int = 3, dark: int = 0) -> SpiritBoard:
	var board: SpiritBoard = Board.new()
	board.setup(Catalog.STARTER, width, 222, 10, dark)
	return board


func _unit(board: SpiritBoard, card: String, side: int, pos: int, face: bool = true) -> void:
	board.units.append({"uid": board.next_uid, "card": card, "side": side, "pos": pos,
		"face": face, "moved": false, "attacked": false, "flipped": false})
	board.next_uid += 1


func _check_board_rules() -> void:
	var board: SpiritBoard = _fixture()
	_check(board.hands[0].size() == 3 and board.hands[1].size() == 3, "両者の開始手札3枚")
	_check(not board.deploy(0, 0).ok, "敵陣へは配置できない")
	_check(board.deploy(0, 7, false).ok and not bool(board.at(7).face), "潜伏で配置")
	_check(not board.deploy(0, 8).ok, "各ターンの配置1枚")
	_check(not board.move_unit(7, 4).ok, "潜伏中は空きマスへ移動できない")
	_check(board.flip_unit(7).ok and bool(board.at(7).face), "潜伏から登場")
	_check(not board.flip_unit(7).ok, "同ターンの登場効果を連発できない")
	_check(board.move_unit(7, 4).ok, "隣接移動")
	_check(board.legal_targets(4).is_empty(), "移動後の攻撃不可")
	_check(not board.move_unit(4, 3).ok, "同じ霊の再移動不可")
	board = _fixture()
	_unit(board, "fox", 0, 7)
	_unit(board, "bell", 1, 4, false)
	_check(not board.attack(7, 3).ok, "斜めの攻撃不可")
	_check(board.attack(7, 4).ok, "隣接攻撃")
	_check(board.at(7).is_empty() and str(board.at(4).card) == "fox", "勝者が敗者の位置へ")
	_check(board.discards[1].size() == 1, "敗者を捨て場へ")
	_check(not board.move_unit(4, 1).ok, "バトル後は準備に戻れない")
	board = _fixture()
	_unit(board, "bell", 0, 7)
	_unit(board, "fox", 1, 4)
	board.attack(7, 4)
	_check(int(board.at(7).side) == 1 and board.at(4).is_empty(), "防御側の勝者も移動")
	board = _fixture()
	_unit(board, "fox", 0, 7)
	_unit(board, "fox", 1, 4)
	board.attack(7, 4)
	_check(board.units.is_empty(), "同点は相打ち")
	board = _fixture()
	_unit(board, "fox", 0, 1)
	board.kings[1] = 3
	_check(-2 in board.legal_targets(1), "王に隣接")
	_check(board.attack(1, -2).ok and board.winner == 0, "王の命0で勝利")
	_check(not board.end_turn().ok, "勝敗確定後の手番停止")
	board = _fixture(5)
	_unit(board, "fox", 0, 2)
	_check(-2 in board.legal_targets(2), "5列盤でも中央の王へ攻撃")
	board = _fixture()
	board.hands[1].clear()
	board.draw_piles[1].clear()
	board.discards[1] = ["fox"]
	board.end_turn()
	_check(board.hands[1] == ["fox"] and board.discards[1].is_empty(), "捨て場を山札に戻す")
	board = _fixture()
	_unit(board, "fox", 0, 7)
	_unit(board, "bell", 0, 8)
	board.at(7).face = false
	_check(board.move_unit(7, 8).ok and bool(board.at(7).moved), "潜伏中の配置換えは両者の移動を消費")


func _check_effects() -> void:
	var board: SpiritBoard = _fixture()
	_unit(board, "fox", 0, 7)
	_unit(board, "bell", 0, 8)
	_check(board.effective_atk(7) == 4, "隣接味方の支援")
	board.at(8).face = false
	_check(board.effective_atk(7) == 3, "潜伏中は支援しない")
	board = _fixture()
	_unit(board, "dragon", 0, 7)
	_unit(board, "willow", 1, 4, false)
	board.attack(7, 4)
	_check(board.units.is_empty(), "潜伏反撃で攻撃者を道連れ")
	board = _fixture()
	_unit(board, "bell", 0, 7)
	_unit(board, "reaper", 1, 4, false)
	board.attack(7, 4)
	_check(board.units.size() == 1 and str(board.at(7).card) == "reaper",
		"裏向きの道連れ持ちも勝った場合は生き残る")
	board = _fixture()
	_unit(board, "hound", 0, 7)
	_unit(board, "fox", 1, 4, false)
	board.attack(7, 4)
	_check(str(board.at(7).card) == "fox" and bool(board.at(7).face), "奇襲の攻撃力と裏返し")
	board = _fixture()
	board.kings[0] = 7
	board.hands[0] = ["lantern"]
	board.deploy(0, 7)
	_check(board.kings[0] == 8, "登場時に王を回復")
	board = _fixture()
	board.hands[0] = ["mask"]
	_unit(board, "fox", 1, 4)
	board.deploy(0, 7)
	_check(not bool(board.at(4).face), "登場時に敵を潜伏へ")
	board = _fixture()
	board.hands[0] = ["crow"]
	board.deploy(0, 7)
	_check(board.hands[0].size() == 1, "登場時のドロー")
	board = _fixture(3, 50)
	_unit(board, "fox", 0, 7)
	_unit(board, "fox", 1, 4)
	_check(board.effective_atk(7) == 4 and board.effective_atk(4) == 3, "闇50の自軍ボーナス")
	board = _fixture(3, 80)
	_check(board.kings[0] == 8 and board.max_kings[0] == 8, "闇80の王最大命減少")
	board = _fixture()
	_unit(board, "monk", 0, 10)
	_check(board.effective_atk(10) == 4, "最後列の守り")
	board = _fixture()
	_unit(board, "hound", 0, 1)
	board.attack(1, -2)
	_check(board.kings[1] == 5, "王への追加ダメージ")


func _session(seed_value: int = 222223) -> Node:
	var session: Node = SessionScript.new()
	session.save_enabled = false
	session.new_run(seed_value)
	return session


func _check_routes() -> void:
	var session: Node = _session()
	for seed_value: int in range(100):
		var nodes: Array = session.generate_nodes(seed_value)
		_check(nodes == session.generate_nodes(seed_value), "同じseedで同じ道")
		_check(nodes.size() == 10, "8〜12ノードのラン")
		var counts: Dictionary = {}
		for pair: Array in nodes:
			_check(pair.size() == 2, "各段に2分岐")
			for node: Dictionary in pair:
				counts[str(node.kind)] = int(counts.get(str(node.kind), 0)) + 1
		_check(str(nodes[9][0].kind) == "boss" and str(nodes[9][1].kind) == "boss",
			"すべての道が最後のボスへ到達")
		_check(int(counts.get("battle", 0)) == 4 and int(counts.get("boss", 0)) == 2,
			"通常戦闘4候補・最終ボス2候補")
		for kind: String in ["grave", "hunt", "police", "rest", "merchant"]:
			_check(int(counts.get(kind, 0)) in range(2, 4), "イベント候補数の範囲: " + kind)
	_check(session.generate_nodes(0) != session.generate_nodes(1), "seedで道と報酬が変わる")
	session.free()


func _enter_event(session: Node, kind: String) -> void:
	session.screen = "event"
	session.run.current_node = SessionScript.NODE_INFO[kind].duplicate()
	session.run.current_node.kind = kind
	session.run.current_node.card = "mask"


func _check_events() -> void:
	var session: Node = _session()
	_enter_event(session, "grave")
	_check(session.resolve_event("grave_take"), "墓荒らし")
	_check(int(session.run.darkness) == 12 and session.run.deck.size() == 9, "墓地の霊と闇")
	_enter_event(session, "hunt")
	session.resolve_event("hunt_hound")
	_check(session.run.deck.back() == "hound" and int(session.run.darkness) == 40, "望む霊を狙う")
	_enter_event(session, "rest")
	session.run.health = 3
	session.resolve_event("rest")
	_check(int(session.run.health) == 7 and int(session.run.darkness) == 25, "休息")
	_enter_event(session, "merchant")
	session.resolve_event("buy")
	_check(int(session.run.gold) == 4 and session.run.deck.back() == "mask", "商人購入")
	_enter_event(session, "merchant")
	_check(not session.resolve_event("buy"), "所持金不足を拒否")
	session.run.darkness = 80
	_enter_event(session, "hunt")
	session.resolve_event("hunt_spider")
	_check(str(session.screen) == "result" and str(session.run.result) == "darkness", "闇100で結末")
	session.new_run(22)
	_enter_event(session, "police")
	session.resolve_event("fight")
	_check(str(session.screen) == "battle" and session.board.enemy_id == "police", "警官との戦闘")
	session.board.winner = 0
	session.call("_check_battle_result")
	_check(int(session.run.darkness) == 25, "警官に勝つと闇が増える")
	var escaped: bool = false
	var punished: bool = false
	for seed_value: int in range(30):
		session.new_run(seed_value)
		session.run.darkness = 60
		_enter_event(session, "police")
		session.resolve_event("escape")
		escaped = escaped or int(session.run.darkness) == 52
		punished = punished or (int(session.run.health) == 7 and session.run.deck.size() == 7)
	_check(escaped and punished, "逃走成功と闇に応じた没収・命の罰則")
	session.free()


func _check_save() -> void:
	var session: Node = _session()
	session.save_path = "res://tmp/selfcheck-run.json"
	session.collection_path = "res://tmp/selfcheck-collection.json"
	session.save_enabled = true
	session.new_run(4242)
	_check(session.save_game() and session.has_save(), "地図を保存")
	var saved: Dictionary = session.run.duplicate(true)
	session.run.gold = 999
	var loaded_map: bool = session.load_game()
	_check(loaded_map and session.run == saved, "保存から地図を復元")
	session.to_title()
	session.save_game()
	_check(session.has_save() and session.load_game(), "タイトルに戻っても再開データを保持")
	var battle_branch: int = 0 if str(session.run.nodes[0][0].kind) == "battle" else 1
	session.choose_node(battle_branch)
	session.board_action("deploy", 0, 7, false)
	var board_saved: Dictionary = session.board.to_data()
	var loaded_board: bool = session.load_game()
	_check(loaded_board and session.board.to_data() == board_saved, "盤面・山札・手番の復元")
	session.begin_enemy_turn()
	session.step_enemy_turn()
	var enemy_saved: Dictionary = session.board.to_data()
	var expected: SpiritBoard = Board.new()
	_check(expected.restore(enemy_saved), "CPU手番途中の盤面を復元")
	var expected_events: Array[Dictionary] = expected.cpu_turn()
	_check(session.load_game() and session.board.turn == 1, "CPUの手番途中から再開")
	var actual_events: Array[Dictionary] = []
	while session.board.turn == 1:
		actual_events.append(session.step_enemy_turn())
	_check(actual_events == expected_events and session.board.to_data() == expected.to_data(),
		"CPU再開後の合法手と結果が一致")
	board_saved = session.board.to_data()
	session.call("_gain_card", "dragon")
	var second: Node = SessionScript.new()
	second.save_path = session.save_path
	second.collection_path = session.collection_path
	second.call("_load_collection")
	_check("dragon" in second.collection(), "図鑑の永続化")
	var broken: Dictionary = enemy_saved.duplicate(true)
	broken.units[0].card = "unknown"
	var board: SpiritBoard = _fixture()
	_check(not board.restore(broken), "未知のカードを含む盤面を拒否")
	broken = enemy_saved.duplicate(true)
	broken.width = {}
	_check(not board.restore(broken), "壊れた型を拒否")
	broken = enemy_saved.duplicate(true)
	broken.units[0].side = 0.5
	_check(not board.restore(broken), "整数でない陣営を拒否")
	broken = enemy_saved.duplicate(true)
	broken.units.append(broken.units[0].duplicate())
	_check(not board.restore(broken), "重複する位置と識別子を拒否")
	broken = enemy_saved.duplicate(true)
	broken.units[0].face = "true"
	_check(not board.restore(broken), "真偽値でない潜伏状態を拒否")
	broken = enemy_saved.duplicate(true)
	broken.kings[0] = 0
	_check(not board.restore(broken), "未決着なのに王の命が0の保存を拒否")
	var file: FileAccess = FileAccess.open(session.save_path, FileAccess.WRITE)
	file.store_string('{"version":1,"run":{},"screen":"battle"}')
	file.close()
	_check(not session.load_game() and session.board.to_data() == board_saved,
		"壊れた保存は進行中の盤面を変えない")
	session.save_enabled = false
	session.free()
	second.free()


func _check_full_runs() -> void:
	var cleared: int = 0
	for seed_value: int in [222223, 4242, 58]:
		var session: Node = _session(seed_value)
		var turns: int = 0
		while str(session.screen) != "result" and turns < 500:
			if str(session.screen) == "map":
				var pair: Array = session.run.nodes[int(session.run.depth)]
				var branch: int = _safe_branch(pair)
				session.choose_node(branch)
			elif str(session.screen) == "event":
				var action: String = "leave"
				match str(session.run.current_node.kind):
					"grave":
						action = "grave_take"
					"rest":
						action = "rest"
					"merchant":
						action = "buy" if int(session.run.gold) >= 12 else "leave"
					"police":
						action = "escape"
				session.resolve_event(action)
			elif str(session.screen) == "battle":
				_play_turn(session)
				turns += 1
		if str(session.run.result) == "clear":
			cleared += 1
		print("ラン検証 seed=%d 結末=%s 到達=%d 手番=%d" %
			[seed_value, str(session.run.result), int(session.run.depth), turns])
		_check(str(session.run.result) == "clear" and int(session.run.depth) == 10,
			"通常デッキから合法手で全ラン踏破 seed=%d" % seed_value)
		session.to_title()
		_check(str(session.screen) == "title", "結果からタイトルへ")
		session.free()
	_check(cleared == 3, "3つのseedでクリア可能")


func _safe_branch(pair: Array) -> int:
	var preferred: Array[String] = ["rest", "grave", "merchant", "battle", "elite", "boss", "hunt"]
	for kind: String in preferred:
		for branch: int in range(2):
			if str(pair[branch].kind) == kind:
				return branch
	return 0


func _play_turn(session: Node) -> void:
	var board: SpiritBoard = session.board
	var positions: Array[int] = []
	var center: int = board.width / 2
	var places: Array[int] = [board.width * 2 + center]
	for pos: int in range(board.width * 2, board.width * 4):
		if pos not in places:
			places.append(pos)
	var best_card: int = -1
	var best_power: int = -1
	for index: int in range(board.hands[0].size()):
		var power: int = int(Catalog.card(str(board.hands[0][index])).atk)
		if power > best_power:
			best_power = power
			best_card = index
	for pos: int in places:
		if best_card >= 0 and board.can_deploy(pos):
			session.board_action("deploy", best_card, pos)
			break
	for unit: Dictionary in board.units:
		if int(unit.side) == 0:
			positions.append(int(unit.pos))
	for pos: int in positions:
		if not board.at(pos).is_empty() and not bool(board.at(pos).face):
			session.board_action("flip", pos)
		if not board.legal_targets(pos).is_empty():
			continue
		var target: int = pos - board.width if pos / board.width > 0 \
			else pos + signi(center - pos % board.width)
		if target >= 0 and target != pos and board.at(target).is_empty():
			session.board_action("move", pos, target)
	for unit: Dictionary in board.units.duplicate():
		if int(unit.side) != 0 or str(session.screen) != "battle":
			continue
		for target: int in board.legal_targets(int(unit.pos)):
			if target < 0 or board.effective_atk(int(unit.pos)) >= board.effective_atk(target):
				session.board_action("attack", int(unit.pos), target)
				break
	if str(session.screen) == "battle":
		session.end_battle_turn()
