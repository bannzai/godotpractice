extends SceneTree
## シーンとアセットクレジットの検証。実行方法は Makefile の selfcheck target を参照。
## release ビルドで assert が消えるため、明示的な判定と exit code で結果を返す。

const Data := preload("res://scripts/voxel_data.gd")
const State := preload("res://scripts/survival_state.gd")
const EnemyChecks := preload("res://scripts/dev/enemies_check.gd")
const World := preload("res://scripts/voxel_world.gd")

var failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_world()
	await _check_mesh()
	_check_survival()
	_check_save()
	_check_hotbar()
	_check_safe_respawn()
	_check(await EnemyChecks.new().run(self), "敵の出現・攻撃・遮蔽・朝の消滅")
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


func _check_world() -> void:
	var first: RefCounted = Data.new()
	var second: RefCounted = Data.new()
	first.generate(46)
	second.generate(46)
	_check(first.blocks == second.blocks, "同じシードの地形と木が一致")
	second.generate(47)
	_check(first.blocks != second.blocks, "異なるシードで地形が変わる")
	first.generate(46)
	_check(first.blocks.size() > 4000, "島のブロックを生成")
	var types: Dictionary = {}
	for cell: Vector3i in first.blocks:
		types[first.get_block(cell)] = true
		_check(first.in_bounds(cell), "生成ブロックは範囲内")
	_check(types.size() >= 7, "7種類以上の地形素材")
	var spawn_cell := Vector3i(first.spawn.floor())
	_check(not first.is_solid(spawn_cell), "スポーン地点に埋まらない")
	_check(not first.is_solid(spawn_cell + Vector3i.UP), "スポーン頭上の空間")
	_check(first.is_solid(spawn_cell + Vector3i.DOWN), "スポーン地点の直下に地面")
	var original_size: int = first.blocks.size()
	first.set_block(Vector3i(-1, 0, 0), Data.STONE)
	_check(first.blocks.size() == original_size, "範囲外の設置を拒否")
	var world: Node3D = World.new()
	world.data = first
	var hit: Dictionary = world.raycast(first.spawn + Vector3(0, 1, 0), Vector3.DOWN)
	_check(not hit.is_empty() and hit.cell == spawn_cell + Vector3i.DOWN, "照準の地面命中")
	_check(hit.previous == spawn_cell, "設置候補は命中ブロックの手前")
	_check(world.raycast(first.spawn, Vector3.UP, 0.5).is_empty(), "射程外は命中しない")
	world.free()


func _check_survival() -> void:
	var state: Node = State.new()
	state.new_game(46)
	_check(not state.craft("stone_pick"), "素材不足ではクラフトしない")
	state.add_item("wood", 12)
	_check(state.craft("plank") and state.inventory.plank == 4, "木から板へ変換")
	_check(state.craft("bench"), "板から作業台へ変換")
	state.craft("plank")
	_check(state.craft("wood_pick") and state.tool_level == 1, "作業台で木の道具を作る")
	var stone := Vector3i(16, 3, 16)
	state.tool_level = 0
	_check(not state.mine(stone), "素手で石は壊せない")
	state.tool_level = 1
	_check(state.mine(stone), "木の道具で石を採掘")
	_check(not state.mine(stone), "採掘済みブロックから重複取得しない")
	state.add_item("stone", 3)
	_check(state.craft("stone_pick") and state.tool_level == 2, "石の道具を作る")
	state.data.set_block(stone, Data.ORE)
	state.tool_level = 1
	_check(not state.mine(stone), "木の道具で鉱石は壊せない")
	state.tool_level = 2
	_check(state.mine(stone), "石の道具で鉱石を採掘")
	state.add_item("dirt", 2)
	var target := Vector3i(16, 7, 16)
	_check(not state.place(target, AABB(Vector3(target), Vector3.ONE)), "体内への設置を拒否")
	_check(state.inventory.dirt == 2, "設置失敗時に素材を消費しない")
	_check(state.place(target, AABB(Vector3(3, 9, 3), Vector3.ONE)), "空間への設置")
	_check(not state.place(target, AABB()), "既存ブロックの上書きを拒否")
	state.hunger = 1
	state.step(10)
	_check(state.hunger == 0 and state.hp < 100, "空腹による継続ダメージ")
	_check(state.eat() and state.hunger > 0, "食べ物で空腹回復")
	_check(State.RECIPES.size() >= 8, "8種類以上のクラフト")
	_check_house_and_goal(state)
	state.damage(1000)
	_check(state.phase == "failed", "体力ゼロでゲームオーバー")
	state.respawn()
	_check(state.phase == "play" and state.inventory.is_empty(), "復活で所持品を失う")
	_check(state.tool_level == 0 and state.hp == 100, "復活時に道具と体力を初期化")
	state.free()


