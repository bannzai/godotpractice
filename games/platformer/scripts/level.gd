class_name DeliveryRoute
extends Node2D
## ステージ生成は初期化時に一度だけ実行する。物理・取得処理はイベントを消費するため非冪等。

signal sound_requested(sound: String)
signal feedback_requested(kind: String, at: Vector2)
const TILE: int = 48
const WIDTHS: Array[int] = [100, 112]
const NAMES: Array[String] = ["風の草原", "ひかりの洞窟"]
const MEADOW_GAPS: Array[int] = [21, 22, 42, 43, 65, 66, 87, 88]
const CAVE_GAPS: Array[int] = [20, 21, 39, 40, 61, 62, 81, 82, 99, 100]
const MEADOW_GROUND_PROFILE: Array[Vector3i] = [
	Vector3i(44, 49, 12), Vector3i(46, 48, 11),
	Vector3i(67, 71, 12), Vector3i(69, 71, 11),
	Vector3i(89, 95, 12), Vector3i(92, 95, 11),
]
const CAVE_GROUND_PROFILE: Array[Vector3i] = [
	Vector3i(22, 27, 14), Vector3i(31, 36, 12), Vector3i(41, 46, 14),
	Vector3i(52, 57, 12), Vector3i(63, 69, 11), Vector3i(74, 81, 12),
	Vector3i(83, 88, 14), Vector3i(92, 99, 12),
]
const MEADOW_PLATFORMS: Array[Vector3i] = [
	Vector3i(28, 4, 11), Vector3i(49, 4, 11), Vector3i(73, 4, 11),
]
const CAVE_PLATFORMS: Array[Vector3i] = [
	Vector3i(25, 5, 10), Vector3i(53, 3, 9), Vector3i(74, 5, 10),
	Vector3i(94, 4, 9),
]
const COMIC_THEME: Theme = preload("res://resources/delivery_theme.tres")
const COMIC_OUTLINE: Shader = preload("res://resources/comic_outline.gdshader")
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
var effects: RouteEffects
var hit_stop: float = 0.0
var shake_strength: float = 0.0
var shake_time: float = 0.0
var goal: Sprite2D
var object_outline: ShaderMaterial


func _ready() -> void:
	session = get_node("/root/Session")
	object_outline = ShaderMaterial.new()
	object_outline.shader = COMIC_OUTLINE
	object_outline.set_shader_parameter("outline_width_px", 2.0)
	effects = RouteEffects.new()
	add_child(effects)
	_build_terrain()
	_build_objects()
	player = Courier.new()
	player.position = Vector2(130, 624)
	player.sound_requested.connect(func(sound: String) -> void: sound_requested.emit(sound))
	player.landed.connect(func(at: Vector2) -> void: effects.burst("land", at))
	add_child(player)
	for enemy: TrailEnemy in enemies:
		enemy.target = player
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
	var file: String = "ground" if stage == 0 else "underground"
	for source_id: int in 2:
		var source: TileSetAtlasSource = TileSetAtlasSource.new()
		var suffix: String = "" if source_id == 0 else "_fill"
		source.texture = load("res://assets/images/%s%s.svg" % [file, suffix])
		source.texture_region_size = Vector2i(TILE, TILE)
		source.create_tile(Vector2i.ZERO)
		tiles.add_source(source, source_id)
		var data: TileData = source.get_tile_data(Vector2i.ZERO, 0)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-24, -24), Vector2(24, -24), Vector2(24, 24), Vector2(-24, 24)]))
	terrain.tile_set = tiles
	add_child(terrain)
	for x: int in WIDTHS[stage]:
		if is_gap(x):
			continue
		var top_row: int = _ground_top_row(x)
		for y: int in range(top_row, 16):
			terrain.set_cell(Vector2i(x, y), 0 if y == top_row else 1, Vector2i.ZERO)
	var platforms: Array[Vector3i] = MEADOW_PLATFORMS if stage == 0 else CAVE_PLATFORMS
	for platform: Vector3i in platforms:
		for x: int in range(platform.x, platform.x + platform.y):
			terrain.set_cell(Vector2i(x, platform.z), 0, Vector2i.ZERO)
		# 草原の浮き足場には一段低い助走台を残し、既存の自動走破の跳躍周期を保つ。
		if stage == 0:
			terrain.set_cell(Vector2i(platform.x - 1, 12), 0, Vector2i.ZERO)
	_build_landmarks()


