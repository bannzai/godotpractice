# rhythm の検証・ビルド入口。target 命名は ~/.claude/rules/makefile-target-naming.md に従う
# (`build-<対象>` = ビルドだけ。配置・起動を伴う `macos` 等の target は本プロジェクトでは持たない)。
# 全ゲーム共通の構成で、リポジトリルートの Makefile から GAMES=<slug> で個別に呼べる。
#
# GODOT は Godot 4.7 の実行ファイル。macOS ローカルの既定値は /Applications/Godot.app。CI では
# 環境変数 GODOT で Linux バイナリを渡す。
GODOT ?= /Applications/Godot.app/Contents/MacOS/Godot
LOG_DIR := tmp
GODOT_FLAGS := --log-file "$(CURDIR)/$(LOG_DIR)/engine.log"
RUN_ARGS ?=

# 描画付きで起動する target (screenshot / movie) の共通オプション。headless では描画されないため付けない。
# CI の Linux では Xvfb + llvmpipe 上で実行する
WINDOWED_FLAGS := --audio-driver Dummy --rendering-driver opengl3 --resolution 1280x720 --windowed --position 0,0
# 描画付き起動でだけ出る、描画に影響しない OS / ドライバ由来の行。ログの WARNING / ERROR 検査から除外する
# (llvmpipe は V-Sync を設定できない WARNING を毎回 1 件出す。macOS は入力メソッドの mach port のエラーを稀に出す)
WINDOWED_LOG_NOISE := -e 'Could not set V-Sync mode' -e 'IMKCFRunLoopWakeUpReliable'
# movie target が録画するフレーム数 (30 fps 固定。150 = 5 秒)
MOVIE_FRAMES ?= 150

.PHONY: import check selfcheck lint test screenshot movie movie-play shutdown-check run build-macos build-windows build-linux build-web build-all clean

# アセットのインポート (初回・素材追加後)。.godot/ を生成する
import:
	@mkdir -p $(LOG_DIR) build
	@touch $(LOG_DIR)/.gdignore build/.gdignore
	"$(GODOT)" $(GODOT_FLAGS) --headless --path . --import > $(LOG_DIR)/import.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/import.log; \
	tail -n 1 $(LOG_DIR)/import.log | grep -q '^exit=0$$'
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/import.log

# 起動検証。シーン・スクリプトがロードでき、メインシーンの _ready が走ることを boot 出力で確認する
check: import
	"$(GODOT)" $(GODOT_FLAGS) --headless --path . --quit > $(LOG_DIR)/check.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/check.log; \
	grep -q '^rhythm boot$$' $(LOG_DIR)/check.log
	tail -n 1 $(LOG_DIR)/check.log | grep -q '^exit=0$$'
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/check.log

# シーンのロードと素材のクレジット記録の検証 (headless)。ゲームのロジック検証もここに足す
selfcheck: import integration shutdown-check
	"$(GODOT)" $(GODOT_FLAGS) --headless --path . --script res://scripts/dev/selfcheck.gd > $(LOG_DIR)/selfcheck.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/selfcheck.log; \
	grep -q '^selfcheck OK$$' $(LOG_DIR)/selfcheck.log
	tail -n 1 $(LOG_DIR)/selfcheck.log | grep -q '^exit=0$$'
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/selfcheck.log

# GDScript の lint (gdtoolkit の gdlint。設定は ./gdlintrc)
lint:
	gdlint scripts/

# ローカル検証の一括実行 (CI と同じ内容)
test: lint check selfcheck

# 実際の描画で代表画面を撮影する (headless の check / selfcheck では見た目の崩れを検出できない)。
# 撮影する画面の並びは scripts/dev/screenshot.gd の _capture_scenes()。撮影した PNG は目視してから完了報告する
screenshot: import
	rm -f $(LOG_DIR)/screenshot-*.png
	"$(GODOT)" $(GODOT_FLAGS) --path . $(WINDOWED_FLAGS) --script res://scripts/dev/screenshot.gd > $(LOG_DIR)/screenshot.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/screenshot.log; \
	tail -n 1 $(LOG_DIR)/screenshot.log | grep -q '^exit=0$$'
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/screenshot.log | grep -v $(WINDOWED_LOG_NOISE) | grep -q .
	ls $(LOG_DIR)/screenshot-*.png

# 操作を伴わない起動〜メインシーン表示を Movie Maker モードで録画して mp4 にする (起動直後の描画崩れ・真っ黒を
# 検出する。headless は dummy レンダラで落ちるため描画付きで起動する)。真っ黒な動画を成功と誤認しないよう、
# 終了 1 秒前のフレームの輝度平均 (Y。limited range のため真っ黒 = 16) が 32 以上であることも検査する
movie: import
	rm -f $(LOG_DIR)/movie.avi $(LOG_DIR)/movie.mp4
	"$(GODOT)" $(GODOT_FLAGS) --path . $(WINDOWED_FLAGS) --script res://scripts/dev/movie.gd --write-movie $(LOG_DIR)/movie.avi --fixed-fps 30 --quit-after $(MOVIE_FRAMES) -- --capture-frames=$(MOVIE_FRAMES) > $(LOG_DIR)/movie.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/movie.log; \
	tail -n 1 $(LOG_DIR)/movie.log | grep -q '^exit=0$$'
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/movie.log | grep -v $(WINDOWED_LOG_NOISE) | grep -q .
	ffmpeg -loglevel error -y -i $(LOG_DIR)/movie.avi -c:v libx264 -threads 2 -pix_fmt yuv420p $(LOG_DIR)/movie.mp4
	rm -f $(LOG_DIR)/movie.avi
	ffmpeg -v error -sseof -1 -i $(LOG_DIR)/movie.mp4 -frames:v 1 -vf signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=- -f null - \
	  | awk -F= '/YAVG/ { found = 1; exit ($$2 >= 32) ? 0 : 1 } END { if (!found) exit 1 }'

