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

- **素材名**: 場面別の曲・紙模型の環境音・行動別の効果音 (`attack.wav`, `break_crystal.wav`, `break_dirt.wav`, `break_grass.wav`, `break_leaves.wav`, `break_sand.wav`, `break_stone.wav`, `break_wood.wav`, `clear.wav`, `craft.wav`, `day.wav`, `failed.wav`, `hurt.wav`, `night.wav`, `paper_day.wav`, `paper_night.wav`, `place.wav`, `place_crystal.wav`, `place_dirt.wav`, `place_grass.wav`, `place_leaves.wav`, `place_sand.wav`, `place_stone.wav`, `place_wood.wav`, `step.wav`, `step_crystal.wav`, `step_dirt.wav`, `step_grass.wav`, `step_leaves.wav`, `step_sand.wav`, `step_stone.wav`, `step_wood.wav`, `title.wav`, `ui.wav`)
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成元: scripts/dev/generate_assets.py。既存曲・録音・サンプルと外部生成サービスは未使用。
- **生成**: Codex による Python 標準ライブラリの加算合成 / プロンプトの要点: タイトル・昼・夜・成功・失敗の5曲。ベル・撥弦・パッドの倍音と循環残響。昼夜で異なる周期波を重ねた波音に、高周波の短い紙擦れを混ぜた環境音。木石草土砂葉結晶ごとの破壊・設置・足音は周波数とノイズの量を個別に変え、攻撃・被弾・制作・操作の出来事音と分ける。

## 紙片 UI テーマ (`assets/ui/`)

- **素材名**: 共通 UI テーマ (`theme.tres`)
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成元: scripts/dev/generate_assets.py（画像・音源）。既存作品素材と外部生成サービスは未使用。
- **生成**: Codex による Godot Theme / GDScript 作成 / プロンプトの要点: 生成した折り紙テクスチャを貼った不揃いな紙片、焦げ茶のインク、机上でずれた角度、金色の選択紙を持つ UI。

## 日本語フォント (`assets/fonts/`)

- **素材名**: Zen Maru Gothic Regular (`ZenMaruGothic-Regular.ttf`, `OFL.txt`)
- **作者**: The Zen Maru Gothic Project Authors
- **入手 URL**: https://fonts.google.com/specimen/Zen+Maru+Gothic
- **ライセンス**: OFL-1.1
- **クレジット表記**: **必要**
- **改変**: なし
- **備考**: Copyright 2021 The Zen Maru Gothic Project Authors (https://github.com/googlefonts/zen-marugothic)。game-asset-search の Google Fonts 経路で取得。フォント本体は無改変、OFL 本文と著作権表示を同梱。

## 独立した 3D キャラクターモデル

- **素材名**: 主人公の手とつるはし、石殻獣、浮遊灯精
- **作者**: 本プロジェクトで制作（Codex 支援）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクトのオリジナル生成物（CC0 の付与なし）
- **クレジット表記**: 不要
- **改変**: なし
- **生成**: GDScript で低分割メッシュを組み合わせた独自モデル。`scripts/actors/player.gd`・`mossling.gd`・`wisp.gd` を個別のモデル定義とし、`creature.gd` が待機・移動・攻撃・被弾・消滅の部位アニメーションを構築する。
- **プロンプトの要点**: 主人公は青緑の手袋と真鍮のつるはし、石殻獣は甲羅と牙と四肢、灯精は六角の籠と発光核と垂れ布で輪郭を分ける。外部モデルや既存作品素材は使わない。

## 生成した紙テクスチャ (`assets/textures/`)

- **素材名**: 折り紙・折り目法線・色画用紙のテクスチャ (`origami-paper.png`, `origami-fold-normal.png`, `construction-paper-sky.png`)
- **作者**: 本プロジェクトで制作（OpenAI image_gen）
- **入手 URL**: https://openai.com/policies/terms-of-use/
- **ライセンス**: OpenAI 利用規約に基づく本プロジェクト用生成物（CC0 の付与なし）
- **クレジット表記**: **不要**
- **改変**: 生成後の拡縮・色加工なし
- **備考**: 1254×1254 RGB。ブロック面・法線・空と机上地図に使用。生成結果を目視確認して採用。
- **生成**: OpenAI built-in image_gen / プロンプトの要点: 暖色の折り紙繊維と浅い斜め折り目、接線空間の青紫法線、青緑の色画用紙。正面・全面・継ぎ目の目立たない素材。物体・文字・ロゴ・既存作品を含めない。
