# shooter 手直しラウンドの振り返り

対象は PR #69 の、見た目の特色化と操作導線を作り直したラウンドである。前ラウンドまでに存在していた約3分のゲーム進行、敵編成、ボス戦、BGM・SEを維持しながら、黒地のベクタースキャン、コクピット計器、航路図、初回チュートリアルへ置き換えた。

成果物のPR:

https://github.com/bannzai/godotpractice/pull/69

## 1. 開発の進め方

### 作業の順序

1. 作業指示書、AGENTS.md、PROJECT.md、issue #5、PR #28、既存の `documents/knowledge/shooter.md`、各ラウンドのヒアリングを読んだ。変更範囲、前ラウンドの受け入れ条件、他ゲームと見た目が重なった原因を先に整理した。
2. 変更前の `make shooter-run`、`movie-play`、`screenshot` とコードを確認した。画面下や右側に操作一覧を常設していること、タイトルから即戦闘に入り行き先が分からないこと、塗りつぶしSVGと四角いHUDが他ゲームに似ていることを問題として特定した。変更前の代表画面は比較用に保存した。
3. 最初に Train One を取得し、OFLを分離してThemeを黒・シアン・マゼンタ・アンバー中心へ変更した。この小さい単位で最初のコミットを作り、draft PRを早期に開いた。
4. 画面遷移を `TITLE → NAVIGATION → TUTORIAL → PLAYING → RESULT` に組み直した。航路図では選択中の航路、選べない理由、約3分・敵120機・旗艦1機のプレビューを表示した。初回のみ移動、射撃、ボムを順番に受け付ける離陸前の計器チェックを追加し、完了状態を保存するようにした。
5. `flight_view.gd` を中心に、黒地の走査線、遠近グリッド、丸い計器、レーダー、ワイヤーフレーム地球儀を描いた。画面下の共通操作ガイドは削除し、タイトル、航路図、チュートリアル、ポーズ、結果の各場面で次に必要な操作だけを表示した。
6. `ship_sprite.gd` を `Sprite2D` のSVG表示から `Node2D` と `Line2D` の線画へ変更した。自機と敵4機種の合計5機種について、待機・移動・攻撃・被弾・撃破の5状態を各4フレームで作った。各線を残光、赤のずれ、青のずれ、明るい芯の4層で重ね、走査用のCanvasItemシェーダを適用した。弾、アイテム、爆発、ボム、撃破演出も線へ統一した。
7. ボス直前に3.2秒の航路確認を追加し、航路図から旗艦戦へ移る意味を画面内で示した。既存の場面別BGM・SEは残し、航路図と計器チェック用の周波数走査パルス `scan.wav` を固定波形で生成した。
8. selfcheck、統合検証、撮影、起動動画、操作付き動画を更新した。静止画を見て線の視認性、表示の重なり、チュートリアルの進行、各機体と演出を調整した。操作付き録画は固定時間終了から結果状態への到達終了へ変えた。
9. fighter、platformer、kartraceの同じ役割の画面をCI artifactから取得し、タイトル、選択画面、プレイ中の識別比較を作った。変更前後、チュートリアル、連続フレーム、webtunnel実操作の画像も一覧化した。
10. ローカルの全検証、macOS・Windows・Linux・Webのエクスポート、webtunnelの実操作を終えた後、画像を `puts upload` で公開しPR本文へ掲載した。CI artifactも目視し、全ジョブ成功を確認してPRをReady for reviewへ切り替えた。

### 詰まった点と解決方法

