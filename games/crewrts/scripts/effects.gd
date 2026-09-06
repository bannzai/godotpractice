extends Node3D
## 表示前後の差分を短い演出へ変換する。ゲームの人数・HP・報酬は変更しない。

signal hit_presented

const GOLD := Color("f4c66c")
const TEAL := Color("76d6bb")
const CORAL := Color("f18d70")

var font: Font
var _previous_hp: Array[float] = []
var _pending_damage: Array[float] = []
var _previous_crew: Dictionary = {}
var _damage_timer: float = 0.0
var _shake: float = 0.0
var _elapsed: float = 0.0


func reset(model: Node) -> void:
	_previous_hp.clear()
	_pending_damage.clear()
	_previous_crew.clear()
	_damage_timer = 0.0
	_shake = 0.0
	for enemy: Dictionary in model.enemies:
		_previous_hp.append(float(enemy.hp))
		_pending_damage.append(0.0)
	for member: Dictionary in model.crew:
		_previous_crew[member.id] = member.position
	for child: Node in get_children():
		child.queue_free()


func set_paused(paused: bool) -> void:
	process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	for child: Node in get_children():
		if child is CPUParticles3D:
			child.speed_scale = 0.0 if paused else 1.0


## 表示の経過時間とダメージ表示を積算するため非冪等。
func sync(model: Node, delta: float, camera: Camera3D) -> void:
	_elapsed += delta
	_damage_timer += delta
	_shake = move_toward(_shake, 0.0, delta * 1.4)
	camera.h_offset = sin(_elapsed * 83.0) * _shake
	camera.v_offset = cos(_elapsed * 67.0) * _shake * 0.65
	for index: int in range(mini(model.enemies.size(), _previous_hp.size())):
		var enemy: Dictionary = model.enemies[index]
		var damage: float = _previous_hp[index] - float(enemy.hp)
		if damage > 0.0:
			_pending_damage[index] += damage
			if enemy.hp <= 0.0:
				burst(enemy.position + Vector3.UP, GOLD, 34, 1.15)
				ring(enemy.position, GOLD, 3.0)
				popup("撃破", enemy.position + Vector3.UP * 2.3, GOLD)
				_pending_damage[index] = 0.0
				_shake = maxf(_shake, 0.18)
		_previous_hp[index] = float(enemy.hp)
		if _damage_timer >= 0.28 and _pending_damage[index] > 0.0:
			burst(enemy.position + Vector3.UP, CORAL, 8, 0.4)
			popup("−%.1f" % _pending_damage[index], enemy.position + Vector3.UP * 3.2, GOLD)
			hit_presented.emit()
			_pending_damage[index] = 0.0
	if _damage_timer >= 0.28:
		_damage_timer = 0.0
	var living: Dictionary = {}
	for member: Dictionary in model.crew:
		living[member.id] = member.position
	for identity: int in _previous_crew:
		if not living.has(identity):
			burst(_previous_crew[identity] + Vector3.UP * 0.6, CORAL, 14, 0.7)
			popup("−1", _previous_crew[identity] + Vector3.UP * 3.6, CORAL)
	_previous_crew = living


## 一度消費された操作イベントにつき、新しい演出を生成するため非冪等。
func notify_event(event: String, model: Node) -> void:
	match event:
		"whistle":
			burst(model.leader + Vector3.UP * 1.4, TEAL, 12, 0.7)
			ring(model.leader, TEAL, 10.8)
		"throw":
			burst(model.leader + Vector3.UP * 1.3, GOLD, 6, 0.28)
		"delivery":
			burst(model.base_position + Vector3.UP * 2.4, GOLD, 40, 1.4)
			ring(model.base_position, TEAL, 4.0)
			popup("回収 +1　仲間 +3", model.base_position + Vector3.UP * 5.8, GOLD)
		"lost":
			_shake = maxf(_shake, 0.1)


## 発生地点ごとに独立した短命ノードを生成するため非冪等。
func burst(point: Vector3, color: Color, amount: int, duration: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.position = point
	particles.emitting = false
	particles.amount = amount
	particles.lifetime = duration
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 95.0
	particles.initial_velocity_min = 1.4
	particles.initial_velocity_max = 4.0
	particles.gravity = Vector3(0, -4.0, 0)
	particles.scale_amount_min = 0.06
	particles.scale_amount_max = 0.15
	particles.angular_velocity_min = -160
	particles.angular_velocity_max = 160
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	mesh.material = material
	particles.mesh = mesh
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(0.65, 0.8))
	curve.add_point(Vector2(1, 0))
	particles.scale_amount_curve = curve
	add_child(particles)
	particles.finished.connect(particles.queue_free)
	particles.emitting = true
	return particles


## Tween 完了時に表示資源を解放する、一回限りの波紋。
func ring(point: Vector3, color: Color, radius: float) -> void:
	var instance := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.92
	mesh.outer_radius = 1.0
	mesh.rings = 32
	mesh.ring_segments = 4
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	instance.material_override = material
	instance.position = point + Vector3.UP * 0.18
	instance.scale = Vector3.ONE * 0.2
	add_child(instance)
	var tween: Tween = instance.create_tween().set_parallel(true)
	tween.tween_property(instance, "scale", Vector3(radius, 0.22, radius), 0.65) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.65)
	tween.chain().tween_callback(instance.queue_free)


## 同時に起きたダメージを重ねて読めるよう、短時間で上へ退避させる。
func popup(text: String, point: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.font = font
	label.text = text
	label.font_size = 44
	label.pixel_size = 0.013
	label.position = point
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = color
	label.outline_modulate = Color("183e39")
	label.outline_size = 6
	add_child(label)
	label.scale = Vector3.ONE * 0.4
	var tween: Tween = label.create_tween()
	tween.tween_property(label, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(label, "position:y", point.y + 1.0, 0.85)
	tween.tween_property(label, "modulate:a", 0.0, 0.22)
	tween.tween_callback(label.queue_free)
