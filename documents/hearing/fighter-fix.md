# fighter 手直し開発ヒアリング

## 1. 開発の進め方

### 全体の順序

1. 依頼書、issue #4、既存コード、`documents/knowledge/fighter.md`、素材規約を読み、変更してよい範囲と維持する戦闘仕様を確認した。
2. 変更前のタイトル、キャラクター選択、対戦画面を撮影して保存した。近隣ゲームの画面も確認し、fighter の弱点を「画面ごとの役割が似ている」「細い手続き生成キャラクターで他ゲームとの差が弱い」「共通フッターと操作対象が離れている」と整理した。
3. UIを先に描き替えるのではなく、今回の見た目を決めるキャラクター、街、フォントを検索した。横向きの格闘動作、同じ画素密度、publicリポジトリへ同梱可能という条件で候補を絞った。
4. ChasersgamingのCC0素材3点とDela Gothic Oneを採用し、元素材を保存した。既存の戦闘コードが要求する「2人、各22動作、各8フレーム」を変えずに済むよう、PythonとPillowによる決定的なPNG生成処理を作った。
5. 生成したキャラクター、ポートレート、東京・ソウル・リオの会場、世界地図、UI部品、演出をGodotへ接続した。タイトル、キャラクター選択、世界地図、対戦、結果の順に画面を刷新した。
6. 初戦だけ表示する3段階チュートリアルを追加した。移動、通常技、必殺技を実際に入力して進め、完了またはスキップするまではCPU、タイマー、投射物を止めた。画面下の共通操作ガイドは廃止し、各画面の操作対象の近くへ説明を移した。
7. 観客のざわめき、手拍子、笛を含む環境音を固定乱数で生成し、世界地図と対戦中だけ低音量で流した。旧SVGと旧Noto Sans JPはランタイム素材から外した。
8. 実装途中から `make test` と `make screenshot` を繰り返し、ロジック、素材境界、レイアウトを修正した。完成後に録画、全プラットフォームのexport、通常起動、終了処理、Web実操作、Linux CI artifactの順で検証範囲を広げた。
9. 変更前後、他ゲームとの識別、実入力録画の連続フレーム、Web実操作を比較画像にまとめ、`puts`で公開してPR本文へ掲載した。最後にCIを再確認し、PRをReady for reviewへ変更した。

### 詰まった点と解決

- OpenGameArtには利用可能な候補自体は多かったが、GIFだけの素材、正面・斜め向き中心の素材、必要な攻撃動作が少ない素材、2人で画素密度が揃わない素材が多かった。ライセンスだけで決めず、「横向き」「パンチ・キック・被弾」「同じ作者」「同程度の解像度」を優先し、Vigilante、Soldier、Market Streetへ絞った。
- CC0の2人にも、しゃがみ、空中、ガード、K.O.を含む22動作は揃っていなかった。既存フレームの順序変更、位置ずらし、nearest-neighbor拡大、回転、縦つぶし、色替えを決定的なスクリプトへまとめ、戦闘側のanimation APIを変えずに補った。
- K.O.姿勢などを回転すると、不透明部分がAtlasTextureのセル端へ達し、隣の動作が混ざった。`filter_clip`とnearest filterだけでは防げなかったため、生成時に使用領域をセル境界から2px内側へ移動し、全352セルの外周が透明であることをselfcheckへ追加した。
- チュートリアルのスキップと弱キックが同じ入力なので、スキップ直後に攻撃が出る可能性があった。決定に使ったボタンが離されるまで戦闘側の攻撃を抑止した。
- webtunnel上では `agent-browser press` の押下と解放が同一描画フレームへ収まり、移動や必殺技の入力履歴へ残らない場合があった。移動と通常技はkeydownとkeyupの間を複数フレーム空け、必殺技は下、斜め下前、前、攻撃のKeyboardEventを80ms間隔でcanvasへ送った。
- Codexのworkspace-writeサンドボックスでは、Godotのユーザーログやエディタ設定への書き込みが原因で、通常起動が`Abort trap: 6`になり、exportログにも権限エラーが出た。失敗ログを成功扱いせず、許可されたmacOSネイティブ実行で同じコマンドをやり直し、exit 0とログ全文を確認した。
- `puts`は当初Keychainの読み取りが`OSStatus -25291`で失敗した。新しいキーは発行せず、設定済みのGitHub画像用R2認証を環境変数経由で利用した。値はログやファイルへ書かなかった。
- 他ゲームとの比較用撮影では、platformerとkartraceはexit 0だったが、shooterの撮影はPNG生成後に既存の`add_child`／`grab_focus`エラーでexit 2になった。fighterの検証結果には混ぜず、生成済み画像だけを視覚比較の参考として使い、範囲外のshooterは変更しなかった。

