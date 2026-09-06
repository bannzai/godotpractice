extends Control
## 画面と入力の制御。戦闘・進行はCampaignに集約する。

const UI := preload("res://scripts/ui.gd")
const Board := preload("res://scripts/board.gd")
const Backdrop := preload("res://scripts/backdrop.gd")
const CombatView := preload("res://scripts/combat_view.gd")
const Effects := preload("res://scripts/effects.gd")
const JOBS: Dictionary = {
	"sword": "剣士", "lance": "槍騎士", "axe": "斧戦士", "bow": "弓使い", "healer": "祈り手"
}

var campaign: Node
var screen: Control
var sidebar: Control
var board: Node2D
var effects: Control
var sound: Node
var selected: String = ""
var target: String = ""
var cursor := Vector2i(2, 5)
var busy: bool = false
var first_focus: Button
var notice: String = ""
var _closing: bool = false
var _enemy_running: bool = false


func _ready() -> void:
	print("tactics boot")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	campaign = get_node("/root/Campaign")
	theme = UI.make_theme()
	get_tree().auto_accept_quit = false
	add_child(Backdrop.new())
	if ResourceLoader.exists("res://scripts/soundscape.gd"):
		sound = load("res://scripts/soundscape.gd").new()
		add_child(sound)
	effects = Effects.new()
	add_child(effects)
	effects.z_index = 20
	show_title()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit()


func stop_audio() -> void:
	if is_instance_valid(sound):
		sound.stop_audio()


func request_quit() -> void:
	if _closing:
		return
	_closing = true
	stop_audio()
	await get_tree().create_timer(0.2, true, false, true).timeout
	get_tree().quit()


func _music(cue: String) -> void:
	if is_instance_valid(sound):
		sound.play_music(cue)


func _sfx(cue: String) -> void:
	if is_instance_valid(sound):
		sound.play_sfx(cue)


func _reset_screen() -> void:
	if is_instance_valid(screen):
		remove_child(screen)
		screen.queue_free()
	screen = Control.new()
	screen.size = Vector2(1280, 720)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	board = null
	sidebar = null
	first_focus = null


func show_title() -> void:
	campaign.screen = "title"
	selected = ""
	target = ""
	busy = false
	_reset_screen()
	_music("title")
	UI.art(screen, "backgrounds/keyart.svg", Rect2(0, 0, 1280, 720))
	UI.panel(screen, Rect2(50, 86, 505, 554), Color(0.05, 0.11, 0.17, 0.94))
	UI.art(screen, "ui/crest.svg", Rect2(84, 112, 56, 56))
	UI.label(screen, "五人の誓い、三つの戦場", Rect2(154, 124, 360, 36), 22, UI.GOLD)
	UI.label(screen, "暁の境界", Rect2(83, 192, 440, 100), 64)
	UI.label(screen, "失われた道に、もう一度灯を。", Rect2(87, 301, 440, 38), 22, UI.MUTED)
	UI.label(screen, "地形を読み、仲間を守る戦術譚", Rect2(87, 342, 440, 38), 20)
	first_focus = UI.button(screen, "新しい旅を始める", Rect2(86, 406, 428, 54), start_game)
	var resume: Button = UI.button(screen, "記録から再開", Rect2(86, 474, 205, 48), resume_game)
	resume.disabled = not campaign.has_save()
	UI.button(screen, "遊び方", Rect2(305, 474, 209, 48), show_help)
	UI.button(screen, "終了", Rect2(86, 542, 428, 44), request_quit)
	UI.label(
		screen, "矢印 / 左スティック  選択     決定 Enter / A     取消 Esc / B", Rect2(64, 665, 1150, 32), 18
	)
	first_focus.grab_focus()


