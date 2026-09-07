# 素材クレジット

## Puny World Tileset

- 素材名: 16x16 Puny World Tileset (`source/punyworld-overworld-tileset_0.png`)
- 作者: Shade
- 入手 URL: https://opengameart.org/content/16x16-puny-world-tileset
- ライセンス: CC0-1.0。クレジット表記は不要
- 改変: 16px単位で切り出し、地域別8色パレットへ再着色し、nearest-neighborで拡大。地形、屋外の小物・景観、背景の主要形状に使用

## Puny Dungeon Tileset

- 素材名: 16x16 Puny Dungeon Tileset (`source/punyworld-dungeon-tileset.png`)
- 作者: Shade
- 入手 URL: https://opengameart.org/content/16x16-puny-dungeon-tileset
- ライセンス: CC0-1.0。クレジット表記は不要
- 改変: 16px単位で切り出し、遺跡用8色パレットへ再着色し、nearest-neighborで拡大。石床、遺跡の小物・景観に使用

## Puny Characters

- 素材名: Puny Characters (`source/puny-charactersorcs_included.zip`)
- 作者: Shade
- 入手 URL: https://opengameart.org/content/puny-characters
- ライセンス: CC0-1.0。クレジット表記は不要
- 改変: ZIP内の Warrior、Mage、Archer、Human Worker、Orc、Slime の画像を32pxセルから切り出し、地域別8色パレットへ再着色。56pxセルへnearest-neighborで拡大し、各キャラクターの idle / walk / action / hurt / death を4フレームずつ構成

## 再着色したゲーム画像

- 素材名: 灯守の島の地域別ピクセル画像
- 原作者: Shade。加工用スクリプトの作者は bannzai（Codexを利用）
- 元素材 URL: https://opengameart.org/content/16x16-puny-world-tileset 、https://opengameart.org/content/16x16-puny-dungeon-tileset 、https://opengameart.org/content/puny-characters
- ライセンス: 元素材と加工画像はいずれも CC0-1.0。クレジット表記は不要
- 改変: `scripts/dev/generate_pixel_assets.py` で元素材の切り出し、5系統の各8色パレットへの再着色、nearest-neighbor拡大、背景の合成を決定的に実行。各画像の元ファイル・切り出し範囲・ZIP内ファイル・SHA-256・色数は `palettes.json` に記録
- 生成物:
  - characters: `boss.png`, `charger.png`, `hero.png`, `merchant.png`, `ranger.png`, `splitter.png`, `villager.png`, `wanderer.png`
  - terrain: `tiles.png`
  - props: `block.png`, `bomb.png`, `boomerang.png`, `chest.png`, `coin.png`, `door.png`, `grass.png`, `heart.png`, `key.png`, `potion.png`, `rock.png`, `switch.png`, `treasure.png`
  - scenery: `arch.png`, `column.png`, `crystals.png`, `house.png`, `lily.png`, `ruins.png`, `stall.png`, `tree.png`
  - backgrounds: `distant.png`, `foreground.png`, `hero-keyart.png`, `middle.png`, `title.png`
- 生成記録: `palettes.json`

## 独自生成した音声

- 素材名: 灯守の島のBGM・効果音・地域環境音
- 作者: bannzai（Codexを利用）
- 入手 URL: https://openai.com/policies/terms-of-use/
- ライセンス: プロジェクト独自生成物。第三者素材なし。クレジット表記は不要
- 改変: なし
- 生成物: `boss.wav`, `chest.wav`, `coast.wav`, `defeat.wav`, `door.wav`, `dungeon.wav`, `field.wav`, `forest.wav`, `hurt.wav`, `marsh.wav`, `result.wav`, `ruins.wav`, `sword.wav`, `title.wav`, `tool.wav`
- 生成: `scripts/dev/generate_assets.py` とPython標準ライブラリによる決定的な加算合成。プロンプトの要点は、少ない波形と短い反復で表現する携帯ゲーム機風の旋律・効果音、海岸の波、森の葉擦れ、湿地の水音、遺跡の低い風。外部録音・外部旋律は不使用

## 日本語フォント

- 素材名: Stick (`Stick-Regular.ttf`, `OFL.txt`)
- 作者: The Stick Project Authors
- 入手 URL: https://fonts.google.com/specimen/Stick
- ライセンス: SIL Open Font License 1.1。著作権表示とライセンス全文の同梱が必要
- クレジット表記: `OFL.txt` をゲームの配布物へ同梱
- 改変: ファイル名・フォントデータともに改変なし
- 備考: Copyright 2020 The Stick Project Authors (https://github.com/fontworks-fonts/Stick)
