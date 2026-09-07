# 素材クレジット

外部素材と生成素材の出典・ライセンス・再生成方法を記録する。

## 青焼きの街・建物・住民

- **素材名**: 青焼き図面、等角投影の道路と建物、地形、寸法線、ハッチング
- **作者**: 本プロジェクトで新規作成（Codex によるコード生成）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 外部素材未使用の独自生成物。CC0 等の別ライセンスは付与していない
- **クレジット表記**: **不要**
- **改変**: `scripts/backdrop.gd`、`scripts/city_view.gd`、`scripts/city_actor.gd` が `Line2D` / `Polygon2D` と CanvasItem の描画 API で実行時に生成
- **生成の要点**: 青地に白〜水色の線、等角投影、建物ごとに異なるシルエットと設備記号。画像ファイルは使用しない

## 図面の紙質感

- **素材名**: 青焼き用 CanvasItem シェーダ (`assets/shaders/blueprint_paper.gdshader`)
- **作者**: 本プロジェクトで新規作成（Codex によるコード生成）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 外部素材未使用の独自生成物。CC0 等の別ライセンスは付与していない
- **クレジット表記**: **不要**
- **生成の要点**: UV 座標の擬似乱数で粒子と繊維を重ね、折り目の白化と周辺の濃淡を加える

## 音楽・環境音・効果音 (`assets/audio/`)

- **素材名**: 場面別音楽 (`title.wav`, `town.wav`, `city.wav`, `result.wav`)、製図室の環境音 (`ambience.wav`)、効果音 (`build.wav`, `click.wav`, `demolish.wav`, `month.wav`, `alert.wav`)
- **作者**: 本プロジェクトで新規作成（Codex による Python 波形合成）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 外部の楽曲・音声サンプル未使用の独自生成物。CC0 等の別ライセンスは付与していない
- **クレジット表記**: **不要**
- **改変**: 再生成は `python3 scripts/dev/generate_assets.py`
- **生成の要点**: 22,050 Hz / 16 bit。ベル、鉛筆、定規、紙の擦過音を想起させる倍音とノイズを合成。音楽と環境音はステレオ・ループ、効果音はモノラル

## 日本語フォント (`assets/fonts/`)

- **素材名**: IBM Plex Sans JP Regular (`IBMPlexSansJP-Regular.ttf`, `OFL.txt`)
- **作者**: IBM Corp.
- **入手 URL**: https://github.com/google/fonts/tree/main/ofl/ibmplexsansjp
- **ライセンス**: SIL Open Font License 1.1
- **クレジット表記**: **必要**
- **改変**: なし。Google Fonts 公式リポジトリのフォント本体と、著作権表示を含む OFL 全文を同梱
- **備考**: Reserved Font Name は "Plex"。画面上のクレジット表記は任意
