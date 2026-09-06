extends Control
## 画面ループの初期実装。進行は押下イベントと時間経過のため非冪等。

var screen: String = ""
var elapsed: float = 0.0
var message: Label


func _ready() -> void:
	print("rhythm boot")
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Hiragino Sans", "Noto Sans CJK JP"])
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 28
	_show("title")


func _show(next_screen: String) -> void:
	if screen == next_screen:
		return
	screen = next_screen
	elapsed = 0.0
	for child: Node in get_children():
		child.queue_free()
	var background: ColorRect = ColorRect.new()
	background.color = Color("172b48")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	message = Label.new()
	message.position = Vector2(160, 180)
	message.size = Vector2(960, 220)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.text = {
		"title": "星灯りのリズム便\n夜の街に、あなたのビートを届けよう。",
		"play": "演奏中\nF / J でリズムを刻もう。",
		"result": "演奏おつかれさま！\nもう一度、星空へ。"
	}[screen]
	add_child(message)
	var button: Button = Button.new()
	button.position = Vector2(440, 450)
	button.size = Vector2(400, 72)
	button.text = {"title": "演奏する", "play": "演奏を終える", "result": "タイトルへ"}[screen]
	button.pressed.connect(func() -> void:
		_show({"title": "play", "play": "result", "result": "title"}[screen]))
	add_child(button)
	button.grab_focus()


func _process(delta: float) -> void:
	if screen == "play":
		elapsed += delta
		if elapsed >= 10.0:
			_show("result")
