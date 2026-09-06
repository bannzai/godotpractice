#!/usr/bin/env bash
# CI の matrix に載せるゲーム (games/<slug>) を決めて `games=<JSON 配列>` の 1 行を出力する (GITHUB_OUTPUT 形式)。
#
#   - pull_request: ベースブランチとの差分が games/ 配下だけなら、変更のあったゲームだけを選ぶ。
#     games/ の外 (workflow・ルートの Makefile・共通設定) に変更があれば全ゲームを選ぶ (共有物の変更は全ゲームに効くため)
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

selected="$(all_games)"

if [ "$event" = "pull_request" ] && [ -n "$base_ref" ]; then
  changed="$(git diff --name-only "origin/${base_ref}...HEAD")"
  if [ -n "$changed" ] && ! grep -qv '^games/' <<< "$changed"; then
    selected="$(grep -oE '^games/[^/]+' <<< "$changed" | cut -d/ -f2 | sort -u | while read -r game; do
      [ -f "games/$game/project.godot" ] && echo "$game"
    done)"
  fi
fi

if [ -z "$selected" ]; then
  echo "対象ゲームが 0 件 (games/*/project.godot が無い)" >&2
  exit 1
fi

json="$(printf '%s\n' $selected | jq -R . | jq -sc .)"
echo "games=$json"