func show_help() -> void:
	campaign.screen = "help"
	_reset_screen()
	UI.panel(screen, Rect2(180, 60, 920, 595))
	UI.label(screen, "旅の手引き", Rect2(220, 82, 800, 60), 36, UI.GOLD)
	var text: String = "味方を選ぶ → 青いマスへ移動 → 相手を選んで予測 → 戦闘を確定\n\n"
	text += "剣は斧に、斧は槍に、槍は剣に有利。速さの差で追撃。\n"
	text += "弓は２マス先だけに攻撃。祈り手は隣の味方を回復します。\n"
	text += "森・山・砦は守りに有利。水は通行不可。移動は取消できます。\n"
	text += "全員行動、または E / Y で敵の番。W / X で待機、I / RB で薬。\n"
	text += "主人公が倒れると敗北。他の仲間の戦死は次の章にも残ります。\n"
	text += "敵全滅 → ボス撃破 → 目的地への到達、の全３章です。\n"
	text += "S / Start で保存してタイトル。F11 で全画面切替。\n"
	text += "マウスはマスとボタンをクリック。パッドは方向キーにも対応。"
	UI.label(screen, text, Rect2(222, 156, 850, 420), 21)
	first_focus = UI.button(screen, "タイトルへ", Rect2(420, 578, 440, 48), show_title)
	first_focus.grab_focus()


func start_game() -> void:
	var saved: bool = campaign.new_game()
	_begin_stage()
	if not saved:
		notice = campaign.save_error
		_refresh_sidebar()


func resume_game() -> void:
	if campaign.load_game():
		_begin_stage()
	else:
		notice = "記録を読み込めませんでした"
		effects.banner(notice, UI.CORAL)


func _begin_stage() -> void:
	campaign.screen = "play"
	selected = ""
	target = ""
	busy = false
	notice = ""
	var hero: Dictionary = campaign.unit_by_id("hero")
	cursor = Vector2i(hero.x, hero.y)
	show_play()
	effects.banner("第 %d 章  %s" % [campaign.stage_index + 1, campaign.stage().name])
	if not campaign.outcome.is_empty():
		show_result()
	elif campaign.phase == "enemy":
		_enemy_turn()


func show_play() -> void:
	_reset_screen()
	_music("stage")
	UI.panel(screen, Rect2(34, 22, 1212, 68), Color(0.05, 0.11, 0.17, 0.97))
	UI.label(screen, "暁の境界", Rect2(56, 28, 225, 54), 29, UI.GOLD)
	UI.label(
		screen,
		"第 %d 章  %s" % [campaign.stage_index + 1, campaign.stage().name],
		Rect2(283, 30, 520, 32),
		23
	)
	UI.label(screen, campaign.stage().objective_text, Rect2(285, 60, 510, 25), 16, UI.MUTED)
	board = Board.new()
	screen.add_child(board)
	board.set_selection(selected, cursor)
	UI.label(screen, "青：移動範囲    赤：移動後を含む射程    輪：味方 / 敵", Rect2(62, 651, 745, 26), 18)
	_refresh_sidebar()


func _unit(id: String) -> Dictionary:
	for unit: Dictionary in campaign.units:
		if unit.id == id:
			return unit
	return {}