func _check_house_and_goal(state: Node) -> void:
	state.data.blocks.clear()
	_check(not state.check_house(), "空のワールドは家ではない")
	for x: int in range(5, 8):
		for z: int in range(5, 8):
			for y: int in range(4):
				if y == 0 or y == 3 or x != 6 or z != 6:
					state.data.set_block(Vector3i(x, y, z), Data.PLANK)
	_check(state.check_house(), "床・屋根・壁のある家を認識")
	state.data.set_block(Vector3i(6, 3, 6), Data.AIR)
	_check(not state.check_house(), "屋根を壊すと家ではない")
	state.data.set_block(Vector3i(6, 3, 6), Data.PLANK)
	state.data.set_block(Vector3i(6, 1, 5), Data.AIR)
	state.data.set_block(Vector3i(6, 2, 5), Data.AIR)
	_check(state.check_house(), "柱とまぐさのある出入口を認識")
	state.data.set_block(Vector3i(7, 1, 6), Data.AIR)
	_check(not state.check_house(), "壁が欠けた構造は家ではない")
	state.data.set_block(Vector3i(7, 1, 6), Data.PLANK)
	state.house_built = state.check_house()
	state.day = 4
	state.day_time = 0.179
	state.hunger = 100
	state.hp = 100
	state.step(0.05)
	_check(state.phase == "play", "開始時刻から三日経過する直前はクリアしない")
	state.step(0.2)
	_check(state.phase == "clear" and state.day == 4, "石道具・家・三日生存でクリア")
	state.phase = "play"


func _check_save() -> void:
	var state: Node = State.new()
	var restored: Node = State.new()
	state.new_game(123)
	state.add_item("stone", 11)
	state.day = 2
	var encoded: String = JSON.stringify(state.serialize())
	_check(restored.deserialize(JSON.parse_string(encoded)), "保存JSONの復元")
	_check(restored.inventory == state.inventory and restored.data.blocks == state.data.blocks,
		"地形と所持品を完全復元")
	var valid: Dictionary = state.serialize()
	for key: String in ["day", "hp", "position", "world", "inventory"]:
		var malformed: Dictionary = valid.duplicate(true)
		malformed.erase(key)
		_check(not restored.deserialize(malformed), "必須項目欠落を拒否: " + key)
	var invalid: Dictionary = valid.duplicate(true)
	invalid.inventory.stone = -1
	_check(not restored.deserialize(invalid), "負の所持数を拒否")
	invalid = valid.duplicate(true)
	invalid.day = 1.5
	_check(not restored.deserialize(invalid), "小数の日数を拒否")
	invalid = valid.duplicate(true)
	invalid.world.cells.append(invalid.world.cells[0])
	_check(not restored.deserialize(invalid), "重複ブロックの破損保存を拒否")
	invalid = valid.duplicate(true)
	invalid.version = 999
	_check(not restored.deserialize(invalid), "未知の保存バージョンを拒否")
	_check(restored.inventory.stone == 11 and restored.day == 2, "読込失敗は現在状態を維持")
	_check(state.save_game("res://tmp/selfcheck-save.json"), "保存ファイルを書き出す")
	_check(restored.load_game("res://tmp/selfcheck-save.json"), "保存ファイルから再開")
	var file := FileAccess.open("res://tmp/selfcheck-corrupt.json", FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	_check(not restored.load_game("res://tmp/selfcheck-corrupt.json"), "破損JSONでクラッシュしない")
	state.free()
	restored.free()


func _check_mesh() -> void:
	var data: RefCounted = Data.new()
	data.set_block(Vector3i(8, 5, 8), Data.STONE)
	data.set_block(Vector3i(9, 5, 8), Data.STONE)
	var world: Node3D = World.new()
	root.add_child(world)
	world.configure(data)
	_check(world.get_child_count() == 1, "二つのブロックを一つのチャンクで描画")
	var mesh: ArrayMesh = world.get_child(0).mesh
	_check(mesh.surface_get_array_len(0) == 60, "接する内面を除いた十面だけを描画")
	await physics_frame
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(Vector3(8.5, 9, 8.5), Vector3(8.5, 0, 8.5))
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	_check(not hit.is_empty() and is_equal_approx(hit.position.y, 6.0), "地面上面の物理衝突")
	data.set_block(Vector3i(8, 5, 8), Data.AIR)
	world.rebuild()
	await physics_frame
	await physics_frame
	_check(world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),
		"採掘後に古い衝突が残らない")
	world.queue_free()
	await process_frame