## 2. 使ったツール・skill・コマンド

### skill

| skill | 実際の用途 |
| --- | --- |
| `godot-development` | Godot 4.7の検証構成、headlessで確認できる範囲、描画付きscreenshot／movie、ログ全文検査、export、sandbox、終了時の音声リークに関する手順を参照した。 |
| `game-asset-search` | OpenGameArtの画像検索、作品ページの添付一覧確認、CC0素材の取得、Google Fontsの検索・取得、ライセンスとCREDITSの記録方針に使った。 |
| `webtunnel` | GitHub Actions上で自分のブランチをWeb exportし、Tailscale越しのChromiumへ接続した。起動前のpreflight、`up`、`cdp`、録画取得、`down`まで使った。 |
| `agent-browser` | webtunnelの専用CDPへ名前付きセッションで接続し、タイトルから0–2の結果画面までキーボード操作、JavaScriptによる時間差KeyboardEvent送信、スクリーンショット取得に使った。 |
| `commit` / `commit-create-pr` | 差分、秘匿情報、電話番号、検証結果を確認して日本語コミットを作成し、pushとDraft PR作成に使った。 |

### 主なコマンドとライブラリ

| ツール・コマンド | 実際の用途 |
| --- | --- |
| `search-assets.sh` | `fighter sprite`、`brawler character`、`martial arts character`、`Dela Gothic One`などを検索した。 |
| `fetch-asset.sh --list` / `--pick` | OpenGameArtの添付ファイル名と配布URLを確認し、Vigilante、Soldier、Market Streetを取得した。Dela Gothic OneのTTFとOFLも取得した。 |
| Python 3 + Pillow | `generate_pixel_assets.py`でキャラクタースプライト、ポートレート、会場、世界地図、UI、演出を生成した。比較画像と連続フレーム一覧の作成にも使った。 |
| Python標準ライブラリ `wave` / `random` / `math` | `generate_audio.py`で既存BGM・SEと、新しい観客環境音を固定入力から生成した。 |
| `make pixel-assets` | 元PNGとフォントからランタイム用PNGを再生成した。同じバイト列のPNGは書き直さない。 |
| `make test GAMES=fighter` | `gdlint`、headless起動、752条件のselfcheckをまとめて実行した。 |
| `gdlint` | GDScriptのlintに使用した。最終結果はexit 0。 |
| `make screenshot GAMES=fighter` | `scripts/dev/screenshot.gd`から63枚の代表画面を生成した。 |
| `make movie GAMES=fighter` | Godot Movie Makerで5秒の起動動画を作り、真っ黒でないことと音声を確認した。 |
| `make -C games/fighter movie-play` | 実入力シナリオで29秒、30fps、870フレームの対戦動画を作った。 |
| `ffmpeg` / `ffprobe` | Movie Makerの出力変換、末尾フレーム・0.1秒間隔フレーム・contact sheet用フレームの抽出、動画情報と音量の確認に使った。 |
| `make build-all GAMES=fighter` | macOS、Windows、Linuxをexportした。 |
| `make build-web GAMES=fighter` | webtunnelで使うWeb版をローカルでもexportした。 |
| `FIGHTER_VERIFY_RUN=1 make fighter-run` | エディタなしの通常起動経路を使い、Godot自身の撮影と`fighter run OK`を確認して自動終了した。 |
| `make -C games/fighter shutdown-check` | 通常終了と`--quit-after`相当の終了でWARNING、ERROR、リークがないことを確認した。 |
| `gh run list` / `gh run view` / `gh run download` | CIの全jobを確認し、`fighter-screenshot-and-movie` artifactを取得した。 |
| `puts upload` | 変更前後、他ゲームとの比較、連続フレーム、Web実操作の4枚を公開R2へアップロードした。 |
| `gh pr create` / `gh pr edit` / `gh pr ready` | Draft PR作成、検証結果と画像を含む本文更新、Ready for reviewへの変更に使った。 |
| `rg` / `git diff` / `git status` | 旧SVG・旧フォント参照、WARNING／ERROR、秘匿情報、変更範囲、作業ツリーの検査に使った。 |

