extends Control
## 入力と描画だけを担当し、進行状態は RunState が所有する。

const Rules = preload("res://scripts/game_rules.gd")
const INK := Color("09051c")
const PANEL := Color("160829")
const CREAM := Color("f8f4ff")
const MINT := Color("2bf0de")
const GOLD := Color("ffb34d")
const MAGENTA := Color("ff2ecf")
const MUTED := Color("a8b9d4")
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
var tutorial_active: bool = false
var tutorial_seen: bool = false
var tutorial_step: int = 0
var tutorial_distance: float = 0.0
var tutorial_timer: float = 0.0
var upgrade_focus: int = 0


func _ready() -> void:
	state = get_node("/root/RunState")
	face = load("res://assets/fonts/RocknRollOne-Regular.ttf")
	theme = load("res://assets/theme/night.tres")
	for key: String in [
		"gem",
		"heal",
		"magnet",
		"title-emblem",
		"icon-health",
		"icon-clock",
		"icon-kills",
		"icon-speed",
		"icon-armor",
		"icon-pause",
		"icon-sound"
	]:
		textures[key] = load("res://assets/art/%s.svg" % key)
	for key: String in ["bolt", "orbit", "pulse", "title-art"]:
		textures[key] = load("res://assets/generated/%s.png" % key)
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
	var vhs := ColorRect.new()
	vhs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vhs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs.z_index = 2
	var vhs_material := ShaderMaterial.new()
	vhs_material.shader = load("res://shaders/vhs_overlay.gdshader")
	vhs.material = vhs_material
	add_child(vhs)
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
	var previous_position: Vector2 = state.player_pos
	if hit_stop > 0.0:
		hit_stop = maxf(0.0, hit_stop - delta)
	else:
		state.step(delta, Input.get_vector("move_left", "move_right", "move_up", "move_down"))
	_advance_tutorial(delta, state.player_pos.distance_to(previous_position))
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
		if tutorial_active and state.phase == "upgrade":
			_finish_tutorial()
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
	elif event.is_action_pressed("tutorial_skip") and tutorial_active:
		_finish_tutorial()
		_refresh_screen()
		get_viewport().set_input_as_handled()


func _advance_tutorial(delta: float, moved: float) -> void:
	if not tutorial_active or state.phase != "playing":
		return
	tutorial_timer += delta
	tutorial_distance += moved
	if tutorial_step == 0 and (tutorial_distance >= 42.0 or tutorial_timer >= 6.0):
		tutorial_step = 1
		tutorial_timer = 0.0
		audio.play_cue("ui")
	elif tutorial_step == 1 and (state.xp > 0 or tutorial_timer >= 6.0):
		tutorial_step = 2
		tutorial_timer = 0.0
		audio.play_cue("ui")
	elif tutorial_step == 2 and tutorial_timer >= 5.0:
		_finish_tutorial()
		_refresh_screen()


func _finish_tutorial() -> void:
	tutorial_active = false
	tutorial_seen = true


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
			_button("10:00 RUN を開始", Rect2(68, 486, 354, 64), _start, true)
		"playing":
			if tutorial_active:
				_button("SKIP", Rect2(1092, 132, 124, 42), _skip_tutorial)
		"upgrade":
			upgrade_focus = 0
			for i: int in range(state.choices.size()):
				var choice_button: Button = _button(
					"選択して再開",
					Rect2(92 + i * 394, 524, 312, 52),
					_choose_upgrade.bind(i),
					i == 0
				)
				choice_button.focus_entered.connect(_set_upgrade_focus.bind(i))
				choice_button.mouse_entered.connect(_focus_button.bind(choice_button))
		"paused":
			_button("信号を再開", Rect2(470, 360, 340, 58), state.toggle_pause, true)
			_button("タイトルへ", Rect2(470, 438, 340, 58), state.return_title)
		"result":
			_button("RETRY", Rect2(326, 514, 300, 60), _start, true)
			_button("TITLE", Rect2(650, 514, 300, 60), state.return_title)


