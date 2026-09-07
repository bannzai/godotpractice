extends SceneTree
## 進行フラグ・敵の体力を直接変更せず、移動と戦闘で最後まで到達する。
var world: Node
var journey: Node
var failed: bool = false

func _initialize() -> void:
	call_deferred("run")

func step(motion: Vector2 = Vector2.ZERO) -> void:
	if world.mode != "play":
		return
	if motion != Vector2.ZERO:
		world.facing = motion.normalized()
	world.move_player(motion.normalized() * world.SPEED / 60.0)
	world._physics_process(1.0 / 60.0)

func expect(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		printerr("失敗: " + label)
	else:
		print("成功: " + label)

func walk(target: Vector2) -> void:
	var goal: Vector2i = world.cell_at(target)
	var start: Vector2i = world.cell_at(world.player)
	var frontier: Array[Vector2i] = [start]
	var previous: Dictionary = {start: start}
	while not frontier.is_empty() and not previous.has(goal):
		var current: Vector2i = frontier.pop_front()
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + direction
			if next.x < 1 or next.x > 18 or next.y < 1 or next.y > 9:
				continue
			if not previous.has(next) and world.can_stand(world.center(next)):
				previous[next] = current
				frontier.append(next)
	if not previous.has(goal):
		expect(false, "歩ける経路がある " + str(goal))
		return
	var path: Array[Vector2i] = [goal]
	while path.back() != start:
		path.append(previous[path.back()])
	path.reverse()
	for cell: Vector2i in path:
		var destination: Vector2 = target if cell == goal else world.center(cell)
		for frame: int in range(120):
			if world.player.distance_to(destination) < 2:
				break
			step(destination - Vector2(world.player))
			if world.mode != "play":
				expect(false, "歩行中に生存")
				return
		expect(world.player.distance_to(destination) < 3, "歩行 " + str(cell))

func travel(direction: Vector2i) -> void:
	var room: int = journey.room
	var exit_point: Vector2i = Vector2i(1 if direction.x < 0 else 18, 5) if direction.x != 0 else Vector2i(10, 1 if direction.y < 0 else 9)
	walk(world.center(exit_point))
	for frame: int in range(100):
		step(Vector2(direction))
		if journey.room != room:
			break
	expect(journey.room != room, "部屋の境界を歩いて通過")

func fight() -> void:
	for frame: int in range(2400):
		if world.enemies.is_empty() or world.mode != "play":
			break
		var enemy: Dictionary = world.enemies[0]
		for candidate: Dictionary in world.enemies:
			if Vector2(candidate.pos).distance_to(world.player) < Vector2(enemy.pos).distance_to(world.player):
				enemy = candidate
		var offset: Vector2 = Vector2(enemy.pos) - Vector2(world.player)
		world.facing = offset.normalized()
		if journey.ember:
			world.interact()
		if offset.length() < 51:
			world.swing()
		if offset.length() > 43:
			step(offset)
		elif offset.length() < 32:
			step(-offset)
		else:
			step()
	expect(world.enemies.is_empty() and world.mode == "play", "通常の攻撃で部屋の敵を全討伐・生存")

func run() -> void:
	journey = root.get_node("Journey")
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set_physics_process(false)
	world.new_game()
	travel(Vector2i.RIGHT)
	fight()
	if world.mode == "play":
		walk(world.center(Vector2i(16, 5)))
		world.interact()
		expect(journey.key_found, "森で鍵を取得")
		walk(world.center(Vector2i(10, 1)))
		world.interact()
		travel(Vector2i.UP)
		walk(world.center(Vector2i(7, 5)))
		for frame: int in range(90):
			step(Vector2.RIGHT)
		expect(journey.solved, "石を押して謎解き")
		walk(world.center(Vector2i(10, 3)))
		world.interact()
		expect(journey.ember, "灯火を取得")
		travel(Vector2i.DOWN)
		travel(Vector2i.RIGHT)
		fight()
		walk(world.center(Vector2i(8, 3)))
		world.interact()
		walk(world.center(Vector2i(12, 3)))
		world.interact()
		expect(journey.braziers.size() == 2, "二本に点灯")
		travel(Vector2i.UP)
		fight()
		walk(world.center(Vector2i(10, 3)))
		world.interact()
	expect(journey.won and world.mode == "ending", "初期状態から進行を改変せず最後までクリア")
	print("クリア時体力: ", journey.health)
	world.queue_free()
	world = null
	for frame: int in range(5):
		await physics_frame
	quit(1 if failed else 0)
