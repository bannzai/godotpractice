# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## キャラクター (`assets/characters/`)

- **素材名**: 灯守りと地下の生き物 (`archer.svg`, `boss.svg`, `chaser.svg`, `hero.svg`, `sleeper.svg`, `splitter.svg`, `swift.svg`)
- **作者**: godotpractice プロジェクト
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/main/games/roguelike/scripts/dev/generate_art.py
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 外部画像生成サービス・既存作品・既存録音は使用していない。再生成: python3 scripts/dev/generate_art.py。
- **生成**: Codex による独自記述、Python と SVG / プロンプトの要点: 灯火とマントの主人公、甲虫、弓の骸骨、胞子粘体、石像、蛾、角と巨大灯芯の番人を独立したシルエットで描く。濃紺・青緑・琥珀金の 96 px SVG。

## アイテム (`assets/items/`)

- **素材名**: 遺跡の道具 (`coin.svg`, `food.svg`, `herb.svg`, `scroll_fire.svg`, `scroll_warp.svg`, `shield.svg`, `stairs.svg`, `wand.svg`, `weapon.svg`)
- **作者**: godotpractice プロジェクト
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/main/games/roguelike/scripts/dev/generate_art.py
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 外部画像生成サービス・既存作品・既存録音は使用していない。再生成: python3 scripts/dev/generate_art.py。
- **生成**: Codex による独自記述、Python と SVG / プロンプトの要点: 剣・盾・薬草・携行食・炎と転移の巻物・杖・階段・金貨を独立した 64 px SVG にする。

- **素材名**: 強化装備の独立画像 (`sunblade.svg`, `ironshield.svg`)
- **作者**: godotpractice プロジェクト
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/main/games/roguelike/scripts/dev/generate_art.py
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 外部画像生成サービス・既存作品は使用していない。再生成: python3 scripts/dev/generate_art.py。
- **生成**: Codex による独自記述、Python と SVG / プロンプトの要点: 暁の剣は二股の金刃と太陽形の鍔。古鉄の盾は大型の菱形金属盾と鋲。通常装備と輪郭で区別できる独立した64px SVG。

## 地形 (`assets/tiles/`)

- **素材名**: 地下遺跡の石畳と壁 (`floor.svg`, `wall.svg`)
- **作者**: godotpractice プロジェクト
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/main/games/roguelike/scripts/dev/generate_art.py
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 外部画像生成サービス・既存作品・既存録音は使用していない。再生成: python3 scripts/dev/generate_art.py。
- **生成**: Codex による独自記述、Python と SVG / プロンプトの要点: 青緑の石畳と古い切石の壁。64 px SVG。

## 多層背景 (`assets/backgrounds/`)

- **素材名**: 灯守りの深層の地下門 (`title_back.svg`, `title_front.svg`, `title_middle.svg`)
- **作者**: godotpractice プロジェクト
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/main/games/roguelike/scripts/dev/generate_art.py
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 外部画像生成サービス・既存作品・既存録音は使用していない。再生成: python3 scripts/dev/generate_art.py。
- **生成**: Codex による独自記述、Python と SVG / プロンプトの要点: 1280×720。星塵と遠方の尖頭アーチ、地下門と柱と階段、主人公と手前の岩を 3 層へ分ける。

## タイトル装飾 (`assets/ui/`)

- **素材名**: 灯守りの深層のロゴと菱形装飾 (`logo.svg`, `ornament.svg`)
- **作者**: godotpractice プロジェクト
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/main/games/roguelike/scripts/dev/generate_art.py
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 外部画像生成サービス・既存作品・既存録音は使用していない。再生成: python3 scripts/dev/generate_art.py。ロゴの文字輪郭は SIL OFL 1.1 のフォントから作成。
- **生成**: Codex による独自記述、Python と SVG / プロンプトの要点: 琥珀金の日本語タイトルと青緑の宝石。ロゴの文字は同梱 OFL フォントの輪郭を SVG に変換。

## 音楽と効果音 (`assets/audio/`)

- **素材名**: 八つの場面の旋律と七つの操作音 (`boss.wav`, `death.wav`, `floor1.wav`, `floor2.wav`, `floor3.wav`, `floor4.wav`, `floor5.wav`, `hit.wav`, `hurt.wav`, `level.wav`, `pickup.wav`, `result.wav`, `select.wav`, `stairs.wav`, `title.wav`)
- **作者**: godotpractice プロジェクト
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/main/games/roguelike/scripts/dev/generate_audio.py
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 外部画像生成サービス・既存作品・既存録音は使用していない。再生成: python3 scripts/dev/generate_audio.py。
- **生成**: Codex による独自作曲、Python 標準ライブラリ / プロンプトの要点: タイトル・各 5 階・ボス・結果で主楽器、旋律、調と速度を変える。倍音・FM の鐘・撥弦・リード・パッド・低音・ノイズの打楽器を合成。攻撃・被弾・成長・階段・取得・選択・消滅の効果音。

## 日本語フォント (`assets/fonts/`)

- **素材名**: Noto Sans JP (`NotoSansJP.ttf`, `OFL.txt`)
- **作者**: Adobe（2014–2021）
- **入手 URL**: https://fonts.google.com/specimen/Noto+Sans+JP
- **ライセンス**: SIL Open Font License 1.1
- **クレジット表記**: **必要**
- **改変**: ファイル名のみ変更。フォントデータは変更なし
- **備考**: 既存 games/cardbattle/assets/fonts から同一のフォントとライセンス全文をコピー。OFL.txt を同梱する。

探索時の霧は `scripts/atmosphere.gdshader` に記述した独自のGL Compatibility対応シェーダ。手続き的な濃淡と時間変化のみで、外部画像を使用していない。