func _button(caption: String, rect: Rect2, action: Callable, focused: bool = false) -> Button:
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
	return button


func _focus_button(button: Button) -> void:
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
	style.set_corner_radius_all(5)
	return style


func _choose_upgrade(index: int) -> void:
	state.choose_upgrade(index)
	_refresh_screen()


func _set_upgrade_focus(index: int) -> void:
	upgrade_focus = index
	queue_redraw()


func _skip_tutorial() -> void:
	_finish_tutorial()
	_refresh_screen()


func _start() -> void:
	if not tutorial_seen:
		tutorial_active = true
		tutorial_step = 0
		tutorial_distance = 0.0
		tutorial_timer = 0.0
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
			_box(Rect2(390, 190, 500, 354), Color(0.04, 0.01, 0.12, 0.96), MAGENTA)
			_center_text("PAUSED // SIGNAL HOLD", 270, 34, CREAM)
			_center_text("戦場の時間は停止中", 318, 19, MINT)
		"result":
			if result_delay <= 0.0:
				_draw_result()


func _draw_title() -> void:
	draw_texture_rect(textures["title-art"], Rect2(0, 0, 1280, 720), false)
	draw_rect(Rect2(0, 0, 555, 720), Color(0.015, 0.008, 0.06, 0.84))
	draw_colored_polygon(
		PackedVector2Array([Vector2(515, 0), Vector2(650, 0), Vector2(440, 720), Vector2(330, 720)]),
		Color(0.04, 0.01, 0.11, 0.48)
	)
	draw_line(Vector2(64, 72), Vector2(418, 72), MINT, 3.0)
	draw_line(Vector2(64, 79), Vector2(284, 79), MAGENTA, 2.0)
	_text("NEON", Vector2(64, 174), 78, CREAM)
	_text("DAWN", Vector2(64, 254), 78, MAGENTA)
	_text("夜明け前線", Vector2(70, 302), 25, MINT)
	_text("MOVE TO SURVIVE", Vector2(68, 370), 25, GOLD)
	_text("敵を避けろ。攻撃は自動。", Vector2(68, 410), 22, CREAM)
	_text("光片を拾い、強化を選んで10分を越える。", Vector2(68, 446), 17, MUTED)


func _draw_hud() -> void:
	_draw_edge_meter(float(state.xp) / Rules.xp_needed(state.level))
	_text("HP %d / %d" % [roundi(shown_hp), state.max_hp], Vector2(28, 36), 17, CREAM)
	_bar(Rect2(28, 49, 176, 7), shown_hp / state.max_hp, MAGENTA)
	_center_text(_clock(maxf(0.0, Rules.DURATION - state.elapsed)), 54, 34, CREAM)
	_text("KO %d" % roundi(shown_kills), Vector2(1092, 34), 17, CREAM)
	_text("LV %d" % state.level, Vector2(1192, 34), 17, GOLD)
	_text("XP %d / %d" % [state.xp, Rules.xp_needed(state.level)], Vector2(1130, 56), 13, MINT)
	for i: int in range(3):
		var id: String = WEAPON_IDS[i]
		var center := Vector2(48 + i * 112, 658)
		var active: bool = state.weapons[id] > 0
		draw_circle(center, 34, Color(0.03, 0.01, 0.10, 0.88))
		var arc_color: Color = MINT if active else Color(MUTED, 0.35)
		var icon_color: Color = Color.WHITE if active else Color(0.35, 0.36, 0.46, 0.62)
		draw_arc(center, 34, 0, TAU, 36, arc_color, 2)
		_art(id, center, 48, icon_color)
		var level_label: String = "%d" % state.weapons[id] if active else "LOCK"
		_text(level_label, center + Vector2(32, 30), 12, GOLD if active else MUTED)
		if not active:
			_text("強化で解放", center + Vector2(-25, 53), 11, MUTED)
	if state.elapsed >= 570:
		_center_text("WARNING // ECLIPSE SIGNAL", 112, 21, GOLD)
	if tutorial_active:
		_draw_tutorial()
	if muted:
		_text("MUTED // M", Vector2(1125, 686), 14, GOLD)


