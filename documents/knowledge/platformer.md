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
