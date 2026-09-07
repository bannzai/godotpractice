# ころころ工房

小さなものを巻き込んで玉を育てる、3Dのお片づけゲーム。おもちゃ箱から2つの部屋を選び、100個以上の小物を集めて3分以内に目標直径へ到達するとクリアです。大きすぎるものにぶつかると反発し、最後に巻き込んだひとつが外れます。

## 遊ぶ

リポジトリルートで `make -C games/rollball run`。Godot エディタで `project.godot` を開いても起動できます。

| 操作 | キーボード | ゲームパッド |
| --- | --- | --- |
| 移動 | WASD・矢印キー | 左スティック・十字キー |
| 視点を回す | Q / E | 右スティック・L / R |
| 決定 | Enter・Space | A |
| タイトルへ戻る | Esc | B |
| 音の切替 | M | Back |
| 全画面の切替 | F11 | Start |

メニューはマウスでも選択できます。初回は粘土キャラクターが移動・視点・巻き込みを順に身振りで案内し、Enter / Aで進むかEsc / Bでスキップできます。プレイ中は金の輪が、現在巻き込める一番近い玩具を示します。再挑戦すると物の配置・サイズ・残り時間を初期状態へ戻します。

## 検証

ルートの `make test GAMES=rollball` は lint、起動、純粋ロジック、実シーンの入力・巻き込み・脱落・勝敗、通常終了とフレーム指定終了を検査します。音声再生中の終了は movie と movie-play のログでも検査します。

- `make screenshot GAMES=rollball`: タイトル・2つの部屋選択・チュートリアル3段階・両部屋のプレイ・結果・演出途中・5種類のモデルの6状態×3時点の PNG。
- `make movie GAMES=rollball`: 起動〜タイトルの5秒動画。
- `make -C games/rollball movie-play`: 実キー・スティックイベントによるタイトル→部屋選択→初回案内→成長→クリアの25秒動画。`tmp/play.mp4` と2秒間隔の一覧 `tmp/play-frames.png`、末尾 `tmp/play-last.png`。
- `make -C games/rollball movie-growth`: 同じ入力シナリオを使う既存の録画入口。`tmp/growth.mp4`。
- `make -C games/rollball run RUN_ARGS="--script res://scripts/dev/run_smoke.gd"`: 通常起動・実キー移動・全画面と復帰・閉じる操作を撮影して検証。
- `make -C games/rollball performance`: 描画付きの実時間 FPS・p95 フレーム時間測定。`tmp/performance.json`。
- `make build-all GAMES=rollball` / `make build-web GAMES=rollball`: デスクトップ3種 / Web のエクスポート。

素材の由来は `assets/CREDITS.md`、実装中の知見は `documents/knowledge/rollball.md` を参照してください。

音声付きで `--quit-after N` を直接使う場合は、末尾に `-- --audio-stop-at-frame N` も付けてください。Godot が消費した終了フレームはスクリプトから取得できず、強制終了通知では音声の解放待ちもできないため、12フレーム前に再生を停止します。`make movie` 系の入口は両方を渡します。通常のウィンドウ終了は停止後に8フレーム待ってから終了します。
