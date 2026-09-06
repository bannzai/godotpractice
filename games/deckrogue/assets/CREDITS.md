# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## フォント (`assets/fonts/`)

- **素材名**: Zen Old Mincho Regular (`ZenOldMincho-Regular.ttf`, `OFL.txt`)
- **作者**: The Zen Old Mincho Project Authors
- **入手 URL**: https://fonts.google.com/specimen/Zen+Old+Mincho
- **ライセンス**: OFL-1.1
- **クレジット表記**: **必要**
- **改変**: なし
- **備考**: 著作権表示とライセンス全文を fonts/OFL.txt に同梱。フォントは改変していない。

## 独自画像 (`assets/art/`)

- **素材名**: 燈火の巡礼 ベクター素材 (`background.svg`, `hero.svg`, `enemy_moth.svg`, `enemy_sentinel.svg`, `enemy_wisp.svg`, `boss.svg`, `card_attack.svg`, `card_block.svg`, `card_skill.svg`, `icon_attack.svg`, `icon_block.svg`, `icon_energy.svg`, `icon_relic.svg`)
- **作者**: bannzai（Codex を用いた独自制作）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト用の独自制作物（第三者素材を使用していない）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 games/deckrogue/scripts/dev/generate_assets.py。画像生成 API や既存画像の加工は使用していない。
- **生成**: Codex による SVG コード記述、Python 標準ライブラリによるファイル出力 / プロンプトの要点: 濃い青緑の石造遺跡、金の細線、朱色の布、燈火を運ぶ巡礼者と架空の敵。既存作品を参照しない。

## 独自音声 (`assets/audio/`)

- **素材名**: 燈火の巡礼 音楽と効果音 (`map.wav`, `battle.wav`, `boss.wav`, `card.wav`, `attack.wav`, `block.wav`)
- **作者**: bannzai（Codex を用いた独自制作）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト用の独自制作物（第三者音源を使用していない）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 16bit mono PCM、22050Hz。map 20秒、battle 15秒、boss 約13.33秒の循環音声。再生成スクリプトで固定シードを使用する。
- **生成**: Codex による作曲と合成コード、Python 標準ライブラリ wave / プロンプトの要点: 巡礼の落ち着いた音楽、戦闘の打楽器、ボス戦の低音、カードを払う音、衝撃音、金属の防御音。既存の曲や録音を使用しない。
