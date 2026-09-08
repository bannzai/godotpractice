# deckrogue 手直しラウンドの開発ヒアリング

## 1. 開発の進め方

### 調査と基準作り

1. `AGENTS.md`、`documents/PROJECT.md`、issue #6、前回の PR #29、`documents/knowledge/deckrogue.md`、3 回分のヒアリングを読み、維持するゲーム仕様と今回だけ変える見た目を分離した。
2. 変更前のゲームを起動して、タイトル、地図、戦闘を実際に操作した。上端の HUD、横一列の箱型地図、下端の共通操作ガイド、暗色パネルが他ゲームと似ていることを確認し、変更前画像を保存した。
3. 調査を並行できる部分は、既存ゲームの監査、過去の要件整理、Public Domain 素材候補の探索に分けた。自分はその間にコード構造、受け入れ条件、検証 target を確認した。
4. 最初に New Tegomin と OFL を入れ、禁止された旧フォントが残らない状態を作った。早い段階で Draft PR を作り、以後の実装と証拠を同じ PR に積み上げた。

### 素材と画面の実装

1. 城と川、騎士と竜、彩色飾り文字、森、動物誌の竜、塔の 6 原画を決めた。作品ページ、所蔵館、作者、年代、権利表示を確認し、原画像は gitignore 済みの `games/deckrogue/tmp/pd-sources/` に置いた。
2. `scripts/dev/process_pd_art.py` を作り、正規化座標によるクロップ、縮小、オートコントラスト、羊皮紙色へのデュオトーン、額縁、キャラクターシート化を決定的に行えるようにした。加工済みの背景、地図、人物、カード、経路、遺物、アイコン、エフェクトだけを `assets/art/` に置いた。
3. 古い手続き SVG を新しい PNG へ置き換えた。7 キャラクターには別々の原画クロップを割り当て、待機・移動・攻撃・被弾・死亡の 5 行×6 コマのシートを作った。
4. `ui.gd` で木の机に開いた羊皮紙の見開きを共通骨格として作り、`main.gd` のタイトル、地図、戦闘、報酬、休息、イベント、結果、カード帳、地図モーダルをその頁として組み直した。
5. 地図を版画上の分岐路へ変え、選択済みの道を朱、選べる枝を金で描いた。フォーカスとホバーで右頁の予告を更新し、決定前に行き先の種類と結果が分かるようにした。
6. 戦闘では敵の次の一手、使える墨、手札、ターン終了の優先順位を作り直した。使えないカードを灰色にするだけでなく、「墨が何点足りないか」を不透明な紙片上へ直接表示した。
7. 初回だけ、地図の読み方、行き先の選び方、敵の意図、カードとターン終了を 4 段階の欄外注で説明した。各段階からスキップでき、同じ実行中の 2 回目以降には出ない状態を UI 側で保持した。
8. 既存の場面別 BGM と SE を保ち、風、焚火、紙の環境音と、頁、羽根ペンの操作音を追加した。画面遷移と終了時に古い再生ノードと stream 参照が残らないよう整理した。

### 詰まった点と解決

