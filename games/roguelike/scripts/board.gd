extends Node2D
## 地形・視界・探索済み地図を、同梱フォントのグリフだけで描画する。

const TILE: int = 30
const COLS: int = 29
const ROWS: int = 13
const GLYPH_SIZE: int = 24
const Data := preload("res://scripts/game_data.gd")
const UI := preload("res://scripts/ui.gd")

var run: Node
var origin: Vector2i = Vector2i.ZERO
var map_open: bool = false
var minimap: Node2D
var _font: Font
var _pulse: float = 0.0


func _ready() -> void:
	_font = load(UI.FONT_PATH)
	minimap = Node2D.new()
	minimap.z_index = 15
	add_child(minimap)
	minimap.draw.connect(_draw_minimap)
	run = get_node("/root/RunState")


## 発光する目標記号を呼吸させるため、描画時刻は非冪等。
func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta, TAU)
	queue_redraw()


func refresh() -> void:
	origin = run.player_pos - Vector2i(COLS / 2, ROWS / 2)
	queue_redraw()


func point(cell: Vector2i) -> Vector2:
	return Vector2(cell - origin) * TILE + Vector2.ONE * TILE * 0.5


func _draw() -> void:
	if not is_instance_valid(run) or run.dungeon == null:
		return
	draw_rect(Rect2(0, 0, COLS * TILE, ROWS * TILE), UI.INK)
	for y: int in range(ROWS):
		for x: int in range(COLS):
			var cell := origin + Vector2i(x, y)
			if not run.dungeon.explored.has(cell):
				continue
			var visible_cell: bool = run.dungeon.visible.has(cell)
			var color := UI.MUTED.darkened(0.42)
			if visible_cell:
				color = UI.MUTED.lightened(0.05)
			var glyph: String = "." if run.dungeon.is_floor(cell) else "#"
			if cell == run.dungeon.stairs:
				glyph = ">"
				color = UI.GOLD if visible_cell else UI.GOLD.darkened(0.55)
			_draw_glyph(Vector2(x * TILE, y * TILE), glyph, color, GLYPH_SIZE)
	for item: Dictionary in run.ground_items:
		if not run.dungeon.visible.has(item.pos):
			continue
		var item_data: Dictionary = Data.ITEMS.get(item.kind, {})
		var glyph: String = str(item_data.get("glyph", "?"))
		_draw_glyph(point(item.pos) - Vector2.ONE * TILE * 0.5, glyph, UI.TEAL, GLYPH_SIZE)
	var hero: Vector2 = point(run.player_pos)
	var alpha: float = 0.35 + (sin(_pulse * 2.0) + 1.0) * 0.18
	draw_rect(Rect2(hero - Vector2.ONE * 14.0, Vector2.ONE * 28.0), Color(UI.TEAL, alpha), false, 2.0)
	minimap.queue_redraw()


func _draw_glyph(top_left: Vector2, glyph: String, color: Color, size: int) -> void:
	var baseline := top_left + Vector2(4, float(size))
	draw_string(
		_font, baseline + Vector2(1, 1), glyph,
		HORIZONTAL_ALIGNMENT_CENTER, TILE - 4, size, Color(0, 0, 0, 0.9)
	)
	draw_string(
		_font, baseline, glyph, HORIZONTAL_ALIGNMENT_CENTER, TILE - 4, size, color
	)


func _draw_minimap() -> void:
	if map_open:
		_draw_large_map()
		return
	var base := Vector2(908, 285)
	minimap.draw_string(
		_font, base - Vector2(0, 18), "SCAN // 探索済み",
		HORIZONTAL_ALIGNMENT_LEFT, 320, 13, UI.MUTED
	)
	for cell: Vector2i in run.dungeon.explored:
		if not run.dungeon.is_floor(cell):
			continue
		var glyph := "."
		var color := UI.MUTED.darkened(0.2)
		if cell == run.dungeon.stairs:
			glyph = ">"
			color = UI.GOLD
		if cell == run.player_pos:
			glyph = "@"
			color = UI.TEAL
		minimap.draw_string(
			_font, base + Vector2(cell) * 2.7, glyph,
			HORIZONTAL_ALIGNMENT_LEFT, 5, 7, color
		)


func _draw_large_map() -> void:
	minimap.draw_rect(Rect2(18, 14, 834, 362), UI.INK)
	minimap.draw_string(
		_font, Vector2(42, 48),
		"┌─ 地下探索図 / EXPLORED CELLS ──────────────────────────┐",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UI.TEAL
	)
	var base := Vector2(112, 58)
	for cell: Vector2i in run.dungeon.explored:
		var glyph := "·" if run.dungeon.is_floor(cell) else "#"
		var color := UI.MUTED if run.dungeon.is_floor(cell) else UI.MUTED.darkened(0.25)
		if cell == run.dungeon.stairs:
			glyph = ">"
			color = UI.GOLD
		if cell == run.player_pos:
			glyph = "@"
			color = UI.TEAL
		minimap.draw_string(
			_font, base + Vector2(cell.x * 16, cell.y * 13), glyph,
			HORIZONTAL_ALIGNMENT_LEFT, 16, 16, color
		)
	minimap.draw_string(
		_font, Vector2(42, 356),
		"└─ @ 現在地   > 階段   · 探索済み   M / SELECT で閉じる ─────┘",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.MUTED
	)
