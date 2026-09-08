# crewrts 手直しラウンドの振り返り

## 1. 開発の進め方

### 着手から実装まで

1. `AGENTS.md`、`documents/PROJECT.md`、issue #10、前ラウンドの PR #33、ヒアリング文書、`documents/knowledge/crewrts.md` を読み、既存の受け入れ条件と今回だけの方向性を分けて整理した。
2. 変更前のゲームを `make crewrts-run` で起動し、タイトルから直接プレイへ入る流れ、画面下の長い操作ガイド、四隅の整ったパネル、背景の情報量を実画面で確認した。変更前のタイトル・プレイ・結果・アニメーション等も PNG として退避した。
3. 先に見た目の核になる素材を用意した。Klee One、紙目、水彩のにじみ、島の絵地図、島の風・葉擦れ・鳥声を含む環境音を追加し、水彩テクスチャを使うトゥーンシェーダを作った。
4. 画面遷移をタイトル → 島の絵地図 → 初回3頁の操作ノート → プレイへ変更した。地図には選択可能な庭、選択できない丘と沼、その理由、選択後の結晶数・仲間数・体験内容を重ねた。
5. プレイ画面から共通操作ガイド行を除き、選択対象の金色リング、対象付近の必要人数、右下の「次の一手」、紙片状の目的・時間・隊列表示へ置き換えた。結果・一時停止も同じ探検ノートの表現へ揃えた。
6. `integration.gd`、`selfcheck.gd`、`screenshot.gd`、`demo.gd` を新しい画面遷移へ追従させた。特に、タイトルから結果まで実入力で通す28秒の録画と、地図・チュートリアル・ハイライト・アニメーションを含む24枚の撮影を追加した。
7. ローカルの test・撮影・録画・全プラットフォーム build・Web build・実ウィンドウ起動を通した。その後 webtunnel で Web 版を実際に操作し、最後に CI artifact をダウンロードして Linux 描画も目視した。
8. 変更前後、近いジャンルの2ゲームとの識別、連続フレーム、Web 実操作を比較画像にし、`puts upload` で PR body に掲載した。知見文書を更新し、PR を ready for review にした。

### 詰まった点と解決

- 最初の `build-all` で、現在は使っていない `garden-theme.tres` が削除済みの旧 M PLUS Rounded を参照して export error になった。実際に表示する UI だけでなく、export 対象に含まれる未使用リソースも Klee One へ置換した。
- 通常の Godot バイナリは sandbox 外の editor settings へ書き込もうとして失敗した。`godot-development` skill の `prepare-sandbox-godot.sh` で `games/crewrts/tmp/godot-sandbox/` に自己完結した Godot 実行環境を作り、build と描画検証に使った。
- `Control.size` を指定しても `PanelContainer` の子要素の minimum size が勝ち、地図の説明紙が画面下へはみ出した。計算値だけで判断せず、撮影した原寸 PNG を見ながら文字量、余白、フォントサイズを調整した。
- 3D 上の説明文字はカメラ端で切れ、対象の個数表示とも重なった。対象付近には短い情報だけ残し、必要人数や次の操作は画面座標の鉛筆メモにも表示した。
- チュートリアルへ遷移したフレームで旧画面の focus を先に解放すると、表示されていても Enter が反応しなかった。状態を先に確定し、頁内容を更新してから主ボタンへ `grab_focus()` する順序にし、実 `InputEvent` の integration で再発を防いだ。
- ローカルでは Klee One にない曲がった矢印を OS フォントが補完したため正常に見えたが、Web では豆腐になった。`hb-shape` で `.notdef` を確認し、Klee One に収録された直線矢印へ置換した。修正後に別の webtunnel session を立て、Web 実画面で再確認した。
- webtunnel の Chromium は 1280×656 でゲームの1280×720と縦横比が違い、SwiftShader では待機が非常に遅かった。クリック時はゲーム座標から canvas 座標へ写し、通常5分の制限は変えず、待機区間だけ viewport を320×180へ縮め、証拠撮影時に原寸へ戻した。
- CI artifact の24 MB ZIPは単一接続で2回 connection reset になった。GitHub artifact の `Accept-Ranges` を確認し、byte range を5分割して並列取得し、サイズと `unzip -t` で完全性を検証してから展開した。
- `puts upload` は sandbox 内から macOS Keychain を読めず失敗した。公開先と対象画像をユーザーに明示して承認を得た後、許可付きで4画像だけをアップロードした。

## 2. 使ったツール・skill・コマンド

### 参照・利用した skill

