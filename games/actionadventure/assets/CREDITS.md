# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## 独自素材 characters (`assets/characters/`)

- **素材名**: 灯守と島の生き物 (`boss.svg`, `charger.svg`, `hero.svg`, `merchant.svg`, `ranger.svg`, `splitter.svg`, `villager.svg`, `wanderer.svg`)
- **作者**: bannzai（Codexを利用）
- **入手 URL**: https://openai.com/policies/terms-of-use/
- **ライセンス**: プロジェクト独自生成物。第三者素材なし。第三者へのライセンス付与はしていない
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 scripts/dev/generate_assets.py。キャラクターは96pxセル、横4列・idle/walk/action/hurt/deathの縦5行。
- **生成**: Codexによるコード作成、Python標準ライブラリによる決定的なSVG・WAV生成 / プロンプトの要点: 暗い藍・翡翠・琥珀の見下ろし遺跡探索。異なる8体と5動作4フレーム。多層背景。場面別の独自旋律、木管・撥弦・ベル・パッド・打楽器の加算合成。外部画像・録音・旋律不使用

## 独自素材 props (`assets/props/`)

- **素材名**: 遺跡と収集品 (`block.svg`, `bomb.svg`, `boomerang.svg`, `chest.svg`, `coin.svg`, `door.svg`, `grass.svg`, `heart.svg`, `key.svg`, `potion.svg`, `rock.svg`, `switch.svg`, `treasure.svg`)
- **作者**: bannzai（Codexを利用）
- **入手 URL**: https://openai.com/policies/terms-of-use/
- **ライセンス**: プロジェクト独自生成物。第三者素材なし。第三者へのライセンス付与はしていない
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 scripts/dev/generate_assets.py。キャラクターは96pxセル、横4列・idle/walk/action/hurt/deathの縦5行。
- **生成**: Codexによるコード作成、Python標準ライブラリによる決定的なSVG・WAV生成 / プロンプトの要点: 暗い藍・翡翠・琥珀の見下ろし遺跡探索。異なる8体と5動作4フレーム。多層背景。場面別の独自旋律、木管・撥弦・ベル・パッド・打楽器の加算合成。外部画像・録音・旋律不使用

## 独自素材 terrain (`assets/terrain/`)

- **素材名**: 草地・道・石床・水 (`tiles.svg`)
- **作者**: bannzai（Codexを利用）
- **入手 URL**: https://openai.com/policies/terms-of-use/
- **ライセンス**: プロジェクト独自生成物。第三者素材なし。第三者へのライセンス付与はしていない
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 scripts/dev/generate_assets.py。キャラクターは96pxセル、横4列・idle/walk/action/hurt/deathの縦5行。
- **生成**: Codexによるコード作成、Python標準ライブラリによる決定的なSVG・WAV生成 / プロンプトの要点: 暗い藍・翡翠・琥珀の見下ろし遺跡探索。異なる8体と5動作4フレーム。多層背景。場面別の独自旋律、木管・撥弦・ベル・パッド・打楽器の加算合成。外部画像・録音・旋律不使用

## 独自素材 backgrounds (`assets/backgrounds/`)

- **素材名**: 灯の遺跡と夜の島 (`distant.svg`, `foreground.svg`, `middle.svg`, `title.svg`)
- **作者**: bannzai（Codexを利用）
- **入手 URL**: https://openai.com/policies/terms-of-use/
- **ライセンス**: プロジェクト独自生成物。第三者素材なし。第三者へのライセンス付与はしていない
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 scripts/dev/generate_assets.py。キャラクターは96pxセル、横4列・idle/walk/action/hurt/deathの縦5行。
- **生成**: Codexによるコード作成、Python標準ライブラリによる決定的なSVG・WAV生成 / プロンプトの要点: 暗い藍・翡翠・琥珀の見下ろし遺跡探索。異なる8体と5動作4フレーム。多層背景。場面別の独自旋律、木管・撥弦・ベル・パッド・打楽器の加算合成。外部画像・録音・旋律不使用

- **素材名**: タイトル用の灯守の主人公 (`hero-keyart.svg`)
- **作者**: bannzai（Codexを利用）
- **入手 URL**: https://openai.com/policies/terms-of-use/
- **ライセンス**: プロジェクト独自生成物。第三者素材なし。第三者へのライセンス付与はしていない
- **クレジット表記**: **不要**
- **改変**: 主人公の独自ベクター図案を480pxの独立SVGへ描画
- **備考**: 再生成: python3 scripts/dev/generate_assets.py --visual-only。スプライトシートの変更やラスター画像の拡大は行わない。
- **生成**: Codexによるコード作成、Python標準ライブラリによる決定的SVG生成 / プロンプトの要点: 藍と翡翠の服、琥珀の灯と剣を持つ主人公。タイトルで鮮明に表示できる独立した高解像度ベクター図案

## 独自素材 audio (`assets/audio/`)

- **素材名**: 灯守の島の旋律と効果音 (`boss.wav`, `chest.wav`, `defeat.wav`, `door.wav`, `dungeon.wav`, `field.wav`, `hurt.wav`, `result.wav`, `sword.wav`, `title.wav`, `tool.wav`)
- **作者**: bannzai（Codexを利用）
- **入手 URL**: https://openai.com/policies/terms-of-use/
- **ライセンス**: プロジェクト独自生成物。第三者素材なし。第三者へのライセンス付与はしていない
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 scripts/dev/generate_assets.py。キャラクターは96pxセル、横4列・idle/walk/action/hurt/deathの縦5行。
- **生成**: Codexによるコード作成、Python標準ライブラリによる決定的なSVG・WAV生成 / プロンプトの要点: 暗い藍・翡翠・琥珀の見下ろし遺跡探索。異なる8体と5動作4フレーム。多層背景。場面別の独自旋律、木管・撥弦・ベル・パッド・打楽器の加算合成。外部画像・録音・旋律不使用

## 日本語フォント (`assets/fonts/`)

- **素材名**: Zen Maru Gothic Medium (`font.ttf`, `OFL.txt`)
- **作者**: The Zen Maru Gothic Project Authors
- **入手 URL**: https://fonts.google.com/specimen/Zen+Maru+Gothic
- **ライセンス**: OFL-1.1
- **クレジット表記**: **必要**
- **改変**: ファイル名のみfont.ttfへ変更。フォントデータは改変なし
- **備考**: 既存survivorsの同梱フォントを再利用。Copyright 2021 The Zen Maru Gothic Project Authors (https://github.com/googlefonts/zen-marugothic)。OFL.txtに著作権表示とライセンス全文を同梱。

## 独自素材 scenery (`assets/scenery/`)

- **素材名**: 島の集落・遺跡・水辺の景観 (`arch.svg`, `column.svg`, `crystals.svg`, `house.svg`, `lily.svg`, `ruins.svg`, `stall.svg`, `tree.svg`)
- **作者**: bannzai（Codexを利用）
- **入手 URL**: https://openai.com/policies/terms-of-use/
- **ライセンス**: プロジェクト独自生成物。第三者素材なし。第三者へのライセンス付与はしていない
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 再生成: python3 scripts/dev/generate_assets.py --visual-only。透過の装飾素材で、当たり判定を持たない。
- **生成**: Codexによるコード作成、Python標準ライブラリによる決定的SVG生成 / プロンプトの要点: 藍・翡翠・琥珀の見下ろし景観。葉冠と枝と根、瓦屋根と窓明かり、縞の天幕と品物、水晶、石組みと蔦、睡蓮、石の門。外部画像不使用
