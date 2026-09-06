extends SceneTree
## シーンとアセットクレジットの検証。実行方法は Makefile の selfcheck target を参照。
## release ビルドで assert が消えるため、明示的な判定と exit code で結果を返す。

const StateScript: GDScript = preload("res://scripts/game_state.gd")
const Stage: GDScript = preload("res://scripts/stage_data.gd")
const Ship: GDScript = preload("res://scripts/ship_sprite.gd")
const TEST_SAVE: String = "res://tmp/selfcheck-save.json"

var failed: bool = false


func _initialize() -> void:
	_check_scenes("res://scenes")
	_check_assets_credited()
	_check_ship_animations()
	_check_game_state()
	_check_save_data()
	_check_waves()
	_check_attacks()
	_check_input_bindings()

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


func _check_ship_animations() -> void:
	var sheets: Array[Texture2D] = []
	for kind: String in ["player", "scout", "aim", "fan", "boss"]:
		var sprite: AnimatedSprite2D = Ship.new()
		sprite.setup(kind)
		_check(sprite.animation == &"idle" and sprite.is_playing(), kind + ": 初回は待機を再生")
		var frames: SpriteFrames = sprite.sprite_frames
		_check(frames != null, kind + ": フレーム資源が存在")
		if frames == null:
			sprite.free()
			continue
		var sheet: Texture2D = _check_ship_frames(frames, kind)
		_check(sheet != null and sheet not in sheets, kind + ": 他の機種と独立した画像")
		if sheet != null:
			sheets.append(sheet)
		sprite.set_pose("move")
		sprite.frame = 2
		sprite.setup(kind)
		_check(sprite.sprite_frames == frames, kind + ": 再初期化で同じフレーム資源を保持")
		_check(
			sprite.animation == &"move" and sprite.frame == 2 and sprite.is_playing(),
			kind + ": 再初期化で再生中の状態とフレームを巻き戻さない"
		)
		var second: AnimatedSprite2D = Ship.new()
		second.setup(kind)
		_check(second.sprite_frames == frames, kind + ": 同種の別個体もフレーム資源を共有")
		# tree 外の Node は即時解放する。共有 SpriteFrames の所有は機体スクリプトに残す。
		second.free()
		sprite.free()


func _check_ship_frames(frames: SpriteFrames, kind: String) -> Texture2D:
	var sheet: Texture2D = null
	var regions: Array[Rect2] = []
	var cell: Vector2 = Vector2(256, 160) if kind == "boss" else Vector2(128, 128)
	_check(frames.get_animation_names().size() == 5, kind + ": アニメーションは5状態")
	for pose: String in ["idle", "move", "attack", "hit", "death"]:
		var label: String = kind + "/" + pose
		_check(frames.has_animation(pose), label + ": 状態が存在")
		if not frames.has_animation(pose):
			continue
		_check(frames.get_frame_count(pose) == 4, label + ": 連続4フレームが存在")
		_check(frames.get_animation_speed(pose) > 0, label + ": 再生速度は正")
		if pose == "death":
			_check(not frames.get_animation_loop(pose), label + ": 死亡は繰り返さない")
		for index: int in range(frames.get_frame_count(pose)):
			var atlas: AtlasTexture = frames.get_frame_texture(pose, index) as AtlasTexture
			_check(atlas != null and atlas.atlas != null, label + ": シートから画像を切り出す")
			if atlas == null or atlas.atlas == null:
				continue
			if sheet == null:
				sheet = atlas.atlas
			_check(atlas.atlas == sheet, label + ": 同一機種の全状態は1枚のシートに収まる")
			var bounds: Rect2 = Rect2(Vector2.ZERO, atlas.atlas.get_size())
			_check(atlas.region.size == cell, label + ": 切り出しサイズを保持")
			_check(bounds.encloses(atlas.region), label + ": 切り出しがシート内に収まる")
			for existing: Rect2 in regions:
				_check(not existing.intersects(atlas.region), label + ": 各フレームは別領域")
			regions.append(atlas.region)
	_check(regions.size() == 20, kind + ": 全状態の20フレームを検証")
	return sheet