`image_gen`は使っていない。今回は、要求されたCC0の出典が明確なドット絵を基にし、その作者固有の体格やポーズを残した方が、手続き生成や画像生成モデルだけで作るより狙いに合った。

## 3. 欲しかったが無かったツール・skill・スクリプト

- OpenGameArtの作品URLを渡すと、作品名、作者、CC0表示、Public Domain notice、添付ZIPの直URL、取得ファイルのSHA-256、加工後ファイル、CREDITSの項目を1つのmanifestへまとめるツールが欲しかった。今回は作品ページ、展開したZIP、配置先、CREDITSを手で対応付けた。
- 素材候補のGIF、PNG strip、ZIP内のスプライトシートを同じ表示倍率のcontact sheetへ変換し、「横向き」「最低限ある動作」「フレーム数」「画素密度」を一覧比較する検索補助が欲しかった。検索結果を開いて一枚ずつ確認する時間を減らせる。
- スプライトシートのセル数、透明外周、隣セルへのはみ出し、使用領域、フレーム差分を一括表示するatlas検査ツールが欲しかった。今回の352セル検査はselfcheckへ実装したが、視覚的な差分一覧とGodotのSpriteFrames生成まで一体化すると再利用しやすい。
- Godot用の「実入力シナリオ → 録画 → 短い動作区間だけ高密度抽出 → contact sheet → PR用比較画像」を1コマンドで実行するスクリプトが欲しかった。2秒間隔だけでは短いジャンプや必殺技を見逃すため、今回は該当区間を調べて0.1秒間隔で追加抽出した。
- webtunnel上のGodot canvasに対し、ゲーム座標からブラウザ座標への変換、指定時間のkeydown／keyup、波動拳のような連続入力を宣言的に書ける補助が欲しかった。`agent-browser press`だけでは入力時間が短すぎるケースを個別のJavaScriptで補った。
- 変更前後と複数ゲームのスクリーンショットを、同じクロップ・寸法・ラベルで並べ、`puts upload`とPR本文更新まで行う比較画像ツールが欲しかった。今回は画像選定、合成、アップロード、URL差し込みを別々に行った。
- sandboxでGodotを実行した時に、権限問題、ゲーム側エラー、既知の描画ノイズを分類して次の実行方法を提示する診断が欲しかった。`godot-development`には`prepare-sandbox-godot.sh`があるが、通常起動・全export・macOS描画付き検証まで一貫して切り替える入口はまだ無い。今回は許可されたネイティブ実行で確認した。
- `puts`のKeychain利用可否を事前診断し、利用可能な既存認証へ安全に切り替えるラッパーが欲しかった。認証値を表示せずに、アップロード可能かだけをpreflightできるとよい。

## 4. 素材の準備方法と使い勝手

### 画像

