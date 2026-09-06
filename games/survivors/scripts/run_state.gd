extends Node
## すべての進行状態の所有者。step は実時間の進行を受け取るため非冪等。

signal sound_requested(cue: String)
signal phase_changed
signal effect_requested(at: Vector2, kind: String, caption: String)

const Rules = preload("res://scripts/game_rules.gd")

var phase: String = "title"
var elapsed: float = 0.0
var player_pos: Vector2 = Vector2.ZERO
var hp: float = 100.0
var max_hp: float = 100.0
var level: int = 1
var xp: int = 0
var kills: int = 0
var won: bool = false
var weapons: Dictionary = {"bolt": 1, "orbit": 0, "pulse": 0}
var enemies: Array[Dictionary] = []
var gems: Array[Dictionary] = []
var items: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var choices: Array[String] = []
var invulnerable: float = 0.0
var damage_bonus: float = 1.0
var attack_speed: float = 1.0
var move_speed: float = 230.0
var pickup_radius: float = 62.0
var orbit_angle: float = 0.0
var boss_spawned: bool = false
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _spawn_cooldown: float = 0.0
var _bolt_cooldown: float = 0.0
var _orbit_cooldown: float = 0.0
var _pulse_cooldown: float = 0.0
var _supply_cooldown: float = 18.0
var _next_enemy_id: int = 0


func start_run(seed_value: int = 0) -> void:
	if seed_value == 0:
		_random.randomize()
	else:
		_random.seed = seed_value
	elapsed = 0.0
	player_pos = Vector2.ZERO
	hp = 100.0
	max_hp = 100.0
	level = 1
	xp = 0
	kills = 0
	won = false
	weapons = {"bolt": 1, "orbit": 0, "pulse": 0}
	enemies.clear()
	gems.clear()
	items.clear()
	projectiles.clear()
	effects.clear()
	choices.clear()
	invulnerable = 0.0
	damage_bonus = 1.0
	attack_speed = 1.0
	move_speed = 230.0
	pickup_radius = 62.0
	orbit_angle = 0.0
	boss_spawned = false
	_spawn_cooldown = 0.0
	_bolt_cooldown = 0.0
	_orbit_cooldown = 0.0
	_pulse_cooldown = 0.0
	_supply_cooldown = 18.0
	_set_phase("playing")


func return_title() -> void:
	_set_phase("title")


func toggle_pause() -> void:
	if phase == "playing":
		_set_phase("paused")
	elif phase == "paused":
		_set_phase("playing")


func finish_run(clear: bool) -> void:
	if phase == "result":
		return
	won = clear
	_set_phase("result")


# 経過時間と入力を積分するため、同一入力の再呼び出しでも状態を進める。
func step(delta: float, movement: Vector2) -> void:
	if phase != "playing" or delta <= 0.0:
		return
	var dt: float = minf(delta, 0.05)
	elapsed = minf(elapsed + dt, Rules.DURATION)
	if elapsed >= Rules.DURATION:
		finish_run(true)
		return
	player_pos += movement.limit_length() * move_speed * dt
	player_pos = player_pos.clamp(Vector2.ONE * -Rules.WORLD_LIMIT, Vector2.ONE * Rules.WORLD_LIMIT)
	invulnerable = maxf(0.0, invulnerable - dt)
	orbit_angle = fmod(orbit_angle + dt * 2.8, TAU)
	_advance_effects(dt)
	_spawn_wave(dt)
	_move_enemies(dt)
	if phase != "playing":
		return
	_attack(dt)
	_move_projectiles(dt)
	_collect_drops(dt)


# スポーンは一体を追加するイベントなので非冪等。
func spawn_enemy(kind: int, at: Vector2) -> void:
	var stats: Dictionary = Rules.enemy_stats(kind)
	_next_enemy_id += 1
	(
		enemies
		. append(
			{
				"id": _next_enemy_id,
				"pos": at,
				"hp": float(stats.hp),
				"kind": kind,
				"radius": float(stats.radius),
				"flash": 0.0,
			}
		)
	)


# 経験値の獲得は一回の拾得ごとに加算するため非冪等。
func gain_xp(amount: int) -> void:
	if phase not in ["playing", "upgrade"]:
		return
	xp += maxi(0, amount)
	if phase == "playing":
		_check_level_up()


# 被弾イベントは無敵時間外で HP を減らすため非冪等。
func take_damage(amount: float) -> void:
	if phase != "playing" or invulnerable > 0.0 or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	invulnerable = 0.8
	_add_effect(player_pos, "hit", "-%d" % int(amount))
	sound_requested.emit("hurt")
	if hp <= 0.0:
		finish_run(false)


