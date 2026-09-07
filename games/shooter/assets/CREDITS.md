# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## フォント (`assets/fonts/`)

- **素材名**: Train One (`TrainOne-Regular.ttf`, `OFL.txt`)
- **作者**: The Train Project Authors（Copyright 2020）
- **入手 URL**: https://fonts.google.com/specimen/Train+One
- **ライセンス**: SIL Open Font License 1.1
- **クレジット表記**: **必要**
- **改変**: なし
- **備考**: 著作権表示とライセンス全文を `fonts/OFL.txt` に保持。Google Fonts の一次配布ファイルを game-asset-search skill で取得した。

- **素材名**: Noto Sans JP（旧画面用・ランタイムでは未使用。`NotoSansJP.ttf`, `NotoSansJP-OFL.txt`）
- **作者**: Adobe（Copyright 2014–2021）
- **入手 URL**: https://fonts.google.com/specimen/Noto+Sans+JP
- **ライセンス**: SIL Open Font License 1.1
- **クレジット表記**: **必要**
- **改変**: ファイル名を NotoSansJP[wght].ttf から NotoSansJP.ttf に変更。フォント本体は未改変。
- **備考**: 変更前画像の再現用にファイルを保持し、著作権表示・Reserved Font Name Source・ライセンス全文を `fonts/NotoSansJP-OFL.txt` に分離した。ゲームとエクスポートからは参照しない。

## ランタイムの線画

- **素材名**: ベクタースキャン表現（自機・敵4種・弾・アイテム・爆発片・丸型計器・レーダー・透視図の地球儀）
- **作者**: 本プロジェクト（Codex による制作支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト向け新規制作物。第三者素材・サンプル画像を使用していない。独立した CC0 宣言は行っていない。
- **クレジット表記**: **不要**
- **改変**: 新規制作
- **生成**: GDScript の `Line2D` / `draw_line` / `draw_arc` と CanvasItem シェーダで実行時に決定的に描画 / プロンプトの要点: 黒地の透視図、発光するシアン・マゼンタ・黄の線、線幅の異なる残光、赤青の位置ずれ、5状態×4フレーム、爆発は放射状の線片。

## 画像 (`assets/sprites/`、旧画面用・ランタイムでは未使用)

- **素材名**: 独自の宇宙戦闘機・弾・アイテム (`player.svg`, `enemy_scout.svg`, `enemy_fighter.svg`, `enemy_carrier.svg`, `boss.svg`, `bullet_player.svg`, `bullet_enemy.svg`, `item_power.svg`, `item_bomb.svg`, `item_score.svg`, `player_sheet.svg`, `scout_sheet.svg`, `aim_sheet.svg`, `fan_sheet.svg`, `boss_sheet.svg`)
- **作者**: 本プロジェクト（Codex による制作支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト向け新規制作物。第三者素材・サンプル音源を使用していない。独立した CC0 宣言は行っていない。
- **クレジット表記**: **不要**
- **改変**: 新規制作
- **備考**: 編集可能な SVG コードを変更前との比較用に保持。現在の描画コードからは参照しない。外部の画像生成 API・既存作品素材は未使用。
- **生成**: Python3 標準ライブラリによる SVG 生成（scripts/dev/generate_art.py、固定シード） / プロンプトの要点: 青緑の可変翼機、朱色の針状機、金色の狙撃機、紫色の回転砲塔機、大型旗艦。装甲・装備・コアを描き分け、待機/移動/攻撃/被弾/撃破を各4フレームで生成。

## 背景 (`assets/backgrounds/`、旧画面用・ランタイムでは未使用)

- **素材名**: 独自の星空背景 (`space.svg`, `nebula.svg`, `stars_far.svg`, `stars_near.svg`, `orbital.svg`, `title_keyart.svg`)
- **作者**: 本プロジェクト（Codex による制作支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト向け新規制作物。第三者素材・サンプル音源を使用していない。独立した CC0 宣言は行っていない。
- **クレジット表記**: **不要**
- **改変**: 新規制作
- **備考**: 編集可能な SVG コードを同梱。外部の画像生成 API・既存作品素材は未使用。
- **生成**: Python3 標準ライブラリによる SVG 生成（scripts/dev/generate_art.py、固定シード） / プロンプトの要点: 固定シードの星配置と青い星雲を SVG の図形で構成。

## UI (`assets/ui/`、`flight_theme.tres` 以外は旧画面用・ランタイムでは未使用)

- **素材名**: 独自の情報パネル (`panel.svg`, `hud_frame.svg`, `emblem.svg`, `title_logo.svg`, `life.svg`, `bomb.svg`, `power.svg`, `flight_theme.tres`)
- **作者**: 本プロジェクト（Codex による制作支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト向け新規制作物。第三者素材・サンプル音源を使用していない。独立した CC0 宣言は行っていない。
- **クレジット表記**: **不要**
- **改変**: 新規制作
- **備考**: 編集可能な SVG コードを同梱。外部の画像生成 API・既存作品素材は未使用。
- **生成**: Python3 標準ライブラリによる SVG 生成（scripts/dev/generate_art.py、固定シード） / プロンプトの要点: 濃紺の面と青緑の角飾り。文字や既存作品のロゴを含まない。

## 音声 (`assets/audio/`)

- **素材名**: 独自の BGM・効果音 (`title.ogg`, `result.ogg`, `stage.ogg`, `boss.ogg`, `shot.wav`, `explosion.wav`, `item.wav`, `bomb.wav`, `scan.wav`)
- **作者**: 本プロジェクト（Codex による制作支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト向け新規制作物。第三者素材・サンプル音源を使用していない。独立した CC0 宣言は行っていない。
- **クレジット表記**: **不要**
- **改変**: 新規制作
- **備考**: 再生成: python3 scripts/dev/generate_audio.py。外部の生成 API・音声素材は未使用。
- **生成**: Python 標準ライブラリによる波形合成 + ffmpeg Vorbis エンコード / プロンプトの要点: 独自固定譜面・固定シード、pad、FM bell、pulse、倍音bass、打楽器、ステレオdelay。タイトル84 BPM/約22.86秒、ステージ132 BPM/約14.55秒、ボス156 BPM/約12.31秒、結果100 BPM/19.2秒。既存4種の効果音に、航路図と計器チェック用の周波数走査パルスを追加。
