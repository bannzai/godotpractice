extends Control
## 入力と描画だけを担当し、進行状態は RunState が所有する。

const Rules = preload("res://scripts/game_rules.gd")
const INK := Color("102b33")
const PANEL := Color("193e48")
const CREAM := Color("f6efd6")
const MINT := Color("8de0c4")
const GOLD := Color("f4cc76")
const MUTED := Color("a9c5c4")
const CENTER := Vector2(640, 392)
const WEAPON_IDS: Array[String] = ["bolt", "orbit", "pulse"]

var state: Node
var face: Font
var textures: Dictionary = {}
var sounds: Dictionary = {}
var music: AudioStreamPlayer
var sound_players: Array[AudioStreamPlayer] = []
var controls: Control
var shown_phase: String = ""
var decoration_time: float = 0.0
var muted: bool = false
var audio_enabled: bool = false


func _ready() -> void:
	audio_enabled = AudioServer.get_driver_name() != "Dummy"
	state = get_node("/root/RunState")
	face = load("res://assets/fonts/font.ttf")
	for key: String in [
		"floor",
		"player",
		"enemy-0",
		"enemy-1",
		"enemy-2",
		"enemy-3",
		"gem",
		"heal",
		"magnet",
		"bolt",
		"orbit",
		"pulse",
		"title-emblem"
	]:
		textures[key] = load("res://assets/art/%s.svg" % key)
	for cue: String in ["attack", "hurt", "level", "pickup"]:
		sounds[cue] = load("res://assets/audio/%s.wav" % cue)
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/bgm.wav")
	music.volume_db = -12.0
	add_child(music)
	music.finished.connect(music.play)
	if audio_enabled:
		music.play()
	for i: int in range(8):
		var player := AudioStreamPlayer.new()
		player.volume_db = -10.0
		add_child(player)
		sound_players.append(player)
	state.sound_requested.connect(_play_sound)
	controls = Control.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(controls)
	_refresh_screen()
	print("survivors boot")


func _exit_tree() -> void:
	if is_instance_valid(music):
		music.stop()
	for player: AudioStreamPlayer in sound_players:
		player.stop()


# 実時間と入力による進行のため、フレームごとに状態を更新する。
func _process(delta: float) -> void:
	decoration_time += delta
	state.step(delta, Input.get_vector("move_left", "move_right", "move_up", "move_down"))
	if state.phase != shown_phase:
		_refresh_screen()
	queue_redraw()


# ユーザーの操作ごとに表示モードを切り替える。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var fullscreen: bool = (
			DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		)
		DisplayServer.window_set_mode(
			(
				DisplayServer.WINDOW_MODE_WINDOWED
				if fullscreen
				else DisplayServer.WINDOW_MODE_FULLSCREEN
			)
		)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		state.toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("mute"):
		muted = not muted
		AudioServer.set_bus_mute(0, muted)
		get_viewport().set_input_as_handled()


# 同じ音の再生要求は別の攻撃・取得を表すため再生する。
func _play_sound(cue: String) -> void:
	if not audio_enabled or not sounds.has(cue):
		return
	for player: AudioStreamPlayer in sound_players:
		if not player.playing:
			player.stream = sounds[cue]
			player.play()
			return


func _refresh_screen() -> void:
	shown_phase = state.phase
	for child: Node in controls.get_children():
		controls.remove_child(child)
		child.queue_free()
	match shown_phase:
		"title":
			_button("森へ向かう", Rect2(96, 438, 340, 64), _start, true)
		"upgrade":
			for i: int in range(state.choices.size()):
				_button(
					"この力を選ぶ", Rect2(170 + i * 322, 480, 292, 56), _choose_upgrade.bind(i), i == 0
				)
		"paused":
			_button("探索を続ける", Rect2(470, 354, 340, 58), state.toggle_pause, true)
			_button("タイトルへ戻る", Rect2(470, 434, 340, 58), state.return_title)
		"result":
			_button("もう一度 挑む", Rect2(326, 503, 300, 60), _start, true)
			_button("タイトルへ", Rect2(650, 503, 300, 60), state.return_title)


