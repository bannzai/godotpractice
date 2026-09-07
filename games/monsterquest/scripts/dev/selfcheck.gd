extends SceneTree
## シーンとアセットクレジットの検証。実行方法は Makefile の selfcheck target を参照。
## release ビルドで assert が消えるため、明示的な判定と exit code で結果を返す。

const DOT_FONT_PATH := "res://assets/fonts/DotGothic16-Regular.ttf"
const RUNTIME_SOURCE_PATHS: Array[String] = [
	"res://project.godot", "res://scenes", "res://scripts", "res://themes",
]
const BANNED_FONT_REFERENCES: Array[String] = [
	"MPLUSRounded", "M PLUS Rounded", "Zen Old Mincho", "Noto Sans JP", "font.ttf",
]

var failed := false
var dot_font_referenced := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	preload("res://scripts/dev/logic_checks.gd").run(_check)
	preload("res://scripts/dev/world_checks.gd").run(_check)
	_check_scenes("res://scenes")
	_check_assets_credited()
	_check_art_direction()
	await preload("res://scripts/dev/input_checks.gd").run(_check, self)
	await preload("res://scripts/dev/polish_checks.gd").run(_check, self)

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


## 特色化で廃止した素材・書体・共通フッターが本番コードへ戻らないことを検査する。
func _check_art_direction() -> void:
	_check(FileAccess.file_exists(DOT_FONT_PATH), "書体: DotGothic16 を同梱")
	if FileAccess.file_exists(DOT_FONT_PATH):
		var font: Font = load(DOT_FONT_PATH) as Font
		_check(font != null, "書体: DotGothic16 をロードできる")
	_check_runtime_source("res://project.godot")
	for path: String in RUNTIME_SOURCE_PATHS.slice(1):
		_check_runtime_directory(path)
	_check(dot_font_referenced, "書体: 本番画面が DotGothic16 を参照")


func _check_runtime_directory(path: String) -> void:
	var directory: DirAccess = DirAccess.open(path)
	_check(directory != null, "特色: %s を走査できる" % path)
	if directory == null:
		return
	for filename: String in directory.get_files():
		if filename.get_extension() in ["gd", "tscn", "tres"]:
			_check_runtime_source(path.path_join(filename))
	for subdirectory: String in directory.get_directories():
		if path == "res://scripts" and subdirectory == "dev":
			continue
		_check_runtime_directory(path.path_join(subdirectory))


func _check_runtime_source(path: String) -> void:
	var source: String = FileAccess.get_file_as_string(path)
	_check(not source.is_empty(), "特色: %s を読み取れる" % path)
	if source.is_empty():
		return
	dot_font_referenced = dot_font_referenced or source.contains("DotGothic16-Regular.ttf")
	_check(not source.to_lower().contains("." + "svg"), "特色: 旧 SVG を参照しない: " + path)
	_check(not source.contains("_foot" + "er("), "UI: 画面下の共通操作ガイドを廃止: " + path)
	for reference: String in BANNED_FONT_REFERENCES:
		_check(not source.contains(reference), "書体: 禁止フォントを参照しない: %s / %s" % [
			path, reference,
		])
