class_name FighterBody
extends Node2D
## 移動・技進行・命中は各物理 tick の時間と入力を消費するため非冪等。
## reset_fighter/configure は繰り返し呼んでも同じ初期状態になる。

signal struck(at: Vector2, blocked: bool)
signal special_cast

const RULES: Script = preload("res://scripts/combat_rules.gd")
const PROJECTILE: Script = preload("res://scripts/projectile.gd")
const FLOOR_Y: float = 570.0
const GRAVITY: float = 1650.0

var opponent: FighterBody
var enabled: bool = false
var health: int = 1000
var facing: float = 1.0
var action: String = ""
var crouching: bool = false
var velocity: Vector2 = Vector2.ZERO
var hitstop: float = 0.0
var stun: float = 0.0
var character_index: int = 0
var is_cpu: bool = false
var hurtbox: Area2D
var attackbox: Area2D
var move_data: Dictionary = {}
var attack_time: float = 0.0
var animation_time: float = 0.0
var guard_flash: float = 0.0
var hit_flash: float = 0.0
var last_outcome: String = ""
var attack_stance: String = "standing"
var _direction: Vector2 = Vector2.ZERO
var _connected: bool = false
var _cast: bool = false
var _hurt_shape: RectangleShape2D
var _hit_shape: RectangleShape2D
var _recovery: float = 0.0
var _guarding_stun: bool = false


func _ready() -> void:
	_build_areas()


func configure(index: int, cpu: bool) -> void:
	character_index = clampi(index, 0, 1)
	is_cpu = cpu
	reset_fighter(position)


func reset_fighter(at: Vector2) -> void:
	position = at
	facing = 1.0 if at.x < 640.0 else -1.0
	health = 1000
	action = ""
	crouching = false
	velocity = Vector2.ZERO
	hitstop = 0.0
	stun = 0.0
	guard_flash = 0.0
	hit_flash = 0.0
	attack_time = 0.0
	animation_time = 0.0
	_direction = Vector2.ZERO
	_connected = false
	_cast = false
	move_data = {}
	attack_stance = "standing"
	_recovery = 0.0
	_guarding_stun = false
	last_outcome = ""
	queue_redraw()


func control(direction: Vector2, attack: String = "") -> void:
	_direction = direction
	if enabled and not attack.is_empty():
		start_attack(attack)


func start_attack(kind: String) -> bool:
	if not enabled or health <= 0 or stun > 0.0 or hitstop > 0.0 or not action.is_empty():
		return false
	var stance: String = "air" if position.y < FLOOR_Y - 1.0 else "standing"
	if stance == "standing" and _direction.y > 0.4:
		stance = "crouching"
	if kind == "special" and stance == "air":
		return false
	var data: Dictionary = RULES.move(kind, stance, character_index)
	if data.is_empty():
		return false
	move_data = data
	attack_stance = stance
	crouching = stance == "crouching"
	action = kind
	attack_time = 0.0
	_connected = false
	_cast = false
	last_outcome = "空振り"
	_recovery = float(data.whiff_recovery)
	if is_instance_valid(attackbox):
		_hit_shape.size = Vector2(float(data.reach), 44.0)
		attackbox.position = Vector2(facing * float(data.reach) * 0.5, float(data.height))
	return true


func receive_hit(data: Dictionary, from: Vector2) -> bool:
	if not enabled or health <= 0:
		return false
	var airborne: bool = position.y < FLOOR_Y - 1.0
	var can_guard: bool = action.is_empty() and (stun <= 0.0 or _guarding_stun)
	if can_guard and not airborne:
		crouching = _direction.y > 0.4
	var guarding: bool = _direction.x * facing < -0.2 and can_guard
	guarding = guarding and RULES.blocks(str(data.level), crouching, airborne)
	_guarding_stun = guarding
	var push: float = 1.0 if position.x >= from.x else -1.0
	if guarding:
		stun = float(data.guardstun)
		guard_flash = 0.22
		velocity.x = push * float(data.knockback) * 0.45
	else:
		health = maxi(0, health - int(data.damage))
		stun = float(data.hitstun)
		hit_flash = 0.16
		velocity.x = push * float(data.knockback)
		if airborne:
			velocity.y = minf(velocity.y, -190.0)
		action = ""
	hitstop = float(data.hitstop)
	struck.emit(global_position + Vector2(0.0, -90.0), guarding)
	return guarding


