# rollball の実装と検証

## 設計判断

独自の「ころころ工房」。玩具の部屋で小さなものから集める、キーボード・ゲームパッド向けの短い3Dゲームとした。部屋・家具・小物はプリミティブで制作し、配置は `room.gd` の決定的なデータで再現する。外部の作品名・キャラクター・音源は使っていない。

- 体積を正として巻き込みと脱落を対称に計算する。付着表示は玉の子に移し、回収した StaticBody3D は解放する。成長後の物理形状は球ひとつであり、小物ごとの衝突計算を持ち越さない。
- 進行は RunState autoload に集約する。UI は表示と操作要求を担当し、結果確定後の時間・直径・個数は固定する。
- 反発は連続接触ごとに発生させず、クールダウンで制限する。剥がれた物体は短時間回収を止め、即座に吸い直すループを防ぐ。
- カメラは玉の大きさに応じて距離を変え、壁の内側に制限する。棚の背後では視線が家具を貫通しない位置まで寄せる。
- マテリアルを色ごとに共有し、小物の影を省く。家具と玉は影を落とす。

## 検証で確認したこと

2026-09-06、Godot 4.7 stable、macOS / Apple M4 Max、GL Compatibility、1280×720。

| 検証 | 結果 |
| --- | --- |
| `make test GAMES=rollball` | exit 0。lint・boot・selfcheck・実シーン integration |
| `make screenshot GAMES=rollball` | exit 0。タイトル・プレイ・成長・成功・時間切れを撮影し目視 |
| `make movie GAMES=rollball` | exit 0。起動〜タイトルの5秒をフレーム抽出して目視 |
| デスクトップ3種と Web エクスポート | 両 make コマンド exit 0。ログ全文に WARNING / ERROR なし |
| 実時間の描画性能 | 最終 make performance は189物体で平均452.86 FPS / p95 3.489ms、成長中は平均480.86 FPS / p95 3.401ms（Dummy音声）。通常音声ドライバでも初回計測は平均145 FPS以上 |
| 最初の PR CI | run 34013477121 全件成功。rollball の PNG 5枚と起動動画を取得して目視 |

性能は `Time.get_ticks_usec()` の実時間で process_frame の間隔を測った値。ウォームアップ5秒、189物体のまま5秒、通常移動による成長10秒、VSyncを無効化して測定した。Movie Maker の固定フレーム数や headless の速度を FPS として扱っていない。CI の llvmpipe に60fpsは要求せず、CIでは描画内容を検証する。

実シーンの統合検証では、アクション入力に加え、左右矢印のキーイベント、左スティック、結果メニューの十字キー→A決定を送る。通常の移動・接触で70個を巻き込み直径3.204mに到達し、無操作で180秒経過すると失敗することを確認する。物理ゲームパッド本体の接続検証ではない。

## Godot のハマりどころ

- `--headless` と撮影用の `--audio-driver Dummy` で WAV を再生すると、終了時に AudioStreamPlaybackWAV / AudioStreamWAV が残る場合があった。音声を出さない検証では再生を開始せず、Movie Maker は録音が必要なので例外にする。通常の音声ドライバと Movie Maker の終了では警告が出ないことを確認した。判定は `AudioServer.get_driver_name()` と `OS.has_feature("movie")`。
- `--path` を指定すると録画ファイルの相対パスはプロジェクトを基準に解決される。リポジトリ基準のパスを重ねると出力先が存在せず、録画エラーが出てもエンジンが exit 0 になる場合がある。成果物の存在とログ全文の検査が必要。
- sandbox 内では Godot の標準ユーザーデータ領域への書き込みが拒否され、起動が abort することがあった。エンジンのエラーとゲームの不具合を分け、許可されたローカル検証として実行した。
- 日本語フォントを同梱して Theme に設定し、Linux の OS fallback へ依存させない。撮影前には複数の描画完了を待つ。半透明フッター越しに小物が見えるため文字欠けを疑ったが、play/growth の文字色画素比較と別担当の目視では文字の消失はなかった。
- InputMap の特殊キー番号を推測すると左右の矢印を取り違える。実 InputEventKey を送る回帰試験で確認する。
- ゲームパッドの独自 confirm を常に start_run へ結ぶと、結果メニューで「タイトルへ戻る」を選んでも再開する。GUIで未処理のconfirmはフォーカス中のボタンへ渡し、入力を消費する。ui_acceptにもゲームパッドを登録する。
- 環境光と指向性ライトを同時に強くすると明るいマテリアルが白飛びした。実スクリーンショットを見て、床・ラグ・小物の色が識別できる明るさへ調整した。

公式の根拠:

- https://docs.godotengine.org/en/stable/classes/class_audioserver.html#class-audioserver-method-get-driver-name
- https://docs.godotengine.org/en/stable/tutorials/export/feature_tags.html
- https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html

## 素材準備と skill への改善提案

- 独自の短い BGM と SE は Python 標準ライブラリによる数式合成で再現可能にした。再生成の SHA-256 一致、非無音、非クリッピング、端点の連続性を確認した。素材の由来・生成方法は CREDITS.md に記録した。
- game-asset-search のフォント取得で汎用 OFL テンプレートを使う場合、著作権者のプレースホルダが残ることがある。実フォントの name テーブルと配布元 METADATA.pb を照合し、実際の著作権表示を残す検査を skill に追加することを提案する。
- godot-development skill のローカル配置が無いとき、GitHub Contents API で SKILL.md と pitfalls.md を取得できた。
- Godot skill に、実シーンのイベント入力、通常操作の成長録画、実時間 FPS 計測、家具越しの追従カメラ検証を再利用可能な例として加えることを提案する。ゲーム側には `movie-growth` と `performance` の入口を用意した。

## 共有物への提案

`documents/knowledge/rollball.md` を同時に変更すると、最初の PR の CI は全9ゲームを対象にした。ゲーム別知見ファイルを同名ゲームへ対応させる変更ゲーム判定にすると、ゲーム作業のCI負荷を減らせる。共有スクリプトは作業範囲外なので変更していない。

## 残した判断点

仕様の判断待ちはなし。PR のマージ、ストア提出、Steamworks 連携はこの作業に含めない。

最終調整では、結果画面のゲームパッド決定、左右矢印、棚裏のカメラ視線を回帰試験へ追加した。描画付きの実 KEY_F11 イベントで全画面への切替と復帰が成功し、棚裏の PNG も目視した。`make -C games/rollball movie-growth` は exit 0、通常移動による成長とクリアを20秒の動画に記録できた。

## 第 2 ラウンド (品質向上)

### 制作方針

木製玩具のアトリエという方向を維持し、主人公と小物を種類ごとに独立したメッシュシーンへ分ける。見分ける手掛かりを色だけに頼らず、顔・車輪・葉・装備のシルエットで用意する。物体配置、体積計算、制限時間、入力方式は維持する。

部位の AnimationPlayer、巻き込みと反発のパーティクル、統一した Theme、場面別の音楽を組み合わせる。結果や直径を直接書き換えずに実入力で遊ぶ録画を追加し、各モデルのアニメーション連続フレーム、通常終了とフレーム指定終了、Web 上の操作を検証する。
