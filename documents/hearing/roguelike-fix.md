# roguelike 手直しラウンドの開発ヒアリング

## 1. 開発の進め方

### 着手前の把握

1. `AGENTS.md`、`documents/PROJECT.md`、issue #40、前ラウンドの PR #54、`documents/knowledge/roguelike.md`、過去のヒアリング文書を読み、既存の受け入れ条件と今回だけの方針を分けた。
2. `make roguelike-run` で既存版を起動し、タイトル、探索、持ち物、地図、結果を見た。前版は「上に HUD、中央に盤面、右に小さいログ、下に共通操作ガイド」という他ゲームにもある構成で、ログが主役になっておらず、次の一手も画面から読み取りにくかった。
3. 既存版と近い `boardrogue`、`deckrogue`、`ghostrogue` のタイトル・地図・プレイ画面も撮り、変更後に識別テストを作れるよう比較元を用意した。

### 実装した順序

1. 先に表示素材の方針を固定した。`game-asset-search` で M PLUS 1 Code を検索・取得し、OFL と著作権表示を確認した。旧 Noto Sans JP、背景・キャラクター・道具・タイル・ロゴの SVG、SVG 生成スクリプト、背景シェーダを外した。
2. `game_data.gd` で主人公・敵・道具・地形を表すグリフと色を定義し直し、`board.gd`、`actor_view.gd`、`effects.gd` を文字描画へ置き換えた。主人公と敵6種に、待機・移動・攻撃・被弾・死亡・登場の文字アニメーションを付けた。
3. `main.gd` と `ui.gd` を組み替えた。画面下約3分の1を `MESSAGE LOG / TURN HISTORY` にし、右欄へ場面ごとに変わる `NEXT ACTION` を置いた。共通操作ガイド行は削除し、3ページの初回チュートリアルと `?` の手引きへ移した。
4. 持ち物画面へ選択ハイライト、使用・装備後のプレビュー、選べない理由を追加した。階層遷移には現在地、到達済み階、未到達階、最終目的を文字で示す地下縦断図を挟んだ。
5. 既存の場面別 BGM / SE の生成方式を残し、`generate_audio.py` に固定シードの12秒環境音を追加した。低い機械音、水滴、活字クリックを合成し、探索中だけ BGM の下で鳴らすよう `sound.gd` を拡張した。
6. 表示と操作の変更に合わせて `selfcheck.gd`、`integration.gd`、`screenshot.gd`、`demo.gd` を更新した。まず headless のロジック検証を通し、次に34画面の撮影、短い起動録画、30秒の実入力デモ、3 OS と Web のエクスポートを行った。
7. 変更前後、近縁3作との識別比較、文字アニメーション、webtunnel の操作フローを比較画像にまとめた。draft PR を段階的に更新し、最後に `puts` 経由で4画像を添付して ready for review にした。

### 詰まった点と解決

- M PLUS 1 Code 単独では `Ω`、`▣`、`▼` が欠字だった。OS の代替フォントを許すとローカルだけ正常に見えるため、`allow_system_fallback=false` と空の fallback を import 設定へ入れ、番人を `W`、古鉄の盾を `H`、地下図の矢印を `v` に変更した。さらに実際に使う文字を `Font.has_char()` で検査した。
- 暗いタイトル画面の動画が、従来の平均輝度32以上という黒画面判定を通らなかった。limited range の黒が約16、正常画面が約16.96であることを `ffmpeg` の `signalstats` で測り、roguelike の閾値を16.5へ変更した。閾値だけに頼らず最終フレームも目視した。
- `movie-play` で回復薬を使おうとした時、体力が満タンなので正しく無効化され、デモだけが失敗した。ゲーム側の制約を緩めず、ターン経過後に有効になる食料を使うデモへ直した。
- webtunnel の実ブラウザ操作で、`W` 1回が2ターンとして処理される不具合が見つかった。キーボード入力を `_input()` で処理した後、`_process()` の `Input.get_vector()` が同じキーを左スティック入力として再度読んでいた。`_process()` は `InputEventJoypadMotion` から保持したスティック軸だけを見るよう変更し、0.3秒キーを保持しても1ターンだけ進む integration を追加した。
- CI artifact の `gh run download` は進捗を出さず長時間継続し、最初は空ディレクトリに見えた。artifact API で名前・サイズ・期限を確認し、実行セッションを終了までポーリングしてから現物を検査した。
- webtunnel を作り直すと CDP の接続先が変わり、古いブラウザセッションが旧接続先を保持した。修正版では別の明示セッション名を使い、`cdp` で新しい IP を取り直した。終了後は workflow とブラウザセッションの両方を閉じた。

