extends SceneTree
## シーンとアセットクレジットの検証。実行方法は Makefile の selfcheck target を参照。
## release ビルドで assert が消えるため、明示的な判定と exit code で結果を返す。

const Course = preload("res://scripts/course_data.gd")
const State = preload("res://scripts/race_state.gd")
const Main = preload("res://scripts/main.gd")

var failed := false


func _initialize() -> void:
	_check_scenes("res://scenes")
	_check_assets_credited()
	_check_course()
	_check_race()
	_check_items_and_drift()
	_check_checkpoints_and_save()
	_check_timestep_and_driving()
	_check_routes_and_collisions()

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


func _check_course() -> void:
	_check(Course.sample(0.0).is_equal_approx(Course.sample(Course.LENGTH)), "コースが閉じる")
	_check(is_equal_approx(Course.tangent(30.0).length(), 1.0), "進行方向が正規化される")
	_check(Course.right(0.0).x > 0.99, "横方向の正が外側を向く")
	_check(Course.sample(30.0).y > Course.sample(90.0).y, "コースに坂がある")
	var previous: float = 0.0
	for checkpoint: float in Course.CHECKPOINTS:
		_check(checkpoint > previous and checkpoint <= Course.LENGTH, "チェックポイントが順序通り")
		previous = checkpoint
	_check(previous == Course.LENGTH, "最後のチェックポイントがゴール")
	for objects: Array[Dictionary] in [Course.ITEM_BOXES, Course.DASH_PADS]:
		for object: Dictionary in objects:
			_check(object.progress > 0.0 and object.progress < Course.LENGTH, "配置物が周回内にある")
			_check(absf(object.lateral) < Course.ROAD_WIDTH * 0.5, "配置物が路面にある")
	_check(Course.on_shortcut(105.0, -7.0), "内側のショートカットを認識")
	_check(not Course.on_shortcut(10.0, -7.0), "通常区間はショートカットにならない")
	_check(Course.is_on_surface(105.0, -8.0), "ショートカットの板上は路面")
	_check(not Course.is_on_surface(160.0, 7.0), "柵のない本線の外は海")
	_check(not Course.is_on_surface(118.0, -7.0), "板の終端の先は海")


func _check_race() -> void:
	var state: Node = State.new()
	state.save_enabled = false
	state.enter_menu_phase("garage")
	_check(state.phase == "garage", "タイトルからガレージへ遷移")
	state.enter_menu_phase("tutorial")
	_check(state.phase == "tutorial", "ガレージからチュートリアルへ遷移")
	state.enter_menu_phase("invalid")
	_check(state.phase == "tutorial", "未定義のメニュー状態を拒否")
	state.reset_race()
	_check(state.racers.size() == 4, "プレイヤーと CPU 3 台")
	_check(state.phase == "countdown", "開始前はカウントダウン")
	state.tick(2.0, 1.0, 0.0, false, false)
	_check(state.racers[0].speed == 0.0, "カウントダウン中は走らない")
	state.tick(1.0, 1.0, 0.0, false, false)
	_check(state.phase == "racing", "カウントダウン終了でレース")
	for _frame: int in range(6000):
		var lateral: float = state.racers[0].lateral
		state.tick(1.0 / 60.0, 1.0, clampf(-lateral * 0.5 - 0.08, -1.0, 1.0), false, true)
		if state.phase == "results":
			break
	_check(state.phase == "results", "実時間積分で全車 3 周完走し結果へ")
	for racer: Dictionary in state.racers:
		_check(racer.finish_time > 20.0, "完走タイムが走行を反映")
		_check(racer.lap_times.size() == Course.LAPS, "3 周のラップタイム")
		_check(racer.checkpoint_count == 12, "全チェックポイントを通過")
	var sorted: Array[Dictionary] = state.results()
	for i: int in range(1, sorted.size()):
		_check(sorted[i - 1].finish_time <= sorted[i].finish_time, "結果がゴール時刻順")
	state.return_to_title()
	_check(state.phase == "title", "結果からタイトルへ戻る")
	state.reset_race()
	_check(state.elapsed == 0.0 and state.racers[0].item == 0, "再走時にレース状態を初期化")
	state.free()


