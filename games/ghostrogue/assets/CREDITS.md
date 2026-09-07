# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## 独自制作の画像 (`assets/art/`)

- **素材名**: 夜を継ぐ者の霊・背景・ロゴ・アイコン (`beast.svg`, `beast_body.svg`, `beast_detail.svg`, `bell.svg`, `bell_body.svg`, `bell_detail.svg`, `boss.svg`, `boss_body.svg`, `boss_detail.svg`, `bride.svg`, `bride_body.svg`, `bride_detail.svg`, `child.svg`, `child_body.svg`, `child_detail.svg`, `crow.svg`, `crow_body.svg`, `crow_detail.svg`, `doll.svg`, `doll_body.svg`, `doll_detail.svg`, `flashlight.svg`, `fog.svg`, `fox.svg`, `fox_body.svg`, `fox_detail.svg`, `graveyard_far.svg`, `graveyard_near.svg`, `headless.svg`, `headless_body.svg`, `headless_detail.svg`, `hero_0.svg`, `hero_0_body.svg`, `hero_0_detail.svg`, `hero_1.svg`, `hero_1_body.svg`, `hero_1_detail.svg`, `hero_2.svg`, `hero_2_body.svg`, `hero_2_detail.svg`, `hero_3.svg`, `hero_3_body.svg`, `hero_3_detail.svg`, `house_far.svg`, `house_near.svg`, `icon_battle.svg`, `icon_boss.svg`, `icon_darkness.svg`, `icon_grave.svg`, `icon_item.svg`, `icon_living.svg`, `icon_police.svg`, `icon_rest.svg`, `icon_spirit.svg`, `icon_story.svg`, `keyart.svg`, `logo.svg`, `monk.svg`, `monk_body.svg`, `monk_detail.svg`, `moth.svg`, `moth_body.svg`, `moth_detail.svg`, `night_sky.svg`, `police.svg`, `police_body.svg`, `police_detail.svg`, `spark.svg`, `town_far.svg`, `town_near.svg`, `warrior.svg`, `warrior_body.svg`, `warrior_detail.svg`, `water.svg`, `water_body.svg`, `water_detail.svg`)
- **作者**: godotpractice
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/ghostrogue/games/ghostrogue/scripts/dev/generate_art.py
- **ライセンス**: 本プロジェクト独自制作。フォント以外の第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 scripts/dev/generate_art.py --out-dir assets。ロゴ文字のフォントは下記OFLに従う。既存作品の固有画像を参照しない。
- **生成**: Python / SVG / fontTools / プロンプトの要点: 墨紺・灰青・古紙・朱の配色。12霊と主人公4段階・警官・大霊を固有の輪郭で描く。可動部位を本体から分離。ロゴ文字の輪郭のみ同梱Zen Old Minchoから取得。

## 独自制作の音声 (`assets/audio/`)

- **素材名**: 夜の町の六つの循環伴奏と効果音 (`acquire.wav`, `attack.wav`, `battle.wav`, `boss.wav`, `dissolve.wav`, `heal.wav`, `heartbeat.wav`, `hurt.wav`, `map.wav`, `police.wav`, `result.wav`, `select.wav`, `siren.wav`, `spirit.wav`, `step.wav`, `title.wav`, `transition.wav`)
- **作者**: godotpractice
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/ghostrogue/games/ghostrogue/scripts/dev/generate_audio.py
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 scripts/dev/generate_audio.py --out-dir assets。22,050Hz・16bit・ステレオ。ループ残響は先頭へ折り返す。既存曲や録音は参照しない。
- **生成**: Python 標準ライブラリ / PCM 合成 / プロンプトの要点: 鈴の非整数倍音・撥弦・息の雑音・太鼓の減衰を合成し、場面ごとに独自の音列・テンポ・楽器構成を変える。

## 日本語フォント (`assets/fonts/`)

- **素材名**: Zen Old Mincho Regular (`ZenOldMincho-Regular.ttf`, `OFL.txt`)
- **作者**: The Zen Old Mincho Project Authors
- **入手 URL**: https://github.com/googlefonts/zen-oldmincho
- **ライセンス**: SIL Open Font License 1.1
- **クレジット表記**: **必要**
- **改変**: なし
- **備考**: Copyright 2021 The Zen Old Mincho Project Authors。フォントと著作権表示・OFL全文を同梱。既存deckrogueに導入済みのファイルを改変せず複製。