func _check_game_state() -> void:
	var state: Node = StateScript.new()
	state.save_path = TEST_SAVE
	_check(state.mode == state.Mode.TITLE, "起動時はタイトル")
	state.reset_run()
	_check(state.lives == 3 and state.bombs == 3 and state.power == 1, "開始時の装備")
	state.add_score(120)
	state.add_score(-100)
	_check(state.score == 120 and state.high_score == 120, "得点加算と負の加算の拒否")
	state.collect_item("power")
	_check(state.power == 2, "パワーアップ第1段階")
	state.collect_item("power")
	_check(state.power == 3, "パワーアップ第2段階")
	state.collect_item("power")
	_check(state.power == 3, "強化上限")
	for index: int in range(4):
		state.collect_item("bomb")
	_check(state.bombs == 5, "ボム補充上限")
	for index: int in range(5):
		_check(state.use_bomb(), "ボム残数があれば使用できる")
	_check(not state.use_bomb() and state.bombs == 0, "残数ゼロではボム不可")
	var score_before: int = state.score
	state.collect_item("score")
	_check(state.score == score_before + 500, "スコアアイテム")
	state.take_hit()
	_check(state.lives == 2 and state.power == 1, "被弾で残機減少・装備初期化")
	state.take_hit()
	state.take_hit()
	_check(state.mode == state.Mode.RESULT and not state.cleared, "残機ゼロで敗北")
	_check(not state.take_hit() and state.lives == 0, "結果中の被弾は無効")
	state.finish_run(true)
	_check(not state.cleared, "結果確定を繰り返しても上書きしない")
	_check(not state.use_bomb(), "結果中はボム不可")
	state.reset_run()
	_check(state.score == 0 and state.high_score > 0, "再開時も最高得点を保持")
	state.elapsed = 17.0
	state.reset_run()
	_check(state.elapsed == 0.0 and state.lives == 3, "再開の初期化は冪等")
	state.finish_run(true)
	_check(state.mode == state.Mode.RESULT and state.cleared, "ボス撃破でクリア")
	state.show_title()
	_check(state.mode == state.Mode.TITLE, "結果からタイトルへ戻る")
	state.free()


func _check_save_data() -> void:
	var state: Node = StateScript.new()
	state.save_path = TEST_SAVE
	state.high_score = 43210
	_check(state.save_high_score(), "最高得点の保存に成功する")
	state.high_score = 0
	state.load_high_score()
	_check(state.high_score == 43210, "保存後に最高得点を復元する")
	for payload: String in [
		"broken", "[]", "null", "{}", '{"high_score":-1}',
		'{"high_score":"9000"}', '{"high_score":1.5}',
		'{"high_score":true}', '{"high_score":1000000000}',
	]:
		_write_save(payload)
		state.high_score = 0
		state.load_high_score()
		_check(state.high_score == 0, "不正な保存内容を安全に無視: " + payload)
	_write_save('{"high_score":500}')
	state.high_score = 900
	state.load_high_score()
	_check(state.high_score == 900, "再読込で進行中の最高得点を下げない")
	state.reset_run()
	state.add_score(1200)
	state.show_title()
	state.high_score = 0
	state.load_high_score()
	_check(state.high_score == 1200, "プレイからタイトルへ戻る時に新記録を保存")
	state.reset_run()
	state.add_score(1800)
	state.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	state.high_score = 0
	state.load_high_score()
	_check(state.high_score == 1800, "ウィンドウを閉じる時に新記録を保存")
	state.save_path = "res://tmp/selfcheck-missing-directory/save.json"
	_check(not state.save_high_score(), "保存先が開けない場合は失敗を返す")
	state.high_score = 0
	state.load_high_score()
	_check(state.high_score == 0, "保存が存在しなくても開始できる")
	state.free()
	_check(DirAccess.remove_absolute(TEST_SAVE) == OK, "検証用保存を片付ける")


