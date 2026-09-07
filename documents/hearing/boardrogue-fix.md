# boardrogue 第2ラウンド 開発ヒアリング

## 1. 開発の進め方

### 実施した順序

1. `AGENTS.md`、issue #60、第1ラウンドの PR #63、既存の `documents/knowledge/boardrogue.md`、元になった札棋の仕様を読み、変更前のタイトル・地図・盤面・札一覧を保存した。
2. `make boardrogue-run` で実際の対局を動かし、マウス・キーボード・ゲームパッドの攻撃操作を調べた。クリック経路は成立していたが発見しにくく、盤上ドラッグは戦闘中も移動として処理されていた。
3. 最優先で入力経路を修正した。準備フェーズのドラッグは移動、戦闘フェーズのドラッグは攻撃へ分岐し、敵札と敵王への攻撃を同じ経路へ揃えた。
4. 攻撃の再発防止を先に固めた。3入力系統それぞれで、選択、攻撃宣言、攻撃力比較、敗者の捨て場移動、勝者の前進、敵王の体力減少までを実入力イベントで検査する `integration.gd` を追加した。
5. 画面の方向性を、水墨画・彩色、生成りの和紙、墨、朱、古金へ切り替えた。タイトル、絵地図、4舞台、札12種、主人公と敵の肖像5種を画像生成し、Godot へ取り込んだ。
6. 生成画像を前提に、巻物パネル、縦書きのフェーズ札、合法対象の脈動、選べない理由、初陣5段階の手ほどき、地図の行き先プレビュー、舞台ごとの光・環境音を組み込んだ。
7. `screenshot.gd` を、タイトル・地図・4舞台・札12種・人物・チュートリアル・攻撃前後を撮る62画面へ拡張した。`demo.gd` は盤面を直接書き換えず、実際の公開操作だけで敵札撃破と敵王攻撃へ到達する手順に変更した。
8. ローカルの lint、selfcheck、スクリーンショット、2種類の録画、3デスクトップ向けビルド、Webビルド、実起動を確認した。その後 webtunnel で Web 版を実操作し、CI artifact も別途ダウンロードして目視した。
9. 変更前後、deckrogue・ghostrogue・cardbattle との識別比較、攻撃の連続フレーム、Web実操作を比較画像へまとめ、puts で PR #78 に添付した。CI 全成功後に draft を解除した。

### 詰まった点と解決方法

- 攻撃できない直接原因は、`_drag_card()` がフェーズを見ず常に `mode = "move"` を設定していたことだった。敵がいるマスへのドロップが「占有マスへの移動」として拒否されていたため、戦闘中だけ攻撃として配送した。
- クリック攻撃は元から可能でも、敵王ボタンが常に押せそうに見え、移動済みなどの失敗理由も分からなかった。合法な敵札と敵王だけを朱で脈動させ、失敗理由を文章にし、操作の発見性も修正対象に含めた。
- 生成画像は一枚ごとの描き込みは強いが、札ごとの余白、人物の大きさ、色温度が揃わなかった。用途別のプロンプト、透明四隅と寸法の検査、縮小一覧、Godot 上のギャラリー撮影を組み合わせて揃えた。
- 生成札は一枚絵なので、既存の4コマスプライトと同じ方法では動かせなかった。既存スプライトは検査用に保持し、実表示の生成PNGには Tween で移動・突進・揺れ・色変化・回転・消失を与えた。
- 描画用 fixture が通常は作られない盤面を構成すると、保存検査由来の `save_error` が結果画面へ残った。撮影用保存先を `res://tmp/` に隔離し、fixture による既知の保存エラーだけを攻撃結果の撮影前に消した。実プレイの保存エラーを隠す処理にはしていない。
- `make boardrogue-run` をタイムアウトで強制終了した最初の確認は exit 2 になった。次は起動プロセスを確認し、最前面表示を調べ、通常の終了操作で閉じて target 自体の exit 0 を確認した。
- webtunnel は 1280×656 の Chromium に 1280×720 の Godot 画面が収まるため、ゲーム座標をそのままクリックできなかった。アスペクト比による左右余白と縮尺を計算して座標を変換した。途中から `agent-browser` のスクリーンショットが既定の30秒でタイムアウトしたため、同じ CDP セッションへ `Input.dispatchMouseEvent` と `Page.captureScreenshot` を直接送り、敵王への3ダメージまで状態を保持したまま完了した。
- CI artifact は `gh run download` が9分以上無出力で止まり、通常の API 取得も約15 KB/sだった。一時スクリプトで署名付きURLを外へ表示せず8分割の Range 取得にし、46,276,084 bytes のサイズと ZIP CRC を検査してから展開した。

## 2. 使ったツール・skill・コマンド

### skill と支援機能

