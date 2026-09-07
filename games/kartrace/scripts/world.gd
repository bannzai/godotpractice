extends Node3D
## 同じコースデータから、頂点カラーの低ポリコースと80年代風の景観を構築する。

const Course = preload("res://scripts/course_data.gd")
const POTTA_FONT_PATH: String = "res://assets/fonts/PottaOne-Regular.ttf"
const CROWD_TEXTURE_PATH: String = "res://assets/pixel/crowd.png"
const RACING_SIGN_TEXTURE_PATH: String = "res://assets/pixel/racing_sign.png"

var boxes: Array[Node3D] = []
var clock: float = 0.0
var _scoreboard_rank: Label3D
var _scoreboard_lap: Label3D


func _ready() -> void:
	_build_environment()
	_build_track()
	_build_scenery()
	_build_arcade_dressing()
	_build_scoreboard()
	update_scoreboard(1, 1)


func _process(delta: float) -> void:
	# 時間に沿う浮遊と回転なのでフレームごとに進める。
	clock += delta
	for index: int in range(boxes.size()):
		boxes[index].visible = get_node("/root/RaceState").box_available(index)
		boxes[index].rotation.y = clock * 1.2
		boxes[index].position.y = Course.sample(Course.ITEM_BOXES[index].progress).y + 1.2
		boxes[index].position.y += sin(clock * 2.5 + index) * 0.2


## コース脇の電光掲示板を更新する。毎フレーム同じ値を渡しても表示結果は変わらない。
func update_scoreboard(rank: int, lap: int) -> void:
	var safe_rank: int = clampi(rank, 1, 4)
	var safe_lap: int = clampi(lap, 1, Course.LAPS)
	if is_instance_valid(_scoreboard_rank):
		_scoreboard_rank.text = "POSITION  %d / 4" % safe_rank
	if is_instance_valid(_scoreboard_lap):
		_scoreboard_lap.text = "LAP  %d / %d" % [safe_lap, Course.LAPS]


## プリミティブMeshを使う既存呼び出し向けの単色マテリアル。
## コース本体は box/cylinder 内でCOLOR属性を持つ専用マテリアルを使う。
static func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.68
	if glow:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = 0.85
	return result


## SurfaceTool.set_color() で Mesh.ARRAY_COLOR を実体として持つ低ポリ直方体を作る。
static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color,
		glow: bool = false) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = _vertex_colored_box_mesh(size, color)
	node.material_override = _vertex_color_material(color, glow)
	parent.add_child(node)
	node.position = pos
	return node


## SurfaceTool.set_color() で Mesh.ARRAY_COLOR を実体として持つ8角柱/円錐を作る。
static func cylinder(parent: Node3D, pos: Vector3, radius: float,
		height: float, color: Color, top: float = -1.0) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	var top_radius: float = radius if top < 0.0 else top
	node.mesh = _vertex_colored_cylinder_mesh(radius, top_radius, height, color, 8)
	node.material_override = _vertex_color_material(color)
	parent.add_child(node)
	node.position = pos
	return node


static func _vertex_color_material(color: Color,
		glow: bool = false) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	# 色そのものはメッシュのCOLOR属性に置き、albedoは白で乗算する。
	result.albedo_color = Color.WHITE
	result.vertex_color_use_as_albedo = true
	result.vertex_color_is_srgb = true
	result.roughness = 0.78
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = 0.65
	return result


