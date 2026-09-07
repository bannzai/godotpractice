# blockpuzzle 手直しラウンドの振り返り

対象は issue #42 の追加手直しで、夜の温室と顔つきピースだった前ラウンドの画面を、情報デザイン「連鎖設計室」へ作り直した。最終ブランチは `fix/blockpuzzle`、PR は https://github.com/bannzai/godotpractice/pull/75 。

## 1. 開発の進め方

最初に作業指示書、AGENTS.md、PROJECT.md、issue #42、前ラウンドの PR #50、3回分のヒアリング、既存の制作知見を読んだ。その後、変更前のゲームを実際に起動し、タイトル・モード選択・プレイ・結果を確認した。変更前スクリーンショットを保存し、近い役割の画面を持つ boardrogue と deckrogue も比較対象として集めた。

実装は、まず画面全体の方向を「明るい紙面、単色の幾何、大きな余白、大数字と折れ線」に固定した。旧SVG・画像用シェーダ・顔つきピースへの参照を外し、背景、カード、盤面セル、4色ピース、おじゃま、折れ線、演出を `ColorRect` と `Polygon2D` で組み直した。次に、CPU対戦と90秒計測をタイル状カードにし、選択内容の盤面数・目的・終了条件を右側へ表示した。プレイ画面では操作盤面を紫、CPU盤面を青緑で固定し、中央に `NOW` / `WAIT` と操作できない理由、次に起きることを表示した。連鎖数は大きな数字、スコアは時系列の折れ線にした。

画面下の共通操作ガイドを削除した後、初回だけ盤面、薄い着地点、連鎖グラフを順に強調する3段階チュートリアルを加えた。完了・スキップを同じ保存経路へ通し、古い保存データや不正な `tutorial_seen` の値も安全に解釈するようにした。入力と記録の selfcheck、チュートリアル各段階の screenshot も同時に足した。

素材は画面実装と並行して整理した。Murecho を Google Fonts から取得し、OFL全文と著作権表示を記録した。既存BGM 4点・SE 8点は残し、Python標準ライブラリで8秒の環境音と選択音を追加した。生成物の再現性、音量、クリップ、ループ境界、クレジットを検査した。

最後にローカルの lint、headless、実描画スクリーンショット、通常起動動画、実入力プレイ動画、3デスクトップ向けビルド、Webビルド、通常ウィンドウ起動を順に通した。29枚の画像と動画のフレーム一覧を目視し、変更前後と他ゲームとの識別比較を作って PR に掲載した。webtunnel ではタイトルからCPU対戦、チュートリアル、左右移動、回転、即時落下、一時停止、中間結果、次ラウンド、最終結果まで実操作した。CI artifact もダウンロードし、Linux llvmpipe 上の29画像と動画を再確認してから PR を ready にした。

詰まった点と解決は次のとおり。

- 初回チュートリアル追加後、既存の `movie-play` が操作を受け付けず止まった。デモ側から30・60・90・120フレームで決定入力を送り、通常プレイ入力を135フレーム以降へ遅らせた。最終録画は26.03秒、781フレーム、固定19回、消去9回まで進んだ。
- 画面遷移の0.22秒フェード直後に撮影すると、完成画面ではなく半透明の途中フレームになった。撮影側で遷移とTweenの完了を待ち、状態成立後にPNGを保存した。
- webtunnel の案内から最初に8080番へ接続したが拒否された。caller workflow の実出力を確認し、このセッションで配信された8000番へ接続した。
- CodeRabbit が、`AudioStreamWAV.data.size() / 2` を `loop_end` に使う誤りを見つけた。Godot 4.7 が長いWAVをQOAへ圧縮しており、`data.size()` は圧縮バイト数、`loop_end` はサンプル数だった。`roundi(stream.get_length() * stream.mix_rate)` に変更し、環境音とBGM 4点の実ロードを selfcheck に追加した。修正後の録画末尾にも音声が継続することを確認した。
- GitHub artifact の通常ダウンロードは接続リセットし、再試行も長時間無出力になった。artifact ID とサイズを API で確認し、`gh api` でZIPを直接取得した。取得サイズ一致と `unzip -t` の成功を確認してから展開した。
- Godot を一時検査スクリプトから直接起動した際、`--log-file` を省くとサンドボックス外の `user://logs` を開けずクラッシュした。作業ディレクトリ内の絶対パスを `--log-file` に渡すと正常に検査できた。

## 2. 使ったツール・skill・コマンド

