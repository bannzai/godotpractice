extends Control
## 各キャラ・動作の同じ時点を並べ、欠けと姿勢の差を比較する撮影用画面。

const Actor = preload("res://scripts/visual/actor.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const UI = preload("res://scripts/ui/widgets.gd")
const POSES: Dictionary = {"idle": "待機", "move": "移動", "attack": "行動", "hurt": "被弾", "death": "消滅"}
const PEOPLE: Dictionary = {
	"hero": "あなたの王",
	"scout": "霧路の斥候",
	"duelist": "雨衣の剣将",
	"general": "黒陣の大将",
	"final": "白灰の城主",
	"merchant": "旅の商人",
	"rest": "宿の灯守"
}


func show_pose(group: String, pose: String, frame: int) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	theme = UI.theme_resource()
	UI.panel(self, Rect2(0, 0, 1280, 720), Color("162a26"))
	UI.label(
		self,
		"%sの動作　／　%s　／　%d コマ目" % ["札" if group == "cards" else "人物", POSES[pose], frame + 1],
		Rect2(30, 17, 1200, 52),
		32,
		UI.GOLD
	)
	var ids: Array = Catalog.CARDS.keys() if group == "cards" else PEOPLE.keys()
	var columns: int = 6 if group == "cards" else 4
	var cell_width: float = 1220.0 / columns
	for index: int in range(ids.size()):
		var x: float = 30 + (index % columns) * cell_width
		var y: float = 91 + (index / columns) * 299
		UI.panel(self, Rect2(x + 3, y, cell_width - 12, 283), Color("243a32"))
		var actor := Actor.new()
		add_child(actor)
		actor.setup(ids[index], 0.64)
		actor.position = Vector2(x + cell_width / 2 - 3, y + 134)
		actor.seek_pose(pose, frame)
		var caption: String = (
			Catalog.CARDS[ids[index]].name if group == "cards" else PEOPLE[ids[index]]
		)
		UI.label(self, caption, Rect2(x + 15, y + 245, cell_width - 29, 36), 21)
