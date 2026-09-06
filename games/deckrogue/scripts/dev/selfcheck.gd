extends SceneTree
## シーンとアセットクレジットの検証。実行方法は Makefile の selfcheck target を参照。
## release ビルドで assert が消えるため、明示的な判定と exit code で結果を返す。

const State = preload("res://scripts/game_state.gd")
const Catalog = preload("res://scripts/card_catalog.gd")

var failed: bool = false


func _initialize() -> void:
	_check_scenes("res://scenes")
	_check_assets_credited()
	_check_catalog()
	_check_input_actions()
	_check_seed_and_map()
	_check_damage_and_cards()
	_check_piles()
	_check_all_card_piles()
	_check_lethal_effects()
	_check_rewards_and_relics()
	_check_run_loop()
	_check_seed_replays()
	_check_defeat_loop()

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
	_check(Catalog.CARDS.size() >= 15, "15種類以上のカード")
	var types: Dictionary = {}
	for id: String in Catalog.CARDS:
		var card: Dictionary = Catalog.CARDS[id]
		_check(not String(card.name).is_empty(), id + " の名前")
		_check(int(card.cost) >= 0 and int(card.cost) <= 3, id + " のコスト")
		_check(Catalog.TYPES.has(card.type), id + " の分類")
		types[card.type] = true
		_check(card.rarity in ["基本", "通常", "希少"], id + " のレアリティ")
		_check(not card.effects.is_empty(), id + " の効果")
		for key: String in card.effects:
			_check(Catalog.EFFECT_LABELS.has(key), id + " の効果を実装・表示できる")
			_check(int(card.effects[key]) > 0, id + " の効果量")
		_check(not Catalog.card_text(id).is_empty(), id + " の説明")
	_check(types.size() == 3, "攻撃・スキル・パワーを含む")
	_check(Catalog.RELICS.size() >= 3, "3種類以上のレリック")
	_check(Catalog.ENEMIES.size() >= 4 and Catalog.ENEMIES.has("boss"), "敵3種とボス")
	for id: String in Catalog.ENEMIES:
		var enemy: Dictionary = Catalog.ENEMIES[id]
		_check(int(enemy.hp) > 0 and not enemy.moves.is_empty(), id + " のHPと意図")
		for move: Dictionary in enemy.moves:
			_check(move.kind in ["attack", "block", "strength", "weak", "vulnerable"],
				id + " の行動が実装済み")


func _check_seed_and_map() -> void:
	var first: Node = State.new()
	var second: Node = State.new()
	first.start_run(609)
	second.start_run(609)
	_check(first.map_rows == second.map_rows, "同じseedでマップ再現")
	_check(first.map_rows.size() == 8, "8階層のマップ")
	for row: Array in first.map_rows:
		_check(not row.is_empty(), "全階層に到達できる")
	_check(first.map_rows[7][0].kind == "boss", "最上階がボス")
	_check(not first.choose_node(-1), "無効な分岐は拒否")
	_check(first.floor_index == -1, "無効な分岐で階層が進まない")
	first.choose_node(0)
	second.choose_node(0)
	_check(first.hand == second.hand and first.enemy == second.enemy, "同じseedで戦闘再現")
	_check(not first.choose_node(0), "戦闘中の分岐選択は拒否")
	first.free()
	second.free()


