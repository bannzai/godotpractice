extends Control
## 起動と画面遷移の入口。

var content: Control
var state: Node


func _ready() -> void:
	print("blockpuzzle boot")
	state = get_node("/root/Session")
	_render()


# 時間による進行のため非冪等。
func _process(delta: float) -> void:
	if state.screen == "play":
		state.elapsed += delta
		if state.elapsed >= 15.0:
			state.screen = "result"
			_render()


# 決定入力ごとに画面を進めるため非冪等。
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and event is InputEventKey and event.keycode == KEY_ENTER:
		_advance()


func _advance() -> void:
	if state.screen == "title":
		state.start()
	elif state.screen == "play":
		state.screen = "result"
	else:
		state.screen = "title"
	_render()


func _render() -> void:
	if is_instance_valid(content):
		remove_child(content)
		content.queue_free()
	content = Control.new()
	add_child(content)
	var background := ColorRect.new()
	background.color = Color("142b40")
	background.size = Vector2(1280, 720)
	content.add_child(background)
	var title := Label.new()
	title.text = {"title": "星つむぎ", "play": "星をつないで育てよう", "result": "今回の記録"}[state.screen]
	title.add_theme_font_size_override("font_size", 56)
	title.position = Vector2(400, 170)
	content.add_child(title)
	var button := Button.new()
	button.text = {"title": "はじめる", "play": "結果へ", "result": "タイトルへ"}[state.screen]
	button.position = Vector2(440, 470)
	button.size = Vector2(400, 72)
	button.pressed.connect(_advance)
	content.add_child(button)
	button.grab_focus()