func _refresh_sidebar() -> void:
	if is_instance_valid(sidebar):
		screen.remove_child(sidebar)
		sidebar.queue_free()
	sidebar = Control.new()
	sidebar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(sidebar)
	UI.panel(sidebar, Rect2(805, 108, 438, 536), Color(0.05, 0.11, 0.17, 0.96))
	var phase_name: String = "自軍フェーズ" if campaign.phase == "player" else "敵軍フェーズ"
	UI.label(
		sidebar,
		"%s  ·  %d ターン" % [phase_name, campaign.turn],
		Rect2(827, 119, 390, 34),
		24,
		UI.GOLD
	)
	var current: Dictionary = _unit(selected)
	if current.is_empty():
		current = campaign.unit_at(cursor)
	if current.is_empty():
		UI.label(sidebar, "仲間を選び、道を拓こう", Rect2(827, 186, 390, 40), 25)
		UI.label(
			sidebar, "青い輪は味方、赤い輪は敵。\n地形と兵種の相性が勝敗を分けます。", Rect2(827, 240, 390, 75), 18, UI.MUTED
		)
	else:
		_unit_panel(current)
	if not target.is_empty():
		_forecast()
	else:
		_actions(current)
	var status: Label = UI.label(sidebar, notice, Rect2(825, 651, 410, 56), 16, UI.GOLD)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for button: Node in sidebar.find_children("*", "Button", true, false):
		button.focus_mode = Control.FOCUS_NONE
	var ground: Dictionary = BattleData.terrain(cursor, campaign.stage().map)
	var cost: String = str(ground.cost) if ground.cost < 99 else "通行不可"
	UI.label(
		sidebar,
		(
			"%s  /  移動 %s  /  守備 +%d  /  回避 +%d%%"
			% [ground.name, cost, ground.defense, ground.evasion]
		),
		Rect2(62, 681, 736, 28),
		17,
		UI.GOLD
	)
	if is_instance_valid(board):
		board.set_selection(selected, cursor)


func _unit_panel(unit: Dictionary) -> void:
	UI.art(sidebar, "units/%s.svg" % Board.art_kind(unit), Rect2(830, 165, 120, 145))
	UI.label(sidebar, "%s  Lv.%d" % [unit.name, unit.level], Rect2(963, 172, 255, 34), 25)
	UI.label(sidebar, JOBS[unit.job], Rect2(963, 211, 255, 28), 20, UI.JADE)
	UI.label(sidebar, "HP  %d / %d" % [unit.hp, unit.max_hp], Rect2(963, 246, 255, 28), 20)
	UI.meter(sidebar, Rect2(963, 282, 250, 10), unit.hp, unit.max_hp)
	UI.label(
		sidebar,
		"力 %d    守 %d    速 %d    技 %d" % [unit.strength, unit.defense, unit.speed, unit.skill],
		Rect2(828, 318, 385, 30),
		20
	)
	UI.label(
		sidebar,
		"移動 %d    経験 %d / 100    薬 %d" % [unit.move, unit.xp, unit.items],
		Rect2(828, 353, 390, 30),
		18,
		UI.MUTED
	)


func _actions(unit: Dictionary) -> void:
	if not selected.is_empty() and not unit.is_empty():
		UI.label(sidebar, "移動後、射程内の相手を選択", Rect2(828, 398, 390, 30), 19, UI.JADE)
		UI.button(sidebar, "待機  W / X", Rect2(828, 443, 182, 44), wait_selected)
		UI.button(sidebar, "薬  I / RB", Rect2(1024, 443, 193, 44), item_selected)
	else:
		UI.label(sidebar, "剣 ＞ 斧 ＞ 槍 ＞ 剣\n弓：距離２  /  祈り：隣の味方", Rect2(828, 397, 390, 76), 21, UI.JADE)
	UI.button(sidebar, "フェーズ終了  E / Y", Rect2(828, 504, 388, 44), end_phase)
	UI.button(sidebar, "保存してタイトル  S / Start", Rect2(828, 566, 388, 44), save_to_title)


func _forecast() -> void:
	var prediction: Dictionary = campaign.preview(selected, target)
	if prediction.is_empty():
		target = ""
		return
	var opponent: Dictionary = _unit(target)
	UI.label(sidebar, "戦闘予測  →  " + opponent.name, Rect2(828, 395, 390, 32), 23, UI.GOLD)
	var summary: String = (
		"回復  +%d" % prediction.heal
		if prediction.heal > 0
		else "与ダメ %d × %d   命中 %d%%" % [prediction.damage, prediction.strikes, prediction.hit]
	)
	UI.label(sidebar, summary, Rect2(828, 437, 390, 30), 22)
	UI.label(
		sidebar,
		(
			"反撃 %d × %d  /  命中 %d%%  /  必殺 %d%%"
			% [
				prediction.counter_damage,
				prediction.counter_strikes,
				prediction.counter_hit,
				prediction.critical
			]
		),
		Rect2(828, 479, 390, 30),
		16,
		UI.CORAL
	)
	UI.button(sidebar, "確定  Enter / A", Rect2(828, 527, 388, 44), confirm_attack)
	UI.button(sidebar, "取消  Esc / B", Rect2(828, 581, 388, 40), cancel_selection)