func _button(caption: String, rect: Rect2, action: Callable, focused: bool = false) -> void:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = caption
	button.add_theme_font_override("font", face)
	button.add_theme_font_size_override("font_size", 23)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_stylebox_override("normal", _style(PANEL, MINT, 1))
	button.add_theme_stylebox_override("hover", _style(MINT, MINT, 2))
	button.add_theme_stylebox_override("focus", _style(GOLD, GOLD, 3))
	button.add_theme_stylebox_override("pressed", _style(GOLD, GOLD, 3))
	button.pressed.connect(action)
	controls.add_child(button)
	if focused:
		button.grab_focus()


func _style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(12)
	return style


func _choose_upgrade(index: int) -> void:
	state.choose_upgrade(index)
	_refresh_screen()


func _start() -> void:
	state.start_run(int(Time.get_ticks_usec()))


func _draw() -> void:
	if state == null or face == null:
		return
	_draw_field()
	if state.phase == "title":
		_draw_title()
		return
	_draw_entities()
	_draw_hud()
	match state.phase:
		"upgrade":
			_draw_upgrade()
		"paused":
			_shade()
			_box(Rect2(390, 208, 500, 330), PANEL, MINT)
			_text("ひと休み", Vector2(525, 282), 38, CREAM)
			_text("森の時間は止まっています", Vector2(484, 324), 21, MUTED)
		"result":
			_draw_result()


func _draw_field() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	var offset: Vector2 = state.player_pos if state.phase != "title" else Vector2.ZERO
	var tile_origin := Vector2(fposmod(-offset.x, 128.0), fposmod(-offset.y, 128.0))
	for y: int in range(-1, 7):
		for x: int in range(-1, 11):
			draw_texture_rect(
				textures.floor, Rect2(tile_origin + Vector2(x, y) * 128, Vector2(128, 128)), false
			)
	if state.phase != "title":
		var world_start: Vector2 = _screen(Vector2(-Rules.WORLD_LIMIT, -Rules.WORLD_LIMIT))
		draw_rect(Rect2(world_start, Vector2.ONE * Rules.WORLD_LIMIT * 2), MINT, false, 4)
	for i: int in range(28):
		var point := Vector2(
			fposmod(i * 173.0 + sin(decoration_time + i) * 9, 1280),
			fposmod(i * 89.0 + decoration_time * 4, 720)
		)
		draw_circle(point, 1.5, Color(0.8, 1.0, 0.68, 0.25 + sin(i + decoration_time) * 0.16))


func _draw_title() -> void:
	draw_rect(Rect2(48, 48, 1184, 624), Color(0.04, 0.13, 0.17, 0.90))
	draw_line(Vector2(96, 118), Vector2(186, 118), GOLD, 3)
	_text("夜明けを待つ、小さな冒険", Vector2(208, 126), 22, GOLD)
	_text("宵森の灯守", Vector2(90, 257), 72, CREAM)
	_text("灯を絶やさず、夜を越えよう。", Vector2(96, 316), 26, MINT)
	_text("移動するだけで魔法は自動発動。", Vector2(96, 371), 21, MUTED)
	_text("光のかけらを集め、力を選び、10分間を生き抜く。", Vector2(96, 405), 21, MUTED)
	_art("title-emblem", Vector2(962, 325), 284)
	draw_arc(
		Vector2(962, 325),
		176,
		decoration_time * 0.1,
		decoration_time * 0.1 + TAU * 0.83,
		72,
		Color(0.6, 0.9, 0.76, 0.35),
		2
	)
	_text("移動  WASD / 矢印 / 左スティック", Vector2(96, 551), 19, CREAM)
	_text("選択  Enter / パッド A / クリック", Vector2(96, 586), 19, CREAM)
	_text("休止  Esc / Start     全画面  F11     消音  M", Vector2(96, 629), 18, MUTED)
	_text("光を拾う", Vector2(885, 543), 18, MINT)
	_art("gem", Vector2(851, 536), 24)
	_text("力を育てる", Vector2(885, 580), 18, MINT)
	_art("orbit", Vector2(851, 573), 28)
	_text("夜を越える", Vector2(885, 617), 18, MINT)
	_art("player", Vector2(851, 610), 30)


