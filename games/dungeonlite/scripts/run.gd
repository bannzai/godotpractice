extends Node
## ラン・戦闘・永続強化の唯一の状態。時間進行と購入はゲームの性質上非冪等。

signal sound_requested(kind: String)
signal phase_changed

enum Phase { CAMP, PLAY, CHOICE, RESULT }

class Foe:
	var position: Vector2
	var health: int
	var maximum: int
	var kind: int
	var timer: float = 1.0
	var flash: float = 0.0
	var target: Vector2 = Vector2.ZERO

class Shot:
	var position: Vector2
	var velocity: Vector2
	var life: float = 5.0

const FIELD: Rect2 = Rect2(96, 176, 960, 480)
const EXIT: Vector2 = Vector2(1008, 416)
const SAVE_PATH: String = "user://lantern.cfg"
const BOONS: Array[Dictionary] = [
	{"name": "砥石", "detail": "剣の威力 +1", "icon": 103},
	{"name": "風の羽", "detail": "移動速度 +24", "icon": 111},
	{"name": "命の器", "detail": "最大体力 +2・体力を全回復", "icon": 115},
	{"name": "長い刃", "detail": "剣の届く距離 +20", "icon": 104},
	{"name": "速い鼓動", "detail": "攻撃の待ち時間を短縮", "icon": 116},
	{"name": "灯の雫", "detail": "体力を4回復・欠片 +5", "icon": 117},
]
var phase: Phase = Phase.CAMP
var bank: int = 0
var vitality: int = 0
var mastery: int = 0
var best: int = 0
var save_path: String = SAVE_PATH
var persistence: bool = true
var save_error: String = ""
var room: int = 0
var shards: int = 0
var collected: int = 0
var health: int = 6
var max_health: int = 6
var power: int = 2
var speed: float = 190.0
var reach: float = 92.0
var interval: float = 0.42
var player: Vector2 = Vector2(200, 416)
var facing: Vector2 = Vector2.RIGHT
var attack_left: float = 0.0
var attack_wait: float = 0.0
var dash_left: float = 0.0
var dash_wait: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT
var invulnerable: float = 0.0
var elapsed: float = 0.0
var clear: bool = false
var paused: bool = false
var result: String = ""
var foes: Array[Foe] = []
var shots: Array[Shot] = []
var obstacles: Array[Rect2] = []
var choices: Array[int] = []
var taken: Array[String] = []
var random: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--no-save"):
		load_progress()
	else:
		persistence = false

func load_progress() -> void:
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(save_path)
	if error == ERR_FILE_NOT_FOUND:
		return
	if error != OK:
		save_error = "記録を読み込めませんでした。今回は保存せず遊べます"
		persistence = false
		return
	bank = maxi(0, int(config.get_value("camp", "shards", 0)))
	vitality = clampi(int(config.get_value("camp", "vitality", 0)), 0, 5)
	mastery = clampi(int(config.get_value("camp", "mastery", 0)), 0, 3)
	best = clampi(int(config.get_value("camp", "best", 0)), 0, 6)

func save_progress() -> bool:
	if not persistence:
		return true
	var config: ConfigFile = ConfigFile.new()
	config.set_value("camp", "shards", bank)
	config.set_value("camp", "vitality", vitality)
	config.set_value("camp", "mastery", mastery)
	config.set_value("camp", "best", best)
	var error: Error = config.save(save_path + ".pending")
	if error == OK:
		error = DirAccess.rename_absolute(save_path + ".pending", save_path)
	save_error = "" if error == OK else "記録の保存に失敗しました。終了前に保存を再試行してください"
	return error == OK

func upgrade_cost(kind: int) -> int:
	return 8 + vitality * 8 if kind == 0 else 14 + mastery * 14

func purchase(kind: int) -> bool:
	if phase != Phase.CAMP or kind not in [0, 1]:
		return false
	if (vitality >= 5 if kind == 0 else mastery >= 3) or bank < upgrade_cost(kind):
		return false
	bank -= upgrade_cost(kind)
	if kind == 0:
		vitality += 1
	else:
		mastery += 1
	save_progress()
	sound_requested.emit("reward")
	phase_changed.emit()
	return true