static func _vertex_colored_box_mesh(size: Vector3, color: Color) -> ArrayMesh:
	var half: Vector3 = size * 0.5
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_quad(tool,
		Vector3(-half.x, -half.y, -half.z), Vector3(half.x, -half.y, -half.z),
		Vector3(half.x, half.y, -half.z), Vector3(-half.x, half.y, -half.z),
		color.lightened(0.08))
	_add_quad(tool,
		Vector3(half.x, -half.y, half.z), Vector3(-half.x, -half.y, half.z),
		Vector3(-half.x, half.y, half.z), Vector3(half.x, half.y, half.z),
		color.darkened(0.08))
	_add_quad(tool,
		Vector3(-half.x, -half.y, half.z), Vector3(-half.x, -half.y, -half.z),
		Vector3(-half.x, half.y, -half.z), Vector3(-half.x, half.y, half.z),
		color.darkened(0.18))
	_add_quad(tool,
		Vector3(half.x, -half.y, -half.z), Vector3(half.x, -half.y, half.z),
		Vector3(half.x, half.y, half.z), Vector3(half.x, half.y, -half.z),
		color.darkened(0.11))
	_add_quad(tool,
		Vector3(-half.x, half.y, -half.z), Vector3(half.x, half.y, -half.z),
		Vector3(half.x, half.y, half.z), Vector3(-half.x, half.y, half.z),
		color.lightened(0.18))
	_add_quad(tool,
		Vector3(-half.x, -half.y, half.z), Vector3(half.x, -half.y, half.z),
		Vector3(half.x, -half.y, -half.z), Vector3(-half.x, -half.y, -half.z),
		color.darkened(0.24))
	var mesh: ArrayMesh = tool.commit()
	mesh.resource_name = "VertexColorBox"
	return mesh


static func _vertex_colored_cylinder_mesh(bottom_radius: float, top_radius: float,
		height: float, color: Color, segments: int) -> ArrayMesh:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_height: float = height * 0.5
	for index: int in range(segments):
		var angle_a: float = float(index) / segments * TAU
		var angle_b: float = float(index + 1) / segments * TAU
		var bottom_a := Vector3(cos(angle_a) * bottom_radius, -half_height,
			sin(angle_a) * bottom_radius)
		var bottom_b := Vector3(cos(angle_b) * bottom_radius, -half_height,
			sin(angle_b) * bottom_radius)
		var top_a := Vector3(cos(angle_a) * top_radius, half_height,
			sin(angle_a) * top_radius)
		var top_b := Vector3(cos(angle_b) * top_radius, half_height,
			sin(angle_b) * top_radius)
		var facet_color: Color = color.lightened(0.06) if index % 2 == 0 else color.darkened(0.13)
		if is_zero_approx(top_radius):
			_add_triangle(tool, bottom_a, bottom_b, Vector3(0, half_height, 0), facet_color)
		else:
			_add_quad(tool, bottom_a, bottom_b, top_b, top_a, facet_color)
		_add_triangle(tool, Vector3(0, -half_height, 0), bottom_b, bottom_a,
			color.darkened(0.22))
		if not is_zero_approx(top_radius):
			_add_triangle(tool, Vector3(0, half_height, 0), top_a, top_b,
				color.lightened(0.16))
	var mesh: ArrayMesh = tool.commit()
	mesh.resource_name = "VertexColorLowPolyCylinder"
	return mesh


static func _add_quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		d: Vector3, color: Color) -> void:
	_add_triangle(tool, a, b, c, color)
	_add_triangle(tool, a, c, d, color)


static func _add_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		color: Color) -> void:
	var normal: Vector3 = (b - a).cross(c - a).normalized()
	for vertex: Vector3 in [a, b, c]:
		tool.set_color(color)
		tool.set_normal(normal)
		tool.add_vertex(vertex)


func _build_environment() -> void:
	var environment: WorldEnvironment = WorldEnvironment.new()
	var settings: Environment = Environment.new()
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	# 紫の天頂から桃色、橙の地平線へ落ちるアーケード筐体風の空。
	sky_material.sky_top_color = Color("211050")
	sky_material.sky_horizon_color = Color("ff3b83")
	sky_material.ground_horizon_color = Color("ff8a38")
	sky_material.ground_bottom_color = Color("101440")
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	settings.background_mode = Environment.BG_SKY
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("ffb0d8")
	settings.ambient_light_energy = 0.42
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color("fff07a")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110.0
	add_child(sun)
	box(self, Vector3(0, -3.6, 0), Vector3(900, 0.4, 900), Color("0955d9"))
	# 遠景を単純な反復シルエットにして、走行時の拡大縮小を強く見せる。
	for index: int in range(25):
		var angle: float = index * TAU / 25.0
		var pos: Vector3 = Vector3(cos(angle) * 240, -1, sin(angle) * 240)
		cylinder(self, pos, 30, 20 + index % 4 * 7,
			Color("5e2ca5") if index % 2 == 0 else Color("0f37a8"), 3)
		box(self, pos + Vector3(0, 60 + index % 3 * 5, 0),
			Vector3(25 + index % 3 * 10, 3, 9),
			Color("ffb6db") if index % 2 == 0 else Color("64f5ff"))
	var sunset: MeshInstance3D = cylinder(
		self, Vector3(-76, 42, -155), 21, 0.45, Color("ffe600"))
	sunset.rotation.x = PI / 2.0


