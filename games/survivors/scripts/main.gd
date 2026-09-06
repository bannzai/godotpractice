extends Control
## 入力と描画だけを担当し、進行状態は RunState が所有する。

const Rules = preload("res://scripts/game_rules.gd")
const INK := Color("102b33")
const PANEL := Color("142c39")
const CREAM := Color("f6efd6")
const MINT := Color("8de0c4")
const GOLD := Color("f4cc76")
const MUTED := Color("a9c5c4")
const CENTER := Vector2(640, 392)
const WEAPON_IDS: Array[String] = ["bolt", "orbit", "pulse"]

var state: Node
var face: Font
var textures: Dictionary = {}
var audio: Node
var arena: Node2D
var effects_layer: Node2D
var transition: ColorRect
var flash: ColorRect
var transition_tween: Tween
var flash_tween: Tween
var shown_hp: float = 100.0
var shown_kills: float = 0.0
var result_progress: float = 1.0
var result_delay: float = 0.0
var hit_stop: float = 0.0
var controls: Control
var shown_phase: String = ""
var decoration_time: float = 0.0
var muted: bool = false
var audio_enabled: bool = false


func _ready() -> void:
	state = get_node("/root/RunState")
	face = load("res://assets/fonts/font.ttf")
	theme = load("res://assets/theme/night.tres")
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
		"title-emblem",
		"forest-far",
		"forest-near",
		"mist",
		"key-art",
		"logo",
		"icon-health",
		"icon-clock",
		"icon-kills",
		"icon-speed",
		"icon-armor",
		"icon-pause",
		"icon-sound"
	]:
		textures[key] = load("res://assets/art/%s.svg" % key)
	arena = load("res://scripts/arena.gd").new()
	arena.z_index = -1
	add_child(arena)
	arena.setup(state, textures, face)
	effects_layer = arena.effects_layer
	audio = load("res://scripts/audio_director.gd").new()
	add_child(audio)
	audio.setup(state)
	state.effect_requested.connect(_impact)
	controls = Control.new()
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(controls)
	flash = _overlay(Color(1, 0.7, 0.45, 0), 3)
	transition = _overlay(Color(0.025, 0.055, 0.09, 0), 4)
	_refresh_screen()
	print("survivors boot")
	if OS.has_feature("editor") and OS.get_environment("SURVIVORS_RUN_CAPTURE") == "1":
		add_child(load("res://scripts/dev/run_capture.gd").new())


func _overlay(color: Color, depth: int) -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = depth
	add_child(rect)
	return rect


func shutdown() -> void:
	set_process(false)
	if is_instance_valid(audio):
		audio.shutdown()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		shutdown()
		get_tree().quit()


func _exit_tree() -> void:
	shutdown()


# 実時間と入力による進行のため、フレームごとに状態を更新する。
func _process(delta: float) -> void:
	decoration_time += delta
	if hit_stop > 0.0:
		hit_stop = maxf(0.0, hit_stop - delta)
	else:
		state.step(delta, Input.get_vector("move_left", "move_right", "move_up", "move_down"))
	shown_hp = move_toward(shown_hp, state.hp, delta * 90.0)
	shown_kills = move_toward(
		shown_kills, state.kills, delta * maxf(40, absf(state.kills - shown_kills) * 5)
	)
	result_delay = maxf(0.0, result_delay - delta)
	if result_delay <= 0.0:
		result_progress = minf(1.0, result_progress + delta * 1.5)
	controls.visible = state.phase != "result" or result_delay <= 0.0
	audio.set_scene(state.phase, state.boss_spawned)
	if state.phase != shown_phase:
		_refresh_screen()
	queue_redraw()


func _impact(_at: Vector2, kind: String, caption: String) -> void:
	if kind not in ["level", "boss"] and not (kind == "hit" and caption.begins_with("-")):
		return
	if kind == "hit":
		hit_stop = 0.045
	if flash_tween:
		flash_tween.kill()
	flash.color = Color(1, 0.55, 0.4, 0.16) if kind == "hit" else Color(1, 0.88, 0.62, 0.19)
	flash_tween = create_tween()
	flash_tween.tween_property(flash, "color:a", 0.0, 0.35)


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