# エディタなしでゲームを起動する (ローカルの手動確認用)
run: import
	"$(GODOT)" $(GODOT_FLAGS) --path . $(RUN_ARGS)

# エクスポート。プリセット名は export_presets.cfg と一致させる。
# 実行には Godot 4.7 の export templates (Godot_v4.7-stable_export_templates.tpz) の展開が必要
# (AGENTS.md「検証方法」参照)
build-macos: import
	@mkdir -p build/macos
	rm -f build/macos/rhythm.zip
	"$(GODOT)" $(GODOT_FLAGS) --headless --path . --export-release "macOS" build/macos/rhythm.zip > $(LOG_DIR)/build-macos.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/build-macos.log; \
	tail -n 1 $(LOG_DIR)/build-macos.log | grep -q '^exit=0$$'
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/build-macos.log
	test -f build/macos/rhythm.zip

build-windows: import
	@mkdir -p build/windows
	"$(GODOT)" $(GODOT_FLAGS) --headless --path . --export-release "Windows Desktop" build/windows/rhythm.exe > $(LOG_DIR)/build-windows.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/build-windows.log; \
	tail -n 1 $(LOG_DIR)/build-windows.log | grep -q '^exit=0$$'
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/build-windows.log
	test -f build/windows/rhythm.exe
	test -f build/windows/rhythm.pck

build-linux: import
	@mkdir -p build/linux
	"$(GODOT)" $(GODOT_FLAGS) --headless --path . --export-release "Linux" build/linux/rhythm.x86_64 > $(LOG_DIR)/build-linux.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/build-linux.log; \
	tail -n 1 $(LOG_DIR)/build-linux.log | grep -q '^exit=0$$'
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/build-linux.log
	test -f build/linux/rhythm.x86_64
	test -f build/linux/rhythm.pck

# Web エクスポート (動作確認専用。配布はデスクトップ 3 種)。webtunnel での確認に使う
build-web: import
	@mkdir -p build/web
	"$(GODOT)" $(GODOT_FLAGS) --headless --path . --export-release "Web" build/web/index.html > $(LOG_DIR)/build-web.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/build-web.log; \
	tail -n 1 $(LOG_DIR)/build-web.log | grep -q '^exit=0$$'
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/build-web.log
	test -f build/web/index.html
	test -f build/web/index.wasm
	test -f build/web/index.pck

build-all: build-macos build-windows build-linux

# 本番シーンへ実入力を送る26秒の録画。描画とエンコードの負荷を抑えるため変換は2スレッド。
movie-play: import
	"$(GODOT)" $(GODOT_FLAGS) --path . $(WINDOWED_FLAGS) --script res://scripts/dev/demo.gd --write-movie $(LOG_DIR)/movie-play.avi --fixed-fps 30 > $(LOG_DIR)/movie-play.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/movie-play.log; \
	tail -n 1 $(LOG_DIR)/movie-play.log | grep -q '^exit=0$$'
	grep -q '^demo OK:' $(LOG_DIR)/movie-play.log
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/movie-play.log | grep -v $(WINDOWED_LOG_NOISE) | grep -q .
	ffmpeg -loglevel error -y -i $(LOG_DIR)/movie-play.avi -c:v libx264 -threads 2 -pix_fmt yuv420p $(LOG_DIR)/movie-play.mp4
	rm -f $(LOG_DIR)/movie-play.avi
	ffmpeg -loglevel error -y -i $(LOG_DIR)/movie-play.mp4 -vf fps=1/2 $(LOG_DIR)/play-frame-%02d.png
	ffmpeg -loglevel error -y -sseof -1 -i $(LOG_DIR)/movie-play.mp4 -frames:v 1 $(LOG_DIR)/play-last.png

# 通常のclose通知とGodot自身のフレーム指定終了を独立に確認する。
shutdown-check: import
	"$(GODOT)" $(GODOT_FLAGS) --headless --path . --script res://scripts/dev/shutdown_check.gd > $(LOG_DIR)/shutdown.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/shutdown.log; \
	tail -n 1 $(LOG_DIR)/shutdown.log | grep -q '^exit=0$$'
	grep -q '^shutdown_check:' $(LOG_DIR)/shutdown.log
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/shutdown.log
	"$(GODOT)" $(GODOT_FLAGS) --headless --path . --fixed-fps 60 --quit-after 90 > $(LOG_DIR)/quit-after.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/quit-after.log; \
	tail -n 1 $(LOG_DIR)/quit-after.log | grep -q '^exit=0$$'
	grep -q '^rhythm boot$$' $(LOG_DIR)/quit-after.log
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/quit-after.log

clean:
	rm -rf build $(LOG_DIR)

# 実入力の各系統・全曲の完走と音声時計を検証する。
.PHONY: integration
integration: import
	"$(GODOT)" $(GODOT_FLAGS) --headless --path . --script res://scripts/dev/integration.gd > $(LOG_DIR)/integration.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/integration.log; \
	tail -n 1 $(LOG_DIR)/integration.log | grep -q '^exit=0$$'
	grep -q '^integration OK$$' $(LOG_DIR)/integration.log
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/integration.log