- **素材名**: Reggae One Regular (`ReggaeOne-Regular.ttf`, `OFL-ReggaeOne.txt`)
- **作者**: The Reggae Project Authors
- **入手 URL**: https://fonts.google.com/specimen/Reggae+One
- **ライセンス**: SIL Open Font License 1.1
- **クレジット表記**: **必要**
- **改変**: なし
- **備考**: fetch-asset.shでGoogle Fontsから取得。Copyright 2020 The Reggae Project Authors (https://github.com/fontworks-fonts/Reggae/), all rights reserved. 実著作権表示とOFL全文をOFL-ReggaeOne.txtとして同梱。既存Zen Old MinchoとOFL.txtは保持。

## 独自制作のUI (`assets/ui/`)

- **素材名**: 夜を継ぐ者の画面テーマ (`night.tres`)
- **作者**: godotpractice
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/ghostrogue/games/ghostrogue/assets/ui/night.tres
- **ライセンス**: 本プロジェクト独自制作。第三者素材の利用なし
- **クレジット表記**: **不要**
- **改変**: なし
- **生成**: Godot Theme / 手書き / プロンプトの要点: 墨紺のパネル、古紙色の文字、朱の押下と金のフォーカス枠。

## 外部制作の背景画像 (`assets/external/streets/`)

- **素材名**: 渋温泉付近の夜道（加工背景） (`street-01.webp`)
- **作者**: Yiannis Theologos Michellis
- **入手 URL**: https://commons.wikimedia.org/wiki/File:Nighttime_street_view_near_Shibu_Onsen_-_Japan_20170406110932_(33327856113).jpg
- **ライセンス**: CC0 1.0
- **クレジット表記**: **不要**
- **改変**: 1920pxサムネイルを1280x720へ縮小。店舗文字をぼかし、グレースケール化・コントラスト調整・3階調網点化し、黒・黄・青白の3色へ置換
- **備考**: Wikimedia Commons APIのiiurlwidth=1920で取得。人物は写っていない。判読可能な店舗文字を加工で除去。

- **素材名**: 高野山奥之院の夜道（加工背景） (`graveyard-01.webp`)
- **作者**: Yiannis Theologos Michellis
- **入手 URL**: https://commons.wikimedia.org/wiki/File:Pathway_through_graveyard_at_Okunoin_at_Koyasan_at_night_-_Japan_20170412105200_(34380968166).jpg
- **ライセンス**: CC0 1.0
- **クレジット表記**: **不要**
- **改変**: 1920pxサムネイルを1280x720へ縮小。灯籠の刻字をぼかし、グレースケール化・コントラスト調整・3階調網点化し、黒・赤・黄の3色へ置換
- **備考**: Wikimedia Commons APIのiiurlwidth=1920で取得。人物・商標は写っていない。判読可能な刻字を加工で除去。

- **素材名**: 京都・鴨川の夜景（加工背景） (`river-01.webp`)
- **作者**: Yiannis Theologos Michellis
- **入手 URL**: https://commons.wikimedia.org/wiki/File:Nighttime_view_along_the_Kamo_River_in_Pontocho,_Kyoto,_Japan_20170409105607_(34280403006).jpg
- **ライセンス**: CC0 1.0
- **クレジット表記**: **不要**
- **改変**: 1920pxサムネイルを1280x720へ縮小し、グレースケール化・コントラスト調整・3階調網点化し、黒・黄・青白の3色へ置換
- **備考**: Wikimedia Commons APIのiiurlwidth=1920で取得。人物は遠景の判別不能なシルエットのみで、判読可能な商標はない。

- **素材名**: 広尾の板張り家屋（加工背景） (`house-01.webp`)
- **作者**: Syced
- **入手 URL**: https://commons.wikimedia.org/wiki/File:Boarded_up_house_in_Hiroo.jpg
- **ライセンス**: CC0 1.0
- **クレジット表記**: **不要**
- **改変**: 1920pxサムネイルから告知紙・表札・郵便受けを除外して1280x720へクロップし、グレースケール化・コントラスト調整・3階調網点化し、黒・赤・黄の3色へ置換
- **備考**: Wikimedia Commons APIのiiurlwidth=1920で取得。人物は写っていない。住所・氏名を特定できる表示を画角と加工で除去。

## 外部制作のテクスチャ (`assets/external/textures/`)

- **素材名**: Parchment background (`parchment.webp`)
- **作者**: Felis Chaus
- **入手 URL**: https://opengameart.org/content/parchment-background
- **ライセンス**: CC0 1.0
- **クレジット表記**: **不要**
- **改変**: 中央を正方形に切り出し、512x512へリサイズしてWebPへ変換
- **備考**: fetch-asset.shでFelisChaus_ParchmentBackground.jpgを取得。

- **素材名**: Rust (semi seamless) (`rust.webp`)
- **作者**: pyranostudios
- **入手 URL**: https://opengameart.org/content/rust-semi-seamless
- **ライセンス**: CC0 1.0（配布ページの複数ライセンスからCC0を選択）
- **クレジット表記**: **不要**
- **改変**: 中央を正方形に切り出し、512x512へリサイズしてWebPへ変換
- **備考**: fetch-asset.shでrusts.jpgを取得。配布元のCopyright/Attribution Notice: Rusty metal texture by Pyrano Studios。

## 外部制作の音声 (`assets/external/audio/`)

- **素材名**: Random Sounds Samples（虫・犬・足音・葉） (`ambience-crickets.ogg`, `ambience-dog.ogg`, `ambience-steps.ogg`, `ambience-leaves.ogg`)
- **作者**: Augmentality (Brandon Morris)
- **入手 URL**: https://opengameart.org/content/random-sounds-samples
- **ライセンス**: CC0 1.0（配布ページの複数ライセンスからCC0を選択）
- **クレジット表記**: **不要**
- **改変**: ファイル名のみ変更。音声データは無改変
- **備考**: fetch-asset.shでcricket ambienc276.ogg、dog barking.ogg、full steps stereo.ogg、moving leaves stereo.oggを取得。

- **素材名**: wind1 (`ambience-wind.ogg`)
- **作者**: Luke.RUSTLTD
- **入手 URL**: https://opengameart.org/content/wind1
- **ライセンス**: CC0 1.0
- **クレジット表記**: **不要**
- **改変**: WAVからVorbis品質4のOGGへ変換し、ファイル名を変更
- **備考**: fetch-asset.shでwind1.wavを取得。44.1kHz・モノラル・約60秒。

- **素材名**: Heartbeat sounds（低速・高速） (`heartbeat-slow.ogg`, `heartbeat-fast.ogg`)
- **作者**: bart
- **入手 URL**: https://opengameart.org/content/heartbeat-sounds
- **ライセンス**: CC0 1.0
- **クレジット表記**: **不要**
- **改変**: WAVからVorbis品質4のOGGへ変換し、ファイル名を変更
- **備考**: fetch-asset.shでheartbeat_slow_0.wav、heartbeat_fast_0.wavを取得。

- **素材名**: Electricity Game Sound Pack（電気ループ） (`electric-loop.ogg`)
- **作者**: faxcorp
- **入手 URL**: https://opengameart.org/content/electricity-game-sound-pack
- **ライセンス**: CC0 1.0
- **クレジット表記**: **不要**
- **改変**: WAVからVorbis品質4のOGGへ変換し、ファイル名を変更
- **備考**: fetch-asset.shでcrackleelectricityloop.wavを取得。

## 画像生成による劇画素材 (`assets/generated/`) (`assets/generated/`)

- **素材名**: 夜を継ぐ者 タイトルキービジュアル (`title-keyart.png`)
- **作者**: godotpractice / OpenAI
- **入手 URL**: https://openai.com/
- **ライセンス**: 本プロジェクト独自制作
- **クレジット表記**: **不要**
- **改変**: 生成結果を1536x1024 PNGのまま同梱し、ゲーム内で16:9へクロップ表示
- **備考**: 既存作品の固有名称・画像・ロゴは入力せず、公開リポジトリ用の独自構図として生成。
- **生成**: OpenAI image generation / プロンプトの要点: 昭和の夜の町、懐中電灯を持つ若者、遠景の怪異、太い黒線・高コントラスト・網点、黒・黄・赤・青白のみ。文字や既存作品要素なし。

- **素材名**: 十二体の霊 劇画アトラス (`spirit-cutins.png`)
- **作者**: godotpractice / OpenAI
- **入手 URL**: https://openai.com/
- **ライセンス**: 本プロジェクト独自制作
- **クレジット表記**: **不要**
- **改変**: 1536x1024の4列3行アトラスとして、通常立ち絵とコマ割りカットインで領域切り出し表示
- **備考**: 霊の名称と造形は本作固有。既存作品の固有名称・画像・ロゴは入力していない。
- **生成**: OpenAI image generation / プロンプトの要点: 十二種類の日本怪異を等身の劇画ホラーで描く統一アトラス。太い墨線、網点、黒・懐中電灯の黄・血の赤・霊の青白。文字や既存作品要素なし。

## 独自制作のシェーダ (`assets/shaders/`) (`assets/shaders/`)

- **素材名**: 劇画ポスタリゼーション・網点シェーダ (`gekiga.gdshader`)
- **作者**: godotpractice
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト独自制作
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: CC0写真背景を輝度三段階へ量子化し、網点と黒・黄・赤の色調へ統一する。
- **生成**: Godot Shader Language / 手書き / プロンプトの要点: 写真を劇画調へ統一するポスタリゼーション、ハーフトーン、闇堕ち度に応じた赤色混合。
