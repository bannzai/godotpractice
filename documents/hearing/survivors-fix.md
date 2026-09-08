# survivors 開発ヒアリング

## 1. 開発の進め方

### 全体の順序

1. まず変更前のゲームを起動し、タイトル、プレイ、アップグレード、リザルトを撮影した。あわせて `ghostrogue`、`roguelike`、`shooter` の代表画面も並べ、ゲーム単体の完成度だけでなく、同じリポジトリ内の別ゲームと見分けが付くかを確認した。
2. 変更前の構成を「画面上下の共通的な HUD」「画面下部の操作説明」「夜の森を模した SVG 中心の見た目」と整理した。操作の順番が画面から読み取りにくく、他ゲームとも印象が近いことを主要な課題にした。
3. 実装前に `documents/knowledge/survivors.md` へ診断と方針を記録した。テーマをネオン調の「NEON DAWN」に定め、生成ラスター画像、シンセウェーブ系の音、無限グリッド、縞模様の太陽、最小限の HUD、画面四辺を使う XP 表示、場面内チュートリアル、ネオン看板風アップグレード画面を一つの方向性として揃えた。
4. プレイヤー、敵4種、攻撃3種、タイトルアートの計9点を画像生成し、Godot へ取り込んだ。画像を置き換えるだけでなく、背景、シェーダー、HUD、チュートリアル、アップグレード、ポーズ、リザルトも同じ視覚言語へまとめ直した。
5. ゲームの境界 clamp を撤去し、どこまでも続いて見える遠近グリッドへ変更した。画面全体には RGB ずれ、走査線、粒子、周辺減光を持つ VHS 風シェーダーを加えた。
6. 画面下部の常設操作説明を外し、「移動する → 光を集める → レベルアップして選ぶ」の3段階を実際のゲーム内状態で進めるチュートリアルにした。スキップ、時間経過、キーボード、マウスの経路も加えた。
7. 既存の4曲と9種類の効果音が担っていた役割を保ったまま、波形生成ロジックをシンセウェーブ寄りに変更し、16秒の環境音を追加した。フォントは RocknRoll One に変更し、通常の Control と `draw_string()` の両方へ明示的に適用した。
8. selfcheck と入力検証を増やし、代表画面28枚、短い movie、全編を自動進行する movie、音声、負荷、長時間プレイ、各プラットフォームの export、実ウィンドウ起動を順に検証した。
9. draft PR を作成して CI を通し、CI artifact の画像と動画を目視した。最後に webtunnel 上の実 Chromium で、タイトルから敗北、タイトルへの復帰まで実際に操作した。

実装のまとまりは、診断と方針、ゲーム本体の刷新、最終検証結果の記録、の順で分けた。この順にしたことで、見た目の変更理由と、後から追加した検証だけの変更を混ぜずに追えるようにした。

### 詰まった点と解決方法

- 生成画像の一部は「透明背景」と指定しても、市松模様を背景画像として描き込んでいた。見た目だけで透明と判断せず、RGBA、四隅の alpha、縮小表示を確認し、問題のある画像は再生成または編集した。
- 1枚のポーズシートで全状態を生成すると、フレーム間で造形が安定しなかった。そこでキャラクターごとに一貫した1枚絵を使い、位置、傾き、拡縮、色、alpha を Godot 側で変えて idle、move、attack、hurt、death を各6フレーム生成した。360体前後を出す構成なので、各フレームで同じ `Texture2D` を共有し、負荷も再計測した。
- Button はマウスの hover とキーボード focus が別状態のため、マウスを重ねた候補と Enter で決定される候補が食い違った。hover 時に `grab_focus()` を呼び、`focus_entered` を表示上の選択状態へ反映した。マウスで候補を変えてから Enter を押す入力テストも追加した。
- 全画面シェーダーの `smoothstep()` に大きい edge と小さい edge を逆順で渡している箇所があった。環境によって挙動が未定義になるため、小さい値から大きい値の順へ直し、GL Compatibility と Web の差が出にくい形にした。
- Godot の `--quit-after` は、ゲーム側で読む通常の GDScript 引数には現れなかった。movie のフレーム数を環境変数でゲーム側にも渡し、最終フレームで音声を停止し `stream = null` にしてから終了する構成にした。
- Dummy audio driver では通常の BGM 再生を抑えたい一方、Movie Maker では音声を記録する必要があった。実行モードを分け、CoreAudio を使う `audiocheck` も別に用意した。
- 音声再生リソースが終了時に残る問題は、`stop()`、`stream = null`、audio mixer が解放を反映するまでの待機を入れて解消した。
- 起動確認の再帰 `make` では、出力されたコマンド文字列を実行ログとして誤検出した。再帰先を `--silent` にし、実際のゲーム出力だけを検査できるようにした。
- title movie の平均輝度は意図した暗い背景のため既存の閾値を下回った。真っ黒な画面との差を保てる値を実測し、判定閾値を20へ調整した。見た目を明るくして検査を通すのではなく、実際のデザインと黒画面検出の目的を両立させた。
- 遠方座標を含む `Vector2` の一致判定は浮動小数点誤差で不安定だった。完全一致を避け、意図した精度の許容差を持たせた。
- 演出数の上限を単純な FIFO で処理すると、重要な演出が先に消えることがあった。イベント種別ごとの上限と処理順を見直し、selfcheck で上限超過時の挙動を確認した。
- PR に掲載した動画 URL が一度 `ghostrogue` の動画を指していた。`survivors` 自身の 21,613,009 byte の動画を再アップロードし、リモートとローカルの SHA-256 を照合した。掲載した画像13点についても同様にローカルとリモートのハッシュを確認した。
- CI artifact の大きな動画はダウンロードが遅く、進捗も分かりにくかった。必要な画像と動画末尾フレームは取得して確認したが、重複する318 MBのローカル録画ダウンロードは中断した。CI artifact と既に確認済みの全編動画で同じ確認目的を満たした。

