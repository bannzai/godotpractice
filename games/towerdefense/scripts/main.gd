extends Control
## 入力と画面を結ぶ。資金・敵・進行状態はautoloadのRunだけが所有する。
## 入力ハンドラと演出は操作のたびに結果を発生させるため非冪等。

enum TutorialStep { SITE, TOWER, BUILD, WAVE, DONE }

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
var advance_button: Button
var tutorial_panel: Panel
var tutorial_text: Label
var tutorial_skip_button: Button
var tutorial_active: bool = false
var tutorial_step: int = TutorialStep.DONE


func _ready() -> void:
	print("towerdefense boot")
	Bindings.configure()
	theme = Ui.make_theme()
	run = get_node("/root/Run")
	sound = get_node("/root/Sound")
	run.load_best()
	run.load_tutorial()
	get_tree().auto_accept_quit = false
	board = Board.new()
	add_child(board)
	Ui.tapestry_overlay(self)
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
	if is_instance_valid(advance_button):
		var pulse: float = (sin(Time.get_ticks_msec() * 0.006) + 1.0) * 0.5
		advance_button.modulate = Color.WHITE.lerp(Ui.GOLD, 0.16 + pulse * 0.18)


func _show_phase() -> void:
	phase = run.phase
	paused = false
	advance_button = null
	board.visible = phase != "map"
	screen = _new_screen()
	match phase:
		"title":
			_title()
		"map":
			_map()
		"play":
			_play_ui()
		"win", "lose":
			_result()
	var track_name: String = "stage" if phase == "play" else phase
	if track_name == "map" and not ResourceLoader.exists("res://assets/audio/map.wav"):
		track_name = "title"
	sound.track(track_name)
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
	var landscape: TextureRect = Ui.texture(
		screen, "res://assets/tapestry/landscape.png", Rect2(0, 0, 1280, 720)
	)
	landscape.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	Ui.panel(
		screen,
		Rect2(32, 42, 700, 636),
		Ui.scroll_box(Color(Ui.PAPER, 0.18), Ui.GOLD),
	)
	Ui.label(screen, "月夜の森から、夜明けの砦へ。", Vector2(66, 76), 21, Ui.PAPER)
	Ui.label(screen, "一本の道に\n十の襲来を縫い留める", Vector2(64, 122), 42, Ui.PAPER)
	Ui.texture(screen, "res://assets/tapestry/towers.png", Rect2(62, 295, 640, 345))
	Ui.label(screen, "森の入口　──　川辺の古道　──　灯砦", Vector2(66, 642), 18, Ui.GOLD)
	Ui.panel(screen, Rect2(770, 58, 470, 604))
	Ui.label(screen, "刺繍戦記", Vector2(810, 92), 19, Ui.THREAD_RED)
	Ui.label(screen, "黄昏の灯砦", Vector2(806, 138), 54, Ui.INK)
	Ui.label(screen, "曲がる道。四つの塔。十の襲来。\n一針ずつ、森の夜を守り抜く。",
		Vector2(810, 244), 22)
	advance_button = Ui.button(screen, "戦の絵巻をひらく  ·  Enter / A",
		Rect2(808, 382, 394, 68), open_map)
	Ui.label(screen, "最高評価  " + "★".repeat(int(run.best.stars))
		+ "☆".repeat(3 - int(run.best.stars)), Vector2(812, 500), 21, Ui.THREAD_RED)
	Ui.label(screen, "次にすること", Vector2(812, 548), 17, Ui.MUTED)
	Ui.label(screen, "絵巻を開き、守る戦場を選ぶ", Vector2(812, 578), 20, Ui.INK)
	Ui.label(screen, "Enter / A または巻物を選択", Vector2(812, 615), 16, Ui.MUTED)


func open_map() -> void:
	run.to_map()
	_reset_board()
	_show_phase()