func _check_hotbar() -> void:
	var state: Node = State.new()
	state.new_game()
	_check(not state.assign_slot("unknown"), "未知のアイテムは選択枠に登録しない")
	_check(not state.assign_slot("meat"), "未所持品は選択枠に登録しない")
	state.add_item("meat", 2)
	state.add_item("bandage", 1)
	state.selected = 3
	_check(state.assign_slot("meat") and state.hotbar[3] == "meat", "拡張所持品を選択枠に登録")
	var restored: Node = State.new()
	_check(restored.deserialize(JSON.parse_string(JSON.stringify(state.serialize()))),
		"選択枠を含む保存を復元")
	_check(restored.hotbar == state.hotbar and restored.selected == 3, "選択枠と選択位置の保存往復")
	for invalid: Variant in [["meat"], [1, 2, 3, 4, 5, 6, 7, 8, 9], "invalid"]:
		var saved: Dictionary = state.serialize()
		saved.hotbar = invalid
		_check(not restored.deserialize(saved), "選択枠の長さと型の破損を拒否")
	var saved: Dictionary = state.serialize()
	saved.hotbar[0] = "unknown"
	_check(not restored.deserialize(saved), "選択枠に未知の品が含まれる保存を拒否")
	state.hunger = 50
	state.eat()
	_check(state.inventory.meat == 1 and state.inventory.apple == 6, "選択した食料を先に消費")
	state.assign_slot("bandage")
	state.hp = 50
	_check(state.eat() and state.hp == 80, "包帯を直接選択して治療")
	state.damage(100)
	state.respawn()
	_check(state.hotbar == State.DEFAULT_HOTBAR, "復活時に選択枠を初期化")
	state.free()
	restored.free()


func _check_safe_respawn() -> void:
	var state: Node = State.new()
	state.new_game()
	var original: Vector3 = state.data.spawn
	state.data.set_block(Vector3i(original.floor()), Data.STONE)
	state.data.set_block(Vector3i(original.floor()) + Vector3i.UP, Data.STONE)
	state.damage(100)
	state.respawn()
	_check(state.phase == "play" and state.player_position != original, "埋まった初期地点を避けて復活")
	_check(State._body_clear(state.data, state.player_position), "復活位置は全身のAABBが空いている")
	_check(state.data.is_solid(Vector3i((state.player_position - Vector3(0, 0.05, 0)).floor())),
		"復活位置の足元には支持ブロックがある")
	var saved: Dictionary = state.serialize()
	saved.position = [original.x, original.y, original.z]
	_check(state.deserialize(saved) and State._body_clear(state.data, state.player_position),
		"保存位置が埋まっていても安全な場所で再開")
	state.free()
