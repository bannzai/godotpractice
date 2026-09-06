extends Node
## 全画面で共有するレース状態。時間進行・入力・命中はイベントなので非冪等。

signal effect(kind: String, racer: int)
signal phase_changed

const Course = preload("res://scripts/course_data.gd")
const SAVE_PATH: String = "user://kartrace-best.cfg"
const KARTS: Array[Dictionary] = [
	{"name": "しずく", "acceleration": 12.0, "max_speed": 22.0,
		"handling": 5.2, "color": Color("7fe3c4")},
	{"name": "あかね", "acceleration": 8.0, "max_speed": 25.0,
		"handling": 4.0, "color": Color("ffad75")},
	{"name": "すみれ", "acceleration": 15.0, "max_speed": 20.5,
		"handling": 6.4, "color": Color("bca7f2")},
]
const ITEM_NAMES: Array[String] = ["なし", "パルス", "ブイ", "ターボ"]

var phase: String = "title"
var selected_kart: int = 0
var racers: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var obstacles: Array[Dictionary] = []
var elapsed: float = 0.0
var countdown: float = 3.0
var best_time: float = 0.0
var save_enabled: bool = true
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _box_cooldowns: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	load_best()


func reset_race() -> void:
	racers.clear()
	projectiles.clear()
	obstacles.clear()
	_box_cooldowns.clear()
	elapsed = 0.0
	countdown = 3.0
	for i: int in range(4):
		var kind: int = selected_kart if i == 0 else (selected_kart + i) % KARTS.size()
		racers.append({
			"id": i, "kind": kind, "name": "あなた" if i == 0 else ["", "ピピ", "モコ", "ルル"][i],
			"progress": -float(i) * 2.0, "lateral": -1.8 if i % 2 == 0 else 1.8,
			"speed": 0.0, "lap": 1, "next_checkpoint": 0, "checkpoint_count": 0,
			"item": 0, "spin": 0.0, "boost": 0.0, "finish_time": -1.0,
			"drift_charge": 0.0, "drifting": false, "drift_direction": 0.0,
			"lap_started": 0.0, "lap_times": [], "respawn_timer": 0.0,
			"invulnerable": 0.0, "item_timer": 2.5 + i, "last_checkpoint": 0.0,
			"last_pad": -1, "wrong_way": false,
		})
	_set_phase("countdown")


func return_to_title() -> void:
	_set_phase("title")


# 入力を積分してレース時刻を進めるため、呼び出すたびに状態が変わる。
func tick(delta: float, throttle: float, steer: float, drift: bool, fire: bool) -> void:
	if delta <= 0.0:
		return
	# フレーム落ちでも壁・チェックポイント・飛翔体を飛び越さないよう小刻みに積分する。
	var remaining: float = delta
	var pending_fire: bool = fire
	while remaining > 0.00001:
		var step: float = minf(remaining, 1.0 / 60.0)
		_tick_step(step, throttle, steer, drift, pending_fire)
		pending_fire = false
		remaining -= step


# フレーム内の時間進行を積分するため非冪等。
func _tick_step(delta: float, throttle: float, steer: float, drift: bool, fire: bool) -> void:
	if phase == "countdown":
		countdown = maxf(0.0, countdown - delta)
		if countdown <= 0.00001:
			countdown = 0.0
			_set_phase("racing")
			effect.emit("start", 0)
		return
	if phase != "racing":
		return
	elapsed += delta
	for i: int in range(racers.size()):
		var racer: Dictionary = racers[i]
		if racer.finish_time >= 0.0:
			continue
		if i == 0:
			_drive(i, delta, throttle, steer, drift)
			if fire:
				use_item(i)
		else:
			_drive_cpu(i, delta)
	_update_weapons(delta)
	_check_collisions()
	if racers.all(func(racer: Dictionary) -> bool: return racer.finish_time >= 0.0):
		if best_time <= 0.0 or racers[0].finish_time < best_time:
			best_time = racers[0].finish_time
			if save_enabled:
				save_best()
		_set_phase("results")
		effect.emit("finish", 0)


func rank_of(index: int) -> int:
	var order: Array[Dictionary] = results()
	for i: int in range(order.size()):
		if order[i].id == index:
			return i + 1
	return racers.size()


func results() -> Array[Dictionary]:
	var order: Array[Dictionary] = racers.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.finish_time >= 0.0 and b.finish_time >= 0.0:
			return a.finish_time < b.finish_time
		if a.finish_time >= 0.0 or b.finish_time >= 0.0:
			return a.finish_time >= 0.0
		return a.progress > b.progress)
	return order


