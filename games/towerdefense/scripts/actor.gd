extends Node2D
## 表示だけを所有する。ゲーム上のHPや座標はRunが正。

const MOTIONS: Array[String] = ["idle", "move", "attack", "hurt", "death"]
const FPS: Array[float] = [7.0, 10.0, 16.0, 20.0, 9.0]

var sprite: AnimatedSprite2D
var kind: String = ""
var resting: String = "idle"
var flash_tween: Tween


func setup(value: String, is_enemy: bool = false) -> void:
	if kind == value:
		return
	kind = value
	resting = "move" if is_enemy else "idle"
	sprite = AnimatedSprite2D.new()
	var sheet: Texture2D = load("res://assets/actors/%s.svg" % kind)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row: int in range(MOTIONS.size()):
		frames.add_animation(MOTIONS[row])
		frames.set_animation_speed(MOTIONS[row], FPS[row])
		frames.set_animation_loop(MOTIONS[row], row < 2)
		if not is_enemy and row == 1:
			frames.set_animation_loop(MOTIONS[row], false)
		for column: int in range(6):
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(column * 128, row * 128, 128, 128)
			frame.filter_clip = true
			frames.add_frame(MOTIONS[row], frame)
	sprite.sprite_frames = frames
	sprite.scale = Vector2.ONE * (0.58 if is_enemy else 0.78)
	if value == "boss":
		sprite.scale = Vector2.ONE * 1.1
	add_child(sprite)
	sprite.animation_finished.connect(_motion_finished)
	sprite.play(resting)
	if is_enemy:
		sprite.play("idle")
		var arrival: Tween = create_tween()
		arrival.tween_interval(0.35)
		arrival.tween_callback(func() -> void:
			if sprite.animation == "idle":
				sprite.play(resting))
	else:
		sprite.play("move")


# 個々の命中・攻撃で再生を開始するため、呼び出しごとに先頭へ戻す。
func act(motion: String) -> void:
	if sprite.animation == "death":
		return
	sprite.play(motion)
	sprite.set_frame_and_progress(0, 0.0)
	if motion == "hurt":
		if flash_tween != null:
			flash_tween.kill()
		sprite.modulate = Color(2.5, 1.7, 1.5)
		sprite.speed_scale = 0.0
		flash_tween = create_tween()
		flash_tween.tween_interval(0.055)
		flash_tween.tween_property(sprite, "speed_scale", 1.0, 0.01)
		flash_tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.15)


func pose(motion: String, frame: int) -> void:
	sprite.pause()
	sprite.animation = motion
	sprite.frame = frame


func _motion_finished() -> void:
	if sprite.animation == "death":
		queue_free()
	else:
		sprite.play(resting)
