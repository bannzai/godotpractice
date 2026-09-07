extends SceneTree
## シーンとアセットクレジットの検証。実行方法は Makefile の selfcheck target を参照。
## release ビルドで assert が消えるため、明示的な判定と exit code で結果を返す。

const Catalog := preload("res://scripts/catalog.gd")
const CutIn := preload("res://scripts/cut_in.gd")

var failed := false


func _initialize() -> void:
	preload("res://scripts/dev/logic_checks.gd").run(_check)
	_check_actors()
	_check_cut_ins()
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


func _check_actors() -> void:
	var characters: Array = Catalog.SPIRITS.keys()
	characters.append_array(["hero_0", "hero_1", "hero_2", "hero_3", "police", "boss"])
	for id: String in characters:
		var actor: Node2D = preload("res://scripts/actor.gd").new()
		root.add_child(actor)
		actor.setup(id)
		_check(actor.sprite.texture != null, "キャラごとの画像を読める: " + id)
		if id in actor.SPIRIT_IDS:
			_check(actor.sprite.texture is AtlasTexture, "十二体の劇画アトラスを切り出す: " + id)
			_check(actor.detail.texture == null, "生成済み劇画の上へ旧部品を重ねない: " + id)
		else:
			_check(actor.detail.texture != null, "キャラごとの可動部位を読める: " + id)
		for motion: String in actor.DURATIONS:
			_check(actor.animator.has_animation(motion), "実行可能なアニメーション: " + id + motion)
			actor.play_motion(motion)
			var initial_position: Vector2 = actor.sprite.position
			var initial_scale: Vector2 = actor.sprite.scale
			actor.animator.advance(float(actor.DURATIONS[motion]) * 0.3)
			_check(actor.animator.current_animation_position > 0.0,
				"AnimationPlayerの時間が進む: " + id + motion)
			_check(actor.sprite.position != initial_position or actor.sprite.scale != initial_scale,
				"再生時間に応じて姿勢が変わる: " + id + motion)
		actor.seek_motion("dissolve", float(actor.DURATIONS.dissolve))
		_check(actor.sprite.modulate.a == 0.0, "消滅アニメーションの終端で霊が霧散する: " + id)
		actor.free()


func _check_cut_ins() -> void:
	var catalog_ids: Array = Catalog.SPIRITS.keys()
	_check(CutIn.SPIRIT_IDS.size() == catalog_ids.size(), "十二体すべてにカットインがある")
	for id: String in catalog_ids:
		_check(id in CutIn.SPIRIT_IDS, "カットインの霊IDが図鑑と一致: " + id)
		var cut_in: Control = CutIn.new()
		root.add_child(cut_in)
		for action: String in cut_in.ACTIONS:
			cut_in.setup(id, action, "検証")
			cut_in.seek_progress(0.5)
			_check(cut_in.visible and cut_in._portrait is AtlasTexture,
				"攻撃・被弾・消滅のコマ割りを描画できる: " + id + action)
		cut_in.free()


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
