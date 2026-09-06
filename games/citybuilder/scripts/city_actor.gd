extends Node2D
## 建物と住民の表示。進行状態は simulation のタイルだけが保持する。

const ACTIONS: Array[String] = ["idle", "build", "demolish", "grow", "problem", "move"]

var kind: String = ""
var sprite: Sprite2D
var animation: AnimationPlayer


func setup(value: String) -> void:
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite"
		sprite.centered = false
		add_child(sprite)
		animation = AnimationPlayer.new()
		animation.name = "AnimationPlayer"
		add_child(animation)
		_make_animations()
	if kind == value:
		return
	kind = value
	var path: String = "res://assets/sprites/%s.svg" % value
	if ResourceLoader.exists(path):
		sprite.texture = load(path) as Texture2D
	if value == "car":
		sprite.offset = Vector2(-20, -12)
	elif value == "walker":
		sprite.offset = Vector2(-10, -29)
	else:
		sprite.offset = Vector2(-32, -68)
	sprite.scale = Vector2.ONE * 0.5
	play_action("idle")


# 操作イベントごとに先頭から演出するため、同じ指定でも再生時刻を戻す。
func play_action(action: String) -> void:
	if animation != null and action in ACTIONS:
		animation.stop()
		sprite.modulate = Color.WHITE
		animation.play(action)


func seek_pose(action: String, progress: float) -> void:
	if animation == null or action not in ACTIONS:
		return
	animation.play(action)
	animation.seek(clampf(progress, 0.0, 1.0) * animation.get_animation(action).length, true)
	animation.pause()


func _make_animations() -> void:
	var library: AnimationLibrary = AnimationLibrary.new()
	_add_action(library, "idle", 2.4, [Vector2(0.5, 0.5), Vector2(0.5, 0.515), Vector2(0.5, 0.5)])
	_add_action(
		library, "build", 0.7, [Vector2(0.05, 0.05), Vector2(0.58, 0.62), Vector2(0.5, 0.5)]
	)
	_add_action(
		library, "demolish", 0.55, [Vector2(0.5, 0.5), Vector2(0.56, 0.3), Vector2(0.02, 0.02)]
	)
	_add_action(library, "grow", 0.8, [Vector2(0.5, 0.35), Vector2(0.56, 0.62), Vector2(0.5, 0.5)])
	_add_action(
		library, "problem", 1.2, [Vector2(0.5, 0.5), Vector2(0.47, 0.52), Vector2(0.5, 0.5)]
	)
	_add_action(library, "move", 0.36, [Vector2(0.5, 0.5), Vector2(0.5, 0.56), Vector2(0.5, 0.5)])
	animation.add_animation_library("", library)


func _add_action(
	library: AnimationLibrary, action: String, duration: float, scales: Array[Vector2]
) -> void:
	var clip: Animation = Animation.new()
	clip.length = duration
	if action in ["idle", "problem", "move"]:
		clip.loop_mode = Animation.LOOP_LINEAR
	var track: int = clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(track, NodePath("Sprite:scale"))
	for index: int in range(3):
		clip.track_insert_key(track, duration * index / 2.0, scales[index])
	if action == "problem":
		var tint: int = clip.add_track(Animation.TYPE_VALUE)
		clip.track_set_path(tint, NodePath("Sprite:modulate"))
		clip.track_insert_key(tint, 0.0, Color.WHITE)
		clip.track_insert_key(tint, duration / 2, Color(1.0, 0.58, 0.43))
		clip.track_insert_key(tint, duration, Color.WHITE)
	library.add_animation(action, clip)
