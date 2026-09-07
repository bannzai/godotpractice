extends Node2D
## 進行状態をベクタースキャンとして描く。表示値の補間だけは非冪等。

const INK: Color = Color("d9fff8")
const MUTED: Color = Color("559b9b")
const CYAN: Color = Color("49ffe6")
const BLUE: Color = Color("3887ff")
const MAGENTA: Color = Color("ff3f88")
const AMBER: Color = Color("ffd166")
const BLACK: Color = Color("01070b")
const FIELD: Rect2 = Rect2(320, 0, 640, 720)
const Stage = preload("res://scripts/stage_data.gd")
const Ship = preload("res://scripts/ship_sprite.gd")
const TRACE_SHADER: String = """shader_type canvas_item;
render_mode unshaded;
uniform float gain = 1.0;
void fragment() {
    float pulse = 0.82 + 0.18 * sin(TIME * 11.0 + UV.y * 19.0);
    COLOR = vec4(COLOR.rgb * gain * pulse, COLOR.a);
}"""

var game: Control
var font: Font
var background: Node2D
var actors: Node2D
var traces: Node2D
var ships: Dictionary = {}
var bullet_lines: Array[Line2D] = []
var bullet_glows: Array[Line2D] = []
var display_score: float = 0.0
var display_hp: float = 0.0
var display_lives: float = 3.0
var last_mode: int = -1
var _trace_shader: Shader


func _ready() -> void:
	font = load("res://assets/ui/flight_theme.tres").default_font
	_trace_shader = Shader.new()
	_trace_shader.code = TRACE_SHADER
	background = Node2D.new()
	background.z_index = -3
	add_child(background)
	background.draw.connect(_draw_background)
	actors = Node2D.new()
	actors.z_index = -2
	add_child(actors)
	traces = Node2D.new()
	traces.z_index = -1
	add_child(traces)


func _process(delta: float) -> void:
	if last_mode != GameState.mode:
		last_mode = GameState.mode
		if GameState.mode == GameState.Mode.PLAYING:
			display_score = 0.0
			display_lives = GameState.lives
	var weight: float = 1.0 - exp(-delta * 8.0)
	display_score = lerpf(display_score, GameState.score, weight)
	display_hp = lerpf(display_hp, game.boss_hp, weight)
	display_lives = move_toward(display_lives, GameState.lives, delta * 4.0)
	_sync_actors()
	_sync_bullets()
	background.queue_redraw()
	queue_redraw()


func _sync_actors() -> void:
	var visible_ids: Array[String] = []
	actors.position = game.shake_offset
	if GameState.mode in [GameState.Mode.PLAYING, GameState.Mode.RESULT]:
		if GameState.lives > 0 and GameState.mode == GameState.Mode.PLAYING:
			var player_ship: Node2D = _actor(
				"player", "player", game.player_pose, game.player, 0.72, visible_ids
			)
			player_ship.modulate.a = (
				0.45 if game.invulnerable > 0.0 and fmod(game.animation_time, 0.16) < 0.08 else 1.0
			)
		for enemy: Dictionary in game.enemies:
			_actor(
				"enemy-%s" % enemy.get("visual_id", 0),
				enemy.kind,
				enemy.get("pose", "move"),
				enemy.position,
				0.72,
				visible_ids
			)
		if game.boss_active and game.boss_hp > 0:
			_actor("boss", "boss", game.boss_pose, game.boss_position, 1.0, visible_ids)
		for effect: Dictionary in game.effects:
			if effect.get("kind", "") != "death":
				continue
			var id: String = "death-%s-%s" % [effect.actor, effect.visual_id]
			var size: float = 1.0 if effect.actor == "boss" else 0.72
			var death_ship: Node2D = _actor(
				id, effect.actor, "death", effect.position, size, visible_ids
			)
			death_ship.set_frame_and_progress(mini(3, int(effect.age / 0.18)), 0.0)
	for id: String in ships.keys():
		if visible_ids.has(id):
			continue
		ships[id].queue_free()
		ships.erase(id)


