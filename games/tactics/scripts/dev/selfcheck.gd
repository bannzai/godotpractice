extends SceneTree
## シーンとアセットクレジットの検証。実行方法は Makefile の selfcheck target を参照。
## release ビルドで assert が消えるため、明示的な判定と exit code で結果を返す。

const CAMPAIGN: Script = preload("res://scripts/campaign.gd")

var failed: bool = false


func _initialize() -> void:
	_check_data()
	_check_battle_rules()
	_check_campaign()
	_check_full_campaign()
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


func _check_data() -> void:
	_check(BattleData.STAGES.size() >= 3, "3 面以上")
	_check(BattleData.ALLIES.size() >= 5 and BattleData.JOBS.size() >= 5, "5 人・5 兵種")
	for stage: Dictionary in BattleData.STAGES:
		_check(stage.map.size() == BattleData.HEIGHT, "マップ縦幅")
		for row: String in stage.map:
			_check(row.length() == BattleData.WIDTH, "マップ横幅")
			for tile: String in row:
				_check(BattleData.TERRAIN.has(tile), "地形参照")
		var occupied: Array[Vector2i] = []
		for definition: Dictionary in BattleData.ALLIES + stage.enemies:
			var cell: Vector2i = Vector2i(definition.x, definition.y)
			_check(BattleData.inside(cell), "配置はマップ内")
			_check(BattleData.JOBS.has(definition.job), "兵種参照")
			_check(cell not in occupied, "配置が重複しない")
			_check(BattleData.terrain(cell, stage.map).cost < 99, "配置は通行可能")
			occupied.append(cell)
		_check(BattleData.inside(stage.goal), "到達目標はマップ内")


func _check_battle_rules() -> void:
	_check(BattleRules.triangle("sword", "axe") == 1, "剣は斧に有利")
	_check(BattleRules.triangle("axe", "lance") == 1, "斧は槍に有利")
	_check(BattleRules.triangle("lance", "sword") == 1, "槍は剣に有利")
	_check(BattleRules.triangle("axe", "sword") == -1, "逆相性は不利")
	_check(BattleRules.triangle("bow", "sword") == 0, "弓に相性なし")
	var attacker: Dictionary = BattleData.create_unit(BattleData.ALLIES[0], "player")
	var target: Dictionary = BattleData.create_unit(BattleData.STAGES[0].enemies[0], "enemy")
	var map: Array = BattleData.STAGES[0].map
	target.x = 3
	target.y = 5
	var predicted: Dictionary = BattleRules.forecast(attacker, target, map)
	_check(predicted.strikes == 2 and predicted.counter_strikes == 1, "速さ差 4 以上で追撃")
	attacker.skill = 0
	var plain: Dictionary = BattleRules.strike(attacker, target, map)
	target.x = 5
	target.y = 4
	var forest: Dictionary = BattleRules.strike(attacker, target, map)
	_check(forest.damage == plain.damage - 1 and forest.hit == plain.hit - 20, "森の防御と回避")
	target.x = 9
	target.y = 5
	var fort: Dictionary = BattleRules.strike(attacker, target, map)
	_check(fort.damage == plain.damage - 3, "砦の防御")
	attacker.job = "bow"
	attacker.x = 2
	target.x = 3
	_check(not BattleRules.can_reach(attacker, target), "弓は隣接攻撃不可")
	target.x = 4
	_check(BattleRules.can_reach(attacker, target), "弓は距離 2 に攻撃")
	predicted = BattleRules.forecast(attacker, target, map)
	_check(predicted.counter_strikes == 0, "近接敵は弓に反撃不可")
	attacker.x = 4
	attacker.y = 4
	attacker.move = 1
	var units: Array[Dictionary] = [attacker]
	var cells: Array[Vector2i] = BattleRules.movement(attacker, units, map)
	_check(Vector2i(3, 4) in cells and Vector2i(5, 4) not in cells, "森は移動力 2 が必要")
	attacker.move = 2
	cells = BattleRules.movement(attacker, units, map)
	_check(Vector2i(5, 4) in cells, "地形コストを満たせば移動可能")
	attacker.x = 5
	attacker.y = 7
	attacker.move = 5
	cells = BattleRules.movement(attacker, units, map)
	_check(Vector2i(6, 7) not in cells, "水へ侵入不可")


