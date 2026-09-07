extends SceneTree
## 描画付きで実入力と画面を確認する。出力先は作業用 tmp のみ。
var world: Node2D
var journey: Node
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func press(code: Key, down: bool = true) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func frames(count: int) -> void:
	for index: int in range(count):
		await physics_frame

func check(condition: bool, label: String) -> void:
	if condition:
		print("成功: " + label)
	else:
		push_error("失敗: " + label)
		failures += 1

func capture(name_text: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var target: String = ProjectSettings.globalize_path("res://../../tmp/actionadventure-" + name_text + ".png")
	check(root.get_texture().get_image().save_png(target) == OK, "画面保存 " + name_text)

func run() -> void:
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	journey = root.get_node("Journey")
	root.grab_focus()
	await frames(15)
	await capture("title")
	press(KEY_ENTER)
	await frames(2)
	press(KEY_ENTER, false)
	check(world.mode == "play", "Enter で開始")
	var before: Vector2 = world.player
	press(KEY_D)
	await frames(40)
	press(KEY_D, false)
	check(world.player.x > before.x + 25, "D キーで移動")
	press(KEY_SPACE)
	await frames(3)
	press(KEY_SPACE, false)
	check(world.dash_cooldown > 0, "Space で回避")
	await frames(15)
	await capture("shore")
	world.player = Vector2(620, 224)
	press(KEY_D)
	await frames(20)
	press(KEY_D, false)
	check(journey.room == 1, "画面東端から森へ移動")
	press(KEY_J)
	await frames(3)
	press(KEY_J, false)
	check(world.attack_cooldown > 0, "J キーで剣")
	await capture("forest")
	press(KEY_TAB)
	await frames(2)
	press(KEY_TAB, false)
	check(world.mode == "map", "地図と一時停止")
	await capture("map")
	press(KEY_ESCAPE)
	await frames(2)
	press(KEY_ESCAPE, false)
	check(world.mode == "play", "Esc で冒険へ復帰")
	# 以降は各進行段階の描画用フィクスチャ。通しプレイとは区別する。
	journey.key_found = true
	journey.shrine_open = true
	world.load_room(2, world.center(Vector2i(7, 5)))
	press(KEY_D)
	await frames(60)
	press(KEY_D, false)
	check(journey.solved, "実移動で石を床まで押す")
	await capture("shrine")
	world.player = world.center(Vector2i(10, 3))
	press(KEY_E)
	await frames(2)
	press(KEY_E, false)
	check(journey.ember, "E キーで灯火を取得")
	world.load_room(3, world.center(Vector2i(8, 3)))
	world.facing = Vector2.UP
	press(KEY_E)
	await frames(2)
	press(KEY_E, false)
	world.player = world.center(Vector2i(12, 3))
	press(KEY_E)
	await frames(2)
	press(KEY_E, false)
	check(journey.braziers.size() == 2, "二つの燭台を灯す")
	await capture("garden")
	world.load_room(4, world.center(Vector2i(10, 8)))
	await frames(110)
	await capture("guardian")
	check(world.bolts.size() > 0 or float(world.enemies[0].phase) > 1.5, "守護者の攻撃予告または弾")
	world.hurt = 0
	journey.health = 1
	world.damage_player(world.player + Vector2.LEFT * 10)
	check(world.mode == "dead", "体力ゼロで再開画面")
	await capture("retry")
	press(KEY_ENTER)
	await frames(2)
	press(KEY_ENTER, false)
	check(world.mode == "play" and journey.health == 6 and journey.ember, "Enter で取得物を保持して再開")
	journey.defeated.append("4:0")
	world.load_room(4, world.center(Vector2i(10, 3)))
	press(KEY_E)
	await frames(2)
	press(KEY_E, false)
	check(world.mode == "ending" and journey.won, "灯台を灯してエンディング")
	await capture("ending")
	world.queue_free()
	world = null
	await frames(5)
	print("描画・入力検証: 失敗 %d 件" % failures)
	quit(0 if failures == 0 else 1)