- `godot-development`: Godot 4.7 の起動、import、検証、録画、export templates、ログ確認の基準に使用した。
- `game-asset-search`: 生成素材の用途定義、除外条件、検品、クレジット記録の進め方に使用した。今回は外部画像検索より画像生成を主経路にした。
- `imagegen`: タイトル1点、絵地図1点、舞台4点、透明背景の札12点、肖像5点の計23点を生成した。
- `commit-create-pr`: 変更範囲、検証、個人情報確認を行い、2コミット、push、draft PR の作成と本文更新に使用した。
- `webtunnel`: GitHub Actions 上の Web エクスポートと Chromium を起動し、ローカルから WebGL 版を実操作した。終了時に `down` し、録画 artifact も取得した。
- `agent-browser`: セッション名と CDP URL を明示し、Canvas のクリック、キー入力、スクリーンショット、console と errors の確認に使用した。
- `pr-attach-screenshots`: puts へのアップロード、公開URLの取得、ローカル画像との SHA-256 一致確認、PR本文の画像区間更新に使用した。7画像を新規アップロードした。
- サブエージェント: 攻撃入力の調査・統合テスト、フォント調査、環境音と再生管理の検査を分担し、変更ファイルの担当を分けて衝突を避けた。

### 実際に使った主なコマンドとツール

- GitHub 調査・PR操作: `gh issue view`、`gh pr view`、`gh api`、`gh pr create --draft`、`gh pr edit`、`gh pr checks`、`gh run view`、`gh run download`、`gh pr ready`
- Godot の一括検証: `make test GAMES=boardrogue`
- 個別検証: `make check GAMES=boardrogue`、`make selfcheck GAMES=boardrogue`、`make screenshot GAMES=boardrogue`、`make movie GAMES=boardrogue`
- 自然対局の実入力録画: `make -C games/boardrogue movie-play`
- 起動・ビルド: `make boardrogue-run`、`make build-all GAMES=boardrogue`、`make build-web GAMES=boardrogue`
- 比較対象の撮影: `make screenshot GAMES="deckrogue ghostrogue cardbattle"`
- GDScript lint: `gdlint`。通常は Make target 経由で `games/boardrogue/scripts/` を検査した。
- Godot 本体: `/Applications/Godot.app/Contents/MacOS/Godot`。GL Compatibility、固定1280×720、録画時は固定30 fpsで使用した。
- 動画: `ffmpeg` で AVI から H.264 MP4 への変換と指定フレームの抽出、`ffprobe` で時間・容量・総フレーム数を確認した。
- 画像比較: ImageMagick の `magick montage` で変更前後、識別テスト、攻撃連続フレーム、Web実操作の比較画像を作った。ローカル画像は画像表示ツールで原寸または一覧表示して目視した。
- 素材検査・生成: Python の `generate_audio.py`、固定seedの数値検査、PNG の寸法・RGBA・alpha確認を使った。
- フォント: Google Fonts 公式配布ファイルを取得し、SHA-256 を照合した。
- PR画像: `puts ls` で接続確認後、`pr-attach-screenshots` のスクリプトから `puts upload` と `curl` による公開画像検証を行った。
- Web実操作の補助: `curl` で CDP endpoint を確認し、Node.js の WebSocket から Chrome DevTools Protocol を送った。ローカル起動確認では `osascript` も使用した。
- Git: `git diff`、`git status`、`git add`、`git commit`、`git push`。最終的に作業ツリーと origin の commit が一致することを確認した。

## 3. 欲しかったが無かったツール・skill・スクリプト

- **画像生成セットの一括管理**: 「用途、縦横比、透明背景、共通画風、除外条件、出力名」を manifest に書くと、複数画像の生成、命名、alpha・寸法検査、縮小 contact sheet、CREDITS のひな型作成まで行う skill が欲しかった。23点を個別に生成・検品した部分を大きく減らせる。
- **Godot の盤ゲーム向け入力試験部品**: マウスのクリック・ドラッグ、キーボード、ゲームパッドについて、選択元と対象だけ渡せば同じ期待値を検査する共通 harness が欲しかった。今回は6経路を `integration.gd` に個別記述した。
- **状態別スクリーンショット定義**: 撮影名、遷移、入力、待機条件をデータで宣言し、`frame_post_draw` 待ちと PNG 保存を共通化する仕組みが欲しかった。62画面の順序と fixture を GDScript へ直接書く必要があった。
- **webtunnel の Godot 座標変換とノード操作**: Godot の基準解像度と Chromium viewport から座標を自動変換し、`cell_1_2` のような Control 名で操作できる補助が欲しかった。ピクセル座標の手計算と、遅延時の生CDP操作を減らせる。
- **CI artifact の選択取得または分割取得**: artifact 内の代表 PNG と動画だけを選ぶか、大きな ZIP を自動で並列 Range 取得し、サイズ・CRC・展開まで行うスクリプトが欲しかった。今回作った `tmp/download-ci-artifact-parallel.sh` は boardrogue と特定 artifact に固定した一時対応なので、そのまま共有化はできない。
- **音声の自動試聴レポート**: ループ境界、peak、clip、長さ、スペクトログラムと、短い試聴用 montage をまとめる仕組みが欲しかった。今回は数値と再生ライフサイクルを検査したが、agent による聴感評価までは行っていない。

