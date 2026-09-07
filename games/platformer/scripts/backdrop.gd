class_name RouteBackdrop
extends Node2D
## メインシーンとは別の CanvasLayer 上で、生成した舞台絵をカメラ位置に合わせて緩やかに動かす。
## 背景の見せ場を保つため移動量を過剰にせず、前景の地形が読める濃度だけを重ねる。

const VIEW_SIZE: Vector2 = Vector2(1280, 720)
const INK: Color = Color("0e2934")
const BACKGROUNDS: Array[Texture2D] = [
	preload("res://assets/images/generated/meadow_background.png"),
	preload("res://assets/images/generated/cave_background.png"),
]
const BACKGROUND_RECTS: Array[Rect2] = [
	Rect2(-48, -54, 1472, 828),
	Rect2(-60, -60, 1504, 846),
]

var stage: int = 0
var camera_x: float = 0.0
var age: float = 0.0


func _process(delta: float) -> void:
	# 浮遊する紙片と洞窟の灯りは時間経過を消費するため非冪等。
	age += delta
	queue_redraw()


func _draw() -> void:
	var selected_stage: int = clampi(stage, 0, BACKGROUNDS.size() - 1)
	var background_rect: Rect2 = BACKGROUND_RECTS[selected_stage]
	# 1ステージ分を走っても余白が露出しない範囲で、舞台絵をカメラより遅く動かす。
	var available_shift: float = background_rect.size.x - VIEW_SIZE.x + background_rect.position.x
	var parallax_shift: float = clampf((camera_x - 640.0) * 0.018, 0.0, available_shift)
	background_rect.position.x -= parallax_shift
	draw_texture_rect(BACKGROUNDS[selected_stage], background_rect, false)
	_draw_foreground_fade(selected_stage)
	if selected_stage == 0:
		_draw_meadow_overlay(parallax_shift)
	else:
		_draw_cave_overlay(parallax_shift)
	_draw_ink_frame()


func _draw_foreground_fade(selected_stage: int) -> void:
	# 生成背景の橋や島と実際に衝突できるタイルを混同しないよう、足元だけを段階的に締める。
	var fade_color: Color = Color("123947") if selected_stage == 0 else Color("07162e")
	for band: int in 6:
		var alpha: float = 0.015 + float(band * band) * 0.006
		var band_color: Color = Color(fade_color, alpha)
		draw_rect(Rect2(0, 468 + band * 42, VIEW_SIZE.x, 43), band_color)


func _draw_meadow_overlay(parallax_shift: float) -> void:
	var paper: Color = Color("fff1b3", 0.28)
	for index: int in 9:
		var x: float = fposmod(index * 211.0 - parallax_shift * 1.8 + age * 17.0, 1440.0) - 80.0
		var y: float = 102.0 + float(index % 4) * 67.0
		draw_line(Vector2(x, y), Vector2(x + 54, y - 11), paper, 3.0, true)
	# 画面端の網点は中央のプレイ領域を濁らせず、アメコミの印刷面だけを足す。
	for row: int in 8:
		for column: int in 11:
			var dot: Vector2 = Vector2(14 + column * 18, 490 + row * 24)
			draw_circle(dot, 1.6 + float((row + column) % 2), Color(INK, 0.16))
			draw_circle(Vector2(VIEW_SIZE.x - dot.x, dot.y), 1.6, Color(INK, 0.11))


func _draw_cave_overlay(parallax_shift: float) -> void:
	var glow: Color = Color("72f4f1", 0.22)
	for index: int in 12:
		var x: float = fposmod(index * 149.0 - parallax_shift * 2.2 + age * 9.0, 1360.0) - 40.0
		var y: float = 140.0 + fposmod(index * 83.0, 420.0)
		draw_circle(Vector2(x, y), 2.0 + float(index % 3), glow)
		draw_line(Vector2(x, y + 6), Vector2(x, y + 24 + index % 4 * 5),
			Color("72f4f1", 0.10), 2.0)
	for row: int in 10:
		for column: int in 7:
			var dot: Vector2 = Vector2(1120 + column * 22, 34 + row * 22)
			draw_circle(dot, 2.0 if (row + column) % 2 == 0 else 1.0,
				Color("75dfe4", 0.14))


func _draw_ink_frame() -> void:
	draw_line(Vector2(0, 2), Vector2(VIEW_SIZE.x, 2), Color(INK, 0.68), 4.0)
	draw_line(Vector2(2, 0), Vector2(2, VIEW_SIZE.y), Color(INK, 0.52), 4.0)
	draw_line(Vector2(VIEW_SIZE.x - 2, 0), Vector2(VIEW_SIZE.x - 2, VIEW_SIZE.y),
		Color(INK, 0.52), 4.0)
