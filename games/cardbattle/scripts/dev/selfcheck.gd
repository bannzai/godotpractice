extends SceneTree
## 決闘ロジック・入力定義・シーン・素材クレジットの検証。
## release ビルドで assert が消えるため、明示的な判定と exit code で結果を返す。

const Catalog = preload("res://scripts/card_catalog.gd")
const Duel = preload("res://scripts/duel_state.gd")

var failed: bool = false
var checked: int = 0


func _initialize() -> void:
	_check_scenes("res://scenes")
	_check_assets_credited()
	_check_input_actions()
	_check_catalog()
	_check_setup_and_phases()
	_check_summoning_and_positions()
	_check_battles()
	_check_spells()
	_check_traps()
	_check_defeat()
	_check_cpu_priorities()
	_check_cpu_matches()

	if failed:
		quit(1)
	else:
		print("検証件数: %d" % checked)
		print("selfcheck OK")
		quit(0)


func _check(cond: bool, label: String) -> void:
	# 失敗を集計する検証ランナーなので呼出しごとに件数を加算する。
	checked += 1
	if not cond:
		push_error("selfcheck FAIL: " + label)
		failed = true


func _check_input_actions() -> void:
	for action: String in [
		"duel_confirm", "duel_cancel", "duel_next", "duel_previous_hand", "duel_next_hand",
		"duel_fullscreen", "duel_up", "duel_down", "duel_left", "duel_right",
	]:
		_check(InputMap.has_action(action), "入力: %s が定義されている" % action)
		if not InputMap.has_action(action):
			continue
		var has_keyboard: bool = false
		var has_gamepad: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			has_keyboard = has_keyboard or event is InputEventKey
			has_gamepad = has_gamepad or event is InputEventJoypadButton
		_check(has_keyboard and has_gamepad, "入力: %s にキーとパッドがある" % action)


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
	var entries: Array[Dictionary] = Catalog.cards()
	_check(entries.size() >= 30, "カード: 30種類以上")
	var ids: Array[String] = []
	var names: Array[String] = []
	var spell_effects: Array[String] = []
	var traps: int = 0
	for card: Dictionary in entries:
		_check(not ids.has(card.id), "カード: IDが一意 %s" % card.id)
		_check(not names.has(card.name), "カード: 名称が一意 %s" % card.name)
		ids.append(card.id)
		names.append(card.name)
		_check(not card.text.is_empty(), "カード: 効果テキスト %s" % card.id)
		_check(card.type in ["monster", "spell", "trap"], "カード: 種別 %s" % card.id)
		if card.type == "monster":
			_check(card.attack >= 0 and card.defense >= 0, "モンスター: 能力値 %s" % card.id)
			_check(card.level >= 1 and not card.attribute.is_empty(), "モンスター: 属性レベル")
		elif card.type == "spell" and not spell_effects.has(card.effect):
			spell_effects.append(card.effect)
		elif card.type == "trap":
			traps += 1
	_check(spell_effects.size() >= 3 and traps >= 1, "カード: 魔法3系統と罠")
	_check(Catalog.card("unknown").is_empty(), "カード: 未定義IDは空")
	for deck_index: int in range(2):
		var deck: Array[String] = Catalog.deck(deck_index)
		_check(deck.size() == 40, "デッキ: 40枚 %d" % deck_index)
		for id: String in deck:
			_check(ids.has(id), "デッキ: 定義済みカード %s" % id)
			_check(deck.count(id) <= 3, "デッキ: 同名3枚以下 %s" % id)
	_check(Catalog.deck(0) != Catalog.deck(1), "デッキ: 異なる固定デッキを2つ用意")
	_check(Catalog.deck_name(0) != Catalog.deck_name(1), "デッキ: 名前で区別できる")


func _check_setup_and_phases() -> void:
	var state: Duel = Duel.new()
	_check(not state.advance_phase(), "開始前: フェイズを進められない")
	_check(state.start(0, 73), "開始: 初期化に成功")
	var original: Array[Dictionary] = state.players.duplicate(true)
	for player: Dictionary in state.players:
		_check(player.life == 8000, "開始: ライフ8000")
		_check(player.hand.size() == 5 and player.deck.size() == 35, "開始: 初手5枚")
	_check(state.phase == "draw" and state.turn == 1 and state.turn_player == 0, "開始: 先攻ドロー")
	_check(state.start(0, 73) and state.players == original, "開始: 同じseedで同じ配札")
	_check(state.advance_phase() and state.phase == "main", "フェイズ: ドローからメイン")
	_check(state.players[0].hand.size() == 6, "フェイズ: 通常ドローは1枚")
	_check(state.advance_phase() and state.phase == "end", "フェイズ: 先攻初回はバトルを飛ばす")
	_check(state.advance_phase() and state.phase == "draw", "フェイズ: エンドから次のドロー")
	_check(state.turn == 2 and state.turn_player == 1, "フェイズ: ターンとプレイヤーが交替")
	_check(state.advance_phase() and state.phase == "main", "フェイズ: 後攻メイン")
	_check(state.advance_phase() and state.phase == "battle", "フェイズ: メインからバトル")
	_check(state.advance_phase() and state.phase == "end", "フェイズ: バトルからエンド")
	_check(state.start(1, 73) and state.winner == -1 and state.turn == 1, "再開: 決闘状態を初期化")


