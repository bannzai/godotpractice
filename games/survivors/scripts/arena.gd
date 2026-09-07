extends Node2D
## 状態の座標を描画へ写す。戦闘判定は RunState に残す。

const Actor = preload("res://scripts/actor_visual.gd")
const Effects = preload("res://scripts/effects_layer.gd")
const Rules = preload("res://scripts/game_rules.gd")
const CENTER := Vector2(640, 392)
var state: Node
var textures: Dictionary
var actors: Dictionary = {}
var player: Node2D
var remains: Node2D
var effects_layer: Node2D
var time: float = 0.0
var previous_player: Vector2
var facing: float = 1.0
var shake: float = 0.0


func setup(run: Node, art: Dictionary, face: Font) -> void:
	state = run
	textures = art
	player = Actor.new()
	player.setup(-1)
	player.scale = Vector2.ONE * 0.48
	add_child(player)
	remains = Node2D.new()
	add_child(remains)
	effects_layer = Effects.new()
	effects_layer.face = face
	add_child(effects_layer)
	state.effect_requested.connect(_effect)
	state.sound_requested.connect(_sound)


# 時間積分とモデルの追従なので非冪等。
func _process(delta: float) -> void:
	if state == null:
		return
	time += delta
	shake = move_toward(shake, 0.0, delta * 26.0)
	position = Vector2(sin(time * 83), cos(time * 67)) * shake
	player.visible = state.phase != "title"
	player.position = CENTER
	var movement: Vector2 = state.player_pos - previous_player
	if absf(movement.x) > 0.01:
		facing = signf(movement.x)
	if state.phase == "result" and not state.won:
		player.set_motion("death", facing)
	else:
		player.set_motion("move" if movement.length_squared() > 0.01 else "idle", facing)
	player.sprite.speed_scale = 0.0 if state.phase == "paused" else 1.0
	previous_player = state.player_pos
	remains.position = CENTER - state.player_pos
	_sync_enemies()
	queue_redraw()


func reset() -> void:
	for actor: Node in actors.values():
		actor.queue_free()
	actors.clear()
	for corpse: Node in remains.get_children():
		remains.remove_child(corpse)
		corpse.queue_free()
	player.reset_motion()
	effects_layer.clear_effects()
	shake = 0.0


func _sync_enemies() -> void:
	if state.phase == "title":
		return
	var alive: Dictionary = {}
	for enemy: Dictionary in state.enemies:
		var id: int = enemy.id
		alive[id] = true
		var point: Vector2 = screen(enemy.pos)
		if not actors.has(id):
			if not Rect2(-120, -120, 1520, 960).has_point(point):
				continue
			var actor: Node2D = Actor.new()
			actor.setup(enemy.kind)
			actor.scale = Vector2.ONE * enemy.radius * 3.25 / 160.0
			add_child(actor)
			move_child(actor, 0)
			actors[id] = actor
		var visual: Node2D = actors[id]
		visual.visible = state.phase != "title"
		visual.position = point
		visual.set_meta("world_position", enemy.pos)
		visual.sprite.speed_scale = 0.0 if state.phase in ["paused", "upgrade", "result"] else 1.0
		var motion: String = "move"
		if enemy.flash > 0.0:
			motion = "hurt"
		elif Vector2(enemy.pos).distance_to(state.player_pos) < enemy.radius + 28:
			motion = "attack"
		visual.set_motion(motion, -1.0 if point.x > CENTER.x else 1.0)
	for id: int in actors.keys():
		if alive.has(id):
			continue
		var visual: Node2D = actors[id]
		actors.erase(id)
		visual.reparent(remains)
		visual.position = visual.get_meta("world_position")
		visual.sprite.speed_scale = 1.0
		visual.set_motion("death")
		visual.motion_finished.connect(func(_motion: String) -> void: visual.queue_free())


func screen(point: Vector2) -> Vector2:
	return point - state.player_pos + CENTER


func _effect(at: Vector2, kind: String, caption: String) -> void:
	effects_layer.emit_effect(
		screen(at), kind, caption, state.pulse_radius() if kind == "pulse" else 0
	)
	if kind == "hit" and caption.begins_with("-"):
		shake = 6.0
		player.set_motion("hurt", facing)
	elif kind == "boss":
		shake = 9.0
	elif kind == "pulse":
		shake = maxf(shake, 2.0)


func _sound(cue: String) -> void:
	if cue == "attack":
		player.set_motion("attack", facing)


func _draw() -> void:
	if state == null:
		return
	var offset: Vector2 = (
		state.player_pos if state.phase != "title" else Vector2(time * 18.0, time * 8.0)
	)
	_draw_synthwave_world(offset)
	if state.phase != "title":
		_draw_objects()
	_draw_tracking_noise(offset)