func _actor(
	id: String, kind: String, pose: String, at: Vector2, size: float, visible_ids: Array[String]
) -> Node2D:
	if not ships.has(id):
		var ship: Node2D = Ship.new()
		actors.add_child(ship)
		ship.setup(kind)
		ships[id] = ship
	var sprite: Node2D = ships[id]
	sprite.position = at
	sprite.scale = Vector2.ONE * size
	sprite.set_pose(pose)
	sprite.speed_scale = 0.0 if game.paused else 1.0
	visible_ids.append(id)
	return sprite


func _sync_bullets() -> void:
	var visible_count: int = game.bullets.size() if GameState.mode == GameState.Mode.PLAYING else 0
	while bullet_lines.size() < visible_count:
		var glow: Line2D = _new_trace(8.0, 1.7)
		var line: Line2D = _new_trace(2.2, 1.15)
		traces.add_child(glow)
		traces.add_child(line)
		bullet_glows.append(glow)
		bullet_lines.append(line)
	for index: int in range(bullet_lines.size()):
		var visible: bool = index < visible_count
		bullet_lines[index].visible = visible
		bullet_glows[index].visible = visible
		if not visible:
			continue
		var bullet: Dictionary = game.bullets[index]
		var direction: Vector2 = bullet.velocity.normalized()
		var length: float = 26.0 if bullet.friendly else 13.0
		var points: PackedVector2Array = PackedVector2Array(
			[bullet.position - direction * length, bullet.position + direction * length * 0.25]
		)
		var color: Color = CYAN if bullet.friendly else MAGENTA
		bullet_lines[index].points = points
		bullet_lines[index].default_color = color
		bullet_glows[index].points = points
		bullet_glows[index].default_color = Color(color.r, color.g, color.b, 0.16)
	traces.position = game.shake_offset


func _new_trace(width: float, gain: float) -> Line2D:
	var line: Line2D = Line2D.new()
	line.width = width
	line.antialiased = true
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _trace_shader
	material.set_shader_parameter("gain", gain)
	line.material = material
	return line


func _draw_background() -> void:
	background.draw_rect(Rect2(0, 0, 1280, 720), BLACK)
	for y: int in range(0, 720, 8):
		background.draw_line(Vector2(0, y), Vector2(1280, y), Color(0.05, 0.4, 0.39, 0.055), 1.0)
	if GameState.mode == GameState.Mode.TITLE:
		_draw_star_noise(Rect2(0, 0, 1280, 720), 42)
		return
	if GameState.mode == GameState.Mode.NAVIGATION:
		_draw_star_noise(Rect2(0, 0, 1280, 720), 32)
		return
	_draw_star_noise(FIELD, 30)
	var vanish: Vector2 = Vector2(640, 205)
	for x: int in range(340, 961, 62):
		background.draw_line(vanish, Vector2(x, 720), Color(0.1, 0.8, 0.75, 0.13), 1.0)
	var scroll: float = fmod(game.animation_time * 95.0, 72.0)
	for row: int in range(9):
		var ratio: float = float(row) / 8.0
		var y: float = 235.0 + pow(ratio, 1.8) * 520.0 + scroll * ratio
		background.draw_line(Vector2(320, y), Vector2(960, y), Color(0.1, 0.9, 0.78, 0.16), 1.0)


func _draw_star_noise(area: Rect2, count: int) -> void:
	for index: int in range(count):
		var x: float = area.position.x + fmod(float(index * 97 + 31), area.size.x)
		var y: float = area.position.y + fmod(float(index * 53 + 17), area.size.y)
		var flicker: float = 0.18 + 0.16 * sin(game.animation_time * 2.0 + float(index))
		background.draw_line(Vector2(x - 2, y), Vector2(x + 2, y), Color(0.4, 1, 0.95, flicker))


func _draw() -> void:
	match GameState.mode:
		GameState.Mode.TITLE:
			_draw_title()
		GameState.Mode.NAVIGATION:
			_draw_navigation()
		GameState.Mode.TUTORIAL:
			_draw_tutorial()
		_:
			_draw_field()
			if game.boss_chart_active:
				_draw_boss_chart()
			else:
				_draw_cockpit()
				if GameState.mode == GameState.Mode.RESULT and game.result_time >= 0.65:
					_draw_result()
				elif game.paused:
					_draw_pause()


