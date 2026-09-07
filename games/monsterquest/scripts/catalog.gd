class_name Catalog
extends RefCounted
## モンスターと技の定義。保存する個体は種族・レベル・経験値・現在 HP のみを持つ。

const TYPES: Dictionary = {"fire": "炎", "water": "水", "leaf": "草"}
const MOVES: Dictionary = {
	"spark": {"name": "火のこ", "type": "fire", "power": 24},
	"flare": {"name": "炎の輪", "type": "fire", "power": 38},
	"sun": {"name": "朝日の息", "type": "fire", "power": 52},
	"drop": {"name": "水しぶき", "type": "water", "power": 24},
	"wave": {"name": "うずしお", "type": "water", "power": 38},
	"rain": {"name": "雨の矢", "type": "water", "power": 52},
	"seed": {"name": "種はじき", "type": "leaf", "power": 24},
	"vine": {"name": "つるの舞", "type": "leaf", "power": 38},
	"bloom": {"name": "花吹雪", "type": "leaf", "power": 52},
}
const SPECIES: Dictionary = {
	"ember": {
		"name": "コハネ", "type": "fire", "hp": 27, "attack": 15, "defense": 12,
		"speed": 16, "image": "res://assets/pixel/characters/ember.png",
		"learn": [[1, "spark"], [6, "seed"], [8, "flare"], [11, "wave"], [14, "sun"]],
	},
	"tide": {
		"name": "シズモ", "type": "water", "hp": 31, "attack": 13, "defense": 15,
		"speed": 11, "image": "res://assets/pixel/characters/tide.png",
		"learn": [[1, "drop"], [6, "spark"], [8, "wave"], [11, "vine"], [14, "rain"]],
	},
	"sprout": {
		"name": "ネムリネ", "type": "leaf", "hp": 33, "attack": 14, "defense": 14,
		"speed": 10, "image": "res://assets/pixel/characters/sprout.png",
		"learn": [[1, "seed"], [6, "drop"], [8, "vine"], [11, "flare"], [14, "bloom"]],
	},
	"moth": {
		"name": "ヒノコガ", "type": "fire", "hp": 24, "attack": 16, "defense": 10,
		"speed": 20, "image": "res://assets/pixel/characters/moth.png",
		"learn": [[1, "spark"], [5, "seed"], [8, "flare"], [11, "wave"], [14, "sun"]],
	},
	"crab": {
		"name": "アワガニ", "type": "water", "hp": 29, "attack": 16, "defense": 18,
		"speed": 8, "image": "res://assets/pixel/characters/crab.png",
		"learn": [[1, "drop"], [5, "spark"], [8, "wave"], [11, "vine"], [14, "rain"]],
	},
	"owl": {
		"name": "モリフク", "type": "leaf", "hp": 28, "attack": 15, "defense": 12,
		"speed": 17, "image": "res://assets/pixel/characters/owl.png",
		"learn": [[1, "seed"], [5, "drop"], [8, "vine"], [11, "flare"], [14, "bloom"]],
	},
}
const MAX_LEVEL: int = 30


static func create_monster(id: String, level: int) -> Dictionary:
	if not SPECIES.has(id):
		return {}
	var monster: Dictionary = {
		"species": id, "level": clampi(level, 1, MAX_LEVEL), "xp": 0, "hp": 0,
	}
	monster.hp = stats(monster).hp
	return monster


static func stats(monster: Dictionary) -> Dictionary:
	var base: Dictionary = SPECIES[monster.species]
	return {
		"hp": int(base.hp) + int(monster.level) * 4,
		"attack": int(base.attack) + int(monster.level) * 2,
		"defense": int(base.defense) + int(monster.level) * 2,
		"speed": int(base.speed) + int(monster.level) * 2,
	}


static func moves(monster: Dictionary) -> Array:
	var result: Array = []
	for entry: Array in SPECIES[monster.species].learn:
		if int(entry[0]) <= int(monster.level):
			result.append(entry[1])
	return result.slice(maxi(0, result.size() - 4))


static func effectiveness(attack_type: String, defense_type: String) -> float:
	if attack_type == defense_type:
		return 1.0
	if {"fire": "leaf", "leaf": "water", "water": "fire"}.get(attack_type) == defense_type:
		return 2.0
	return 0.5


static func damage(attacker: Dictionary, defender: Dictionary, move_id: String) -> int:
	var move: Dictionary = MOVES[move_id]
	var power: float = float(move.power) * float(stats(attacker).attack)
	power /= float(stats(defender).defense)
	power *= (2.0 + float(attacker.level) * 0.4) / 10.0
	power *= effectiveness(move.type, SPECIES[defender.species].type)
	return maxi(1, int(power))


static func capture_chance(monster: Dictionary) -> float:
	var health_ratio: float = float(monster.hp) / float(stats(monster).hp)
	return clampf(0.25 + (1.0 - health_ratio) * 0.65, 0.25, 0.9)


static func encounter(roll: float) -> String:
	var ids: Array = SPECIES.keys()
	return ids[clampi(int(clampf(roll, 0.0, 1.0) * ids.size()), 0, ids.size() - 1)]


static func xp_needed(level: int) -> int:
	return level * 12


static func valid_monster(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 4:
		return false
	if not value.has_all(["species", "level", "hp", "xp"]):
		return false
	if not value.species is String or not SPECIES.has(value.species):
		return false
	for key: String in ["level", "hp", "xp"]:
		if not integer_between(value[key], 0, 10000):
			return false
	if value.level < 1 or value.level > MAX_LEVEL:
		return false
	return value.hp <= stats(value).hp and value.xp < xp_needed(int(value.level))


static func integer_between(value: Variant, low: int, high: int) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and value >= low and value <= high and value == int(value)
