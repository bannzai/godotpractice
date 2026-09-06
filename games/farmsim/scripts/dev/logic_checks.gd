extends RefCounted
## UI に依存せず、畑・暦・経済・保存の境界を検証する。

const FarmState: GDScript = preload("res://scripts/farm_state.gd")
const TEST_SAVE: String = "res://tmp/logic-check-save.json"

var _failures: Array[String] = []
var _checks: int = 0


func run() -> Array[String]:
	_failures.clear()
	_checks = 0
	_check_initial_and_invalid_actions()
	_check_growth_and_tools()
	_check_all_crops()
	_check_season_transition()
	_check_shipping_and_outcomes()
	_check_clock_and_exhaustion()
	_check_shop_and_food()
	_check_save_round_trip()
	_check_walkable_save_positions()
	_check_corrupt_saves()
	_check_save_files()
	print("農場ロジック: %d 件を検証" % _checks)
	return _failures.duplicate()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _check_initial_and_invalid_actions() -> void:
	var farm: Node = FarmState.new()
	_check(farm.day == 1 and farm.season() == "spring", "初日は春の 1 日目")
	_check(farm.money == 120 and farm.food == 3 and farm.stamina == 100, "開始時の所持品と体力")
	_check(farm.seeds.turnip == 8 and farm.seeds.carrot == 4, "開始時の種")
	_check(farm.tiles.size() == 24 and farm.player_position == Vector2(416, 272), "畑の数と初期位置")
	var initial: Dictionary = farm.to_dict()
	farm.reset()
	_check(farm.to_dict() == initial, "初期化を繰り返しても同じ状態")
	_check(not farm.use_tool(-1).ok and not farm.use_tool(24).ok, "畑の範囲外は操作できない")
	_check(farm.to_dict() == initial, "範囲外操作は状態を変えない")
	for tool: int in [1, 2, 3]:
		farm.selected_tool = tool
		_check(not farm.use_tool(0).ok, "未耕作地で道具 %d は使えない" % tool)
	_check(farm.stamina == 100, "無効な操作では体力を減らさない")
	farm.free()


func _check_growth_and_tools() -> void:
	var farm: Node = FarmState.new()
	_check(farm.use_tool(0).ok and farm.tiles[0].tilled, "クワで耕せる")
	_check(not farm.use_tool(0).ok and farm.stamina == 96, "耕した土の再操作では体力を使わない")
	farm.selected_tool = 2
	_check(farm.use_tool(0).ok and farm.seeds.turnip == 7, "種を植えると種を 1 個使う")
	_check(farm.crop_stage(0) == 0, "植えた直後は種の画像段階")
	_check(not farm.use_tool(0).ok and farm.seeds.turnip == 7, "重複した植え付けを拒否")
	farm.selected_tool = 0
	_check(not farm.use_tool(0).ok, "育成中の作物をクワで上書きしない")
	farm.advance_day()
	_check(farm.tiles[0].growth == 0, "水を与えない日は成長しない")
	farm.selected_tool = 1
	_check(farm.use_tool(0).ok, "植えた作物に水を与えられる")
	_check(farm.tiles[0].growth == 0 and farm.crop_stage(0) == 1, "水を与えた直後は日数を進めない")
	_check(not farm.use_tool(0).ok and farm.stamina == 97, "同じ日の二重水やりでは体力を使わない")
	farm.advance_day()
	_check(farm.tiles[0].growth == 1 and farm.crop_stage(0) == 2, "水やりした日の翌朝に一段成長")
	_check(not farm.tiles[0].watered, "翌朝は畑が乾燥する")
	farm.selected_tool = 3
	_check(not farm.use_tool(0).ok, "成長途中の作物は収穫できない")
	farm.selected_tool = 1
	farm.use_tool(0)
	farm.advance_day()
	_check(farm.crop_stage(0) == 3, "かぶは二回の水やりで収穫可能")
	farm.selected_tool = 3
	_check(farm.use_tool(0).ok and farm.harvested.turnip == 1, "収穫すると所持品に入る")
	_check(farm.crop_stage(0) == -1 and farm.tiles[0].tilled, "収穫後も耕した土を使える")
	_check(not farm.use_tool(0).ok and farm.harvested.turnip == 1, "二重収穫で増殖しない")
	farm.selected_tool = 1
	farm.use_tool(0)
	farm.selected_tool = 2
	farm.use_tool(0)
	farm.advance_day()
	_check(farm.tiles[0].growth == 1, "植える前に与えた水でも翌朝成長する")
	farm.free()


