extends Node
## 遠征の状態を一元管理する。描画・入力機器に依存せず固定時間刻みで検証できる。

const DAY_SECONDS: float = 300.0
const LEADER_SPEED: float = 7.0
const THROW_RANGE: float = 10.0
const WHISTLE_RANGE: float = 11.0
const OBSTACLE_RADIUS: float = 1.7
const FLIGHT_SECONDS: float = 0.55

var phase: String = "title"
var tutorial_page: int = -1
var tutorial_seen: bool = false
var leader: Vector3 = Vector3.ZERO
var crew: Array[Dictionary] = []
var cargo: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var collected: int = 0
var remaining: float = DAY_SECONDS
var goal: int = 5
var selected_kind: int = 0
var events: Array[String] = []
var obstacles: Array[Vector3] = []
var base_position: Vector3 = Vector3(0, 0, 15)
var _next_id: int = 0


func start_day() -> void:
	phase = "playing"
	tutorial_page = -1 if tutorial_seen else 0
	leader = Vector3(0, 0, 11)
	remaining = DAY_SECONDS
	collected = 0
	selected_kind = 0
	_next_id = 0
	crew.clear()
	cargo.clear()
	enemies.clear()
	events.clear()
	obstacles.assign([Vector3(-5, 0, 0), Vector3(5, 0, -3), Vector3(0, 0, -9)])
	for index: int in range(30):
		_add_crew(index % 2, leader + _formation_offset(index))
	cargo.assign([
		_cargo(Vector3(-9, 0, 7), 2), _cargo(Vector3(9, 0, 5), 4),
		_cargo(Vector3(-13, 0, -6), 6), _cargo(Vector3(10, 0, -9), 4),
		_cargo(Vector3(0, 0, -17), 6),
	])
	enemies.assign([
		{"position": Vector3(-11, 0, -8), "hp": 22.0, "cooldown": 1.4},
		{"position": Vector3(11, 0, -12), "hp": 26.0, "cooldown": 1.4},
	])


func show_title() -> void:
	phase = "title"
	tutorial_page = -1
	events.clear()


func show_map() -> void:
	phase = "map"
	tutorial_page = -1
	events.clear()


func advance_tutorial() -> void:
	if phase != "playing" or tutorial_page < 0:
		return
	if tutorial_page < 2:
		tutorial_page += 1
	else:
		skip_tutorial()


func skip_tutorial() -> void:
	if phase != "playing":
		return
	tutorial_page = -1
	tutorial_seen = true


## 時間と操作を積算するため非冪等。大きな delta は分割して衝突・死亡順を安定させる。
func step(delta: float, movement: Vector3) -> void:
	if phase != "playing" or delta <= 0.0:
		return
	var left: float = delta
	while left > 0.00001 and phase == "playing":
		var tick: float = minf(left, 1.0 / 30.0)
		_tick(tick, movement)
		left -= tick


## 笛を吹くたびに効果音イベントを積むため非冪等。呼び寄せた後の隊員状態は同一になる。
func whistle() -> void:
	if phase != "playing":
		return
	for member: Dictionary in crew:
		if _flat(member.position).distance_to(leader) <= WHISTLE_RANGE:
			member.state = "follow"
			member.target = -1
			member.flight = 0.0
			member.position = _flat(member.position)
	events.append("whistle")


func dismiss() -> void:
	if phase != "playing":
		return
	for member: Dictionary in crew:
		if member.state == "follow":
			member.state = "idle"
			member.target = -1


## 1 回の操作につき選択種を 1 体消費して投げるため非冪等。
func throw_at(point: Vector3) -> void:
	if phase != "playing":
		return
	for member: Dictionary in crew:
		if member.state != "follow" or member.kind != selected_kind:
			continue
		var offset: Vector3 = (_flat(point) - leader).limit_length(THROW_RANGE)
		member.state = "thrown"
		member.origin = leader + Vector3.UP
		member.aim = _safe_position(leader + offset)
		member.position = member.origin
		member.flight = FLIGHT_SECONDS
		member.target = -1
		events.append("throw")
		return


