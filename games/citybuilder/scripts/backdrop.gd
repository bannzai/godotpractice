extends Control
## タイトルと結果に、街の図面を多層の線で描く。

const UI = preload("res://scripts/ui.gd")
const CANVAS := Vector2(1280.0, 720.0)
const WHITE := Color("dff6ff")
const GRID := Color("4c92bf")
const CYAN := Color("64ddff")

var elapsed: float = 0.0
var parallax := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var paper := ShaderMaterial.new()
	paper.shader = UI.BLUEPRINT_SHADER
	material = paper


func _process(delta: float) -> void:
	# 時間と追従位置の積算は背景アニメーションのため非冪等。
	elapsed += delta
	var pointer := get_local_mouse_position() / CANVAS - Vector2(0.5, 0.5)
	pointer.x = clampf(pointer.x, -0.5, 0.5)
	pointer.y = clampf(pointer.y, -0.5, 0.5)
	parallax = parallax.lerp(pointer, 1.0 - exp(-delta * 2.5))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, CANVAS), UI.BLUE)
	_draw_grid()
	_draw_contours()
	_draw_city()
	_draw_dimensioning()


func _draw_grid() -> void:
	var drift := Vector2(fmod(elapsed * 1.2, 20.0), 0.0) + parallax * Vector2(2.0, 1.0)
	for x: int in range(-20, 1320, 20):
		var major: bool = posmod(x, 100) == 0
		draw_line(
			Vector2(x, 0) + drift,
			Vector2(x, 720) + drift,
			GRID if major else Color(GRID, 0.27),
			1.1 if major else 0.55
		)
	for y: int in range(0, 740, 20):
		var major: bool = y % 100 == 0
		draw_line(
			Vector2(0, y) + drift,
			Vector2(1280, y) + drift,
			GRID if major else Color(GRID, 0.27),
			1.1 if major else 0.55
		)


func _draw_contours() -> void:
	var offset := parallax * Vector2(7.0, 3.0)
	for ring: int in range(6):
		var points := PackedVector2Array()
		for index: int in range(41):
			var angle: float = TAU * index / 40.0
			var radius_x: float = 235.0 + ring * 25.0 + sin(angle * 3.0 + elapsed * 0.08) * 10.0
			var radius_y: float = 80.0 + ring * 15.0 + cos(angle * 2.0) * 8.0
			points.append(Vector2(970, 360) + Vector2(cos(angle) * radius_x, sin(angle) * radius_y) + offset)
		draw_polyline(points, Color(WHITE, 0.12 + ring * 0.015), 1.0, true)


func _draw_city() -> void:
	var offset := parallax * Vector2(16.0, 8.0)
	offset.y += sin(elapsed * 0.28) * 1.5
	var origin := Vector2(935, 452) + offset
	for row: int in range(5, -1, -1):
		for column: int in range(7):
			if (column + row * 2) % 5 == 0:
				continue
			var point := origin + Vector2((column - row) * 67, (column + row) * 31)
			var height: float = 34.0 + float((column * 17 + row * 11) % 4) * 17.0
			_draw_prism(point, Vector2(50, 24), height, (column + row) % 3)
	var road_color := Color(CYAN, 0.65)
	for index: int in range(7):
		var start := origin + Vector2(index * 67, index * 31)
		draw_line(start, start + Vector2(-335, 155), road_color, 8.0, true)
		draw_line(start, start + Vector2(-335, 155), Color(UI.INK, 0.85), 4.0, true)


func _draw_prism(point: Vector2, footprint: Vector2, height: float, variant: int) -> void:
	var top := PackedVector2Array(
		[
			point + Vector2(0, -height - footprint.y),
			point + Vector2(footprint.x, -height),
			point + Vector2(0, -height + footprint.y),
			point + Vector2(-footprint.x, -height),
		]
	)
	var left := PackedVector2Array(
		[top[3], top[2], point + Vector2(0, footprint.y), point + Vector2(-footprint.x, 0)]
	)
	var right := PackedVector2Array(
		[top[2], top[1], point + Vector2(footprint.x, 0), point + Vector2(0, footprint.y)]
	)
	draw_colored_polygon(left, Color("0a4274c8"))
	draw_colored_polygon(right, Color("083661d8"))
	draw_colored_polygon(top, Color("126aa0b8"))
	for face: PackedVector2Array in [top, left, right]:
		var closed := face.duplicate()
		closed.append(face[0])
		draw_polyline(closed, Color(WHITE, 0.82), 1.4, true)
	if variant == 0:
		draw_line(top[3], top[1], Color(CYAN, 0.75), 1.0)
	elif variant == 1:
		for floor_index: int in range(1, 3):
			var y: float = point.y - height + floor_index * height / 3.0
			draw_line(
				point + Vector2(-footprint.x, y - point.y),
				point + Vector2(0, y - point.y + footprint.y),
				Color(WHITE, 0.48),
				1.0
			)
	else:
		draw_circle(top[0].lerp(top[2], 0.5), 4.0, Color(UI.ORANGE, 0.85))


func _draw_dimensioning() -> void:
	var color := Color(WHITE, 0.62)
	draw_rect(Rect2(18, 18, 1244, 684), color, false, 1.5)
	draw_line(Vector2(632, 34), Vector2(1238, 34), color, 1.0)
	draw_line(Vector2(632, 29), Vector2(632, 39), color, 1.0)
	draw_line(Vector2(1238, 29), Vector2(1238, 39), color, 1.0)
	for x: int in range(652, 1239, 40):
		draw_line(Vector2(x, 31), Vector2(x, 37), Color(color, 0.55), 0.8)
	draw_arc(Vector2(1164, 124), 42.0, 0.2, TAU - 0.2, 48, Color(CYAN, 0.48), 1.2)
	draw_line(Vector2(1164, 68), Vector2(1164, 180), Color(CYAN, 0.45), 1.0)
	draw_line(Vector2(1108, 124), Vector2(1220, 124), Color(CYAN, 0.45), 1.0)
