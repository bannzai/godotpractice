# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## フォント (`assets/fonts/`)

- **素材名**: Rampart One Regular (`RampartOne-Regular.ttf`, `OFL.txt`)
- **作者**: Copyright 2020 The Rampart Project Authors (https://github.com/fontworks-fonts/Rampart/)
- **入手 URL**: https://fonts.google.com/specimen/Rampart+One
- **ライセンス**: SIL Open Font License 1.1
- **クレジット表記**: **必要**
- **改変**: 無改変。著作権表示と OFL 全文を同梱。
- **備考**: 入手元: https://github.com/google/fonts/tree/main/ofl/rampartone 。game-asset-search の `fetch-asset.sh --family 'Rampart One'` でフォントと OFL.txt を取得。画面上のクレジット表示は任意。

## キャラクター (`assets/characters/`)

- **素材名**: 星灯りのバンド 3 人 (`fox.svg`, `bird.svg`, `rabbit.svg`)
- **作者**: 本プロジェクトで新規作成（Codex によるコード生成）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 外部素材未使用の独自生成物。CC0 等の別ライセンスは付与していない。
- **クレジット表記**: **不要**
- **改変**: scripts/dev/generate_assets.py から新規生成。外部の画像・楽曲・音声サンプルは不使用。
- **備考**: 再生成: python3 scripts/dev/generate_assets.py。OpenAI と利用者との関係では適用法の範囲で出力の権利は利用者に帰属: https://openai.com/policies/terms-of-use/ 。既存作品・ブランドの再現なし。
- **生成**: Python 3 標準ライブラリ / SVG / ffmpeg / Codex / プロンプトの要点: キツネの配達ドラマー、鳥のシンセ奏者、ウサギのベーシスト。紺・クリーム・珊瑚・ミントを使った別シルエットの SVG。

## 背景 (`assets/backgrounds/`)

- **素材名**: 星灯りの夜空と街並み (`sky.svg`, `city.svg`, `foreground.svg`)
- **作者**: 本プロジェクトで新規作成（Codex によるコード生成）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 外部素材未使用の独自生成物。CC0 等の別ライセンスは付与していない。
- **クレジット表記**: **不要**
- **改変**: scripts/dev/generate_assets.py から新規生成。外部の画像・楽曲・音声サンプルは不使用。
- **備考**: 再生成: python3 scripts/dev/generate_assets.py。OpenAI と利用者との関係では適用法の範囲で出力の権利は利用者に帰属: https://openai.com/policies/terms-of-use/ 。既存作品・ブランドの再現なし。
- **生成**: Python 3 標準ライブラリ / SVG / ffmpeg / Codex / プロンプトの要点: 星と三日月、窓明かりのある街、地面と電飾の 3 層 SVG。

## 画面素材 (`assets/ui/`)

- **素材名**: 星灯りのロゴと操作アイコン (`logo-mark.svg`, `note-coral.svg`, `note-mint.svg`, `note-long.svg`, `star.svg`, `moon.svg`, `ticket.svg`)
- **作者**: 本プロジェクトで新規作成（Codex によるコード生成）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 外部素材未使用の独自生成物。CC0 等の別ライセンスは付与していない。
- **クレジット表記**: **不要**
- **改変**: scripts/dev/generate_assets.py から新規生成。外部の画像・楽曲・音声サンプルは不使用。
- **備考**: 再生成: python3 scripts/dev/generate_assets.py。OpenAI と利用者との関係では適用法の範囲で出力の権利は利用者に帰属: https://openai.com/policies/terms-of-use/ 。既存作品・ブランドの再現なし。
- **生成**: Python 3 標準ライブラリ / SVG / ffmpeg / Codex / プロンプトの要点: 星と音の軌道のロゴ、色だけでなく丸・ひし形・矢印で区別するノーツ。

## 音声 (`assets/audio/`)

- **素材名**: 星灯りの楽曲と効果音 (`starlight.ogg`, `moonride.ogg`, `comet.ogg`, `title.ogg`, `select.ogg`, `result-clear.ogg`, `result-fail.ogg`, `hit-coral.wav`, `hit-mint.wav`, `hold.wav`, `fever.wav`, `miss.wav`)
- **作者**: 本プロジェクトで新規作成（Codex によるコード生成）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 外部素材未使用の独自生成物。CC0 等の別ライセンスは付与していない。
- **クレジット表記**: **不要**
- **改変**: scripts/dev/generate_assets.py から新規生成。外部の画像・楽曲・音声サンプルは不使用。
- **備考**: 再生成: python3 scripts/dev/generate_assets.py。OpenAI と利用者との関係では適用法の範囲で出力の権利は利用者に帰属: https://openai.com/policies/terms-of-use/ 。既存作品・ブランドの再現なし。
- **生成**: Python 3 標準ライブラリ / SVG / ffmpeg / Codex / プロンプトの要点: 112 BPM / 72 秒、128 BPM / 75 秒、144 BPM / 70 秒の 3 曲。各曲にドラム・ベース・和音・旋律・中盤の変化・後半の盛り上がりを配置。タイトル・選曲・成功・失敗と 5 種の操作音を個別生成。音源の時刻 0 が第 0 拍。

## キャラクターアニメーション (`assets/characters/`)

- **素材名**: 星灯りのバンドの状態別スプライトシート (`fox-sheet.svg`, `bird-sheet.svg`, `rabbit-sheet.svg`)
- **作者**: 本プロジェクトで新規作成（Codex によるコード生成）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 外部素材未使用の独自生成物。CC0 等の別ライセンスは付与していない。
- **クレジット表記**: **不要**
- **改変**: 独自 SVG キャラクターを待機・拍ダンス・命中・ミス・祝福の 5 状態 × 4 フレームへ展開。
- **備考**: 200 × 240 セル、800 × 1200 のシート。状態は上から idle/dance/hit/miss/celebrate。再生成: python3 scripts/dev/generate_assets.py --images-only。OpenAI と利用者との関係では適用法の範囲で出力の権利は利用者に帰属: https://openai.com/policies/terms-of-use/
- **生成**: Python 3 標準ライブラリ / SVG / Codex / プロンプトの要点: 胴体とは独立した左右の腕、スティック、楽器、耳や羽の角度を変える。まばたき・笑顔・困り顔・祝福の開いた口と星で状態を区別する。

## 画像生成素材 (`assets/generated/`) (`assets/generated/`)

- **素材名**: 祭りの切り絵背景・奏者・提灯 (`festival-night.png`, `fox-taiko.png`, `bird-flute.png`, `rabbit-shamisen.png`, `combo-lantern.png`)
- **作者**: 本プロジェクトで新規生成
- **入手 URL**: https://openai.com/policies/terms-of-use/
- **ライセンス**: OpenAI 利用規約に基づく生成物。外部素材未使用の独自生成物で、CC0 等の別ライセンスは付与していない。
- **クレジット表記**: **不要**
- **改変**: 生成された alpha を保持したまま配置。ファイル名のみ変更し、拡縮・クロマキー加工なし。
- **備考**: 既存作品・ブランドの名称や素材を参照せず、festival-night.png を共通の紙素材・輪郭・配色の画風参照として奏者と提灯を生成。
- **生成**: ChatGPT built-in image_gen / プロンプトの要点: 黒い輪郭紙と朱・藍・山吹・生成りの色紙を重ねた祭りの切り絵。三つの屋台と横歩きの参道、法被姿のキツネ太鼓奏者・鳥の笛奏者・ウサギの三味線風奏者、UI 用提灯。文字・ロゴ・既存キャラクターを入れない。奏者と提灯は透過背景。