func _fixture() -> Duel:
	var state: Duel = Duel.new()
	state.start(0, 13)
	state.turn = 3
	state.phase = "main"
	for player: Dictionary in state.players:
		player.hand.clear()
		player.monsters.clear()
		player.spells.clear()
		player.grave.clear()
	return state


func _monster(id: String = "m00", defense: bool = false, boost: int = 0) -> Dictionary:
	return {"id": id, "defense": defense, "attacked": false, "boost": boost, "changed": false}


func _check_summoning_and_positions() -> void:
	var state: Duel = _fixture()
	state.players[0].hand.assign(["m00", "m01", "draw", "snare"])
	_check(not state.summon(-1) and not state.summon(99), "召喚: 手札範囲外を拒否")
	_check(not state.summon(2), "召喚: 魔法を召喚できない")
	_check(state.summon(0, true), "召喚: 守備表示を選べる")
	_check(state.players[0].monsters[0].defense, "召喚: 守備表示を保持")
	_check(not state.summon(0), "召喚: 同一ターン2回目を拒否")
	_check(state.change_position(0), "表示: メインに攻撃へ変更")
	_check(not state.change_position(0), "表示: 同一ターン2回変更を拒否")
	state.advance_phase()
	_check(state.attack(0), "召喚: 先攻初回以外は召喚ターンに攻撃可")
	_check(not state.attack(0), "攻撃: 同じモンスターの2回目を拒否")
	_check(not state.summon(0) and not state.change_position(0), "バトル: 召喚と表示変更を拒否")
	state.advance_phase()
	state.advance_phase()
	_check(not state.summoned, "ターン交替: 通常召喚回数を戻す")
	_check(not state.players[0].monsters[0].attacked, "ターン交替: 攻撃済みを戻す")
	_check(not state.players[0].monsters[0].changed, "ターン交替: 表示変更済みを戻す")
	state = _fixture()
	state.players[0].hand.assign(["m00", "m01"])
	for _slot: int in range(5):
		state.players[0].monsters.append(_monster())
	var before: Array[Dictionary] = state.players.duplicate(true)
	_check(not state.summon(0) and state.players == before, "召喚: 5枠満杯なら状態を変更しない")
	state = _fixture()
	state.turn = 1
	state.phase = "battle"
	state.players[0].monsters.append(_monster())
	_check(not state.attack(0), "攻撃: 先攻最初のターンは直接呼出しも拒否")


func _check_battles() -> void:
	# 強弱と同値を固定するため、同じモンスターの強化値だけを変える。
	for defense: bool in [false, true]:
		for difference: int in [-400, 0, 400]:
			var state: Duel = _fixture()
			state.phase = "battle"
			var resistance: int = 1400 if defense else 1600
			state.players[0].monsters.append(_monster("m00", false, resistance + difference - 1600))
			state.players[1].monsters.append(_monster("m00", defense))
			_check(state.attack(0, 0), "戦闘: 攻守=%s 差=%d" % [defense, difference])
			var attacker_destroyed: bool = not defense and difference <= 0
			var defender_destroyed: bool = difference > 0 or (difference == 0 and not defense)
			_check(state.players[0].monsters.is_empty() == attacker_destroyed, "戦闘: 攻撃側の破壊")
			_check(state.players[1].monsters.is_empty() == defender_destroyed, "戦闘: 防御側の破壊")
			_check(state.players[0].grave.size() == int(attacker_destroyed), "戦闘: 攻撃側の墓地")
			_check(state.players[1].grave.size() == int(defender_destroyed), "戦闘: 防御側の墓地")
			_check(state.players[0].life == 8000 - maxi(0, -difference), "戦闘: 攻撃側差分ダメージ")
			var enemy_damage: int = maxi(0, difference) if not defense else 0
			_check(state.players[1].life == 8000 - enemy_damage, "戦闘: 守備に貫通ダメージなし")
	var state: Duel = _fixture()
	state.phase = "battle"
	state.players[0].monsters.append(_monster("m00", true))
	_check(not state.attack(0), "戦闘: 守備表示では攻撃できない")
	state.players[0].monsters[0].defense = false
	state.players[1].monsters.append(_monster())
	var before: Array[Dictionary] = state.players.duplicate(true)
	_check(not state.attack(0), "戦闘: 相手モンスター存在時は直接攻撃不可")
	_check(not state.attack(0, 5) and state.players == before, "戦闘: 不正対象は状態不変")
	_check(not state.attack(-1, 0) and not state.attack(5, 0), "戦闘: 不正攻撃者を拒否")
	state.players[1].monsters.clear()
	_check(state.attack(0) and state.players[1].life == 6400, "戦闘: 直接攻撃は攻撃力全量")
	_check(state.power(_monster("m00", false, -5000)) == 0, "戦闘: 攻撃力を負にしない")