# 消費入力は同じ引数でも所持品を消費するイベント。
func use_item(index: int) -> void:
	if phase != "racing" or racers[index].finish_time >= 0.0:
		return
	var racer: Dictionary = racers[index]
	var item: int = racer.item
	if item == 0:
		return
	racer.item = 0
	match item:
		1:
			projectiles.append({"owner": index, "progress": racer.progress + 3.0,
				"lateral": racer.lateral, "ttl": 3.0})
		2:
			obstacles.append({"owner": index, "progress": racer.progress - 3.0,
				"lateral": racer.lateral, "ttl": 16.0})
		3:
			racer.boost = 2.2
	effect.emit("item_use", index)


# 命中は減速と無敵時間を開始するイベント。重複命中は無敵時間で抑える。
func hit(index: int) -> void:
	var racer: Dictionary = racers[index]
	if racer.invulnerable > 0.0 or racer.finish_time >= 0.0:
		return
	racer.spin = 0.85
	racer.speed *= 0.3
	racer.boost = 0.0
	racer.invulnerable = 1.5
	effect.emit("hit", index)


func respawn(index: int) -> void:
	var racer: Dictionary = racers[index]
	if racer.respawn_timer > 0.0:
		return
	racer.progress = racer.last_checkpoint
	racer.lateral = 0.0
	racer.speed = 0.0
	racer.spin = 0.0
	racer.boost = 0.0
	racer.respawn_timer = 1.1
	racer.invulnerable = 2.0
	effect.emit("respawn", index)


func load_best() -> void:
	var config: ConfigFile = ConfigFile.new()
	best_time = 0.0
	if config.load(SAVE_PATH) == OK:
		best_time = parse_best(config.get_value("record", "time", 0.0))


func save_best() -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("record", "time", best_time)
	return config.save(SAVE_PATH)


static func parse_best(value: Variant) -> float:
	if not (value is float or value is int):
		return 0.0
	var number: float = float(value)
	return number if is_finite(number) and number > 0.0 else 0.0


func _set_phase(value: String) -> void:
	if phase == value:
		return
	phase = value
	phase_changed.emit()


# 物理フレームごとの積分処理なので非冪等。
func _drive(index: int, delta: float, throttle: float, steer: float, drift: bool) -> void:
	var racer: Dictionary = racers[index]
	var kart: Dictionary = KARTS[racer.kind]
	for timer: String in ["spin", "boost", "respawn_timer", "invulnerable"]:
		racer[timer] = maxf(0.0, racer[timer] - delta)
	if racer.respawn_timer > 0.0:
		return
	var maximum: float = kart.max_speed
	if index > 0:
		maximum *= clampf(1.0 + (racers[0].progress - racer.progress) * 0.002, 0.86, 1.15)
	if racer.boost > 0.0:
		maximum *= 1.48
	if Course.on_shortcut(racer.progress, racer.lateral):
		maximum *= 1.22
	var target: float = maximum * throttle if throttle >= 0.0 else 7.0 * throttle
	if racer.spin > 0.0:
		target = 2.0
	racer.speed = move_toward(racer.speed, target, kart.acceleration * delta)
	var previous: float = racer.progress
	racer.progress += racer.speed * delta
	racer.wrong_way = racer.speed < -1.0
	_update_drift(index, delta, steer, drift)
	var lateral_speed: float = steer * kart.handling * minf(absf(racer.speed) / 8.0, 1.0)
	if racer.spin <= 0.0:
		racer.lateral += (lateral_speed + racer.speed * racer.speed * 0.0008) * delta
	if absf(racer.lateral) > Course.ROAD_WIDTH * 0.5:
		if Course.has_wall(racer.progress, racer.lateral):
			racer.lateral = clampf(racer.lateral, -5.95, 5.95)
			if racer.invulnerable <= 0.0:
				racer.speed *= 0.58
				racer.invulnerable = 0.45
				effect.emit("wall", index)
		elif absf(racer.lateral) > 10.5 and not Course.on_shortcut(racer.progress, racer.lateral):
			respawn(index)
			return
	_update_checkpoints(index, previous)
	_collect_track_objects(index, previous)


# チャージは持続入力の時間を蓄積するため非冪等。
func _update_drift(index: int, delta: float, steer: float, drift: bool) -> void:
	var racer: Dictionary = racers[index]
	var active: bool = drift and absf(steer) > 0.15 and racer.speed > 8.0 and racer.spin <= 0.0
	if active:
		if racer.drift_direction != signf(steer):
			racer.drift_charge = 0.0
			racer.drift_direction = signf(steer)
		racer.drift_charge = minf(2.0, racer.drift_charge + delta)
	elif racer.drifting:
		if racer.drift_charge >= 0.65:
			racer.boost = maxf(racer.boost, 0.7 + racer.drift_charge * 0.35)
			effect.emit("boost", index)
		racer.drift_charge = 0.0
	racer.drifting = active