# 入力された移動・行動を一回だけ進行に反映する。
func choose_cell(cell: Vector2i) -> void:
	if busy or campaign.screen != "play" or campaign.phase != "player":
		return
	if cell.x < 0 or cell.y < 0 or cell.x >= 16 or cell.y >= 12:
		return
	cursor = cell
	var clicked: Dictionary = campaign.unit_at(cell)
	if selected.is_empty():
		if not clicked.is_empty() and clicked.team == "player" and not clicked.acted:
			selected = clicked.id
			notice = "青いマスへ移動、赤い射程で相手を選択"
			_sfx("confirm")
	elif not clicked.is_empty() and clicked.id != selected:
		if not campaign.preview(selected, clicked.id).is_empty():
			target = clicked.id
			_sfx("confirm")
		elif clicked.team == "player" and not clicked.acted:
			campaign.undo_move(selected)
			selected = clicked.id
			target = ""
	elif target.is_empty():
		var actor: Node2D = board.actors.get(selected)
		var previous: Vector2 = actor.position if actor != null else Vector2.ZERO
		if campaign.move_unit(selected, cell):
			busy = true
			if actor != null:
				actor.play_pose("move")
				var tween: Tween = actor.create_tween()
				actor.position = previous
				tween.tween_property(actor, "position", Board.center(cell) + Vector2(0, -4), 0.3)
				await tween.finished
			busy = false
			notice = "相手を選んで攻撃 / 待機 / 薬。取消で移動を戻せます"
	_refresh_sidebar()
	_check_progress()


func cancel_selection() -> void:
	if busy:
		return
	if not target.is_empty():
		target = ""
	elif not selected.is_empty():
		campaign.undo_move(selected)
		var restored: Dictionary = _unit(selected)
		cursor = Vector2i(restored.x, restored.y)
		selected = ""
	_refresh_sidebar()


# 戦闘確定ごとに抽選とアニメーションを一度進める。
func confirm_attack() -> void:
	if busy or target.is_empty():
		return
	busy = true
	var initial_hp: Dictionary = _health_snapshot()
	var events: Array = campaign.attack(selected, target)
	target = ""
	await _animate_events(events, initial_hp)
	selected = ""
	busy = false
	_refresh_sidebar()
	_check_progress()


func wait_selected() -> void:
	if busy or selected.is_empty() or campaign.phase != "player":
		return
	campaign.wait_unit(selected)
	selected = ""
	target = ""
	_refresh_sidebar()
	_check_progress()


func item_selected() -> void:
	if busy or selected.is_empty() or campaign.phase != "player":
		return
	busy = true
	var events: Array = campaign.use_item(selected)
	if events.is_empty():
		busy = false
		notice = "HPが満タン、または薬を持っていません"
		_refresh_sidebar()
		return
	await _animate_events(events)
	selected = ""
	target = ""
	busy = false
	_refresh_sidebar()
	_check_progress()


func end_phase() -> void:
	if busy or campaign.phase != "player":
		return
	selected = ""
	target = ""
	campaign.end_player_phase()
	_check_progress()


func save_to_title() -> void:
	if busy:
		return
	if not selected.is_empty():
		campaign.undo_move(selected)
	if campaign.save_game():
		show_title()
	else:
		notice = "保存できませんでした。ゲームは続けられます"
		_refresh_sidebar()