func _draw_entities() -> void:
	for gem: Dictionary in state.gems:
		_art("gem", _screen(gem.pos), 16)
	for item: Dictionary in state.items:
		var point: Vector2 = _screen(item.pos)
		draw_circle(point, 23 + sin(decoration_time * 3) * 3, Color(0.8, 0.9, 0.5, 0.14))
		_art(item.kind, point, 32)
	for enemy: Dictionary in state.enemies:
		var point: Vector2 = _screen(enemy.pos)
		if not Rect2(-100, -100, 1480, 920).has_point(point):
			continue
		draw_circle(
			point + Vector2(0, enemy.radius * 0.6), enemy.radius * 0.8, Color(0, 0, 0, 0.25)
		)
		_art("enemy-%d" % enemy.kind, point, enemy.radius * 2.6)
		if enemy.kind == 3:
			_bar(
				Rect2(point + Vector2(-52, -65), Vector2(104, 6)),
				enemy.hp / float(Rules.enemy_stats(3).hp),
				Color("eb887c")
			)
	for projectile: Dictionary in state.projectiles:
		_art("bolt", _screen(projectile.pos), 22)
	if state.weapons.orbit > 0:
		for i: int in range(state.weapons.orbit + 1):
			_art("orbit", _screen(state.orbit_position(i)), 30)
	draw_circle(CENTER + Vector2(0, 19), 23, Color(0, 0, 0, 0.25))
	draw_circle(CENTER, 35 + sin(decoration_time * 2) * 3, Color(1, 0.84, 0.46, 0.1))
	var blink: bool = state.invulnerable > 0 and int(decoration_time * 16) % 2 == 0
	_art("player", CENTER, 52, Color(1, 0.55, 0.55) if blink else Color.WHITE)
	_draw_effects()


func _draw_effects() -> void:
	for effect: Dictionary in state.effects:
		var point: Vector2 = _screen(effect.pos)
		var alpha: float = clampf(1.0 - effect.age / 0.7, 0, 1)
		match effect.kind:
			"death":
				for i: int in range(6):
					draw_circle(
						point + Vector2.from_angle(i * TAU / 6) * effect.age * 64,
						4 * alpha,
						Color(0.77, 0.94, 0.7, alpha)
					)
			"pulse", "level", "magnet":
				draw_arc(point, 20 + effect.age * 250, 0, TAU, 64, Color(0.5, 0.94, 0.84, alpha), 4)
		if not effect.text.is_empty():
			_text(
				effect.text,
				point + Vector2(-12, -25 - effect.age * 50),
				20,
				Color(1, 0.87, 0.58, alpha)
			)


func _draw_hud() -> void:
	_box(Rect2(20, 16, 1240, 94), Color(0.05, 0.16, 0.2, 0.95), Color("36626a"))
	_text("灯守", Vector2(42, 49), 20, GOLD)
	_text("体力  %d / %d" % [state.hp, state.max_hp], Vector2(116, 48), 19, CREAM)
	_bar(Rect2(42, 66, 294, 16), state.hp / state.max_hp, Color("eb9580"))
	_text("夜明けまで", Vector2(574, 44), 16, MUTED)
	_text(_clock(maxf(0.0, Rules.DURATION - state.elapsed)), Vector2(574, 84), 34, CREAM)
	_text("撃破  %d" % state.kills, Vector2(770, 49), 22, CREAM)
	_text("レベル  %d" % state.level, Vector2(1018, 49), 22, GOLD)
	_bar(Rect2(770, 71, 446, 10), float(state.xp) / Rules.xp_needed(state.level), MINT)
	for i: int in range(3):
		var id: String = WEAPON_IDS[i]
		var rect := Rect2(26 + i * 182, 635, 170, 61)
		_box(rect, Color(0.05, 0.16, 0.2, 0.93), Color("36626a"))
		_art(
			id,
			rect.position + Vector2(28, 29),
			34,
			Color.WHITE if state.weapons[id] > 0 else Color(0.4, 0.5, 0.5, 0.6)
		)
		_text(Rules.WEAPON_NAMES[id], rect.position + Vector2(52, 26), 17, CREAM)
		_text(
			"未習得" if state.weapons[id] == 0 else "段階 %d / 3" % state.weapons[id],
			rect.position + Vector2(52, 49),
			15,
			MINT
		)
	_text("移動 WASD / 左スティック   休止 Esc / Start", Vector2(745, 683), 16, MUTED)
	if state.elapsed >= 570:
		_text("夜の主が現れた ― 夜明けまで耐えよう", Vector2(415, 146), 22, GOLD)
	elif state.elapsed < 12:
		_text("光のかけらで成長。赤い実で回復、磁石で光を集めよう。", Vector2(345, 144), 19, CREAM)
	if muted:
		_text("消音中  Mで解除", Vector2(1090, 623), 15, GOLD)