- 原画の白背景を透過すると線画の輪郭に白い縁が残った。無理に切り抜かず、古書から切り取った矩形の版画札として見せることで、加工を減らしながら紙質も残した。
- 異なる所蔵館の画像は色味と線密度が揃わなかった。彩色写本だけは色を残し、それ以外を少数の墨色と羊皮紙色へデュオトーン化し、同じ細い額縁を付けて一冊にまとめた。
- 地図の開始直後は完了経路が 1 点しかなく、`Line2D` に 1 点を渡しても線にならなかった。完了経路は 2 点以上の時だけ設定し、次候補への線は候補ごとの 2 点線として作った。
- 画面を破棄して次画面を作った直後に撮影すると、旧画面とフェード中の新画面が重なった。代表画像は 0.32 秒の Tween 完了後まで待ち、演出途中の画像とはファイル名と撮影時点を分けた。
- 使用不可理由を版画の上へ直接描いた最初の版は文字が埋もれた。赤枠付きの不透明な紙片に変更し、一覧画像でも理由を読めるようにした。
- `webtunnel` の一般例は `localhost:8080` だったが、このリポジトリの caller workflow は `port: "8000"` だった。最初の接続拒否後に `.github/workflows/browser-session.yml` を確認し、`http://localhost:8000/index.html` へ直した。
- sandbox 内の Tailscale 事前確認は CLI が Abort した。ホスト側で同じ preflight を再実行すると READY になり、その後は通常どおり接続できた。
- PR の知見文書を変更すると CI が全ゲームを対象にし、無関係な citybuilder の撮影 job が一度失敗した。失敗ログを確認して deckrogue 起因でないことを確かめ、失敗 job だけ再実行して全体を success にした。
- macOS でバイナリを直接起動した Godot は AppleScript の application process として取得できず、ウィンドウの終了操作を送れなかった。対象 PID へ `SIGINT` を送り、Godot と `make deckrogue-run` が exit 0 で終了することを確認した。`SIGTERM` は make 側が exit 2 になったため採用しなかった。

## 2. 使ったツール・skill・コマンド

### skill

- `godot-development`: Godot 4.7 の起動、import、headless 検証、描画付き撮影、export、ログ検査の前提確認に使った。
- `game-asset-search`: Public Domain / CC0 素材の探し方、作品ページと権利表示の確認、原画と派生物のクレジット記録に使った。
- `webtunnel`: GitHub Actions の Linux runner 上で Web export と Chromium を起動し、Tailscale 経由で操作・撮影・録画した。
- `agent-browser`: 名前付きセッション `deckrogue` でリモート Chromium に接続し、キー入力、待機、DOM 評価、スクリーンショット、console / error 確認を行った。
- `commit`: 差分、秘密情報、電話番号を点検し、段階ごとにコミットと push を行った。
- `gh-r2-image` の現在の推奨経路である `puts`: 比較画像、連続フレーム、webtunnel の画面をアップロードし、PR body に埋め込んだ。

### 実際に使った主なコマンドと用途

```sh
# コード、素材、規約、ログの探索
rg ...
git diff --check
git status --short --branch

# Godot の基本検証
make import GAMES=deckrogue
make test GAMES=deckrogue
make screenshot GAMES=deckrogue
make movie GAMES=deckrogue
make -C games/deckrogue movie-play
make build-all GAMES=deckrogue
make build-web GAMES=deckrogue
make deckrogue-run

# 素材の再生成
python3 games/deckrogue/scripts/dev/process_pd_art.py
python3 games/deckrogue/scripts/dev/generate_audio.py

# 静止画と動画の点検
magick montage ...
identify ...
ffprobe ...
ffmpeg -sseof -1 -i ... -frames:v 1 ...

# Web 実操作
bash ~/.agents/skills/webtunnel/scripts/preflight.sh bannzai/godotpractice
WEBTUNNEL_REPO=bannzai/godotpractice bash ~/.agents/skills/webtunnel/scripts/webtunnel-cli.sh up deckrogue --software-webgl --ref fix/deckrogue --wait
bash ~/.agents/skills/webtunnel/scripts/webtunnel-cli.sh cdp deckrogue
agent-browser --session deckrogue --cdp http://<tailscale-ip>:9222 ...
WEBTUNNEL_REPO=bannzai/godotpractice bash ~/.agents/skills/webtunnel/scripts/webtunnel-cli.sh down deckrogue
WEBTUNNEL_REPO=bannzai/godotpractice bash ~/.agents/skills/webtunnel/scripts/fetch-recording.sh deckrogue ...

# GitHub と証拠画像
gh issue view 6 -R bannzai/godotpractice
gh pr view 29 -R bannzai/godotpractice
gh run view ...
gh run download ... -n deckrogue-screenshot-and-movie ...
gh run rerun ... --failed
puts upload <画像パス>
gh pr edit 70 -R bannzai/godotpractice --body-file ...
gh pr ready 70 -R bannzai/godotpractice
```

