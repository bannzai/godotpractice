extends Node
## 画面をまたぐ進行状態の唯一の保存先。

var screen: String = "title"
var score: int = 0
var elapsed: float = 0.0


func start() -> void:
	screen = "play"
	score = 0
	elapsed = 0.0
