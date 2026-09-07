# survivors 開発のヒアリング

対象は「宵森の灯守」（issue #7、PR #17）。今回の作業で実行した内容と、次回への改善案を分けて記載する。サブエージェントが担当した素材準備・ロジック・負荷計測も含む。

PR: https://github.com/bannzai/godotpractice/pull/17

## 1. 開発の進め方

1. 作業指示書、AGENTS.md、PROJECT.md、issue #7、既存の雛形を読み、10分生存・3武器・成長・200体以上の性能・全export・CI・映像確認までを実装範囲とした。Godot 4.7、gdlint、ffmpeg、export templatesが利用できることも確認した。
2. 「宵森の灯守」という独自の世界観と、状態・描画の分担を決めた。実装方針をknowledgeに記録して最初のコミットをpushし、早期にdraft PRを作った。
3. シミュレーションとselfcheck、素材準備をサブエージェントへ分担した。自分はmainの画面・入力・音声・project設定を担当した。状態名、武器ID、敵・ジェム・演出のデータ、素材パスを先に共有して並行作業をつないだ。
4. autoloadのRunStateに状態を集約し、敵・投射物を個別の物理ノードにせず配列で更新した。タイトル、プレイ、3択強化、休止、勝敗結果、再挑戦をつなげた。
5. lint、import、起動、selfcheckを通し、代表画面を撮影した。さらに実入力イベントを使うinput_check、通常音声を使うaudio_check、600秒のplaythrough、描画付きbenchmarkを追加した。
6. 独立したコード確認で、密集時に範囲攻撃の輪が消える問題と、輪の大きさが攻撃判定と一致しない問題を修正した。各OS向けexport、CI artifactの画像・動画の確認を終えてPRをレビュー可能にした。
7. 追加指示を受け、putsで代表PNG7枚と動画末尾フレームをアップロードし、PR本文へ埋め込んだ。その後、make runの通常起動を確認し、同じ起動経路からタイトルを保存できる開発用処理と、その画像もPRに追加した。

### 詰まった点と解決

- Godotの標準アプリデータとeditor設定、Git worktreeの管理領域、putsのKeychainアクセスがsandbox制限に当たった。対象操作の権限付き実行で進めた。認証情報を表示したり、設定を新規作成したりはしていない。
- importがexit 0でもERRORを残す例があったため、終了コードに加えてログ全文を検査するようゲーム側Makefileを修正した。
- キー番号の推測による左右矢印の誤割り当てを、実入力の結合検証で見つけた。Godot自身が返すキー定数の値を確認して修正した。
- headlessのマウス検証で画面サイズが合わず、クリックが期待するボタンに届かなかった。検証用rootのサイズを1280×720に固定した。
- macOSの全画面切替が非同期で、短すぎる待ち時間では復帰の検証が失敗した。OSの切替完了を待つようにした。
- 通常起動のウィンドウは生成されたが、OSのscreencaptureによる撮影が失敗した。原因を画面収録権限と断定せず、ゲーム自身のビューポートを保存するrun_capture.gdで確認した。

### 進め方の反省

最初の完了報告では、画像・動画の目視はしていたものの、PR本文への画像埋め込みとmake run経路の直接確認がそろっていなかった。追加指示で補完した。次回は「動く」「撮影する」「共有先に貼る」「普段の起動コマンドでも確認する」を最初から完了条件に含める方がよい。

ルートのmake runは、直近の確認時点でmainに未追加だったため、origin/mainの取得と内容確認までで、mergeは行っていない。このヒアリング作成ではmainの再調査はしていない。

## 2. 実際に使ったツール・skill・コマンド

