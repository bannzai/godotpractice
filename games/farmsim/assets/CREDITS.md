# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## キャラクター (`assets/characters/`)

- **素材名**: 主人公・花売り・鶏の独立スプライトシート (`chicken.svg`, `farmer.svg`, `merchant.svg`)
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成元: scripts/dev/generate_assets.py。既存作品の素材や画像生成サービスは未使用。第三者への追加ライセンス付与は行っていない。
- **生成**: Codex による Python / SVG コード作成、Python 3 標準ライブラリ / プロンプトの要点: 128px 4列6行。待機・移動・鍬・水やり・収穫・疲労の6動作。麦わら帽子とオーバーオール、眼鏡と花籠、鶏冠と羽を固有の輪郭で描き分ける。

## 作物 (`assets/crops/`)

- **素材名**: 4種の作物の成長段階 (`carrot_growing.svg`, `carrot_ripe.svg`, `carrot_seed.svg`, `carrot_sprout.svg`, `corn_growing.svg`, `corn_ripe.svg`, `corn_seed.svg`, `corn_sprout.svg`, `tomato_growing.svg`, `tomato_ripe.svg`, `tomato_seed.svg`, `tomato_sprout.svg`, `turnip_growing.svg`, `turnip_ripe.svg`, `turnip_seed.svg`, `turnip_sprout.svg`)
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成元: scripts/dev/generate_assets.py。既存作品の素材や画像生成サービスは未使用。第三者への追加ライセンス付与は行っていない。
- **生成**: Codex による Python / SVG コード作成、Python 3 標準ライブラリ / プロンプトの要点: カブ・ニンジン・トマト・トウモロコシ各4段階。種・発芽・成長・収穫を葉と実で表す。

## 建物と小物 (`assets/props/`)

- **素材名**: 農園の建物・道具置き場 (`fence.svg`, `house.svg`, `shipping.svg`, `shop.svg`, `tree.svg`, `well.svg`)
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成元: scripts/dev/generate_assets.py。既存作品の素材や画像生成サービスは未使用。第三者への追加ライセンス付与は行っていない。
- **生成**: Codex による Python / SVG コード作成、Python 3 標準ライブラリ / プロンプトの要点: 家・井戸・出荷箱・商店・木・柵。深緑の輪郭、クリーム色の壁、琥珀色の木工。

## UI (`assets/ui/`)

- **素材名**: 農具アイコンと農園の紋章 (`hand.svg`, `hoe.svg`, `logo.svg`, `seed.svg`, `water.svg`)
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成元: scripts/dev/generate_assets.py。既存作品の素材や画像生成サービスは未使用。第三者への追加ライセンス付与は行っていない。
- **生成**: Codex による Python / SVG コード作成、Python 3 標準ライブラリ / プロンプトの要点: 鍬・種袋・じょうろ・手・葉と太陽のロゴ。画像内文字を使わない。

## 背景 (`assets/backgrounds/`)

- **素材名**: 三層の農園風景とタイトル画像 (`far.svg`, `mid.svg`, `near.svg`, `title.svg`)
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成元: scripts/dev/generate_assets.py。既存作品の素材や画像生成サービスは未使用。第三者への追加ライセンス付与は行っていない。
- **生成**: Codex による Python / SVG コード作成、Python 3 標準ライブラリ / プロンプトの要点: 遠景の空と丘、中景の農道と木立、前景の葉と花、タイトル用の楕円の農園と主人公。

## 音源 (`assets/audio/`)

- **素材名**: 場面別BGMと効果音 (`fail.wav`, `festival.wav`, `harvest.wav`, `hoe.wav`, `next_day.wav`, `result.wav`, `seed.wav`, `ship.wav`, `spring.wav`, `success.wav`, `summer.wav`, `title.wav`, `ui.wav`, `water.wav`)
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: BGM終端8msの接続補正、SE先頭2ms・末尾10msの音量包絡を追加
- **備考**: 再生成元: scripts/dev/generate_assets.py。既存作品の素材や画像生成サービスは未使用。第三者への追加ライセンス付与は行っていない。--verify で全素材の再生成とSHA-256一致、PCMのクリッピング・無音・BGM接続境界を検査する。
- **生成**: Codex による Python / SVG コード作成、Python 3 標準ライブラリ / プロンプトの要点: 22050 Hz 16bit stereo PCM。倍音撥弦・木琴・低音・ブラシ打楽器・分散和音を重ねる。タイトル・春・夏・盛り上がり・結果のBGMと道具・出荷・翌日・UI効果音。外部録音・既存楽曲は未使用。

## 地形 (`assets/tiles/`)

- **素材名**: 農園の地形アトラス (`terrain.svg`)
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成元: scripts/dev/generate_assets.py。既存作品の素材や画像生成サービスは未使用。第三者への追加ライセンス付与は行っていない。
- **生成**: Codex による Python / SVG コード作成、Python 3 標準ライブラリ / プロンプトの要点: 64px横6タイル。草・道・耕した土・水を含む土・池・花。

## フォント (`assets/fonts/`)

- **素材名**: M PLUS Rounded 1c Regular (`MPLUSRounded1c-Regular.ttf`, `OFL.txt`)
- **作者**: The Rounded M+ Project Authors
- **入手 URL**: https://fonts.google.com/specimen/M+PLUS+Rounded+1c
- **ライセンス**: OFL-1.1
- **クレジット表記**: **必要**
- **改変**: なし
- **備考**: 既存 monsterquest の検証済みフォントをそのまま複製。Copyright 2016 The Rounded M+ Project Authors. 同梱 OFL.txt の著作権表示とライセンス全文を保持。
