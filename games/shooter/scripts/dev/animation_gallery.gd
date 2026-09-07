extends Node2D
## 同じ Line2D 機体の連続フレームを固定し、機体別に比較する撮影用画面。

const Ship = preload("res://scripts/ship_sprite.gd")
const LABELS: Array[String] = ["待機", "移動", "攻撃", "被弾", "撃破"]
const NAMES: Dictionary = {
	"player": "防衛機・蒼翼", "scout": "直進機・朱針", "aim": "狙撃機・金嘴", "fan": "編隊機・紫盾", "boss": "旗艦・黒冠"
}
var kind: String = "player"
var font: Font


func _ready() -> void:
	font = load("res://assets/ui/flight_theme.tres").default_font
	for row: int in range(5):
		for column: int in range(3):
			var sprite: Node2D = Ship.new()
			add_child(sprite)
			sprite.setup(kind)
			sprite.set_pose(Ship.POSES[row])
			sprite.pause()
			sprite.set_frame_and_progress([0, 1, 3][column], 0.0)
			sprite.position = Vector2(409 + column * 315, 164 + row * 117)
			sprite.scale = Vector2.ONE * (0.66 if kind == "boss" else 0.85)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("01070b"))
	for y: int in range(0, 720, 8):
		draw_line(Vector2(0, y), Vector2(1280, y), Color(0.1, 0.8, 0.7, 0.05))
	draw_string(font, Vector2(38, 49), NAMES[kind] + "  /  動作フレーム", 0, -1, 27, Color("d9fff8"))
	for column: int in range(3):
		draw_string(
			font,
			Vector2(377 + column * 315, 94),
			["開始", "途中", "終了"][column],
			0,
			-1,
			18,
			Color("79f5d4")
		)
	for row: int in range(5):
		draw_arc(Vector2(640, 164 + row * 117), 544, PI, TAU, 64, Color(0.2, 1, 0.9, 0.08), 2)
		draw_string(font, Vector2(63, 170 + row * 117), LABELS[row], 0, -1, 22, Color("a0b3c7"))