## 2. 使ったツール・skill・コマンド

### skill と支援機能

- `godot-development`: Godot 4.7 の起動方法、headless 検証、export templates、ログ全文の確認、よくあるハマりどころの確認に使った。
- `game-asset-search`: 外部素材だけでなく生成素材も含め、素材源の選択、ライセンス確認、共通スタイル prompt、`CREDITS.md` への記録方法を決めるために使った。今回、同 skill の素材検索スクリプトは使っていない。外部から取得した素材は Google Fonts 公式リポジトリのフォントだけである。
- `imagegen`: OpenAI の画像生成機能で、プレイヤー、敵、攻撃、タイトルアートを作成し、問題のある透明背景画像を再生成・編集した。
- `webtunnel` と `agent-browser`: GitHub Actions runner 上の Web export を実 Chromium で開き、キーボード入力、マウス入力、画面遷移、スクリーンショット取得を行った。
- `pr-attach-screenshots`: 画像と動画を puts へアップロードし、PR に確認可能な証跡を掲載するために使った。
- `commit`: 変更を意味のある単位に分け、検証後にコミットするために使った。

### 主なツール

- Godot 4.7: import、headless 起動、selfcheck、スクリーンショット、Movie Maker、デスクトップ・Web export、通常ウィンドウ起動に使用した。
- `gdlint` / gdtoolkit: `make lint` と `make test` 経由で GDScript を検査した。
- Python 3: PNG の派生処理と、BGM・SE・環境音の PCM 波形生成に使用した。
- Pillow、ImageMagick、rsvg: alpha、画像寸法、縮小、montage、contact sheet、SVG からの変換を確認するために使用した。
- `ffmpeg` / `ffprobe`: Movie Maker の AVI を MP4 に変換し、音量、音声トラック、長さ、末尾フレーム、contact sheet を検査した。
- `puts`: PR 用のスクリーンショットと動画を公開 URL へ置いた。
- `curl` / `shasum`: puts に置いたファイルを取得し、ローカルとリモートの SHA-256 が一致することを確認した。
- `git` / `gh`: 差分、コミット、draft PR、CI check、artifact の取得、PR 本文の更新に使用した。
- `make`: 個別コマンドを再現可能な検証 target としてまとめて実行した。

### 実際に使った代表コマンド

```bash
make test GAMES=survivors
make screenshot GAMES=survivors
make movie GAMES=survivors
make -C games/survivors movie-play
make -C games/survivors audiocheck
make -C games/survivors benchmark
make -C games/survivors playthrough
make build-all GAMES=survivors
make build-web GAMES=survivors
SURVIVORS_RUN_CAPTURE=1 make survivors-run
make -C games/survivors runcheck
make import GAMES=survivors
```

ほかに、`ffmpeg` で動画の変換・音量測定・フレーム抽出を行い、ImageMagick で変更前後と別ゲームの比較画像、各アニメーションの contact sheet を作成した。webtunnel では `fix/survivors` を `--ref` に指定し、software WebGL の Chromium セッションへ明示的に接続した。

