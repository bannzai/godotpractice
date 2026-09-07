extends SceneTree

## 再実行で同一の画像と音源を出力する、外部素材を使わない制作スクリプト。
const COLORS: Dictionary = {
	".": Color.TRANSPARENT, "o": Color("182c34"), "g": Color("476650"),
	"m": Color("70875a"), "l": Color("a3b975"), "c": Color("e7dfb0"),
	"w": Color("faf0ce"), "r": Color("b7513c"), "s": Color("733e39"),
	"b": Color("345968"), "a": Color("538a91"), "t": Color("947c5c"),
	"y": Color("edb85e"), "d": Color("354b46"),
}
const SPRITES: Array[Array] = [
	[], [], [],
	["......oooo......", "....ooggggoo....", "...ogmmllmggo...", "..ogmllllmmggo..", ".ogmmllmlmmmggo.", ".ogmlmmgmmmgggo.", "ogmmmgmmmmgggggo", "ogmmggmlmmgggggo", ".ogggmmgggggggo.", "..oggggggggggo..", "...ooggggggoo...", ".....ottoo......", ".....ottoo......", "....oottttoo....", ".....oooooo.....", "................"],
	["oooooooooooooooo", "occcccccccccccco", "ottttttottttttto", "otmmmttottttttto", "ottttttottttttto", "oooooooooooooooo", "ottttottttttttto", "ottttottttttmmto", "ottttottttttmmto", "oooooooooooooooo", "ottttttttottttto", "ottttttttottttto", "otmttttttottttto", "otmmtttttottttto", "oddddddddddddddo", "oooooooooooooooo"],
	["................", "......oooo......", ".....ocwwwo.....", "....ocwwwwwo....", "....owwccwwo....", "....ocococoo....", ".....occcco.....", "....orsrrro.....", "...orrsrrrro....", "...oryrrrrro....", "...oorrrrrroo...", "....orsrssro....", "....oossooso....", ".....ot..oto....", ".....oo..ooo....", "................"],
	["................", "................", "................", "................", "......oooo......", "....oommmmoo....", "...omlllllmmo...", "..omllllllmmmo..", "..olwllwllmmmo..", "..olollollmmmo..", "..omllllllmmmo..", "...ommmmmmggo...", "..oggggggggggo..", "...oooooooooo...", "................", "................"],
	["................", "......o..o......", "......oggo......", ".....ooaaoo.....", "....obaaaabo....", "...obaaaabbbo...", "..oobaaaaabbooo.", "...obaaobbbbo...", "..oobaaobbbbooo.", "...obaaobbbbo...", "..oobbbobbbbooo.", "....obbbbbo.....", ".....ooooo......", "................", "................", "................"],
	["......oooo......", "....oottttoo....", "...otccccttto...", "...otoyyoytto...", "...otttttttto...", "....otttttto....", "..ooooggggoooo..", ".otttotmmotttto.", ".otttoyllotttto.", ".otttoymmottmto.", "..ooooggggoooo..", "....otttttto....", "....ottottto....", "...otttoottto...", "...oooo.ooooo...", "................"],
	["................", "................", "................", "...oooooooooo...", "..ottttyytttto..", "..otcccyycccto..", "..otttryyrttto..", "..oooooooooooo..", "..otttoyyottto..", "..otttoooottto..", "..otrttttttrto..", "..otttttttttto..", "..oooooooooooo..", "................", "................", "................"],
	["......oooo......", ".....occcco.....", "....otccccto....", "....otcwccto....", "....otcwccto....", "....otcyccto....", "....otcyccto....", "....otccccto....", "....otmcccto....", "....otmcccto....", "....otccccto....", "...oottttttoo...", "..otccccccccto..", "..otttttttttto..", "..oooooooooooo..", "................"],
	["................", "................", "................", "................", "...oooooooooo...", "..otttttttttto..", "..otccccccccto..", "..otcccyccccto..", "..otccyyycccto..", "..otcccyccccto..", "..otccccccccto..", "..otttttttttto..", "...oooooooooo...", "................", "................", "................"],
	["................", "..oooooooooooo..", ".otccccccccccto.", ".otcttttttttcto.", ".otctcccccttcto.", ".otctctttcttcto.", ".otctctmtcttcto.", ".otctctmtcttcto.", ".otctctttcttcto.", ".otctcccccttcto.", ".otcttttttttcto.", ".otccccccmmccto.", ".otttttttmmttto.", ".oddddddddddddo.", "..oooooooooooo..", "................"],
	["................", "................", "................", "................", "....w.......r...", "...wyw.....ryr..", "....w...w...r...", "....g..wyw..g...", "...mg...w..mg...", "....gm..g..g....", "....g..mg.......", ".......g........", "................", "................", "................", "................"],
	["................", "................", ".....oooo.......", "....oyyyyo......", "...oywooyyo.....", "...oyyooyyo.....", "....oyyyyo......", ".....oyyo.......", ".....oyyo.......", ".....oyyoo......", ".....oyyyyo.....", ".....oyyoo......", "......oo........", "................", "................", "................"],
	["................", ".......y........", "......yyy.......", ".....yywyy......", ".....ywwwy......", ".....yywyy......", "......yyy.......", "......oyo.......", ".....otcto......", ".....otcto......", ".....otcto......", ".....otcto......", "....ootctoo.....", "....ottttto.....", "....ooooooo.....", "................"]
]

