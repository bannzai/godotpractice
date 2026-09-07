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
var hud_line: RichTextLabel
var log_label: RichTextLabel
var equipment: Label
var objective_label: RichTextLabel
var inventory_preview: RichTextLabel
var background_layers: Array[Label] = []
var clock_time: float = 0.0
var cooldown: float = 0.0
var closing: bool = false
var displayed_floor: int = 0
var pending_result: bool = false
var tutorial_active: bool = false
var tutorial_seen: bool = false
var tutorial_page: int = 0
var stick_axis: Vector2 = Vector2.ZERO


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
		var layer: Label = background_layers[index]
		var base_x: float = float(layer.get_meta("base_x", layer.position.x))
		layer.position.x = base_x + sin(clock_time * 0.15) * (index + 1) * 4
	if run.status != "playing" or not modal_kind.is_empty() or busy or cooldown > 0:
		return
	var direction := stick_axis
	if direction.length() > 0.5:
		_step(
			Vector2i(
				signf(direction.x) if absf(direction.x) > 0.3 else 0,
				signf(direction.y) if absf(direction.y) > 0.3 else 0
			)
		)


# 一つの入力イベントは一つのプレイヤー操作として消費する。
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		_update_stick_axis(event)
		return
	if event.is_echo():
		return
	if _handle_global_input(event):
		return
	if run.status != "playing" or not modal_kind.is_empty() or busy:
		return
	if event.is_action_pressed("inventory"):
		_open_inventory()
	elif event.is_action_pressed("map"):
		board.map_open = not board.map_open
		board.queue_redraw()
		_update_hud()
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


func _update_stick_axis(event: InputEventJoypadMotion) -> void:
	if event.axis == JOY_AXIS_LEFT_X:
		stick_axis.x = event.axis_value
	elif event.axis == JOY_AXIS_LEFT_Y:
		stick_axis.y = event.axis_value


func _handle_global_input(event: InputEvent) -> bool:
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
		return true
	if event.is_action_pressed("help"):
		if modal_kind == "help":
			_close_modal()
		else:
			_open_help()
		get_viewport().set_input_as_handled()
		return true
	if event.is_action_pressed("ui_cancel") and (
		run.status == "playing" or not modal_kind.is_empty()
	):
		if modal_kind.is_empty():
			_open_pause()
		elif modal_kind == "tutorial":
			_skip_tutorial()
		else:
			_close_modal()
		get_viewport().set_input_as_handled()
		return true
	return false


func _step(direction: Vector2i) -> void:
	if not run.move(direction):
		board.refresh()
	cooldown = 0.18


func start_new(seed_value: int = 0) -> void:
	_close_modal()
	tutorial_active = not tutorial_seen
	tutorial_page = 0
	run.start_run(seed_value)
	if tutorial_active:
		_open_tutorial.call_deferred()


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
	var layers: Array[String] = [
		(
			".       .             :       .            .        :\n"
			+ "     .        .              .       :          .\n"
			+ "  :       .       .      .       .        .          .\n"
			+ ".      .      :       .       .      :       ."
		),
		(
			"│                 │                 │\n"
			+ "│       ┌─────────┴─────────┐       │\n"
			+ "│       │  SIGNAL: ALIVE   │       │\n"
			+ "│       └─────────┬─────────┘       │\n"
			+ "│                 │                 │"
		),
		(
			"\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\n"
			+ "  深度計測中 ...  01  02  03  04  05\n"
			+ "////////////////////////////////////////////////////"
		)
	]
	var positions: Array[Vector2] = [Vector2(20, 50), Vector2(790, 80), Vector2(38, 625)]
	var sizes: Array[int] = [24, 19, 16]
	for index: int in range(layers.size()):
		var layer: Label = UI.label(
			screen, layers[index], Rect2(positions[index], Vector2(1180, 300)),
			sizes[index], UI.MUTED.darkened(0.45 - index * 0.12)
		)
		layer.set_meta("base_x", layer.position.x)
		background_layers.append(layer)


