extends Control
## 入力と画面を結ぶ。資金・敵・進行状態はautoloadのRunだけが所有する。
## 入力ハンドラと演出は操作のたびに結果を発生させるため非冪等。

const Catalog := preload("res://scripts/catalog.gd")
const Ui := preload("res://scripts/ui.gd")
const Board := preload("res://scripts/board.gd")
const Bindings := preload("res://scripts/input_bindings.gd")

var selected_site: int = 0
var selected_kind: int = 0
var board: Node2D
var screen: Control
var run: Node
var sound: Node
var paused: bool = false
var closing: bool = false
var phase: String = ""
var hud: Label
var preview: Label
var detail: Label
var status: Label
var notice: Label
var build_button: Button
var upgrade_button: Button
var sell_button: Button
var wave_button: Button
var speed_button: Button
var tower_buttons: Array[Button] = []
var gold_display: float = 0.0
var notice_time: float = 0.0
var selection_delay: float = 0.0
var result_count: Label
var result_value: float = 0.0
var pause_panel: Panel


func _ready() -> void:
	print("towerdefense boot")
	Bindings.configure()
	theme = Ui.make_theme()
	run = get_node("/root/Run")
	sound = get_node("/root/Sound")
	run.load_best()
	get_tree().auto_accept_quit = false
	board = Board.new()
	add_child(board)
	_show_phase()


# 毎フレームの戦闘・表示時間を積算する。
func _process(delta: float) -> void:
	selection_delay = maxf(0.0, selection_delay - delta)
	if not paused:
		run.step(delta)
	for value: Dictionary in run.events:
		board.event(value)
		_event(value)
	run.events.clear()
	if phase != run.phase:
		_show_phase()
	board.selected_site = selected_site
	board.selected_kind = Catalog.TOWERS.keys()[selected_kind]
	if phase == "play":
		_update_hud(delta)
	if phase in ["win", "lose"] and is_instance_valid(result_count):
		result_value = move_toward(result_value, float(run.hp), delta * 18)
		result_count.text = "守り抜いた灯  %02d / %02d" % [int(result_value), Catalog.MAX_HP]


func _show_phase() -> void:
	phase = run.phase
	paused = false
	screen = _new_screen()
	match phase:
		"title":
			_title()
		"play":
			_play_ui()
		"win", "lose":
			_result()
	sound.track("stage" if phase == "play" else phase)
	screen.modulate.a = 0
	screen.create_tween().tween_property(screen, "modulate:a", 1.0, 0.28)


func _new_screen() -> Control:
	if is_instance_valid(screen):
		screen.queue_free()
	var node := Control.new()
	node.z_index = 20
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node


func _title() -> void:
	Ui.texture(screen, "res://assets/keyart.svg", Rect2(0, 10, 830, 700))
	Ui.panel(screen, Rect2(780, 90, 445, 540))
	Ui.label(screen, "森の灯を、夜明けまで。", Vector2(820, 128), 19, Ui.GOLD)
	Ui.texture(screen, "res://assets/logo.svg", Rect2(810, 173, 380, 130))
	Ui.label(screen, "曲がる道。四つの塔。十の襲来。\n小さな灯砦の、長い夜が始まる。",
		Vector2(820, 326), 21)
	Ui.button(screen, "防衛を始める  ·  Enter / A", Rect2(818, 429, 370, 62), start_game)
	Ui.label(screen, "最高評価  " + "★".repeat(int(run.best.stars))
		+ "☆".repeat(3 - int(run.best.stars)), Vector2(822, 523), 20, Ui.GOLD)
	Ui.label(screen, "マウス / キーボード / ゲームパッド対応", Vector2(813, 579), 16, Ui.MUTED)
	Ui.label(screen, "黄昏の灯砦  ·  防衛の物語", Vector2(35, 658), 19, Ui.GOLD)
	Ui.label(screen, "F11 全画面    Esc 終了", Vector2(987, 672), 15, Ui.MUTED)


func start_game() -> void:
	run.new_run()
	selected_site = 0
	selected_kind = 0
	gold_display = run.gold
	_reset_board()
	_show_phase()


func _reset_board() -> void:
	board.queue_free()
	board = Board.new()
	add_child(board)
	move_child(board, 0)


