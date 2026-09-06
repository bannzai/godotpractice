extends SceneTree
## 30 fps・26 秒の実入力プレイ録画。冒険の初期準備後は Game の状態を直接変更しない。

const TOTAL_FRAMES: int = 780

var main: Control
var game: Node
var failed: bool = false
var saw_field: bool = false
var saw_dialogue: bool = false
var saw_battle: bool = false
var saw_clear: bool = false
var returned_title: bool = false
var walked_to_captain: bool = false


func _initialize() -> void:
	_run.call_deferred()


## 固定時刻の入力で冒険を進める録画なので非冪等。
func _run() -> void:
	game = root.get_node("Game")
	game.new_game()
	game.mode = "title"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	print("プレイ録画の初期条件: 新規冒険・コハネ Lv15・経験値179・町の通常開始位置。セーブは不使用。")
	for frame: int in TOTAL_FRAMES:
		if frame == 45:
			_key(KEY_ENTER, true)
		elif frame == 47:
			_key(KEY_ENTER, false)
		elif frame == 54:
			_prepare_adventure()
		_route_input(frame)
		if frame in [228, 270]:
			_key(KEY_ENTER, true)
		elif frame in [230, 272]:
			_key(KEY_ENTER, false)
		if frame in [315, 435, 555] and game.mode == "battle":
			_check(not main.busy, "戦闘の次の入力時刻までに演出が終了する")
			if not main.busy:
				_key(KEY_ENTER, true)
		elif frame in [317, 437, 557]:
			_key(KEY_ENTER, false)
		if frame == 630:
			_check(saw_clear and not main.busy, "21 秒までに隊長に勝利して結果画面が表示される")
			if saw_clear and not main.busy:
				_click(Vector2(310, 580), true)
		elif frame == 632:
			_click(Vector2(310, 580), false)
		_observe()
		if frame == TOTAL_FRAMES - 12:
			main.stop_audio()
		await process_frame
	_check(saw_field, "タイトルから冒険を開始した")
	_check(walked_to_captain, "実際の移動入力で 12 歩進み、隊長の南隣に到着した")
	_check(saw_dialogue, "隊長との対話を実入力で開いた")
	_check(saw_battle, "隊長との戦闘へ実入力で進んだ")
	_check(saw_clear, "戦闘演出と結果画面への遷移が完了した")
	_check(returned_title and game.mode == "title", "結果画面のボタン操作でタイトルへ戻った")
	if not failed:
		print("プレイ録画 OK: タイトル → 12 歩移動 → 隊長対話 → 戦闘 → クリア → タイトル / 780 フレーム")
	quit(1 if failed else 0)


func _prepare_adventure() -> void:
	_check(game.mode == "field", "冒険開始の決定入力が届いた")
	if game.mode != "field":
		return
	# start_new が個体を作り直すため、最初の操作直後を初期条件の設定時点とする。
	game.party = [Catalog.create_monster("ember", 15)]
	game.party[0].xp = 179
	game.rng.seed = 23
	main.refresh()


## 一歩ずつの押下・解放で、長押しリピートに依存しない移動を録画する。
func _route_input(frame: int) -> void:
	for step: int in 9:
		if frame == 90 + step * 8:
			_key(KEY_RIGHT, true)
		elif frame == 92 + step * 8:
			_key(KEY_RIGHT, false)
	for step: int in 3:
		if frame == 180 + step * 8:
			_key(KEY_UP, true)
		elif frame == 182 + step * 8:
			_key(KEY_UP, false)


func _observe() -> void:
	saw_field = saw_field or game.mode == "field"
	walked_to_captain = walked_to_captain or (
		game.mode == "field" and game.cell == Vector2i(18, 7) and game.steps == 12
	)
	saw_dialogue = saw_dialogue or (
		game.mode == "field" and main.menu_open and game.cell == Vector2i(18, 7)
	)
	saw_battle = saw_battle or (game.mode == "battle" and game.trainer)
	saw_clear = saw_clear or (
		game.mode == "clear" and main.drawn_mode == "clear"
		and not main.busy and main.page.modulate.a >= 0.99
	)
	returned_title = returned_title or (
		saw_clear and game.mode == "title" and main.page.modulate.a >= 0.99
	)


## 押下・解放は録画中の一操作なので非冪等。
func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


## ポインター移動とクリックを実際の GUI に届けるため非冪等。
func _click(at: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("プレイ録画: " + message)
