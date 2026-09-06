class_name QuestActor
extends Control
## キャラクターごとの原画と姿勢を、画面側から独立して表示する。

const ACTIONS: Array[String] = ["idle", "walk", "attack", "hurt", "defeat"]
const FRAME_SIZE := 192
const FRAME_COUNT := 6

var sprite: AnimatedSprite2D
var _character_id := ""


func setup(character_id: String, rect: Rect2) -> void:
	position = rect.position
	size = rect.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not is_instance_valid(sprite):
		sprite = AnimatedSprite2D.new()
		add_child(sprite)
	sprite.position = rect.size / 2.0
	sprite.scale = Vector2.ONE * minf(rect.size.x, rect.size.y) / FRAME_SIZE
	if _character_id == character_id:
		return
	_character_id = character_id
	var sheet := load("res://assets/characters/%s.svg" % character_id) as Texture2D
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row in range(ACTIONS.size()):
		var action: String = ACTIONS[row]
		frames.add_animation(action)
		frames.set_animation_loop(action, action in ["idle", "walk"])
		frames.set_animation_speed(action, 8.0 if action == "idle" else 12.0)
		for column in range(FRAME_COUNT):
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(column * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
			frames.add_frame(action, frame)
	sprite.sprite_frames = frames
	sprite.play("idle")


func set_action(action: String) -> void:
	if not is_instance_valid(sprite) or not sprite.sprite_frames.has_animation(action):
		return
	# 終了済みの攻撃は次のターンで再実行するため、停止中の同名アニメーションを再開する。
	if sprite.animation != action or not sprite.is_playing():
		if sprite.animation == action:
			sprite.set_frame_and_progress(0, 0.0)
		sprite.play(action)
