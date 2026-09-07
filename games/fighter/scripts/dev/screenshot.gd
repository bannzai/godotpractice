extends SceneTree
## 実際の描画で代表画面を撮影する (headless では描画されないため、Makefile の screenshot target が
## --headless なしで起動する)。撮影した PNG は tmp/screenshot-<名前>.png に保存し、失敗したら quit(1) で終わる。
## ゲーム固有の状態作り (画面遷移・スコアの投入・操作の再現等) は _capture_scenes() に足す。
## autoload は --script 起動でも root から取得できる。


func _initialize() -> void:
	# BGM の autoload やゲーム側の SE が撮影中に鳴らないよう Master バスをミュートする
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	_run.call_deferred()


## 時間経過と物理で画面を進めるため、同じ実行中に重ねて呼び出さない。
func _run() -> void:
	if await _capture_scenes():
		quit(0)


## 撮影する画面の並び。雛形はメインシーン (タイトル) だけを撮る。失敗した撮影は _capture() が
## quit(1) 済みなので、false を受けたらそのまま抜ける。
func _capture_scenes() -> bool:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.6).timeout
	if not await _capture_menu_screens(main):
		return false
	if not await _capture_tutorial(main):
		return false
	main.previewing = true
	main.player.enabled = false
	main.cpu.enabled = false
	if not await _capture_stage_backgrounds(main):
		return false
	main.combo_count = 7
	main.combo_time = 10.0
	if not await _capture("tmp/screenshot-play.png"):
		return false
	for capture_group: Callable in [
		_capture_moves, _capture_combat, _capture_effects, _capture_projectiles, _capture_results,
		_capture_character_frames, _capture_buttons, _capture_display
	]:
		if not await capture_group.call(main):
			return false
	main.queue_free()
	# 音声ミキサーが停止済みの再生リソースを解放する周期を待つ。
	await create_timer(0.2).timeout
	await process_frame
	return true


func _capture_menu_screens(main: Control) -> bool:
	if not await _capture("tmp/screenshot-title.png"):
		return false
	main.show_select()
	await create_timer(0.5).timeout
	if not await _capture("tmp/screenshot-select.png"):
		return false
	main._choose(1)
	await create_timer(0.2).timeout
	if not await _capture("tmp/screenshot-select-highlight.png"):
		return false
	main._choose(0)
	if not await _capture_stage_screens(main):
		return false
	return true


func _capture_stage_screens(main: Control) -> bool:
	main.show_stage()
	await create_timer(0.5).timeout
	if not await _capture("tmp/screenshot-stage-map.png"):
		return false
	main._choose_stage(1)
	await create_timer(0.6).timeout
	if not await _capture("tmp/screenshot-stage-highlight.png"):
		return false
	main._choose_stage(0)
	main.start_match()
	await create_timer(0.08).timeout
	if not await _capture("tmp/screenshot-transition-fight.png"):
		return false
	return true


func _capture_tutorial(main: Control) -> bool:
	main.intro = 0.0
	await create_timer(0.5).timeout
	main.tutorial_step = 0
	if not await _capture("tmp/screenshot-tutorial-move.png"):
		return false
	main.tutorial_step = 1
	if not await _capture("tmp/screenshot-tutorial-strike.png"):
		return false
	main.tutorial_step = 2
	if not await _capture("tmp/screenshot-tutorial-special.png"):
		return false
	main._finish_tutorial(false)
	return true


func _capture_stage_backgrounds(main: Control) -> bool:
	for index: int in range(main.STAGE_NAMES.size()):
		main.stage_index = index
		if not await _capture("tmp/screenshot-fight-%s.png" % ["tokyo", "seoul", "rio"][index]):
			return false
	main.stage_index = 0
	return true


func _capture_moves(main: Control) -> bool:
	for stance: String in ["standing", "crouching", "air"]:
		for kind: String in ["lp", "hp", "lk", "hk"]:
			main.player.reset_fighter(Vector2(570, 570 if stance != "air" else 450))
			main.cpu.reset_fighter(Vector2(735, 570))
			main.player.enabled = true
			main.player.control(Vector2(0, 1 if stance == "crouching" else 0))
			main.player.start_attack(kind)
			main.player.attack_time = float(main.player.move_data.startup) + 0.03
			main.player.enabled = false
			main.player.queue_redraw()
			if not await _capture("tmp/screenshot-%s-%s.png" % [stance, kind]):
				return false
	return true