- 変更前から、ウィンドウのフォーカス通知中に結果・ポーズ用の子ノードを追加すると `Parent node is busy setting up children` が出る問題があった。通知中は状態だけを変更し、UIの再構成を `call_deferred` で次の安全なタイミングへ送った。headlessだけでは再現しにくいため、描画付きの実入力録画を再発検査にした。
- 複数の作業でGodotウィンドウが同時に開いており、最初の `make shooter-run` ではmacOSのアクセシビリティ操作が応答しなかった。他のウィンドウを壊さないよう前面操作を中止し、変更前の体験は既存の実入力 `movie-play` と代表画面で確認した。変更後の通し操作は専用runnerを持つwebtunnelで行った。
- `Line2D` を持つ親ノードを拡大すると線幅まで太くなり、旗艦と通常機で発光の印象が変わった。線幅をスケール前に一定として、状態アニメーションの拡縮は線の座標へ適用した。爆発もノード全体の拡大ではなく線片の座標を更新した。
- 発光を4層にするとノード数が増えた。画面内に大量に出る弾まで機体と同じ構成で毎フレーム生成すると負荷と管理コストが増えるため、弾は芯と残光の2層に絞り、必要数まで増やした `Line2D` を再利用した。
- ボス前航路図を3.2秒追加したことで、従来の26秒固定録画は旗艦戦の途中で終わった。`demo.gd` は結果を45フレーム収録した時点で正常終了し、結果へ到達しない場合だけ35秒で失敗する状態駆動の終了条件へ変更した。最終動画は743フレーム、24.77秒になった。
- 黒地の線画では、動画の平均輝度だけを旧画面と同じ閾値で検査すると正常な画面まで黒画面扱いになった。平均輝度 `YAVG >= 8` に加えて、発光線の存在を見る最大輝度 `YMAX >= 128` を併用した。閾値変更後も末尾フレームを実際に見て、検査を通すためだけの値になっていないことを確認した。
- `puts upload` はサンドボックス内からmacOS Keychainを読めず失敗した。新しい認証情報は作らず、既存設定を読める通常権限で同じコマンドを再実行した。8画像の公開後は `curl` で全URLがHTTP 200かつ `image/png` であることを確認した。
- webtunnelのWebサーバーを最初に `localhost:8080` と誤認し、ブラウザ接続が1回失敗した。caller workflowの現物から実際のポートが8000だと確認し、`localhost:8000` で起動完了とWebGL 2を確認してから操作した。agent-browserのセッション名は毎回 `shooter` を明示した。
- 最新CIの1回目は、変更していないcitybuilderの撮影終了時リークで全体が失敗になった。ジョブログとartifactを取得するとshooterの3ジョブは成功しており、citybuilderだけの終了時リークだった。再実行では再現せず全ジョブが成功した。成功runのshooter artifactは、先に目視したものと全40ファイルがバイト単位で一致した。
- `gh run download` は5.4 MB程度でも出力なしで1分以上待つことがあり、停止か転送中か判別しにくかった。プロセスを中断せず完了まで待ち、取得後にファイル数、ログ、ハッシュを別途確認した。

## 2. 使ったツール・skill・コマンド

### 実際に使ったskill

| skill | 利用内容 |
| --- | --- |
| godot-development | Godot 4.7の起動、headlessと描画付き検証の使い分け、エクスポートテンプレート、ログと終了時リークの確認方法を参照した |
| game-asset-search | Train Oneを一次配布元から取得するスクリプト、OFL確認、生成素材を含むCREDITSの書き方に使用した。外部画像や音源の検索には使っていない |
| commit-create-pr | 差分点検、コミット、push、draft PRの作成と更新、Ready for reviewまでの流れに使用した |
| webtunnel | `fix/shooter` のWebエクスポートをGitHub Actions runnerで起動し、CDP接続先の取得、録画の取得、セッション終了に使用した |
| agent-browser | `--session shooter` とCDP接続先を明示し、タイトルから結果までのキー入力、画面撮影、ブラウザエラーとコンソールの確認に使用した |

### 実際に使った道具

