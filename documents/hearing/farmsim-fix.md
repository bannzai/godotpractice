# farmsim 手直しラウンドの振り返り

対象は PR #81 の、farmsim を「昭和の年賀状に刷った芋版」風へ手直ししたラウンドである。既存の農業・経済・季節・保存・勝敗の仕様は維持し、初見で次の行動が分かることと、ほかのゲームから見分けられることを主眼にした。

## 1. 開発の進め方

### 既存状態と要件の確認

最初に作業指示書、AGENTS.md、PROJECT.md、issue #37、前回の PR #48、既存の知見・ヒアリング、`godot-development` と `game-asset-search` を読んだ。続いて既存版を `make farmsim-run` と `make screenshot GAMES=farmsim` で起動・撮影し、次を変更前の問題として確認した。

- 上部 HUD、下部の横長な操作ガイド、右側パネルという構成がほかのゲームと似ていた。
- 農場と町が同じ画面上に並び、移動している感覚が弱かった。
- 道具を選べても、向いているマスで実行できるか、実行後に何が起きるかが事前に分からなかった。
- 手続き SVG の輪郭と淡い多層背景が、ほかのゲームの生成物と似ていた。

変更前のタイトル・農場・種屋の画像を保存し、後で同じ役割の変更後画面と並べられるようにした。citybuilder、monsterquest、survivalcraft のタイトル・地図相当・プレイ中画面も取得し、最後の識別比較に使った。

### 素材の方針を先に固定

実装前に、色を茶墨・深緑・朱・黄土・古紙色へ絞り、写真は写実的に見せず3値化した質感として使うと決めた。Yomogi は `game-asset-search` の検索・取得スクリプトで Google Fonts から取得した。写真は汎用の検索結果だけではライセンスや原典を追いにくかったため、Wikimedia Commons の個別ファイルページと MediaWiki API で作者、CC0、原寸 URL を照合した。

古紙、山間の農場、にんじん、かぶ、とうもろこし、トマトの6枚を原写真として保存した。検索結果のサムネイルや転載ページは証拠にせず、個別ファイルページを `assets/CREDITS.md` に記録した。

### アセット生成を置き換え

`scripts/dev/generate_assets.py` を Pillow ベースへ変更し、まず画像を一括生成できるようにした。背景は写真をトリミングし、グレースケール化、自動コントラスト、弱いぼかし、固定閾値での3値化、共通パレットへの写像、古紙との乗算、固定座標のかすれ、という順で加工した。作物は写真全体を小さく縮めるのではなく、写真の色面を種・芽・成長・収穫の輪郭マスク内に通した。

キャラクター、小物、地形、UI は固定座標の図形を PNG へ直接描いた。旧 SVG と M PLUS Rounded 1c を削除し、コード・シーン・テストの参照を PNG と Yomogi へ更新した。検証モードは元ファイルを上書きせず一時生成先と比較する形に直し、同じ入力とコードから同じ SHA-256 が得られるようにした。

音は既存14本を維持し、Python の数式合成で8秒ループの農村環境音 `rural_ambience.wav` と、村地図へ移る時の短い木の打音 `map.wav` を追加した。外部録音、既存楽曲、音声生成サービスは使っていない。

### UI と導線を実装

次に画面構成と操作導線を変えた。

- 所持金、日付、体力、出荷、道具、次の一手を右側の「農家の日記」に集約した。
- 共通の下部操作ガイドを廃止した。
- 初回に「母からの手紙」を出し、一つの畑をクワ、種、水の順に操作する短いチュートリアルを追加した。スキップも可能にした。
- 状態を変更しない `Farm.tool_preview()` を作り、日記の説明と畑上の黄緑・朱の対象枠で同じ判定を共有した。
- 農場と種屋の間に独立した版画の村地図を置き、現在地の印が歩く演出と、行き先でできることの説明を追加した。
- 農村環境音は農場と村地図だけで再生し、既存の場面別 BGM・SE と役割を分けた。