func _check_progress() -> void:
	if not campaign.outcome.is_empty():
		show_result()
	elif campaign.phase == "enemy" and not _enemy_running:
		_enemy_turn()


# 敵の手番を１体ずつ表示し、モデルが自軍へ戻すまで順に進める。
func _enemy_turn() -> void:
	_enemy_running = true
	busy = true
	_refresh_sidebar()
	effects.banner("敵軍フェーズ", UI.CORAL)
	await get_tree().create_timer(0.95).timeout
	while campaign.phase == "enemy" and campaign.outcome.is_empty():
		var initial_hp: Dictionary = _health_snapshot()
		var events: Array = campaign.enemy_step()
		await _animate_events(events, initial_hp)
		if is_instance_valid(board):
			board.sync()
		await get_tree().create_timer(0.16).timeout
	busy = false
	_enemy_running = false
	if not campaign.outcome.is_empty():
		show_result()
	else:
		effects.banner("自軍フェーズ  ·  第 %d ターン" % campaign.turn)
		_refresh_sidebar()


# イベントごとの表示時間を確保し、判定済みの結果を順番に再生する。
func _health_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for unit: Dictionary in campaign.units:
		result[unit.id] = unit.hp
	return result


func _animate_events(events: Array, initial_hp: Dictionary = {}) -> void:
	if events.is_empty():
		return
	_music("battle")
	var cutin: Control
	for event: Dictionary in events:
		if event.kind == "attack" and cutin == null:
			cutin = CombatView.new()
			add_child(cutin)
			cutin.setup(campaign, event.actor, event.target, initial_hp)
			await get_tree().create_timer(0.16).timeout
		if cutin != null:
			cutin.present(event)
		var actor: Node2D = board.actors.get(str(event.get("actor", "")))
		var victim: Node2D = board.actors.get(str(event.get("target", "")))
		var point: Vector2 = victim.position if victim != null else Vector2(600, 320)
		match event.kind:
			"move":
				if actor != null:
					actor.play_pose("move")
					var unit: Dictionary = _unit(event.actor)
					var motion: Tween = actor.create_tween()
					motion.tween_property(
						actor,
						"position",
						Board.center(Vector2i(unit.x, unit.y)) + Vector2(0, -4),
						0.24
					)
					await motion.finished
			"attack":
				if actor != null:
					actor.play_pose("attack")

				_sfx("attack")
				await get_tree().create_timer(0.22).timeout
			"hit":
				if victim != null:
					victim.play_pose("hurt")
				var critical: bool = event.get("critical", false)
				if cutin == null:
					effects.burst(
						point, ("必殺！ " if critical else "") + "−%d" % event.amount, UI.CORAL
					)
				if critical:
					effects.banner("一閃  —  クリティカル", UI.GOLD)
				await _impact(victim, critical)
			"miss":
				if victim != null:
					victim.play_pose("dodge")
				if cutin == null:
					effects.burst(point, "回避", UI.JADE)
			"death":
				if victim != null:
					victim.play_pose("defeat")
				if cutin == null:
					effects.burst(point, "撃破", UI.GOLD)
			"heal":
				_sfx("heal")
				effects.burst(point, "+%d" % event.amount, UI.JADE)
			"level":
				_sfx("level")
				if cutin == null:
					effects.burst(actor.position if actor != null else point, "成長  Lv.UP", UI.GOLD)
		await get_tree().create_timer(0.24).timeout
	if cutin != null:
		await get_tree().create_timer(0.25).timeout
		cutin.queue_free()
	if is_instance_valid(board):
		board.scale = Vector2.ONE
		board.position = Vector2.ZERO
	_music("stage")


