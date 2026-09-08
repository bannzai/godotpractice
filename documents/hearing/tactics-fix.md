# tactics 手直しラウンド ヒアリング

## 1. 開発の進め方

### 作業した順序

1. `AGENTS.md`、`documents/PROJECT.md`、issue #41、前ラウンドの PR #56、既存のヒアリングと `documents/knowledge/tactics.md` を読み、今回も維持すべき戦術ゲームの仕様と、壊すべき共通 UI の特徴を分けた。
2. 変更前のゲームを実際に起動し、タイトル、戦場、戦闘予測を撮影した。紺色の矩形パネル、上部 HUD、右サイドバー、下部の操作ガイドが他ゲームと似ていること、初手で選べる味方や選べない理由が分からないことを基準にした。
3. 早い段階で draft PR #80 を作り、作業を次の単位に分けた。
   - 大和絵の人物・地形画像、Shippori Mincho B1、金雲と金縁のシェーダ
   - 屏風の表紙と章間絵巻、扇形コマンド、巻物の戦闘予測、初回指南、選択不可理由
   - 環境音と扇を開く音、既存 BGM・SE との統合
   - `screenshot.gd`、実入力の integration、32 秒のデモ録画
4. まず素材と画面の骨格を作り、次に操作案内を入れ、最後に自動検証と録画を新しい画面遷移へ追従させた。見た目だけ先に完成させるのではなく、タイトルから章間絵巻、指南、盤面、結果までを実入力で通せる状態を完成単位にした。
5. ローカルの headless 検証、描画付きスクリーンショット、起動録画、32 秒の操作デモ、3 OS と Web のエクスポート、通常起動を順に確認した。その後、webtunnel で Web 版を最初から結果まで操作し、CI の PNG と動画も別途目視した。
6. ready for review 後の CodeRabbit の指摘を現物と照合し、妥当だった5件を修正した。知見と素材記録の矛盾、シェーダでの modulate の欠落、環境音の周期的な音量低下、地形絵の縦横比の変形を直し、全検証と証拠画像を再作成した。

レビュー修正をローカルコミット `fedcd77` にした直前、PR #80 は修正前の `ededd98` を head としてユーザーによりマージされ、リモートブランチも削除された。そのため、5件のレビュー修正はマージ済みの main には含まれず、ローカルにだけ残っている。マージ後に無断で新しい PR を作るのは依頼範囲を広げるため行っていない。

### 詰まった点と解決方法

- 敵兵アトラスは「透過背景」を指定しても、市松模様が画像の RGB として焼き込まれた。採用せず、人物は変えずに背景だけを alpha にする画像編集をもう一度行い、ImageMagick で RGBA と四隅の alpha 0 を確認した。
- 生成した人物は等幅セルを指定しても馬や槍が隣のセルへ張り出した。元 PNG を加工せず、Godot の `AtlasTexture` の領域と表示倍率を実物に合わせて調整した。
- ローカルでは正常に見えた全角記号が Web 版では豆腐になった。OS のフォントフォールバックがローカルだけで不足文字を隠していたため、webtunnel の実画面で発見できた。表示文字を同梱フォントに確実にある記号へ置き換え、Web 版を最初から再操作した。
- webtunnel の `agent-browser` が一部の撮影で応答待ちになった。同じ runner の CDP に直接つなぎ、画面取得とマウス入力を分けて確認した。JavaScript でゲーム状態を書き換えず、タイトルから結果まで通常の入力経路を使った。
- Chromium の表示領域が 1280×656 でゲームの 16:9 と一致せず、クリック位置がそのままではずれた。canvas の表示矩形、余白、倍率からゲーム座標をブラウザ座標へ変換した。
- GitHub Actions の artifact は一覧取得に成功しても ZIP 本体の接続がリセットされた。`gh run download` の成否だけで判断せず、artifact API と `curl` の再試行・再開で取得し、ZIP の CRC 検査後に展開した。
- 一度、tactics と無関係な citybuilder の CI が失敗した。古い変更ゲーム判定では `documents/knowledge/tactics.md` の変更が全ゲーム扱いになっていたためだった。共有ファイルを直接直さず、既に main に入っていた判定改善をマージし、次の CI が tactics だけを検証して全 pass になることを確認した。
- CodeRabbit により、地形の 1774×887 の原画を 704×528 へ引き伸ばしていたことが分かった。中央を縦横比維持で cover crop し、`draw_texture_rect_region` で描くようにした。環境音はループ端の 40 ms を落とす処理が16秒ごとの音量低下を作っていたため撤去し、Ogg を PCM へ復号して継ぎ目を数値確認した。

## 2. 使ったツール・skill・コマンド

### skill とサービス

