# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## フォント (`assets/fonts/`)

- **素材名**: Klee One Regular (`KleeOne-Regular.ttf`, `OFL.txt`)
- **作者**: Copyright 2020 The Klee Project Authors (https://github.com/fontworks-fonts/Klee)
- **入手 URL**: https://fonts.google.com/specimen/Klee+One
- **ライセンス**: SIL Open Font License 1.1
- **クレジット表記**: **必要**
- **改変**: フォント本体は無改変。配布元の OFL.txt と著作権表示を保持。
- **備考**: Google Fonts の公式配布から `game-asset-search` skill で取得。https://github.com/google/fonts/tree/main/ofl/kleeone 。探検ノートの手書き文字として日本語表示を OS 搭載フォントに依存させないため採用。

## 音声 (`assets/audio/`)

- **素材名**: 庭の伴奏・島の環境音と回収隊の操作音 (`title.wav`, `garden.wav`, `battle.wav`, `clear.wav`, `failed.wav`, `island-ambience.wav`, `whistle.wav`, `throw.wav`, `delivery.wav`, `defeat.wav`, `lost.wav`, `hit.wav`, `switch.wav`)
- **作者**: 本プロジェクトで新規作成（Codexによるコード生成）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 外部素材未使用の独自生成物。CC0等の別ライセンスは付与していない。
- **クレジット表記**: **不要**
- **改変**: 第2ラウンドの全曲と効果音を維持し、見た目の特色化ラウンドで風・葉音・鳥声の島環境音を追加。PCM 16-bit / 22050Hz。曲と環境音はステレオ、効果音はモノラル。
- **備考**: 再生成はpython3 scripts/dev/generate_audio.py。外部サンプルと既存曲を使用しない。OpenAIと利用者との関係では適用法の範囲で出力の権利は利用者に帰属: https://openai.com/policies/terms-of-use/
- **生成**: Python 3 標準ライブラリ / Codex / プロンプトの要点: 庭に合う木琴・弦・リード・ベース・ノイズ打楽器を合成。タイトル・庭・戦闘・成功・失敗で旋律、速さ、音色を変える。操作と出来事を区別する7種の効果音。周期補間した風と葉音に短い鳥声を重ね、島にいることが音だけでも伝わる環境音を加える。

## 立体造形（ゲーム内で生成）

- **素材名**: こもれび回収隊の庭、ロボット、結晶、敵
- **作者**: 本プロジェクトで新規作成（Codex によるコード生成）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 外部モデル未使用のコード生成。第三者素材のライセンス条件なし。CC0 等の別ライセンスは付与していない。
- **クレジット表記**: 不要
- **改変**: 新規作成。外部モデルは取り込まず、見た目の特色化ラウンドで生成水彩テクスチャをトゥーンシェーダへ適用。
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
- **備考**: 第2ラウンドの生成記録。現在の探検ノート UI は Klee One と生成紙テクスチャを使う。OpenAIと利用者との関係では適用法の範囲で出力の権利は利用者に帰属: https://openai.com/policies/terms-of-use/
- **生成**: SVG / Godot Theme / Codex / プロンプトの要点: 温かなクリームと濃緑、朱と青で庭と回収隊を描く。人物と操作アイコンを分離し、ゲームモデルの装備に合わせる。

## 見た目の特色化ラウンドの生成画像 (`assets/textures/`)

- **素材名**: 水彩紙・顔料にじみ・島の絵地図 (`paper-grain.png`, `watercolor-wash.png`, `island-map.png`)
- **作者**: 本プロジェクトで新規生成
- **入手 URL**: https://openai.com/policies/terms-of-use/
- **ライセンス**: OpenAI 利用規約に基づく生成物。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: 生成画像を無改変で配置し、Godot のトゥーンシェーダと UI で縮尺・色を調整
- **備考**: paper-grain.png と watercolor-wash.png は材質用、island-map.png は文字を Godot 側で重ねる一枚絵。watercolor_toon.gdshader で3Dへ適用。
- **生成**: OpenAI built-in image_gen / プロンプトの要点: 輪郭線なしの絵本水彩。紙の繊維、顔料のにじみ、苔庭・霧の沼・あかね丘を持つ文字なしの架空島。既存作品・ブランドを参照しない。
