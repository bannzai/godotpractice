extends Control
## 入力、進行の正本、描画、音声を接続する。

const Controls := preload("res://scripts/controls.gd")
const World := preload("res://scripts/voxel_world.gd")
const Player := preload("res://scripts/player.gd")
const Surroundings := preload("res://scripts/environment.gd")
const Effects := preload("res://scripts/effects.gd")
const Hud := preload("res://scripts/hud.gd")
const Data := preload("res://scripts/voxel_data.gd")

var model: Node
var world: Node3D
var player: CharacterBody3D
var surroundings: Node3D
var effects: Node3D
var hud: Control
var audio: Node
var enemies: Node3D
var hand: Node3D
var title_camera: Camera3D
var paused: bool = false
var mining_progress: float = 0.0
var target_block: Dictionary = {}
var _mining_cell := Vector3i(-1, -1, -1)
var _attack_cooldown: float = 0.0
var _hit_stop: float = 0.0
var _last_phase: String = ""
var _quitting: bool = false
var _highlight: MeshInstance3D
var _highlight_material: StandardMaterial3D
var _placement_preview: MeshInstance3D
var _placement_material: StandardMaterial3D
var _cracks: MeshInstance3D
var _crack_material: StandardMaterial3D
var _torches: Node3D
var _quit_at: int = -1


func _ready() -> void:
	print("survivalcraft boot")
	Controls.configure()
	get_tree().auto_accept_quit = false
	model = get_node("/root/Island")
	world = World.new()
	add_child(world)
	surroundings = Surroundings.new()
	add_child(surroundings)
	surroundings.configure()
	effects = Effects.new()
	add_child(effects)
	player = Player.new()
	add_child(player)
	player.setup(Vector3(16, 10, 16))
	player.fell.connect(_hurt)
	player.step_taken.connect(_footstep)
	title_camera = Camera3D.new()
	add_child(title_camera)
	title_camera.position = Vector3(43, 29, 45)
	title_camera.look_at(Vector3(16, 5, 16))
	title_camera.fov = 47
	audio = load("res://scripts/audio.gd").new()
	add_child(audio)
	enemies = load("res://scripts/enemies.gd").new()
	add_child(enemies)
	enemies.configure(model, effects)
	enemies.player_hit.connect(_hurt)
	enemies.enemy_hit.connect(_on_enemy_hit)
	hand = load("res://scripts/actors/creature.gd").new()
	player.camera.add_child(hand)
	hand.configure("player")
	hand.position = Vector3(0.15, -0.28, -0.3)
	hand.scale = Vector3.ONE * 0.55
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	hud.configure(model)
	hud.requested.connect(_request)
	model.world_changed.connect(_rebuild)
	model.event.connect(_state_event)
	model.data.generate(46073)
	_rebuild()
	_build_target()
	for index: int in range(OS.get_cmdline_args().size() - 1):
		if OS.get_cmdline_args()[index] == "--quit-after":
			_quit_at = int(OS.get_cmdline_args()[index + 1])
	_sync_phase()


func start_game() -> void:
	paused = false
	model.new_game(46073)
	_resume_world()
	hud.start_tutorial(player.position)


func _resume_world() -> void:
	enemies.reset()
	hand.reset_animation()
	player.setup(model.player_position)
	player.rotation.y = 0.0
	player.camera.rotation.x = -0.08
	mining_progress = 0.0
	hud.close_overlay()
	paused = false
	_sync_phase()


func show_title() -> void:
	paused = false
	model.phase = "title"
	hud.close_overlay()
	_sync_phase()


func _sync_phase() -> void:
	var playing: bool = model.phase == "play"
	player.enabled = playing and not paused
	player.camera.current = playing
	title_camera.current = not playing
	hand.visible = playing
	var mouse_mode: int = (Input.MOUSE_MODE_CAPTURED
		if playing and not paused else Input.MOUSE_MODE_VISIBLE)
	if Input.mouse_mode != mouse_mode:
		Input.mouse_mode = mouse_mode
	if model.phase != _last_phase:
		_last_phase = model.phase
		audio.play_music("day" if playing else model.phase)
		if model.phase in ["failed", "clear"]:
			hud.close_overlay()
			paused = false
			hand.animate("vanish")
		elif playing:
			hand.animate("idle")
	hand.set_tool_level(model.tool_level)
	hud.refresh()


