# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## 旧ラウンドの独自画像 (`assets/art/`)

- **素材名**: 宵森の灯守の図案 (`bolt.svg`, `enemy-0-sheet.svg`, `enemy-0.svg`, `enemy-1-sheet.svg`, `enemy-1.svg`, `enemy-2-sheet.svg`, `enemy-2.svg`, `enemy-3-sheet.svg`, `enemy-3.svg`, `floor.svg`, `forest-far.svg`, `forest-near.svg`, `gem.svg`, `heal.svg`, `icon-armor.svg`, `icon-clock.svg`, `icon-health.svg`, `icon-kills.svg`, `icon-pause.svg`, `icon-sound.svg`, `icon-speed.svg`, `key-art.svg`, `logo.svg`, `magnet.svg`, `mist.svg`, `orbit.svg`, `player-sheet.svg`, `player.svg`, `pulse.svg`, `spark.svg`, `title-emblem.svg`)
- **作者**: bannzai（Codexを利用）
- **入手 URL**: https://openai.com/policies/terms-of-use/
- **ライセンス**: プロジェクト独自生成物。第三者素材なし。第三者へのライセンス付与はしていない
- **クレジット表記**: **不要**
- **改変**: 品質向上ラウンドで再設計。現行画面では一部の小物・UIアイコン・演出にだけ使用
- **備考**: 再生成: python3 scripts/dev/generate_assets.py
- **生成**: Codexによるコード作成・PythonとfontToolsで決定的に生成 / プロンプトの要点: 青緑の夜森、金色の灯守、葉の精・蛾・石の巨獣・枝角の主。各体に5動作6フレーム、個別アイテムとUI図案、多層背景、キーアート。ロゴは同梱OFLフォントの輪郭から生成

## 画像生成したキャラクター・武器・タイトル絵 (`assets/generated/`)

- **素材名**: NEON DAWN の画像素材 (`bolt.png`, `enemy-0.png`, `enemy-1.png`, `enemy-2.png`, `enemy-3.png`, `orbit.png`, `player.png`, `pulse.png`, `title-art.png`)
- **作者**: bannzai（OpenAI image generationを利用）
- **入手 URL**: https://openai.com/policies/terms-of-use/
- **ライセンス**: プロジェクト独自生成物。第三者素材なし。第三者へのライセンス付与はしていない
- **クレジット表記**: **不要**
- **改変**: 透過背景の補正、Godot上での縮小、ポーズ差分・発光・色ずれのシェーダ処理
- **備考**: 元ネタの名称・画像・ロゴを参照せず、同じ色・輪郭・発光条件を全素材へ指定して個別生成
- **生成**: OpenAI image generation / プロンプトの要点: 黒に近い宇宙背景へシアンとマゼンタの発光、太いシルエット、正面寄りのゲーム用切り抜き。プレイヤーはネオン配達人、敵は電気蛾・データハウンド・多面体センチネル・日食の君主、武器はプラズマ槍・四方リング・六角パルス。タイトル絵は縞の太陽、透視グリッド、対峙する主人公とボス、左側にタイトル用の余白

## 独自音声 (`assets/audio/`)

- **素材名**: NEON DAWN の旋律・環境音・効果音 (`ambience.wav`, `attack.wav`, `bgm-boss.wav`, `bgm-play.wav`, `bgm-result.wav`, `bgm-title.wav`, `boss.wav`, `heal.wav`, `hurt.wav`, `level.wav`, `magnet.wav`, `pickup.wav`, `result.wav`, `ui.wav`)
- **作者**: bannzai（Codexを利用）
- **入手 URL**: https://openai.com/policies/terms-of-use/
- **ライセンス**: プロジェクト独自生成物。第三者素材なし。第三者へのライセンス付与はしていない
- **クレジット表記**: **不要**
- **改変**: 既存の場面別譜面と効果音の役割を維持し、シンセウェーブに合う位相変調リード、デチューンパッド、矩形波プラックへ音色を変更。ループする電気的な環境音を追加
- **備考**: 再生成: python3 scripts/dev/generate_assets.py。フォントの著作権とOFL全文は fonts/OFL.txt を参照。
- **生成**: Codexによるコード作成・Python標準ライブラリで決定的に生成 / プロンプトの要点: 4場面の独自譜面、アナログシンセ風の発光感、低い電気ハムと左右に漂う高域、ベース・打楽器と9種の効果音。外部旋律・録音サンプル不使用

## フォント (`assets/fonts/`)

- **素材名**: RocknRoll One Regular (`RocknRollOne-Regular.ttf`, `OFL.txt`)
- **作者**: The RocknRoll Project Authors
- **入手 URL**: https://github.com/google/fonts/tree/main/ofl/rocknrollone
- **ライセンス**: OFL-1.1
- **クレジット表記**: **必要**
- **改変**: なし
- **備考**: Copyright 2020 The RocknRoll Project Authors (https://github.com/fontworks-fonts/RocknRoll)。取得先: https://raw.githubusercontent.com/google/fonts/main/ofl/rocknrollone/RocknRollOne-Regular.ttf。旧 `font.ttf` はゲーム実行時にも再生成時にも使用しないが、既存素材の来歴を保つため残している。旧ファイルの取得先は https://raw.githubusercontent.com/google/fonts/main/ofl/zenmarugothic/ZenMaruGothic-Medium.ttf。両フォントの著作権表示と共通するOFL全文をOFL.txtに同梱

## UIテーマ (`assets/theme/`)

- **素材名**: NEON DAWN のUIテーマ (`night.tres`)
- **作者**: bannzai（Codexを利用）
- **入手 URL**: https://openai.com/policies/terms-of-use/
- **ライセンス**: プロジェクト独自生成物。第三者素材なし。第三者へのライセンス付与はしていない
- **クレジット表記**: **不要**
- **改変**: シアンとマゼンタのネオン看板、角張った選択状態、RocknRoll Oneへ再設計
- **備考**: Godot Themeリソースとして記述。フォントの著作権とOFL全文は fonts/OFL.txt を参照。
- **生成**: CodexによるGodotリソース作成 / プロンプトの要点: 最小HUDとネオン看板で、通常・選択・フォーカス・無効状態を色と輪郭で判別できるテーマ