func _map() -> void:
	Ui.panel(screen, Rect2(36, 30, 1208, 660))
	Ui.label(screen, "夜明けまでの長いタペストリー", Vector2(78, 62), 35, Ui.GOLD)
	Ui.label(screen, "左から右へ縫い継がれた森をたどり、最後の灯砦を守る。",
		Vector2(80, 112), 19)
	var landscape_path := "res://assets/tapestry/landscape.png"
	if ResourceLoader.exists(landscape_path):
		var landscape: TextureRect = Ui.texture(
			screen, landscape_path, Rect2(78, 153, 1124, 320)
		)
		landscape.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	else:
		Ui.texture(screen, "res://assets/keyart.svg", Rect2(78, 153, 1124, 320))
	Ui.label(screen, "森の入口", Vector2(102, 438), 18, Ui.MUTED)
	Ui.label(screen, "───  川辺の古道  ───", Vector2(432, 438), 18, Ui.MUTED)
	Ui.label(screen, "灯砦", Vector2(1080, 438), 18, Ui.GOLD)
	Ui.label(screen, "選べる戦場", Vector2(78, 502), 17, Ui.GOLD)
	Ui.label(screen, "第一巻　森を渡る十の襲来", Vector2(78, 535), 25)
	advance_button = Ui.button(screen, "この巻をたどる  ·  Enter / A",
		Rect2(748, 516, 420, 66), start_game)
	Ui.label(screen, "Esc / Start で表紙へ戻る", Vector2(894, 620), 16, Ui.MUTED)


func start_game() -> void:
	run.new_run()
	selected_site = 0
	selected_kind = 0
	gold_display = run.gold
	tutorial_active = not run.tutorial_seen
	tutorial_step = TutorialStep.SITE if tutorial_active else TutorialStep.DONE
	_reset_board()
	_show_phase()


func _reset_board() -> void:
	board.queue_free()
	board = Board.new()
	add_child(board)
	move_child(board, 0)


func _play_ui() -> void:
	Ui.panel(screen, Rect2(18, 16, 932, 66))
	Ui.label(screen, "戦況の巻物", Vector2(37, 29), 25, Ui.GOLD)
	hud = Ui.label(screen, "", Vector2(257, 30), 24)
	Ui.texture(screen, "res://assets/ui/heart.svg", Rect2(216, 32, 28, 30))
	Ui.panel(screen, Rect2(970, 16, 292, 688))
	Ui.label(screen, "四つの紋章盾", Vector2(992, 33), 27, Ui.GOLD)
	Ui.label(screen, "盾を選び、光る地点へ", Vector2(992, 79), 17, Ui.MUTED)
	tower_buttons.clear()
	for index: int in range(Catalog.TOWERS.size()):
		var kind: String = Catalog.TOWERS.keys()[index]
		var data: Dictionary = Catalog.TOWERS[kind]
		var button: Button = Ui.button(screen, "%s  %d\n%s" % [data.name, data.cost, data.role],
			Rect2(991, 112 + index * 70, 250, 62), _select_kind.bind(index))
		button.add_theme_font_size_override("font_size", 17)
		button.set_meta("tower_kind", kind)
		button.tooltip_text = "%sの紋章盾：%s" % [data.name, data.role]
		button.add_theme_stylebox_override("normal", Ui.crest_box(data.color))
		tower_buttons.append(button)
	detail = Ui.label(screen, "", Vector2(991, 395), 15)
	build_button = Ui.button(screen, "建設  ·  Enter / A", Rect2(991, 497, 250, 45), _build)
	build_button.add_theme_font_size_override("font_size", 14)
	upgrade_button = Ui.button(screen, "", Rect2(991, 550, 250, 45), _upgrade)
	upgrade_button.add_theme_font_size_override("font_size", 14)
	sell_button = Ui.button(screen, "", Rect2(991, 603, 250, 39), _sell)
	sell_button.add_theme_font_size_override("font_size", 14)
	Ui.label(screen, "Tab / RB で紋章盾を切替", Vector2(995, 663), 15, Ui.MUTED)
	Ui.panel(screen, Rect2(18, 609, 932, 95))
	wave_button = Ui.button(screen, "", Rect2(32, 622, 245, 45), _wave)
	wave_button.add_theme_font_size_override("font_size", 14)
	speed_button = Ui.button(screen, "", Rect2(288, 622, 145, 45), _speed)
	Ui.button(screen, "休止  Esc", Rect2(444, 622, 124, 45), _pause)
	preview = Ui.label(screen, "", Vector2(590, 620), 16, Ui.GOLD)
	status = Ui.label(screen, "", Vector2(31, 568), 17, Ui.GOLD)
	notice = Ui.label(screen, "", Vector2(205, 94), 28, Ui.GOLD)
	notice.add_theme_color_override("font_outline_color", Ui.INK)
	notice.add_theme_constant_override("outline_size", 8)
	if tutorial_active:
		_create_tutorial_panel()
	else:
		_notify("光る地点を選び、紋章盾の塔を置いて襲来を始めよう", 4)