## 時間と入力を積算するゲームループのため非冪等。
func _physics_process(delta: float) -> void:
	if not is_instance_valid(hud) or _quitting:
		return
	if _quit_at > 0 and Engine.get_process_frames() >= maxi(0, _quit_at - 10):
		stop_audio()
	if model.phase != "play" or paused:
		_sync_phase()
		return
	if _hit_stop > 0:
		_hit_stop -= delta
		return
	model.player_position = player.position
	model.step(delta)
	surroundings.sync(model.day_time, 1.0)
	enemies.step(delta, player)
	_attack_cooldown = maxf(0, _attack_cooldown - delta)
	target_block = world.raycast(player.camera.global_position,
		-player.camera.global_basis.z, 5.0)
	_update_target(delta)
	hud.update_tutorial(player.position,
		Data.AIR if target_block.is_empty() else int(target_block.id))
	if Input.is_action_pressed("mine"):
		_mine(delta)
	else:
		mining_progress = 0
		if _attack_cooldown <= 0:
			hand.animate("walk" if player.velocity.length() > 0.6 else "idle")
	audio.play_music("night" if model.is_night() else "day")
	_sync_phase()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var mode: int = DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED
			if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if model.phase != "play":
		return
	if event.is_action_pressed("tutorial_skip") and hud.tutorial_step >= 0:
		hud.skip_tutorial()
		return
	if event.is_action_pressed("map_menu"):
		_request("close" if paused else "map", "")
		return
	if event.is_action_pressed("pause_game"):
		_request("close" if paused else "pause", "")
	elif event.is_action_pressed("craft_menu"):
		_request("close" if paused else "craft_menu", "")
	elif not paused:
		_play_input(event)


