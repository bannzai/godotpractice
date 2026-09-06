class_name FighterBody
extends Node2D
## 移動・技進行・命中は各物理 tick の時間と入力を消費するため非冪等。
## reset_fighter/configure は繰り返し呼んでも同じ初期状態になる。

signal struck(at: Vector2, blocked: bool)
signal special_cast

const RULES: Script = preload("res://scripts/combat_rules.gd")
const PROJECTILE: Script = preload("res://scripts/projectile.gd")
const VISUAL: Script = preload("res://scripts/fighter_visual.gd")
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
var visual: FighterVisual
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
	visual = VISUAL.new()
	visual.name = "CharacterAnimation"
	visual.configure(character_index)
	add_child(visual)
	visual.sync_state(self, 0.0, _recovery)


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
	if is_instance_valid(visual):
		visual.configure(character_index)
		visual.sync_state(self, 0.0, _recovery)
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
		if is_instance_valid(visual):
			visual.start_hurt(animation_time)
	hitstop = float(data.hitstop)
	struck.emit(global_position + Vector2(0.0, -90.0), guarding)
	return guarding


func _physics_process(delta: float) -> void:
	if not enabled:
		visual.sync_state(self, delta, _recovery)
		queue_redraw()
		return
	if hitstop > 0.0:
		visual.sync_state(self, 0.0, _recovery)
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
	visual.sync_state(self, delta, _recovery)
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


func is_visually_guarding() -> bool:
	return _guarding_stun or (
		_direction.x * facing < -0.2 and action.is_empty() and health > 0
		and stun <= 0.0 and position.y >= FLOOR_Y - 1.0)


func _draw() -> void:
	var accent: Color = Color("8cfce7") if character_index == 0 else Color("ffd28a")
	var altitude: float = maxf(0.0, FLOOR_Y - position.y)
	var shadow_scale: float = clampf(1.0 - altitude / 650.0, 0.55, 1.0)
	var shadow_alpha: float = clampf(0.45 - altitude / 800.0, 0.16, 0.45)
	draw_set_transform(Vector2(0.0, altitude - 2.0), 0.0,
		Vector2(shadow_scale, shadow_scale * 0.23))
	draw_circle(Vector2.ZERO, 44.0 if character_index == 0 else 53.0,
		Color(0.02, 0.04, 0.07, shadow_alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1.0))
	if guard_flash > 0.0 or is_visually_guarding():
		var center: Vector2 = Vector2(40.0, -73.0 if crouching else -111.0)
		draw_arc(center, 43.0, -1.2, 1.2, 24, Color(accent, 0.7), 2.0, true)
		if guard_flash > 0.0:
			draw_arc(center, 48.0, -0.9, 0.9, 24, Color(accent, guard_flash * 3.0), 4.0, true)
	draw_set_transform(Vector2.ZERO)
