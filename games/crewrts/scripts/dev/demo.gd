extends SceneTree
## 28 秒の実入力録画。待ち時間を縮めるため、この検証だけ日暮れを22秒後に設定する。
## 地図・チュートリアル・移動・照準・投擲・笛・解散・結果の決定は InputEvent だけで行う。

const FPS: int = 30
const DURATION: int = 28

var main: Node
var _sent: Dictionary = {}
var _failed: bool = false
var _delivered: bool = false
var _combat: bool = false
var _result: bool = false


func _initialize() -> void:
	_run.call_deferred()


## フレームに沿って操作を積算するため、同じツリー内では一度だけ実行する。
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for frame: int in range(DURATION * FPS):
		var seconds: float = float(frame) / FPS
		_operate(seconds)
		_delivered = _delivered or main.model.collected > 0
		for enemy: Dictionary in main.model.enemies:
			_combat = _combat or float(enemy.hp) < 22.0
		_result = _result or main.model.phase == "failed"
		if frame == DURATION * FPS - 8:
			main.stop_audio()
		await process_frame
	_check(_delivered, "実入力で結晶を回収")
	_check(_combat, "実入力で敵を攻撃")
	_check(_result, "短縮した一日の時間切れから結果に到達")
	_check(main.model.phase == "title", "結果のボタンからタイトルへ帰還")
	print("demo OK" if not _failed else "demo FAIL")
	quit(1 if _failed else 0)


## 指定時刻を初めて通過したフレームだけ操作する。
func _operate(seconds: float) -> void:
	if _at(seconds, 1.0):
		_key(KEY_ENTER, true)
	if _at(seconds, 1.1):
		_key(KEY_ENTER, false)
	if _at(seconds, 1.6):
		_key(KEY_ENTER, true)
	if _at(seconds, 1.7):
		_key(KEY_ENTER, false)
	if _at(seconds, 2.2):
		_key(KEY_ENTER, true)
	if _at(seconds, 2.3):
		_key(KEY_ENTER, false)
	if _at(seconds, 2.8):
		_key(KEY_ENTER, true)
	if _at(seconds, 2.9):
		_key(KEY_ENTER, false)
	if _at(seconds, 3.4):
		_key(KEY_ENTER, true)
	if _at(seconds, 3.5):
		_key(KEY_ENTER, false)
		main.model.remaining = 19.5
	if _at(seconds, 4.2):
		_key(KEY_TAB, true)
	if _at(seconds, 4.3):
		_key(KEY_TAB, false)
		_point(main.model.cargo[0].position)
		_key(KEY_SPACE, true)
	if _at(seconds, 4.85):
		_key(KEY_SPACE, false)
	if _at(seconds, 8.2):
		_key(KEY_A, true)
		_key(KEY_W, true)
	if _at(seconds, 9.8):
		_key(KEY_A, false)
	if _at(seconds, 10.4):
		_key(KEY_W, false)
		_key(KEY_TAB, true)
	if _at(seconds, 10.5):
		_key(KEY_TAB, false)
	if _at(seconds, 11.0):
		_point(main.model.enemies[0].position)
		_key(KEY_SPACE, true)
	if _at(seconds, 12.5):
		_key(KEY_SPACE, false)
	if _at(seconds, 15.9):
		_key(KEY_SHIFT, true)
	if _at(seconds, 16.05):
		_key(KEY_SHIFT, false)
		_key(KEY_S, true)
	if _at(seconds, 17.9):
		_key(KEY_S, false)
		_key(KEY_R, true)
	if _at(seconds, 18.05):
		_key(KEY_R, false)
	if _at(seconds, 19.4):
		_key(KEY_SHIFT, true)
	if _at(seconds, 19.55):
		_key(KEY_SHIFT, false)
		_key(KEY_E, true)
	if _at(seconds, 20.1):
		_key(KEY_E, false)
	if _at(seconds, 25.5):
		_key(KEY_DOWN, true)
	if _at(seconds, 25.6):
		_key(KEY_DOWN, false)
		_key(KEY_ENTER, true)
	if _at(seconds, 25.7):
		_key(KEY_ENTER, false)


func _at(seconds: float, moment: float) -> bool:
	if seconds < moment or _sent.has(moment):
		return false
	_sent[moment] = true
	return true


func _point(point: Vector3) -> void:
	var event := InputEventMouseMotion.new()
	event.position = main.world.camera.unproject_position(point)
	event.global_position = event.position
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("demo FAIL: " + message)
