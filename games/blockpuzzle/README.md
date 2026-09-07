# 結晶の庭

同じ色の結晶を4個以上つなげて消す、一人用の落ち物パズル。消えたあとの落下で新しいつながりができると連鎖する。色に加えて中心の模様でも結晶を区別できる。

## 起動

リポジトリのルートで実行する。

```sh
make -C games/blockpuzzle run
```

Godot 4.7 の GL Compatibility を使用。macOS 以外では `GODOT=/path/to/godot` を指定する。日本語対応のシステムフォントが必要。Windows・Linux へのエクスポートは未検証。

## 遊び方

- Enter または「はじめる」をクリックして開始。
- ← → / A D で移動。↑ / X / W で右回転、Z で左回転。
- ↓ / S で早く落下、Space で着地点まで一気に落下。
- 縦・横につながった同色の結晶を4個以上そろえる。斜めはつながらない。
- 結晶を消すほど落下速度が上がる。出現位置が埋まると終了。
- P / Esc または画面のボタンで一時停止。ウィンドウが非アクティブになった時も停止する。
- M または画面のボタンで音を切り替える。

最高スコアはゲーム終了時に Godot の `user://record.cfg` へ保存する。

## 検証

```sh
make -C games/blockpuzzle test
make -C games/blockpuzzle screenshot
```

`test` は盤面ロジックと保存を headless で検証する。`screenshot` は描画付きでキー入力・画面遷移・連鎖・音の切替を検証し、ルートの `tmp/blockpuzzle-*.png` へ保存する。消去・連鎖の撮影には再現用の盤面を使う。プレイ中のセーブデータは変更しない。

## セッション再開

```sh
cd /Users/bannzai/worktrees/bannzai/godotpractice/game/blockpuzzle
codex resume --last
```
