# platformer 手直しラウンドの開発ヒアリング

## 1. 開発の進め方

### 作業した順序

1. `AGENTS.md`、`documents/PROJECT.md`、issue #3、前回の PR #26、platformer の既存知見とヒアリングを読み、変更前のゲームを起動した。タイトルから直接ゲームへ入ること、上部の情報量が多い HUD、画面下の常設操作ガイド、淡色の手続き SVG が他ゲームと似て見えることを確認した。変更前のタイトル・プレイ画面も証拠用に保存した。
2. 「空を渡る配達人」を中心に、太い濃紺線、セル塗り、ハーフトーン、青緑・黄土・珊瑚・クリーム・紫という画風と配色を先に決めた。タイトル背景を最初に生成し、その画像を同一プロジェクト内の画風参照として、ワールドマップ、草原、洞窟、配達人、歩行敵、殻の敵を個別に生成した。
3. Mochiy Pop One を Google Fonts 公式配布物から取得し、公式ファイルとの SHA-256 照合と OFL の確認を行った。既存 BGM・SE の生成コードを保ちつつ、草原の風と遠いベル、洞窟の空気音と結晶音を `generate_polish_audio.py` に追加した。
4. 生成画像を Godot に組み込み、タイトル → 手描き地図 → ステージという導線へ変更した。地図には、選択中の旗、洞窟のロック理由、選択先の説明、草原クリア後の洞窟解放を実装した。プレイ中の HUD はコインと残機だけにし、移動・ジャンプ・ダッシュは初回だけ場面内の吹き出しで順に案内するようにした。取得、着地、踏みつけ、被弾、ゴールには短い擬音を追加した。
5. 配達人、歩行敵、殻の敵を `AtlasTexture` で切り出し、背景色の透明化と輪郭追加をシェーダで行った。全102フレームの非空・重複検査を `selfcheck.gd` に、実シェーダを通したフレーム一覧撮影を `screenshot.gd` に追加した。
6. ローカルで lint、import、起動、selfcheck、46画面の撮影、起動録画、2ステージ自動走破、macOS・Windows・Linux・Web のビルドを行った。変更前後と、actionadventure・fighter・monsterquest との識別比較画像を作り、画面構成まで別物になっていることを目視した。
7. draft PR #79 を作り、3コミットに分けて push した。Web エクスポートを webtunnel で実操作し、タイトルから草原クリア、洞窟解放、洞窟開始まで確認した。最後に CI の46枚の PNG と5秒の録画をダウンロードして目視し、PR 本文へ17点の証拠画像を添付して Ready for review にした。

### 詰まった点と解決方法

- 画像生成で「透過背景」を指定しても、市松模様が画像の RGB として焼き込まれた。透過だけを直す再編集でも安定しなかったため、キャラクターに使わない単色マゼンタ背景を指定して再生成し、実行時シェーダで背景色と補間後の暗いマゼンタを除去した。
- 最初の歩行敵シートは要求した6列ではなく5列で、攻撃末尾も煙だけだった。6列×5行、全30セルに主役、各セル内に余白、境界越え禁止、全ポーズを別にする条件を明記して再生成した。さらに selfcheck を「各動作6枚が異なること」へ戻し、一覧画像でも確認した。
- macOS の全画面撮影は、モード切替完了時間が一定でなく、解除直後に黒いフレームが保存されることがあった。`DisplayServer.window_get_mode()` を上限付きで待ち、入力を離す間隔と描画安定待ちを追加し、保存前に複数点の輝度を調べて黒画像なら失敗させた。
- 別 worktree の描画付き Godot が同時起動している時、全画面遷移や editor settings の保存が競合した。失敗ログと実プロセスを確認し、他作業のプロセスは終了せず、競合がない時間に撮影を再実行した。
- Web 版は `agent-browser press` を1回ずつ送ると通信待ちの間に敵へ当たり、移動を継続できなかった。Chrome DevTools Protocol の WebSocket を1本維持し、`Input.dispatchKeyEvent` の `rawKeyDown` と `keyUp` を時間制御する一時ドライバを作った。これで D・X・Space 相当の移動・ジャンプ・ダッシュを実入力として通し、草原の結果画面まで到達できた。
- 約60 MBの CI artifact は `gh run download` が遅く、99%付近で接続が切れた。途中の ZIP を作業ディレクトリへ退避し、GitHub API から短時間有効な署名 URL を取得して HTTP Range で続きから取得する一時スクリプトを作った。API のサイズ 59,538,948 bytesとの一致と `unzip -tq` の成功まで確認した。

