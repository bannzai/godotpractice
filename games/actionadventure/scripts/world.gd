extends Node2D
## 部屋ごとの障害物・戦闘を所有する。報酬と解錠は永続状態の一回性を使う。

const Actor = preload("res://scripts/actor.gd")
const ROOM_NAMES: Array[String] = [
	"潮風の村", "旅商人の庭", "苔むす小径", "水晶の湿地", "夕映えの森", "灯の遺跡・門前",
	"遺跡 / 風の宝庫", "遺跡 / 遠い灯台", "遺跡 / 崩れた回廊", "遺跡 / 重さの間",
	"遺跡 / 星渡りの間", "遺跡 / 灯を喰らう梟"
]
const GOLD: Color = Color("f4ce82")
const MINT: Color = Color("70d7bb")
var host: Node
var state: Node
var hero: Node2D
var actors: Node2D
var tiles: TileMapLayer
var effects: Node2D
var props: Array[Dictionary] = []
var enemies: Array[Node2D] = []
var projectiles: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var textures: Dictionary = {}
var facing: Vector2 = Vector2.RIGHT
var attack_time: float = 0.0
var invulnerable: float = 0.0
var tool_time: float = 0.0
var elapsed: float = 0.0
var shake: float = 0.0
var hitstop: float = 0.0
var transition: float = 0.0
var old_image: Texture2D
var slide_dir: float = 1.0
var block_pos: Vector2 = Vector2(480, 384)
var boom_pos: Vector2 = Vector2.ZERO
var boom_direction: Vector2 = Vector2.RIGHT
var boom_timer: float = 0.0
var bomb_pos: Vector2 = Vector2.ZERO
var bomb_timer: float = 0.0
var fatal: bool = false
var background: Array[Sprite2D] = []
var ambient: CanvasModulate
var lantern: PointLight2D


func setup(main: Node) -> void:
	host = main
	state = host.state
	for name: String in ["chest", "grass", "rock", "block", "switch", "door", "heart", \
		"coin", "key", "boomerang", "bomb", "potion", "treasure"]:
		textures[name] = load("res://assets/props/%s.svg" % name)
	for name: String in ["tree", "house", "stall", "crystals", "ruins", "column", "lily", "arch"]:
		textures[name] = load("res://assets/scenery/%s.svg" % name)
	for name: String in ["distant", "middle", "foreground"]:
		var layer := Sprite2D.new()
		layer.texture = load("res://assets/backgrounds/%s.svg" % name)
		layer.centered = false
		layer.z_index = -5
		add_child(layer)
		background.append(layer)
	tiles = TileMapLayer.new()
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load("res://assets/terrain/tiles.svg")
	atlas.texture_region_size = Vector2i(64, 64)
	for i: int in range(4):
		atlas.create_tile(Vector2i(i, 0))
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 64)
	tile_set.add_source(atlas, 0)
	tiles.tile_set = tile_set
	tiles.position = Vector2(64, 128)
	tiles.z_index = -2
	add_child(tiles)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)
	hero = Actor.new()
	hero.setup("hero")
	actors.add_child(hero)
	effects = preload("res://scripts/effects.gd").new()
	add_child(effects)
	ambient = CanvasModulate.new()
	add_child(ambient)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.75))
	gradient.set_color(1, Color.TRANSPARENT)
	var light_texture := GradientTexture2D.new()
	light_texture.gradient = gradient
	light_texture.width = 256
	light_texture.height = 256
	light_texture.fill = GradientTexture2D.FILL_RADIAL
	light_texture.fill_from = Vector2(0.5, 0.5)
	light_texture.fill_to = Vector2(0.5, 0)
	lantern = PointLight2D.new()
	lantern.texture = light_texture
	lantern.texture_scale = 2.2
	lantern.color = GOLD
	lantern.energy = 0.7
	hero.add_child(lantern)
	enter_room(0, Vector2(280, 384), false)
	state.mode = "title"


func objective() -> String:
	var objectives: Dictionary = {
		0: "村人と話そう。東の遺跡へ  →", 1: "村人と話そう。東の遺跡へ  →",
		2: "草や魔物から琥珀貨を集め、東へ  →", 3: "草や魔物から琥珀貨を集め、東へ  →",
		4: "草や魔物から琥珀貨を集め、東へ  →", 5: "北の遺跡の門で E / A",
		6: "宝箱から風の輪を入手。東へ  →", 7: "風の輪を対岸のスイッチに当てよう",
		8: "爆弾袋を入手し、右のひび割れ壁を爆破",
		9: "石を右に押し、床スイッチへ。鍵で東の扉を開く",
		10: "床の灯を踏み、穴を避けて東へ", 11: "予兆を避け、梟の攻撃後に剣を当てよう",
	}
	return objectives[state.room]


