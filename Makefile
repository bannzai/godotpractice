# godotpractice のルート入口。各ゲームの検証・ビルドは games/<slug>/Makefile が正で、ここからは
# 全ゲーム (または GAMES=<slug> で指定したゲーム) への一括実行だけを提供する。
# target 命名は ~/.claude/rules/makefile-target-naming.md に従う (`build-<対象>` = ビルドだけ)。
#
# 例:
#   make list                      # ゲーム一覧
#   make test                      # 全ゲームの lint + 起動検証 + selfcheck
#   make test GAMES=platformer     # 1 ゲームだけ
#   make screenshot GAMES=shooter  # 描画付きの撮影 (games/shooter/tmp/screenshot-*.png)
#   make run                       # ゲームを起動する。GAME 未指定ならブランチ名 game/<slug> から決める (worktree で使う)
#   make run GAME=shooter          # ゲームを指定して起動する
GODOT ?= /Applications/Godot.app/Contents/MacOS/Godot
GAMES ?= $(sort $(notdir $(patsubst %/,%,$(dir $(wildcard games/*/project.godot)))))
# run の対象 1 本。作業者の worktree はブランチ game/<slug> で 1 ゲームを担当するため、ブランチ名から slug を取る
GAME ?= $(patsubst game/%,%,$(filter game/%,$(shell git branch --show-current 2>/dev/null)))

# ゲーム側の Makefile へそのまま委譲する target。1 ゲームでも失敗したら exit 非 0 で止まる
DELEGATED_TARGETS := import check selfcheck lint test screenshot movie build-macos build-windows build-linux build-web build-all clean

.PHONY: list run $(DELEGATED_TARGETS)

list:
	@printf '%s\n' $(GAMES)

# エディタなしでゲームを 1 本起動する (ローカルの手動確認用)。実体は games/<slug>/Makefile の run target
run:
	@test -n "$(GAME)" || { echo "GAME を指定してください (例: make run GAME=shooter)。ブランチ game/<slug> 上なら省略できます" >&2; exit 1; }
	@test -f games/$(GAME)/project.godot || { echo "games/$(GAME)/project.godot が無い" >&2; exit 1; }
	$(MAKE) -C games/$(GAME) run GODOT="$(GODOT)"

$(DELEGATED_TARGETS):
	@for game in $(GAMES); do \
	  echo "== games/$$game: $@ =="; \
	  $(MAKE) -C games/$$game $@ GODOT="$(GODOT)" || exit 1; \
	done
