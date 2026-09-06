# platformer の実装知見

## 設計

- オリジナル作品「そらいろ便」。地上の「風の草原」と地下の「ひかりの洞窟」を、同じ操作と異なる地形・背景・BGMで構成する。
- 進行状態は autoload の Session に集約。死亡・ゴール処理は phase を使って重複適用を防ぐ。残機の減算や取得などイベントを消費する関数には非冪等の理由を記載する。
- TileMapLayer に TileSetAtlasSource と衝突ポリゴンを設定する。移動する主人公と敵は CharacterBody2D、叩けるブロックは StaticBody2D とし、衝突の役割を分ける。
- 主人公の座標は足元。成長時も足元を動かさず、形状と画像だけ上へ広げる。ジャンプ受付猶予と足場を離れてからの短い猶予を設ける。

## 環境で確認した問題

- ローカルに godot-development skill が無かった。指定の raw URL は匿名アクセスで404だったが、設定済み認証の `gh api repos/bannzai/castle/contents/... -H 'Accept: application/vnd.github.raw+json'` で取得できた。
- sandbox 下で Godot が user://logs の既存ログを更新できず、起動時にクラッシュした。ゲーム内 Makefile の `--log-file` を作業ディレクトリ内の絶対パスへ向けて回避した。実ウィンドウの撮影は sandbox 外で実行する。
- `--headless --quit` の即時終了で AudioStreamPlaybackWAV が保持され、終了時の WARNING/ERROR が発生した。音を出せない headless 環境では再生を開始しない。描画付き検証と通常プレイでは音声を再生する。

## 素材

- SVG と WAV は独自の生成スクリプトで再生成可能。フォントは日本語を含む Noto Sans JP を OFL 全文付きで同梱する。出典・条件はゲーム内 assets/CREDITS.md を正とする。
- OS のフォント代替に依存せず Theme.default_font を指定する。OFL.txt と CREDITS.md は export preset の include_filter に明示して配布物へ含める。

## 検証の進捗

実装中。状態ロジックの selfcheck、実物理の入力検証、代表画面撮影、録画、全エクスポートと CI を順に実施する。

## 共有 skill への改善提案

- godot-development: sandbox 向け `--log-file` 絶対パス指定と、private リポジトリの skill を既存 gh 認証で読む経路を追記すると再利用できる。

## 残した判断点

現時点でユーザー判断が必要な仕様分岐はない。マージとストア公開は作業対象外。
