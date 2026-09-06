# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## オリジナル画像 (`assets/art/`)

- **素材名**: 星つむぎの精霊・夜の温室・ロゴ (`piece_1.svg`, `piece_2.svg`, `piece_3.svg`, `piece_4.svg`, `piece_5.svg`, `sky.svg`, `greenhouse.svg`, `foliage.svg`, `panel.svg`, `keyart.svg`, `logo.svg`)
- **作者**: godotpractice プロジェクト
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/blockpuzzle/games/blockpuzzle/scripts/dev/generate_assets.py
- **ライセンス**: 本プロジェクト独自制作。第三者画像の利用なし。ロゴ文字の字体は同梱の OFL フォント
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 画像生成サービス・既存作品の画像は不使用。python3 scripts/dev/generate_assets.py で再生成。ロゴは Noto Sans JP の字形をアウトライン化。
- **生成**: Codex による SVG 記述、Python・fontTools / プロンプトの要点: 夜空の温室。珊瑚の角、翡翠の葉、金の星、紫のしずくの四精霊と灰色の歯車。独自のシルエットと表情。遠景・温室アーチ・手前の植物の三層、金と翡翠の UI、星つむぎのアウトライン文字ロゴ。

## オリジナル音声 (`assets/audio/`)

- **素材名**: 温室の場面別旋律と操作音 (`bgm_title.wav`, `bgm_play.wav`, `bgm_danger.wav`, `bgm_result.wav`, `move.wav`, `rotate.wav`, `land.wav`, `clear.wav`, `chain.wav`, `garbage.wav`, `victory.wav`, `defeat.wav`)
- **作者**: godotpractice プロジェクト
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/blockpuzzle/games/blockpuzzle/scripts/dev/generate_assets.py
- **ライセンス**: 本プロジェクト独自制作。第三者音源の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 22050 Hz・16 bit・モノラル PCM。BGM は残響を先頭へ折り返してループ。既存曲・録音・音声生成サービスは不使用。
- **生成**: Codex による作曲、Python 標準ライブラリの FM・倍音・打楽器合成 / プロンプトの要点: 静かなベルとパッドのタイトル、軽快な操作中のアルペジオ、不協和音を交えた速いピンチ、ゆったりした結果の旋律。移動・回転・着地・消去・連鎖・おじゃま・勝利・敗北の音色を区別。

## フォント (`assets/fonts/`)

- **素材名**: Noto Sans JP (`NotoSansJP.ttf`, `OFL.txt`)
- **作者**: Adobe（2014–2021）
- **入手 URL**: https://fonts.google.com/specimen/Noto+Sans+JP
- **ライセンス**: OFL-1.1
- **クレジット表記**: **必要**
- **改変**: 既存の games/cardbattle/assets/fonts からフォントデータとライセンス全文を複製。フォントデータの変更なし。ロゴでは字形をアウトラインに変換。
- **備考**: SIL Open Font License 1.1 と著作権表示を fonts/OFL.txt に保持。アプリ画面での帰属表記は要求されない。
