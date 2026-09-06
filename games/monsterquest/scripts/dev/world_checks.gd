extends RefCounted
## 実際の地形を幅優先で探索し、行き止まりや戻れない地域移動を検出する。

const WORLD = preload("res://scripts/world.gd")
const DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const STARTS := {
	"town": Vector2i(9, 10),
	"route": Vector2i(1, 7),
	"home": Vector2i(11, 11),
	"clinic": Vector2i(11, 11),
}


static func run(check: Callable) -> void:
	for zone: String in STARTS:
		_check_region(zone, STARTS[zone], check)
	_check_connections(check)
	_check_obstacles(check)
	_check_input(check)


static func _reachable(zone: String, start: Vector2i) -> Dictionary:
	var visited: Dictionary = {}
	if not WORLD.walkable(zone, start):
		return visited
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	var index := 0
	while index < queue.size():
		var cell: Vector2i = queue[index]
		index += 1
		# 入口に踏み込むと別の地域へ移るため、その先を同じ地域として探索しない。
		if not WORLD.portal(zone, cell).is_empty():
			continue
		for direction: Vector2i in DIRECTIONS:
			var next := cell + direction
			if not visited.has(next) and WORLD.walkable(zone, next):
				visited[next] = true
				queue.append(next)
	return visited


static func _check_region(zone: String, start: Vector2i, check: Callable) -> void:
	var visited := _reachable(zone, start)
	check.call(visited.has(start), "%s の開始位置に立てる" % zone)
	var grass_count := 0
	var water_count := 0
	var portals: Array[Dictionary] = []
	for y in range(WORLD.GRID.y):
		for x in range(WORLD.GRID.x):
			var cell := Vector2i(x, y)
			if WORLD.walkable(zone, cell):
				check.call(visited.has(cell), "%s の歩けるセル %s まで到達できる" % [zone, cell])
			if WORLD.is_grass(zone, cell):
				grass_count += 1
				check.call(visited.has(cell), "%s の草むら %s まで到達できる" % [zone, cell])
			if WORLD.tile(zone, cell) == 4:
				water_count += 1
				check.call(not WORLD.walkable(zone, cell), "%s の水 %s に進入できない" % [zone, cell])
			var portal: Dictionary = WORLD.portal(zone, cell)
			if not portal.is_empty():
				check.call(visited.has(cell), "%s の出口 %s に到達できる" % [zone, cell])
				portals.append(portal)
	_check_return_paths(zone, portals, check)
	check.call(grass_count > 0 if zone == "route" else grass_count == 0,
		"草むらはルートに存在し、町と室内には存在しない: " + zone)
	if zone in ["town", "route"]:
		check.call(water_count > 0, zone + " に進入禁止の池が存在する")
	check.call(portals.size() == (3 if zone == "town" else 1), zone + " の出口数が正しい")
	if zone == "town":
		check.call(visited.has(Vector2i(18, 7)), "開始位置から隊長の隣まで到達できる")


static func _check_return_paths(zone: String, portals: Array[Dictionary], check: Callable) -> void:
	for portal: Dictionary in portals:
		var destination: String = portal.get("zone", "")
		check.call(STARTS.has(destination), "%s の移動先が存在する: %s" % [zone, destination])
		if not STARTS.has(destination):
			continue
		var landing: Vector2i = portal.get("cell", Vector2i(-1, -1))
		check.call(WORLD.walkable(destination, landing), "地域移動後に壁へ埋まらない")
		check.call(WORLD.portal(destination, landing).is_empty(), "地域移動直後に往復し続けない")
		var can_return := false
		for cell: Vector2i in _reachable(destination, landing):
			if WORLD.portal(destination, cell).get("zone", "") == zone:
				can_return = true
		check.call(can_return, "%s から %s へ移動したあと戻れる" % [zone, destination])


static func _check_connections(check: Callable) -> void:
	var expected: Array[Array] = [
		["town", Vector2i(23, 7), "route", Vector2i(1, 7)],
		["route", Vector2i(0, 7), "town", Vector2i(22, 7)],
		["town", Vector2i(5, 6), "home", Vector2i(11, 11)],
		["town", Vector2i(11, 6), "clinic", Vector2i(11, 11)],
		["home", Vector2i(11, 12), "town", Vector2i(5, 7)],
		["clinic", Vector2i(11, 12), "town", Vector2i(11, 7)],
	]
	for connection: Array in expected:
		var actual: Dictionary = WORLD.portal(connection[0], connection[1])
		check.call(actual.get("zone", "") == connection[2]
			and actual.get("cell", Vector2i(-1, -1)) == connection[3],
			"%s の入口 %s は %s の正しい位置へつながる" % connection.slice(0, 3))
		check.call(WORLD.walkable(connection[0], connection[1]), "地域の入口を通過できる")