func choose_upgrade(index: int) -> void:
	if phase != "upgrade" or index < 0 or index >= choices.size():
		return
	var id: String = choices[index]
	if weapons.has(id):
		weapons[id] = mini(int(weapons[id]) + 1, 3)
	else:
		match id:
			"power":
				damage_bonus += 0.15
			"tempo":
				attack_speed += 0.08
			"speed":
				move_speed = minf(350.0, move_speed + 12.0)
			"health":
				max_hp += 20.0
				hp = minf(max_hp, hp + 35.0)
			"reach":
				pickup_radius = minf(220.0, pickup_radius + 18.0)
	choices.clear()
	_set_phase("playing")
	_check_level_up()


func upgrade_name(id: String) -> String:
	return Rules.upgrade_name(id)


func upgrade_description(id: String) -> String:
	return Rules.upgrade_description(id)


func _set_phase(value: String) -> void:
	if phase == value:
		return
	phase = value
	phase_changed.emit()


func _check_level_up() -> void:
	if xp < Rules.xp_needed(level):
		return
	xp -= Rules.xp_needed(level)
	level += 1
	var available: Array[String] = ["power", "health", "tempo"]
	if move_speed < 350.0:
		available.append("speed")
	if pickup_radius < 220.0:
		available.append("reach")
	for weapon: String in weapons:
		if int(weapons[weapon]) < 3:
			available.append(weapon)
	choices.clear()
	while choices.size() < 3:
		var index: int = _random.randi_range(0, available.size() - 1)
		choices.append(available[index])
		available.remove_at(index)
	_add_effect(player_pos, "level", "レベルアップ")
	sound_requested.emit("level")
	_set_phase("upgrade")


func _spawn_wave(dt: float) -> void:
	_spawn_cooldown -= dt
	if _spawn_cooldown <= 0.0:
		var stage: Dictionary = Rules.spawn_stage(elapsed)
		_spawn_cooldown = float(stage.interval)
		for _index: int in range(int(stage.count)):
			if enemies.size() >= Rules.MAX_ENEMIES:
				break
			var kinds: Array = stage.kinds
			spawn_enemy(int(kinds[_random.randi_range(0, kinds.size() - 1)]), _spawn_position())
	if elapsed >= 570.0 and not boss_spawned:
		boss_spawned = true
		spawn_enemy(3, _spawn_position())
		_add_effect(player_pos, "boss", "夜の主が目覚めた")
		sound_requested.emit("boss")
	_supply_cooldown -= dt
	if _supply_cooldown <= 0.0:
		_supply_cooldown = 25.0
		for kind: String in ["heal", "magnet"]:
			var at: Vector2 = player_pos + Vector2.from_angle(_random.randf() * TAU) * 120.0
			items.append(
				{
					"pos":
					at.clamp(Vector2.ONE * -Rules.WORLD_LIMIT, Vector2.ONE * Rules.WORLD_LIMIT),
					"kind": kind
				}
			)


func _spawn_position() -> Vector2:
	var at: Vector2 = player_pos + Vector2.from_angle(_random.randf() * TAU) * 760.0
	at = at.clamp(Vector2.ONE * -Rules.WORLD_LIMIT, Vector2.ONE * Rules.WORLD_LIMIT)
	if at.distance_squared_to(player_pos) < 550.0 * 550.0:
		at = player_pos.move_toward(Vector2.ZERO, 760.0)
	return at


func _move_enemies(dt: float) -> void:
	for enemy: Dictionary in enemies:
		var stats: Dictionary = Rules.enemy_stats(int(enemy.kind))
		var offset: Vector2 = player_pos - Vector2(enemy.pos)
		enemy.pos += offset.normalized() * float(stats.speed) * dt
		enemy.flash = maxf(0.0, float(enemy.flash) - dt)
		if offset.length_squared() < pow(float(enemy.radius) + 16.0, 2):
			take_damage(float(stats.damage))


func _attack(dt: float) -> void:
	_bolt_cooldown -= dt
	_orbit_cooldown -= dt
	_pulse_cooldown -= dt
	if _bolt_cooldown <= 0.0 and not enemies.is_empty():
		_bolt_cooldown = (0.6 - float(weapons.bolt) * 0.07) / attack_speed
		_fire_bolts()
	if int(weapons.orbit) > 0 and _orbit_cooldown <= 0.0:
		_orbit_cooldown = 0.18 / attack_speed
		_orbit_attack()
	if int(weapons.pulse) > 0 and _pulse_cooldown <= 0.0:
		_pulse_cooldown = (2.7 - float(weapons.pulse) * 0.25) / attack_speed
		for index: int in range(enemies.size() - 1, -1, -1):
			if Vector2(enemies[index].pos).distance_to(player_pos) < pulse_radius():
				_hit_enemy(index, (20.0 + 16.0 * float(weapons.pulse)) * damage_bonus)
		_add_effect(player_pos, "pulse", "")
		sound_requested.emit("attack")


func pulse_radius() -> float:
	return 120.0 + float(weapons.pulse) * 38.0


func orbit_position(index: int) -> Vector2:
	var count: int = int(weapons.orbit) + 1
	return player_pos + Vector2.from_angle(orbit_angle + TAU * index / count) * 88.0