| 道具 | 今回の用途と使い方 |
| --- | --- |
| godot-development skill | 立ち上げ・検証・export・落とし穴の手順を参照。ローカルのSKILL.mdが無かったためGitHub上のSKILL.mdとpitfalls.mdを取得した。Web取得は失敗したが、gh apiで読めた。skill付属のscaffold/verify/install-export-templatesスクリプトは実行していない。雛形とtemplatesは配置済みだった |
| game-asset-search skill | 日本語フォント検索・取得、素材のクレジット記録・記録漏れ検査に使用。search-assets.sh、fetch-asset.sh、record-credit.sh、check-credits.shを実行した |
| Godot CLI / make | `make test GAMES=survivors`、`make screenshot GAMES=survivors`、`make movie GAMES=survivors`、`make build-all GAMES=survivors`、`make build-web GAMES=survivors`、`make -C games/survivors run`を実行。追加検証はGodotの`--script`で直接実行したものもある |
| gdlint / gdformat | 型付きGDScriptのlintと整形。長い行やreturn数などの違反を修正した |
| Python標準ライブラリ | SVGコードの保存、WAV波形合成、PCMとハッシュの検査、設定編集、PR本文の組み立て、公開画像と元PNGの一致確認 |
| ImageMagick | サブエージェントがSVG素材の一覧画像を作成し、スタイル・余白・切れを目視確認した |
| ffmpeg / ffprobe | AVIからmp4への変換、動画の時系列フレーム一覧・末尾フレームの抽出、解像度・fps・フレーム数・長さの確認 |
| puts | `puts upload <PNGのパス>`を実行し、返されたMarkdownをPR本文の「検証」に埋め込んだ。既存の8枚に加え、make runのタイトル画像も添付した |
| curl | 公開画像を取得して、アップロード元PNGとSHA256が一致することを確認。Pythonのurllibでは403になったURLもcurlでは取得できた |
| Git / gh | issue取得、早期draft PR作成、commit・push、PR本文更新、ready化、CI結果取得、`gh run download`によるartifact取得。mainへの取り込み可否確認ではfetchとMakefileの読み取りを行った |
| Swift / CoreGraphics / ps / screencapture | 複数のGodotが同時起動していたため、今回のmakeの子PIDとウィンドウIDを対応付けた。ウィンドウの生成は確認できたが、screencaptureによる画像取得は失敗した |
| サブエージェント | シミュレーション・素材・負荷計測を分担し、通しプレイとコード確認も依頼。画面の統合と最終の画像確認は自分が行った |

フォント取得で実行したコマンドの例:

```sh
bash ~/.agents/skills/game-asset-search/scripts/search-assets.sh --type font --query 'Zen Maru Gothic' --subset japanese --limit 3
bash ~/.agents/skills/game-asset-search/scripts/fetch-asset.sh --family 'Zen Maru Gothic' --dest games/survivors/assets/fonts --list
bash ~/.agents/skills/game-asset-search/scripts/fetch-asset.sh --family 'Zen Maru Gothic' --dest games/survivors/assets/fonts --pick ZenMaruGothic-Medium.ttf
bash ~/.agents/skills/game-asset-search/scripts/check-credits.sh --assets games/survivors/assets
```

image_gen、Gemini画像生成、agent-browser、webtunnel、video-frame-reader skillは今回は使っていない。画像生成モデルへの依頼や外部のBGM・SE素材の検索もしていない。

## 3. 欲しかったが無かったツール・skill・スクリプト

以下は今回の反復を減らせる改善案であり、共有skillや共有CIへの実装はしていない。

- **通常のmake runをそのまま検証する共通の撮影処理。** ウィンドウ生成・タイトルの状態・実描画・正常終了を一度に確認できるもの。今回はゲーム専用のrun_capture.gdを追加した。OSのウィンドウ撮影に依存しない雛形が最初からあれば、後追いの補完を減らせた。
- **Godotの実入力検証の雛形。** キー、パッド、マウス、フォーカス移動、ポーズ、全画面切替を共通化したもの。rootサイズとmacOSの非同期待ちも組み込んでおきたい。InputMapにイベントがあるだけの検査では誤割り当てを見逃す。
- **通常音声とDummy音声を分ける検証の雛形。** 通常ドライバでBGMループとSE・バス出力を確認し、headlessではロジックに集中できる構成。今回はaudio_check.gdを個別に作った。
- **描画付きの負荷試験の雛形。** fps、p95フレーム時間、画面内の実体数、ゲーム時間の進行をまとめて測り、画像も残すもの。今回のbenchmark.gdを他ゲームへ展開できるとよい。
- **撮影からPR画像更新までの一括処理。** make screenshot/movie、目視対象の一覧作成、末尾フレーム抽出、puts upload、公開画像の一致確認、PR本文の該当部分だけの置換までをつなぎたい。アップロード済みURLとコミットの対応を保存し、失敗時に同じ画像を二重アップロードしない仕組みも欲しい。
- **戦闘中の短い録画を作る共通処理。** 移動→攻撃→撃破→ジェム取得→レベルアップを操作込みで録画できれば、静止画では評価しづらい演出の時間変化を確認しやすい。
- **生成音声の検査処理。** 長さ、ピーク、ループ境界、Godot側のループ設定を一緒に確認できると、ファイルの波形とエンジンの再生設定を別々に調べる手間が減る。
- **ゲーム別knowledge変更を考慮したCIの対象判定。** knowledge文書の変更でも全9ゲームが対象になった。単一ゲームの知見更新をそのゲームの検証だけに絞れれば、今回のような文書更新に伴う待ちと実行量を減らせる。

## 4. 素材の準備方法と使い勝手

### 画像

キャラクター、通常敵3種・最終強敵、繰り返し背景、ジェム・アイテム・武器アイコン、タイトル紋章の計13点を、CodexがSVGコードとして作成した。Pythonの`generate_assets.py`でファイルを生成した。画像生成AIによるラスター画像ではない。

