extends SceneTree
## シーンとアセットクレジットの検証。実行方法は Makefile の selfcheck target を参照。
## release ビルドで assert が消えるため、明示的な判定と exit code で結果を返す。

const Catalog = preload("res://scripts/catalog.gd")
const State = preload("res://scripts/run_state.gd")

var failed: bool = false


func _initialize() -> void:
	_check_scenes("res://scenes")
	_check_assets_credited()
	_check_catalog()
	_check_navigation_and_tutorial()
	_check_economy()
	_check_target_and_special_attacks()
	_check_victory_and_defeat()
	_check_save()

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
	_check(Catalog.TOWERS.size() == 4, "4種類の塔")
	_check(Catalog.ENEMIES.size() == 5, "4種類の敵とボス")
	_check(Catalog.WAVES.size() == 10, "10ウェーブ")
	for index: int in range(1, Catalog.PATH.size()):
		_check(Catalog.PATH[index] != Catalog.PATH[index - 1], "経路の区間に長さがある")
	_check(Catalog.path_position(-50) == Catalog.PATH[0], "経路の始点境界")
	_check(Catalog.path_position(10000) == Catalog.PATH[-1], "経路の終点境界")
	for site: Vector2 in Catalog.SITES:
		for index: int in range(1, Catalog.PATH.size()):
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(
				site, Catalog.PATH[index - 1], Catalog.PATH[index])
			_check(closest.distance_to(site) >= 58, "建設地点は道から離れている")
	var boss_count: int = 0
	for wave_index: int in range(Catalog.WAVES.size()):
		var definition: Dictionary = Catalog.WAVES[wave_index]
		_check(float(definition.interval) > 0 and int(definition.reward) > 0, "波の間隔と報酬")
		for group: Dictionary in definition.groups:
			_check(Catalog.ENEMIES.has(group.kind) and int(group.count) > 0, "出現敵の参照と数")
			if group.kind == "boss":
				boss_count += int(group.count)
				_check(wave_index == 9, "最終ウェーブにボス")
	_check(boss_count == 1, "ボスは1体")


func _check_navigation_and_tutorial() -> void:
	var run: Node = State.new()
	run.new_run()
	run.build(0, "arrow")
	run.to_map()
	_check(run.phase == "map", "タイトルとプレイの間に正式な地図状態")
	_check(run.towers.is_empty() and run.gold == Catalog.START_GOLD,
		"地図へ入る時に戦闘状態を初期化")
	_check(not run.build(0, "arrow") and not run.start_wave(), "地図では戦闘操作を拒否")
	run.tutorial_save_path = "res://tmp/selfcheck-tutorial.json"
	_remove_file(run.tutorial_save_path)
	run.load_tutorial()
	_check(not run.tutorial_seen, "指南記録がなければ未読")
	_check(not State.parse_tutorial(null) and not State.parse_tutorial({"seen": "yes"}),
		"不正な指南記録を未読として解釈")
	run.mark_tutorial_seen()
	run.mark_tutorial_seen()
	run.tutorial_seen = false
	run.load_tutorial()
	_check(run.tutorial_seen, "指南完了の保存と再読込は冪等")
	var file: FileAccess = FileAccess.open(run.tutorial_save_path, FileAccess.WRITE)
	file.store_string("破損したJSON{")
	file.close()
	run.load_tutorial()
	_check(not run.tutorial_seen, "壊れた指南記録から未読で復帰")
	_remove_file(run.tutorial_save_path)
	run.free()


func _check_economy() -> void:
	var run: Node = State.new()
	run.new_run()
	_check(not run.build(-1, "arrow") and not run.build(0, "invalid"), "無効な建設を拒否")
	_check(run.gold == Catalog.START_GOLD and run.towers.is_empty(), "拒否操作は資金と塔を変更しない")
	for kind: String in Catalog.TOWERS:
		run.gold = 1000
		_check(run.build(0, kind), kind + " の建設")
		var balance: int = run.gold
		_check(not run.build(0, kind) and run.gold == balance, "同じ場所の二重購入を拒否")
		_check(run.upgrade(0) and run.upgrade(0), kind + " を2段階強化")
		balance = run.gold
		_check(not run.upgrade(0) and run.gold == balance, "上限で資金を消費しない")
		var refund: int = run.sell_price(0)
		_check(run.sell(0) and run.gold == balance + refund, "売却は総支出の一部を返金")
		balance = run.gold
		_check(not run.sell(0) and run.gold == balance, "二重売却の返金を防ぐ")
	_check(run.build(0, "arrow"), "売却後に再建設")
	run.gold = 0
	_check(not run.build(1, "arrow") and not run.upgrade(0), "資金不足の建設と強化を拒否")
	_check(run.gold == 0 and run.tower_at(0).level == 1, "資金不足で状態を壊さない")
	_check(run.start_wave() and not run.start_wave(), "実行中の波を再開始できない")
	run.new_run()
	_check(run.gold == Catalog.START_GOLD and run.towers.is_empty() and run.wave == 0,
		"リトライは全進行を初期化")
	run.to_title()
	_check(run.phase == "title" and not run.start_wave() and not run.build(0, "arrow"),
		"タイトルから直接戦闘できない")
	run.free()


func _test_enemy(run: Node, kind: String, at: Vector2, distance: float) -> Dictionary:
	# 単独効果を切り分ける検証用の初期条件を一体ずつ追加するため非冪等。
	run._spawn(kind)
	var enemy: Dictionary = run.enemies.back()
	enemy.position = at
	enemy.distance = distance
	return enemy


