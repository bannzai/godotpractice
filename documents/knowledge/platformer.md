# platformer の実装知見

## 設計

- オリジナル作品「そらいろ便」。地上の「風の草原」と地下の「ひかりの洞窟」を、同じ操作と異なる地形・背景・BGMで構成する。
- 進行状態は autoload の Session に集約。死亡・ゴール処理は phase を使って重複適用を防ぐ。残機の減算や取得などイベントを消費する関数には非冪等の理由を記載する。
- TileMapLayer に TileSetAtlasSource と衝突ポリゴンを設定する。移動する主人公と敵は CharacterBody2D、叩けるブロックは StaticBody2D とし、衝突の役割を分ける。
- 主人公の座標は足元。成長時も足元を動かさず、形状と画像だけ上へ広げる。ジャンプ受付猶予と足場を離れてからの短い猶予を設ける。

## 環境で確認した問題

- ローカルに godot-development skill が無かった。指定の raw URL は匿名アクセスで404だったが、設定済み認証の `gh api repos/bannzai/castle/contents/... -H 'Accept: application/vnd.github.raw+json'` で取得できた。
- sandbox 下で Godot が user://logs の既存ログを更新できず、起動時にクラッシュした。ゲーム内 Makefile の `--log-file` を作業ディレクトリ内の絶対パスへ向けて回避した。実ウィンドウの撮影は sandbox 外で実行する。
- `--headless --quit` の即時終了で AudioStreamPlaybackWAV が保持され、終了時の WARNING/ERROR が発生した。音を出せない headless 環境では再生を開始しない。描画付き検証と通常プレイでは音声を再生する。録画は専用 SceneTree で終了8フレーム前に停止し、音声ミキサーへ反映させる。通常の閉じる操作でも停止後に終了する。

## 素材

- SVG と WAV は独自の生成スクリプトで再生成可能。フォントは日本語を含む Noto Sans JP を OFL 全文付きで同梱する。出典・条件はゲーム内 assets/CREDITS.md を正とする。
- OS のフォント代替に依存せず Theme.default_font を指定する。OFL.txt と CREDITS.md は export preset の include_filter に明示して配布物へ含める。

## 実描画・入力で見つけた問題

- `_draw()` の中だけで `load()` した Texture2D は、描画命令が実行される前に参照が消え、白い矩形として描画された。preload 定数で保持して解消した。
- 背景をワールドと同じ CanvasItem に描くと、横スクロールで画面外へ流れる。背景専用 CanvasLayer を使い、カメラ位置は視差の計算にだけ渡す。
- Noto Sans JP 可変フォントは既定ウェイトが100だった。FontVariation の variation_opentype に文字列の wght を渡しただけでは反映されず、TextServer.name_to_tag("wght") の数値タグで600を指定すると反映された。
- 標準 ui_accept の実行時イベントにはキーボードだけが含まれていた。独自 confirm だけにパッドを割り当てても Button は動かない。ui_accept にもパッド A を明示し、タイトルと一時停止メニューからの決定を InputEventJoypadButton で検証した。
- 敵の生成位置はステージの衝突タイルから足元の高さを決める。固定の地面座標では段差の中に埋まった。
- 殻を横から蹴った瞬間に自身へ被弾判定が戻らないよう、短い接触猶予を設ける。殻の速度もプレイヤーのダッシュより速くする。

## 検証結果

- ルートの `make test GAMES=platformer` が exit 0。selfcheck は状態・ダメージ・時間切れ・2ステージ遷移・入力割当・素材クレジットを検証する。
- playcheck は実際の物理フレームと入力で、加減速、ダッシュ、短押しと長押しジャンプ、ブロックへの衝突、強化、踏みつけ、被弾、残機切れ、再挑戦を検証する。両ステージを始点からゴールまで、座標の書き換えや無敵付与なしで走破する。キーボード・パッドの合成イベントでも開始・移動・一時停止・再開を確認した。物理パッド実機の接続確認はしていない。
- `make screenshot GAMES=platformer` が exit 0。タイトル、草原、洞窟、変身、踏みつけ、ポーズ、ステージクリア、最終クリア、ゲームオーバー、全画面、960×540の11画像を目視確認。F11の往復もスクリプトで確認した。
- `make movie GAMES=platformer` が exit 0。5秒のmp4を0.5秒間隔の10フレームで目視確認し、起動表示の欠落や崩れがない。音声トラックは平均 -32.6 dB・最大 -22.7 dBで、無音やクリッピングではない。音の聴取評価はしていない。
- `make build-all GAMES=platformer` と `make build-web GAMES=platformer` が exit 0。macOS ZIP、Windows EXE/PCK、Linux実行形式/PCK、Web HTML/WASM/PCK を生成。ログ全文に WARNING/ERROR なし。デスクトップの起動検証はローカルのGodot実行で行い、Windows/Linux実機とWebブラウザ上のプレイは今回の受け入れ条件外。
- CI の最終結果と artifact 目視確認は PR body に記録する。