# CPU の意思決定とアイテム使用時刻を毎フレーム進める。
func _drive_cpu(index: int, delta: float) -> void:
	var racer: Dictionary = racers[index]
	var lane: float = sin(racer.progress / 31.0 + index) * 2.1
	var steer: float = clampf((lane - racer.lateral) * 0.7 - 0.08, -1.0, 1.0)
	_drive(index, delta, 1.0, steer, false)
	racer.item_timer -= delta
	if racer.item_timer <= 0.0 and racer.item != 0:
		use_item(index)
		racer.item_timer = 2.2 + index * 0.5


# 正方向の通過イベントだけを受理し、次に受理できる地点を進める。
func _update_checkpoints(index: int, previous: float) -> void:
	var racer: Dictionary = racers[index]
	var next: float = (
		floorf(float(racer.checkpoint_count) / Course.CHECKPOINTS.size()) * Course.LENGTH
		+ Course.CHECKPOINTS[racer.next_checkpoint]
	)
	if previous >= next or racer.progress < next or racer.progress <= previous:
		return
	racer.last_checkpoint = next
	racer.checkpoint_count += 1
	racer.next_checkpoint = racer.checkpoint_count % Course.CHECKPOINTS.size()
	if racer.next_checkpoint != 0:
		return
	racer.lap_times.append(elapsed - racer.lap_started)
	racer.lap_started = elapsed
	if racer.checkpoint_count >= Course.LAPS * Course.CHECKPOINTS.size():
		racer.finish_time = elapsed
		racer.speed = 0.0
		effect.emit("goal", index)
	else:
		racer.lap += 1
		effect.emit("lap", index)


# 配置物の通過は取得・使用済み状態を作るイベント。
func _collect_track_objects(index: int, previous: float) -> void:
	var racer: Dictionary = racers[index]
	if racer.progress <= previous:
		return
	var lap_start: float = floorf(racer.progress / Course.LENGTH) * Course.LENGTH
	for i: int in range(Course.ITEM_BOXES.size()):
		var box: Dictionary = Course.ITEM_BOXES[i]
		var point: float = lap_start + box.progress
		if previous < point and racer.progress >= point and absf(racer.lateral - box.lateral) < 1.7:
			if racer.item == 0 and elapsed >= float(_box_cooldowns.get(i, 0.0)):
				racer.item = _rng.randi_range(1, 3)
				_box_cooldowns[i] = elapsed + 2.0
				effect.emit("pickup", index)
	for i: int in range(Course.DASH_PADS.size()):
		var pad: Dictionary = Course.DASH_PADS[i]
		var point: float = lap_start + pad.progress
		if previous < point and racer.progress >= point and absf(racer.lateral - pad.lateral) < 1.8:
			racer.boost = maxf(racer.boost, 1.3)
			effect.emit("boost", index)


# 飛翔体の積分と命中による消費を行うため非冪等。
func _update_weapons(delta: float) -> void:
	for weapons: Array[Dictionary] in [projectiles, obstacles]:
		for i: int in range(weapons.size() - 1, -1, -1):
			var weapon: Dictionary = weapons[i]
			weapon.ttl -= delta
			if weapons == projectiles:
				weapon.progress += 42.0 * delta
			for racer: Dictionary in racers:
				if racer.id == weapon.owner or racer.finish_time >= 0.0:
					continue
				var gap: float = absf(wrapf(racer.progress - weapon.progress,
					-Course.LENGTH * 0.5, Course.LENGTH * 0.5))
				if gap < 2.2 and absf(racer.lateral - weapon.lateral) < 1.65:
					hit(racer.id)
					weapon.ttl = 0.0
					break
			if weapon.ttl <= 0.0:
				weapons.remove_at(i)


# 接触イベントで速度を落とすため非冪等。接触直後の再適用は無敵時間で抑える。
func _check_collisions() -> void:
	for i: int in range(racers.size()):
		for j: int in range(i + 1, racers.size()):
			var a: Dictionary = racers[i]
			var b: Dictionary = racers[j]
			if a.finish_time >= 0.0 or b.finish_time >= 0.0:
				continue
			var gap: float = absf(wrapf(a.progress - b.progress,
				-Course.LENGTH * 0.5, Course.LENGTH * 0.5))
			if gap < 2.0 and absf(a.lateral - b.lateral) < 1.5:
				if a.invulnerable <= 0.0 and b.invulnerable <= 0.0:
					a.speed *= 0.72
					b.speed *= 0.72
					a.invulnerable = 0.7
					b.invulnerable = 0.7
					effect.emit("wall", i)