func _check_damage_and_cards() -> void:
	_check(State.attack_damage(10, 2, 0, 0) == 12, "筋力を加算")
	_check(State.attack_damage(10, 0, 1, 0) == 7, "弱体で25%減少し切り捨て")
	_check(State.attack_damage(10, 0, 0, 1) == 15, "脆弱で50%増加")
	_check(State.attack_damage(10, 2, 1, 1) == 13, "筋力・弱体・脆弱の合成")
	_check(State.attack_damage(1, -5, 0, 0) == 0, "負のダメージを防ぐ")
	var run: Node = State.new()
	run.start_run(11)
	run.choose_node(0)
	run.hand.assign(["strike", "fortress", "fervor", "insight"])
	run.enemy.hp = 100
	run.enemy.block = 4
	_check(run.play_card(0), "攻撃カードが使える")
	_check(run.enemy.hp == 97 and run.enemy.block == 0, "敵の防御がダメージを吸収")
	_check(run.energy == 2, "コストを消費")
	run.play_card(1)
	_check(run.strength == 3 and run.exhaust_pile.has("fervor"), "パワーは持続して廃棄")
	var before: Array = run.hand.duplicate()
	_check(not run.play_card(0), "エネルギー不足のカードを拒否")
	_check(run.hand == before and run.energy == 1, "拒否したカードで状態を消費しない")
	run.play_card(1)
	_check(run.exhaust_pile.has("insight"), "廃棄カードの再利用を防ぐ")
	run.hand.assign(["guard"])
	run.energy = 1
	run.play_card(0)
	run.enemy.intent = {"kind": "attack", "amount": 10}
	run.enemy.strength = 0
	var hp_before: int = run.hp
	run.end_turn()
	_check(run.hp == hp_before - 4, "プレイヤーの防御が被害を軽減")
	_check(run.block == 0 and run.energy == 3, "ターン開始で防御とエネルギー更新")
	_check(run.strength == 3, "パワーはターンを越えて持続")
	run.enemy.intent = {"kind": "weak", "amount": 2}
	run.end_turn()
	_check(run.weak == 2, "敵の弱体がプレイヤーに付く")
	run.enemy.intent = {"kind": "vulnerable", "amount": 2}
	run.end_turn()
	_check(run.weak == 1 and run.vulnerable == 2, "状態異常の持続ターン")
	run.enemy.intent = {"kind": "attack", "amount": 10}
	_check(run.intent_text() == "攻撃 15", "意図表示は脆弱込みの実ダメージ")
	hp_before = run.hp
	run.end_turn()
	_check(run.hp == hp_before - 15 and run.vulnerable == 1, "脆弱の適用と減衰")
	run.enemy.intent = {"kind": "attack", "amount": 10}
	hp_before = run.hp
	run.end_turn()
	_check(run.hp == hp_before - 15 and run.vulnerable == 0, "脆弱は2回分の敵行動で消える")
	run.enemy.intent = {"kind": "attack", "amount": 10}
	hp_before = run.hp
	run.end_turn()
	_check(run.hp == hp_before - 10, "脆弱消失後は通常ダメージ")
	run.free()


func _check_piles() -> void:
	var run: Node = State.new()
	run.start_run(28)
	run.choose_node(0)
	_check(run.hand.size() == 5 and run.draw_pile.size() == 5, "初手5枚")
	var cards: Array[String] = run.deck.duplicate()
	cards.sort()
	for _turn: int in range(8):
		run.enemy.intent = {"kind": "block", "amount": 2}
		run.end_turn()
		var actual: Array[String] = []
		actual.append_array(run.hand)
		actual.append_array(run.draw_pile)
		actual.append_array(run.discard_pile)
		actual.append_array(run.exhaust_pile)
		actual.sort()
		_check(actual == cards, "再シャッフルを越えてカードの種類と枚数を保存")
		_check(run.hand.size() == 5, "毎ターン5枚引く")
	run.free()