## 3. 欲しかったが無かったツール・skill・スクリプト

- 画像生成の一括管理ツールが欲しかった。同じスタイル prompt を複数ファイルへ適用し、ファイル名、再試行、生成時 prompt、結果、alpha、偽の市松背景、縮小サムネイル、contact sheet を一つの manifest で管理できれば、9点を個別に生成・確認する手作業を減らせた。
- 1枚のキャラクター画像から Godot 用の擬似ポーズアニメーションを作るテンプレートが欲しかった。位置、傾き、拡縮、色、alpha の定型パターンと、各状態の contact sheet、回帰検査まで生成できると、今回の5状態×6フレームをゲーム固有コードで組む量を減らせた。生成 AI に完全なポーズシートを作らせる場合も、フレーム間の一貫性を機械的に評価できる仕組みが欲しかった。
- `screenshot.gd` の宣言的な撮影ヘルパーが欲しかった。「シーン名、ゲーム状態、待機フレーム、撮影名、入力」を列挙すると、遷移、チュートリアル、アップグレード、ボス、クリア、アニメーションを順に撮れる形である。現状はゲームごとに状態遷移用コードを書く必要がある。
- Godot 音声ライフサイクルの共通検証 harness が欲しかった。Dummy、Movie Maker、CoreAudio を切り替え、BGM・SE・環境音の開始、loop、停止、`stream` 解放、終了時 leak、動画内 loudness を同じ仕組みで検証できれば、今回追加した環境変数と `audiocheck` の個別配線を減らせた。
- webtunnel 用の Godot 入力ヘルパーが欲しかった。1280×720 のゲーム座標を、1280×656 の Chromium viewport 内の letterbox 付き canvas 座標へ変換し、CDP のキー入力・クリック・スクリーンショットを安定して送れるものがあるとよい。今回 `agent-browser` の一部操作が30秒で timeout したため、直接 CDP の WebSocket を使う場面があった。
- PR 証跡用 manifest が欲しかった。ゲーム名、ローカルパス、サイズ、SHA-256、アップロード先 URL を結び、別ゲームの成果物が混ざっていないことをアップロード前後に検査できれば、誤った動画 URL の掲載を防げた。
- CI artifact downloader に進捗、再開、対象ファイルだけを取得する機能が欲しかった。大きな録画を無表示で待つか中断するかの判断を減らせる。

このうち、画像生成の一括管理、Godot の宣言的スクリーンショット撮影、音声ライフサイクル検証、webtunnel の座標・入力補助は、次のゲームでも再利用できるため skill または共有スクリプトにする価値が高い。

## 4. 素材の準備方法と、素材源・生成手段ごとの使い勝手

### 画像

プレイヤー1点、敵4点、攻撃3点、タイトルアート1点は OpenAI の画像生成機能で作った。黒に近い宇宙色、cyan と magenta の glow、太い silhouette、小さく表示しても識別できる形、という共通条件を prompt に入れた。

画像生成は、ゲーム全体の固有テーマを短時間で揃える用途には非常に使いやすかった。特に、既存作品の名称・ロゴ・画像を使わずに、プレイヤーと敵の印象をまとめて変えられた。一方で、透明背景の正確さと、複数フレームで同じ造形を維持する能力は信用せず、機械検査と目視が必要だった。偽の市松背景は2点で発生した。アニメーションは完成したポーズシートを生成せず、1枚絵と Godot 側の変形を組み合わせる方が一貫性と実行時負荷を管理しやすかった。

背景の無限グリッド、縞模様の太陽、VHS 効果、UI の図形はコードと shader で描いた。画面サイズやゲーム状態に追従し、追加ライセンスも不要なので、規則的・幾何学的な素材は画像ファイルより扱いやすかった。

### BGM・SE

既存の4曲と9種類の効果音について、用途と呼び出し箇所は保ち、Python で PCM を生成する内容を作り直した。square wave の pluck、FM lead、detune した pad などを組み合わせ、16秒の環境音も追加した。

手続き生成は、著作権とファイル出所が明確で、ゲーム状態に必要な音を漏れなく揃えやすい。生成スクリプトから何度でも同じ素材を作れる点もよかった。一方、人間が制作した楽曲ほどの展開や自然な mix を得るには調整工数が掛かる。波形が生成できたことと聴感がよいことは別なので、動画内の音量測定に加え、CoreAudio での実再生確認が必要だった。

### フォント

