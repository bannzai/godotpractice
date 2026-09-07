# 素材クレジット

本作の画面は M PLUS 1 Code のグリフを `Label` / `RichTextLabel` と文字描画で配置し、位置・大きさ・色・発光を Godot のアニメーションで変化させている。画像、SVG、既存作品の名称・画像・音・ロゴは使用していない。

## 音楽・効果音・環境音 (`assets/audio/`)

- **素材名**: 八つの場面の旋律、七つの操作音、地下端末の環境音 (`ambience.wav`, `boss.wav`, `death.wav`, `floor1.wav`, `floor2.wav`, `floor3.wav`, `floor4.wav`, `floor5.wav`, `hit.wav`, `hurt.wav`, `level.wav`, `pickup.wav`, `result.wav`, `select.wav`, `stairs.wav`, `title.wav`)
- **作者**: godotpractice プロジェクト
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/main/games/roguelike/scripts/dev/generate_audio.py
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成は `python3 scripts/dev/generate_audio.py`。22,050 Hz・16 bit・stereo PCM。既存の曲・録音は参照していない。
- **生成**: Codex による独自作曲、Python 標準ライブラリ / プロンプトの要点: タイトル・各5階・番人・結果で旋律、速度、調、主楽器、打楽器密度を変える。倍音・FMの鐘・撥弦・リード・パッド・低音・ノイズ打楽器を合成する。環境音は低い機械唸り、周期の異なる水滴、活字端末のクリックを固定シードで重ね、探索中のBGMの下でループする。

## 表示フォント (`assets/fonts/`)

- **素材名**: M PLUS 1 Code (`MPLUS1Code[wght].ttf`, `OFL.txt`)
- **作者**: The M+ FONTS Project Authors（2021）
- **入手 URL**: https://fonts.google.com/specimen/M+PLUS+1+Code
- **上流 URL**: https://github.com/coz-m/MPLUS_FONTS
- **ライセンス**: SIL Open Font License 1.1
- **クレジット表記**: **必要**（著作権表示と OFL 全文を同梱）
- **改変**: なし。Google Fonts の可変フォントを元のファイル名で同梱
- **備考**: `game-asset-search` の Google Fonts 検索・取得経路を使用。`OFL.txt` 冒頭にフォント固有の著作権表示を保持し、全エクスポートの `include_filter` で CREDITS と OFL を同梱する。
