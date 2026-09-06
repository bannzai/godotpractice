extends SceneTree
## シーンとアセットクレジットの検証。実行方法は Makefile の selfcheck target を参照。
## release ビルドで assert が消えるため、明示的な判定と exit code で結果を返す。

var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_state_and_world()
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


func _check_state_and_world() -> void:
	var state: Node = load("res://scripts/game_state.gd").new()
	var cases: GDScript = load("res://scripts/dev/state_cases.gd")
	for failure: String in cases.run(state):
		_check(false, failure)
	state.free()
	var world_script: GDScript = load("res://scripts/world.gd")
	_check(world_script.ROOM_NAMES.size() == 12, "フィールド6画面と遺跡6部屋")
	_check(world_script.sword_hits(Vector2.ZERO, Vector2.RIGHT, Vector2(100, 0)), "剣は前方へ届く")
	_check(not world_script.sword_hits(Vector2.ZERO, Vector2.RIGHT, Vector2(-80, 0)), "剣は背後へ届かない")
	_check(not world_script.sword_hits(Vector2.ZERO, Vector2.RIGHT, Vector2(0, 80)), "剣の扇の外は無傷")
	_check(not world_script.sword_hits(Vector2.ZERO, Vector2.RIGHT, Vector2(116, 0)), "剣の射程外は無傷")
	for kind: String in ["hero", "villager", "merchant", "wanderer", "charger", "ranger",
		"splitter", "boss"]:
		var actor: Node2D = load("res://scripts/actor.gd").new()
		actor.setup(kind)
		for motion: String in ["idle", "walk", "action", "hurt", "death"]:
			_check(actor.sprite.sprite_frames.has_animation(motion), "%s の %s" % [kind, motion])
			_check(actor.sprite.sprite_frames.get_frame_count(motion) == 4,
				"%s の %s は4フレーム" % [kind, motion])
		actor.free()