func start(seed_value: int = -1) -> void:
	if seed_value < 0:
		random.randomize()
	else:
		random.seed = seed_value
	room = 0
	shards = 0
	collected = 0
	max_health = 6 + vitality * 2
	health = max_health
	power = 2 + mastery
	speed = 190.0
	reach = 92.0
	interval = 0.42
	taken.clear()
	elapsed = 0.0
	paused = false
	next_room()

func next_room() -> void:
	room += 1
	phase = Phase.PLAY
	clear = false
	player = Vector2(200, 416)
	facing = Vector2.RIGHT
	attack_left = 0.0
	attack_wait = 0.0
	dash_left = 0.0
	dash_wait = 0.0
	invulnerable = 1.0
	foes.clear()
	shots.clear()
	obstacles.clear()
	if room < 6:
		var shift: float = float(random.randi_range(-1, 1)) * 48.0
		obstacles.append(Rect2(432, 240 + shift, 48, 96))
		obstacles.append(Rect2(672, 496 - shift, 48, 96))
		for index: int in range(3 + room):
			spawn_foe(Vector2(600 + (index % 4) * 96, 220 + (index / 4) * 300), random.randi_range(0, mini(2, room - 1)))
	else:
		spawn_foe(Vector2(840, 416), 3)
	phase_changed.emit()

func spawn_foe(at: Vector2, kind: int) -> void:
	var foe: Foe = Foe.new()
	foe.position = at
	while not can_stand(foe.position):
		foe.position.y -= 48.0
	foe.kind = kind
	foe.maximum = 44 if kind == 3 else 3 + room + kind
	foe.health = foe.maximum
	foe.timer = random.randf_range(0.5, 1.5)
	foes.append(foe)

func can_stand(at: Vector2, radius: float = 16.0) -> bool:
	if not FIELD.grow(-radius).has_point(at):
		return false
	for obstacle: Rect2 in obstacles:
		if obstacle.grow(radius).has_point(at):
			return false
	return true

func move_actor(at: Vector2, offset: Vector2, radius: float = 16.0) -> Vector2:
	var moved: Vector2 = at
	# 軸ごとに判定すると壁沿いの移動を止めず、低fps時も細分化で貫通を防げる。
	var steps: int = maxi(1, ceili(offset.length() / 8.0))
	for step: int in range(steps):
		var part: Vector2 = offset / float(steps)
		if can_stand(moved + Vector2(part.x, 0), radius):
			moved.x += part.x
		if can_stand(moved + Vector2(0, part.y), radius):
			moved.y += part.y
	return moved

func visible_between(from: Vector2, to: Vector2) -> bool:
	for obstacle: Rect2 in obstacles:
		for step: int in range(1, 17):
			if obstacle.has_point(from.lerp(to, float(step) / 16.0)):
				return false
	return true

func swing() -> void:
	if phase != Phase.PLAY or paused or attack_wait > 0.0:
		return
	attack_wait = interval
	attack_left = 0.17
	sound_requested.emit("swing")
	for foe: Foe in foes:
		var direction: Vector2 = foe.position - player
		if direction.length() < reach + (18.0 if foe.kind == 3 else 0.0) and facing.dot(direction.normalized()) > 0.05 and visible_between(player, foe.position):
			foe.health -= power
			foe.flash = 0.15
			foe.position = move_actor(foe.position, direction.normalized() * 24.0)
			sound_requested.emit("hit")
	remove_defeated()

func remove_defeated() -> void:
	for index: int in range(foes.size() - 1, -1, -1):
		if foes[index].health <= 0:
			shards += 12 if foes[index].kind == 3 else 2
			foes.remove_at(index)
	if foes.is_empty() and not clear:
		clear = true
		shots.clear()
		shards += 3
		health = mini(max_health, health + 1)
		sound_requested.emit("reward")

func dash(direction: Vector2) -> void:
	if phase != Phase.PLAY or paused or dash_wait > 0.0:
		return
	dash_direction = direction.normalized() if direction.length() > 0.1 else facing
	dash_left = 0.18
	dash_wait = 1.2
	invulnerable = maxf(invulnerable, 0.25)
	sound_requested.emit("dash")

func hurt(amount: int) -> void:
	if phase != Phase.PLAY or invulnerable > 0.0 or clear:
		return
	health = maxi(0, health - amount)
	invulnerable = 0.9
	sound_requested.emit("hurt")
	if health == 0:
		finish("灯が消えた", false)