func _check_all_crops() -> void:
	for crop: String in FarmState.CROPS:
		var farm: Node = FarmState.new()
		if FarmState.CROPS[crop].season == "summer":
			farm.day = 11
		farm.seeds[crop] = 1
		farm.selected_crop = crop
		farm.use_tool(0)
		farm.selected_tool = 2
		_check(farm.use_tool(0).ok, "%s を対応する季節に植えられる" % crop)
		for growth: int in range(int(FarmState.CROPS[crop].days)):
			farm.selected_tool = 1
			farm.use_tool(0)
			farm.advance_day()
			_check(farm.tiles[0].growth == growth + 1, "%s の成長日数 %d" % [crop, growth + 1])
		farm.selected_tool = 3
		_check(farm.use_tool(0).ok and farm.harvested[crop] == 1, "%s を収穫できる" % crop)
		farm.free()


func _check_season_transition() -> void:
	var farm: Node = FarmState.new()
	farm.day = 10
	farm.use_tool(0)
	farm.selected_tool = 2
	farm.use_tool(0)
	farm.selected_tool = 1
	farm.use_tool(0)
	farm.advance_day()
	_check(farm.day == 11 and farm.season() == "summer", "春 10 日の次は夏 1 日")
	_check(farm.tiles[0].withered and farm.crop_stage(0) == 4, "春の作物は夏に枯れる")
	_check(not farm.tiles[0].watered, "枯れた作物の土も乾く")
	farm.selected_tool = 3
	_check(not farm.use_tool(0).ok, "枯れた作物は収穫できない")
	farm.selected_tool = 1
	_check(not farm.use_tool(0).ok, "枯れた作物には水を使わない")
	farm.selected_tool = 0
	_check(farm.use_tool(0).ok and farm.tiles[0].crop == "", "クワで枯れた作物を片づけられる")
	farm.selected_tool = 2
	_check(not farm.use_tool(0).ok and farm.seeds.turnip == 7, "季節外の種は消費せず植え付け拒否")
	farm.free()


func _check_shipping_and_outcomes() -> void:
	var farm: Node = FarmState.new()
	_check(not farm.ship_all().ok, "空の所持品は出荷できない")
	farm.harvested.turnip = 2
	_check(farm.ship_all().amount == 120, "出荷予定額は売値と個数から計算")
	_check(farm.money == 120 and farm.shipping.turnip == 2, "出荷直後は所持金を増やさない")
	_check(farm.harvested.turnip == 0 and farm.shipped.turnip == 0, "箱への移動と翌朝精算を区別")
	farm.advance_day()
	_check(farm.money == 240 and farm.earned == 120, "翌朝に所持金と累計売上が増える")
	_check(farm.shipping.turnip == 0 and farm.shipped.turnip == 2, "出荷履歴を残して箱を空にする")
	farm.advance_day()
	_check(farm.money == 240 and farm.earned == 120, "同じ出荷を翌々朝に二重精算しない")
	farm.reset()
	farm.shipping.carrot = 8
	farm.advance_day()
	_check(farm.phase == "win" and farm.money == 920, "所持金の目標で勝利")
	var finished: Dictionary = farm.to_dict()
	farm.advance_day()
	farm.tick(1000.0)
	_check(farm.to_dict() == finished, "結果が確定した後は日付を進めない")
	farm.reset()
	farm.day = 14
	for crop: String in FarmState.CROPS:
		farm.shipping[crop] = 1
	farm.advance_day()
	_check(farm.phase == "win" and farm.money < 900, "全四作物の出荷でも勝利")
	farm.reset()
	farm.day = 20
	farm.advance_day()
	_check(farm.phase == "loss" and farm.day == 20, "20 日の終了で目標未達なら結果画面")
	farm.reset()
	farm.day = 20
	farm.shipping.carrot = 8
	farm.advance_day()
	_check(farm.phase == "win" and farm.money == 920, "最終日の出荷も精算してから勝敗判定")
	farm.free()


