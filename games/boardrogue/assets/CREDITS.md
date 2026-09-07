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

- **素材名**: 墨将紀の場面別音楽・効果音 (`arrow.wav`, `battle.wav`, `blade.wav`, `boss.wav`, `card.wav`, `drum.wav`, `hit.wav`, `map.wav`, `result_loss.wav`, `result_win.wav`, `reward.wav`, `title.wav`, `river.wav`, `wind.wav`, `snow.wav`, `insects.wav`, `shakuhachi.wav`)
- **作者**: godotpractice
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/boardrogue/games/boardrogue/scripts/dev/generate_audio.py
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 scripts/dev/generate_audio.py --out-dir assets。同一バイト列なら書き直さない。
- **生成**: Python 標準ライブラリによる PCM 合成 / プロンプトの要点: 独自の旋律、撥弦・息・膜・金属の異なる倍音と減衰。タイトル・地図・戦闘・将軍・勝利・敗北の 6 曲、札・刀・矢・太鼓・被弾・報酬の 6 効果音。固定 seed の円環補間ノイズと整数周期の倍音で川・風・雪・虫の 4 環境音を作り、別の 3 音による息成分から尺八の合図を作った。既存曲・録音は使用していない。

## 水墨画・彩色の生成画像 (`assets/art/generated/`)

- **素材名**: タイトル絵、街道絵地図、河原・城内・雪原・夜陣の舞台、札12種、王と敵4人の肖像画（`campaign-map.png`, `card-blade.png`, `card-bow.png`, `card-dragon.png`, `card-drummer.png`, `card-fox.png`, `card-lancer.png`, `card-monk.png`, `card-oracle.png`, `card-reed.png`, `card-shield.png`, `card-veil.png`, `card-wraith.png`, `portrait-duelist.png`, `portrait-final.png`, `portrait-general.png`, `portrait-hero.png`, `portrait-scout.png`, `stage-castle.png`, `stage-night-camp.png`, `stage-river.png`, `stage-snow.png`, `title-key-art.png` の PNG 23点）
- **作者**: OpenAI の画像生成モデルを用いて godotpractice が生成
- **入手 URL**: なし（Codex の `image_gen` でプロジェクト専用に生成）
- **ライセンス**: 本プロジェクト独自の生成物。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: Godot 上で縮小・色調変化・和紙ノイズのシェーダを重ねる
- **備考**: 元ゲームの名称・画像・音・ロゴ・実在家紋は入力にも出力にも使用していない。生成結果は透明度、文字・ロゴの混入、輪郭の識別性、画面上の余白を目視した。
- **生成**: 共通要点は「表情のある水墨の筆致、墨のにじみとかすれ、控えめな岩絵具、生成りの和紙、墨黒・朱・古金、文字・ロゴ・透かし・現代物・実在家紋なし」。タイトルは旅人が霧の山城へ向かう横長絵、地図は河原・社・宿場・峠・雪道・夜陣・関所・天守を一本の街道で結ぶ俯瞰絵、舞台は中央に盤を重ねられる河原・城内・雪原・夜陣。札は葦の槍兵、朱の二刀、鉤縄の潜入者、月弓、星読み、泥の亡霊、鉄傘、暁の槍、灯守、陣太鼓、白狐、墨龍を、それぞれ全身の異なる輪郭と透明背景で生成。肖像は若い王、蓑の斥候、雨衣の剣将、黒鎧の大将、白灰の城主を正方形の胸像として生成した。

## 墨のにじみ・和紙の繊維・端のかすれ (`assets/shaders/`)

- **素材名**: 墨のにじみ・和紙の繊維・端のかすれ (`atmosphere.gdshader`)
- **作者**: godotpractice
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/boardrogue/games/boardrogue/assets/shaders/atmosphere.gdshader
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **生成**: Godot Shader Language による独自制作 / プロンプトの要点: GL Compatibility の CanvasItem 上で、低周波ノイズの墨のにじみ、高周波の紙繊維、画面端の不規則なかすれを半透明で重ねる。

## Zen Old Mincho (`assets/fonts/`)

- **素材名**: Zen Old Mincho (`ZenOldMincho-Regular.ttf`, `OFL.txt`)
- **作者**: Copyright 2021 The Zen Old Mincho Project Authors
- **入手 URL**: https://github.com/googlefonts/zen-oldmincho
- **ライセンス**: SIL Open Font License 1.1
- **クレジット表記**: **必要**
- **改変**: なし
- **備考**: games/deckrogue の同梱フォントを改変せず再利用。実著作権表示と OFL 全文を fonts/OFL.txt に保持。

## Yuji Syuku (`assets/fonts/`)

- **素材名**: Yuji Syuku (`YujiSyuku-Regular.ttf`, `OFL.txt`)
- **作者**: Copyright 2021 The Yuji Project Authors (https://github.com/Kinutafontfactory/Yuji)
- **入手 URL**: https://github.com/google/fonts/tree/main/ofl/yujisyuku
- **ライセンス**: SIL Open Font License 1.1
- **クレジット表記**: **必要**
- **改変**: なし
- **備考**: Google Fonts の公式配布ファイルを取得。Yuji Syuku と既存の Zen Old Mincho の実著作権表示、および OFL 全文を `fonts/OFL.txt` に保持。