func _initialize() -> void:
	var base: String = get_script().resource_path.get_base_dir().get_base_dir().get_base_dir()
	var target: String = base.path_join("assets")
	DirAccess.make_dir_recursive_absolute(target)
	var atlas: Image = Image.create(256, 16, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for index: int in range(16):
		for y: int in range(16):
			for x: int in range(16):
				var color: Color
				if index == 0:
					color = COLORS["g"] if (x * 7 + y * 11) % 31 < 3 else Color("536d50")
					if (x * 3 + y * 17) % 61 < 2:
						color = COLORS["m"]
				elif index == 1:
					color = Color("938d6a") if y % 8 == 0 or (x + (8 if y < 8 else 0)) % 16 == 0 else Color("b4ac81")
					if (x * 13 + y * 7) % 53 == 0:
						color = Color("a49c77")
				elif index == 2:
					color = COLORS["b"]
					if (y == 4 and x > 2 and x < 8) or (y == 11 and x > 8 and x < 14):
						color = COLORS["a"]
				else:
					color = COLORS[SPRITES[index][y][x]]
				atlas.set_pixel(index * 16 + x, y, color)
	var result: Error = atlas.save_png(target.path_join("atlas.png"))
	if result != OK:
		push_error("画像保存失敗: %s" % result)
		quit(1)
		return
	for sound: String in ["ambient", "swing", "hit", "chime"]:
		if not _save_sound(target, sound):
			quit(1)
			return
	print("画像と音源の生成完了: ", target)
	quit(0)

func _save_sound(target: String, kind: String) -> bool:
	const RATE: int = 22050
	var duration: float = 16.0 if kind == "ambient" else (1.2 if kind == "chime" else 0.22)
	var data: PackedByteArray = PackedByteArray()
	data.resize(int(duration * RATE) * 2)
	var melody: Array[float] = [440.0, 523.251, 659.255, 587.33, 523.251, 440.0, 391.995, 329.628, 349.228, 440.0, 523.251, 587.33, 523.251, 440.0, 391.995, 329.628]
	for sample: int in range(data.size() / 2):
		var time: float = float(sample) / RATE
		var value: float = 0.0
		if kind == "ambient":
			var note_time: float = fmod(time, 0.5)
			var frequency: float = melody[int(time / 0.5) % melody.size()]
			var envelope: float = minf(note_time * 40.0, 1.0) * exp(-note_time * 5.0)
			value = sin(TAU * frequency * time) * envelope * 0.13
			value += sin(TAU * frequency * 2.0 * time) * envelope * 0.025
			var chord: float = 110.0 if time < 8.0 else 130.8128
			value += (sin(TAU * chord * time) + sin(TAU * chord * 1.5 * time)) * 0.03
			value *= minf(time * 4.0, 1.0) * minf((duration - time) * 4.0, 1.0)
		elif kind == "swing":
			value = sin(TAU * (1300.0 * time - 2300.0 * time * time)) * sin(time * 19379.0) * (1.0 - time / duration) * 0.4
		elif kind == "hit":
			value = (sin(TAU * (150.0 * time - 200.0 * time * time)) + sin(time * 32117.0) * 0.4) * exp(-time * 20.0) * 0.4
		else:
			for note: int in range(3):
				var since: float = time - float(note) * 0.13
				if since > 0.0:
					value += sin(TAU * [523.251, 659.255, 783.991][note] * since) * exp(-since * 5.0) * minf(since * 100.0, 1.0) * 0.2
		data.encode_s16(sample * 2, int(clampf(value, -0.95, 0.95) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	var result: Error = stream.save_to_wav(target.path_join(kind + ".wav"))
	if result != OK:
		push_error("音源保存失敗: %s" % result)
	return result == OK
