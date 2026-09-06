extends RefCounted
## エンジンの描画に依存しない、収集・戦闘・保存の受け入れ検証。

const State: Script = preload("res://scripts/game_state.gd")


static func run(check: Callable) -> void:
	_check_catalog(check)
	_check_battle(check)
	_check_collection(check)
	_check_save(check)


static func _check_catalog(check: Callable) -> void:
	check.call(Catalog.SPECIES.size() >= 6, "6 種以上のモンスター")
	for id: String in Catalog.SPECIES:
		var definition: Dictionary = Catalog.SPECIES[id]
		check.call(not definition.name.is_empty(), "種族の名前: " + id)
		check.call(Catalog.TYPES.has(definition.type), "種族のタイプ: " + id)
		check.call(ResourceLoader.exists(definition.image), "種族の画像: " + id)
		var first: Dictionary = Catalog.create_monster(id, 1)
		var grown: Dictionary = Catalog.create_monster(id, 14)
		check.call(Catalog.valid_monster(first), "初期個体の整合: " + id)
		check.call(Catalog.stats(grown).hp > Catalog.stats(first).hp, "HP の成長: " + id)
		for stat: String in ["attack", "defense", "speed"]:
			check.call(Catalog.stats(grown)[stat] > Catalog.stats(first)[stat], "能力の成長: " + id)
		for level: int in range(1, Catalog.MAX_LEVEL + 1):
			var known: Array = Catalog.moves(Catalog.create_monster(id, level))
			check.call(not known.is_empty() and known.size() <= 4, "技数の上限: " + id)
			for move_id: String in known:
				check.call(Catalog.MOVES.has(move_id), "習得技の存在: " + id)
		check.call(Catalog.moves(grown) != Catalog.moves(first), "成長で技を習得: " + id)
	for move_id: String in Catalog.MOVES:
		check.call(Catalog.TYPES.has(Catalog.MOVES[move_id].type), "技のタイプ: " + move_id)
		check.call(Catalog.MOVES[move_id].power > 0, "技の威力: " + move_id)
	for pair: Array in [["fire", "leaf"], ["leaf", "water"], ["water", "fire"]]:
		check.call(Catalog.effectiveness(pair[0], pair[1]) == 2.0, "有利なタイプは 2 倍")
		check.call(Catalog.effectiveness(pair[1], pair[0]) == 0.5, "不利なタイプは 0.5 倍")
		check.call(Catalog.effectiveness(pair[0], pair[0]) == 1.0, "同じタイプは等倍")
	var ember: Dictionary = Catalog.create_monster("ember", 5)
	var sprout: Dictionary = Catalog.create_monster("sprout", 5)
	check.call(Catalog.damage(ember, sprout, "spark") == 20, "既知の能力値でダメージは 20")
	var full_chance: float = Catalog.capture_chance(sprout)
	sprout.hp = 1
	check.call(Catalog.capture_chance(sprout) > full_chance, "弱らせると捕獲率が上がる")
	var encountered: Dictionary = {}
	for index: int in 600:
		encountered[Catalog.encounter(float(index) / 600.0)] = true
	check.call(encountered.size() == 6, "遭遇抽選で全 6 種が出現する")
	check.call(Catalog.SPECIES.has(Catalog.encounter(1.0)), "遭遇抽選の上端")


static func _check_battle(check: Callable) -> void:
	var game: Node = State.new()
	game.new_game()
	game.start_battle("sprout", 5)
	game.enemy.hp = 1
	var previous_hp: int = game.active_monster().hp
	var events: Array[Dictionary] = game.resolve_turn("attack", "spark")
	check.call(game.mode == "field", "野生戦勝利でフィールドに戻る")
	check.call(events[0].target == "enemy", "素早い仲間が先に行動")
	check.call(game.active_monster().level == 6, "勝利経験値でレベルが上がる")
	check.call("seed" in Catalog.moves(game.active_monster()), "レベル 6 で技を習得")
	check.call(game.active_monster().hp >= previous_hp, "倒した敵は反撃しない")
	game.start_battle("moth", 20)
	game.active_monster().hp = 1
	events = game.resolve_turn("attack", "spark")
	check.call(game.mode == "gameover", "全滅するとゲームオーバー")
	check.call(events[0].target == "player", "素早い敵が先に行動")
	check.call(game.enemy.hp == Catalog.stats(game.enemy).hp, "倒れた仲間は攻撃しない")
	game.new_game()
	game.party.append(Catalog.create_monster("tide", 5))
	game.start_battle("moth", 20)
	game.active_monster().hp = 1
	game.resolve_turn("attack", "spark")
	check.call(game.mode == "battle" and game.active_index == 1, "控えが生きていれば自動交代")
	check.call(game.enemy.hp == Catalog.stats(game.enemy).hp, "交代した控えは同ターンに攻撃しない")
	game.new_game()
	game.start_battle("owl", 7, true)
	var old_balls: int = game.balls
	game.resolve_turn("capture")
	game.resolve_turn("flee")
	check.call(game.balls == old_balls and game.mode == "battle", "隊長は捕獲・逃走不可")
	game.enemy.hp = 1
	game.active_monster().level = 30
	game.active_monster().hp = Catalog.stats(game.active_monster()).hp
	game.resolve_turn("attack", "sun")
	check.call(game.mode == "clear", "隊長に勝つとクリア")
	game.new_game()
	check.call(game.mode == "field" and game.party.size() == 1, "結果から新しい冒険を再開")
	game.start_battle("sprout", 2)
	game.active_monster().hp -= 20
	var old_potions: int = game.potions
	game.resolve_turn("potion")
	check.call(game.potions == old_potions - 1, "回復薬は一つ消費する")
	game.resolve_turn("flee")
	check.call(game.mode == "field", "野生から逃走できる")
	game.heal_party()
	check.call(game.potions >= 5 and game.balls >= 12, "回復施設で消耗品を補充")
	check.call(game.active_monster().hp == Catalog.stats(game.active_monster()).hp, "施設で完全回復")
	game.free()


