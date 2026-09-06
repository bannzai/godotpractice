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


func _ready() -> void:
	campaign = get_node("/root/Campaign")
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
	draw_rect(Rect2(ORIGIN - Vector2(7, 7), Vector2(718, 542)), UI.GOLD)
	for y: int in rows.size():
		for x: int in String(rows[y]).length():
			var cell := Vector2i(x, y)
			var rect := Rect2(ORIGIN + Vector2(cell) * TILE, Vector2.ONE * TILE)
			var code: String = String(rows[y])[x]
			draw_rect(rect, Color("64806b") if (x + y) % 2 == 0 else Color("597563"))
			if terrain_images.has(code):
				draw_texture_rect(terrain_images[code], rect, false)
			draw_rect(rect, Color(0.05, 0.15, 0.17, 0.25), false, 1)
			if cell in threats:
				draw_rect(rect.grow(-2), Color(0.95, 0.34, 0.30, 0.32))
			if cell in reachable:
				draw_rect(rect.grow(-2), Color(0.2, 0.85, 0.9, 0.28))
				draw_rect(rect.grow(-2), Color(0.5, 0.94, 0.9, 0.48), false, 1)
	var goal: Vector2i = campaign.stage().goal
	if campaign.stage().objective == "reach":
		draw_circle(center(goal), 17, Color(1, 0.85, 0.35, 0.5))
	for unit: Dictionary in campaign.units:
		if unit.hp <= 0:
			continue
		var at: Vector2 = center(Vector2i(unit.x, unit.y))
		var tint: Color = UI.JADE if unit.team == "player" else UI.CORAL
		draw_circle(at + Vector2(0, 7), 17, Color(0.04, 0.1, 0.12, 0.7))
		draw_arc(at + Vector2(0, 7), 17, 0, TAU, 30, tint, 2)
		draw_rect(Rect2(at + Vector2(-17, 17), Vector2(34, 4)), UI.INK)
		draw_rect(Rect2(at + Vector2(-17, 17), Vector2(34.0 * unit.hp / unit.max_hp, 4)), tint)
		if actor_script == null:
			draw_circle(at, 12, tint)
	var cursor_rect := Rect2(ORIGIN + Vector2(cursor) * TILE, Vector2.ONE * TILE)
	draw_rect(cursor_rect.grow(-1), UI.PAPER, false, 3)


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