## 2. 使ったツール・skill・コマンド

### skill と周辺ツール

- `godot-development`: 既存 Godot プロジェクトの検証構成、headless と描画付き検証の役割分担、ログ全文検査、Movie Maker、CI artifact、WAV 終了時リークの注意点を参照した。雛形生成は行わず、既存の Makefile と `scripts/dev/` を更新した。
- `game-asset-search`: `search-assets.sh --type font --query 'M PLUS 1 Code' --subset japanese` で Google Fonts を検索し、`fetch-asset.sh --list` と `--pick 'MPLUS1Code[wght].ttf'` でフォントと OFL を取得した。画像検索・画像生成は、グリフだけで作る方針のため使っていない。
- `webtunnel`: preflight、`up roguelike --software-webgl --ref fix/roguelike --wait`、`cdp`、`down`、`fetch-recording.sh` を使った。GitHub Actions の Chromium で Web エクスポートを実操作し、録画 artifact を取得した。
- `agent-browser`: webtunnel の CDP へ明示セッションで接続し、キー入力、クリック、画面遷移、スクリーンショット撮影を行った。
- `pr-attach-screenshots`: `attach-screenshots.sh` の dry-run 後に4画像を添付した。内部の `puts upload` と `curl` により、公開 URL の内容とローカル画像の SHA-256 一致まで確認した。事前確認には `puts ls --number 1` を使った。
- `video-frame-reader`: webtunnel 録画とローカルの `movie-play.mp4` から変化フレームを抽出し、それぞれ20枚に絞って確認した。
- `apply_patch`: GDScript、Makefile、CREDITS、知見文書の変更に使用した。

### 主なコマンド

- 調査: `rg`、`git diff`、`git show`、`gh issue view`、`gh pr view`、`gh api`
- フォント取得: `search-assets.sh`、`fetch-asset.sh`
- 音声生成: `python3 scripts/dev/generate_audio.py`
- ロジック検証: `make test GAMES=roguelike`。内部で `gdlint scripts/`、import、boot check、selfcheck、integration を実行した。
- 描画検証: `make screenshot GAMES=roguelike`、`make movie GAMES=roguelike`、`make -C games/roguelike movie-play`
- エクスポート: `make build-all GAMES=roguelike`、`make build-web GAMES=roguelike`
- 実起動: `make roguelike-run`。最後は対象 PID の `Quit Godot` を選び、通常終了でも exit 0 とリークなしを確認した。
- 動画処理: `ffmpeg` / `ffprobe`。AVI から H.264 MP4 への変換、平均輝度の取得、最終フレーム抽出に使用した。
- 比較画像: ImageMagick の `magick montage`。変更前後、識別テスト、全スクリーンショット、動画の変化フレームを一覧化した。
- Git / PR: `git add`、`git commit`、`git push`、`gh pr create --draft`、`gh pr edit`、`gh pr ready`、`gh run download`

## 3. 欲しかったが無かったツール・skill・スクリプト

