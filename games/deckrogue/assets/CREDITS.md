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

- **素材名**: 燈火の巡礼 ベクター素材 (`background.svg`, `bg_foreground.svg`, `bg_ruins.svg`, `bg_sky.svg`, `boss.svg`, `boss_sheet.svg`, `card_aegis.svg`, `card_attack.svg`, `card_bash.svg`, `card_block.svg`, `card_charge.svg`, `card_expose.svg`, `card_feint.svg`, `card_fervor.svg`, `card_flow.svg`, `card_focus.svg`, `card_fortress.svg`, `card_fracture.svg`, `card_guard.svg`, `card_heavy.svg`, `card_insight.svg`, `card_quick.svg`, `card_renew.svg`, `card_siphon.svg`, `card_skill.svg`, `card_smoke.svg`, `card_strike.svg`, `enemy_brute.svg`, `enemy_brute_sheet.svg`, `enemy_moth.svg`, `enemy_moth_sheet.svg`, `enemy_sentinel.svg`, `enemy_sentinel_sheet.svg`, `enemy_wisp.svg`, `enemy_wisp_sheet.svg`, `fx_glow.svg`, `fx_spark.svg`, `hero.svg`, `hero_sheet.svg`, `icon_attack.svg`, `icon_block.svg`, `icon_energy.svg`, `icon_relic.svg`, `logo_mark.svg`, `npc_keeper.svg`, `npc_keeper_sheet.svg`, `relic_ember.svg`, `relic_seed.svg`, `relic_shell.svg`, `route_battle.svg`, `route_boss.svg`, `route_card.svg`, `route_elite.svg`, `route_event.svg`, `route_rest.svg`, `title_keyart.svg`)
- **作者**: bannzai（Codex を用いた独自制作）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト用の独自制作物（第三者素材を使用していない）
- **クレジット表記**: **不要**
- **改変**: 第2ラウンドで固有シルエット・部位ごとの連続ポーズ・多層背景・カード挿絵を新規制作
- **備考**: 再生成: python3 games/deckrogue/scripts/dev/generate_art.py。キャラ7種は各256×320の30コマ（待機・移動・攻撃・被弾・死亡）を1536×1600の独立シートに配置。画像生成APIや既存画像の加工は使用していない。
- **生成**: CodexによるSVGコード記述、Python標準ライブラリによる決定的生成 / プロンプトの要点: 濃紺・深緑・金・生成り・朱の共通パレット。燈籠を持つ朱マントの巡礼者、模様のある夜蛾、甲冑巨兵、陶器仮面の霊炎、岩角の四足獣、冠と六腕の巨像、鳥面の祠の番人。切り絵の輪郭と金の細線、月・塔・廃墟・草木の多層背景。カード18種と遺物3種も独立した固有図案。既存作品を参照しない。

## 独自UI・シェーダ (`assets/ui/`, `assets/shaders/`)

- **素材名**: 共通テーマと環境光 (`pilgrimage.tres`, `atmosphere.gdshader`, `pulse.gdshader`)
- **作者**: bannzai（Codex を用いた独自制作）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト用の独自制作物（第三者素材を使用していない）
- **クレジット表記**: **不要**
- **改変**: なし
- **生成**: Codex による Theme リソースと Godot シェーダの記述 / プロンプトの要点: 紺と金の共通UI、GL Compatibility で動く霧と燈火の発光。

## 独自音声 (`assets/audio/`)

- **素材名**: 燈火の巡礼 音楽と効果音 (`title.wav`, `map.wav`, `battle.wav`, `boss.wav`, `result.wav`, `victory.wav`, `card.wav`, `attack.wav`, `block.wav`, `heal.wav`, `power.wav`, `death.wav`, `transition.wav`)
- **作者**: bannzai（Codex を用いた独自制作）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト用の独自制作物（第三者音源・楽譜を使用していない）
- **クレジット表記**: **不要**
- **改変**: 第 2 ラウンドで全音声を作曲・合成し直した
- **備考**: 16 bit stereo PCM / 22050 Hz。6 場面の 8 小節ループと 7 種の効果音。再生成: python3 games/deckrogue/scripts/dev/generate_audio.py。Python 標準ライブラリのみ、固定 seed。
- **生成**: Codex による独自作曲、倍音合成・ノイズ合成・左右定位・短い反射音の Python コード / プロンプトの要点: 濃い青緑の遺跡を巡る旅。タイトルは笛と柔らかい持続音、探索は撥弦とベル、戦闘は細かい弦の反復と打楽器、ボスは低い金管と銅鑼、敗北は疎な下降旋律、勝利は明るい和声。カードの擦過・攻撃の衝撃・防御の金属音・回復の上昇ベル・強化の上昇音・死亡の下降音・遷移の風音。既存の曲や録音は使わない。

## 画面合成 (`assets/shaders/`)

- **素材名**: キーアートの境界フェード (`keyart.gdshader`)
- **作者**: bannzai（Codexを用いた独自制作）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト用の独自制作物
- **クレジット表記**: **不要**
- **改変**: なし
- **生成**: Codexによるシェーダ記述 / プロンプトの要点: キーアートの左端を多層背景へ自然につなぐ