- `godot-development`: Godot 4.7 の検証手順、GL Compatibility、export template、sandbox 用 Godot の準備、既知の落とし穴を確認した。
- `game-asset-search`: 素材源、ライセンス、加工・生成手段を `CREDITS.md` に残す基準を使った。Klee One は Google Fonts の公式配布元と OFL 1.1 を確認した。
- `imagegen`: 紙目、水彩のにじみ、文字なしの架空島絵地図を生成した。既存作品・ロゴ・文字を入れない条件をプロンプトへ含めた。
- `webtunnel` と `agent-browser`: GitHub Actions runner 上の Web export を Chromium で開き、キーボード・マウスの実入力、スクリーンショット、録画、session の終了まで行った。
- `gh-r2-image`: 新規用途では `puts upload` を使うという手順に従い、PR 掲載用の比較画像を公開 URL 化した。
- `commit-create-pr`: 個人情報・secret・差分・検証を確認しながら、日本語の commit、push、draft PR、PR body 更新を行う流れを参照した。

### 実際に使った主なコマンド・ツール

- Godot / Make:
  - `make test GAMES=crewrts`
  - `make screenshot GAMES=crewrts`
  - `make movie GAMES=crewrts`
  - `make -C games/crewrts movie-play`
  - `make build-all GAMES=crewrts`
  - `make build-web GAMES=crewrts`
  - `make crewrts-run`
- `gdlint`: `make test` 内の GDScript lint として実行した。
- `python3 scripts/dev/generate_audio.py`: 外部サンプルを使わず、既存 BGM / SE と新しい島環境音の WAV を再生成した。
- `ffmpeg` / `ffprobe`: AVI から H.264 MP4 への変換、時間・解像度・codec の検査、2秒間隔のフレーム、動画末尾、音量・スペクトログラムの確認に使った。
- ImageMagick の `magick montage`: 変更前後、他ゲームとの識別、Web 実操作、全撮影画像の contact sheet を作った。
- `hb-shape`: Klee One が UI で使う矢印を収録しているか調べ、Web だけで発生する字形不足を切り分けた。
- `gh`: issue / PR / Actions の参照、draft PR 作成、commit 後の push、CI status 確認、失敗 job の再実行、artifact の取得、PR body 更新、ready 化に使った。
- `puts upload`: 変更前後、識別比較、連続フレーム、Web 実操作の4画像を Cloudflare R2 にアップロードした。
- `curl`: GitHub artifact の単一接続取得が繰り返し切れたため、range download に使った。
- `git diff --check`、`git status`、電話番号差分検査スクリプト: push と完了報告前の差分・個人情報・作業ツリー確認に使った。

## 3. 欲しかったが無かったツール・skill・スクリプト

- **比較画像の自動生成器**: ゲーム slug、変更前ディレクトリ、比較対象 slug を渡すと、タイトル・ステージ選択・プレイ中を規定サイズで撮影し、日本語ラベル付きの変更前後・識別テスト画像まで作るもの。今回は対象画像の選定、仮の「変更前は地図なし」画面、`magick montage` の tile と余白を手で組んだ。
- **同梱フォントの使用字形検査**: GDScript / scene / resource から表示文字を抽出し、`hb-shape` または font cmap と照合して `.notdef` を CI で落とすもの。ローカルの OS fallback が不足を隠すため、Web 起動後に豆腐を発見するまで分からなかった。
- **GitHub artifact の再開・分割ダウンローダー**: `gh run download` と同じ認証を使い、途中再開、range 並列、最終サイズ・ZIP integrity まで一度に確認するもの。低速回線での手作業が大きかった。
- **Godot UI の安全領域可視化**: Control の指定 rect、実 minimum size、親 Container による再配置、1280×720 の画面端を重ねて撮影する debug overlay。画面下のはみ出しを原寸 PNG で発見してから調整した。
- **3D ラベル重なり検査**: Label3D と重要オブジェクトの投影領域を撮影時に検査し、画面外・重なりを警告する補助。今回は目視で UI へ情報を移した。
- **短い Web E2E の状態待機**: webtunnel の実入力は有効だったが、SwiftShader 上で通常5分を待つ時間が長かった。ゲーム状態を書き換えず、画面描画を最小化しながら timer 終了を待ち、証拠時だけ原寸に戻す操作を定型化できるとよい。
- **音声の主観 QA 経路**: 波形、音量、再生 event、スペクトログラムは機械検査できたが、「島らしい」「うるさくない」「BGM と混ざって聞き取りやすい」は音声入力のないエージェントでは評価できなかった。録音を人へ渡す手順と短い聴感チェック項目があると判断を残しやすい。

## 4. 素材の準備方法と使い勝手

### 画像

