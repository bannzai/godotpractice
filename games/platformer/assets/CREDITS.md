# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## 画像 (`assets/images/`)

- **素材名**: 空の配達人のオリジナル画像 (`player.svg`, `walker.svg`, `shell.svg`, `cloud.svg`, `crystal.svg`, `logo.svg`)
- **作者**: 本プロジェクトで制作
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/platformer/games/platformer/scripts/dev/generate_assets.py
- **ライセンス**: 本プロジェクトのオリジナル生成素材。第三者素材は含まない
- **クレジット表記**: **不要**
- **改変**: 第 1 ラウンドの元画像を保持。第 2 ラウンドの差し替え素材は次項に記録
- **備考**: 外部画像生成サービスは不使用。CC0 として扱わず、生成コードとともに本プロジェクトへ同梱する。
- **生成**: Codex による SVG コード作成・Python 標準ライブラリ / プロンプトの要点: 空の配達人、浮島草原と青い結晶地下。温かい色のベクター画。既存作品の名称や画像を使わない

- **素材名**: 空の郵便路の第 2 ラウンド画像 (`player_sheet.svg`, `walker_sheet.svg`, `shell_sheet.svg`, `coin.svg`, `power.svg`, `item_block.svg`, `item_block_used.svg`, `goal.svg`, `ground.svg`, `ground_fill.svg`, `underground.svg`, `underground_fill.svg`, `landscape_far.svg`, `landscape_near.svg`, `cave_far.svg`, `cave_near.svg`, `title_keyart.svg`, `title_logo.svg`, `ui_coin.svg`, `ui_life.svg`, `ui_time.svg`, `ui_score.svg`, `particle.svg`)
- **作者**: 本プロジェクトで制作
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/polish/platformer/games/platformer/scripts/dev/generate_polish_art.py
- **ライセンス**: 本プロジェクトのオリジナル生成素材。第三者素材は含まない
- **クレジット表記**: **不要**
- **改変**: 配達人・森の生き物・結晶の甲虫を別デザインで描き直し、キャラクター別の全 102 フレームを制作。既存の収集物・地形・ポストを再描画し、使用済みケース・多層背景・タイトル・UI・パーティクルを追加
- **備考**: SVG パスとグラデーションだけで描画し、外部の画像・ロゴ・商標・フォント輪郭は使用しない。スプライトは各 6 列、配達人は 64×80 セルの 7 行、敵は 64×56 セルの 5 行。生成コードを同梱し、CC0 として扱わない。
- **生成**: Codex による SVG コード作成・Python 標準ライブラリ math/pathlib / プロンプトの要点: 空中郵便島の温かい絵本風ベクター画。琥珀色の服と青緑の帽子の配達人、芽のある橙色の森の生き物、青緑の結晶の甲虫。姿勢・脚・腕・表情・小物の動きをフレーム別に描く。金色の郵便収集物、透明背景の草原と結晶洞窟、羽のある封筒ロゴ。既存作品を模倣しない。

## 音楽と効果音 (`assets/audio/`)

- **素材名**: 空の配達人のオリジナル音声 (`title.wav`, `stage1.wav`, `stage2.wav`, `result.wav`, `game_over.wav`, `jump.wav`, `stomp.wav`, `coin.wav`, `power.wav`, `death.wav`, `clear.wav`, `hurt.wav`, `ui.wav`)
- **作者**: 本プロジェクトで制作
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/polish/platformer/games/platformer/scripts/dev/generate_polish_audio.py
- **ライセンス**: 本プロジェクトのオリジナル生成素材。第三者素材は含まない
- **クレジット表記**: **不要**
- **改変**: 第 2 ラウンドで全曲・効果音を再作曲し、タイトル・結果・ゲームオーバー曲と被弾・UI 効果音を追加
- **備考**: 既存曲・録音・サンプルを使用しない。撥弦・ベル・リード・和音・ベース・ドラムを 32 kHz / 16-bit ステレオ PCM に合成。BGM は音符の余韻と残響を循環させ、効果音は両端を無音にする。生成スクリプトの --check でピーク・DC・境界を検査できる。CC0 として扱わず、生成コードとともに本プロジェクトへ同梱する。
- **生成**: Codex による作曲コード作成・Python 標準ライブラリ math/random/array/wave / プロンプトの要点: 温かな空の配達人の世界。タイトルはベル、草原は活発な撥弦とドラム、地下は低音の反復と結晶の響き、結果は上昇する祝福の旋律、ゲームオーバーは穏やかな下降旋律。既存作品を模倣しない。

## フォント (`assets/fonts/`)

- **素材名**: Noto Sans JP (`NotoSansJP[wght].ttf`, `OFL.txt`)
- **作者**: Adobe（Copyright 2014-2021 Adobe）
- **入手 URL**: https://fonts.google.com/specimen/Noto+Sans+JP
- **ライセンス**: SIL Open Font License 1.1
- **クレジット表記**: **必要**
- **改変**: なし
- **備考**: Google Fonts の ofl/notosansjp より取得。フォント固有の著作権表示、Reserved Font Name Source、OFL 全文を OFL.txt に保持。ライセンス: https://openfontlicense.org/open-font-license-official-text/ 。アプリ画面での表示義務はなく、同梱ライセンスを保持する。
