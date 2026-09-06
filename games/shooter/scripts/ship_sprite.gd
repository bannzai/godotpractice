extends AnimatedSprite2D
## 機体ごとの独立シートから、装甲・砲塔・コアのフレームアニメーションを再生する。

const POSES: Array[String] = ["idle", "move", "attack", "hit", "death"]
const KINDS: Array[String] = ["player", "scout", "aim", "fan", "boss"]
const FRAME_COUNT: int = 4
const FRAME_RATES: Dictionary = {
	"idle": 6.0, "move": 12.0, "attack": 14.0, "hit": 18.0, "death": 8.0
}

static var _frames_cache: Dictionary = {}

var kind: String = ""


func setup(next_kind: String) -> void:
	if kind == next_kind and sprite_frames != null:
		return
	if next_kind not in KINDS:
		push_error("未対応の機体: " + next_kind)
		return
	kind = next_kind
	if not _frames_cache.has(kind):
		_frames_cache[kind] = _create_frames(kind)
	sprite_frames = _frames_cache[kind]
	play("idle")


func set_pose(pose: String) -> void:
	if sprite_frames == null or pose not in POSES:
		return
	if animation == pose:
		return
	play(pose)


static func _create_frames(ship_kind: String) -> SpriteFrames:
	var result: SpriteFrames = SpriteFrames.new()
	result.remove_animation("default")
	var sheet: Texture2D = load("res://assets/sprites/%s_sheet.svg" % ship_kind)
	var cell: Vector2 = Vector2(256, 160) if ship_kind == "boss" else Vector2(128, 128)
	for row: int in range(POSES.size()):
		var pose: String = POSES[row]
		result.add_animation(pose)
		result.set_animation_speed(pose, FRAME_RATES[pose])
		result.set_animation_loop(pose, pose in ["idle", "move", "attack"])
		for column: int in range(FRAME_COUNT):
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(Vector2(column, row) * cell, cell)
			result.add_frame(pose, atlas)
	return result