func _update_hud(delta: float) -> void:
	gold_display = move_toward(gold_display, float(run.gold), delta * 360)
	hud.text = "灯  %02d     金貨  %03d     襲来  %02d / %02d" % [
		run.hp, int(gold_display), run.wave, Catalog.WAVES.size()]
	var kind: String = Catalog.TOWERS.keys()[selected_kind]
	var tower: Dictionary = run.tower_at(selected_site)
	var stats: Dictionary = Catalog.tower_stats(kind, 1)
	var cost: int = int(Catalog.TOWERS[kind].cost)
	if tower.is_empty():
		detail.text = "地点 %02d　空き\n%s　段階 1\n威力 %d　射程 %d　間隔 %.2f秒\n建設後の金貨 %d" % [
			selected_site + 1, stats.name, stats.damage, stats.range, stats.interval,
			maxi(0, run.gold - cost)]
	else:
		stats = Catalog.tower_stats(tower.kind, tower.level)
		var next_stats: Dictionary = Catalog.tower_stats(tower.kind, tower.level + 1)
		var sale_total: int = run.gold + run.sell_price(selected_site)
		if next_stats.is_empty():
			detail.text = "地点 %02d　%s　段階 3\n威力 %d　射程 %d　間隔 %.2f秒\n強化は最終段階\n売却後の金貨 %d" % [
				selected_site + 1, stats.name, stats.damage, stats.range, stats.interval,
				sale_total]
		else:
			var upgrade_total: int = run.gold - run.upgrade_price(selected_site)
			var forecast := ("地点 %02d　%s　段階 %d\n現在 威力 %d / 射程 %d\n"
				+ "強化後 威力 %d / 射程 %d\n間隔 %.2f秒 → %.2f秒\n"
				+ "強化後 金貨 %d / 売却後 %d")
			detail.text = forecast % [
				selected_site + 1, stats.name, tower.level, stats.damage, stats.range,
				next_stats.damage, next_stats.range, stats.interval, next_stats.interval,
				maxi(0, upgrade_total), sale_total]
	var build_reason: String = _build_reason()
	build_button.disabled = not build_reason.is_empty()
	build_button.text = "建設 %d  ·  Enter / A" % cost if build_reason.is_empty() \
		else "建設不可：" + build_reason
	var price: int = run.upgrade_price(selected_site)
	var upgrade_reason: String = _upgrade_reason()
	upgrade_button.disabled = not upgrade_reason.is_empty()
	upgrade_button.text = "強化 %d  ·  U / LB" % price if upgrade_reason.is_empty() \
		else "強化不可：" + upgrade_reason
	var sell_reason: String = _sell_reason()
	sell_button.disabled = not sell_reason.is_empty()
	sell_button.text = "売却 +%d  ·  X / B" % run.sell_price(selected_site) \
		if sell_reason.is_empty() else "売却不可：" + sell_reason
	var wave_reason: String = _wave_reason()
	wave_button.disabled = not wave_reason.is_empty()
	wave_button.text = "防衛中　残り %d 体" % (run.enemies.size() + run.spawn_remaining()) if run.active \
		else ("襲来を開始  ·  Space / Y" if wave_reason.is_empty() else "開始不可：" + wave_reason)
	speed_button.text = "%d倍速  ·  F / X" % run.speed
	var guide_pulse: float = (sin(Time.get_ticks_msec() * 0.009) + 1.0) * 0.5
	for index: int in range(tower_buttons.size()):
		var button: Button = tower_buttons[index]
		var button_kind: String = Catalog.TOWERS.keys()[index]
		button.add_theme_stylebox_override(
			"normal", Ui.crest_box(Catalog.TOWERS[button_kind].color, selected_kind == index)
		)
		button.modulate = Ui.GOLD if selected_kind == index else Color.WHITE
	build_button.modulate = Color.WHITE
	wave_button.modulate = Color.WHITE
	if tutorial_active:
		match tutorial_step:
			TutorialStep.TOWER:
				for button: Button in tower_buttons:
					button.modulate = button.modulate.lerp(Ui.GOLD, 0.2 + guide_pulse * 0.25)
			TutorialStep.BUILD:
				build_button.modulate = Color.WHITE.lerp(Ui.GOLD, 0.22 + guide_pulse * 0.28)
			TutorialStep.WAVE:
				wave_button.modulate = Color.WHITE.lerp(Ui.GOLD, 0.22 + guide_pulse * 0.28)
	var next: int = mini(run.wave, Catalog.WAVES.size() - 1)
	var names: Array[String] = []
	for group: Dictionary in Catalog.WAVES[next].groups:
		names.append("%s×%d" % [Catalog.ENEMIES[group.kind].name, group.count])
	preview.text = "次の敵：" + Catalog.WAVES[next].name + "\n" + " / ".join(names)
	if run.wave >= Catalog.WAVES.size():
		preview.text = "最終襲来：" + Catalog.WAVES[-1].name + "\n全ての敵を防げば、夜明けが来る。"
	preview.add_theme_font_size_override("font_size", 14 if names.size() > 3 else 16)
	if tutorial_active:
		# 手順本文は上の指南巻物だけに置き、下部の戦況欄へ重複させない。
		status.text = ""
	elif run.active:
		status.text = "いま：防衛中。空き地点への建設と塔の強化はいつでも可能"
	elif run.towers.is_empty():
		status.text = "次：光る地点と紋章盾を選び、最初の塔を建設"
	else:
		status.text = "次：敵の予告を読み、襲来を開始"
	notice_time = maxf(0, notice_time - delta)
	notice.modulate.a = minf(1, notice_time)