func _check_timestep_and_driving() -> void:
	var fine: Node = State.new()
	var coarse: Node = State.new()
	for state: Node in [fine, coarse]:
		state.save_enabled = false
		state.reset_race()
		state.tick(3.0, 0.0, 0.0, false, false)
	for _frame: int in range(60):
		fine.tick(1.0 / 60.0, 1.0, 0.0, false, false)
	coarse.tick(1.0, 1.0, 0.0, false, false)
	_check(is_equal_approx(fine.racers[0].progress, coarse.racers[0].progress),
		"1 秒のフレーム落ちでも通常フレームと同じ距離")
	_check(is_equal_approx(fine.racers[0].speed, coarse.racers[0].speed),
		"1 秒のフレーム落ちでも通常フレームと同じ速度")
	coarse.tick(4.0, -1.0, 0.0, false, false)
	_check(coarse.racers[0].speed < 0.0 and coarse.racers[0].wrong_way, "ブレーキ後はバック走行")
	fine.reset_race()
	coarse.reset_race()
	fine.racers[1].progress = -100.0
	coarse.racers[1].progress = 100.0
	for state: Node in [fine, coarse]:
		state.racers[0].progress = 0.0
		state.racers[1].speed = 25.0
		state.racers[1].lateral = 0.0
		state._drive(1, 0.5, 1.0, 0.0, false)
	_check(fine.racers[1].speed > coarse.racers[1].speed, "後方 CPU は前方 CPU より速度補正が高い")
	fine.free()
	coarse.free()


func _check_items_and_drift() -> void:
	var state: Node = State.new()
	state.save_enabled = false
	state.reset_race()
	state.tick(3.0, 0.0, 0.0, false, false)
	state.racers[0].item = 1
	state.use_item(0)
	_check(state.projectiles.size() == 1 and state.racers[0].item == 0, "飛び道具を消費して発射")
	state.racers[1].progress = state.projectiles[0].progress
	state.racers[1].lateral = state.projectiles[0].lateral
	state.racers[1].speed = 20.0
	state.racers[1].drifting = true
	state.racers[1].drift_charge = 0.8
	state.racers[1].drift_direction = 1.0
	state._update_weapons(0.0)
	_check(state.racers[1].spin > 0.0 and state.racers[1].speed == 6.0, "飛び道具でスピンと減速")
	_check(not state.racers[1].drifting and state.racers[1].drift_charge == 0.0
		and state.racers[1].drift_direction == 0.0, "被弾時にドリフト蓄積を破棄")
	state._update_drift(1, 0.01, 0.0, false)
	_check(state.racers[1].boost == 0.0, "被弾直後のドリフト解除ではブーストしない")
	_check(state.projectiles.is_empty(), "命中した飛び道具は消える")
	state.racers[0].item = 2
	state.use_item(0)
	_check(state.obstacles.size() == 1 and state.obstacles[0].progress < 0.0, "後方に障害物")
	state.racers[0].item = 3
	state.use_item(0)
	_check(state.racers[0].boost > 2.0, "加速アイテムでブースト")
	state.racers[0].boost = 0.0
	state.racers[0].speed = 15.0
	state._update_drift(0, 0.8, -1.0, true)
	state._update_drift(0, 0.01, 0.0, false)
	_check(state.racers[0].boost > 0.7, "持続ドリフトの解除でブースト")
	state.racers[0].boost = 0.0
	state._update_drift(0, 0.2, 1.0, true)
	state._update_drift(0, 0.01, 0.0, false)
	_check(state.racers[0].boost == 0.0, "短すぎるドリフトはブーストしない")
	state.racers[0].lateral = 8.0
	state.racers[0].progress = 20.0
	state.racers[0].speed = 20.0
	state._drive(0, 0.01, 1.0, 1.0, false)
	_check(state.racers[0].speed < 15.0, "壁への衝突で減速")
	state.racers[0].progress = 160.0
	state.racers[0].last_checkpoint = 122.0
	state.racers[0].lateral = 11.0
	state._drive(0, 0.01, 1.0, 1.0, false)
	_check(state.racers[0].progress == 122.0, "落下時は直前チェックポイントへ復帰")
	_check(state.racers[0].respawn_timer > 0.0, "復帰には時間ペナルティ")
	_check(Main.respawn_lift(0.55) > 3.9, "復帰演出は路面より上へ持ち上がる")
	_check(Main.respawn_lift(0.0) == 0.0, "復帰演出の終了時は路面へ戻る")
	state.free()


