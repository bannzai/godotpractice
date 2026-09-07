# godotpractice

既存ゲームを題材に Godot 4.7 (GDScript) でゲームを作り、その過程で得た Godot 開発の知見を bannzai/castle の skill に登録していく学習プロジェクト (Steam 向けのデスクトップ構成・公開しない)。起点は https://github.com/bannzai/godotpractice/issues/1 。目的・対象ゲーム・技術構成は [documents/PROJECT.md](documents/PROJECT.md) を参照。

リポジトリは **public**。秘匿情報をコミット・ログ・PR に載せない。

## 進め方

- 1 ゲーム = `games/<slug>/` の 1 Godot プロジェクト = ブランチ `game/<slug>` の 1 worktree = 1 作業者 (Codex)。作業者に渡すのは「作って欲しいゲーム」だけ。司令塔は指示書テンプレート・共通の受け入れ条件・画面構成・検証方法・雛形を配らない (配った結果、全ゲームの画面構成が同じになった。経緯は PR #87)
- 画面構成・見た目・作り方・検証方法は、作業者がそのゲームに合わせて決める。他のゲームや過去のゲームを踏襲しない
- 品質: 画像や BGM・SE も使ってゲームとして成立させる。素材はそれっぽければよく、完コピでなくてよい (issue #1 の原文)
- 実装中に得た知見 (Godot のハマりどころ・素材の準備・検証の工夫・skill にしたいこと) を `documents/knowledge/<slug>.md` に書く。司令塔がこれを横断して castle の skill にする
- 作業者は commit・push・PR の作成を行う。PR のマージ・force push・履歴の書き換えは行わない (マージは司令塔またはユーザーが行う)

## CI・コードレビュー

このプロジェクトでは CI とコードレビュー (自動レビュー・Codex レビュー・人間レビュー) を行わない。PR は CI の結果やレビューを待たずにマージする。`.github/workflows/` の CI が動いても結果を待たず、失敗していても直さなくてよい。

## 制約

- C# (.NET 版 Godot) を導入しない。Steamworks SDK / GodotSteam を追加しない。元ネタの名称・画像・音・ロゴを使わない。レンダラを GL Compatibility から変えない (根拠: [ADR 0001](documents/adr/0001-godot-gdscript-monorepo-unpublished.md))
- 作業者は `games/<slug>/` と `documents/knowledge/<slug>.md` の外を変更しない。共有物 (本ファイル・ルートの Makefile・`.github/`・`.claude/rules/`・他のゲーム) への変更は `documents/knowledge/<slug>.md` に提案として書く
- 外部素材は出典とライセンスを `games/<slug>/assets/CREDITS.md` に記録する (public リポジトリのため。書き方は `.claude/rules/coding-rules-assets-license.md`)

## 環境

- Godot のバイナリ (macOS ローカル): `/Applications/Godot.app/Contents/MacOS/Godot`
- ルートの `make list` がゲームの一覧。`make <slug>-run` は `games/<slug>/Makefile` の `run` target へ委譲する (ゲーム側に `run` target を作るかどうかは作業者に任せる)
- 動作確認を GHA runner 上のブラウザで行いたい時は webtunnel skill (`~/.agents/skills/webtunnel/SKILL.md`) が使える (issue #1 で指定された経路。必須ではない)

## 規約

- コーディング規約・素材の扱いは [.claude/rules/](.claude/rules/) の各ファイルを参照 (castle の propagate-coding-rules skill が同期する。選択は `.claude/rules/.coding-rules-selection`)
- 応答・コミットメッセージ・PR・issue は日本語で書く