func _write_save(payload: String) -> void:
	var file: FileAccess = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	_check(file != null, "検証用保存を書き込める")
	if file != null:
		file.store_string(payload)


func _check_waves() -> void:
	var waves: Array[Dictionary] = Stage.waves()
	_check(waves.size() == 120, "ステージの敵数")
	_check(waves == Stage.waves(), "ウェーブ生成は決定的")
	var last_time: float = -1.0
	var kinds: Dictionary = {}
	var drops: Dictionary = {}
	for wave: Dictionary in waves:
		_check(wave.time >= last_time and wave.time < Stage.BOSS_TIME, "出現時刻の昇順と上限")
		_check(wave.x >= 320.0 and wave.x <= 960.0, "敵はプレイ領域に出現する")
		_check(wave.kind in ["scout", "aim", "fan"], "定義済みの敵機種")
		_check(wave.drop in ["", "power", "bomb", "score"], "定義済みのドロップ")
		var stats: Dictionary = Stage.enemy_stats(wave.kind)
		_check(stats.hp > 0 and stats.speed > 0, "敵の体力と移動速度は正")
		_check(stats.score > 0 and stats.shot_interval > 0, "敵の得点と射撃間隔は正")
		last_time = wave.time
		kinds[wave.kind] = true
		drops[wave.drop] = true
	_check(kinds.size() >= 3, "敵3種類がステージに登場する")
	_check(drops.size() == 4, "すべてのアイテムがステージに登場する")
	_check(Stage.enemy_stats("unknown").is_empty(), "未定義の機種は無効")


func _check_attacks() -> void:
	var origin: Vector2 = Vector2(640.0, 100.0)
	var target: Vector2 = Vector2(800.0, 600.0)
	var aimed: Array[Vector2] = Stage.bullet_velocities("aim", origin, target)
	_check(aimed.size() == 1, "自機狙い弾の数")
	_check(aimed[0].normalized().is_equal_approx(origin.direction_to(target)), "自機狙いの方向")
	_check(Stage.bullet_velocities("aim", origin, origin)[0].y > 0, "同座標でも弾速を失わない")
	var fan: Array[Vector2] = Stage.bullet_velocities("fan", origin, target)
	_check(fan.size() == 3 and fan[0].x * fan[2].x < 0, "扇状弾は左右に広がる")
	var first: Array[Vector2] = Stage.bullet_velocities("boss", origin, target, 1)
	var second: Array[Vector2] = Stage.bullet_velocities("boss", origin, target, 2)
	_check(second.size() > first.size(), "ボス後半では攻撃が変化する")
	_check(Stage.boss_phase(Stage.BOSS_HP) == 1, "ボス開始時は第1段階")
	_check(Stage.boss_phase(180) == 2 and Stage.boss_phase(1) == 2, "半分以下で第2段階")
	for pattern: String in ["straight", "aim", "fan", "boss"]:
		for velocity: Vector2 in Stage.bullet_velocities(pattern, origin, target):
			_check(velocity.is_finite() and velocity.length() > 0, "敵弾の速度は有限かつ正")
	_check(Stage.bullet_velocities("unknown", origin, target).is_empty(), "未知の弾は生成しない")


func _check_input_bindings() -> void:
	for action: String in [
		"move_left", "move_right", "move_up", "move_down", "shoot", "bomb", "start", "pause"
	]:
		_check(InputMap.has_action(action), "操作を定義: " + action)
		var has_keyboard: bool = false
		var has_gamepad: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			has_keyboard = has_keyboard or event is InputEventKey
			has_gamepad = (
				has_gamepad or event is InputEventJoypadButton or event is InputEventJoypadMotion
			)
		_check(has_keyboard and has_gamepad, "キーボードとゲームパッドの両方を割当: " + action)
	var fullscreen: InputEventKey = InputEventKey.new()
	fullscreen.physical_keycode = KEY_F11
	_check(InputMap.action_has_event("fullscreen", fullscreen), "F11で全画面切替")
