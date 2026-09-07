#!/usr/bin/env bash
# CI の matrix に載せるゲーム (games/<slug>) を決めて `games=<JSON 配列>` の 1 行を出力する (GITHUB_OUTPUT 形式)。
#
#   - pull_request: ベースブランチとの差分が「ゲーム個別のパス」だけなら、変更のあったゲームだけを選ぶ。
#     ゲーム個別のパス = games/<slug>/ 配下、documents/knowledge/<slug>.md、documents/hearing/<slug>.md
#     それ以外 (workflow・ルートの Makefile・共通設定・共有ドキュメント) に変更があれば全ゲームを選ぶ (共有物の変更は全ゲームに効くため)
#   - それ以外 (push 等): 全ゲーム
#
# Usage: changed-games.sh <event_name> <base_ref>
#   base_ref は pull_request の時だけ使う (例: main)。origin/<base_ref> が fetch 済みであること (fetch-depth: 0)
set -euo pipefail

event="${1:?event_name が必要}"
base_ref="${2:-}"

all_games() {
  for project in games/*/project.godot; do
    [ -f "$project" ] || continue
    basename "$(dirname "$project")"
  done | sort
}

# 変更ファイルのパスから対応するゲームの slug を出力する。ゲーム個別のパスでなければ何も出力しない
game_of() {
  case "$1" in
    games/*/*) echo "$1" | cut -d/ -f2 ;;
    documents/knowledge/*.md | documents/hearing/*.md) basename "$1" .md ;;
  esac
}

selected="$(all_games)"

if [ "$event" = "pull_request" ] && [ -n "$base_ref" ]; then
  changed="$(git diff --name-only "origin/${base_ref}...HEAD")"
  if [ -n "$changed" ]; then
    per_game_only=1
    candidates=""
    while IFS= read -r path; do
      game="$(game_of "$path")"
      if [ -z "$game" ] || [ ! -f "games/$game/project.godot" ]; then
        per_game_only=0
        break
      fi
      candidates="$candidates$game"$'\n'
    done <<< "$changed"
    if [ "$per_game_only" = 1 ]; then
      selected="$(printf '%s' "$candidates" | sort -u)"
    fi
  fi
fi

if [ -z "$selected" ]; then
  echo "対象ゲームが 0 件 (games/*/project.godot が無い)" >&2
  exit 1
fi

json="$(printf '%s\n' $selected | jq -R . | jq -sc .)"
echo "games=$json"