# 被弾の短い停止はユニットだけにかけ、入力や音声の処理を止めない。
func _impact(victim: Node2D, critical: bool) -> void:
	if victim != null:
		victim.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(0.07 if not critical else 0.13).timeout
	if victim != null:
		victim.process_mode = Node.PROCESS_MODE_INHERIT
	var shake: Tween = board.create_tween()
	var amount: float = 9.0 if critical else 4.0
	shake.tween_property(board, "position:x", amount, 0.04)
	shake.tween_property(board, "position:x", -amount, 0.05)
	shake.tween_property(board, "position", Vector2.ZERO, 0.06)


func show_result() -> void:
	campaign.screen = "result"
	busy = false
	_reset_screen()
	_music("result")
	UI.art(screen, "backgrounds/keyart.svg", Rect2(0, 0, 1280, 720))
	UI.panel(screen, Rect2(112, 122, 685, 478), Color(0.05, 0.11, 0.17, 0.96))
	var won: bool = campaign.outcome != "defeat"
	var title: String = "道は、暁へ続く" if campaign.outcome == "ending" else "戦場を越えて"
	if not won:
		title = "灯はまだ、消えない"
	UI.label(
		screen,
		"全章踏破" if campaign.outcome == "ending" else ("章クリア" if won else "敗北"),
		Rect2(154, 150, 600, 40),
		24,
		UI.GOLD
	)
	UI.label(screen, title, Rect2(154, 205, 600, 75), 43)
	var text: String = "仲間と繋いだ道に、朝の光が満ちていく。\nその旅は、新しい物語として語り継がれる。"
	if campaign.outcome == "victory":
		text = "この勝利を胸に、次の戦場へ。\n失った仲間の想いも、ともに連れていく。"
	elif not won:
		text = "主人公が倒れ、旅は途切れました。\n地形と相性を見直し、もう一度挑みましょう。"
	UI.label(screen, text, Rect2(155, 300, 615, 90), 23)
	var count: Label = UI.label(screen, "", Rect2(155, 398, 600, 35), 23, UI.JADE)
	var tween: Tween = count.create_tween()
	tween.tween_method(
		func(value: float) -> void:
			count.text = "残った仲間  %d 人  /  %d ターン" % [int(value), campaign.turn],
		0.0,
		float(campaign.living("player").size()),
		0.5
	)
	if campaign.outcome == "victory":
		first_focus = UI.button(screen, "次の章へ", Rect2(154, 473, 283, 58), advance_stage)
	else:
		first_focus = UI.button(screen, "新しい旅", Rect2(154, 473, 283, 58), start_game)
	UI.button(screen, "タイトルへ", Rect2(457, 473, 283, 58), show_title)
	first_focus.grab_focus()


func advance_stage() -> void:
	var saved: bool = campaign.next_stage()
	_begin_stage()
	if not saved:
		notice = campaign.save_error
		_refresh_sidebar()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN
		)
		return
	if campaign.screen != "play" or busy:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		choose_cell(Board.cell_at(get_global_transform().affine_inverse() * event.position))
		return
	if event.is_action_pressed("ui_cancel"):
		cancel_selection()
	elif event.is_action_pressed("end_phase"):
		end_phase()
	elif event.is_action_pressed("wait_unit"):
		wait_selected()
	elif event.is_action_pressed("use_item"):
		item_selected()
	elif event.is_action_pressed("save_game"):
		save_to_title()
	elif event.is_action_pressed("ui_accept"):
		if not target.is_empty():
			confirm_attack()
		else:
			choose_cell(cursor)
	else:
		_move_cursor(event)


func _move_cursor(event: InputEvent) -> void:
	var direction := Vector2i.ZERO
	if event.is_action_pressed("ui_left"):
		direction.x = -1
	elif event.is_action_pressed("ui_right"):
		direction.x = 1
	elif event.is_action_pressed("ui_up"):
		direction.y = -1
	elif event.is_action_pressed("ui_down"):
		direction.y = 1
	if direction != Vector2i.ZERO:
		cursor = (cursor + direction).clamp(Vector2i.ZERO, Vector2i(15, 11))
		_refresh_sidebar()