## 共有 skill への改善提案

- godot-development: 背景用 CanvasLayer、描画テクスチャの参照保持、可変フォントのタグ、ui_accept のパッド割当、Movie Maker 終了時の音声停止を実例として追加するとよい。
- 共有 CI: documents/knowledge/platformer.md の変更も共有変更と判定され、初回 PR では9ゲームすべての matrix が動いた。ゲーム別知見の変更を該当ゲームに絞る改善を提案する。
- godot-development: sandbox 向け `--log-file` 絶対パス指定と、private リポジトリの skill を既存 gh 認証で読む経路を追記すると再利用できる。

## 残した判断点

現時点でユーザー判断が必要な仕様分岐はない。マージとストア公開は作業対象外。

## 第 2 ラウンド (品質向上)

### 制作方針

- 配達人、芽を持つ歩行敵、結晶の殻を持つ敵を、それぞれ独立したフレーム画像で描き分ける。草原と洞窟、郵便とひかりの題材を維持し、生成可能なベクター素材でパレットを揃える。
- 衝突形状・移動速度・ステージ構成・残機ルールは維持し、状態別アニメーション、粒子、画面遷移、HUD、場面別の多声合成音を追加する。
- このゲームにはボス・NPC・弾が存在しないため、新たなゲーム仕様は追加せず、主人公と既存の敵2種・アイテム・UIを対象にする。
- 連続フレーム撮影、実入力によるプレイ録画、通常終了と強制フレーム終了の検証、Webの実操作とCI画像の確認を実施し、結果を追記する。

### 素材とアニメーション

- `generate_polish_art.py` でキャラ別3シート、全102フレームと、個別の地形・道具・UI・多層背景・キーアートを生成した。SVGの生成はセル寸法・足元・配色を揃えやすい。タイトルには別の大きな画像を用意し、小さなキャラ画像の拡大によるぼけを避けた。
- 周期を6枚に分けてsinだけで姿勢を変えると、途中に同じ姿勢が出る。cosの位相も使い、selfcheckで各動作6枚の画像差分を検証する。死亡時の縮小は足元を基点にし、セル内に描画を収める。
- `ActorFrames` が各シートを `AtlasTexture` に切り出し、`AnimatedSprite2D` が動作を再生する。被弾・退場・踏みつけは非ループにし、待機や移動へ戻る動作と区別した。物理の当たり判定は画像から独立して維持した。
- 背景は空のグラデーションシェーダ、遠景、雲、中景、光の粒を異なる速度で動かす。繰り返す背景画像の左右端の高さを揃えて継ぎ目を防いだ。GL Compatibilityのままで描画できる。
- `CPUParticles2D`、Tweenの光輪と得点表示を使った。ヒットストップは各ゲームノード内に閉じ、`Engine.time_scale` を変えない。演出の子ノードが解放され、画面揺れが収束することをplaycheckで確認した。
- `Theme` リソースへフォントとボタン・パネルの外観をまとめた。得点は表示だけを補間し、正しい値はSessionに保持する。HUDの進行バーは、テーマと最小寸法を設定してから高さを指定する必要があった。

### 音声と終了処理

- `generate_polish_audio.py` で、ベル・撥弦・リード・和音・低音・ドラムを32 kHz/16-bitステレオへ合成した。タイトル、草原、洞窟、成功結果、ゲームオーバーの5曲と8効果音を分け、全13ファイルの再生成ハッシュ一致を確認した。BGMのピークは0.62、SEは0.70以下、ループ境界差は最大0.00272だった。
- 生成コードと客観的な音量検査は再利用できる。一方、この実行環境のモデルは音声入力に非対応で、音楽の聴覚評価は未検証。音色の良さを波形検査だけで確認済みとはしない。
- Godot 4.7では `OS.get_cmdline_args()` にエンジンが消費した `--quit-after` が残らない。終了フレームをこのAPIから読んで先に音を止める実装は機能しなかった。通常のcloseでは停止後にTimerで待ち、SceneTree終了中の `_exit_tree()` では停止後に150 msだけ待って音声スレッドへ解放を反映した。`--quit`、`--quit-after`、Dummy/CoreAudio、複数SE再生中で終了コード0とリーク警告なしを確認した。
- 引数の仕様の一次情報: https://docs.godotengine.org/en/stable/classes/class_os.html#class-os-method-get-cmdline-args

### 実入力の検証で見つかったこと

