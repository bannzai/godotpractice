# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## フォント (`assets/fonts/`)

- **素材名**: Zen Antique (`ZenAntique-Regular.ttf`, `OFL.txt`)
- **作者**: The Zen Antique Project Authors（2021）
- **入手 URL**: https://fonts.google.com/specimen/Zen+Antique
- **ライセンス**: OFL-1.1
- **クレジット表記**: **必要**
- **改変**: Google Fonts から取得した通常ウェイト。フォントデータは変更なし
- **備考**: 著作権表示および SIL Open Font License 1.1 全文を fonts/OFL.txt に同梱。アプリ画面での帰属表示は要求されない。

## オリジナル画像 (`assets/art/`)

- **素材名**: 星図の対戦盤と四属性の精霊 (`arena.svg`, `fire.svg`, `water.svg`, `wind.svg`, `earth.svg`, `card_back.svg`)
- **作者**: godotpractice プロジェクト
- **入手 URL**: https://github.com/bannzai/godotpractice/tree/main/games/cardbattle/scripts/dev/generate_assets.py
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 第三者画像の生成サービスは使用していない。再生成は python3 scripts/dev/generate_assets.py。
- **生成**: Codex による SVG 記述、Python 標準ライブラリ / プロンプトの要点: 紺・青緑・金の天文学的な対戦盤、火・水・風・土のオリジナル精霊、星図のカード裏。既存作品の名称や素材を参照しない。

## オリジナル音声 (`assets/audio/`)

- **素材名**: 静かな星の旋律と操作音 (`bgm.wav`, `draw.wav`, `summon.wav`, `attack.wav`, `destroy.wav`, `damage.wav`, `victory.wav`)
- **作者**: godotpractice プロジェクト
- **入手 URL**: https://github.com/bannzai/godotpractice/tree/main/games/cardbattle/scripts/dev/generate_assets.py
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 既存の曲・録音・サンプルを使用していない。22,050 Hz・16 bit・モノラル PCM。BGM はループ境界で残響を重ねている。
- **生成**: Codex による作曲・Python 標準ライブラリの正弦波合成 / プロンプトの要点: 穏やかな短調アルペジオの 16 秒ループ、ドロー・召喚・攻撃・破壊・被ダメージ・勝利を区別する短い音。

## カード別イラスト (`assets/art/cards/`)

- **素材名**: 日輪と月影の全 30 カード (`boost.svg`, `destroy.svg`, `draw.svg`, `m00.svg`, `m01.svg`, `m02.svg`, `m03.svg`, `m04.svg`, `m05.svg`, `m06.svg`, `m07.svg`, `m08.svg`, `m09.svg`, `m10.svg`, `m11.svg`, `m12.svg`, `m13.svg`, `m14.svg`, `m15.svg`, `m16.svg`, `m17.svg`, `m18.svg`, `m19.svg`, `m20.svg`, `m21.svg`, `m22.svg`, `m23.svg`, `mist.svg`, `snare.svg`, `spark.svg`)
- **作者**: godotpractice プロジェクト
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/polish/cardbattle/games/cardbattle/scripts/dev/generate_card_art.py
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 画像生成サービスや第三者画像を使用していない。再生成は python3 scripts/dev/generate_card_art.py。
- **生成**: Codex による独自 SVG 記述・Python 標準ライブラリ / プロンプトの要点: 紺・青緑・金の天体ファンタジー。24 体の剣士・斥候・獣・翼ある衛士・魔術師・巨兵・槍使い・竜・番人・戦乙女・王を個別の輪郭、装備、顔、姿勢で描く。6 種の魔法・罠も独自の絵にする。320×240 SVG、陰影を持つ金属・布・宝石。

## 生成したアール・ヌーヴォー画像 (`assets/art/generated/`)

- **素材名**: 全30カードの完成原画、共通装飾枠、木製卓上 (`boost.png`, `destroy.png`, `draw.png`, `m00.png`, `m01.png`, `m02.png`, `m03.png`, `m04.png`, `m05.png`, `m06.png`, `m07.png`, `m08.png`, `m09.png`, `m10.png`, `m11.png`, `m12.png`, `m13.png`, `m14.png`, `m15.png`, `m16.png`, `m17.png`, `m18.png`, `m19.png`, `m20.png`, `m21.png`, `m22.png`, `m23.png`, `mist.png`, `snare.png`, `spark.png`, `card_frame.png`, `table.png`)
- **生成手段**: OpenAI の組み込み `image_gen`
- **入力画像**: なし。各画像を文章による指示から新規生成
- **ライセンス**: 第三者素材ではない生成物。利用条件は生成時の OpenAI サービス条件に従う
- **クレジット表記**: **不要**
- **改変**: 生成結果を ImageMagick でカード原画は724×543、共通枠は530×742、卓上は1280×720へ縮小し、メタデータを除去。カード原画は共通枠の内側へ Godot で合成
- **備考**: 30原画はSHA-256で相互に異なることを selfcheck で検証する。共通枠は中央と四隅が透明なRGBA画像。既存作品の名称・画像・ロゴ、参照画像は使っていない。
- **プロンプトの要点**: 1900年前後のアール・ヌーヴォー印刷物、金箔と深緑、流れる植物曲線、装飾的な人物画。24体は暖色の温室と青銀の夜園に分け、人物・獣・植物・武具・姿勢をカードごとに変える。6種の魔法・罠は花冠、封印鏡、書物、蔓の罠、霧の香炉、火花の機巧という静物。共通枠は金の蔓・花・孔雀羽、卓上はウォルナット材・深緑フェルト・真鍮ランプ・花・本・サイコロを真上から描く。