func _check_spells() -> void:
	var state: Duel = _fixture()
	state.players[0].hand.assign(["draw"])
	var deck_size: int = state.players[0].deck.size()
	_check(state.play_spell(0), "魔法: ドロー発動")
	_check(state.players[0].hand.size() == 2, "魔法: 2枚ドロー")
	_check(state.players[0].deck.size() == deck_size - 2, "魔法: 山札から2枚減る")
	_check(state.players[0].grave == ["draw"], "魔法: 使用カードを墓地へ")
	state = _fixture()
	state.players[0].hand.assign(["destroy", "boost"])
	var before: Array[Dictionary] = state.players.duplicate(true)
	_check(not state.play_spell(0), "魔法: 対象なしの破壊を拒否")
	_check(not state.play_spell(1) and state.players == before, "魔法: 対象なしの強化は状態不変")
	state.players[1].monsters.append(_monster("m00"))
	state.players[1].monsters.append(_monster("m11"))
	_check(not state.play_spell(0, 2), "魔法: 範囲外対象を拒否")
	_check(state.play_spell(0), "魔法: 自動で最強の敵を破壊")
	_check(state.players[1].grave == ["m11"], "魔法: 最強の敵が墓地へ")
	state.players[0].monsters.append(_monster())
	_check(state.play_spell(0, 0), "魔法: 指定した味方を強化")
	_check(state.power(state.players[0].monsters[0]) == 2300, "魔法: 攻撃力700上昇")
	state.phase = "end"
	state.advance_phase()
	_check(state.power(state.players[0].monsters[0]) == 1600, "魔法: ターン交替で強化が切れる")
	state.players[1].hand.assign(["draw"])
	_check(not state.play_spell(0), "魔法: メイン以外は使用できない")


func _check_traps() -> void:
	var state: Duel = _fixture()
	state.players[0].hand.assign(["snare", "draw"])
	_check(not state.set_trap(1), "罠: 魔法を罠として伏せられない")
	_check(state.set_trap(0), "罠: メインでセットできる")
	_check(state.players[0].spells == ["snare"], "罠: 伏せ札として保持")
	for id: String in ["snare", "mist", "spark"]:
		state = _fixture()
		state.phase = "battle"
		state.players[0].monsters.append(_monster())
		state.players[1].spells.assign([id, "snare"])
		_check(state.attack(0), "罠: 相手の攻撃で発動 %s" % id)
		_check(state.players[1].spells == ["snare"], "罠: 1回の攻撃に1枚発動")
		_check(state.players[1].grave == [id], "罠: 発動後に墓地へ")
		match id:
			"snare":
				_check(state.players[0].monsters.is_empty(), "罠: 攻撃モンスターを破壊")
				_check(state.players[1].life == 8000, "罠: 破壊された攻撃はダメージなし")
			"mist":
				_check(state.players[1].life == 7200, "罠: 攻撃力を800下げてから戦闘")
				state.phase = "end"
				state.advance_phase()
				_check(state.power(state.players[0].monsters[0]) == 1600, "罠: 弱体化はターン終了まで")
			"spark":
				_check(state.players[0].life == 7000, "罠: 攻撃側へ1000ダメージ")
				_check(state.players[1].life == 6400, "罠: 生存していれば攻撃継続")
	state = _fixture()
	state.players[0].hand.assign(["snare"])
	state.players[0].spells.assign(["snare", "snare", "mist", "mist", "spark"])
	_check(not state.set_trap(0), "罠: 魔法罠ゾーン5枠上限")