## 4. 素材の準備方法と使い勝手

### 画像

- 第三者の画像素材は使わず、Codex の画像生成で23点を作った。共通条件は、水墨の筆致、墨のにじみとかすれ、岩絵具、生成りの和紙、墨黒・朱・古金である。文字、ロゴ、透かし、現代物、実在家紋、既存作品の人物を除外した。
- タイトルと地図は UI を重ねる余白、舞台は盤面中央の可読性、札は小さくしても分かる全身の輪郭と透明背景、肖像は顔と装束の差を個別に指定した。プロンプトの要点と生成手段は `assets/CREDITS.md` に各ファイル単位で記録した。
- 画像生成は、筆の濃淡、人物の量感、風景の奥行きを短時間で得られ、手続きSVGよりゲーム固有の印象を作りやすかった。一方で、文字らしい異物、手足や武器の欠け、余白と縮尺の不統一は目視が必要だった。同一入力からのバイト一致も期待できない。
- 既存の手続きSVGは、再生成の決定性、4コマの境界検査、軽さに優れていた。ただし人物や風景の描き込み量を増やすにはコード量が大きく、他ゲームと同じ切り絵調になりやすかった。今回は実表示を生成PNGへ移し、SVGの4コマ素材はアニメーション検査用に残した。

### BGM・SE・環境音

- 外部録音は使わず、`generate_audio.py` で固定seedの波形合成を行った。22,050 Hz、16 bit、stereo WAV とし、既存の6曲・6SEに、川、風、雪、虫の8秒ループ4種と尺八の合図1種を追加した。
- 五音音階、撥弦、笛、pad、bass、太鼓、木、鉦を数式とノイズで合成した。環境音は周期ノイズと整数周期の倍音を使い、ループ境界でも連続するようにした。
- 合成音は第三者ライセンスと録音環境が不要で、固定seedから再生成でき、peak 0.82、clip 0、ループ境界差0を自動検査できた。反面、生録音の空気感や演奏の揺らぎには及ばず、最終的な聴感評価は別に必要である。

### フォント

- Google Fonts 公式配布の Yuji Syuku を使用した。公式ファイルとの SHA-256 一致を確認し、OFL 1.1 と著作権表示を `assets/fonts/OFL.txt` に保存した。
- 筆文字らしい見出しと本文を同じフォントでまとめられ、水墨画との一体感は得やすかった。ファイル容量は約8.4 MBで、Webビルドにも含まれるため、容量面ではシステムフォントより重い。
- Zen Old Mincho、Noto Sans JP、M PLUS Rounded は画面表示に使わなかった。

## 5. 動作確認の方法

### headless の selfcheck と integration

- `make test GAMES=boardrogue` から lint、import、起動、selfcheck、入力統合、素材検査を通した。`integration OK: 254 件`、`artcheck OK: 19種 × 5動作 × 4コマ` まで確認した。
- headless はルール、保存、デッキ、AI、入力イベント後の状態変化、リソースのロード失敗を高速に繰り返すのに効いた。特に3入力系統で敵札撃破と敵王の体力減少を同じ期待値にしたことが、攻撃不具合の再発防止に効いた。
- headless だけではフォントの大きさ、背景とのコントラスト、画像の欠け、Tween 中の見え方、真っ黒な画面を判断できない。

### `screenshot.gd`

- `await RenderingServer.frame_post_draw` 後に viewport を保存し、タイトル、地図、チュートリアル、4舞台、札12種、人物5動作、攻撃前・接触・結果など62 PNGを撮った。
- 静止画は、余白、文字の薄さ、盤面と背景の分離、カードの縮小時識別、合法対象の色を比較するのに最も効いた。変更前後と他ゲームとの識別テストも同じ1280×720へ揃えられた。
- 一枚だけでは脈動、攻撃の時間順、暗転、音、操作可能性は分からない。そのため攻撃は3連続フレーム、生成絵の動作は複数コマ、全画面は contact sheet で確認した。

### movie とアニメーション