func _build_track() -> void:
	for index: int in range(160):
		var distance: float = float(index) / 160 * Course.LENGTH
		var point: Vector3 = Course.sample(distance)
		var next: Vector3 = Course.sample(distance + Course.LENGTH / 160)
		var tangent: Vector3 = (next - point).normalized()
		var right: Vector3 = tangent.cross(Vector3.UP).normalized()
		var middle: Vector3 = (point + next) * 0.5
		var road: MeshInstance3D = box(self, middle - Vector3(0, 0.25, 0),
			Vector3(Course.ROAD_WIDTH, 0.5, point.distance_to(next) + 0.15),
			Color("1a1747"))
		road.look_at(middle + tangent)
		for side: float in [-1.0, 1.0]:
			var color: Color = Color("ffe600") if index % 4 < 2 else Color("ff247f")
			var curb: MeshInstance3D = box(self, middle + right * side * 5.8,
				Vector3(0.5, 0.12, point.distance_to(next) + 0.15), color)
			curb.look_at(curb.position + tangent)
			# 開いた区間では海へ落ちる。安全柵がカメラを遮らない高さにする。
			if Course.has_wall(distance, side):
				var rail: MeshInstance3D = box(self,
					middle + right * side * 6.3 + Vector3.UP * 0.4,
					Vector3(0.25, 0.7, point.distance_to(next) + 0.15), Color("00eaff"))
				rail.look_at(rail.position + tangent)
		if index % 4 == 0:
			var mark: MeshInstance3D = box(self, middle + Vector3.UP * 0.015,
				Vector3(0.12, 0.03, 1.0), Color("fff45c"))
			mark.look_at(mark.position + tangent)
	for placement: Dictionary in Course.ITEM_BOXES:
		var cube: Node3D = Node3D.new()
		add_child(cube)
		cube.position = point_at(placement.progress, placement.lateral) + Vector3.UP * 1.2
		var gem: MeshInstance3D = box(
			cube, Vector3.ZERO, Vector3.ONE * 1.2, Color("ffe600"), true)
		gem.rotation_degrees = Vector3(15, 0, 20)
		box(cube, Vector3(0, 0, -0.64), Vector3(0.65, 0.65, 0.06), Color("ff3c8f"), true)
		boxes.append(cube)
	for placement: Dictionary in Course.DASH_PADS:
		var pad: Node3D = Node3D.new()
		add_child(pad)
		pad.position = point_at(placement.progress, placement.lateral) + Vector3.UP * 0.03
		pad.look_at(pad.position + Course.tangent(placement.progress))
		box(pad, Vector3.ZERO, Vector3(3, 0.06, 4), Color("00dfff"), true)
		for stripe: int in range(3):
			box(pad, Vector3(0, 0.055, -1.2 + stripe * 1.1),
				Vector3(2.5, 0.04, 0.35), Color("ffe600"), true)
	_build_shortcut()
	var gate: Node3D = Node3D.new()
	add_child(gate)
	gate.position = Course.sample(0)
	gate.look_at(gate.position + Course.tangent(0))
	for side: float in [-1.0, 1.0]:
		box(gate, Vector3(side * 6.8, 3, 0), Vector3(0.6, 6, 0.7), Color("ff3c8f"))
	box(gate, Vector3(0, 6, 0), Vector3(14.2, 1.6, 0.8), Color("17206b"))
	var sign: Label3D = Label3D.new()
	sign.text = "潮 風 カ ー ト"
	sign.font_size = 72
	sign.pixel_size = 0.015
	sign.outline_size = 8
	sign.modulate = Color("ffe600")
	_set_arcade_font(sign)
	sign.position = Vector3(0, 6, 0.44)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gate.add_child(sign)
	for row: int in range(2):
		for col: int in range(12):
			box(gate, Vector3(col - 5.5, 0.04, row - 0.5), Vector3(1, 0.04, 1),
				Color("ffe600") if (row + col) % 2 == 0 else Color("ff247f"))


