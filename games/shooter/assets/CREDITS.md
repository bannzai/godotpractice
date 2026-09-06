# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## フォント (`assets/fonts/`)

- **素材名**: Noto Sans JP (`NotoSansJP.ttf`, `OFL.txt`)
- **作者**: Adobe（Copyright 2014–2021）
- **入手 URL**: https://fonts.google.com/specimen/Noto+Sans+JP
- **ライセンス**: SIL Open Font License 1.1
- **クレジット表記**: **必要**
- **改変**: ファイル名を NotoSansJP[wght].ttf から NotoSansJP.ttf に変更。フォント本体は未改変。
- **備考**: 著作権表示・Reserved Font Name Source・ライセンス全文を fonts/OFL.txt に保持。フォント単体の販売不可。

## 画像 (`assets/sprites/`)

- **素材名**: 独自の宇宙戦闘機・弾・アイテム (`player.svg`, `enemy_scout.svg`, `enemy_fighter.svg`, `enemy_carrier.svg`, `boss.svg`, `bullet_player.svg`, `bullet_enemy.svg`, `item_power.svg`, `item_bomb.svg`)
- **作者**: 本プロジェクト（Codex による制作支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト向け新規制作物。第三者素材・サンプル音源を使用していない。独立した CC0 宣言は行っていない。
- **クレジット表記**: **不要**
- **改変**: 新規制作
- **備考**: 編集可能な SVG コードを同梱。外部の画像生成 API・既存作品素材は未使用。
- **生成**: SVG コードの直接記述 / プロンプトの要点: 青緑の自機、赤・橙・紫の敵と大型ボス。幾何学形状で構成した独自の SF 図案。

## 背景 (`assets/backgrounds/`)

- **素材名**: 独自の星空背景 (`space.svg`)
- **作者**: 本プロジェクト（Codex による制作支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト向け新規制作物。第三者素材・サンプル音源を使用していない。独立した CC0 宣言は行っていない。
- **クレジット表記**: **不要**
- **改変**: 新規制作
- **備考**: 編集可能な SVG コードを同梱。外部の画像生成 API・既存作品素材は未使用。
- **生成**: SVG コードの直接記述 / プロンプトの要点: 固定シードの星配置と青い星雲を SVG の図形で構成。

## UI (`assets/ui/`)

- **素材名**: 独自の情報パネル (`panel.svg`)
- **作者**: 本プロジェクト（Codex による制作支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト向け新規制作物。第三者素材・サンプル音源を使用していない。独立した CC0 宣言は行っていない。
- **クレジット表記**: **不要**
- **改変**: 新規制作
- **備考**: 編集可能な SVG コードを同梱。外部の画像生成 API・既存作品素材は未使用。
- **生成**: SVG コードの直接記述 / プロンプトの要点: 濃紺の面と青緑の角飾り。文字や既存作品のロゴを含まない。

## 音声 (`assets/audio/`)

- **素材名**: 独自の BGM・効果音 (`stage.ogg`, `boss.ogg`, `shot.wav`, `explosion.wav`, `item.wav`, `bomb.wav`)
- **作者**: 本プロジェクト（Codex による制作支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト向け新規制作物。第三者素材・サンプル音源を使用していない。独立した CC0 宣言は行っていない。
- **クレジット表記**: **不要**
- **改変**: 新規制作
- **備考**: 再生成: python3 scripts/dev/generate_audio.py。外部の生成 API・音声素材は未使用。
- **生成**: Python 標準ライブラリによる波形合成 + ffmpeg Vorbis エンコード / プロンプトの要点: 固定シードのノイズ・正弦波・独自譜面から生成。ステージ 16 秒、ボス約 13.33 秒のループと効果音 4 種。
