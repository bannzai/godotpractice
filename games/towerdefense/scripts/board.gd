extends Node2D
## 経路・射程とキャラの表示。描画位置以外の戦闘状態はRunを参照する。

const Catalog := preload("res://scripts/catalog.gd")
const Actor := preload("res://scripts/actor.gd")
const Ui := preload("res://scripts/ui.gd")

var run: Node
var selected_site: int = 0
var selected_kind: String = "arrow"
var preview_tower_kind: String = ""
var show_build_preview: bool = true
var enemy_nodes: Dictionary = {}
var tower_nodes: Dictionary = {}
var clock: float = 0.0
var shots: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var backdrop: Sprite2D
var preview_actor: Node2D
var shake: float = 0.0
var gallery: bool = false
var lantern: PointLight2D


func _ready() -> void:
	run = get_node("/root/Run")
	var backing := Polygon2D.new()
	backing.polygon = PackedVector2Array([
		Vector2.ZERO, Vector2(960, 0), Vector2(960, 720), Vector2(0, 720),
	])
	backing.color = Ui.PARCHMENT_DARK
	backing.z_index = -11
	add_child(backing)
	backdrop = Sprite2D.new()
	backdrop.texture = load("res://assets/tapestry/landscape.png")
	backdrop.centered = false
	var landscape_size := Vector2(backdrop.texture.get_width(), backdrop.texture.get_height())
	var landscape_scale: float = 960.0 / landscape_size.x
	backdrop.scale = Vector2.ONE * landscape_scale
	backdrop.position = Vector2(0, (720.0 - landscape_size.y * landscape_scale) * 0.5)
	backdrop.z_index = -10
	backdrop.modulate = Color(1.0, 0.96, 0.88, 0.84)
	add_child(backdrop)
	var gradient := Gradient.new()
	gradient.set_color(0, Color("ffe1a1"))
	gradient.set_color(1, Color(1, 0.8, 0.4, 0))
	var glow := GradientTexture2D.new()
	glow.gradient = gradient
	glow.width = 256
	glow.height = 256
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1, 0.5)
	lantern = PointLight2D.new()
	lantern.texture = glow
	lantern.position = Vector2(925, 475)
	lantern.energy = 0.35
	add_child(lantern)


# 描画アニメーションの時刻を進めるため、フレームごとに呼ぶ。
func _process(delta: float) -> void:
	clock += delta
	lantern.energy = 0.3 + sin(clock * 2.1) * 0.035
	shake = maxf(0.0, shake - delta * 18)
	position = Vector2(sin(clock * 95), cos(clock * 83)) * shake
	for group: Array[Dictionary] in [shots, rings]:
		for index: int in range(group.size() - 1, -1, -1):
			group[index].age += delta
			if float(group[index].age) >= float(group[index].duration):
				group.remove_at(index)
	if not gallery:
		_sync_actors()
		_sync_build_preview()
	queue_redraw()


func _sync_actors() -> void:
	var present: Array[int] = []
	for tower: Dictionary in run.towers:
		var site: int = tower.site
		present.append(site)
		if not tower_nodes.has(site):
			var actor: Node2D = Actor.new()
			actor.position = Catalog.SITES[site] + Vector2(0, -17)
			add_child(actor)
			actor.setup(tower.kind)
			tower_nodes[site] = actor
	for site: int in tower_nodes.keys():
		if site not in present:
			var actor: Node2D = tower_nodes[site]
			actor.act("death")
			tower_nodes.erase(site)
	present.clear()
	for enemy: Dictionary in run.enemies:
		var id: int = enemy.id
		present.append(id)
		if not enemy_nodes.has(id):
			var actor: Node2D = Actor.new()
			add_child(actor)
			actor.setup(enemy.kind, true)
			enemy_nodes[id] = actor
		enemy_nodes[id].position = enemy.position + Vector2(0, -15)
	for id: int in enemy_nodes.keys():
		if id not in present:
			var actor: Node2D = enemy_nodes[id]
			if is_instance_valid(actor):
				actor.act("death")
			enemy_nodes.erase(id)