フォントだけは Google Fonts の公式リポジトリから RocknRoll One Regular を取得した。取得元、著作権表示、OFL-1.1 を `assets/CREDITS.md` と `assets/fonts/OFL.txt` に記録した。ダウンロード後は checksum と参照先を確認し、旧 `font.ttf` の参照を外した。全4 export preset では旧フォントを除外し、使用中のフォント、credits、ライセンスは含めた。

公式配布元から取得できるフォントは、品質、文字集合、ライセンス表記を確認しやすかった。一方、Theme に設定するだけでは CanvasItem の `draw_string()` へ自動適用されないため、描画コード側でも font resource を明示する必要があった。

### 素材源全体の所感

- 画像生成は固有の見た目を短時間で作るのに向くが、alpha と連続フレームの一貫性は検査が必要だった。
- コード描画は幾何学的な背景・UI・effect に向き、解像度対応と再利用性が高かった。
- Python による音声生成は出所と再現性に優れるが、聴感の品質保証は別途必要だった。
- Google Fonts 公式配布は品質とライセンスの確認が容易だったが、Godot 内の全描画経路に適用されたかは実画面で確認する必要があった。
- すべての生成物と外部素材を `assets/CREDITS.md` にまとめたため、後から由来を追える状態にできた。

## 5. 動作確認の方法

### headless の自動検証

`make test GAMES=survivors` を実行し、lint、起動確認、入力検証、visual 検証、selfcheck をすべて exit 0 で通した。ログは末尾だけでなく全文を WARNING / ERROR で検索した。import 自体が exit 0 でも diagnostic がログに残る可能性があるため、終了コードだけでは成功と判定しなかった。

selfcheck では、ゲーム進行、攻撃、敵、アップグレード、演出上限、遠方座標、音声の状態など、画面を見なくても確定できるロジックを検査した。入力検証では実際の `InputEvent` を送り、キーボード、合成 gamepad、マウス、fullscreen、マウス hover 後の Enter 決定を確認した。物理 gamepad は使用していないため、実デバイス固有の接続・ボタン配置・振動は未検証である。

### `screenshot.gd` とアニメーション

`make screenshot GAMES=survivors` で28枚を生成した。タイトル、画面遷移、チュートリアル3段階、無限グリッド、通常プレイ、複数 effect、アップグレードと選択 highlight、ポーズ、リザルト、ボス、クリアに加え、5種類の actor の motion sheet を撮影し、すべて目視した。

アニメーションは、単一フレームのスクリーンショットだけでは確認せず、idle、move、attack、hurt、death の各6フレームを横に並べた contact sheet と movie の連続フレームを併用した。これにより、造形の一貫性、動きの方向、alpha の消え方、1枚絵のまま静止して見えないかを確認した。ただし、実際の人間が初見で各動作を正しく読み取れるかというユーザーテストは行っていない。

### movie と音声

通常の `make movie GAMES=survivors` では5秒、150フレームを記録した。平均音量は -28.2 dB、タイトルの平均輝度は27.2で、黒画面検出の閾値20を上回った。

`make -C games/survivors movie-play` では26.067秒の自動進行を録画し、タイトル、チュートリアル、通常プレイ、アップグレード、ボス、クリア、タイトル復帰を確認した。平均音量は -27.7 dB だった。動画全体の contact sheet と末尾フレームを目視し、開始時だけでなく終了時にも正常な画面へ戻ることを確認した。

CoreAudio を使う `audiocheck` では、全BGM、全SE、環境音、loop、停止、終了時の resource 解放を確認した。音が存在すること、音量が極端でないこと、終了時に leak しないことは確認できたが、音楽としての好みや長時間聴いた際の疲れに関する第三者評価は行っていない。

### 負荷、長時間進行、export、実起動

- benchmark は M4 Max で10.001秒、952フレーム、平均95.19 fps、p95 frame time 15.555 ms だった。敵は336〜360体、画面内は最小307体だった。
- playthrough はゲーム内600秒まで進め、level 91、kills 5809、HP 100、最大223体、実時間16.13秒で完了した。
- macOS、Windows、Linux、Web の export と Web build はすべて exit 0 で完了した。
- `SURVIVORS_RUN_CAPTURE=1 make survivors-run` と `runcheck` で、エディタなしの実ウィンドウ起動、画面表示、終了時 leak がないことを確認した。

### CI artifact

