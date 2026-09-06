# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## フォント (`assets/fonts/`)

- **素材名**: M PLUS Rounded 1c Medium (`MPLUSRounded1c-Medium.ttf`, `OFL.txt`)
- **作者**: Coji Morishita, M+ Fonts Project / Copyright 2016 The Rounded M+ Project Authors.
- **入手 URL**: https://fonts.google.com/specimen/M+PLUS+Rounded+1c
- **ライセンス**: OFL-1.1
- **クレジット表記**: **必要**
- **改変**: なし
- **備考**: フォントは無改変。OFL.txt に著作権表示と SIL Open Font License 1.1 の全文を保持。Google Fonts の METADATA.pb およびフォント内 name テーブルで作者・ライセンスを確認。画面内の作者表記は不要。

## オリジナル音源 (`assets/audio/`)

- **素材名**: 玩具工房の音楽と効果音 (`music.wav`, `pickup.wav`, `bump.wav`, `win.wav`, `lose.wav`)
- **作者**: 本プロジェクトで Codex を用いて制作
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/rollball/games/rollball/scripts/dev/generate_audio.py
- **ライセンス**: 本プロジェクトのオリジナル生成物（第三者音源なし）
- **クレジット表記**: **不要**
- **改変**: 生成した波形を無圧縮 WAV として保存
- **備考**: 外部音声・既存楽曲を使用せず、独自の音列と正弦波から生成。OpenAI 利用規約では、適用法の認める範囲で出力は利用者に帰属する。CC0 とは宣言しない。再生成: python3 scripts/dev/generate_audio.py。BGM は 19.2 秒でループ。
- **生成**: Python 3 標準ライブラリによる数式合成（実装支援: Codex） / プロンプトの要点: 温かい玩具工房、木琴風の静かなループ、拾得・衝突・成功・失敗が聞き分けられる短い音

## オリジナル画像 (`assets/`)

- **素材名**: ころがる玉のマーク (`ball-mark.svg`)
- **作者**: 本プロジェクトで Codex を用いて制作
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/rollball/games/rollball/assets/ball-mark.svg
- **ライセンス**: 本プロジェクトのオリジナル生成物（第三者素材なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 外部画像・原作ロゴを使用せず、基本図形とパスで制作。適用法の認める範囲で出力は利用者に帰属する。利用規約: https://openai.com/policies/terms-of-use/。CC0 とは宣言しない。
- **生成**: Codex による SVG 記述 / プロンプトの要点: ティールの抽象的な玉、クリームの帯、コーラルのアクセント、温かい玩具工房
