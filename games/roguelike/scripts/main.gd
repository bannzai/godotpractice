extends Control
## 入力は一手ずつ RunState へ渡す。画面にはアニメーションとフォーカスだけを保持する。

const Data := preload("res://scripts/game_data.gd")
const UI := preload("res://scripts/ui.gd")
const Board := preload("res://scripts/board.gd")
const Actor := preload("res://scripts/actor_view.gd")
const Effects := preload("res://scripts/effects.gd")
const DIRECTIONS: Dictionary = {
	"move_left": Vector2i.LEFT,
	"move_right": Vector2i.RIGHT,
	"move_up": Vector2i.UP,
	"move_down": Vector2i.DOWN,
	"move_nw": Vector2i(-1, -1),
	"move_ne": Vector2i(1, -1),
	"move_sw": Vector2i(-1, 1),
	"move_se": Vector2i(1, 1)
}

var run: Node
var sound: Node
var screen: Control
var board: Node2D
var actors: Dictionary = {}
var effects: Node2D
var first_focus: Button
var modal: Control
var modal_kind: String = ""
var selected_item: int = 0
var busy: bool = false
var current_screen: String = ""
var stats: Label
var health: Label
var food: Label
var log_label: Label
var log_scroll: ScrollContainer
var equipment: Label
var floor_label: Label
var hp_bar: ProgressBar
var hunger_bar: ProgressBar
var background_layers: Array[TextureRect] = []
var clock_time: float = 0.0
var cooldown: float = 0.0
var closing: bool = false
var displayed_floor: int = 0
var pending_result: bool = false


func _ready() -> void:
	print("roguelike boot")
	run = get_node("/root/RunState")
	sound = get_node("/root/Sound")
	theme = UI.make_theme()
	get_tree().auto_accept_quit = false
	run.changed.connect(_refresh)
	run.event.connect(_event)
	_refresh()


# 時間に応じて視差と入力間隔を進めるため非冪等。
func _process(delta: float) -> void:
	clock_time += delta
	cooldown = maxf(0.0, cooldown - delta)
	for index: int in range(background_layers.size()):
		background_layers[index].position.x = sin(clock_time * 0.15) * (index + 1) * 7 - 12
	if run.status != "playing" or not modal_kind.is_empty() or busy or cooldown > 0:
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction.length() > 0.5:
		_step(
			Vector2i(
				signf(direction.x) if absf(direction.x) > 0.3 else 0,
				signf(direction.y) if absf(direction.y) > 0.3 else 0
			)
		)


# 一つの入力イベントは一つのプレイヤー操作として消費する。
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var mode: int = DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(
			(
				DisplayServer.WINDOW_MODE_WINDOWED
				if mode == DisplayServer.WINDOW_MODE_FULLSCREEN
				else DisplayServer.WINDOW_MODE_FULLSCREEN
			)
		)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadMotion or event.is_echo():
		return
	if (
		event.is_action_pressed("ui_cancel")
		and (run.status == "playing" or not modal_kind.is_empty())
	):
		if modal_kind.is_empty():
			_open_pause()
		else:
			_close_modal()
		get_viewport().set_input_as_handled()
		return
	if run.status != "playing" or not modal_kind.is_empty() or busy:
		return
	if event.is_action_pressed("inventory"):
		_open_inventory()
	elif event.is_action_pressed("map"):
		board.map_open = not board.map_open
		board.queue_redraw()
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("wait_turn") and cooldown <= 0:
		run.wait_turn()
		cooldown = 0.18
	else:
		for action: String in DIRECTIONS:
			if event.is_action_pressed(action) and cooldown <= 0:
				_step(DIRECTIONS[action])
				get_viewport().set_input_as_handled()
				return
		return
	get_viewport().set_input_as_handled()


func _step(direction: Vector2i) -> void:
	if not run.move(direction):
		board.refresh()
	cooldown = 0.18


func start_new(seed_value: int = 0) -> void:
	_close_modal()
	run.start_run(seed_value)


func return_title() -> void:
	_close_modal()
	run.return_title()


func _refresh() -> void:
	if run.status in ["won", "dead"] and current_screen == "playing":
		if not pending_result:
			pending_result = true
			_finish_result_transition()
		return
	if run.status != current_screen:
		_build_screen()
	if run.status == "playing":
		_sync_world()
		_update_hud()
		var track_name: String = "floor%d" % run.floor_number
		for enemy: Dictionary in run.enemies:
			if enemy.kind == "boss" and run.dungeon.visible.has(enemy.pos):
				track_name = "boss"
		sound.track(track_name)
	elif run.status == "title":
		sound.track("title")
	else:
		sound.track("result")


