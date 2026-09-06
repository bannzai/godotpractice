extends SceneTree
## シーンとアセットクレジットの検証。実行方法は Makefile の selfcheck target を参照。
## release ビルドで assert が消えるため、明示的な判定と exit code で結果を返す。

const Sim = preload("res://scripts/simulation.gd")

var failed: bool = false


func _initialize() -> void:
	_check_simulation()
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


func _check_simulation() -> void:
	var city: Dictionary = Sim.new_city()
	_check(city.tiles.size() == 1024, "32×32 マップ")
	_check(city == Sim.new_city(), "新規都市は決定的")
	_check(city.tiles.any(func(tile: Dictionary) -> bool: return tile.terrain == "water"), "水地形")
	_check(city.tiles.any(func(tile: Dictionary) -> bool: return tile.terrain == "forest"), "森地形")
	var original: Dictionary = city.duplicate(true)
	var built: Dictionary = Sim.place(city, Vector2i(8, 16), "residential")
	_check(city == original, "建設は入力を変更しない")
	_check(built.money == city.money - Sim.COSTS.residential, "建設費")
	_check(Sim.place(built, Vector2i(8, 16), "residential") == built, "同一配置は冪等")
	_check(Sim.place(city, Vector2i(-1, 0), "road") == city, "範囲外拒否")
	_check(Sim.place(city, Vector2i(31, 0), "road") == city, "水上建設拒否")
	_check(Sim.place(city, Vector2i(8, 16), "unknown") == city, "未知ツール拒否")
	var removed: Dictionary = Sim.place(built, Vector2i(8, 16), "empty")
	_check(removed.tiles[16 * 32 + 8].kind == "empty", "撤去")
	var broke: Dictionary = city.duplicate(true)
	broke.money = -1
	_check(Sim.place(broke, Vector2i(8, 16), "road") == broke, "赤字時建設禁止")
	_check(Sim.place(broke, Vector2i(7, 15), "empty") == broke, "赤字時撤去禁止")
	var report: Dictionary = Sim.analyze(city)
	_check(city == original, "解析は入力を変更しない")
	_check(report.powered[14 * 32 + 8], "道路から電力が届く")
	_check(report.road_access[14 * 32 + 8], "幹線道路への接続")
	var isolated: Dictionary = Sim.place(city, Vector2i(2, 2), "residential")
	isolated = Sim.place(isolated, Vector2i(2, 3), "road")
	_check(not Sim.analyze(isolated).road_access[2 * 32 + 2], "孤立道路は幹線への接続が必要")
	for step: int in 6:
		isolated = Sim.advance_month(isolated)
	_check(isolated.tiles[2 * 32 + 2].level == 0, "道路・電源不足で成長停止")
	var evolved: Dictionary = Sim.advance_month(city)
	_check(city == original, "月次処理は入力を変更しない")
	_check(evolved == Sim.advance_month(city), "月次処理は決定的")
	_check(evolved.month == 1, "月の進行")
	_check(evolved.money == city.money + evolved.income - evolved.expenses, "月次収支")
	_check_growth_and_problems(city)
	_check_problem_regression(city)
	_check_endings(city)
	_check_save(city)


func _check_growth_and_problems(city: Dictionary) -> void:
	var grown: Dictionary = city.duplicate(true)
	for step: int in 6:
		grown = Sim.advance_month(grown)
	_check(grown.population > 0 and grown.jobs > 0, "人口と雇用の成長")
	_check(grown.tiles[14 * 32 + 10].level == 2, "建物の段階成長")
	var stopped: Dictionary = Sim.place(grown, Vector2i(7, 16), "empty")
	var previous_population: int = stopped.population
	for step: int in 2:
		stopped = Sim.advance_month(stopped)
	_check(stopped.population < previous_population, "停電で人口減少")
	var taxed: Dictionary = grown.duplicate(true)
	taxed.tax = 20
	_check(Sim.analyze(taxed).demand.r < Sim.analyze(grown).demand.r, "高税率で需要減少")
	for step: int in 2:
		taxed = Sim.advance_month(taxed)
	_check(taxed.population < grown.population, "重税で人口減少")
	var report: Dictionary = Sim.analyze(grown)
	_check(report.pollution[16 * 32 + 18] > report.pollution[14 * 32 + 8], "工業近隣の公害")
	var no_police: Dictionary = Sim.place(grown, Vector2i(13, 16), "empty")
	_check(Sim.analyze(no_police).crime[14 * 32 + 12] > report.crime[14 * 32 + 12], "警察の犯罪抑制")
	var no_fire: Dictionary = Sim.place(grown, Vector2i(15, 16), "empty")
	_check(Sim.analyze(no_fire).fire_risk[16 * 32 + 17] > report.fire_risk[16 * 32 + 17], "消防の火災予防")
	var no_park: Dictionary = Sim.place(grown, Vector2i(11, 16), "empty")
	no_park.tiles[16 * 32 + 12] = {"terrain": "flat", "kind": "industrial", "level": 3, "age": 0}
	var with_park: Dictionary = no_park.duplicate(true)
	with_park.tiles[16 * 32 + 11].kind = "park"
	_check(
		(
			Sim.analyze(with_park).pollution[14 * 32 + 12]
			< Sim.analyze(no_park).pollution[14 * 32 + 12]
		),
		"公園で公害低減"
	)
	var overloaded: Dictionary = grown.duplicate(true)
	for x: int in range(8, 23):
		overloaded.tiles[14 * 32 + x] = {
			"terrain": "flat", "kind": "residential", "level": 3, "age": 0
		}
		overloaded.tiles[16 * 32 + x] = {
			"terrain": "flat", "kind": "residential", "level": 3, "age": 0
		}
	var overloaded_report: Dictionary = Sim.analyze(overloaded)
	_check(overloaded_report.power_used <= overloaded_report.capacity, "電力使用量は容量以下")
	_check(
		overloaded_report.warnings.any(func(item: String) -> bool: return item.begins_with("停電")),
		"容量不足で停電"
	)