func _build_shortcut() -> void:
	var data: Dictionary = Course.SHORTCUT
	for index: int in range(30):
		var distance: float = lerpf(data.start, data.end, index / 29.0)
		var point: Vector3 = point_at(distance, data.lateral)
		var plank: MeshInstance3D = box(self, point - Vector3.UP * 0.1,
			Vector3(data.width, 0.2, 1.6),
			Color("ff9b24") if index % 2 == 0 else Color("ffe04d"))
		plank.look_at(point + Course.tangent(distance))


static func point_at(distance: float, lateral: float) -> Vector3:
	return Course.sample(distance) + Course.right(distance) * lateral


func _build_scenery() -> void:
	cylinder(self, Vector3(0, -2.5, 0), 27, 3, Color("ffe14d"))
	cylinder(self, Vector3(0, -0.9, 0), 23, 0.3, Color("16d989"))
	for index: int in range(22):
		var angle: float = index * 2.399
		var radius: float = 10 + index % 4 * 3
		var pos: Vector3 = Vector3(cos(angle) * radius, -0.7, sin(angle) * radius)
		_palm(pos, 0.8 + (index % 3) * 0.2)
	cylinder(self, Vector3(1, 5.2, 0), 2.4, 12, Color("fff072"), 1.6)
	for stripe: int in range(3):
		cylinder(self, Vector3(1, 1.5 + stripe * 3.5, 0), 2.2 - stripe * 0.2,
			1.1, Color("ff245f"))
	cylinder(self, Vector3(1, 11.8, 0), 2.5, 0.5, Color("17206b"))
	cylinder(self, Vector3(1, 13, 0), 1.4, 2, Color("00eaff"))
	cylinder(self, Vector3(1, 14.6, 0), 2.5, 1.8, Color("ff247f"), 0)
	for index: int in range(16):
		var pos: Vector3 = Vector3(-100 + index * 14, -3.3, -75 - index % 3 * 15)
		box(self, pos, Vector3(8, 0.03, 0.18),
			Color("00eaff") if index % 2 == 0 else Color("ff247f"), true)


func _build_arcade_dressing() -> void:
	_build_pixel_crowds()
	_build_neon_signs()


func _build_pixel_crowds() -> void:
	var crowd_texture: Texture2D = _load_optional_texture(CROWD_TEXTURE_PATH)
	if crowd_texture == null:
		return
	for index: int in range(18):
		var distance: float = 14.0 + index * 12.2
		var side: float = -1.0 if index % 3 != 0 else 1.0
		var sprite: Sprite3D = Sprite3D.new()
		sprite.texture = crowd_texture
		# CC0素材は4×4のシート。看板を掲げる先頭行を観客として切り出す。
		var cell_size := Vector2i(
			crowd_texture.get_width() / 4, crowd_texture.get_height() / 4)
		sprite.region_enabled = true
		sprite.region_rect = Rect2(
			Vector2(cell_size.x * (index % 4), 0), Vector2(cell_size))
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.shaded = false
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		# fixed_sizeを使わず、追従カメラの遠近でドット絵が拡大縮小する。
		sprite.pixel_size = 0.026
		sprite.scale = Vector3.ONE * (0.95 + float(index % 4) * 0.08)
		sprite.position = point_at(distance, side * 8.7) + Vector3.UP * 1.65
		add_child(sprite)