# 部屋の変更は移動イベント。前景は作り直し、開封済み報酬は再配置しない。
func enter_room(index: int, spawn: Vector2, animate: bool = true) -> void:
	if animate and DisplayServer.get_name() != "headless":
		old_image = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	transition = 0.38 if animate else 0.0
	slide_dir = 1.0 if index >= state.room else -1.0
	state.room = index
	ambient.color = Color("b1bbc9") if index >= 6 else Color("e0edf0")
	lantern.visible = index >= 6
	state.checkpoint = index
	fatal = false
	invulnerable = 1.0
	attack_time = 0
	boom_timer = 0
	bomb_timer = 0
	projectiles.clear()
	pickups.clear()
	for enemy: Node2D in enemies:
		enemy.queue_free()
	enemies.clear()
	props.clear()
	hero.dead = false
	hero.sprite.play("idle")
	hero.position = spawn
	block_pos = Vector2(608, 384) if state.has_flag("weight") else Vector2(480, 384)
	_build_tiles()
	_build_props()
	_build_enemies()
	host.audio.set_track("boss" if index == 11 else ("dungeon" if index >= 6 else "field"))
	queue_redraw()


func _build_tiles() -> void:
	tiles.clear()
	for x: int in range(18):
		for y: int in range(8):
			var tile: int = 2 if state.room >= 6 else 0
			if y in [3, 4] and state.room < 6:
				tile = 1
			if state.room == 3 and ((x in range(1, 5) and y < 2)
				or (x in range(13, 17) and y > 5)):
				tile = 3
			tiles.set_cell(Vector2i(x, y), 0, Vector2i(tile, 0))
	tiles.modulate = Color("c1d3d2") if state.room >= 6 else Color.WHITE
	if state.room == 4:
		tiles.modulate = Color("efd3a8")


func _prop(kind: String, at: Vector2, id: String = "", reward: String = "") -> void:
	props.append({"kind": kind, "pos": at, "id": id, "reward": reward})


func _build_props() -> void:
	if state.room < 6:
		for i: int in range(10):
			var id: String = "grass-%d-%d" % [state.room, i]
			if not state.has_flag(id):
				_prop("grass", Vector2(400 + (i % 5) * 115, 240 + (i / 5) * 310), id)
		_prop("rock", Vector2(610, 384), "rock-%d" % state.room)
		if state.room == 0:
			_prop("villager", Vector2(420, 290), "elder")
			_prop("villager", Vector2(770, 500), "scout")
		if state.room == 1:
			_prop("merchant", Vector2(500, 290), "shop")
		if state.room == 4:
			_prop("chest", Vector2(890, 530), "field-heart", "heart")
		if state.room == 5:
			_prop("door", Vector2(640, 190), "entrance")
	else:
		match state.room:
			6: _prop("chest", Vector2(500, 330), "wind", "boomerang")
			7: _prop("switch", Vector2(850, 384), "wind-bridge")
			8: _prop("chest", Vector2(350, 300), "powder", "bombs")
			9:
				_prop("switch", Vector2(608, 384), "weight")
				_prop("chest", Vector2(850, 300), "small-key", "key")
				_prop("door", Vector2(1150, 384), "iron")
			10:
				_prop("switch", Vector2(416, 384), "star")
				_prop("chest", Vector2(830, 270), "deep-heart", "heart")
			11:
				if state.has_flag("boss"):
					_prop("treasure", Vector2(900, 384), "island-light", "treasure")
	for prop: Dictionary in props:
		if prop.kind in ["villager", "merchant"]:
			var npc: Node2D = Actor.new()
			npc.setup(prop.kind)
			npc.position = prop.pos
			actors.add_child(npc)
			enemies.append(npc)


func _spawn(kind: String, at: Vector2, health: int = -1) -> Node2D:
	var enemy: Node2D = Actor.new()
	enemy.setup(kind)
	enemy.position = at
	enemy.origin = at
	enemy.timer = float(enemies.size()) * 0.35
	if health > 0:
		enemy.hp = health
	actors.add_child(enemy)
	enemies.append(enemy)
	return enemy


