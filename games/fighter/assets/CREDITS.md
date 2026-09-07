# 素材クレジット

このゲームで使う外部素材と独自生成物を記録する。外部素材はすべて public リポジトリへの同梱と改変が可能な CC0 または OFL-1.1 である。確認日: 2026-09-07。

## CC0 キャラクター: Brawler Asset Character 'Vigilante' SMS

- **作者**: Chasersgaming
- **入手 URL**: https://opengameart.org/content/brawler-asset-character-vigilante-sms
- **ライセンス**: CC0 1.0 / Public Domain。クレジット表記は不要。
- **同梱した原素材**: `Renegade_Idle_1_strip4.png`, `Renegade_Walk_1_strip4.png`, `Renegade_Run_1_strip4.png`, `Renegade_Daze_strip4.png`, `Renegade_Punch_1.png`, `Renegade_Punch_2.png`, `Renegade_Kick_1.png`, `Renegade_Kick_2.png`, `Renegade_Hurt.png`, `Renegade_Knock_Out.png`
- **改変**: `generate_pixel_assets.py` で原寸の画素を nearest-neighbor 拡大し、青と橙をシアン系へ色替えした。既存フレームの組み合わせ・位置ずらし・回転・縦つぶしで、蒼電の22動作×8フレームと `portrait-teal.png` を作った。

## CC0 キャラクター: RPG Asset Character 'Soldier' SMS

- **作者**: Chasersgaming
- **入手 URL**: https://opengameart.org/content/rpg-asset-character-soldier-sms
- **ライセンス**: CC0 1.0 / Public Domain。クレジット表記は不要。
- **同梱した原素材**: `SMS_Soldier_IDLE_EAST_strip4.png`, `SMS_Soldier_WALK_EAST_strip4.png`, `SMS_Soldier_RUN_EAST_strip4.png`, `SMS_Soldier_ATTACKPUNCH_EAST.png`, `SMS_Soldier_ATTACKKICK_EAST.png`, `SMS_Soldier_HITHURT_EAST.png`, `SMS_Soldier_JUMP_EAST.png`, `SMS_Soldier_AVATAR_ANGRY.png`
- **改変**: `generate_pixel_assets.py` で原寸の画素を nearest-neighbor 拡大し、黄緑を橙・深紅へ色替えした。既存フレームの組み合わせ・位置ずらし・回転・縦つぶしで、紅蓮の22動作×8フレームと `portrait-amber.png` を作った。

## CC0 背景: Brawler Asset Tile Set 'Market Street' SMS

- **作者**: Chasersgaming
- **入手 URL**: https://opengameart.org/content/brawler-asset-tile-set-market-street-sms
- **ライセンス**: CC0 1.0 / Public Domain。クレジット表記は不要。
- **同梱した原素材**: `SMS_C_Street_16x16_128_x128.png`, `SMS_Sprites.png`
- **改変**: `generate_pixel_assets.py` で nearest-neighbor 拡大・左右反転・会場別の色調補正を行い、付属の街頭小物と独自作画の観客・床・照明・看板を合成して `tokyo.png`, `seoul.png`, `rio.png` を作った。

## フォント: Dela Gothic One

- **作者**: The Dela Gothic Project Authors
- **入手 URL**: https://github.com/google/fonts/tree/main/ofl/delagothicone
- **ライセンス**: SIL Open Font License 1.1。著作権表示とライセンス全文の同梱が必要。
- **同梱ファイル**: `DelaGothicOne-Regular.ttf`, `OFL.txt`
- **改変**: フォントファイルは無改変。ゲーム内の文字描画と `title-logo.png`・会場画像内の見出し生成に使用した。Copyright 2020 The Dela Gothic Project Authors (https://github.com/syakuzen/DelaGothic)。

## CC0 素材から生成したドット絵と独自 UI

- **生成手段**: Pillow を使う `scripts/dev/generate_pixel_assets.py`。同じ入力から同じ PNG を生成し、内容が同じファイルは書き直さない。
- **生成物**: `teal-sheet.png`, `amber-sheet.png`, `teal-frames.tres`, `amber-frames.tres`, `portrait-teal.png`, `portrait-amber.png`, `tokyo.png`, `seoul.png`, `rio.png`, `world-map.png`, `title-logo.png`, `emblem.png`, `health-frame.png`, `round-medal.png`, `spark.png`, `impact.png`, `guard.png`, `wave-teal.png`, `wave-amber.png`
- **生成内容**: CC0 のキャラクターと街を90年代アーケード格闘風に色替え・再構成し、世界地図、飛行機経路用の背景、筐体風 HUD、四角い光線・打撃・防御エフェクトを画素単位で独自作画した。既存作品の名称・画像・音・ロゴは使っていない。
- **補助素材**: `fighter-flash.gdshader`, `vignette.gdshader`, `fighter-theme.tres` は本プロジェクト用に独自実装した。スキャンライン、被弾明滅、筐体風の配色・ボタンを構成する。

## 独自生成音声

- **素材名**: `hit.wav`, `guard.wav`, `special.wav`, `confirm.wav`, `ko.wav`, `title.wav`, `arena.wav`, `final.wav`, `result.wav`, `crowd.wav`
- **作者**: 本プロジェクトで Codex を用いて独自制作
- **生成手段**: Python 標準ライブラリだけを使う `scripts/dev/generate_audio.py`。固定乱数ノイズ、正弦波、倍音、FM、非整数倍の共鳴を合成し、同じ PCM を再生成する。第三者の録音・楽曲・音色サンプルは使っていない。
- **生成内容**: タイトル96 BPM、対戦128 BPM、最終ラウンド160 BPM、結果112 BPMの4曲、打撃・防御・必殺技・決定・KOの5効果音、遠い声・手拍子・笛を重ねた会場環境音を生成した。
- **ライセンス**: 独自制作素材。外部素材の流用なし。クレジット表記は不要。

## 独自制作物の扱い

独自 UI、シェーダ、音声合成スクリプトは Codex が本プロジェクト用に生成した。OpenAI 利用規約の Content / Ownership of content は、適用法で許される範囲で、利用者と OpenAI の間では出力を利用者が所有すると定める。第三者素材への権利を与えるものではなく、本素材は上記 CC0・OFL 素材以外の第三者素材を取り込んでいない。CC0 などの追加ライセンスは付与していない。

https://openai.com/policies/terms-of-use/
