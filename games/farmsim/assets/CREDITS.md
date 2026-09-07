# 素材クレジット

## CC0 原写真 (`assets/source_photos/`)

以下は Wikimedia Commons の各ファイルページで CC0 1.0 Universal を確認して取得した。生成スクリプトでトリミング、グレースケール化、3値化、減色、紙目との乗算、版ずれ風のかすれを加えている。

- **古紙テクスチャ** (`paper_cc0.jpg`) — 作者: leonardoai / ライセンス: CC0 1.0 / https://commons.wikimedia.org/wiki/File:Old_Paper_texture.jpg
- **山間の農場写真** (`farm_cc0.jpg`) — 作者: Percy Benzie Abery、所蔵: National Library of Wales / ライセンス: CC0 1.0 / https://commons.wikimedia.org/wiki/File:Farm_in_rural_setting_(1293838).jpg
- **にんじん写真** (`carrot_cc0.jpg`) — 作者: MarkBuckawicki / ライセンス: CC0 1.0 / https://commons.wikimedia.org/wiki/File:Carrots_on_Display.jpg
- **かぶ写真** (`turnip_cc0.jpg`) — 作者: Hans Braxmeier / ライセンス: CC0 1.0 / https://commons.wikimedia.org/wiki/File:Turnip-5743_-_Hans_Braxmeier.jpg
- **とうもろこし写真** (`corn_cc0.jpg`) — 作者: Ocdp / ライセンス: CC0 1.0 / https://commons.wikimedia.org/wiki/File:Corn_001.jpg
- **トマト写真** (`tomato_cc0.jpg`) — 作者: Carola Hornbach / ライセンス: CC0 1.0 / https://commons.wikimedia.org/wiki/File:Tomato_(259888895).jpeg

クレジット表記は CC0 のため不要だが、出典と加工経路を追跡できるよう記録している。

## 版画 PNG (`assets/backgrounds/`、`assets/crops/`)

- **背景**: `far.png`, `mid.png`, `near.png`, `title.png`, `village_map.png`
- **作物**: `carrot_seed.png`, `carrot_sprout.png`, `carrot_growing.png`, `carrot_ripe.png`, `turnip_seed.png`, `turnip_sprout.png`, `turnip_growing.png`, `turnip_ripe.png`, `corn_seed.png`, `corn_sprout.png`, `corn_growing.png`, `corn_ripe.png`, `tomato_seed.png`, `tomato_sprout.png`, `tomato_growing.png`, `tomato_ripe.png`
- **生成手段**: `scripts/dev/generate_assets.py` と Pillow。原写真を固定の閾値で3値化し、深緑・朱・黄土・茶墨の少色パレットへ写像して、古紙の明暗とかすれを合成する。作物は写真の質感を、種・芽・成長・収穫のマスクに通した。
- **プロンプトの要点**: 昭和の年賀状に刷った芋版、輪郭のわずかな欠け、紙の目、手作業の版ずれ、山里の農場と村の道しるべ。
- **ライセンス**: 上記 CC0 原写真の加工物と、本プロジェクトで制作した描画コードによる生成物。追加のクレジット表記は不要。

## 手続き生成 PNG (`assets/characters/`、`assets/props/`、`assets/tiles/`、`assets/ui/`)

- **キャラクター**: `chicken.png`, `farmer.png`, `merchant.png`
- **建物・小物**: `fence.png`, `house.png`, `shipping.png`, `shop.png`, `tree.png`, `well.png`
- **地形**: `terrain.png`
- **UI**: `hand.png`, `hoe.png`, `logo.png`, `seed.png`, `water.png`
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: 不要
- **生成手段**: `scripts/dev/generate_assets.py` と Pillow。固定座標の図形と上記古紙テクスチャを使い、PNG に直接描画する。
- **プロンプトの要点**: 128px・4列6行の農場主、商店主、ニワトリ。待機・歩行・耕作・水やり・収穫・疲労の各4コマ。家、井戸、種屋、出荷箱、畑、農具を同じ少色の芋版調で描き分ける。

## 音源 (`assets/audio/`)

- **場面別 BGM と効果音**: `fail.wav`, `festival.wav`, `harvest.wav`, `hoe.wav`, `next_day.wav`, `result.wav`, `seed.wav`, `ship.wav`, `spring.wav`, `success.wav`, `summer.wav`, `title.wav`, `ui.wav`, `water.wav`
- **追加した環境音と音色**: `rural_ambience.wav`, `map.wav`
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: 不要
- **生成手段**: Python の数式合成、22050 Hz・16 bit・stereo PCM。外部録音・既存楽曲・音声生成サービスは未使用。
- **プロンプトの要点**: 既存曲は倍音のある撥弦、木琴、低音、ブラシ打楽器。追加音は風、せせらぎ、遠い鳥を表す周期波を8秒の環境ループにし、村地図への移動音は木を打つ短い倍音にする。
- **改変と検証**: BGM の終端と効果音の音量包絡を補正済み。`scripts/dev/generate_assets.py --verify` で追加音と全 PNG の再生成 SHA-256、全 WAV の PCM 形式・クリッピング・無音を検査する。

## フォント (`assets/fonts/`)

- **素材名**: Yomogi Regular (`Yomogi-Regular.ttf`, `OFL.txt`)
- **作者**: The Yomogi Project Authors
- **入手 URL**: https://github.com/google/fonts/tree/main/ofl/yomogi
- **原プロジェクト**: https://github.com/satsuyako/YomogiFont
- **ライセンス**: SIL Open Font License 1.1
- **クレジット表記**: 必要。同梱 `OFL.txt` に Copyright 2020 The Yomogi Project Authors とライセンス全文を保持する。
- **改変**: なし
