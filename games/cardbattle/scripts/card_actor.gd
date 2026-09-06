extends Control
## カードの絵と部位の動きを、手札・盤面・拡大表示で共有する。

const ACTIONS: Array[String] = ["idle", "summon", "attack", "hit", "death"]
const CANVAS := Vector2(320, 240)
const Catalog = preload("res://scripts/card_catalog.gd")
const HEAD_PIVOTS := {
	"m02": Vector2(230, 110), "m05": Vector2(212, 110), "m08": Vector2(227, 95),
	"m09": Vector2(59, 163), "m14": Vector2(225, 103), "m17": Vector2(162, 105),
	"m20": Vector2(225, 92),
}

var card_id: String = ""
var animation_player: AnimationPlayer
var rig: Node2D
var body: Sprite2D
var head: Sprite2D
var accent: Sprite2D
var backdrop: Sprite2D
var stage: Node2D
var action: String = "idle"
var stop_remaining: float = 0.0
var preview: bool = false
var family: int = 0
var handedness: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	if is_instance_valid(animation_player) and not preview:
		play_action(action)


func setup(id: String, display_size: Vector2) -> void:
	_ensure_nodes()
	size = display_size
	stage.position = size * 0.5
	stage.scale = Vector2.ONE * minf(size.x / CANVAS.x, size.y / CANVAS.y)
	if card_id == id:
		return
	card_id = id
	var monster: bool = Catalog.card(id).type == "monster"
	family = int(id.substr(1)) % 12 if monster else 4
	handedness = -1.0 if monster and int(id.substr(1)) >= 12 else 1.0
	body.texture = load("res://assets/art/cards/%s.svg" % id) as Texture2D
	body.scale = CANVAS / body.texture.get_size()
	body.offset = -body.texture.get_size() * 0.5
	_load_parts()
	_build_animations()
	if is_inside_tree():
		play_action("idle")


func animation_length(action_name: String) -> float:
	if animation_player.has_animation(action_name):
		return animation_player.get_animation(action_name).length
	return 0.0


# 演出はイベントごとに先頭から再生するため非冪等。
func play_action(action_name: String) -> void:
	if not animation_player.has_animation(action_name):
		return
	action = action_name
	preview = false
	animation_player.speed_scale = 1.0
	animation_player.stop()
	animation_player.play(action_name)
	animation_player.advance(0.0)


func seek_action(action_name: String, seconds: float) -> void:
	if not animation_player.has_animation(action_name):
		return
	action = action_name
	preview = true
	animation_player.play(action_name)
	animation_player.seek(clampf(seconds, 0.0, animation_length(action_name)), true)
	animation_player.pause()


func hit_stop(seconds: float = 0.055) -> void:
	if preview or not is_instance_valid(animation_player):
		return
	stop_remaining = maxf(stop_remaining, seconds)
	animation_player.speed_scale = 0.0


# 衝撃で止めた再生速度は実時間に応じて復帰するため非冪等。
func _process(delta: float) -> void:
	if stop_remaining > 0.0:
		stop_remaining = maxf(0.0, stop_remaining - delta)
		if stop_remaining == 0.0 and is_instance_valid(animation_player):
			animation_player.speed_scale = 1.0


func _ensure_nodes() -> void:
	if is_instance_valid(stage):
		return
	stage = Node2D.new()
	stage.name = "Stage"
	add_child(stage)
	backdrop = Sprite2D.new()
	backdrop.name = "Backdrop"
	stage.add_child(backdrop)
	rig = Node2D.new()
	rig.name = "Rig"
	stage.add_child(rig)
	body = Sprite2D.new()
	body.name = "Body"
	body.centered = false
	rig.add_child(body)
	head = Sprite2D.new()
	head.name = "Head"
	head.centered = false
	head.position = Vector2(0, -35)
	rig.add_child(head)
	accent = Sprite2D.new()
	accent.name = "Accent"
	accent.centered = false
	rig.add_child(accent)
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)
	animation_player.animation_finished.connect(_animation_finished)


