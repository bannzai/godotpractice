# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## 独自画像 (`assets/art/`)

- **素材名**: 宵森の灯守の図案 (`bolt.svg`, `enemy-0-sheet.svg`, `enemy-0.svg`, `enemy-1-sheet.svg`, `enemy-1.svg`, `enemy-2-sheet.svg`, `enemy-2.svg`, `enemy-3-sheet.svg`, `enemy-3.svg`, `floor.svg`, `forest-far.svg`, `forest-near.svg`, `gem.svg`, `heal.svg`, `icon-armor.svg`, `icon-clock.svg`, `icon-health.svg`, `icon-kills.svg`, `icon-pause.svg`, `icon-sound.svg`, `icon-speed.svg`, `key-art.svg`, `logo.svg`, `magnet.svg`, `mist.svg`, `orbit.svg`, `player-sheet.svg`, `player.svg`, `pulse.svg`, `spark.svg`, `title-emblem.svg`)
- **作者**: bannzai（Codexを利用）
- **入手 URL**: https://openai.com/policies/terms-of-use/
- **ライセンス**: プロジェクト独自生成物。第三者素材なし。第三者へのライセンス付与はしていない
- **クレジット表記**: **不要**
- **改変**: 品質向上ラウンドで再設計
- **備考**: 再生成: python3 scripts/dev/generate_assets.py。フォントの著作権とOFL全文は fonts/OFL.txt を参照。
- **生成**: Codexによるコード作成・PythonとfontToolsで決定的に生成 / プロンプトの要点: 青緑の夜森、金色の灯守、葉の精・蛾・石の巨獣・枝角の主。各体に5動作6フレーム、個別アイテムとUI図案、多層背景、キーアート。ロゴは同梱OFLフォントの輪郭から生成

## 独自音声 (`assets/audio/`)

- **素材名**: 宵森の旋律と効果音 (`attack.wav`, `bgm-boss.wav`, `bgm-play.wav`, `bgm-result.wav`, `bgm-title.wav`, `boss.wav`, `heal.wav`, `hurt.wav`, `level.wav`, `magnet.wav`, `pickup.wav`, `result.wav`, `ui.wav`)
- **作者**: bannzai（Codexを利用）
- **入手 URL**: https://openai.com/policies/terms-of-use/
- **ライセンス**: プロジェクト独自生成物。第三者素材なし。第三者へのライセンス付与はしていない
- **クレジット表記**: **不要**
- **改変**: 品質向上ラウンドで再設計
- **備考**: 再生成: python3 scripts/dev/generate_assets.py。フォントの著作権とOFL全文は fonts/OFL.txt を参照。
- **生成**: Codexによるコード作成・Python標準ライブラリで決定的に生成 / プロンプトの要点: 4場面の独自譜面。撥弦、木琴、ベル、倍音パッド、ベース、ノイズ打楽器と9種の効果音。外部旋律・録音サンプル不使用

## フォント (`assets/fonts/`)

- **素材名**: Zen Maru Gothic Medium (`font.ttf`, `OFL.txt`)
- **作者**: The Zen Maru Gothic Project Authors
- **入手 URL**: https://fonts.google.com/specimen/Zen+Maru+Gothic
- **ライセンス**: OFL-1.1
- **クレジット表記**: **必要**
- **改変**: ファイル名をZenMaruGothic-Medium.ttfからfont.ttfに変更。フォントデータは改変なし
- **備考**: Copyright 2021 The Zen Maru Gothic Project Authors (https://github.com/googlefonts/zen-marugothic)。取得先: https://raw.githubusercontent.com/google/fonts/main/ofl/zenmarugothic/ZenMaruGothic-Medium.ttf。著作権表示とライセンス全文をOFL.txtに同梱。

## UIテーマ (`assets/theme/`)

- **素材名**: 宵森のUIテーマ (`night.tres`)
- **作者**: bannzai（Codexを利用）
- **入手 URL**: https://openai.com/policies/terms-of-use/
- **ライセンス**: プロジェクト独自生成物。第三者素材なし。第三者へのライセンス付与はしていない
- **クレジット表記**: **不要**
- **改変**: 品質向上ラウンドで再設計
- **備考**: Godot Themeリソースとして記述。フォントの著作権とOFL全文は fonts/OFL.txt を参照。
- **生成**: CodexによるGodotリソース作成 / プロンプトの要点: night.tresに青緑・金色のボタン状態と同梱日本語フォントを統一
