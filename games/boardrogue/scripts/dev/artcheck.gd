extends SceneTree
## Godot が読み込んだ全コマの余白・内容・再生位置を検査する。

const Actor = preload("res://scripts/visual/actor.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const ACTIONS: Array[String] = ["idle", "move", "attack", "hurt", "death"]
const FRAME_SIZE := Vector2i(256, 320)
const FRAME_COUNT: int = 4

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ids: Array = Catalog.CARDS.keys() + Catalog.ENEMIES.keys() + ["hero", "merchant", "rest"]
	for id: String in ids:
		_check_actor(id)
	var result: String = "OK" if _failures == 0 else "FAIL"
	print("artcheck %s: %d 種 × 5 動作 × 4 コマ、余白・差異・再生位置" % [result, ids.size()])
	quit(0 if _failures == 0 else 1)


func _check_actor(id: String) -> void:
	var path: String = "res://assets/art/%s_sheet.svg" % id
	if not ResourceLoader.exists(path):
		_fail("素材なし: %s" % id)
		return
	var texture: Texture2D = load(path)
	var source: Image = texture.get_image()
	if source.is_compressed():
		source.decompress()
	if source.get_size() != FRAME_SIZE * Vector2i(FRAME_COUNT, ACTIONS.size()):
		_fail("シート寸法: %s %s" % [id, source.get_size()])
		return
	var actor: Node2D = Actor.new()
	root.add_child(actor)
	actor.setup(id, 1.0)
	for row: int in range(ACTIONS.size()):
		var seen: Array[int] = []
		for column: int in range(FRAME_COUNT):
			actor.seek_pose(ACTIONS[row], column)
			var area := Rect2i(Vector2i(column, row) * FRAME_SIZE, FRAME_SIZE)
			var image: Image = source.get_region(area)
			_check_frame(id, ACTIONS[row], column, image, seen)
			if actor.sprite.frame != column:
				_fail("再生位置: %s %s %d" % [id, ACTIONS[row], column])
		if actor.sprite.sprite_frames.get_frame_count(ACTIONS[row]) != FRAME_COUNT:
			_fail("動作のコマ数: %s %s" % [id, ACTIONS[row]])
	actor.free()


# 同一動作内の各画像を順に照合するため、呼ぶたびに照合済み一覧へ追加する。
func _check_frame(id: String, action: String, frame: int, image: Image, seen: Array[int]) -> void:
	var used: Rect2i = image.get_used_rect()
	var digest: int = hash(image.get_data())
	if used.size.x < 70 or used.size.y < 90:
		_fail("空または不完全なコマ: %s %s %d %s" % [id, action, frame, used])
	if digest in seen:
		_fail("重複するコマ: %s %s %d" % [id, action, frame])
	if used.position.x <= 1 or used.position.y <= 1 or used.end.x >= 255 or used.end.y >= 319:
		_fail("コマ境界へのはみ出し: %s %s %d %s" % [id, action, frame, used])
	seen.append(digest)


# 検査で見つかった不一致を一件ずつ数えるため非冪等。
func _fail(message: String) -> void:
	_failures += 1
	print("artcheck FAIL: " + message)
