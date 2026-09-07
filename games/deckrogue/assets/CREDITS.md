# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## フォント (`assets/fonts/`)

- **素材名**: New Tegomin Regular (`NewTegomin-Regular.ttf`, `OFL.txt`)
- **作者**: The New Tegomin Project Authors
- **入手 URL**: https://fonts.google.com/specimen/New+Tegomin
- **ライセンス**: OFL-1.1
- **クレジット表記**: **必要**
- **改変**: なし
- **備考**: Copyright 2020 The New Tegomin Project Authors (https://github.com/nagamaki008/NewTegomin)。著作権表示とライセンス全文を fonts/OFL.txt に同梱。フォントは改変していない。

## Public Domain 画像と加工画像 (`assets/art/`)

加工は `scripts/dev/process_pd_art.py` に固定したクロップ、縮小、羊皮紙色へのデュオトーン、額縁追加、アニメーションシート化で行った。原画像はビルドに含めず、ゲームで使う加工済み PNG のみを同梱する。

- **素材名**: Rivierlandschap met een kasteel (`paper_texture.png`, `map_engraving.png`, `card_aegis.png`, `card_feint.png`, `card_guard.png`, `card_skill.png`)
- **作者**: Johann Sadeler I（版画）、Paul Bril（原画）
- **入手 URL**: https://commons.wikimedia.org/wiki/File:Rivierlandschap_met_een_kasteel,_RP-P-OB-7512.jpg
- **ライセンス**: CC0 1.0
- **クレジット表記**: **不要**
- **改変**: 城・森・川・道をクロップし、縮小、グレースケール化、墨色と羊皮紙色へのデュオトーン、枠追加を行った

- **素材名**: Saint George Killing the Dragon (`title_keyart.png`, `hero.png`, `hero_sheet.png`, `enemy_brute.png`, `enemy_brute_sheet.png`, `card_attack.png`, `card_fervor.png`, `card_heavy.png`, `card_smoke.png`, `route_battle.png`, `icon_attack.png`)
- **作者**: Albrecht Dürer
- **入手 URL**: https://commons.wikimedia.org/wiki/File:Albrecht_D%C3%BCrer,_Saint_George_Killing_the_Dragon,_1501-1504,_NGA_6715.jpg
- **ライセンス**: CC0 1.0（National Gallery of Art Open Access）
- **クレジット表記**: **不要**
- **改変**: 騎士・竜の各部分をクロップし、縮小、墨色へのデュオトーン、額縁追加、30コマのシート化を行った

- **素材名**: Manuscript Illumination with Initial Q, from a Choir Book (`ornament_initial.png`, `enemy_moth.png`, `enemy_moth_sheet.png`, `npc_keeper.png`, `npc_keeper_sheet.png`, `card_bash.png`, `card_flow.png`, `card_insight.png`, `card_strike.png`, `route_rest.png`, `route_card.png`, `relic_ember.png`, `relic_seed.png`, `icon_energy.png`, `logo_mark.png`)
- **作者**: 不詳（15世紀前半、北イタリア）
- **入手 URL**: https://commons.wikimedia.org/wiki/File:Manuscript_Illumination_with_Initial_Q,_from_a_Choir_Book_MET_sf32-100-477s1at.jpg
- **ライセンス**: CC0 1.0（The Metropolitan Museum of Art Open Access）
- **クレジット表記**: **不要**
- **改変**: 彩色飾り文字、葉飾り、人物、鳥獣をクロップし、縮小、彩度・コントラスト調整、額縁追加、30コマのシート化を行った

- **素材名**: Dante lost in the dark forest (`battle_forest.png`, `enemy_wisp.png`, `enemy_wisp_sheet.png`, `card_block.png`, `card_focus.png`, `card_quick.png`, `route_event.png`)
- **作者**: Gustave Doré
- **入手 URL**: https://commons.wikimedia.org/wiki/File:Dante_lost_in_the_dark_forest,_illustration_to_Dante%E2%80%99s_Inferno_by_Gustave_Dor%C3%A9.jpg
- **ライセンス**: Public Domain（PD-Art / PD-old-auto-expired）
- **クレジット表記**: **不要**
- **改変**: 森の線画部分をクロップし、縮小、深緑と羊皮紙色へのデュオトーン、30コマのシート化を行った

- **素材名**: Dragon Detail, Folio 065v, Aberdeen Bestiary (`bestiary_dragon.png`, `boss.png`, `boss_sheet.png`, `card_charge.png`, `card_fortress.png`, `card_renew.png`, `route_boss.png`, `relic_shell.png`, `icon_relic.png`)
- **作者**: 不詳（12世紀）
- **入手 URL**: https://commons.wikimedia.org/wiki/File:AberdeenBestiaryFolio065vDragonDetail.jpg
- **ライセンス**: Public Domain（PD-Art / PD-old）
- **クレジット表記**: **不要**
- **改変**: 竜・象・金地をクロップし、縮小、彩度・コントラスト調整、額縁追加、30コマのシート化を行った

- **素材名**: Curthose Tower, The Castles and Abbeys of England (`tower_stamp.png`, `enemy_sentinel.png`, `enemy_sentinel_sheet.png`, `card_expose.png`, `card_fracture.png`, `card_siphon.png`, `route_elite.png`, `icon_block.png`)
- **作者**: William Beattie、Thomas Allom、John Wykeham Archer、W. H. Bartlett（頁固有の作画者は不詳）
- **入手 URL**: https://www.flickr.com/photos/britishlibrary/11022557003/
- **ライセンス**: Public Domain（1844年刊。British Library / Flickr Commons は No known copyright restrictions と表示）
- **クレジット表記**: **不要**
- **改変**: 塔と周囲の線画をクロップし、縮小、墨色と羊皮紙色へのデュオトーン、額縁追加、30コマのシート化を行った

- **素材名**: 写本風エフェクト (`fx_glow.png`, `fx_spark.png`)
- **作者**: bannzai（Codex を用いた独自制作）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト用の独自制作物
- **クレジット表記**: **不要**
- **改変**: なし
- **生成**: Pillow の楕円・線・ぼかしによる決定的生成 / プロンプトの要点: 写本の金箔と朱インクに見える小さな発光・火花

## 独自UI・シェーダ (`assets/ui/`, `assets/shaders/`)

- **素材名**: 写本テーマと演出 (`pilgrimage.tres`, `pulse.gdshader`)
- **作者**: bannzai（Codex を用いた独自制作）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト用の独自制作物（第三者素材を使用していない）
- **クレジット表記**: **不要**
- **改変**: なし
- **生成**: Codex による Theme リソースと Godot シェーダの記述 / プロンプトの要点: New Tegomin、羊皮紙・墨・金・朱の見開きUIと、GL Compatibility で動く燈火の発光。

## 独自音声 (`assets/audio/`)

- **素材名**: 燈火の巡礼 音楽・環境音・効果音 (`title.wav`, `map.wav`, `battle.wav`, `boss.wav`, `result.wav`, `victory.wav`, `ambience_wind.wav`, `ambience_fire.wav`, `ambience_paper.wav`, `card.wav`, `attack.wav`, `block.wav`, `heal.wav`, `power.wav`, `death.wav`, `transition.wav`, `page.wav`, `quill.wav`)
- **作者**: bannzai（Codex を用いた独自制作）
- **入手 URL**: https://github.com/bannzai/godotpractice
- **ライセンス**: 本プロジェクト用の独自制作物（第三者音源・楽譜を使用していない）
- **クレジット表記**: **不要**
- **改変**: 第2ラウンドの音楽・効果音を維持し、手直しラウンドで風・焚火・紙の環境音と、頁・羽根ペンの効果音を追加
- **備考**: 16 bit stereo PCM / 22050 Hz。6場面の8小節ループ、環境音3点、効果音9点。再生成: `python3 games/deckrogue/scripts/dev/generate_audio.py`。Python標準ライブラリのみ、固定seed。
- **生成**: Codex による独自作曲、倍音・ノイズ・左右定位・短い反射音の Python 合成 / プロンプトの要点: 既存の場面別楽曲に、風、焚火、紙の擦れを薄く重ね、ページをめくる紙のしなりと羽根ペンの引っかきを操作音にする。既存の曲・録音・楽譜は使わない。