## 選択中の空き地点へ、建設後の姿と資金不足を半透明で予告する。
func _sync_build_preview() -> void:
	var preview_kind: String = _effective_preview_kind()
	var visible: bool = show_build_preview and run.phase == "play" and not gallery
	visible = visible and selected_site >= 0 and selected_site < Catalog.SITES.size()
	visible = visible and Catalog.TOWERS.has(preview_kind)
	visible = visible and run.tower_at(selected_site).is_empty()
	if not visible:
		_clear_build_preview()
		return
	if not is_instance_valid(preview_actor) or preview_actor.kind != preview_kind:
		_clear_build_preview()
		preview_actor = Actor.new()
		preview_actor.z_index = 3
		add_child(preview_actor)
		preview_actor.setup(preview_kind)
	preview_actor.position = Catalog.SITES[selected_site] + Vector2(0, -17)
	var can_afford: bool = run.gold >= int(Catalog.TOWERS[preview_kind].cost)
	var pulse: float = 0.30 + sin(clock * 4.0) * 0.06
	preview_actor.modulate = Color(1.0, 1.0, 1.0, pulse) if can_afford \
		else Color(0.9, 0.45, 0.36, pulse * 0.8)


func _clear_build_preview() -> void:
	if is_instance_valid(preview_actor):
		preview_actor.queue_free()
	preview_actor = null


func _effective_preview_kind() -> String:
	var value: String = preview_tower_kind if not preview_tower_kind.is_empty() else selected_kind
	return value if Catalog.TOWERS.has(value) else selected_kind


# 戦闘イベントごとに一つの演出を開始する。
func event(value: Dictionary) -> void:
	match value.type:
		"shot":
			shots.append({"from": value.from + Vector2(0, -30),
				"to": value.to + Vector2(0, -15), "kind": value.kind,
				"age": 0.0, "duration": 0.25 if value.kind == "sun" else 0.35})
			for site: int in tower_nodes:
				if Catalog.SITES[site].distance_to(value.from) < 1:
					tower_nodes[site].act("attack")
			if value.splash > 0:
				ring(value.to, Catalog.TOWERS[value.kind].color, value.splash)
		"hurt", "death":
			if enemy_nodes.has(value.target):
				enemy_nodes[value.target].act(value.type)
				if value.type == "death":
					enemy_nodes.erase(value.target)
			if value.type == "death":
				burst(value.position, Ui.GOLD, 12)
				popup(value.position, "+%d" % value.reward, Ui.GOLD)
		"build", "upgrade":
			if value.type == "upgrade":
				for site: int in tower_nodes:
					if Catalog.SITES[site].distance_to(value.position) < 1:
						tower_nodes[site].act("hurt")
			burst(value.position, Ui.GOLD, 22)
			ring(value.position, Ui.GOLD, 68)
			popup(value.position, "建設" if value.type == "build" else "強化", Ui.GOLD)
		"sell":
			for site: int in tower_nodes.keys():
				if Catalog.SITES[site].distance_to(value.position) < 1:
					tower_nodes[site].act("death")
					tower_nodes.erase(site)
			burst(value.position, Ui.GOLD, 12)
		"base":
			shake = 8
			burst(value.position, Color("ff977e"), 28)
			popup(value.position + Vector2(-30, -25), "拠点に被害", Color("ff977e"))


func ring(point: Vector2, color: Color, radius: float) -> void:
	rings.append({"position": point, "color": color, "radius": radius,
		"age": 0.0, "duration": 0.48})


func burst(point: Vector2, color: Color, count: int) -> void:
	var particles := CPUParticles2D.new()
	particles.position = point
	particles.emitting = false
	particles.amount = count
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180
	particles.initial_velocity_min = 35
	particles.initial_velocity_max = 100
	particles.gravity = Vector2(0, 50)
	particles.scale_amount_min = 2
	particles.scale_amount_max = 5
	particles.color = color
	particles.z_index = 8
	add_child(particles)
	particles.finished.connect(particles.queue_free)
	particles.emitting = true


func popup(point: Vector2, text: String, color: Color) -> void:
	var node := Label.new()
	node.text = text
	node.position = point + Vector2(-22, -45)
	node.add_theme_font_override("font", load("res://assets/fonts/ZenKurenaido-Regular.ttf"))
	node.add_theme_font_size_override("font_size", 20)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_outline_color", Ui.INK)
	node.add_theme_constant_override("outline_size", 5)
	node.z_index = 10
	add_child(node)
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "position:y", node.position.y - 32, 0.65)
	tween.parallel().tween_property(node, "modulate:a", 0.0, 0.65).set_delay(0.15)
	tween.tween_callback(node.queue_free)


