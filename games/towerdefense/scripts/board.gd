extends Node2D
## 経路・射程とキャラの表示。描画位置以外の戦闘状態はRunを参照する。

const Catalog := preload("res://scripts/catalog.gd")
const Actor := preload("res://scripts/actor.gd")
const Ui := preload("res://scripts/ui.gd")

var run: Node
var selected_site: int = 0
var selected_kind: String = "arrow"
var enemy_nodes: Dictionary = {}
var tower_nodes: Dictionary = {}
var clock: float = 0.0
var shots: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var foreground: Sprite2D
var backdrop: Sprite2D
var base_texture: Texture2D
var site_texture: Texture2D
var shake: float = 0.0
var gallery: bool = false
var lantern: PointLight2D


func _ready() -> void:
	run = get_node("/root/Run")
	backdrop = Sprite2D.new()
	backdrop.texture = load("res://assets/background.svg")
	backdrop.centered = false
	backdrop.z_index = -10
	add_child(backdrop)
	foreground = Sprite2D.new()
	foreground.texture = load("res://assets/foreground.svg")
	foreground.centered = false
	foreground.z_index = 5
	foreground.modulate.a = 0.65
	add_child(foreground)
	base_texture = load("res://assets/base.svg")
	site_texture = load("res://assets/ui/site.svg")
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
	backdrop.position.x = sin(clock * 0.13) * 4 - 4
	foreground.position.x = sin(clock * 0.22) * 9 - 9
	shake = maxf(0.0, shake - delta * 18)
	position = Vector2(sin(clock * 95), cos(clock * 83)) * shake
	for group: Array[Dictionary] in [shots, rings]:
		for index: int in range(group.size() - 1, -1, -1):
			group[index].age += delta
			if float(group[index].age) >= float(group[index].duration):
				group.remove_at(index)
	if not gallery:
		_sync_actors()
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
	node.add_theme_font_override("font", load("res://assets/fonts/font.ttf"))
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
	_draw_path()
	if run.phase == "title":
		return
	for index: int in range(Catalog.SITES.size()):
		var point: Vector2 = Catalog.SITES[index]
		draw_texture_rect(site_texture, Rect2(point - Vector2(40, 24), Vector2(80, 48)), false)
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
	draw_texture_rect(base_texture, Rect2(863, 390, 115, 144), false)
	for enemy: Dictionary in run.enemies:
		var point: Vector2 = enemy.position + Vector2(-22, -52)
		draw_style_box(Ui.box(Color("112d33"), Color("224441")), Rect2(point, Vector2(44, 7)))
		draw_rect(Rect2(point + Vector2(1, 1), Vector2(42 * enemy.hp / enemy.max_hp, 5)),
			Color("91d9c3") if enemy.slow < 1.0 else Color("f3ad90"))
	_draw_effects()


func _draw_path() -> void:
	for layer: Array in [[66.0, Color("30443e")], [58.0, Color("8c8363")],
		[49.0, Color("baa27b")], [40.0, Color("c6b28a")]]:
		draw_polyline(PackedVector2Array(Catalog.PATH), layer[1], layer[0], true)
		for point: Vector2 in Catalog.PATH:
			draw_circle(point, layer[0] / 2.0, layer[1])
	for index: int in range(12, int(Catalog.path_length()), 39):
		var point: Vector2 = Catalog.path_position(index)
		draw_line(point + Vector2(-4, 10), point + Vector2(4, 8), Color("b49b76"), 2)
	for distance: int in range(70, int(Catalog.path_length()), 270):
		var point: Vector2 = Catalog.path_position(distance)
		var direction: Vector2 = (Catalog.path_position(distance + 8) - point).normalized()
		var side: Vector2 = direction.orthogonal() * 5
		draw_polyline(PackedVector2Array([point - direction * 5 + side,
			point + direction * 3, point - direction * 5 - side]), Color("9a835f"), 2, true)


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