static func _check_collection(check: Callable) -> void:
	var game: Node = State.new()
	game.new_game()
	for index: int in 6:
		game.start_battle("tide", 2)
		game.enemy.hp = 1
		_seed_capture(game, true)
		game.resolve_turn("capture")
		check.call(game.mode == "field", "捕獲成功で戦闘終了")
	check.call(game.party.size() == 6 and game.storage.size() == 1, "7 体目は預かり所に入る")
	check.call(game.balls == 6, "捕獲を試みるごとにボール消費")
	game.zone = "clinic"
	check.call(game.swap_storage(0, 0), "回復施設で預かり交換")
	check.call(game.party[0].species == "tide" and game.storage[0].species == "ember", "交換内容が正しい")
	game.heal_party()
	game.start_battle("sprout", 2)
	game.resolve_turn("switch", "1")
	check.call(game.active_index == 1, "戦闘中の交代")
	_seed_capture(game, false)
	var old_balls: int = game.balls
	var old_hp: int = game.active_monster().hp
	game.resolve_turn("capture")
	check.call(game.balls == old_balls - 1 and game.mode == "battle", "捕獲失敗でも消費する")
	check.call(game.active_monster().hp < old_hp, "捕獲失敗後は敵のターン")
	game.balls = 0
	old_hp = game.active_monster().hp
	game.resolve_turn("capture")
	check.call(game.active_monster().hp == old_hp, "ボール不足ではターンを消費しない")
	game.free()


## 乱数の結果を固定し成功と失敗の両経路を再現するため、検証専用の種を探索する。
static func _seed_capture(game: Node, success: bool) -> void:
	for seed_value: int in 10000:
		game.rng.seed = seed_value
		var will_succeed: bool = game.rng.randf() < Catalog.capture_chance(game.enemy)
		if will_succeed == success:
			game.rng.seed = seed_value
			return


static func _check_save(check: Callable) -> void:
	var game: Node = State.new()
	var loaded: Node = State.new()
	var path: String = "res://tmp/logic-selfcheck.json"
	game.new_game()
	game.party.append(Catalog.create_monster("owl", 8))
	game.storage.append(Catalog.create_monster("crab", 4))
	game.zone = "route"
	game.cell = Vector2i(8, 7)
	game.steps = 42
	game.active_index = 1
	check.call(game.save_game(path), "セーブを書き込める")
	check.call(loaded.load_game(path), "タイトルからセーブを読み込める")
	check.call(loaded.party == game.party and loaded.storage == game.storage, "手持ちと預かりを復元")
	check.call(loaded.zone == game.zone and loaded.cell == game.cell, "場所を復元")
	check.call(loaded.mode == "field" and loaded.steps == 42, "保存後フィールドから再開")
	check.call(loaded.active_index == 1, "保存した先頭の選択を復元")
	loaded.start_battle("sprout", 2)
	check.call(loaded.active_index == 1, "戦闘開始で選択した先頭を維持")
	loaded.resolve_turn("flee")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for value: Variant in [null, [], {}, {"version": 99}]:
		check.call(not loaded.valid_save(value), "壊れた保存形式を拒否")
	for key: String in data:
		var missing: Dictionary = data.duplicate(true)
		missing.erase(key)
		check.call(not loaded.valid_save(missing), "必須項目の欠落を拒否: " + key)
	for key: String in ["balls", "potions", "steps", "active_index"]:
		for value: Variant in [-1, 0.5, "1", true]:
			var invalid: Dictionary = data.duplicate(true)
			invalid[key] = value
			check.call(not loaded.valid_save(invalid), "不正な数値を拒否: " + key)
	for key: String in ["level", "hp", "xp"]:
		var invalid: Dictionary = data.duplicate(true)
		invalid.party[0][key] = 99999
		check.call(not loaded.valid_save(invalid), "不正な個体を拒否: " + key)
	var bad_species: Dictionary = data.duplicate(true)
	bad_species.party[0].species = "missing"
	check.call(not loaded.valid_save(bad_species), "存在しない種族を拒否")
	var bad_cell: Dictionary = data.duplicate(true)
	bad_cell.cell = [24, 14]
	check.call(not loaded.valid_save(bad_cell), "範囲外の座標を拒否")
	bad_cell.zone = "town"
	bad_cell.cell = [3, 2]
	check.call(not loaded.valid_save(bad_cell), "建物の壁の内部への復元を拒否")
	var extra_key: Dictionary = data.duplicate(true)
	extra_key.unknown = 1
	check.call(not loaded.valid_save(extra_key), "不明な保存キーを拒否")
	var previous_save: String = FileAccess.get_file_as_string(path)
	game.cell = Vector2i(-1, 0)
	check.call(not game.save_game(path), "不正な状態の保存は失敗する")
	check.call(FileAccess.get_file_as_string(path) == previous_save, "保存失敗時に旧セーブを保持")
	game.cell = Vector2i(8, 7)
	var old_party: Array = loaded.party.duplicate(true)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	check.call(not loaded.load_game(path) and loaded.party == old_party, "破損セーブで現在の冒険を壊さない")
	game.start_battle("tide", 2)
	check.call(not game.save_game(path), "戦闘途中の不完全な状態を保存しない")
	game.free()
	loaded.free()
