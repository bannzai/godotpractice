extends Control
## 12 層の経路を、現在の区画で近づける入口を持つ横長の通りとして描く。

const UI := preload("res://scripts/ui.gd")
const ENTRANCE_NAMES: Dictionary = {
	"battle": "ざわめく路地",
	"grave": "墓地裏門",
	"living": "息のある廃屋",
	"police": "赤灯の交番",
	"rest": "蝋燭の祠",
	"story": "声のする水路",
	"boss": "夜葬の正門",
}
const ENTRANCE_LINES: Dictionary = {
	"battle": "喧嘩の音ではない。霊同士が爪を研いでいる。",
	"grave": "土の下から名を呼ぶ声。荒らせば魂を連れ出せる。",
	"living": "戸の向こうに鼓動。強い霊と、消える命が待つ。",
	"police": "赤い灯が影を数えている。闇が濃いほど罰は重い。",
	"rest": "まだ人の手が守る灯。傷と闇を少し鎮められる。",
	"story": "水音に妹の声が混じる。選ぶ言葉で夜が変わる。",
	"boss": "十二番地の門。ここを潜れば夜は決着する。",
}

var run: Node
var active_branch: int = 0
var walker_x: float = 264.0
var target_x: float = 264.0
var elapsed: float = 0.0


func set_active_branch(branch: int, immediate: bool = false) -> void:
	if not is_instance_valid(run) or run.depth >= run.route.size():
		return
	active_branch = clampi(branch, 0, run.route[run.depth].size() - 1)
	target_x = 264.0 if active_branch == 0 else 1016.0
	if run.route[run.depth].size() == 1:
		target_x = 640.0
	if immediate:
		walker_x = target_x
	queue_redraw()


func active_line() -> String:
	if not is_instance_valid(run) or run.depth >= run.route.size():
		return ""
	var info: Dictionary = run.route[run.depth][active_branch]
	return ENTRANCE_LINES.get(str(info.get("kind", "story")), "何かがこちらを見ている。")


func entrance_name(branch: int) -> String:
	if not is_instance_valid(run) or run.depth >= run.route.size():
		return ""
	var info: Dictionary = run.route[run.depth][branch]
	return ENTRANCE_NAMES.get(str(info.get("kind", "story")), "名もない入口")


func _process(delta: float) -> void:
	elapsed += delta
	walker_x = lerpf(walker_x, target_x, 1.0 - exp(-delta * 7.0))
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(run) or run.depth >= run.route.size():
		return
	_draw_district_strip()
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0, 492), Vector2(1280, 451), Vector2(1280, 720), Vector2(0, 720)
		]),
		Color("030303e8")
	)
	for x: float in range(-80, 1380, 94):
		draw_line(Vector2(x, 607), Vector2(x + 260, 570), Color("ffd44722"), 2.0)
	var branches: Array = run.route[run.depth]
	for branch: int in range(branches.size()):
		_draw_entrance(branch, branches[branch])
	_draw_flashlight()
	_draw_walker()


func _draw_district_strip() -> void:
	for district: int in range(12):
		var width: float = 93.0
		var x: float = 61.0 + district * 97.0
		var past: bool = district < run.depth
		var current: bool = district == run.depth
		draw_rect(Rect2(x, 20, width, 25), UI.GOLD if current else Color("101010dd"), true)
		if past:
			draw_line(Vector2(x + 7, 39), Vector2(x + width - 7, 25), UI.RED, 4.0)
		draw_string(
			get_theme_default_font(),
			Vector2(x, 40),
			"%02d" % (district + 1),
			HORIZONTAL_ALIGNMENT_CENTER,
			width,
			16,
			Color.BLACK if current else UI.MUTED
		)


func _draw_entrance(branch: int, info: Dictionary) -> void:
	var count: int = run.route[run.depth].size()
	var center_x: float = 264.0 + branch * 752.0 if count > 1 else 640.0
	var kind: String = str(info.get("kind", "story"))
	var selected: bool = branch == active_branch
	var ink: Color = UI.GOLD if selected else Color("4b4b46")
	var glow: Color = Color("ffd44722") if selected else Color("00000000")
	draw_rect(Rect2(center_x - 194, 169, 388, 332), Color("000000c8"), true)
	draw_rect(Rect2(center_x - 185, 178, 370, 315), glow, true)
	draw_rect(Rect2(center_x - 194, 169, 388, 332), ink, false, 7.0)
	match kind:
		"grave":
			_draw_grave_gate(center_x, ink)
		"police":
			_draw_police_box(center_x, ink)
		"rest":
			_draw_shrine(center_x, ink)
		"living":
			_draw_living_house(center_x, ink)
		"story":
			_draw_waterway(center_x, ink)
		"battle":
			_draw_battle_alley(center_x, ink)
		"boss":
			_draw_boss_gate(center_x, ink)


func _draw_grave_gate(x: float, color: Color) -> void:
	draw_rect(Rect2(x - 128, 274, 22, 190), color, true)
	draw_rect(Rect2(x + 106, 274, 22, 190), color, true)
	draw_rect(Rect2(x - 153, 254, 306, 27), color, true)
	for offset: float in [-72.0, 0.0, 72.0]:
		draw_rect(Rect2(x + offset - 25, 372, 50, 91), Color("070707"), true)
		draw_line(Vector2(x + offset - 30, 372), Vector2(x + offset, 337), color, 7.0)
		draw_line(Vector2(x + offset, 337), Vector2(x + offset + 30, 372), color, 7.0)


