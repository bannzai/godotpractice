# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## フォント (`assets/fonts/`)

- **素材名**: M PLUS Rounded 1c Regular (`MPLUSRounded1c-Regular.ttf`, `OFL.txt`)
- **作者**: The Rounded M+ Project Authors
- **入手 URL**: https://fonts.google.com/specimen/M+PLUS+Rounded+1c
- **ライセンス**: OFL-1.1
- **クレジット表記**: **必要**
- **改変**: なし
- **備考**: Copyright 2016 The Rounded M+ Project Authors. フォント内の著作権表示を確認し、fonts/OFL.txt に著作権表示とライセンス全文を同梱。フォント本体は取得時のまま。

## オリジナル画像 (`assets/`)

- **素材名**: こもれびの調査隊のモンスター6体 (`ember.svg`, `tide.svg`, `sprout.svg`, `moth.svg`, `crab.svg`, `owl.svg`)
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成元: scripts/dev/generate_assets.py。画像生成サービスは未使用。外部素材の転載なし。第三者への追加ライセンス付与は行っていない。
- **生成**: Codex による Python / SVG コード作成、Python 3 標準ライブラリ / プロンプトの要点: 192px透過、丸い異なる輪郭、紺色の線と柔らかな金・赤・ターコイズ・若草色。既存作品の素材は使わない。

- **素材名**: 調査隊員と地形タイル (`player.svg`, `tiles.svg`)
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成元: scripts/dev/generate_assets.py。画像生成サービスは未使用。外部素材の転載なし。第三者への追加ライセンス付与は行っていない。
- **生成**: Codex による Python / SVG コード作成、Python 3 標準ライブラリ / プロンプトの要点: 48pxの調査隊員、草地・道・背高草・樹冠・水・室内床の48pxタイル6枚。既存作品素材を使わない。

## オリジナル音源 (`assets/audio/`)

- **素材名**: 探索・戦闘BGMと行動効果音 (`field.wav`, `battle.wav`, `attack.wav`, `capture.wav`, `heal.wav`)
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成元: scripts/dev/generate_assets.py。22050 Hz / 16 bit / mono PCM WAV。BGMは16秒、attackは0.35秒、captureとhealは0.9秒。外部音声生成サービス・録音素材は未使用。第三者への追加ライセンス付与は行っていない。
- **生成**: Codex による Python コード作成、Python 3 wave/math/struct による加算合成 / プロンプトの要点: 素朴な冒険の16秒ループBGMと速い戦闘BGM。攻撃・捕獲・回復の短い効果音。既存曲・録音・サンプルは使わない。
