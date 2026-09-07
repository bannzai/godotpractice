extends SceneTree
## シーンとアセットクレジットの検証。実行方法は Makefile の selfcheck target を参照。
## release ビルドで assert が消えるため、明示的な判定と exit code で結果を返す。

var failed: bool = false
var image_count: int = 0
var audio_count: int = 0


func _initialize() -> void:
	_run.call_deferred()


## アニメーションの実時間による進行を検証するため非冪等。
func _run() -> void:
	var logic: RefCounted = load("res://scripts/dev/logic_checks.gd").new()
	for message: String in logic.run():
		_check(false, message)
	_check_scenes("res://scenes")
	_check_assets_credited()
	_check(image_count > 0, "画像素材が空ではない")
	_check(audio_count > 0, "音声素材が空ではない")
	_check_print_assets()
	await _check_animations()

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
		_check_media(path.path_join(filename))
	for subdirectory: String in directory.get_directories():
		_check_asset_directory(path.path_join(subdirectory), credits)


func _check_media(path: String) -> void:
	if path.get_extension() in ["svg", "png", "jpg", "webp"]:
		image_count += 1
		var texture: Texture2D = load(path) as Texture2D
		_check(texture != null, "画像をロードできる: " + path)
		if texture == null:
			return
		var picture: Image = texture.get_image()
		_check(picture != null and not picture.is_empty(), "画像の画素を読み取れる: " + path)
		if picture != null and not picture.is_empty():
			_check(picture.get_used_rect().has_area(), "画像に不透明な画素がある: " + path)
	elif path.get_extension() in ["wav", "ogg", "mp3"]:
		audio_count += 1
		var sound: AudioStream = load(path) as AudioStream
		_check(sound != null and sound.get_length() > 0.05, "音声に再生時間がある: " + path)


## 再生中のフレーム変化を測るため非冪等。
func _check_animations() -> void:
	var actor_script: Script = load("res://scripts/farm_actor.gd")
	for kind: String in actor_script.CHARACTER_IMAGES:
		var actor: Node2D = actor_script.new()
		root.add_child(actor)
		actor.setup(kind)
		var sprite: AnimatedSprite2D = actor.sprite
		var actions: PackedStringArray = sprite.sprite_frames.get_animation_names()
		_check(actions.size() >= 4, kind + ": アニメーションが4種類以上ある")
		for action: String in actions:
			_check(sprite.sprite_frames.get_frame_count(action) >= 4, kind + "/" + action + ": 4コマある")
			actor.animate(action)
			sprite.set_frame_and_progress(0, 0.0)
			await create_timer(0.25).timeout
			_check(sprite.frame > 0, kind + "/" + action + ": 実際にフレームが進む")
			var first: Texture2D = sprite.sprite_frames.get_frame_texture(action, 0)
			var middle: Texture2D = sprite.sprite_frames.get_frame_texture(action, 1)
			_check(first.get_image().get_data() != middle.get_image().get_data(),
				kind + "/" + action + ": 開始と途中の画素が異なる")
		actor.queue_free()
		await process_frame


## 写真由来の版画 PNG と指定フォントが実際に読めることを検証する。
func _check_print_assets() -> void:
	var landscape: Texture2D = load("res://assets/backgrounds/far.png")
	_check(landscape != null and landscape.get_size() == Vector2(1280, 720),
		"CC0農村写真の版画背景が1280×720である")
	var village_map: Texture2D = load("res://assets/backgrounds/village_map.png")
	_check(village_map != null and village_map.get_size() == Vector2(1280, 720),
		"村の地図が1280×720である")
	for crop: String in ["turnip", "carrot", "tomato", "corn"]:
		var texture: Texture2D = load("res://assets/crops/%s_ripe.png" % crop)
		_check(texture != null and texture.get_size() == Vector2(64, 64),
			crop + ": 写真を減色した収穫画像が64×64である")
	_check(not FileAccess.file_exists("res://assets/characters/farmer.svg"),
		"旧SVG素材を使っていない")
	_check(FileAccess.file_exists("res://assets/fonts/Yomogi-Regular.ttf"),
		"Yomogiフォントを同梱している")
	_check(not FileAccess.file_exists("res://assets/fonts/MPLUSRounded1c-Regular.ttf"),
		"禁止されたM PLUS Rounded 1cを同梱していない")