## 2. 使ったツール・skill・コマンド

### skill とツール

| skill・ツール | 実際の用途 |
| --- | --- |
| `godot-development` | Godot 4.7 の起動、import、検証、export、ログ確認、既知の注意点を確認した |
| `game-asset-search` | 素材源の選び方、生成素材の採用手順、クレジットとライセンス記録の形式を確認した |
| built-in `image_gen` | タイトル、ワールドマップ、草原、洞窟、配達人、歩行敵、殻の敵を生成し、歩行敵を再編集した |
| `webtunnel` | GitHub Actions 上の Web エクスポートと Chromium を起動し、Tailscale 経由の CDP 接続を得た。終了時は `down platformer` を実行した |
| `agent-browser` | `platformer` 専用セッションでタイトル、地図、プレイ、結果を操作・撮影し、console と error が0件であることを確認した |
| `pr-attach-screenshots` | `puts` を使って証拠画像17点を一括アップロードし、PR の管理ブロックを更新して公開 URL のハッシュを検証した |
| ImageMagick | 変更前後、他ゲームとの識別比較、全 CI 画像、重要画面のコンタクトシートを作った |
| `ffmpeg` / `ffprobe` | ローカルと CI の録画情報を確認し、フレーム一覧と末尾フレームを抽出した |
| `gh` | issue・過去 PR の確認、draft PR の作成と更新、push 後の checks・run・artifact の確認、Ready 化に使った |

`puts` は最初に `puts ls --number 1` で利用可能性を確認し、最終的には `pr-attach-screenshots` のスクリプト経由で使った。

### 主に実行したコマンド

```sh
make platformer-run
make import GAMES=platformer
make lint GAMES=platformer
make check GAMES=platformer
make selfcheck GAMES=platformer
make test GAMES=platformer
make screenshot GAMES=platformer
make movie GAMES=platformer
make -C games/platformer movie-play
make build-all GAMES=platformer
make build-web GAMES=platformer
python3 games/platformer/scripts/dev/generate_polish_audio.py --check
git diff --check origin/main...HEAD
```

`make lint` の実体は `gdlint scripts/` である。素材差し替え後は `make import` を先に実行し、Godot の import 情報を更新してから他の検証へ進んだ。録画の確認には、次のように末尾を PNG 化する方法も使った。

```sh
ffmpeg -sseof -1 -i movie.mp4 -frames:v 1 movie-last.png
```

Web 実操作では、次の構成を使った。

```sh
WEBTUNNEL_REPO=bannzai/godotpractice bash ~/.agents/skills/webtunnel/scripts/webtunnel-cli.sh up platformer --software-webgl --ref fix/platformer --wait
bash ~/.agents/skills/webtunnel/scripts/webtunnel-cli.sh cdp platformer
agent-browser --session platformer --cdp http://<Tailscale IP>:9222 ...
WEBTUNNEL_REPO=bannzai/godotpractice bash ~/.agents/skills/webtunnel/scripts/webtunnel-cli.sh down platformer
```

## 3. 欲しかったが無かったツール・skill・スクリプト

- 画像生成したスプライトシートについて、要求した列×行、各セルの前景有無、境界越え、実アルファか焼き込み背景か、動作内の重複フレーム、足元位置を一括判定する検査スクリプトが欲しかった。今回は画像確認、selfcheck、フレーム一覧撮影を別々に作ったため、採用判定までの往復が多かった。
- Godot の撮影用プロセスを worktree 間で排他制御し、ウィンドウモードの遷移待ち、黒フレーム検出、期待 PNG 一覧、ログ全文検索まで共通で行う仕組みが欲しかった。特に macOS の全画面確認はゲームごとに同じ問題が起き得る。
- Web 版のアクションゲーム向けに、CDP の接続を維持してキーを指定時間押し続け、途中の状態を撮影できる入力ドライバが欲しかった。通常の `agent-browser` はメニュー操作には十分だが、各 CLI 呼び出しの待ち時間があるためリアルタイム移動には向かなかった。
- GitHub Actions artifact を標準で再開ダウンロードし、API 上のサイズと ZIP 整合性を照合するスクリプトが欲しかった。今回の一時スクリプトは他の約60 MB以上の撮影 artifact にもそのまま役立つ。
- 過去 PR から同じ役割の画面を取得し、ゲーム名と役割を付けた変更前後・識別比較画像を一括生成する仕組みが欲しかった。今回は比較対象ごとの画像選定、ダウンロード、配置、ラベル付けを手でつないだ。

