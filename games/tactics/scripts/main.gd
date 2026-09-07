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
var tutorial_active: bool = false
var tutorial_step: int = 0
var pending_save_notice: String = ""
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
	UI.art_cover(screen, "generated/yamato-landscape.png", Rect2(0, 0, 1280, 720))
	var wash := ColorRect.new()
	wash.color = Color(0.16, 0.08, 0.03, 0.20)
	wash.size = Vector2(1280, 720)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(wash)
	UI.panel(screen, Rect2(46, 68, 500, 584), Color(0.96, 0.90, 0.72, 0.96), UI.INK)
	UI.label(screen, "五人の誓い、三つの戦場", Rect2(82, 102, 410, 36), 22, UI.CORAL)
	UI.label(screen, "暁の境界", Rect2(78, 150, 440, 100), 64, UI.INK)
	UI.label(screen, "あかつき の きょうかい", Rect2(82, 237, 420, 34), 17, UI.MUTED)
	UI.label(screen, "金雲の向こうへ、道をひらく。", Rect2(82, 292, 420, 38), 23, UI.JADE)
	UI.label(screen, "地形を読み、五人を導く戦術絵巻", Rect2(82, 334, 420, 34), 19, UI.INK)
	first_focus = UI.button(screen, "新しい絵巻をひらく", Rect2(82, 405, 428, 56), start_game)
	var resume: Button = UI.button(screen, "続きから", Rect2(82, 478, 202, 50), resume_game)
	resume.disabled = not campaign.has_save()
	UI.button(screen, "軍議の手引き", Rect2(300, 478, 210, 50), show_help)
	UI.button(screen, "絵巻を閉じる", Rect2(82, 548, 428, 46), request_quit)
	var allies: TextureRect = UI.art(
		screen, "generated/allies-atlas.png", Rect2(525, 284, 740, 405)
	)
	if ResourceLoader.exists("res://assets/shaders/gold_outline.gdshader"):
		var gold_material := ShaderMaterial.new()
		gold_material.shader = load("res://assets/shaders/gold_outline.gdshader")
		allies.material = gold_material
	first_focus.grab_focus()


func show_help() -> void:
	campaign.screen = "help"
	_reset_screen()
	var scroll: Panel = UI.scroll_panel(screen, Rect2(142, 48, 996, 620))
	UI.label(scroll, "軍議の手引き", Rect2(58, 36, 880, 55), 38, UI.CORAL)
	var text: String = "味方を選ぶ、青いマスへ移動、相手を選んで予測、戦闘を確定\n\n"
	text += "剣は斧に、斧は槍に、槍は剣に有利。速さの差で追撃。\n"
	text += "弓は２マス先だけに攻撃。祈り手は隣の味方を回復します。\n"
	text += "森・山・砦は守りに有利。水は通行不可。移動は取消できます。\n"
	text += "全員行動、または E / Y で敵の番。W / X で待機、I / RB で薬。\n"
	text += "主人公が倒れると敗北。他の仲間の戦死は次の章にも残ります。\n"
	text += "敵全滅、ボス撃破、目的地への到達という全３章です。\n"
	text += "S / Start で保存してタイトル。F11 で全画面切替。\n"
	text += "マウスはマスとボタンをクリック。パッドは方向キーにも対応。"
	text += "\n最初の戦場では、金雲の指南が盤面上で順番に案内します。"
	UI.label(scroll, text, Rect2(58, 105, 880, 420), 21, UI.INK)
	first_focus = UI.button(scroll, "表紙へ戻る", Rect2(274, 534, 450, 50), show_title)
	first_focus.grab_focus()


func start_game() -> void:
	var saved: bool = campaign.new_game()
	tutorial_active = true
	tutorial_step = 0
	if not saved:
		pending_save_notice = campaign.save_error
	show_chapter_scroll()