- `godot-development`: sandbox 内での Godot 起動、headless 検証、描画付き撮影、ログの扱い、export templates と終了時リークの確認に使った。
- `game-asset-search`: 素材の採否、生成物とフォントのライセンス・取得元・加工履歴を `assets/CREDITS.md` へ残す手順に使った。
- OpenAI built-in `image_gen`: 味方5兵種、敵5兵種、俯瞰地形絵を大和絵・屏風の共通方向で生成し、敵兵画像の背景抽出にも使った。
- `webtunnel`: GitHub Actions runner で Web エクスポートを配信し、自分の `fix/tactics` を Chromium で操作した。
- `agent-browser` と Chrome DevTools Protocol: Web 版の状態確認、クリック、スクリーンショット取得に使った。セッションは tactics 専用名で分離し、終了時に閉じた。
- `pr-attach-screenshots`: PR body へ比較画像、識別比較、連続フレーム、ローカル画面、Web 実操作画面、動画の最終フレームを付けた。内部の `puts upload` で公開し、公開 URL から再取得した SHA-256 と原本を照合した。
- `fix-pr-reviews`: CodeRabbit の未解決5スレッドを取得・分類し、修正、返信、resolve、再検証する流れに使った。

### 主なコマンド

- Godot の一括検証: `make test GAMES=tactics`
- 個別検証: `make lint GAMES=tactics`、`make check GAMES=tactics`、`make selfcheck GAMES=tactics`
- アセット import: `make import GAMES=tactics`
- 代表画面撮影: `make screenshot GAMES=tactics`
- 起動録画: `make movie GAMES=tactics`
- 実入力デモ録画: `make -C games/tactics movie-play`
- export: `make build-all GAMES=tactics`、`make build-web GAMES=tactics`
- 通常起動と終了経路: `make tactics-run RUN_FLAGS='--script res://scripts/dev/runcheck.gd'`
- GDScript lint: `gdlint`
- 画像・音声の再生成: `python3 games/tactics/scripts/art/generate_art.py`、`python3 games/tactics/scripts/art/generate_audio.py`
- 音声・動画検査: `ffmpeg`、`ffprobe`
- 比較画像と一覧画像: ImageMagick の `magick montage` と画像情報検査
- 再生成一致・公開物一致: `shasum` による SHA-256 比較
- GitHub 操作: `gh pr`、`gh run`、`gh api graphql`
- artifact と webtunnel 録画の取得: `curl`、`unzip`
- 差分確認: `git diff --check`、個人情報検査スクリプト

`gdlint` 単体の成功だけで終わらせず、各 Make target の保存ログ全文を WARNING / ERROR で調べた。画像生成物、CI artifact、公開した PR 画像も、コマンドが成功したという事実と中身が正しいという判断を分けて確認した。

## 3. 欲しかったが無かったツール・skill・スクリプト

- 画像生成アトラスの自動検品が欲しかった。RGBA、四隅 alpha、人物数だけでなく、市松模様が RGB に焼き込まれていないか、セルごとの alpha 占有率、隣セルへの張り出しを一覧化できれば、生成直後の手作業が減る。
- ゲーム内の全表示文字が同梱フォントに含まれるかを export 前に調べるスクリプトが欲しかった。ローカルの OS フォールバックで欠字が隠れる問題を、Web 起動前に検出できる。
- Ogg を PCM へ復号して、長さ、非無音、最大振幅、クリップ、左右チャンネル、ループ継ぎ目、再生成 SHA-256 を一括確認する共通スクリプトが欲しかった。今回は `ffmpeg` と個別の数値検査を組み合わせた。
- title → story → tutorial → play → result の遷移を追加した時、`screenshot.gd`、integration、movie-play の fixture と待機条件をまとめて更新できる Godot 向け雛形が欲しかった。今回は3系統を手で揃えた。
- `AnimationPlayer` の全キャラクター・全動作・指定時刻を一覧化する撮影部品が再利用可能な形で欲しかった。今回の実装は tactics 内にあるが、他ゲームへ持ち出すには整理が必要である。
- GitHub artifact を API から安全に再試行・resume し、ZIP の CRC、動画情報、期待ファイル一覧まで確認する補助スクリプトが欲しかった。`gh run download` の接続リセット時に手作業が多かった。
- webtunnel で CDP 疎通、canvas の実表示矩形、16:9 座標変換、スクリーンショット、クリック、録画取得、セッション終了を一連で診断する補助コマンドが欲しかった。

特に再利用価値が高いのは、`game-asset-search` への「生成アトラス検品」と「Ogg 復号検査」、`godot-development` への「画面遷移を含む撮影・実入力・録画の同期更新」である。

## 4. 素材の準備方法と使い勝手

### 画像

