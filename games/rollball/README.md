# ころころ工房

小さなものを巻き込んで玉を育てる、3Dのお片づけゲーム。189個の小物と家具がある部屋で、3分以内に目標直径へ到達するとクリアです。大きすぎるものにぶつかると反発し、最後に巻き込んだひとつが外れます。

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

メニューはマウスでも選択できます。再挑戦すると物の配置・サイズ・残り時間を初期状態へ戻します。

## 検証

ルートの `make test GAMES=rollball` は lint、起動、純粋ロジック、実シーンの入力・巻き込み・脱落・勝敗を検査します。

- `make screenshot GAMES=rollball`: 代表画面の PNG。
- `make movie GAMES=rollball`: 起動〜タイトルの5秒動画。
- `make -C games/rollball movie-growth`: 通常移動による巻き込みと成長の20秒動画。`tmp/growth.mp4`。
- `make -C games/rollball performance`: 描画付きの実時間 FPS・p95 フレーム時間測定。`tmp/performance.json`。
- `make build-all GAMES=rollball` / `make build-web GAMES=rollball`: デスクトップ3種 / Web のエクスポート。

素材の由来は `assets/CREDITS.md`、実装中の知見は `documents/knowledge/rollball.md` を参照してください。
