extends Node2D
## 描画と入力。戦闘状態はRunに集約し、画面を開き直してもランを二重生成しない。

const ATLAS: Texture2D = preload("res://assets/dungeon.png")
const FONT: Font = preload("res://assets/reading-font.tres")
const GOLD: Color = Color("e7be75")
const INK: Color = Color("101a26")
const PALE: Color = Color("e8e2d3")
const MUTED: Color = Color("97acb8")
var menu: Control
var hud: Label
var hint: Label
var time: float = 0.0
var mouse_aim: bool = false
var muted: bool = false
var music: AudioStreamPlayer
var effects: Array[AudioStreamPlayer] = []
var effect_index: int = 0

func _ready() -> void:
	get_tree().auto_accept_quit = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var theme: Theme = Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 18
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	layer.add_child(root)
	hud = label(root, "", Vector2(50, 24), 22, PALE)
	hint = label(root, "", Vector2(50, 724), 17, MUTED)
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(menu)
	Run.phase_changed.connect(rebuild_menu)
	Run.sound_requested.connect(play_sound)
	music = AudioStreamPlayer.new()
	var stream: AudioStreamOggVorbis = load("res://assets/audio/exploration.ogg") as AudioStreamOggVorbis
	stream.loop = true
	music.stream = stream
	music.volume_db = -15.0
	add_child(music)
	music.play()
	for index: int in range(8):
		var effect: AudioStreamPlayer = AudioStreamPlayer.new()
		effect.volume_db = -12.0
		add_child(effect)
		effects.append(effect)
	rebuild_menu()

func label(parent: Node, content: String, at: Vector2, size: int, color: Color = PALE) -> Label:
	var item: Label = Label.new()
	item.text = content
	item.position = at
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

func button(content: String, at: Vector2, dimensions: Vector2, action: Callable, disabled: bool = false) -> Button:
	var item: Button = Button.new()
	item.text = content
	item.position = at
	item.size = dimensions
	item.disabled = disabled
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.add_theme_color_override("font_color", PALE)
	item.add_theme_color_override("font_hover_color", Color.WHITE)
	item.add_theme_color_override("font_disabled_color", MUTED.darkened(0.3))
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Color("283b48") if state in ["hover", "focus"] else INK
		box.border_color = GOLD if state in ["hover", "focus"] else Color("4b5555")
		box.set_border_width_all(2 if state == "focus" else 1)
		box.set_corner_radius_all(4)
		item.add_theme_stylebox_override(state, box)
	item.pressed.connect(action)
	menu.add_child(item)
	return item

