extends RefCounted
## 録画・撮影・入力検証の終了前に音声を止める。停止後は呼び出し側で約0.2秒待ち、
## WAV の再生状態がミキサーに残ったまま終了することによるリークを避ける。


## stop_audio() を持つノードに委ね、それ以外は子の音声プレイヤーを停止する。
## 繰り返し呼んでも音声は停止した状態を保つ。
static func stop(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node.has_method("stop_audio"):
		node.call("stop_audio")
		return
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.stop()
		node.stream = null
	for child: Node in node.get_children():
		stop(child)