func _play_ui() -> void:
	Ui.panel(screen, Rect2(18, 16, 932, 66))
	Ui.label(screen, "黄昏の灯砦", Vector2(37, 29), 25, Ui.GOLD)
	hud = Ui.label(screen, "", Vector2(257, 30), 24)
	Ui.texture(screen, "res://assets/ui/heart.svg", Rect2(216, 32, 28, 30))
	Ui.panel(screen, Rect2(970, 16, 292, 688))
	Ui.label(screen, "灯を守る塔", Vector2(992, 33), 27, Ui.GOLD)
	Ui.label(screen, "地点を選んで建設", Vector2(992, 79), 17, Ui.MUTED)
	tower_buttons.clear()
	for index: int in range(Catalog.TOWERS.size()):
		var kind: String = Catalog.TOWERS.keys()[index]
		var data: Dictionary = Catalog.TOWERS[kind]
		var button: Button = Ui.button(screen, "%s  %d\n%s" % [data.name, data.cost, data.role],
			Rect2(991, 112 + index * 70, 250, 62), _select_kind.bind(index))
		button.add_theme_font_size_override("font_size", 17)
		tower_buttons.append(button)
	detail = Ui.label(screen, "", Vector2(991, 405), 17)
	build_button = Ui.button(screen, "建設  ·  Enter / A", Rect2(991, 497, 250, 45), _build)
	upgrade_button = Ui.button(screen, "", Rect2(991, 550, 250, 45), _upgrade)
	sell_button = Ui.button(screen, "", Rect2(991, 603, 250, 39), _sell)
	Ui.label(screen, "Tab / RB で塔を切替", Vector2(1006, 663), 16, Ui.MUTED)
	Ui.panel(screen, Rect2(18, 609, 932, 95))
	wave_button = Ui.button(screen, "", Rect2(32, 622, 245, 45), _wave)
	speed_button = Ui.button(screen, "", Rect2(288, 622, 145, 45), _speed)
	Ui.button(screen, "休止  Esc", Rect2(444, 622, 124, 45), _pause)
	preview = Ui.label(screen, "", Vector2(590, 620), 16, Ui.GOLD)
	Ui.label(screen, "方向キー / 左スティック：地点選択　 Enter / A：建設　 U / LB：強化",
		Vector2(35, 676), 15, Ui.MUTED)
	status = Ui.label(screen, "", Vector2(31, 566), 18, Ui.GOLD)
	notice = Ui.label(screen, "", Vector2(205, 94), 28, Ui.GOLD)
	notice.add_theme_color_override("font_outline_color", Ui.INK)
	notice.add_theme_constant_override("outline_size", 8)
	_notify("建設地点を選び、塔を置いてから襲来を開始", 4)


func _update_hud(delta: float) -> void:
	gold_display = move_toward(gold_display, float(run.gold), delta * 360)
	hud.text = "灯  %02d     金貨  %03d     襲来  %02d / %02d" % [
		run.hp, int(gold_display), run.wave, Catalog.WAVES.size()]
	var kind: String = Catalog.TOWERS.keys()[selected_kind]
	var tower: Dictionary = run.tower_at(selected_site)
	var stats: Dictionary = Catalog.tower_stats(kind, 1)
	if not tower.is_empty():
		stats = Catalog.tower_stats(tower.kind, tower.level)
		detail.text = "地点 %02d　%s\n段階 %d / 3　射程 %d\n威力 %d　間隔 %.2f秒" % [
			selected_site + 1, stats.name, tower.level, stats.range, stats.damage, stats.interval]
	else:
		detail.text = "地点 %02d　建設可能\n%s　射程 %d\n威力 %d　間隔 %.2f秒" % [
			selected_site + 1, stats.name, stats.range, stats.damage, stats.interval]
	build_button.disabled = not tower.is_empty() or run.gold < int(Catalog.TOWERS[kind].cost)
	build_button.text = "建設 %d  ·  Enter / A" % Catalog.TOWERS[kind].cost
	var price: int = run.upgrade_price(selected_site)
	upgrade_button.disabled = price == 0 or run.gold < price
	upgrade_button.text = "強化 %d  ·  U / LB" % price if price > 0 else "強化できません"
	sell_button.disabled = tower.is_empty()
	sell_button.text = "売却 +%d  ·  X / B" % run.sell_price(selected_site)
	wave_button.disabled = run.active
	wave_button.text = "防衛中　残り %d 体" % (run.enemies.size() + run.spawn_remaining()) if run.active \
		else "襲来を開始  ·  Space / Y"
	speed_button.text = "%d倍速  ·  F / X" % run.speed
	for index: int in range(tower_buttons.size()):
		tower_buttons[index].modulate = Ui.GOLD if selected_kind == index else Color.WHITE
	var next: int = mini(run.wave, Catalog.WAVES.size() - 1)
	var names: Array[String] = []
	for group: Dictionary in Catalog.WAVES[next].groups:
		names.append("%s×%d" % [Catalog.ENEMIES[group.kind].name, group.count])
	preview.text = "次の襲来：" + Catalog.WAVES[next].name + "\n" + " / ".join(names)
	if run.wave >= Catalog.WAVES.size():
		preview.text = "最終襲来：" + Catalog.WAVES[-1].name + "\n全ての敵を防げば、夜明けが来る。"
	preview.add_theme_font_size_override("font_size", 14 if names.size() > 3 else 16)
	status.text = "防衛中はいつでも建設・強化できます" if run.active \
		else "準備の時間：敵は襲来を開始するまで現れません"
	notice_time = maxf(0, notice_time - delta)
	notice.modulate.a = minf(1, notice_time)