func _draw_title() -> void:
	_wire_globe(Vector2(974, 344), 282.0, game.animation_time * 0.08, CYAN)
	_neon_line(
		PackedVector2Array(
			[Vector2(706, 548), Vector2(842, 434), Vector2(982, 372), Vector2(1124, 236)]
		),
		MAGENTA,
		2.0
	)
	for point: Vector2 in [
		Vector2(706, 548), Vector2(842, 434), Vector2(982, 372), Vector2(1124, 236)
	]:
		draw_arc(point, 9.0, 0.0, TAU, 24, CYAN, 2.0, true)
	_label("VECTOR SCAN / ROUTE 07", Vector2(76, 88), 19, CYAN)
	_label("星環防衛線", Vector2(72, 208), 66, INK)
	_label("SIGNAL // LAST ORBIT", Vector2(78, 252), 22, MAGENTA)
	_neon_line(PackedVector2Array([Vector2(78, 292), Vector2(478, 292)]), CYAN, 1.0)
	_label("最後の航路に、未確認の巨大信号。", Vector2(78, 347), 22, INK)
	_label("航路図を開き、単機迎撃の結果を確認する。", Vector2(78, 388), 17, MUTED)
	_label("最高記録  %07d" % GameState.high_score, Vector2(78, 454), 20, AMBER)
	draw_arc(Vector2(226, 562), 176.0, PI, TAU, 48, Color(CYAN, 0.2), 1.0, true)
	_label("航路受信待機", Vector2(80, 624), 15, MUTED)
	_label("TRAIN ONE / COCKPIT TERMINAL", Vector2(832, 684), 14, MUTED)


func _draw_navigation() -> void:
	_label("航路図  /  ORBITAL NAVIGATION", Vector2(48, 62), 27, INK)
	_label("選択中の航路は明滅します。未解析領域は出撃できません。", Vector2(49, 96), 16, MUTED)
	_wire_globe(Vector2(416, 376), 266.0, game.animation_time * 0.13, CYAN)
	var route: PackedVector2Array = PackedVector2Array(
		[
			Vector2(212, 500),
			Vector2(314, 423),
			Vector2(421, 366),
			Vector2(531, 283),
			Vector2(605, 176)
		]
	)
	_neon_line(route, CYAN, 2.5)
	for index: int in range(route.size()):
		var radius: float = (
			11.0 + (sin(game.tutorial_pulse * 4.0) + 1.0) * 3.0 if index == 2 else 7.0
		)
		draw_arc(route[index], radius, 0.0, TAU, 28, CYAN, 2.0, true)
	_label("第 07 航路", Vector2(461, 352), 21, INK)
	_label("選択中", Vector2(461, 378), 14, CYAN)
	draw_arc(Vector2(255, 227), 18.0, 0.0, TAU, 24, Color(MAGENTA, 0.42), 2.0, true)
	draw_line(Vector2(242, 214), Vector2(268, 240), Color(MAGENTA, 0.72), 2.0)
	draw_line(Vector2(268, 214), Vector2(242, 240), Color(MAGENTA, 0.72), 2.0)
	_label("深宙域", Vector2(280, 222), 17, Color(MAGENTA, 0.7))
	_label("選択不可: 旗艦信号を未解析", Vector2(280, 248), 14, MUTED)
	_draw_dial(Vector2(1000, 235), 108.0, 0.72, "推定交戦", "03:00", CYAN)
	_draw_dial(Vector2(1000, 470), 108.0, 1.0, "編隊 / 旗艦", "120 / 1", MAGENTA)
	_label("進行プレビュー", Vector2(811, 78), 18, AMBER)
	_label("編隊を突破 → 航路再計算 → 巨大信号を迎撃", Vector2(754, 113), 16, INK)
	_label("選択を確定すると離陸前の計器チェックへ進みます。", Vector2(766, 575), 15, MUTED)


