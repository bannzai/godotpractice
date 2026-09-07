extends Node2D
## 画像生成したキャラ固有の絵とポーズ再生を担当する。

signal motion_finished(animation: String)

const FRAME_SIZE := 160
const FRAME_COUNT := 6
const ANIMATIONS: Array[String] = ["idle", "move", "attack", "hurt", "death"]
const FRAME_RATES: Array[float] = [7.0, 12.0, 15.0, 20.0, 10.0]
const SHEETS: Array[Texture2D] = [
	preload("res://assets/generated/player.png"),
	preload("res://assets/generated/enemy-0.png"),
	preload("res://assets/generated/enemy-1.png"),
	preload("res://assets/generated/enemy-2.png"),
	preload("res://assets/generated/enemy-3.png"),
]

var sprite: AnimatedSprite2D
var _kind: int = -99
var _pending_motion: String = "idle"


func setup(kind: int) -> void:
	if kind == _kind:
		return
	_kind = clampi(kind, -1, 3)
	_pending_motion = "idle"
	if sprite == null:
		sprite = AnimatedSprite2D.new()
		add_child(sprite)
		sprite.animation_finished.connect(_on_animation_finished)
		sprite.frame_changed.connect(_apply_pose)
		var neon := ShaderMaterial.new()
		neon.shader = load("res://shaders/neon_sprite.gdshader")
		neon.set_shader_parameter("phase", float(_kind + 1) * 0.83)
		sprite.material = neon
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row: int in range(ANIMATIONS.size()):
		var animation: String = ANIMATIONS[row]
		frames.add_animation(animation)
		frames.set_animation_speed(animation, FRAME_RATES[row])
		frames.set_animation_loop(animation, row < 2)
		for column: int in range(FRAME_COUNT):
			frames.add_frame(animation, SHEETS[_kind + 1])
	sprite.sprite_frames = frames
	sprite.play("idle")
	_apply_pose()


func reset_motion() -> void:
	_pending_motion = "idle"
	if sprite != null:
		sprite.play("idle")
		sprite.set_frame_and_progress(0, 0.0)
		_apply_pose()


func set_motion(animation: String, facing: float = 1.0) -> void:
	if sprite == null or not ANIMATIONS.has(animation):
		return
	if absf(facing) > 0.01:
		sprite.flip_h = facing < 0.0
	if sprite.animation == "death":
		return
	if animation == "idle" or animation == "move":
		_pending_motion = animation
		if sprite.is_playing() and sprite.animation in ["attack", "hurt"]:
			return
	if sprite.animation == animation:
		return
	sprite.play(animation)
	_apply_pose()


func pose_signature(animation: String, frame: int) -> Vector4:
	var phase: int = clampi(frame, 0, FRAME_COUNT - 1)
	match animation:
		"idle":
			var sway: Array[float] = [0.0, 0.55, 1.0, 0.35, -0.55, -1.0]
			return Vector4(sway[phase] * 1.7, -absf(sway[phase]) * 2.5,
				sway[phase] * 0.018, 1.0 + sway[phase] * 0.018)
		"move":
			var lift: Array[float] = [0.0, -5.0, -1.0, -6.0, -2.0, -4.0]
			return Vector4(float(phase - 2) * 0.45, lift[phase],
				[-0.035, 0.015, 0.04, -0.02, -0.045, 0.025][phase], 1.0)
		"attack":
			return Vector4(float(phase) * 1.2, -sin(float(phase) / 5.0 * PI) * 5.0,
				(float(phase) - 2.5) * 0.035, 1.0 + sin(float(phase) / 5.0 * PI) * 0.12)
		"hurt":
			var kick: Array[float] = [-7.0, 6.0, -5.0, 4.0, -2.0, 1.0]
			return Vector4(kick[phase], float(phase) * 0.7, kick[phase] * 0.012,
				1.0 - float(phase) * 0.018)
		"death":
			return Vector4(float(phase) * 3.2, float(phase * phase) * 1.9,
				float(phase) * 0.18, 1.0 - float(phase) * 0.095)
	return Vector4(0, 0, 0, 1)


func _apply_pose() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var pose: Vector4 = pose_signature(sprite.animation, sprite.frame)
	var texture: Texture2D = SHEETS[_kind + 1]
	var fit: float = float(FRAME_SIZE) / maxf(texture.get_width(), texture.get_height())
	sprite.position = Vector2(pose.x, pose.y)
	sprite.rotation = pose.z
	sprite.scale = Vector2.ONE * fit * pose.w
	sprite.modulate = Color.WHITE
	if sprite.animation == "hurt":
		sprite.modulate = Color(1.0, 0.52, 0.9, 1.0)
	elif sprite.animation == "death":
		sprite.modulate.a = 1.0 - float(sprite.frame) / float(FRAME_COUNT) * 0.78


# 終了通知は再生された各動作に対応するため、完了イベントごとに送る。
func _on_animation_finished() -> void:
	var animation: String = sprite.animation
	if animation != "death":
		sprite.play(_pending_motion)
	motion_finished.emit(animation)
