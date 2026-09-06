# godotpractice のルート入口。各ゲームの検証・ビルドは games/<slug>/Makefile が正で、ここからは
# 全ゲーム (または GAMES=<slug> で指定したゲーム) への一括実行だけを提供する。
# target 命名は ~/.claude/rules/makefile-target-naming.md に従う (`build-<対象>` = ビルドだけ)。
#
# 例:
#   make list                      # ゲーム一覧
#   make test                      # 全ゲームの lint + 起動検証 + selfcheck
#   make test GAMES=platformer     # 1 ゲームだけ
#   make screenshot GAMES=shooter  # 描画付きの撮影 (games/shooter/tmp/screenshot-*.png)
#   make -C games/shooter run      # ゲームを起動する (個別 target はゲーム側の Makefile を直接呼ぶ)
GODOT ?= /Applications/Godot.app/Contents/MacOS/Godot
GAMES ?= $(sort $(notdir $(patsubst %/,%,$(dir $(wildcard games/*/project.godot)))))

# ゲーム側の Makefile へそのまま委譲する target。1 ゲームでも失敗したら exit 非 0 で止まる
DELEGATED_TARGETS := import check selfcheck lint test screenshot movie build-macos build-windows build-linux build-web build-all clean

.PHONY: list $(DELEGATED_TARGETS)

list:
	@printf '%s\n' $(GAMES)

$(DELEGATED_TARGETS):
	@for game in $(GAMES); do \
	  echo "== games/$$game: $@ =="; \
	  $(MAKE) -C games/$$game $@ GODOT="$(GODOT)" || exit 1; \
	done
