extends Control
## 画面の初期ループ。進行ロジックは農場の状態ノードへ接続する。

var page: Control
var mode: String = "title"


func _ready() -> void:
	print("farmsim boot")
	refresh()


func refresh() -> void:
	if is_instance_valid(page):
		remove_child(page)
		page.queue_free()
	page = Control.new()
	add_child(page)
	var background := ColorRect.new()
	background.color = Color("254d40")
	background.size = Vector2(1280, 720)
	page.add_child(background)
	var heading := Label.new()
	heading.text = {"title": "こもれび農園", "playing": "春の農場", "result": "農場の記録"}[mode]
	heading.position = Vector2(160, 150)
	heading.add_theme_font_size_override("font_size", 54)
	page.add_child(heading)
	var caption := Label.new()
	caption.text = "種をまき、季節を育てる。小さな二十日間の物語。"
	caption.position = Vector2(164, 256)
	caption.add_theme_font_size_override("font_size", 24)
	page.add_child(caption)
	var button := Button.new()
	button.text = {"title": "新しい暮らし", "playing": "農場を離れる", "result": "タイトルへ"}[mode]
	button.position = Vector2(160, 370)
	button.size = Vector2(340, 64)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(_advance)
	page.add_child(button)
	button.grab_focus()


## 一回の決定入力で画面を進めるため非冪等。
func _advance() -> void:
	mode = {"title": "playing", "playing": "result", "result": "title"}[mode]
	refresh()


func stop_audio() -> void:
	pass