func rebuild_menu() -> void:
	for child: Node in menu.get_children():
		menu.remove_child(child)
		child.queue_free()
	if Run.phase == Run.Phase.CAMP:
		label(menu, "灯守の迷宮", Vector2(104, 186), 58, GOLD)
		label(menu, "消えても、灯は受け継がれる", Vector2(108, 274), 23)
		label(menu, "六つの部屋を越え、迷宮の心臓に朝を取り戻す\n剣と回避で敵を倒し、欠片を持ち帰ろう", Vector2(108, 329), 18, MUTED)
		button("迷宮へ入る  →  [ Enter ]", Vector2(108, 427), Vector2(420, 60), begin).grab_focus()
		label(menu, "WASD / 矢印   移動      J / クリック   攻撃\nSpace   無敵回避      E   扉を開く\nEsc   一時停止      M   音の切り替え", Vector2(108, 518), 17, MUTED)
		label(menu, "焚き火の工房", Vector2(682, 219), 28, GOLD)
		label(menu, "持ち帰った欠片  %d    /    踏破 %d / 6" % [Run.bank, Run.best], Vector2(682, 275), 18)
		button("命の灯  %d / 5\n最大体力 +2    欠片 %d" % [Run.vitality, Run.upgrade_cost(0)], Vector2(682, 339), Vector2(350, 86), buy.bind(0), Run.vitality >= 5 or Run.bank < Run.upgrade_cost(0))
		button("剣の記憶  %d / 3\n初期威力 +1    欠片 %d" % [Run.mastery, Run.upgrade_cost(1)], Vector2(682, 445), Vector2(350, 86), buy.bind(1), Run.mastery >= 3 or Run.bank < Run.upgrade_cost(1))
		label(menu, "倒れたら欠片の半分を持ち帰る\n部屋を制圧して帰還すれば、すべて残る", Vector2(682, 558), 17, MUTED)
		label(menu, "素材  Kenney / Ruhinre / Noto", Vector2(108, 660), 14, MUTED)
	elif Run.phase == Run.Phase.CHOICE:
		label(menu, "ひとつ、灯に宿す", Vector2(374, 248), 38, GOLD)
		label(menu, "この探索だけの力を選び、次の部屋へ", Vector2(373, 312), 18, MUTED)
		for index: int in range(Run.choices.size()):
			var boon: Dictionary = Run.BOONS[Run.choices[index]]
			var item: Button = button("%d   %s\n\n%s" % [index + 1, boon.name, boon.detail], Vector2(126 + index * 306, 379), Vector2(288, 130), select_boon.bind(index))
			if index == 0:
				item.grab_focus()
		button("欠片 %d を持って帰還する" % Run.shards, Vector2(361, 565), Vector2(430, 58), retreat)
	elif Run.phase == Run.Phase.RESULT:
		label(menu, Run.result, Vector2(282, 260), 44, GOLD)
		label(menu, "到達  第%d室    /    探索時間 %d秒" % [Run.room, int(Run.elapsed)], Vector2(348, 346), 21, MUTED)
		label(menu, "持ち帰った欠片  +%d" % Run.collected, Vector2(348, 399), 32)
		label(menu, "焚き火の欠片  %d     力を整え、もう一度" % Run.bank, Vector2(348, 456), 18, MUTED)
		button("焚き火へ戻る  [ Enter ]", Vector2(348, 532), Vector2(456, 64), Run.camp).grab_focus()
	elif Run.paused:
		label(menu, "ひと休み", Vector2(449, 301), 42, GOLD)
		button("探索に戻る  [ Esc ]", Vector2(376, 402), Vector2(400, 64), toggle_pause).grab_focus()
		button("探索を終える・欠片の半分を持ち帰る", Vector2(326, 498), Vector2(500, 58), abandon)
	if not Run.save_error.is_empty():
		label(menu, Run.save_error, Vector2(180, 690), 16, Color("ffaaaa"))
		button("保存を再試行", Vector2(912, 731), Vector2(190, 45), retry_save)
	queue_redraw()

func begin() -> void:
	Run.start()

func buy(kind: int) -> void:
	Run.purchase(kind)

func select_boon(index: int) -> void:
	Run.choose(index)

func retreat() -> void:
	Run.finish("灯を連れて帰還した", true)

func abandon() -> void:
	Run.finish("探索を切り上げた", false)

func retry_save() -> void:
	Run.save_progress()
	rebuild_menu()

func toggle_pause() -> void:
	if Run.phase != Run.Phase.PLAY:
		return
	Run.paused = not Run.paused
	rebuild_menu()

func movement() -> Vector2:
	return Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_aim = true
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT:
				mouse_aim = false
			KEY_M:
				muted = not muted
				AudioServer.set_bus_mute(0, muted)
			KEY_ESCAPE:
				toggle_pause()
			KEY_SPACE:
				Run.dash(movement())
			KEY_E:
				Run.interact()
			KEY_1, KEY_2, KEY_3:
				Run.choose(event.physical_keycode - KEY_1)
			KEY_ENTER:
				if Run.phase == Run.Phase.CAMP:
					begin()
				elif Run.phase == Run.Phase.RESULT:
					Run.camp()

func _physics_process(delta: float) -> void:
	var direction: Vector2 = movement()
	var aim: Vector2 = get_global_mouse_position() - Run.player if mouse_aim else direction
	Run.advance(delta, direction, aim)
	if Input.is_physical_key_pressed(KEY_J) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		Run.swing()

func _process(delta: float) -> void:
	time += delta
	if Run.phase in [Run.Phase.PLAY, Run.Phase.CHOICE]:
		hud.text = "灯守   %d / %d     剣 %d     欠片 %d" % [Run.health, Run.max_health, Run.power, Run.shards]
		if Run.clear:
			hint.text = "部屋を制圧  ·  体力 +1     →  右の灯る扉へ進み [ E ]" if Run.room < 6 else "迷宮の心臓を鎮めた  →  右の灯る扉へ進み [ E ] で帰還"
		else:
			hint.text = "WASD / 矢印  移動    J / クリック  攻撃    Space  回避    Esc  一時停止"
	else:
		hud.text = "灯 守 の 迷 宮"
		hint.text = ""
	queue_redraw()