func _build_title() -> void:
	UI.rich_text(
		screen,
		(
			"[color=#45f0b5]┌─ TERMINAL ROGUE / LAMP-05 ─────────────────┐[/color]\n"
			+ "│                                                  │\n"
			+ "│     [color=#ffbd4a]灯 守 り の 深 層[/color]                         │\n"
			+ "│     T O M O S H I B I   D E P T H S              │\n"
			+ "│                                                  │\n"
			+ "[color=#45f0b5]└──────────────────────────────────────────────────┘[/color]"
		),
		Rect2(68, 116, 690, 245),
		24
	)
	UI.label(
		screen,
		"一手入力するたび、地下の全員が一手動く。\n@ を導き、五層の > から灯を持ち帰れ。",
		Rect2(83, 370, 660, 70),
		20
	)
	UI.panel(screen, Rect2(790, 110, 432, 414))
	UI.rich_text(screen, _depth_diagram(0), Rect2(818, 132, 390, 370), 19)
	first_focus = UI.button(screen, "> 深層へ潜る", Rect2(83, 474, 310, 58), start_new)
	UI.button(screen, "?  探索コマンド", Rect2(411, 474, 280, 58), _open_help)
	UI.label(
		screen,
		"RECORD // 最深到達  %02d / 05" % run.best_floor,
		Rect2(83, 558, 610, 36),
		19,
		UI.GOLD
	)
	UI.label(screen, "初回は場面内チュートリアルが開きます。", Rect2(83, 604, 640, 28), 16, UI.MUTED)
	first_focus.grab_focus()


func _build_play() -> void:
	UI.panel(screen, Rect2(16, 12, 1248, 52))
	UI.panel(screen, Rect2(16, 76, 876, 390))
	UI.panel(screen, Rect2(908, 76, 356, 388))
	UI.panel(screen, Rect2(16, 480, 1248, 224))
	hud_line = UI.rich_text(screen, "", Rect2(32, 22, 1210, 34), 18)
	var playfield_header: Label = UI.label(
		screen, "┌ PLAYFIELD / GLYPH MAP", Rect2(30, 80, 600, 28), 14, UI.MUTED
	)
	playfield_header.z_index = 3
	UI.label(screen, "┌ NEXT ACTION", Rect2(922, 80, 310, 28), 14, UI.GOLD)
	objective_label = UI.rich_text(screen, "", Rect2(928, 114, 314, 146), 17)
	equipment = UI.label(screen, "", Rect2(928, 266, 310, 48), 15, UI.MUTED)
	UI.button(screen, "[ I / Y ] 道具", Rect2(928, 402, 150, 44), _open_inventory)
	UI.button(screen, "[ ? ] 手引き", Rect2(1090, 402, 152, 44), _open_help)
	UI.label(screen, "┌ MESSAGE LOG / TURN HISTORY", Rect2(30, 485, 840, 28), 14, UI.TEAL)
	log_label = UI.rich_text(screen, "", Rect2(34, 516, 842, 170), 16)
	log_label.scroll_active = true
	log_label.scroll_following = true
	UI.rich_text(
		screen,
		(
			"[color=#739487]CURRENT SYMBOLS[/color]\n"
			+ "[color=#45f0b5]@[/color] 灯守り    [color=#ffbd4a]>[/color] 階段\n"
			+ "[color=#45f0b5]! % ? / ) ][/color] 道具\n\n"
			+ "[color=#739487]必要な操作は右上に表示。\n全コマンドは ? で確認。[/color]"
		),
		Rect2(916, 514, 320, 174),
		15
	)
	board = Board.new()
	board.position = Vector2(20, 76)
	screen.add_child(board)
	effects = Effects.new()
	board.add_child(effects)
	effects.z_index = 10
	displayed_floor = 0


func _update_hud() -> void:
	hud_line.text = (
		"[color=#ffbd4a]B%02d/05[/color]  "
		+ "HP [color=#45f0b5]%02d/%02d[/color]  "
		+ "HUNGER [color=#ffbd4a]%03d/100[/color]  "
		+ "LV %02d  XP %02d/%02d  GOLD %03d  TURN %03d"
	) % [
		run.floor_number, run.hp, run.max_hp, run.hunger,
		run.level, run.xp, run.xp_to_next(), run.gold, run.turns
	]
	equipment.text = (
		"ATK %02d / DEF %02d\nPACK %02d/%02d"
		% [run.attack_power(), run.defense_power(), run.inventory.size(), Data.PACK_LIMIT]
	)
	var lines: Array[String] = []
	for index: int in range(maxi(0, run.messages.size() - 7), run.messages.size()):
		var message: String = run.messages[index]
		var marker := "[color=#739487]%02d[/color]" % (index + 1)
		var body := message
		if "倒" in message or "空腹" in message:
			body = "[color=#ff6174]%s[/color]" % message
		elif "拾" in message or "レベル" in message or "出口" in message:
			body = "[color=#ffbd4a]%s[/color]" % message
		lines.append("%s  > %s" % [marker, body])
	log_label.text = "\n".join(lines)
	objective_label.text = _next_action_text()