static func _check_obstacles(check: Callable) -> void:
	var obstacles := {
		"town": [Vector2i(3, 2), Vector2i(7, 5), Vector2i(9, 2), Vector2i(13, 5),
			Vector2i(18, 6)],
		"route": [Vector2i(11, 2), Vector2i(13, 5)],
		"home": [Vector2i(3, 3), Vector2i(7, 5), Vector2i(16, 3), Vector2i(20, 5)],
		"clinic": [Vector2i(4, 3), Vector2i(8, 5), Vector2i(15, 3), Vector2i(19, 5)],
	}
	for zone: String in STARTS:
		for cell: Vector2i in obstacles[zone]:
			check.call(not WORLD.walkable(zone, cell), "%s の建物・家具・NPC %s に衝突する" % [zone, cell])
		for cell: Vector2i in [Vector2i(-1, 7), Vector2i(24, 7), Vector2i(7, -1), Vector2i(7, 14)]:
			check.call(not WORLD.walkable(zone, cell), zone + " のマップ外へ進めない")
		for x in range(WORLD.GRID.x):
			check.call(not WORLD.walkable(zone, Vector2i(x, 0)), zone + " の上端は壁")
			check.call(not WORLD.walkable(zone, Vector2i(x, 13)), zone + " の下端は壁")
		for y in range(WORLD.GRID.y):
			for x in [0, 23]:
				var cell := Vector2i(x, y)
				if WORLD.portal(zone, cell).is_empty():
					check.call(not WORLD.walkable(zone, cell), zone + " の左右端は出口以外が壁")


static func _check_input(check: Callable) -> void:
	var bindings := {
		"walk_left": {"keys": [KEY_A, KEY_LEFT], "button": JOY_BUTTON_DPAD_LEFT,
			"axis": JOY_AXIS_LEFT_X, "value": -1.0},
		"walk_right": {"keys": [KEY_D, KEY_RIGHT], "button": JOY_BUTTON_DPAD_RIGHT,
			"axis": JOY_AXIS_LEFT_X, "value": 1.0},
		"walk_up": {"keys": [KEY_W, KEY_UP], "button": JOY_BUTTON_DPAD_UP,
			"axis": JOY_AXIS_LEFT_Y, "value": -1.0},
		"walk_down": {"keys": [KEY_S, KEY_DOWN], "button": JOY_BUTTON_DPAD_DOWN,
			"axis": JOY_AXIS_LEFT_Y, "value": 1.0},
		"interact": {"keys": [KEY_ENTER, KEY_SPACE], "button": JOY_BUTTON_A},
		"ui_accept": {"keys": [KEY_ENTER, KEY_SPACE], "button": JOY_BUTTON_A},
		"menu": {"keys": [KEY_ESCAPE, KEY_TAB], "button": JOY_BUTTON_START},
		"fullscreen": {"keys": [KEY_F11]},
	}
	for action: String in bindings:
		check.call(InputMap.has_action(action), "入力アクションが存在する: " + action)
		if not InputMap.has_action(action):
			continue
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		var binding: Dictionary = bindings[action]
		for key: int in binding["keys"]:
			check.call(_has_key(events, key), "%s のキー %s が設定されている" % [action, OS.get_keycode_string(key)])
		if binding.has("button"):
			check.call(_has_button(events, binding["button"]), action + " にゲームパッドのボタンが設定されている")
		if binding.has("axis"):
			check.call(_has_motion(events, binding["axis"], binding["value"]),
				action + " に左スティックの方向が正しく設定されている")


static func _has_key(events: Array[InputEvent], key: int) -> bool:
	for event: InputEvent in events:
		if event is InputEventKey:
			if event.physical_keycode == key or event.keycode == key:
				return true
	return false


static func _has_button(events: Array[InputEvent], button: int) -> bool:
	for event: InputEvent in events:
		if event is InputEventJoypadButton and event.button_index == button:
			return true
	return false


static func _has_motion(events: Array[InputEvent], axis: int, value: float) -> bool:
	for event: InputEvent in events:
		if event is InputEventJoypadMotion:
			if event.axis == axis and is_equal_approx(event.axis_value, value):
				return true
	return false
