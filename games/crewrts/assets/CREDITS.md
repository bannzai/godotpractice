# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## フォント (`assets/fonts/`)

- **素材名**: M PLUS Rounded 1c Regular (`MPLUSRounded1c-Regular.ttf`, `OFL.txt`)
- **作者**: The Rounded M+ Project Authors
- **入手 URL**: https://fonts.google.com/specimen/M+PLUS+Rounded+1c
- **ライセンス**: SIL Open Font License 1.1
- **クレジット表記**: **必要**
- **改変**: フォント本体は無改変。OFL.txt にフォント内部の著作権表示を保持。
- **備考**: Google Fonts の公式リポジトリから取得。https://github.com/google/fonts/tree/main/ofl/mplusrounded1c 。同梱条件: 著作権表示と OFL 全文をフォントとともに保持。画面上のクレジット表示は任意。OFL 全文の取得元: https://openfontlicense.org/documents/OFL.txt 。日本語表示を OS 搭載フォントに依存させないため採用。

## 音声 (`assets/audio/`)

- **素材名**: 庭の伴奏と回収隊の操作音 (`garden.wav`, `whistle.wav`, `throw.wav`, `delivery.wav`, `defeat.wav`, `lost.wav`)
- **作者**: 本プロジェクトで新規作成（Codex によるコード生成）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 外部素材未使用の独自生成物。第三者ライセンス条件なし。CC0 等の別ライセンスは付与していない。
- **クレジット表記**: **不要**
- **改変**: 新規生成。PCM 16-bit / 22050 Hz。伴奏はステレオ 16 秒、効果音はモノラル。
- **備考**: 再生成: python3 scripts/dev/generate_audio.py。外部の録音・サンプル・旋律を取り込まず、正弦波の倍音・包絡線・音高列から生成した。伴奏の残響をループ先頭へ折り返して接続。OpenAI の利用条件上、適用法の範囲で出力の権利は利用者に帰属: https://openai.com/policies/terms-of-use/ 。第三者著作物の利用許諾や著作権の成立を保証するものではない。
- **生成**: Python 3 標準ライブラリ math / wave、生成コードは Codex / プロンプトの要点: 穏やかな庭に合う木琴風のループ伴奏、呼び寄せ、投擲、納品、敵撃破、隊員喪失を区別できる短い音。既存曲や作品の再現を求めず数式で合成。

## 立体造形（ゲーム内で生成）

- **素材名**: こもれび回収隊の庭、ロボット、結晶、敵
- **作者**: 本プロジェクトで新規作成（Codex によるコード生成）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 外部モデル未使用のコード生成。第三者素材のライセンス条件なし。CC0 等の別ライセンスは付与していない。
- **クレジット表記**: 不要
- **改変**: 新規作成。外部モデル・画像・テクスチャの取り込みなし。
- **生成**: Godot のプリミティブメッシュ。`scripts/world.gd` で球・箱・円柱などから組み立てる。
- **生成指示の要点**: 青緑・オレンジ・アイボリーを中心に、小さなロボットとエネルギー結晶を温かい庭に配置するオリジナル RTS。既存作品の再現は行わない。
- **生成理由**: キャラクターと庭の形・配色を揃え、ゲームの状態を立体形状から読み取れるようにするため。
- **利用規約上の帰属**: OpenAI と利用者の関係では、適用法の範囲で出力の権利は利用者に帰属。https://openai.com/policies/terms-of-use/