func _physics_process(delta: float) -> void:
	if not enabled:
		queue_redraw()
		return
	if hitstop > 0.0:
		hitstop = maxf(0.0, hitstop - delta)
		return
	animation_time += delta
	guard_flash = maxf(0.0, guard_flash - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	stun = maxf(0.0, stun - delta)
	if stun <= 0.0:
		_guarding_stun = false
	var grounded: bool = position.y >= FLOOR_Y - 0.5
	if action.is_empty() and stun <= 0.0 and health > 0:
		if is_instance_valid(opponent):
			facing = 1.0 if opponent.position.x >= position.x else -1.0
		crouching = grounded and _direction.y > 0.4
		if grounded:
			velocity.x = _direction.x * (250.0 if character_index == 0 else 215.0)
			if crouching:
				velocity.x = 0.0
			if _direction.y < -0.4:
				velocity.y = -710.0
				crouching = false
	elif grounded:
		velocity.x = move_toward(velocity.x, 0.0, 1100.0 * delta)
	velocity.y += GRAVITY * delta
	position += velocity * delta
	position.x = clampf(position.x, 85.0, 1195.0)
	if position.y >= FLOOR_Y:
		position.y = FLOOR_Y
		velocity.y = 0.0
	_separate_bodies()
	_update_hurtbox()
	if not action.is_empty():
		_advance_attack(delta)
	queue_redraw()


func _build_areas() -> void:
	hurtbox = Area2D.new()
	hurtbox.collision_layer = 1
	hurtbox.collision_mask = 0
	_hurt_shape = RectangleShape2D.new()
	_hurt_shape.size = Vector2(66.0, 149.0)
	var hurt_collision: CollisionShape2D = CollisionShape2D.new()
	hurt_collision.shape = _hurt_shape
	hurtbox.add_child(hurt_collision)
	add_child(hurtbox)
	attackbox = Area2D.new()
	attackbox.collision_layer = 2
	attackbox.collision_mask = 1
	_hit_shape = RectangleShape2D.new()
	_hit_shape.size = Vector2(90.0, 44.0)
	var hit_collision: CollisionShape2D = CollisionShape2D.new()
	hit_collision.shape = _hit_shape
	attackbox.add_child(hit_collision)
	add_child(attackbox)
	_update_hurtbox()


func _update_hurtbox() -> void:
	var height: float = 92.0 if crouching else 149.0
	_hurt_shape.size = Vector2(66.0, height)
	hurtbox.position.y = -height * 0.5


func _separate_bodies() -> void:
	if not is_instance_valid(opponent) or absf(position.y - opponent.position.y) > 95.0:
		return
	var gap: float = position.x - opponent.position.x
	if absf(gap) < 69.0:
		position.x = opponent.position.x + (69.0 if gap > 0.0 else -69.0)
		position.x = clampf(position.x, 85.0, 1195.0)


func _advance_attack(delta: float) -> void:
	attack_time += delta
	var startup: float = float(move_data.startup)
	var active_end: float = startup + float(move_data.active)
	if attack_time >= startup and attack_time < active_end:
		if action == "special":
			if not _cast:
				_cast_projectile()
		elif not _connected and is_instance_valid(opponent):
			for area: Area2D in attackbox.get_overlapping_areas():
				if area == opponent.hurtbox:
					_connected = true
					var blocked: bool = opponent.receive_hit(move_data, global_position)
					_recovery = float(move_data.guard_recovery if blocked else move_data.hit_recovery)
					last_outcome = "ガード" if blocked else "命中"
					hitstop = float(move_data.hitstop)
					break
	if attack_time >= active_end + _recovery:
		action = ""


func _cast_projectile() -> void:
	_cast = true
	var projectile: FighterProjectile = PROJECTILE.new()
	projectile.position = position + Vector2(facing * 73.0, -90.0)
	projectile.direction = facing
	projectile.source = self
	projectile.target = opponent
	projectile.move_data = move_data.duplicate()
	projectile.tint = Color("55e5e0") if character_index == 0 else Color("ffab68")
	get_parent().add_child(projectile)
	special_cast.emit()


func _draw() -> void:
	var accent: Color = Color("5ce4d8") if character_index == 0 else Color("ffad64")
	var armor: Color = Color("167b82") if character_index == 0 else Color("b8563b")
	var dark: Color = Color("172b39")
	var phase: float = sin(animation_time * 4.5)
	var hip: Vector2 = Vector2(-4.0, -76.0)
	var chest: Vector2 = Vector2(1.0, -118.0 + phase * 2.0)
	var head: Vector2 = Vector2(4.0, -145.0 + phase * 2.0)
	var rear_foot: Vector2 = Vector2(-32.0, -7.0)
	var front_foot: Vector2 = Vector2(36.0, -7.0)
	var rear_hand: Vector2 = Vector2(-25.0, -103.0)
	var front_hand: Vector2 = Vector2(36.0, -117.0)
	if crouching:
		hip.y += 34.0
		chest.y += 50.0
		head.y += 52.0
		rear_hand.y += 47.0
		front_hand.y += 47.0
	elif position.y < FLOOR_Y - 1.0:
		rear_foot = Vector2(-27.0, -36.0)
		front_foot = Vector2(31.0, -23.0)
	elif absf(velocity.x) > 15.0 and action.is_empty() and stun <= 0.0:
		rear_foot.x += sin(animation_time * 14.0) * 17.0
		front_foot.x -= sin(animation_time * 14.0) * 17.0
	var pose: Array[Vector2] = [hip, chest, head, rear_foot, front_foot, rear_hand, front_hand]
	_pose_attack(pose)
	if health <= 0:
		draw_set_transform(Vector2(0.0, -24.0), -facing * 1.35, Vector2(facing, 1.0))
	else:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1.0))
	if hit_flash > 0.0:
		armor = Color("e9f8ff")
	_draw_body(pose, armor, dark, accent)
	if guard_flash > 0.0 or (_direction.x * facing < -0.2 and action.is_empty()):
		var guard_center: Vector2 = Vector2(28.0, -73.0 if crouching else -104.0)
		draw_arc(guard_center, 40.0, -1.3, 1.3, 16, Color(accent, 0.85), 3.0)
	draw_set_transform(Vector2.ZERO)


