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
	var atmosphere := ColorRect.new()
	atmosphere.size = Vector2(1280, 720)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := ShaderMaterial.new()
	shader.shader = load("res://shaders/forest_atmosphere.gdshader")
	atmosphere.material = shader
	add_child(atmosphere)
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
	draw_rect(Rect2(-20, -20, 1320, 760), Color("102c36"))
	var offset: Vector2 = state.player_pos if state.phase != "title" else Vector2(time * 5, 0)
	var tile := Vector2(fposmod(-offset.x, 256.0), fposmod(-offset.y, 256.0))
	for y: int in range(-1, 4):
		for x: int in range(-1, 6):
			draw_texture_rect(
				textures.floor, Rect2(tile + Vector2(x, y) * 256, Vector2(256, 256)), false
			)
	_layer("forest-far", offset * 0.12, Color(1, 1, 1, 0.72))
	_layer("mist", offset * 0.25 + Vector2(time * 5, 0), Color(1, 1, 1, 0.24))
	if state.phase != "title":
		draw_rect(
			Rect2(screen(Vector2.ONE * -Rules.WORLD_LIMIT), Vector2.ONE * Rules.WORLD_LIMIT * 2),
			Color("63846c"),
			false,
			3
		)
		_draw_objects()
	_layer("forest-near", offset * 0.42, Color(1, 1, 1, 0.52))
	for i: int in range(36):
		var point := Vector2(
			fposmod(i * 173 + sin(time + i) * 16 - offset.x * 0.35, 1280),
			fposmod(i * 89 + time * 5 - offset.y * 0.35, 720)
		)
		draw_circle(point, 1.8, Color(0.9, 1.0, 0.7, 0.26 + sin(i + time) * 0.2))


func _layer(key: String, offset: Vector2, tint: Color) -> void:
	var x: float = fposmod(-offset.x, 1280.0)
	for index: int in range(-1, 1):
		draw_texture_rect(
			textures[key], Rect2(x + index * 1280, -offset.y * 0.08, 1280, 760), false, tint
		)


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
