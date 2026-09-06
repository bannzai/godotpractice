extends Control
## 最初の通し確認用。各ボタン操作は進行を一度進めるため非冪等。

var page: Control


func _ready() -> void:
	print("ghostrogue boot")
	_show("夜を継ぐ者", "消えた妹を探し、夜明けのない町へ入る。", "夜の町へ", _play)


func _show(title: String, body: String, action: String, callback: Callable) -> void:
	if is_instance_valid(page):
		remove_child(page)
		page.queue_free()
	page = Control.new()
	add_child(page)
	var background := ColorRect.new()
	background.color = Color("202f3d")
	background.size = Vector2(1280, 720)
	page.add_child(background)
	var heading := Label.new()
	heading.text = title
	heading.position = Vector2(160, 180)
	heading.add_theme_font_size_override("font_size", 64)
	page.add_child(heading)
	var description := Label.new()
	description.text = body
	description.position = Vector2(160, 300)
	description.add_theme_font_size_override("font_size", 26)
	page.add_child(description)
	var button := Button.new()
	button.text = action
	button.position = Vector2(160, 430)
	button.size = Vector2(440, 70)
	button.pressed.connect(callback)
	page.add_child(button)
	button.grab_focus()


func _play() -> void:
	_show("夜の町", "門の向こうで、誰かがあなたの名前を呼んでいる。", "夜から帰る", _result)


func _result() -> void:
	_show("夜明けの気配", "あなたは町の入り口から生きて帰った。", "タイトルへ", _ready)
