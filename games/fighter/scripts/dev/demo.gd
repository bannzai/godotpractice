extends SceneTree
## キーイベントと時間を消費する開発専用の録画シナリオなので、同じ実行中には再入しない。
## 通常のHP・技性能で操作し、後半のみ残り時間を短縮して29秒内に結果とタイトル復帰を撮る。

const TOTAL_FRAMES: int = 870
const REQUIRED: Array[String] = [
	"タイトル", "選択", "対戦", "移動", "ジャンプ", "通常技", "ガード", "被弾", "コマンド必殺", "結果", "タイトル復帰"
]
const EVENTS: Array[Array] = [
	[30, KEY_ENTER, true], [32, KEY_ENTER, false],
	[49, KEY_D, true], [51, KEY_D, false],
	[75, KEY_ENTER, true], [77, KEY_ENTER, false],
	[132, KEY_D, true], [153, KEY_D, false],
	[155, KEY_W, true], [158, KEY_W, false],
	[165, KEY_I, true], [168, KEY_I, false],
	[194, KEY_A, true], [194, KEY_S, true],
	[242, KEY_A, false], [242, KEY_S, false],
	[244, KEY_K, true], [247, KEY_K, false],
	[261, KEY_A, true], [276, KEY_A, false],
	[278, KEY_S, true], [281, KEY_D, true],
	[284, KEY_S, false], [284, KEY_J, true],
	[287, KEY_J, false], [287, KEY_D, false],
	[311, KEY_S, true], [314, KEY_D, true],
	[317, KEY_S, false], [317, KEY_J, true],
	[320, KEY_J, false], [320, KEY_D, false],
	[810, KEY_ESCAPE, true], [812, KEY_ESCAPE, false],
]

var main: Control
var state: Node
var event_index: int = 0
var observed_player_id: int = 0
var evidence: Dictionary = {}
var shortened_rounds: Array[int] = []
var failure: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	state = root.get_node("Match")
	print("操作録画: 29秒 / 30fps。15秒以降と22.5秒以降に録画専用の時間短縮を使用")
	for frame: int in range(TOTAL_FRAMES):
		_inject_events(frame)
		_observe(frame)
		_shorten_demo_round(frame)
		if frame == TOTAL_FRAMES - 15:
			main.stop_audio()
		await process_frame
	# 音声停止後15フレーム（30fpsで0.5秒）のミキサー解放待ちを終えてから終了する。
	for requirement: String in REQUIRED:
		if not evidence.has(requirement):
			push_error("操作録画で確認できなかった項目: " + requirement)
			failure = true
	if state.screen != state.Screen.TITLE:
		push_error("操作録画の終了時にタイトルへ戻っていない")
		failure = true
	if not failure:
		print("fighter demo OK")
	quit(1 if failure else 0)


func _inject_events(frame: int) -> void:
	while event_index < EVENTS.size() and int(EVENTS[event_index][0]) == frame:
		var entry: Array = EVENTS[event_index]
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = int(entry[1])
		event.pressed = bool(entry[2])
		Input.parse_input_event(event)
		event_index += 1


func _observe(frame: int) -> void:
	match state.screen:
		state.Screen.TITLE:
			_record("タイトル復帰" if evidence.has("結果") else "タイトル", frame)
		state.Screen.SELECT:
			_record("選択", frame)
		state.Screen.RESULT:
			_record("結果", frame)
		state.Screen.FIGHT:
			_record("対戦", frame)
			if main.player.get_instance_id() != observed_player_id:
				observed_player_id = main.player.get_instance_id()
				main.player.special_cast.connect(_record_special)
			if absf(main.player.velocity.x) > 15.0 and main.player.stun <= 0.0:
				_record("移動", frame)
			if main.player.position.y < 540.0:
				_record("ジャンプ", frame)
			if main.player.action in ["lp", "hp", "lk", "hk"]:
				_record("通常技", frame)
			if main.player.guard_flash > 0.0:
				_record("ガード", frame)
			if main.player.health < 1000:
				_record("被弾", frame)


func _record_special() -> void:
	# 直接start_attackを呼ばず、下→斜め下前→前+拳のキー入力から実際に弾が出たことを記録する。
	_record("コマンド必殺", Engine.get_process_frames())


func _record(label: String, frame: int) -> void:
	if evidence.has(label):
		return
	evidence[label] = true
	print("操作確認: %.2f秒 %s" % [frame / 30.0, label])


func _shorten_demo_round(frame: int) -> void:
	if state.screen != state.Screen.FIGHT or state.round_over or main.intro > 0.0:
		return
	var earliest: int = 450 if state.round_number == 1 else 675
	if frame < earliest or int(state.round_number) in shortened_rounds:
		return
	# 入力で被弾した実際の体力差を使う。時間だけを短縮し、2本先取の通常の結果遷移を通す。
	if main.cpu.health <= main.player.health:
		return
	shortened_rounds.append(int(state.round_number))
	print("録画専用時間短縮: 第%d戦 / 体力 %d対%d / %.2f秒" % [
		state.round_number, main.player.health, main.cpu.health, frame / 30.0])
	state.remaining = minf(state.remaining, 0.05)