func _capture_combat(main: Control) -> bool:
	main.player.reset_fighter(Vector2(570, 570))
	main.cpu.reset_fighter(Vector2(710, 570))
	main.player.enabled = true
	main.cpu.enabled = true
	main.player.start_attack("hp")
	await create_timer(0.22).timeout
	main.player.enabled = false
	main.cpu.enabled = false
	if not await _capture("tmp/screenshot-hit.png"):
		return false
	_clear_effects()
	main.player.reset_fighter(Vector2(1070, 570))
	main.cpu.reset_fighter(Vector2(1195, 570))
	main.player.facing = 1.0
	main.cpu.facing = -1.0
	main.feedback = ""
	main.cpu.control(Vector2(1, 0))
	main.player.enabled = true
	main.cpu.enabled = true
	main.player.start_attack("hp")
	await create_timer(0.23).timeout
	main.player.enabled = false
	main.cpu.enabled = false
	if not await _capture("tmp/screenshot-guard.png"):
		return false
	_clear_effects()
	main.player.reset_fighter(Vector2(420, 570))
	main.cpu.reset_fighter(Vector2(900, 570))
	main.player.enabled = true
	main.player.start_attack("special")
	await create_timer(0.44).timeout
	main.player.enabled = false
	for projectile: Node in get_nodes_in_group("projectiles"):
		projectile.set_physics_process(false)
	if not await _capture("tmp/screenshot-special.png"):
		return false
	return true


func _capture_projectiles(main: Control) -> bool:
	for character: int in range(2):
		for projectile: Node in get_nodes_in_group("projectiles"):
			projectile.queue_free()
		main._choose(character)
		main.start_match()
		main.intro = 0.0
		main.player.reset_fighter(Vector2(400, 570))
		main.cpu.reset_fighter(Vector2(1050, 570))
		main.player.enabled = true
		main.player.start_attack("special")
		await create_timer(0.4).timeout
		main.player.enabled = false
		for projectile: Node in get_nodes_in_group("projectiles"):
			projectile.set_physics_process(false)
		if not await _capture("tmp/screenshot-wave-%s.png" % ["teal" if character == 0 else "amber"]):
			return false
	main._choose(0)
	main.start_match()
	main.intro = 0.0
	return true


func _capture_ko(main: Control) -> bool:
	var state: Node = root.get_node("Match")
	_clear_effects()
	main.feedback_time = 0.0
	for projectile: Node in get_nodes_in_group("projectiles"):
		projectile.queue_free()
	state.finish_round(0, 1000)
	main.cpu.health = 1000
	main.player.health = 0
	main.health_observed[0] = 0
	main._update_fight(0.0)
	main.player.queue_redraw()
	for sample: int in range(3):
		await create_timer(0.02 if sample == 0 else 0.4).timeout
		if not await _capture("tmp/screenshot-ko-frame-%d.png" % sample):
			return false
	if not await _capture("tmp/screenshot-ko.png"):
		return false
	return true


func _capture_results(main: Control) -> bool:
	var state: Node = root.get_node("Match")
	if not await _capture_ko(main):
		return false
	state.wins.assign([2, 1])
	main._clear_arena()
	state.screen = state.Screen.RESULT
	await create_timer(0.08).timeout
	if not await _capture("tmp/screenshot-transition-result.png"):
		return false
	await create_timer(0.5).timeout
	if not await _capture("tmp/screenshot-victory.png"):
		return false
	state.wins.assign([0, 2])
	await create_timer(0.4).timeout
	if not await _capture("tmp/screenshot-defeat.png"):
		return false
	main.show_title()
	await create_timer(0.5).timeout
	if not await _capture("tmp/screenshot-return.png"):
		return false
	return true


