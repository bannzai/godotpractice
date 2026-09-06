# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## 独自画像 (`assets/art/`)

- **素材名**: 宵森の灯守の図案 (`floor.svg`, `player.svg`, `enemy-0.svg`, `enemy-1.svg`, `enemy-2.svg`, `enemy-3.svg`, `gem.svg`, `heal.svg`, `magnet.svg`, `bolt.svg`, `orbit.svg`, `pulse.svg`, `title-emblem.svg`)
- **作者**: bannzai（Codexを利用）
- **入手 URL**: https://openai.com/policies/terms-of-use/
- **ライセンス**: 独自生成物。OpenAI規約のOutput帰属に従い利用者が権利を保有。第三者素材なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 scripts/dev/generate_assets.py。第三者へのライセンス付与はしていない。
- **生成**: CodexでSVGコードを作成・Python標準ライブラリで保存 / プロンプトの要点: 独自の青緑の森、金色のランタンを持つ灯守、紫の精霊・赤い蛾・苔獣・巨大怪物、ミント色の魔法。既存作品は参照しない

## 独自音声 (`assets/audio/`)

- **素材名**: 宵森の旋律と効果音 (`bgm.wav`, `attack.wav`, `hurt.wav`, `level.wav`, `pickup.wav`)
- **作者**: bannzai（Codexを利用）
- **入手 URL**: https://openai.com/policies/terms-of-use/
- **ライセンス**: 独自生成物。OpenAI規約のOutput帰属に従い利用者が権利を保有。第三者音源なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 scripts/dev/generate_assets.py。PCM16 22050Hz。第三者へのライセンス付与はしていない。
- **生成**: CodexでPythonコードを作成・Python標準ライブラリで波形合成 / プロンプトの要点: 独自の短い音列と正弦波で24秒の幻想的なループ、控えめな攻撃・被弾・成長・取得音を合成

## フォント (`assets/fonts/`)

- **素材名**: Zen Maru Gothic Medium (`font.ttf`, `OFL.txt`)
- **作者**: The Zen Maru Gothic Project Authors
- **入手 URL**: https://fonts.google.com/specimen/Zen+Maru+Gothic
- **ライセンス**: OFL-1.1
- **クレジット表記**: **必要**
- **改変**: ファイル名をZenMaruGothic-Medium.ttfからfont.ttfに変更。フォントデータは改変なし
- **備考**: Copyright 2021 The Zen Maru Gothic Project Authors (https://github.com/googlefonts/zen-marugothic)。取得先: https://raw.githubusercontent.com/google/fonts/main/ofl/zenmarugothic/ZenMaruGothic-Medium.ttf。著作権表示とライセンス全文をOFL.txtに同梱。