機能を足すたびに `make lint`、`make check`、`make selfcheck`、`make integration` を個別に回し、最後にルートの `make test GAMES=farmsim` でまとめて確認した。チュートリアルと村地図経由の種屋については、実際の `InputEvent` を本番シーンへ送る integration ケースも追加した。

### 描画・実操作・CI を順に確認

ローカルで代表画面とキャラクターの連続フレームを撮影し、コンタクトシートで一覧にして目視した。次に起動録画と26秒のプレイ録画を作り、一定間隔のフレームと厳密な最終フレームを抽出した。その後、macOS・Windows・Linux・Web を書き出した。

Web 版は webtunnel の runner 上の Chromium に接続し、新規開始から母の手紙、耕す、植える、水やり、村地図、種屋での購入、翌朝の成長、収穫、出荷、精算、20日目の結果、タイトル復帰まで実入力だけで通した。最後に CI の全ジョブを確認し、`farmsim-screenshot-and-movie` artifact の全 PNG、動画のフレーム一覧、最終フレーム、ログを目視した。比較画像と操作証拠は PUTS へアップロードし、公開画像を読み戻して SHA-256 が原本と同じことを確認してから PR body に載せた。

### 詰まった点と解決

- Codex のサンドボックスでは Godot がエディタ設定領域へ書こうとして import や起動が安定しなかった。`godot-development` の `prepare-sandbox-godot.sh` で作業ディレクトリ内に Godot をコピーし、ad-hoc 署名、self-contained mode、既存 export templates への symlink を用意した。すべての起動ログも作業ディレクトリ内の絶対パスへ向けた。
- 汎用 Web 検索は CC0 写真の候補や原典情報が不安定だった。Wikimedia Commons API で複数ファイルの作者、ライセンス、説明ページ、原寸 URL をまとめて取り、個別ページで最終確認した。
- 写真を単純に二値化すると細部が黒い塊になった。3値化前に弱くぼかし、全画面を約5色へ制限し、作物写真は輪郭マスク内の質感だけに使った。
- Yomogi は小さい文字や薄い茶色だと紙目に埋もれた。主要情報は18px以上と濃い茶墨にし、薄い色は補助文だけに限定した。
- `refresh()` は現在のページとモーダルを破棄するため、新規開始直後に母の手紙を同期的に開くと消えた。農場ページの再構築後に `call_deferred()` で開いた。
- 畑の対象枠を親の `_draw()` で描くと TileMapLayer の下へ隠れた。最後に追加する Node2D overlay の `draw` シグナルで描いた。
- Web の最初の長時間セッションでは、CDP の `keyDown` 応答を待った時間まで長押し時間に含まれ、想定以上に歩いた。さらに証拠取得中もゲーム内時計が進み、60分の runner 上限までに結果へ届かなかった。2回目は `keyDown` 送信直後から実時間を測って所定時刻に `keyUp` を送り、地図・手帳・ベッド確認を開いて待機中の時計を止めた。15分44秒で結果とタイトル復帰まで完走した。
- agent-browser のスクリーンショット保存がタイムアウト表示になっても、少し後に PNG が生成されている場合があった。同じ入力や撮影を即座に再送せず、ファイルの存在と現在画面を別の読み取りで確認した。
- 最初の通常起動確認はウィンドウへの終了操作が届かずコマンドが exit 2 になった。対象プロセスだけを終了し、`RUN_FLAGS='--quit-after 300'` で再実行して exit 0 とログの正常終了を確認した。

## 2. 使ったツール・skill・コマンド