func _capture_character_frames(main: Control) -> bool:
	main.visible = false
	var names: Dictionary = {
		"idle": "待機", "walk": "移動", "jump": "跳躍", "crouch": "しゃがみ",
		"guard": "立ちガード", "crouch_guard": "しゃがみガード", "hurt": "被弾", "ko": "倒れる",
		"special": "燈波", "attack": "攻撃",
		"standing_lp": "立ち・弱拳", "standing_hp": "立ち・強拳",
		"standing_lk": "立ち・弱蹴", "standing_hk": "立ち・強蹴",
		"crouching_lp": "しゃがみ・弱拳", "crouching_hp": "しゃがみ・強拳",
		"crouching_lk": "しゃがみ・弱蹴", "crouching_hk": "しゃがみ・強蹴",
		"air_lp": "空中・弱拳", "air_hp": "空中・強拳",
		"air_lk": "空中・弱蹴", "air_hk": "空中・強蹴"
	}
	for character: int in range(2):
		var frames: SpriteFrames = FighterVisual.TEAL if character == 0 else FighterVisual.AMBER
		var animations: PackedStringArray = frames.get_animation_names()
		for page: int in range(ceili(animations.size() / 3.0)):
			var gallery: Control = Control.new()
			root.add_child(gallery)
			var background: ColorRect = ColorRect.new()
			background.size = Vector2(1280, 720)
			background.color = Color("102236")
			gallery.add_child(background)
			_gallery_label(gallery, Vector2(35, 22),
				("蒼電" if character == 0 else "紅蓮") + "  /  連続フレーム  %d" % (page + 1), 30)
			for column: int in range(3):
				_gallery_label(gallery, Vector2(300 + column * 335, 82),
					["開始  1/8", "途中  4/8", "終了  8/8"][column], 19)
			for row: int in range(3):
				var index: int = page * 3 + row
				if index >= animations.size():
					break
				var action: String = animations[index]
				_gallery_label(gallery, Vector2(35, 189 + row * 175), names.get(action, action), 23)
				for column: int in range(3):
					var visual: FighterVisual = FighterVisual.new()
					visual.configure(character)
					visual.animation = action
					visual.set_frame_and_progress([0, 3, 7][column], 0.0)
					visual.position = Vector2(340 + column * 335, 285 + row * 175)
					visual.scale = Vector2.ONE * 0.72
					gallery.add_child(visual)
			if not await _capture("tmp/screenshot-%s-animations-%02d.png" % [
				"teal" if character == 0 else "amber", page + 1]):
				return false
			gallery.queue_free()
			await process_frame
	main.visible = true
	return true


func _gallery_label(parent: Control, at: Vector2, text: String, size_px: int) -> void:
	var label: Label = Label.new()
	label.position = at
	label.text = text
	label.add_theme_font_override("font", preload("res://assets/fonts/DelaGothicOne-Regular.ttf"))
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", Color("f5e7c9"))
	parent.add_child(label)


func _capture_effects(main: Control) -> bool:
	for projectile: Node in get_nodes_in_group("projectiles"):
		projectile.queue_free()
	main.player.reset_fighter(Vector2(510, 570))
	main.cpu.reset_fighter(Vector2(710, 570))
	for blocked: bool in [false, true]:
		main._on_struck(Vector2(660, 460), blocked)
		if not blocked:
			main.cpu.health -= 92
		for sample: int in range(3):
			await create_timer(0.07 if sample == 0 else 0.1).timeout
			if not await _capture("tmp/screenshot-effect-%s-%d.png" % [
				"guard" if blocked else "hit", sample]):
				return false
		await create_timer(0.5).timeout
	return true


func _capture_buttons(main: Control) -> bool:
	main.previewing = false
	main.show_title()
	await create_timer(0.5).timeout
	var pointer: InputEventMouseMotion = InputEventMouseMotion.new()
	pointer.position = Vector2(250, 523)
	Input.parse_input_event(pointer)
	await create_timer(0.18).timeout
	if not await _capture("tmp/screenshot-button-hover.png"):
		return false
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.position = pointer.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await create_timer(0.12).timeout
	if not await _capture("tmp/screenshot-button-pressed.png"):
		return false
	click.pressed = false
	Input.parse_input_event(click)
	await create_timer(0.08).timeout
	if not await _capture("tmp/screenshot-transition-select.png"):
		return false
	await create_timer(0.5).timeout
	if not await _capture("tmp/screenshot-transition-ended.png"):
		return false
	main.show_title()
	await create_timer(0.5).timeout
	return true


func _capture_display(main: Control) -> bool:
	main.previewing = false
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_F11
	key.pressed = true
	Input.parse_input_event(key)
	await create_timer(0.5).timeout
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
		push_error("F11で全画面にならない")
		quit(1)
		return false
	if not await _capture("tmp/screenshot-fullscreen.png"):
		return false
	key.pressed = false
	Input.parse_input_event(key)
	await process_frame
	key.pressed = true
	Input.parse_input_event(key)
	await create_timer(0.5).timeout
	key.pressed = false
	Input.parse_input_event(key)
	return true


func _clear_effects() -> void:
	for effect: Node in get_nodes_in_group("combat_effects"):
		effect.queue_free()


func _capture(path: String) -> bool:
	await process_frame
	await process_frame
	var status: Error = root.get_viewport().get_texture().get_image().save_png(path)
	if status != OK:
		push_error("スクリーンショット保存失敗: %s (%s)" % [path, error_string(status)])
		quit(1)
		return false
	print("screenshot: " + path)
	return true