- `gdlint` は直接ではなく `make lint` / `make test` の内部で `games/deckrogue/scripts/` に対して実行した。
- Pillow は `process_pd_art.py` の画像加工に使った。ImageMagick は変更前後、他ゲームとの識別比較、全スクリーンショット、連続フレームの contact sheet 作成に使った。
- `ffmpeg` / `ffprobe` は mp4 化、解像度・fps・長さの確認、一定間隔フレームと終端フレームの抽出に使った。
- GitHub CLI は issue / PR / CI の読み取りだけでなく、Draft PR の作成・更新、push 後のチェック確認、artifact 取得、ready 化にも使った。

## 3. 欲しかったが無かったツール・skill・スクリプト

### Public Domain 素材の加工パイプライン

原画 URL、作品ページ URL、作者、年代、ライセンス、クロップ矩形、出力用途を 1 つの manifest に書くと、次をまとめて行うツールが欲しかった。

- 原画と小さいプレビューの取得
- Open Access / Public Domain 表示の保存
- 正規化クロップ、デュオトーン、額縁、シート化
- 全派生ファイルと `CREDITS.md` の対応漏れ検査
- 元画像を commit せず、加工済みファイルだけを出力する確認
- 同じ入力から同じバイト列が再生成されるかの検査

今回の `process_pd_art.py` は加工部分を解決したが、権利情報の収集と CREDITS の対応付けは手作業が残った。`game-asset-search` に manifest と加工スクリプトの雛形があると再利用しやすい。

### Godot スクリーンショット監査

`screenshot.gd` の撮影 manifest を読み、次を 1 コマンドで行う仕組みが欲しかった。

- 必須画面、チュートリアル段階、フォーカス、ホバー、使用不可理由、モーダル背面の撮り漏れ検査
- 同じ画面の重複、真っ黒、遷移途中の重なり、文字の画面外はみ出しの検出
- 全画像の日本語ラベル付き contact sheet 作成
- キャラクター×動作×時点の組み合わせ漏れ検査
- 変更前後と他ゲームの比較画像作成

現在は Godot 側で 46 枚を書き出し、ImageMagick で一覧化して目視したため、ファイル選択とラベル付けに手作業が残った。

### Web export の操作ドライバ

`webtunnel` の起動、caller workflow からのポート取得、Godot の `#status` 消失待ち、canvas の座標変換、画面撮影、console / error 取得、`down`、録画取得までを一つの Godot 向けコマンドにしたかった。今回はポート 8080 と 8000 の違いを手作業で調べ、各キー入力と待機を個別に実行した。

### CI の変更ゲーム判定

`documents/knowledge/deckrogue.md` だけの変更を deckrogue に対応付ける判定が欲しかった。今回はゲーム固有の知見追記で全ゲーム matrix が走り、無関係な一時失敗の調査と再実行が必要になった。

### 音の検証

PCM 形式、ピーク、無音、ループ境界、再生成一致は自動検査できたが、音色が中世写本の雰囲気として成立しているか、BGM・環境音・SE の音量関係が自然かは聴覚評価できなかった。ラウドネス、帯域、クリックノイズ、ループ境界の波形差をまとめて可視化するスクリプトがあると、主観評価前の不具合をさらに減らせる。

## 4. 素材の準備方法と使い勝手

### 画像

使った素材源は次の 6 系統だった。