- OpenGameArtを`game-asset-search`の`search-assets.sh`で検索し、`fetch-asset.sh --list`で実ファイルを確認してから取得した。
- 採用したのは、ChasersgamingのCC0素材 `Brawler Asset Character 'Vigilante' SMS`、`RPG Asset Character 'Soldier' SMS`、`Brawler Asset Tile Set 'Market Street' SMS`。同じ作者なので輪郭、配色数、16px級の画素密度が揃い、別々の作者の素材を混ぜるより加工しやすかった。
- OpenGameArtはCC0の小規模素材を探すには有効だった。一方、検索語だけでは向き、収録動作、実ファイル形式、フレーム数を判断できず、作品ページと配布物の目視が必要だった。ライセンスが適合しても、格闘ゲームで使えるとは限らない。
- 元PNGはリポジトリに保存し、Pillowでnearest-neighbor拡大、色替え、切り出し、反転、位置ずらし、回転、縦つぶしを行った。ランタイム用の2人×22動作×8フレーム、ポートレート、3会場、世界地図、UI、エフェクトを一括生成した。
- Market Streetは正方形の素材なので、そのまま横長会場には使えなかった。左右反転、色調補正、独自の観客、床、照明、看板を重ね、東京・ソウル・リオに展開した。Pillowはピクセル単位の制御と決定的再生成には使いやすいが、足りない人体ポーズを自然に補う部分は手作業の割り当て判断が多かった。
- 旧ラウンドの手続き生成SVGはセル寸法と再現性を管理しやすかった反面、輪郭や陰影が幾何学的で、他ゲームとの差が弱かった。CC0の手描きドット絵は少ない色でも作者の癖と情報量があり、特色化には有効だった。

素材源:

https://opengameart.org/content/brawler-asset-character-vigilante-sms

https://opengameart.org/content/rpg-asset-character-soldier-sms

https://opengameart.org/content/brawler-asset-tile-set-market-street-sms

### BGM・SE

- 今回は外部のBGMやSEを新規取得していない。既存のBGM・打撃SEは`generate_audio.py`による正弦波、倍音、FM、ノイズ、エンベロープの手続き生成を継続利用した。
- 新規の観客環境音も同じPythonスクリプトで作り、固定seedのノイズへ、ざわめき、手拍子、笛を重ねた。10秒以上のWAVをForward loopにし、世界地図と対戦だけで再生した。
- 手続き生成は権利関係が明確で、再生成一致、非無音、クリップ、最大音量を自動検査しやすかった。反面、数値検査では音色、賑やかさ、BGMとの混ざり方の良し悪しまでは判断できないため、録画の音声を実際に再生して確認する必要があった。

### フォント

- Google FontsからDela Gothic Oneを検索し、`fetch-asset.sh`で`DelaGothicOne-Regular.ttf`と`OFL.txt`を取得した。Copyright表示、OFL-1.1全文、上流URLを確認し、フォントファイルは無改変で同梱した。
- Dela Gothic Oneは日本語と英数字を同じ太い形で表示でき、90年代アーケードの見出し、大きなK.O.、タイトルロゴに合った。Google Fontsは配布元とライセンスが整理されており、画像素材より採否判断が速かった。
- 小さい補足文では太さと字間のため窮屈になりやすい。本文を小さく詰め込まず、短い文へ分けて操作対象の近くへ置いた。

### 出典管理

- `games/fighter/assets/CREDITS.md`へ元素材名、作者、URL、ライセンス、同梱ファイル、加工内容を記録した。
- Dela Gothic OneのOFL全文を保持し、export presetから配布物へ含めた。
- selfcheckで素材ファイルのクレジット記録漏れ、旧SVGと旧フォント参照、生成物の寸法とセル境界を検査した。

## 5. 動作確認の方法

### headlessのselfcheck

- `make test GAMES=fighter`でgdlint、headless起動、selfcheckを実行し、最終的に752条件が成功した。
- 戦闘ロジック、画面状態、チュートリアルの停止条件、入力抑止、素材の存在と寸法、全352セルの透明外周、音声のloop設定、CREDITSを機械的に確認するのに効いた。
- headlessでは実際の描画結果、文字の重なり、色、アニメーションの見え方、音の聴感は確認できない。exit 0だけでなく、`tmp/check.log`と`tmp/selfcheck.log`の全文にWARNING／ERRORがないことも確認した。

