extends Node3D
## 露出面だけを 8 × 8 のチャンクへ束ね、描画と衝突を同じ形状から生成する。

const Data := preload("res://scripts/voxel_data.gd")
const CHUNK := 8
const NORMALS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)
]
const CORNERS := [
	[Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)],
	[Vector3(0, 0, 1), Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1)],
	[Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, 0)],
	[Vector3(1, 0, 1), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1)],
	[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)]
]
const COLORS := {
	1: Color("76ad62"), 2: Color("8f6346"), 3: Color("899396"), 4: Color("885032"),
	5: Color("478b5a"), 6: Color("dac28d"), 7: Color("3b91b9"), 8: Color("bd884f"),
	9: Color("c29761"), 10: Color("ffbd54"), 11: Color("789caa")
}

var data: RefCounted
var _material: StandardMaterial3D


func configure(world_data: RefCounted) -> void:
	data = world_data
	rebuild()


func rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if data == null:
		return
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.94
	for x: int in range(0, Data.SIZE.x, CHUNK):
		for z: int in range(0, Data.SIZE.z, CHUNK):
			_build_chunk(Vector2i(x, z))


func _build_chunk(start: Vector2i) -> void:
	var surface := SurfaceTool.new()
	var collision := PackedVector3Array()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 0
	for x: int in range(start.x, start.x + CHUNK):
		for z: int in range(start.y, start.y + CHUNK):
			for y: int in Data.SIZE.y:
				var cell := Vector3i(x, y, z)
				var id: int = data.get_block(cell)
				if id == Data.AIR:
					continue
				for side: int in 6:
					var neighbor: int = data.get_block(cell + NORMALS[side])
					if neighbor != Data.AIR and neighbor != Data.TORCH \
						and not (neighbor == Data.WATER and id != Data.WATER):
						continue
					_emit_face(surface, collision, cell, id, side)
					count += 1
	if count == 0:
		return
	var mesh: ArrayMesh = surface.commit()
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _material
	add_child(visual)
	if not collision.is_empty():
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var trimesh := ConcavePolygonShape3D.new()
		trimesh.set_faces(collision)
		shape.shape = trimesh
		body.add_child(shape)
		visual.add_child(body)


func _emit_face(surface: SurfaceTool, collision: PackedVector3Array,
		cell: Vector3i, id: int, side: int) -> void:
	var tint: Color = COLORS[id]
	var variation: float = float(posmod(cell.x * 19 + cell.z * 31 + cell.y * 7, 9)) * 0.012
	tint = tint.lightened(variation)
	if side != 2:
		tint = tint.darkened(0.12 if side < 2 else 0.22)
	if id == Data.GRASS and side != 2:
		tint = Color("98714f")
	for index: int in [0, 1, 2, 0, 2, 3]:
		var vertex: Vector3 = Vector3(cell) + CORNERS[side][index]
		if id == Data.WATER:
			vertex.y -= 0.18
		elif id == Data.TORCH:
			vertex = Vector3(cell) + CORNERS[side][index] * Vector3(0.16, 0.85, 0.16) \
				+ Vector3(0.42, 0, 0.42)
		surface.set_normal(Vector3(NORMALS[side]))
		surface.set_color(tint)
		surface.add_vertex(vertex)
		if data.is_solid(cell):
			collision.append(vertex)


func raycast(origin: Vector3, direction: Vector3, reach: float = 5.0) -> Dictionary:
	if data == null or direction.length_squared() < 0.0001 or reach <= 0:
		return {}
	var ray: Vector3 = direction.normalized()
	var cell := Vector3i(origin.floor())
	var previous: Vector3i = cell
	var increment := Vector3i(int(signf(ray.x)), int(signf(ray.y)), int(signf(ray.z)))
	var next_crossing := Vector3(INF, INF, INF)
	var interval := Vector3(INF, INF, INF)
	for axis: int in 3:
		if absf(ray[axis]) > 0.000001:
			interval[axis] = absf(1.0 / ray[axis])
			var boundary: float = float(cell[axis] + (1 if increment[axis] > 0 else 0))
			next_crossing[axis] = (boundary - origin[axis]) / ray[axis]
	var distance: float = 0
	while distance <= reach:
		var id: int = data.get_block(cell)
		if id not in [Data.AIR, Data.WATER]:
			return {"cell": cell, "previous": previous, "id": id}
		var axis: int = 0
		if next_crossing.y < next_crossing.x:
			axis = 1
		if next_crossing.z < next_crossing[axis]:
			axis = 2
		distance = next_crossing[axis]
		next_crossing[axis] += interval[axis]
		previous = cell
		cell[axis] += increment[axis]
	return {}