func _draw() -> void:
	if gallery or run == null:
		return
	_draw_tapestry_frame()
	if run.phase == "title":
		return
	_draw_path()
	for index: int in range(Catalog.SITES.size()):
		_draw_site_marker(index)
		var point: Vector2 = Catalog.SITES[index]
		if index == selected_site:
			var tower: Dictionary = run.tower_at(index)
			var stats: Dictionary = Catalog.tower_stats(selected_kind, 1)
			if not tower.is_empty():
				stats = Catalog.tower_stats(tower.kind, tower.level)
			draw_circle(point, stats.range, Color(stats.color, 0.055))
			draw_arc(point, stats.range, 0, TAU, 80, Color(stats.color, 0.38), 1.5, true)
			draw_arc(point, 37 + sin(clock * 4) * 2, 0, TAU, 50, Ui.GOLD, 3, true)
		var tower: Dictionary = run.tower_at(index)
		if not tower.is_empty():
			for level: int in range(int(tower.level)):
				draw_circle(point + Vector2(-8 + level * 8, 22), 2.8, Ui.GOLD)
	_draw_base_emblem()
	for enemy: Dictionary in run.enemies:
		var point: Vector2 = enemy.position + Vector2(-22, -52)
		draw_style_box(Ui.box(Color("112d33"), Color("224441")), Rect2(point, Vector2(44, 7)))
		draw_rect(Rect2(point + Vector2(1, 1), Vector2(42 * enemy.hp / enemy.max_hp, 5)),
			Color("91d9c3") if enemy.slow < 1.0 else Color("f3ad90"))
	_draw_effects()


## 1枚の布の外周と、左の夜から右の夜明けへ続く章の結び目を描く。
func _draw_tapestry_frame() -> void:
	draw_rect(Rect2(8, 8, 944, 704), Ui.THREAD_BROWN, false, 5)
	draw_rect(Rect2(15, 15, 930, 690), Ui.GOLD, false, 2)
	for x: int in range(22, 944, 18):
		draw_line(Vector2(x, 10), Vector2(x + 8, 17), Ui.THREAD_RED, 2)
		draw_line(Vector2(x, 710), Vector2(x + 8, 703), Ui.THREAD_BLUE, 2)
	for y: int in range(24, 700, 18):
		draw_line(Vector2(10, y), Vector2(17, y + 8), Ui.THREAD_OLIVE, 2)
		draw_line(Vector2(950, y), Vector2(943, y + 8), Ui.THREAD_RED, 2)
	for chapter_x: float in [318.0, 638.0]:
		draw_circle(Vector2(chapter_x, 20), 7, Ui.PAPER)
		draw_arc(Vector2(chapter_x, 20), 7, 0, TAU, 12, Ui.THREAD_BROWN, 2)
		draw_line(
			Vector2(chapter_x - 5, 15), Vector2(chapter_x + 5, 25), Ui.THREAD_RED, 2
		)
		draw_line(
			Vector2(chapter_x + 5, 15), Vector2(chapter_x - 5, 25), Ui.THREAD_BLUE, 2
		)


