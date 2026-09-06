extends Node2D
## キャラの表示と一時的な戦闘状態。進行の永続状態は AdventureState が所有する。

const MOTIONS: Array[String] = ["idle", "walk", "action", "hurt", "death"]
var kind: String = "hero"
var sprite: AnimatedSprite2D
var hp: int = 2
var timer: float = 0.0
var hurt_time: float = 0.0
var dead: bool = false
var velocity: Vector2 = Vector2.ZERO
var origin: Vector2


func setup(character: String) -> void:
	kind = character
	if is_instance_valid(sprite):
		return
	sprite = AnimatedSprite2D.new()
	var sheet: Texture2D = load("res://assets/characters/%s.svg" % kind)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row: int in range(MOTIONS.size()):
		var motion: String = MOTIONS[row]
		frames.add_animation(motion)
		frames.set_animation_speed(motion, 8.0 if row < 2 else 12.0)
		frames.set_animation_loop(motion, row < 2)
		for col: int in range(4):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(col * 96, row * 96, 96, 96)
			frames.add_frame(motion, atlas)
	sprite.sprite_frames = frames
	add_child(sprite)
	sprite.play("idle")
	if kind == "boss":
		scale = Vector2.ONE * 1.9
		hp = 16
	elif kind == "splitter":
		hp = 3


func motion(name: String) -> void:
	if not is_instance_valid(sprite):
		return
	if dead and name != "death":
		return
	if name in ["idle", "walk"] and sprite.is_playing() \
		and sprite.animation in ["action", "hurt"]:
		return
	if sprite.animation != name:
		sprite.play(name)


# 演出時間を消費して通常色へ戻すため非冪等。
func _process(delta: float) -> void:
	hurt_time = maxf(0.0, hurt_time - delta)
	modulate = Color(2.8, 1.9, 1.4) if hurt_time > 0.15 else Color.WHITE
