extends SceneTree
## シーンとアセットクレジットの検証。実行方法は Makefile の selfcheck target を参照。
## release ビルドで assert が消えるため、明示的な判定と exit code で結果を返す。

const Rules = preload("res://scripts/game_rules.gd")
const State = preload("res://scripts/run_state.gd")

var failed: bool = false


func _initialize() -> void:
	_check_gameplay()
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


func _check_gameplay() -> void:
	_check_spawn_table()
	var state: Node = State.new()
	_check(state.phase == "title", "最初はタイトル")
	state.start_run(42)
	_check(state.phase == "playing" and state.weapons.bolt == 1, "初期武器を持って開始")
	_check_motion_and_pause(state)
	_check_damage_and_retry(state)
	_check_growth(state)
	_check_combat_and_items(state)
	_check_finale(state)
	state.free()


func _check_spawn_table() -> void:
	var previous_time: float = -1.0
	var previous_count: int = 0
	var previous_interval: float = INF
	for stage: Dictionary in Rules.SPAWN_TABLE:
		var time: float = float(stage.time)
		_check(time > previous_time, "出現表の時刻が昇順")
		_check(int(stage.count) >= previous_count, "敵の出現数が減らない")
		_check(float(stage.interval) <= previous_interval, "出現間隔が短くなる")
		_check(Rules.spawn_stage(time) == stage, "出現表の境界で新編成へ切り替わる")
		if previous_time >= 0.0:
			_check(Rules.spawn_stage(time - 0.001).time == previous_time, "境界直前は前編成")
		for kind: int in stage.kinds:
			_check(kind >= 0 and kind < 3, "通常出現の敵種が有効")
		previous_time = time
		previous_count = int(stage.count)
		previous_interval = float(stage.interval)
	_check(Rules.spawn_stage(450.0).kinds.size() >= 3, "3 種類以上が出現")


func _check_motion_and_pause(state: Node) -> void:
	state.step(0.05, Vector2.ONE)
	_check(is_equal_approx(state.player_pos.length(), 11.5), "斜め移動を正規化")
	state.toggle_pause()
	var before: Vector2 = state.player_pos
	var elapsed_before: float = state.elapsed
	state.step(0.05, Vector2.RIGHT)
	_check(state.player_pos == before and state.elapsed == elapsed_before, "ポーズ中に進行しない")
	state.toggle_pause()
	_check(state.phase == "playing", "ポーズから再開")
	state.player_pos = Vector2.ONE * Rules.WORLD_LIMIT
	state.step(0.05, Vector2.ONE)
	_check(state.player_pos == Vector2.ONE * Rules.WORLD_LIMIT, "フィールド境界を越えない")


func _check_damage_and_retry(state: Node) -> void:
	state.start_run(42)
	state.take_damage(20.0)
	state.take_damage(20.0)
	_check(state.hp == 80.0, "連続接触は無敵時間で一回の被弾に制限")
	for _frame: int in range(17):
		state.step(0.05, Vector2.ZERO)
	state.take_damage(20.0)
	_check(state.hp == 60.0, "無敵時間終了後は再び被弾")
	state.invulnerable = 0.0
	state.take_damage(100.0)
	_check(state.phase == "result" and not state.won and state.hp == 0.0, "HP 0 で敗北")
	state.return_title()
	_check(state.phase == "title", "結果からタイトルに戻る")
	state.start_run(42)
	_check(state.hp == 100.0 and state.elapsed == 0.0 and state.kills == 0, "再開で成績を初期化")
	_check(state.enemies.is_empty() and state.effects.is_empty(), "再開で前回の実体を破棄")


