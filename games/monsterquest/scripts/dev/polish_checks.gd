extends RefCounted
## 画像の別デザイン、実時間のフレーム進行、演出に渡す戦闘イベントの回帰検証。

const CHARACTERS: Array[String] = [
	"ember", "tide", "sprout", "moth", "crab", "owl", "player", "captain", "healer", "crab_captain",
]
const State: Script = preload("res://scripts/game_state.gd")
const FRAME_SIZE := 32
const FRAME_COUNT := 6
const SHEET_SIZE := Vector2i(FRAME_SIZE * FRAME_COUNT, FRAME_SIZE * 5)
const FIELD_PALETTE: Array[String] = ["0F380F", "306230", "8BAC0F", "9BBC0F"]
const BATTLE_PALETTE: Array[String] = ["0F380F", "306230", "8BAC0F", "9BBC0F", "C3423F"]


static func run(check: Callable, tree: SceneTree) -> void:
	_check_pixel_assets(check)
	_check_sheets(check)
	_check_events(check)
	await _check_animations(check, tree)


static func _check_sheets(check: Callable) -> void:
	var designs: Dictionary = {}
	for id: String in CHARACTERS:
		var texture: Texture2D = load("res://assets/pixel/characters/%s.png" % id)
		check.call(texture != null, "キャラクター固有の画像をロード: " + id)
		if texture == null:
			continue
		var image: Image = texture.get_image()
		check.call(image != null and not image.is_empty(), "シートの画素を取得: " + id)
		if image == null or image.is_empty():
			continue
		check.call(image.get_size() == SHEET_SIZE, "32px・6 列 × 5 行のキャラクター画像: " + id)
		_check_palette(check, image, id, FIELD_PALETTE)
		var fingerprint: int = hash(image.get_data())
		check.call(not designs.has(fingerprint), "他のキャラとは異なる画像: " + id)
		designs[fingerprint] = id
		for row: int in QuestActor.ACTIONS.size():
			var poses: Dictionary = {}
			for column: int in QuestActor.FRAME_COUNT:
				var frame: Image = image.get_region(Rect2i(
					column * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE
				))
				check.call(frame.get_used_rect().has_area(), "透明だけのフレームではない: %s/%d/%d" % [
					id, row, column,
				])
				poses[hash(frame.get_data())] = true
			check.call(poses.size() >= 3, "各動作に 3 枚以上の異なる姿勢がある: %s/%s" % [
				id, QuestActor.ACTIONS[row],
			])


static func _check_pixel_assets(check: Callable) -> void:
	_check_pixel_directory(check, "res://assets/pixel")


static func _check_pixel_directory(check: Callable, path: String) -> void:
	var directory: DirAccess = DirAccess.open(path)
	check.call(directory != null, "ドット絵素材を走査: " + path)
	if directory == null:
		return
	for filename: String in directory.get_files():
		if filename.get_extension().to_lower() != "png":
			continue
		var asset_path: String = path.path_join(filename)
		var texture: Texture2D = load(asset_path) as Texture2D
		check.call(texture != null, "ドット絵素材をロード: " + asset_path)
		if texture == null:
			continue
		var image: Image = texture.get_image()
		check.call(image != null and not image.is_empty(), "ドット絵の画素を取得: " + asset_path)
		if image != null and not image.is_empty():
			var is_effect: bool = path == "res://assets/pixel/effects" or "/effects/" in path
			var palette: Array[String] = BATTLE_PALETTE if is_effect else FIELD_PALETTE
			_check_palette(check, image, asset_path, palette)
	for subdirectory: String in directory.get_directories():
		if subdirectory in ["source", "characters"]:
			continue
		_check_pixel_directory(check, path.path_join(subdirectory))


static func _check_palette(
	check: Callable, image: Image, label: String, allowed_palette: Array[String]
) -> void:
	var colors: Dictionary = {}
	var invalid_colors: Dictionary = {}
	var partial_alpha := false
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a8 == 0:
				continue
			partial_alpha = partial_alpha or color.a8 != 255
			var html: String = color.to_html(false).to_upper()
			colors[html] = true
			if html not in allowed_palette:
				invalid_colors[html] = true
	check.call(not partial_alpha, "アンチエイリアスになる半透明画素がない: " + label)
	check.call(invalid_colors.is_empty(), "許可パレットだけを使う: %s / %s" % [
		label, ", ".join(invalid_colors.keys()),
	])
	check.call(colors.size() >= 1 and colors.size() <= allowed_palette.size(),
		"許可した階調数以内で描く: " + label)


