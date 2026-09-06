class_name FighterRules
extends RefCounted
## 技の値は純粋関数で取得する。秒数は物理更新の実時間を使う。

const NORMALS: Dictionary = {
	"standing": {
		"lp": [45, 0.07, 0.12, 0.19, 94.0, -109.0, "mid"],
		"hp": [100, 0.16, 0.13, 0.36, 125.0, -113.0, "mid"],
		"lk": [55, 0.10, 0.12, 0.24, 119.0, -64.0, "mid"],
		"hk": [115, 0.21, 0.14, 0.43, 153.0, -105.0, "mid"],
	},
	"crouching": {
		"lp": [35, 0.06, 0.12, 0.18, 87.0, -61.0, "mid"],
		"hp": [95, 0.15, 0.13, 0.35, 97.0, -92.0, "mid"],
		"lk": [45, 0.08, 0.12, 0.23, 111.0, -22.0, "low"],
		"hk": [105, 0.22, 0.15, 0.44, 150.0, -22.0, "low"],
	},
	"air": {
		"lp": [45, 0.07, 0.13, 0.18, 88.0, -100.0, "overhead"],
		"hp": [95, 0.15, 0.14, 0.30, 117.0, -81.0, "overhead"],
		"lk": [60, 0.10, 0.13, 0.22, 126.0, -60.0, "overhead"],
		"hk": [110, 0.18, 0.15, 0.36, 148.0, -85.0, "overhead"],
	},
}


static func move(kind: String, stance: String, index: int) -> Dictionary:
	var values: Array = []
	if kind == "special":
		values = [110, 0.23, 0.12, 0.48, 120.0, -89.0, "mid"]
	elif NORMALS.has(stance) and NORMALS[stance].has(kind):
		values = NORMALS[stance][kind]
	else:
		return {}
	var power: float = 1.15 if index == 1 else 0.92
	var speed: float = 1.12 if index == 1 else 0.92
	return {
		"damage": roundi(float(values[0]) * power),
		"startup": float(values[1]) * speed,
		"active": float(values[2]),
		"whiff_recovery": float(values[3]) * speed,
		"hit_recovery": float(values[3]) * speed * 0.65,
		"guard_recovery": float(values[3]) * speed * 0.83,
		"reach": float(values[4]) * (1.10 if index == 1 else 1.0),
		"height": float(values[5]),
		"level": str(values[6]),
		"hitstun": 0.22 + float(values[0]) * 0.0015,
		"guardstun": 0.17 + float(values[0]) * 0.001,
		"knockback": 95.0 + float(values[0]) * 1.1,
		"hitstop": 0.055 if kind in ["lp", "lk"] else 0.09,
	}


static func blocks(level: String, crouch: bool, air: bool) -> bool:
	if air:
		return false
	return level == "mid" or (level == "low" and crouch) or (level == "overhead" and not crouch)
