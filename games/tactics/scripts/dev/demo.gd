extends SceneTree
## 32 秒の録画へ実入力を流す。戦闘状態は本番の入力処理だけが変更する。
## 入力・時間経過・録画を伴うため一起動で一巡だけ実行する。

const FRAME_LIMIT: int = 960

var main: Node
var campaign: Node
var frames: int = 0
var step: int = 0
var next_frame: int = 40
var releases: Array[InputEvent] = []
var story_seen: bool = false
var moved: bool = false
var forecasted: bool = false
var attacked: bool = false
var enemy_phase_seen: bool = false
var healed: bool = false
var healing_id: String = ""
var previous_hp: int = 0
var previous_items: int = 0


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	campaign = root.get_node("Campaign")
	campaign.save_path = "res://tmp/demo-campaign.json"
	campaign.rng.seed = 42
	root.size = Vector2i(1280, 720)
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	main = scene.instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	for event: InputEvent in releases:
		Input.parse_input_event(event)
	releases.clear()
	Input.flush_buffered_events()
	if not is_instance_valid(main):
		return false
	if campaign.phase == "enemy":
		enemy_phase_seen = true
	if frames >= FRAME_LIMIT - 12:
		# 演出の途中でも最後の12フレームは音声参照を解放しておく。
		main.stop_audio()
	elif frames >= next_frame and not main.busy:
		_advance()
	if frames >= FRAME_LIMIT:
		_finish()
	return false


func _advance() -> void:
	match step:
		0:
			_click(Vector2(300, 433))
			_wait(1, 42)
		1:
			if campaign.screen == "story":
				story_seen = true
				_click(Vector2(1025, 605))
				_wait(2, 42)
		2:
			if campaign.screen == "play":
				_click_cell(Vector2i(2, 5))
				_wait(3, 35)
		3:
			if main.selected == "hero":
				_click_cell(Vector2i(4, 5))
				_wait(4, 38)
		4:
			var hero: Dictionary = campaign.unit_by_id("hero")
			if Vector2i(hero.x, hero.y) == Vector2i(4, 5):
				moved = true
				_click_cell(Vector2i(5, 5))
				_wait(5, 55)
		5:
			if main.target == "e1" and not campaign.preview("hero", "e1").is_empty():
				forecasted = true
				_key(KEY_ENTER)
				_wait(6, 30)
		6:
			if campaign.unit_by_id("hero").acted:
				attacked = true
				_key(KEY_E)
				_wait(7, 30)
		7:
			if campaign.phase == "player" and campaign.turn >= 2:
				_select_wounded()
		8:
			if main.selected == healing_id:
				# 薬ボタンもマウスの押下と解放で操作する。
				_click(Vector2(1060, 485))
				_wait(9, 30)
		9:
			var unit: Dictionary = campaign.unit_by_id(healing_id)
			if not unit.is_empty():
				healed = unit.hp > previous_hp and unit.items == previous_items - 1
				_key(KEY_E)
				_wait(10, 30)
		10:
			# 次の自軍フェーズでは選択範囲を表示し、最後まで盤面を見せる。
			if campaign.phase == "player" and campaign.screen == "play":
				var hero: Dictionary = campaign.unit_by_id("hero")
				_click_cell(Vector2i(hero.x, hero.y))
				_wait(11, FRAME_LIMIT)


func _select_wounded() -> void:
	for unit: Dictionary in campaign.living("player"):
		if unit.hp < unit.max_hp and unit.items > 0 and not unit.acted:
			healing_id = unit.id
			previous_hp = unit.hp
			previous_items = unit.items
			_click_cell(Vector2i(unit.x, unit.y))
			_wait(8, 35)
			return
	# 回復が不要な戦闘結果なら、状態を捏造せず次の敵フェーズへ進める。
	_key(KEY_E)
	_wait(7, 30)


func _wait(value: int, delay_frames: int) -> void:
	step = value
	next_frame = frames + delay_frames


func _key(code: Key) -> void:
	var pressed := InputEventKey.new()
	pressed.physical_keycode = code
	pressed.keycode = code
	pressed.pressed = true
	Input.parse_input_event(pressed)
	var released := InputEventKey.new()
	released.physical_keycode = code
	released.keycode = code
	releases.append(released)
	Input.flush_buffered_events()


func _click_cell(cell: Vector2i) -> void:
	_click(Vector2(66, 117) + Vector2(cell) * 44 + Vector2(22, 22))


func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	var pressed := InputEventMouseButton.new()
	pressed.position = point
	pressed.global_position = point
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	Input.parse_input_event(pressed)
	var released := InputEventMouseButton.new()
	released.position = point
	released.global_position = point
	released.button_index = MOUSE_BUTTON_LEFT
	releases.append(released)
	Input.flush_buffered_events()


func _finish() -> void:
	print("demo 検証: 物語=%s 移動=%s 予測=%s 攻撃=%s 敵軍=%s 回復=%s" % [
		story_seen, moved, forecasted, attacked, enemy_phase_seen, healed])
	if story_seen and moved and forecasted and attacked and enemy_phase_seen and healed:
		print("demo OK")
		quit(0)
	else:
		push_error("実入力の録画で必須の操作を完了できませんでした: step=%d" % step)
		quit(1)