## アニメーション用のキャラ部位 (`assets/art/characters/`)

- **素材名**: 24 体の頭・胴・装備とカード背景 (`m00/accent.svg`, `m00/background.svg`, `m00/body.svg`, `m00/head.svg`, `m01/accent.svg`, `m01/background.svg`, `m01/body.svg`, `m01/head.svg`, `m02/accent.svg`, `m02/background.svg`, `m02/body.svg`, `m02/head.svg`, `m03/accent.svg`, `m03/background.svg`, `m03/body.svg`, `m03/head.svg`, `m04/accent.svg`, `m04/background.svg`, `m04/body.svg`, `m04/head.svg`, `m05/accent.svg`, `m05/background.svg`, `m05/body.svg`, `m05/head.svg`, `m06/accent.svg`, `m06/background.svg`, `m06/body.svg`, `m06/head.svg`, `m07/accent.svg`, `m07/background.svg`, `m07/body.svg`, `m07/head.svg`, `m08/accent.svg`, `m08/background.svg`, `m08/body.svg`, `m08/head.svg`, `m09/accent.svg`, `m09/background.svg`, `m09/body.svg`, `m09/head.svg`, `m10/accent.svg`, `m10/background.svg`, `m10/body.svg`, `m10/head.svg`, `m11/accent.svg`, `m11/background.svg`, `m11/body.svg`, `m11/head.svg`, `m12/accent.svg`, `m12/background.svg`, `m12/body.svg`, `m12/head.svg`, `m13/accent.svg`, `m13/background.svg`, `m13/body.svg`, `m13/head.svg`, `m14/accent.svg`, `m14/background.svg`, `m14/body.svg`, `m14/head.svg`, `m15/accent.svg`, `m15/background.svg`, `m15/body.svg`, `m15/head.svg`, `m16/accent.svg`, `m16/background.svg`, `m16/body.svg`, `m16/head.svg`, `m17/accent.svg`, `m17/background.svg`, `m17/body.svg`, `m17/head.svg`, `m18/accent.svg`, `m18/background.svg`, `m18/body.svg`, `m18/head.svg`, `m19/accent.svg`, `m19/background.svg`, `m19/body.svg`, `m19/head.svg`, `m20/accent.svg`, `m20/background.svg`, `m20/body.svg`, `m20/head.svg`, `m21/accent.svg`, `m21/background.svg`, `m21/body.svg`, `m21/head.svg`, `m22/accent.svg`, `m22/background.svg`, `m22/body.svg`, `m22/head.svg`, `m23/accent.svg`, `m23/background.svg`, `m23/body.svg`, `m23/head.svg`)
- **作者**: godotpractice プロジェクト
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/polish/cardbattle/games/cardbattle/scripts/dev/generate_card_art.py
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 画像生成サービスや第三者画像を使用していない。再生成は python3 scripts/dev/generate_card_art.py。
- **生成**: Codex による独自 SVG 記述・Python 標準ライブラリ / プロンプトの要点: 各キャラを同じ 320×240 キャンバスの透明な head・body・accent と背景へ分離。装備は武器・翼・尾・炎・書物・結晶をキャラごとに選ぶ。形状はカード原画を唯一の定義として分割している。

## 多層背景とタイトル (`assets/art/`)

- **素材名**: 天文台の多層背景と二王の紋章 (`far.svg`, `mid.svg`, `near.svg`, `title_keyart.svg`, `logo.svg`)
- **作者**: godotpractice プロジェクト
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/polish/cardbattle/games/cardbattle/scripts/dev/generate_card_art.py
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 画像生成サービスや第三者画像を使用していない。再生成は python3 scripts/dev/generate_card_art.py。
- **生成**: Codex による独自 SVG 記述・Python 標準ライブラリ / プロンプトの要点: 星雲と星の遠景、天球儀と尖塔の中景、柱と対戦盤の近景を独立した SVG にする。日輪の王と星辰の王のタイトル用キーアート、金と青緑の星環紋章。
## 場面別のオリジナル音声 (`assets/audio/`)

- **素材名**: 五つの旋律、効果音、机上の環境音 (`bgm_title.wav`, `bgm_duel.wav`, `bgm_boss.wav`, `bgm_victory.wav`, `bgm_defeat.wav`, `draw.wav`, `summon.wav`, `attack.wav`, `destroy.wav`, `damage.wav`, `victory.wav`, `boost.wav`, `trap.wav`, `transition.wav`, `ambience.wav`)
- **作者**: godotpractice プロジェクト
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/main/games/cardbattle/scripts/dev/generate_audio.py
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: 第1ラウンドの効果音を再作曲・再合成。場面別BGMと強化・罠・遷移音を新規制作。今回、全場面へ小さく重ねる12秒の環境音を追加
- **備考**: 22,050 Hz・16 bit・ステレオ PCM。既存楽曲・録音・サンプルは不使用。固定の旋律・乱数による再現生成。BGMと環境音はループする。再生成は python3 scripts/dev/generate_audio.py。
- **生成**: Codex による作曲、Python標準ライブラリによる倍音・FM・ノイズ・打楽器合成 / プロンプトの要点: タイトルは鐘、決闘は低音と打楽器、強敵は速い金管風の短調、勝利は長調、敗北は疎らな短調。環境音は暖炉の小さな爆ぜ、紙の擦れ、左右に揺れる振り子、低い室内の響きで、木の机を囲む夜の対戦会を表す。