func finish(message: String, safe: bool) -> void:
	# phaseを先に変更し、連続衝突や二重入力による持ち帰りの重複を防ぐ。
	if phase not in [Phase.PLAY, Phase.CHOICE]:
		return
	phase = Phase.RESULT
	paused = false
	collected = shards if safe else shards / 2
	bank += collected
	best = maxi(best, room if clear else room - 1)
	result = message
	save_progress()
	phase_changed.emit()

func interact() -> void:
	if phase != Phase.PLAY or paused or not clear or player.distance_to(EXIT) > 80:
		return
	if room == 6:
		finish("迷宮に朝が戻った", true)
		return
	choices.clear()
	while choices.size() < 3:
		var candidate: int = random.randi_range(0, BOONS.size() - 1)
		if not choices.has(candidate):
			choices.append(candidate)
	phase = Phase.CHOICE
	phase_changed.emit()

func choose(index: int) -> void:
	if phase != Phase.CHOICE or index < 0 or index >= choices.size():
		return
	var boon: int = choices[index]
	taken.append(BOONS[boon].name)
	match boon:
		0: power += 1
		1: speed += 24.0
		2:
			max_health += 2
			health = max_health
		3: reach += 20.0
		4: interval = maxf(0.18, interval * 0.8)
		5:
			health = mini(max_health, health + 4)
			shards += 5
	next_room()

func camp() -> void:
	phase = Phase.CAMP
	paused = false
	phase_changed.emit()

func fire(at: Vector2, direction: Vector2) -> void:
	var shot: Shot = Shot.new()
	shot.position = at
	shot.velocity = direction * 155.0
	shots.append(shot)

func advance(delta: float, movement: Vector2, aim: Vector2) -> void:
	if phase != Phase.PLAY or paused:
		return
	elapsed += delta
	attack_left = maxf(0, attack_left - delta)
	attack_wait = maxf(0, attack_wait - delta)
	dash_wait = maxf(0, dash_wait - delta)
	invulnerable = maxf(0, invulnerable - delta)
	if aim.length() > 0.1:
		facing = aim.normalized()
	player = move_actor(player, (dash_direction * 650.0 if dash_left > 0.0 else movement.limit_length() * speed) * delta)
	dash_left = maxf(0, dash_left - delta)
	for foe: Foe in foes:
		foe.timer -= delta
		foe.flash = maxf(0, foe.flash - delta)
		var toward: Vector2 = (player - foe.position).normalized()
		var pace: float = 66.0 + room * 4.0
		if foe.kind == 1:
			pace = 40.0 if foe.position.distance_to(player) > 280.0 else -24.0
			if foe.timer <= 0.0:
				fire(foe.position, toward)
				foe.timer = 2.2
		elif foe.kind == 2:
			if foe.timer > 0.55:
				foe.target = player
				pace = 38.0
			elif foe.timer > 0.0:
				pace = 0.0
			elif foe.timer > -0.4:
				toward = (foe.target - foe.position).normalized()
				pace = 300.0
			else:
				foe.timer = 1.8
		elif foe.kind == 3:
			pace = 42.0
			if foe.timer <= 0.0:
				for index: int in range(10):
					fire(foe.position, toward.rotated(float(index) * TAU / 10.0))
				foe.timer = 1.9 if foe.health < foe.maximum / 2 else 2.6
		# 接触時の重なりを避け、複数の敵を視認できるようにする。
		var separation: Vector2 = Vector2.ZERO
		for other: Foe in foes:
			if other != foe and foe.position.distance_to(other.position) < 44.0:
				separation += (foe.position - other.position).normalized() * 60.0
		foe.position = move_actor(foe.position, (toward * pace + separation) * delta)
		if foe.position.distance_to(player) < (42.0 if foe.kind == 3 else 29.0):
			hurt(2 if foe.kind == 3 else 1)
	for index: int in range(shots.size() - 1, -1, -1):
		var shot: Shot = shots[index]
		shot.position += shot.velocity * delta
		shot.life -= delta
		if shot.position.distance_to(player) < 22:
			hurt(1)
			shot.life = 0.0
		if shot.life <= 0.0 or not can_stand(shot.position, 4):
			shots.remove_at(index)
