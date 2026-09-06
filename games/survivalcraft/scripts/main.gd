extends Control
## 初期の画面遷移。ゲーム世界との接続は同じ開始・帰還ボタンに追加する。

var panel: VBoxContainer


func _ready() -> void:
	print("survivalcraft boot")
	var background := ColorRect.new()
	background.color = Color("163a40")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	panel = VBoxContainer.new()
	panel.position = Vector2(420, 230)
	panel.custom_minimum_size = Vector2(440, 220)
	add_child(panel)
	show_title()


func show_title() -> void:
	_screen("灯守の島", "島へ出発", start_game)


func start_game() -> void:
	_screen("島での暮らし", "遠征を終える", show_result)


func show_result() -> void:
	_screen("遠征の記録", "タイトルへ", show_title)


func _screen(title: String, text: String, action: Callable) -> void:
	for child: Node in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 46)
	panel.add_child(label)
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 64
	button.pressed.connect(action)
	panel.add_child(button)
	button.grab_focus()