func _draw_synthwave_world(offset: Vector2) -> void:
	var progress: float = (
		fposmod(time / 45.0, 1.0)
		if state.phase == "title"
		else clampf(state.elapsed / Rules.DURATION, 0.0, 1.0)
	)
	var horizon_y: float = 248.0 - progress * 28.0
	var sky_top := Color("08051f").lerp(Color("021f31"), progress)
	var sky_horizon := Color("72136f").lerp(Color("087f83"), progress)
	for band: int in range(18):
		var fraction: float = float(band) / 17.0
		var band_y: float = horizon_y * fraction
		draw_rect(
			Rect2(0, band_y, 1280, horizon_y / 17.0 + 1.0),
			sky_top.lerp(sky_horizon, pow(fraction, 1.3))
		)
	var ground_top := Color("16062b").lerp(Color("031d2c"), progress)
	var ground_bottom := Color("05030f").lerp(Color("050b17"), progress)
	for band: int in range(18):
		var fraction: float = float(band) / 17.0
		var band_y: float = horizon_y + (720.0 - horizon_y) * fraction
		draw_rect(
			Rect2(0, band_y, 1280, (720.0 - horizon_y) / 17.0 + 1.0),
			ground_top.lerp(ground_bottom, fraction)
		)
	_draw_striped_sun(progress, horizon_y)
	_draw_infinite_grid(offset, horizon_y, progress)


func _draw_striped_sun(progress: float, horizon_y: float) -> void:
	var center := Vector2(1000.0 - progress * 110.0, horizon_y - 18.0 - progress * 42.0)
	var radius: float = 86.0 + progress * 18.0
	var sun_color := Color("ff3cae").lerp(Color("ffbd57"), progress)
	for stripe: int in range(-6, 7):
		var local_y: float = float(stripe) * 13.0
		if absf(local_y) >= radius:
			continue
		var half_width: float = sqrt(radius * radius - local_y * local_y)
		draw_line(
			center + Vector2(-half_width, local_y),
			center + Vector2(half_width, local_y),
			sun_color,
			8.0,
			true
		)
	draw_arc(center, radius + 8.0, PI, TAU, 64, Color(sun_color, 0.24), 5.0, true)


func _draw_infinite_grid(offset: Vector2, horizon_y: float, progress: float) -> void:
	var cyan := Color("21e6e6").lerp(Color("41ffd1"), progress)
	var magenta := Color("f51acb").lerp(Color("8a3ffc"), progress)
	var lane_offset: float = fposmod(offset.x, 128.0)
	var vanishing_x: float = 640.0 - fposmod(offset.x * 0.06 + 64.0, 128.0) + 64.0
	for index: int in range(-8, 9):
		var bottom_x: float = 640.0 + float(index) * 128.0 - lane_offset
		var color: Color = magenta if index % 4 == 0 else cyan
		color.a = 0.38 if index % 4 == 0 else 0.28
		draw_line(Vector2(vanishing_x, horizon_y), Vector2(bottom_x, 720), color, 1.5, true)
	var travel: float = fposmod(offset.y / 920.0, 1.0)
	for index: int in range(19):
		var depth: float = fposmod((float(index) + travel) / 19.0, 1.0)
		var y: float = horizon_y + pow(depth, 2.35) * (720.0 - horizon_y)
		var line_color := Color(cyan, 0.08 + depth * 0.42)
		draw_line(Vector2(0, y), Vector2(1280, y), line_color, 1.0 + depth * 1.7, true)
	draw_line(Vector2(0, horizon_y), Vector2(1280, horizon_y), Color(magenta, 0.62), 3.0)


func _draw_tracking_noise(offset: Vector2) -> void:
	for index: int in range(17):
		var y: float = fposmod(float(index * 97) + time * (9.0 + index % 3) - offset.y * 0.03, 720.0)
		var x: float = fposmod(float(index * 211) - offset.x * 0.05, 1280.0)
		var length: float = 18.0 + float(index % 5) * 14.0
		var color := Color("21e6e6") if index % 2 == 0 else Color("ff2ecf")
		color.a = 0.08 + float(index % 3) * 0.025
		draw_line(Vector2(x, y), Vector2(x + length, y), color, 1.0)


func _draw_objects() -> void:
	for gem: Dictionary in state.gems:
		_art("gem", screen(gem.pos), 20)
	for item: Dictionary in state.items:
		var point: Vector2 = screen(item.pos)
		draw_circle(point, 27, Color(0.67, 0.9, 0.68, 0.12))
		_art(item.kind, point + Vector2(0, sin(time * 3) * 3), 40)
	for projectile: Dictionary in state.projectiles:
		var point: Vector2 = screen(projectile.pos)
		var velocity: Vector2 = projectile.velocity
		draw_line(point - velocity.normalized() * 25, point, Color(0.55, 1, 0.87, 0.35), 5, true)
		draw_set_transform(point, velocity.angle() + PI / 4)
		_art("bolt", Vector2.ZERO, 30)
		draw_set_transform(Vector2.ZERO)
	if state.weapons.orbit > 0:
		for index: int in range(state.weapons.orbit + 1):
			_art("orbit", screen(state.orbit_position(index)), 40)
	draw_circle(CENTER, 48 + sin(time * 3) * 3, Color(1, 0.84, 0.5, 0.09))
	for enemy: Dictionary in state.enemies:
		if enemy.kind == 3:
			var point: Vector2 = screen(enemy.pos) + Vector2(-52, -70)
			draw_rect(Rect2(point, Vector2(104, 6)), Color("1c2735"))
			draw_rect(
				Rect2(point, Vector2(104 * maxf(0, enemy.hp / Rules.enemy_stats(3).hp), 6)),
				Color("ed9a83")
			)


func _art(key: String, at: Vector2, extent: float) -> void:
	draw_texture_rect(
		textures[key], Rect2(at - Vector2.ONE * extent / 2, Vector2.ONE * extent), false
	)