青緑の森、金色の灯、ミント色の魔法という共通色を先に決めたため、少ない図形でも識別しやすい素材をそろえやすかった。SVGは余白・色・サイズをコードで修正でき、透過も直接制御できる。生成後は一覧画像とGodot上の画面の両方を見た。2回の再生成でSHA256が一致することも確認した。

今回の小さな見下ろしゲームには扱いやすかった。一方、手描きの質感や複雑なキャラクターアニメーションを作ったわけではなく、その用途での品質・工数は比較していない。

### BGM・SE

外部音源は使わず、独自の音列と波形合成で24秒のBGM、攻撃・被弾・レベルアップ・取得のSE4種を作った。Python標準ライブラリのwave等でPCM16・22,050HzのWAVとして保存した。

曲の長さ、振幅、減衰、再生成をコードで管理できる点は扱いやすかった。検査では最大ピーク約0.201、クリッピングなし、BGMの終端と先頭の差は1PCM以内だった。Godotの通常音声ドライバで実再生、SEごとの再生、バス出力、24秒を越えたループも確認した。

波形の連続性や再生成功は検証できたが、音楽としての聴き心地や長時間プレイ時の疲れを評価する試聴は行っていない。外部のCC0音源と比べてどちらが良いかも、今回は判断していない。

### フォント

Google FontsのZen Maru Gothic Mediumをgame-asset-searchの検索・取得スクリプトで用意し、font.ttfへ改名した。フォントデータ自体は変更していない。OFL全文と著作権表示を同梱し、全exportのinclude_filterにもライセンスを含めた。

フォントとライセンスをまとめて取得でき、日本語の表示をOS依存にしない点がよかった。Godot上の日本語表示と、各形式のパックにライセンス・クレジットが含まれることも確認した。ライセンス文書の末尾空白がgit diff --checkに引っかかった箇所は、本文の意味を変えず空白だけ除去した。

素材源:

https://fonts.google.com/specimen/Zen+Maru+Gothic

https://raw.githubusercontent.com/google/fonts/main/ofl/zenmarugothic/ZenMaruGothic-Medium.ttf

### 記録・配布

CREDITS.mdはrecord-credit.shで記録し、check-credits.shで漏れを検査した。独自生成物を自動的にCC0とせず、生成手段と由来を記録した。フォントは必要な作者表示とOFLを残した。

putsは1画像ごとにPRへ貼れるMarkdownが返るので、その後の編集が簡単だった。一方、複数画像のアップロード結果の保持、公開URLの検証、PR本文の部分更新は別途組み立てた。putsが作業ディレクトリにdefault.profrawを生成したため、一時ディレクトリへ移動し、以後はtmp内から実行した。

## 5. 動作確認の方法・効いた点・不足

| 方法 | 使用状況・効いた点 | 限界・不足 |
| --- | --- | --- |
| headless起動・selfcheck | 使用。シーンロード、出現表の全境界、移動、ダメージと無敵、勝敗・再開、3択と強化上限、複数レベル、3武器の実撃破、回復・吸引、終盤強敵、600秒クリアを検証 | 見た目と実音声は確認できない |
| input_check.gd | 使用。実際のInputEventを流し、左右キーの誤り、headlessのマウス座標、全画面切替の待ちを検出。ローカルとCIに組み込んだ | 物理ゲームパッドは未接続。接続・切断や実機固有の挙動は未検証 |
| screenshot.gd | 使用。タイトル、プレイ、演出途中、強化、敗北、最終強敵、クリアの7枚を描画付きで撮影し目視 | 一時点の形は分かるが、連続した動きの速さ・滑らかさは保証できない |
| movie | 使用。起動からタイトルまでを1280×720・30fps・5秒・150フレームで録画。ffmpegで時系列フレーム一覧と末尾フレームを抽出して目視 | 操作なしのタイトル録画であり、戦闘中の一連の動作は録画していない。固定fps録画から実時間の性能は判断しなかった |
| CI artifact | 使用。GitHub ActionsのXvfb＋llvmpipeで生成した7枚のPNGとmp4をダウンロードして目視。ローカルmacOSとは別環境でも文字・画面が成立することを確認 | Windows/Linux/Webのそれぞれで人間が遊んだ確認ではない。CIで見たのはLinux上のGodot描画と各形式へのexport |
| webtunnel | 未使用。PROJECT.md上にSecretsとWebGL対応の前提が未整備事項としてあったため、ローカルとCI artifactで検証した | ブラウザ上でWeb版を実プレイする確認はしていない |
| 通常のmake run | 使用。個別ゲームのrun targetでウィンドウと起動ログを確認し、開発用環境変数を付けた同じ経路からタイトルを撮影して目視 | OS側のウィンドウ直接撮影は成功していない。代わりにゲームのビューポートを保存した |

