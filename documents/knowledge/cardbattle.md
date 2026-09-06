# cardbattle の実装と検証

## 採用するルール

通常召喚は毎ターン1回、上級モンスターの生け贄は導入しない。召喚したターンも攻撃できるが、決闘の最初のターンだけバトルを行えない。守備表示同士の戦闘は行わず、攻撃表示のモンスターから攻撃する。罠は相手の攻撃宣言時に自動発動する。これらをゲーム内の遊び方にも表示する。

## 設計

カード定義と固定デッキは CardCatalog に集約し、決闘ロジックを描画から分離する。CPU と人間が同じ操作 API を使うことで、操作制限と勝敗判定の食い違いを防ぐ。描画・音の演出はロジックの結果イベントを使う。

## ローカルの検証結果（2026-09-06）

| 検証 | 実測結果 |
| --- | --- |
| `make test GAMES=cardbattle` | exit 0。15,819検証。固定seed40局のCPU対CPUが最大94操作で終局し、各カードの総枚数を保持 |
| `make screenshot GAMES=cardbattle` | exit 0。タイトル・遊び方・初手・対戦・召喚途中・攻撃途中・勝利・敗北の8 PNGを目視し、1280×720の文字・画像に崩れなし |
| `make movie GAMES=cardbattle` | exit 0。音声付き1280×720、約5秒のmp4。0.5秒ごとの連続フレームで起動からタイトル表示を目視 |
| `make build-all GAMES=cardbattle` | exit 0。macOS / Windows / Linuxの成果物を生成 |
| `make build-web GAMES=cardbattle` | exit 0。WebのHTML / WASM / PCKを生成 |

起動・selfcheck・import・録画・書き出しの各ログ全文を検査し、実行に由来する WARNING / ERROR はなかった。OFL全文とCREDITSが各書き出しの保存ログに含まれることも確認した。CIでの最終結果とartifact確認はPRに記録する。

画面検証は InputEventKey / InputEventJoypadButton / InputEventMouseButton を実際のInput処理へ投入する。矢印・十字キーでデッキ選択、Enterで開始、N / Yでフェイズ進行、Aでカード選択と再戦、マウスで召喚、実攻撃とドロー不能から勝敗結果への遷移、タイトル復帰を確認した。F11で全画面へ切り替え、STARTでウィンドウに戻る操作も確認した。物理ゲームパッドの機種固有の接続互換性は対象に含めていない。

## 判断点

現時点でユーザー判断が必要な項目はない。既存の共有設定は変更しない。

## 素材の生成と同梱条件

背景・四属性の精霊・カード裏はオリジナルの SVG とし、BGM・効果音は Python 標準ライブラリだけで正弦波を合成した。生成器は `games/cardbattle/scripts/dev/generate_assets.py`。プロジェクトのルートで次を実行すると、同じ設計の画像と音声を再生成できる。フォントのダウンロードは生成器に含めていない。

```bash
python3 games/cardbattle/scripts/dev/generate_assets.py
```

- 色は紺・青緑・金を基調とし、属性ごとの色と図形を併用した。SVG 内の星の配置には固定シードを使用する。全 6 SVG を XML パーサーで読み込み、構文が成立することを確認した。実際のゲーム画面での見た目の判定は描画検証で行う。
- 音声は 22,050 Hz・16 bit・モノラル PCM。16 秒の BGM は終端を越える音の残響を先頭に折り返して重ねる。効果音は短いアタックとリリースを持たせ、急な波形の切断を避ける。生成時の最大振幅は BGM が 0.212、効果音が最大 0.508 で、PCM の上限に達していないことを確認した。耳での聴取評価とは区別する。
- 日本語フォントは Google Fonts の Noto Sans JP を取得し、データを改変せずファイル名だけ `NotoSansJP.ttf` に変更した。取得したフォントに対応する著作権表示と OFL 1.1 全文を `assets/fonts/OFL.txt` に同梱した。ライセンス文書は Godot の通常のリソース検出だけではエクスポート対象にならないため、各エクスポート設定の `include_filter` にも含める。
- `game-asset-search` の `record-credit.sh` で全素材を `assets/CREDITS.md` に記録し、`check-credits.sh --assets games/cardbattle/assets` が `check-credits OK` となることを確認した。独自生成物に根拠なく CC0 を付けず、生成方法と第三者素材を使用していないことを記録した。

フォントの取得元:

https://fonts.google.com/specimen/Noto+Sans+JP

https://github.com/google/fonts/tree/main/ofl/notosansjp

## Godot 4.7 の音声停止と終了時の解放

macOS の Godot `4.7.stable.official.5b4e0cb0f` で、`AudioStreamPlayer` に `assets/audio/bgm.wav` を設定して再生し、約 0.35 秒後に終了する最小構成を実行した。音声ドライバは Dummy。終了コードが 0 でも `AudioStreamPlaybackWAV` と `AudioStreamWAV` の 2 インスタンス、および 1 リソースの解放漏れを示す WARNING / ERROR が出る。このため終了コードだけで検証を成功扱いにしない。

最小再現スクリプトと実行ログは、作業時に `games/cardbattle/tmp/audio_shutdown.gd` と同ディレクトリの `audio-shutdown-*`・`audio-headed-*`・`audio-movie-*` に保存した。いずれも一時的な検証成果物であり、配布物には含めない。