- **手直しラウンド一括検証コマンド**: `test`、`screenshot`、`movie`、`movie-play`、`build-all`、`build-web`、`run` を順に実行し、全ログの WARNING / ERROR / leak、成果物の存在、スクリーンショット数を1つのレポートへまとめるものが欲しかった。今回は各コマンドとログ検査を個別に行った。
- **撮影マニフェストと比較画像生成**: `screenshot.gd` の撮影名から、全画面の一覧、変更前後、他ゲームとの同役割画面、アニメーションの連続フレームを定型レイアウトで作るスクリプトがあるとよい。今回はファイルを選び、`magick montage` の順序・タイル数・ラベルを個別に組んだ。
- **実使用文字からのフォント検査**: GDScript とシーンに含まれる表示文字を収集し、指定フォントの `Font.has_char()`、system fallback 無効、禁止フォント不在をまとめて検査する仕組みが欲しかった。今回は必要文字列を手で `selfcheck.gd` に列挙したため、新しい文言を足した時の更新漏れがあり得る。
- **Godot Web 入力の定型回帰テスト**: Canvas の起動待ち、ゲーム座標からブラウザ座標への変換、キーを指定時間保持、ターン番号の前後比較、スクリーンショット取得までを webtunnel 上で行うヘルパが欲しかった。今回の二重入力は実ブラウザで初めて見つかり、操作と判定を個別に行った。
- **CI artifact の進捗付き取得・ギャラリー化**: `gh run download` の無出力継続を実行中と判定し、完了後に PNG の contact sheet と MP4 の最終フレームを自動生成するスクリプトが欲しかった。
- **音の検証レポート**: PCM の形式、非無音、ピーク、クリップ、ループ端点、周波数分布、BGM と環境音の音量差を一括表示するものがあると調整が速い。数値検査では聴感の良さまでは保証できないので、そこは別の確認として明示する必要がある。

## 4. 素材の準備方法と使い勝手

| 種類 | 準備方法・素材源 | 使い勝手と判断 |
| --- | --- | --- |
| 画像 | 新規画像は用意しなかった。旧背景・キャラクター・道具・タイル・UI の SVG と生成スクリプトを削除し、`Label`、`RichTextLabel`、`draw_string()`、罫線文字だけで構成した。 | 画像ごとの生成、切り出し、import、ライセンス確認が不要になり、監査と再現が最も簡単だった。形状の自由度は SVG より低いが、その制約が伝統的ローグライクらしさと他ゲームからの識別性につながった。 |
| フォント | Google Fonts の M PLUS 1 Code 可変フォントを `game-asset-search` で検索・取得した。配布元は https://fonts.google.com/specimen/M+PLUS+1+Code、上流は https://github.com/coz-m/MPLUS_FONTS、ライセンスは SIL Open Font License 1.1。`MPLUS1Code[wght].ttf` と `OFL.txt` を同梱した。 | 検索結果から取得ファイル一覧を確認して選べ、OFL の著作権者も取得時に補完されたので扱いやすかった。1書体で日本語、英数字、罫線、キャラクターの線質が揃い、可変 weight も強弱付けに使えた。一方で全 Unicode 記号を持つわけではなく、欠字と OS fallback の検査が必要だった。 |
| BGM / SE | 既存の `scripts/dev/generate_audio.py` を使い、Python 標準ライブラリで場面別 BGM 8曲と操作音7音を再生成した。倍音、FM の鐘、撥弦、リード、パッド、低音、ノイズ打楽器を組み合わせ、外部録音や既存曲は使っていない。 | 固定パラメータから同じ WAV を再生成でき、尺・音量・ファイル名をゲーム側に合わせやすい。多数の音を一括変更できる反面、自然な演奏やミックスの良さはコードと数値だけでは判断しにくい。 |
| 環境音 | 同じ生成器へ固定シードの12秒 `ambience.wav` を追加し、低い機械音、周期の異なる水滴、短い活字クリックを合成した。探索と番人戦だけで -24 dB で重ねた。 | 追加取得や別ライセンスが不要で、端末世界の音を狙った長さ・密度で作れた。単体の非無音や形式は検査しやすいが、BGM との主観的なバランスは実再生または録画での確認が必要だった。 |

