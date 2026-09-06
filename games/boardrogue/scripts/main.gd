extends Control
## 最初の通し動作を確認する小さな対局。盤面戦闘へ順次拡張する。

var screen: String = "title"
var king_hp: int = 10
var enemy_hp: int = 10


func _ready() -> void:
	print("boardrogue boot")
	_render()


func _render() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var background := ColorRect.new()
	background.color = Color("192927")
	background.size = Vector2(1280, 720)
	add_child(background)
	var title := Label.new()
	title.text = "墨将紀　― 霧の九峠 ―"
	title.position = Vector2(190, 150)
	title.add_theme_font_size_override("font_size", 48)
	add_child(title)
	var caption := Label.new()
	caption.position = Vector2(190, 260)
	caption.text = "一枚を伏せ、一手を読む。王を守り、峠の先へ。"
	if screen == "battle":
		caption.text = "自軍の王 %d / 10　　　敵軍の王 %d / 10" % [king_hp, enemy_hp]
	elif screen == "result":
		caption.text = "勝利。次の旅へ。" if enemy_hp == 0 else "敗北。再び旗を掲げよ。"
	caption.add_theme_font_size_override("font_size", 24)
	add_child(caption)
	var button := Button.new()
	button.position = Vector2(190, 360)
	button.size = Vector2(340, 72)
	button.text = {"title": "旅を始める", "battle": "進軍する", "result": "タイトルへ"}[screen]
	button.pressed.connect(_advance)
	add_child(button)
	button.grab_focus()


# 一度の操作で一手を進めるため非冪等。
func _advance() -> void:
	match screen:
		"title":
			king_hp = 10
			enemy_hp = 10
			screen = "battle"
		"battle":
			enemy_hp = maxi(0, enemy_hp - 3)
			king_hp = maxi(0, king_hp - 2)
			if enemy_hp == 0 or king_hp == 0:
				screen = "result"
		"result":
			screen = "title"
	_render()