func _build_enemies() -> void:
	match state.room:
		2: _spawn("wanderer", Vector2(830, 390))
		3:
			_spawn("splitter", Vector2(860, 400))
			_spawn("ranger", Vector2(950, 240))
		4:
			_spawn("charger", Vector2(850, 390))
			_spawn("wanderer", Vector2(480, 500))
		5: _spawn("ranger", Vector2(940, 440))
		6: _spawn("wanderer", Vector2(900, 450))
		8: _spawn("wanderer", Vector2(650, 520))
		10: _spawn("charger", Vector2(1000, 400))
		11:
			if not state.has_flag("boss"):
				_spawn("boss", Vector2(900, 384))


# 物理時間と入力を消費して移動・当たり判定を更新する。
func _physics_process(delta: float) -> void:
	elapsed += delta
	transition = maxf(0, transition - delta)
	shake = maxf(0, shake - delta)
	position = Vector2(sin(elapsed * 97), cos(elapsed * 83)) * shake * 15
	for i: int in range(background.size()):
		background[i].position.x = sin(elapsed * 0.15 + i) * (i + 1) * 5
	queue_redraw()
	if state.mode != "play" or transition > 0 or fatal:
		return
	if hitstop > 0:
		hitstop -= delta
		return
	invulnerable = maxf(0, invulnerable - delta)
	attack_time = maxf(0, attack_time - delta)
	tool_time = maxf(0, tool_time - delta)
	var direction: Vector2 = Input.get_vector("left", "right", "up", "down")
	if absf(direction.x) > absf(direction.y):
		direction = Vector2(signf(direction.x), 0)
	elif not direction.is_zero_approx():
		direction = Vector2(0, signf(direction.y))
	if direction != Vector2.ZERO:
		facing = direction
		hero.sprite.flip_h = facing.x < 0
		_move_hero(direction * 245.0 * delta)
		hero.motion("walk")
	else:
		hero.motion("idle")
	if fatal:
		return
	if Input.is_action_just_pressed("attack"):
		sword()
	if Input.is_action_just_pressed("tool"):
		use_tool()
	if Input.is_action_just_pressed("interact"):
		interact()
	if state.mode != "play" or transition > 0:
		return
	_update_tools(delta)
	_update_enemies(delta)
	if fatal:
		return
	_update_projectiles(delta)
	if fatal:
		return
	_collect_pickups()
	_check_room_exit()
	hero.visible = invulnerable <= 0 or int(elapsed * 18) % 2 == 0


func barriers() -> Array[Rect2]:
	var result: Array[Rect2] = []
	if state.room == 7:
		if state.has_flag("wind-bridge"):
			result.append(Rect2(640, 128, 96, 202))
			result.append(Rect2(640, 440, 96, 200))
		else:
			result.append(Rect2(640, 128, 96, 512))
	if state.room == 8 and not state.has_flag("broken-wall"):
		result.append(Rect2(960, 128, 64, 512))
	if state.room == 9 and not state.unlocked.has("iron"):
		result.append(Rect2(1120, 128, 64, 512))
	if state.room == 10:
		result.append(Rect2(600, 160, 100, 160))
		result.append(Rect2(600, 450, 100, 160))
		if not state.has_flag("star"):
			result.append(Rect2(1050, 128, 48, 512))
	return result


func _move_hero(step: Vector2) -> void:
	var next: Vector2 = hero.position + step
	if state.room == 9 and next.distance_to(block_pos) < 50:
		var moved: Vector2 = block_pos + step
		if moved.x >= 400 and moved.x <= 850 and moved.y >= 200 and moved.y <= 570:
			block_pos = moved
			if block_pos.distance_to(Vector2(608, 384)) < 23:
				activate("weight")
		else:
			return
	for barrier: Rect2 in barriers():
		if barrier.grow(18).has_point(next):
			if state.room == 10 and barrier.size.x == 100:
				_damage_hero(Vector2.LEFT, true)
			return
	for prop: Dictionary in props:
		if prop.kind == "rock" and next.distance_to(prop.pos) < 44:
			return
	hero.position = Vector2(clampf(next.x, 84, 1196), clampf(next.y, 166, 610))
	if state.room == 10 and hero.position.distance_to(Vector2(416, 384)) < 38:
		activate("star")