- Rijksmuseum 由来の城と川の銅版画: CC0。地図、紙地、カードへ複数の有効なクロップを取れた。線が大きく、高解像度で加工しやすかった。
- National Gallery of Art 由来の Albrecht Dürer の騎士と竜: CC0 Open Access。タイトル、主人公、敵、カード、経路アイコンまで展開でき、ゲームの顔を作るのに最も効いた。
- The Metropolitan Museum of Art 由来の彩色飾り文字: CC0 Open Access。ロゴ、飾り、人物、鳥獣へ使えた。色を残すことで墨一色の画面に焦点を作れた。
- Gustave Doré の森: Public Domain。線密度が高く、戦闘背景と霊的な敵に向いた。縮小後につぶれないクロップ選びが必要だった。
- Aberdeen Bestiary の竜: Public Domain。ボスと遺物に強い個性を出せた。彩色原稿なので、通常のデュオトーンとは別の調整が必要だった。
- British Library Flickr Commons の塔: 1844 年刊、No known copyright restrictions。塔の輪郭が明快で強敵や防御系カードに使いやすかった。一方、この表示は CC0 の許諾文ではないため、年代と関係作者も別途確認する手間が大きかった。

所蔵館の Open Access ページや Wikimedia Commons は、作品情報とライセンス根拠を追いやすいものが使いやすかった。Flickr Commons は原画像の取得は容易だが、「No known copyright restrictions」をそのまま CC0 と扱えない点が面倒だった。固有の書名、文字、紋章、ロゴが大きく入る候補は、権利が問題なくてもゲームへ不要な固有性を持ち込むため外した。

原画像は `tmp/pd-sources/` に保存し、`process_pd_art.py` で 58 個のゲーム用 PNG に加工した。正規化座標でクロップ位置を持つため、元画像の解像度が変わらなければ再現できる。オートコントラスト、デュオトーン、額縁を共通化したことで、異なる作品を同じ本の頁として扱えた。

手続き SVG は小さく、色や部位をコードだけで修正しやすい。一方、複数ゲームで同じ作り方をすると形、余白、輪郭が似やすく、古書固有の線密度や偶然性を出しにくかった。Public Domain 画像は探索と権利確認に時間がかかるが、少数の原画でも「どの時代・媒体の画面か」が即座に伝わった。

### フォント

Google Fonts の New Tegomin Regular を使い、OFL-1.1 本文を `assets/fonts/OFL.txt` に同梱した。Google Fonts は作者、ライセンス、配布ファイルを一式で取得しやすく、導入は画像素材より単純だった。日本語本文、見出し、ボタンを一つの書体で賄え、中世写本そのものではないが、手書きの揺れが版画と調和した。

### BGM・環境音・SE

第三者の録音・楽譜は使わず、`scripts/dev/generate_audio.py` を Python 標準ライブラリだけで実行し、固定 seed で生成した。16 bit stereo PCM / 22050 Hz で、6 場面の 8 小節ループ、風・焚火・紙の環境音 3 点、効果音 9 点、合計 18 ファイルを用意した。

コード生成音は権利関係と再生成性が明確で、場面数や長さ、左右定位、倍音、ノイズ量を一括で変えやすかった。反面、実録音の質感や演奏の揺らぎは出しにくく、最終的な音量バランスと世界観の評価には人間の試聴が必要になる。今回は形式、ピーク、クリップ、ループ境界、再生成一致、場面への割り当てを機械検証したが、主観的な試聴は行っていない。

### 小さな独自画像

金箔と朱インクの発光・火花は、外部の画像生成サービスを使わず Pillow の楕円、線、ぼかしで決定的に生成した。用途が小さく抽象的なエフェクトなので、Public Domain 素材を探すより速く、他作品の意匠も持ち込まなかった。

## 5. 動作確認の方法

### headless の selfcheck

`make test GAMES=deckrogue` で lint、import、起動検証、selfcheck をまとめて実行した。selfcheck では従来のゲームロジックと入力経路に加え、次を検査した。

- 7 枚のキャラクターシートが 1536×1600 であること
- 1 コマが 256×320、5 動作×6 コマを持つこと
- 各動作に 3 種類以上の異なる画像があること
- `assets/art/` に旧 SVG が残っていないこと
- 画面遷移、カード、敵、報酬など既存の受け入れ条件が壊れていないこと