func _check_routes_and_collisions() -> void:
	for kind: int in range(State.KARTS.size()):
		var state: Node = State.new()
		state.save_enabled = false
		state.selected_kart = kind
		state.reset_race()
		state.tick(3.0, 0.0, 0.0, false, false)
		for racer: Dictionary in state.racers:
			racer.progress = -float(racer.id) * 0.3
			racer.lateral = 0.0
		for _frame: int in range(4500):
			var lateral: float = state.racers[0].lateral
			state.tick(1.0 / 30.0, 1.0, clampf(-lateral * 0.5 - 0.08, -1.0, 1.0), false, true)
			if state.phase == "results":
				break
		_check(state.phase == "results", "車種 %d は接触が続く密集スタートでも全車完走" % kind)
		state.reset_race()
		state.tick(3.0, 0.0, 0.0, false, false)
		state.racers[0].progress = 95.0
		state.racers[0].lateral = -4.0
		state.racers[0].speed = 16.0
		for _frame: int in range(35):
			state.tick(1.0 / 60.0, 1.0, -1.0, false, false)
		_check(Course.on_shortcut(state.racers[0].progress, state.racers[0].lateral),
			"車種 %d はステア入力でショートカットへ入れる" % kind)
		_check(state.racers[0].respawn_timer == 0.0, "板上を走っている間は落下しない")
		state.free()


func _check_checkpoints_and_save() -> void:
	var state: Node = State.new()
	state.reset_race()
	state.racers[0].progress = 245.0
	state._update_checkpoints(0, 243.0)
	_check(state.racers[0].lap == 1, "途中を飛ばしたゴール通過は周回にならない")
	state.racers[0].progress = 60.0
	state._update_checkpoints(0, 62.0)
	_check(state.racers[0].checkpoint_count == 0, "逆走ではチェックポイントを通過しない")
	state.racers[0].progress = 62.0
	state._update_checkpoints(0, 60.0)
	_check(state.racers[0].checkpoint_count == 1, "正方向で最初のチェックポイントを通過")
	state._update_checkpoints(0, 60.0)
	_check(state.racers[0].checkpoint_count == 1, "同じ通過を重複計上しない")
	_check(State.parse_best(-1.0) == 0.0, "負の保存タイムを除外")
	_check(State.parse_best("42") == 0.0, "文字列の保存タイムを除外")
	_check(State.parse_best(INF) == 0.0, "無限大の保存タイムを除外")
	_check(State.parse_best(42.5) == 42.5, "正しい保存タイムを復元")
	state.save_enabled = false
	state.elapsed = 45.0
	state.racers[0].checkpoint_count = 11
	state.racers[0].next_checkpoint = 3
	state.racers[0].progress = Course.LENGTH * Course.LAPS + 1.0
	state._update_checkpoints(0, Course.LENGTH * Course.LAPS - 1.0)
	_check(state.best_time == 45.0 and state.racers[1].finish_time < 0.0,
		"他車の完走待ちをせずプレイヤーのゴール時点でベストを確定")
	state.free()