func _result() -> void:
	Ui.panel(screen, Rect2(300, 135, 680, 448))
	Ui.label(screen, "夜明けの灯" if phase == "win" else "灯は、またともせる。",
		Vector2(355, 173), 43, Ui.GOLD)
	Ui.label(screen, "★".repeat(run.stars()) + "☆".repeat(3 - run.stars()),
		Vector2(533, 250), 56, Ui.GOLD)
	result_value = 0
	result_count = Ui.label(screen, "", Vector2(440, 330), 27)
	Ui.label(screen, "十の襲来を防ぎ切った。森に朝が戻る。" if phase == "win"
		else "塔の組合せと曲がり角の射程を見直そう。", Vector2(385, 385), 21)
	Ui.button(screen, "もう一度  ·  Enter / A", Rect2(354, 462, 280, 60), start_game)
	Ui.button(screen, "タイトル  ·  Esc / Start", Rect2(653, 462, 280, 60), _title_return)
	Ui.label(screen, "最高評価は自動保存されます", Vector2(491, 551), 17, Ui.MUTED)


func _title_return() -> void:
	run.to_title()
	_reset_board()
	_show_phase()


func _select_kind(index: int) -> void:
	selected_kind = posmod(index, Catalog.TOWERS.size())


func _build() -> void:
	if not paused and not run.build(selected_site, Catalog.TOWERS.keys()[selected_kind]):
		_notify("建設には空き地点と金貨が必要です")


func _upgrade() -> void:
	if not paused and not run.upgrade(selected_site):
		_notify("塔を選び、強化に必要な金貨を集めよう")


func _sell() -> void:
	if not paused:
		run.sell(selected_site)


func _wave() -> void:
	if not paused:
		run.start_wave()


func _speed() -> void:
	run.speed = 3 if run.speed == 1 else 1


func _pause() -> void:
	if phase != "play":
		return
	paused = not paused
	if not paused:
		if is_instance_valid(pause_panel):
			pause_panel.queue_free()
		return
	pause_panel = Ui.panel(screen, Rect2(0, 0, 1280, 720))
	pause_panel.add_theme_stylebox_override("panel", Ui.box(Color(0, 0, 0, 0.5), Color.TRANSPARENT))
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var inner: Panel = Ui.panel(pause_panel, Rect2(280, 190, 460, 300))
	Ui.label(inner, "ひと休み", Vector2(148, 32), 36, Ui.GOLD)
	Ui.button(inner, "防衛に戻る  ·  Enter / Esc", Rect2(40, 112, 380, 55), _pause)
	Ui.button(inner, "タイトルへ  ·  X / B", Rect2(40, 188, 380, 55), _title_return)


func _notify(text: String, duration: float = 2.5) -> void:
	if is_instance_valid(notice):
		notice.text = text
		notice_time = duration


func _event(value: Dictionary) -> void:
	match value.type:
		"shot":
			sound.play(value.kind)
		"build", "upgrade":
			sound.play("build")
		"death":
			sound.play("death")
		"base":
			sound.play("base")
		"wave":
			sound.play("wave")
			_notify("第 %d 襲来  ―  %s" % [value.wave, Catalog.WAVES[value.wave - 1].name])
		"wave_clear":
			_notify("防衛成功！ 金貨を補充しました。次の襲来に備えよう", 4)
		"spawn":
			if value.kind == "boss":
				sound.track("boss")
				_notify("警戒！ 朽木の巨獣が森を進む", 5)
				board.shake = 5


func _input(event: InputEvent) -> void:
	if closing or event.is_echo():
		return
	if event.is_action_pressed("fullscreen"):
		var fullscreen: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen
			else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if phase == "play" and not paused:
			for index: int in range(Catalog.SITES.size()):
				if event.position.distance_to(Catalog.SITES[index]) < 43:
					selected_site = index
					get_viewport().set_input_as_handled()
					return
		return
	_handle_actions(event)


func _handle_actions(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	if paused:
		if event.is_action_pressed("cancel") or event.is_action_pressed("ui_accept"):
			_pause()
		elif event.is_action_pressed("sell"):
			_title_return()
	elif phase == "title":
		if event.is_action_pressed("ui_accept"):
			start_game()
		elif event.is_action_pressed("cancel"):
			_close()
	elif phase in ["win", "lose"]:
		if event.is_action_pressed("ui_accept"):
			start_game()
		elif event.is_action_pressed("cancel"):
			_title_return()
	elif phase == "play":
		_play_input(event)
	get_viewport().set_input_as_handled()


func _play_input(event: InputEvent) -> void:
	for action: String in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		if event.is_action_pressed(action, false, true) and selection_delay <= 0:
			selected_site = posmod(selected_site + (-1 if action in ["ui_left", "ui_up"] else 1),
				Catalog.SITES.size())
			selection_delay = 0.16 if event is InputEventJoypadMotion else 0.0
			return
	if event.is_action_pressed("ui_accept"):
		_build()
	elif event.is_action_pressed("tower_next"):
		_select_kind(selected_kind + 1)
	elif event.is_action_pressed("wave"):
		_wave()
	elif event.is_action_pressed("faster"):
		_speed()
	elif event.is_action_pressed("upgrade"):
		_upgrade()
	elif event.is_action_pressed("sell"):
		_sell()
	elif event.is_action_pressed("cancel"):
		_pause()


func stop_audio() -> void:
	sound.shutting_down = true
	sound.stop_all()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_close()


func _close() -> void:
	if closing:
		return
	closing = true
	await sound.shutdown()
	get_tree().quit()