func following_count() -> int:
	var count: int = 0
	for member: Dictionary in crew:
		if member.state == "follow":
			count += 1
	return count


## tick ごとに状態を積算する内部関数のため非冪等。
func _tick(delta: float, movement: Vector3) -> void:
	remaining = maxf(0.0, remaining - delta)
	leader = _safe_position(leader + _flat(movement).limit_length(1.0) * LEADER_SPEED * delta)
	_update_crew(delta)
	_update_enemies(delta)
	_update_cargo(delta)
	if collected >= goal:
		phase = "clear"
	elif crew.is_empty() or remaining <= 0.0001:
		phase = "failed"


## 隊員の移動・投擲時間・与ダメージを積算するため非冪等。
func _update_crew(delta: float) -> void:
	var formation_index: int = 0
	for member: Dictionary in crew:
		match member.state:
			"follow":
				var target: Vector3 = leader + _formation_offset(formation_index)
				member.position = _move_ground(member.position, target, 8.5 * delta)
				formation_index += 1
			"thrown":
				member.flight = maxf(0.0, float(member.flight) - delta)
				var progress: float = 1.0 - float(member.flight) / FLIGHT_SECONDS
				member.position = member.origin.lerp(member.aim, progress)
				member.position.y += sin(progress * PI) * 3.5
				if member.flight <= 0.0:
					member.position = member.aim
					_attach(member)
			"attack":
				var target_index: int = member.target
				if target_index < 0 or target_index >= enemies.size():
					member.state = "idle"
					continue
				var enemy: Dictionary = enemies[target_index]
				if enemy.hp <= 0.0:
					member.state = "idle"
					continue
				member.position = _move_ground(member.position, enemy.position, 8.0 * delta)
				if member.position.distance_to(enemy.position) < 2.5:
					enemy.hp = maxf(0.0, float(enemy.hp) - (4.5 if member.kind == 0 else 2.0) * delta)
					if enemy.hp <= 0.0:
						_defeat_enemy(target_index)


func _attach(member: Dictionary) -> void:
	member.state = "idle"
	member.target = -1
	var best_distance: float = 2.8
	for index: int in range(enemies.size()):
		var distance: float = member.position.distance_to(enemies[index].position)
		if enemies[index].hp > 0.0 and distance < best_distance:
			member.state = "attack"
			member.target = index
			best_distance = distance
	if member.state == "attack":
		return
	for index: int in range(cargo.size()):
		var distance: float = member.position.distance_to(cargo[index].position)
		if not cargo[index].delivered and distance < best_distance:
			member.state = "carry"
			member.target = index
			best_distance = distance


## 生存敵のみが攻撃間隔を積算し、範囲内の隊員を 1 体失わせるため非冪等。
func _update_enemies(delta: float) -> void:
	for enemy: Dictionary in enemies:
		if enemy.hp <= 0.0:
			continue
		enemy.cooldown = maxf(0.0, float(enemy.cooldown) - delta)
		if enemy.cooldown > 0.0:
			continue
		for index: int in range(crew.size() - 1, -1, -1):
			var member: Dictionary = crew[index]
			if member.state != "thrown" and member.position.distance_to(enemy.position) < 2.2:
				crew.remove_at(index)
				enemy.cooldown = 1.4
				events.append("lost")
				break


## 撃破直後に 1 回だけ呼び、敵を運搬物へ変換するため非冪等。
func _defeat_enemy(enemy_index: int) -> void:
	var cargo_index: int = cargo.size()
	cargo.append(_cargo(enemies[enemy_index].position, 4))
	for member: Dictionary in crew:
		if member.state == "attack" and member.target == enemy_index:
			member.state = "carry"
			member.target = cargo_index
	events.append("defeat")


