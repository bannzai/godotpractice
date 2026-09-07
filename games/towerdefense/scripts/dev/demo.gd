extends SceneTree
## 30 秒の実入力によるプレイ録画。初期資金・敵・時間・能力は変更しない。
## 通常の操作とフレームを順番に消費するため非冪等。

const FRAME_LIMIT: int = 900

var main: Node
var run: Node
var frames: int = 0
var failed: bool = false
var built: bool = false
var upgraded: bool = false
var saw_enemies: bool = false


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	root.size = Vector2i(1280, 720)
	run = root.get_node("Run")
	run.save_path = "res://tmp/demo-save.json"
	run.tutorial_save_path = "res://tmp/demo-tutorial.json"
	_remove_file(run.tutorial_save_path)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	print("録画開始: 30 秒、表紙・地図・指南から実キー入力で建設・強化・防衛")
	for frame: int in range(FRAME_LIMIT):
		frames = frame
		_event(frame)
		await process_frame
		if not run.enemies.is_empty():
			saw_enemies = true
	_check(built and upgraded and saw_enemies, "建設・強化・敵との戦闘を録画")
	_check(run.wave >= 1, "実入力でウェーブ開始")
	if not failed:
		print("demo OK")
	quit(1 if failed else 0)


func _event(frame: int) -> void:
	match frame:
		30: _key(KEY_ENTER, true)
		32: _key(KEY_ENTER, false)
		60:
			_check(run.phase == "map", "Enter でタイトルから地図へ")
			_key(KEY_ENTER, true)
		62: _key(KEY_ENTER, false)
		90: _key(KEY_RIGHT, true)
		92: _key(KEY_RIGHT, false)
		105: _key(KEY_TAB, true)
		107: _key(KEY_TAB, false)
		111: _key(KEY_TAB, true)
		113: _key(KEY_TAB, false)
		117: _key(KEY_TAB, true)
		119: _key(KEY_TAB, false)
		123: _key(KEY_TAB, true)
		125: _key(KEY_TAB, false)
		135: _key(KEY_ENTER, true)
		137: _key(KEY_ENTER, false)
		165: _key(KEY_SPACE, true)
		167: _key(KEY_SPACE, false)
		170: _key(KEY_U, true)
		172: _key(KEY_U, false)
		180: _key(KEY_RIGHT, true)
		182: _key(KEY_RIGHT, false)
		195: _key(KEY_TAB, true)
		197: _key(KEY_TAB, false)
		210: _key(KEY_ENTER, true)
		212: _key(KEY_ENTER, false)
		225: _key(KEY_F, true)
		227: _key(KEY_F, false)
		240:
			built = run.towers.size() >= 2
			for tower: Dictionary in run.towers:
				if int(tower.level) > 1:
					upgraded = true
			_check(run.phase == "play", "地図からプレイへ遷移")
			_check(not main.tutorial_active and run.tutorial_seen, "実入力で指南を完了")
			_check(run.speed == 3, "F の実入力で 3 倍速")
		FRAME_LIMIT - 15: main.stop_audio()
	# 敵を全滅させた後も通常のウェーブ開始操作だけで録画を続ける。
	if frame > 250 and frame < FRAME_LIMIT - 30 and frame % 60 == 0:
		if run.phase == "play" and not run.active:
			_key(KEY_SPACE, true)
	if frame > 250 and frame < FRAME_LIMIT - 30 and frame % 60 == 2:
		_key(KEY_SPACE, false)
	if frame % 60 == 0:
		print("録画 %02d 秒: %s / ウェーブ %d / 塔 %d / 敵 %d" % [frame / 30,
			run.phase, run.wave, run.towers.size(), run.enemies.size()])


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _check(condition: bool, description: String) -> void:
	if not condition:
		failed = true
		push_error("demo FAIL: " + description)


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
