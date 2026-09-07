extends Node2D
## 線画機体の状態とフレームを保持する。再生中のフレーム更新だけは非冪等。

const POSES: Array[String] = ["idle", "move", "attack", "hit", "death"]
const KINDS: Array[String] = ["player", "scout", "aim", "fan", "boss"]
const FRAME_COUNT: int = 4
const MAX_SEGMENTS: int = 10
const FRAME_RATES: Dictionary = {
	"idle": 6.0, "move": 12.0, "attack": 14.0, "hit": 18.0, "death": 8.0
}
const KIND_COLORS: Dictionary = {
	"player": Color("6dfff2"),
	"scout": Color("ff536f"),
	"aim": Color("ffd166"),
	"fan": Color("bd7cff"),
	"boss": Color("ff6a9d"),
}
const SCAN_SHADER: String = """shader_type canvas_item;
render_mode unshaded;
uniform float gain = 1.0;
uniform float phase = 0.0;
void fragment() {
    float scan = 0.84 + 0.16 * sin(TIME * 9.0 + UV.y * 31.0 + phase);
    COLOR = vec4(COLOR.rgb * gain * scan, COLOR.a);
}"""

var kind: String = ""
var animation: StringName = &"idle"
var frame: int = 0
var speed_scale: float = 1.0
var _playing: bool = true
var _frame_time: float = 0.0
var _lines: Array[Line2D] = []
var _shader: Shader


func _ready() -> void:
	_ensure_lines()
	_refresh_shape()


func _process(delta: float) -> void:
	if not _playing or kind.is_empty() or speed_scale <= 0.0:
		return
	_frame_time += delta * speed_scale
	var next_frame: int = int(_frame_time * float(FRAME_RATES[String(animation)]))
	if animation == &"death":
		next_frame = mini(next_frame, FRAME_COUNT - 1)
	else:
		next_frame %= FRAME_COUNT
	if next_frame != frame:
		frame = next_frame
		_refresh_shape()


func setup(next_kind: String) -> void:
	if next_kind not in KINDS:
		push_error("未対応の機体: " + next_kind)
		return
	if kind == next_kind:
		return
	kind = next_kind
	_ensure_lines()
	_refresh_shape()


func set_pose(pose: String) -> void:
	if pose not in POSES or animation == StringName(pose):
		return
	animation = StringName(pose)
	frame = 0
	_frame_time = 0.0
	_playing = true
	_refresh_shape()


func play(pose: String = "") -> void:
	if not pose.is_empty():
		set_pose(pose)
	_playing = true


func pause() -> void:
	_playing = false


func is_playing() -> bool:
	return _playing


func set_frame_and_progress(next_frame: int, _progress: float) -> void:
	frame = clampi(next_frame, 0, FRAME_COUNT - 1)
	_frame_time = float(frame) / float(FRAME_RATES[String(animation)])
	_refresh_shape()


func segment_count() -> int:
	return shape_segments(kind, String(animation), frame).size()


func line_count() -> int:
	return _lines.size()


func frame_signature() -> String:
	var signature: String = "%s/%s/%d" % [kind, animation, frame]
	for segment: PackedVector2Array in shape_segments(kind, String(animation), frame):
		for point: Vector2 in segment:
			signature += ":%.2f,%.2f" % [point.x, point.y]
	return signature


func _ensure_lines() -> void:
	if not _lines.is_empty():
		return
	_shader = Shader.new()
	_shader.code = SCAN_SHADER
	for segment_index: int in range(MAX_SEGMENTS):
		for layer_index: int in range(4):
			var line: Line2D = Line2D.new()
			line.antialiased = true
			line.width = [9.0, 1.2, 1.2, 2.2][layer_index]
			var material: ShaderMaterial = ShaderMaterial.new()
			material.shader = _shader
			material.set_shader_parameter("gain", 1.7 if layer_index == 0 else 1.12)
			material.set_shader_parameter("phase", float(segment_index) * 0.73)
			line.material = material
			add_child(line)
			_lines.append(line)


func _refresh_shape() -> void:
	if _lines.is_empty() or kind.is_empty():
		return
	var segments: Array[PackedVector2Array] = shape_segments(kind, String(animation), frame)
	var color: Color = KIND_COLORS[kind]
	for segment_index: int in range(MAX_SEGMENTS):
		for layer_index: int in range(4):
			var line: Line2D = _lines[segment_index * 4 + layer_index]
			if segment_index >= segments.size():
				line.clear_points()
				continue
			var offset: Vector2 = [
				Vector2.ZERO, Vector2(-1.7, 0.3), Vector2(1.7, -0.3), Vector2.ZERO
			][layer_index]
			line.points = _offset_points(segments[segment_index], offset)
			match layer_index:
				0:
					line.default_color = Color(color.r, color.g, color.b, 0.13)
				1:
					line.default_color = Color(1.0, 0.12, 0.38, 0.58)
				2:
					line.default_color = Color(0.12, 0.45, 1.0, 0.58)
				3:
					line.default_color = color


