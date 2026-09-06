extends Node3D
## 状態は SurvivalState、表示ノードは views に分離する夜の敵管理。

signal player_hit(amount: float)
signal enemy_hit

const Data := preload("res://scripts/voxel_data.gd")
const Creature := preload("res://scripts/actors/creature.gd")
const MAX_ENEMIES: int = 6

var views: Dictionary[int, Node3D] = {}
var _projectile_views: Dictionary[int, MeshInstance3D] = {}
var _state: Node
var _effects: Node3D
var _spawn_clock: float = 0.0
var _attack_clock: float = 0.0
var _sequence: int = 0
var _spawn_sequence: int = 0
var _was_night: bool = false


func configure(state: Node, effects: Node3D) -> void:
	_state = state
	_effects = effects


func reset() -> void:
	for view: Node3D in views.values():
		view.queue_free()
	for view: MeshInstance3D in _projectile_views.values():
		view.queue_free()
	views.clear()
	_projectile_views.clear()
	if _state != null:
		_state.enemies.clear()
		_state.projectiles.clear()
	_spawn_clock = 0.0
	_attack_clock = 0.0
	_sequence = 0
	_spawn_sequence = 0
	_was_night = false


static func can_spawn(data: RefCounted, point: Vector3) -> bool:
	var cell: Vector3i = Vector3i(point.floor())
	if not data.in_bounds(cell) or not data.is_solid(cell + Vector3i.DOWN):
		return false
	if not _body_clear(data, point):
		return false
	for offset_x: int in range(-5, 6):
		for offset_z: int in range(-5, 6):
			for offset_y: int in range(-5, 6):
				var check: Vector3i = cell + Vector3i(offset_x, offset_y, offset_z)
				if data.get_block(check) == Data.TORCH \
					and point.distance_to(Vector3(check) + Vector3.ONE * 0.5) <= 5.0:
					return false
	return true


static func line_clear(data: RefCounted, start: Vector3, end: Vector3) -> bool:
	var distance: float = start.distance_to(end)
	var steps: int = maxi(1, ceili(distance / 0.08))
	for index: int in range(steps + 1):
		var point: Vector3 = start.lerp(end, float(index) / float(steps))
		if data.is_solid(Vector3i(point.floor())):
			return false
	return true


static func _body_clear(data: RefCounted, point: Vector3) -> bool:
	for offset_x: float in [-0.34, 0.34]:
		for offset_z: float in [-0.34, 0.34]:
			for offset_y: float in [0.05, 0.85, 1.55]:
				if data.is_solid(Vector3i((point + Vector3(offset_x, offset_y, offset_z)).floor())):
					return false
	return true


# 敵・弾の時間と位置を進めるゲームループのため非冪等。
func step(delta: float, player: Node3D) -> void:
	if _state == null or _state.phase != "play" or delta <= 0.0 or not is_finite(delta):
		return
	_attack_clock = maxf(0.0, _attack_clock - delta)
	var night: bool = _state.is_night()
	if night and not _was_night:
		_spawn_clock = 0.0
		_spawn("mossling", player.position)
		_spawn("wisp", player.position)
	if not night and _was_night:
		for enemy: Dictionary in _state.enemies:
			_begin_vanish(enemy)
		_clear_projectiles()
	_was_night = night
	if night:
		_spawn_clock -= delta
		if _spawn_clock <= 0.0:
			_spawn_clock = 11.0
			_spawn("mossling" if _spawn_sequence % 2 == 0 else "wisp", player.position)
	for enemy: Dictionary in _state.enemies.duplicate():
		if not views.has(int(enemy.id)):
			_create_view(enemy)
		if bool(enemy.dying):
			enemy.fade = float(enemy.fade) - delta
			if float(enemy.fade) <= 0.0:
				_remove_enemy(enemy)
			continue
		_step_enemy(enemy, delta, player)
	_step_projectiles(delta, player)


# 攻撃イベントで体力と所持品を更新するため非冪等。
func attack(origin: Vector3, direction: Vector3) -> bool:
	if _state == null or _state.phase != "play" or _attack_clock > 0.0:
		return false
	var chosen: Dictionary = {}
	var closest: float = 4.01
	for enemy: Dictionary in _state.enemies:
		if bool(enemy.dying):
			continue
		var bounds: AABB = AABB(enemy.position - Vector3(0.45, 0, 0.45), Vector3(0.9, 1.8, 0.9))
		var hit: Variant = bounds.intersects_segment(origin, origin + direction.normalized() * 4.0)
		if hit == null:
			continue
		var distance: float = origin.distance_to(hit)
		if distance < closest and line_clear(_state.data, origin, hit):
			closest = distance
			chosen = enemy
	if chosen.is_empty():
		return false
	_attack_clock = 0.4
	chosen.hp = float(chosen.hp) - (12.0 + float(_state.tool_level) * 7.0)
	if views.has(int(chosen.id)):
		views[int(chosen.id)].animate("hurt")
	_effects.burst(chosen.position + Vector3.UP, Color("cfed9a"))
	enemy_hit.emit()
	if float(chosen.hp) <= 0.0:
		var loot: String = "meat" if chosen.kind == "mossling" else "ore"
		_state.add_item(loot, 1)
		_effects.floating_text(chosen.position + Vector3.UP, _state.item_name(loot) + " +1",
			Color("ffe3a0"))
		_begin_vanish(chosen)
	return true


