extends Control
## シーン間の進行は AdventureState、プレイ空間は World が所有する。

const WorldScript = preload("res://scripts/world.gd")
const Presentation = preload("res://scripts/presentation.gd")
var state: Node
var world: Node2D
var ui: Control
var audio: Node
var notice: String = "東へ進み、遺跡に消えた灯りを探そう。"
var dialogue_title: String = ""
var dialogue_text: String = ""
var shop_open: bool = false
var closing: bool = false


func _ready() -> void:
	print("actionadventure boot")
	state = get_node("/root/AdventureState")
	get_tree().auto_accept_quit = false
	audio = preload("res://scripts/audio_director.gd").new()
	add_child(audio)
	world = WorldScript.new()
	add_child(world)
	world.setup(self)
	ui = Presentation.new()
	var canvas := CanvasLayer.new()
	canvas.layer = 1
	add_child(canvas)
	canvas.add_child(ui)
	ui.setup(self, state)
	audio.set_track("title")
	if OS.get_environment("ACTIONADVENTURE_RUN_CAPTURE") == "1":
		_run_capture.call_deferred()


# フレームと入力を消費するため非冪等。
func _process(_delta: float) -> void:
	ui.refresh()
	var quit_frame: int = OS.get_environment("ACTIONADVENTURE_MOVIE_FRAMES").to_int()
	if quit_frame > 0 and Engine.get_process_frames() >= quit_frame - 12:
		stop_audio()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var fullscreen: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen \
			else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if event.is_action_pressed("menu") and not world.fatal:
		if state.mode == "play":
			state.mode = "menu"
		elif state.mode == "menu":
			close_menu()
		elif state.mode == "dialogue":
			close_dialogue()
		get_viewport().set_input_as_handled()


func start_new() -> void:
	state.new_game()
	notice = "東へ進み、遺跡に消えた灯りを探そう。"
	world.enter_room(0, Vector2(280, 384))
	ui.refresh()


func continue_game() -> void:
	if state.load_game():
		world.enter_room(state.room, Vector2(200, 384))
	else:
		notice = "保存データを読み込めませんでした。新しい旅を始められます。"
	ui.refresh()


func retry_game() -> void:
	state.retry()
	world.enter_room(state.room, Vector2(200, 384))
	ui.refresh()


func to_title() -> void:
	state.mode = "title"
	audio.set_track("title")
	ui.refresh()


func close_menu() -> void:
	state.mode = "play"
	ui.refresh()


# 装備変更は冪等、薬だけは一回の使用で在庫を消費する。
func select_tool(tool: String) -> void:
	if tool == "potion":
		if state.potions > 0 and state.hp < state.max_hp:
			state.potions -= 1
			state.heal(state.max_hp)
			world.effects.popup(world.hero.position, "全回復")
	elif tool == "boomerang" and state.boomerang_owned:
		state.tool = tool
	elif tool == "bomb" and state.bombs_owned:
		state.tool = tool
	close_menu()


func save_progress() -> void:
	notice = "旅を記録しました。" if state.save_game() else "保存できませんでした。"
	close_menu()


# 購入は取引ごとに所持金と在庫を更新する。
func buy_item(item: String) -> void:
	var price: int = 10 if item == "bomb" else 15
	if item == "bomb" and not state.bombs_owned:
		dialogue_text = "爆弾袋は遺跡にあります。先に道具を見つけてください。"
	elif (item == "bomb" and state.bombs > 96) or (item == "potion" and state.potions >= 99):
		dialogue_text = "これ以上は持てません。道具を使ってからお越しください。"
	elif state.spend(price):
		if item == "bomb":
			state.bombs += 3
		else:
			state.potions += 1
		dialogue_text = "お買い上げありがとう。道具はメニューから選べます。"
		audio.cue("chest")
	else:
		dialogue_text = "琥珀貨が足りません。草や魔物を調べてみてください。"
	ui.refresh()


func talk(title: String, message: String, shop: bool = false) -> void:
	dialogue_title = title
	dialogue_text = message
	shop_open = shop
	state.mode = "dialogue"
	ui.refresh()


func close_dialogue() -> void:
	state.mode = "play"
	shop_open = false
	ui.refresh()


func room_name() -> String:
	return WorldScript.ROOM_NAMES[state.room]


func objective() -> String:
	return world.objective()


func show_result(won: bool) -> void:
	state.mode = "ending" if won else "gameover"
	audio.set_track("result")
	ui.refresh()


func stop_audio() -> void:
	audio.shutdown()


func shutdown() -> void:
	if closing:
		return
	closing = true
	stop_audio()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		shutdown()


func _run_capture() -> void:
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var result: Error = get_viewport().get_texture().get_image().save_png("res://tmp/run-title.png")
	var audible: bool = audio.music.playing \
		and AudioServer.get_bus_peak_volume_left_db(0, 0) > -60
	for mode: int in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_WINDOWED]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_F11
		event.pressed = true
		Input.parse_input_event(event)
		await get_tree().create_timer(1.2).timeout
		if DisplayServer.window_get_mode() != mode:
			result = FAILED
	if result == OK and audible:
		print("runcheck OK: タイトル描画・実音声・F11往復・通常終了")
		shutdown()
	else:
		push_error("起動検証の描画・音声・全画面切替のいずれかが不成立")
		stop_audio()
		await get_tree().create_timer(0.2).timeout
		get_tree().quit(1)