### `screenshot.gd`

- `make screenshot GAMES=fighter`で63枚を生成した。タイトル、2人の選択・hover・決定、世界地図と飛行機、3段階チュートリアル、東京・ソウル・リオ、全動作の開始・途中・終了、通常技、必殺技、ガード、被弾、コンボ、K.O.、結果を目視した。
- 同じ状態を繰り返し作れるため、UIの位置、文字切れ、選択枠、背景、セル混入を網羅するのに最も効いた。
- 静止画だけでは動作の速度、フレーム順、短い途中崩れ、実入力からの画面遷移、音声を確認できない。

### movieとアニメーション検証

- `make movie GAMES=fighter`で5秒の起動動画を作り、起動直後が真っ黒でないこと、タイトルまでの描画、音声の有無を確認した。
- `make -C games/fighter movie-play`では、移動、ジャンプ、通常技、ガード、被弾、必殺技、2ラウンド、結果、タイトル復帰までを実入力する29秒・30fpsの動画を作った。
- まず2秒間隔のcontact sheetと末尾フレームを確認した。ただしジャンプや必殺技は短く、2秒間隔では途中フレームをほぼ拾えなかったため、該当区間を0.1秒間隔で追加抽出した。
- K.O.姿勢で隣セルが混ざる問題は連続フレームの確認で発見できた。最終版では全動作の開始・中間・終了の静止画に加え、ジャンプと必殺技の高密度フレーム、実戦録画を組み合わせた。
- `ffmpeg`／`ffprobe`でフレーム抽出と音量も確認した。5秒動画は平均約-25.6dB・最大約-12.9dB、29秒動画は平均約-25.8dB・最大約-8.1dBで、無音ではなくクリップもしていなかった。

### CI artifact

- GitHub Actionsのlint、check-and-export、screenshot-and-movie、human-verification、CodeRabbitがすべて成功した。
- `fighter-screenshot-and-movie` artifactをダウンロードし、タイトル、地図、チュートリアル、対戦、必殺技、K.O.、結果のPNGと、mp4の末尾フレームを目視した。macOSローカルだけでなく、Linux、Xvfb、llvmpipeでも表示できる証拠として効いた。
- CIログにはllvmpipeの既知の`Could not set V-Sync mode`だけがあり、それ以外のWARNING／ERROR／リークがないことを確認した。
- CIのスクリプト撮影だけでは、ブラウザ特有のフォント・入力・WebGL起動や、人が順番に操作できることまでは保証できない。

### webtunnel

- preflight後、自分の`fix/fighter`ブランチをGitHub ActionsでWeb exportし、software WebGLのChromiumへCDP接続した。
- `started=true`、`notice=""`、`webgl2=true`を確認し、タイトル、右側キャラクターの選択、飛行機でリオへ移動、3段階チュートリアル、実戦、K.O.、0–2の結果まで実際に操作した。
- Web版の実入力、Canvas上の表示、画面遷移、WebGL2起動をまとめて確認できた。録画artifactと末尾フレームも取得して目視し、最後に`down fighter`でセッションを停止した。
- webtunnelで確認できるのはWeb版であり、macOS／Windows／Linuxのフルスクリーンや物理ゲームパッドは確認できない。runnerのブラウザviewportとゲーム座標の差もあるため、座標変換が必要だった。

### 最終的な使い分け

- selfcheckは状態と不変条件、`screenshot.gd`は広い静止画網羅、movieは時間方向と音、CI artifactはLinux描画、webtunnelはブラウザ実操作を担当した。
- どれか1つでは不足した。特にアニメーションは「全動作の代表静止画」「実入力録画」「短い動作だけ0.1秒間隔」の3段階にしたことで、フレーム境界の混入と動作途中の欠けを確認できた。
- 未実施なのは物理ゲームパッド実機と、export先のWindows／Linux実機での手操作。今回の完了条件では、InputEventによるゲームパッド経路、各OS向けexport、Linux CI、macOS通常起動を確認範囲とした。

