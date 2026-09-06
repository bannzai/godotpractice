extends Control
## 最初の画面往復。防衛ルールは次の実装で接続する。


func _ready() -> void:
	print("towerdefense boot")
	_show("黄昏の灯砦", "防衛を始める", _play)


func _show(caption: String, action: String, callback: Callable) -> void:
	for child: Node in get_children():
		child.queue_free()
	var background := ColorRect.new()
	background.color = Color("173f42")
	background.size = Vector2(1280, 720)
	add_child(background)
	var label := Label.new()
	label.text = caption
	label.position = Vector2(420, 210)
	label.add_theme_font_size_override("font_size", 48)
	add_child(label)
	var button := Button.new()
	button.text = action
	button.position = Vector2(460, 390)
	button.size = Vector2(360, 80)
	button.pressed.connect(callback)
	add_child(button)
	button.grab_focus()


func _play() -> void:
	_show("灯砦を守る", "撤退して結果へ", _result)


func _result() -> void:
	_show("防衛を終了しました", "タイトルへ", _ready)