| 道具 | 用途 |
| --- | --- |
| Godot 4.7 / GDScript / Make | ゲーム実装、アセットimport、headless検証、描画付き撮影、Movie Maker録画、デスクトップ3種とWebのエクスポート |
| gdlint | `games/shooter/scripts/` の静的検査。`make lint` と `make test` から実行した |
| Python標準ライブラリ | 固定波形の `scan.wav` 生成、既存音声の再生成・数値検査に使用した。画像生成APIとしては使っていない |
| ffmpeg / ffprobe | AVIからH.264 mp4への変換、動画の長さ・フレーム数・解像度の確認、2秒間隔と末尾フレームの抽出、`signalstats` による黒画面検査、音声デコード確認に使用した |
| ImageMagick `magick` | 37枚の撮影結果、アニメーション、演出、操作動画、他ゲームとの識別比較をラベル付き一覧画像へまとめた |
| puts | 比較・チュートリアル・アニメーション・webtunnel・ボス航路の8画像をR2へアップロードし、PRへ埋め込むURLを得た |
| gh | issue・PR・CIの参照、draft PR作成と本文更新、push後のcheck確認、ジョブログとartifactの取得、CI再実行、Ready for reviewへの切り替えに使用した |
| git | 差分・変更範囲・コミット内容の確認、2コミットの作成、通常pushに使用した。マージ、force push、履歴書き換えは行っていない |
| curl / cmp / rg | 公開画像のHTTP状態とContent-Type確認、2回のCI artifactのバイト比較、コード・ログ全文のWARNING / ERROR / リーク検索に使用した |
| 画像表示ツール | ローカルとCIのPNG、一覧画像、動画から抽出したフレームを実際に目視した |

今回の代表的なコマンドは次のとおり。

```bash
make import GAMES=shooter
make test GAMES=shooter
make screenshot GAMES=shooter
make movie GAMES=shooter
make -C games/shooter movie-play
make build-all GAMES=shooter
make build-web GAMES=shooter
make shooter-run RUN_ARGS='--quit-after 120'
```

webtunnelでは次の流れを使用した。

```bash
WEBTUNNEL_REPO=bannzai/godotpractice bash ~/.agents/skills/webtunnel/scripts/webtunnel-cli.sh up shooter --software-webgl --ref fix/shooter --wait
bash ~/.agents/skills/webtunnel/scripts/webtunnel-cli.sh cdp shooter
WEBTUNNEL_REPO=bannzai/godotpractice bash ~/.agents/skills/webtunnel/scripts/webtunnel-cli.sh down shooter
```

証拠画像は次の形式で1枚ずつ公開した。

```bash
puts upload games/shooter/tmp/<画像名>.png --template 'Markdown Image,URL'
```

CI artifactの取得には次を使った。

```bash
gh run download 34102748236 -n shooter-screenshot-and-movie -D games/shooter/tmp/<取得先>
```

## 3. 欲しかったが無かったツール・skill・スクリプト

| 欲しかったもの | 減らせた手作業 |
| --- | --- |
| Godotの状態・入力・終了条件から撮影と録画を作る共通ハーネス | `screenshot.gd` と `demo.gd` に、各画面の準備、InputEvent、待機フレーム、結果到達、タイムアウトを個別に実装した。宣言的なシナリオから静止画と操作動画を作れれば、画面追加時の変更箇所と撮り忘れを減らせる |
| `Line2D` ベクターキャラクターの雛形 | 形状座標、4層の発光、色収差、状態ごとの座標変形、形状重複検査を今回まとめて作った。機種と線分を定義するだけでノード生成・アニメーション・gallery・selfcheckまで出せる雛形があれば再利用しやすい |
| スクリーンショット証拠の一括生成・公開スクリプト | ImageMagickで変更前後、他ゲーム比較、アニメーション一覧を別々に作り、8回 `puts upload` し、URLをPR本文へ手で対応付けた。撮影定義から一覧化、公開URL確認、PR用Markdownまで一括生成できると更新漏れを減らせる |
| 暗色ゲーム向けの動画健全性検査 | 平均輝度だけでは発光線画に合わず、YAVGとYMAXの組み合わせを手で調べた。複数フレームの輝度分布、フリーズ、全面単色をまとめて検査する共通スクリプトが欲しかった |
| CI artifact取得の進捗・再試行・差分確認ラッパー | `gh run download` が無出力で長時間待つため、停止との区別が難しかった。run attempt、転送量、再試行、ファイル数、ハッシュ差分を一度に表示できれば確認が速い |
| webtunnelのGodot用接続診断 | Webサーバーのポート、Godotローダーの終了、canvas寸法、WebGL 2、CDP到達性を別々に確認した。caller workflowからポートを決定し、操作可能になるまで待つ診断があれば誤接続を防げる |
| 音声の聴感確認を支援する仕組み | peak、RMS、端点差、デコードは数値で確認できたが、BGMとSEの聞き分け、耳障りな周波数、実スピーカーでの音量差は判断できなかった。ゲーム場面ごとの音声ミックス書き出しとラウドネス・スペクトログラム比較があると調整しやすい |