## 同じツリー上で全キャラを実際に再生して、時間経過と完了状態を確かめる。
static func _check_animations(check: Callable, tree: SceneTree) -> void:
	var actors: Array[QuestActor] = []
	for id: String in CHARACTERS:
		var actor := QuestActor.new()
		tree.root.add_child(actor)
		actor.setup(id, Rect2(0, 0, 192, 192))
		check.call(
			actor.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
			or actor.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"キャラクターをニアレストで拡大: " + id
		)
		actors.append(actor)
		for action: String in QuestActor.ACTIONS:
			check.call(actor.sprite.sprite_frames.get_frame_count(action) == 6,
				"動作ごとに 6 フレームを登録: %s/%s" % [id, action])
		actor.set_action("walk")
	await tree.create_timer(0.22).timeout
	for index: int in actors.size():
		var actor: QuestActor = actors[index]
		check.call(actor.sprite.frame > 0 and actor.sprite.is_playing(),
			"移動フレームが時間で進む: " + CHARACTERS[index])
		var frame_before: int = actor.sprite.frame
		actor.set_action("walk")
		check.call(actor.sprite.frame == frame_before, "同じ移動状態を設定しても先頭へ戻らない")
	for action: String in ["attack", "hurt", "defeat"]:
		for actor: QuestActor in actors:
			actor.set_action(action)
		await tree.create_timer(0.70).timeout
		for index: int in actors.size():
			var actor: QuestActor = actors[index]
			check.call(actor.sprite.animation == action and actor.sprite.frame == 5,
				"一回の動作が最後のフレームへ到達: %s/%s" % [CHARACTERS[index], action])
			check.call(not actor.sprite.is_playing(),
				"一回の動作はループせず完了する: %s/%s" % [CHARACTERS[index], action])
	for actor: QuestActor in actors:
		actor.queue_free()
	await tree.process_frame
	await tree.process_frame


static func _check_events(check: Callable) -> void:
	var game: Node = State.new()
	for fixture: Array in [["ember", "sprout", "spark", "fire"],
		["tide", "ember", "drop", "water"], ["sprout", "tide", "seed", "leaf"]]:
		game.new_game()
		game.party = [Catalog.create_monster(fixture[0], 10)]
		game.start_battle(fixture[1], 6)
		var before_hp: int = game.enemy.hp
		var events: Array[Dictionary] = game.resolve_turn("attack", fixture[2])
		var hit: Dictionary = events[0]
		check.call(hit.kind == "attack" and hit.target == "enemy", "先攻のダメージイベントを取得")
		check.call(hit.element == fixture[3], "属性エフェクトに技の属性が届く: " + fixture[3])
		check.call(hit.hp_after == before_hp - hit.damage,
			"HP 演出の到達値は、その攻撃直後の実 HP に一致する")
		check.call(hit.effectiveness == 2.0, "有利な攻撃の演出に 2 倍の倍率が届く")
	_check_heal_event(check, game)
	_check_faint_event(check, game)
	game.free()


static func _check_heal_event(check: Callable, game: Node) -> void:
	game.new_game()
	game.start_battle("sprout", 2)
	game.active_monster().hp = 1
	var events: Array[Dictionary] = game.resolve_turn("potion")
	check.call(events[0].kind == "heal" and events[0].hp_after == 36,
		"回復演出は敵の反撃前の HP を保持する")
	check.call(events[1].kind == "attack" and events[1].target == "player",
		"回復演出の後に相手の攻撃が続く")
	check.call(events[1].hp_after == game.active_monster().hp
		and events[1].hp_after < events[0].hp_after,
		"回復後の被弾は別イベントの HP へ減る")


static func _check_faint_event(check: Callable, game: Node) -> void:
	game.new_game()
	game.start_battle("sprout", 5)
	game.enemy.hp = 1
	var events: Array[Dictionary] = game.resolve_turn("attack", "spark")
	check.call(events[0].damage == 1 and events[0].hp_after == 0,
		"とどめの数値は残 HP を超えず、0 へ到達する")
	check.call(events[1].kind == "faint" and events[1].target == "enemy",
		"HP が 0 になった相手に倒れる演出が続く")
	check.call(events.any(func(event: Dictionary) -> bool: return event.kind == "level"),
		"勝利で成長した時にレベルアップの演出が届く")
	game.new_game()
	game.party.append(Catalog.create_monster("tide", 8))
	game.active_monster().hp = 1
	game.start_battle("moth", 20)
	events = game.resolve_turn("attack", "spark")
	var swap: Dictionary = events.back()
	check.call(swap.kind == "switch" and swap.species == "tide",
		"味方が倒れた時の交代イベントは次のキャラを指定する")
	check.call(swap.hp_after == game.party[1].hp and swap.maximum == Catalog.stats(game.party[1]).hp,
		"交代後の HP 表示に次の個体の現在値と最大値が届く")
