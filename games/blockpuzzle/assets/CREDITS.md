# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## コード描画 (`scripts/main.gd`、`scripts/board_view.gd`、`scripts/piece_sprite.gd`)

- **素材名**: 連鎖設計室の背景・盤面・4色ピース・予告ブロック・消去片・グラフ
- **作者**: godotpractice プロジェクト
- **入手 URL**: https://github.com/bannzai/godotpractice/tree/fix/blockpuzzle/games/blockpuzzle/scripts
- **ライセンス**: 本プロジェクト独自制作。第三者画像の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: SVG・PNG・画像生成サービス・既存作品の画像は不使用。実行時に ColorRect / Polygon2D を組み立て、Tween で動かす。
- **生成**: Codex による GDScript 記述 / プロンプトの要点: 明るい大余白に、珊瑚・青緑・黄・紫の単色正方形と円を置く。顔・輪郭線・グラデーションを使わず、数字とスコア折れ線を主役にする。4色と予告ブロックを形でも識別し、5動作を伸縮・移動・回転・退色で表す。

## オリジナル音声 (`assets/audio/`)

- **素材名**: 場面別旋律・データ環境音・操作音 (`ambient.wav`, `bgm_title.wav`, `bgm_play.wav`, `bgm_danger.wav`, `bgm_result.wav`, `move.wav`, `rotate.wav`, `land.wav`, `clear.wav`, `chain.wav`, `garbage.wav`, `victory.wav`, `defeat.wav`, `select.wav`)
- **作者**: godotpractice プロジェクト
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/fix/blockpuzzle/games/blockpuzzle/scripts/dev/generate_assets.py
- **ライセンス**: 本プロジェクト独自制作。第三者音源の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 22050 Hz・16 bit・モノラル PCM。BGM は残響を先頭へ折り返してループ。既存曲・録音・音声生成サービスは不使用。
- **生成**: Codex による作曲、Python 標準ライブラリの FM・倍音・打楽器合成 / プロンプトの要点: 静かなベルとパッドのタイトル、軽快な操作中のアルペジオ、不協和音を交えた速いピンチ、ゆったりした結果の旋律。移動・回転・着地・消去・連鎖・おじゃま・勝利・敗北の音色を区別し、低い持続音・周期的なデータ音の環境音とモード選択音を追加。

## フォント (`assets/fonts/`)

- **素材名**: Murecho (`Murecho[wght].ttf`, `OFL.txt`)
- **作者**: Copyright 2021 The Murecho Project Authors (https://github.com/positype/Murecho-Project)
- **入手 URL**: https://fonts.google.com/specimen/Murecho
- **ライセンス**: OFL-1.1
- **クレジット表記**: **必要**
- **改変**: Google Fonts の配布ファイル名のまま同梱。フォントデータの変更なし。
- **備考**: SIL Open Font License 1.1 と著作権表示を fonts/OFL.txt に保持。アプリ画面での帰属表記は要求されない。