func _draw_tutorial() -> void:
	_label("離陸前計器チェック", Vector2(43, 63), 29, INK)
	_label("場面内の計器を順に作動させてください。", Vector2(44, 98), 17, MUTED)
	var titles: Array[String] = ["操縦桿", "射撃管制", "全域放電"]
	var actions: Array[String] = [
		"WASD / 矢印 / 左スティックを倒す",
		"Z / Space / A を押す",
		"X / B を押す",
	]
	var colors: Array[Color] = [CYAN, AMBER, MAGENTA]
	for index: int in range(3):
		var center: Vector2 = Vector2(248 + index * 390, 344)
		var complete: bool = index < game.tutorial_step
		var active: bool = index == game.tutorial_step
		var value: float = (
			1.0 if complete else (0.62 + sin(game.tutorial_pulse * 5.0) * 0.18 if active else 0.08)
		)
		_draw_dial(
			center,
			132.0,
			value,
			titles[index],
			"OK" if complete else "%d" % (index + 1),
			colors[index]
		)
		_label_centered(actions[index], Vector2(center.x, 522), 16, INK if active else MUTED)
		_label_centered(
			"完了" if complete else ("入力待機" if active else "ロック中"),
			Vector2(center.x, 558),
			15,
			colors[index] if active or complete else MUTED
		)
		if index < 2:
			_neon_line(
				PackedVector2Array([Vector2(center.x + 143, 344), Vector2(center.x + 247, 344)]),
				colors[index],
				1.5
			)
	_label("CHECK %d / 3" % game.tutorial_step, Vector2(45, 667), 15, CYAN)
	_label("3つ完了すると自動離陸", Vector2(457, 657), 19, AMBER)


func _draw_field() -> void:
	draw_set_transform(game.shake_offset)
	for item: Dictionary in game.items:
		var location: Vector2 = item.position + Vector2(0, sin(item.age * 5.0) * 4.0)
		var color: Color = AMBER if item.kind == "score" else CYAN
		var radius: float = 16.0
		draw_arc(location, radius, 0.0, TAU, 20, Color(color, 0.28), 7.0, true)
		draw_arc(location, radius, 0.0, TAU, 20, color, 1.8, true)
		draw_line(location + Vector2(-7, 0), location + Vector2(7, 0), color, 1.8)
		draw_line(location + Vector2(0, -7), location + Vector2(0, 7), color, 1.8)
	if GameState.lives > 0 and GameState.mode == GameState.Mode.PLAYING:
		if game.invulnerable > 0.0:
			draw_arc(game.player, 34.0, 0.0, TAU, 40, Color(CYAN, 0.55), 1.5, true)
		draw_arc(game.player, 4.0, 0.0, TAU, 16, INK, 1.5, true)
	draw_set_transform(Vector2.ZERO)
	if game.flash > 0.0:
		for offset: float in [0.0, 12.0, 24.0]:
			draw_rect(Rect2(320, offset, 640, 2), Color(CYAN, game.flash * (0.32 - offset * 0.006)))
	if game.boss_active and game.boss_hp > 0:
		_label_centered(
			"FLAGSHIP / PHASE %d" % Stage.boss_phase(game.boss_hp), Vector2(640, 30), 15, MAGENTA
		)
		draw_arc(Vector2(640, 38), 188.0, PI * 1.08, PI * 1.92, 60, Color(MAGENTA, 0.2), 8.0, true)
		draw_arc(
			Vector2(640, 38),
			188.0,
			PI * 1.08,
			lerpf(PI * 1.08, PI * 1.92, display_hp / Stage.BOSS_HP),
			60,
			MAGENTA,
			3.0,
			true
		)