func _check_campaign() -> void:
	var model: Node = CAMPAIGN.new()
	model.save_path = "res://tmp/selfcheck-campaign.json"
	_check(model.new_game(), "新規ゲーム保存")
	_check(model.living("player").size() == 5, "開始時の味方人数")
	_check(model.move_unit("hero", Vector2i(3, 5)), "移動できる")
	_check(not model.move_unit("hero", Vector2i(4, 5)), "一行動で二度移動不可")
	_check(model.undo_move("hero"), "行動前の移動取消")
	_check(model.unit_by_id("hero").x == 2, "取消は元のマスへ")
	_check(not model.move_unit("hero", Vector2i(5, 5)), "敵の占有マスへ移動不可")
	_check(model.preview("hero", "e1").is_empty(), "射程外の攻撃予測は空")
	var hero: Dictionary = model.unit_by_id("hero")
	hero.hp -= 18
	var healing: Array[Dictionary] = model.attack("healer", "hero")
	_check(not healing.is_empty() and hero.hp == hero.max_hp - 1, "隣接味方を回復")
	_check(model.attack("healer", "hero").is_empty(), "行動済みの再回復不可")
	var heal_preview: Dictionary = BattleRules.forecast(
		model.unit_by_id("healer"), hero, model.stage().map)
	_check(heal_preview.heal == 1 and heal_preview.counter_strikes == 0
		and heal_preview.counter_damage == 0, "回復予測は実回復量を示し反撃なし")
	_check(not model.use_item("hero").is_empty() and hero.items == 1, "傷薬で回復し消費")
	for unit: Dictionary in model.living("player"):
		model.wait_unit(unit.id)
	_check(model.phase == "enemy", "全員行動で敵軍へ")
	for step: int in range(5):
		model.enemy_step()
	_check(model.phase == "player" and model.turn == 2, "敵全員行動で次ターン")
	_check(not model.unit_by_id("hero").acted, "自軍の行動状態をリセット")
	_check_combat(model)
	_check_ai(model)
	_check_progression(model)
	_check_save(model)
	model.free()


func _check_combat(model: Node) -> void:
	model.new_game()
	var hero: Dictionary = model.unit_by_id("hero")
	var enemy: Dictionary = model.unit_by_id("e1")
	enemy.x = 3
	enemy.y = 5
	enemy.hp = 100
	enemy.max_hp = 100
	hero.skill = 100
	hero.speed = 100
	enemy.skill = 100
	enemy.speed = 96
	model.rng.seed = 123
	var combat: Array[Dictionary] = model.attack("hero", "e1")
	var attacks: int = 0
	for event: Dictionary in combat:
		if event.kind == "attack":
			attacks += 1
	_check(attacks == 3, "攻撃・反撃・追撃を順に適用")
	model.new_game()
	hero = model.unit_by_id("hero")
	enemy = model.unit_by_id("e1")
	enemy.x = 3
	enemy.y = 5
	enemy.hp = 1
	hero.skill = 100
	hero.xp = 60
	hero.growth = {"strength": 100, "defense": 0}
	var old_strength: int = hero.strength
	var old_defense: int = hero.defense
	combat = model.attack("hero", "e1")
	_check(enemy.hp == 0 and hero.level == 2 and hero.xp == 20, "撃破経験値でレベル上昇")
	_check(hero.strength == old_strength + 1 and hero.defense == old_defense, "成長率 100 と 0 の抽選")
	_check(combat.filter(func(event: Dictionary) -> bool: return event.kind == "death").size() == 1,
		"撃破イベントは一度だけ")


func _check_ai(model: Node) -> void:
	model.new_game()
	var enemy: Dictionary = model.unit_by_id("e1")
	enemy.x = 3
	enemy.y = 5
	enemy.ai = "hold"
	model.unit_by_id("lance").x = 3
	model.unit_by_id("lance").y = 6
	model.unit_by_id("lance").hp = 1
	var choice: Dictionary = model._enemy_choice(enemy)
	_check(choice.target == "lance", "AI は倒しやすい味方を狙う")
	enemy.x = 15
	enemy.y = 0
	choice = model._enemy_choice(enemy)
	_check(choice.cell == Vector2i(15, 0) and choice.target == "", "待機 AI は射程外で移動しない")
	enemy.ai = "approach"
	choice = model._enemy_choice(enemy)
	_check(choice.cell != Vector2i(15, 0), "接近 AI は射程外で近づく")


func _check_progression(model: Node) -> void:
	model.new_game()
	model.unit_by_id("axe").hp = 0
	for enemy: Dictionary in model.living("enemy"):
		enemy.hp = 0
	model.wait_unit("hero")
	_check(model.outcome == "victory", "敵全滅で勝利")
	_check(model.next_stage() and model.stage_index == 1, "次ステージへ進む")
	_check(model.living("player").size() == 4 and model.unit_by_id("axe").hp == 0, "死亡者は次面不参加")
	model.unit_by_id("boss").hp = 0
	model.wait_unit("hero")
	_check(model.outcome == "victory" and model.living("enemy").size() == 2, "隊長のみ撃破で勝利")
	model.next_stage()
	model.unit_by_id("hero").x = 12
	model.unit_by_id("hero").y = 5
	_check(model.move_unit("hero", Vector2i(13, 5)) and model.outcome == "ending", "指定マス到達で全章クリア")
	model.new_game()
	model.unit_by_id("hero").hp = 0
	model.wait_unit("lance")
	_check(model.outcome == "defeat", "主人公死亡は敗北")


