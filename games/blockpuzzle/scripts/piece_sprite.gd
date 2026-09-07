class_name PieceSprite
extends Node2D
## 単色の正方形と円だけで構成するピース。動作は Tween で再生する。

const COLORS: Array[Color] = [
	Color("ff5d73"), Color("2ec4b6"), Color("ffca3a"), Color("7b61ff"), Color("70717a"),
]
const INK := Color("17171c")

var kind: int = 1
var _rig: Node2D
var _shapes: Node2D
var _pose_tween: Tween


func setup(piece_kind: int, side: float = 40.0) -> void:
	kind = clampi(piece_kind, 1, COLORS.size())
	if not is_instance_valid(_rig):
		_build()
	_rig.scale = Vector2.ONE * side / 128.0
	_build_kind()
	play_pose("idle")


## 操作への反応は毎回先頭から再生するため、同名でも再開する。
func play_pose(pose: String, delay: float = 0.0) -> void:
	if is_instance_valid(_pose_tween):
		_pose_tween.kill()
	var samples: Dictionary = _pose_samples(pose)
	_apply_sample(samples.start)
	_pose_tween = create_tween()
	if delay > 0.0:
		_pose_tween.tween_interval(delay)
	_tween_sample(samples.middle, samples.duration * 0.5)
	_tween_sample(samples.end, samples.duration * 0.5)
	if pose == "idle":
		_pose_tween.set_loops()
	else:
		_pose_tween.tween_callback(func() -> void: play_pose("idle"))


func seek_pose(pose: String, time: float) -> void:
	if is_instance_valid(_pose_tween):
		_pose_tween.kill()
	var samples: Dictionary = _pose_samples(pose)
	var progress: float = clampf(time / samples.duration, 0.0, 1.0)
	if progress <= 0.5:
		_apply_interpolated(samples.start, samples.middle, progress * 2.0)
	else:
		_apply_interpolated(samples.middle, samples.end, (progress - 0.5) * 2.0)


func pose_duration(pose: String) -> float:
	return float(_pose_samples(pose).duration)


func _build() -> void:
	_rig = Node2D.new()
	_rig.name = "Rig"
	add_child(_rig)
	_shapes = Node2D.new()
	_shapes.name = "Shapes"
	_rig.add_child(_shapes)


func _build_kind() -> void:
	for child: Node in _shapes.get_children():
		child.free()
	var color: Color = COLORS[kind - 1]
	match kind:
		1:
			_square(Vector2(100, 100), Vector2.ZERO, color)
			_circle(19.0, Vector2.ZERO, INK)
		2:
			_circle(52.0, Vector2.ZERO, color)
			_square(Vector2(30, 30), Vector2.ZERO, INK)
		3:
			var diamond: ColorRect = _square(Vector2(72, 72), Vector2.ZERO, color)
			diamond.rotation = PI * 0.25
			_circle(13.0, Vector2.ZERO, INK)
		4:
			_circle(52.0, Vector2.ZERO, color)
			_square(Vector2(74, 16), Vector2.ZERO, INK)
		5:
			_square(Vector2(100, 100), Vector2.ZERO, color)
			for point: Vector2 in [Vector2(-23, -23), Vector2(23, -23), Vector2(-23, 23), Vector2(23, 23)]:
				_circle(9.0, point, INK)


func _square(size: Vector2, point: Vector2, color: Color) -> ColorRect:
	var shape := ColorRect.new()
	shape.color = color
	shape.size = size
	shape.position = point - size * 0.5
	shape.pivot_offset = size * 0.5
	shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shapes.add_child(shape)
	return shape


func _circle(radius: float, point: Vector2, color: Color) -> Polygon2D:
	var shape := Polygon2D.new()
	var points := PackedVector2Array()
	for index: int in range(32):
		var angle: float = TAU * float(index) / 32.0
		points.append(point + Vector2(cos(angle), sin(angle)) * radius)
	shape.polygon = points
	shape.color = color
	_shapes.add_child(shape)
	return shape


func _pose_samples(pose: String) -> Dictionary:
	match pose:
		"move":
			return _samples(
				0.20,
				[Vector2.ONE, Vector2(0.82, 1.14), Vector2.ONE],
				[Vector2.ZERO, Vector2(0, -5), Vector2.ZERO],
				[0.0, -0.16, 0.0]
			)
		"land":
			return _samples(
				0.32,
				[Vector2(0.92, 1.08), Vector2(1.23, 0.76), Vector2.ONE],
				[Vector2(0, -8), Vector2(0, 10), Vector2.ZERO],
				[0.0, 0.04, 0.0]
			)
		"hurt":
			return _samples(
				0.30,
				[Vector2.ONE, Vector2(1.14, 0.86), Vector2.ONE],
				[Vector2(-5, 0), Vector2(6, 0), Vector2.ZERO],
				[-0.10, 0.10, 0.0],
				[Color.WHITE, Color("ff334f"), Color.WHITE]
			)
		"clear":
			return _samples(
				0.48,
				[Vector2.ONE, Vector2(1.25, 1.25), Vector2(0.12, 0.12)],
				[Vector2.ZERO, Vector2(0, -10), Vector2(0, -20)],
				[0.0, -0.13, 0.20],
				[Color.WHITE, Color(1.7, 1.7, 1.7), Color(1, 1, 1, 0)]
			)
		_:
			return _samples(
				1.80,
				[Vector2.ONE, Vector2(1.035, 0.965), Vector2.ONE],
				[Vector2.ZERO, Vector2(0, -3), Vector2.ZERO],
				[0.0, 0.025, 0.0]
			)


func _samples(
	duration: float,
	scales: Array,
	positions: Array,
	rotations: Array,
	colors: Array = [Color.WHITE, Color.WHITE, Color.WHITE]
) -> Dictionary:
	return {
		"duration": duration,
		"start": {
			"scale": scales[0],
			"position": positions[0],
			"rotation": rotations[0],
			"modulate": colors[0],
		},
		"middle": {
			"scale": scales[1],
			"position": positions[1],
			"rotation": rotations[1],
			"modulate": colors[1],
		},
		"end": {
			"scale": scales[2],
			"position": positions[2],
			"rotation": rotations[2],
			"modulate": colors[2],
		},
	}


func _tween_sample(sample: Dictionary, duration: float) -> void:
	_pose_tween.set_parallel(true)
	_pose_tween.tween_property(_shapes, "scale", sample.scale, duration).set_trans(
		Tween.TRANS_CUBIC
	)
	_pose_tween.tween_property(_shapes, "position", sample.position, duration).set_trans(
		Tween.TRANS_CUBIC
	)
	_pose_tween.tween_property(_shapes, "rotation", sample.rotation, duration).set_trans(
		Tween.TRANS_CUBIC
	)
	_pose_tween.tween_property(_shapes, "modulate", sample.modulate, duration)
	_pose_tween.set_parallel(false)


func _apply_sample(sample: Dictionary) -> void:
	_shapes.scale = sample.scale
	_shapes.position = sample.position
	_shapes.rotation = sample.rotation
	_shapes.modulate = sample.modulate


func _apply_interpolated(from: Dictionary, to: Dictionary, weight: float) -> void:
	_shapes.scale = from.scale.lerp(to.scale, weight)
	_shapes.position = from.position.lerp(to.position, weight)
	_shapes.rotation = lerpf(from.rotation, to.rotation, weight)
	_shapes.modulate = from.modulate.lerp(to.modulate, weight)