func _check_room_exit() -> void:
	if hero.position.x > 1188 and state.room != 5 and state.room != 11:
		enter_room(state.room + 1, Vector2(120, hero.position.y))
	elif hero.position.x < 92 and state.room > 0:
		enter_room(state.room - 1, Vector2(1150, hero.position.y))


static func sword_hits(origin: Vector2, direction: Vector2, target: Vector2) -> bool:
	var offset: Vector2 = target - origin
	return offset.length() <= 115 \
		and (offset.length() < 25 or direction.dot(offset.normalized()) > 0.25)


# 剣を振る入力ごとに一度ダメージを発生させる。
func sword() -> void:
	if attack_time > 0:
		return
	attack_time = 0.32
	hero.sprite.play("action")
	host.audio.cue("sword")
	for enemy: Node2D in enemies.duplicate():
		if enemy.kind not in ["villager", "merchant"] and not enemy.dead \
			and sword_hits(hero.position, facing, enemy.position):
			_hit_enemy(enemy, 1)
	for prop: Dictionary in props.duplicate():
		if prop.kind == "grass" and sword_hits(hero.position, facing, prop.pos):
			state.set_flag(prop.id)
			props.erase(prop)
			effects.burst(prop.pos, MINT, 12)
			pickups.append({"kind": "coin", "pos": prop.pos})


func interact() -> void:
	for prop: Dictionary in props.duplicate():
		if prop.kind not in ["villager", "merchant", "rock", "chest", "treasure", "door"]:
			continue
		if hero.position.distance_to(prop.pos) > 110:
			continue
		match prop.kind:
			"villager":
				var text: String = "東の遺跡に島の灯りが眠っている。宝箱は E / A で開けよう。"
				if prop.id == "scout":
					text = "剣は向いている方向へ届くよ。草を切り、岩を持ち上げると琥珀貨が見つかる。"
				host.talk("灯守の長老" if prop.id == "elder" else "見習いの灯守", text)
			"merchant":
				host.talk("旅の道具屋", "爆弾 3 個は 10 貨、回復薬は 15 貨。何を用意しよう？", true)
			"rock":
				props.erase(prop)
				hero.sprite.play("action")
				effects.burst(prop.pos, GOLD)
				pickups.append({"kind": "coin", "pos": prop.pos})
			"chest", "treasure":
				if state.room == 9 and not state.has_flag("weight"):
					host.notice = "宝箱は沈んでいる。石を床の灯へ押そう。"
				elif prop.id == "powder" and state.opened.has("powder") and state.bombs < 3:
					state.bombs = 3
					effects.popup(prop.pos, "爆弾を3個まで補充")
					host.audio.cue("chest")
				else:
					_open_chest(prop)
			"door":
				if prop.id == "entrance":
					enter_room(6, Vector2(200, 384))
				elif state.unlock_door("iron"):
					host.audio.cue("door")
					effects.burst(prop.pos, GOLD)
				else:
					host.notice = "鍵が必要。石を押して宝箱を取り出そう。"
		return


func _open_chest(prop: Dictionary) -> void:
	if not state.open_chest(prop.id, prop.reward):
		return
	host.audio.cue("chest")
	effects.burst(prop.pos, GOLD, 30)
	effects.popup(prop.pos, {"boomerang": "風の輪を手に入れた", "bombs": "爆弾袋を手に入れた",
		"key": "小さな鍵 +1", "heart": "最大ハート +1", "treasure": "島の灯り"}[prop.reward])
	host.notice = "道具は Esc / Start のメニューで選択。K / Y で使おう。"
	if prop.reward == "treasure":
		host.show_result(true)


func activate(flag: String) -> void:
	if state.has_flag(flag):
		return
	state.set_flag(flag)
	host.audio.cue("door")
	effects.popup(hero.position, "仕掛けが動いた")
	shake = 0.22


func use_tool() -> void:
	if tool_time > 0:
		return
	if state.tool == "boomerang" and state.boomerang_owned and boom_timer <= 0:
		boom_pos = hero.position
		boom_direction = facing
		boom_timer = 0.95
	elif state.tool == "bomb" and state.bombs_owned and state.bombs > 0 and bomb_timer <= 0:
		state.bombs -= 1
		bomb_pos = hero.position + facing * 48
		bomb_timer = 1.1
	else:
		host.notice = "道具はメニューで選べます。爆弾切れは入口の宝箱から補充できます。"
		return
	tool_time = 0.45
	hero.sprite.play("action")
	host.audio.cue("tool")