- 前ラウンドの人物、背景、地形、UI は、Python 標準ライブラリで SVG を決定的に生成していた。本体と武器を別ファイル・別ノードにでき、再生成 SHA-256 が一致し、AnimationPlayer で武器だけを振る用途には扱いやすかった。一方で、線や面の密度が均一で、他ゲームのコード生成素材と似やすかった。
- 今回は OpenAI built-in image generation で、味方5兵種、敵5兵種、平原・森・山・川・砦を含む横長地形絵を生成した。衣装の重なり、墨のかすれ、鉱物顔料、金箔、遠景の密度を短時間で揃えられ、ゲーム固有の印象を大きく上げられた。一方で非決定的で、透過指定、市松模様、人物の占有幅は出力後の検品と再試行が必要だった。
- 味方アトラスと地形絵は生成 PNG を無改変で使用した。敵アトラスだけ画像編集で背景抽出した。人物 PNG は Godot の `AtlasTexture` で切り分け、盤面、人物欄、交戦画面で表示倍率を変えた。地形絵は縦横比を維持する中央 cover crop にした。
- 金雲、和紙の繊維、屏風の折り目、人物の金縁は PNG へ焼き込まず、GL Compatibility 対応の CanvasItem shader で統一した。複数画面へ同じ規則を適用しやすい反面、import 後の実描画、modulate、透過端を必ず確認する必要があった。
- CC0 や Public Domain の既成画像は今回は使わなかった。大和絵の人物5種ずつと地形を同じ筆致で揃える条件では、検索、各素材の加工、個別ライセンス確認より画像生成の方が速かった。

### BGM・環境音・SE

- BGM4曲と既存SE4種は、Python で独自旋律と倍音を固定 seed 生成し、一時 WAV から `ffmpeg` で Ogg Vorbis に変換する方式を維持した。第三者楽曲を使わず、再生成でき、左右定位や場面ごとの長さをコードで調整できる点が良かった。
- 今回は風・水・遠い鈴の16秒環境音と、和紙の擦れ・扇骨の連続打音による約0.95秒の扇音を同じ生成系へ追加した。既存8音の SHA-256 を変えずに足せた。
- 手続き音はライセンスと再現性には強いが、Ogg 化した後のループ境界や周期的な音量変化はコードだけでは判断しにくい。PCM 復号後の数値検査、ゲーム内ミックス、通常終了時の解放確認が必要だった。外部の BGM・SE 素材は使っていない。

### フォント

- Google Fonts から Shippori Mincho B1 の Regular と SemiBold を取得し、SIL Open Font License 1.1 とプロジェクト固有の著作権表示を `assets/fonts/OFL.txt` に同梱した。大和絵・屏風の方向と合い、Web とデスクトップへ同じファイルを含められる点が扱いやすかった。
- 最初に同梱した OFL の著作権行が以前の Zen Old Mincho のままだったため、Google Fonts の一次配布と照合して修正した。フォント名だけでなく OFL 冒頭の著作権表示まで確認する必要がある。
- OS のフォールバックが使えるローカルでは不足グリフを見逃す。Web export で同梱フォントだけに近い条件を確認したことが有効だった。

全素材について、作者、取得 URL、ライセンス、クレジット要否、加工内容、生成手段とプロンプト要点を `games/tactics/assets/CREDITS.md` に記録した。

## 5. 動作確認の方法

### headless とロジック

- `make selfcheck GAMES=tactics` では移動可能範囲、占有、反撃・追撃、回復、敵 AI、3章の勝利条件、保存復元、通常 API だけで最後まで進めることを検査した。画面とは独立した計算の退行検出に効いた。
- `make check GAMES=tactics` ではシーンとスクリプトがロードされ、boot ログが出て、終了時に WARNING / ERROR やリークがないことを確認した。
- headless はロジックとロードには強いが、フォントの欠字、レイアウト、shader、画像の変形、真っ黒な画面、実時間アニメーションは判断できない。

### `screenshot.gd` とアニメーション

- `make screenshot GAMES=tactics` で、表紙、章間絵巻、初回指南、盤面、選べる味方、移動範囲、選択不可理由、扇、巻物予測、交戦、各章、結果を含む32枚を撮影し、全 PNG を目視した。
- キャラクターは10種について、待機・選択・移動・攻撃・被弾・回避・撃破の7動作を、開始・途中・終了の固定時刻で並べた。`AnimationPlayer.pause()` と `seek(time, true)` で同じ瞬間を再現し、動作別の一覧画像と7枚をまとめた contact sheet で、誰のどの動作が欠けたかを確認した。
- 固定時刻画像だけでは補間速度、ヒットストップ、揺れ、粒子の順序は分からない。そのため `movie-play` の実時間録画でも、移動、予測、攻撃、敵軍フェーズ、回復、結果への遷移を確認した。