func resume_game() -> void:
	if campaign.load_game():
		tutorial_active = false
		_begin_stage()
	else:
		notice = "記録を読み込めませんでした"
		effects.banner(notice, UI.CORAL)


func show_chapter_scroll() -> void:
	campaign.screen = "story"
	selected = ""
	target = ""
	busy = false
	_reset_screen()
	_music("title")
	var landscape: TextureRect = UI.art_cover(
		screen, "generated/yamato-landscape.png", Rect2(-240, -45, 1760, 810)
	)
	landscape.create_tween().tween_property(landscape, "position:x", -80.0, 10.0)
	for fold: int in range(1, 5):
		var seam := ColorRect.new()
		seam.color = Color(0.18, 0.11, 0.05, 0.32)
		seam.position = Vector2(fold * 256 - 2, 0)
		seam.size = Vector2(4, 720)
		seam.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(seam)
	var chapter: Panel = UI.scroll_panel(screen, Rect2(58, 58, 500, 244))
	UI.label(
		chapter,
		"第 %d 章　%s" % [campaign.stage_index + 1, campaign.stage().name],
		Rect2(34, 30, 430, 48),
		31,
		UI.CORAL
	)
	var stories: Array[String] = [
		"風の草原で、途絶えた街道を取り戻す。\n五人の印を重ね、最初の陣を破れ。",
		"山峡の砦に、敵将の旗が上がる。\n深い森と高地を読み、包囲を解け。",
		"川霧の向こうに、夜明けの門がある。\n失った仲間の思いも連れ、境界を越えよ。",
	]
	UI.label(chapter, stories[campaign.stage_index], Rect2(36, 96, 426, 105), 22, UI.INK)
	first_focus = UI.button(screen, "戦場の屏風をひらく", Rect2(842, 576, 366, 58), _begin_stage)
	if tutorial_active:
		var guide: Panel = UI.scroll_panel(screen, Rect2(58, 523, 560, 124))
		UI.label(guide, "初陣の指南は、戦場の金雲に現れます。", Rect2(28, 22, 500, 36), 20, UI.INK)
		UI.button(guide, "指南を省く", Rect2(302, 66, 224, 38), skip_tutorial)
	first_focus.grab_focus()


func skip_tutorial() -> void:
	tutorial_active = false
	tutorial_step = 0
	_sfx("fan")
	show_chapter_scroll()


func skip_play_tutorial() -> void:
	tutorial_active = false
	tutorial_step = 0
	_sfx("fan")
	notice = "指南を閉じました。金に光る仲間から自由に選べます"
	_refresh_sidebar()


func _begin_stage() -> void:
	campaign.screen = "play"
	selected = ""
	target = ""
	busy = false
	notice = ""
	var hero: Dictionary = campaign.unit_by_id("hero")
	cursor = Vector2i(hero.x, hero.y)
	show_play()
	if not pending_save_notice.is_empty():
		notice = pending_save_notice
		pending_save_notice = ""
		_refresh_sidebar()
	effects.banner("第 %d 章  %s" % [campaign.stage_index + 1, campaign.stage().name])
	if not campaign.outcome.is_empty():
		show_result()
	elif campaign.phase == "enemy":
		_enemy_turn()


