# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## 墨将紀の人物・背景・札・道の紋章 (`assets/art/`)

- **素材名**: 墨将紀の人物・背景・札・道の紋章 (`bg_foreground.svg`, `bg_landscape.svg`, `bg_sky.svg`, `blade.svg`, `blade_sheet.svg`, `bow.svg`, `bow_sheet.svg`, `card_back.svg`, `dragon.svg`, `dragon_sheet.svg`, `drummer.svg`, `drummer_sheet.svg`, `duelist.svg`, `duelist_sheet.svg`, `final.svg`, `final_sheet.svg`, `fox.svg`, `fox_sheet.svg`, `fx_glow.svg`, `fx_ink.svg`, `fx_spark.svg`, `general.svg`, `general_sheet.svg`, `hero.svg`, `hero_sheet.svg`, `icon_attack.svg`, `icon_card.svg`, `icon_coin.svg`, `icon_health.svg`, `lancer.svg`, `lancer_sheet.svg`, `logo_mark.svg`, `merchant.svg`, `merchant_sheet.svg`, `monk.svg`, `monk_sheet.svg`, `oracle.svg`, `oracle_sheet.svg`, `reed.svg`, `reed_sheet.svg`, `rest.svg`, `rest_sheet.svg`, `route_battle.svg`, `route_final.svg`, `route_general.svg`, `route_merchant.svg`, `route_rest.svg`, `route_reward.svg`, `scout.svg`, `scout_sheet.svg`, `shield.svg`, `shield_sheet.svg`, `title_keyart.svg`, `veil.svg`, `veil_sheet.svg`, `wraith.svg`, `wraith_sheet.svg`)
- **作者**: godotpractice
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/boardrogue/games/boardrogue/scripts/dev/generate_art.py
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 scripts/dev/generate_art.py --out-dir assets。同一バイト列なら書き直さない。
- **生成**: Python 標準ライブラリによる SVG 生成 / プロンプトの要点: 19 種の人物・妖を武具・輪郭・冠・衣で描き分ける。5 動作を各 4 コマ、墨黒・生成り・朱・青磁・金の配色。固定 seed で鎧の細線・山・城・松・霧を描く。

## 墨将紀の場面別音楽・効果音 (`assets/audio/`)

- **素材名**: 墨将紀の場面別音楽・効果音 (`arrow.wav`, `battle.wav`, `blade.wav`, `boss.wav`, `card.wav`, `drum.wav`, `hit.wav`, `map.wav`, `result_loss.wav`, `result_win.wav`, `reward.wav`, `title.wav`)
- **作者**: godotpractice
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/boardrogue/games/boardrogue/scripts/dev/generate_audio.py
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 scripts/dev/generate_audio.py --out-dir assets。同一バイト列なら書き直さない。
- **生成**: Python 標準ライブラリによる PCM 合成 / プロンプトの要点: 独自の旋律、撥弦・息・膜・金属の異なる倍音と減衰。タイトル・地図・戦闘・将軍・勝利・敗北の 6 曲、札・刀・矢・太鼓・被弾・報酬の 6 効果音。

## 背景の霧 (`assets/shaders/`)

- **素材名**: 背景の霧 (`atmosphere.gdshader`)
- **作者**: godotpractice
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/boardrogue/games/boardrogue/assets/shaders/atmosphere.gdshader
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **生成**: GDScript / Godot Shader Language による独自制作 / プロンプトの要点: GL Compatibility の CanvasItem 上でノイズの重ね合わせと透過により漂う霧を描く。

## Zen Old Mincho (`assets/fonts/`)

- **素材名**: Zen Old Mincho (`ZenOldMincho-Regular.ttf`, `OFL.txt`)
- **作者**: Copyright 2021 The Zen Old Mincho Project Authors
- **入手 URL**: https://github.com/googlefonts/zen-oldmincho
- **ライセンス**: SIL Open Font License 1.1
- **クレジット表記**: **必要**
- **改変**: なし
- **備考**: games/deckrogue の同梱フォントを改変せず再利用。実著作権表示と OFL 全文を fonts/OFL.txt に保持。
