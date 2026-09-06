# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## 独自画像 (`assets/`)

- **素材名**: 黄昏の灯砦の図案 (`actors/arrow.svg`, `actors/mortar.svg`, `actors/frost.svg`, `actors/sun.svg`, `actors/runner.svg`, `actors/armor.svg`, `actors/flyer.svg`, `actors/swarm.svg`, `actors/boss.svg`, `background.svg`, `foreground.svg`, `keyart.svg`, `logo.svg`, `base.svg`, `ui/panel.svg`, `ui/site.svg`, `ui/coin.svg`, `ui/heart.svg`)
- **作者**: bannzai（Codexを利用）
- **入手 URL**: https://openai.com/policies/terms-of-use/
- **ライセンス**: プロジェクト独自生成物。第三者素材なし（ロゴの字形は同梱OFLフォント）。第三者へのライセンス付与はしていない
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 scripts/dev/generate_art.py。128pxセル、6列5行（idle/move/attack/hurt/death）。生成と記録は同内容で冪等。ロゴはZen Maru Gothicの字形から輪郭を取得。フォントの帰属は下記参照。
- **生成**: CodexによるPythonコード作成、Python標準ライブラリとfontToolsによるSVG生成 / プロンプトの要点: 深緑の谷、金の灯、紺の石造り。弩・火砲・氷晶・太陽砲の4塔と狐・甲羅獣・羽獣・茸・鹿角巨獣の5敵。各体5動作6フレームで部位を動かす。多層背景・灯砦・日本語ロゴ・UI。

## 独自音声 (`assets/audio/`)

- **素材名**: 黄昏の灯砦の旋律と効果音 (`title.wav`, `stage.wav`, `boss.wav`, `win.wav`, `lose.wav`, `arrow.wav`, `mortar.wav`, `frost.wav`, `sun.wav`, `build.wav`, `hit.wav`, `death.wav`, `wave.wav`, `base.wav`)
- **作者**: bannzai（Codexを利用）
- **入手 URL**: https://openai.com/policies/terms-of-use/
- **ライセンス**: プロジェクト独自生成物。第三者素材なし。第三者へのライセンス付与はしていない
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 scripts/dev/generate_audio.py。22050 Hz、16 bit、stereo PCM。音源合成の共通処理は同一リポジトリdeckrogueの独自生成スクリプトを利用し、楽譜と効果音を新規作成。
- **生成**: CodexによるPythonコード作成、Python標準ライブラリによるPCM合成 / プロンプトの要点: 独自楽譜の5場面BGM。撥弦・笛・倍音パッド・低音・金管・ベル・ノイズ打楽器。弩の弦、火砲の爆風、氷の金属部分音、太陽砲の上昇音など9効果音。外部旋律や録音サンプル不使用。

## フォント (`assets/fonts/`)

- **素材名**: Zen Maru Gothic Medium (`font.ttf`, `OFL.txt`)
- **作者**: The Zen Maru Gothic Project Authors
- **入手 URL**: https://fonts.google.com/specimen/Zen+Maru+Gothic
- **ライセンス**: OFL-1.1
- **クレジット表記**: **必要**
- **改変**: ファイル名をZenMaruGothic-Medium.ttfからfont.ttfに変更。フォントデータは改変なし
- **備考**: Copyright 2021 The Zen Maru Gothic Project Authors (https://github.com/googlefonts/zen-marugothic)。同一リポジトリのsurvivorsから、フォントとOFL全文を複製。取得元 https://raw.githubusercontent.com/google/fonts/main/ofl/zenmarugothic/ZenMaruGothic-Medium.ttf 。配布物にもOFL.txtを同梱する。