- `make movie GAMES=boardrogue` で起動からタイトル表示まで5秒を録画し、黒画面や初期描画崩れがないことを確認した。
- `make -C games/boardrogue movie-play` は30 fps・900フレームの自然対局を実入力で進めた。309フレーム目の敵札撃破と、518フレーム目の敵王への3ダメージをログと抽出フレームで確認した。
- 生成PNGのアニメーションは、`seek_pose()` で待機・移動・攻撃・被弾・消滅の0・2・3コマ目を撮り、実時間の Tween は movie-play で確認した。攻撃の突進、被弾の揺れと色、死亡の回転とalpha減少を静止画と動画の両方で見た。
- `ffprobe` でフレーム数を数え、`ffmpeg` の `select=eq(n\,N-1)` で本当の最終フレームを抽出した。`-sseof -1` は最終フレームではなく終了1秒前なので使わなかった。

### CI artifact

- GitHub Actions の Xvfb + llvmpipe 上で作られた `boardrogue-screenshot-and-movie` を取得した。全62 PNGを contact sheet で目視し、タイトル、地図、盤面、札12種一覧、攻撃結果、雪原、最終将軍を原寸でも確認した。動画の最終フレームも確認した。
- ローカルGPUだけでなく Linux のソフトウェア描画でも同じ構図が出る確認として効いた。ログは既知の「V-Sync modeを変更できない」警告以外に WARNING、ERROR、リークがなかった。
- artifact のダウンロード自体が遅く、標準の `gh run download` には進捗表示と部分取得がない点が不足していた。

### webtunnel

- `fix/boardrogue` の Webエクスポートを GitHub Actions 上で配信し、Chromium の WebGL 2 で「札を選ぶ → 配置 → 登場 → 敵札撃破 → 敵王へ3ダメージ」まで操作した。console には Godot 4.7、WebGL 2、`boardrogue boot` だけが出ており、errors は空だった。
- Web固有の入力配送、Canvasの拡縮、WASM/PCKのロードを確認できた点が効いた。終了後は `down` し、約38分のブラウザ録画と敵王HPが10から7になった最終フレームも回収した。
- デスクトップ固有のフルスクリーン、ゲームパッド、macOSネイティブ描画は Web版では確認できない。そこはローカル実起動、3入力の integration、CI artifact と役割を分けた。

## 6. Godot 固有のハマりどころと回避策

- `Control` のクリック、ドラッグ、キーボードフォーカス、ゲームパッドフォーカスは別経路になりやすい。UI上の最終処理だけを単体テストせず、`InputEventMouseButton`、`InputEventMouseMotion`、`InputEventKey.physical_keycode`、ゲームパッド操作を press / release の実イベントで通す。
- ドラッグ開始時の `mode` を固定すると、同じ盤上札でもフェーズごとの意味が変わるゲームで破綻する。入力を受けた時点のフェーズと合法手から、移動か攻撃かを決める。
- フォーカス可能、押せる外見、合法な操作を一致させないと、Control はイベントを受けてもゲーム側で拒否され、ユーザーからは無反応に見える。敵王ボタンは攻撃可能時だけ enabled にし、合法マスは色と脈動でも示した。
- Tween と scene tree の終了は非同期である。固定秒数だけ待たず `main.busy` を待ち、撮影は `RenderingServer.frame_post_draw` 後に行う。終了時は Tween を kill し、AudioStreamPlayer を停止・解放してから node を破棄する。これで `ObjectDB instances were leaked` と `resources still in use` を避けた。
- 生成画像を追加した直後は `.import` がなく、ロードやexportの確認が不安定になる。素材追加後に `make import` を通し、全プリセットへ元PNGとフォントが含まれることをビルドで確認する。
- GL Compatibility と WebGL 2 の共通範囲を守る必要がある。和紙と墨の shader は `canvas_item` の単純な低周波・高周波ノイズ、周期波、端からの距離で構成し、レンダラ変更やデスクトップ専用機能を避けた。
- 1280×720の基準画面でも、Webの実viewportが16:9とは限らない。`keep` の縮尺と左右・上下の余白を含めてゲーム座標をブラウザ座標へ変換する。
- Movie Maker はゲーム時間を固定fpsで進めるので、実時間の待機やAIの `busy` を雑に扱うと、録画だけ途中状態になる。フレーム数を基準にしつつ、各操作前に `busy == false` を待ち、完了条件をログで検査した。
- 合成したループ音源が数値上連続でも、nodeを破棄する前に再生を止めないと終了時リークになる。場面切替を冪等な `play_ambience(key)` にまとめ、空文字で停止できるようにし、`shutdown()` を撮影・録画の終了処理から await した。
- 描画fixtureで内部状態を直接組み立てる場合、それを実プレイ証拠にしてはいけない。fixture は見た目と連続フレームの比較だけに使い、敵札撃破・敵王攻撃の成立証拠は integration、自然対局の movie-play、webtunnel の実入力で別に取った。
