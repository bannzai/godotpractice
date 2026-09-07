extends SceneTree
## 代表画面・農作業の途中・キャラクターの各姿勢を実描画で記録する。

var main: Control
var farm: Node
var failed: bool = false


func _initialize() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	_run.call_deferred()


## シーンを実時間で進めて撮影するため非冪等。
func _run() -> void:
	farm = root.get_node("Farm")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _capture_scenes()
	main.stop_audio()
	await create_timer(0.2).timeout
	main.queue_free()
	await process_frame
	quit(1 if failed else 0)


## 操作中の状態と演出を作って撮影するため非冪等。
func _capture_scenes() -> void:
	await create_timer(0.55).timeout
	await _check_fullscreen()
	await _capture("title")
	main._help()
	await create_timer(0.3).timeout
	await _capture("help")
	main.close_modal()
	main.start_new()
	await create_timer(0.4).timeout
	await _capture("tutorial-letter")
	main._begin_tutorial()
	await create_timer(0.25).timeout
	await _capture("tutorial-step-1-highlight")
	farm.selected_tool = 3
	main._update_hud()
	await create_timer(0.2).timeout
	await _capture("highlight-unavailable")
	main._skip_tutorial()
	_prepare_field("spring")
	await create_timer(0.35).timeout
	await _capture("spring")
	await _capture_tools()
	main.open_menu()
	await create_timer(0.3).timeout
	await _capture("journal")
	main._inventory()
	await create_timer(0.2).timeout
	await _capture("inventory")
	main._catalogue()
	await create_timer(0.2).timeout
	await _capture("catalogue")
	main.close_modal()
	main._open_village_map()
	await create_timer(0.5).timeout
	await _capture("village-map")
	main.open_shop()
	await create_timer(0.3).timeout
	await _capture("shop")
	main.close_modal()
	main._return_to_field()
	farm.player_position = main.world.BED
	main.world.refresh()
	main.interact()
	await create_timer(0.3).timeout
	await _capture("sleep")
	main.close_modal()
	farm.minutes = 1290.0
	await create_timer(0.3).timeout
	await _capture("evening")
	_prepare_field("summer")
	await _capture("summer")
	await _capture_characters()
	farm.money = 900
	farm.phase = "win"
	main.show_result()
	await create_timer(0.55).timeout
	await _capture("result-clear")
	farm.money = 120
	farm.day = 20
	farm.phase = "loss"
	main.show_result()
	await create_timer(0.55).timeout
	await _capture("result-season-end")
	main.return_title()
	await create_timer(0.5).timeout
	await _capture("title-return")


func _prepare_field(season_id: String) -> void:
	farm.day = 4 if season_id == "spring" else 14
	farm.minutes = 570.0
	farm.player_position = Vector2(416, 272)
	farm.facing = Vector2.DOWN
	var crops: Array[String] = []
	crops.assign(["turnip", "carrot"] if season_id == "spring" else ["tomato", "corn"])
	for index: int in farm.tiles.size():
		var crop: String = crops[index % 2]
		var stage: int = index % 4
		farm.tiles[index].merge({
			"tilled": true, "watered": stage == 1,
			"crop": crop, "growth": int(farm.CROPS[crop].days) if stage == 3 else maxi(0, stage - 1),
			"withered": false,
		}, true)
	farm.tiles[0].merge({"tilled": false, "watered": false, "crop": "", "growth": 0}, true)
	main.refresh()


## 農作業のパーティクルと Tween が途中の時点を撮影するため非冪等。
func _capture_tools() -> void:
	farm.selected_tool = 0
	main.use_tool()
	await create_timer(0.16).timeout
	await _capture("effect-hoe")
	await create_timer(0.55).timeout
	farm.selected_tool = 2
	main.use_tool()
	await create_timer(0.55).timeout
	farm.selected_tool = 1
	main.use_tool()
	await create_timer(0.16).timeout
	await _capture("effect-water")
	await create_timer(0.55).timeout
	farm.player_position = Vector2(480, 272)
	farm.tiles[1].merge({"tilled": true, "crop": "turnip", "growth": 2}, true)
	farm.selected_tool = 3
	main.refresh()
	main.use_tool()
	await create_timer(0.16).timeout
	await _capture("effect-harvest")
	await create_timer(0.55).timeout
	farm.player_position = main.world.SHIPPING
	main.world.refresh()
	main.interact()
	await create_timer(0.16).timeout
	await _capture("effect-shipping")
	await create_timer(0.55).timeout


## 各キャラを実再生し、対象コマへ到達した時点で止めて比較できる形で撮影する。
func _capture_characters() -> void:
	var gallery := Control.new()
	gallery.theme = main.theme
	main.add_child(gallery)
	var panel := Panel.new()
	panel.position = Vector2(60, 116)
	panel.size = Vector2(1160, 538)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff8e9")
	style.set_corner_radius_all(24)
	panel.add_theme_stylebox_override("panel", style)
	gallery.add_child(panel)
	var heading: Label = _label(gallery, "キャラクターの動き", Vector2(102, 148), 34)
	var actors: Array[Node2D] = []
	var kinds: Array[String] = ["farmer", "merchant", "chicken"]
	var names: Array[String] = ["農場主", "商店主", "ニワトリ"]
	for index: int in kinds.size():
		var actor: Node2D = load("res://scripts/farm_actor.gd").new()
		gallery.add_child(actor)
		actor.setup(kinds[index])
		actor.position = Vector2(285 + index * 350, 490)
		actor.scale = Vector2.ONE * 1.5
		actors.append(actor)
		_label(gallery, names[index], Vector2(228 + index * 350, 530), 26)
	var descriptions: Dictionary = {
		"idle": "待機", "walk": "歩く", "hoe": "耕す", "water": "水やり",
		"harvest": "収穫", "tired": "疲れた姿",
	}
	for action: String in descriptions:
		for pose: int in [0, 1, 3]:
			heading.text = "キャラクターの動き　/　%s　/　%s" % [
				descriptions[action], {0: "開始", 1: "途中", 3: "終了"}[pose]]
			for actor: Node2D in actors:
				await _animate_to_pose(actor, action, pose)
			await _capture("characters-%s-%d" % [action, pose])
	gallery.queue_free()
	await process_frame


## アニメーションの frame_changed を待つため非冪等。フレーム番号を直接書き換えない。
func _animate_to_pose(actor: Node2D, action: String, pose: int) -> void:
	actor.sprite.stop()
	actor.animate(action)
	while actor.sprite.frame < pose:
		await actor.sprite.frame_changed
	actor.sprite.pause()
	print("アニメーション到達: %s/%s コマ%d" % [actor.kind, action, actor.sprite.frame])


func _label(parent: Node, text: String, at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("244c41"))
	parent.add_child(label)
	return label


## F11 の実キー操作で表示モードを往復するため非冪等。
func _check_fullscreen() -> void:
	for expected: int in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_WINDOWED]:
		for pressed: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = KEY_F11
			event.physical_keycode = KEY_F11
			event.pressed = pressed
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			await process_frame
		await create_timer(1.2).timeout
		if DisplayServer.window_get_mode() != expected:
			failed = true
			push_error("F11 で表示モードを切り替えられない")
	if not failed:
		print("全画面の往復 OK: F11 の実キー入力")


## 描画サーバーが反映した画面を保存するため非冪等。
func _capture(scene_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://tmp/screenshot-%s.png" % scene_name
	var status: Error = root.get_texture().get_image().save_png(path)
	if status != OK:
		failed = true
		push_error("スクリーンショット保存失敗: %s (%s)" % [path, error_string(status)])
	else:
		print("screenshot: " + path)