static func shape_segments(
	ship_kind: String, pose: String, frame_index: int
) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	match ship_kind:
		"player":
			result = [
				PackedVector2Array(
					[
						Vector2(0, -39),
						Vector2(-11, 9),
						Vector2(-6, 27),
						Vector2(0, 19),
						Vector2(6, 27),
						Vector2(11, 9),
						Vector2(0, -39)
					]
				),
				PackedVector2Array(
					[Vector2(-8, -3), Vector2(-36, 14), Vector2(-29, 29), Vector2(-8, 17)]
				),
				PackedVector2Array(
					[Vector2(8, -3), Vector2(36, 14), Vector2(29, 29), Vector2(8, 17)]
				),
				PackedVector2Array(
					[Vector2(-6, 3), Vector2(0, -5), Vector2(6, 3), Vector2(0, 13), Vector2(-6, 3)]
				),
				PackedVector2Array([Vector2(-7, 26), Vector2(-11, 39)]),
				PackedVector2Array([Vector2(7, 26), Vector2(11, 39)]),
			]
		"scout":
			result = [
				PackedVector2Array(
					[
						Vector2(0, 31),
						Vector2(-23, -22),
						Vector2(0, -11),
						Vector2(23, -22),
						Vector2(0, 31)
					]
				),
				PackedVector2Array([Vector2(-17, -14), Vector2(-31, -2), Vector2(-12, 7)]),
				PackedVector2Array([Vector2(17, -14), Vector2(31, -2), Vector2(12, 7)]),
				PackedVector2Array([Vector2(-5, -5), Vector2(0, 4), Vector2(5, -5)]),
			]
		"aim":
			result = [
				_circle_points(22.0, 24),
				_circle_points(9.0, 16),
				PackedVector2Array([Vector2(-33, 0), Vector2(-12, 0)]),
				PackedVector2Array([Vector2(12, 0), Vector2(33, 0)]),
				PackedVector2Array([Vector2(0, -33), Vector2(0, -12)]),
				PackedVector2Array([Vector2(0, 12), Vector2(0, 33)]),
			]
		"fan":
			result = [
				PackedVector2Array(
					[
						Vector2(0, 30),
						Vector2(-32, -17),
						Vector2(-11, -8),
						Vector2(0, -28),
						Vector2(11, -8),
						Vector2(32, -17),
						Vector2(0, 30)
					]
				),
				PackedVector2Array(
					[
						Vector2(-27, -14),
						Vector2(-17, 14),
						Vector2(0, 4),
						Vector2(17, 14),
						Vector2(27, -14)
					]
				),
				PackedVector2Array([Vector2(-8, -7), Vector2(0, 6), Vector2(8, -7)]),
			]
		"boss":
			result = [
				PackedVector2Array(
					[
						Vector2(-101, 19),
						Vector2(-80, -39),
						Vector2(-42, -52),
						Vector2(0, -31),
						Vector2(42, -52),
						Vector2(80, -39),
						Vector2(101, 19)
					]
				),
				PackedVector2Array(
					[
						Vector2(-101, 19),
						Vector2(-63, 11),
						Vector2(-45, 39),
						Vector2(0, 53),
						Vector2(45, 39),
						Vector2(63, 11),
						Vector2(101, 19)
					]
				),
				_circle_points(25.0, 24),
				_circle_points(10.0, 16),
				PackedVector2Array([Vector2(-74, -32), Vector2(-58, 19), Vector2(-42, -39)]),
				PackedVector2Array([Vector2(74, -32), Vector2(58, 19), Vector2(42, -39)]),
				PackedVector2Array([Vector2(-39, 38), Vector2(-29, 58)]),
				PackedVector2Array([Vector2(39, 38), Vector2(29, 58)]),
			]
	for index: int in range(result.size()):
		result[index] = _animate_segment(result[index], index, pose, frame_index)
	return result


static func _animate_segment(
	points: PackedVector2Array, segment_index: int, pose: String, frame_index: int
) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var phase: float = [0.0, 1.0, 0.35, -1.0][frame_index % FRAME_COUNT]
	var offset: Vector2 = Vector2(0, phase * 1.4)
	var rotation: float = 0.0
	var scale_factor: float = 1.0
	if pose == "move":
		offset = Vector2(phase * 2.1, -absf(phase) * 1.5)
		rotation = phase * 0.025
	elif pose == "attack":
		offset = Vector2(0, -float(frame_index) * 1.4 if segment_index % 2 == 0 else 0.0)
		scale_factor = 1.0 + 0.025 * float(frame_index)
	elif pose == "hit":
		offset = Vector2(phase * 4.5, -phase * 2.0)
		rotation = phase * 0.075
	elif pose == "death":
		offset = Vector2.from_angle(float(segment_index) * 2.17 - 1.1) * float(frame_index) * 8.0
		rotation = phase * 0.18 + float(segment_index % 3 - 1) * float(frame_index) * 0.055
		scale_factor = 1.0 - float(frame_index) * 0.12
	var transform: Transform2D = Transform2D(rotation, Vector2.ZERO).scaled(
		Vector2.ONE * scale_factor
	)
	for point: Vector2 in points:
		result.append(transform * point + offset)
	return result


static func _circle_points(radius: float, steps: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(steps + 1):
		points.append(Vector2.from_angle(float(index) * TAU / float(steps)) * radius)
	return points


static func _offset_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var shifted: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		shifted.append(point + offset)
	return shifted