func _draw_upgrade() -> void:
	_shade()
	_center_text("SELECT // NEON UPGRADE", 120, 36, CREAM)
	_center_text("LV %d    選択中は戦場時間が停止" % state.level, 156, 17, MINT)
	for i: int in range(state.choices.size()):
		var id: String = state.choices[i]
		var origin := Vector2(70 + i * 394, 190)
		var selected: bool = i == upgrade_focus
		if selected:
			_box(
				Rect2(origin - Vector2(7, 7), Vector2(374, 424)),
				Color(0.08, 0.0, 0.18, 0.74),
				Color(MAGENTA, 0.34)
			)
		var outline: Color = MAGENTA if selected else Color(MINT, 0.58)
		_box(Rect2(origin, Vector2(360, 410)), Color(0.035, 0.008, 0.09, 0.96), outline)
		_text("0%d // AVAILABLE" % (i + 1), origin + Vector2(22, 34), 14, MINT if selected else MUTED)
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
		_art(icon, origin + Vector2(180, 100), 84)
		_text(state.upgrade_name(id), origin + Vector2(24, 171), 25, CREAM)
		var description: String = state.upgrade_description(id)
		_wrapped_text(description, origin + Vector2(24, 211), 312, 17, MUTED)
		_text("PREVIEW", origin + Vector2(24, 286), 13, MAGENTA if selected else MINT)
		_wrapped_text(_upgrade_preview(id), origin + Vector2(24, 318), 312, 16, CREAM)
	_center_text("左右で看板を選ぶ  //  ENTER・A・クリックで即時反映", 650, 16, MUTED)


func _draw_result() -> void:
	_shade()
	_box(Rect2(230, 102, 820, 510), Color(0.035, 0.008, 0.10, 0.96), MINT if state.won else MAGENTA)
	_center_text("DAWN REACHED" if state.won else "SIGNAL LOST", 205, 46, CREAM)
	_center_text("地平線に朝が到達した" if state.won else "記録を保持。再起動できる", 250, 19, MINT)
	var labels: Array[String] = ["生存時間", "撃破数", "到達レベル"]
	var values: Array[String] = [
		_clock(state.elapsed * result_progress),
		str(roundi(state.kills * result_progress)),
		str(roundi(state.level * result_progress))
	]
	for i: int in range(3):
		var x: float = 365 + i * 235
		draw_line(Vector2(x - 28, 344), Vector2(x + 150, 344), Color(MAGENTA, 0.5), 2)
		_text(labels[i], Vector2(x, 385), 17, MUTED)
		_text(values[i], Vector2(x, 440), 38, GOLD)


func _draw_edge_meter(fraction: float) -> void:
	var corners: Array[Vector2] = [
		Vector2(5, 5), Vector2(1275, 5), Vector2(1275, 715), Vector2(5, 715), Vector2(5, 5)
	]
	for index: int in range(corners.size() - 1):
		draw_line(corners[index], corners[index + 1], Color(0.18, 0.08, 0.30, 0.72), 2.0)
	var remaining: float = clampf(fraction, 0.0, 1.0) * 3960.0
	for index: int in range(corners.size() - 1):
		if remaining <= 0.0:
			break
		var start: Vector2 = corners[index]
		var finish: Vector2 = corners[index + 1]
		var length: float = start.distance_to(finish)
		var amount: float = minf(remaining, length)
		var endpoint: Vector2 = start + start.direction_to(finish) * amount
		draw_line(start, endpoint, Color(MAGENTA, 0.16), 12.0, true)
		draw_line(start, endpoint, Color(MINT, 0.36), 6.0, true)
		draw_line(start, endpoint, CREAM, 2.0, true)
		remaining -= amount


