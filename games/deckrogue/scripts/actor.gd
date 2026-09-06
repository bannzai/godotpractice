extends Node2D
## キャラごとのシートと一時的な動作だけを所有する。

signal action_finished(action: String)

const FRAME_SIZE := Vector2(256, 320)
const ACTIONS: Array[String] = ["idle", "move", "attack", "hurt", "death"]
const FRAME_RATES: Array[float] = [7.0, 12.0, 14.0, 12.0, 8.0]

var sprite: AnimatedSprite2D
var character_id: String = ""
var _motion: Tween


func setup(id: String, rect: Rect2) -> void:
	position = rect.get_center()
	var fit: float = minf(rect.size.x / FRAME_SIZE.x, rect.size.y / FRAME_SIZE.y)
	scale = Vector2.ONE * fit
	if not is_instance_valid(sprite):
		sprite = AnimatedSprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(sprite)
		sprite.animation_finished.connect(_on_animation_finished)
	if character_id != id:
		character_id = id
		sprite.sprite_frames = _frames(id)
	resume_idle()


func _frames(id: String) -> SpriteFrames:
	var sheet: Texture2D = load("res://assets/art/%s_sheet.svg" % id)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row: int in range(ACTIONS.size()):
		frames.add_animation(ACTIONS[row])
		frames.set_animation_loop(ACTIONS[row], ACTIONS[row] == "idle")
		frames.set_animation_speed(ACTIONS[row], FRAME_RATES[row])
		for column: int in range(6):
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(Vector2(column, row) * FRAME_SIZE, FRAME_SIZE)
			frame.filter_clip = true
			frames.add_frame(ACTIONS[row], frame)
	return frames


# 一度の入力に対する演出なので、同じ動作名でも新たな攻撃として最初から再生する。
func play_action(action: String) -> void:
	if not is_instance_valid(sprite) or action not in ACTIONS:
		return
	_reset_pose()
	sprite.play(action)
	sprite.set_frame_and_progress(0, 0.0)
	match action:
		"attack":
			_motion = create_tween()
			var direction: float = 1.0 if character_id == "hero" else -1.0
			_motion.tween_property(sprite, "position:x", -8.0 * direction, 0.08)
			_motion.tween_property(sprite, "position:x", 22.0 * direction, 0.10)
			_motion.tween_property(sprite, "position:x", 0.0, 0.22)
		"hurt":
			sprite.speed_scale = 0.0
			sprite.modulate = Color(1.5, 0.72, 0.56)
			_motion = create_tween()
			_motion.tween_interval(0.065)
			_motion.tween_property(sprite, "speed_scale", 1.0, 0.01)
			_motion.tween_property(sprite, "position:x", -8.0, 0.055)
			_motion.tween_property(sprite, "position:x", 5.0, 0.055)
			_motion.tween_property(sprite, "position:x", 0.0, 0.11)
			_motion.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.11)
		"move":
			_motion = create_tween()
			_motion.tween_property(sprite, "position:y", -5.0, 0.14)
			_motion.tween_property(sprite, "position:y", 0.0, 0.26)


func seek_pose(action: String, progress: float) -> void:
	if not is_instance_valid(sprite) or action not in ACTIONS:
		return
	_reset_pose()
	sprite.animation = action
	sprite.pause()
	sprite.set_frame_and_progress(roundi(clampf(progress, 0.0, 1.0) * 5.0), 0.0)


func resume_idle() -> void:
	if not is_instance_valid(sprite):
		return
	_reset_pose()
	sprite.play("idle")


func _reset_pose() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null
	sprite.position = Vector2.ZERO
	sprite.modulate = Color.WHITE
	sprite.speed_scale = 1.0


func _on_animation_finished() -> void:
	var finished_action: String = sprite.animation
	if finished_action != "death":
		resume_idle()
	action_finished.emit(finished_action)


func _exit_tree() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null
	if is_instance_valid(sprite):
		sprite.stop()
