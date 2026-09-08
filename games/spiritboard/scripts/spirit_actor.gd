extends Control
## 各人物・霊の独立シートから、部位の異なる連続ポーズを再生する。

signal pose_finished(pose: String)

const FRAME_SIZE := Vector2(256, 320)
const POSES: Array[String] = ["idle", "move", "action", "hit", "vanish"]
const POSE_SECONDS: float = 0.6

var character_id: String = ""
var sprite: AnimatedSprite2D


func setup(id: String, display_size: Vector2) -> void:
	size = display_size
	custom_minimum_size = display_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not is_instance_valid(sprite):
		sprite = AnimatedSprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(sprite)
		sprite.animation_finished.connect(_on_animation_finished)
	sprite.position = display_size * 0.5
	sprite.scale = Vector2.ONE * minf(display_size.x / 256.0, display_size.y / 320.0)
	if character_id != id:
		character_id = id
		sprite.sprite_frames = _frames(id)
		sprite.play("idle")


func _frames(id: String) -> SpriteFrames:
	var sheet: Texture2D = load("res://assets/art/%s_sheet.svg" % id)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row: int in range(POSES.size()):
		frames.add_animation(POSES[row])
		frames.set_animation_loop(POSES[row], POSES[row] == "idle")
		frames.set_animation_speed(POSES[row], 6.0 / POSE_SECONDS)
		for column: int in range(6):
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(Vector2(column, row) * FRAME_SIZE, FRAME_SIZE)
			frame.filter_clip = true
			frames.add_frame(POSES[row], frame)
	return frames


# 操作一回ごとの演出なので、同じ名前でも開始コマに戻して再生する。
func play_pose(pose: String) -> void:
	if not is_instance_valid(sprite) or pose not in POSES:
		return
	sprite.play(pose)
	sprite.set_frame_and_progress(0, 0.0)


func seek_pose(pose: String, seconds: float) -> void:
	if not is_instance_valid(sprite) or pose not in POSES:
		return
	sprite.animation = pose
	sprite.pause()
	sprite.set_frame_and_progress(clampi(int(seconds / POSE_SECONDS * 6.0), 0, 5), 0.0)


func _on_animation_finished() -> void:
	var finished: String = sprite.animation
	if finished != "vanish":
		sprite.play("idle")
	pose_finished.emit(finished)


func _exit_tree() -> void:
	if is_instance_valid(sprite):
		sprite.stop()
