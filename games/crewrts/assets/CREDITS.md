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

- **素材名**: 庭の伴奏と回収隊の操作音 (`title.wav`, `garden.wav`, `battle.wav`, `clear.wav`, `failed.wav`, `whistle.wav`, `throw.wav`, `delivery.wav`, `defeat.wav`, `lost.wav`, `hit.wav`, `switch.wav`)
- **作者**: 本プロジェクトで新規作成（Codexによるコード生成）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 外部素材未使用の独自生成物。CC0等の別ライセンスは付与していない。
- **クレジット表記**: **不要**
- **改変**: 第2ラウンドで全曲と効果音を刷新。PCM 16-bit / 22050Hz。曲はステレオ、効果音はモノラル。
- **備考**: 再生成はpython3 scripts/dev/generate_audio.py。外部サンプルと既存曲を使用しない。OpenAIと利用者との関係では適用法の範囲で出力の権利は利用者に帰属: https://openai.com/policies/terms-of-use/
- **生成**: Python 3 標準ライブラリ / Codex / プロンプトの要点: 庭に合う木琴・弦・リード・ベース・ノイズ打楽器を合成。タイトル・庭・戦闘・成功・失敗で旋律、速さ、音色を変える。操作と出来事を区別する7種の効果音。

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

## 第2ラウンドの立体造形 (`assets/models/`)

- **素材名**: 独立モデルと部位アニメーション (`captain.tscn`, `striker.tscn`, `porter.tscn`, `beetle.tscn`, `thorn_beetle.tscn`, `crystal_light.tscn`, `crystal_medium.tscn`, `crystal_heavy.tscn`, `base.tscn`)
- **作者**: 本プロジェクトで新規作成（Codexによるコード生成）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 外部素材未使用の独自生成物。CC0等の別ライセンスは付与していない。
- **クレジット表記**: **不要**
- **改変**: Godotのプリミティブから新規作成。第三者モデルの取り込みなし。
- **備考**: 造形コードはscripts/visuals。OpenAIと利用者との関係では適用法の範囲で出力の権利は利用者に帰属: https://openai.com/policies/terms-of-use/
- **生成**: Godot 4.7 / GDScript / Codex / プロンプトの要点: 隊長・朱のハンマー装甲・青の運搬装備・甲虫・トゲ甲虫を固有の輪郭に。重量ごとに結晶を分け、基地を庭の作業場にする。元作品の再現は行わない。

## 第2ラウンドの画面素材 (`assets/ui/`)

- **素材名**: 庭のロゴ・キーアート・操作アイコン・テーマ (`logo-mark.svg`, `title-garden.svg`, `crystal.svg`, `sun.svg`, `crew-red.svg`, `crew-blue.svg`, `whistle.svg`, `garden-theme.tres`)
- **作者**: 本プロジェクトで新規作成（Codexによるコード生成）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 外部画像未使用の独自生成物。CC0等の別ライセンスは付与していない。
- **クレジット表記**: **不要**
- **改変**: SVGとGodot Themeを新規作成。第三者画像の取り込みなし。
- **備考**: 既存のM PLUS Rounded 1cをThemeから参照。OpenAIと利用者との関係では適用法の範囲で出力の権利は利用者に帰属: https://openai.com/policies/terms-of-use/
- **生成**: SVG / Godot Theme / Codex / プロンプトの要点: 温かなクリームと濃緑、朱と青で庭と回収隊を描く。人物と操作アイコンを分離し、ゲームモデルの装備に合わせる。