## 6. Godot固有のハマりどころと回避策

- **AtlasTextureの隣セル混入**: `filter_clip`と`CanvasItem.TEXTURE_FILTER_NEAREST`だけでは、回転や縦つぶしでセル端へ達した不透明画素を防げない。生成時に不透明領域を2px内側へ収め、全セルの四辺をselfcheckで透明検査する。
- **描画と戦闘時間の同期**: `AnimatedSprite2D`を独立再生すると、ヒットストップ中にも見た目だけ進む。戦闘側の発生・持続・硬直時間から表示フレームを決め、K.O.だけは入力停止後も倒れる時間を進める。
- **同じ入力のイベント漏れ**: 決定、チュートリアルスキップ、弱キックに同じ入力を使う場合、1回の押下が次の状態にも伝播する。状態遷移に使ったボタンを離すまで攻撃入力を抑止する。
- **チュートリアル中の部分停止**: CPUだけ止めてもタイマーや投射物が進むと安全に練習できない。戦闘更新の入口でCPU、タイマー、投射物をまとめて停止し、対象となるプレイヤー入力だけ処理する。
- **headlessでは見た目を検証できない**: headlessの成功は描画成功を意味しない。描画付きの`screenshot.gd`とMovie Makerを別targetにし、ローカルとXvfb上のCIでPNG／mp4を生成して目視する。
- **sandboxでのGodot起動**: Godotは`user://`のログローテーションやエディタ設定へ書き込み、workspace-writeではAbortやexport失敗になる場合がある。すべての起動でworktree内の`--log-file`を使い、必要なら`prepare-sandbox-godot.sh`のself-containedコピー、または承認されたネイティブ実行を使う。今回は後者で最終確認した。
- **WAVのloop設定**: 実行時にloopを意図するだけでは、import後の`AudioStreamWAV`が終端で停止することがある。import設定でForward loopとloop範囲を持たせ、selfcheckで`loop_mode`と`loop_end`を検査する。
- **音声終了時のリーク**: `AudioStreamPlayer.stop()`直後に終了すると、ミキサー側の`AudioStreamPlaybackWAV`が残る場合がある。playerを止め、stream参照を外し、シーンを解放し、実時間で解放を待つ。固定fpsのフレーム待ちは実時間の待機とは限らない。通常終了と短時間終了の両方を`shutdown-check`で検査する。
- **一時PNGの再import**: `screenshot.gd`や録画から作ったPNGをプロジェクト配下へ置くと、Godotが開発成果物までimportする。`tmp/.gdignore`を作り、export presetでも`tmp/*`、`build/*`、`scripts/dev/*`を除外する。
- **型付きArrayへの代入**: 動的なNode参照経由で通常配列を`Array[int]`へ置き換えると実行時エラーになる。撮影スクリプトから試合状態を作る時は`wins.assign(...)`のように要素を代入する。
- **Area2Dの接触更新**: `get_overlapping_areas()`は同じ処理内ですぐ最新にならない。テストでは本番シーンをtreeへ追加し、物理フレームを進め、攻撃のactive中に接触が一度だけ成立することをHPとsignal数で確認する。
- **短い入力をブラウザから送る場合**: Web版ではkeydownとkeyupが同じ描画フレームへ入るとGodotのInputMapに残らないことがある。複数フレーム相当の間隔を空け、コマンド技は制限時間内で各方向と攻撃を順番に送る。
- **太い日本語フォントの小サイズ表示**: Dela Gothic Oneは見出しに向くが、小さい長文では字間が詰まりやすい。文字サイズを下げて詰め込まず、短文化して対象の近くへ分割する。
- **ログ判定**: Godotのexit 0だけではWARNINGや終了時リークを見落とす。各targetのログ全文を検査し、既知のプラットフォームノイズだけを限定的に除外する。