func show_play() -> void:
	_reset_screen()
	_music("stage")
	UI.scroll_panel(screen, Rect2(28, 17, 1224, 76))
	UI.label(screen, "暁の境界", Rect2(50, 27, 225, 54), 29, UI.CORAL)
	UI.label(
		screen,
		"第 %d 章  %s" % [campaign.stage_index + 1, campaign.stage().name],
		Rect2(283, 30, 520, 32),
		23,
		UI.INK
	)
	UI.label(screen, campaign.stage().objective_text, Rect2(285, 60, 560, 25), 16, UI.MUTED)
	board = Board.new()
	screen.add_child(board)
	board.set_selection(selected, cursor)
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
	UI.panel(sidebar, Rect2(803, 104, 443, 541), Color(0.95, 0.88, 0.69, 0.97), UI.INK)
	var phase_name: String = "自軍フェーズ" if campaign.phase == "player" else "敵軍フェーズ"
	UI.label(
		sidebar,
		"%s  ·  %d ターン" % [phase_name, campaign.turn],
		Rect2(824, 115, 390, 34),
		24,
		UI.CORAL
	)
	if tutorial_active:
		var tutorial: Panel = UI.scroll_panel(sidebar, Rect2(819, 154, 411, 82))
		UI.label(tutorial, _tutorial_caption(), Rect2(18, 17, 300, 48), 18, UI.INK)
		UI.button(tutorial, "省く", Rect2(321, 20, 72, 40), skip_play_tutorial)
	var current: Dictionary = _unit(selected)
	if current.is_empty():
		current = campaign.unit_at(cursor)
	if current.is_empty():
		UI.label(sidebar, "金に光る仲間を選ぶ", Rect2(827, 252, 390, 40), 25, UI.INK)
		UI.label(
			sidebar,
			"カーソル先: %s\n%s"
			% [BattleData.terrain(cursor, campaign.stage().map).name, campaign.stage().objective_text],
			Rect2(827, 302, 390, 75),
			18,
			UI.MUTED
		)
	else:
		_unit_panel(current)
	if not target.is_empty():
		_forecast()
	else:
		_actions(current)
	var status_scroll: Panel = UI.scroll_panel(sidebar, Rect2(803, 650, 443, 58))
	var message: String = notice if not notice.is_empty() else _next_action_text()
	var status: Label = UI.label(status_scroll, message, Rect2(18, 13, 408, 38), 16, UI.INK)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for button: Node in sidebar.find_children("*", "Button", true, false):
		button.focus_mode = Control.FOCUS_NONE
	var ground: Dictionary = BattleData.terrain(cursor, campaign.stage().map)
	var cost: String = str(ground.cost) if ground.cost < 99 else "通行不可"
	UI.label(
		sidebar,
		(
			"カーソルの地形　%s　移動 %s　守備 +%d　回避 +%d%%"
			% [ground.name, cost, ground.defense, ground.evasion]
		),
		Rect2(842, 61, 386, 26),
		17,
		UI.MUTED
	)
	if is_instance_valid(board):
		board.set_selection(selected, cursor)


func _unit_panel(unit: Dictionary) -> void:
	var portrait := preload("res://scripts/unit_actor.gd").new()
	sidebar.add_child(portrait)
	portrait.configure(Board.art_kind(unit), unit.team == "enemy")
	portrait.position = Vector2(871, 305)
	portrait.scale = Vector2.ONE * 0.48
	UI.label(sidebar, "%s  Lv.%d" % [unit.name, unit.level], Rect2(963, 252, 255, 34), 25, UI.INK)
	UI.label(sidebar, JOBS[unit.job], Rect2(963, 290, 255, 28), 20, UI.JADE)
	UI.label(sidebar, "HP  %d / %d" % [unit.hp, unit.max_hp], Rect2(963, 324, 255, 28), 20, UI.INK)
	UI.meter(sidebar, Rect2(963, 356, 250, 10), unit.hp, unit.max_hp)
	UI.label(
		sidebar,
		"力 %d    守 %d    速 %d    技 %d" % [unit.strength, unit.defense, unit.speed, unit.skill],
		Rect2(828, 378, 385, 30),
		20,
		UI.INK
	)
	UI.label(
		sidebar,
		"移動 %d    経験 %d / 100    薬 %d" % [unit.move, unit.xp, unit.items],
		Rect2(828, 407, 390, 30),
		18,
		UI.MUTED
	)


