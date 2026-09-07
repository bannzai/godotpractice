extends Node2D
## 地形・範囲・ユニットの表示。座標とHPの正はCampaignにある。

const UI := preload("res://scripts/ui.gd")
const TILE: int = 44
const ORIGIN := Vector2(66, 117)
const TERRAIN: Dictionary = {
	".": "plain", "F": "forest", "M": "mountain", "W": "water", "T": "fort"
}
var campaign: Node
var cursor := Vector2i(2, 5)
var reachable: Array[Vector2i] = []
var threats: Array[Vector2i] = []
var selected: String = ""
var actors: Dictionary = {}
var terrain_images: Dictionary = {}
var actor_script: Script
var landscape: Texture2D


func _ready() -> void:
	campaign = get_node("/root/Campaign")
	if ResourceLoader.exists("res://assets/generated/yamato-landscape.png"):
		landscape = load("res://assets/generated/yamato-landscape.png")
	for code: String in TERRAIN:
		var path: String = "res://assets/terrain/%s.svg" % TERRAIN[code]
		if ResourceLoader.exists(path):
			terrain_images[code] = load(path)
	if ResourceLoader.exists("res://scripts/unit_actor.gd"):
		actor_script = load("res://scripts/unit_actor.gd")


static func center(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2(cell) * TILE + Vector2.ONE * TILE * 0.5


static func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori((point.x - ORIGIN.x) / TILE), floori((point.y - ORIGIN.y) / TILE))


static func art_kind(unit: Dictionary) -> String:
	if unit.team == "player":
		return unit.job
	if unit.boss:
		return "boss"
	if unit.job in ["sword", "lance"]:
		return "enemy_" + str(unit.job)
	return "archer" if unit.job == "bow" else "raider"


func sync() -> void:
	var living_ids: Array[String] = []
	for unit: Dictionary in campaign.units:
		if unit.hp <= 0:
			continue
		living_ids.append(unit.id)
		if not actors.has(unit.id):
			var actor: Node2D = actor_script.new() if actor_script != null else Node2D.new()
			add_child(actor)
			if actor.has_method("configure"):
				actor.configure(art_kind(unit), unit.team == "enemy")
			actor.scale = Vector2.ONE * 0.22
			actors[unit.id] = actor
		var node: Node2D = actors[unit.id]
		node.position = center(Vector2i(unit.x, unit.y)) + Vector2(0, -4)
		node.modulate = Color("889b9d") if unit.acted else Color.WHITE
		if node.has_method("play_pose"):
			node.play_pose("select" if unit.id == selected else "idle")
	for id: String in actors.keys():
		if id not in living_ids:
			actors[id].queue_free()
			actors.erase(id)
	queue_redraw()


func _draw() -> void:
	if campaign == null or campaign.units.is_empty():
		return
	var rows: Array = campaign.stage().map
	var board_rect := Rect2(ORIGIN, Vector2(16, 12) * TILE)
	draw_rect(board_rect.grow(8), Color("3b2417"))
	if landscape != null:
		draw_texture_rect(landscape, board_rect, false, Color(0.92, 0.88, 0.72, 1.0))
	for y: int in rows.size():
		for x: int in String(rows[y]).length():
			var cell := Vector2i(x, y)
			var rect := Rect2(ORIGIN + Vector2(cell) * TILE, Vector2.ONE * TILE)
			var code: String = String(rows[y])[x]
			var terrain_tint: Dictionary = {
				".": Color(0.78, 0.70, 0.46, 0.48),
				"F": Color(0.18, 0.32, 0.20, 0.58),
				"M": Color(0.48, 0.36, 0.22, 0.57),
				"W": Color(0.12, 0.28, 0.42, 0.65),
				"T": Color(0.55, 0.28, 0.19, 0.56),
			}
			draw_rect(rect, terrain_tint[code])
			if terrain_images.has(code):
				draw_texture_rect(terrain_images[code], rect, false, Color(1, 0.93, 0.7, 0.72))
			draw_rect(rect, Color(0.16, 0.10, 0.06, 0.42), false, 1)
			if cell in threats:
				draw_rect(rect.grow(-2), Color(0.75, 0.12, 0.08, 0.36))
			if cell in reachable:
				draw_rect(rect.grow(-2), Color(0.91, 0.72, 0.26, 0.26))
				draw_rect(rect.grow(-3), Color(0.96, 0.82, 0.42, 0.78), false, 2)
	for fold: int in range(1, 4):
		var fold_x: float = board_rect.position.x + board_rect.size.x * fold / 4.0
		draw_line(
			Vector2(fold_x, board_rect.position.y),
			Vector2(fold_x, board_rect.end.y),
			Color(0.14, 0.09, 0.05, 0.35),
			3
		)
	var goal: Vector2i = campaign.stage().goal
	if campaign.stage().objective == "reach":
		draw_circle(center(goal), 19, Color(0.95, 0.72, 0.18, 0.56))
		draw_arc(center(goal), 20, 0, TAU, 30, UI.GOLD, 3)
	for unit: Dictionary in campaign.units:
		if unit.hp <= 0:
			continue
		var at: Vector2 = center(Vector2i(unit.x, unit.y))
		var tint: Color = UI.JADE if unit.team == "player" else UI.CORAL
		if unit.team == "player" and not unit.acted and selected.is_empty():
			draw_circle(at + Vector2(0, 7), 22, Color(0.95, 0.74, 0.20, 0.22))
			draw_arc(at + Vector2(0, 7), 22, 0, TAU, 30, UI.GOLD, 3)
		draw_circle(at + Vector2(0, 7), 17, Color(0.04, 0.1, 0.12, 0.7))
		draw_arc(at + Vector2(0, 7), 17, 0, TAU, 30, tint, 2)
		draw_rect(Rect2(at + Vector2(-17, 17), Vector2(34, 4)), UI.INK)
		draw_rect(Rect2(at + Vector2(-17, 17), Vector2(34.0 * unit.hp / unit.max_hp, 4)), tint)
		if actor_script == null:
			draw_circle(at, 12, tint)
	var cursor_rect := Rect2(ORIGIN + Vector2(cursor) * TILE, Vector2.ONE * TILE)
	draw_rect(cursor_rect.grow(-1), UI.GOLD, false, 4)
	if not selected.is_empty():
		var actor: Dictionary = campaign.unit_by_id(selected)
		if not actor.is_empty():
			draw_dashed_line(
				center(Vector2i(actor.x, actor.y)), center(cursor), UI.INK, 2.0, 7.0, true
			)


func set_selection(id: String, cell: Vector2i) -> void:
	selected = id
	cursor = cell
	reachable.clear()
	threats.clear()
	for unit: Dictionary in campaign.units:
		if unit.id == selected and unit.hp > 0:
			reachable.assign(campaign.movement(unit))
			threats.assign(campaign.attack_range(unit))
	sync()