func _play_input(event: InputEvent) -> void:
	if event.is_action_pressed("place") and not target_block.is_empty():
		var cell: Vector3i = target_block.previous
		if model.place(cell, player.body_aabb()):
			audio.play_sfx("place_" + _sound_kind(model.data.get_block(cell)))
			effects.burst(Vector3(cell) + Vector3.ONE * 0.5, Color("eac47e"))
			hand.animate("attack")
	elif event.is_action_pressed("eat"):
		if not model.eat():
			hud.notify_text("食べ物がないか、空腹ではありません")
	elif event.is_action_pressed("next_slot"):
		model.selected = (model.selected + 1) % 9
	elif event.is_action_pressed("prev_slot"):
		model.selected = posmod(model.selected - 1, 9)
	elif (event is InputEventKey and event.pressed
		and event.physical_keycode in range(KEY_1, KEY_9 + 1)):
		model.selected = event.physical_keycode - KEY_1
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			model.selected = posmod(model.selected - 1, 9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			model.selected = (model.selected + 1) % 9


func _mine(delta: float) -> void:
	if _attack_cooldown <= 0 and enemies.attack(player.camera.global_position,
		-player.camera.global_basis.z):
		_attack_cooldown = 0.45
		mining_progress = 0
		hand.animate("attack")
		return
	if target_block.is_empty():
		mining_progress = 0
		return
	var cell: Vector3i = target_block.cell
	if cell != _mining_cell:
		_mining_cell = cell
		mining_progress = 0
	if not model.can_mine(cell):
		hud.target.text = "より丈夫なつるはしが必要です"
		return
	var hardness: float = Data.HARDNESS.get(target_block.id, 1.0)
	mining_progress += delta / hardness * (1.0 + model.tool_level * 0.3)
	hand.animate("attack")
	if mining_progress >= 1.0:
		var block_id: int = target_block.id
		if model.mine(cell):
			var item: String = Data.ITEMS[block_id]
			effects.burst(Vector3(cell) + Vector3.ONE * 0.5, Color("b8cb8e"))
			effects.floating_text(Vector3(cell) + Vector3.UP, "+1 " + model.item_name(item),
				Color("ffe0a0"))
			audio.play_sfx("break_" + {"leaf": "leaves", "ore": "crystal",
				"plank": "wood", "bench": "wood", "torch": "wood"}.get(item, item))
			player.shake(0.025)
		mining_progress = 0


func _update_target(_delta: float) -> void:
	_highlight.visible = not target_block.is_empty()
	_placement_preview.hide()
	_cracks.visible = not target_block.is_empty() and mining_progress > 0
	hud.progress.value = mining_progress
	hud.progress.visible = mining_progress > 0
	hud.target.text = ""
	hud.placement.text = ""
	if target_block.is_empty():
		hud.target.text = "照準を紙ブロックへ重ねると、できることが見えます"
		return
	_highlight.position = Vector3(target_block.cell) + Vector3.ONE * 0.5
	_cracks.position = _highlight.position
	_crack_material.albedo_color.a = 0.12 + floorf(mining_progress * 4) * 0.15
	var can_mine: bool = model.can_mine(target_block.cell)
	_highlight_material.albedo_color = Color("ffd65e80") if can_mine else Color("e46b5f80")
	hud.target.text = ("○ %sをひらく　左クリック / Q / RT 長押し" %
		model.item_name(Data.ITEMS[target_block.id])) if can_mine else \
		("× %s　より丈夫なつるはしが必要" % model.item_name(Data.ITEMS[target_block.id]))
	var place_cell: Vector3i = target_block.previous
	var place_reason: String = model.placement_reason(place_cell, player.body_aabb())
	if place_reason.is_empty():
		_placement_preview.show()
		_placement_preview.position = Vector3(place_cell) + Vector3.ONE * 0.5
		hud.placement.text = "◇ %sをここに組む　右クリック / R / LT" % \
			model.item_name(model.selected_item())
	else:
		hud.placement.text = "置けない理由：" + place_reason


func _rebuild() -> void:
	world.configure(model.data)
	effects.clear_torches()
	for cell: Vector3i in model.data.blocks:
		if model.data.get_block(cell) == Data.TORCH:
			effects.torch(Vector3(cell) + Vector3(0.5, 0, 0.5))


func _build_target() -> void:
	_highlight = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 1.012
	_highlight.mesh = mesh
	_highlight_material = StandardMaterial3D.new()
	_highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_material.albedo_color = Color("ffd65e80")
	_highlight.material_override = _highlight_material
	add_child(_highlight)
	_placement_preview = MeshInstance3D.new()
	_placement_preview.mesh = mesh
	_placement_preview.scale = Vector3.ONE * 0.985
	_placement_material = StandardMaterial3D.new()
	_placement_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_placement_material.albedo_color = Color("69d7c34f")
	_placement_material.albedo_texture = load("res://assets/textures/origami-paper.png")
	_placement_material.roughness = 1.0
	_placement_preview.material_override = _placement_material
	add_child(_placement_preview)
	_cracks = MeshInstance3D.new()
	_cracks.mesh = mesh
	_cracks.scale = Vector3.ONE * 1.003
	_crack_material = StandardMaterial3D.new()
	_crack_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_crack_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var texture := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	texture.fill(Color.TRANSPARENT)
	for index: int in range(32):
		texture.set_pixel(index, (index * 3 + 7) % 32, Color("14282d"))
		texture.set_pixel((index + 4) % 32, index, Color("14282d"))
		texture.set_pixel(31 - index, (index + 12) % 32, Color("14282d"))
	_crack_material.albedo_texture = ImageTexture.create_from_image(texture)
	_cracks.material_override = _crack_material
	add_child(_cracks)
	_highlight.hide()
	_placement_preview.hide()
	_cracks.hide()


func _request(action: String, value: String) -> void:
	audio.play_sfx("ui")
	match action:
		"new": start_game()
		"load":
			if model.load_game():
				_resume_world()
			else:
				hud.notify_text("保存した島がないか、保存データを読み込めません")
		"respawn":
			model.respawn()
			_resume_world()
		"title": show_title()
		"pause", "craft_menu", "help", "map":
			paused = true
			hud.show_menu({"pause": "pause", "craft_menu": "craft", "help": "help",
				"map": "map"}[action])
		"close":
			paused = false
			hud.close_overlay()
		"save":
			hud.notify_text("島を保存しました" if model.save_game() else "保存できませんでした")
		"retire":
			model.damage(100)
			paused = false
		"equip":
			if model.assign_slot(value):
				hud.show_menu("craft")
		"craft":
			if model.craft(value):
				hud.show_menu("craft")
			else:
				hud.notify_text("材料か作業台が足りません。先に木材と板を集めよう")
	_sync_phase()


func _state_event(kind: String, text: String) -> void:
	hud.notify_text(text)
	audio.play_sfx("craft" if kind == "craft" else "ui")


func _hurt(amount: float) -> void:
	if model.phase != "play" or paused:
		return
	model.damage(amount)
	hud.damage_flash()
	player.shake(0.13)
	hand.animate("hurt")
	audio.play_sfx("hurt")
	_hit_stop = 0.045


func _on_enemy_hit() -> void:
	audio.play_sfx("attack")
	player.shake(0.055)
	_hit_stop = 0.045


func stop_audio() -> void:
	if is_instance_valid(audio):
		audio.stop_audio()


func _exit_tree() -> void:
	stop_audio()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not _quitting:
		_quitting = true
		stop_audio()
		await get_tree().create_timer(0.2).timeout
		get_tree().quit()


func _footstep() -> void:
	var cell := Vector3i(floor(player.position - Vector3(0, 0.12, 0)))
	audio.play_sfx("step_" + _sound_kind(model.data.get_block(cell)))


func _sound_kind(block_id: int) -> String:
	return {Data.GRASS: "grass", Data.DIRT: "dirt", Data.STONE: "stone",
		Data.SAND: "sand", Data.LEAVES: "leaves", Data.ORE: "crystal"}.get(block_id, "wood")