func _draw_cockpit() -> void:
	_draw_dial(
		Vector2(145, 153),
		102.0,
		fmod(display_score / 100000.0, 1.0),
		"SCORE",
		"%07d" % int(round(display_score)),
		CYAN
	)
	_draw_dial(
		Vector2(145, 375),
		84.0,
		float(GameState.power) / 3.0,
		"SHOT",
		"LEVEL %d" % GameState.power,
		AMBER
	)
	_draw_dial(
		Vector2(145, 580),
		76.0,
		float(GameState.bombs) / 5.0,
		"BOMB",
		"%d / 5" % GameState.bombs,
		MAGENTA
	)
	_draw_radar(Vector2(1135, 174), 112.0)
	var progress: float = minf(1.0, GameState.elapsed / Stage.BOSS_TIME)
	_draw_dial(
		Vector2(1135, 424),
		91.0,
		progress,
		"ROUTE",
		"%02d:%02d" % [int(GameState.elapsed) / 60, int(GameState.elapsed) % 60],
		CYAN
	)
	_label_centered("次の指示", Vector2(1135, 557), 15, MUTED)
	_label_centered("旗艦を撃破" if game.boss_active else "航路を確保", Vector2(1135, 591), 20, INK)
	_label_centered("残機 %d" % int(ceil(display_lives)), Vector2(1135, 632), 17, AMBER)
	for index: int in range(3):
		var x: float = 1098.0 + index * 37.0
		draw_arc(
			Vector2(x, 666),
			9.0,
			0.0,
			TAU,
			20,
			CYAN if index < GameState.lives else Color(CYAN, 0.16),
			2.0,
			true
		)
	draw_line(Vector2(309, 0), Vector2(309, 720), Color(CYAN, 0.34), 2.0)
	draw_line(Vector2(971, 0), Vector2(971, 720), Color(CYAN, 0.34), 2.0)


func _draw_radar(center: Vector2, radius: float) -> void:
	draw_arc(center, radius, 0.0, TAU, 64, Color(CYAN, 0.7), 2.0, true)
	draw_arc(center, radius * 0.66, 0.0, TAU, 48, Color(CYAN, 0.22), 1.0, true)
	draw_arc(center, radius * 0.33, 0.0, TAU, 32, Color(CYAN, 0.22), 1.0, true)
	var angle: float = fmod(game.animation_time * 1.4, TAU)
	draw_line(center, center + Vector2.from_angle(angle) * radius, Color(CYAN, 0.7), 1.5)
	for enemy: Dictionary in game.enemies:
		var normalized: Vector2 = Vector2(
			(enemy.position.x - FIELD.position.x) / FIELD.size.x * 2.0 - 1.0,
			(enemy.position.y / FIELD.size.y) * 2.0 - 1.0
		)
		var blip: Vector2 = center + normalized * radius * 0.82
		draw_arc(blip, 3.5, 0.0, TAU, 12, MAGENTA, 2.0, true)
	_label_centered("RADAR", Vector2(center.x, center.y + radius + 28.0), 14, MUTED)


func _draw_boss_chart() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.0, 0.01, 0.02, 0.93))
	_wire_globe(Vector2(640, 355), 250.0, game.animation_time * 0.22, MAGENTA)
	var route: PackedVector2Array = PackedVector2Array(
		[
			Vector2(402, 470),
			Vector2(502, 411),
			Vector2(622, 354),
			Vector2(747, 279),
			Vector2(859, 205)
		]
	)
	_neon_line(route, CYAN, 3.0)
	for point: Vector2 in route:
		draw_arc(point, 7.0, 0.0, TAU, 20, CYAN, 2.0, true)
	draw_arc(
		route[-1], 26.0 + sin(game.tutorial_pulse * 8.0) * 5.0, 0.0, TAU, 32, MAGENTA, 3.0, true
	)
	_label_centered("航路再計算", Vector2(640, 65), 28, INK)
	_label_centered("巨大信号を捕捉 / 旗艦戦へ移行", Vector2(640, 105), 18, MAGENTA)
	_label_centered("AUTO INTERCEPT  %.1f" % game.boss_chart_time, Vector2(640, 664), 18, CYAN)


func _draw_result() -> void:
	draw_rect(Rect2(318, 0, 644, 720), Color(0.0, 0.02, 0.025, 0.86))
	draw_arc(Vector2(640, 338), 236.0, 0.0, TAU, 72, Color(CYAN, 0.28), 2.0, true)
	draw_arc(
		Vector2(640, 338),
		208.0,
		-PI * 0.2,
		PI * 1.2,
		72,
		CYAN if GameState.cleared else MAGENTA,
		4.0,
		true
	)
	_label_centered(
		"MISSION COMPLETE" if GameState.cleared else "SIGNAL LOST",
		Vector2(640, 218),
		18,
		CYAN if GameState.cleared else MAGENTA
	)
	_label_centered("航路確保" if GameState.cleared else "機体ロスト", Vector2(640, 285), 43, INK)
	_label_centered("SCORE  %07d" % int(round(display_score)), Vector2(640, 350), 23, AMBER)
	_label_centered("HIGH   %07d" % GameState.high_score, Vector2(640, 390), 19, CYAN)
	_label_centered("航路を再設定すると、装備を初期化して再出撃します。", Vector2(640, 437), 15, MUTED)


