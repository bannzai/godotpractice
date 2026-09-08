# 落ち物パズル「結晶の庭」開発ヒアリング

対象: `games/blockpuzzle/`。今回の開発で実行・確認した内容を記す。過去の `documents/knowledge/blockpuzzle.md` にある別実装の経験とは区別する。

## 1. 開発の進め方

1. ブランチ・未コミット変更・プロジェクト文書・Godotと素材の規約を確認した。開始時は `game/blockpuzzle` ブランチで、`games/blockpuzzle/` は存在しなかった。知見ファイルだけが既存だった。
2. 「2個組を落とし、同じ色を縦横に4個以上つなげて消す」方式を選んだ。6列12行の盤面と、消去後の重力による連鎖を軸にした。他ゲームの画面や実装は参照しなかった。
3. サブエージェントに盤面・移動・回転・消去・連鎖・記録保存とロジック検証を委譲した。先に状態名・シグナル・関数の入出力を伝え、こちらは同じAPIに対して画面と音を実装した。
4. Godotプロジェクト・シーン・Makefile・SVGを作り、Node2Dの描画APIで盤面、結晶、スコア、操作案内、開始・停止・結果画面を実装した。結晶は色だけでなく中央の模様でも区別できるようにした。
5. 正弦波からBGMと効果音を合成し、落下・回転・消去・終了イベントに接続した。
6. headlessのロジック検証と、描画付きの入力検証・撮影を実施した。画像を目視し、最高スコア表示を追加し、結果画面の裏に連鎖文字が残る問題を修正した。
7. 保存・復元と固定乱数200手の検証を追加した。README、素材記録、知見を整備し、commit・push・PR作成・画像4枚の添付まで実施した。

詰まった点は、存在しないフォーカスイベント型によるパースエラー、sandboxでのGodot保存エラー、音声再生中の終了警告、自動入力とOSフォーカス通知の競合だった。それぞれ型の置換、必要な権限での実行、音声停止後の終了、自動検証での通知分離により解消した。詳細は後述する。

## 2. 使ったツール・skill・コマンド

### 実際に使ったツール

- `functions.exec` と `exec_command`: ローカルコマンド実行、ログ確認。
- `apply_patch`: プロジェクト、GDScript、Makefile、文書の作成・編集。
- `collaboration.spawn_agent` / `followup_task`: ロジックと検証の委譲、保存とランダム操作検証の追加依頼。
- `view_image`: Godotが出力したPNGの目視確認。
- `rg` / `cat` / `sed` / `ls`: ファイル探索、規約・スキル・ソース・ログの読み取り。
- `python3`: Codexのセッション記録の先頭メタデータから再開用IDを取得。
- `mkdir` / `mv`: 作業ディレクトリの用意と、生成された `default.profraw` の `tmp/` への退避。

### 読んで手順を適用したskill

- `commit-create-pr`: PR本文の構成、秘匿情報確認、セッション再開欄、画像添付手順に使用。共有ファイルの変更やCI導入はプロジェクトの制約に従って行わなかった。
- `pr-attach-screenshots`: アップロード前の機械・目視検査、公開後の画像検証、PR本文への添付に使用。
- 電話番号チェックは規約が指定するスクリプトを直接使用した。該当skill全体を実行したわけではない。

### 主な実行コマンド

```sh
/Applications/Godot.app/Contents/MacOS/Godot --version
/Applications/Godot.app/Contents/MacOS/Godot --headless --path games/blockpuzzle --editor --import --quit --log-file /Users/bannzai/worktrees/bannzai/godotpractice/game/blockpuzzle/tmp/import-final.log
/Applications/Godot.app/Contents/MacOS/Godot --path games/blockpuzzle --script scripts/dev/screenshot.gd --log-file /Users/bannzai/worktrees/bannzai/godotpractice/game/blockpuzzle/tmp/visual.log
make -C games/blockpuzzle test
make -C games/blockpuzzle screenshot
git diff --cached --check
bash /Users/bannzai/.claude/skills/github-repos-phone-number-check/scripts/check-diff-for-phone-numbers.sh --staged
bash /Users/bannzai/.claude/skills/github-repos-phone-number-check/scripts/check-diff-for-phone-numbers.sh --unpushed
git commit -m '落ち物パズル「結晶の庭」を実装'
git push -u origin game/blockpuzzle
gh pr create --base main --head game/blockpuzzle --title '落ち物パズル「結晶の庭」を追加' --body-file tmp/blockpuzzle-pr.md
```