### movie、通常起動、export

- `make movie GAMES=tactics` は起動直後からメインシーンが表示される5秒間を記録し、真っ黒、初期描画崩れ、終了処理を見た。
- `make -C games/tactics movie-play` は32秒・960フレームの実入力デモを作り、物語、移動、予測、攻撃、敵軍、回復がすべて実行されたことをログでも判定した。最初は28秒で終端に帯状の描画が残ったため32秒へ延ばし、末尾フレームまで正常にした。
- `make tactics-run RUN_FLAGS='--script res://scripts/dev/runcheck.gd'` では、通常の描画付き起動、タイトル表示、F11 のフルスクリーン往復、ウィンドウ close、音声 stream 解放を確認した。
- `make build-all GAMES=tactics` と `make build-web GAMES=tactics` で macOS、Windows、Linux、Web の export が成立することを確認した。export 成功だけでは実行時の表示までは保証しないため、ローカル描画、CI、Web を分けた。

### CI artifact と webtunnel

- CI の Linux + Xvfb + llvmpipe で作られた32枚の PNG を4枚の contact sheet にし、全画面を目視した。5秒の MP4 は `ffprobe` で 1280×720、30 fps、150フレーム、H.264/AAC を確認し、末尾フレームも見た。ローカル macOS だけに依存しない描画確認として効いた。
- webtunnel では Web 版を表紙から開始し、章間絵巻、指南、味方選択、移動、扇、巻物予測、攻撃、敵軍フェーズ、5ターン目の敗北結果まで実操作した。別の新規戦では満 HP で薬を使えない理由、移動取消、待機も確認した。Web 固有のフォント欠字を見つけられたのが最大の効果だった。
- CI と webtunnel でも、物理ゲームパッド、デスクトップ固有のフルスクリーン、実機ごとの音量バランスまでは確認できない。キーボード・パッド・スティック・マウスの経路は InputMap と合成イベントで通したが、物理ゲームパッド実機は使っていない。

## 6. Godot 固有のハマりどころと回避策

- `Control` の既定 `mouse_filter` が盤面の `_unhandled_input` より先にクリックを消費した。背景とコンテナは `MOUSE_FILTER_IGNORE`、操作ボタンだけ停止する構成にした。見た目の Control を重ねた後は必ず実入力経路を通す。
- 合成した `InputEventMouseButton` は OS のマウスポインタを移動しないことがある。処理側でイベント自身の座標を使うと、実マウスと `Input.parse_input_event` のテストを同じ経路にできる。
- 盤面操作中に Button のフォーカスを残すと、方向キーやゲームパッド入力が盤面カーソルからボタンへ移る。盤面中はボタンの focus を無効にし、画面ごとに入力責務を分けた。
- 章間絵巻を足すと、新規開始・次章・保存再開の入口が分かれる。新規と次章だけ story を通し、再開は保存された戦場へ直接戻すようにした。画面追加時は、遷移本体だけでなく screenshot、integration、demo の「開始直後が盤面」という前提も同時に直す。
- `CanvasItem` shader の fragment に入る `COLOR` は、既定テクスチャと CanvasItem の色が既に組み合わされた値である。テクスチャを明示的に読むシェーダでそのまま上書きすると modulate を失い、再度掛けるとテクスチャを二重にする。vertex で tint を varying に退避し、fragment の最終色へ一度だけ掛けた。
- `draw_texture_rect` は描画先の縦横比が違うと画像を変形する。盤面背景は元画像の中央領域を描画先比率で切り、`draw_texture_rect_region` で cover 表示した。
- 音声プレイヤーを停止するだけでは、終了時に stream 参照が残ることがある。BGM、環境音、SE を止めて全 stream を `null` にし、音声サーバーが解放を処理する短い時間を取った。録画では終了直前より前に停止した。
- `--quit-after` の自動終了と通常 close は終了順が違うため、両方を `runcheck.gd` と録画で確認した。
- sandbox 内の headless Godot は動いても、macOS のウィンドウサービスへ接続する描画付き起動は拒否される。headless を見た目確認の代わりにせず、許可された通常起動で screenshot と movie を作った。
- ローカルの OS フォントフォールバックは export 後の欠字を隠す。表示文字のグリフ検査を行い、最終的には Web export の実画面で確認する。
- `AnimationPlayer.seek()` で固定した代表フレームは再現性が高いが、実時間の補間や演出順を保証しない。固定時刻の一覧と実時間録画を併用する。
- Web 版ではブラウザの viewport と Godot の canvas が一致せず letterbox が入る。canvas の DOM 上の矩形から倍率と余白を求めて入力座標を変換し、クリック後の画面変化も毎回確認する。