最終 CI run `34109457806` は全 job が成功した。`survivors-screenshot-and-movie` artifact をダウンロードし、28枚の PNG の contact sheet と movie の末尾フレームを目視した。Xvfb と llvmpipe では想定済みの VSync warning だけがあり、ゲーム由来の WARNING、ERROR、resource leak はなかった。

VHS shader の時間依存 grain により、同じ画面でも PNG の byte hash は実行ごとに変わる。したがって再現性を byte 一致だけで判定せず、構造的な検査と目視を組み合わせた。

### webtunnel

CI run `34104330103` で `fix/survivors` の Web export を software WebGL の実 Chromium へ配信した。タイトル、3段階チュートリアル、斜め移動、gem 回収、level 2 のアップグレード、pause/resume、連続したアップグレード、通常の敗北、1分24秒・level 7・kills 132 のリザルト、タイトル復帰まで操作した。各段階のスクリーンショットも目視し、runner は確認後に停止した。

webtunnel は headless の selfcheck では分からない canvas 描画、WebGL、キーボードとマウス、画面遷移の統合確認に効いた。一方、Chromium viewport が1280×656でゲームの1280×720と一致せず letterbox が入るため、ゲーム座標をそのままクリック座標に使えなかった。また、Web 版の確認なので、デスクトップ固有の fullscreen や物理 gamepad の検証は代替できない。

## 6. Godot 固有のハマりどころと回避策

- `import` の終了コードが0でも、resource import や parser の diagnostic がログに出ることがある。`tmp/import.log` を含むログ全文を WARNING / ERROR で検査する。
- headless の Dummy audio driver は、通常の音声再生、Movie Maker の音声記録、CoreAudio の実再生と条件が違う。通常 headless、Movie Maker、実 audio の検証を分け、どの driver を確認したかを明示する。
- `--quit-after` は GDScript の通常引数として利用できない。ゲーム内で終了時処理が必要なら、環境変数など別の明示的な経路で予定フレーム数を共有する。
- `AudioStreamPlayer.stop()` だけでは終了直後に stream resource が保持されたように見える場合がある。再入可能な停止処理で `stop()` と `stream = null` を行い、mixer が解放を反映するフレームも確保する。
- Control の Theme に font を設定しても、CanvasItem の `draw_string()` には適用されない。コード描画には対象 `Font` を明示して渡し、旧フォント参照が残っていないか検索する。
- Button の hover、keyboard focus、押下対象は自動では同じ状態にならない。hover で focus を同期し、focus change を見た目へ反映して、マウスからキーボードへ切り替える入力列をテストする。
- shader の `smoothstep(edge0, edge1, x)` は `edge0 < edge1` を守る。逆順に依存した反転表現は環境差の原因になるため、正しい順序の結果を明示的に反転する。
- GL Compatibility、software WebGL、Metal では見え方や許容される shader の書き方が異なる。ローカル画像だけで完了にせず、CI の llvmpipe artifact と実 Chromium の WebGL も確認する。
- Movie Maker の画像と音声はリアルタイム実行と終了タイミングが異なる。最終フレームで audio を解放し、MP4 の duration、audio stream、末尾フレームまで検査する。
- `Vector2` など浮動小数点を遠方座標で完全一致させる selfcheck は不安定になる。ゲームの許容精度に合った誤差を使う。
- 多数の actor にアニメーション用画像を複製すると VRAM と import 数が増える。1体1枚の `Texture2D` を共有し、transform と modulate で動きを出して、最大出現数で benchmark する。
- 全画面 shader に時間依存 noise があるとスクリーンショットの hash は毎回変わる。画像全体の hash を唯一の回帰判定にせず、固定状態の構造検査、輝度、代表フレーム、目視を組み合わせる。
- export preset ごとに resource の include/exclude が異なると、エディタでは表示できても配布物で欠ける。macOS、Windows、Linux、Web の全 preset を build し、使用中フォント、credits、ライセンスが含まれ、旧素材が除外されることを確認する。
- headless screenshot は状態とレイアウトの網羅に強いが、実際の描画 backend、入力の体感、音の聴感は保証しない。selfcheck、screenshot、movie、CoreAudio、実ウィンドウ、CI artifact、実 Chromium を役割別に組み合わせる。

今回特に有効だった回避策は、「終了コードだけでなくログ全文を見る」「1種類の headless 検証だけで完成としない」「生成素材は prompt を信用せず alpha と縮小表示を確認する」「Godot の自動状態同期を仮定せず、hover・focus・audio・終了処理を入力列とライフサイクルとしてテストする」の4点だった。