- 第1ラウンドのInputMapに左右矢印の数値の誤りがあった。Godot 4.7で `KEY_LEFT=4194319`、`KEY_RIGHT=4194321` を実測して修正した。アクション名だけのテストでは分からないため、selfcheckの割当検査と、左右それぞれの `InputEventKey` による実移動をplaycheckへ追加した。
- `demo.gd` はタイトルの決定から、ダッシュ・跳躍・次のステージへの決定を実キーイベントで投入する。座標の書き換えや無敵付与なしで両ステージを走破し、30秒以内に最終結果へ到達しなければ失敗にする。
- 録画中に別のGodotウィンドウへフォーカスが移ると、キーの保持が解放される。自動操作側だけに「押している」という状態を持つと復帰できないため、毎回 `Input.is_physical_key_pressed()` から実状態を読むようにした。入力の蓄積もデモでは無効にした。通常のゲーム入力設定は変えていない。
- 録画は898フレーム/30 fps、最終結果への到達は約26.8秒。2秒間隔の一覧と末尾フレームで両ステージと結果画面を目視した。
- 動作一覧PNGは各シートの1・3・6枚目を固定表示する。演出は開始・途中・終端まで実際に時間を進めて撮る。シートの確認とゲーム内の再生・遷移の確認を両方行う必要がある。

### 本番に向けた道具の改善候補

- godot-developmentへ、キャラ別シートの足元基準、フレーム重複検査、実キー入力とフォーカス喪失、エンジン消費後の引数と音声終了の注意を追加すると再利用できる。
- `compose_evidence.py` のように、撮影PNGから演出の開始・途中・終端を並べ、PR添付を更新する処理をskill化したい。今回はゲーム内のスクリプトとして用意し、共有skill自体は変更していない。
- 音声を実際に聴いて比較する評価経路が必要。生成方法ごとの向き不向きは今回実測したSVG/PCM合成に限って記録し、未使用の画像生成サービスや外部素材サイトとの比較はしない。

### 第2ラウンドの検証結果

- ローカルの `make test GAMES=platformer`、`make screenshot GAMES=platformer`、`make movie GAMES=platformer`、`make build-all GAMES=platformer`、`make build-web GAMES=platformer` はすべてexit 0。保存したログ全文にWARNING/ERRORはなかった。
- `movie-play` と `exitcheck` はゲーム固有targetとして追加したため、`make -C games/platformer movie-play` / `make -C games/platformer exitcheck` で実行する。共有Makefileは作業範囲外なので変更していない。PR #25は検証時点で未マージのため、起動は指定の代替targetで確認した。
- 最終画面で再生成したプレイ録画は29.93秒、最終結果への到達は26.82秒。2秒間隔の15枚と末尾フレームを目視し、草原から洞窟、最終結果まで確認した。
- CIのartifactでも各画面、主人公・敵2種の連続フレーム、物体一覧、8演出、起動動画の0.5秒間隔のフレームを目視した。Linuxでは既知のllvmpipeによるV-Sync未対応警告が各描画ログに1件あり、ゲーム由来のWARNING/ERRORとリーク警告はなかった。CIのrun URLと添付画像はPR本文を正とする。

### Webの実操作で見つかったこと

- Webtunnelは `--software-webgl --ref polish/platformer` で起動し、callerが指定するポート8000のWeb版を開いた。スキルの一般例の8080では接続できないため、callerの `port` を確認する。1280×656のブラウザには16:9のゲームを左右余白付きで表示する。
- `agent-browser press ArrowRight` はGodotへ `physical_keycode=4194321`、右移動の強度1として届いた。一方、この環境の `keydown ArrowRight` は `keycode=4194321` でも `physical_keycode=65`（A）となり、左移動の強度1になった。長押し操作ではDキーを使い、矢印の確認はpressで行った。InputMapを逆に変更して合わせてはいけない。
- 調査では配信PCKの `project.binary`、エンジンJS/WASMのハッシュをローカルと比較し、同じ値とバイナリであることを確認した。その後、ブラウザ内だけで観測用ノードを追加したPCKを一時起動し、受信イベントと入力強度を記録して操作ツール側の不一致を特定した。診断ファイルはtmpに置き、配信ソースやPRには含めていない。
- Web版のreleaseテンプレートでは今回 `--script` による診断起動は機能しなかった。Engineの `preloadFile` と `start` で診断PCKを使う場合、`start` の前に `init("index")` が必要だった。公式API: https://docs.godotengine.org/en/stable/tutorials/platform/web/html5_shell_classref.html
- 上記のキー長押しと公開APIによる一時観測を、agent-browser / godot-development skillの調査例に追記すると再利用できる。共有skillへの変更は今回行っていない。
- 通常起動のWeb版で、決定・移動・ジャンプ・再挑戦・マウスによるタイトル復帰を実操作した。タイトル、プレイ、残機切れの結果、タイトル復帰を撮影し、最新通常起動からのコンソールにWARNING/ERRORがないことを確認した。検証後に `down platformer` を実行し、workflowの終了を確認した。
- PUTSの保存済み設定を読む際、macOSのアプリデータアクセス同意待ち／SQLiteエラー23が発生した。許可が通った実行ではアップロードできた。未添付の物体・演出・録画・Webの確認済み画像を1枚の比較用PNGへまとめ、追加1回のアップロードで添付を完了した。公開URLから取り直した画像と元PNGのSHA-256一致を確認した。OSのアクセス設定やアプリ保存データは変更していない。
