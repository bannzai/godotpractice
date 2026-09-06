extends "res://scripts/dev/integration.gd"
## 画面とアニメーションを実際に描画して記録する。
## 個別画面の撮影は固定条件を用い、通常操作での到達は integration/demo で別に検証する。

const Catalog := preload("res://scripts/catalog.gd")
const Story := preload("res://scripts/story.gd")
const ACTOR_IDS: Array[String] = [
	"child", "warrior", "water", "fox", "headless", "doll", "monk", "moth",
	"bride", "crow", "bell", "beast", "hero_0", "hero_1", "hero_2", "hero_3", "police", "boss"
]
const MOTIONS: Dictionary = {
	"idle": "待機", "move": "移動", "attack": "攻撃", "hurt": "被弾", "dissolve": "霧散"
}


func _initialize() -> void:
	deadline_seconds = 240.0
	_take_screenshots.call_deferred()


func _take_screenshots() -> void:
	await _load_main("screenshot")
	await _capture_scenes()
	await _finish_checks("screenshot OK")


func _capture_scenes() -> void:
	await _capture("title")
	_set_seed(20260907)
	await _click_name("StartRun")
	await _capture("intro")
	await _click_name("BeginJourney")
	await _capture("map")
	await _click_name("OpenCodex")
	await _capture("codex")
	for page: int in range(1, 3):
		await _click_name("CodexNext")
		await _capture("codex-%d" % page)
	await _click_name("CloseOverlay")
	await _click_name("OpenParty")
	await _capture("party")
	await _click_name("CloseOverlay")
	await _key(KEY_ESCAPE)
	await _capture("pause")
	await _click_name("Help")
	await _capture("help")
	await _click_name("CloseOverlay")
	for kind: String in Catalog.NODE_LABELS:
		await _prepare_node(kind)
		await _capture("node-" + kind)
	await _prepare_node("grave")
	await _click_name("EventChoice0")
	await _click_name("OpenParty")
	await _capture("party-reserve")
	await _click_name("CloseOverlay")
	await _capture_dialogues()
	await _capture_police_penalties()
	await _capture_darkness()
	await _capture_endings()
	await _capture_effects()
	await _capture_characters()
	await _check_fullscreen()


## 個別ノードを固定した撮影条件。通常プレイの到達証明とは区別する。
func _prepare_node(kind: String) -> void:
	main.busy = true
	run.new_run(20260907)
	run.begin_journey()
	for depth: int in range(run.route.size()):
		for branch: int in range(run.route[depth].size()):
			if run.route[depth][branch].kind == kind:
				run.depth = depth
				run.route_choices.resize(depth)
				run.route_choices.fill(0)
				run.enter_node(branch)
				main.busy = false
				main.render()
				await _settle()
				await create_timer(0.25).timeout
				return
	main.busy = false
	_check(false, "撮影するノードが道に存在: " + kind)


func _capture_dialogues() -> void:
	await _prepare_node("story")
	for index: int in range(Story.EVENTS.size()):
		run.current_node.story = index
		main.render()
		await _capture("story-%d" % index)


func _capture_police_penalties() -> void:
	await _prepare_node("police")
	for darkness: int in [0, 40, 65, 80]:
		run.darkness = darkness
		main.render()
		await _capture("police-darkness-%d" % darkness)


func _capture_darkness() -> void:
	for darkness: int in [0, 30, 60, 80]:
		main.busy = true
		run.new_run(20260907)
		run.begin_journey()
		run.darkness = darkness
		main.busy = false
		main.render()
		await _settle()
		await _capture("darkness-%d" % darkness)


func _capture_endings() -> void:
	var darkness_by_ending: Dictionary = {
		"saved": 12, "scarred": 68, "darkness": 100, "arrest": 80, "lost": 24
	}
	for ending: String in Story.ENDINGS:
		main.busy = true
		run.new_run(20260907)
		run.mode = "result"
		run.ending = ending
		run.result_text = Story.ENDINGS[ending].text
		run.darkness = darkness_by_ending[ending]
		run.depth = 12 if ending in ["saved", "scarred"] else 7
		run.route_choices.resize(run.depth)
		run.route_choices.fill(0)
		main.busy = false
		main.render()
		await _settle()
		await _capture("ending-" + ending)