func play_sound(kind: String) -> void:
	if effects.is_empty():
		return
	var file: String = "attack"
	match kind:
		"hurt": file = "hurt"
		"reward": file = "pickup"
		"dash": file = "step"
	var effect: AudioStreamPlayer = effects[effect_index % effects.size()]
	effect_index += 1
	effect.stream = load("res://assets/audio/%s.ogg" % file)
	effect.pitch_scale = 0.85 if kind == "hit" else 1.0
	effect.play()

func stop_audio() -> void:
	music.stop()
	music.stream = null
	for effect: AudioStreamPlayer in effects:
		effect.stop()
		effect.stream = null
	# 音声スレッドが停止要求を取り込んでからtreeを破棄する。
	await get_tree().create_timer(0.15).timeout

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		await stop_audio()
		get_tree().quit()

func tile(index: int, at: Vector2, dimensions: Vector2 = Vector2(48, 48), tint: Color = Color.WHITE) -> void:
	var region: Rect2 = Rect2(Vector2((index % 12) * 16, (index / 12) * 16), Vector2(16, 16))
	draw_texture_rect_region(ATLAS, Rect2(at, dimensions), region, tint)

func text(content: String, at: Vector2, size: int = 18, color: Color = PALE) -> void:
	draw_string(FONT, at, content, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func glow(at: Vector2, radius: float, color: Color) -> void:
	for index: int in range(6, 0, -1):
		draw_circle(at, radius * float(index) / 6.0, Color(color, 0.025))

func torch(at: Vector2) -> void:
	glow(at, 100.0 + sin(time * 5.0) * 5.0, GOLD)
	tile(125, at - Vector2(12, 8), Vector2(24, 36), Color("a97149"))
	draw_circle(at - Vector2(0, 9), 7 + sin(time * 9.0), Color("ffb65a"))
	draw_circle(at - Vector2(0, 12), 3, Color("fff2b3"))

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1152, 800), Color("090f19"))
	for row: int in range(12):
		for column: int in range(22):
			var at: Vector2 = Vector2(48 + column * 48, 128 + row * 48)
			if row == 0 or row == 11 or column == 0 or column == 21:
				tile(14, at, Vector2(48, 48), Color("677783"))
			else:
				tile(48 + ((row * 7 + column * 3) % 6), at, Vector2(48, 48), Color("586774"))
				draw_rect(Rect2(at, Vector2(48, 48)), Color(0.02, 0.07, 0.12, 0.22))
	for at: Vector2 in [Vector2(116, 188), Vector2(986, 188), Vector2(122, 600), Vector2(984, 596)]:
		tile(56, at, Vector2(40, 40), Color("789198"))
	draw_rect(Rect2(96, 176, 960, 480), Color("1b2633"), false, 3)
	for at: Vector2 in [Vector2(168, 155), Vector2(552, 155), Vector2(984, 155), Vector2(168, 681), Vector2(984, 681)]:
		torch(at)
	if Run.phase == Run.Phase.CAMP:
		tile(96, Vector2(560, 538), Vector2(84, 84))
		glow(Vector2(600, 605), 150, GOLD)
	else:
		for obstacle: Rect2 in Run.obstacles:
			draw_rect(Rect2(obstacle.position + Vector2(8, 12), obstacle.size), Color(0, 0, 0, 0.4))
			for row: int in range(int(obstacle.size.y) / 48):
				tile(14, obstacle.position + Vector2(0, row * 48), Vector2(48, 48), Color("a2afb7"))
		var exit_color: Color = Color("9de3b4") if Run.clear else Color("515764")
		if Run.clear:
			glow(Run.EXIT, 125, exit_color)
		draw_rect(Rect2(Run.EXIT - Vector2(23, 38), Vector2(46, 76)), Color("0c131e"))
		draw_arc(Run.EXIT, 30, 0, TAU, 32, exit_color, 3)
		text("E" if Run.clear else "封", Run.EXIT + Vector2(-9, 8), 22, exit_color)
		for foe: Run.Foe in Run.foes:
			draw_foe(foe)
		for shot: Run.Shot in Run.shots:
			glow(shot.position, 23, Color("fc7f86"))
			draw_circle(shot.position, 7, Color("a94466"))
			draw_circle(shot.position, 3, Color("ffe4ae"))
		draw_player()
		draw_rect(Rect2(50, 66, 300, 9), Color("263542"))
		draw_rect(Rect2(50, 66, 300.0 * Run.health / Run.max_health, 9), Color("b4d295"))
		text("第 %d 室 / 6   %s" % [Run.room, "迷宮の心臓" if Run.room == 6 else "忘れられた回廊"], Vector2(712, 53), 23, GOLD)
		for index: int in range(6):
			draw_circle(Vector2(730 + index * 58, 89), 5, GOLD if index < Run.room else Color("35424d"))
		text("回避  %s" % ("準備完了" if Run.dash_wait <= 0.0 else "%.1f秒" % Run.dash_wait), Vector2(430, 57), 18, MUTED)
		if not Run.taken.is_empty():
			text("灯に宿る力  " + " ・ ".join(Run.taken), Vector2(50, 113), 15, GOLD)
		if Run.clear:
			text("制 圧", Vector2(532, 215), 22, Color("b4d295"))
	text("音 OFF" if muted else "音 ON  [M]", Vector2(990, 767), 15, MUTED)
	if Run.phase != Run.Phase.PLAY or Run.paused:
		draw_rect(Rect2(0, 122, 1152, 588), Color(0.02, 0.04, 0.065, 0.90 if Run.phase == Run.Phase.CAMP else 0.87))
		if Run.phase == Run.Phase.CAMP:
			draw_line(Vector2(614, 209), Vector2(614, 620), Color("445050"), 1)
		else:
			draw_rect(Rect2(96, 213, 960, 423), INK)
			draw_rect(Rect2(96, 213, 960, 423), Color("7a7056"), false, 1)

