# actionadventure 開発ヒアリング

## 1. 開発の進め方

最初に issue、既存コード、変更前の実画面、他ゲームの画面を調べ、「次の行動が分かりにくい」「共通の藍色UIと手続きSVGで他ゲームに似る」を主因と整理した。次に素材候補を探し、同じ作者・同じシリーズで屋外、遺跡、人物を揃えられる Shade の Puny World、Puny Dungeon、Puny Characters を採用した。

実装は、素材取得とライセンス記録、決定的な画像生成、地域別パレットとタイル表示、石版HUD・地図・チュートリアル・操作対象表示、音声、ゲームロジック修正、検証コード拡充の順に進めた。35枚のPNGを生成してから、既存の8キャラクター×5動作、12室、仕掛け、戦闘を新素材へ接続した。最後にスクリーンショット、録画、通常入力の通しプレイ、Web実操作、CI artifactを確認し、比較画像をPRへ添付した。

詰まった点と解決は次のとおり。

- 別作者のタイルと人物を混ぜると地域差より素材差が目立った。同じ作者の3素材へ統一した。
- 宝箱の最初の切り出し座標が空白だった。ファイルの存在だけでなく、透明でない画素数・寸法・パレット外色を生成時に検査した。
- 16pxから56pxへの3.5倍拡大は nearest-neighbor でも画素幅が均一にならない。実寸スクリーンショットで輪郭と密度を調整した。
- webtunnelでチュートリアル本文だけ進み、見出しが `1 / 3` のまま残る不具合を発見した。見出しラベルもページ更新対象にし、統合テストで `2 / 3` と `3 / 3` を検査した。
- 古いブランチのCI対象判定で全ゲームが走り、無関係な flaky job が失敗した。無関係ゲームは変更せず `origin/main` をマージし、actionadventureだけのCIへ戻した。

## 2. 使ったツール・skill・コマンド

- `godot-development`: Godot 4.7の検証構成、headlessと描画付き検証の分離、ログ全文検査、export、音声終了処理の指針に使った。
- `game-asset-search`: `search-assets.sh` でCC0画像とStickフォントを検索し、`fetch-asset.sh --list` で正式な添付を確認、`--pick` で取得した。作品ページも照合した。
- `webtunnel` と `agent-browser --session actionadventure --cdp ...`: GitHub Actions上のWeb exportへ接続し、起動判定、WebGL2、キー入力、スクリーンショット、console/page errorを確認した。
- `pr-attach-screenshots`: `puts upload`、`curl`、SHA-256照合、PR本文のマーカー区間更新をまとめて実行した。比較画像4枚を添付した。
- `commit-create-pr`、`git`、`gh`: commit、push、draft PR、CI監視・artifact取得、`origin/main` のマージ、Ready化に使った。
- Godot CLIとMakefile: `make test GAMES=actionadventure`、`make screenshot`、`make movie`、`make -C games/actionadventure movie-play`、`make build-all`、`make build-web`、`make actionadventure-run` を実行した。
- `gdlint`: GDScriptのlintに使用した。Godot importによる全依存スクリプトのコンパイル確認も併用した。
- Python: `generate_pixel_assets.py` で切り出し、5系統各8色への再着色、nearest-neighbor拡大、背景合成、寸法・可視画素・色検査を行った。別の生成スクリプトでWAVも合成した。
- `ffmpeg` / `ffprobe`: Movie MakerのAVIをMP4へ変換し、輝度、長さ、末尾フレーム、contact sheetを確認した。
- ImageMagick、`screencapture`、`osascript`: 多数画像の比較表、実ウィンドウ撮影、起動中アプリ確認と通常終了に使った。
- `rg`: コード、ログ、差分、WARNING / ERROR / leakの検索に使った。

## 3. 欲しかったが無かったツール・skill・スクリプト

- スプライトシートの候補矩形を一覧画像にし、空白切り出し、寸法、パレット外色、再生成SHA-256を一括検査する補助ツール。空の宝箱切り出しをもっと早く検出できた。
- 全 `AnimatedSprite2D` の全動作について開始・中間・終了フレームを自動撮影し、名前付きcontact sheetを作るスクリプト。今回は `screenshot.gd` の撮影ケースとmontageを手で増やした。
- Godot Web向けのwebtunnel操作マクロ。キー押下・待機・状態取得・撮影・console検査を宣言的に書ければ、多数の `agent-browser` 呼び出しと1280×656座標換算を減らせた。
- PR作業開始時にmerge baseと最新のCI対象判定を比較する事前検査。古い判定による全ゲームCIと、無関係jobの再実行を防げた。
- チュートリアル、メニュー、地図、フォーカスを巡回し、本文と見出しの組を検査するUI状態遷移テスト生成器。

## 4. 素材の準備方法と使い勝手

画像はOpenGameArtの Shade による `16x16 Puny World Tileset`、`16x16 Puny Dungeon Tileset`、`Puny Characters` を使った。検索結果のプレビューではなく作品ページの正式配布ファイルとCC0-1.0表記を確認し、元ファイルを `assets/source/` に保持した。同一作者・同一シリーズは輪郭、陰影、セル寸法、動作数が揃い、別作者の素材を混ぜるより扱いやすかった。一方、正式添付の判別、ZIP内ファイル、切り出し座標の調査には時間がかかった。