func _capture_effects() -> void:
	for kind: String in ["grave", "living", "police"]:
		await _prepare_node(kind)
		if kind == "police":
			main.effects.flash(Color("b748666f"))
			main.effects.shake()
		else:
			main.effects.flash(Color("accfce65"))
			main.effects.burst(Vector2(264, 352), Color("cbb486"))
		await create_timer(0.12).timeout
		await _capture("effect-arrival-" + kind, 0.0)
	main.effects.darkness_pulse()
	await create_timer(0.12).timeout
	await _capture("effect-darkness", 0.0)
	await create_timer(0.4).timeout
	main.effects.transition()
	await create_timer(0.12).timeout
	await _capture("effect-transition", 0.0)
	await _prepare_node("battle")
	# 通常のターン解決を実クリックし、演出の進行中を撮る。
	await _click(_button("ResolveTurn"), "戦闘演出の開始")
	for index: int in range(3):
		await create_timer(0.18).timeout
		await _capture("effect-battle-%d" % index, 0.0)
	await _settle()


func _capture_characters() -> void:
	main.hide()
	main.effects.visible = false
	main.process_mode = Node.PROCESS_MODE_DISABLED
	for id: String in ACTOR_IDS:
		await _capture_character(id)
	main.process_mode = Node.PROCESS_MODE_INHERIT
	main.effects.visible = true
	main.show()


func _capture_character(id: String) -> void:
	var stage := Control.new()
	stage.theme = main.theme
	root.add_child(stage)
	var backdrop := ColorRect.new()
	backdrop.color = Color("101e29")
	backdrop.size = Vector2(1280, 720)
	stage.add_child(backdrop)
	var heading: String = Catalog.spirit(id).get("name", "灯を継ぐ者")
	if id.begins_with("hero_"):
		heading += " / 闇の段階 " + id.get_slice("_", 1)
	_gallery_label(stage, heading, Vector2(40, 18), Vector2(1180, 48), 30)
	_gallery_label(stage, "AnimationPlayer の開始・途中・終了を同じ条件で描画",
		Vector2(40, 64), Vector2(1180, 30), 16)
	for row: int in range(3):
		_gallery_label(stage, ["開始", "途中", "終了"][row],
			Vector2(14, 185 + row * 185), Vector2(65, 34), 16)
	var column: int = 0
	for motion: String in MOTIONS:
		_gallery_label(stage, MOTIONS[motion], Vector2(100 + column * 238, 100),
			Vector2(205, 32), 20)
		for row: int in range(3):
			var actor: Node2D = load("res://scripts/actor.gd").new()
			stage.add_child(actor)
			actor.setup(id)
			actor.position = Vector2(190 + column * 238, 220 + row * 185)
			actor.scale = Vector2.ONE * 0.65
			var players: Array[Node] = actor.find_children("*", "AnimationPlayer", true, false)
			_check(players.size() == 1, "キャラがAnimationPlayerを持つ: " + id)
			if players.size() == 1:
				var player: AnimationPlayer = players[0] as AnimationPlayer
				_check(player.has_animation(motion), "キャラの動作が登録済み: " + id + motion)
				if player.has_animation(motion):
					var length: float = player.get_animation(motion).length
					var time: float = minf(float(row) * 0.5 * length, length - 0.001)
					actor.seek_motion(motion, time)
			actor.process_mode = Node.PROCESS_MODE_DISABLED
		column += 1
	await _capture("character-" + id, 0.0)
	stage.queue_free()
	await process_frame


func _gallery_label(parent: Node, text: String, position: Vector2,
		size: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e6dec9"))
	parent.add_child(label)


func _check_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var initial: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	await _key(KEY_F11)
	await create_timer(1.0).timeout
	_check(DisplayServer.window_get_mode() != initial, "F11で全画面へ切り替える")
	await _key(KEY_F11)
	await create_timer(1.0).timeout
	_check(DisplayServer.window_get_mode() == initial, "F11の再入力で表示モードが戻る")


func _capture(scene_name: String, settle_delay: float = 0.4) -> void:
	if settle_delay > 0.0:
		await create_timer(settle_delay).timeout
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "tmp/screenshot-%s.png" % scene_name
	var status: Error = root.get_viewport().get_texture().get_image().save_png(path)
	_check(status == OK, "スクリーンショット保存: " + scene_name)
	print("screenshot: " + path)
