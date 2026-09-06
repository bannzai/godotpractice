extends SceneTree
## 26 秒の農作業を実入力で記録する。開始直後の初期条件以外は状態を直接書き換えない。

const TOTAL_FRAMES: int = 780

var main: Control
var farm: Node
var failed: bool = false
var saw_play: bool = false
var saw_result: bool = false
var saw_title_again: bool = false
var saw_hoe: bool = false
var saw_plant: bool = false
var saw_water: bool = false
var saw_harvest: bool = false
var saw_ship: bool = false


func _initialize() -> void:
	_run.call_deferred()


## 固定時刻の入力で一回の農場生活を進めるため非冪等。
func _run() -> void:
	farm = root.get_node("Farm")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for frame: int in TOTAL_FRAMES:
		if frame == 54:
			_prepare()
		_inputs(frame)
		_observe()
		if frame == TOTAL_FRAMES - 12:
			main.stop_audio()
		await process_frame
	_check(saw_play, "タイトルから農場へ進んだ")
	_check(saw_hoe and saw_plant and saw_water, "同じ畑を耕し、種まきと水やりを行った")
	_check(saw_harvest and saw_ship, "歩いて隣の畑を収穫し、出荷箱へ作物を運んだ")
	_check(saw_result, "家で眠り、出荷の精算で目標を達成した")
	_check(saw_title_again and main.mode == "title", "結果画面からタイトルへ戻った")
	if not failed:
		print("プレイ録画 OK: 農作業 → 収穫 → 出荷 → 就寝 → 目標達成 → タイトル / 780フレーム")
	quit(1 if failed else 0)


## 録画の開始条件を固定する。以降の農場状態は実入力だけで変化させる。
func _prepare() -> void:
	_check(main.mode == "playing", "決定入力で農場を開始できる")
	farm.day = 10
	farm.money = 840
	farm.tiles[1].merge({"tilled": true, "crop": "turnip", "growth": 2}, true)
	main.refresh()
	print("録画の初期条件: 春10日・840G・隣の畑に収穫できるかぶ1個。セーブは不使用。")


## 押下・解放は記録中の一度の操作なので非冪等。
func _inputs(frame: int) -> void:
	for at: int in [45, 560, 650]:
		_tap(frame, at, KEY_ENTER)
	for at: int in [75, 120, 165, 230]:
		_tap(frame, at, KEY_SPACE)
	_tap(frame, 105, KEY_3)
	_tap(frame, 150, KEY_2)
	_tap(frame, 215, KEY_4)
	_tap(frame, 365, KEY_F)
	_tap(frame, 540, KEY_F)
	_hold(frame, 190, 200, KEY_RIGHT)
	_hold(frame, 202, 204, KEY_DOWN)
	_hold(frame, 270, 328, KEY_RIGHT)
	_hold(frame, 330, 350, KEY_DOWN)
	_hold(frame, 390, 496, KEY_LEFT)
	_hold(frame, 500, 509, KEY_UP)


func _observe() -> void:
	saw_play = saw_play or main.mode == "playing"
	saw_result = saw_result or (main.mode == "result" and farm.phase == "win")
	saw_title_again = saw_title_again or (saw_result and main.mode == "title")
	saw_hoe = saw_hoe or farm.tiles[0].tilled
	saw_plant = saw_plant or farm.tiles[0].crop == "turnip"
	saw_water = saw_water or farm.tiles[0].watered
	saw_harvest = saw_harvest or farm.harvested.turnip > 0
	saw_ship = saw_ship or farm.shipping.turnip > 0


## 入力列の押下と解放の時点にだけイベントを送るため非冪等。
func _tap(frame: int, at: int, code: Key) -> void:
	_hold(frame, at, at + 1, code)


## 入力列の押下と解放の時点にだけイベントを送るため非冪等。
func _hold(frame: int, start: int, finish: int, code: Key) -> void:
	if frame == start:
		_key(code, true)
	elif frame == finish:
		_key(code, false)


## 実入力イベントは一回の操作を表すため非冪等。
func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("プレイ録画: " + message)
