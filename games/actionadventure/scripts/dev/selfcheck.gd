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
	_check_art_direction()

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
		_check(filename.get_extension().to_lower() != "svg", "画像: SVG を使っていない")
		_check(
			credits.contains(filename),
			"CREDITS: %s が assets/CREDITS.md に記録されていない" % path.path_join(filename)
		)
	for subdirectory: String in directory.get_directories():
		_check_asset_directory(path.path_join(subdirectory), credits)


func _check_art_direction() -> void:
	_check(FileAccess.file_exists("res://assets/fonts/Stick-Regular.ttf"), "フォント: Stick を同梱")
	_check(not FileAccess.file_exists("res://assets/fonts/font.ttf"), "フォント: 旧 font.ttf を使わない")
	var catalog_text: String = FileAccess.get_file_as_string("res://assets/palettes.json")
	var parsed: Variant = JSON.parse_string(catalog_text)
	_check(parsed is Dictionary, "パレット: palettes.json を解析できる")
	if not parsed is Dictionary:
		return
	var catalog: Dictionary = parsed
	var palettes: Dictionary = catalog.get("palettes", {})
	_check(palettes.size() >= 4, "パレット: 地域・用途別の配色が4種類以上")
	for palette_name: String in palettes:
		var palette: Dictionary = palettes[palette_name]
		var colors: Array = palette.get("colors", [])
		_check(colors.size() >= 4 and colors.size() <= 8,
			"パレット: %s は4〜8色" % palette_name)
	var outputs: Dictionary = catalog.get("outputs", {})
	_check(outputs.size() >= 30, "画像: 再着色したPNGを30点以上記録")
	for output_name: String in outputs:
		var metadata: Dictionary = outputs[output_name]
		var expected_size: Array = metadata.get("size", [])
		var texture: Texture2D = load("res://assets/" + output_name) as Texture2D
		_check(texture != null, "画像: %s を読み込める" % output_name)
		if texture != null and expected_size.size() == 2:
			_check(Vector2i(texture.get_width(), texture.get_height()) == \
				Vector2i(expected_size[0], expected_size[1]),
				"画像: %s の寸法が生成記録と一致" % output_name)
		var verification: Dictionary = metadata.get("verification", {})
		_check(verification.get("unique_rgb_colors", 999) <= verification.get("palette_limit", 0),
			"画像: %s は割り当てた色数以内" % output_name)
	var sources: Array = catalog.get("sources", [])
	_check(sources.size() == 3, "素材: 採用したCC0素材3点を記録")
	for source: Dictionary in sources:
		_check(source.get("license", "") == "CC0-1.0", "素材: CC0のみを採用")


func _check_state_and_world() -> void:
	var state: Node = load("res://scripts/game_state.gd").new()
	var cases: GDScript = load("res://scripts/dev/state_cases.gd")
	for failure: String in cases.run(state):
		_check(false, failure)
	state.free()
	var world_script: GDScript = load("res://scripts/world.gd")
	_check(world_script.ROOM_NAMES.size() == 12, "フィールド6画面と遺跡6部屋")
	_check(world_script.TILE_SIZE == 56, "画像: 56pxタイルで構成")
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