- `imagegen` で `paper-grain.png`、`watercolor-wash.png`、`island-map.png` を生成した。紙の繊維、顔料の偶然のむら、複数地域を一枚にまとめた島のような、有機的で情報量の多い静的素材を短時間で作る用途には強かった。
- 島絵地図には文字を焼き込まず、場所名、選択状態、理由、ボタンを Godot 側で重ねた。生成画像内の文字崩れを避け、状態変更・localization・操作入力を画像から分離できた。
- 生成画像は同じプロンプトから同一 pixel を再生成できず、道の位置や一部分だけを正確に直しにくい。バイナリ容量も増える。背景や質感には向くが、状態を持つ UI、正確な文字、クリック領域の SSOT には向かなかった。
- 前ラウンドの手続き SVG は、座標・色・形を正確に修正でき、git diff と再現性に優れる。一方で、指定した図形以上の質感は出ず、複数ゲームで同じ図形語彙に見えやすい。今回は「偶然の質感と背景は生成 PNG、状態表示は Godot、識別が必要な立体は既存プリミティブと shader」に分担した。
- 3D は外部 model を追加せず、既存の Godot primitive mesh を維持し、水彩のにじみを低い混合率で toon shader へ重ねた。小さい部品へ強く貼ると識別色が壊れたため、紙の明度と弱い色むらだけを使った。

### BGM・SE・環境音

- 前ラウンドの場面別 BGM と SE は維持し、Python 標準ライブラリで WAV を数式合成する `generate_audio.py` に島環境音を追加した。周期補間した風、葉擦れの高域、短い鳥声を12秒 stereo loop にまとめた。
- 外部録音を探す必要がなく、再生成が冪等で、権利関係と provenance を説明しやすい。音量、長さ、波形、鳥声の時刻も機械検査しやすかった。
- 実録音より自然さを出しにくく、BGM・SE と混ぜた時の心地よさは数値だけでは判断できない。今回はスペクトログラムと再生経路までは確認したが、主観的な聴感は未評価である。

### フォント

- Klee One Regular を Google Fonts 公式配布から取得し、フォント本体と SIL Open Font License 1.1 全文を `assets/fonts/` に保存した。取得元、作者、改変なし、クレジット要否を `CREDITS.md` に記録した。
- OS font に依存せず macOS、Linux CI、Web で同じ日本語を出せ、探検ノートの手書き感を大きく支えた。
- 日本語が入っていても全記号を含むとは限らない。macOS の fallback では問題が隠れたため、使用文字を同梱 font 自体に対して検査し、Web 実画面でも確認する必要があった。

### ライセンスと記録

- Klee One は公式 URL と OFL 1.1、生成画像は OpenAI の生成手段・規約 URL・プロンプト要点、数式合成音声と手続き3Dは外部素材未使用として、それぞれ `assets/CREDITS.md` に分けて記録した。
- 素材を置いてから出所を後追いするのではなく、採用時に URL、license、加工、生成 prompt の要点を同時に残す方が迷いが少なかった。

## 5. 動作確認の方法

### headless とロジック検証

- `make test GAMES=crewrts` で `gdlint`、import、boot、`selfcheck.gd`、`integration.gd`、終了処理を確認した。
- `selfcheck.gd` は scene / asset の load、禁止 font 不使用、チュートリアル state、通常5分の clear 経路など、描画を見なくても判定できる不変条件に効いた。
- `integration.gd` は実 `InputEvent` を本番 scene へ送り、タイトル、地図、チュートリアル、プレイ操作を UI と simulation の接続ごと検証した。focus 順序による Enter 無反応の再発防止には unit test より有効だった。
- headless では UI のはみ出し、紙 texture の見え方、3D ラベルの切れ、文字の豆腐、黒画面は分からないため、これだけでは不十分だった。

### `screenshot.gd` とアニメーション

- `make screenshot GAMES=crewrts` でタイトル、地図、チュートリアル3頁、通常プレイ、highlight、投擲の開始・途中・終了、運搬、戦闘、回収、結果、object gallery、部位 animation を含む24枚を撮った。
- PNG は contact sheet だけでなく、文字と画面端を確認する場面は1280×720原寸でも見た。Container の下端はみ出し、Label3D の重なり、Web 用記号の候補など、ロジック検証で見つからない問題に最も効いた。
- アニメーションは隊長、攻撃役、運搬役、甲虫、トゲ甲虫について、idle / walk / attack / hit / death の開始0%、途中50%、終了100%を同じ倍率で並べた。部位の接続、動きの方向、終了 pose、敵の退場を比較できた。
- 投擲はフィールド上でも開始・飛行中・到着後を別 PNG にした。gallery だけでは分からない、群衆の中での見え方と対象 ring の関係を確認できた。
- 3時点の静止画では補間中の一瞬の貫通や動きの滑らかさを完全には保証できない。その不足は `movie-play` と Web 実操作で補った。

