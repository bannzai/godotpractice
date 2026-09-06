extends Node2D
## キャラクター固有の素材を、盤上・札・肖像・撮影で共通に使う。

signal pose_finished(action: String)

const FRAME_SIZE := Vector2(256, 320)
const FRAME_COUNT: int = 4
const ACTIONS: Array[String] = ["idle", "move", "attack", "hurt", "death"]
const RATES: Array[float] = [4.0, 9.0, 10.0, 9.0, 6.0]

var sprite: AnimatedSprite2D
var character_id: String = ""
var _motion: Tween


func setup(id: String, scale_factor: float = 1.0) -> void:
	scale = Vector2.ONE * scale_factor
	if not is_instance_valid(sprite):
		sprite = AnimatedSprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(sprite)
		sprite.animation_finished.connect(_on_pose_finished)
	if character_id == id:
		return
	character_id = id
	sprite.sprite_frames = _build_frames(id)
	sprite.play("idle")


func _build_frames(id: String) -> SpriteFrames:
	var sheet: Texture2D = load("res://assets/art/%s_sheet.svg" % id)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row: int in range(ACTIONS.size()):
		var action: String = ACTIONS[row]
		frames.add_animation(action)
		frames.set_animation_loop(action, action == "idle")
		frames.set_animation_speed(action, RATES[row])
		for column: int in range(FRAME_COUNT):
			var texture := AtlasTexture.new()
			texture.atlas = sheet
			texture.region = Rect2(Vector2(column, row) * FRAME_SIZE, FRAME_SIZE)
			texture.filter_clip = true
			frames.add_frame(action, texture)
	return frames


# 入力イベントごとの演出なので、同じ攻撃も先頭から再生する。
func play_pose(action: String) -> void:
	if not is_instance_valid(sprite) or action not in ACTIONS:
		return
	_reset_pose()
	sprite.play(action)
	sprite.set_frame_and_progress(0, 0.0)
	match action:
		"attack":
			_motion = create_tween()
			_motion.tween_property(sprite, "position:x", -8.0, 0.09)
			_motion.tween_property(sprite, "position:x", 16.0, 0.07)
			_motion.tween_property(sprite, "position:x", 0.0, 0.20)
		"hurt":
			# 描画だけを 60ms 止め、UI と音声の処理は進める。
			sprite.speed_scale = 0.0
			sprite.modulate = Color(1.6, 0.85, 0.68)
			_motion = create_tween()
			_motion.tween_interval(0.06)
			_motion.tween_property(sprite, "speed_scale", 1.0, 0.01)
			_motion.tween_property(sprite, "position:x", -7.0, 0.05)
			_motion.tween_property(sprite, "position:x", 4.0, 0.06)
			_motion.tween_property(sprite, "position:x", 0.0, 0.10)
			_motion.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.10)
		"move":
			_motion = create_tween()
			_motion.tween_property(sprite, "position:y", -5.0, 0.12)
			_motion.tween_property(sprite, "position:y", 0.0, 0.26)


func seek_pose(action: String, frame: int) -> void:
	if not is_instance_valid(sprite) or action not in ACTIONS:
		return
	_reset_pose()
	sprite.animation = action
	sprite.pause()
	sprite.set_frame_and_progress(clampi(frame, 0, FRAME_COUNT - 1), 0.0)


func _reset_pose() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null
	sprite.position = Vector2.ZERO
	sprite.modulate = Color.WHITE
	sprite.speed_scale = 1.0


func _on_pose_finished() -> void:
	var action: String = sprite.animation
	if action != "death":
		_reset_pose()
		sprite.play("idle")
	pose_finished.emit(action)


func _exit_tree() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	if is_instance_valid(sprite):
		sprite.stop()
