extends Node3D
## 海、遠い岩島、ゆっくり流れる雲を異なる距離に重ねた空の風景。

const ORIGAMI_PAPER := preload("res://assets/textures/origami-paper.png")
const CONSTRUCTION_PAPER := preload("res://assets/textures/construction-paper-sky.png")

var _environment: Environment
var _sky: PanoramaSkyMaterial
var _sun: DirectionalLight3D
var _clouds: Node3D
var _cloud_material: StandardMaterial3D
var _sea_material: StandardMaterial3D
var _moon: MeshInstance3D


func configure() -> void:
	if _environment != null:
		return
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_sky = PanoramaSkyMaterial.new()
	_sky.panorama = CONSTRUCTION_PAPER
	var sky_resource: Sky = Sky.new()
	sky_resource.sky_material = _sky
	_environment.sky = sky_resource
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = _environment
	add_child(world_environment)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 60.0
	add_child(_sun)
	_cloud_material = _material(Color("fff6d9"), ORIGAMI_PAPER)
	_sea_material = _material(Color("4ba8b1"), CONSTRUCTION_PAPER)
	var sea: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(440.0, 440.0)
	sea.mesh = plane
	sea.material_override = _sea_material
	sea.position = Vector3(16.0, -0.9, 16.0)
	add_child(sea)
	_clouds = Node3D.new()
	add_child(_clouds)
	_build_horizon()
	_moon = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 3.2
	sphere.height = 6.4
	_moon.mesh = sphere
	var moon_material: StandardMaterial3D = _material(Color("d1f2ed"))
	moon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_moon.material_override = moon_material
	_moon.position = Vector3(-68.0, 62.0, -110.0)
	add_child(_moon)
	sync(40.0, 180.0)


func sync(day_time: float, day_length: float) -> void:
	if _environment == null:
		configure()
	var phase: float = fposmod(day_time / maxf(day_length, 1.0), 1.0)
	# 生存ロジックの夜 (0.68〜翌0.16) に空の暗さを合わせる。
	var daylight: float = smoothstep(0.12, 0.21, phase) * (1.0 - smoothstep(0.61, 0.71, phase))
	var sunset: float = (1.0 - absf(daylight * 2.0 - 1.0)) * 0.65
	_sky.energy_multiplier = 0.27 + daylight * 0.73 + sunset * 0.08
	_environment.ambient_light_color = Color("859fce").lerp(Color("fff1d8"), daylight)
	_environment.ambient_light_energy = 0.45 + daylight * 0.3
	_sun.rotation_degrees = Vector3(-(phase - 0.16) * 346.0, -35.0, 0.0)
	_sun.light_color = Color("abb8e7").lerp(Color("ffe4b2"), daylight)
	_sun.light_energy = 0.18 + daylight * 0.95
	_cloud_material.albedo_color = Color("556284").lerp(Color("fff6de"), daylight)
	_sea_material.albedo_color = Color("172e4e").lerp(Color("398aa2"), daylight)
	_clouds.position.x = sin(phase * TAU) * 8.0
	_moon.visible = daylight < 0.65


func _build_horizon() -> void:
	var rock_material: StandardMaterial3D = _material(Color("6d8991"), ORIGAMI_PAPER)
	var distant_material: StandardMaterial3D = _material(Color("82979d"), ORIGAMI_PAPER)
	for index: int in range(18):
		var angle: float = float(index) * TAU / 18.0
		var distance: float = 62.0 + float(index % 3) * 25.0
		var island: MeshInstance3D = MeshInstance3D.new()
		var rock: CylinderMesh = CylinderMesh.new()
		rock.top_radius = 2.0 + float(index % 3)
		rock.bottom_radius = 10.0 + float(index % 5)
		rock.height = 12.0 + float(index % 4) * 3.0
		rock.radial_segments = 5
		island.mesh = rock
		island.material_override = rock_material if index % 2 == 0 else distant_material
		island.position = Vector3(16.0 + cos(angle) * distance, 1.0, 16.0 + sin(angle) * distance)
		island.rotation.y = angle
		add_child(island)
	for index: int in range(14):
		var angle: float = float(index) * TAU / 14.0
		for part: int in range(3):
			var cloud: MeshInstance3D = MeshInstance3D.new()
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(10.0 + part * 2.0, 1.4 + part * 0.5, 5.0 + part)
			cloud.mesh = box
			cloud.material_override = _cloud_material
			cloud.position = Vector3(
				16.0 + cos(angle) * 70.0 + part * 6.0,
				28.0 + float(index % 3) * 6.0 + part * 0.5,
				16.0 + sin(angle) * 70.0
			)
			_clouds.add_child(cloud)


func _material(color: Color, texture: Texture2D = null) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_texture = texture
	material.roughness = 1.0
	return material
