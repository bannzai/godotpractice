extends Node
## 戦闘の進行と資金の所有者。攻撃・時間進行・購入は一操作ごとに状態を変えるため非冪等。

const Catalog = preload("res://scripts/catalog.gd")

var phase: String = "title"
var gold: int = Catalog.START_GOLD
var hp: int = Catalog.MAX_HP
var wave: int = 0
var active: bool = false
var speed: int = 1
var elapsed: float = 0.0
var towers: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var events: Array[Dictionary] = []
var best: Dictionary = {"stars": 0, "wave": 0}
var save_path: String = "user://grove_defense.json"
var _pending: Array[String] = []
var _spawn_time: float = 0.0
var _next_id: int = 0


func new_run() -> void:
	phase = "play"
	gold = Catalog.START_GOLD
	hp = Catalog.MAX_HP
	wave = 0
	active = false
	speed = 1
	elapsed = 0.0
	towers.clear()
	enemies.clear()
	events.clear()
	_pending.clear()
	_spawn_time = 0.0
	_next_id = 0


func to_title() -> void:
	new_run()
	phase = "title"


func tower_at(site: int) -> Dictionary:
	for tower: Dictionary in towers:
		if int(tower.site) == site:
			return tower
	return {}


func build(site: int, kind: String) -> bool:
	if phase != "play" or site < 0 or site >= Catalog.SITES.size():
		return false
	if not Catalog.TOWERS.has(kind) or not tower_at(site).is_empty():
		return false
	if gold < int(Catalog.TOWERS[kind].cost):
		return false
	gold -= int(Catalog.TOWERS[kind].cost)
	towers.append({"site": site, "kind": kind, "level": 1, "cooldown": 0.0})
	events.append({"type": "build", "kind": kind, "position": Catalog.SITES[site]})
	return true


func upgrade_price(site: int) -> int:
	var tower: Dictionary = tower_at(site)
	return 0 if tower.is_empty() else Catalog.upgrade_cost(tower.kind, tower.level)


func sell_price(site: int) -> int:
	var tower: Dictionary = tower_at(site)
	return 0 if tower.is_empty() else Catalog.sell_value(tower.kind, tower.level)


func upgrade(site: int) -> bool:
	var price: int = upgrade_price(site)
	if phase != "play" or price <= 0 or gold < price:
		return false
	var tower: Dictionary = tower_at(site)
	gold -= price
	tower.level += 1
	events.append({"type": "upgrade", "kind": tower.kind, "position": Catalog.SITES[site]})
	return true


func sell(site: int) -> bool:
	var tower: Dictionary = tower_at(site)
	if phase != "play" or tower.is_empty():
		return false
	gold += sell_price(site)
	events.append({"type": "sell", "kind": tower.kind, "position": Catalog.SITES[site]})
	towers.erase(tower)
	return true


func start_wave() -> bool:
	if phase != "play" or active or wave >= Catalog.WAVES.size():
		return false
	var definition: Dictionary = Catalog.WAVES[wave]
	_pending.clear()
	for group: Dictionary in definition.groups:
		for _index: int in range(int(group.count)):
			_pending.append(group.kind)
	wave += 1
	active = true
	_spawn_time = 0.0
	events.append({"type": "wave", "wave": wave, "position": Catalog.PATH[0]})
	return true


func spawn_remaining() -> int:
	return _pending.size()


func step(delta: float) -> void:
	if phase != "play" or not active or delta <= 0.0 or not is_finite(delta):
		return
	# 大きなフレーム落ちでも標的や減速の判定を飛び越えないよう小分けに積分する。
	var remaining: float = minf(delta, 0.25) * clampi(speed, 1, 3)
	while remaining > 0.00001 and phase == "play" and active:
		var dt: float = minf(remaining, 1.0 / 60.0)
		_tick(dt)
		remaining -= dt


func _tick(dt: float) -> void:
	elapsed += dt
	_spawn_time -= dt
	if _spawn_time <= 0.0 and not _pending.is_empty():
		_spawn(_pending.pop_front())
		_spawn_time += float(Catalog.WAVES[wave - 1].interval)
	_move_enemies(dt)
	if phase != "play":
		return
	_attack(dt)
	if _pending.is_empty() and enemies.is_empty():
		active = false
		gold += int(Catalog.WAVES[wave - 1].reward)
		events.append({"type": "wave_clear", "wave": wave, "position": Catalog.PATH[-1]})
		if wave == Catalog.WAVES.size():
			phase = "win"
			events.append({"type": "win", "position": Catalog.PATH[-1]})
			save_result()