| 手段 | 実際の用途 |
| --- | --- |
| `godot-development` skill | Godot 4.7の起動、headlessと実描画の分離、ログ検査、Movie Maker、exportの完了条件と既知の注意点を確認した |
| `game-asset-search` skill | Murechoの検索・取得、OFL確認、独自生成音源の仕様、CREDITS、手続き生成物の検査方法を使った |
| `webtunnel` skill | `preflight`、`up blockpuzzle --software-webgl --ref fix/blockpuzzle --wait`、`cdp`、`down` を使い、GHA runner上のWeb版を実操作した |
| `agent-browser` skill / CLI | `--session blockpuzzle` と専用CDP URLを常に指定し、クリック、キー入力、スクリーンショット、console・page error確認を行った |
| `gh-r2-image` skill / `puts` | PR証拠の画像・MP4をR2へアップロードし、公開URLをPR本文へ埋め込んだ |
| `fix-pr-reviews` skill | CodeRabbitの指摘を現行コードで検証し、修正後に未解決スレッド0件と再レビュー成功を確認した |
| Godot 4.7 / GDScript | UI、図形描画、Tween、入力、保存、selfcheck、integration、screenshot、Movie Maker、各形式のexportを実行した |
| `gdlint` | `gdlint scripts/` を `make lint` と `make test` から実行した |
| Python標準ライブラリ | 決定的なWAV生成、既存BGM・SEの再生成、環境音・選択音の追加に使った |
| `search-assets.sh` / `fetch-asset.sh` | Google FontsのMurechoを検索し、`Murecho[wght].ttf` を取得した |
| `check-credits.sh` / `check-procedural-assets.sh` | フォント・音源の記録と、14 WAVの形式、非無音、ピーク、クリップ、ループ境界、再生成SHA-256一致を検査した |
| `ffmpeg` / `ffprobe` | AVIからH.264/AACのMP4へ変換し、長さ・音声形式・末尾音量、2秒間隔の一覧、末尾フレームを確認した |
| ImageMagick | 29枚のスクリーンショット、変更前後、他ゲームとの識別比較を一覧画像にした |
| `git` / `gh` | 差分確認、commit・push、draft PR作成と更新、ready化、review・checks・CI run・artifactの確認に使った |
| `gh api` / `unzip` | 通常取得が止まったCI artifactをZIPで直接取得し、整合性を検査して展開した |
| AppKitを呼ぶ一時JXA | `make blockpuzzle-run` で起動した対象PIDだけへ通常終了要求を送り、他のGodotプロセスを巻き込まずexit 0を確認した |

主なローカル検証コマンドは次のとおり。

```sh
make test GAMES=blockpuzzle
make screenshot GAMES=blockpuzzle
make movie GAMES=blockpuzzle
make -C games/blockpuzzle movie-play
make build-all GAMES=blockpuzzle
make build-web GAMES=blockpuzzle
make blockpuzzle-run
```

画像生成モデル、外部の画像素材サイト、外部のBGM・SE配布サイトは使っていない。skillを読んだことと、そのskillが扱うすべてのサービスを使ったことは区別している。

## 3. 欲しかったが無かったツール・skill・スクリプト

- **コード描画専用の素材検査**。現在の `check-procedural-assets.sh` は生成ファイルには強いが、`ColorRect` / `Polygon2D` だけで描く方針、画像参照0件、禁止ノード0件、コード生成物のCREDITS記録までは検査しない。画像ファイルを持たない経路が `game-asset-search` にあると手作業の `rg` と目視を減らせる。
- **状態駆動のスクリーンショット器**。シーン名、成立を待つ条件、Tween完了、撮影名を宣言すると、固定秒数ではなく状態を待って撮る共通部品が欲しかった。初回チュートリアル3段階、操作可能・不可能、連鎖途中、予告落下の撮り逃しを減らせる。
- **図形アニメーションの一覧生成**。図形の種類と待機・移動・着地・被害・消去を渡すと、開始・途中・終了を一覧化するもの。今回は5図形×5動作×3時点をゲーム固有の撮影コードで組んだ。
- **チュートリアル対応の実入力録画**。InputEventの押下・解放、オーバーレイの段階送り、通常プレイ開始待ち、Movie Maker終了前の音声解放、MP4変換、フレーム一覧までを一括化できると、`movie-play` がチュートリアルで止まる回帰を減らせる。
- **インポート後音声のループ検査**。元WAVのフレーム数だけでなく、Godotで実際にロードした形式、`mix_rate`、`get_length()`、`loop_end` を比較する検査が欲しかった。QOAやIMA ADPCMの圧縮バイト数をサンプル数と誤認する実装を検出できる。
- **CI artifact取得・目視準備の共通化**。ダウンロード進捗、再開、API ZIPへの切替、サイズ・ZIP整合性、PNG一覧、動画の代表フレーム、ログ全文検査までを一つにしたものが欲しかった。
- **PR証拠の差分アップロード**。ローカルファイルのハッシュを持ち、変わった証拠だけ `puts upload` し、PR本文のURL・SHA・検証値を安全に差し替えるもの。今回はレビュー修正後のMP4・フレーム一覧・末尾を手動で再アップロードした。