## 4. 素材の準備方法と使い勝手

### 画像

- タイトル、ワールドマップ、草原、洞窟、配達人、歩行敵、殻の敵は built-in `image_gen` で生成した。第三者の作品名・画像・ロゴ・商標は入力せず、同じプロジェクトで生成したタイトルだけを画風参照にした。採用画像、生成手段、プロンプトの要点、加工内容、OpenAI 利用規約の URL を `assets/CREDITS.md` に記録した。生成物は CC0 とは扱っていない。
- 背景と地図は使い勝手が良かった。手続き SVG よりも筆致、雲の量感、遠近、浮島、風車、結晶洞窟の情報量を短時間で得られ、タイトル・地図・プレイ画面の識別性に直接効いた。
- キャラクターシートは、表情やシルエットには強いが、厳密な6列、セル境界、連続姿勢、透明背景の保証には弱かった。採用後も Atlas 切り出し、サイズ正規化、背景キー、輪郭シェーダ、重複検査、全フレーム目視が必要だった。特に歩行敵は再生成が必要だった。
- 前ラウンドでコード生成した地形、コイン、ブロック、ゴールなどの SVG は、衝突形状と寸法を正確に保てるため再利用した。背景・主役は画像生成、ゲームルールと密接な小物は手続き生成、と役割を分けるのが扱いやすかった。

### BGM・SE・環境音

- BGM と SE は外部録音やサンプルを使わず、`generate_polish_audio.py` が Python 標準ライブラリで 32 kHz / 16-bit ステレオ PCM を合成する構成を継続した。今回、草原の循環する風と遠いベル、洞窟の空気音と反響する結晶音を追加した。
- コード生成音は、ライセンスと再生成経路が明確で、ピーク・DC・ループ境界を `--check` で検査できる点が使いやすかった。一方で、音楽的な自然さや音色の豊かさは録音素材より作り込みが必要で、最終的な世界観の判断には実際にゲーム内で聴く確認が欠かせない。

### フォント

- Mochiy Pop One を Google Fonts 公式から取得し、公式配布物と SHA-256 を照合した。フォント固有の著作権表示と SIL Open Font License 1.1 の全文を `assets/fonts/OFL.txt` に保持した。前回の Noto Sans JP 本体と参照は削除した。
- 公式配布元と OFL が明確で、ライセンス確認は画像生成物より容易だった。太い見出しと擬音に合い、Theme を1か所差し替えるだけでも他ゲームとの印象差が大きかった。

## 5. 動作確認の方法

| 方法 | 今回確認できたこと | 効いた点・足りなかった点 |
| --- | --- | --- |
| headless の `selfcheck.gd` | 地図のロックと解放、チュートリアル状態、ステージ進行、全102フレームの非空、各動作6枚の非重複、2ステージのロジック | 高速で回帰を検出できた。見た目、文字切れ、背景抜き、入力の押下時間は確認できない |
| `screenshot.gd` | タイトル、地図3状態、チュートリアル3段階、草原、洞窟、結果、死亡、全擬音、全画面、リサイズ、全アニメーションなど46画面 | 決定的な状態を並べて目視でき、Button の状態別配色や黒画面も見つけられた。時間的な動きと実入力経路は別検証が必要だった |
| `make movie` | 起動からタイトルまでの5秒、真っ黒、ちらつき、起動直後の崩れがないこと | 起動健全性には有効だが、操作しないためゲームプレイは確認できない |
| `make -C games/platformer movie-play` | 地図を経由して草原と洞窟を完走し、最終結果へ到達する一連の描画 | 長い状態遷移と動くアニメーションを確認できた。開発用の自動操作なので、ブラウザの物理入力確認にはならない |
| CI artifact | Linux の Xvfb + llvmpipe で生成した46枚と5秒の録画 | macOS 以外でも同じ見た目が出ることを確認できた。artifact は目視するまで成功ログだけでは判断できず、今回は大容量ダウンロードの再開手段も必要だった。ログには llvmpipe の V-Sync 変更非対応という環境由来の警告だけが残った |
| webtunnel | Web 版でタイトル → 地図 → 草原、移動・ジャンプ・ダッシュ、結果、洞窟解放、洞窟開始 | 実ブラウザと実入力の確認に効いた。CLI を1操作ずつ呼ぶ方法はリアルタイムアクションに遅く、持続 CDP 接続による押下時間制御が必要だった |