func _draw_pause() -> void:
	draw_rect(Rect2(318, 0, 644, 720), Color(0.0, 0.01, 0.015, 0.86))
	draw_arc(Vector2(640, 340), 220.0, 0.0, TAU, 64, Color(CYAN, 0.25), 2.0, true)
	_label_centered("FLIGHT HOLD", Vector2(640, 286), 19, CYAN)
	_label_centered("飛行を一時停止", Vector2(640, 334), 34, INK)
	_label_centered("計器は保持されています。", Vector2(640, 369), 16, MUTED)


func _draw_dial(
	center: Vector2, radius: float, value: float, title: String, readout: String, color: Color
) -> void:
	value = clampf(value, 0.0, 1.0)
	draw_arc(center, radius + 7.0, 0.0, TAU, 64, Color(color, 0.1), 8.0, true)
	draw_arc(center, radius, PI * 0.72, PI * 2.28, 52, Color(color, 0.28), 2.0, true)
	draw_arc(center, radius, PI * 0.72, lerpf(PI * 0.72, PI * 2.28, value), 52, color, 4.0, true)
	for index: int in range(11):
		var angle: float = lerpf(PI * 0.72, PI * 2.28, float(index) / 10.0)
		var outside: Vector2 = center + Vector2.from_angle(angle) * (radius - 6.0)
		var inside: Vector2 = center + Vector2.from_angle(angle) * (radius - 15.0)
		draw_line(inside, outside, Color(color, 0.62), 1.2)
	_label_centered(title, Vector2(center.x, center.y - 10.0), 14, MUTED)
	_label_centered(readout, Vector2(center.x, center.y + 25.0), 18, INK)


func _wire_globe(center: Vector2, radius: float, rotation: float, color: Color) -> void:
	draw_arc(center, radius + 9.0, 0.0, TAU, 96, Color(color, 0.1), 10.0, true)
	draw_arc(center, radius, 0.0, TAU, 96, Color(color, 0.75), 2.0, true)
	for latitude: float in [-0.66, -0.33, 0.0, 0.33, 0.66]:
		var y: float = center.y + latitude * radius
		var width: float = sqrt(1.0 - latitude * latitude) * radius
		draw_polyline(
			_ellipse_points(Vector2(center.x, y), width, radius * 0.16, 0.0),
			Color(color, 0.36),
			1.0,
			true
		)
	for longitude: float in [-0.72, -0.36, 0.0, 0.36, 0.72]:
		draw_polyline(
			_ellipse_points(center, radius * (0.18 + absf(longitude) * 0.5), radius, rotation),
			Color(color, 0.31),
			1.0,
			true
		)


func _ellipse_points(
	center: Vector2, radius_x: float, radius_y: float, rotation: float
) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(65):
		var angle: float = float(index) * TAU / 64.0
		var point: Vector2 = Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
		points.append(center + point.rotated(rotation))
	return points


func _neon_line(points: PackedVector2Array, color: Color, width: float) -> void:
	draw_polyline(points, Color(color, 0.12), width * 7.0, true)
	draw_polyline(_offset_points(points, Vector2(-1.4, 0.0)), Color(MAGENTA, 0.48), width, true)
	draw_polyline(_offset_points(points, Vector2(1.4, 0.0)), Color(BLUE, 0.48), width, true)
	draw_polyline(points, color, width, true)


func _offset_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var shifted: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		shifted.append(point + offset)
	return shifted


func _label(text: String, at: Vector2, size: int, color: Color) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _label_centered(text: String, at: Vector2, size: int, color: Color) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_label(text, Vector2(at.x - width * 0.5, at.y), size, color)
