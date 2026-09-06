extends Node2D
## キャラクターごとの画像から部位が動くアニメーションを組み立てる。

const ACTIONS: Array[String] = ["idle", "walk", "hoe", "water", "harvest", "tired"]
const CHARACTER_IMAGES: Dictionary = {
	"farmer": preload("res://assets/characters/farmer.svg"),
	"merchant": preload("res://assets/characters/merchant.svg"),
	"chicken": preload("res://assets/characters/chicken.svg"),
}

var sprite: AnimatedSprite2D
var kind: String = ""


func setup(character_kind: String) -> void:
	if kind == character_kind and is_instance_valid(sprite):
		return
	kind = character_kind
	if not is_instance_valid(sprite):
		sprite = AnimatedSprite2D.new()
		sprite.name = "AnimatedSprite2D"
		add_child(sprite)
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation("default")
	var texture: Texture2D = CHARACTER_IMAGES[kind]
	for row: int in range(ACTIONS.size()):
		var action: String = ACTIONS[row]
		frames.add_animation(action)
		frames.set_animation_speed(action, 6.0 if action == "idle" else 9.0)
		frames.set_animation_loop(action, action in ["idle", "walk", "tired"])
		for column: int in range(4):
			var frame: AtlasTexture = AtlasTexture.new()
			frame.atlas = texture
			frame.region = Rect2(column * 128, row * 128, 128, 128)
			frames.add_frame(action, frame)
	sprite.sprite_frames = frames
	sprite.position = Vector2(0, -46)
	sprite.play("idle")


func animate(action: String) -> void:
	if not is_instance_valid(sprite) or not ACTIONS.has(action):
		return
	# 完了した農作業は次の実行要求で再生するため、その場合だけ開始時刻を更新する。
	if sprite.animation != action or not sprite.is_playing():
		sprite.play(action)


func face(direction: Vector2) -> void:
	if is_instance_valid(sprite) and absf(direction.x) > 0.05:
		sprite.flip_h = direction.x < 0.0