| ツール・skill | 実際の用途 |
| --- | --- |
| `godot-development` | Godot 4.7 の検証構成、ログ全文の判定、描画付き screenshot / movie、CI artifact、サンドボックス用 self-contained Godot の手順を参照した。`prepare-sandbox-godot.sh` も実行した。 |
| `game-asset-search` | 検索・手続き生成・ライセンスの使い分けを決め、Yomogi の検索、添付一覧確認、TTF と OFL の取得に `search-assets.sh` / `fetch-asset.sh` を使った。Wikimedia Commons 写真は同 skill のライセンス方針に従ったが、取得自体は MediaWiki API と `curl` を使った。 |
| Godot 4.7 stable | import、headless 起動、selfcheck、integration、実描画、Movie Maker、デスクトップと Web の export に使った。レンダラは GL Compatibility のままにした。 |
| `make` | `lint`、`check`、`selfcheck`、`integration`、`test`、`screenshot`、`movie`、`movie-play`、`build-all`、`build-web`、`farmsim-run` の共通入口にした。 |
| `gdlint` / gdtoolkit 4 | GDScript の lint。開発途中は単独 target、最終確認は `make test` 内で実行した。 |
| Python 3 + Pillow | CC0 写真のトリミング・3値化・減色・古紙合成、キャラクター・小物・UI の PNG 描画、コンタクトシート作成、決定的な WAV 合成に使った。 |
| Web 検索、MediaWiki API、`curl`、`jq` | CC0 写真候補の探索、作者・ライセンス・作品ページ・画像 URL の取得、原写真のダウンロードに使った。 |
| `ffmpeg` / `ffprobe` | AVI から mp4 への変換、動画の長さ・fps・解像度確認、一定間隔のフレーム一覧と厳密な最終フレームの抽出、末尾輝度の検査に使った。 |
| `webtunnel` | GitHub Actions runner で Web export と Chromium を起動し、Tailscale 経由の CDP 接続を作った。`up farmsim --software-webgl --ref fix/farmsim --wait`、`cdp farmsim`、`down farmsim`、録画取得を使った。 |
| `agent-browser` | セッション名 `farmsim` を明示し、runner 上の Godot Web 版へキー入力、クリック、JavaScript 状態確認、console / page error 確認、スクリーンショット取得を行った。 |
| `view_image` | ローカル、Web、CI の PNG と、比較・コンタクトシート・動画抽出フレームを原寸で目視した。 |
| `pr-attach-screenshots` / PUTS | `attach-screenshots.sh` の dry-run 後に11枚をアップロードし、PR body の画面証拠区間を更新した。動画の厳密な最終フレームには同 skill のスクリプトも使った。 |
| Git / GitHub CLI | 差分・禁止物・作業ツリー・個人情報を検査し、3コミットの作成、push、draft PR の作成・更新、CI の監視、artifact の取得、ready 化に使った。マージは行っていない。 |
| `rg` | SVG、禁止フォント、WARNING / ERROR、参照漏れ、変更範囲の検索に使った。 |

最終的に実行して exit 0 を確認した中心コマンドは次のとおり。

```bash
python3 scripts/dev/generate_assets.py --verify
make test GAMES=farmsim
make screenshot GAMES=farmsim
make movie GAMES=farmsim
make -C games/farmsim movie-play
make build-all GAMES=farmsim
make build-web GAMES=farmsim
make farmsim-run
```

`game-asset-search` の `check-procedural-assets.sh` は今回そのままでは使っていない。今回の生成器が Pillow 入力写真を含む独自構成だったため、`generate_assets.py --verify` に、全 PNG と追加 WAV の一時再生成・SHA-256 比較、全16 WAV の PCM 形式・無音・クリッピング検査を実装して実行した。

## 3. 欲しかったが無かったツール・skill・スクリプト

### Wikimedia Commons 取り込みスクリプト

ファイル名または検索語を渡すと、MediaWiki API から原寸 URL、作者、ライセンス、作品ページを取得し、原写真を保存して、加工物との対応を CREDITS に記録・検査するものが欲しかった。今回は検索、API クエリ、HTML を含む作者欄の確認、保存名の対応、CREDITS 記入を手でつないだ。`game-asset-search` への追加候補である。

### 版画加工の比較生成器