func _next_action_text() -> String:
	if board.map_open:
		return (
			"[color=#45f0b5]> 地図を確認中[/color]\n\n"
			+ "@ が現在地、> が階段。\n\n"
			+ "[color=#ffbd4a][ M / SELECT ] 閉じる[/color]"
		)
	if run.player_pos == run.dungeon.stairs:
		return (
			"[color=#ffbd4a]> 階段を発見[/color]\n\n"
			+ ("最深層から脱出します。" if run.floor_number == Data.LAST_FLOOR
			else "地下図を開き、次の層へ降ります。")
			+ "\n\n[color=#45f0b5][ F / A ] 実行[/color]"
		)
	for enemy: Dictionary in run.enemies:
		var offset: Vector2i = Vector2i(enemy.pos) - run.player_pos
		if maxi(absi(offset.x), absi(offset.y)) <= 1:
			var enemy_data: Dictionary = Data.ENEMIES[enemy.kind]
			return (
				"[color=#ff6174]> 敵が隣接[/color]\n\n"
				+ "%s  %s  HP %d\n"
				% [enemy_data.glyph, enemy_data.name, enemy.hp]
				+ "%sへ移動すると ATK %d で攻撃。"
				% [_direction_name(offset), run.attack_power()]
			)
	var nearest_item: Dictionary = {}
	var nearest_distance: float = INF
	for item: Dictionary in run.ground_items:
		if not run.dungeon.visible.has(item.pos):
			continue
		var distance: float = run.player_pos.distance_to(item.pos)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_item = item
	if not nearest_item.is_empty():
		var item_data: Dictionary = Data.ITEMS[nearest_item.kind]
		var availability := "移動して拾えます。"
		if run.inventory.size() >= Data.PACK_LIMIT:
			availability = "[color=#ff6174]持ち物が満杯。I / Y で空きを作る必要があります。[/color]"
		return (
			"[color=#45f0b5]> 発光する道具[/color]\n\n"
			+ "%s  %s\n%s" % [item_data.glyph, run.item_name(nearest_item.kind), availability]
		)
	if run.hunger <= 25:
		return (
			"[color=#ff6174]> 空腹警告[/color]\n\n"
			+ "HUNGER が 0 になると毎手 HP を失います。\n\n"
			+ "[color=#45f0b5][ I / Y ] 食料を選ぶ[/color]"
		)
	return (
		"[color=#45f0b5]> 未探索の暗部を開く[/color]\n\n"
		+ "@ を一マス動かすと世界が一手進みます。\n"
		+ "明るい . を辿り、> を探してください。\n\n"
		+ "[color=#739487]? で全コマンド[/color]"
	)


func _direction_name(direction: Vector2i) -> String:
	var vertical := "北" if direction.y < 0 else ("南" if direction.y > 0 else "")
	var horizontal := "西" if direction.x < 0 else ("東" if direction.x > 0 else "")
	return vertical + horizontal


func _depth_diagram(current_depth: int) -> String:
	var lines: Array[String] = [
		"[color=#739487]地下縦断図 / DEPTH SIGNAL[/color]", ""
	]
	for depth: int in range(1, Data.LAST_FLOOR + 1):
		var line := "      │\n  ├── B%02d  %s" % [depth, "未知の層"]
		if depth == current_depth:
			line = "[color=#ffbd4a]      v\n  ╞══ B%02d  @ 到達[/color]" % depth
		elif current_depth > 0 and depth < current_depth:
			line = "[color=#45f0b5]      │\n  ├── B%02d  記録済[/color]" % depth
		lines.append(line)
	lines.append("\n      v\n[color=#ff6174]  B05 の番人 / または > で脱出[/color]")
	return "\n".join(lines)


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
	tween.tween_property(board, "position", Vector2(24, 77), 0.035)
	tween.tween_property(board, "position", Vector2(16, 75), 0.035)
	tween.tween_property(board, "position", Vector2(20, 76), 0.035)


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
			if run.descend():
				_open_depth_map.call_deferred(run.floor_number)
	else:
		run.pickup()


