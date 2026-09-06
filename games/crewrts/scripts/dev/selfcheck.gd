extends SceneTree
## シーンとアセットクレジットの検証。実行方法は Makefile の selfcheck target を参照。
## release ビルドで assert が消えるため、明示的な判定と exit code で結果を返す。

const Simulation = preload("res://scripts/simulation.gd")

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
	var game: Node = Simulation.new()
	game.start_day()
	_check(game.crew.size() == 30 and game.following_count() == 30, "30 体で開始")
	_check(game.remaining == 300.0 and game.collected == 0, "初期時刻と回収数")
	game.dismiss()
	game.dismiss()
	_check(game.following_count() == 0, "解散の再実行で状態が変わらない")
	game.whistle()
	_check(game.following_count() == 30, "範囲内の隊員を笛で呼ぶ")
	game.start_day()
	_check(game.crew.size() == 30 and game.cargo.size() == 5, "再開で状態を初期化")
	_check_throw(game)
	_check_transport(game)
	_check_combat(game)
	_check_navigation(game)
	_check_results(game)
	_check_play_route(game, false)
	_check_play_route(game, true)
	game.free()


func _check_throw(game: Node) -> void:
	game.start_day()
	game.selected_kind = 1
	game.throw_at(game.leader + Vector3(100, 0, 0))
	var thrown: Dictionary = game.crew[1]
	_check(thrown.state == "thrown" and thrown.kind == 1, "選択した青を 1 体だけ投げる")
	_check(game.following_count() == 29, "投擲で隊列を 1 体減らす")
	_check(thrown.aim.distance_to(game.leader) <= 10.001, "投擲距離を 10 に制限")
	game.step(0.25, Vector3.ZERO)
	_check(thrown.position.y > 2.0, "飛行中は放物線の高さを持つ")
	game.step(0.5, Vector3.ZERO)
	_check(thrown.flight == 0.0 and thrown.position.y == 0.0, "着地で地面に戻る")
	game.dismiss()
	game.throw_at(Vector3.ZERO)
	_check(game.following_count() == 0, "隊列が空なら投げない")
	game.start_day()
	game.crew[0].position = Vector3(22, 0, -22)
	game.dismiss()
	game.whistle()
	_check(game.crew[0].state == "idle", "笛は遠方の隊員を呼ばない")


func _throw_many(game: Node, point: Vector3, count: int, kind: int) -> void:
	game.selected_kind = kind
	for index: int in range(count):
		game.throw_at(point)
	game.step(0.6, Vector3.ZERO)


func _check_transport(game: Node) -> void:
	game.start_day()
	game.enemies.clear()
	game.leader = Vector3(-6, 0, 7)
	var item: Dictionary = game.cargo[0]
	var original: Vector3 = item.position
	_throw_many(game, item.position, 1, 1)
	game.step(1.0, Vector3.ZERO)
	_check(item.position == original, "必要人数未満では運搬物が動かない")
	_throw_many(game, item.position, 1, 1)
	game.step(1.0, Vector3.ZERO)
	_check(item.position.distance_to(original) > 2.0, "必要人数が揃うと運搬開始")
	game.whistle()
	var stopped: Vector3 = item.position
	game.step(1.0, Vector3.ZERO)
	_check(item.position == stopped, "笛で運搬から離れると停止")
	_throw_many(game, item.position, 2, 1)
	game.step(10.0, Vector3.ZERO)
	_check(game.collected == 1 and item.delivered, "拠点へ運ぶと回収")
	_check(game.crew.size() == 33, "回収で仲間を 3 体追加")
	game.step(5.0, Vector3.ZERO)
	_check(game.collected == 1 and game.crew.size() == 33, "回収済み物体を二重計上しない")
	var blue_distance: float = _transport_distance(game, 1)
	var red_distance: float = _transport_distance(game, 0)
	_check(blue_distance > red_distance * 1.5, "青は赤より速く運搬する")


func _transport_distance(game: Node, kind: int) -> float:
	game.start_day()
	game.enemies.clear()
	game.leader = Vector3(-6, 0, 7)
	var original: Vector3 = game.cargo[0].position
	_throw_many(game, original, 2, kind)
	game.step(1.0, Vector3.ZERO)
	return original.distance_to(game.cargo[0].position)


func _check_combat(game: Node) -> void:
	var red_damage: float = _attack_damage(game, 0)
	var blue_damage: float = _attack_damage(game, 1)
	_check(red_damage > blue_damage * 2.0, "赤は青より強く攻撃")
	game.start_day()
	game.leader = Vector3(-11, 0, -4)
	var enemy: Dictionary = game.enemies[0]
	_throw_many(game, enemy.position, 6, 0)
	game.step(1.3, Vector3.ZERO)
	_check(enemy.hp == 0.0 and game.cargo.size() == 6, "敵撃破で運搬物を追加")
	_check(game.events.count("defeat") == 1, "敵撃破イベントは 1 回だけ")
	var carriers: int = 0
	for member: Dictionary in game.crew:
		if member.state == "carry" and member.target == 5:
			carriers += 1
	_check(carriers >= 4, "攻撃隊員が敵の運搬へ移る")
	game.start_day()
	game.crew[0].state = "idle"
	game.crew[0].position = game.enemies[0].position
	game.step(1.5, Vector3.ZERO)
	_check(game.crew.size() == 29 and game.events.has("lost"), "敵が近い仲間を倒す")


