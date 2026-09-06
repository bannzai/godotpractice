# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## 画像 (`assets/images/`)

- **素材名**: 空の配達人のオリジナル画像 (`player.svg`, `walker.svg`, `shell.svg`, `coin.svg`, `power.svg`, `ground.svg`, `underground.svg`, `item_block.svg`, `cloud.svg`, `crystal.svg`, `goal.svg`, `logo.svg`)
- **作者**: 本プロジェクトで制作
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/platformer/games/platformer/scripts/dev/generate_assets.py
- **ライセンス**: 本プロジェクトのオリジナル生成素材。第三者素材は含まない
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 外部画像生成サービスは不使用。CC0 として扱わず、生成コードとともに本プロジェクトへ同梱する。
- **生成**: Codex による SVG コード作成・Python 標準ライブラリ / プロンプトの要点: 空の配達人、浮島草原と青い結晶地下。温かい色のベクター画。既存作品の名称や画像を使わない

## 音楽と効果音 (`assets/audio/`)

- **素材名**: 空の配達人のオリジナル音声 (`stage1.wav`, `stage2.wav`, `jump.wav`, `stomp.wav`, `coin.wav`, `power.wav`, `death.wav`, `clear.wav`)
- **作者**: 本プロジェクトで制作
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/platformer/games/platformer/scripts/dev/generate_assets.py
- **ライセンス**: 本プロジェクトのオリジナル生成素材。第三者素材は含まない
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 既存曲・録音・サンプルを使用せず正弦波から合成。CC0 として扱わず、生成コードとともに本プロジェクトへ同梱する。
- **生成**: Codex による作曲コード作成・Python math/wave による PCM 合成 / プロンプトの要点: 草原の明るい旋律と地下の静かな旋律、ジャンプ・踏む・収集・強化・ミス・クリアの短い効果音

## フォント (`assets/fonts/`)

- **素材名**: Noto Sans JP (`NotoSansJP[wght].ttf`, `OFL.txt`)
- **作者**: Adobe（Copyright 2014-2021 Adobe）
- **入手 URL**: https://fonts.google.com/specimen/Noto+Sans+JP
- **ライセンス**: SIL Open Font License 1.1
- **クレジット表記**: **必要**
- **改変**: なし
- **備考**: Google Fonts の ofl/notosansjp より取得。フォント固有の著作権表示、Reserved Font Name Source、OFL 全文を OFL.txt に保持。ライセンス: https://openfontlicense.org/open-font-license-official-text/ 。アプリ画面での表示義務はなく、同梱ライセンスを保持する。