func _spawn(kind: String) -> void:
	_next_id += 1
	var stats: Dictionary = Catalog.ENEMIES[kind]
	var health: float = float(stats.hp) * (1.0 + (wave - 1) * 0.12)
	enemies.append({"id": _next_id, "kind": kind, "hp": health, "max_hp": health,
		"distance": 0.0, "position": Catalog.PATH[0], "slow": 1.0, "slow_time": 0.0})
	events.append({"type": "spawn", "kind": kind, "position": Catalog.PATH[0],
		"target": _next_id})


func _move_enemies(dt: float) -> void:
	for index: int in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[index]
		enemy.slow_time = maxf(0.0, float(enemy.slow_time) - dt)
		if float(enemy.slow_time) <= 0.0:
			enemy.slow = 1.0
		enemy.distance += float(Catalog.ENEMIES[enemy.kind].speed) * float(enemy.slow) * dt
		enemy.position = Catalog.path_position(enemy.distance)
		if float(enemy.distance) >= Catalog.path_length():
			hp = maxi(0, hp - int(Catalog.ENEMIES[enemy.kind].leak))
			events.append({"type": "base", "kind": enemy.kind, "position": enemy.position})
			enemies.remove_at(index)
			if hp == 0:
				phase = "lose"
				active = false
				events.append({"type": "lose", "position": Catalog.PATH[-1]})
				save_result()
				return


func _attack(dt: float) -> void:
	for tower: Dictionary in towers:
		tower.cooldown = maxf(0.0, float(tower.cooldown) - dt)
		if float(tower.cooldown) > 0.0:
			continue
		var stats: Dictionary = Catalog.tower_stats(tower.kind, tower.level)
		var origin: Vector2 = Catalog.SITES[tower.site]
		var target: Dictionary = _target(origin, stats)
		if target.is_empty():
			continue
		tower.cooldown = stats.interval
		var impact: Vector2 = target.position
		events.append({"type": "shot", "kind": tower.kind, "from": origin,
			"to": impact, "target": target.id, "position": impact, "splash": stats.splash})
		for index: int in range(enemies.size() - 1, -1, -1):
			var enemy: Dictionary = enemies[index]
			if enemy.kind == "flyer" and not bool(stats.air):
				continue
			if int(enemy.id) != int(target.id) and (float(stats.splash) <= 0.0
				or impact.distance_to(enemy.position) > float(stats.splash)):
				continue
			_hit(index, tower.kind, stats)


func _target(origin: Vector2, stats: Dictionary) -> Dictionary:
	var chosen: Dictionary = {}
	for enemy: Dictionary in enemies:
		if enemy.kind == "flyer" and not bool(stats.air):
			continue
		if origin.distance_to(enemy.position) > float(stats.range):
			continue
		if chosen.is_empty() or float(enemy.distance) > float(chosen.distance):
			chosen = enemy
	return chosen


func _hit(index: int, kind: String, stats: Dictionary) -> void:
	var enemy: Dictionary = enemies[index]
	var armor: float = 0.0 if kind == "sun" else float(Catalog.ENEMIES[enemy.kind].armor)
	enemy.hp = maxf(0.0, float(enemy.hp) - maxf(1.0, float(stats.damage) - armor))
	if float(stats.slow) < 1.0:
		enemy.slow = minf(float(enemy.slow), float(stats.slow))
		enemy.slow_time = 1.6
	var dead: bool = float(enemy.hp) <= 0.0
	events.append({"type": "death" if dead else "hurt", "kind": enemy.kind,
		"position": enemy.position, "target": enemy.id,
		"reward": int(Catalog.ENEMIES[enemy.kind].reward) if dead else 0})
	if dead:
		gold += int(Catalog.ENEMIES[enemy.kind].reward)
		enemies.remove_at(index)


func stars() -> int:
	if phase != "win":
		return 0
	return 3 if hp >= 18 else (2 if hp >= 10 else 1)


static func parse_best(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"stars": 0, "wave": 0}
	var rating: Variant = value.get("stars", 0)
	var cleared: Variant = value.get("wave", 0)
	if not (rating is int or rating is float) or not (cleared is int or cleared is float):
		return {"stars": 0, "wave": 0}
	if not is_finite(float(rating)) or not is_finite(float(cleared)):
		return {"stars": 0, "wave": 0}
	return {"stars": clampi(int(rating), 0, 3), "wave": clampi(int(cleared), 0, 10)}


func load_best() -> void:
	best = {"stars": 0, "wave": 0}
	if not FileAccess.file_exists(save_path):
		return
	var parser: JSON = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(save_path)) == OK:
		best = parse_best(parser.data)


func save_result() -> void:
	if phase not in ["win", "lose"]:
		return
	load_best()
	best.stars = maxi(int(best.stars), stars())
	best.wave = maxi(int(best.wave), wave if phase == "win" else maxi(0, wave - 1))
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(best))