func _attack_damage(game: Node, kind: int) -> float:
	game.start_day()
	game.leader = Vector3(-11, 0, -4)
	var hp: float = game.enemies[0].hp
	_throw_many(game, game.enemies[0].position, 1, kind)
	game.step(0.5, Vector3.ZERO)
	return hp - float(game.enemies[0].hp)


func _check_navigation(game: Node) -> void:
	game.start_day()
	game.enemies.clear()
	game.leader = Vector3(22.9, 0, 22.9)
	game.step(1.0, Vector3(1, 0, 1))
	_check(game.leader.x <= 23.0 and game.leader.z <= 23.0, "リーダーは地面の外に出ない")
	var obstacle: Vector3 = game.obstacles[0]
	var point: Vector3 = obstacle + Vector3(0, 0, -6)
	var target: Vector3 = obstacle + Vector3(0, 0, 6)
	for index: int in range(600):
		point = game._move_ground(point, target, 0.05)
		_check(point.distance_to(obstacle) >= 1.699, "簡易経路は円柱内部へ入らない")
	_check(point.distance_to(target) < 0.2, "円柱正面から回り込んで目的地へ到達")


func _check_results(game: Node) -> void:
	game.start_day()
	game.remaining = 0.01
	game.step(0.02, Vector3.ZERO)
	_check(game.phase == "failed", "時間切れで失敗")
	var end_position: Vector3 = game.leader
	game.step(10.0, Vector3.RIGHT)
	game.throw_at(Vector3.ZERO)
	_check(game.leader == end_position, "結果画面ではシミュレーションが進まない")
	game.show_title()
	_check(game.phase == "title", "結果からタイトルへ戻れる")
	game.start_day()
	game.crew.clear()
	game.step(0.01, Vector3.ZERO)
	_check(game.phase == "failed", "全滅で失敗")
	game.start_day()
	game.collected = game.goal
	game.step(0.01, Vector3.ZERO)
	_check(game.phase == "clear", "目標達成でクリア")
	game.start_day()
	game.step(-1.0, Vector3.RIGHT)
	_check(game.remaining == 300.0, "負の時間刻みを無視する")


## 移動入力・投擲・回収・再集合だけで、敵なしと通常の敵あり双方のクリアを確認する。
func _check_play_route(game: Node, with_enemies: bool) -> void:
	game.start_day()
	if not with_enemies:
		game.enemies.clear()
	for cargo_index: int in range(5):
		var item: Dictionary = game.cargo[cargo_index]
		_walk_to(game, Vector3(18, 0, game.leader.z))
		_walk_to(game, Vector3(18, 0, item.position.z + 4))
		_walk_to(game, item.position + Vector3(0, 0, 4))
		for enemy: Dictionary in game.enemies:
			if enemy.hp > 0.0 and enemy.position.distance_to(item.position) < 5.0:
				_throw_many(game, enemy.position, 6, 0)
				game.step(1.3, Vector3.ZERO)
				_check(enemy.hp == 0.0, "操作経路で運搬物を守る敵を撃破")
		_throw_many(game, item.position, int(item.weight), 1)
		game.step(12.0, Vector3.ZERO)
		_check(item.delivered or game.phase == "clear", "操作経路で運搬物 %d を回収" % cargo_index)
		if game.phase != "playing":
			break
		_walk_to(game, Vector3(18, 0, game.leader.z))
		_walk_to(game, Vector3(18, 0, 15))
		_walk_to(game, game.base_position)
		game.whistle()
	_check(game.phase == "clear" and game.collected == 5, "5 個を操作で回収してクリア")
	if with_enemies:
		_check(game.events.count("defeat") >= 1, "通常ステージで敵を倒してクリア")
		_check(game.crew.size() >= 40, "敵の攻撃を受けても回収報酬で隊列を維持")
	else:
		_check(game.crew.size() == 45, "一連の回収で 15 体増員")
	game.show_title()
	game.start_day()
	_check(game.phase == "playing" and game.crew.size() == 30, "クリア後に再開できる")


func _walk_to(game: Node, point: Vector3) -> void:
	for index: int in range(500):
		if game.leader.distance_to(point) < 0.2 or game.phase != "playing":
			return
		var next: Vector3 = game._move_ground(game.leader, point, 0.3)
		game.step(0.05, (next - game.leader).normalized())
	_check(false, "移動先へ到達できる: %s" % point)