## 空き・資金不足・占有を色だけでなく、＋・斜線・四角の刺繍記号でも区別する。
func _draw_site_marker(index: int) -> void:
	var point: Vector2 = Catalog.SITES[index]
	var tower: Dictionary = run.tower_at(index)
	var occupied := not tower.is_empty()
	var preview_kind: String = _effective_preview_kind()
	var cost: int = int(Catalog.TOWERS[preview_kind].cost)
	var can_afford: bool = run.gold >= cost
	var thread_color := Ui.THREAD_BROWN
	if not occupied:
		thread_color = Ui.THREAD_OLIVE if can_afford else Ui.THREAD_RED
	var diamond := PackedVector2Array([
		point + Vector2(0, -27),
		point + Vector2(35, 0),
		point + Vector2(0, 27),
		point + Vector2(-35, 0),
		point + Vector2(0, -27),
	])
	draw_colored_polygon(diamond, Color(Ui.PAPER, 0.78))
	draw_polyline(diamond, thread_color, 3, true)
	if occupied:
		draw_rect(Rect2(point - Vector2(9, 8), Vector2(18, 16)), thread_color, false, 3)
		draw_line(point + Vector2(-7, 1), point + Vector2(7, 1), thread_color, 2)
	elif can_afford:
		draw_line(point + Vector2(-9, 0), point + Vector2(9, 0), thread_color, 4)
		draw_line(point + Vector2(0, -9), point + Vector2(0, 9), thread_color, 4)
	else:
		draw_circle(point, 9, thread_color, false, 3, true)
		draw_line(point + Vector2(-10, 10), point + Vector2(10, -10), thread_color, 4)
	if index == selected_site:
		var pulse: float = 4.0 + sin(clock * 4.0) * 2.0
		var selected_diamond := PackedVector2Array([
			point + Vector2(0, -34 - pulse),
			point + Vector2(42 + pulse, 0),
			point + Vector2(0, 34 + pulse),
			point + Vector2(-42 - pulse, 0),
			point + Vector2(0, -34 - pulse),
		])
		draw_polyline(selected_diamond, Ui.GOLD, 4, true)


func _draw_base_emblem() -> void:
	var point := Vector2(925, 500)
	var shield := PackedVector2Array([
		point + Vector2(-24, -37),
		point + Vector2(24, -37),
		point + Vector2(25, 5),
		point + Vector2(0, 35),
		point + Vector2(-25, 5),
		point + Vector2(-24, -37),
	])
	draw_colored_polygon(shield, Color(Ui.THREAD_BLUE, 0.86))
	draw_polyline(shield, Ui.GOLD, 4, true)
	draw_line(point + Vector2(0, 21), point + Vector2(0, -18), Ui.PAPER, 4)
	draw_circle(point + Vector2(0, -21), 7 + sin(clock * 3.0), Ui.GOLD)


func _draw_path() -> void:
	for layer: Array in [[38.0, Ui.THREAD_BROWN], [33.0, Ui.GOLD],
		[27.0, Ui.PAPER], [21.0, Ui.PARCHMENT_DARK]]:
		draw_polyline(PackedVector2Array(Catalog.PATH), layer[1], layer[0], true)
		for point: Vector2 in Catalog.PATH:
			draw_circle(point, layer[0] / 2.0, layer[1])
	for index: int in range(12, int(Catalog.path_length()), 28):
		var point: Vector2 = Catalog.path_position(index)
		draw_line(point + Vector2(-4, 8), point + Vector2(4, 6), Ui.THREAD_BROWN, 2)
	for distance: int in range(70, int(Catalog.path_length()), 270):
		var point: Vector2 = Catalog.path_position(distance)
		var direction: Vector2 = (Catalog.path_position(distance + 8) - point).normalized()
		var side: Vector2 = direction.orthogonal() * 5
		draw_polyline(PackedVector2Array([point - direction * 5 + side,
			point + direction * 3, point - direction * 5 - side]), Ui.THREAD_RED, 2, true)


func _draw_effects() -> void:
	for shot: Dictionary in shots:
		var progress: float = shot.age / shot.duration
		var color: Color = Catalog.TOWERS[shot.kind].color
		if shot.kind == "sun":
			draw_line(shot.from, shot.to, Color(color, 0.2 * (1 - progress)), 16, true)
			draw_line(shot.from, shot.to, Color(color, 1 - progress), 4, true)
		else:
			# ダメージは即時解決されるため、発射から命中までを同フレームに描き、
			# 残光だけを減衰させる。移動中の弾より先に敵が死ぬ食い違いを作らない。
			var points: PackedVector2Array = PackedVector2Array([shot.from, shot.to])
			if shot.kind == "mortar":
				points.clear()
				for segment: int in range(17):
					var fraction: float = segment / 16.0
					points.append(shot.from.lerp(shot.to, fraction)
						+ Vector2(0, -sin(fraction * PI) * 50))
			draw_polyline(points, Color(color, (1 - progress) * 0.55), 4, true)
			draw_circle(shot.to, 4 + progress * 4, Color(color, 1 - progress))
	for effect: Dictionary in rings:
		var progress: float = effect.age / effect.duration
		draw_arc(effect.position, maxf(1, effect.radius * progress), 0, TAU, 50,
			Color(effect.color, (1 - progress) * 0.8), 3, true)