## 4. 素材の準備方法と使い勝手

### 画像・画面表現

今回は画像ファイルを新規作成せず、前ラウンドの手続きSVG 11点と画像用シェーダを削除した。背景の色面、カード、盤面セル、正方形・円・ひし形、内側記号、おじゃま、消去片、折れ線をGDScriptの `ColorRect` / `Polygon2D` で作り、動きは `Tween` に限定した。

この方法は、平面の情報デザインでは色、寸法、余白、線幅を一か所で揃えやすく、SVGの再生成・import・参照差し替え・画像ライセンス確認が不要だった。決まった時刻の図形も再現しやすく、連続フレーム検査との相性が良かった。一方、複雑な輪郭、質感、描き替えアニメーションには向かない。小さな図形生成ヘルパとTweenの寿命管理が増え、表現を幾何に限定できないゲームへそのまま流用する方法ではない。

画像生成やフリー画像検索は使っていないため、今回の実績からそれらとの品質・速度比較はできない。

### BGM・SE

前ラウンドの場面別BGM 4点とSE 8点を残し、Python標準ライブラリで8秒の環境音と短い選択音を追加した。音源は22050Hz・16bit・モノラルのWAVとして決定的に生成し、同じバイト列ならファイルを書き直さない。`check-procedural-assets.sh` で14点の形式、非無音、ピーク、クリップ、ループ端点、再生成一致を検査した。

手続き音源は外部ライセンスがなく、長さ・音量・音程・周期をコードで揃えやすかった。操作音と抽象的な環境音には扱いやすい。一方、波形の数値検査と録画の音声ストリーム確認では、音楽としての好みや長時間の聴き疲れは評価できない。そこは未検証の主観判断として残した。

### フォント

`game-asset-search` のGoogle Fonts検索・取得スクリプトで Murecho の可変フォントを取得した。素材源は https://fonts.google.com/specimen/Murecho 、ライセンスはOFL-1.1、著作権表示は Murecho Project Authors のものを `assets/fonts/OFL.txt` と `assets/CREDITS.md` に残した。

検索、ファイル選択、ライセンス取得、配置まで同じskillで行える点は扱いやすかった。可変フォント1ファイルで太さを使い分けられ、禁止指定だった Noto Sans JP を外せた。一方、Godotのimport後表示は実スクリーンショットで確認する必要があり、ライセンスが正しいことと日本語が意図した太さで読めることは別の検証だった。

## 5. 動作確認の方法、効いたことと不足

**headless の `make test`、`selfcheck.gd`、`integration.gd`** では、既存の盤面ロジック・CPU・保存互換を維持しながら、初回チュートリアルの記録、キー・ゲームパッド・マウスの実 `InputEvent`、環境音とBGM 4点の全サンプルループを検査した。速く再現性があり、QOAのループ終端のような数値問題の回帰防止に効いた。headlessでは音声プレイヤー生成を省くため、実際の聞こえ方やTheme・フォント・Tweenの見た目は判定できない。

**`screenshot.gd`** では29 PNGを実描画で生成した。タイトル、モード選択、ヘルプ、プレイ、待機理由、一時停止、途中結果、勝敗、90秒結果、タイトル復帰、チュートリアル3段階、連鎖・予告落下に加え、5図形の各動作を撮った。全画像を一覧化して目視したため、文字切れ、重なり、禁止していた共通操作ガイド、半透明の撮影ミスを見つけやすかった。

アニメーションは、5図形それぞれの待機・移動・着地・被害・消去を、開始・途中・終了の3時点で並べた。静止画の連続フレームは形、色、傾き、消滅、Tween終了後の残骸確認に効いた。ただし3時点の間にだけ出るちらつきや補間の滑らかさは否定できないため、通常の `movie`、26秒の `movie-play`、Web実操作録画で補った。

**`movie`** は操作なしの起動からタイトルを5.03秒撮り、0秒・2秒・4秒・末尾を目視した。**`movie-play`** は盤面や抽選列を直接書き換えず、初回チュートリアルを実キー入力で進め、その後の通常状態を読みながら左右・回転・即時落下を26.03秒送った。映像781フレーム、H.264 1280×720、AAC 48kHz 2chを確認し、2秒間隔の一覧と末尾を目視した。修正後は末尾1秒の平均音量が−24.7 dBで、ループ後も無音になっていないことを確認した。録画全編を聴いて長時間の疲れを評価したわけではない。

