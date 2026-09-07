# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## フォント (`assets/fonts/`)

- **素材名**: DotGothic16 Regular (`DotGothic16-Regular.ttf`, `OFL.txt`)
- **作者**: The DotGothic16 Project Authors / Fontworks Inc.
- **入手 URL**: https://fonts.google.com/specimen/DotGothic16
- **上流リポジトリ**: https://github.com/fontworks-fonts/DotGothic16/
- **ライセンス**: OFL-1.1
- **クレジット表記**: **必要**（フォントと著作権表示・OFL全文を同梱）
- **改変**: なし
- **備考**: Copyright 2020 The DotGothic16 Project Authors (https://github.com/fontworks-fonts/DotGothic16/). Google Fonts の配布ファイルを `game-asset-search` の取得スクリプトで取得。`fonts/OFL.txt` に著作権表示とライセンス全文を同梱。

- **素材名**: M PLUS Rounded 1c Regular (`MPLUSRounded1c-Regular.ttf`, `OFL.txt`)
- **作者**: The Rounded M+ Project Authors
- **入手 URL**: https://fonts.google.com/specimen/M+PLUS+Rounded+1c
- **ライセンス**: OFL-1.1
- **クレジット表記**: **必要**
- **改変**: なし
- **備考**: Copyright 2016 The Rounded M+ Project Authors. フォント内の著作権表示を確認し、fonts/OFL.txt に著作権表示とライセンス全文を同梱。フォント本体は取得時のまま。第3ラウンド以降の画面では使用せず、過去素材として保持。

## オリジナル画像 (`assets/`)

- **素材名**: こもれびの調査隊のモンスター6体 (`monsters/ember.svg`, `monsters/tide.svg`, `monsters/sprout.svg`, `monsters/moth.svg`, `monsters/crab.svg`, `monsters/owl.svg`)
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: 第2ラウンドで6体を固有デザインに描き直し。characters の待機先頭フレームから生成
- **備考**: 再生成元: scripts/dev/generate_polish_assets.py。画像生成サービス・外部素材は未使用。第三者への追加ライセンス付与は行っていない。
- **生成**: Codex による Python / SVG コード作成、Python 3 標準ライブラリ / プロンプトの要点: 192 px 透過。深緑の線とアイボリー・金・コーラルの絵本風。狐の耳と炎尾、水棲のひれ、球根と葉、蛾の模様翼、蟹のはさみ、梟の眼鏡を固有の輪郭と細部で描き分ける。既存作品の素材は使わない。

- **素材名**: 調査隊員と地形タイル (`player.svg`, `tiles.svg`)
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成元: scripts/dev/generate_assets.py。画像生成サービスは未使用。外部素材の転載なし。第三者への追加ライセンス付与は行っていない。
- **生成**: Codex による Python / SVG コード作成、Python 3 標準ライブラリ / プロンプトの要点: 48pxの調査隊員、草地・道・背高草・樹冠・水・室内床の48pxタイル6枚。既存作品素材を使わない。

## オリジナル音源 (`assets/audio/`)

- **素材名**: 場面別BGMと行動効果音 (`title.wav`, `field.wav`, `battle.wav`, `boss.wav`, `result.wav`, `attack.wav`, `capture.wav`, `heal.wav`, `levelup.wav`, `defeat.wav`, `ui.wav`)
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: 第1ラウンドの音源を新規合成で置換
- **備考**: 再生成元: scripts/dev/generate_polish_audio.py。32000 Hz / 16 bit / stereo PCM WAV。既存曲・録音・サンプルを使用せず、外部音楽生成サービスは未使用。第三者への追加ライセンス付与は行っていない。
- **生成**: Python 3 標準ライブラリによる木管・撥弦・ベル・マレット・弦・打楽器の加算合成。固定乱数と循環残響。タイトルは6/8、探索は木管、戦闘は速いマレット、隊長戦は低音とタム、結果は3/4のファンファーレで描き分ける。


## 第2ラウンドのキャラクター画像 (`assets/characters/`)

- **素材名**: 10体の部位アニメーション (`captain.svg`, `crab.svg`, `crab_captain.svg`, `ember.svg`, `healer.svg`, `moth.svg`, `owl.svg`, `player.svg`, `sprout.svg`, `tide.svg`)
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成元: scripts/dev/generate_polish_assets.py。画像生成サービス・外部素材は未使用。第三者への追加ライセンス付与は行っていない。
- **生成**: Codex による Python / SVG コード作成、Python 3 標準ライブラリ / プロンプトの要点: 192×192 px を6列×5行に配置。待機・移動・攻撃・被弾・戦闘不能の各6フレーム。主人公は探検帽と調査手帳、隊長は制帽・口ひげ・勲章、回復係は薬瓶と葉の帽子、専用ボスは隊長帽と羽飾りで描き分ける。耳・ひれ・葉・翼・はさみ・手足・装備・目・口をフレームごとに動かす。

## 第2ラウンドのUI画像 (`assets/ui/`)

- **素材名**: 道具・属性・紋章の独立アイコン (`capture_ball.svg`, `emblem.svg`, `logo.svg`, `potion.svg`, `type_fire.svg`, `type_leaf.svg`, `type_water.svg`)
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成元: scripts/dev/generate_polish_assets.py。画像生成サービス・外部素材は未使用。第三者への追加ライセンス付与は行っていない。
- **生成**: Codex による Python / SVG コード作成、Python 3 標準ライブラリ / プロンプトの要点: 捕獲器・回復薬・炎/水/草の属性・羅針盤紋章・葉飾りのロゴを別ファイルで制作。アイボリー・深緑・真鍮金・コーラルを統一する。

## 第2ラウンドの演出画像 (`assets/effects/`)

- **素材名**: 属性別の弾と光粒 (`projectile_fire.svg`, `projectile_leaf.svg`, `projectile_water.svg`, `spark.svg`)
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成元: scripts/dev/generate_polish_assets.py。画像生成サービス・外部素材は未使用。第三者への追加ライセンス付与は行っていない。
- **生成**: Codex による Python / SVG コード作成、Python 3 標準ライブラリ / プロンプトの要点: 炎・水滴・葉の弾を個別ファイルにし、光粒の中心はアイボリーと金。GL Compatibilityで使用する透過SVG。

## 第2ラウンドの背景画像 (`assets/backgrounds/`)

- **素材名**: 三層の森とタイトル専用キーアート (`forest_far.svg`, `forest_mid.svg`, `forest_near.svg`, `title_keyart.svg`)
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成元: scripts/dev/generate_polish_assets.py。画像生成サービス・外部素材は未使用。第三者への追加ライセンス付与は行っていない。
- **生成**: Codex による Python / SVG コード作成、Python 3 標準ライブラリ / プロンプトの要点: 1280×720 px の遠景・中景・前景を別ファイルにする。遠景は暖色の空と山、中景は樹木と草地、前景は額縁の葉。640×600 px のタイトル用構図は主人公と3体を森の楕円額縁に配置する。

## 第2ラウンドの地形・建築・小物 (`assets/world/`)

- **素材名**: `bed.svg`, `bench.svg`, `canopy_shadow.svg`, `captain_plaza.svg`, `clinic.svg`, `flowers.svg`, `healing_table.svg`, `home.svg`, `lily.svg`, `pollen.svg`, `room_walls.svg`, `rug.svg`, `sign.svg`, `storage_shelf.svg`, `tile_grass.svg`, `tile_hedge.svg`, `tile_meadow.svg`, `tile_path.svg`, `tile_water.svg`, `tile_wood.svg`
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: 第1ラウンドのコード描画を独立画像へ置換
- **生成**: scripts/dev/generate_world_assets.py、Python 3 標準ライブラリ。森の絵本、暖色木造建築、青緑の回復施設、木工家具、花・睡蓮、草・石畳・樹木・水・床を個別に作図。外部素材・既存作品の素材は使わない。

## 第3ラウンドのCC0原典 (`assets/pixel/source/`)

- **素材名**: TinyRpg Stranger Forest Pack (`spritesheet_58.png`)
- **作者**: ansimuz
- **入手 URL**: https://opengameart.org/content/tinyrpg-stranger-forest-pack
- **ライセンス**: CC0
- **クレジット表記**: **不要**（作者の任意表記: by ansimuz）
- **改変**: 原典ファイルは変更なし。`scripts/dev/generate_pixel_assets.py` が先頭行の歩行4コマを最近傍で18×25 pxへ縮小し、緑がかった4色へ減色して `characters/player.png` の基礎部分に使用。
- **備考**: SHA-256 `27e1d8a583a84a88b17e5e79a1b822ef0022ef3073da8dca84c76c51a545f890`。取得とライセンス確認は game-asset-search skill の `fetch-asset.sh` を使用。

- **素材名**: 16x16 8-bit RPG character set (`rpg_16x16_0.png`)
- **作者**: devurandom
- **入手 URL**: https://opengameart.org/content/16x16-8-bit-rpg-character-set
- **ライセンス**: CC0
- **クレジット表記**: **不要**
- **改変**: 原典ファイルは変更なし。`scripts/dev/generate_pixel_assets.py` が16×24 pxの人物コマを切り出し、緑がかった4色へ減色して `characters/captain.png` と `characters/healer.png` の基礎部分に使用。帽子・口ひげ・記章・回復係の外套と印は直接描画で追加。
- **備考**: SHA-256 `edaf9cbd192f52778caa6c0818d050042ea8d3356a8a2f0d77b112d7c55c0e2d`。取得とライセンス確認は game-asset-search skill の `fetch-asset.sh` を使用。

## 第3ラウンドの4階調キャラクター (`assets/pixel/characters/`)

- **素材名**: 10体の4階調アニメーション (`captain.png`, `crab.png`, `crab_captain.png`, `ember.png`, `healer.png`, `moth.png`, `owl.png`, `player.png`, `sprout.png`, `tide.png`)
- **作者**: 本プロジェクトで制作（Codex支援。player・captain・healerの基礎部分のみ上記CC0原典を加工）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成部分にはCC0を付与しない。原典由来部分はCC0
- **クレジット表記**: **不要**
- **改変**: CC0人物コマは最近傍縮小・4色減色・装備の加筆。その他7体は32×32 pxの直接描画。
- **生成**: `scripts/dev/generate_pixel_assets.py`、Python 3標準ライブラリ。透過を除く色は `#0F380F`、`#306230`、`#8BAC0F`、`#9BBC0F` の4色。32×32 pxを6列×5行に並べ、待機・移動・攻撃・被弾・戦闘不能を各6フレーム維持。アンチエイリアスなし。
- **備考**: `python3 scripts/dev/generate_pixel_assets.py` で再生成し、`--check` で原典SHA-256・寸法・色・再生成一致を検査する。

## 第3ラウンドの4階調背景・地方図 (`assets/pixel/backgrounds/`, `assets/pixel/world/`)

- **素材名**: 森の三層背景とタイトル原画 (`forest_far.png`, `forest_mid.png`, `forest_near.png`, `title_keyart.png`)
- **作者**: 本プロジェクトで制作（Codex支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0の付与なし）
- **クレジット表記**: **不要**
- **改変**: 第2ラウンドのSVGと同じ三層構成を、4階調ピクセル画像として新規作成。
- **生成**: `scripts/dev/generate_pixel_assets.py`、Python 3標準ライブラリ。背景は329×180 px、タイトル原画は160×143 px。アンチエイリアスを使わずピクセル単位で描画。

- **素材名**: 4階調フィールド・建物・家具・地方図 (`bed.png`, `bench.png`, `canopy_shadow.png`, `captain_plaza.png`, `clinic.png`, `flowers.png`, `healing_table.png`, `home.png`, `lily.png`, `pollen.png`, `region_map.png`, `room_walls.png`, `rug.png`, `sign.png`, `storage_shelf.png`, `tile_grass.png`, `tile_hedge.png`, `tile_meadow.png`, `tile_path.png`, `tile_water.png`, `tile_wood.png`)
- **作者**: 本プロジェクトで制作（Codex支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0の付与なし）
- **クレジット表記**: **不要**
- **改変**: 第2ラウンドのSVGと同じ役割を保ち、16×16 pxタイルとピクセル小物として新規作成。地方図は町からルート・隊長の目的地までを1枚で示す画像として追加。
- **生成**: `scripts/dev/generate_pixel_assets.py`、Python 3標準ライブラリ。緑がかった4色のみを使い、アンチエイリアスなしで直接描画。

## 第3ラウンドの4階調UI・戦闘演出 (`assets/pixel/ui/`, `assets/pixel/effects/`)

- **素材名**: 選択カーソル・道具・属性・紋章・ロゴ (`cursor.png`, `capture_ball.png`, `emblem.png`, `logo.png`, `potion.png`, `type_fire.png`, `type_leaf.png`, `type_water.png`)
- **作者**: 本プロジェクトで制作（Codex支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0の付与なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **生成**: `scripts/dev/generate_pixel_assets.py`、Python 3標準ライブラリ。16×16 pxを基本とする4階調ピクセル画像。ロゴのみ96×48 px。

- **素材名**: 戦闘時の属性弾と光 (`projectile_fire.png`, `projectile_leaf.png`, `projectile_water.png`, `spark.png`)
- **作者**: 本プロジェクトで制作（Codex支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0の付与なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **生成**: `scripts/dev/generate_pixel_assets.py`、Python 3標準ライブラリ。16×16 px。基本4色に加え、戦闘時だけ表示する炎と光へ差し色 `#C3423F` を使用。

## 第3ラウンドの8-bit風環境音 (`assets/audio/`)

- **素材名**: 町とルートの環境音 (`town_ambience.wav`, `route_ambience.wav`)
- **作者**: 本プロジェクトで制作（Codex支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0の付与なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **生成**: `scripts/dev/generate_pixel_audio.py`、Python 3標準ライブラリ。32,000 Hz・16 bit・stereo PCM・8秒。町は矩形波の時計・チャイム・左右の短い会話音・足音、ルートは固定LFSRの草音・三角波・鳥の矩形波を合成。既存の曲・録音・サンプルを使用していない。
- **備考**: `python3 scripts/dev/generate_pixel_audio.py` で再生成し、`--check` でフォーマット・非無音・最大振幅・クリップ・ループ端点・再生成一致を数値検査する。
