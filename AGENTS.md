# godotpractice

既存ゲーム 9 本を題材に Godot 4.7 (GDScript) でゲームを作り、Godot 開発の skill・ツール・知見を bannzai/castle に蓄積する学習プロジェクト (Steam 向けデスクトップ構成・公開しない)。目的・対象ゲーム・運用 (司令塔と作業者の分担・ブランチ・PR・知見の流れ・安全)・技術構成は [documents/PROJECT.md](documents/PROJECT.md) を参照 (SSOT)。各ゲームの仕様と受け入れ条件は PROJECT.md「対象ゲーム」の issue を正とする。

リポジトリは **public**。秘匿情報をコミット・ログ・PR に載せない。

## 制約

- C# (.NET 版 Godot) を導入しない。Steamworks SDK / GodotSteam を追加しない。元ネタの名称・画像・音・ロゴを使わない。レンダラを GL Compatibility から変えない (根拠: [ADR 0001](documents/adr/0001-godot-gdscript-monorepo-unpublished.md))
- ゲームの作業者は `games/<slug>/` と `documents/knowledge/<slug>.md` の外を変更しない。共有物 (本ファイル・ルートの Makefile・`.github/`・`.claude/rules/`・他のゲーム) への変更は `documents/knowledge/<slug>.md` に提案として書く
- PR のマージ・force push・履歴の書き換えを作業者は行わない。commit・push・draft PR の作成と更新は行う

## 検証方法

Godot のパス (macOS ローカル。CI では環境変数 `GODOT` で Linux バイナリを渡す):

```bash
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
```

ルートの `make <target> GAMES=<slug>` は `games/<slug>/Makefile` の同名 target へ委譲する (`GAMES` を省くと全ゲーム)。ゲームのディレクトリで直接 `make <target>` としてもよい。

| 目的 | コマンド | 成功条件 |
|---|---|---|
| lint | `make lint GAMES=<slug>` (`gdlint scripts/`) | exit 0 |
| アセットインポート (初回・素材追加後) | `make import GAMES=<slug>` | exit 0 (ログは `games/<slug>/tmp/import.log`) |
| 起動検証 (シーン・スクリプトのロード確認) | `make check GAMES=<slug>` | exit 0 かつ `tmp/check.log` に `<slug> boot` が出力され、WARNING / ERROR 行がない |
| ロジック検証 (`scripts/dev/selfcheck.gd`。ゲーム固有の検証を足す) | `make selfcheck GAMES=<slug>` | exit 0 かつ `tmp/selfcheck.log` に `selfcheck OK` が出力され、WARNING / ERROR 行がない |
| ローカル検証の一括実行 (CI と同じ内容) | `make test GAMES=<slug>` | exit 0 |
| スクリーンショット (`scripts/dev/screenshot.gd` の `_capture_scenes()` が撮る代表画面。headless では見た目の崩れを検出できない) | `make screenshot GAMES=<slug>` | exit 0 かつ `tmp/screenshot-*.png` が生成される。PNG を目視してから完了報告する |
| 起動の録画 (操作なしで起動〜メインシーン表示。起動直後の描画崩れ・真っ黒を検出する) | `make movie GAMES=<slug>` | exit 0 かつ `tmp/movie.mp4` が生成される (ffmpeg が必要) |
| ゲームをエディタなしで起動 (手動確認) | `make -C games/<slug> run` | ウィンドウが開きメインシーンが表示される |
| デスクトップエクスポート | `make build-macos` / `build-windows` / `build-linux` / `build-all` (`GAMES=<slug>`) | exit 0 で `games/<slug>/build/<platform>/` に成果物が生成される |
| Web エクスポート (動作確認専用) | `make build-web GAMES=<slug>` | exit 0 で `games/<slug>/build/web/index.html` が生成される |

- Makefile の target 命名は `~/.claude/rules/makefile-target-naming.md` に従う (`build-<対象>` = ビルドだけ)
- ログは `games/<slug>/tmp/*.log` に保存して全文を WARNING / ERROR で検査する (`tail` で切り詰めて判定しない)
- エクスポートには Godot 4.7 の export templates が必要。macOS ローカルでは `~/Library/Application Support/Godot/export_templates/4.7.stable/` に展開する (導入は godot-development skill の `install-export-templates.sh`)。CI (`.github/workflows/ci.yml`) は tpz から必要なテンプレートだけを取り出してキャッシュする
- `gdlint` は gdtoolkit (`pipx install "gdtoolkit==4.*"`) で入る。設定は各ゲームの `gdlintrc`
- CI は PR で変更のあったゲームだけを matrix で検証する (共有物の変更と main への push では全ゲーム。判定は `.github/scripts/changed-games.sh`)。`screenshot-and-movie` job は Xvfb + llvmpipe 上で `make screenshot` と `make movie` を実行し、PNG と mp4 を artifact `<slug>-screenshot-and-movie` に残す。PR を開いた agent は `gh run download <run ID> -n <slug>-screenshot-and-movie -D tmp/artifact` でダウンロードし、PNG と mp4 (`ffmpeg -sseof -1 -i tmp/artifact/movie.mp4 -frames:v 1 tmp/artifact/movie-last.png` で末尾のフレームを静止画にする) を目視してから完了報告する
- webtunnel (GHA runner 上の Chromium を Tailscale 経由で操作) で Web エクスポートを開く caller workflow は `.github/workflows/browser-session.yml` (ゲームは `-f game=<slug>`)。成立の前提 (Secrets の登録・webtunnel 側のソフトウェア WebGL 対応) は PROJECT.md「未検証事項・リスク」を参照し、揃うまでは CI の artifact とローカルの `make screenshot` / `make movie` で動作確認する
- Godot の立ち上げ・検証・export templates・ハマりどころは godot-development skill を参照する。ローカルは `~/.agents/skills/godot-development/SKILL.md`、ローカルに無い時は https://github.com/bannzai/castle/blob/main/home/.agents/skills/godot-development/SKILL.md と https://github.com/bannzai/castle/blob/main/home/.agents/skills/godot-development/references/pitfalls.md を読む
- 素材の検索・生成・クレジット記録は game-asset-search skill (`~/.agents/skills/game-asset-search/SKILL.md`) を使う。Codex から skill のスクリプトを実行する時は `${CLAUDE_SKILL_DIR}` を `~/.agents/skills/<skill 名>/` に読み替える

## 規約

- コーディング規約・素材の扱いは [.claude/rules/](.claude/rules/) の各ファイルを参照 (castle の propagate-coding-rules skill が同期する。選択は `.claude/rules/.coding-rules-selection`)
- 応答・コミットメッセージ・PR・issue は日本語で書く

<!-- ai-review-config begin -->
<!--
このブロックは自動生成です。直接編集せず、テンプレートを更新してから再生成してください。
内容は AI コードレビュー時の挙動指示であり、コードベース自体への規約ではありません。
-->

## レビュー時の応答スタイル

- 応答は日本語で行う

## レビュー範囲外

以下は自動レビューで指摘しない (別の検出経路があるため):

- コンパイルエラー・型エラー (ローカル/CI のビルドで検出される)
- Lint/フォーマット違反 (リンター・フォーマッターで検出される)
<!-- ai-review-config end -->
