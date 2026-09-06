extends SceneTree
## 描画を伴う代表場面と、全画像・全アニメーションの連続ポーズを保存する。

const Sim = preload("res://scripts/simulation.gd")
const Actor = preload("res://scripts/city_actor.gd")
const UI = preload("res://scripts/ui.gd")
const ACTORS: Array[String] = [
	"residential",
	"residential_mid",
	"commercial",
	"commercial_mid",
	"industrial",
	"industrial_mid",
	"power",
	"park",
	"police",
	"fire",
	"tree",
	"car",
	"walker"
]
const ACTOR_NAMES: Array[String] = [
	"住宅", "中層住宅", "商店", "中層商業", "工場", "中層工業", "発電所", "公園", "警察", "消防", "街路樹", "車", "住民"
]
const ACTION_NAMES: Dictionary = {
	"idle": "待機", "build": "建設", "demolish": "撤去", "grow": "成長", "problem": "問題", "move": "移動"
}

var _main: Node
var _city: Node
var _success: bool = true


func _initialize() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	_run.call_deferred()


# 撮影は時間と演出を進める検証シナリオなので、一実行で一巡させる。
func _run() -> void:
	await _capture_scenes()
	if is_instance_valid(_main):
		_main.queue_free()
	await root.get_node("Sound").shutdown()
	await process_frame
	quit(0 if _success else 1)


func _capture_scenes() -> void:
	_city = root.get_node("City")
	_city.saving_enabled = false
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	_main = scene.instantiate()
	root.add_child(_main)
	await _shot("title", 0.5)
	_city.start_city()
	_city.speed = 0
	await _shot("initial-city", 0.5)
	for month: int in range(3):
		_city.next_month()
	await _shot("growth", 0.25)
	for month: int in range(2):
		_city.next_month()
	await _shot("developed-city", 1.0)
	await _capture_effects()
	await _capture_overlays()
	_main.view.daylight_override = 1.0
	await _shot("day", 0.2)
	_main.view.daylight_override = 0.0
	await _shot("night", 0.2)
	_main.view.daylight_override = -1.0
	await _capture_results()
	_main.hide()
	await _capture_galleries()


func _capture_effects() -> void:
	var cell: Vector2i = Vector2i(10, 16)
	if _city.build(cell, "park"):
		_main.view.burst(cell)
		await _shot("construction-particles", 0.15)
	else:
		_fail("撮影用公園を建設できません")
	if _city.build(cell, "empty"):
		_main.view.burst(cell, true)
		await _shot("demolition-shake", 0.14)
	else:
		_fail("撮影用公園を撤去できません")
	await create_timer(0.6).timeout


func _capture_overlays() -> void:
	for index: int in range(1, _main.OVERLAYS.size()):
		_main.overlay_index = index
		_main.view.overlay = _main.OVERLAYS[index]
		_main._refresh()
		await _shot("overlay-" + _main.OVERLAYS[index], 0.2)
	_main.overlay_index = 0
	_main.view.overlay = "none"
	var original: Dictionary = _city.state.duplicate(true)
	if _city.build(Vector2i(7, 16), "empty"):
		await _shot("power-failure", 0.6)
	else:
		_fail("停電の撮影用に発電所を撤去できません")
	_city.state = original
	_city.analysis = Sim.analyze(original)
	_city.changed.emit()
	await create_timer(0.6).timeout


func _capture_results() -> void:
	var active: Dictionary = _city.state.duplicate(true)
	for x: int in range(8, 11):
		_city.build(Vector2i(x, 16), "residential")
	for month: int in range(30):
		if _city.phase == "result":
			break
		_city.next_month()
	if _city.state.outcome != "clear":
		_fail("通常の月送りで人口目標に到達できません")
	await _shot("result-clear", 0.5)
	_city.state = active
	_city.state.money = -10000
	_city.analysis = Sim.analyze(_city.state)
	_city.set_phase("playing")
	_city.speed = 0
	for month: int in range(3):
		_city.next_month()
	if _city.state.outcome != "defeat":
		_fail("資金不足が3か月続いても終了しません")
	await _shot("result-bankrupt", 0.5)


func _capture_galleries() -> void:
	for action: String in Actor.ACTIONS:
		var gallery: Control = Control.new()
		gallery.theme = UI.make_theme()
		root.add_child(gallery)
		UI.panel(gallery, Rect2(0, 0, 1280, 720), Color("eeeada"))
		UI.label(gallery, "街の図鑑  /  " + ACTION_NAMES[action], Rect2(28, 18, 1220, 50), 30, UI.INK)
		UI.label(gallery, "全13画像の開始・途中・終了を、同じ倍率で比較", Rect2(28, 70, 1220, 30), 18, UI.INK)
		for column: int in range(ACTORS.size()):
			UI.label(gallery, ACTOR_NAMES[column], Rect2(31 + column * 94, 112, 94, 28), 13, UI.INK)
		for row: int in range(3):
			var progress: float = row * 0.5
			UI.label(
				gallery,
				["開始 0%", "途中 50%", "終了 100%"][row],
				Rect2(28, 158 + row * 178, 220, 25),
				14,
				UI.INK
			)
			for column: int in range(ACTORS.size()):
				UI.panel(
					gallery, Rect2(26 + column * 94, 190 + row * 178, 87, 130), Color("d5dacb")
				)
				var actor: Node2D = Actor.new()
				gallery.add_child(actor)
				actor.position = Vector2(69 + column * 94, 295 + row * 178)
				actor.scale = Vector2.ONE * 1.7
				actor.setup(ACTORS[column])
				actor.seek_pose(action, progress)
		await _shot("actors-" + action, 0.1)
		gallery.queue_free()
		await process_frame


func _shot(label: String, delay: float) -> void:
	await create_timer(delay).timeout
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://tmp/screenshot-%s.png" % label
	var status: Error = root.get_texture().get_image().save_png(path)
	if status != OK:
		_fail("スクリーンショット保存失敗: %s (%s)" % [path, error_string(status)])
	else:
		print("screenshot: " + path)


func _fail(message: String) -> void:
	_success = false
	push_error(message)