func _update_tools(delta: float) -> void:
	if boom_timer > 0:
		boom_timer -= delta
		boom_pos += (boom_direction if boom_timer > 0.48 else boom_pos.direction_to(hero.position)) \
			* 650 * delta
		if state.room == 7 and boom_pos.distance_to(Vector2(850, 384)) < 64:
			activate("wind-bridge")
		for enemy: Node2D in enemies:
			if enemy.kind not in ["villager", "merchant"] and not enemy.dead \
				and enemy.hurt_time <= 0 and boom_pos.distance_to(enemy.position) < 60:
				_hit_enemy(enemy, 1)
	if bomb_timer > 0:
		bomb_timer -= delta
		if bomb_timer <= 0:
			effects.burst(bomb_pos, GOLD, 50)
			effects.popup(bomb_pos, "爆発")
			shake = 0.5
			host.audio.cue("defeat")
			if state.room == 8 and absf(bomb_pos.x - 992) < 155:
				activate("broken-wall")
			for enemy: Node2D in enemies.duplicate():
				if enemy.kind not in ["villager", "merchant"] \
					and bomb_pos.distance_to(enemy.position) < 165:
					_hit_enemy(enemy, 3)


func _update_enemies(delta: float) -> void:
	for enemy: Node2D in enemies:
		if enemy.dead or enemy.kind in ["villager", "merchant"]:
			continue
		enemy.timer += delta
		if enemy.hurt_time > 0:
			continue
		var direction: Vector2 = enemy.position.direction_to(hero.position)
		match enemy.kind:
			"wanderer", "splitter":
				enemy.position += direction * (65 if enemy.kind == "wanderer" else 42) * delta
				enemy.motion("walk")
			"charger":
				var phase: float = fmod(enemy.timer, 2.8)
				if phase < 1.4:
					enemy.velocity = direction * 340
					enemy.motion("idle")
				elif phase < 2.15:
					enemy.position += enemy.velocity * delta
					enemy.motion("action")
			"ranger":
				if enemy.timer > 2.0:
					enemy.timer = 0
					enemy.sprite.play("action")
					projectiles.append({"pos": enemy.position, "vel": direction * 190, "life": 5.0})
			"boss":
				_boss_step(enemy, delta)
		enemy.position.x = clampf(enemy.position.x, 150, 1120)
		enemy.position.y = clampf(enemy.position.y, 200, 580)
		if hero.position.distance_to(enemy.position) < (70 if enemy.kind == "boss" else 43):
			_damage_hero(-direction)


func _boss_step(enemy: Node2D, delta: float) -> void:
	var furious: bool = enemy.hp <= 8
	var cycle: float = 2.4 if furious else 3.2
	var phase: float = fmod(enemy.timer, cycle)
	if phase < 1.0:
		enemy.velocity = enemy.position.direction_to(hero.position) * (310 if furious else 220)
		enemy.motion("idle")
	elif phase < 1.65:
		enemy.motion("action")
		enemy.position += enemy.velocity * delta
	else:
		enemy.motion("idle")
	if enemy.timer >= cycle:
		enemy.timer = 0
		for i: int in range(8 if furious else 4):
			var angle: float = TAU * i / (8.0 if furious else 4.0)
			projectiles.append({"pos": enemy.position, "vel": Vector2.from_angle(angle) * 165,
				"life": 4.0})


func _update_projectiles(delta: float) -> void:
	for shot: Dictionary in projectiles.duplicate():
		var before: Vector2 = shot.pos
		shot.pos += shot.vel * delta
		shot.life -= delta
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(hero.position, before, shot.pos)
		if closest.distance_to(hero.position) < 24:
			_damage_hero(shot.vel.normalized())
			projectiles.erase(shot)
		elif shot.life <= 0:
			projectiles.erase(shot)


