class_name ShooterStageData
extends RefCounted
## ステージの出現時刻・機種と、敵の射撃パターンの定義。

const BOSS_TIME: float = 150.0
const BOSS_HP: int = 360


static func waves() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for group: int in range(30):
		for member: int in range(4):
			var kind: String = ["scout", "aim", "fan"][group % 3]
			var drop: String = ""
			if member == 2:
				drop = ["power", "score", "bomb", "score", "power"][group % 5]
			result.append({
				"time": 3.0 + group * 4.7 + member * 0.45,
				"x": 390.0 + member * 145.0 + sin(group * 1.7) * 40.0,
				"kind": kind,
				"drop": drop,
			})
	return result


static func enemy_stats(kind: String) -> Dictionary:
	match kind:
		"scout":
			return {"hp": 3, "speed": 110.0, "score": 120, "shot_interval": 2.2}
		"aim":
			return {"hp": 6, "speed": 75.0, "score": 240, "shot_interval": 2.0}
		"fan":
			return {"hp": 9, "speed": 85.0, "score": 360, "shot_interval": 2.8}
	return {}


static func bullet_velocities(
	pattern: String, origin: Vector2, target: Vector2, phase: int = 1
) -> Array[Vector2]:
	var result: Array[Vector2] = []
	match pattern:
		"straight":
			result.append(Vector2(0.0, 240.0))
		"aim":
			var direction: Vector2 = origin.direction_to(target)
			if direction.is_zero_approx():
				direction = Vector2.DOWN
			result.append(direction * 230.0)
		"fan":
			for angle: float in [-0.4, 0.0, 0.4]:
				result.append(Vector2.DOWN.rotated(angle) * 210.0)
		"boss":
			var count: int = 5 if phase == 1 else 7
			for index: int in range(count):
				var angle: float = lerpf(-0.72, 0.72, float(index) / (count - 1))
				result.append(Vector2.DOWN.rotated(angle) * (200.0 + phase * 25.0))
			if phase >= 2:
				result.append_array(bullet_velocities("aim", origin, target))
	return result


static func boss_phase(hp: int) -> int:
	return 1 if hp > BOSS_HP * 0.5 else 2