func draw_player() -> void:
	if Run.dash_left > 0:
		for index: int in range(1, 5):
			tile(96, Run.player - Run.dash_direction * index * 13.0 - Vector2(24, 34), Vector2(48, 48), Color(0.5, 0.85, 1.0, 0.3 / index))
	draw_set_transform(Run.player, 0, Vector2(1, 0.4))
	draw_circle(Vector2(0, 24), 20, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO)
	glow(Run.player, 125, GOLD)
	var bob: float = sin(time * 12.0) * 2.0 if movement().length() > 0 else sin(time * 2.0)
	var tint: Color = Color(1, 1, 1, 0.45) if Run.invulnerable > 0 and int(time * 12) % 2 == 0 else Color.WHITE
	tile(96, Run.player + Vector2(-24, -35 + bob), Vector2(48, 48), tint)
	var angle: float = Run.facing.angle()
	draw_line(Run.player + Run.facing * 28, Run.player + Run.facing * 43, GOLD, 3)
	if Run.attack_left > 0:
		var progress: float = 1.0 - Run.attack_left / 0.17
		draw_arc(Run.player, Run.reach, angle - 1.1, angle + 1.1, 25, Color(1, 0.84, 0.55, 1.0 - progress), 6)
		draw_arc(Run.player, Run.reach - 12, angle - 0.9, angle + 0.9, 20, Color(1, 1, 0.9, 0.5 - progress * 0.5), 3)

func draw_foe(foe: Run.Foe) -> void:
	var dimensions: Vector2 = Vector2(80, 80) if foe.kind == 3 else Vector2(48, 48)
	var tint: Color = Color("f0a6ae") if foe.kind == 3 else Color.WHITE
	if foe.flash > 0:
		tint = Color(2, 2, 2)
	if foe.kind == 2 and foe.timer < 0.55 and foe.timer > 0:
		draw_line(foe.position, foe.target, Color(0.9, 0.4, 0.3, 0.5), 3)
		draw_arc(foe.position, 27, 0, TAU, 24, Color("ef927c"), 2)
	if foe.kind == 3:
		draw_arc(foe.position, 54, 0, TAU * (1.0 - clampf(foe.timer / 2.6, 0, 1)), 40, Color("dd7582"), 3)
	draw_circle(foe.position + Vector2(0, 7), dimensions.x * 0.34, Color(0, 0, 0, 0.3))
	tile([108, 124, 120, 122][foe.kind], foe.position - dimensions * Vector2(0.5, 0.72) + Vector2(0, sin(time * 5 + foe.position.x) * 2), dimensions, tint)
	var width: float = dimensions.x
	draw_rect(Rect2(foe.position + Vector2(-width / 2, -dimensions.y * 0.8), Vector2(width, 4)), Color("362331"))
	draw_rect(Rect2(foe.position + Vector2(-width / 2, -dimensions.y * 0.8), Vector2(width * foe.health / foe.maximum, 4)), Color("d6797c"))