func _check_save(model: Node) -> void:
	model.new_game()
	model.unit_by_id("bow").hp = 0
	model.unit_by_id("hero").level = 4
	model.turn = 7
	model.end_player_phase()
	_check(model.save_game(), "進行をファイルへ保存")
	var restored: Node = CAMPAIGN.new()
	restored.save_path = model.save_path
	_check(restored.load_game(), "保存ファイルを復元")
	_check(restored.turn == 7 and restored.phase == "enemy", "ターンとフェーズを復元")
	_check(restored.unit_by_id("hero").level == 4 and restored.unit_by_id("bow").hp == 0,
		"成長と永久死亡を復元")
	_check(not restored.valid_save({"version": 99}), "未対応・欠損データを拒否")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(model.save_path))
	var invalid_roster: Dictionary = data.duplicate(true)
	invalid_roster.units.pop_back()
	_check(not restored.valid_save(invalid_roster), "配置ユニットの欠損を拒否")
	invalid_roster = data.duplicate(true)
	invalid_roster.units[0].team = "enemy"
	_check(not restored.valid_save(invalid_roster), "主人公の陣営改変を拒否")
	invalid_roster = data.duplicate(true)
	invalid_roster.stage = 1
	_check(not restored.valid_save(invalid_roster), "第 2 章のボス欠損を拒否")
	data.units[0].x = 99
	_check(not restored.valid_save(data), "マップ外の保存座標を拒否")
	data.units[0].x = "invalid"
	_check(not restored.valid_save(data), "型違いの保存値を拒否")
	data.turn = "invalid"
	_check(not restored.valid_save(data), "型違いのターンを拒否")
	_check(restored.turn == 7, "無効なデータで現在の進行を破壊しない")
	restored.free()


func _check_full_campaign() -> void:
	for seed_value: int in [7, 41, 2026]:
		var model: Node = CAMPAIGN.new()
		model.save_path = "res://tmp/selfcheck-playthrough.json"
		model.new_game()
		model.rng.seed = seed_value
		for step: int in range(400):
			if model.outcome in ["ending", "defeat"]:
				break
			if model.outcome == "victory":
				_check(model.save_game() and model.load_game(), "章クリア後に保存と再開")
				model.next_stage()
			elif model.phase == "enemy":
				model.enemy_step()
			else:
				_autoplay_turn(model)
		_check(model.outcome == "ending", "通常操作のみで 3 章完走 seed=%d" % seed_value)
		print("通しプレイ seed=%d outcome=%s stage=%d turn=%d" % [
			seed_value, model.outcome, model.stage_index + 1, model.turn])
		model.free()


## 受け入れ検証では公開操作だけを行い、HP や座標を直接変更しない。
func _autoplay_turn(model: Node) -> void:
	for unit: Dictionary in model.living("player"):
		if unit.acted or model.outcome != "" or model.phase != "player":
			continue
		if unit.hp < unit.max_hp / 2 and unit.items > 0:
			model.use_item(unit.id)
			continue
		var choice: Dictionary = _autoplay_choice(model, unit)
		model.move_unit(unit.id, choice.cell)
		if choice.target != "":
			model.attack(unit.id, choice.target)
		else:
			model.wait_unit(unit.id)


func _autoplay_choice(model: Node, unit: Dictionary) -> Dictionary:
	var best: Dictionary = {"cell": BattleRules.position_of(unit), "target": ""}
	var best_score: float = -INF
	for cell: Vector2i in model.movement(unit):
		if cell == model.stage().goal and unit.id != "hero":
			continue
		var candidate: Dictionary = unit.duplicate(true)
		candidate.x = cell.x
		candidate.y = cell.y
		var targets: Array[Dictionary] = model.living("enemy")
		if unit.job == "healer":
			targets = model.living("player")
		for target: Dictionary in targets:
			if target.id == unit.id or not BattleRules.can_reach(candidate, target):
				continue
			var prediction: Dictionary = BattleRules.forecast(candidate, target, model.stage().map)
			var score: float = target.max_hp - target.hp if unit.job == "healer" else (
				prediction.damage * prediction.strikes * prediction.hit / 100.0
				- prediction.counter_damage * prediction.counter_strikes * 0.5)
			if unit.job == "healer" and score == 0:
				continue
			if unit.job != "healer" and prediction.damage * prediction.strikes >= target.hp:
				score += 100
			score += 1000
			if score > best_score:
				best_score = score
				best = {"cell": cell, "target": target.id}
		var destination: Vector2i = model.stage().goal
		if unit.job == "healer":
			destination = BattleRules.position_of(model.unit_by_id("hero"))
		elif model.stage().objective != "reach":
			var nearest: int = 999
			for target: Dictionary in model.living("enemy"):
				var distance: int = BattleRules.distance(cell, BattleRules.position_of(target))
				if distance < nearest:
					nearest = distance
					destination = BattleRules.position_of(target)
		var move_score: float = -BattleRules.distance(cell, destination)
		if cell == model.stage().goal and unit.id == "hero" and model.stage().objective == "reach":
			move_score = 10000
		if move_score > best_score:
			best_score = move_score
			best = {"cell": cell, "target": ""}
	return best