func is_gap(column: int) -> bool:
	var gaps: Array[int] = MEADOW_GAPS if stage == 0 else CAVE_GAPS
	return column in gaps


func _ground_top_row(column: int) -> int:
	var result: int = 13
	var profile: Array[Vector3i] = (
		MEADOW_GROUND_PROFILE if stage == 0 else CAVE_GROUND_PROFILE
	)
	for band: Vector3i in profile:
		if column >= band.x and column < band.y:
			result = mini(result, band.z) if stage == 0 else band.z
	return result


func _surface_y(column: int) -> float:
	for row: int in range(6, 16):
		if terrain.get_cell_source_id(Vector2i(column, row)) != -1:
			return float(row * TILE)
	return 624.0


func _build_landmarks() -> void:
	var columns: Array[int] = [6, 36, 60, 84]
	var captions: Array[String] = ["風車の丘 →", "大跳躍！", "雲海便  中継所", "郵便塔は目前！"]
	if stage == 1:
		columns = [5, 27, 55, 68, 90, 105]
		captions = ["結晶坑道 →", "足元注意！", "灯をたどれ", "吊橋の上層", "深部  第三便", "出口は目前！"]
	for index: int in columns.size():
		_add_landmark(columns[index], captions[index], index)


func _add_landmark(column: int, caption: String, index: int) -> void:
	var marker: Node2D = Node2D.new()
	marker.position = Vector2(column * TILE + 24, _surface_y(column))
	marker.rotation = deg_to_rad(-2.0 if index % 2 == 0 else 2.0)
	marker.z_index = -1
	marker.set_meta("kind", "landmark")
	add_child(marker)
	var accent: Color = Color("ffcf57") if stage == 0 else Color("67edf0")
	var post: Line2D = Line2D.new()
	post.width = 9.0 if stage == 0 else 5.0
	post.default_color = Color("6f4329") if stage == 0 else Color("45738c")
	post.add_point(Vector2(0, -5))
	post.add_point(Vector2(0, -72 if stage == 0 else -82))
	marker.add_child(post)
	var board: Polygon2D = Polygon2D.new()
	board.polygon = _landmark_polygon()
	board.color = Color("fff4c7") if stage == 0 else Color("142f52")
	marker.add_child(board)
	var border: Line2D = Line2D.new()
	border.width = 6.0
	border.default_color = Color("153e4a") if stage == 0 else accent
	border.closed = true
	for point: Vector2 in board.polygon:
		border.add_point(point)
	marker.add_child(border)
	var label: Label = Label.new()
	label.theme = COMIC_THEME
	label.text = caption
	label.position = Vector2(-69, -112 if stage == 0 else -127)
	label.size = Vector2(138, 48 if stage == 0 else 62)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("153e4a") if stage == 0 else Color("efffff"))
	label.add_theme_color_override(
		"font_outline_color", Color("fff4c7") if stage == 0 else Color("07162e")
	)
	label.add_theme_constant_override("outline_size", 3)
	marker.add_child(label)


func _landmark_polygon() -> PackedVector2Array:
	if stage == 0:
		return PackedVector2Array([
			Vector2(-78, -116), Vector2(57, -116), Vector2(82, -92),
			Vector2(57, -65), Vector2(-78, -65),
		])
	return PackedVector2Array([
		Vector2(0, -145), Vector2(72, -121), Vector2(63, -69),
		Vector2(0, -53), Vector2(-63, -69), Vector2(-72, -121),
	])


func _build_objects() -> void:
	for column: int in [8, 9, 10, 17, 18, 29, 30, 31, 37, 38, 50, 51, 57, 58, 74, 75, 91]:
		var y: float = _surface_y(column) - 56.0
		spawn_item(Vector2(column * TILE + 24, y), "coin")
	for column: int in [12, 34, 55, 78]:
		var block: SupplyBlock = SupplyBlock.new()
		block.position = Vector2(column * TILE + 24, _surface_y(column) - 120.0)
		block.contents = "power" if column in [12, 55] else "coin"
		block.opened.connect(_block_opened)
		add_child(block)
		block.sprite.material = object_outline
		blocks.append(block)
	for index: int in 7:
		var enemy: TrailEnemy = TrailEnemy.new()
		enemy.kind = "walker" if index % 2 == 0 else "shell"
		var column: int = 16 + index * 11
		enemy.position = Vector2(column * TILE + 24, _surface_y(column))
		add_child(enemy)
		enemies.append(enemy)
	goal_x = (WIDTHS[stage] - 5) * TILE
	goal = Sprite2D.new()
	goal.texture = load("res://assets/images/goal.svg")
	goal.position = Vector2(goal_x, _surface_y(int(goal_x / TILE)) - 60.0)
	goal.material = object_outline
	add_child(goal)


