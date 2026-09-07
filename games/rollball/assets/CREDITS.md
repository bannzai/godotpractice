# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## フォント (`assets/fonts/`)

- **素材名**: Kosugi Maru Regular (`KosugiMaru-Regular.ttf`, `LICENSE.txt`)
- **作者**: MOTOYA / Copyright 2010 The Kosugi Maru Project Authors (https://github.com/googlefonts/kosugi-maru)
- **入手 URL**: https://fonts.google.com/specimen/Kosugi+Maru
- **ライセンス**: Apache License 2.0
- **クレジット表記**: **必要**
- **改変**: なし
- **備考**: フォントは無改変。Google Fonts の `apache/kosugimaru` にあるライセンス全文を `LICENSE.txt` として保持し、METADATA.pb の作者・ライセンス・上流コミットを確認。作業指示では OFL とされていたが、公式配布は Apache-2.0 のため実際の条件を記録する。画面内の作者表記は不要。

## オリジナル音源 (`assets/audio/`)

- **素材名**: 玩具工房の音楽・環境音・効果音 (`title.wav`, `play.wav`, `urgent.wav`, `finish.wav`, `timeout.wav`, `ambience_atelier.wav`, `ambience_playroom.wav`, `music.wav`, `pickup.wav`, `bump.wav`, `win.wav`, `lose.wav`, `growth.wav`)
- **作者**: 本プロジェクトで Codex を用いて制作
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/main/games/rollball/scripts/dev/generate_audio.py
- **ライセンス**: 本プロジェクトのオリジナル生成物（第三者音源なし）
- **クレジット表記**: **不要**
- **改変**: 生成した波形を無圧縮 WAV として保存
- **備考**: 外部音声・既存楽曲を使用せず、独自の音列と木琴・弦のプラック・ベース・ブラシ・ベルを数式合成。OpenAI 利用規約では、適用法の認める範囲で出力は利用者に帰属する。CC0 とは宣言しない。再生成: python3 scripts/dev/generate_audio.py。場面ごとに8〜15秒のループ。music.wav は従来入口との互換用に play.wav と同内容。
- **生成**: Python 3 標準ライブラリによる数式合成（実装支援: Codex） / プロンプトの要点: 柔らかい粘土玩具の世界、木琴風の静かなループ、タイトル・プレイ・残り30秒・成功・失敗の場面別BGM、紙を擦る音・粘土を置く音・遠い玩具のベルを重ねた部屋別環境音、拾得・衝突・成長・成功・失敗が聞き分けられる短い音

## オリジナル画像 (`assets/`)

- **素材名**: ころがる玉のマーク (`ball-mark.svg`)
- **作者**: 本プロジェクトで Codex を用いて制作
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/rollball/games/rollball/assets/ball-mark.svg
- **ライセンス**: 本プロジェクトのオリジナル生成物（第三者素材なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 外部画像・原作ロゴを使用せず、基本図形とパスで制作。適用法の認める範囲で出力は利用者に帰属する。利用規約: https://openai.com/policies/terms-of-use/。CC0 とは宣言しない。
- **生成**: Codex による SVG 記述 / プロンプトの要点: ティールの抽象的な玉、クリームの帯、コーラルのアクセント、温かい玩具工房

## オリジナルの3D表示とUI

- **素材名**: 部屋・家具・小物・玉・回収エフェクト・UI
- **作者**: 本プロジェクトで Codex を用いて制作
- **入手 URL**: https://github.com/bannzai/godotpractice/tree/game/rollball/games/rollball/scripts
- **ライセンス**: 本プロジェクトのオリジナル生成物（第三者モデルなし）
- **クレジット表記**: 不要
- **生成**: GDScript と Godot 組み込みプリミティブ / プロンプトの要点: 木の床とティールの壁、コーラル色の玉、玩具と家具のある工房。独自の基本図形の組み合わせで構成。
- **備考**: 外部のモデル・テクスチャは使用していない。適用法の認める範囲で出力は利用者に帰属する。

## 第2ラウンドの独立モデル (`assets/models/`)

- **素材名**: 巻き取りボール `ball.tscn`、木のアヒル `duck.tscn`、ぜんまいロボット `robot.tscn`、玩具の汽車 `train.tscn`、花鉢 `plant.tscn`
- **作者**: 本プロジェクトで Codex を用いて制作
- **入手 URL**: 外部取得なし。本リポジトリの `games/rollball/assets/models/`。
- **ライセンス**: 本プロジェクトのオリジナル生成物（第三者モデルなし、CC0とは宣言しない）
- **クレジット表記**: 不要
- **改変**: なし
- **生成**: Codex による Godot シーン・AnimationLibrary の記述。木製玩具を顔・装備・車輪・葉の形で見分け、待機・移動・回収・反発・喜び・時間切れの部位アニメーションを備える。
- **備考**: 部屋の窓外風景・雲・カーテン・腰壁・縫い目、紙吹雪と輪の演出も GDScript と組み込みメッシュで独自制作。外部モデル・原作素材を使用していない。

## 第2ラウンドのUI (`assets/ui/`)

- **素材名**: `atelier-theme.tres`、`logo-emblem.svg`、`title-key-art.svg`、`goal-rosette.svg`、`timer-clock.svg`、`collected-blocks.svg`
- **作者**: 本プロジェクトで Codex を用いて制作
- **入手 URL**: 外部取得なし。本リポジトリの `games/rollball/assets/ui/`。
- **ライセンス**: 本プロジェクトのオリジナル生成物（第三者画像なし、CC0とは宣言しない）
- **クレジット表記**: 不要
- **改変**: なし
- **生成**: Codex による SVG と Godot Theme の直接記述。クリーム・青緑・コーラル・金の配色、糸玉・アヒル・ロボットの独自図案。日本語ロゴ文字は同梱フォントで描画。
- **備考**: 画像生成モデルは使用していない。適用法の認める範囲で生成出力は利用者に帰属する。

## 手直しラウンドの粘土表面と画用紙UI

- **素材名**: 手続きノイズの法線マップと頂点カラーによる粘土表面、画用紙の繊維シェーダー、2つの部屋とおもちゃ箱型の選択画面
- **作者**: 本プロジェクトで Codex を用いて制作
- **入手 URL**: 外部取得なし。本リポジトリの `games/rollball/scripts/visuals/clay_surface.gd`、`room.gd`、`hud.gd`。
- **ライセンス**: 本プロジェクトのオリジナル生成物（第三者素材なし、CC0とは宣言しない）
- **クレジット表記**: 不要
- **改変**: 第2ラウンドのプリミティブモデルとUIを、粘土アニメ風・紙工作風へ加工
- **生成**: GDScript と Godot 組み込みの FastNoiseLite / NoiseTexture2D / CanvasItem shader / プリミティブ。固定seedの凹凸、指紋状の色むら、紙繊維状の輝度むらをコードで生成する。
- **備考**: テクスチャ画像や外部モデルは追加していない。同じコードとseedから再現でき、外部素材のライセンス確認を必要としない。
