# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## 独自画像 (`assets/`)

- **素材名**: 手直し前の図案と補助UI (`actors/arrow.svg`, `actors/mortar.svg`, `actors/frost.svg`, `actors/sun.svg`, `actors/runner.svg`, `actors/armor.svg`, `actors/flyer.svg`, `actors/swarm.svg`, `actors/boss.svg`, `background.svg`, `foreground.svg`, `keyart.svg`, `logo.svg`, `base.svg`, `ui/panel.svg`, `ui/site.svg`, `ui/coin.svg`, `ui/heart.svg`)
- **作者**: bannzai（Codexを利用）
- **入手 URL**: https://openai.com/policies/terms-of-use/
- **ライセンス**: プロジェクト独自生成物。第三者素材なし（ロゴの字形は同梱OFLフォント）。第三者へのライセンス付与はしていない
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 前回ラウンドの手続きSVG。再生成: python3 scripts/dev/generate_art.py。現在の主景・塔・敵は下記の画像生成物へ置換し、heart等の補助UIだけを継続利用する。生成と記録は同内容で冪等。ロゴの字形は同梱OFLフォントから取得する。
- **生成**: CodexによるPythonコード作成、Python標準ライブラリとfontToolsによるSVG生成 / プロンプトの要点: 深緑の谷、金の灯、紺の石造り。弩・火砲・氷晶・太陽砲の4塔と狐・甲羅獣・羽獣・茸・鹿角巨獣の5敵。各体5動作6フレームで部位を動かす。多層背景・灯砦・日本語ロゴ・UI。

- **素材名**: 刺繍タペストリーの塔・敵・長景 (`tapestry/towers.png`, `tapestry/enemies.png`, `tapestry/landscape.png`)
- **作者**: bannzai（OpenAI image_genを利用）
- **入手 URL**: https://openai.com/policies/terms-of-use/
- **ライセンス**: プロジェクト独自生成物。第三者素材・入力画像なし。第三者へのライセンス付与はしていない
- **クレジット表記**: **不要**
- **改変**: 生成画像のalpha・寸法を保ったまま配置。実行時にAtlasTextureで等分表示し、ファイル自体の切り抜き・拡縮・色変換はしていない
- **備考**: `towers.png` は左から弩・臼砲・氷筒・陽光の4塔、`enemies.png` は左から斥候・重装兵・飛行獣・小鬼群・森の巨獣の5敵。固有作品の画像・人物・ロゴを参照していない。
- **生成**: OpenAI built-in image_gen / プロンプトの要点: 粗い亜麻布と太い毛糸、チェーンステッチと伏せ縫い、平面的な横向き像、亜麻色・茜・褪せた藍・煤茶・苔緑・黄土の限定色。地形は月夜の森から川と石橋を経て夜明けの灯砦へ一本の道が続く横長構図。文字・枠・透かし・既存作品の再現を入れない。

- **素材名**: 織物目の画面シェーダー (`shaders/tapestry.gdshader`)
- **作者**: bannzai（Codexを利用）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: プロジェクト独自制作。第三者素材なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: GL Compatibility の canvas_item で、縦横の糸筋と微細な色むらを画面全体へ重ねる。
- **生成**: CodexによるGLSLコード作成 / プロンプトの要点: 生成画像・巻物UI・ゲーム描画を同じ織物面として統一し、文字の可読性を損なわない低強度の規則模様。

## 独自音声 (`assets/audio/`)

- **素材名**: 黄昏の灯砦の旋律・効果音・環境音 (`title.wav`, `stage.wav`, `boss.wav`, `win.wav`, `lose.wav`, `ambience.wav`, `arrow.wav`, `mortar.wav`, `frost.wav`, `sun.wav`, `build.wav`, `hit.wav`, `death.wav`, `wave.wav`, `base.wav`)
- **作者**: bannzai（Codexを利用）
- **入手 URL**: https://openai.com/policies/terms-of-use/
- **ライセンス**: プロジェクト独自生成物。第三者素材なし。第三者へのライセンス付与はしていない
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: `python3 scripts/dev/generate_audio.py --out-dir assets`。22050 Hz、16 bit、stereo PCM。`--print-spec` で検査定義を出力する。音源合成の共通処理は同一リポジトリdeckrogueの独自生成スクリプトを利用し、楽譜・効果音・環境音を新規作成。
- **生成**: CodexによるPythonコード作成、Python標準ライブラリによるPCM合成 / プロンプトの要点: 独自楽譜の5場面BGM。撥弦・笛・倍音パッド・低音・金管・ベル・ノイズ打楽器。弩の弦、火砲の爆風、氷の金属部分音、太陽砲の上昇音など9効果音。固定seedの風、旗布、焚き火、木の軋みを重ねた継ぎ目のない16秒の環境音。外部旋律や録音サンプル不使用。

## フォント (`assets/fonts/`)

- **素材名**: Zen Kurenaido Regular (`ZenKurenaido-Regular.ttf`, `OFL.txt`)
- **作者**: The Zen Kurenaido Project Authors
- **入手 URL**: https://github.com/google/fonts/tree/main/ofl/zenkurenaido
- **ライセンス**: OFL-1.1
- **クレジット表記**: **必要**
- **改変**: なし
- **備考**: Copyright 2021 The Zen Kurenaido Project Authors (https://github.com/googlefonts/zen-kurenaido)。取得元 https://raw.githubusercontent.com/google/fonts/main/ofl/zenkurenaido/ZenKurenaido-Regular.ttf 。配布物にもOFL.txtを同梱する。