func _check_endings(city: Dictionary) -> void:
	var winning: Dictionary = city.duplicate(true)
	for x: int in range(8, 11):
		winning = Sim.place(winning, Vector2i(x, 16), "residential")
	for step: int in 20:
		winning = Sim.advance_month(winning)
		print(
			(
				"検証: %d月 人口%d 雇用%d 資金%d %s"
				% [winning.month, winning.population, winning.jobs, winning.money, winning.outcome]
			)
		)
		if winning.outcome != "playing":
			break
	_check(
		winning.outcome == "clear" and winning.population >= Sim.GOAL_POPULATION, "通常建設と20月以内の目標到達"
	)
	_check(Sim.advance_month(winning) == winning, "クリア後は月停止")
	_check(Sim.place(winning, Vector2i(4, 8), "road") == winning, "クリア後は建設停止")
	var losing: Dictionary = city.duplicate(true)
	losing.tax = 0
	losing.money = 0
	for step: int in 3:
		losing = Sim.advance_month(losing)
	_check(losing.outcome == "defeat" and losing.negative_months == 3, "3月連続赤字で敗北")
	_check(Sim.advance_month(losing) == losing, "敗北後は月停止")
	_check(not Sim.decode_save(winning).is_empty(), "クリア保存")
	_check(not Sim.decode_save(losing).is_empty(), "敗北保存")


func _check_save(city: Dictionary) -> void:
	var encoded: String = JSON.stringify(city)
	var decoded: Dictionary = Sim.decode_save(JSON.parse_string(encoded))
	_check(decoded == city, "JSON 保存往復")
	_check(Sim.decode_save(null).is_empty(), "空の保存拒否")
	_check(Sim.decode_save([]).is_empty(), "不正な保存型拒否")
	for key: String in city:
		var missing: Dictionary = city.duplicate(true)
		missing.erase(key)
		_check(Sim.decode_save(missing).is_empty(), "必須保存キー欠落: " + key)
	var corrupt: Dictionary = city.duplicate(true)
	corrupt.tax = 8.5
	_check(Sim.decode_save(corrupt).is_empty(), "小数の税率拒否")
	corrupt = city.duplicate(true)
	corrupt.money = NAN
	_check(Sim.decode_save(corrupt).is_empty(), "NaN 拒否")
	corrupt = city.duplicate(true)
	corrupt.tiles[0].kind = "unknown"
	_check(Sim.decode_save(corrupt).is_empty(), "未知の建物拒否")
	corrupt = city.duplicate(true)
	corrupt.tiles.pop_back()
	_check(Sim.decode_save(corrupt).is_empty(), "タイル数不正拒否")
	corrupt = city.duplicate(true)
	corrupt.population = 999
	_check(Sim.decode_save(corrupt).is_empty(), "タイルと人口の不整合拒否")
	corrupt = city.duplicate(true)
	corrupt.outcome = "clear"
	_check(Sim.decode_save(corrupt).is_empty(), "未達成クリア拒否")


func _check_problem_regression(city: Dictionary) -> void:
	var grown: Dictionary = city.duplicate(true)
	for step: int in 9:
		grown = Sim.advance_month(grown)
	var no_police: Dictionary = Sim.place(grown, Vector2i(13, 16), "empty")
	var before: int = no_police.population
	no_police = Sim.advance_month(no_police)
	_check(no_police.population < before, "犯罪多発で住宅が退化")
	var polluted: Dictionary = Sim.place(grown, Vector2i(16, 16), "residential")
	polluted.tiles[16 * 32 + 16].level = 2
	polluted.tiles[16 * 32 + 16].age = 1
	_check(Sim.analyze(polluted).pollution[16 * 32 + 16] >= 55, "工場隣接住宅の公害")
	polluted = Sim.advance_month(polluted)
	_check(polluted.tiles[16 * 32 + 16].level == 1, "公害で住宅が退化")
	var unsafe: Dictionary = Sim.place(grown, Vector2i(15, 16), "empty")
	unsafe.tiles[16 * 32 + 17].age = 49
	var safe: Dictionary = unsafe.duplicate(true)
	safe.tiles[16 * 32 + 15].kind = "fire"
	_check(Sim.analyze(unsafe).fire_risk[16 * 32 + 17] >= 75, "老朽工業区画の火災危険")
	unsafe = Sim.advance_month(unsafe)
	safe = Sim.advance_month(safe)
	_check(unsafe.tiles[16 * 32 + 17].level < safe.tiles[16 * 32 + 17].level, "消防施設で退化予防")
	var recovery: Dictionary = grown.duplicate(true)
	recovery.money = -1
	recovery.negative_months = 1
	recovery = Sim.advance_month(recovery)
	_check(recovery.money >= 0 and recovery.negative_months == 0, "黒字復帰で赤字月数リセット")
	var excess_housing: Dictionary = grown.duplicate(true)
	excess_housing.jobs = 0
	_check(Sim.analyze(excess_housing).demand.r < Sim.analyze(grown).demand.r, "雇用不足で住宅需要減少")