func _actions(unit: Dictionary) -> void:
	if not selected.is_empty() and not unit.is_empty():
		UI.label(sidebar, "扇を開き、行動を選ぶ", Rect2(828, 431, 390, 22), 16, UI.CORAL)
		UI.fan_button(sidebar, "攻撃", Rect2(816, 478, 126, 62), -0.18, show_attack_hint)
		UI.fan_button(sidebar, "待機", Rect2(906, 454, 126, 62), -0.06, wait_selected)
		UI.fan_button(sidebar, "薬", Rect2(997, 454, 126, 62), 0.06, item_selected)
		UI.fan_button(sidebar, "取消", Rect2(1087, 478, 126, 62), 0.18, cancel_selection)
	else:
		UI.label(sidebar, "剣 > 斧 > 槍 > 剣\n弓は二升先　祈りは隣の味方", Rect2(828, 438, 390, 67), 20, UI.JADE)
	UI.button(sidebar, "軍議を終えて敵軍へ", Rect2(828, 553, 388, 38), end_phase)
	UI.button(sidebar, "記録して表紙へ", Rect2(828, 600, 388, 34), save_to_title)


func _forecast() -> void:
	var prediction: Dictionary = campaign.preview(selected, target)
	if prediction.is_empty():
		target = ""
		return
	var opponent: Dictionary = _unit(target)
	var scroll: Panel = UI.scroll_panel(sidebar, Rect2(819, 430, 411, 204))
	UI.label(scroll, "戦の見立て　対　" + opponent.name, Rect2(22, 22, 367, 32), 23, UI.CORAL)
	var summary: String = (
		"回復  +%d" % prediction.heal
		if prediction.heal > 0
		else "与ダメ %d × %d   命中 %d%%" % [prediction.damage, prediction.strikes, prediction.hit]
	)
	UI.label(scroll, summary, Rect2(22, 64, 367, 30), 22, UI.INK)
	UI.label(
		scroll,
		(
			"反撃 %d × %d  /  命中 %d%%  /  必殺 %d%%"
			% [
				prediction.counter_damage,
				prediction.counter_strikes,
				prediction.counter_hit,
				prediction.critical
			]
		),
		Rect2(22, 99, 367, 30),
		16,
		UI.CORAL
	)
	UI.button(scroll, "この見立てで進む", Rect2(20, 140, 220, 42), confirm_attack)
	UI.button(scroll, "巻物を戻す", Rect2(250, 140, 140, 42), cancel_selection)


func _tutorial_caption() -> String:
	var captions: Array[String] = [
		"一ノ指南　金に光る仲間を選ぶ",
		"二ノ指南　金枠の升へ進める",
		"三ノ指南　赤い相手を選び、巻物を見る",
		"四ノ指南　見立てを確定する",
	]
	return captions[clampi(tutorial_step, 0, captions.size() - 1)]


func _next_action_text() -> String:
	if campaign.phase == "enemy":
		return "敵軍の動きを見届ける"
	if not target.is_empty():
		return "巻物の予測を読み、進むか戻すか選ぶ"
	if not selected.is_empty():
		return "金枠へ移動するか、扇から行動を選ぶ"
	return "金に光る未行動の仲間を選ぶ"


func show_attack_hint() -> void:
	notice = "盤上の赤い相手を選ぶと、結果を巻物で確認できます"
	_sfx("fan")
	_refresh_sidebar()