`assets/CREDITS.md` にはフォントの配布元・上流・著作権者・OFL、独自合成音源の生成手段・再生成コマンド・第三者素材不使用を記録した。export preset では CREDITS と OFL を各配布物へ含めた。画像生成モデル、フリー画像、外部 BGM / SE 配布サイトは今回使っていないため、それらとの生成品質や探索時間の比較はしていない。

## 5. 動作確認の方法

| 方法 | 今回確認したこと | 効いた点 | 足りなかった点 |
| --- | --- | --- | --- |
| `make test` / headless | import、起動マーカー、gdlint、40シード×5階の地形と到達性、道具・敵・勝敗、クレジット、画像素材不在、必要グリフ、実入力 integration | 高速で繰り返せ、ロジック、参照切れ、欠字、禁止素材の再混入を早期に止められた。0.3秒のキー保持テストは Web 二重入力の回帰防止にもなった。 | headless では実際の描画、文字の重なり、発光、透明度、アニメーション、音を確認できない。ブラウザ固有の入力重複も最初の短い疑似入力では見つからなかった。 |
| `screenshot.gd` | タイトル、手引き、チュートリアル3頁、探索、持ち物、未識別・識別済み道具、ポーズ、拡大地図、地下図、全5階、敵ハイライト、番人、文字効果6種、勝敗・結果、アニメーション6動作を計34 PNG にした。 | UI の重なり、ログの高さ、NEXT ACTION、選択状態、欠字、階ごとの差を固定状態で比較できた。CI の Linux 画像との比較にも使えた。 | 1枚だけでは入力の反応、時間変化、音、フルスクリーン、ゲームパッドの手触りは分からない。撮影スクリプトが誤った状態を作っても画像の目視なしでは気づけない。 |
| アニメーション専用撮影 | 主人公と敵6種を横に並べ、各キャラクター固有のクリップ長に対する開始0%、途中45%、終盤95%を、待機・移動・攻撃・被弾・死亡・登場ごとに停止して撮った。各種攻撃・被弾・レベルアップ・階段・取得・死亡の効果も別画面で撮った。 | 速度の異なるクリップでも同じ割合で比較でき、文字の変形、残像、色、透明度、消滅・登場が全キャラクターに存在することを一度に確認できた。 | 補間中の引っ掛かりや一瞬だけ出る破綻は3時点だけでは見落とせるため、`movie-play` の連続録画も併用した。 |
| `make movie` | 起動から5秒を Movie Maker で録画し、MP4 化、平均輝度ゲート、最終フレーム目視を行った。 | 真っ黒、起動直後の大崩れ、録画終了時リークを機械判定できた。 | 今回は暗いタイトルが中心で、プレイ操作や各アニメーションの全遷移までは含まない。平均輝度は作品ごとに基準が必要だった。 |
| `movie-play` | 30秒の入力デモで、タイトル、探索、持ち物選択、食料の詳細と使用、拡大地図、移動、戦闘、結果、タイトル復帰を録画した。20変化フレームを抽出して目視した。 | 自動テストの状態値だけでなく、入力後の実画面と時間変化をまとめて確認できた。無効な回復薬を使おうとするデモの誤りも検出した。 | 固定シナリオなので全地形・全敵・全入力機器は通らない。音の主観評価を録画の成否だけで保証できない。 |
| CI artifact | Linux/Xvfb/llvmpipe 上の34 PNG、5秒 MP4、ログをダウンロードし、全画面 contact sheet と重要画面、動画末尾を目視した。 | macOS の system fallback に隠れる欠字、OS 間のフォント・描画差、CI 上だけの崩れを確認できた。 | V-Sync 切替非対応の既知 WARNING が混ざる。CI の成功だけでは画像の内容を判断できず、artifact の目視が必要だった。 |
| webtunnel | WebGL2 を有効にした GHA Chromium で、タイトルから結果までキーとクリックで操作し、スクリーンショットと録画を取得した。 | 実 Web ブラウザでのみ表面化した「キー1回で2ターン」を発見できた。修正後は `TURN 000` から `TURN 001` だけ進むことを画像で確認できた。 | Web 版の確認なので、デスクトップ固有のフルスクリーン、物理ゲームパッド、ネイティブ音声出力は保証しない。1280×656 のブラウザ viewport からゲーム座標への換算も必要だった。 |
| `make roguelike-run` / export | macOS の GL Compatibility で通常起動・通常終了、macOS / Windows / Linux / Web の成果物生成を確認した。 | 実行入口、main scene、フォント・音声参照、終了処理、export preset を最終形で確認できた。 | Windows / Linux のネイティブ実行そのものはローカルでは行わず、CI とエクスポート成功で補った。 |

