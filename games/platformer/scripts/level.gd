class_name DeliveryRoute
extends Node2D
## ステージ生成は初期化時に一度だけ実行する。物理・取得処理はイベントを消費するため非冪等。

signal sound_requested(sound: String)
const TILE: int = 48
const WIDTHS: Array[int] = [100, 112]
const NAMES: Array[String] = ["風の草原", "ひかりの洞窟"]
var stage: int = 0
var player: Courier
var camera: Camera2D
var terrain: TileMapLayer
var enemies: Array[TrailEnemy] = []
var items: Array[Sprite2D] = []
var blocks: Array[SupplyBlock] = []
var goal_x: float = 0.0
var session: Node
var elapsed: float = 0.0


func _ready() -> void:
	session = get_node("/root/Session")
	_build_terrain()
	_build_objects()
	player = Courier.new()
	player.position = Vector2(130, 624)
	player.sound_requested.connect(func(sound: String) -> void: sound_requested.emit(sound))
	add_child(player)
	camera = Camera2D.new()
	camera.position = Vector2(640, 360)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = WIDTHS[stage] * TILE
	camera.limit_bottom = 720
	add_child(camera)


func _build_terrain() -> void:
	terrain = TileMapLayer.new()
	var tiles: TileSet = TileSet.new()
	tiles.tile_size = Vector2i(TILE, TILE)
	tiles.add_physics_layer()
	tiles.set_physics_layer_collision_layer(0, 1)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	var file: String = "ground" if stage == 0 else "underground"
	source.texture = load("res://assets/images/%s.svg" % file)
	source.texture_region_size = Vector2i(TILE, TILE)
	source.create_tile(Vector2i.ZERO)
	tiles.add_source(source, 0)
	var data: TileData = source.get_tile_data(Vector2i.ZERO, 0)
	data.add_collision_polygon(0)
	data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-24, -24), Vector2(24, -24), Vector2(24, 24), Vector2(-24, 24)]))
	terrain.tile_set = tiles
	add_child(terrain)
	for x: int in WIDTHS[stage]:
		if is_gap(x):
			continue
		for y: int in range(13, 16):
			terrain.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	for start: int in [28, 49, 73]:
		for x: int in range(start, start + 4):
			terrain.set_cell(Vector2i(x, 11), 0, Vector2i.ZERO)
		terrain.set_cell(Vector2i(start - 1, 12), 0, Vector2i.ZERO)
	if stage == 1:
		for x: int in range(86, 90):
			terrain.set_cell(Vector2i(x, 10), 0, Vector2i.ZERO)


func is_gap(column: int) -> bool:
	var gaps: Array[int] = [21, 22, 42, 43, 65, 66, 87, 88]
	if stage == 1:
		gaps = [20, 21, 39, 40, 61, 62, 81, 82, 99, 100]
	return column in gaps


func _build_objects() -> void:
	for column: int in [8, 9, 10, 17, 18, 29, 30, 31, 37, 38, 50, 51, 57, 58, 74, 75, 91]:
		var y: float = 485 if column in [29, 30, 31, 50, 51, 74, 75] else 568
		spawn_item(Vector2(column * TILE + 24, y), "coin")
	for column: int in [12, 34, 55, 78]:
		var block: SupplyBlock = SupplyBlock.new()
		block.position = Vector2(column * TILE + 24, 504)
		block.contents = "power" if column in [12, 55] else "coin"
		block.opened.connect(_block_opened)
		add_child(block)
		blocks.append(block)
	for index: int in 7:
		var enemy: TrailEnemy = TrailEnemy.new()
		enemy.kind = "walker" if index % 2 == 0 else "shell"
		var column: int = 16 + index * 11
		var floor_y: int = 13
		for row: int in range(10, 13):
			if terrain.get_cell_source_id(Vector2i(column, row)) != -1:
				floor_y = mini(floor_y, row)
		enemy.position = Vector2(column * TILE + 24, floor_y * TILE)
		add_child(enemy)
		enemies.append(enemy)
	goal_x = (WIDTHS[stage] - 5) * TILE
	var goal: Sprite2D = Sprite2D.new()
	goal.texture = load("res://assets/images/goal.svg")
	goal.position = Vector2(goal_x, 564)
	add_child(goal)


func spawn_item(at: Vector2, kind: String) -> void:
	var item: Sprite2D = Sprite2D.new()
	item.texture = load("res://assets/images/%s.svg" % kind)
	item.position = at
	item.set_meta("kind", kind)
	item.set_meta("origin_y", at.y)
	add_child(item)
	items.append(item)


func _block_opened(at: Vector2, contents: String) -> void:
	if contents == "coin":
		session.collect_coin()
		sound_requested.emit("coin")
	else:
		spawn_item(at, contents)
		sound_requested.emit("power")


func _physics_process(delta: float) -> void:
	if session.phase != "playing":
		return
	elapsed += delta
	camera.position.x = clampf(player.position.x + 160, 640, WIDTHS[stage] * TILE - 640)
	if player.position.y > 810:
		session.damage(true, "穴に落ちた")
		return
	_collect_items()
	_check_enemies()
	if absf(player.position.x - goal_x) < 32 and player.position.y > 490:
		session.finish_stage()


func _collect_items() -> void:
	for item: Sprite2D in items.duplicate():
		item.position.y = float(item.get_meta("origin_y")) + sin(elapsed * 4 + item.position.x) * 4
		var height: float = 64.0 if session.powered else 42.0
		var body: Rect2 = Rect2(player.position - Vector2(19, height), Vector2(38, height))
		if not body.grow(10).has_point(item.position):
			continue
		var kind: String = item.get_meta("kind")
		if kind == "coin":
			session.collect_coin()
		else:
			session.collect_power()
			player.transform()
		sound_requested.emit(kind)
		items.erase(item)
		item.queue_free()


func _check_enemies() -> void:
	for enemy: TrailEnemy in enemies:
		if not is_instance_valid(enemy) or enemy.mode == "dead":
			continue
		if enemy.mode == "sliding":
			for other: TrailEnemy in enemies:
				if is_instance_valid(other) and other != enemy and other.mode != "dead":
					if enemy.position.distance_to(other.position) < 36:
						other.defeat()
						session.score += 200
		var distance: Vector2 = player.position - enemy.position
		var height: float = 64 if session.powered else 42
		if absf(distance.x) > 31 or distance.y < -36 or distance.y > height:
			continue
		if player.velocity.y > 0 and player.previous_feet <= enemy.position.y - 20:
			enemy.stomp(player.position.x)
			player.bounce()
			session.score += 200
		elif enemy.mode == "resting":
			enemy.stomp(player.position.x)
		elif enemy.kick_grace == 0.0:
			var result: String = session.damage()
			if result == "shrunk":
				player.transform()
				sound_requested.emit("power")