func _refresh_screen() -> void:
	var previous: String = shown_phase
	shown_phase = state.phase
	if shown_phase == "playing" and previous in ["title", "result"]:
		arena.reset()
		shown_hp = state.hp
		shown_kills = state.kills
	if shown_phase == "title":
		arena.reset()
	if shown_phase == "result":
		# 灯守が消える0.6秒を見届けてから結果を表示する。
		result_delay = 0.0 if state.won else 0.65
		controls.visible = result_delay <= 0.0
		result_progress = 0.0
		audio.play_cue("result")
	if previous != shown_phase:
		if transition_tween:
			transition_tween.kill()
		transition.color.a = 0.88 if previous in ["title", "result"] else 0.42
		controls.modulate.a = 0.0
		controls.position.y = 12.0
		transition_tween = create_tween().set_parallel(true)
		transition_tween.tween_property(transition, "color:a", 0.0, 0.48)
		transition_tween.tween_property(controls, "modulate:a", 1.0, 0.34)
		transition_tween.tween_property(controls, "position:y", 0.0, 0.34).set_trans(
			Tween.TRANS_CUBIC
		)
	for child: Node in controls.get_children():
		controls.remove_child(child)
		child.queue_free()
	match shown_phase:
		"title":
			_button("森へ向かう", Rect2(96, 438, 340, 64), _start, true)
		"upgrade":
			for i: int in range(state.choices.size()):
				_button(
					"この力を選ぶ", Rect2(170 + i * 322, 480, 276, 56), _choose_upgrade.bind(i), i == 0
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
	button.pivot_offset = rect.size * 0.5
	button.mouse_entered.connect(_animate_button.bind(button, 1.035))
	button.mouse_exited.connect(_animate_button.bind(button, 1.0))
	button.button_down.connect(_animate_button.bind(button, 0.97))
	button.button_up.connect(_animate_button.bind(button, 1.0))
	button.pressed.connect(func() -> void: audio.play_cue("ui"))
	button.pressed.connect(action)
	controls.add_child(button)
	if focused:
		button.grab_focus()


func _animate_button(button: Button, factor: float) -> void:
	if button.has_meta("tween"):
		var previous: Tween = button.get_meta("tween")
		previous.kill()
	var tween: Tween = button.create_tween()
	button.set_meta("tween", tween)
	tween.tween_property(button, "scale", Vector2.ONE * factor, 0.12)


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
	if state.phase == "title":
		_draw_title()
		return
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
			if result_delay <= 0.0:
				_draw_result()


func _draw_title() -> void:
	draw_texture_rect(textures["key-art"], Rect2(515, 0, 800, 720), false)
	_box(Rect2(58, 60, 590, 594), Color(0.035, 0.09, 0.14, 0.93), Color("45615c"))
	draw_line(Vector2(96, 112), Vector2(156, 112), GOLD, 2)
	_text("夜明けを待つ、小さな冒険", Vector2(174, 120), 20, GOLD)
	draw_texture_rect(textures.logo, Rect2(88, 148, 540, 162), false)
	_text("灯を絶やさず、夜を越えよう。", Vector2(96, 325), 27, CREAM)
	_text("移動するだけで、魔法は自動発動。", Vector2(96, 375), 21, MINT)
	_text("光を集め、力を選び、10分間を生き抜く。", Vector2(96, 409), 20, MUTED)
	_text("移動  WASD / 矢印 / 左スティック", Vector2(96, 550), 18, CREAM)
	_text("選択  Enter / パッド A / クリック", Vector2(96, 583), 18, CREAM)
	_text("休止 Esc / Start     全画面 F11     消音 M", Vector2(96, 625), 17, MUTED)
	_text("森の奥で、灯があなたを待っている。", Vector2(804, 669), 18, GOLD)


func _draw_hud() -> void:
	_box(Rect2(20, 16, 400, 94), Color(0.035, 0.09, 0.14, 0.96), Color("456b68"))
	_art("player", Vector2(59, 62), 68)
	_text("灯守", Vector2(104, 44), 19, GOLD)
	_text("体力  %d / %d" % [roundi(shown_hp), state.max_hp], Vector2(200, 44), 17, CREAM)
	_bar(Rect2(104, 61, 282, 13), shown_hp / state.max_hp, Color("eb9580"))
	_text("灯が消えるまで、歩き続けよう", Vector2(104, 96), 14, MUTED)
	_box(Rect2(518, 16, 244, 94), Color(0.035, 0.09, 0.14, 0.96), Color("847348"))
	_art("icon-clock", Vector2(553, 47), 32)
	_text("夜明けまで", Vector2(580, 44), 15, MUTED)
	_text(_clock(maxf(0.0, Rules.DURATION - state.elapsed)), Vector2(579, 88), 36, CREAM)
	_box(Rect2(848, 16, 412, 94), Color(0.035, 0.09, 0.14, 0.96), Color("456b68"))
	_art("icon-kills", Vector2(879, 46), 30)
	_text("撃破  %d" % roundi(shown_kills), Vector2(902, 51), 21, CREAM)
	_text("レベル %d" % state.level, Vector2(1115, 51), 21, GOLD)
	_bar(Rect2(878, 71, 350, 8), float(state.xp) / Rules.xp_needed(state.level), MINT)
	_text("経験値  %d / %d" % [state.xp, Rules.xp_needed(state.level)], Vector2(878, 101), 13, MUTED)
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
		var icon: String = (
			id
			if id in WEAPON_IDS
			else str(
				(
					{
						"health": "icon-health",
						"power": "icon-kills",
						"speed": "icon-speed",
						"tempo": "icon-clock",
						"reach": "magnet"
					}
					. get(id, "title-emblem")
				)
			)
		)
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
	var values: Array[String] = [
		_clock(state.elapsed * result_progress),
		str(roundi(state.kills * result_progress)),
		str(roundi(state.level * result_progress))
	]
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
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.06, 0.10, 0.82))


func _clock(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]