func _draw_upgrade() -> void:
	_shade()
	_text("灯に、新しい力を", Vector2(452, 181), 38, CREAM)
	_text("レベル %d    時間は止まっています。ひとつ選んで進もう。" % state.level, Vector2(342, 223), 20, MINT)
	for i: int in range(state.choices.size()):
		var id: String = state.choices[i]
		var origin := Vector2(154 + i * 322, 263)
		_box(Rect2(origin, Vector2(308, 295)), PANEL, Color("50817d"))
		var icon: String = id if id in WEAPON_IDS else "title-emblem"
		_art(icon, origin + Vector2(154, 59), 64)
		_text(state.upgrade_name(id), origin + Vector2(24, 124), 25, CREAM)
		var description: String = state.upgrade_description(id)
		_wrapped_text(description, origin + Vector2(24, 161), 260, 18, MUTED)
	_text("矢印 / 十字キーで移動    Enter / Aで決定    クリックでも選べます", Vector2(317, 605), 18, MUTED)


func _draw_result() -> void:
	_shade()
	_box(Rect2(262, 123, 756, 478), PANEL, GOLD)
	_art("title-emblem", Vector2(640, 194), 84)
	_text("夜明けを迎えた" if state.won else "灯は、またともる", Vector2(436, 289), 42, CREAM)
	_text("森に朝の光が戻りました。" if state.won else "集めた光は、次の冒険の道しるべ。", Vector2(428, 331), 21, MINT)
	var labels: Array[String] = ["生存時間", "撃破数", "到達レベル"]
	var values: Array[String] = [_clock(state.elapsed), str(state.kills), str(state.level)]
	for i: int in range(3):
		var x: float = 365 + i * 222
		_text(labels[i], Vector2(x, 396), 19, MUTED)
		_text(values[i], Vector2(x, 448), 38, GOLD)


func _screen(point: Vector2) -> Vector2:
	return point - state.player_pos + CENTER


func _art(key: String, center: Vector2, extent: float, tint: Color = Color.WHITE) -> void:
	draw_texture_rect(
		textures[key], Rect2(center - Vector2.ONE * extent / 2, Vector2.ONE * extent), false, tint
	)


func _text(value: String, point: Vector2, font_size: int, color: Color) -> void:
	draw_string(face, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _wrapped_text(
	value: String, point: Vector2, width: float, font_size: int, color: Color
) -> void:
	var line: String = ""
	var y: float = point.y
	for character: String in value:
		if (
			face.get_string_size(line + character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			> width
		):
			_text(line, Vector2(point.x, y), font_size, color)
			line = ""
			y += font_size + 9
		line += character
	_text(line, Vector2(point.x, y), font_size, color)


func _box(rect: Rect2, fill: Color, border: Color) -> void:
	draw_style_box(_style(fill, border, 1), rect)


func _bar(rect: Rect2, fraction: float, color: Color) -> void:
	draw_rect(rect, Color("10232b"))
	draw_rect(
		Rect2(rect.position, Vector2(rect.size.x * clampf(fraction, 0, 1), rect.size.y)), color
	)


func _shade() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.08, 0.12, 0.88))


func _clock(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]
