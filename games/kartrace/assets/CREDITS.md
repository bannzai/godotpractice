# 素材クレジット

外部素材 (画像・音声・フォント) を `assets/` に追加する時に記録する。記録の項目とルールは `.claude/rules/coding-rules-assets-license.md` (propagate-coding-rules skill で castle から配布) を参照。

## フォント (`assets/fonts/`)

- **素材名**: Potta One Regular (`PottaOne-Regular.ttf`, `OFL.txt`)
- **作者**: Copyright 2020 The Potta Project Authors (https://github.com/go108go/Potta), all rights reserved.
- **入手 URL**: https://fonts.google.com/specimen/Potta+One
- **ライセンス**: OFL-1.1
- **クレジット表記**: **必要**
- **改変**: なし
- **備考**: Google Fonts の公式リポジトリから取得。著作権表示と SIL Open Font License 1.1 全文を OFL.txt に保持。画面内の作者表記は不要。

## CC0 のドット絵 (`assets/pixel/`)

- **素材名**: Summer Otters w/ Signs (`crowd.png`。配布名 `otters.png`)
- **作者**: Spring Spring（Julie Damsgaard / Spring Spring / Spring Enterprises）
- **入手 URL**: https://opengameart.org/content/summer-otters-w-signs
- **ライセンス**: CC0
- **クレジット表記**: **不要**
- **改変**: ファイル名を変更。元画像を編集せず、Godot の region で看板を持つ先頭4コマだけを切り出し、nearest filtering でコース脇の観客として表示。
- **備考**: 作品ページの Copyright/Attribution Notice は「Produced by Julie Damsgaard/Spring Spring/Spring Enterprises」。

- **素材名**: 2.5D Racing Resources (`racing_sign.png`。配布zip内 `sprite_finish.png`)
- **作者**: Drummyfish
- **入手 URL**: https://opengameart.org/content/25d-racing-resources
- **ライセンス**: CC0
- **クレジット表記**: **不要**
- **改変**: `racing resources_0.zip` から FINISH 看板だけを抽出し、ファイル名を変更。画像自体は編集せず、nearest filtering でコース脇の看板にだけ使用。
- **備考**: 作品ページの Copyright/Attribution Notice は「not required, you can credit drummyfish」。

## 独自のキャラクター画像 (`assets/portraits/`)

- **素材名**: カワウソ・キツネ・フクロウのレーサー肖像 (`otter.svg`, `fox.svg`, `owl.svg`)
- **作者**: 本プロジェクトで Codex を用いて制作
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/kartrace/games/kartrace/scripts/dev/generate_assets.py
- **ライセンス**: 本プロジェクトのオリジナル生成物（第三者素材なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 画像生成モデルと既存作品の素材は使用しない。適用法の認める範囲で生成出力は利用者に帰属する。CC0 とは宣言しない。
- **生成**: Python 3 による SVG 手続き生成（実装支援: Codex） / プロンプトの要点: サンゴ湾を走る動物レーサー。カワウソはミントのヘルメット、キツネは橙のスーツと赤いスカーフ、フクロウは紫のヘルメット。顔・耳・目・衣装を別設計。

## 独自のUI画像 (`assets/ui/`)

- **素材名**: 潮風カートの看板・海辺のコースイラスト・UI部品 (`logo.svg`, `keyart.svg`, `trophy.svg`, `speed.svg`, `flag.svg`, `wave.svg`)
- **作者**: 本プロジェクトで Codex を用いて制作
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/kartrace/games/kartrace/scripts/dev/generate_assets.py
- **ライセンス**: 本プロジェクトのオリジナル生成物（第三者素材なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 画像生成モデルと既存作品の素材は使用しない。適用法の認める範囲で生成出力は利用者に帰属する。CC0 とは宣言しない。
- **生成**: Python 3 による SVG 手続き生成（実装支援: Codex） / プロンプトの要点: ミント、橙、紺、珊瑚、クリームの海辺のカートレース。独自の車体、波、サンゴ、コース、多層の空と海。日本語タイトル文字は同梱フォントで UI 描画。

## 独自のアイテム画像 (`assets/items/`)

- **素材名**: 前方パルス・後方ブイ・ターボのアイコン (`pulse.svg`, `buoy.svg`, `turbo.svg`)
- **作者**: 本プロジェクトで Codex を用いて制作
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/kartrace/games/kartrace/scripts/dev/generate_assets.py
- **ライセンス**: 本プロジェクトのオリジナル生成物（第三者素材なし）
- **クレジット表記**: **不要**
- **改変**: なし
- **備考**: 適用法の認める範囲で生成出力は利用者に帰属する。CC0 とは宣言しない。
- **生成**: Python 3 による SVG 手続き生成（実装支援: Codex） / プロンプトの要点: 前方への矢印と波紋、海上のブイ、ミントの推進器を太い紺線とクリームの円でまとめる。

## 独自の音楽と効果音 (`assets/audio/`)

- **素材名**: 潮風カートの場面別BGM・操作効果音・環境音 (`title.wav`, `race.wav`, `final.wav`, `results.wav`, `engine.wav`, `item.wav`, `hit.wav`, `boost.wav`, `countdown.wav`, `finish.wav`, `select.wav`, `lap.wav`, `garage.wav`, `crowd.wav`)
- **作者**: 本プロジェクトで Codex を用いて制作
- **入手 URL**: https://github.com/bannzai/godotpractice/blob/game/kartrace/games/kartrace/scripts/dev/generate_assets.py
- **ライセンス**: 本プロジェクトのオリジナル生成物（第三者音源なし）
- **クレジット表記**: **不要**
- **改変**: 独自波形を 22050 Hz / 16 bit / mono WAV として保存
- **備考**: 外部音源と既存楽曲は使用しない。適用法の認める範囲で生成出力は利用者に帰属する。CC0 とは宣言しない。再生成: python3 scripts/dev/generate_assets.py。エンジン音は整数倍の周期波を合成してループ境界を連続にする。
- **生成**: Python 3 標準ライブラリによる数式合成（実装支援: Codex） / プロンプトの要点: 80年代アーケードの海上レース。倍音を持つベル、和音パッド、ベース、キック、スネア、ハイハット。タイトル116BPM、レース144BPM、最終周170BPM、結果108BPM。ガレージのネオン音・工具音と、コースの観客ざわめきを別ループで重ね、場面を音だけでも区別する。

## 3D カート

- otter.tscn / fox.tscn / owl.tscn：GDScript による独自の手続き生成。カワウソ・キツネ・フクロウそれぞれ別の車体、顔、装備。低ポリの ArrayMesh に頂点カラーを持たせ、車体にはテクスチャを使わない。外部素材なし。生成コード scripts/kart_visual.gd、プロジェクトと同条件で利用。
