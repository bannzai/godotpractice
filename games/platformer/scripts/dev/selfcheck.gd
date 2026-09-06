extends SceneTree
## シーン・クレジット・進行ロジック・入力設定の検証。
## release ビルドで assert が消えるため、明示的な判定と exit code で結果を返す。

var failed: bool = false


func _initialize() -> void:
	_check_scenes("res://scenes")
	_check_assets_credited()
	_check_run_reset_and_rewards()
	_check_damage_and_game_over()
	_check_timer_and_pause()
	_check_stage_progression()
	_check_input_actions()
	_check_actor_animations()

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


## 各検証は独立した状態を生成し、tree に入れず最後に free する。
func _new_session() -> Node:
	var session: Node = load("res://scripts/session.gd").new()
	session.reset_run()
	return session


func _check_run_reset_and_rewards() -> void:
	var session: Node = _new_session()
	_check(session.lives == 3 and session.stage == 0, "新規開始: 残機3・ステージ1")
	_check(session.phase == "playing", "新規開始: プレイ状態")
	_check(session.seconds == 180.0, "新規開始: 制限時間180秒")
	session.collect_coin()
	session.collect_coin()
	_check(session.coins == 2 and session.score == 200, "コイン1枚で100点")
	session.collect_power()
	_check(session.powered and session.score == 700, "強化取得で500点")
	session.title()
	session.collect_coin()
	session.collect_power()
	_check(session.coins == 2 and session.score == 700, "タイトル中は取得できない")
	session.stage = 1
	session.seconds = 1.0
	session.lives = 1
	session.death_reason = "検証用"
	session.reset_run()
	session.reset_run()
	_check(session.lives == 3 and session.stage == 0, "再開始は何度呼んでも初期残機・ステージ")
	_check(session.coins == 0 and session.score == 0, "再開始でコイン・スコアを初期化")
	_check(not session.powered and session.invulnerable == 0.0, "再開始で強化・無敵を初期化")
	_check(session.seconds == 180.0 and session.death_reason == "", "再開始で時間・死亡理由を初期化")
	session.free()


func _check_damage_and_game_over() -> void:
	var session: Node = _new_session()
	session.collect_power()
	_check(session.damage() == "ignored", "強化取得直後は無敵")
	session.tick(1.3)
	_check(session.damage() == "shrunk", "強化中は通常接触に1回耐える")
	_check(not session.powered and session.lives == 3, "縮小では残機を消費しない")
	_check(session.damage() == "ignored", "縮小直後は連続被弾を無視")
	session.tick(2.0)
	_check(session.damage() == "dead", "無敵終了後の通常接触で死亡")
	_check(session.phase == "dead" and session.lives == 2, "死亡で残機を1だけ減らす")
	_check(session.damage(true) == "ignored" and session.lives == 2, "死亡中の再通知は無視")
	session.begin_stage()
	session.begin_stage()
	_check(session.lives == 2 and session.seconds == 180.0, "リトライで残機維持・時間初期化")
	_check(session.death_reason == "" and session.invulnerable == 0.0, "リトライで死亡状態を解除")
	session.collect_power()
	_check(session.damage(true, "落下") == "dead", "落下は強化・無敵を貫通")
	_check(not session.powered and session.death_reason == "落下", "落下で強化解除・理由記録")
	session.begin_stage()
	session.damage(true)
	_check(session.lives == 0 and session.phase == "game_over", "残機0でゲームオーバー")
	session.damage(true)
	_check(session.lives == 0, "ゲームオーバー後の死亡通知で残機を負にしない")
	session.free()


func _check_timer_and_pause() -> void:
	var session: Node = _new_session()
	session.collect_power()
	session.phase = "paused"
	session.tick(200.0)
	_check(session.seconds == 180.0 and session.lives == 3, "ポーズ中は時間・残機を維持")
	_check(session.invulnerable == 1.2, "ポーズ中は無敵時間を維持")
	_check(session.damage(true) == "ignored", "ポーズ中の死亡通知は無視")
	session.phase = "playing"
	session.seconds = 0.5
	session.tick(0.5)
	_check(session.seconds == 0.0 and session.phase == "dead", "時間が0になると死亡")
	_check(session.lives == 2 and session.death_reason == "時間切れ", "時間切れは強化・無敵を貫通")
	session.tick(5.0)
	_check(session.lives == 2 and session.seconds == 0.0, "時間切れの死亡処理は一度だけ")
	session.free()