func _hit_enemy(enemy: Node2D, damage: int) -> void:
	if enemy.dead or enemy.hurt_time > 0:
		return
	enemy.hp -= damage
	enemy.hurt_time = 0.32
	enemy.sprite.play("hurt")
	enemy.position += hero.position.direction_to(enemy.position) * 18
	effects.burst(enemy.position, GOLD)
	effects.popup(enemy.position, str(damage))
	hitstop = 0.055
	host.audio.cue("hurt")
	if enemy.hp <= 0:
		enemy.dead = true
		enemy.sprite.play("death")
		effects.burst(enemy.position, Color("adc0cb"), 26)
		pickups.append({"kind": "heart" if state.hp < state.max_hp else "coin", "pos": enemy.position})
		if enemy.kind == "splitter":
			_spawn("wanderer", enemy.position + Vector2(45, 0), 1)
			_spawn("wanderer", enemy.position - Vector2(45, 0), 1)
		if enemy.kind == "boss":
			state.set_flag("boss")
			shake = 1.0
			host.audio.cue("defeat")
			projectiles.clear()
			_prop("treasure", Vector2(900, 384), "island-light", "treasure")
			host.notice = "梟を倒した。祭壇の灯りを E / A で受け取ろう。"
		var tween: Tween = create_tween()
		tween.tween_property(enemy, "modulate:a", 0.0, 0.4).set_delay(0.35)


func _damage_hero(direction: Vector2, pit: bool = false) -> void:
	if invulnerable > 0 or fatal:
		return
	invulnerable = 1.35
	hero.hurt_time = 0.32
	hero.sprite.play("hurt")
	hero.position += direction * 42
	if pit:
		hero.position = Vector2(510, 384)
	effects.burst(hero.position, Color("e78c79"))
	effects.popup(hero.position, "−1", Color("f29a89"))
	shake = 0.35
	host.audio.cue("hurt")
	if state.damage(1):
		fatal = true
		state.mode = "play"
		hero.dead = true
		hero.sprite.play("death")
		await get_tree().create_timer(0.55).timeout
		host.show_result(false)


func _collect_pickups() -> void:
	for pickup: Dictionary in pickups.duplicate():
		if hero.position.distance_to(pickup.pos) > 48:
			continue
		if pickup.kind == "heart":
			state.heal(1)
		else:
			state.coins = mini(9999, state.coins + 3)
		effects.popup(pickup.pos, "+1" if pickup.kind == "heart" else "+3")
		host.audio.cue("chest")
		pickups.erase(pickup)


func _draw() -> void:
	if not is_instance_valid(hero):
		return
	draw_rect(Rect2(58, 122, 1164, 524), Color("071d2b"), false, 8)
	_draw_architecture()
	_draw_scenery()
	for prop: Dictionary in props:
		if prop.kind in ["villager", "merchant"]:
			continue
		var color: Color = Color.WHITE
		if prop.kind == "chest" and state.opened.has(prop.id):
			color = Color(0.5, 0.6, 0.6, 0.6)
		if prop.kind == "switch" and state.has_flag(prop.id):
			color = Color(1.5, 2.0, 1.3)
		draw_texture_rect(textures[prop.kind], Rect2(prop.pos - Vector2(42, 42), Vector2(84, 84)),
			false, color)
	if state.room == 9:
		draw_texture_rect(textures.block, Rect2(block_pos - Vector2(40, 40), Vector2(80, 80)), false)
	for pickup: Dictionary in pickups:
		draw_texture_rect(textures[pickup.kind],
			Rect2(pickup.pos - Vector2(20, 20), Vector2(40, 40)), false)
	for shot: Dictionary in projectiles:
		draw_circle(shot.pos, 14, Color("e68a6f"))
		draw_circle(shot.pos, 6, GOLD)
	if boom_timer > 0:
		draw_set_transform(boom_pos, elapsed * 16)
		draw_texture_rect(textures.boomerang, Rect2(-32, -32, 64, 64), false)
		draw_set_transform(Vector2.ZERO)
	if bomb_timer > 0:
		draw_circle(bomb_pos, 145, Color(1, 0.6, 0.2, 0.1 + sin(elapsed * 20) * 0.05))
		draw_texture_rect(textures.bomb, Rect2(bomb_pos - Vector2(28, 28), Vector2(56, 56)), false)
	if attack_time > 0:
		var angle: float = facing.angle()
		draw_arc(hero.position, 90, angle - 1.2, angle + 1.2, 18, GOLD, 9, true)
		draw_arc(hero.position, 110, angle - 0.9, angle + 0.9, 18, Color(0.5, 1, 0.9, 0.7), 3, true)
	_draw_enemy_signals()
	if shake > 0.6:
		draw_rect(Rect2(64, 128, 1152, 512), Color(1, 0.9, 0.5, (shake - 0.6) * 0.45))
	if transition > 0 and old_image != null:
		if state.room == 6:
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.025, 0.05, 0.08, transition / 0.38))
		else:
			draw_texture_rect(old_image, Rect2(-slide_dir * (1.0 - transition / 0.38) * 1280, 0,
				1280, 720), false, Color(1, 1, 1, transition / 0.38))