func _load_parts() -> void:
	var monster: bool = Catalog.card(card_id).type == "monster"
	head.visible = monster
	accent.visible = monster
	backdrop.visible = monster
	if not monster:
		return
	var directory: String = "res://assets/art/characters/%s/" % card_id
	body.texture = load(directory + "body.svg") as Texture2D
	body.scale = Vector2.ONE
	body.offset = -CANVAS * 0.5
	head.texture = load(directory + "head.svg") as Texture2D
	head.position = HEAD_PIVOTS.get(card_id, Vector2(160, 84)) - CANVAS * 0.5
	head.offset = -CANVAS * 0.5 - head.position
	accent.texture = load(directory + "accent.svg") as Texture2D
	accent.position = Vector2(40, 25) if family in [0, 1, 7] else Vector2(0, 8)
	accent.offset = -CANVAS * 0.5 - accent.position
	var behind: bool = card_id in [
		"m02", "m03", "m05", "m08", "m10", "m15", "m17", "m20", "m22",
	]
	rig.move_child(accent, 0 if behind else rig.get_child_count() - 1)
	backdrop.texture = load(directory + "background.svg") as Texture2D


func _build_animations() -> void:
	animation_player.stop()
	if animation_player.has_animation_library(""):
		animation_player.remove_animation_library("")
	var library := AnimationLibrary.new()
	library.add_animation("idle", _idle_animation())
	library.add_animation("summon", _summon_animation())
	library.add_animation("attack", _attack_animation())
	library.add_animation("hit", _hit_animation())
	library.add_animation("death", _death_animation())
	animation_player.add_animation_library("", library)


func _new_animation(duration: float) -> Animation:
	var animation := Animation.new()
	animation.length = duration
	_track(animation, "Stage/Rig:position", [0.0], [Vector2.ZERO])
	_track(animation, "Stage/Rig:rotation", [0.0], [0.0])
	_track(animation, "Stage/Rig:scale", [0.0], [Vector2.ONE])
	_track(animation, "Stage/Rig:modulate", [0.0], [Color.WHITE])
	_track(animation, "Stage/Rig/Head:rotation", [0.0], [0.0])
	_track(animation, "Stage/Rig/Accent:rotation", [0.0], [0.0])
	return animation


func _idle_animation() -> Animation:
	var length: float = 2.4 + family * 0.11
	var animation: Animation = _new_animation(length)
	animation.loop_mode = Animation.LOOP_LINEAR
	var lift: float = 3.0
	var lean: float = 0.01
	var weapon: float = 0.03
	if family in [3, 4, 8, 10]:
		lift = 9.0
		weapon = 0.11
	elif family in [2, 5]:
		lean = 0.035
		weapon = 0.06
	elif family in [6, 9]:
		lift = 1.8
		lean = 0.008
	var times: Array = [0.0, length * 0.25, length * 0.5, length * 0.75, length]
	_replace_track(animation, "Stage/Rig:position", times,
		[Vector2.ZERO, Vector2(1, -lift), Vector2.ZERO, Vector2(-1, lift * 0.3), Vector2.ZERO])
	_replace_track(animation, "Stage/Rig:rotation", times,
		[0.0, lean, 0.0, -lean, 0.0])
	_replace_track(animation, "Stage/Rig/Accent:rotation", times,
		[0.0, weapon, 0.0, -weapon * 0.6, 0.0])
	_replace_track(animation, "Stage/Rig/Head:rotation", times,
		[0.0, -lean * 1.8, 0.0, lean * 1.4, 0.0])
	return animation


func _summon_animation() -> Animation:
	var animation: Animation = _new_animation(0.58)
	var times: Array = [0.0, 0.14, 0.31, 0.44, 0.58]
	_replace_track(animation, "Stage/Rig:position", times,
		[Vector2(0, 55), Vector2(0, 28), Vector2(0, -15), Vector2(0, 5), Vector2.ZERO])
	_replace_track(animation, "Stage/Rig:scale", times,
		[Vector2(0.5, 0.12), Vector2(0.82, 1.16), Vector2(1.07, 0.96),
		Vector2(0.99, 1.01), Vector2.ONE])
	_replace_track(animation, "Stage/Rig:modulate", times,
		[Color(1, 1, 1, 0), Color("fff1b6"), Color.WHITE, Color.WHITE, Color.WHITE])
	_replace_track(animation, "Stage/Rig/Accent:rotation", times,
		[-0.42 * handedness, -0.22 * handedness, 0.12 * handedness, 0.0, 0.0])
	_replace_track(animation, "Stage/Rig/Head:rotation", times, [0.20, 0.14, -0.12, 0.04, 0.0])
	return animation


