extends Node2D
## キャラクター固有の素材を、盤上・札・肖像・撮影で共通に使う。

signal pose_finished(action: String)

const FRAME_SIZE := Vector2(256, 320)
const FRAME_COUNT: int = 4
const ACTIONS: Array[String] = ["idle", "move", "attack", "hurt", "death"]
const RATES: Array[float] = [4.0, 9.0, 10.0, 9.0, 6.0]

var sprite: AnimatedSprite2D
var generated_art: Sprite2D
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
	_setup_generated_art(id)
	sprite.play("idle")


func _setup_generated_art(id: String) -> void:
	var filename: String = ""
	var cards: Array[String] = [
		"reed", "blade", "veil", "bow", "oracle", "wraith",
		"shield", "lancer", "monk", "drummer", "fox", "dragon"
	]
	if id in cards:
		filename = "card-%s" % id
	elif id in ["hero", "scout", "duelist", "general", "final"]:
		filename = "portrait-%s" % id
	var path: String = "res://assets/art/generated/%s.png" % filename
	if filename.is_empty() or not ResourceLoader.exists(path):
		sprite.visible = true
		if is_instance_valid(generated_art):
			generated_art.visible = false
		return
	if not is_instance_valid(generated_art):
		generated_art = Sprite2D.new()
		generated_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(generated_art)
	generated_art.texture = load(path)
	generated_art.scale = Vector2.ONE * (256.0 / generated_art.texture.get_width())
	generated_art.visible = true
	sprite.visible = false


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
	var has_generated: bool = is_instance_valid(generated_art) and generated_art.visible
	var visual: CanvasItem = generated_art if has_generated else sprite
	match action:
		"attack":
			_motion = create_tween()
			_motion.tween_property(visual, "position:x", -8.0, 0.09)
			_motion.tween_property(visual, "position:x", 16.0, 0.07)
			_motion.tween_property(visual, "position:x", 0.0, 0.20)
		"hurt":
			# 描画だけを 60ms 止め、UI と音声の処理は進める。
			sprite.speed_scale = 0.0
			visual.modulate = Color(1.6, 0.85, 0.68)
			_motion = create_tween()
			_motion.tween_interval(0.06)
			_motion.tween_property(sprite, "speed_scale", 1.0, 0.01)
			_motion.tween_property(visual, "position:x", -7.0, 0.05)
			_motion.tween_property(visual, "position:x", 4.0, 0.06)
			_motion.tween_property(visual, "position:x", 0.0, 0.10)
			_motion.parallel().tween_property(visual, "modulate", Color.WHITE, 0.10)
		"move":
			_motion = create_tween()
			_motion.tween_property(visual, "position:y", -5.0, 0.12)
			_motion.tween_property(visual, "position:y", 0.0, 0.26)
		"death":
			if visual != sprite:
				_motion = create_tween().set_parallel(true)
				_motion.tween_property(visual, "modulate:a", 0.0, 0.55)
				_motion.tween_property(visual, "rotation", 0.09, 0.55)


func seek_pose(action: String, frame: int) -> void:
	if not is_instance_valid(sprite) or action not in ACTIONS:
		return
	_reset_pose()
	sprite.animation = action
	sprite.pause()
	sprite.set_frame_and_progress(clampi(frame, 0, FRAME_COUNT - 1), 0.0)
	if is_instance_valid(generated_art) and generated_art.visible:
		var amount: float = float(clampi(frame, 0, FRAME_COUNT - 1)) / 3.0
		match action:
			"move":
				generated_art.position.y = -8.0 * sin(amount * PI)
			"attack":
				generated_art.position.x = 18.0 * amount
			"hurt":
				generated_art.position.x = -7.0 + 7.0 * amount
				generated_art.modulate = Color(1.0, 0.75 + amount * 0.25, 0.72 + amount * 0.28)
			"death":
				generated_art.rotation = amount * 0.09
				generated_art.modulate.a = 1.0 - amount * 0.75


func _reset_pose() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null
	sprite.position = Vector2.ZERO
	sprite.modulate = Color.WHITE
	sprite.speed_scale = 1.0
	if is_instance_valid(generated_art):
		generated_art.position = Vector2.ZERO
		generated_art.rotation = 0.0
		generated_art.modulate = Color.WHITE


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
