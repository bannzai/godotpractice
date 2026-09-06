# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## ブロック・道具・キャラクターの独立アイコン (`assets/icons/`)

- **素材名**: ブロック・道具・キャラクターの独立アイコン (`apple.svg`, `bandage.svg`, `beacon.svg`, `bench.svg`, `crystal.svg`, `dirt.svg`, `grass.svg`, `leaf.svg`, `leaves.svg`, `meat.svg`, `mossling.svg`, `ore.svg`, `pickaxe.svg`, `plank.svg`, `player.svg`, `sand.svg`, `stew.svg`, `stone.svg`, `stone_pick.svg`, `torch.svg`, `water.svg`, `wisp.svg`, `wood.svg`, `wood_pick.svg`)
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成元: scripts/dev/generate_assets.py。既存作品素材と外部生成サービスは未使用。
- **生成**: Codex による Python / SVG 作成 / プロンプトの要点: 青緑・真鍮・濃紺の配色。ブロック、素材、調理食、回復材、木と石のつるはし、主人公・石殻獣・灯精をそれぞれ別ファイル・固有の輪郭で描く。

## 灯守の島のタイトルキーアートと紋章 (`assets/art/`)

- **素材名**: 灯守の島のタイトルキーアートと紋章 (`logo.svg`, `title.svg`)
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成元: scripts/dev/generate_assets.py（画像・音源）。既存作品素材と外部生成サービスは未使用。
- **生成**: Codex による Python / SVG / GDScript 作成 / プロンプトの要点: 青緑の海、重なる遠島、段状の草島、夕空、ランタンを配した独自 SVG。

## 場面別の曲と行動別の効果音 (`assets/audio/`)

- **素材名**: 場面別の曲と行動別の効果音 (`attack.wav`, `break_crystal.wav`, `break_dirt.wav`, `break_grass.wav`, `break_leaves.wav`, `break_sand.wav`, `break_stone.wav`, `break_wood.wav`, `clear.wav`, `craft.wav`, `day.wav`, `failed.wav`, `hurt.wav`, `night.wav`, `place.wav`, `place_crystal.wav`, `place_dirt.wav`, `place_grass.wav`, `place_leaves.wav`, `place_sand.wav`, `place_stone.wav`, `place_wood.wav`, `step.wav`, `step_crystal.wav`, `step_dirt.wav`, `step_grass.wav`, `step_leaves.wav`, `step_sand.wav`, `step_stone.wav`, `step_wood.wav`, `title.wav`, `ui.wav`)
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成元: scripts/dev/generate_assets.py。既存曲・録音・サンプルと外部生成サービスは未使用。
- **生成**: Codex による Python 標準ライブラリの加算合成 / プロンプトの要点: タイトル・昼・夜・成功・失敗の5曲。ベル・撥弦・パッドの倍音と循環残響。木石草土砂葉結晶ごとの破壊・設置・足音は周波数とノイズの量を個別に変え、攻撃・被弾・制作・操作の出来事音と分ける。

## 共通 UI テーマ (`assets/ui/`)

- **素材名**: 共通 UI テーマ (`theme.tres`)
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成元: scripts/dev/generate_assets.py（画像・音源）。既存作品素材と外部生成サービスは未使用。
- **生成**: Codex による Python / SVG / GDScript 作成 / プロンプトの要点: 濃紺のパネルと青緑のボタン、琥珀のフォーカス、角丸を持つ Godot Theme。

## 日本語フォント (`assets/fonts/`)

- **素材名**: M PLUS Rounded 1c Regular (`MPLUSRounded1c-Regular.ttf`, `OFL.txt`)
- **作者**: The Rounded M+ Project Authors
- **入手 URL**: https://fonts.google.com/specimen/M+PLUS+Rounded+1c
- **ライセンス**: OFL-1.1
- **クレジット表記**: **必要**
- **改変**: なし
- **備考**: Copyright 2016 The Rounded M+ Project Authors. 既存 monsterquest で取得済みのフォントと OFL.txt を無改変で同梱。

## 独立した 3D キャラクターモデル

- **素材名**: 主人公の手とつるはし、石殻獣、浮遊灯精
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: 不要
- **改変**: なし
- **生成**: GDScript で低分割メッシュを組み合わせた独自モデル。`scripts/actors/player.gd`・`mossling.gd`・`wisp.gd` を個別のモデル定義とし、`creature.gd` が待機・移動・攻撃・被弾・消滅の部位アニメーションを構築する。
- **プロンプトの要点**: 主人公は青緑の手袋と真鍮のつるはし、石殻獣は甲羅と牙と四肢、灯精は六角の籠と発光核と垂れ布で輪郭を分ける。外部モデルや既存作品素材は使わない。