# 入力された移動・行動を一回だけ進行に反映する。
func choose_cell(cell: Vector2i) -> void:
	if busy or campaign.screen != "play" or campaign.phase != "player":
		return
	if cell.x < 0 or cell.y < 0 or cell.x >= 16 or cell.y >= 12:
		return
	cursor = cell
	var clicked: Dictionary = campaign.unit_at(cell)
	if selected.is_empty():
		if clicked.is_empty():
			notice = "この升には誰もいません。金に光る仲間を選んでください"
		elif clicked.team != "player":
			notice = "敵兵です。先に金に光る仲間を選んでください"
		elif clicked.acted:
			notice = "%sはこの手番ですでに行動しました" % clicked.name
		else:
			selected = clicked.id
			notice = "金枠の升へ移動できます。赤い相手は攻撃候補です"
			tutorial_step = maxi(tutorial_step, 1)
			_sfx("fan")
	elif not clicked.is_empty() and clicked.id != selected:
		if not campaign.preview(selected, clicked.id).is_empty():
			target = clicked.id
			notice = "巻物に、選んだ先の結果が出ました"
			tutorial_step = maxi(tutorial_step, 3)
			_sfx("confirm")
		elif clicked.team == "player" and not clicked.acted:
			campaign.undo_move(selected)
			selected = clicked.id
			target = ""
			notice = "%sに選び直しました" % clicked.name
			_sfx("fan")
		elif clicked.team == "player":
			notice = "%sはこの手番ですでに行動しました" % clicked.name
		else:
			notice = "%sは今いる升から射程外です。先に金枠へ移動してください" % clicked.name
	elif target.is_empty():
		var actor_unit: Dictionary = _unit(selected)
		var movement: Array = campaign.movement(actor_unit)
		if cell not in movement:
			var terrain: Dictionary = BattleData.terrain(cell, campaign.stage().map)
			notice = (
				"%sは通れません。別の金枠を選んでください" % terrain.name
				if terrain.cost >= 99
				else "そこまでは移動できません。金枠の升を選んでください"
			)
			_refresh_sidebar()
			return
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
			notice = "赤い相手を選ぶか、扇から待機・薬・取消を選んでください"
			tutorial_step = maxi(tutorial_step, 2)
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
	if tutorial_active:
		tutorial_active = false
		tutorial_step = 0
		notice = "指南は完了です。以後は金の光と巻物を頼りに進めます"
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
	UI.art_cover(screen, "generated/yamato-landscape.png", Rect2(0, 0, 1280, 720))
	var scroll: Panel = UI.scroll_panel(screen, Rect2(104, 104, 720, 504))
	var won: bool = campaign.outcome != "defeat"
	var title: String = "道は、暁へ続く" if campaign.outcome == "ending" else "戦場を越えて"
	if not won:
		title = "灯はまだ、消えない"
	UI.label(
		scroll,
		"全章踏破" if campaign.outcome == "ending" else ("章クリア" if won else "敗北"),
		Rect2(48, 34, 620, 40),
		24,
		UI.CORAL
	)
	UI.label(scroll, title, Rect2(48, 88, 620, 75), 43, UI.INK)
	var text: String = "仲間と繋いだ道に、朝の光が満ちていく。\nその旅は、新しい物語として語り継がれる。"
	if campaign.outcome == "victory":
		text = "この勝利を胸に、次の戦場へ。\n失った仲間の想いも、ともに連れていく。"
	elif not won:
		text = "主人公が倒れ、旅は途切れました。\n地形と相性を見直し、もう一度挑みましょう。"
	UI.label(scroll, text, Rect2(49, 183, 615, 90), 23, UI.INK)
	var count: Label = UI.label(scroll, "", Rect2(49, 288, 600, 35), 23, UI.JADE)
	var tween: Tween = count.create_tween()
	tween.tween_method(
		func(value: float) -> void:
			count.text = "残った仲間  %d 人  /  %d ターン" % [int(value), campaign.turn],
		0.0,
		float(campaign.living("player").size()),
		0.5
	)
	if campaign.outcome == "victory":
		first_focus = UI.button(scroll, "次の絵巻へ", Rect2(48, 368, 283, 58), advance_stage)
	else:
		first_focus = UI.button(scroll, "新しい絵巻", Rect2(48, 368, 283, 58), start_game)
	UI.button(scroll, "表紙へ戻る", Rect2(351, 368, 283, 58), show_title)
	first_focus.grab_focus()


func advance_stage() -> void:
	var saved: bool = campaign.next_stage()
	if not saved:
		pending_save_notice = campaign.save_error
	show_chapter_scroll()


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