func spawn_item(at: Vector2, kind: String) -> void:
	var item: Sprite2D = Sprite2D.new()
	item.texture = load("res://assets/images/%s.svg" % kind)
	item.position = at
	item.material = object_outline
	item.set_meta("kind", kind)
	item.set_meta("origin_y", at.y)
	add_child(item)
	items.append(item)
	if kind == "power":
		item.scale = Vector2(0.2, 0.2)
		var tween: Tween = item.create_tween()
		tween.tween_property(item, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)


func _block_opened(at: Vector2, contents: String) -> void:
	effects.burst("block", at)
	if contents == "coin":
		session.collect_coin()
		sound_requested.emit("coin")
		impact("coin", at, "+100")
	else:
		spawn_item(at, contents)
		sound_requested.emit("power")
		effects.burst("power", at)


func _process(delta: float) -> void:
	if session.phase == "paused":
		return
	shake_time += delta
	shake_strength = move_toward(shake_strength, 0.0, delta * 25.0)
	camera.offset = Vector2(sin(shake_time * 97), cos(shake_time * 83)) * shake_strength
	goal.rotation = sin(shake_time * 1.8) * 0.025


func _physics_process(delta: float) -> void:
	if session.phase != "playing":
		return
	if player.position.y > 810:
		session.damage(true, "穴に落ちた")
		return
	if hit_stop > 0.0:
		hit_stop = maxf(hit_stop - delta, 0.0)
		return
	elapsed += delta
	camera.position.x = clampf(player.position.x + 160, 640, WIDTHS[stage] * TILE - 640)
	_collect_items()
	_check_enemies()
	if session.phase == "playing" and absf(player.position.x - goal_x) < 32:
		if player.position.y <= 490:
			return
		impact("clear", Vector2(goal_x, 540), "配達完了")
		session.finish_stage()


func _collect_items() -> void:
	for item: Sprite2D in items.duplicate():
		item.position.y = float(item.get_meta("origin_y")) + sin(elapsed * 4 + item.position.x) * 4
		if item.get_meta("kind") == "coin":
			item.scale.x = 0.78 + absf(sin(elapsed * 3.4 + item.position.x)) * 0.22
		var height: float = 64.0 if session.powered else 42.0
		var body: Rect2 = Rect2(player.position - Vector2(19, height), Vector2(38, height))
		if not body.grow(10).has_point(item.position):
			continue
		var kind: String = item.get_meta("kind")
		if kind == "coin":
			session.collect_coin()
			impact("coin", item.position, "+100")
		else:
			session.collect_power()
			player.transform()
			impact("power", item.position, "+500")
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
						impact("stomp", other.position + Vector2(0, -18), "+200")
		var distance: Vector2 = player.position - enemy.position
		var height: float = 64 if session.powered else 42
		if absf(distance.x) > 31 or distance.y < -36 or distance.y > height:
			continue
		if player.velocity.y > 0 and player.previous_feet <= enemy.position.y - 20:
			enemy.stomp(player.position.x)
			player.bounce()
			session.score += 200
			impact("stomp", enemy.position + Vector2(0, -18), "+200")
		elif enemy.mode == "resting":
			enemy.stomp(player.position.x)
			impact("stomp", enemy.position + Vector2(0, -18))
		elif enemy.kick_grace == 0.0:
			var result: String = session.damage()
			if result == "shrunk":
				player.hurt()
				sound_requested.emit("hurt")
				impact("hurt", player.position + Vector2(0, -28), "-1")


func impact(kind: String, at: Vector2, score_text: String = "") -> void:
	effects.burst(kind, at, score_text)
	feedback_requested.emit(kind, at)
	if kind in ["stomp", "power", "hurt", "death", "clear"]:
		shake_strength = maxf(shake_strength, 7.0 if kind in ["hurt", "death"] else 3.5)
	if kind in ["stomp", "power", "hurt"]:
		hit_stop = maxf(hit_stop, 0.045)
		player.freeze(hit_stop)
		for enemy: TrailEnemy in enemies:
			if is_instance_valid(enemy):
				enemy.freeze(hit_stop)