func _finish_result_transition() -> void:
	busy = true
	await get_tree().create_timer(0.55).timeout
	if run.status in ["won", "dead"] and current_screen == "playing":
		_build_screen()
		sound.track("result")
	pending_result = false
	busy = false


func _build_screen() -> void:
	_close_modal()
	first_focus = null
	if is_instance_valid(screen):
		remove_child(screen)
		screen.queue_free()
	actors.clear()
	background_layers.clear()
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	current_screen = run.status
	var fill := ColorRect.new()
	fill.color = UI.INK
	fill.size = Vector2(1280, 720)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(fill)
	if run.status == "playing":
		_build_play()
	else:
		_build_backdrop()
		if run.status == "title":
			_build_title()
		else:
			_build_result()
	var fade := ColorRect.new()
	fade.size = Vector2(1280, 720)
	fade.color = UI.INK
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(fade)
	create_tween().tween_property(fade, "modulate:a", 0.0, 0.35)
	get_tree().create_timer(0.4).timeout.connect(fade.queue_free)


func _build_backdrop() -> void:
	for layer: String in ["back", "middle", "front"]:
		background_layers.append(
			UI.picture(
				screen, "res://assets/backgrounds/title_" + layer + ".svg", Rect2(-12, 0, 1304, 720)
			)
		)


func _build_title() -> void:
	UI.label(screen, "五つの深層に、消えない灯を。", Rect2(84, 115, 650, 44), 24, UI.TEAL)
	UI.picture(screen, "res://assets/ui/logo.svg", Rect2(70, 170, 680, 180))
	UI.label(screen, "一歩で世界が動く、ターン制の地下探索。\n食料と道具を選び、最深層から灯火を持ち帰ろう。", Rect2(88, 365, 660, 76), 21)
	first_focus = UI.button(screen, "深層へ潜る   →", Rect2(88, 478, 310, 58), start_new)
	UI.button(screen, "操作と探索の手引き", Rect2(416, 478, 270, 58), _open_help)
	UI.label(screen, "最深到達記録   %d / 5 階" % run.best_floor, Rect2(88, 559, 500, 36), 19, UI.GOLD)
	UI.label(
		screen,
		"矢印 / WASD 移動  ·  Q E Z C 斜め  ·  I 道具  ·  F 決定  ·  F11 全画面",
		Rect2(88, 651, 1120, 32),
		17,
		UI.MUTED
	)
	first_focus.grab_focus()


func _build_play() -> void:
	UI.panel(screen, Rect2(16, 14, 1248, 84))
	UI.panel(screen, Rect2(964, 112, 300, 520))
	UI.panel(screen, Rect2(16, 642, 1248, 64))
	floor_label = UI.label(screen, "", Rect2(34, 21, 250, 38), 25, UI.GOLD)
	stats = UI.label(screen, "", Rect2(34, 60, 260, 26), 16, UI.MUTED)
	health = UI.label(screen, "", Rect2(310, 22, 300, 32), 20)
	food = UI.label(screen, "", Rect2(656, 22, 275, 32), 20)
	hp_bar = _bar(Rect2(310, 63, 300, 14), UI.TEAL)
	hunger_bar = _bar(Rect2(656, 63, 260, 14), UI.GOLD)
	UI.button(screen, "道具  I / Y", Rect2(982, 31, 122, 44), _open_inventory)
	UI.button(screen, "手引き", Rect2(1120, 31, 120, 44), _open_help)
	UI.label(screen, "灯守りの記録", Rect2(985, 126, 250, 30), 20, UI.GOLD)
	equipment = UI.label(screen, "", Rect2(985, 165, 250, 65), 16)
	UI.label(screen, "探索図   M / セレクト", Rect2(985, 365, 250, 30), 17, UI.MUTED)
	log_scroll = ScrollContainer.new()
	log_scroll.position = Vector2(985, 236)
	log_scroll.size = Vector2(252, 120)
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen.add_child(log_scroll)
	log_label = UI.label(log_scroll, "", Rect2(), 15)
	log_label.custom_minimum_size.x = 232
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.label(
		screen,
		"移動・接敵で攻撃  /  空白・X 足踏み  /  F・A 拾う・階段\n斜め Q E Z C・スティック  /  I・Y 道具  /  Esc・B 中断",
		Rect2(34, 650, 1180, 49),
		16,
		UI.MUTED
	)
	board = Board.new()
	board.position = Vector2(20, 112)
	screen.add_child(board)
	effects = Effects.new()
	board.add_child(effects)
	effects.z_index = 10
	var mist := ColorRect.new()
	mist.position = Vector2(20, 112)
	mist.size = Vector2(920, 520)
	mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/atmosphere.gdshader")
	mist.material = material
	screen.add_child(mist)
	displayed_floor = 0


