extends Node2D
## 盤面の表示。背景・ピース・演出は単色の正方形と円で構成する。

const Piece = preload("res://scripts/piece_sprite.gd")
const Rules = preload("res://scripts/puzzle_rules.gd")
const CELL: float = 40.0
const INK := Color("18181d")
const PAPER := Color("f6f3ec")
const GRID_A := Color("ebe7de")
const GRID_B := Color("e2ddd3")

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
var _border: Array[ColorRect] = []


func setup(owner_session: Node, player: int) -> void:
	session = owner_session
	side = player
	origin = position
	_build_board()
	pieces = Node2D.new()
	add_child(pieces)
	ghosts = Node2D.new()
	add_child(ghosts)
	active = Node2D.new()
	add_child(active)
	next_pieces = Node2D.new()
	add_child(next_pieces)
	refresh("idle")


func _build_board() -> void:
	_rect(self, Rect2(-12, -12, 264, 504), Color(0.09, 0.09, 0.11, 0.12))
	_rect(self, Rect2(-8, -8, 256, 496), PAPER)
	for row: int in range(12):
		for col: int in range(6):
			_rect(
				self,
				Rect2(col * CELL + 1, row * CELL + 1, CELL - 2, CELL - 2),
				GRID_A if (row + col) % 2 == 0 else GRID_B
			)
	for rect: Rect2 in [
		Rect2(-8, -8, 256, 4), Rect2(-8, 484, 256, 4),
		Rect2(-8, -8, 4, 496), Rect2(244, -8, 4, 496),
	]:
		_border.append(
			_rect(self, rect, Color("6750a4") if side == 0 else Color("00a6a6"))
		)
	_rect(self, Rect2(0, 0, 240, 2), Color("ff5d73"))
	_circle(self, Vector2(100, 10), 4.0, Color("ff5d73"))


func _rect(parent: Node, rect: Rect2, color: Color) -> ColorRect:
	var shape := ColorRect.new()
	shape.color = color
	shape.position = rect.position
	shape.size = rect.size
	shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shape)
	return shape


func _circle(parent: Node, point: Vector2, radius: float, color: Color) -> Polygon2D:
	var shape := Polygon2D.new()
	var points := PackedVector2Array()
	for index: int in range(24):
		var angle: float = TAU * float(index) / 24.0
		points.append(point + Vector2(cos(angle), sin(angle)) * radius)
	shape.polygon = points
	shape.color = color
	parent.add_child(shape)
	return shape


func set_available(available: bool) -> void:
	var color := Color("6750a4") if side == 0 else Color("00a6a6")
	if side == 0 and not available:
		color = Color("aaa6a0")
	for edge: ColorRect in _border:
		edge.color = color


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
			actor.setup(board[row][col], CELL - 5)
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
	var board_state: Dictionary = session.boards[side]
	for index: int in range(2):
		_add_piece(active, board_state.pair[index], CELL - 5)
		var ghost: Node2D = _add_piece(ghosts, board_state.pair[index], CELL - 7)
		ghost.modulate.a = 0.20
		for part: int in range(2):
			var preview: Node2D = _add_piece(next_pieces, board_state.next[index][part], 29)
			preview.position = Vector2(278 + part * 32, 51 + index * 79)


func _add_piece(parent: Node, kind: int, side_length: float) -> Node2D:
	var actor: Node2D = Piece.new()
	parent.add_child(actor)
	actor.setup(kind, side_length)
	return actor


## 描画時計と落下位置を追うため非冪等。
func _process(delta: float) -> void:
	if not is_instance_valid(session) or session.boards.is_empty():
		return
	clock += delta
	shake = maxf(0.0, shake - delta)
	position = origin + Vector2(sin(clock * 90.0), cos(clock * 73.0)) * shake * 16.0
	var board_state: Dictionary = session.boards[side]
	active.visible = board_state.phase == "falling"
	ghosts.visible = active.visible and side == 0
	if not active.visible:
		return
	var falling: Array = Rules.cells(board_state.position, board_state.rotation)
	var landing: Array = Rules.cells(
		Rules.drop_position(board_state.board, board_state.position, board_state.rotation),
		board_state.rotation
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
				actors[cell].play_pose("clear", 0.055)
				_spark((Vector2(cell) + Vector2(0.5, 0.5)) * CELL, chain)
		shake = minf(0.20, chain * 0.04)
	if kind == "garbage":
		shake = 0.38


## 一度の消去に幾何片を生成し、Tween 完了後に解放するため非冪等。
func _spark(point: Vector2, chain: int) -> void:
	for index: int in range(12):
		var fragment := Node2D.new()
		add_child(fragment)
		fragment.position = point
		if index % 2 == 0:
			_circle(fragment, Vector2.ZERO, 3.0 + chain, Color("6750a4"))
		else:
			_rect(fragment, Rect2(-3, -3, 6, 6), Color("ffca3a"))
		fragment.z_index = 20
		var angle: float = TAU * float(index) / 12.0
		var target: Vector2 = point + Vector2(cos(angle), sin(angle)) * (32.0 + chain * 5.0)
		var tween := fragment.create_tween()
		tween.set_parallel(true)
		tween.tween_property(fragment, "position", target, 0.46).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(fragment, "rotation", angle + PI, 0.46)
		tween.tween_property(fragment, "modulate:a", 0.0, 0.46)
		tween.set_parallel(false)
		tween.tween_callback(fragment.queue_free)