func _attack_animation() -> Animation:
	var animation: Animation = _new_animation(0.60)
	var times: Array = [0.0, 0.14, 0.22, 0.31, 0.43, 0.60]
	var lunge: Vector2 = Vector2(36, 4)
	var turn: float = 0.18
	var swing: float = 0.72
	if family in [2, 5]:
		lunge = Vector2(44, -30)
		turn = 0.25
	elif family in [4, 11]:
		lunge = Vector2(0, -24)
		turn = 0.04
		swing = -0.28
	elif family in [6, 9]:
		lunge = Vector2(17, 21)
		turn = 0.10
		swing = 0.40
	elif family in [3, 8, 10]:
		lunge = Vector2(25, -20)
		swing = 0.50
	elif family in [1, 7]:
		lunge = Vector2(52, -3)
		swing = 0.32
	lunge.x *= handedness
	turn *= handedness
	swing *= handedness
	_replace_track(animation, "Stage/Rig:position", times,
		[Vector2.ZERO, -lunge * 0.35, lunge, lunge * 0.8, -lunge * 0.08, Vector2.ZERO])
	_replace_track(animation, "Stage/Rig:rotation", times,
		[0.0, -turn * 0.6, turn, turn * 0.7, -turn * 0.15, 0.0])
	_replace_track(animation, "Stage/Rig/Accent:rotation", times,
		[0.0, -swing * 0.65, swing, swing * 0.65, -swing * 0.12, 0.0])
	_replace_track(animation, "Stage/Rig/Head:rotation", times,
		[0.0, turn * 0.4, -turn * 0.7, -turn * 0.5, turn * 0.12, 0.0])
	_replace_track(animation, "Stage/Rig:scale", times,
		[Vector2.ONE, Vector2(0.90, 0.86), Vector2(0.70, 0.74),
		Vector2(0.78, 0.76), Vector2(0.98, 1.0), Vector2.ONE])
	return animation


func _hit_animation() -> Animation:
	var animation: Animation = _new_animation(0.46)
	var times: Array = [0.0, 0.055, 0.10, 0.16, 0.25, 0.46]
	var recoil: float = 11.0 if family in [6, 9] else 27.0
	_replace_track(animation, "Stage/Rig:position", times,
		[Vector2.ZERO, Vector2(-recoil, 7), Vector2(recoil * 0.4, -3),
		Vector2(-recoil * 0.35, 3), Vector2(recoil * 0.1, 0), Vector2.ZERO])
	_replace_track(animation, "Stage/Rig:rotation", times, [0.0, -0.13, 0.08, -0.04, 0.01, 0.0])
	_replace_track(animation, "Stage/Rig:modulate", times,
		[Color.WHITE, Color("ff927e"), Color.WHITE, Color("ffc7a4"), Color.WHITE, Color.WHITE])
	_replace_track(animation, "Stage/Rig/Accent:rotation", times, [0.0, -0.4, 0.22, -0.1, 0.0, 0.0])
	_replace_track(animation, "Stage/Rig/Head:rotation", times, [0.0, -0.16, 0.12, -0.06, 0.0, 0.0])
	return animation


func _death_animation() -> Animation:
	var animation: Animation = _new_animation(0.62)
	var times: Array = [0.0, 0.12, 0.24, 0.43, 0.62]
	_replace_track(animation, "Stage/Rig:position", times,
		[Vector2.ZERO, Vector2(0, -4), Vector2(8, 13), Vector2(20, 40), Vector2(26, 78)])
	_replace_track(animation, "Stage/Rig:rotation", times,
		[0.0, -0.08, 0.13, 0.35 * handedness, 0.55 * handedness])
	_replace_track(animation, "Stage/Rig:modulate", times,
		[Color.WHITE, Color("fff0b3"), Color("e7867b"), Color(0.25, 0.20, 0.32, 0.65),
		Color(0.15, 0.12, 0.22, 0)])
	_replace_track(animation, "Stage/Rig/Accent:rotation", times,
		[0.0, 0.12, 0.38 * handedness, 0.9 * handedness, 1.5 * handedness])
	_replace_track(animation, "Stage/Rig/Head:rotation", times,
		[0.0, -0.12, 0.18 * handedness, 0.38 * handedness, 0.55 * handedness])
	return animation


func _replace_track(animation: Animation, path: String, times: Array, values: Array) -> void:
	var index: int = animation.find_track(NodePath(path), Animation.TYPE_VALUE)
	if index >= 0:
		animation.remove_track(index)
	_track(animation, path, times, values)


func _track(animation: Animation, path: String, times: Array, values: Array) -> void:
	var index: int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(index, NodePath(path))
	animation.track_set_interpolation_type(index, Animation.INTERPOLATION_CUBIC)
	for key: int in range(times.size()):
		animation.track_insert_key(index, times[key], values[key])


func _animation_finished(name: StringName) -> void:
	if not preview and name != "death":
		play_action("idle")