### movie と実入力録画

- `make movie GAMES=crewrts` は起動からタイトルまでの5秒を撮り、真っ黒でないことと末尾 frame を確認した。起動直後の camera・texture import・UI 初期表示に効いた。
- `make -C games/crewrts movie-play` は28秒、840 frame の固定 fps 録画で、タイトル → 地図 → チュートリアル → 移動 → 照準 → 役割切替 → 投擲 → 笛 → 解散 → 結果 → タイトルを実入力で通した。2秒間隔14枚と末尾を見て、状態遷移と animation の連続性を確認した。
- 録画時間を短くするため残り時間だけを22秒にしたが、回収数や敵 HP は直接成功状態へ書き換えていない。通常5分の経路は selfcheck と Web 実操作で別に確認した。

### 実ウィンドウ、CI artifact、webtunnel

- `make crewrts-run` で macOS の実 window を開き、main scene が表示されることを確認して window の close button から終了した。
- CI は Linux / Xvfb / llvmpipe の screenshot と movie artifact を取得し、PNG 24枚、movie の codec・長さ・末尾を目視した。macOS だけで正常な shader や font を成功扱いしないために効いた。V-Sync 非対応 warning は既知の allowlist だけだった。
- webtunnel は実際の Web export を Chromium で開き、タイトルから通常5分の結果、タイトル復帰までキーボードと mouse で操作した。ローカル fallback に隠れた font glyph 不足は Web で初めて見つかった。
- Web の SwiftShader は約2 fpsまで落ち、滑らかさや desktop 固有の fullscreen / gamepad は評価できない。Web は入力経路、Web export、font、画面遷移に使い、滑らかさはローカル録画、desktop 表示はローカル実 window と CI artifact で分担した。

## 6. Godot 固有のハマりどころと回避策

- **Container の minimum size が指定 size より強い**: `PanelContainer` の子の font、余白、button の minimum size の合計で rect が拡大する。数値だけでなく、最終解像度の原寸 screenshot で上下左右の端を見る。
- **別 root に置いた UI は親画面と一緒に消えない**: 紙メモを main screen と別の root child にすると、画面本体を hide しても残る。同じ画面単位の UI は同じ親に入れるか、遷移時に関連 node をすべて明示的に切り替える。
- **focus 更新順で同じ frame の入力が落ちる**: scene state を確定する前に旧 button の focus を解放すると、新 UI は見えても Enter / gamepad A を受けない。state → 内容更新 → `grab_focus()` の順にし、その frame 境界を実 InputEvent で検証する。
- **Label3D は情報 UI の SSOT に向かない**: camera 端、depth、群衆、別 label との重なりで読めなくなる。world 中には対象を指す短い情報だけ置き、重要な必要人数・不可理由・次の操作は screen-space UI にも持たせる。
- **ローカル font fallback が Web の不足を隠す**: 同梱 font にない glyph を macOS が補完しても Web export は補完できず豆腐になる。`hb-shape` / cmap で使用文字を同梱 font に対して検査し、Web 実画面を撮る。
- **未使用 resource も export 時に parse される**: 表示中の UI で使っていない theme が削除済み font を参照しても export error になる。asset を置換・削除する時は `rg` で `.tres`、`.tscn`、script、export filter の全参照を調べ、`build-all` と `build-web` を通す。
- **sandbox では editor settings の書き込み先が問題になる**: Godot 本体が project 外へ設定を書こうとする環境では、skill の sandbox wrapper で実行ファイルと editor data を project の `tmp/` に閉じる。
- **GL Compatibility の shader は実 renderer で確認が必要**: headless の load 成功だけでは sampler、lighting、texture の実表示を保証しない。OpenGL Compatibility の windowed screenshot、macOS 実機、Linux llvmpipe、WebGL2を組み合わせる。
- **audio resource の解放は固定 frame 待ちだけでは不安定**: `AudioStreamPlayer.stop()` 後も audio thread が playback / WAV を一時保持する。撮影終了時は固定秒数ではなく WAV の `weakref` が解放されたことを観測し、timeout 時は明示的に失敗させる。
- **Movie Maker と通常実行は時間の意味が違う**: Movie Maker は固定 fps で決定的に進むが、通常 window / Web は実時間と描画性能に依存する。録画用に game state を直接成功へ変更せず、短縮する値と通常経路の検証を分離する。
- **Web の canvas と game 解像度が一致しない**: browser viewport 1280×656 に対して game は1280×720だった。CDP の click 座標へ写す時は canvas の表示 rect と letterbox を含めて変換し、撮影前に viewport を元へ戻す。
