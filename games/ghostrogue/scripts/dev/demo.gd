extends "res://scripts/dev/integration.gd"
## 30 fps・900フレームの録画。シード入力以外は本番GUIへの実入力だけで操作する。
## 入力とフレームの消費は一回のプレイを再現するため非冪等。

const FRAME_LIMIT: int = 900
var frames: int = 0
var next_action_frame: int = 36
var acting: bool = false
var finishing: bool = false
var completed: bool = false
var saw_result: bool = false
var entered_play: bool = false
var action_count: int = 0
var observed_modes: Array[String] = []


func _initialize() -> void:
	_start_demo.call_deferred()


func _start_demo() -> void:
	await _load_main("demo")
	_set_seed(20260907)
	print("プレイ録画: 30 fps / 900 フレーム / 30 秒 / シード20260907")
	print("初期条件: 通常の体力・霊気・仲間・闇堕ち度。保存先だけ検証専用。")


func _process(_delta: float) -> bool:
	frames += 1
	if not is_instance_valid(main):
		return false
	if frames >= FRAME_LIMIT - 24 and not finishing:
		finishing = true
		_finish_demo.call_deferred()
	elif not acting and not finishing and not completed and frames >= next_action_frame:
		if not main.busy:
			acting = true
			_demo_action.call_deferred()
	return false


func _demo_action() -> void:
	var mode: String = run.mode
	if mode not in observed_modes:
		observed_modes.append(mode)
		print("録画到達 %03d F: %s" % [frames, mode])
	match mode:
		"title":
			if saw_result:
				completed = true
				print("録画到達 %03d F: 結果からタイトルへ復帰" % frames)
			else:
				await _click_name("StartRun")
				next_action_frame = frames + 28
		"intro":
			await _key(KEY_ENTER)
			await _settle()
			entered_play = run.mode == "map"
			# 30秒の全ラン録画では、画面にある導線を実クリックして案内を省略する。
			# チュートリアル本編は screenshot と integration で別に最後まで検証する。
			await _click_name("SkipTutorial")
			print("録画入力 %03d F: 最初の夜の案内をスキップ" % frames)
			next_action_frame = frames + 20
		"result":
			saw_result = true
			await create_timer(1.8).timeout
			await _click_name("ReturnTitle")
			next_action_frame = frames + 24
		_:
			print("録画入力 %03d F: %s / 闇 %d" % [frames, mode, run.darkness])
			await _act_on_run()
			action_count += 1
			next_action_frame = frames + 36
	acting = false


func _finish_demo() -> void:
	_check(entered_play, "実入力でタイトルから地図へ入る")
	_check(saw_result and completed, "30秒以内に自然な結末とタイトル復帰へ到達")
	_check(action_count >= 4, "複数の道とイベントを実入力で操作")
	main.stop_audio()
	while frames < FRAME_LIMIT:
		await process_frame
	print("録画終了: %d フレーム / 入力操作 %d 回" % [frames, action_count])
	if not failed:
		print("demo OK")
	quit(1 if failed else 0)