func _pose_attack(pose: Array[Vector2]) -> void:
	if stun > 0.0 and guard_flash <= 0.0:
		pose[1].x -= 14.0
		pose[2].x -= 22.0
		return
	if action.is_empty():
		return
	var startup: float = float(move_data.startup)
	var progress: float = clampf(attack_time / startup, 0.0, 1.0)
	if attack_time > startup + float(move_data.active):
		progress = 1.0 - clampf(
			(attack_time - startup - float(move_data.active)) / _recovery, 0.0, 1.0)
	var reach: float = float(move_data.reach)
	var height: float = float(move_data.height)
	if action in ["lp", "hp"]:
		pose[6] = pose[6].lerp(Vector2(reach, height), progress)
		pose[1].x += progress * (15.0 if action == "hp" else 5.0)
	elif action in ["lk", "hk"]:
		pose[4] = pose[4].lerp(Vector2(reach, height), progress)
		pose[1].x -= progress * 13.0
		pose[2].x -= progress * 11.0
	else:
		pose[5] = pose[5].lerp(Vector2(62.0, -94.0), progress)
		pose[6] = pose[6].lerp(Vector2(77.0, -89.0), progress)


func _draw_body(pose: Array[Vector2], armor: Color, dark: Color, accent: Color) -> void:
	var hip: Vector2 = pose[0]
	var chest: Vector2 = pose[1]
	var head: Vector2 = pose[2]
	_limb(hip, (hip + pose[3]) * 0.5 + Vector2(-14.0, 3.0), pose[3], armor.darkened(0.3), 18.0)
	_limb(chest, (chest + pose[5]) * 0.5 + Vector2(-19.0, 2.0), pose[5], dark, 15.0)
	var body: PackedVector2Array = PackedVector2Array([
		chest + Vector2(-23.0, -8.0), chest + Vector2(24.0, -8.0),
		hip + Vector2(17.0, 4.0), hip + Vector2(-17.0, 4.0)])
	draw_colored_polygon(body, armor)
	draw_polyline(body, armor.lightened(0.22), 2.0, true)
	draw_line(chest + Vector2(-12.0, 2.0), chest + Vector2(12.0, 2.0), accent, 4.0)
	draw_circle(hip, 14.0, dark)
	_limb(hip, (hip + pose[4]) * 0.5 + Vector2(13.0, -3.0), pose[4], armor, 20.0)
	_limb(chest + Vector2(11.0, 1.0),
		(chest + pose[6]) * 0.5 + Vector2(13.0, 14.0), pose[6], armor.lightened(0.08), 16.0)
	draw_circle(pose[6], 11.0, accent)
	draw_circle(pose[6] + Vector2(-2.0, -2.0), 7.0, armor)
	draw_circle(head, 19.0, dark)
	var helmet: PackedVector2Array = PackedVector2Array([
		head + Vector2(-17.0, -11.0), head + Vector2(6.0, -19.0),
		head + Vector2(21.0, -6.0), head + Vector2(17.0, 12.0),
		head + Vector2(-11.0, 16.0)])
	draw_colored_polygon(helmet, armor)
	draw_line(head + Vector2(-3.0, -3.0), head + Vector2(20.0, -3.0), accent, 6.0)
	draw_line(head + Vector2(0.0, -4.0), head + Vector2(19.0, -4.0), Color("e7fff9"), 2.0)


func _limb(start: Vector2, joint: Vector2, end: Vector2, tint: Color, width: float) -> void:
	draw_line(start, joint, Color("102430"), width + 5.0, true)
	draw_line(joint, end, Color("102430"), width + 5.0, true)
	draw_line(start, joint, tint, width, true)
	draw_line(joint, end, tint, width, true)
	draw_circle(joint, width * 0.43, tint.lightened(0.2))
	draw_line(joint + Vector2(-2.0, -3.0), end + Vector2(-2.0, -3.0), tint.lightened(0.24), 3.0)
