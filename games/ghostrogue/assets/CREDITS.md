# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## 独自制作の画像 (`assets/art/`)

- **素材名**: 夜を継ぐ者の霊・背景・ロゴ・アイコン (`beast.svg`, `beast_body.svg`, `beast_detail.svg`, `bell.svg`, `bell_body.svg`, `bell_detail.svg`, `boss.svg`, `boss_body.svg`, `boss_detail.svg`, `bride.svg`, `bride_body.svg`, `bride_detail.svg`, `child.svg`, `child_body.svg`, `child_detail.svg`, `crow.svg`, `crow_body.svg`, `crow_detail.svg`, `doll.svg`, `doll_body.svg`, `doll_detail.svg`, `flashlight.svg`, `fog.svg`, `fox.svg`, `fox_body.svg`, `fox_detail.svg`, `graveyard_far.svg`, `graveyard_near.svg`, `headless.svg`, `headless_body.svg`, `headless_detail.svg`, `hero_0.svg`, `hero_0_body.svg`, `hero_0_detail.svg`, `hero_1.svg`, `hero_1_body.svg`, `hero_1_detail.svg`, `hero_2.svg`, `hero_2_body.svg`, `hero_2_detail.svg`, `hero_3.svg`, `hero_3_body.svg`, `hero_3_detail.svg`, `house_far.svg`, `house_near.svg`, `icon_battle.svg`, `icon_boss.svg`, `icon_darkness.svg`, `icon_grave.svg`, `icon_item.svg`, `icon_living.svg`, `icon_police.svg`, `icon_rest.svg`, `icon_spirit.svg`, `icon_story.svg`, `keyart.svg`, `logo.svg`, `monk.svg`, `monk_body.svg`, `monk_detail.svg`, `moth.svg`, `moth_body.svg`, `moth_detail.svg`, `night_sky.svg`, `police.svg`, `police_body.svg`, `police_detail.svg`, `spark.svg`, `town_far.svg`, `town_near.svg`, `warrior.svg`, `warrior_body.svg`, `warrior_detail.svg`, `water.svg`, `water_body.svg`, `water_detail.svg`)
- **作者**: godotpractice
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/ghostrogue/games/ghostrogue/scripts/dev/generate_art.py
- **ライセンス**: 本プロジェクト独自制作。フォント以外の第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 scripts/dev/generate_art.py --out-dir assets。ロゴ文字のフォントは下記OFLに従う。既存作品の固有画像を参照しない。
- **生成**: Python / SVG / fontTools / プロンプトの要点: 墨紺・灰青・古紙・朱の配色。12霊と主人公4段階・警官・大霊を固有の輪郭で描く。可動部位を本体から分離。ロゴ文字の輪郭のみ同梱Zen Old Minchoから取得。

## 独自制作の音声 (`assets/audio/`)

- **素材名**: 夜の町の六つの循環伴奏と効果音 (`acquire.wav`, `attack.wav`, `battle.wav`, `boss.wav`, `dissolve.wav`, `heal.wav`, `heartbeat.wav`, `hurt.wav`, `map.wav`, `police.wav`, `result.wav`, `select.wav`, `siren.wav`, `spirit.wav`, `step.wav`, `title.wav`, `transition.wav`)
- **作者**: godotpractice
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/ghostrogue/games/ghostrogue/scripts/dev/generate_audio.py
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 scripts/dev/generate_audio.py --out-dir assets。22,050Hz・16bit・ステレオ。ループ残響は先頭へ折り返す。既存曲や録音は参照しない。
- **生成**: Python 標準ライブラリ / PCM 合成 / プロンプトの要点: 鈴の非整数倍音・撥弦・息の雑音・太鼓の減衰を合成し、場面ごとに独自の音列・テンポ・楽器構成を変える。

## 日本語フォント (`assets/fonts/`)

- **素材名**: Zen Old Mincho Regular (`ZenOldMincho-Regular.ttf`, `OFL.txt`)
- **作者**: The Zen Old Mincho Project Authors
- **入手 URL**: https://github.com/googlefonts/zen-oldmincho
- **ライセンス**: SIL Open Font License 1.1
- **クレジット表記**: **必要**
- **改変**: なし
- **備考**: Copyright 2021 The Zen Old Mincho Project Authors。フォントと著作権表示・OFL全文を同梱。既存deckrogueに導入済みのファイルを改変せず複製。

## 独自制作のUI (`assets/ui/`)

- **素材名**: 夜を継ぐ者の画面テーマ (`night.tres`)
- **作者**: godotpractice
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/ghostrogue/games/ghostrogue/assets/ui/night.tres
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **生成**: Godot Theme / 手書き / プロンプトの要点: 墨紺のパネル、古紙色の文字、朱の押下と金のフォーカス枠。