func _bar(rect: Rect2, color: Color) -> ProgressBar:
	var node := ProgressBar.new()
	node.show_percentage = false
	var back := StyleBoxFlat.new()
	back.bg_color = Color("0b151f")
	back.set_corner_radius_all(5)
	var front := StyleBoxFlat.new()
	front.bg_color = color
	front.set_corner_radius_all(5)
	node.add_theme_stylebox_override("background", back)
	node.add_theme_stylebox_override("fill", front)
	node.position = rect.position
	node.size = rect.size
	screen.add_child(node)
	return node


func _update_hud() -> void:
	floor_label.text = "第 %d 層 / 5   灯の遺跡" % run.floor_number
	stats.text = "Lv.%d   経験 %d   金貨 %d" % [run.level, run.xp, run.gold]
	health.text = "体力  %d / %d" % [run.hp, run.max_hp]
	food.text = "満腹度  %d / 100" % run.hunger
	hp_bar.max_value = run.max_hp
	create_tween().tween_property(hp_bar, "value", run.hp, 0.15)
	create_tween().tween_property(hunger_bar, "value", run.hunger, 0.15)
	equipment.text = (
		"攻撃 %d  /  防御 %d\n道具 %d / 12  ·  %d 手目"
		% [run.attack_power(), run.defense_power(), run.inventory.size(), run.turns]
	)
	var lines: Array[String] = []
	for index: int in range(maxi(0, run.messages.size() - 4), run.messages.size()):
		lines.append(run.messages[index])
	log_label.text = "\n".join(lines)
	log_scroll.set_deferred("scroll_vertical", 100000)


func _sync_world() -> void:
	board.refresh()
	if displayed_floor != run.floor_number:
		for actor: Node in actors.values():
			actor.queue_free()
		actors.clear()
		displayed_floor = run.floor_number
	var present: Array[int] = [-1]
	_sync_actor(-1, "hero", run.player_pos)
	for enemy: Dictionary in run.enemies:
		present.append(enemy.id)
		if run.dungeon.visible.has(enemy.pos):
			_sync_actor(enemy.id, enemy.kind, enemy.pos)
		elif actors.has(enemy.id):
			actors[enemy.id].visible = false
	for id: int in actors.keys():
		if not present.has(id):
			var actor: Node2D = actors[id]
			actor.animate("death")
			get_tree().create_timer(0.55).timeout.connect(actor.queue_free)
			actors.erase(id)


func _sync_actor(id: int, kind: String, cell: Vector2i) -> void:
	var target: Vector2 = board.point(cell)
	if not actors.has(id):
		var actor: Node2D = Actor.new()
		board.add_child(actor)
		actor.setup(kind)
		actor.position = target
		actor.animate("appear")
		actors[id] = actor
	var actor: Node2D = actors[id]
	actor.visible = Rect2(0, 0, Board.COLS * Board.TILE, Board.ROWS * Board.TILE).has_point(target)
	actor.z_index = 2
	if actor.position.distance_to(target) > 1:
		actor.travel(target)