headless は状態遷移、配列境界、リソースの存在、決定的なデータ検査には速く効いた。一方、文字の重なり、コントラスト、余白、画像の意味、Tween の途中状態は判断できない。

### `screenshot.gd`

描画付きの `make screenshot GAMES=deckrogue` で 46 PNG を生成した。タイトル、地図、戦闘、報酬、休息、イベント、勝利、敗北、カード帳に加え、4 段階のチュートリアル、フォーカス、ホバー、使用不可理由、大量手札、スクロール、各エフェクトを撮った。

アニメーションは 7 キャラクターそれぞれについて、待機・移動・攻撃・被弾・死亡の開始、途中、終了の 3 時点を撮影した。15 枚のスクリーンショットに各キャラクターを横並びにし、5 動作×3 時点の contact sheet で、人物ごとの絵の違いと動きの方向を一度に確認した。静止画を 1 枚だけ見るより、攻撃の傾き、被弾の色、死亡の回転と透明化を比較しやすかった。

この方法は全状態を同じ解像度で再撮影でき、PR の証拠にも使いやすかった。ただしフレーム間の速度、引っ掛かり、音との同期は静止画だけでは分からない。

### `movie` と `movie-play`

- `make movie GAMES=deckrogue` は操作なしで 5 秒録画し、起動直後が黒画面でないこと、表紙が安定して描画されることを確認した。
- `make -C games/deckrogue movie-play` は、チュートリアルのスキップ、地図の決定、カード 2 枚の使用、10 回のターン終了、敗北、表紙への復帰まで約 30 秒の実入力を通した。
- `ffmpeg` で一定間隔のフレームと終端フレームを抽出し、contact sheet にして画面の連続性を確認した。

`movie-play` は、単独の状態撮影では見つけにくいフォーカスの遷移、入力が busy 中に無視される時間、画面遷移後の操作復帰、終了経路の問題に効いた。物理ゲームパッド固有の入力、手で遊んだ時のテンポ、音の主観評価は含められなかった。

### CI artifact

最新コミットの CI で deckrogue の lint、起動/selfcheck、macOS・Windows・Linux・Web export、Xvfb + llvmpipe 上の screenshot / movie が成功した。`deckrogue-screenshot-and-movie` artifact をダウンロードし、46 PNG 全件の contact sheet、動画の毎秒フレーム、終端フレーム、`screenshot.log`、`movie.log` の全文を確認した。

CI はローカル macOS とは別の Linux 描画経路と、クリーンな import / export を確認できた点が効いた。Xvfb の `Could not set V-Sync mode` は workflow が許可している既知の警告で、それ以外の WARNING / ERROR / リーク警告はなかった。Windows と Linux は export 成功までで、実 OS 上での起動操作はしていない。

### webtunnel

`--software-webgl` を付けて GitHub Actions 上の Chromium を起動した。DOM で `#status` が消えたこと、notice が空であること、WebGL2 が有効なこと、canvas の境界を確認してから操作した。

実際に表紙から開始し、初回案内をスキップし、地図の戦闘を選び、カードを 2 枚使い、墨不足の表示を確認し、10 回ターンを終了して敗北結果まで到達した。タイトル、案内、地図、カード使用後、結果を撮影した。`agent-browser errors` は空で、console は Godot 4.7、WebGL2、Emscripten、`deckrogue boot` の起動ログだけだった。終了後は `down` し、録画 artifact も取得した。

webtunnel は Web export を本物のブラウザ入力で確認でき、操作過程の録画を公開 artifact として残せた点が有効だった。SwiftShader のため性能評価には使えず、1280×656 のブラウザ viewport と 1280×720 のゲーム座標の変換も必要だった。今回はキー入力を中心にして座標依存を減らした。

### 最終的に足りなかった確認