画像は `check-upload-target.sh` に4枚を渡して検査し、目視後に `attach-screenshots.sh --pr 89 --repo bannzai/godotpractice` へ同じ4枚とキャプションを渡した。スクリプト経由でputsへのアップロードと公開画像の検証が行われ、`UPLOADED=4`、`REUSED=0`、`BODY_CHANGED=1` を確認した。

Web検索、ブラウザ操作、画像生成サービス、外部音源の取得、動画録画、エクスポート、CI、コードレビューは実行していない。`godot-development` は規約中の参照を見たが、この開発でskill本文や雛形スクリプトは使っていない。

## 3. 欲しかったが無かったツール・skill・スクリプト

以下は「環境全体に存在しない」と調査で確定したものではなく、今回の作業で利用できる形にしていなかったもの。

- **Godotの描画付き入力検証の小さな共通スクリプト**。押下・解放、フレーム待ち、フォーカス通知との競合回避、撮影、終了時の音声停止を各ゲームで書かずに済むとよい。画面構成やゲーム仕様を固定せず、検証の補助関数だけを提供する形がよい。
- **合成音の検査スクリプト**。PCMの有無だけでなく、ピーク、無音、クリッピング、ループの継ぎ目を数値で確認できると、聴感未検証の穴を減らせる。
- **Godotコマンドのログ判定補助**。exit 0でもERRORが出るケースを拾い、ログ全文と終了コードを一緒に保存できると判定の手間を減らせる。
- **保存を隔離した検証の例**。本番の `user://` を変更せず、一時ファイルで保存・再読込を確認するパターンがあると、テスト用保存先を毎回設計せずに済む。

既存の画像添付スクリプトは有効だった。画像の公開・URL検証・PR本文編集を個別に組み立てずに済んだため、この部分に新規ツールは必要なかった。

## 4. 素材の準備方法と使い勝手

### 画像・図形

結晶アイコンはオリジナルのSVGを直接記述した。盤面、結晶、中央の識別模様、背景の点、消去粒子はGodotの描画APIで作った。第三者の画像や元ゲームの素材は使っていない。

SVGとコード描画は色・寸法・配置の変更がすぐでき、追加ダウンロードやライセンス調査を要しなかった。色に加えて丸・十字・四角・三角を使い分けられた。一方、手描き風の質感や複雑な背景は作っておらず、装飾の豊かさには限界がある。

### BGM・SE

`AudioStreamWAV` 用の16bit PCMをGDScriptで合成した。BGMは音列を使った8秒のループ、SEは周波数と減衰時間を変えて回転・着地・消去・終了に割り当てた。外部楽曲、音声ファイル、生成サービスは使っていない。

短い音を素早く用意でき、連鎖段数に応じた音程変更も容易だった。反面、音作りは簡素で、今回スピーカーから実際に聴いて評価していない。音楽としての心地よさやループの継ぎ目は未検証。

### フォント

`SystemFont` に日本語フォント候補を設定し、実行環境のフォントを使った。macOSで日本語が描画されることをPNGで確認した。フォントファイルの取得・同梱・再配布はしていない。

すぐ日本語画面を作れた一方、実行環境に依存する。Windows・Linuxで同じ字形や日本語表示を保証する検証は行っていない。

素材の作成方法と外部素材未使用の事実は `games/blockpuzzle/assets/CREDITS.md` に記録した。外部素材サイトや画像生成サービスを使っていないため、それらの使い勝手は今回の経験から評価できない。

## 5. 動作確認の方法

### ロジック

`scripts/dev/selfcheck.gd` をheadlessで実行した。assertだけに依存せず、条件判定・成功失敗表示・終了コードで検査した。

- 盤面寸法、開始、次ペア、壁衝突、壁・床での回転、着地点、横向きペアの独立落下。
- 一時停止中の時間・入力無効化、再開後の自然落下。
- 4個の直交接続、消去待ちの盤面保持、重力後の二連鎖、得点、斜めや3個では消えないこと、複数色の同時消去。
- 出現位置が塞がった場合の終了、再挑戦。
- テスト専用ファイルでの最高記録の読込・更新・別インスタンスによる復元・低得点で記録が減らないこと。
- 固定乱数200手、1,360状態で盤面色、消去対象の重複・境界、操作中と予告ペアの衝突を検査。