func _build_reason() -> String:
	if paused:
		return "休止中です"
	if tutorial_active:
		if tutorial_step == TutorialStep.SITE:
			return "先に地点を選んでください"
		if tutorial_step == TutorialStep.TOWER:
			return "先に紋章盾を選んでください"
		if tutorial_step == TutorialStep.WAVE:
			return "先に襲来を開始してください"
	if not run.tower_at(selected_site).is_empty():
		return "地点に塔があります"
	var kind: String = Catalog.TOWERS.keys()[selected_kind]
	var shortage: int = int(Catalog.TOWERS[kind].cost) - run.gold
	return "あと%d金貨必要" % shortage if shortage > 0 else ""


func _upgrade_reason() -> String:
	if paused:
		return "休止中です"
	if tutorial_active:
		return "指南完了後に使えます"
	var tower: Dictionary = run.tower_at(selected_site)
	if tower.is_empty():
		return "塔がありません"
	var price: int = run.upgrade_price(selected_site)
	if price == 0:
		return "最終段階です"
	var shortage: int = price - run.gold
	return "あと%d金貨必要" % shortage if shortage > 0 else ""


func _sell_reason() -> String:
	if paused:
		return "休止中です"
	if tutorial_active:
		return "指南完了後に使えます"
	return "塔がありません" if run.tower_at(selected_site).is_empty() else ""


func _wave_reason() -> String:
	if paused:
		return "休止中です"
	if tutorial_active and tutorial_step != TutorialStep.WAVE:
		return _tutorial_wave_reason()
	if run.active:
		return "襲来が進行中です"
	if run.wave >= Catalog.WAVES.size():
		return "全ての襲来が終了しました"
	return ""


func _tutorial_wave_reason() -> String:
	match tutorial_step:
		TutorialStep.SITE:
			return "先に地点を選んでください"
		TutorialStep.TOWER:
			return "先に紋章盾を選んでください"
		TutorialStep.BUILD:
			return "先に塔を建設してください"
	return ""


func _create_tutorial_panel() -> void:
	tutorial_panel = Ui.panel(screen, Rect2(182, 96, 670, 118))
	tutorial_text = Ui.label(tutorial_panel, "", Vector2(18, 13), 17, Ui.GOLD)
	tutorial_skip_button = Ui.button(tutorial_panel, "指南を省く  ·  Q / Back",
		Rect2(432, 68, 220, 36), _skip_tutorial)
	tutorial_skip_button.add_theme_font_size_override("font_size", 14)
	_refresh_tutorial_panel()


