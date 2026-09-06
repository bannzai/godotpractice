extends SceneTree
## 初期状態から実ゲームと同じ更新を実行し、移動・強化選択だけで生存可能か確認する。
## 経過時間を加算するシミュレーションを駆動するため、実行は非冪等。

const State = preload("res://scripts/run_state.gd")
const STEP: float = 1.0 / 60.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var seed_value: int = 42
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if not arguments.is_empty():
		seed_value = int(arguments[0])
	var state: Node = State.new()
	state.start_run(seed_value)
	var movement: Vector2 = Vector2.ZERO
	var frame: int = 0
	var next_report: float = 120.0
	var peak_enemies: int = 0
	var started: int = Time.get_ticks_msec()
	while state.phase != "result" and frame < 37000:
		if state.phase == "upgrade":
			state.choose_upgrade(_upgrade_index(state))
			continue
		if frame % 6 == 0:
			movement = _movement(state)
		state.step(STEP, movement)
		peak_enemies = maxi(peak_enemies, state.enemies.size())
		frame += 1
		if state.elapsed >= next_report:
			print("途中経過: %d 秒 / レベル %d / 撃破 %d / HP %.0f" % [
				state.elapsed, state.level, state.kills, state.hp])
			next_report += 120.0
	print("自動通し検証: seed=%d / 勝利=%s / 生存=%.2f 秒 / レベル=%d / 撃破=%d" % [
		seed_value, str(state.won), state.elapsed, state.level, state.kills])
	print("残 HP=%.0f/%.0f / 武器=%s / 最大敵数=%d / 実行=%.2f 秒" % [
		state.hp, state.max_hp, str(state.weapons), peak_enemies,
		float(Time.get_ticks_msec() - started) / 1000.0])
	var won: bool = state.won
	state.free()
	quit(0 if won else 1)


func _upgrade_index(state: Node) -> int:
	var selected: int = 0
	var best: float = -INF
	for index: int in range(state.choices.size()):
		var choice: String = state.choices[index]
		var score: float = 0.0
		if state.weapons.has(choice):
			score = 100.0 - float(state.weapons[choice]) * 12.0
			if choice == "pulse":
				score += 5.0
		else:
			score = float({"power": 45, "tempo": 40, "reach": 35, "health": 25,
				"speed": 20}.get(choice, 0))
			if choice == "health" and state.hp < state.max_hp * 0.5:
				score = 110.0
		if score > best:
			best = score
			selected = index
	return selected


func _movement(state: Node) -> Vector2:
	var at: Vector2 = state.player_pos
	var target: Vector2 = Vector2.from_angle(state.elapsed * 0.05) * 550.0
	var best_distance: float = 1000.0
	for gem: Dictionary in state.gems:
		var distance: float = at.distance_to(Vector2(gem.pos))
		if distance < best_distance:
			best_distance = distance
			target = Vector2(gem.pos)
	for item: Dictionary in state.items:
		var distance: float = at.distance_to(Vector2(item.pos))
		if str(item.kind) == "heal" and state.hp < state.max_hp - 25.0:
			distance *= 0.25
		elif str(item.kind) == "magnet":
			distance *= 0.5
		else:
			continue
		if distance < best_distance:
			best_distance = distance
			target = Vector2(item.pos)
	var nearby: Array[Dictionary] = []
	for enemy: Dictionary in state.enemies:
		if at.distance_squared_to(Vector2(enemy.pos)) < 250.0 * 250.0:
			nearby.append(enemy)
	var selected: Vector2 = Vector2.ZERO
	var best_score: float = -INF
	for direction: int in range(16):
		var movement: Vector2 = Vector2.from_angle(TAU * direction / 16.0)
		var predicted: Vector2 = at + movement * state.move_speed * 0.3
		var score: float = at.distance_to(target) - predicted.distance_to(target)
		for enemy: Dictionary in nearby:
			var distance: float = predicted.distance_to(Vector2(enemy.pos)) - float(enemy.radius)
			if distance < 110.0:
				score -= pow(110.0 - maxf(0.0, distance), 2.0) * 0.15
		if absf(predicted.x) > 2100.0 or absf(predicted.y) > 2100.0:
			score -= 500.0
		if score > best_score:
			best_score = score
			selected = movement
	return selected