func _check_clock_and_exhaustion() -> void:
	var farm: Node = FarmState.new()
	_check(farm.clock_text() == "06:00", "朝の表示")
	farm.tick(60.0)
	_check(farm.minutes == 660.0 and farm.clock_text() == "11:00", "実時間 60 秒で 5 時間")
	farm.minutes = 1500.0
	_check(farm.clock_text() == "01:00", "深夜の表示を 24 時間で折り返す")
	farm.reset()
	farm.tick(240.0)
	_check(farm.day == 2 and farm.minutes == 360.0, "実時間 240 秒で深夜 2 時に翌日へ")
	_check(farm.money == 108 and farm.stamina == 100, "夜更かしの罰金と翌朝の体力回復")
	farm.reset()
	farm.stamina = 4
	farm.player_position = Vector2(800, 500)
	_check(farm.use_tool(0).advanced_day, "道具使用で体力が尽きると翌日へ")
	_check(farm.tiles[0].tilled and farm.day == 2, "最後の道具操作を反映してから翌日へ")
	_check(farm.money == 108 and farm.stamina == 100, "体力切れでは所持金の 10% を失い回復")
	_check(farm.player_position == Vector2(416, 272), "翌朝は安全な初期位置へ戻る")
	var before: Dictionary = farm.to_dict()
	farm.tick(-1.0)
	farm.tick(NAN)
	farm.tick(INF)
	_check(farm.to_dict() == before, "不正な経過時間は状態を変えない")
	farm.free()


func _check_shop_and_food() -> void:
	var farm: Node = FarmState.new()
	_check(not farm.eat().ok and farm.food == 3, "満腹時は食べ物を使わない")
	farm.stamina = 85
	_check(farm.eat().amount == 15 and farm.stamina == 100, "食事は最大体力を超えない")
	farm.stamina = 40
	_check(farm.eat().amount == 30 and farm.stamina == 70, "お弁当で体力を 30 回復")
	_check(farm.buy_food().ok and farm.food == 2 and farm.money == 85, "お弁当を買える")
	_check(farm.buy_seed("turnip").ok and farm.seeds.turnip == 9, "種を一つ買える")
	_check(farm.money == 70, "購入額を所持金から引く")
	_check(not farm.buy_seed("tomato").ok, "季節外の種は販売しない")
	_check(not farm.buy_seed("unknown").ok, "存在しない作物は販売しない")
	farm.money = 0
	var before: Dictionary = farm.to_dict()
	_check(not farm.buy_food().ok and not farm.buy_seed("carrot").ok, "所持金不足の購入を拒否")
	_check(farm.to_dict() == before, "購入失敗で所持品を変えない")
	farm.food = 0
	_check(not farm.eat().ok and farm.stamina == 70, "食べ物なしでは回復しない")
	farm.free()


func _check_save_round_trip() -> void:
	var farm: Node = FarmState.new()
	farm.use_tool(0)
	farm.selected_tool = 2
	farm.use_tool(0)
	farm.selected_tool = 1
	farm.use_tool(0)
	farm.minutes = 900.25
	farm.player_position = Vector2(678.5, 420.25)
	farm.facing = Vector2(-1, 1).normalized()
	farm.harvested.carrot = 2
	farm.shipping.turnip = 1
	var original: Dictionary = farm.to_dict()
	var restored: Node = FarmState.new()
	_check(restored.from_dict(JSON.parse_string(JSON.stringify(original))), "JSON 保存を読み込める")
	_check(restored.to_dict() == original, "畑・所持品・時間・位置・向きを復元する")
	_check(restored.from_dict(original) and restored.from_dict(original), "同じデータを繰り返し復元できる")
	_check(restored.to_dict() == original, "復元は冪等")
	var exported: Dictionary = restored.to_dict()
	exported.tiles[0].growth = 2
	exported.seeds.turnip = 999
	_check(restored.to_dict() == original, "書き出した辞書は状態の参照を共有しない")
	restored.free()
	farm.free()