### 通しプレイと性能

- playthrough.gdは通常初期状態・通常ルールのまま、移動と強化選択だけを行うbotで600秒生存した。seed 42、撃破5810、レベル89、HP100/100、全3武器最大。実行15.72秒。生存可能性は確認できたが、人間の初見難度や面白さを評価したものではない。
- botは敵近くのジェム回収を後回しにし、後半の磁石回収で大量にレベルアップした。経験値を失わず連続した強化画面を処理できることの確認にもなった。
- benchmark.gdは2秒暖機後、描画完了フレーム間の実時間を10.003秒測定した。Apple M4 Max、GL Compatibility、1280×720、VSync無効で平均119.36fps、p95 9.392ms。同時敵342〜360、画面内最小310、ジェム最小180、演出最大120だった。
- 敵・プレイヤーのHPを増やして計測中の停止や実体数の急減を防いだ負荷条件であり、通常プレイの成績とは分けて扱った。ゲーム時間も10.003秒進んでおり、更新を止めてfpsだけ上げた計測ではない。全PCで60fpsを保証した結果ではない。

### アニメーションの確認

撃破の粒子、ダメージ数字、範囲攻撃の輪は、演出の途中時刻を作ったPNGを見た。タイトルの円弧と光の変化、起動直後の黒画面の有無は、mp4から抽出した時系列フレームで確認した。独立したコード確認で演出の消失と範囲の不整合を見つけ、60体一括撃破後も輪が残る回帰検証を加えた。

戦闘の攻撃から消滅までを連続再生してタイミング・滑らかさを評価する検証は不足している。静止画とロジック検証だけでアニメーション全体を確認済みとは言えない。次回は戦闘の短い操作付き録画を、起動動画とは別に用意したい。

## 6. Godot固有のハマりどころと回避策

| 現象 | 今回の確認・回避策 |
| --- | --- |
| importがexit 0でもERRORを残す | アプリデータやeditor設定への書き込みが失敗していた。実行権限を確保し、importを含めてログ全文のWARNING/ERRORを検査した |
| headlessの短い起動やDummy音声でWAVのPlaybackが残る | verboseログでBGM等のAudioStreamPlaybackWAV/AudioStreamWAVを特定。Dummyでは再生を開始せず、通常ドライバは別途実再生検証した。音声停止と終了の間に時間を置く処理も使用した |
| コマンドライン引数からDummy判定を試しても機能しなかった | AudioServer.get_driver_name()で実ドライバ名を確認する方式へ変更した |
| WAVファイルがつながっていてもGodot側の再生設定は別 | AudioStreamWAV.LOOP_FORWARDと、音源の長さ・mix_rateから求めたloop_endを設定し、音源の長さを越える実再生で確認した |
| headlessでは描画画像を取得できない | selfcheckと、描画付きscreenshot/movie/benchmarkを分離した。画像取得はRenderingServer.frame_post_drawの後に行った |
| headlessのマウス入力が期待座標に当たらない | root.sizeを1280×720へ設定して画面の前提をそろえた |
| 特殊キー番号の推測が誤っていた | GodotのKEY_LEFT/KEY_RIGHT等の実値を確認し、InputMapを修正。存在確認だけでなく入力から画面遷移まで検証した |
| 全画面の切替直後に次の操作をすると検証が失敗する | macOSの非同期切替を待ってから状態確認と次のF11入力を行った |
| 強化前後でphaseが同じだと表示更新を取りこぼす | 選択後に再びupgradeへ入るケースでも、選択処理後に候補UIを再構築するようにした |
| 大量撃破で重要な演出がFIFO上限から押し出される | ダメージ処理後に範囲攻撃の輪を追加する。輪の半径も実際の攻撃範囲を正として計算した |
| 開発機で日本語が見えても別環境では保証されない | 日本語フォントを同梱して全描画に使用し、CIの画像でも文字を確認した。OFLも各exportに含めた |
| Nodeをtree外で作る検証は解放が必要 | selfcheckで生成した状態Nodeやシーンをfreeし、終了時のリーク診断を検査した |
| llvmpipeはVSync変更のWARNINGを出す | 既存Makefileの既知の除外に従った。ゲーム由来のWARNING/ERRORまでまとめて無視することはしなかった |
| 通常起動のOS撮影に依存すると詰まる | makeの子プロセスからウィンドウ生成を確認した上で、同じGodot --path .経路に開発用のビューポート保存処理を追加した。run target自体は変更していない |

再利用価値が高いのは、入力・音声・通常起動・描画負荷の検証を最初から持つことと、画像・動画をPRへ掲載する工程まで含めた手順である。今回のゲーム専用スクリプトとknowledgeはその材料として残した。
