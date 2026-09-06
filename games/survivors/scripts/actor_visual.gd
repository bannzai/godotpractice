extends Node2D
## キャラ固有の絵とフレーム再生を担当し、ゲーム進行の状態は保持しない。

signal motion_finished(animation: String)

const FRAME_SIZE := 160
const FRAME_COUNT := 6
const ANIMATIONS: Array[String] = ["idle", "move", "attack", "hurt", "death"]
const FRAME_RATES: Array[float] = [7.0, 12.0, 15.0, 20.0, 10.0]
const SHEETS: Array[Texture2D] = [
	preload("res://assets/art/player-sheet.svg"),
	preload("res://assets/art/enemy-0-sheet.svg"),
	preload("res://assets/art/enemy-1-sheet.svg"),
	preload("res://assets/art/enemy-2-sheet.svg"),
	preload("res://assets/art/enemy-3-sheet.svg"),
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
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row: int in range(ANIMATIONS.size()):
		var animation: String = ANIMATIONS[row]
		frames.add_animation(animation)
		frames.set_animation_speed(animation, FRAME_RATES[row])
		frames.set_animation_loop(animation, row < 2)
		for column: int in range(FRAME_COUNT):
			var frame := AtlasTexture.new()
			frame.atlas = SHEETS[_kind + 1]
			frame.region = Rect2(column * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
			frames.add_frame(animation, frame)
	sprite.sprite_frames = frames
	sprite.play("idle")


func reset_motion() -> void:
	_pending_motion = "idle"
	if sprite != null:
		sprite.play("idle")
		sprite.set_frame_and_progress(0, 0.0)


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


# 終了通知は再生された各動作に対応するため、完了イベントごとに送る。
func _on_animation_finished() -> void:
	var animation: String = sprite.animation
	if animation != "death":
		sprite.play(_pending_motion)
	motion_finished.emit(animation)
