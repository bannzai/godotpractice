class_name FighterCommand
extends RefCounted
## 方向履歴は実入力の時間順を記録するため、push/consume は非冪等。

const WINDOW: float = 0.65
var history: Array[Vector2] = []
var clock: float = 0.0
var previous: int = 5


func reset() -> void:
	history.clear()
	clock = 0.0
	previous = 5


func push(direction: Vector2, facing: float, delta: float) -> void:
	clock += delta
	var code: int = 5 + int(signf(direction.x * facing)) - 3 * int(signf(direction.y))
	if code != previous:
		history.append(Vector2(code, clock))
		previous = code
	while not history.is_empty() and clock - history[0].y > WINDOW:
		history.pop_front()


func consume() -> bool:
	var progress: int = 0
	for entry: Vector2 in history:
		var code: int = int(entry.x)
		if (progress == 0 and code == 2) or (progress == 1 and code == 3):
			progress += 1
		elif progress == 2 and code == 6:
			history.clear()
			return true
		elif code not in [2, 3, 5, 6]:
			progress = 0
	return false
