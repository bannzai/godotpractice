extends Node2D
## 本体と武器を別パーツとして動かす。画像原寸192×224、原点は画像中心。

const KINDS: Array[String] = [
	"sword", "lance", "axe", "bow", "healer", "raider", "archer", "boss",
	"enemy_sword", "enemy_lance"
]
const POSES: Array[String] = ["idle", "select", "move", "attack", "hurt", "dodge", "defeat"]

var kind: String = "sword"
var enemy: bool = false
var pose: String = "idle"
var animation_player: AnimationPlayer
var body: Node2D
var weapon: Node2D
var body_sprite: Sprite2D
var weapon_sprite: Sprite2D


func _ready() -> void:
	_ensure_nodes()
	configure(kind, enemy)
	play_pose(pose)


func configure(value: String, is_enemy: bool = false) -> void:
	_ensure_nodes()
	kind = value if value in KINDS else "sword"
	enemy = is_enemy
	body_sprite.texture = load("res://assets/units/%s_body.svg" % kind)
	weapon_sprite.texture = load("res://assets/units/%s_weapon.svg" % kind)


func play_pose(value: String) -> void:
	_ensure_nodes()
	var requested: String = value if value in POSES else "idle"
	if pose == requested and animation_player.is_playing():
		return
	pose = requested
	# 同じ継続動作は巻き戻さず、完了した攻撃などは次の行動で再生できる。
	animation_player.play("RESET")
	animation_player.advance(0)
	animation_player.play(pose)
	animation_player.advance(0)


func _ensure_nodes() -> void:
	if is_instance_valid(animation_player):
		return
	body = Node2D.new()
	body.name = "Body"
	add_child(body)
	body_sprite = Sprite2D.new()
	body_sprite.name = "Image"
	body.add_child(body_sprite)
	weapon = Node2D.new()
	weapon.name = "Weapon"
	weapon.position = Vector2(44, 13)
	body.add_child(weapon)
	weapon_sprite = Sprite2D.new()
	weapon_sprite.position = Vector2(0, -20)
	weapon.add_child(weapon_sprite)
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)
	var library: AnimationLibrary = AnimationLibrary.new()
	library.add_animation("RESET", _reset_animation())
	for name_value: String in POSES:
		library.add_animation(name_value, _pose_animation(name_value))
	animation_player.add_animation_library("", library)


func _reset_animation() -> Animation:
	var animation: Animation = Animation.new()
	animation.length = 0.01
	_track(animation, "Body:position", [0.0], [Vector2.ZERO])
	_track(animation, "Body:rotation", [0.0], [0.0])
	_track(animation, "Body:scale", [0.0], [Vector2.ONE])
	_track(animation, "Body:modulate", [0.0], [Color.WHITE])
	_track(animation, "Body/Weapon:rotation", [0.0], [0.0])
	return animation


func _pose_animation(value: String) -> Animation:
	var animation: Animation = Animation.new()
	animation.length = 0.72
	match value:
		"idle", "select":
			animation.length = 1.8 if value == "idle" else 0.9
			animation.loop_mode = Animation.LOOP_LINEAR
			var lift: float = -3.0 if value == "idle" else -11.0
			_track(animation, "Body:position", [0.0, animation.length / 2, animation.length],
				[Vector2.ZERO, Vector2(0, lift), Vector2.ZERO])
			_track(animation, "Body/Weapon:rotation",
				[0.0, animation.length / 2, animation.length], [0.0, -0.09, 0.0])
		"move":
			animation.length = 0.4
			animation.loop_mode = Animation.LOOP_LINEAR
			_track(animation, "Body:position", [0.0, 0.1, 0.2, 0.3, 0.4],
				[Vector2.ZERO, Vector2(0, -11), Vector2.ZERO, Vector2(0, -11), Vector2.ZERO])
			_track(animation, "Body:rotation", [0.0, 0.1, 0.3, 0.4], [0.0, -0.07, 0.07, 0.0])
			_track(animation, "Body/Weapon:rotation", [0.0, 0.2, 0.4], [0.13, -0.13, 0.13])
		"attack":
			_track(animation, "Body:position", [0.0, 0.2, 0.32, 0.5, 0.72],
				[Vector2.ZERO, Vector2(-12, 4), Vector2(20, -4), Vector2(16, 0), Vector2.ZERO])
			_track(animation, "Body:rotation", [0.0, 0.2, 0.32, 0.72], [0.0, -0.1, 0.12, 0.0])
			_track(animation, "Body/Weapon:rotation", [0.0, 0.2, 0.32, 0.48, 0.72],
				[0.0, -1.35, 1.65, 1.1, 0.0])
		"hurt":
			_track(animation, "Body:position", [0.0, 0.08, 0.16, 0.24, 0.72],
				[Vector2.ZERO, Vector2(-19, 0), Vector2(-8, 0), Vector2(-15, 0), Vector2.ZERO])
			_track(animation, "Body:modulate", [0.0, 0.08, 0.18, 0.3, 0.72],
				[Color.WHITE, Color(2, 0.4, 0.3), Color.WHITE, Color(1.8, 0.7, 0.5), Color.WHITE])
			_track(animation, "Body:rotation", [0.0, 0.08, 0.72], [0.0, -0.15, 0.0])
		"dodge":
			_track(animation, "Body:position", [0.0, 0.15, 0.36, 0.72],
				[Vector2.ZERO, Vector2(-35, -12), Vector2(-28, -7), Vector2.ZERO])
			_track(animation, "Body:rotation", [0.0, 0.15, 0.72], [0.0, -0.25, 0.0])
			_track(animation, "Body:modulate", [0.0, 0.15, 0.72],
				[Color.WHITE, Color(0.5, 1.2, 1.2, 0.55), Color.WHITE])
		"defeat":
			_track(animation, "Body:position", [0.0, 0.3, 0.72],
				[Vector2.ZERO, Vector2(0, 28), Vector2(16, 52)])
			_track(animation, "Body:rotation", [0.0, 0.3, 0.72], [0.0, 0.35, 1.2])
			_track(animation, "Body/Weapon:rotation", [0.0, 0.3, 0.72], [0.0, -0.6, -1.2])
			_track(animation, "Body:modulate", [0.0, 0.4, 0.72],
				[Color.WHITE, Color(0.7, 0.7, 0.8), Color(0.6, 0.6, 0.7, 0.25)])
	return animation


func _track(animation: Animation, path: String, times: Array, values: Array) -> void:
	var index: int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(index, NodePath(path))
	animation.track_set_interpolation_type(index, Animation.INTERPOLATION_LINEAR)
	for key: int in range(times.size()):
		animation.track_insert_key(index, times[key], values[key])