func _fire_bolts() -> void:
	var target: Vector2 = Vector2(enemies[0].pos)
	var distance: float = INF
	for enemy: Dictionary in enemies:
		var squared: float = player_pos.distance_squared_to(Vector2(enemy.pos))
		if squared < distance:
			distance = squared
			target = Vector2(enemy.pos)
	if distance > 780.0 * 780.0:
		return
	var direction: Vector2 = (target - player_pos).normalized()
	for index: int in range(int(weapons.bolt)):
		var angle: float = (float(index) - float(int(weapons.bolt) - 1) / 2.0) * 0.14
		projectiles.append(
			{
				"pos": player_pos,
				"velocity": direction.rotated(angle) * 660.0,
				"life": 1.3,
				"damage": (24.0 + float(weapons.bolt) * 9.0) * damage_bonus
			}
		)
	sound_requested.emit("attack")


func _orbit_attack() -> void:
	for index: int in range(enemies.size() - 1, -1, -1):
		for blade: int in range(int(weapons.orbit) + 1):
			if Vector2(enemies[index].pos).distance_to(orbit_position(blade)) < 32.0:
				_hit_enemy(index, (9.0 + float(weapons.orbit) * 6.0) * damage_bonus)
				break


func _move_projectiles(dt: float) -> void:
	for index: int in range(projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = projectiles[index]
		projectile.pos += Vector2(projectile.velocity) * dt
		projectile.life = float(projectile.life) - dt
		var consumed: bool = float(projectile.life) <= 0.0
		if not consumed:
			for enemy_index: int in range(enemies.size() - 1, -1, -1):
				var enemy: Dictionary = enemies[enemy_index]
				if (
					Vector2(projectile.pos).distance_squared_to(Vector2(enemy.pos))
					< pow(float(enemy.radius) + 9.0, 2)
				):
					_hit_enemy(enemy_index, float(projectile.damage))
					consumed = true
					break
		if consumed:
			projectiles.remove_at(index)


func _hit_enemy(index: int, amount: float) -> void:
	var enemy: Dictionary = enemies[index]
	enemy.hp = float(enemy.hp) - amount
	enemy.flash = 0.12
	_add_effect(Vector2(enemy.pos), "hit", str(int(amount)))
	if float(enemy.hp) > 0.0:
		return
	kills += 1
	gems.append({"pos": enemy.pos, "value": int(Rules.enemy_stats(int(enemy.kind)).xp)})
	_add_effect(Vector2(enemy.pos), "death", "")
	if kills % 24 == 0:
		items.append({"pos": enemy.pos, "kind": "heal"})
	elif kills % 17 == 0:
		items.append({"pos": enemy.pos, "kind": "magnet"})
	enemies.remove_at(index)
	# 長時間の逃走でもメモリが増え続けないよう、古いジェムの経験値を保持して統合する。
	if gems.size() > 600:
		gems[1].value = int(gems[1].value) + int(gems[0].value)
		gems.remove_at(0)


func _collect_drops(dt: float) -> void:
	for index: int in range(items.size() - 1, -1, -1):
		var item: Dictionary = items[index]
		if Vector2(item.pos).distance_squared_to(player_pos) > 34.0 * 34.0:
			continue
		if str(item.kind) == "heal":
			var healed: float = minf(30.0, max_hp - hp)
			hp = minf(max_hp, hp + 30.0)
			_add_effect(player_pos, "heal", "+%d HP" % int(healed))
		else:
			for gem: Dictionary in gems:
				if Vector2(gem.pos).distance_squared_to(player_pos) <= 900.0 * 900.0:
					gem["magnet"] = true
			_add_effect(player_pos, "magnet", "吸い寄せ")
		sound_requested.emit(str(item.kind))
		items.remove_at(index)
	for index: int in range(gems.size() - 1, -1, -1):
		var gem: Dictionary = gems[index]
		var distance: float = Vector2(gem.pos).distance_to(player_pos)
		if distance < pickup_radius or bool(gem.get("magnet", false)):
			gem.pos = Vector2(gem.pos).move_toward(player_pos, 560.0 * dt)
		if Vector2(gem.pos).distance_squared_to(player_pos) < 22.0 * 22.0:
			var value: int = int(gem.value)
			gems.remove_at(index)
			gain_xp(value)
			if phase != "playing":
				return


func _add_effect(at: Vector2, kind: String, text: String) -> void:
	if effects.size() >= 120:
		effects.remove_at(0)
	effects.append({"pos": at, "kind": kind, "text": text, "age": 0.0})
	effect_requested.emit(at, kind, text)


func _advance_effects(dt: float) -> void:
	for index: int in range(effects.size() - 1, -1, -1):
		effects[index].age = float(effects[index].age) + dt
		if float(effects[index].age) >= 0.7:
			effects.remove_at(index)