同じ写真について二値化、3値化、ぼかし量、閾値、共通パレットを小さなコンタクトシートへ自動出力し、色数・寸法・SHA-256 も添えるスクリプトがあると調整が速かった。今回は生成器を書き換えてゲームを import・撮影する往復で比較した。

### webtunnel の時間指定長押し

`keydown` の送信完了を待たず、指定ミリ秒後に必ず `keyup` を送って両方の結果を回収するヘルパが欲しかった。遠隔 CDP の応答時間を押下時間に混ぜないこと、応答不明時に同じ入力を再送しないこと、長時間操作中はゲームを一時停止状態へ置くことまで `webtunnel` の Godot 向け手順へ入れられる。

### Godot の画面証拠一括生成

`screenshot.gd` の全 PNG、キャラクター連続フレーム、movie / movie-play の間引きフレームと末尾、CI artifact を一つの索引画像へまとめ、期待枚数と不足画面を検査する仕組みが欲しかった。`pr-attach-screenshots` はアップロードと PR body 更新を自動化できたが、比較画像・フレーム一覧の組み立てと目視対象の整理は別の一時スクリプトで行った。

## 4. 素材の準備方法と使い勝手

### 画像とテクスチャ

原写真は Wikimedia Commons の CC0 作品を使った。

- 古紙: Old Paper texture、leonardoai
  https://commons.wikimedia.org/wiki/File:Old_Paper_texture.jpg
- 山間の農場: Farm in rural setting、Percy Benzie Abery / National Library of Wales
  https://commons.wikimedia.org/wiki/File:Farm_in_rural_setting_(1293838).jpg
- にんじん: Carrots on Display、MarkBuckawicki
  https://commons.wikimedia.org/wiki/File:Carrots_on_Display.jpg
- かぶ: Turnip-5743、Hans Braxmeier
  https://commons.wikimedia.org/wiki/File:Turnip-5743_-_Hans_Braxmeier.jpg
- とうもろこし: Corn 001、Ocdp
  https://commons.wikimedia.org/wiki/File:Corn_001.jpg
- トマト: Tomato (259888895)、Carola Hornbach
  https://commons.wikimedia.org/wiki/File:Tomato_(259888895).jpeg

Wikimedia Commons は個別ページと API に作者・ライセンス・画像 URL がそろい、public リポジトリに入れる根拠を追跡しやすかった。一方で、一般検索から狙った構図と CC0 を同時に満たす写真を探す精度は低く、ファイル名の違い、作者欄の HTML、候補の差し替えを手で処理する必要があった。

版画化では、古い白黒写真の大きな山・農地の面と、弱い繊維模様の古紙が扱いやすかった。細部の多いカラー写真を単純に二値化すると黒く潰れ、写真らしさを残した多色表現は UI と衝突した。弱いぼかし、3値化、約5色の共通パレット、固定したかすれを組み合わせると安定した。PNG は画素結果をそのまま目視でき、前回の SVG のような外部ビューアと Godot の解釈差を避けやすかった。ただし原写真の探索、各作品のライセンス確認、原本保管、閾値調整の手間は手続き SVG より大きい。

画像生成モデルは使っていない。今回の指定が CC0 写真の加工であり、原典・加工経路・再生成性を残す方が目的に合ったためである。

### BGM と効果音

既存14本と追加2本はすべて Python の数式合成による 22050 Hz・16 bit・stereo PCM WAV である。外部素材探しや帰属が不要で、同じコードから同じ音を再生成でき、無音、クリッピング、最大振幅、ループ端点を数値で検査しやすかった。短い木の打音や周期的な風・せせらぎ・鳥のような環境ループには向いていた。

一方、数式合成と数値検査だけでは、音色が本当に農村や昭和版画の雰囲気に合うか、長時間聴いて疲れないか、BGM・SE・環境音のミックスが心地よいかは保証できない。今回も形式、ループ境界、非無音、クリッピングなし、ゲーム内再生までは確認し、聴感の最終評価は人間の好みとして分けた。

### フォント

