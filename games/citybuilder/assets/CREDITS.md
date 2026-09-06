# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## 街の建物と住民 (`assets/sprites/`)

- **素材名**: 街の建物と住民 (`car.svg`, `commercial.svg`, `commercial_mid.svg`, `fire.svg`, `industrial.svg`, `industrial_mid.svg`, `park.svg`, `police.svg`, `power.svg`, `residential.svg`, `residential_mid.svg`, `tree.svg`, `walker.svg`)
- **作者**: 本プロジェクトで新規作成（Codex によるコード生成）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 外部素材未使用の独自生成物。CC0 等の別ライセンスは付与していない。
- **クレジット表記**: **不要**
- **改変**: 新規生成。再生成: python3 scripts/dev/generate_assets.py
- **備考**: 外部画像・既存曲・音声サンプルは使用しない。OpenAI と利用者との関係では適用法の範囲で出力の権利は利用者に帰属: https://openai.com/policies/terms-of-use/
- **生成**: Python 3 標準ライブラリ / SVG / Codex / プロンプトの要点: 用途ごとに住宅・中層住宅・商店・商業ビル・工場・大型工場・発電施設・公園・警察・消防・木・車・住民を独立SVGに描く。温かな紙色、濃紺の輪郭、ミント・コーラル・黄土色。

## 多層背景 (`assets/backgrounds/`)

- **素材名**: 多層背景 (`clouds.svg`, `mountains.svg`, `terrain.svg`)
- **作者**: 本プロジェクトで新規作成（Codex によるコード生成）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 外部素材未使用の独自生成物。CC0 等の別ライセンスは付与していない。
- **クレジット表記**: **不要**
- **改変**: 新規生成。再生成: python3 scripts/dev/generate_assets.py
- **備考**: 外部画像・既存曲・音声サンプルは使用しない。OpenAI と利用者との関係では適用法の範囲で出力の権利は利用者に帰属: https://openai.com/policies/terms-of-use/
- **生成**: Python 3 標準ライブラリ / SVG / Codex / プロンプトの要点: 都市計画図の方眼と川、遠景の山、独立して動かせる雲。

## タイトル画像 (`assets/branding/`)

- **素材名**: タイトル画像 (`keyart.svg`, `logo.svg`)
- **作者**: 本プロジェクトで新規作成（Codex によるコード生成）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 外部素材未使用の独自生成物。CC0 等の別ライセンスは付与していない。
- **クレジット表記**: **不要**
- **改変**: 新規生成。再生成: python3 scripts/dev/generate_assets.py
- **備考**: 外部画像・既存曲・音声サンプルは使用しない。OpenAI と利用者との関係では適用法の範囲で出力の権利は利用者に帰属: https://openai.com/policies/terms-of-use/
- **生成**: Python 3 標準ライブラリ / SVG / Codex / プロンプトの要点: 独自の建物を並べた街のロゴマークと、川沿いのミニチュア都市のキーアート。

## 画面部品 (`assets/ui/`)

- **素材名**: 画面部品 (`button.svg`, `panel.svg`)
- **作者**: 本プロジェクトで新規作成（Codex によるコード生成）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 外部素材未使用の独自生成物。CC0 等の別ライセンスは付与していない。
- **クレジット表記**: **不要**
- **改変**: 新規生成。再生成: python3 scripts/dev/generate_assets.py
- **備考**: 外部画像・既存曲・音声サンプルは使用しない。OpenAI と利用者との関係では適用法の範囲で出力の権利は利用者に帰属: https://openai.com/policies/terms-of-use/
- **生成**: Python 3 標準ライブラリ / SVG / Codex / プロンプトの要点: 濃紺のパネルとミント色の立体的なボタン。

## 音楽と効果音 (`assets/audio/`)

- **素材名**: 音楽と効果音 (`build.wav`, `city.wav`, `click.wav`, `demolish.wav`, `month.wav`, `result.wav`, `title.wav`, `town.wav`, `alert.wav`)
- **作者**: 本プロジェクトで新規作成（Codex によるコード生成）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 外部素材未使用の独自生成物。CC0 等の別ライセンスは付与していない。
- **クレジット表記**: **不要**
- **改変**: 新規生成。再生成: python3 scripts/dev/generate_assets.py
- **備考**: 外部画像・既存曲・音声サンプルは使用しない。OpenAI と利用者との関係では適用法の範囲で出力の権利は利用者に帰属: https://openai.com/policies/terms-of-use/
- **生成**: Python 3 標準ライブラリ / SVG / Codex / プロンプトの要点: タイトル・小都市・発展都市・結果の4曲。倍音のあるベル、持続和音、ベース、ノイズとキックの打楽器を合成。建築・撤去・警告・月経過・操作の5効果音。

## 日本語フォント (`assets/fonts/`)

- **素材名**: M PLUS Rounded 1c Regular (`MPLUSRounded1c-Regular.ttf`, `OFL.txt`)
- **作者**: The Rounded M+ Project Authors
- **入手 URL**: https://fonts.google.com/specimen/M+PLUS+Rounded+1c
- **ライセンス**: SIL Open Font License 1.1
- **クレジット表記**: **必要**
- **改変**: なし。既存ゲーム crewrts からフォント本体と著作権表示を保持した OFL 全文を複製。
- **備考**: 入手元は Google Fonts 公式リポジトリ https://github.com/google/fonts/tree/main/ofl/mplusrounded1c 。OFL 全文と著作権表示をフォントとともに配布。画面上のクレジット表示は任意。