func _spawn(kind: String, player_point: Vector3) -> void:
	if _state.enemies.size() >= MAX_ENEMIES:
		return
	var point: Vector3 = Vector3.INF
	for attempt: int in range(32):
		var angle: float = float(_spawn_sequence * 11 + attempt) * 2.399963
		var radius: float = 7.0 + float(attempt % 4)
		var x: int = floori(player_point.x + cos(angle) * radius)
		var z: int = floori(player_point.z + sin(angle) * radius)
		var candidate: Vector3 = Vector3(x + 0.5, _state.data.surface_y(x, z) + 1.0, z + 0.5)
		if candidate.y >= 4.0 and can_spawn(_state.data, candidate):
			point = candidate
			break
	if not point.is_finite():
		return
	_sequence += 1
	_spawn_sequence += 1
	var enemy: Dictionary = {
		"id": _sequence, "kind": kind, "position": point,
		"hp": 36.0 if kind == "mossling" else 28.0,
		"cooldown": 1.0, "dying": false, "fade": 0.0
	}
	_state.enemies.append(enemy)
	_create_view(enemy)


func _create_view(enemy: Dictionary) -> void:
	var view: Node3D = Creature.new()
	add_child(view)
	view.configure(str(enemy.kind))
	view.position = enemy.position
	views[int(enemy.id)] = view


func _step_enemy(enemy: Dictionary, delta: float, player: Node3D) -> void:
	var view: Node3D = views[int(enemy.id)]
	var point: Vector3 = enemy.position
	var difference: Vector3 = player.position - point
	difference.y = 0.0
	var distance: float = difference.length()
	var ranged: bool = enemy.kind == "wisp"
	var direction: Vector3 = difference.normalized()
	var moving: bool = distance > (5.5 if ranged else 1.35)
	if ranged and distance < 4.0:
		direction = -direction
		moving = true
	if moving:
		var next: Vector3 = _walk(point, direction * delta * (1.25 if ranged else 1.65))
		enemy.position = next
		view.position = next
		view.animate("walk" if point.distance_to(next) > 0.001 else "idle")
	else:
		view.animate("idle")
	if difference.length_squared() > 0.001:
		view.rotation.y = atan2(-difference.x, -difference.z)
	enemy.cooldown = maxf(0.0, float(enemy.cooldown) - delta)
	if float(enemy.cooldown) > 0.0:
		return
	var origin: Vector3 = enemy.position + Vector3(0.0, 1.0, 0.0)
	var target: Vector3 = player.position + Vector3(0.0, 0.95, 0.0)
	if not line_clear(_state.data, origin, target):
		return
	if ranged and distance < 12.0:
		enemy.cooldown = 2.5
		view.animate("attack")
		_shoot(origin, target)
	elif not ranged and distance < 1.55 and absf(origin.y - target.y) < 1.8:
		enemy.cooldown = 1.2
		view.animate("attack")
		player_hit.emit(9.0)


func _walk(point: Vector3, movement: Vector3) -> Vector3:
	for angle: float in [0.0, 0.65, -0.65, 1.3, -1.3]:
		var next: Vector3 = point + movement.rotated(Vector3.UP, angle)
		if next.x < 0.5 or next.x > 31.5 or next.z < 0.5 or next.z > 31.5:
			continue
		for height: int in range(floori(point.y) + 1, floori(point.y) - 3, -1):
			next.y = float(height)
			var cell: Vector3i = Vector3i(next.floor())
			if _state.data.is_solid(cell + Vector3i.DOWN) and _body_clear(_state.data, next):
				return next
	return point


func _shoot(origin: Vector3, target: Vector3) -> void:
	if _state.projectiles.size() >= 12:
		return
	_sequence += 1
	_state.projectiles.append({"id": _sequence, "position": origin,
		"velocity": origin.direction_to(target) * 6.0, "ttl": 3.0})
	var view: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.26
	view.mesh = sphere
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("92f8ec")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	view.material_override = material
	view.position = origin
	add_child(view)
	_projectile_views[_sequence] = view


func _step_projectiles(delta: float, player: Node3D) -> void:
	var player_bounds: AABB = AABB(player.position - Vector3(0.4, 0.0, 0.4), Vector3(0.8, 1.8, 0.8))
	for projectile: Dictionary in _state.projectiles.duplicate():
		var previous: Vector3 = projectile.position
		var next: Vector3 = previous + projectile.velocity * delta
		projectile.ttl = float(projectile.ttl) - delta
		var blocked: bool = not line_clear(_state.data, previous, next)
		var hit: bool = not blocked and player_bounds.intersects_segment(previous, next) != null
		if blocked or hit or float(projectile.ttl) <= 0.0:
			if hit:
				player_hit.emit(7.0)
			_effects.burst(previous, Color("92f8ec"))
			_remove_projectile(projectile)
			continue
		projectile.position = next
		if _projectile_views.has(int(projectile.id)):
			_projectile_views[int(projectile.id)].position = next


func _begin_vanish(enemy: Dictionary) -> void:
	if bool(enemy.dying):
		return
	enemy.dying = true
	enemy.fade = 0.75
	if views.has(int(enemy.id)):
		views[int(enemy.id)].animate("vanish")


func _remove_enemy(enemy: Dictionary) -> void:
	var id: int = int(enemy.id)
	if views.has(id):
		views[id].queue_free()
		views.erase(id)
	_state.enemies.erase(enemy)


func _remove_projectile(projectile: Dictionary) -> void:
	var id: int = int(projectile.id)
	if _projectile_views.has(id):
		_projectile_views[id].queue_free()
		_projectile_views.erase(id)
	_state.projectiles.erase(projectile)


func _clear_projectiles() -> void:
	for projectile: Dictionary in _state.projectiles.duplicate():
		_remove_projectile(projectile)