func _check_growth(state: Node) -> void:
	state.gain_xp(Rules.xp_needed(1))
	_check(state.phase == "upgrade" and state.level == 2, "経験値でレベルアップして停止")
	_check(state.choices.size() == 3, "選択肢が 3 個")
	_check(state.choices[0] != state.choices[1] and state.choices[1] != state.choices[2]
		and state.choices[0] != state.choices[2], "候補に重複なし")
	var time: float = state.elapsed
	state.step(0.05, Vector2.RIGHT)
	_check(state.elapsed == time, "強化選択中は時間が止まる")
	state.choose_upgrade(-1)
	_check(state.phase == "upgrade", "不正な選択は無視")
	state.choose_upgrade(0)
	_check(state.phase == "playing", "強化後に再開")
	state.weapons = {"bolt": 3, "orbit": 3, "pulse": 3}
	state.move_speed = 350.0
	state.pickup_radius = 220.0
	state.gain_xp(Rules.xp_needed(state.level))
	_check(state.choices.size() == 3, "全武器最大でも 3 択を維持")
	for choice: String in state.choices:
		_check(choice in ["health", "power", "tempo"], "上限に達した強化は候補から除外")
	state.choose_upgrade(0)
	state.start_run(42)
	state.gain_xp(Rules.xp_needed(1) + Rules.xp_needed(2))
	state.choose_upgrade(0)
	_check(state.phase == "upgrade" and state.level == 3, "複数レベル分の経験値を失わない")
	state.choose_upgrade(0)
	_check(state.phase == "playing" and state.xp == 0, "保留した強化を選び終えて再開")


func _check_combat_and_items(state: Node) -> void:
	state.start_run(42)
	state.spawn_enemy(0, Vector2(130, 0))
	for _frame: int in range(10):
		state.step(0.05, Vector2.ZERO)
	_check(state.kills >= 1, "投射武器が自動で敵を狙って撃破")
	_check(not state.gems.is_empty() or state.xp > 0, "敵が経験値を落とす")
	state.start_run(42)
	state.weapons.orbit = 1
	state.spawn_enemy(0, state.orbit_position(0))
	state.enemies[0].hp = 1.0
	state.step(0.01, Vector2.ZERO)
	_check(state.kills >= 1, "周回武器の接触で撃破")
	state.start_run(42)
	state.weapons.pulse = 1
	state.spawn_enemy(0, Vector2(100, 0))
	state.step(0.01, Vector2.ZERO)
	_check(state.kills >= 1, "範囲武器が敵を撃破")
	state.start_run(42)
	state.hp = 40.0
	state.items.append({"pos": Vector2.ZERO, "kind": "heal"})
	state.items.append({"pos": Vector2.ZERO, "kind": "magnet"})
	state.gems.append({"pos": Vector2(400, 0), "value": 2})
	state.step(0.05, Vector2.ZERO)
	_check(state.hp == 70.0 and state.items.is_empty(), "回復アイテムを取得")
	_check(state.gems[0].pos.x < 400.0, "磁石が通常範囲外のジェムを吸引")
	for _frame: int in range(20):
		state.step(0.05, Vector2.ZERO)
	_check(state.xp == 2, "磁石で経験値を回収")
	state.start_run(42)
	for _frame: int in range(361):
		state.step(0.05, Vector2.RIGHT)
	var kinds: Array[String] = []
	for item: Dictionary in state.items:
		kinds.append(str(item.kind))
	_check("heal" in kinds and "magnet" in kinds, "両アイテムを定期供給")


func _check_finale(state: Node) -> void:
	state.start_run(42)
	state.elapsed = 569.98
	state.step(0.05, Vector2.ZERO)
	var bosses: int = 0
	for enemy: Dictionary in state.enemies:
		if int(enemy.kind) == 3:
			bosses += 1
	_check(bosses == 1 and state.boss_spawned, "終盤に強敵が出現")
	state.step(0.05, Vector2.ZERO)
	bosses = 0
	for enemy: Dictionary in state.enemies:
		if int(enemy.kind) == 3:
			bosses += 1
	_check(bosses == 1, "最終強敵は重複出現しない")
	state.elapsed = 599.98
	state.step(0.05, Vector2.ZERO)
	_check(state.phase == "result" and state.won, "10 分生存でクリア")
	_check(state.elapsed == Rules.DURATION, "結果の生存時間は 10 分")
	state.start_run(42)
	_check(not state.boss_spawned and not state.won, "再開で最終強敵・勝敗を初期化")
