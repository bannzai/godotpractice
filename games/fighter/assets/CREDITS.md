# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## 画像 (`assets/`)

- **素材名**: 燈環闘技の背景・紋章・装甲闘士 (`stage.svg`, `emblem.svg`, `portrait-teal.svg`, `portrait-amber.svg`)
- **作者**: 本プロジェクトで Codex を用いて独自制作
- **入手 URL**: https://github.com/bannzai/godotpractice/tree/main/games/fighter/assets
- **ライセンス**: 独自制作素材（外部素材の流用なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 画像生成サービスは使用せず、SVG の図形とパスを独自に記述。生成物であることを理由に CC0 とはしていない。
- **生成**: Codex による SVG ソース作成 / プロンプトの要点: 夕暮れの工業都市、円形闘技場、青緑と橙の装甲闘士。既存作品の名称・画像・ロゴを使わず、幾何図形から作画。

## 音声 (`assets/audio/`)

- **素材名**: 燈環闘技の打撃音・防御音・特殊攻撃音・競技場曲 (`hit.wav`, `guard.wav`, `special.wav`, `arena.wav`)
- **作者**: 本プロジェクトで Codex を用いて独自制作
- **入手 URL**: https://github.com/bannzai/godotpractice/tree/main/games/fighter/scripts/dev/generate_audio.py
- **ライセンス**: 独自制作素材（外部素材の流用なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: scripts/dev/generate_audio.py で同一データに再生成可能。第三者の録音、楽曲、音色サンプルは使用していない。
- **生成**: Python 標準ライブラリによる数学的音声合成 / プロンプトの要点: 固定乱数と正弦波で金属打撃・防御・上昇音を合成。BGM は独自の 120 BPM、8 小節、16 秒の反復演奏。

## フォント (`assets/fonts/`)

- **素材名**: Noto Sans JP (`font.ttf`, `OFL.txt`)
- **作者**: Adobe、Google、Noto プロジェクト
- **入手 URL**: https://fonts.google.com/specimen/Noto+Sans+JP
- **ライセンス**: OFL-1.1
- **クレジット表記**: **必要**
- **改変**: NotoSansJP[wght].ttf を font.ttf にファイル名変更。フォントデータは変更なし。
- **備考**: Copyright 2014-2021 Adobe (http://www.adobe.com/), with Reserved Font Name Source。同梱する fonts/OFL.txt に取得元の著作権表示と SIL Open Font License 1.1 全文を保持。取得元: https://github.com/google/fonts/tree/main/ofl/notosansjp。フォント単体では販売しない。

## 独自制作素材の生成条件

SVG と音声合成スクリプトは Codex が本プロジェクト用に生成したもの。OpenAI 利用規約の Content / Ownership of content は、適用法で許される範囲で、利用者と OpenAI の間では出力を利用者が所有すると定める。第三者素材への権利を与えるものではなく、本素材は第三者の図案・録音を取り込んでいない。CC0 などの追加ライセンスはここでは付与していない。

確認日: 2026-09-06

https://openai.com/policies/terms-of-use/