今回、共有skillやリポジトリ共通スクリプトは変更範囲外だったため作っていない。`documents/knowledge/shooter.md` には、`game-asset-search` へ発光線の層構成と連続フレーム検証を追加する案、`godot-development` へ通知中のUI再構成、Line2Dのプール、状態到達型録画を追加する案を記録した。

## 4. 素材の準備方法と、素材源・生成手段ごとの使い勝手

### 実行時の画像・背景・UI

新しい外部画像と画像生成APIは使わなかった。自機と敵、弾、アイテム、爆発、背景グリッド、走査線、丸い計器、レーダー、ワイヤーフレーム地球儀をGDScriptの `Line2D`、`draw_line`、`draw_arc` とCanvasItemシェーダで実行時に生成した。

- 外部素材の構図や解像度に合わせる必要がなく、座標・色・線幅を変えると全画面へ即時反映できた。インポート待ちや拡大時のぼけもなく、今回の「線に限定する」方向と相性が良かった。
- 機体の形、状態変化、発光層を同じデータから作れるため、画像ファイルとアニメーション定義の不一致が起きにくかった。
- 一方、座標列の手調整は視覚的でなく、1フレームだけでは状態差が分かりにくい。発光4層によってノード数も増える。gallery、連続フレーム、形状差のselfcheck、弾ノードの再利用が必要だった。
- 前ラウンドの手続きSVGは変更前比較の再現用に残したが、実行時には参照していない。SVGは独立した画像として確認しやすい反面、画像生成、import、SpriteFrames、セル境界の管理が別々になる。Line2Dはこの画風では動きと演出まで一つの座標系で扱える点が良かった。

### フォント

`game-asset-search` の取得スクリプトでGoogle Fontsの一次配布元から Train Oneを取得した。

https://fonts.google.com/specimen/Train+One

同梱されたSIL Open Font License 1.1を `assets/fonts/OFL.txt` に保持し、作者、取得元、ライセンスを `assets/CREDITS.md` に記録した。旧画面との比較用に残したNoto Sans JPは実行時に使わず、ライセンス文書を `NotoSansJP-OFL.txt` へ分離した。

- 一次配布元からフォント本体とライセンスを同時に取得でき、出典確認が容易だった。
- Themeに設定すれば通常のControlとCanvas描画の文字を揃えられ、輪郭中心の画面に固有の印象を与えられた。
- 日本語を含むためファイルサイズは約2.1 MBになった。フォントが持つ文字とWeb側のフォールバックに依存する記号は避け、キー表記は `Enter / A` など収録が明確な文字へ寄せる必要がある。

### BGM・SE

前ラウンドでPython標準ライブラリの波形合成とffmpegのVorbisエンコードにより生成されていた、タイトル・ステージ・ボス・結果の4曲と、射撃・爆発・アイテム・ボムのSEを維持した。今回新しく、航路図と離陸前チェックへ `scan.wav` を追加した。

`scan.wav` は `scripts/dev/generate_audio.py` で固定波形として生成した。長さ0.820秒、peak 0.4648、RMS 0.1352、端点差0を検査し、既存音声も同じスクリプトでデコードと波形を再確認した。

- 外部サンプルや音楽生成サービスを使わないため、権利関係が単純で、コードから同じ音を再生成できた。航路図の視覚的な走査周期と発音間隔もコード上で合わせやすかった。
- 波形パラメータの変更は速いが、数値検査は音色の良さを保証しない。今回利用できた手段では実スピーカーで聴取できず、場面別BGMとの音量・音色バランスは未検証として残した。

### クレジット

外部由来はTrain Oneだけで、取得元とOFLを記録した。新しい線画と `scan.wav` は本プロジェクト向けのコード生成物として、生成手段と方針を `games/shooter/assets/CREDITS.md` に記録した。外部画像、フリーBGM、フリーSE、既存作品の名称・画像・音・ロゴは使っていない。そのため、素材サイト間の検索性やダウンロード品質は今回比較していない。