func _build_result() -> void:
	UI.panel(screen, Rect2(232, 78, 816, 564))
	var won: bool = run.status == "won"
	UI.label(
		screen,
		"RUN COMPLETE // 灯を地上へ" if won else "SIGNAL LOST // 灯火は次の旅へ",
		Rect2(274, 111, 740, 58),
		31,
		UI.GOLD if won else UI.ALERT
	)
	UI.rich_text(
		screen,
		"[color=#739487]┌─ LAST MESSAGE ─────────────────────────────────────────┐[/color]\n"
		+ "  %s\n[color=#739487]└─────────────────────────────────────────────────────────┘[/color]"
		% run.result_cause,
		Rect2(274, 188, 730, 100),
		18
	)
	var summary: Label = UI.label(screen, "", Rect2(316, 310, 650, 150), 21)
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

	first_focus = UI.button(screen, "> もう一度潜る", Rect2(316, 532, 300, 58), start_new)
	UI.button(screen, "< タイトルへ", Rect2(664, 532, 300, 58), return_title)
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
	dim.color = Color(0.01, 0.025, 0.035, 0.9)
	modal.add_child(dim)
	UI.panel(modal, Rect2(72, 48, 1136, 624))
	UI.label(
		modal,
		"┌─ LAMPKEEPER TERMINAL ───────────────────────────────────────────────────────────┐",
		Rect2(91, 57, 1096, 26),
		15,
		UI.MUTED
	)


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
	UI.label(
		modal,
		"PACK // 旅の道具  %02d / %02d" % [run.inventory.size(), Data.PACK_LIMIT],
		Rect2(100, 91, 650, 42),
		27,
		UI.GOLD
	)
	UI.label(modal, "選択中の道具と、実行後に起きることを右側へ表示します。", Rect2(100, 132, 760, 30), 15, UI.MUTED)
	inventory_preview = UI.rich_text(
		modal,
		"[color=#739487]> 道具を選択してください[/color]",
		Rect2(758, 174, 412, 350),
		17
	)
	UI.label(modal, "┌ SELECTED ITEM / PREVIEW", Rect2(750, 150, 420, 26), 14, UI.TEAL)
	var first: Button
	for index: int in range(run.inventory.size()):
		var item: String = run.inventory[index]
		var item_data: Dictionary = Data.ITEMS[item]
		var caption: String = "%s  %s" % [item_data.glyph, run.item_name(item)]
		if item == run.weapon or item == run.shield:
			caption += "  [EQUIPPED]"
		var button: Button = UI.button(
			modal,
			caption,
			Rect2(100 + (index % 2) * 310, 174 + (index / 2) * 61, 294, 49),
			_select_item.bind(index)
		)
		button.focus_entered.connect(_show_inventory_preview.bind(index))
		button.mouse_entered.connect(_show_inventory_preview.bind(index))
		if first == null:
			first = button
	var close: Button = UI.button(modal, "< 戻る  [ Esc / B ]", Rect2(876, 588, 292, 52), _close_modal)
	if first != null:
		first.grab_focus()
	else:
		close.grab_focus()


func _show_inventory_preview(index: int) -> void:
	if not is_instance_valid(inventory_preview) or index < 0 or index >= run.inventory.size():
		return
	var kind: String = run.inventory[index]
	var data: Dictionary = Data.ITEMS[kind]
	var reason: String = _item_use_block_reason(kind)
	var state := "[color=#45f0b5]使用できます[/color]"
	if not reason.is_empty():
		state = "[color=#ff6174]使用不可: %s[/color]" % reason
	inventory_preview.text = (
		"[color=#ffbd4a]%s  %s[/color]\n\n%s\n\n%s\n\n"
		+ "[color=#739487]決定すると、使用・投擲・廃棄の詳細へ進みます。[/color]"
	) % [data.glyph, run.item_name(kind), run.item_description(kind), state]