Yomogi Regular を Google Fonts から `game-asset-search` のスクリプトで取得し、上流の `OFL.txt` と Copyright 2020 The Yomogi Project Authors を同梱した。

https://github.com/google/fonts/tree/main/ofl/yomogi

検索、添付一覧、TTF、OFL、著作権者を一つの流れで確認できる点は使いやすかった。細い手書き線は日記帳と版画に合ったが、小さい補助文字を薄色にすると古紙へ埋もれた。フォントを選ぶだけで終わらず、Godot の実画面でサイズとコントラストを再調整する必要があった。

## 5. 動作確認の方法

### headless の check・selfcheck・integration

`make test GAMES=farmsim` で lint、起動、selfcheck、integration、アセット、終了処理をまとめて検査した。起動ログの `farmsim boot`、selfcheck の `selfcheck OK`、integration の成功、ログ全文の WARNING / ERROR / 終了時リークなしを確認した。

selfcheck は農業、経済、季節、保存・再開、通行可能な保存位置、PNG と Yomogi の読み込み、アセット条件のような決定的な状態検証に効いた。integration は InputMap に定義があるだけでなく、実際のキー・ボタンイベントを本番シーンへ送り、タイトル開始、農作業、モーダル、チュートリアル、村地図、種屋への遷移を確認できた。

headless では描画されないため、文字の重なり、紙目への埋没、対象枠の描画順、アニメーションの見た目、黒画面は分からない。音も形式と再生開始の確認はできるが、聴感は判定できない。

### `screenshot.gd`

`make screenshot GAMES=farmsim` で、タイトル、母の手紙、実行可能・不可能な対象枠、村地図、種屋、春・夏、夜、勝敗など代表21画面と、3キャラクター×6動作×3時点を含む計39 PNG を生成した。画面一覧とキャラクター一覧のコンタクトシートを作って全画像を目視した。

これは静的な UI 崩れ、表示漏れ、対象枠の色、フォントの可読性、各アニメーションが開始・途中・終盤の異なる絵へ到達することの確認に効いた。ただし数枚の静止画だけではフレーム間の速度、引っかかり、入力への反応速度までは分からない。

### movie とアニメーション

`make movie GAMES=farmsim` では5秒・150フレームの起動録画を作り、真っ黒でないことを末尾輝度でも検査した。`make -C games/farmsim movie-play` では、春10日・840 G・隣に収穫可能なかぶ1個という開始条件だけを固定し、その後は実 `InputEvent` で耕す、植える、水やり、収穫、出荷、就寝、目標達成、結果、タイトル復帰まで26秒・780フレームを録画した。

ffmpeg で2秒間隔の一覧と最終フレームを作り、操作の連続性とアニメーションを確認した。キャラクター固有の全動作は `screenshot.gd` の3時点、実プレイで使う農作業動作は movie-play の連続映像、起動時の描画は movie という分担にした。これは一枚だけの代表画像より有効だったが、全アニメーションを人間が等速で長時間見た官能評価までは行っていない。

### CI artifact

最終コミット `7597fa9` の CI run は全ジョブが成功した。

https://github.com/bannzai/godotpractice/actions/runs/34113445896

`farmsim-screenshot-and-movie` artifact をダウンロードし、全 PNG、mp4 の間引きフレーム、厳密な最終フレーム、ログを確認した。macOS ローカルだけでなく Linux + Xvfb + llvmpipe でも同じ描画スクリプトが動くことを確認できた。llvmpipe で V-Sync 変更を利用できない警告は screenshot / movie ログに各1件あったが、ゲーム由来の ERROR と終了時リークはなかった。

CI artifact は再現可能な証拠として有効だが、GPU、入力機器、音、ウィンドウ操作はローカルのデスクトップ環境と同じではない。

### webtunnel

最終経路は次の run で確認した。

https://github.com/bannzai/godotpractice/actions/runs/34111162811

