# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## フォント (`assets/fonts/`)

- **素材名**: M PLUS Rounded 1c Regular (`MPLUSRounded1c-Regular.ttf`, `OFL.txt`)
- **作者**: The Rounded M+ Project Authors
- **入手 URL**: https://fonts.google.com/specimen/M+PLUS+Rounded+1c
- **ライセンス**: OFL-1.1
- **クレジット表記**: **必要**
- **改変**: なし
- **備考**: Copyright 2016 The Rounded M+ Project Authors. フォント内の著作権表示を確認し、fonts/OFL.txt に著作権表示とライセンス全文を同梱。フォント本体は取得時のまま。

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
