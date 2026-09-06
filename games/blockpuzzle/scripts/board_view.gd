extends Node2D
## 盤面の表示。落下中・固定済み・消去中の精霊を別々に保持する。

const Piece = preload("res://scripts/piece_sprite.gd")
const Rules = preload("res://scripts/puzzle_rules.gd")
const CELL: float = 40.0

var session: Node
var side: int = 0
var pieces: Node2D
var active: Node2D
var ghosts: Node2D
var actors: Dictionary = {}
var next_pieces: Node2D
var shake: float = 0.0
var origin: Vector2
var clock: float = 0.0


func setup(owner_session: Node, player: int) -> void:
	session = owner_session
	side = player
	origin = position
	pieces = Node2D.new()
	add_child(pieces)
	ghosts = Node2D.new()
	add_child(ghosts)
	active = Node2D.new()
	add_child(active)
	next_pieces = Node2D.new()
	add_child(next_pieces)
	refresh("idle")


func _draw() -> void:
	draw_style_box(_panel(), Rect2(-12, -12, 264, 504))
	for row: int in range(12):
		for col: int in range(6):
			var color := Color("243c51") if (row + col) % 2 == 0 else Color("20364a")
			draw_rect(Rect2(col * CELL + 1, row * CELL + 1, CELL - 2, CELL - 2), color)
	draw_line(Vector2(0, 1), Vector2(240, 1), Color("f5a589"), 2)
	draw_circle(Vector2(100, 12), 3, Color("f5a589"))


func _panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101e32")
	style.border_color = Color("76b9b3") if side == 0 else Color("b49ec6")
	style.set_border_width_all(2)
	style.set_corner_radius_all(15)
	style.shadow_color = Color(0.02, 0.04, 0.09, 0.5)
	style.shadow_size = 12
	return style


func _empty(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


func refresh(pose: String) -> void:
	if not is_instance_valid(pieces) or session.boards.is_empty():
		return
	_empty(pieces)
	actors.clear()
	var board: Array = session.boards[side].board
	for row: int in range(12):
		for col: int in range(6):
			if board[row][col] == 0:
				continue
			var actor: Node2D = Piece.new()
			pieces.add_child(actor)
			actor.setup(board[row][col], CELL - 1)
			actor.position = Vector2(col + 0.5, row + 0.5) * CELL
			actors[Vector2i(col, row)] = actor
			if pose in ["land", "garbage"]:
				actor.play_pose("land" if pose == "land" else "hurt")
			if pose in ["fall", "garbage"]:
				var destination: Vector2 = actor.position
				actor.position.y -= 32 if pose == "fall" else 90
				actor.create_tween().tween_property(actor, "position", destination, 0.24)
	_empty(active)
	_empty(ghosts)
	_empty(next_pieces)
	var b: Dictionary = session.boards[side]
	for index: int in range(2):
		_add_piece(active, b.pair[index], CELL - 1)
		var ghost: Node2D = _add_piece(ghosts, b.pair[index], CELL - 4)
		ghost.modulate.a = 0.24
		for part: int in range(2):
			var preview: Node2D = _add_piece(next_pieces, b.next[index][part], 31)
			preview.position = Vector2(280 + part * 33, 50 + index * 79)


func _add_piece(parent: Node, kind: int, side_length: float) -> Node2D:
	var actor: Node2D = Piece.new()
	parent.add_child(actor)
	actor.setup(kind, side_length)
	return actor


# 描画時計と落下位置を追うため非冪等。
func _process(delta: float) -> void:
	if not is_instance_valid(session) or session.boards.is_empty():
		return
	clock += delta
	shake = maxf(0.0, shake - delta)
	position = origin + Vector2(sin(clock * 90.0), cos(clock * 73.0)) * shake * 16.0
	var b: Dictionary = session.boards[side]
	active.visible = b.phase == "falling"
	ghosts.visible = active.visible and side == 0
	if not active.visible:
		return
	var falling: Array = Rules.cells(b.position, b.rotation)
	var landing: Array = Rules.cells(
		Rules.drop_position(b.board, b.position, b.rotation), b.rotation
	)
	for index: int in range(2):
		active.get_child(index).position = (Vector2(falling[index]) + Vector2(0.5, 0.5)) * CELL
		active.get_child(index).visible = falling[index].y >= 0
		ghosts.get_child(index).position = (Vector2(landing[index]) + Vector2(0.5, 0.5)) * CELL


func animate(kind: String, cells: Array, chain: int) -> void:
	if kind in ["move", "rotate"]:
		for actor: Node in active.get_children():
			actor.play_pose("move")
	if kind == "clear":
		for cell: Vector2i in cells:
			if actors.has(cell):
				actors[cell].play_pose("clear")
				actors[cell].animator.speed_scale = 0.0
				var release: Tween = actors[cell].create_tween()
				release.tween_interval(0.055)
				release.tween_property(actors[cell].animator, "speed_scale", 1.0, 0.01)
				_spark((Vector2(cell) + Vector2(0.5, 0.5)) * CELL, chain)
		shake = minf(0.20, chain * 0.04)
	if kind == "garbage":
		shake = 0.38


# 一度の消去に粒子を生成し、寿命後に解放するため非冪等。
func _spark(point: Vector2, chain: int) -> void:
	var particle := CPUParticles2D.new()
	add_child(particle)
	particle.position = point
	particle.emitting = false
	particle.amount = 14
	particle.one_shot = true
	particle.explosiveness = 1.0
	particle.lifetime = 0.5
	particle.direction = Vector2.UP
	particle.spread = 180.0
	particle.gravity = Vector2(0, 160)
	particle.initial_velocity_min = 45
	particle.initial_velocity_max = 130
	particle.scale_amount_min = 2.0
	particle.scale_amount_max = 4.0
	particle.color = Color("ffdf9c") if chain < 3 else Color("baffeb")
	particle.emitting = true
	get_tree().create_timer(0.8).timeout.connect(particle.queue_free)