# イベントごとに演出を追加するので、同じイベントの再実行は別の演出になる。
func _event(kind: String, cell: Vector2i, value: int) -> void:
	if not is_instance_valid(board) or current_screen != "playing":
		return
	var point: Vector2 = board.point(cell)
	match kind:
		"attack":
			if actors.has(-1):
				actors[-1].animate("attack", Vector2(run.facing))
			if value > 0:
				for id: int in actors:
					if id != -1 and actors[id].position.distance_to(point) < 24:
						actors[id].animate("hurt")
			effects.slash(point, Vector2(run.facing))
			effects.popup(point, str(value), UI.GOLD)
			sound.play("hit")
			_hit_stop()
		"enemy_attack":
			for actor: Node2D in actors.values():
				if actor.position.distance_to(point) < 24:
					actor.animate("attack", Vector2(run.player_pos - cell))
			if value > 0:
				effects.slash(point, Vector2(run.player_pos - cell))
		"hurt":
			effects.burst(point, Color("ea776d"))
			effects.popup(point, "−%d" % value, Color("ff9988"))
			for actor: Node2D in actors.values():
				if actor.position.distance_to(point) < 24:
					actor.animate("hurt")
			sound.play("hurt")
			_shake()
		"level":
			effects.burst(point, UI.GOLD, 32)
			effects.popup(point, "レベルアップ！", UI.GOLD)
			sound.play("level")
		"stairs":
			sound.play("stairs")
			_flash(UI.TEAL)
		"pickup", "use":
			effects.burst(point, UI.TEAL)
			sound.play("pickup")
		"win":
			effects.burst(point, UI.GOLD, 48)
			effects.popup(point, "灯を取り戻した！", UI.GOLD)
			sound.play("level")
		"death", "kill":
			if kind == "death" and actors.has(-1):
				actors[-1].animate("death")
			effects.burst(point, UI.GOLD)
			sound.play("death")


func _hit_stop() -> void:
	busy = true
	for actor: Node2D in actors.values():
		actor.animation.speed_scale = 0.0
	await get_tree().create_timer(0.055).timeout
	for actor: Node2D in actors.values():
		actor.animation.speed_scale = 1.0
	busy = false


func _shake() -> void:
	var tween := create_tween()
	tween.tween_property(board, "position", Vector2(24, 113), 0.035)
	tween.tween_property(board, "position", Vector2(16, 111), 0.035)
	tween.tween_property(board, "position", Vector2(20, 112), 0.035)


func _flash(color: Color) -> void:
	var flash := ColorRect.new()
	flash.size = Vector2(1280, 720)
	flash.color = Color(color, 0.3)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(flash)
	create_tween().tween_property(flash, "modulate:a", 0.0, 0.45)
	get_tree().create_timer(0.5).timeout.connect(flash.queue_free)


func _interact() -> void:
	if run.player_pos == run.dungeon.stairs:
		if run.floor_number == 5:
			run.escape()
		else:
			run.descend()
	else:
		run.pickup()


func _build_result() -> void:
	UI.panel(screen, Rect2(340, 100, 600, 510))
	var won: bool = run.status == "won"
	UI.label(screen, "灯を地上へ" if won else "灯火は、次の旅へ", Rect2(390, 133, 500, 64), 36, UI.GOLD)
	UI.label(screen, run.result_cause, Rect2(390, 213, 500, 56), 21)
	var summary: Label = UI.label(screen, "", Rect2(390, 285, 500, 170), 23)
	var result_numbers: Array[int] = [
		run.floor_number, run.kills, run.level, run.turns, run.best_floor
	]
	summary.create_tween().tween_method(
		func(progress: float) -> void:
			summary.text = (
				"到達  %d 階    /    討伐  %d 体\n\nレベル %d    ·    %d 手の探索\n\n最深到達記録  %d 階"
				% [
					result_numbers[0],
					int(result_numbers[1] * progress),
					result_numbers[2],
					int(result_numbers[3] * progress),
					result_numbers[4]
				]
			),
		0.0,
		1.0,
		0.42
	)

	first_focus = UI.button(screen, "もう一度潜る", Rect2(390, 508, 230, 58), start_new)
	UI.button(screen, "タイトルへ", Rect2(644, 508, 230, 58), return_title)
	first_focus.grab_focus()


func _new_modal(kind: String) -> void:
	_close_modal()
	modal_kind = kind
	for button: Node in screen.find_children("*", "Button", true, false):
		button.disabled = true
	modal = Control.new()
	modal.z_index = 20
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var dim := ColorRect.new()
	dim.size = Vector2(1280, 720)
	dim.color = Color(0.02, 0.04, 0.07, 0.84)
	modal.add_child(dim)
	UI.panel(modal, Rect2(230, 70, 820, 580))


func _close_modal() -> void:
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
		modal = null
	modal_kind = ""
	if is_instance_valid(screen):
		for button: Node in screen.find_children("*", "Button", true, false):
			button.disabled = false
	if is_instance_valid(first_focus) and first_focus.is_inside_tree() and run.status != "playing":
		first_focus.grab_focus()