## 5. 動作確認の方法、効いた点と足りなかった点

### headlessのcheck・selfcheck・integration・shutdown-check

`make test GAMES=shooter` でgdlint、import、起動、selfcheck、統合検証、終了方法別の検証をまとめて実行した。

selfcheckでは、5機種の形が同一でないこと、5状態×4フレームで座標が変わること、各線分に残光・赤青の色収差・芯の4つの `Line2D` とシェーダがあることを検査した。航路選択、初回チュートリアル、完了状態の保存と復元、スキップも検査した。integrationでは実際のInputEventを送り、移動、射撃、ボムでチュートリアルが順に進むことと、従来のゲーム進行を確認した。

ロジック、素材参照、状態遷移、保存、終了時リークを速く反復するのに効いた。一方、headlessでは発光線の細さ、文字の読みやすさ、UIの重なり、背景とのコントラスト、色収差の印象を判定できなかった。

### screenshot.gd

`make screenshot GAMES=shooter` で37枚を生成した。タイトル、航路図、選択ハイライト、チュートリアル3段階、戦闘、ポーズ、ボス前航路、ボス2段階、クリア・ゲームオーバーに加え、5機種のアニメーション一覧と5演出の3時点を撮影した。

固定状態を同じ解像度で比較できるため、画面ごとの導線、発光線の視認性、選択中とロック中の差、計器の情報量、機体の輪郭を確認するのに最も効いた。ただし、撮影スクリプトが直接状態を準備する画面もあるので、通常の入力経路で到達できることの証拠にはならない。

### アニメーションの検証

アニメーションは次の3段階で確認した。

1. selfcheckで、5機種、5状態、4フレームの座標差と描画層を数値検査した。
2. `animation_gallery.gd` と `screenshot.gd` で、機種ごとに状態とフレームを一覧にしたPNGを撮り、輪郭の重複、動きの差、撃破時の崩れ方を目視した。
3. `movie-play` で、移動、連射、被弾、旗艦の段階変化、撃破が実際の時間経過と入力で切り替わることを確認した。

この組み合わせで「データが違う」「静止画で違って見える」「通常進行中に切り替わる」を別々に確認できた。全フレームの滑らかさや高負荷時のフレーム落ちは測っていない。

### movieとmovie-play

`make movie GAMES=shooter` は操作なしの5秒録画で、起動直後が真っ黒でなくタイトルが表示されることを確認した。末尾フレームのYAVGとYMAXを検査し、画像も目視した。

`make -C games/shooter movie-play` は `demo.gd` から実InputEventを送り、タイトル、航路選択、チュートリアル、戦闘、ポーズと復帰、ボス前航路、旗艦戦、結果までを録画した。結果を直接書き換えておらず、入力と戦闘処理で到達している。mp4を2秒間隔と末尾の静止画へ分け、24.77秒・743フレームの流れを目視した。

実時間の通知で起きるUI追加エラーと、演出を追加した後の録画終了条件を検出できた。一方、固定fpsのMovie Makerは実機の処理性能を測るものではなく、音声はDummy driverなので聴感確認にも使えない。

### CI artifact

CIの `lint (shooter)`、`check-and-export (shooter)`、`screenshot-and-movie (shooter)` が成功した。成功runの `shooter-screenshot-and-movie` artifactを取得し、37枚のPNGを一覧化して目視し、mp4の末尾フレームも確認した。ログはどちらもexit 0で、Linux/XvfbのV-Sync変更非対応というMakefileで限定除外している既知警告以外にWARNING / ERROR / リークはなかった。

Linuxのllvmpipeでもフォント、発光線、地球儀、各画面が描けることを確認できた。macOSローカルだけでは見つからないレンダラ差の確認に有効だった。一方、artifactはWindows/Linux実機操作の代替ではない。

CI:

https://github.com/bannzai/godotpractice/actions/runs/34102748236

### webtunnel

`--software-webgl --ref fix/shooter` で専用runnerを起動し、agent-browserからタイトル、航路選択、計器チェック、移動、射撃、ボム、ポーズと復帰、ゲームオーバー、リトライまで実際のキー入力で確認した。ブラウザエラーは0件で、コンソールはGodot/OpenGL情報と `shooter boot` のみだった。画面を撮影し、セッション録画も取得して30秒間隔の一覧で複数回の通し操作を確認した。終了後は必ず `down shooter` を実行した。

