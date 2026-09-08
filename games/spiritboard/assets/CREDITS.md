# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## フォント (`assets/fonts/`)

- **素材名**: Zen Old Mincho Regular (`ZenOldMincho-Regular.ttf`, `OFL.txt`)
- **作者**: Copyright 2021 The Zen Old Mincho Project Authors
- **入手 URL**: https://github.com/googlefonts/zen-oldmincho
- **ライセンス**: SIL Open Font License 1.1
- **クレジット表記**: **必要**
- **改変**: なし
- **備考**: 既存 deckrogue の未改変フォントと著作権表示・ライセンス全文をコピー。OFL.txt を同梱。

## 独自画像 (`assets/art/`)

- **素材名**: 幽契の夜路の人物・霊・背景・道具 (`hero.svg`, `hero_sheet.svg`, `ghost.svg`, `ghost_sheet.svg`, `general.svg`, `general_sheet.svg`, `police.svg`, `police_sheet.svg`, `merchant.svg`, `merchant_sheet.svg`, `lantern.svg`, `lantern_sheet.svg`, `fox.svg`, `fox_sheet.svg`, `bell.svg`, `bell_sheet.svg`, `willow.svg`, `willow_sheet.svg`, `crow.svg`, `crow_sheet.svg`, `mask.svg`, `mask_sheet.svg`, `spider.svg`, `spider_sheet.svg`, `monk.svg`, `monk_sheet.svg`, `hound.svg`, `hound_sheet.svg`, `dragon.svg`, `dragon_sheet.svg`, `empress.svg`, `empress_sheet.svg`, `reaper.svg`, `reaper_sheet.svg`, `bg_sky.svg`, `bg_village.svg`, `bg_foreground.svg`, `node_battle.svg`, `node_boss.svg`, `node_grave.svg`, `node_hunt.svg`, `node_police.svg`, `node_rest.svg`, `node_merchant.svg`, `logo_mark.svg`, `title_keyart.svg`, `card_back.svg`, `card_frame.svg`, `card_frame_rare.svg`, `card_frame_epic.svg`, `prop_talisman.svg`, `prop_coin.svg`, `prop_grave.svg`, `fx_glow.svg`, `fx_spark.svg`, `icon_king.svg`, `icon_darkness.svg`, `icon_attack.svg`)
- **作者**: bannzai（Codex を用いた独自制作）
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/spiritboard/games/spiritboard/scripts/dev/generate_art.py
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 games/spiritboard/scripts/dev/generate_art.py。17キャラに各256×320・5種×6コマの独立シート。SVG 58点。タイトルのキーアートは人物・霊・朱印のみとし、月・樹木・鳥居は背景3層に描く。コマ境界検査: python3 games/spiritboard/scripts/dev/generate_art.py --check-frame-bounds（rsvg-convert・Pillow が必要）。
- **生成**: Python 標準ライブラリ (SVG コード生成) / プロンプトの要点: 青墨・古い和紙・くすんだ金・朱赤・青緑の霊光を共通配色とする和風ホラーの切り絵。旅人、霊、将軍、警官、商人と12種の霊を独立した輪郭で描く。待機・移動・行動・被弾・消失の部位変化、月夜・村・草木の多層背景、札・鏡・鈴・提灯の図案。既存作品は参照しない。

## 独自音声 (`assets/audio/`)

- **素材名**: 幽契の夜路の場面音楽と効果音 (`title.wav`, `map.wav`, `battle.wav`, `boss.wav`, `police.wav`, `result.wav`, `card.wav`, `attack.wav`, `voice.wav`, `acquire.wav`, `transition.wav`, `hit.wav`, `darkness.wav`, `heal.wav`, `victory.wav`)
- **作者**: bannzai（Codex を用いた独自制作）
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/spiritboard/games/spiritboard/scripts/dev/generate_audio.py
- **ライセンス**: 本プロジェクト独自制作。第三者音源・楽譜の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 games/spiritboard/scripts/dev/generate_audio.py。22050 Hz / 16 bit / stereo PCM。BGM 6場面・各8小節とSE 9種。音色の聴感評価は未実施。
- **生成**: Python 標準ライブラリ (倍音・ノイズ・PCM 合成) / プロンプトの要点: タイトルは息と尺八風の音色、地図は箏風の撥弦、戦闘は三味線風の反復と太鼓、ボスは低いリードと銅鑼、警察は木製打楽器の緊張した反復、結果は疎な下降ベル。札の擦過、攻撃の衝撃、霊の声、獲得ベル、暗転・闇の風、回復と勝利の鐘。固定乱数、左右定位と反射音。

## 画面テーマ

`scenes/ui/theme.tres` は本プロジェクト用に作成した独自Theme。青墨・和紙・金・朱の配色と、同梱するZen Old Minchoを使用する。第三者のUI画像やテーマは使用していない。

`scripts/ink_veil.gdshader` は独自の紙目と墨の陰影を描くCanvasItemシェーダ。外部のシェーダコードは使用していない。