元画像はそのまま使わず、海岸・森・遺跡・危険物・タイトルの各8色へ決定的に再着色した。元ファイルのSHA-256、ZIP内パス、切り出し範囲、出力寸法を `palettes.json` に残した。35枚を再生成できるため手修正より再現性が高い。前ラウンドの手続きSVGは取得や権利確認が不要で速かったが、同じ図形と配色に寄りやすく、粗いピクセル表現とゲーム間の識別には不向きだった。

BGM・SE・環境音は外部録音や既存旋律を使わず、PythonでPCMを合成した。長さ、最大振幅、クリップ、ループ端点、再生成一致は機械検査しやすいが、人の耳による音色・ミックス評価は代替できない。

フォントはGoogle FontsのStickを取得し、公式ファイルとのSHA-256とOFL全文を確認・同梱した。日本語グリフをすぐ利用でき、ライセンスも扱いやすかった。素材の作者、URL、ライセンス、加工内容は `assets/CREDITS.md` に記録した。

## 5. 動作確認の方法

- `selfcheck.gd`: 保存データ、仕掛け、素材寸法、パレット、クレジット、旧SVG不在など、描画を要しない不変条件に効いた。ただし見た目と時間変化は分からない。
- `integration.gd`: 実キー・パッドイベントでタイトル、移動、剣、道具、地図、会話、フォーカス、戦闘を120件検査した。入力マップの定数誤りや遅延フォーカスを検出できた。
- `playthrough.gd`: 状態や座標を書き換えず通常入力だけで全12室と結末まで4335フレームで完走し、撮影用前提と本当の攻略可能性を分離した。
- `screenshot.gd`: タイトル、チュートリアル3頁、地図、全室、選択可否、演出、8キャラ×5動作の開始・中間・終了を55枚撮影した。アニメーションは単一静止画ではなく連続3時点のcontact sheetで、ポーズが実際に変わることを目視した。
- `movie` と `movie-play`: 5秒の起動録画で黒画面や初期フェードを確認し、26秒の実入力モンタージュで探索・剣・道具・ボス・結末・タイトル復帰を確認した。録画用前提があるため、攻略可能性の証明には使わなかった。
- CI artifact: Xvfb/llvmpipeで再生成された55 PNG、MP4、ログを取得し、contact sheetと末尾フレームを目視した。Linux描画経路を確認できるが、物理ゲームパッドや各OS実機は確認できない。
- webtunnel: WebGL2の実画面へ通常入力を送り、タイトル、3頁の案内、地図、移動、剣、岩の取得、メニュー、ゲームオーバーを確認した。静的撮影で見逃した見出し更新バグに最も効いた。一方、フルスクリーンやデスクトップ固有挙動は対象外だった。
- `make actionadventure-run`: macOSの実ウィンドウ、Metal、CoreAudio、通常のCommand-Q終了を確認した。

## 6. Godot 固有のハマりどころと回避策

- sandboxでは `user://` 作成に失敗してもimportがexit 0になる場合がある。`--log-file` をworktree内へ向け、終了コードだけでなくログ全文を検査する。
- tree外で作ったNodeや再生中WAVは終了時リークになる。Nodeを解放し、音声を停止してstream参照を外し、ミキサーを待つ。Movie Makerでは終了12フレーム前に音を止める。
- Movie Makerで描画ノードを先に `queue_free()` すると末尾が灰色になった。描画ノードは `SceneTree.quit()` に任せ、音だけ先に止めた。
- headlessでは見た目を検証できず、`--write-movie` もdummy rendererでは使えない。ローカルの描画付き起動か、CIのXvfb + llvmpipeを使う。
- llvmpipeのV-Sync非対応警告は既知のドライバー警告として限定的に除外し、それ以外のWARNING / ERROR / leakは失敗にする。
- `Image.load()` によるPNG検査はexport後に使えない読み方の警告を出した。import済みの `Texture2D` として読み、配布物と同じ経路で寸法を検査した。
- `TextureRect` は元画像の最小サイズを持つ。`expand_mode` とstretchを設定してから表示サイズを決める。
- UI再構築後の `grab_focus.call_deferred()` がテスト側のフォーカスを上書きした。再構築後に1フレーム待ってから対象へフォーカスする。
- 点滅中の状態は物理フレーム直後では描画へ反映済みとは限らない。`RenderingServer.frame_post_draw` を待ってから可視状態を調べて保存する。
- 遷移先Actorを旧画面のキャプチャ前に生成すると、新しい敵が旧画面へ混ざる。遷移中はActor群を隠し、完了後に表示する。
- 分裂敵を倒した同じ風の輪が新しい小敵へ再命中した。投擲開始時に対象配列を固定した。
- 画像名に `warning` を含めるだけでログ検査が誤反応した。画像を `bomb-fuse` に改名し、警告除外を広げなかった。