**通常起動** は `make blockpuzzle-run` でウィンドウと `blockpuzzle boot` を確認し、対象PIDだけをAppKitで通常終了してexit 0まで確認した。headlessやMovie Makerとは別に、通常のGUI起動経路が残っていることを確認できた。

**ビルド** は macOS・Windows・Linux・Web のexportをローカルで実行し、必要な成果物を確認した。WindowsとLinuxの実機デスクトップ操作はしておらず、エクスポート成功とLinux CIを実機検証の代わりとはしていない。

**CI artifact** は最終コミット `4951efb` の全ジョブ成功後に取得した。LinuxのXvfb・llvmpipeで生成された29 PNGを全目視し、5.03秒のMP4を0秒・2秒・4秒・末尾で確認した。ログ全文では、V-Syncを変更できない既知のllvmpipe警告がスクリーンショットと動画に各1件あり、ゲームのERROR・ObjectDBリーク・未解放リソースはなかった。

最終CI: https://github.com/bannzai/godotpractice/actions/runs/34108178456

**webtunnel** は `--software-webgl` で `fix/blockpuzzle` をWebエクスポートし、専用ChromiumでタイトルからCPU勝利結果まで実操作した。Godot起動判定、WebGL2、canvas 1279×656、console、page errorを確認した。デスクトップとは異なるcanvas比率なので座標変換が必要だった。Web版でフルスクリーンや物理ゲームパッドなどのデスクトップ固有機能は確認していない。

Web実操作: https://github.com/bannzai/godotpractice/actions/runs/34102543023

## 6. Godot 固有のハマりどころと回避策

- **`AudioStreamWAV.loop_end` の単位**。`data.size()` はインポート後データのバイト数で、QOAやIMA ADPCMでは圧縮後の値になる。`loop_end` はサンプル位置なので、全体ループには `roundi(get_length() * mix_rate)` を使う。元WAVだけでなくGodotでロードしたResourceをselfcheckする。
- **`ColorRect` と `Polygon2D` の基底型**。前者は `Control`、後者は `Node2D` で、同じ型の変数へ入れて位置・回転を操作できない。消去片は共通の `Node2D` 親を作り、その子として図形を置き、親の `position`、`rotation`、`modulate` をTweenした。
- **Tween対象の寿命**。大数字と単位ラベルを別ノードにすると、一方だけを解放した時に表示ノードが連鎖ごとに蓄積する。演出単位の親を持たせるか、作成した全ノードに同じ寿命を持たせる。画面遷移時も古いTweenを止めてからノードを片付ける。
- **フェードと撮影タイミング**。入力直後は論理画面が変わっていても、contentの0.22秒フェード中である。`process_frame` だけを1回待つのでは足りず、遷移時間と目的状態の成立を待ってから撮る。
- **初回オーバーレイと自動入力**。チュートリアルはゲーム入力を遮るため、従来のデモをそのまま流すと操作検証にならない。チュートリアル段階を実入力で完了させ、その後に本編入力を始める。スキップも通常完了と同じ保存関数へ通す。
- **音声を含む終了**。停止後も毎フレームの場面更新からBGM切替が呼ばれると再生が復活する。停止フラグで後続再生を拒否し、stream参照を外し、Movie Maker側は終了前に複数フレームを進めて音声スレッドへ反映する。ログで `resources still in use` とObjectDBリークを確認する。
- **headlessと実描画の役割**。headlessはロジックとロード確認には速いが、フォント、Theme、Tween、OpenGL、音声の実挙動を保証しない。実描画のscreenshot・movie、通常ウィンドウ、Linux CI、Webを別々に通す必要がある。
- **ログ出力先**。サンドボックス下で既定の `user://logs` に書けないと、実装と無関係な失敗やクラッシュになる。すべてのGodotコマンドで作業ディレクトリ内の絶対パスを `--log-file` に渡し、終了コードだけでなくログ全文を検査する。
- **Web canvasの座標**。runnerのブラウザは1280×656付近で、1280×720のゲーム座標と一致しない。比率を保った縮小と余白を考慮してゲーム座標をクリック座標へ写し、起動判定だけでなく実スクリーンショットで入力先を確認する。

最も効いた組み合わせは、headlessの数値検査、状態駆動のスクリーンショット、通常状態へ実入力する録画、Linux CI artifact、Web実操作を別々の証拠として持つことだった。どれか一つの成功を他の経路の代用にしないことで、UI、入力、アニメーション、音声、終了処理の問題を切り分けられた。