## 6. Godot 固有のハマりどころと回避策

- **`draw_string()` の座標は文字の左上ではなくベースライン**: セル左上へそのまま描くと Label のキャラクターと地形が縦にずれた。フォントサイズを加味する共通のセル中央計算へ寄せた。
- **Node2D の子は親の座標を引き継ぐ**: 盤面の子にした拡大地図・ミニマップへ画面全体の座標を渡すと HUD 側へずれた。盤面のローカル座標へ変換し、PNG で装備値やボタンと重ならないことを確認した。
- **半透明パネルでは背後の ASCII も読めてしまう**: モーダルの文字と盤面の文字が重なり、画像 UI よりノイズが強かった。持ち物、手引き、地下図、拡大地図は不透明パネルにし、背景を見せる通常画面だけ透過を使った。
- **FontFile は OS fallback が欠字を隠す**: ローカルで表示できても Web/Linux では別字形や豆腐になる。font import の `allow_system_fallback=false`、`fallbacks=[]` を明示し、`Font.has_char()` と CI 画像の両方で確認した。
- **可変フォントでも全記号を持つとは限らない**: 見栄えだけで `Ω`、`▣`、`▼` を選ばず、対象フォント内にある `W`、`H`、`v` へ置き換えた。使用文字の検査を表示実装と同時に追加した方が手戻りが少ない。
- **キーボードと `Input.get_vector()` の二重読みに注意**: InputMap にキーボードとスティック軸の両方を割り当てた状態で、イベント入力と毎フレームの action polling を併用すると Web で同じキーを二度消費した。キーボードは `_input()`、スティックは `InputEventJoypadMotion` から保持した軸値、と入口を分けた。
- **短い tap の integration だけでは長押しバグを再現できない**: 実ブラウザのキー入力時間が cooldown をまたいでいた。回帰テストでも0.3秒保持し、ターン増分が1であることを検査した。
- **AnimationPlayer の全キャラクター比較は絶対秒では揃わない**: クリップ長が違うため、`seek(clip.length * fraction, true)` と `pause()` で0%、45%、95%へ固定した。登場の開始と死亡の終盤は透明度も確認対象にした。
- **`process_frame` 待ちだけでは前画面を保存することがある**: screenshot は `RenderingServer.frame_post_draw` まで待ってから viewport texture を保存した。これにより連続する階・モーダル・アニメーション画面を確実に分けた。
- **暗色ゲームでは動画の固定輝度閾値を流用できない**: H.264 の limited range では黒が0ではなく約16になり、正常な暗色画面との差が小さい。`signalstats` の実測でゲーム固有の閾値を決め、最終フレーム目視を必ず併用した。
- **WAV 再生中の終了は ObjectDB / AudioStreamPlaybackWAV のリーク警告になり得る**: 終了前に全 `AudioStreamPlayer` を stop し stream を外し、実時間タイマーと複数フレームを進めて音声スレッドの解放を待った。通常の `Quit Godot` と各自動検証のログを全文検索した。
- **Xvfb/llvmpipe の V-Sync WARNING はアプリ不具合と区別する**: CI では `Could not set V-Sync mode` が出る。既知のドライバ通知だけを狭く除外し、それ以外の WARNING / ERROR / leak は失敗のままにした。