- 物理ゲームパッドでの実入力
- Windows / Linux 実機での起動と入力
- 人間の耳による BGM、環境音、SE の音量・音色評価
- アニメーションの美的な速度感を人間が長時間プレイして評価すること

ロジック、InputMap、export、Linux 描画、Web 入力、静止フレームと録画は確認できたため、未確認部分は実機・感覚評価に限定できた。

## 6. Godot 固有のハマりどころと回避策

### `Line2D` の点数境界

`Line2D.points` に 0 点または 1 点を渡しても線は描かれない。地図の開始地点のように履歴が 1 点だけの状態を通常経路として扱い、2 点以上の時だけ完了経路を設定する。次候補の予告線は候補ごとに 2 点の `Line2D` を作ると単純になる。

### 画面差し替えと Tween 中の撮影

`queue_free()` した Control は即座には消えず、同じフレームで新画面を作ると短時間共存する。さらに新画面へフェードや位置 Tween を掛けると、自動撮影が正常な遷移途中を不具合として記録しやすい。代表画面は Tween の所要時間より後まで待ち、演出途中を確認する画像は別名で意図的に撮る。

### 外部画像と文字のコントラスト

高密度な版画を `TextureRect` で全面表示すると、Theme の文字色だけでは本文と操作対象が埋もれる。紙地画像は低い不透明度で左右頁に敷き、本文、選択枠、道、使用不可理由は画像と独立した不透明な紙片・線・枠へ載せる。画像内の偶然の明暗を UI 状態色として使わない。

### 見た目を共有する Control の入力状態

カード帳と戦闘手札で同じカード表現を共有すると、読むだけのカードまで操作可能に見える。カード帳では `focus_mode` と `mouse_filter` を無効にし、戦闘手札だけをフォーカス対象にする。使用不可カードは単に disabled 色へ変えるだけでなく、理由をカード自身へ表示するとキーボード・ゲームパッドでも情報が欠けない。

### headless と描画検証の役割分担

headless はスクリプト、状態、リソースの検査には向くが、スクリーンショットの見た目は保証しない。ローカルでは OpenGL3 の描画付きプロセス、CI では Xvfb + llvmpipe、Web では Chromium + WebGL2 を別々に通す必要がある。Web の Chromium は `--software-webgl` がないと Godot の WebGL2 起動に失敗する。

### 新規 PNG の import

加工スクリプトが PNG を作っただけでは、Godot が import 済みとは限らない。素材追加後に `make import GAMES=deckrogue` を明示的に実行し、その後に check、selfcheck、screenshot を行う。原画は `tmp` に置き、Godot が読む派生 PNG だけを `assets/` に置くと、巨大な原画を export に混ぜずに済む。

### AudioStreamPlayer の終了時解放

場面ごとに BGM と複数の環境音を切り替えると、停止した `AudioStreamPlayer` が stream 参照を保持しやすい。切り替え時と終了時に stop するだけでなく stream を外し、終了要求では `Sound.shutdown()` を await してから tree を終了する。起動・録画・通常終了のログでリーク警告がないことまで確認する。

### 初回チュートリアルとゲーム状態の分離

説明の段階をゲーム進行データへ混ぜると、案内を閉じた時に地図や戦闘まで進んだり、再挑戦で不自然に戻ったりする。チュートリアルは UI セッション内の表示済みフラグと段階だけを持ち、実際の地図選択や戦闘状態を変更しない。地図で前半を終え、戦闘へ遷移した時に後半を出すことで、説明対象と画面を一致させた。

### macOS の通常起動プロセス

Makefile から Godot 実行ファイルを直接起動すると、macOS の Application Services から通常のアプリとして PID を引けない場合があった。自動検証で終了させる場合、`SIGTERM` は make を失敗扱いにしたが、`SIGINT` は Godot が正常に処理し、親の make も exit 0 になった。終了コードまで確認し、単にプロセスが消えたことを成功条件にしない。
