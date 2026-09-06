class_name BattleData
extends RefCounted
## マップ・兵種・配置の唯一の定義。

const WIDTH: int = 16
const HEIGHT: int = 12
const TERRAIN: Dictionary = {
	".": {"name": "平地", "cost": 1, "evasion": 0, "defense": 0},
	"F": {"name": "森", "cost": 2, "evasion": 20, "defense": 1},
	"M": {"name": "山", "cost": 3, "evasion": 30, "defense": 2},
	"W": {"name": "水", "cost": 99, "evasion": 0, "defense": 0},
	"T": {"name": "砦", "cost": 2, "evasion": 15, "defense": 3},
}
const JOBS: Dictionary = {
	"sword": {"name": "剣士", "max_hp": 30, "strength": 10, "defense": 5,
		"speed": 10, "skill": 12, "move": 5},
	"lance": {"name": "槍兵", "max_hp": 34, "strength": 11, "defense": 7,
		"speed": 6, "skill": 10, "move": 5},
	"axe": {"name": "斧兵", "max_hp": 36, "strength": 14, "defense": 4,
		"speed": 5, "skill": 8, "move": 4},
	"bow": {"name": "弓兵", "max_hp": 26, "strength": 10, "defense": 3,
		"speed": 9, "skill": 14, "move": 5},
	"healer": {"name": "癒し手", "max_hp": 24, "strength": 9, "defense": 3,
		"speed": 7, "skill": 10, "move": 5},
}
const ALLIES: Array[Dictionary] = [
	{"id": "hero", "name": "リオ", "job": "sword", "x": 2, "y": 5},
	{"id": "lance", "name": "セナ", "job": "lance", "x": 2, "y": 6},
	{"id": "axe", "name": "ガル", "job": "axe", "x": 1, "y": 4},
	{"id": "bow", "name": "ネリ", "job": "bow", "x": 1, "y": 6},
	{"id": "healer", "name": "ルカ", "job": "healer", "x": 1, "y": 5},
]
const STAGES: Array[Dictionary] = [
	{
		"name": "風渡りの草原", "objective": "rout", "objective_text": "敵を全滅させる",
		"goal": Vector2i(13, 5),
		"map": ["................", "..FF......MM....", "..F.......M.....",
			"......F.........", ".....FF.........", ".........T......",
			"..........F.....", "......WW..FF....", ".....WWW........",
			"................", "..MM.......FF...", "................"],
		"enemies": [
			{"id": "e1", "name": "荒野の斧兵", "job": "axe", "x": 5, "y": 5, "ai": "approach"},
			{"id": "e2", "name": "荒野の槍兵", "job": "lance", "x": 8, "y": 3, "ai": "approach"},
			{"id": "e3", "name": "荒野の弓兵", "job": "bow", "x": 10, "y": 6, "ai": "approach"},
		],
	},
	{
		"name": "霧の砦", "objective": "boss", "objective_text": "砦の隊長を倒す",
		"goal": Vector2i(11, 5),
		"map": ["................", "...FFF....MMM...", "...FF.....M.....",
			"......W.........", "......W...FFF...", "..........TT....",
			"..........TT....", "......W.........", "......W...FF....",
			".....WW.........", "..MM.......FF...", "................"],
		"enemies": [
			{"id": "e1", "name": "砦の剣兵", "job": "sword", "x": 6, "y": 5, "ai": "approach"},
			{"id": "e2", "name": "砦の弓兵", "job": "bow", "x": 9, "y": 7, "ai": "approach"},
			{"id": "boss", "name": "灰の隊長", "job": "axe", "x": 11, "y": 5,
				"ai": "hold", "boss": true},
		],
	},
	{
		"name": "夜明けの道", "objective": "reach", "objective_text": "リオが東の光柱へ到達する",
		"goal": Vector2i(13, 5),
		"map": ["................", "..MM.....FF.....", "...M.....FFF....",
			"......WW........", "......WW........", ".............T..",
			"................", "......WW....F...", ".....WWW....FF..",
			"................", "..MM.......FF...", "................"],
		"enemies": [
			{"id": "e1", "name": "街道の槍兵", "job": "lance", "x": 6, "y": 5, "ai": "approach"},
			{"id": "e2", "name": "街道の剣兵", "job": "sword", "x": 9, "y": 6, "ai": "approach"},
			{"id": "e3", "name": "街道の斧兵", "job": "axe", "x": 13, "y": 4, "ai": "hold"},
		],
	},
]


static func terrain(cell: Vector2i, map: Array) -> Dictionary:
	if not inside(cell):
		return TERRAIN["W"]
	return TERRAIN[str(map[cell.y])[cell.x]]


static func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < WIDTH and cell.y >= 0 and cell.y < HEIGHT


static func create_unit(definition: Dictionary, team: String) -> Dictionary:
	var unit: Dictionary = JOBS[definition.job].duplicate(true)
	unit.merge(definition, true)
	unit.merge({"team": team, "hp": unit.max_hp, "level": 1, "xp": 0,
		"acted": false, "moved": false, "items": 2, "boss": false, "ai": "hold",
		"growth": {"max_hp": 85, "strength": 55, "defense": 45, "speed": 50, "skill": 60}})
	if team == "enemy":
		unit.max_hp = 20 if not unit.boss else 32
		unit.hp = unit.max_hp
		unit.strength -= 3
	return unit