func _draw_police_box(x: float, color: Color) -> void:
	draw_rect(Rect2(x - 129, 285, 258, 179), Color("070707"), true)
	draw_rect(Rect2(x - 129, 285, 258, 179), color, false, 8.0)
	draw_rect(Rect2(x - 31, 334, 62, 130), color, false, 6.0)
	draw_rect(Rect2(x - 92, 312, 55, 48), UI.RED, true)
	draw_rect(Rect2(x + 37, 312, 55, 48), UI.RED, true)
	draw_line(Vector2(x, 282), Vector2(x, 227), UI.RED, 7.0)
	draw_rect(Rect2(x - 28, 218, 56, 20), UI.RED, true)


func _draw_shrine(x: float, color: Color) -> void:
	draw_line(Vector2(x - 125, 462), Vector2(x - 89, 293), color, 13.0)
	draw_line(Vector2(x + 125, 462), Vector2(x + 89, 293), color, 13.0)
	draw_line(Vector2(x - 113, 316), Vector2(x + 113, 316), color, 15.0)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(x - 153, 300), Vector2(x, 224), Vector2(x + 153, 300)
		]),
		Color("050505")
	)
	draw_polyline(
		PackedVector2Array([
			Vector2(x - 153, 300), Vector2(x, 224), Vector2(x + 153, 300)
		]),
		color,
		10.0
	)
	draw_rect(Rect2(x - 13, 362, 26, 69), UI.GOLD, true)


func _draw_living_house(x: float, color: Color) -> void:
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(x - 158, 310), Vector2(x - 79, 238), Vector2(x + 158, 292),
			Vector2(x + 142, 466), Vector2(x - 145, 466)
		]),
		Color("050505")
	)
	draw_polyline(
		PackedVector2Array([
			Vector2(x - 158, 310), Vector2(x - 79, 238), Vector2(x + 158, 292)
		]),
		color,
		9.0
	)
	draw_rect(Rect2(x - 45, 325, 90, 141), color, false, 7.0)
	var beat: float = 8.0 + sin(elapsed * 4.0) * 4.0
	draw_circle(Vector2(x, 383), beat, UI.RED)


func _draw_waterway(x: float, color: Color) -> void:
	for line: int in range(5):
		var y: float = 337.0 + line * 25.0
		draw_line(
			Vector2(x - 151 + line * 8, y),
			Vector2(x + 151 - line * 10, y + 8),
			color,
			5.0
		)
	draw_line(Vector2(x - 165, 309), Vector2(x - 133, 466), Color.BLACK, 20.0)
	draw_line(Vector2(x + 165, 309), Vector2(x + 133, 466), Color.BLACK, 20.0)
	draw_string(
		get_theme_default_font(),
		Vector2(x - 90, 294),
		"……きこえる",
		HORIZONTAL_ALIGNMENT_CENTER,
		180,
		18,
		UI.GHOST
	)


func _draw_battle_alley(x: float, color: Color) -> void:
	for slash: int in range(4):
		draw_line(
			Vector2(x - 112 + slash * 57, 276),
			Vector2(x - 153 + slash * 57, 445),
			UI.RED if slash == 1 else color,
			11.0
		)
	draw_string(
		get_theme_default_font(),
		Vector2(x - 142, 405),
		"霊戦",
		HORIZONTAL_ALIGNMENT_CENTER,
		284,
		54,
		color
	)


func _draw_boss_gate(x: float, color: Color) -> void:
	draw_rect(Rect2(x - 151, 219, 28, 247), color, true)
	draw_rect(Rect2(x + 123, 219, 28, 247), color, true)
	draw_rect(Rect2(x - 179, 203, 358, 34), color, true)
	draw_rect(Rect2(x - 144, 267, 288, 199), Color("030303"), true)
	for eye_x: float in [-54.0, 54.0]:
		draw_circle(Vector2(x + eye_x, 340), 12.0, UI.RED)


func _draw_flashlight() -> void:
	var light_x: float = target_x
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(walker_x, 527),
			Vector2(light_x - 205, 153),
			Vector2(light_x + 205, 153),
			Vector2(walker_x + 35, 527),
		]),
		Color("ffd44719")
	)


func _draw_walker() -> void:
	var bob: float = sin(elapsed * 8.0) * minf(absf(target_x - walker_x) / 30.0, 4.0)
	draw_circle(Vector2(walker_x, 527 + bob), 19.0, Color("050505"))
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(walker_x - 28, 552 + bob),
			Vector2(walker_x + 28, 552 + bob),
			Vector2(walker_x + 42, 638),
			Vector2(walker_x - 42, 638),
		]),
		Color("050505")
	)
	draw_line(
		Vector2(walker_x + 19, 557 + bob), Vector2(walker_x + 53, 541), UI.GOLD, 8.0
	)
	draw_line(
		Vector2(walker_x - 19, 631), Vector2(walker_x - 29, 675), Color("050505"), 13.0
	)
	draw_line(
		Vector2(walker_x + 19, 631), Vector2(walker_x + 29, 675), Color("050505"), 13.0
	)


func point(level: int, branch: int, count: int) -> Vector2:
	# 呼び出し側との互換性のため、現在の街路描画では使わない階層も受け取る。
	if level < 0:
		return Vector2.ZERO
	return Vector2(264.0 + branch * 752.0 if count > 1 else 640.0, 342.0)
