---
paths:
  - "**/*.gd"
  - "**/*.tscn"
  - "**/project.godot"
  - "**/export_presets.cfg"
---
# Godot / GDScript の規約

Godot 4 プロジェクトのコードとプロジェクト構成の書き方。立ち上げ・検証の手順 (雛形生成・headless 検証・export templates の導入・ハマりどころ) は godot-development skill (`~/.claude/skills/godot-development/SKILL.md`) を参照し、本ルールには転記しない。

## GDScript

- 型付きで書く。引数・戻り値・変数に型注釈を付け、`@export` 変数も型を明示する
- ゲーム進行の状態 (スコア・日数・ゲームオーバー等、画面をまたいで参照する値) は autoload シングルトンに集約し、UI ノードに状態を持たせない (Single State of Truth)
- 純粋なロジック (段階表・スコア表・状態遷移・保存データの解釈等) は `scripts/dev/selfcheck.gd` (`SceneTree` を継承し `--headless --script` で実行する) で検証し、`make test` に含める。release ビルドでは `assert` の中身が実行されないため、`assert` に頼らず明示的な判定と `quit(<exit code>)` で結果を返す
- `Node` 系 (`RefCounted` でない) のオブジェクトを `.new()` で作って tree に入れずに使った時は、検証後に `free()` する (放置すると headless 終了時にリークとして WARNING が出て、ログ検査に引っかかる)

## ディレクトリ構成とコミット対象

- シーンは `scenes/`、スクリプトは `scripts/`、画像・音声・フォント素材は `assets/`、開発用スクリプト (headless で実行する検証・ダンプ・撮影) は `scripts/dev/` に置く
- `.godot/` と `build/` はコミットしない (自動生成物)。`*.import` と `*.uid` はコミットする (Godot がリソース参照に使う)
- Godot に読ませないディレクトリ (`documents/` 等) には `.gdignore` を置く (置かないと配下の画像が import されて `.import` が生成される)
- 外部素材の追加は `coding-rules-assets-license.md` (同ディレクトリ) に従い `assets/CREDITS.md` に記録する

## プロジェクト固有の制約の置き場

C# の導入可否・特定 SDK の追加可否・Web エクスポートのスレッド設定など、プロジェクトの判断で決めた禁止事項は本ルールに書かず、そのプロジェクトの AGENTS.md (= CLAUDE.md)「制約」に ADR への参照付きで書く (本ルールは castle から複数プロジェクトへ配布されるため、プロジェクト固有の値・ADR 番号を含めない)。
