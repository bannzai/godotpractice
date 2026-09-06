class_name KartCourse
extends RefCounted
## 描画と走行判定が共有する周回コース。

const LENGTH: float = 244.0
const ROAD_WIDTH: float = 12.0
const LAPS: int = 3
const CHECKPOINTS: Array[float] = [61.0, 122.0, 183.0, 244.0]
const ITEM_BOXES: Array[Dictionary] = [
	{"progress": 35.0, "lateral": -3.0},
	{"progress": 35.0, "lateral": 0.0},
	{"progress": 35.0, "lateral": 3.0},
	{"progress": 135.0, "lateral": -3.0},
	{"progress": 135.0, "lateral": 0.0},
	{"progress": 135.0, "lateral": 3.0},
]
const DASH_PADS: Array[Dictionary] = [
	{"progress": 80.0, "lateral": 2.5},
	{"progress": 205.0, "lateral": -2.5},
]
const SHORTCUT: Dictionary = {"start": 92.0, "end": 116.0, "lateral": -7.0, "width": 4.0}


static func sample(progress: float) -> Vector3:
	var angle: float = fposmod(progress, LENGTH) / LENGTH * TAU
	return Vector3(45.0 * cos(angle), 2.0 + 2.0 * sin(angle * 2.0), -32.0 * sin(angle))


static func tangent(progress: float) -> Vector3:
	return (sample(progress + 0.1) - sample(progress - 0.1)).normalized()


static func right(progress: float) -> Vector3:
	return tangent(progress).cross(Vector3.UP).normalized()


static func on_shortcut(progress: float, lateral: float) -> bool:
	var local: float = fposmod(progress, LENGTH)
	return (
		local >= SHORTCUT.start and local <= SHORTCUT.end
		and absf(lateral - SHORTCUT.lateral) <= SHORTCUT.width * 0.5
	)


static func has_wall(progress: float, lateral: float) -> bool:
	var local: float = fposmod(progress, LENGTH)
	if local > 146.0 and local < 176.0:
		return false
	if lateral < 0.0 and local >= SHORTCUT.start - 4.0 and local <= SHORTCUT.end + 4.0:
		return false
	return true