func _check_rewards_and_relics() -> void:
	var run: Node = State.new()
	run.start_run(55)
	run.choose_node(0)
	run.hand.assign(["strike"])
	run.enemy.hp = 1
	run.enemy.block = 0
	run.play_card(0)
	_check(run.phase == "reward" and run.reward_cards.size() == 3, "勝利後の3択報酬")
	_check(run.reward_cards[0] != run.reward_cards[1]
		and run.reward_cards[1] != run.reward_cards[2]
		and run.reward_cards[0] != run.reward_cards[2], "報酬3枚は重複しない")
	var before: int = run.deck.size()
	run.choose_reward(-1)
	_check(run.phase == "map" and run.deck.size() == before, "報酬をスキップ")
	_check(not run.choose_reward(0), "報酬を二重取得できない")
	for _index: int in range(3):
		run.phase = "event"
		run.resolve_event()
	_check(run.relics.size() == 3, "イベントで全3種の遺物を重複なく獲得")
	run.hp = 10
	run.phase = "rest"
	run.rest()
	_check(run.hp == 36 and run.phase == "map", "休憩で回復してマップへ")
	_check(not run.rest() and run.hp == 36, "同じ休憩を再利用できない")
	run.phase = "map"
	for index: int in range(run.map_rows[2].size()):
		if run.map_rows[2][index].kind == "elite":
			run.floor_index = 1
			run.choose_node(index)
			break
	_check(run.strength == 2 and run.armor == 3, "遺物の戦闘開始効果")
	_check(run.block == 3, "遺物の毎ターン防御")
	run.enemy.hp = 1
	run.enemy.block = 0
	run.hand.assign(["strike"])
	run.play_card(0)
	_check(run.phase == "reward" and run.hp > 36, "強敵撃破で遺物と勝利回復")
	var selected: String = run.reward_cards[0]
	run.choose_reward(0)
	_check(run.deck.back() == selected and run.deck.size() == before + 1, "報酬がデッキへ追加")
	run.free()


func _check_run_loop() -> void:
	var run: Node = State.new()
	run.start_run(609)
	var steps: int = 0
	while run.phase != "result" and steps < 800:
		steps += 1
		_advance_run(run)
	_check(run.phase == "result" and run.won, "通常操作だけで8階層とボスを突破")
	_check(run.route.size() == 8, "全階層の選択を記録")
	run.return_title()
	_check(run.phase == "title", "クリア結果からタイトルへ")
	run.start_run(609)
	_check(run.hp == run.max_hp and run.deck.size() == 10 and run.relics.is_empty(),
		"再開時に前の旅の成長とダメージを初期化")
	run.free()


func _choose_safe_node(run: Node) -> void:
	var row: Array = run.map_rows[run.floor_index + 1]
	for kind: String in ["rest", "event", "card", "battle", "elite", "boss"]:
		for index: int in range(row.size()):
			if row[index].kind == kind:
				run.choose_node(index)
				return


func _play_turn(run: Node) -> void:
	var limit: int = 0
	while run.phase == "battle" and limit < 25:
		limit += 1
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


func _check_defeat_loop() -> void:
	var run: Node = State.new()
	run.start_run(8)
	run.choose_node(0)
	for _index: int in range(80):
		if run.phase == "result":
			break
		run.end_turn()
	_check(run.phase == "result" and not run.won and run.hp == 0, "無抵抗で敗北に到達")
	_check(not run.end_turn() and not run.play_card(0), "敗北後に戦闘を続けられない")
	run.return_title()
	_check(run.phase == "title", "敗北からタイトルに戻る")
	run.free()



func _check_all_card_piles() -> void:
	for id: String in Catalog.CARDS:
		var run: Node = State.new()
		run.start_run(71)
		run.deck.assign(Catalog.CARDS.keys())
		run.choose_node(0)
		# 手札順の影響を除き、各効果で実際にカードが失われないか調べる。
		run.draw_pile.append_array(run.hand)
		run.hand.clear()
		run.draw_pile.erase(id)
		run.hand.append(id)
		run.enemy.hp = 1000
		run.hp = 20
		_check(run.play_card(0), id + " を使用できる")
		var actual: Array[String] = []
		actual.append_array(run.hand)
		actual.append_array(run.draw_pile)
		actual.append_array(run.discard_pile)
		actual.append_array(run.exhaust_pile)
		actual.sort()
		var expected: Array[String] = run.deck.duplicate()
		expected.sort()
		_check(actual == expected, id + " のドロー・廃棄・パワー解決後の保存則")
		var card: Dictionary = Catalog.CARDS[id]
		if card.get("exhaust", false) or card.type == "power":
			_check(run.exhaust_pile.has(id), id + " の再使用を防止")
		else:
			_check(run.discard_pile.has(id), id + " は再シャッフル可能")
		run.free()