func _check_stage_progression() -> void:
	var session: Node = _new_session()
	session.advance_stage()
	_check(session.stage == 0, "未クリアでは次のステージへ進めない")
	session.collect_coin()
	session.seconds = 12.2
	session.finish_stage()
	_check(session.phase == "stage_clear" and session.score == 230, "ゴールで残り時間を得点化")
	session.finish_stage()
	session.tick(10.0)
	_check(session.score == 230 and session.seconds == 12.2, "クリア後は再加点・時間進行なし")
	_check(session.damage(true) == "ignored", "クリア後は死亡しない")
	session.advance_stage()
	session.advance_stage()
	_check(session.stage == 1 and session.phase == "playing", "次のステージへの遷移は一度だけ")
	_check(session.score == 230 and session.coins == 1, "ステージ間で得点・コインを維持")
	_check(session.seconds == 180.0 and session.lives == 3, "次のステージで時間を初期化・残機維持")
	session.seconds = 2.0
	session.finish_stage()
	session.finish_stage()
	_check(session.phase == "complete" and session.score == 250, "最終ゴールで全体クリア・一度だけ加点")
	session.advance_stage()
	_check(session.stage == 1 and session.phase == "complete", "最終クリア後は存在しないステージへ進まない")
	session.free()


func _check_input_actions() -> void:
	for action: String in ["move_left", "move_right", "jump", "dash", "confirm", "pause"]:
		_check(InputMap.has_action(action), "入力: %s が存在する" % action)
		var has_keyboard: bool = false
		var has_gamepad: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			has_keyboard = has_keyboard or event is InputEventKey
			has_gamepad = (
				has_gamepad or event is InputEventJoypadButton or event is InputEventJoypadMotion
			)
		_check(has_keyboard and has_gamepad, "入力: %s にキーボードとパッドを設定" % action)
	var has_f11: bool = false
	for event: InputEvent in InputMap.action_get_events("fullscreen"):
		if event is InputEventKey:
			has_f11 = has_f11 or event.physical_keycode == KEY_F11
	_check(has_f11, "入力: 全画面切替は物理キーF11")
	var left: InputEventKey = InputEventKey.new()
	left.physical_keycode = KEY_LEFT
	var right: InputEventKey = InputEventKey.new()
	right.physical_keycode = KEY_RIGHT
	_check(InputMap.action_has_event("move_left", left), "入力: 左矢印は左移動に割り当てる")
	_check(InputMap.action_has_event("move_right", right), "入力: 右矢印は右移動に割り当てる")
	_check(not InputMap.action_has_event("move_right", left), "入力: 左矢印で右移動しない")
	_check(not InputMap.action_has_event("move_left", right), "入力: 右矢印で左移動しない")


func _check_actor_animations() -> void:
	var sheets: Array[Texture2D] = []
	for kind: String in ["player", "walker", "shell"]:
		var frames: SpriteFrames = ActorFrames.build(kind)
		_check(frames.get_animation_names().size() >= 4, "%s: 4種類以上の動作" % kind)
		var first: AtlasTexture = frames.get_frame_texture("idle", 0) as AtlasTexture
		_check(first != null and first.atlas != null, "%s: 専用シートが存在する" % kind)
		if first == null or first.atlas == null:
			continue
		_check(first.atlas not in sheets, "%s: 他キャラと画像を共有しない" % kind)
		sheets.append(first.atlas)
		for animation: StringName in frames.get_animation_names():
			_check(frames.get_frame_count(animation) == 6,
				"%s %s: 6フレームある" % [kind, animation])
			_check(frames.get_animation_speed(animation) > 0,
				"%s %s: 時間経過で再生する" % [kind, animation])
			if animation in [&"hurt", &"death", &"stomp"]:
				_check(not frames.get_animation_loop(animation),
					"%s %s: 一度再生して終了する" % [kind, animation])
			_check_animation_images(kind, animation, frames)


func _check_animation_images(kind: String, animation: StringName, frames: SpriteFrames) -> void:
	var distinct: Dictionary = {}
	for index: int in frames.get_frame_count(animation):
		var frame: AtlasTexture = frames.get_frame_texture(animation, index) as AtlasTexture
		var label: String = "%s %s のフレーム %d" % [kind, animation, index]
		_check(frame != null and frame.atlas != null, label + ": 画像をロードできる")
		if frame == null or frame.atlas == null:
			continue
		var bounds: Rect2 = Rect2(Vector2.ZERO, frame.atlas.get_size())
		var valid: bool = frame.region.has_area() and bounds.encloses(frame.region)
		_check(valid, label + ": 切り出し矩形が画像内に収まる")
		if not valid:
			continue
		var pixels: Image = frame.atlas.get_image().get_region(Rect2i(frame.region))
		_check(pixels.get_used_rect().has_area(), label + ": 透明な空画像ではない")
		distinct[hash(pixels.get_data())] = true
	_check(distinct.size() == 6, "%s %s: 6枚すべての描画が異なる" % [kind, animation])
