# そらいろ便

風の草原とひかりの洞窟を走り、右端のポストへ配達する横スクロールアクション。

リポジトリルートで `make -C games/platformer run` を実行すると起動する。

| 操作 | キーボード | パッド |
| --- | --- | --- |
| 移動 | ← → / A D | 左スティック / 十字キー |
| ジャンプ | Space / Z | A |
| ダッシュ | Shift / X | X |
| メニュー決定 | Enter / Space | A |
| メニュー選択 | ↑ ↓ | 左スティック / 十字キー |
| 一時停止・再開 | Esc | Start |
| 全画面切替 | F11 | — |

ジャンプは長く押すと高くなる。封筒の補給ケースを下から叩くとコインや強化アイテムが出る。強化中は一度の接触に耐えられるが、落下と時間切れは防げない。芽のある橙色の敵は上から踏んで倒し、殻の敵は踏むと停止する。停止した殻は横から触れるか再び踏むと転がり、他の敵を倒す。

ゲームオーバー・最終クリアから再挑戦またはタイトルへ戻れる。素材の出典と生成方法は assets/CREDITS.md、検証方法はゲーム内 Makefile、設計判断と検証結果は documents/knowledge/platformer.md に記録している。


品質向上後の素材は `make -C games/platformer assets` で再生成できる。初回の素材生成を先に行い、キャラ別シートと多声合成音を最後に生成するため、旧素材に戻らない。

| 検証 | リポジトリルートからのコマンド |
| --- | --- |
| 操作・状態・素材の検証 | `make test GAMES=platformer` |
| 画面・動作の先頭/途中/終端・演出 | `make screenshot GAMES=platformer` |
| 起動の録画 | `make movie GAMES=platformer` |
| 実入力で2ステージを走る30秒の録画 | `make -C games/platformer movie-play` |
| 通常終了とフレーム指定終了のリーク検査 | `make -C games/platformer exitcheck` |

`tmp/movie-play-frames.png` は録画の2秒ごとの一覧、`tmp/movie-play-last.png` は末尾の画像。動作一覧はシートの1・3・6枚目を固定表示し、演出の3枚は実際に時間を進めて撮影する。プレイ録画はキーイベントだけで開始・移動・跳躍・次ステージへ進み、座標や無敵状態を書き換えない。