func _build_neon_signs() -> void:
	var sign_texture: Texture2D = _load_optional_texture(RACING_SIGN_TEXTURE_PATH)
	var captions: Array[String] = ["TURBO!", "GO!", "NEON CUP", "MAX SPEED"]
	var colors: Array[Color] = [Color("ff247f"), Color("ffe600"), Color("00eaff"), Color("8d38ff")]
	for index: int in range(8):
		var distance: float = 24.0 + index * 27.0
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var sign_root: Node3D = Node3D.new()
		add_child(sign_root)
		sign_root.position = point_at(distance, side * 10.2) + Vector3.UP * 2.8
		sign_root.look_at(Course.sample(distance) + Vector3.UP * 2.2, Vector3.UP)
		box(sign_root, Vector3.ZERO, Vector3(5.8, 2.7, 0.24), colors[index % colors.size()], true)
		for post_x: float in [-2.1, 2.1]:
			box(sign_root, Vector3(post_x, -2.25, 0.1), Vector3(0.22, 2.6, 0.22), Color("15143f"))
		if sign_texture != null:
			var sprite: Sprite3D = Sprite3D.new()
			sprite.texture = sign_texture
			sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			sprite.shaded = false
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sprite.pixel_size = 0.018
			sprite.position = Vector3(0, 0, -0.18)
			sign_root.add_child(sprite)
		else:
			var label: Label3D = _arcade_label(captions[index % captions.size()], 46, Color("10143b"))
			label.position = Vector3(0, 0, -0.2)
			sign_root.add_child(label)


func _build_scoreboard() -> void:
	# スタート直後の追従カメラを塞がず、最初のアイテム箱の先で順位を読める位置。
	var distance: float = 42.0
	var scoreboard: Node3D = Node3D.new()
	add_child(scoreboard)
	scoreboard.position = point_at(distance, -9.6) + Vector3.UP * 3.2
	scoreboard.look_at(Course.sample(distance) + Vector3.UP * 2.8, Vector3.UP)
	box(scoreboard, Vector3.ZERO, Vector3(6.8, 3.4, 0.4), Color("10112e"))
	box(scoreboard, Vector3(0, 0, -0.24), Vector3(6.2, 2.8, 0.1), Color("25165f"))
	for side: float in [-1.0, 1.0]:
		box(scoreboard, Vector3(side * 2.7, -3.05, 0.18),
			Vector3(0.28, 4.4, 0.28), Color("00dfff"))
	for column: int in range(8):
		for row: int in range(2):
			box(scoreboard, Vector3(-3.0 + column * 0.86, -1.55 + row * 3.1, -0.3),
				Vector3(0.18, 0.18, 0.07),
				Color("ffe600") if column % 2 == 0 else Color("ff247f"), true)
	_scoreboard_rank = _arcade_label("", 42, Color("ffe600"))
	_scoreboard_rank.pixel_size = 0.009
	_scoreboard_rank.position = Vector3(0, 0.55, -0.34)
	scoreboard.add_child(_scoreboard_rank)
	_scoreboard_lap = _arcade_label("", 36, Color("00eaff"))
	_scoreboard_lap.pixel_size = 0.011
	_scoreboard_lap.position = Vector3(0, -0.55, -0.34)
	scoreboard.add_child(_scoreboard_lap)


func _arcade_label(text: String, size: int, color: Color) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.018
	label.modulate = color
	label.outline_modulate = Color("100c2b")
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_set_arcade_font(label)
	return label


func _set_arcade_font(label: Label3D) -> void:
	if ResourceLoader.exists(POTTA_FONT_PATH):
		label.font = load(POTTA_FONT_PATH)


func _load_optional_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var resource: Resource = load(path)
	return resource as Texture2D


func _palm(pos: Vector3, size: float) -> void:
	var trunk: MeshInstance3D = cylinder(self, pos + Vector3.UP * 2.5 * size,
		0.35 * size, 5 * size, Color("ff7b25"), 0.2 * size)
	trunk.rotation.z = 0.1
	for leaf: int in range(5):
		var angle: float = leaf * TAU / 5
		var mesh: MeshInstance3D = box(self,
			pos + Vector3(cos(angle), 4.8, sin(angle)) * size,
			Vector3(0.85, 0.13, 3.7) * size,
			Color("00d77c") if leaf % 2 == 0 else Color("00aef0"))
		mesh.rotation = Vector3(0.3, -angle + PI / 2, 0)