func _select_item(index: int) -> void:
	if index < 0 or index >= run.inventory.size():
		return
	selected_item = index
	_new_modal("item")
	var kind: String = run.inventory[index]
	var data: Dictionary = Data.ITEMS[kind]
	UI.label(
		modal,
		"%s  %s" % [data.glyph, run.item_name(kind)],
		Rect2(112, 106, 700, 58),
		30,
		UI.GOLD
	)
	UI.label(modal, run.item_description(kind), Rect2(112, 174, 1020, 50), 19)
	var action_preview: RichTextLabel = UI.rich_text(
		modal, "", Rect2(112, 264, 1020, 160), 19
	)
	UI.label(modal, "┌ ACTION PREVIEW", Rect2(104, 235, 1028, 28), 14, UI.TEAL)
	var reason: String = _item_use_block_reason(kind)
	var use: Button = UI.button(
		modal, "> 使う / 装備", Rect2(112, 456, 300, 60), _item_action.bind("use")
	)
	use.disabled = not reason.is_empty()
	var throw_button: Button = UI.button(
		modal, "> 投げる", Rect2(428, 456, 300, 60), _item_action.bind("throw")
	)
	var drop_button: Button = UI.button(
		modal, "> 捨てる", Rect2(744, 456, 300, 60), _item_action.bind("drop")
	)
	UI.button(modal, "< 道具一覧へ", Rect2(828, 580, 304, 52), _open_inventory)
	use.focus_entered.connect(_show_action_preview.bind(action_preview, kind, "use"))
	use.mouse_entered.connect(_show_action_preview.bind(action_preview, kind, "use"))
	throw_button.focus_entered.connect(_show_action_preview.bind(action_preview, kind, "throw"))
	throw_button.mouse_entered.connect(_show_action_preview.bind(action_preview, kind, "throw"))
	drop_button.focus_entered.connect(_show_action_preview.bind(action_preview, kind, "drop"))
	drop_button.mouse_entered.connect(_show_action_preview.bind(action_preview, kind, "drop"))
	if use.disabled:
		throw_button.grab_focus()
		_show_action_preview(action_preview, kind, "use")
	else:
		use.grab_focus()


func _item_use_block_reason(kind: String) -> String:
	var data: Dictionary = Data.ITEMS[kind]
	match str(data.type):
		"heal":
			return "HP が満タンです" if run.hp >= run.max_hp else ""
		"food":
			return "満腹度が 100 です" if run.hunger >= 100 else ""
		"weapon":
			return "すでに装備中です" if run.weapon == kind else ""
		"shield":
			return "すでに装備中です" if run.shield == kind else ""
	return ""


func _show_action_preview(label: RichTextLabel, kind: String, action: String) -> void:
	if not is_instance_valid(label):
		return
	var data: Dictionary = Data.ITEMS[kind]
	match action:
		"use":
			var reason := _item_use_block_reason(kind)
			if not reason.is_empty():
				label.text = "[color=#ff6174]> 実行できません[/color]\n\n%s。\n道具は消費されません。" % reason
			elif data.has("unknown") and not run.identified.has(kind):
				label.text = (
					"[color=#ffbd4a]> 未識別の効果を発動[/color]\n\n"
					+ "効果が判明し、一手経過します。"
				)
			else:
				label.text = "[color=#45f0b5]> %s[/color]\n\n%s\n一手経過します。" % [
					"装備を変更" if str(data.type) in ["weapon", "shield"] else "道具を使用",
					run.item_description(kind)
				]
		"throw":
			label.text = (
				"[color=#ffbd4a]> %sへ投擲[/color]\n\n"
				+ "最初に当たった敵へ %d ダメージ。外れた道具は床に残り、一手経過します。"
			) % [_direction_name(run.facing), 12 + run.level]
		"drop":
			label.text = (
				"[color=#739487]> 足元へ廃棄[/color]\n\n"
				+ "装備中なら外し、床へ置いて一手経過します。"
			)


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
	if modal_kind == "tutorial":
		tutorial_seen = true
		tutorial_active = false
	_new_modal("help")
	UI.label(modal, "? COMMAND REFERENCE // 探索の手引き", Rect2(108, 100, 900, 58), 30, UI.GOLD)
	UI.rich_text(
		modal,
		(
			"[color=#45f0b5]一手を進める[/color]\n"
			+ "  矢印 / WASD / 十字・左スティック  :  8方向移動、接敵で攻撃\n"
			+ "  Q E Z C                              :  斜め移動\n"
			+ "  空白 / X                             :  その場で一手待つ\n\n"
			+ "[color=#45f0b5]調べて選ぶ[/color]\n"
			+ "  F / A       :  足元を拾う、> で階段を降りる\n"
			+ "  I / Y       :  道具と実行結果のプレビュー\n"
			+ "  M / SELECT  :  探索済みの文字地図\n"
			+ "  ?           :  この手引きを開閉\n\n"
			+ "[color=#ffbd4a]目的[/color]\n"
			+ "  歩くと HUNGER が減少。0 では毎手 HP を失います。\n"
			+ "  巻物と杖は使用まで未識別。五層の番人撃破、または > から脱出でクリア。\n"
			+ "  Esc / B は中断、F11 は全画面。敗北時は持ち物を失います。"
		),
		Rect2(108, 172, 1038, 392),
		18
	)
	var close: Button = UI.button(
		modal, "< 閉じる  [ ? / Esc / B ]", Rect2(792, 586, 354, 52), _close_modal
	)
	close.grab_focus()