runner 上の Chromium で、タイトルから結果・タイトル復帰まで実際のキー入力とクリックだけで操作した。ゲーム状態の注入は使っていない。結果は所持金165 G、売上60 G、出荷1個で、操作内容と一致した。console は Godot 4.7、WebGL 2.0、`farmsim boot` だけで、page error は0件だった。15分44秒の録画を1分間隔の16フレームと厳密な最終フレームへ変換し、黒画面や描画崩れがないことを目視した。

WebGL の実ロード、ブラウザ内の文字・UI、実入力、長いゲーム進行を確認できた点が最も有効だった。一方、遠隔 CDP は長押し時間とスクリーンショット取得の応答が不安定で、ゲーム内時計が実時間で進む設計との相性が悪かった。Web 版の確認なので、デスクトップ固有のフルスクリーン切替、ゲームパッド、OS ごとのウィンドウ挙動は保証しない。

## 6. Godot 固有のハマりどころと回避策

- **headless では見た目を検証できない。** `make test` だけで完了せず、描画付きの `screenshot.gd`、Movie Maker、ローカル起動、Xvfb 上の CI artifact、Web export を組み合わせた。
- **サンドボックスでは Godot の書き込み先が原因で止まる。** 作業ディレクトリ内へコピーした Godot を ad-hoc 署名し、self-contained mode にして、既存 export templates を symlink した。起動時の `--log-file` は作業ディレクトリ内の絶対パスにした。
- **素材追加後は import 生成物も確認する必要がある。** PNG、JPG、WAV、TTF を追加した後に `make import` を通し、対応する `.import` と UID、参照切れを確認した。`.godot/` はコミットしなかった。
- **CanvasItem の親の描画は子より前に描かれる。** 親の `_draw()` に対象枠を置くと不透明な TileMapLayer に隠れたため、最後に追加した Node2D overlay から描いた。
- **UI を再生成するとモーダルも消える。** `refresh()` 後に初回モーダルを `call_deferred()` で開き、再開時のチュートリアル状態も明示的に解除した。
- **プレビュー処理が状態を変えると UI 更新だけでゲームが進む。** `Farm.tool_preview()` を状態変更のない関数にし、実行関数と分離した。同じ結果を日記とワールドの対象枠で共有した。
- **別画面の背後で時間や入力が進みやすい。** 農場と村地図を独立した `mode` にし、地図、手帳、モーダルの間は農場の時計と移動を止めた。Esc / B の帰還とボタンのフォーカス移動も実入力テストへ入れた。
- **InputMap の存在確認だけでは操作可能性を証明できない。** 押下と解放を対にした `InputEventKey` / ボタンイベントを本番シーンへ送り、画面遷移と状態変化まで integration で検査した。
- **WAV を再生したまま SceneTree を終了するとリーク警告が出る。** 通常終了では音声停止後にフレームを進め、Movie Maker では終了12フレーム前に `stop_audio()` を呼び、`_exit_tree()` でも停止した。
- **SVG は外部ビューアと Godot で透明色の結果が異なることがある。** 前回の `#RRGGBBAA` では Godot 上で雲や影が黒くなった。今回の指定に合わせて SVG をすべて除去し、Pillow が描いた最終画素の PNG を使った。
- **細い手書きフォントと紙テクスチャは実画面で調整が要る。** Yomogi の主要文字を18px以上・濃い茶墨にし、代表画面を原寸で確認した。
- **Web export の canvas とゲーム解像度が一致するとは限らない。** runner の Chromium は1280×656、ゲームは1280×720だったため、左右の余白と縮尺を含めてクリック座標を写した。Godot の開始完了、WebGL 2.0、canvas の矩形を JavaScript で確認してから操作した。

今回の知見から、`game-asset-search` には Wikimedia Commons の原写真・ライセンス・加工物・CREDITS を一括で結ぶ仕組み、`webtunnel` には応答遅延を押下時間へ混ぜない長押しヘルパ、`godot-development` には UI と対象枠で共有する状態非変更プレビューとページ再生成後の初回モーダルの例を追加すると、次回の手作業と再発調査を減らせる。