func _draw_tutorial() -> void:
	var pulse: float = 0.65 + sin(decoration_time * 4.0) * 0.25
	var callout := Rect2(744, 112, 330, 112)
	if tutorial_step == 0:
		draw_arc(CENTER, 66.0 + pulse * 8.0, 0, TAU, 48, Color(MINT, pulse), 3.0)
		for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var inner: Vector2 = CENTER + direction * 78.0
			draw_line(inner, inner + direction * 24.0, Color(MAGENTA, pulse), 5.0, true)
		_box(callout, Color(0.025, 0.005, 0.08, 0.94), MINT)
		_text("STEP 01 // MOVE", callout.position + Vector2(20, 31), 15, MINT)
		_text("敵との距離を作れ", callout.position + Vector2(20, 65), 22, CREAM)
		_text("WASD・矢印・左スティック", callout.position + Vector2(20, 94), 14, MUTED)
	elif tutorial_step == 1:
		var target := CENTER + Vector2(190, 120)
		if not state.gems.is_empty():
			target = arena.screen(Vector2(state.gems[0].pos))
		target = target.clamp(Vector2(70, 90), Vector2(1210, 650))
		draw_line(CENTER, target, Color(MINT, 0.22), 2.0, true)
		draw_arc(target, 30.0 + pulse * 7.0, 0, TAU, 32, Color(MAGENTA, pulse), 3.0)
		_box(callout, Color(0.025, 0.005, 0.08, 0.94), MAGENTA)
		_text("STEP 02 // COLLECT", callout.position + Vector2(20, 31), 15, MAGENTA)
		_text("攻撃は自動。光片へ移動", callout.position + Vector2(20, 65), 20, CREAM)
		_text("赤は回復、磁石は一括回収", callout.position + Vector2(20, 94), 14, MUTED)
	else:
		_box(callout, Color(0.025, 0.005, 0.08, 0.94), GOLD)
		_text("STEP 03 // LEVEL UP", callout.position + Vector2(20, 31), 15, GOLD)
		_text("画面の縁を光で満たせ", callout.position + Vector2(20, 65), 21, CREAM)
		_text("満タンでネオン看板から1つ選択", callout.position + Vector2(20, 94), 14, MUTED)
	_text("T / Y / SKIPボタンでスキップ", Vector2(1018, 198), 12, MUTED)


func _upgrade_preview(id: String) -> String:
	var preview: String = "選択後に即時反映"
	if state.weapons.has(id):
		var current: int = int(state.weapons[id])
		preview = "未解放  →  LV 1" if current == 0 else "LV %d  →  LV %d" % [current, current + 1]
		return preview
	match id:
		"power":
			preview = "武器威力 %d%%  →  %d%%" % [
				roundi(state.damage_bonus * 100), roundi((state.damage_bonus + 0.15) * 100)
			]
		"tempo":
			preview = "攻撃速度 %d%%  →  %d%%" % [
				roundi(state.attack_speed * 100), roundi((state.attack_speed + 0.08) * 100)
			]
		"speed":
			preview = "移動速度 %d  →  %d" % [
				roundi(state.move_speed), roundi(minf(350, state.move_speed + 12))
			]
		"health":
			preview = "最大HP %d  →  %d / HP +35" % [
				roundi(state.max_hp), roundi(state.max_hp + 20)
			]
		"reach":
			preview = "回収範囲 %d  →  %d" % [
				roundi(state.pickup_radius), roundi(minf(220, state.pickup_radius + 18))
			]
	return preview


func _screen(point: Vector2) -> Vector2:
	return point - state.player_pos + CENTER


func _art(key: String, center: Vector2, extent: float, tint: Color = Color.WHITE) -> void:
	draw_texture_rect(
		textures[key], Rect2(center - Vector2.ONE * extent / 2, Vector2.ONE * extent), false, tint
	)


func _text(value: String, point: Vector2, font_size: int, color: Color) -> void:
	draw_string(face, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _center_text(value: String, baseline: float, font_size: int, color: Color) -> void:
	draw_string(
		face,
		Vector2(0, baseline),
		value,
		HORIZONTAL_ALIGNMENT_CENTER,
		1280,
		font_size,
		color
	)


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
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.002, 0.04, 0.84))


func _clock(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]
