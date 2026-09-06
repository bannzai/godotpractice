extends Node
## 画面をまたぐ進行状態と、端末に残す最高得点の保存先。

enum Mode {TITLE, PLAYING, RESULT}

const MAX_SCORE: int = 999999999
const MAX_POWER: int = 3
const MAX_BOMBS: int = 5

var mode: Mode = Mode.TITLE
var score: int = 0
var high_score: int = 0
var lives: int = 3
var bombs: int = 3
var power: int = 1
var cleared: bool = false
var elapsed: float = 0.0
var save_path: String = "user://shooter-save.json"


func _ready() -> void:
	load_high_score()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_high_score()


func reset_run() -> void:
	score = 0
	lives = 3
	bombs = 3
	power = 1
	cleared = false
	elapsed = 0.0
	mode = Mode.PLAYING


func show_title() -> void:
	if mode == Mode.PLAYING:
		save_high_score()
	mode = Mode.TITLE


func finish_run(won: bool) -> void:
	if mode != Mode.PLAYING:
		return
	cleared = won
	mode = Mode.RESULT
	save_high_score()


# 撃破・回収イベントごとの加算なので、呼び出すたびに得点が変化する。
func add_score(amount: int) -> void:
	if mode != Mode.PLAYING or amount <= 0:
		return
	score = mini(score + mini(amount, MAX_SCORE), MAX_SCORE)
	high_score = maxi(high_score, score)


# 無敵時間と同一衝突の重複除外はワールド側で管理し、確定した被弾だけを受け取る。
func take_hit() -> bool:
	if mode != Mode.PLAYING:
		return false
	lives = maxi(lives - 1, 0)
	power = 1
	if lives == 0:
		finish_run(false)
	return true


# 回収済みアイテムの除去はワールド側が担い、ここでは回収1回分を反映する。
func collect_item(kind: String) -> void:
	if mode != Mode.PLAYING:
		return
	match kind:
		"power":
			power = mini(power + 1, MAX_POWER)
			add_score(100)
		"bomb":
			bombs = mini(bombs + 1, MAX_BOMBS)
			add_score(100)
		"score":
			add_score(500)


# 発動イベント1回につき残数を消費するため、この操作は冪等ではない。
func use_bomb() -> bool:
	if mode != Mode.PLAYING or bombs <= 0:
		return false
	bombs -= 1
	return true


func load_high_score() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return
	var saved: Variant = json.data.get("high_score")
	if not (saved is int or saved is float):
		return
	var number: float = float(saved)
	if not is_finite(number) or number < 0 or number > MAX_SCORE or floor(number) != number:
		return
	high_score = maxi(high_score, int(number))


func save_high_score() -> bool:
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"high_score": high_score}))
	file.flush()
	return file.get_error() == OK