func _check_target_and_special_attacks() -> void:
	var run: Node = State.new()
	run.new_run()
	run.wave = 1
	run.build(0, "mortar")
	var at: Vector2 = Catalog.SITES[0] + Vector2(0, -80)
	var first: Dictionary = _test_enemy(run, "runner", at, 50)
	var next: Dictionary = _test_enemy(run, "armor", at + Vector2(15, 0), 80)
	var flying: Dictionary = _test_enemy(run, "flyer", at, 120)
	run._attack(0.1)
	_check(first.hp < first.max_hp and next.hp < next.max_hp, "臼砲は複数の地上敵に範囲攻撃")
	_check(flying.hp == flying.max_hp, "臼砲は飛行敵に当たらない")
	var shots: Array[Dictionary] = []
	for event: Dictionary in run.events:
		if event.type == "shot":
			shots.append(event)
	_check(shots.size() == 1 and shots[0].target == next.id, "攻撃可能な最も終点に近い敵を狙う")
	run.new_run()
	run.wave = 1
	run.build(0, "frost")
	first = _test_enemy(run, "armor", at, 50)
	next = _test_enemy(run, "flyer", at + Vector2(20, 0), 80)
	run._attack(0.1)
	_check(first.slow == 0.5 and next.slow == 0.5, "氷晶は範囲内の地上と飛行を減速")
	var before: float = first.distance
	run._move_enemies(0.1)
	_check(is_equal_approx(first.distance - before, float(Catalog.ENEMIES.armor.speed) * 0.05),
		"減速は移動距離へ反映")
	run._move_enemies(1.6)
	_check(first.slow == 1.0 and next.slow == 1.0, "減速効果が期限切れで戻る")
	run.new_run()
	run.wave = 1
	run.build(0, "sun")
	first = _test_enemy(run, "armor", at, 50)
	run._attack(0.1)
	_check(is_equal_approx(first.max_hp - first.hp, float(Catalog.TOWERS.sun.damage)),
		"陽光は装甲を無視した単体攻撃")
	run.free()


func _invest(run: Node) -> void:
	# 同じ投入資金でも建設を積み重ねる操作列なので非冪等。
	var kinds: Array[String] = ["arrow", "sun", "frost", "mortar", "sun", "arrow"]
	var sites: Array[int] = [0, 2, 4, 3, 7, 1]
	for index: int in range(sites.size()):
		if run.tower_at(sites[index]).is_empty():
			run.build(sites[index], kinds[index])
	for level: int in [1, 2]:
		for site: int in sites:
			if not run.tower_at(site).is_empty() and run.tower_at(site).level == level:
				run.upgrade(site)


func _check_victory_and_defeat() -> void:
	var run: Node = State.new()
	run.save_path = "res://tmp/selfcheck-result.json"
	run.new_run()
	run.speed = 3
	var ticks: int = 0
	var boss_seen: bool = false
	while run.phase == "play" and ticks < 12000:
		if not run.active:
			_invest(run)
			run.start_wave()
		run.step(0.05)
		for event: Dictionary in run.events:
			if event.type == "spawn" and event.kind == "boss":
				boss_seen = true
		run.events.clear()
		_check(run.gold >= 0, "通常の全プレイ中に資金が負にならない")
		ticks += 1
	_check(run.phase == "win" and run.wave == 10 and boss_seen, "合法な建設と強化だけで全波とボスを突破")
	_check(run.stars() >= 1 and run.stars() <= 3, "残存HPでクリア評価")
	print("防衛検証: phase=%s hp=%d elapsed=%.1f gold=%d" % [
		run.phase, run.hp, run.elapsed, run.gold])
	run.new_run()
	run.speed = 3
	ticks = 0
	while run.phase == "play" and ticks < 3000:
		if not run.active:
			run.start_wave()
		run.step(0.05)
		run.events.clear()
		ticks += 1
	_check(run.phase == "lose" and run.hp == 0 and run.stars() == 0, "無防備なら拠点が破壊されて敗北")
	_check(not run.build(0, "arrow") and not run.start_wave(), "敗北後に進行できない")
	var elapsed: float = run.elapsed
	run.step(0.2)
	_check(run.elapsed == elapsed, "結果画面では時間を進めない")
	run.to_title()
	_check(run.phase == "title", "敗北結果からタイトルへ")
	run.free()


func _check_save() -> void:
	_check(State.parse_best(null) == {"stars": 0, "wave": 0}, "空の保存データを解釈")
	_check(State.parse_best({"stars": "3"}) == {"stars": 0, "wave": 0}, "不正型を拒否")
	_check(State.parse_best({"stars": 12, "wave": -9}) == {"stars": 3, "wave": 0}, "値域を制限")
	var run: Node = State.new()
	run.save_path = "res://tmp/selfcheck-save.json"
	var file: FileAccess = FileAccess.open(run.save_path, FileAccess.WRITE)
	file.store_string("破損したJSON{")
	file.close()
	run.load_best()
	_check(run.best.stars == 0, "壊れたJSONから初期値で復帰")
	run.phase = "win"
	run.wave = 10
	run.hp = 20
	run.save_result()
	run.save_result()
	run.load_best()
	_check(run.best == {"stars": 3, "wave": 10}, "星3の保存は冪等")
	run.hp = 1
	_check(run.stars() == 1, "HP1は星1")
	run.hp = 10
	_check(run.stars() == 2, "HP10は星2")
	run.save_result()
	run.load_best()
	_check(run.best.stars == 3, "低い評価で最高記録を上書きしない")
	run.free()


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