func _open_pause() -> void:
	_new_modal("pause")
	UI.label(modal, "PAUSE // 入力待機", Rect2(112, 122, 700, 70), 34, UI.GOLD)
	UI.label(modal, "停止中。あなたが一手を選ぶまで、地下も敵も動きません。", Rect2(112, 236, 960, 50), 21)
	var resume: Button = UI.button(modal, "> 探索を続ける", Rect2(112, 406, 420, 64), _close_modal)
	UI.button(modal, "! 旅を諦めて結果へ", Rect2(560, 406, 480, 64), _retire)
	resume.grab_focus()


func _open_tutorial() -> void:
	if not tutorial_active or run.status != "playing":
		return
	_new_modal("tutorial")
	var pages: Array[String] = [
		(
			"[color=#45f0b5]01 / 03  @ を一マス動かす[/color]\n\n"
			+ "@ があなたです。明るい . は歩ける床、# は壁。\n"
			+ "矢印 / WASD / 十字・左スティックで一手動かします。\n"
			+ "敵の文字へ進むと、その一手は攻撃になります。"
		),
		(
			"[color=#ffbd4a]02 / 03  ログと次の一手を読む[/color]\n\n"
			+ "画面下 1/3 が MESSAGE LOG。起きたことが新しい順に残ります。\n"
			+ "右の NEXT ACTION は、今できる操作と結果を場面ごとに表示。\n"
			+ "! % ? / ) ] は道具。I / Y で効果を見てから選べます。"
		),
		(
			"[color=#ff6174]03 / 03  五層から帰還する[/color]\n\n"
			+ "> を探して F / A。層の間では地下縦断図が現在地を示します。\n"
			+ "HUNGER が 0 になる前に % を使い、HP を守ってください。\n"
			+ "迷ったら ?。ここから先は一手ずつ選べます。"
		)
	]
	UI.label(modal, "FIRST DESCENT // 初回チュートリアル", Rect2(108, 102, 900, 54), 29, UI.GOLD)
	UI.rich_text(modal, pages[tutorial_page], Rect2(108, 190, 1030, 270), 21)
	UI.button(modal, "SKIP // 案内を飛ばす", Rect2(108, 574, 330, 54), _skip_tutorial)
	var next_caption := "> 探索を始める" if tutorial_page == pages.size() - 1 else "> 次へ"
	var next: Button = UI.button(modal, next_caption, Rect2(816, 574, 330, 54), _tutorial_next)
	next.grab_focus()


func _tutorial_next() -> void:
	if tutorial_page >= 2:
		_skip_tutorial()
		return
	tutorial_page += 1
	_open_tutorial()


func _skip_tutorial() -> void:
	tutorial_active = false
	tutorial_seen = true
	_close_modal()
	if run.status == "playing":
		_update_hud()


func _open_depth_map(depth: int) -> void:
	if run.status != "playing":
		return
	_new_modal("depth")
	UI.label(modal, "DESCENT LOG // 階層間の地下図", Rect2(108, 100, 900, 50), 29, UI.GOLD)
	UI.rich_text(modal, _depth_diagram(depth), Rect2(342, 154, 610, 380), 18)
	UI.label(
		modal,
		"B%02d の地形は新しい seed 配置で再構成されました。" % depth,
		Rect2(108, 542, 760, 32),
		17,
		UI.MUTED
	)
	var resume: Button = UI.button(
		modal, "> この層を探索  [ F / A ]", Rect2(792, 576, 354, 54), _close_modal
	)
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