アニメーションは一つの方法だけで合格にしなかった。`selfcheck.gd` で配達人42枚、歩行敵30枚、殻の敵30枚が空でなく、各動作の6枚が異なることを機械検査した。そのうえで `screenshot-animation-player.png`、`screenshot-animation-walker.png`、`screenshot-animation-shell.png` に、実際の `AtlasTexture`、背景キー、輪郭シェーダ、ゲーム内スケールを通した全フレームを並べた。最後に自動走破録画と Web 実操作で、静止一覧では分からない再生中の見え方も確認した。

## 6. Godot 固有のハマりどころと回避策

- `AtlasTexture` は元画像の列数が想定と違っても切り出し自体はできるため、誤った隣セルや空白を表示して初めて気づくことがある。元画像寸法だけでなく、各セルの前景、境界、足元、動作内の差分を検査し、実シェーダ経由の一覧画像を撮る。
- 画像生成の背景キーは完全一致だけでは足りない。テクスチャ補間でマゼンタが暗くなった縁が残るため、色距離に加えて「赤と青が緑より十分強い」という色相条件を使った。一方、既存の透過 SVG に同じ背景キーを有効にすると明るい地形や UI まで消えるので、素材ごとにキーの有効・無効を分ける。
- Godot の Theme は Button の `normal`、`hover`、`pressed`、`focus`、`disabled` で背景と文字色が別に継承される。地図ではフォーカスを移した時だけ非選択ボタンの文字が読めなくなる問題が出た。選択中だけでなく、ロック中、解放後、両方のフォーカス状態を撮影する。
- チュートリアルで入力を奪うと、説明どおりにキーを押しても Player が動かない。`_unhandled_input()` で現在の1操作を観測し、Player 側の通常入力は止めないようにした。成功した入力で次の吹き出しへ進め、別の決定入力でスキップできるようにする。
- 地図の解放、チュートリアル完了、残機などの進行状態は表示ノードごとに持たず `Session` に集約した。旗、ロック理由、プレビュー、初期フォーカスを同じ値から作ることで、表示と選択可否の食い違いを避けた。
- macOS の全画面切替は固定秒数の待機では安定しない。期待する `DisplayServer.window_get_mode()` を上限付きで観測し、モードが戻った後も描画安定を待つ。さらに保存前の画像を複数点サンプリングし、黒一色なら exit 0 にしない。
- PNG や WAV を差し替えた直後は、古い `.godot/imported` を前提に検証しない。`make import GAMES=platformer` を先に通し、生成された `.import` と実ゲーム表示を確認する。
- 複数 worktree で描画付き Godot を同時に動かすと、全画面、ウィンドウ配置、editor settings が競合し得る。他作業のプロセスを勝手に終了せず、ログとプロセスを確認して競合のない時間に再実行する。
- Web エクスポートの入力確認では、JavaScript の合成 `KeyboardEvent` は Godot の物理入力として扱われなかった。Chrome DevTools Protocol の `Input.dispatchKeyEvent` を使い、`rawKeyDown` と `keyUp` の間隔を制御すると、移動・ジャンプ・ダッシュをゲーム側へ渡せた。
- Linux CI の llvmpipe は V-Sync モード変更をサポートせず警告を出す。この警告を無条件に無視するのではなく、ログ全文を読み、発生箇所が graphics driver の V-Sync だけであること、ゲーム由来の WARNING / ERROR / leak がないことを区別した。