func _check_lethal_effects() -> void:
	var run: Node = State.new()
	run.start_run(1)
	run.choose_node(0)
	run.hand.assign(["siphon"])
	run.hp = 20
	run.enemy.hp = 1
	run.enemy.block = 0
	run.play_card(0)
	_check(run.phase == "reward" and run.hp == 23, "致死攻撃でも同カードの回復を解決")
	_check(run.discard_pile.has("siphon"), "致死攻撃のカードも捨て札へ移す")
	_check(not run.play_card(0), "致死攻撃の後に追加入力を受け付けない")
	run.start_run(1)
	run.choose_node(0)
	# 山札が空で、使用中のドローカードだけが存在するときの境界。
	run.draw_pile.clear()
	run.discard_pile.clear()
	run.hand.assign(["flow"])
	run.enemy.hp = 1
	run.enemy.block = 0
	run.play_card(0)
	_check(run.hand.is_empty() and run.discard_pile == ["flow"],
		"致死ドローでも使用中のカードを山札へ混ぜて引き直さない")
	run.free()


func _check_seed_replays() -> void:
	for value: int in [1, 7, 28, 82, 609]:
		var first: Node = State.new()
		var second: Node = State.new()
		first.start_run(value)
		second.start_run(value)
		var steps: int = 0
		while first.phase != "result" and steps < 800:
			steps += 1
			_advance_run(first)
			_advance_run(second)
			_check(first.phase == second.phase and first.hp == second.hp
				and first.hand == second.hand and first.enemy == second.enemy
				and first.reward_cards == second.reward_cards and first.relics == second.relics,
				"seed %d の全行動で戦闘と抽選が再現" % value)
		_check(first.phase == "result", "seed %d の旅が停止せず結果に到達" % value)
		_check(first.won == second.won and first.deck == second.deck,
			"seed %d の最終結果とデッキが再現" % value)
		first.free()
		second.free()


func _advance_run(run: Node) -> void:
	match String(run.phase):
		"map":
			_choose_safe_node(run)
		"rest":
			run.rest()
		"event":
			run.resolve_event()
		"reward":
			var choice: int = -1
			for index: int in range(run.reward_cards.size()):
				if run.reward_cards[index] in ["heavy", "siphon", "aegis", "fervor", "bash"]:
					choice = index
			run.choose_reward(choice)
		"battle":
			_play_turn(run)



func _check_input_actions() -> void:
	# --script の実行でも、実際のプロジェクト定義を入力判定に読み込む。
	InputMap.load_from_project_settings()
	var bindings: Dictionary = {
		"ui_left": [KEY_LEFT, JOY_BUTTON_DPAD_LEFT],
		"ui_right": [KEY_RIGHT, JOY_BUTTON_DPAD_RIGHT],
		"ui_up": [KEY_UP, JOY_BUTTON_DPAD_UP],
		"ui_down": [KEY_DOWN, JOY_BUTTON_DPAD_DOWN],
		"ui_accept": [KEY_ENTER, JOY_BUTTON_A],
		"ui_cancel": [KEY_ESCAPE, JOY_BUTTON_B],
		"fullscreen": [KEY_F11, JOY_BUTTON_START],
		"deck": [KEY_D, JOY_BUTTON_Y],
		"map": [KEY_M, JOY_BUTTON_X],
		"end_turn": [KEY_E, JOY_BUTTON_RIGHT_SHOULDER],
	}
	for action: String in bindings:
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = bindings[action][0]
		key.pressed = true
		var joy: InputEventJoypadButton = InputEventJoypadButton.new()
		joy.button_index = bindings[action][1]
		joy.pressed = true
		_check(InputMap.event_is_action(key, action, true), action + " の物理キー対応")
		_check(InputMap.event_is_action(joy, action, true), action + " のゲームパッド対応")
		for other: String in bindings:
			if other == action:
				continue
			_check(not InputMap.event_is_action(key, other, true),
				action + " の物理キーが別操作 " + other + " と競合しない")
			_check(not InputMap.event_is_action(joy, other, true),
				action + " のパッド入力が別操作 " + other + " と競合しない")
