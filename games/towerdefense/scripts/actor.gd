extends Node2D
## 表示だけを所有する。ゲーム上のHPや座標はRunが正。

const TOWER_ATLAS := "res://assets/tapestry/towers.png"
const ENEMY_ATLAS := "res://assets/tapestry/enemies.png"
const TOWER_KINDS: Array[String] = ["arrow", "mortar", "frost", "sun"]
const ENEMY_KINDS: Array[String] = ["runner", "armor", "flyer", "swarm", "boss"]
const MOTIONS: Array[String] = ["idle", "move", "attack", "hurt", "death"]
const FPS: Array[float] = [7.0, 10.0, 16.0, 20.0, 9.0]
const FRAME_COUNT: int = 6
const ENEMY_REGION_RATIOS: Dictionary = {
	"runner": Rect2(0.00, 0.20, 0.24, 0.80),
	"armor": Rect2(0.215, 0.13, 0.255, 0.87),
	"flyer": Rect2(0.44, 0.04, 0.21, 0.62),
	"swarm": Rect2(0.52, 0.50, 0.23, 0.50),
	"boss": Rect2(0.74, 0.00, 0.26, 1.00),
}

var sprite: AnimatedSprite2D
var kind: String = ""
var resting: String = "idle"
var flash_tween: Tween
var base_scale: Vector2 = Vector2.ONE
var is_enemy_actor: bool = false


func setup(value: String, is_enemy: bool = false) -> void:
	if kind == value and is_instance_valid(sprite):
		return
	if is_instance_valid(sprite):
		sprite.free()
	kind = value
	is_enemy_actor = is_enemy
	resting = "move" if is_enemy else "idle"
	sprite = AnimatedSprite2D.new()
	var sheet: Texture2D = load(ENEMY_ATLAS if is_enemy else TOWER_ATLAS)
	var region := _atlas_region(sheet, value, is_enemy)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row: int in range(MOTIONS.size()):
		var motion: String = MOTIONS[row]
		frames.add_animation(motion)
		frames.set_animation_speed(motion, FPS[row])
		frames.set_animation_loop(motion, row < 2)
		if not is_enemy and motion == "move":
			frames.set_animation_loop(motion, false)
		for _column: int in range(FRAME_COUNT):
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = region
			frame.filter_clip = true
			frames.add_frame(motion, frame)
	sprite.sprite_frames = frames
	base_scale = Vector2.ONE * (_display_height(value, is_enemy) / region.size.y)
	add_child(sprite)
	sprite.frame_changed.connect(_apply_frame_pose)
	sprite.animation_finished.connect(_motion_finished)
	sprite.play(resting)
	_apply_frame_pose()
	if is_enemy:
		sprite.play("idle")
		var arrival: Tween = create_tween()
		arrival.tween_interval(0.35)
		arrival.tween_callback(func() -> void:
			if sprite.animation == "idle":
				sprite.play(resting)
				_apply_frame_pose())
	else:
		sprite.play("move")
		_apply_frame_pose()


func _atlas_region(sheet: Texture2D, value: String, is_enemy: bool) -> Rect2:
	var texture_size := Vector2(sheet.get_width(), sheet.get_height())
	if is_enemy:
		var ratio: Rect2 = ENEMY_REGION_RATIOS[value]
		return Rect2(ratio.position * texture_size, ratio.size * texture_size)
	var index: int = TOWER_KINDS.find(value)
	var cell_width: float = texture_size.x / TOWER_KINDS.size()
	return Rect2(index * cell_width, 0.0, cell_width, texture_size.y)


func _display_height(value: String, is_enemy: bool) -> float:
	if not is_enemy:
		return 112.0
	match value:
		"boss":
			return 136.0
		"swarm":
			return 62.0
		"flyer":
			return 70.0
		_:
			return 82.0


## 個々の命中・攻撃で再生を開始するため、呼び出しごとに先頭へ戻す。
func act(motion: String) -> void:
	if sprite.animation == "death" or motion not in MOTIONS:
		return
	if motion != "hurt":
		_reset_flash()
	sprite.play(motion)
	sprite.set_frame_and_progress(0, 0.0)
	_apply_frame_pose()
	if motion == "hurt":
		if flash_tween != null:
			flash_tween.kill()
		sprite.modulate = Color(1.9, 1.15, 1.05)
		sprite.speed_scale = 0.0
		flash_tween = create_tween()
		flash_tween.tween_interval(0.055)
		flash_tween.tween_property(sprite, "speed_scale", 1.0, 0.01)
		flash_tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.15)


func pose(motion: String, frame: int) -> void:
	sprite.pause()
	sprite.animation = motion
	sprite.frame = clampi(frame, 0, FRAME_COUNT - 1)
	_apply_frame_pose()


## 1枚絵の各領域へ刺繍人形らしい揺れ・踏み込み・倒れ込みを与える。
func _apply_frame_pose() -> void:
	if not is_instance_valid(sprite):
		return
	var progress: float = float(sprite.frame) / float(FRAME_COUNT - 1)
	var cycle: float = sin(progress * TAU)
	var pose_scale := Vector2.ONE
	var offset := Vector2.ZERO
	var angle: float = 0.0
	var tint := Color.WHITE
	match sprite.animation:
		"idle":
			offset.y = -absf(cycle) * 2.0
			pose_scale = Vector2(1.0 + cycle * 0.018, 1.0 - cycle * 0.018)
			angle = cycle * 0.012
		"move":
			offset = Vector2(cycle * 3.2, -absf(cycle) * 4.0)
			pose_scale = Vector2(1.0 - absf(cycle) * 0.025, 1.0 + absf(cycle) * 0.04)
			angle = cycle * 0.045
		"attack":
			var thrust: float = sin(progress * PI)
			offset = Vector2(thrust * 8.0, -thrust * 2.0)
			pose_scale = Vector2(1.0 + thrust * 0.09, 1.0 - thrust * 0.045)
			angle = -0.07 + progress * 0.12
		"hurt":
			var recoil: float = 1.0 - progress
			offset.x = recoil * (7.0 if sprite.frame % 2 == 0 else -7.0)
			pose_scale = Vector2(1.0 + recoil * 0.08, 1.0 - recoil * 0.08)
			angle = recoil * (0.09 if sprite.frame % 2 == 0 else -0.09)
			tint = Color(1.0, 0.72 + progress * 0.28, 0.65 + progress * 0.35)
		"death":
			offset = Vector2(progress * 8.0, progress * 13.0)
			pose_scale = Vector2(1.0 + progress * 0.1, 1.0 - progress * 0.72)
			angle = progress * (-0.72 if is_enemy_actor else 0.65)
			tint = Color(0.72, 0.64, 0.52, 1.0 - progress * 0.82)
	sprite.position = offset
	sprite.scale = base_scale * pose_scale
	sprite.rotation = angle
	sprite.self_modulate = tint


func _reset_flash() -> void:
	if flash_tween != null:
		flash_tween.kill()
		flash_tween = null
	if is_instance_valid(sprite):
		sprite.speed_scale = 1.0
		sprite.modulate = Color.WHITE


func _motion_finished() -> void:
	if sprite.animation == "death":
		queue_free()
	else:
		_reset_flash()
		sprite.play(resting)
		_apply_frame_pose()
