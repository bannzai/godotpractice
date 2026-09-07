extends SceneTree
## 30 fps・37 秒の実入力プレイ録画。冒険の初期準備後は Game の状態を直接変更しない。

const TOTAL_FRAMES: int = 1110

var main: Control
var game: Node
var failed: bool = false
var saw_field: bool = false
var saw_tutorial_move: bool = false
var saw_tutorial_interact: bool = false
var saw_region_map: bool = false
var saw_region_preview: bool = false
var saw_route: bool = false
var returned_town: bool = false
var saw_choice_highlight: bool = false
var saw_dialogue: bool = false
var saw_battle: bool = false
var saw_battle_preview: bool = false
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
	print("プレイ録画の初期条件: 新規冒険・チュートリアルと地方図を実入力・隊長戦のみ固定育成値。")
	for frame: int in TOTAL_FRAMES:
		if frame == 45:
			_key(KEY_ENTER, true)
		elif frame == 47:
			_key(KEY_ENTER, false)
		elif frame == 90:
			_key(KEY_RIGHT, true)
		elif frame == 92:
			_key(KEY_RIGHT, false)
		elif frame == 135:
			_key(KEY_ENTER, true)
		elif frame == 137:
			_key(KEY_ENTER, false)
		elif frame == 180:
			_key(KEY_ESCAPE, true)
		elif frame == 182:
			_key(KEY_ESCAPE, false)
		elif frame == 210:
			_click(Vector2(620, 551), true)
		elif frame == 212:
			_click(Vector2(620, 551), false)
		elif frame == 270:
			_key(KEY_ENTER, true)
		elif frame == 272:
			_key(KEY_ENTER, false)
		elif frame == 320:
			_key(KEY_ESCAPE, true)
		elif frame == 322:
			_key(KEY_ESCAPE, false)
		elif frame == 350:
			_click(Vector2(620, 551), true)
		elif frame == 352:
			_click(Vector2(620, 551), false)
		elif frame == 410:
			_key(KEY_ENTER, true)
		elif frame == 412:
			_key(KEY_ENTER, false)
		elif frame == 450:
			_prepare_adventure()
		_route_input(frame)
		if frame in [550, 600]:
			_key(KEY_ENTER, true)
		elif frame in [552, 602]:
			_key(KEY_ENTER, false)
		if frame in [660, 780, 900] and game.mode == "battle":
			_check(not main.busy, "戦闘の次の入力時刻までに演出が終了する")
			if not main.busy:
				_key(KEY_ENTER, true)
		elif frame in [662, 782, 902]:
			_key(KEY_ENTER, false)
		if frame == 1040:
			_check(saw_clear and not main.busy, "35 秒までに隊長に勝利して結果画面が表示される")
			if saw_clear and not main.busy:
				_key(KEY_ENTER, true)
		elif frame == 1042:
			_key(KEY_ENTER, false)
		_observe()
		if frame == TOTAL_FRAMES - 12:
			main.stop_audio()
		await process_frame
	_check(saw_field, "タイトルから冒険を開始した")
	_check(saw_tutorial_move and saw_tutorial_interact,
		"移動と話す操作のチュートリアルを順に表示した")
	_check(saw_region_map and saw_region_preview,
		"旅支度から地方図を開き、移動先プレビューと現在地の不可理由を表示した")
	_check(saw_route and returned_town, "地方図の実入力で小径へ移動し、町へ戻った")
	_check(saw_choice_highlight, "選択中の項目を ▶ でハイライトした")
	_check(walked_to_captain, "実際の移動入力で隊長の南隣に到着した")
	_check(saw_dialogue, "隊長との対話を実入力で開いた")
	_check(saw_battle, "隊長との戦闘へ実入力で進んだ")
	_check(saw_battle_preview, "戦闘で縦並びの技と効果プレビューを表示した")
	_check(saw_clear, "戦闘演出と結果画面への遷移が完了した")
	_check(returned_title and game.mode == "title", "結果画面のボタン操作でタイトルへ戻った")
	if not failed:
		print("プレイ録画 OK: タイトル → チュートリアル → 地方図往復 → 隊長戦 → クリア → タイトル / 1110 フレーム")
	quit(1 if failed else 0)


func _prepare_adventure() -> void:
	_check(game.mode == "field" and not main.tutorial_active and game.zone == "town",
		"チュートリアルと地方図往復を終えて町へ戻った")
	if game.mode != "field" or main.tutorial_active or game.zone != "town":
		return
	# start_new が個体を作り直すため、最初の操作直後を初期条件の設定時点とする。
	game.party = [Catalog.create_monster("ember", 15)]
	game.party[0].xp = 179
	game.rng.seed = 23
	main.refresh()


## 一歩ずつの押下・解放で、長押しリピートに依存しない移動を録画する。
func _route_input(frame: int) -> void:
	for step: int in 4:
		if frame == 480 + step * 8:
			_key(KEY_LEFT, true)
		elif frame == 482 + step * 8:
			_key(KEY_LEFT, false)


func _observe() -> void:
	saw_field = saw_field or game.mode == "field"
	saw_tutorial_move = saw_tutorial_move or (
		main.tutorial_active and main.tutorial_step == 0
		and is_instance_valid(main.tutorial_message)
	)
	saw_tutorial_interact = saw_tutorial_interact or (
		main.tutorial_active and main.tutorial_step == 1
		and is_instance_valid(main.tutorial_message)
	)
	saw_region_map = saw_region_map or main.region_map_open
	saw_region_preview = saw_region_preview or (
		main.region_map_open and not main.region_preview.is_empty()
		and not main.region_unavailable_reason.is_empty()
	)
	saw_route = saw_route or (game.mode == "field" and game.zone == "route")
	returned_town = returned_town or (saw_route and game.mode == "field" and game.zone == "town")
	saw_choice_highlight = saw_choice_highlight or (
		is_instance_valid(main.focused_choice) and main.focused_choice.text.begins_with("▶ ")
	)
	walked_to_captain = walked_to_captain or (
		returned_town and game.mode == "field" and game.cell == Vector2i(18, 7)
		and game.steps >= 5
	)
	saw_dialogue = saw_dialogue or (
		game.mode == "field" and main.menu_open and game.cell == Vector2i(18, 7)
	)
	saw_battle = saw_battle or (game.mode == "battle" and game.trainer)
	saw_battle_preview = saw_battle_preview or (
		game.mode == "battle" and not main.battle_preview.is_empty()
		and is_instance_valid(main.focused_choice)
	)
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
