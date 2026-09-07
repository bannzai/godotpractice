extends Control
## シーン間の進行は AdventureState、プレイ空間は World が所有する。

const WorldScript = preload("res://scripts/world.gd")
const Presentation = preload("res://scripts/presentation.gd")
const TUTORIAL_PAGES: Array[Dictionary] = [
	{
		"title": "長老の石版　はじめの刻み 1 / 3",
		"text": "琥珀色に点滅するものへ近づき、E または A で調べるのじゃ。\nまずは、この長老へ話しかける感覚を覚えよう。",
	},
	{
		"title": "長老の石版　はじめの刻み 2 / 3",
		"text": "WASD・矢印・左スティックで歩く。J・Space・X で剣、K・Y で道具。\n赤い印は、鍵や道具が足りず今はできないことを示す。",
	},
	{
		"title": "長老の石版　はじめの刻み 3 / 3",
		"text": "この羊皮紙を持ってゆけ。M または Back で地図を開ける。\n金の灯が現在地、点線の先が次の目的じゃ。東の遺跡へ向かえ。",
	},
]
var state: Node
var world: Node2D
var ui: Control
var audio: Node
var notice: String = "東へ進み、遺跡に消えた灯りを探そう。"
var dialogue_title: String = ""
var dialogue_text: String = ""
var shop_open: bool = false
var tutorial_step: int = -1
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
	audio.set_region(0)
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
		elif state.mode == "map":
			_close_map()
		elif state.mode == "dialogue":
			if _tutorial_active():
				_skip_tutorial()
			else:
				close_dialogue()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("map") and not world.fatal:
		if state.mode == "map":
			_close_map()
		elif state.mode == "play":
			_open_map()
		get_viewport().set_input_as_handled()


func start_new() -> void:
	state.new_game()
	notice = "長老の石版を読み、島の歩き方を知ろう。"
	world.enter_room(0, Vector2(280, 384))
	_begin_tutorial()


func continue_game() -> void:
	if state.load_game(_save_path()):
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
	audio.set_region(0)
	ui.refresh()


func close_menu() -> void:
	state.mode = "play"
	ui.refresh()


func _open_map() -> void:
	if not state.has_flag("map-owned"):
		notice = "地図はまだ持っていない。村の長老に話しかけよう。"
		world.flash_unavailable("地図なし", world.hero.position)
		ui.refresh()
		return
	state.mode = "map"
	ui.refresh()


func _close_map() -> void:
	state.mode = "play"
	ui.refresh()


func _tutorial_active() -> bool:
	return tutorial_step >= 0 and tutorial_step < TUTORIAL_PAGES.size()


func _begin_tutorial() -> void:
	tutorial_step = 0
	_show_tutorial_page()


func _next_tutorial() -> void:
	if not _tutorial_active():
		return
	tutorial_step += 1
	if tutorial_step >= TUTORIAL_PAGES.size():
		_finish_tutorial(false)
	else:
		_show_tutorial_page()


func _skip_tutorial() -> void:
	if _tutorial_active():
		_finish_tutorial(true)


func _finish_tutorial(skipped: bool) -> void:
	tutorial_step = -1
	state.set_flag("map-owned")
	state.mode = "play"
	shop_open = false
	notice = (
		"案内を省いた。M / Back の羊皮紙で、次の目的を確かめられる。"
		if skipped else
		"羊皮紙の地図を受け取った。東の遺跡へ向かおう。"
	)
	world.effects.burst(world.hero.position, Color("d8c28a"), 22)
	world.effects.popup(world.hero.position, "羊皮紙の地図")
	ui.refresh()


func _show_tutorial_page() -> void:
	var page: Dictionary = TUTORIAL_PAGES[tutorial_step]
	dialogue_title = page.title
	dialogue_text = page.text
	shop_open = false
	state.mode = "dialogue"
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
	notice = "旅を記録しました。" if state.save_game(_save_path()) else "保存できませんでした。"
	close_menu()


func _save_path() -> String:
	var override: String = OS.get_environment("ACTIONADVENTURE_SAVE_PATH")
	return state.SAVE_PATH if override.is_empty() else override


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