func _draw_architecture() -> void:
	for barrier: Rect2 in barriers():
		var pit: bool = state.room in [7, 10]
		draw_rect(barrier, Color("081522") if pit else Color("405269"))
		draw_rect(barrier, Color("77a4a4") if pit else GOLD, false, 3)
		for y: int in range(int(barrier.position.y) + 12, int(barrier.end.y), 35):
			draw_line(Vector2(barrier.position.x + 8, y), Vector2(barrier.end.x - 8, y + 15),
				Color("25394b"), 3)
	if state.room == 7 and state.has_flag("wind-bridge"):
		draw_rect(Rect2(630, 330, 125, 110), Color("b99560"))
		for x: int in range(634, 755, 18):
			draw_line(Vector2(x, 333), Vector2(x, 437), Color("5b5549"), 3)
	if state.room >= 6:
		for at: Vector2 in [Vector2(170, 205), Vector2(1110, 565)]:
			for r: int in range(5, 0, -1):
				draw_circle(at, r * 19, Color(0.3, 0.9, 0.75, 0.017))
			draw_circle(at, 8, MINT)
			draw_arc(at, 18, 0, TAU, 24, GOLD, 2, true)



func _draw_enemy_signals() -> void:
	for enemy: Node2D in enemies:
		if enemy.dead:
			continue
		if enemy.kind == "charger" and fmod(enemy.timer, 2.8) > 0.8 \
			and fmod(enemy.timer, 2.8) < 1.4:
			draw_line(enemy.position, enemy.position + enemy.velocity.normalized() * 220,
				Color(0.95, 0.45, 0.35, 0.5), 24)
		if enemy.kind == "boss":
			var cycle: float = 2.4 if enemy.hp <= 8 else 3.2
			if fmod(enemy.timer, cycle) < 1:
				draw_line(enemy.position, enemy.position + enemy.velocity.normalized() * 260,
					Color(1, 0.4, 0.3, 0.3), 90)
			draw_rect(Rect2(440, 105, 400, 12), Color("162b3b"))
			draw_rect(Rect2(440, 105, 400 * maxf(enemy.hp, 0) / 16.0, 12),
				Color("ea9879") if enemy.hp <= 8 else GOLD)



func _scenery(name: String, rect: Rect2, color: Color = Color.WHITE) -> void:
	draw_texture_rect(textures[name], rect, false, color)


func _draw_scenery() -> void:
	if state.room < 6:
		_scenery("tree", Rect2(70, 128, 145, 145))
		_scenery("tree", Rect2(1020, 488, 180, 180))
		match state.room:
			0:
				_scenery("house", Rect2(180, 134, 245, 196))
				_scenery("house", Rect2(880, 445, 240, 192))
			1:
				_scenery("stall", Rect2(420, 132, 256, 192))
				_scenery("house", Rect2(870, 440, 225, 180))
			2:
				for x: int in [190, 740, 980]:
					_scenery("tree", Rect2(x, 130, 185, 185))
				_scenery("ruins", Rect2(220, 445, 225, 170))
			3:
				_scenery("lily", Rect2(165, 170, 110, 83))
				_scenery("lily", Rect2(965, 525, 110, 83))
				_scenery("crystals", Rect2(260, 460, 190, 158))
				_scenery("crystals", Rect2(720, 140, 190, 158))
			4:
				_scenery("tree", Rect2(220, 130, 190, 190), Color("efc68b"))
				_scenery("tree", Rect2(950, 130, 190, 190), Color("efc68b"))
				_scenery("ruins", Rect2(230, 460, 225, 170))
			5:
				_scenery("arch", Rect2(510, 113, 260, 208))
				_scenery("ruins", Rect2(830, 450, 250, 187))
				_scenery("column", Rect2(340, 145, 78, 130))
				_scenery("column", Rect2(895, 145, 78, 130))
	else:
		for at: Vector2 in [Vector2(140, 135), Vector2(1090, 470)]:
			_scenery("column", Rect2(at, Vector2(78, 130)))
		_scenery("ruins", Rect2(240, 485, 180, 135))
		if state.room == 11:
			_scenery("arch", Rect2(820, 130, 270, 216))
			_scenery("crystals", Rect2(210, 150, 150, 125))
		elif state.room == 7:
			_scenery("crystals", Rect2(840, 180, 160, 134))