func _check_corrupt_saves() -> void:
	var farm: Node = FarmState.new()
	var original: Dictionary = farm.to_dict()
	var bad_fields: Dictionary = {
		"version": [0, 2, "1", true], "day": [0, 21, 1.5, "2", true],
		"minutes": [359.9, 1560, NAN, INF, "360"], "stamina": [0, 101, 1.5, false],
		"money": [-1, 1.5, "100", true], "food": [-1, 0.5], "selected_tool": [-1, 4, "0"],
		"selected_crop": ["unknown", 0], "position": [[0, 0], [64, 199], [929, 300], [INF, 300]],
		"facing": [[0, 0], [1, 1], ["0", 1]], "tiles": [[], {}, null],
		"seeds": [{}, {"turnip": -1, "carrot": 0, "tomato": 0, "corn": 0}],
		"harvested": [null], "shipping": [false], "shipped": [1],
		"earned": [-1, 1.5], "phase": ["unknown", "win", "loss", 0],
	}
	for field: String in bad_fields:
		for bad: Variant in bad_fields[field]:
			var malformed: Dictionary = original.duplicate(true)
			malformed[field] = bad
			_check(not farm.from_dict(malformed), "破損した保存フィールド %s を拒否" % field)
			_check(farm.to_dict() == original, "破損した %s を反映しない" % field)
	for field: String in original:
		var missing: Dictionary = original.duplicate(true)
		missing.erase(field)
		_check(not farm.from_dict(missing), "保存フィールド %s の欠落を拒否" % field)
	_check(not farm.from_dict(null) and not farm.from_dict([]), "辞書でない保存を拒否")
	_check_bad_tiles(farm, original)
	farm.free()


func _check_walkable_save_positions() -> void:
	var farm: Node = FarmState.new()
	var original: Dictionary = farm.to_dict()
	for at: Vector2 in [
		Vector2(416, 272), Vector2(176, 302), Vector2(302, 275), Vector2(865, 418),
		Vector2(876, 256), Vector2(927, 559), Vector2(64, 200),
	]:
		var valid: Dictionary = original.duplicate(true)
		valid.position = [at.x, at.y]
		_check(farm.can_walk(at), "農場の入口と施設前を歩ける %s" % at)
		_check(farm.from_dict(valid), "歩行可能な位置から再開できる %s" % at)
	farm.reset()
	for at: Vector2 in [
		Vector2(120, 220), Vector2(302, 220), Vector2(865, 385), Vector2(100, 500),
		Vector2(250, 490), Vector2(928, 300), Vector2(416, 560), Vector2(850, 200),
	]:
		var invalid: Dictionary = original.duplicate(true)
		invalid.position = [at.x, at.y]
		_check(not farm.can_walk(at), "建物・池・世界の外へ歩けない %s" % at)
		_check(not farm.from_dict(invalid), "閉じ込められる保存位置を拒否 %s" % at)
		_check(farm.to_dict() == original, "不正な保存位置は現在地を変えない")
	farm.free()


func _check_bad_tiles(farm: Node, original: Dictionary) -> void:
	var bad_tiles: Array[Variant] = [
		null, {}, {"tilled": true, "watered": false, "crop": "unknown", "growth": 0, "withered": false},
		{"tilled": false, "watered": true, "crop": "", "growth": 0, "withered": false},
		{"tilled": false, "watered": false, "crop": "turnip", "growth": 0, "withered": false},
		{"tilled": true, "watered": false, "crop": "turnip", "growth": 3, "withered": false},
		{"tilled": true, "watered": false, "crop": "turnip", "growth": 1.5, "withered": false},
		{"tilled": true, "watered": false, "crop": "turnip", "growth": 0, "withered": true},
		{"tilled": true, "watered": false, "crop": "tomato", "growth": 0, "withered": false},
		{"tilled": true, "watered": false, "crop": "", "growth": 1, "withered": false},
	]
	for tile: Variant in bad_tiles:
		var malformed: Dictionary = JSON.parse_string(JSON.stringify(original))
		malformed.tiles[23] = tile
		_check(not farm.from_dict(malformed), "畑の末尾の破損も拒否")
		_check(farm.to_dict() == original, "畑を部分的に復元しない")


func _check_save_files() -> void:
	var farm: Node = FarmState.new()
	_check(farm.save_game(TEST_SAVE), "保存ファイルへ書き込める")
	farm.money = 80
	farm.minutes = 540.0
	_check(farm.save_game(TEST_SAVE), "既存の保存ファイルを更新できる")
	farm.reset()
	_check(farm.load_game(TEST_SAVE), "保存ファイルを読める")
	_check(farm.money == 80 and farm.minutes == 540.0, "最後に保存した状態を復元する")
	var before: Dictionary = farm.to_dict()
	var file: FileAccess = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	if file != null:
		file.store_string("{途中で壊れた JSON")
		file.close()
	_check(not farm.load_game(TEST_SAVE), "壊れた JSON ファイルの読み込みを拒否")
	_check(farm.to_dict() == before, "ファイルの読み込み失敗はプレイを変えない")
	DirAccess.remove_absolute(TEST_SAVE)
	_check(not farm.load_game(TEST_SAVE), "存在しない保存ファイルを拒否")
	farm.free()