| 終了前の処理 | 実測結果 |
| --- | --- |
| 再生中のまま `quit()` | 2 インスタンスと 1 リソースの解放漏れ |
| `stop()` と `stream = null` の直後に `quit()` | 同じ解放漏れ |
| 停止後に `await create_timer(0.2).timeout` を挟んで `quit()` | headless と Movie Maker の両方で WARNING / ERROR なし |
| 停止後に 8 回 `process_frame` を待って `quit()` | headless で WARNING / ERROR なし |
| 終了処理中の停止後に `OS.delay_msec(200)` | 通常の描画あり・Dummy では WARNING / ERROR なし。Movie Maker では解放漏れが残った |

Godot の上流 issue では、停止要求が AudioServer 内で即時に参照を破棄する処理ではなく、後続の音声処理でフェードアウトして解放する処理になることが説明されている。今回の即時終了と解放待ちの差はその説明と一致する。`_exit_tree()` で `stop()` するだけでは後続フレームを確保できない。Movie Maker は録画フレームに合わせて音声を処理するため、メインスレッドを単にスリープさせても解放処理を進められなかった。

https://github.com/godotengine/godot/issues/76745

https://github.com/godotengine/godot/blob/4.7/servers/audio/audio_server.cpp

最小構成で音声を停止してから 0.2 秒フレームを進めた録画は 18 フレーム・0.60 秒となり、ログ全文に WARNING / ERROR がないことを確認した。`ffmpeg` の `volumedetect` でも最大音量 -14.7 dB、平均音量 -26.8 dB を取得し、正常終了のために録画音声をすべて消していないことを確認した。この数値は最小構成の検証結果であり、ゲーム本体の最終録画結果とは別である。

`--quit-after` は指定したフレーム数でエンジンを終了させるため、終了時のノード解放から追加の描画フレームを待つ用途には向かない。cardbattle では専用の `scripts/dev/movie.gd` からシーンを起動し、終了 8 フレーム前に `main.stop_audio()` を呼び、残りの描画を進めてから `quit()` する形を採用した。既定の 150 フレームは維持し、Makefile から `-- --movie-frames $(MOVIE_FRAMES)` で渡す。30 fps の 8 フレームは約 0.267 秒に相当する。録画スクリプト追加直後の `gdlint scripts/dev/movie.gd` は成功した。本体を通した最終録画結果は後続の検証記録に記載する。

## Godot skill・共通 Makefile への提案

共有ファイルはこの作業では変更していない。次の内容を司令塔側で再利用すると、音声のある他ゲームでも同じ問題を調べ直す手間を減らせる。

- `godot-development` の `references/pitfalls.md` に、音声を再生中の終了で `AudioStreamPlayback` が残る再現条件と上流 issue、停止後に描画フレームを進める回避策を追加する。単なる `stop()` や Movie Maker での `OS.delay_msec()` では解消しない点も区別して記載する。
- 共通の録画テンプレートは、`--quit-after` に任せる方法に加えて、録画スクリプトが音声停止と終了を管理できる構成を提供する。`MOVIE_FRAMES` の外部インターフェースは維持し、音声が不要なゲームに一律の処理を強制しない。
- 音声再生を遅延タイマーで開始するゲームでは、終了準備後にタイマーが発火して音声を再開しないようにする。短い録画や起動確認でも停止済みの状態を保持する。
- 素材を扱う共通手順では、OFL 文書の取得とリポジトリへの配置だけでなく、各エクスポートの `include_filter` への追加も確認する。素材の生成スクリプトとクレジット検査を残す運用を継続する。


## UIと決闘の検証で得た知見

- カスタム `_draw()` で描く画像を、その呼び出しの中だけで `load()` すると、参照が保持されず背景やカード画像が白くなる事象を実測した。描画するテクスチャを定数の `preload()` で保持すると解消した。リソースの読み込み成功だけでは見た目を検証できない。
- `TextureRect` は `expand_mode` を先に設定し、Labelはフォントと折り返しの設定・親への追加後にサイズを適用する。設定順によって一時的な最小サイズが残り、詳細画像やテキストが右パネルからはみ出す事象を実測した。
- Noto Sans JPの可変フォントは初期ウェイト100だった。`FontVariation` の `variation_opentype` に `TextServer.name_to_tag("wght")` で得た整数タグと500を渡し、各OSで同じ太さを使う。文字列キー指定では薄いままの描画を実測したため、整数タグを採用した。
- macOSの全画面切替はアニメーションを伴い、入力の直後2フレームでは切替完了を判定できなかった。全画面とウィンドウの各切替後に1秒待つと、F11 / STARTの入力検証が成立した。
- CPUと人間は同じルールAPIを使うが、UI側でも人間の手番かを確認する必要がある。CPU思考中の場の選択からCPUの攻撃処理を実行できないようにし、CPUのドロー演出には非公開のカード名を表示しない。
- ロジックの乱数を固定seedで再現できるようにすると、カード保存則と終局の多数試行を描画なしで検証できる。一方、代表画面では既知のカードを配置し、決定入力と実際のルールAPIで勝敗まで進めることで、ロジック検証と表示検証の両方を持てる。

FontVariationの公式仕様:

https://docs.godotengine.org/en/stable/classes/class_fontvariation.html

共有CIへの追加提案: 現行の `.github/scripts/changed-games.sh` は `games/` 外の差分を全ゲーム対象とするため、作業指示で必須の `documents/knowledge/cardbattle.md` だけでも9ゲームの検証が走った。知見文書の差分を該当ゲームに対応づければ検証負荷を減らせる。共有スクリプトは今回変更していない。