func _open_inventory() -> void:
	if run.status != "playing":
		return
	_new_modal("inventory")
	UI.label(modal, "旅の道具   %d / 12" % run.inventory.size(), Rect2(265, 91, 600, 46), 28, UI.GOLD)
	UI.label(modal, "選ぶ → 使う・装備 / 投げる / 捨てる。投げる方向は主人公の向き。", Rect2(265, 142, 760, 34), 16, UI.MUTED)
	var first: Button
	for index: int in range(run.inventory.size()):
		var item: String = run.inventory[index]
		var caption: String = run.item_name(item)
		if item == run.weapon or item == run.shield:
			caption += " 〈装備〉"
		var button: Button = UI.button(
			modal,
			caption,
			Rect2(265 + (index % 2) * 380, 190 + (index / 2) * 55, 360, 46),
			_select_item.bind(index)
		)
		UI.picture(
			modal,
			"res://assets/items/%s.svg" % Data.ITEMS[item].image,
			Rect2(270 + (index % 2) * 380, 195 + (index / 2) * 55, 36, 36)
		)
		if first == null:
			first = button
	var close: Button = UI.button(modal, "戻る   Esc / B", Rect2(765, 573, 240, 48), _close_modal)
	if first != null:
		first.grab_focus()
	else:
		close.grab_focus()


func _select_item(index: int) -> void:
	selected_item = index
	_new_modal("item")
	UI.label(modal, run.item_name(run.inventory[index]), Rect2(280, 140, 700, 60), 30, UI.GOLD)
	UI.label(
		modal,
		run.item_description(run.inventory[index]) + "\n\n使用・装備・投擲・廃棄で一手が経過します。",
		Rect2(280, 228, 700, 100),
		20
	)
	var use: Button = UI.button(
		modal, "使う / 装備", Rect2(280, 389, 220, 58), _item_action.bind("use")
	)
	UI.button(modal, "投げる", Rect2(520, 389, 220, 58), _item_action.bind("throw"))
	UI.button(modal, "捨てる", Rect2(760, 389, 220, 58), _item_action.bind("drop"))
	UI.button(modal, "道具一覧へ", Rect2(740, 550, 240, 50), _open_inventory)
	use.grab_focus()


func _item_action(action: String) -> void:
	_close_modal()
	match action:
		"use":
			run.use_item(selected_item)
		"throw":
			run.throw_item(selected_item, run.facing)
		"drop":
			run.drop_item(selected_item)
	cooldown = 0.2


func _open_help() -> void:
	_new_modal("help")
	UI.label(modal, "探索の手引き", Rect2(280, 100, 700, 58), 32, UI.GOLD)
	UI.label(
		modal,
		(
			"移動は矢印 / WASD / 十字キー・左スティック。\n"
			+ "Q E Z C またはスティックで斜めに移動。接敵で攻撃。\n"
			+ "\n"
			+ "空白 / X：足踏み　　F / A：足元を拾う・階段を降りる\n"
			+ "I / Y：道具　　M / セレクト：地図　　Esc / B：戻る\n"
			+ "\n"
			+ "歩くとお腹が減り、空腹では体力を失います。\n"
			+ "部屋を探索して食料を確保し、道具を使い分けましょう。\n"
			+ "巻物と杖は使うまで未識別。投げる方向は直前の移動方向。\n"
			+ "5階の番人を倒すか、5階の階段から脱出すればクリア。\n"
			+ "F11：全画面切替。敗北すると持ち物を失います。"
		),
		Rect2(280, 184, 740, 350),
		20
	)
	var close: Button = UI.button(modal, "閉じる", Rect2(740, 558, 240, 50), _close_modal)
	close.grab_focus()


func _open_pause() -> void:
	_new_modal("pause")
	UI.label(modal, "ひと息つく", Rect2(290, 150, 600, 70), 36, UI.GOLD)
	UI.label(modal, "操作するまで、敵も時間も進みません。", Rect2(290, 260, 680, 50), 23)
	var resume: Button = UI.button(modal, "探索を続ける", Rect2(290, 400, 300, 60), _close_modal)
	UI.button(modal, "旅を諦める", Rect2(650, 400, 300, 60), _retire)
	resume.grab_focus()


func _retire() -> void:
	_close_modal()
	run.retire()


func stop_audio() -> void:
	sound.stop_all()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not closing:
		closing = true
		await sound.shutdown()
		get_tree().quit()