撮影用スクリプトが直接状態を準備していない、ユーザーと同じ入力経路の証拠として効いた。Web版で確認できない物理ゲームパッド、デスクトップのフルスクリーン、Windows/Linux実機、実スピーカーでの音は足りないまま残った。

webtunnel run:

https://github.com/bannzai/godotpractice/actions/runs/34102767644

### 変更前後と識別テスト

変更前後のタイトル・地図・プレイ中を並べ、さらにfighter、platformer、kartraceの同じ役割の画面と比較した。自分の画面だけを見て「特色がある」と判断せず、他ゲームとの間で、黒地の線画、地球儀、丸い計器、配色、画面構成が重ならないことを確認できた。

静止画比較は一目での識別には有効だったが、音、操作感、ゲームテンポの識別までは示せない。その部分はmovie-playとwebtunnelで補った。

## 6. Godot固有のハマりどころと回避策

### `_notification` 中のUI再構成

フォーカス解放の `_notification` 中にButtonを `add_child` すると、親が子ノードの初期化中で `Parent node is busy setting up children` になった。通知関数では状態だけ更新し、ポーズ処理とUI再構成を `call_deferred` した。headlessではなく描画付きのフォーカス変化で再現したため、実入力録画を再発検査に含める必要がある。

### `Line2D` のスケールと線幅

親の `scale` は座標だけでなく `Line2D.width` の見かけにも作用する。機体サイズや撃破時の縮小をノードスケールだけで表すと、機種ごと・フレームごとに発光の太さまで変わる。基本線幅は一定にし、形状の拡縮は点列へ変換してから渡した。爆発の広がりも線片座標を更新した。

### 多層発光のノード数

一本の輪郭線を残光・赤ずれ・青ずれ・芯の4本にすると、線分数の4倍のノードになる。機体は再構築時に既存の `Line2D` を再利用し、弾は芯と残光だけのプールにした。毎フレームの生成・破棄を避けることが、線画を大量表示する場合の前提になる。

### CanvasItemシェーダと描画確認

シェーダがロードできることだけでは、暗い背景で発光が十分に見えるか、赤青のずれが過剰でないかは分からない。固定時刻のPNGを撮り、macOSとCIのllvmpipeの両方を目視した。描画付きログではOS・ドライバ由来のV-Sync警告だけを限定的に除外し、一般的なWARNING / ERROR除外にはしなかった。

### Movie Makerとheadless

Movie Makerは実際のレンダラが必要で、headlessだけでは見た目を検証できない。ローカルはOpenGL 3のウィンドウ、CIはXvfbとllvmpipeを使った。操作なしmovieは固定フレーム数、通し操作movieは状態到達とタイムアウトで終了させ、目的の異なる2種類を分けた。

### 暗い画面の黒画面判定

黒を基調に細い発光線だけを置く画面では、平均輝度が低いこと自体は正常である。平均値だけを下限にせず、`ffmpeg` の `signalstats` からYAVGとYMAXの両方を取り、暗い背景と明るい線が共存する条件を検査した。数値だけで完了せず末尾PNGを目視した。

### `user://` の初回チュートリアル状態

チュートリアル完了を通常の `user://shooter-save.json` に保存すると、開発者の過去実行によって「初回」画面が出たり出なかったりする。撮影とdemoでは検証用の状態を明示して `tutorial_seen = false` に戻し、selfcheckでは保存先を検証用へ差し替えた。旧保存データにキーがない場合は `false` として扱い、既存ユーザーにも一度だけ表示されるようにした。

### 描画付き終了時のリーク判定

Godot本体のexit 0だけでは、`ObjectDB instances were leaked` や `resources still in use` がログに残ることがある。各targetでログ末尾のexitを確認するだけでなく、全文をWARNING / ERRORで検索した。OS・ドライバ固有の既知行だけを具体的な文字列で除外した。CIで別ゲームの一過性リークが出た際も、ジョブ全体の失敗表示だけでなくartifact内のログを読んで原因を切り分けた。
