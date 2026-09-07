extends SceneTree
## シーンとアセットクレジットの検証。実行方法は Makefile の selfcheck target を参照。
## release ビルドで assert が消えるため、明示的な判定と exit code で結果を返す。

const RunStateScript: GDScript = preload("res://scripts/run_state.gd")
const RoomScript: GDScript = preload("res://scripts/room.gd")

var failed: bool = false


func _initialize() -> void:
	_check_run_state()
	_check_stages_and_art_direction()
	_check_input_map()
	_check_scenes("res://scenes")
	_check_assets_credited()

	if failed:
		quit(1)
	else:
		print("selfcheck OK")
		quit(0)


func _check_run_state() -> void:
	var state: Node = RunStateScript.new()
	_check(state.phase == "title", "初期状態はタイトル")
	_check(not state.can_collect(0.1), "タイトル中は取得できない")
	state.collect(1.0)
	state.tick(10.0)
	_check(state.collected == 0 and state.remaining == state.TIME_LIMIT, "タイトル中は進行しない")
	state.start_run()
	_check(state.phase == "playing", "開始でプレイに遷移")
	_check(state.can_collect(state.diameter * state.COLLECT_RATIO), "巻き込み可能サイズの境界")
	_check(not state.can_collect(state.diameter * state.COLLECT_RATIO + 0.001), "境界より大きい物体")
	_check(not state.can_collect(0.0), "体積を持たない物体は取得できない")
	state.collect(-1.0)
	state.collect(0.0)
	_check(state.collected == 0, "無効な体積を無視")
	state.collect(0.12)
	state.collect(0.2)
	_check(state.collected == 2, "取得数は現在の付着物数")
	var initial_volume: float = PI * pow(state.INITIAL_DIAMETER, 3.0) / 6.0
	var grown_volume: float = PI * pow(state.diameter, 3.0) / 6.0
	_check(is_equal_approx(grown_volume, initial_volume + 0.32), "球と取得物の体積保存")
	_check(is_equal_approx(state.shed(), 0.2), "最後に付着した物体が脱落")
	_check(state.collected == 1, "脱落で付着物数が減少")
	grown_volume = PI * pow(state.diameter, 3.0) / 6.0
	_check(is_equal_approx(grown_volume, initial_volume + 0.12), "脱落後も体積保存")
	state.shed()
	_check(is_equal_approx(state.diameter, state.INITIAL_DIAMETER), "全脱落で初期直径に戻る")
	_check(state.shed() == 0.0 and state.collected == 0, "付着物なしの衝突で縮まない")
	_check_timeout(state)
	_check_success(state)
	state.reset()
	state.reset()
	_check(state.phase == "title" and state.collected == 0, "結果からタイトルへ戻り初期化")
	_check(state.remaining == state.TIME_LIMIT, "リセットで時間を復元")
	_check(state.diameter == state.INITIAL_DIAMETER, "リセットで直径を復元")
	state.free()


func _check_stages_and_art_direction() -> void:
	var state: Node = RunStateScript.new()
	state.open_stage_select()
	_check(state.phase == "stage_select", "タイトルから部屋選択に遷移")
	state.select_stage("playroom")
	_check(state.selected_stage == "playroom", "選んだ部屋を進行状態に保持")
	state.begin_tutorial()
	_check(state.phase == "tutorial" and not state.tutorial_seen, "初回チュートリアルを開始")
	state.finish_tutorial()
	state.start_run()
	_check(state.phase == "playing" and state.tutorial_seen, "チュートリアル完了後に開始")
	state.reset()
	_check(state.selected_stage == "playroom" and state.tutorial_seen,
		"タイトルへ戻っても選択と初回完了を保持")
	var atelier: Array[Dictionary] = RoomScript.item_layout("atelier")
	var playroom: Array[Dictionary] = RoomScript.item_layout("playroom")
	_check(RoomScript.STAGES.size() == 2, "選べる部屋が2つ")
	_check(atelier.size() >= 100 and playroom.size() >= 100, "両方の部屋に100個以上配置")
	_check(atelier[0].position != playroom[0].position, "部屋ごとに異なる配置")
	var clay_source: String = FileAccess.get_file_as_string(
		"res://scripts/visuals/clay_surface.gd"
	)
	_check(clay_source.contains("normal_texture") and clay_source.contains("ARRAY_COLOR"),
		"粘土表面に手続き法線と頂点カラー")
	var hud_source: String = FileAccess.get_file_as_string("res://scripts/hud.gd")
	_check(not hud_source.contains("移動  WASD / 左スティック"), "画面下の共通操作ガイドを廃止")
	state.free()


func _check_timeout(state: Node) -> void:
	state.tick(-1.0)
	_check(state.remaining == state.TIME_LIMIT, "負の時間で制限時間が増えない")
	state.tick(state.TIME_LIMIT - 0.01)
	_check(state.phase == "playing", "時間が残る間はプレイ継続")
	state.tick(0.02)
	_check(state.phase == "lost" and state.remaining == 0.0, "時間切れで失敗し時間をゼロに固定")
	state.collect(100.0)
	state.tick(1.0)
	_check(state.phase == "lost" and state.collected == 0, "失敗後は取得でクリアに変わらない")
	_check(state.shed() == 0.0, "失敗後は脱落しない")


func _check_success(state: Node) -> void:
	state.start_run()
	_check(state.phase == "playing" and state.remaining == state.TIME_LIMIT, "結果から再挑戦")
	state.tick(1.0)
	var goal_volume: float = PI / 6.0 * (
		pow(state.TARGET_DIAMETER, 3.0) - pow(state.INITIAL_DIAMETER, 3.0)
	)
	state.collect(goal_volume - 0.001)
	_check(state.phase == "playing", "目標直径未満はプレイ継続")
	state.collect(0.002)
	_check(state.phase == "won", "目標直径に到達したらクリア")
	var won_diameter: float = state.diameter
	var won_count: int = state.collected
	state.tick(state.TIME_LIMIT)
	state.collect(5.0)
	_check(state.shed() == 0.0, "クリア後は脱落しない")
	_check(state.diameter == won_diameter and state.collected == won_count, "クリア時の結果を保持")
	_check(state.remaining == state.TIME_LIMIT - 1.0, "クリア後の時間を保持")
	_check(not state.can_collect(0.1), "クリア後は取得できない")


func _check_input_map() -> void:
	for action: String in [
		"move_left", "move_right", "move_forward", "move_back",
		"camera_left", "camera_right", "confirm", "cancel", "fullscreen", "mute"
	]:
		_check(InputMap.has_action(action), "入力アクション: " + action)
		if not InputMap.has_action(action):
			continue
		var has_keyboard: bool = false
		var has_joypad: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			has_keyboard = has_keyboard or event is InputEventKey
			has_joypad = has_joypad or event is InputEventJoypadButton or event is InputEventJoypadMotion
		_check(has_keyboard, "キーボード入力: " + action)
		if action not in ["fullscreen", "mute"]:
			_check(has_joypad, "ゲームパッド入力: " + action)


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
