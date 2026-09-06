# こもれびの調査隊 — 開発知見

## 実装方針

- オリジナルのモンスター収集RPG。町・草むらのルート・自宅・回復施設を歩き、捕獲と育成を経て町の調査隊長に挑む。
- 種族と技の定義は Catalog、進行状態と保存は Game autoload に集約する。画面は状態を表示し、戦闘イベントを順番に演出する。
- 現行 Godot の TileMapLayer と TileSetAtlasSource でグリッドを描画する。TileMap は非推奨のため、同じタイルマップの役割を TileMapLayer が担う。
  https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html
- 描画素材はオリジナルSVG、音源は独自合成、日本語フォントは同梱可能なOFLを採用する。

## 検証計画

純粋ロジック・保存の異常入力・実シーン操作を selfcheck で検証し、代表画面と攻撃中の画像を撮影する。ローカルとCIの動画をフレーム抽出して確認し、デスクトップ3種とWebをエクスポートする。

## 判断点

現時点でユーザーの判断が必要な未確定事項はない。実測した知見と検証結果は実装後に追記する。