func _refresh_tutorial_panel() -> void:
	if not is_instance_valid(tutorial_panel):
		return
	tutorial_panel.visible = tutorial_active
	if tutorial_active:
		tutorial_text.text = _tutorial_status()


func _tutorial_status() -> String:
	match tutorial_step:
		TutorialStep.SITE:
			return "一針目：光る空き地点を選ぶ\n方向キー / 左スティック、または地点をクリック"
		TutorialStep.TOWER:
			return "二針目：右の紋章盾から塔を選ぶ\n盾をクリック、または Tab / RB で切替"
		TutorialStep.BUILD:
			return "三針目：建設後の残金と塔を確かめて建設\nEnter / A、または建設ボタン"
		TutorialStep.WAVE:
			return "結び：次の敵を読んで襲来を開始\nSpace / Y、または襲来ボタン"
	return ""


func _advance_tutorial(completed_step: int) -> void:
	if not tutorial_active or tutorial_step != completed_step:
		return
	if completed_step == TutorialStep.WAVE:
		_finish_tutorial(false)
		return
	tutorial_step += 1
	_refresh_tutorial_panel()


func _skip_tutorial() -> void:
	_finish_tutorial(true)


func _finish_tutorial(skipped: bool) -> void:
	if not tutorial_active:
		return
	tutorial_active = false
	tutorial_step = TutorialStep.DONE
	run.mark_tutorial_seen()
	_refresh_tutorial_panel()
	_notify("指南を閉じました。戦況の巻物はいつでも読めます" if skipped \
		else "指南完了。灯砦の防衛を始めます", 4)


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
	advance_button = Ui.button(screen, "もう一度  ·  Enter / A",
		Rect2(354, 462, 280, 60), start_game)
	Ui.button(screen, "タイトル  ·  Esc / Start", Rect2(653, 462, 280, 60), _title_return)
	Ui.label(screen, "最高評価は自動保存されます", Vector2(491, 551), 17, Ui.MUTED)


func _title_return() -> void:
	run.to_title()
	_reset_board()
	_show_phase()


func _select_kind(index: int) -> void:
	selected_kind = posmod(index, Catalog.TOWERS.size())
	_advance_tutorial(TutorialStep.TOWER)


func _select_site(index: int) -> void:
	selected_site = posmod(index, Catalog.SITES.size())
	_advance_tutorial(TutorialStep.SITE)


func _build() -> void:
	if paused:
		return
	var reason: String = _build_reason()
	if not reason.is_empty():
		_notify("建設できません：" + reason)
		return
	if run.build(selected_site, Catalog.TOWERS.keys()[selected_kind]):
		_advance_tutorial(TutorialStep.BUILD)


func _upgrade() -> void:
	if paused:
		return
	var reason: String = _upgrade_reason()
	if not reason.is_empty():
		_notify("強化できません：" + reason)
		return
	run.upgrade(selected_site)


func _sell() -> void:
	if paused:
		return
	var reason: String = _sell_reason()
	if not reason.is_empty():
		_notify("売却できません：" + reason)
		return
	run.sell(selected_site)


func _wave() -> void:
	if paused:
		return
	var reason: String = _wave_reason()
	if not reason.is_empty():
		_notify("襲来を始められません：" + reason)
		return
	if run.start_wave():
		_advance_tutorial(TutorialStep.WAVE)


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
					_select_site(index)
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
			open_map()
		elif event.is_action_pressed("cancel"):
			_close()
	elif phase == "map":
		if event.is_action_pressed("ui_accept"):
			start_game()
		elif event.is_action_pressed("cancel"):
			_title_return()
	elif phase in ["win", "lose"]:
		if event.is_action_pressed("ui_accept"):
			start_game()
		elif event.is_action_pressed("cancel"):
			_title_return()
	elif phase == "play":
		_play_input(event)
	get_viewport().set_input_as_handled()


func _play_input(event: InputEvent) -> void:
	if tutorial_active and event.is_action_pressed("tutorial_skip"):
		_skip_tutorial()
		return
	for action: String in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		if event.is_action_pressed(action, false, true) and selection_delay <= 0:
			_select_site(selected_site + (-1 if action in ["ui_left", "ui_up"] else 1))
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
