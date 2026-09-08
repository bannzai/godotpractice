extends Node
## 冒険の進行を保持する。部屋を読み直しても取得物と討伐結果を保持する。

const ROOM_NAMES: Array[String] = ["風待ちの岸", "木霊の森", "灯火の祠", "封印の庭", "最後の灯台"]
const ROOM_MAP: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0), Vector2i(2, 1), Vector2i(2, 0)]
const CONNECTIONS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(3, 4)]
var room: int = 0
var health: int = 6
var key_found: bool = false
var shrine_open: bool = false
var ember: bool = false
var solved: bool = false
var braziers: Array[int] = []
var defeated: Array[String] = []
var won: bool = false
var visited: Array[int] = [0]

func reset() -> void:
	room = 0
	health = 6
	key_found = false
	shrine_open = false
	ember = false
	solved = false
	braziers.clear()
	defeated.clear()
	won = false
	visited = [0]

func destination(direction: Vector2i) -> int:
	var next: int = ROOM_MAP.find(ROOM_MAP[room] + direction)
	return next if connected(room, next) else -1

func connected(from: int, to: int) -> bool:
	return CONNECTIONS.has(Vector2i(mini(from, to), maxi(from, to)))

func objective() -> String:
	if won:
		return "森に、灯りが帰ってきた"
	if not key_found:
		return "東の森で、祠の鍵を探す"
	if not ember:
		return "森の北の祠で、灯火を手に入れる"
	if braziers.size() < 2:
		return "東の庭の、二つの燭台に火を灯す"
	return "庭の北へ。灯台の守護者を鎮める"