最終結果は24項目成功、exit 0。サブエージェントの報告だけでなく `tmp/blockpuzzle-logic.log` を読み、こちらでも `make -C games/blockpuzzle test` を実行して確認した。

### 描画と入力

`scripts/dev/screenshot.gd` をheadlessなしで起動。`Input.parse_input_event` で押下と解放を送り、本体の入力経路で開始・移動・回転・即落下・停止・再開・音切替・再挑戦を確認した。非アクティブ化は通知を明示的に送って停止を検査した。

タイトル・プレイ・消去・二連鎖・停止・結果の6画面をPNGに保存した。プレイ・連鎖には再現用盤面を設定し、結果画面は終了処理を呼び出して撮影した。自然な一局を通しで録画した証拠ではない。

画像を目視し、文字の欠け、盤面の可読性、連鎖文字、結果画面との重なりを確認した。最終の `make -C games/blockpuzzle screenshot` はexit 0、失敗0件、警告・エラーなし。4枚は機械検査と再度の目視を経てPRへ添付した。

### 効いた点と不足

- 純粋ロジックの検証と描画付き入力検証を分けたことで、連鎖の正しさと画面上の問題を別々に発見できた。
- 再現用盤面により二連鎖を短時間で確実に撮れた。
- ログ全文確認により、exit 0のインポートエラーと終了時警告を見落とさずに済んだ。
- 長時間の手動プレイによる難易度・面白さの評価、実際の聴感、Windows・Linux、エクスポートは未検証。
- 描画付きシナリオはキー入力中心で、クリック操作、長押しリピート、ウィンドウサイズ変更を網羅していない。

## 6. Godot固有のハマりどころと回避策

### 存在しないフォーカスイベント型

最初は `InputEventWindowFocusOut` を入力イベントとして扱おうとしてパースエラーになった。Godot 4.7では今回のコードでその型を解決できず、`_notification` の `NOTIFICATION_APPLICATION_FOCUS_OUT` に変更した。

### 自動入力とOS通知の競合

直接の撮影実行では通っても、Makefileからimport直後に描画を起動した検証で、開始後のキー操作が5項目失敗した。ウィンドウのフォーカス通知が自動入力と競合して停止状態になる問題として対処した。

撮影中は自動フォーカス停止を無効にし、別の検査箇所で有効化して通知を明示的に送り、停止を確認する形へ変更した。通常プレイではフォーカス停止を有効にしたまま。変更後のMakefile経由検証は成功した。

### 終了時の音声オブジェクト残留

撮影直後に終了したところ、4件のObjectDB残留警告が出た。`--verbose` で `AudioStreamWAV` と `AudioStreamPlaybackWAV` が対象だと確認した。

撮影スクリプトでBGM・SEをstopし、0.1秒待ってシーンを解放し、フレームを進めて終了すると警告が消えた。全環境共通の仕様と断定せず、今回のmacOS / Godot 4.7で確認できた回避策とする。

### sandboxとuser://・エディター設定

サブエージェントの最初のheadless実行では、ユーザーディレクトリ作成に失敗してexit 134となった。こちらのeditor importでも、exit 0なのに `user://` のObjectDB保存先とエディター設定の保存にERRORが出た。

必要な権限で実行し直して正常動作を確認した。`--log-file` は作業内へのログ保存には使えるが、Godotが行う他のユーザーディレクトリへの書込みまで解決するものではなかった。

### typed Arrayの代入

サブエージェントの検証では、Sessionを型なしで扱った際にtyped Arrayへの代入で実行時エラーが出た。`preload` したスクリプト型でテスト対象を宣言する形に修正した。親側では修正後のコードと成功ログを確認した。

### 描画タイミングと状態遷移

撮影は描画完了を待ってviewportを保存した。ゲーム側では消去対象を0.42秒保持し、その後に削除・重力・次の判定を行うことで連鎖の段階を見せた。結果画面に連鎖表示が残る問題は、連鎖文字をプレイ中・消去中だけ描く条件にして修正した。

## セッション再開

```sh
cd /Users/bannzai/worktrees/bannzai/godotpractice/game/blockpuzzle
codex resume 01a07dec-daaf-7ed3-9c3e-611132745d98
```
