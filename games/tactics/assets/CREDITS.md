# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## 独自素材 (units) (`assets/units/`)

- **素材名**: 暁の境界 キャラクターと武器 (`archer.svg`, `archer_body.svg`, `archer_weapon.svg`, `axe.svg`, `axe_body.svg`, `axe_weapon.svg`, `boss.svg`, `boss_body.svg`, `boss_weapon.svg`, `bow.svg`, `bow_body.svg`, `bow_weapon.svg`, `enemy_lance.svg`, `enemy_lance_body.svg`, `enemy_lance_weapon.svg`, `enemy_sword.svg`, `enemy_sword_body.svg`, `enemy_sword_weapon.svg`, `healer.svg`, `healer_body.svg`, `healer_weapon.svg`, `lance.svg`, `lance_body.svg`, `lance_weapon.svg`, `raider.svg`, `raider_body.svg`, `raider_weapon.svg`, `sword.svg`, `sword_body.svg`, `sword_weapon.svg`)
- **作者**: bannzai（Codexを用いた独自制作）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト用の独自制作物（第三者素材を使用していない）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 games/tactics/scripts/art/generate_art.py
- **生成**: Codexによるコード記述、Python標準ライブラリによる決定的生成 / プロンプトの要点: 剣士、盾を持つ槍兵、大柄な斧兵、フード弓兵、白い法衣の回復役、角兜の略奪兵、羽兜と覆面の反曲弓射手、冠甲冑の指揮官、尖兜と曲刀の敵剣士、大盾と長槍の敵槍兵。全10種の本体と武器を分離しアニメーションする。

## 独自素材 (backgrounds) (`assets/backgrounds/`)

- **素材名**: 暁の境界 多層背景とキーアート (`foreground.svg`, `keyart.svg`, `mountains.svg`, `sky.svg`)
- **作者**: bannzai（Codexを用いた独自制作）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト用の独自制作物（第三者素材・楽譜を使用していない）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 games/tactics/scripts/art/generate_art.py
- **生成**: Codexによるコード記述、Python標準ライブラリによる決定的生成 / プロンプトの要点: 深紺と翡翠、金の夜明け。空、遠山と谷に架かる橋と塔、手前の樹木。三人の旅人を右側に配した独自の構図。

## 独自素材 (terrain) (`assets/terrain/`)

- **素材名**: 暁の境界 戦術盤の地形 (`forest.svg`, `fort.svg`, `mountain.svg`, `plain.svg`, `water.svg`)
- **作者**: bannzai（Codexを用いた独自制作）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト用の独自制作物（第三者素材・楽譜を使用していない）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 games/tactics/scripts/art/generate_art.py
- **生成**: Codexによるコード記述、Python標準ライブラリによる決定的生成 / プロンプトの要点: 平原、森林、山、水域、砦を独立画像で描き分ける。

## 独自素材 (ui) (`assets/ui/`)

- **素材名**: 暁の境界 UI装飾 (`crest.svg`, `cursor.svg`, `panel.svg`, `potion.svg`)
- **作者**: bannzai（Codexを用いた独自制作）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト用の独自制作物（第三者素材・楽譜を使用していない）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 games/tactics/scripts/art/generate_art.py
- **生成**: Codexによるコード記述、Python標準ライブラリによる決定的生成 / プロンプトの要点: 八方向の境界紋章、翡翠の回復薬、金の四隅カーソル、紺と金のパネル。

## 独自素材 (audio) (`assets/audio/`)

- **素材名**: 暁の境界 BGM・環境音・効果音 (`ambience.ogg`, `attack.ogg`, `battle.ogg`, `confirm.ogg`, `fan.ogg`, `heal.ogg`, `level.ogg`, `result.ogg`, `stage.ogg`, `title.ogg`)
- **作者**: bannzai（Codexを用いた独自制作）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト用の独自制作物（第三者素材・楽譜を使用していない）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 games/tactics/scripts/art/generate_audio.py
- **生成**: Codexによるコード記述、Python標準ライブラリによる決定的生成、ffmpeg Ogg Vorbis変換 / プロンプトの要点: タイトル、出撃、戦闘、結果の四曲。独自旋律の笛、撥弦、持続弦、ベルと打楽器を倍音合成し左右定位を与える。風・水・遠い鈴の環境音、和紙と扇骨が開く音、攻撃・回復・成長・決定の効果音。

## フォント (`assets/fonts/`)

- **素材名**: Shippori Mincho B1 (`ShipporiMinchoB1-Regular.ttf`, `ShipporiMinchoB1-SemiBold.ttf`, `OFL.txt`)
- **作者**: Copyright 2021 The Shippori Mincho Project Authors (https://github.com/fontdasu/ShipporiMincho)
- **入手 URL**: https://fonts.google.com/specimen/Shippori+Mincho+B1
- **ライセンス**: SIL Open Font License 1.1
- **クレジット表記**: **必要**
- **改変**: なし
- **備考**: Google Fontsから取得。著作権表示とライセンス全文をfonts/OFL.txtへ同梱し、全export presetのinclude_filterへ含める

## 独自シェーダ (`assets/shaders/`)

- **素材名**: 暁の境界 谷の薄霧 (`atmosphere.gdshader`)
- **作者**: bannzai（Codexを用いた独自制作）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト用の独自制作物（第三者素材を使用していない）
- **クレジット表記**: **不要**
- **改変**: なし
- **生成**: CodexによるGodotシェーダ記述 / プロンプトの要点: 深紺と翡翠の谷に漂う低速の薄霧と淡い金の光。最大透明度0.075、GL Compatibility対応。

- **素材名**: 金雲と人物の金縁 (`gold_clouds.gdshader`, `gold_outline.gdshader`)
- **作者**: bannzai（Codexを用いた独自制作）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト用の独自制作物（第三者素材を使用していない）
- **クレジット表記**: **不要**
- **改変**: なし
- **生成**: CodexによるGodotシェーダ記述 / プロンプトの要点: GL Compatibility向けCanvasItem。和紙の繊維、四曲屏風の折り目、すやり霞の金縁を背景へ重ね、透過人物画の外周へ解像度追従の金線を描く。

## 画像生成による大和絵 (`assets/generated/`)

- **素材名**: 屏風絵の人物画と地形絵 (`allies-atlas.png`, `enemies-atlas.png`, `yamato-landscape.png`)
- **作者**: bannzai（OpenAI built-in image generationを使用）
- **入手 URL**: https://openai.com/policies/services-agreement/
- **ライセンス**: OpenAI利用規約の範囲で本プロジェクトが利用する生成物。第三者素材を入力に使用していない
- **クレジット表記**: **不要**
- **改変**: 敵兵アトラスのみ背景抽出で市松模様を透明alphaへ置換。拡縮・クロマキー加工なし
- **備考**: 人物アトラスはGodotのAtlasTextureで領域参照し、生成PNG自体は後加工していない。四隅alphaをImageMagickで検査済み
- **生成**: OpenAI built-in image_gen / プロンプトの要点: 大和絵・屏風・平面的な全身人物・墨線・鉱物顔料・金箔。味方5兵種と敵5兵種を横一列の透過人物画にし、俯瞰の平原・森・山・川・砦を金雲入りの横長地形絵にした。既存作品名や原作素材は指定していない