func _check_defeat() -> void:
	var state: Duel = _fixture()
	state.phase = "battle"
	state.players[0].monsters.append(_monster())
	state.players[1].life = 900
	_check(state.attack(0) and state.winner == 0, "勝敗: 相手ライフ0で勝利")
	_check(state.players[1].life == 0, "勝敗: ライフは0で止まる")
	var finished: Array[Dictionary] = state.players.duplicate(true)
	_check(not state.advance_phase() and not state.attack(0), "勝敗: 終了後は進行不可")
	_check(not state.summon(0) and not state.play_spell(0), "勝敗: 終了後はカード使用不可")
	_check(state.players == finished, "勝敗: 終了後の状態不変")
	state = _fixture()
	state.phase = "draw"
	state.players[0].deck.clear()
	_check(state.advance_phase() and state.winner == 1, "勝敗: 通常ドロー不能で敗北")
	state = _fixture()
	state.players[0].hand.assign(["draw"])
	state.players[0].deck.assign(["m00"])
	_check(state.play_spell(0) and state.winner == 1, "勝敗: 2枚ドローの途中で山札切れ")
	_check(state.players[0].hand == ["m00"], "勝敗: 山札切れ前の1枚は引ける")
	state = _fixture()
	state.phase = "battle"
	state.players[0].life = 800
	state.players[0].monsters.append(_monster())
	state.players[1].spells.assign(["spark"])
	_check(state.attack(0) and state.winner == 1, "勝敗: 攻撃時の罠で敗北")
	_check(state.players[1].life == 8000, "勝敗: 罠で敗北したら戦闘を続けない")


func _check_cpu_priorities() -> void:
	var state: Duel = _fixture()
	_check(not state.cpu_step(), "CPU: 人間のターンを操作しない")
	state.turn_player = 1
	state.players[1].hand.assign(["m00", "draw"])
	state.players[1].deck.assign(["m01", "m02"])
	_check(state.cpu_step() and state.players[1].grave == ["draw"], "CPU: ドロー魔法を優先")
	_check(state.players[1].monsters.is_empty(), "CPU: ドローより先に召喚しない")
	state = _fixture()
	state.turn_player = 1
	state.players[1].hand.assign(["m00", "m11", "destroy", "boost", "snare"])
	state.players[0].monsters.append(_monster("m06"))
	_check(state.cpu_step() and state.players[0].monsters.is_empty(), "CPU: 破壊魔法を先に使う")
	_check(state.cpu_step() and state.players[1].monsters[0].id == "m11", "CPU: 最大攻撃力を召喚")
	_check(state.cpu_step() and state.power(state.players[1].monsters[0]) == 3100, "CPU: 召喚後に強化")
	_check(state.cpu_step() and state.players[1].spells == ["snare"], "CPU: 罠を伏せる")
	_check(state.cpu_step() and state.phase == "battle", "CPU: 行動後にバトルへ")
	_check(state.cpu_step() and state.players[0].life == 4900, "CPU: 相手の場が空なら直接攻撃")
	_check(state.cpu_step() and state.phase == "end", "CPU: 攻撃後にエンドへ")
	state = _fixture()
	state.turn_player = 1
	state.phase = "battle"
	state.players[1].monsters.append(_monster("m00"))
	state.players[0].monsters.append(_monster("m11"))
	state.players[0].monsters.append(_monster("m01"))
	_check(state.cpu_step() and state.players[0].grave == ["m01"], "CPU: 勝てる相手を選んで攻撃")
	state = _fixture()
	state.turn_player = 1
	state.phase = "battle"
	state.players[1].monsters.append(_monster("m01"))
	state.players[0].monsters.append(_monster("m11"))
	_check(state.cpu_step() and state.phase == "end", "CPU: 勝てる対象がなければ攻撃を控える")


func _counts(player: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for zone: String in ["deck", "hand", "spells", "grave"]:
		for id: String in player[zone]:
			counts[id] = int(counts.get(id, 0)) + 1
	for monster: Dictionary in player.monsters:
		counts[monster.id] = int(counts.get(monster.id, 0)) + 1
	return counts


func _check_cpu_matches() -> void:
	var max_steps: int = 0
	for seed_value: int in range(40):
		var state: Duel = Duel.new()
		state.start(seed_value % 2, seed_value)
		var expected: Array[Dictionary] = [_counts(state.players[0]), _counts(state.players[1])]
		var steps: int = 0
		while state.winner == -1 and steps < 1500:
			# CPU専用コマンドを両陣営に適用するため、プレイヤー側のターンだけ配列を交換する。
			if state.turn_player == 0:
				state.players.reverse()
				expected.reverse()
				state.turn_player = 1
			_check(state.cpu_step(), "CPU対CPU: 行動が進む seed=%d step=%d" % [seed_value, steps])
			for owner: int in range(2):
				var player: Dictionary = state.players[owner]
				_check(_counts(player) == expected[owner], "CPU対CPU: 全ゾーンで各カード枚数を保存")
				_check(player.monsters.size() <= 5 and player.spells.size() <= 5, "CPU対CPU: 場の上限")
				_check(player.life >= 0, "CPU対CPU: ライフ非負")
			steps += 1
		max_steps = maxi(max_steps, steps)
		_check(state.winner in [0, 1], "CPU対CPU: 有限手で終局 seed=%d" % seed_value)
	print("CPU対CPU: 固定seed40局、最大%d操作で終局" % max_steps)
