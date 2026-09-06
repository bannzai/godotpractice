# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## フォント (`assets/fonts/`)

- **素材名**: Noto Sans JP (`NotoSansJP.ttf`, `OFL.txt`)
- **作者**: Adobe（2014–2021）
- **入手 URL**: https://fonts.google.com/specimen/Noto+Sans+JP
- **ライセンス**: OFL-1.1
- **クレジット表記**: **必要**
- **改変**: ファイル名を NotoSansJP.ttf に変更。フォントデータは変更なし
- **備考**: 著作権表示および SIL Open Font License 1.1 全文を fonts/OFL.txt に同梱。アプリ画面での帰属表示は要求されない。

## オリジナル画像 (`assets/art/`)

- **素材名**: 星図の対戦盤と四属性の精霊 (`arena.svg`, `fire.svg`, `water.svg`, `wind.svg`, `earth.svg`, `card_back.svg`)
- **作者**: godotpractice プロジェクト
- **入手 URL**: https://github.com/bannzai/godotpractice/tree/main/games/cardbattle/scripts/dev/generate_assets.py
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 第三者画像の生成サービスは使用していない。再生成は python3 scripts/dev/generate_assets.py。
- **生成**: Codex による SVG 記述、Python 標準ライブラリ / プロンプトの要点: 紺・青緑・金の天文学的な対戦盤、火・水・風・土のオリジナル精霊、星図のカード裏。既存作品の名称や素材を参照しない。

## オリジナル音声 (`assets/audio/`)

- **素材名**: 静かな星の旋律と操作音 (`bgm.wav`, `draw.wav`, `summon.wav`, `attack.wav`, `destroy.wav`, `damage.wav`, `victory.wav`)
- **作者**: godotpractice プロジェクト
- **入手 URL**: https://github.com/bannzai/godotpractice/tree/main/games/cardbattle/scripts/dev/generate_assets.py
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 既存の曲・録音・サンプルを使用していない。22,050 Hz・16 bit・モノラル PCM。BGM はループ境界で残響を重ねている。
- **生成**: Codex による作曲・Python 標準ライブラリの正弦波合成 / プロンプトの要点: 穏やかな短調アルペジオの 16 秒ループ、ドロー・召喚・攻撃・破壊・被ダメージ・勝利を区別する短い音。