## 運搬距離と回収を積算するため非冪等。delivered が二重回収を防ぐ。
func _update_cargo(delta: float) -> void:
	for index: int in range(cargo.size()):
		var item: Dictionary = cargo[index]
		if item.delivered:
			continue
		var carriers: Array[Dictionary] = []
		var blue_count: int = 0
		for member: Dictionary in crew:
			if member.state == "carry" and member.target == index:
				carriers.append(member)
				if member.kind == 1:
					blue_count += 1
		if carriers.size() >= int(item.weight):
			var speed: float = 2.4 + 2.2 * float(blue_count) / float(carriers.size())
			item.position = _move_ground(item.position, base_position, speed * delta)
		for carrier_index: int in range(carriers.size()):
			var member: Dictionary = carriers[carrier_index]
			var angle: float = TAU * float(carrier_index) / maxf(1.0, float(carriers.size()))
			member.position = _safe_position(item.position + Vector3(cos(angle), 0, sin(angle)))
		if carriers.size() >= int(item.weight) and item.position.distance_to(base_position) < 1.8:
			_deliver(index, carriers)


## 回収物ごとに 1 回だけスコアと隊員を増やすため非冪等。
func _deliver(index: int, carriers: Array[Dictionary]) -> void:
	cargo[index].delivered = true
	collected += 1
	for member: Dictionary in carriers:
		member.state = "idle"
		member.target = -1
	for bonus_index: int in range(3):
		_add_crew(bonus_index % 2, base_position + Vector3(bonus_index - 1, 0, 1))
		crew.back().state = "idle"
	events.append("delivery")


## 初期配置・回収報酬に応じて新しい識別子の隊員を追加するため非冪等。
func _add_crew(kind: int, position: Vector3) -> void:
	crew.append({
		"id": _next_id, "position": _safe_position(position), "kind": kind,
		"state": "follow", "target": -1, "flight": 0.0,
		"origin": position, "aim": position,
	})
	_next_id += 1


func _cargo(position: Vector3, weight: int) -> Dictionary:
	return {"position": position, "weight": weight, "delivered": false}


func _formation_offset(index: int) -> Vector3:
	var angle: float = float(index) * 2.4
	var radius: float = 0.65 + sqrt(float(index)) * 0.42
	return Vector3(cos(angle), 0, sin(angle)) * radius


func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0, point.z)


func _safe_position(point: Vector3) -> Vector3:
	var result: Vector3 = Vector3(clampf(point.x, -23, 23), 0, clampf(point.z, -23, 23))
	for obstacle: Vector3 in obstacles:
		var offset: Vector3 = result - obstacle
		if offset.length() < OBSTACLE_RADIUS:
			if offset.length_squared() < 0.0001:
				offset = Vector3.RIGHT
			result = obstacle + offset.normalized() * OBSTACLE_RADIUS
	return result


func _move_ground(position: Vector3, target: Vector3, distance: float) -> Vector3:
	var destination: Vector3 = _safe_position(target)
	var direction: Vector3 = destination - position
	if direction.length() <= distance:
		return destination
	# 経路を横切る円柱の外周へ中間点を置く。常に同じ側を選び、正面での往復を防ぐ。
	for obstacle: Vector3 in obstacles:
		var offset: Vector3 = obstacle - position
		var along: float = offset.dot(direction.normalized())
		if along <= 0.0 or along >= direction.length():
			continue
		var nearest: Vector3 = position + direction.normalized() * along
		if nearest.distance_to(obstacle) >= OBSTACLE_RADIUS + 0.35:
			continue
		if offset.length() > 4.5:
			continue
		var radial: Vector3 = (position - obstacle).normalized()
		var tangent: Vector3 = Vector3(-radial.z, 0, radial.x)
		if tangent.dot(direction) < -0.01:
			tangent = -tangent
		var outward: float = maxf(0.0, 2.25 - offset.length())
		direction = tangent + radial * outward * 2.0
		break
	return _safe_position(position + direction.normalized() * distance)
