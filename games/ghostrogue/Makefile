# ghostrogue の検証・ビルド入口。build-* はエクスポートだけ、run はエディタなしの起動。
GODOT ?= /Applications/Godot.app/Contents/MacOS/Godot
LOG_DIR := tmp
RUN_FLAGS ?=
WINDOWED_FLAGS := --audio-driver Dummy --rendering-driver opengl3 --resolution 1280x720 --windowed --position 0,0
# llvmpipe の V-Sync 非対応と macOS の入力メソッド由来の既知ログだけを除外する。
WINDOWED_LOG_NOISE := -e 'Could not set V-Sync mode' -e 'IMKCFRunLoopWakeUpReliable'
MOVIE_FRAMES ?= 150
LOG_FAILURES := -e WARNING -e ERROR -e 'ObjectDB instances were leaked' -e 'resources still in use'

.PHONY: import check selfcheck integration lint test screenshot movie movie-play check-shutdown check-shutdown-windowed run generate-art generate-audio build-macos build-windows build-linux build-web build-all clean

generate-art:
	python3 scripts/dev/generate_art.py

generate-audio:
	python3 scripts/dev/generate_audio.py

import:
	@mkdir -p $(LOG_DIR) build
	@touch $(LOG_DIR)/.gdignore build/.gdignore
	"$(GODOT)" --log-file "$(abspath $(LOG_DIR)/engine-import.log)" --headless --path . --import > $(LOG_DIR)/import.log 2>&1
	! grep -i $(LOG_FAILURES) $(LOG_DIR)/import.log

check: import
	"$(GODOT)" --log-file "$(abspath $(LOG_DIR)/engine-check.log)" --headless --path . --quit > $(LOG_DIR)/check.log 2>&1
	grep -q '^ghostrogue boot$$' $(LOG_DIR)/check.log
	! grep -i $(LOG_FAILURES) $(LOG_DIR)/check.log

selfcheck: import
	"$(GODOT)" --log-file "$(abspath $(LOG_DIR)/engine-selfcheck.log)" --headless --path . --script res://scripts/dev/selfcheck.gd > $(LOG_DIR)/selfcheck.log 2>&1
	grep -q '^selfcheck OK$$' $(LOG_DIR)/selfcheck.log
	! grep -i $(LOG_FAILURES) $(LOG_DIR)/selfcheck.log

integration: import
	"$(GODOT)" --log-file "$(abspath $(LOG_DIR)/engine-integration.log)" --headless --path . --script res://scripts/dev/integration.gd > $(LOG_DIR)/integration.log 2>&1
	grep -q '^integration OK$$' $(LOG_DIR)/integration.log
	! grep -i $(LOG_FAILURES) $(LOG_DIR)/integration.log

lint:
	gdlint scripts/

test: lint check selfcheck integration check-shutdown

screenshot: import check-shutdown-windowed
	"$(GODOT)" --log-file "$(abspath $(LOG_DIR)/engine-screenshot.log)" --path . $(WINDOWED_FLAGS) --script res://scripts/dev/screenshot.gd > $(LOG_DIR)/screenshot.log 2>&1
	grep -q '^screenshot OK$$' $(LOG_DIR)/screenshot.log
	! grep -i $(LOG_FAILURES) $(LOG_DIR)/screenshot.log | grep -v $(WINDOWED_LOG_NOISE) | grep -q .
	ls $(LOG_DIR)/screenshot-*.png

# 音を停止してから12フレーム以上待ち、描画を残したまま終了する。
movie: import
	"$(GODOT)" --log-file "$(abspath $(LOG_DIR)/engine-movie.log)" --path . $(WINDOWED_FLAGS) --write-movie $(LOG_DIR)/movie.avi --fixed-fps 30 --script res://scripts/dev/movie.gd -- $(MOVIE_FRAMES) > $(LOG_DIR)/movie.log 2>&1
	grep -q '^movie OK$$' $(LOG_DIR)/movie.log
	! grep -i $(LOG_FAILURES) $(LOG_DIR)/movie.log | grep -v $(WINDOWED_LOG_NOISE) | grep -q .
	ffmpeg -loglevel error -y -i $(LOG_DIR)/movie.avi -c:v libx264 -threads 2 -pix_fmt yuv420p $(LOG_DIR)/movie.mp4
	rm -f $(LOG_DIR)/movie.avi
	ffmpeg -loglevel error -y -sseof -1 -i $(LOG_DIR)/movie.mp4 -frames:v 1 $(LOG_DIR)/movie-last.png
	ffmpeg -v error -sseof -1 -i $(LOG_DIR)/movie.mp4 -frames:v 1 -vf signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=- -f null - \
	  | awk -F= '/YAVG/ { found = 1; exit ($$2 >= 32) ? 0 : 1 } END { if (!found) exit 1 }'

# 30 fps・30秒。通常の初期状態から実入力だけで進行し、結果とタイトル復帰を記録する。
movie-play: import
	"$(GODOT)" --log-file "$(abspath $(LOG_DIR)/engine-movie-play.log)" --path . $(WINDOWED_FLAGS) --write-movie $(LOG_DIR)/movie-play.avi --fixed-fps 30 --script res://scripts/dev/demo.gd > $(LOG_DIR)/movie-play.log 2>&1
	grep -q '^demo OK$$' $(LOG_DIR)/movie-play.log
	! grep -i $(LOG_FAILURES) $(LOG_DIR)/movie-play.log | grep -v $(WINDOWED_LOG_NOISE) | grep -q .
	ffmpeg -loglevel error -y -i $(LOG_DIR)/movie-play.avi -c:v libx264 -threads 2 -pix_fmt yuv420p $(LOG_DIR)/movie-play.mp4
	rm -f $(LOG_DIR)/movie-play.avi
	ffmpeg -loglevel error -y -i $(LOG_DIR)/movie-play.mp4 -vf fps=1/2 $(LOG_DIR)/movie-play-frame-%02d.png
	ffmpeg -loglevel error -y -sseof -0.034 -i $(LOG_DIR)/movie-play.mp4 -frames:v 1 $(LOG_DIR)/movie-play-last.png

check-shutdown: import
	@for frames in 1 8 40 150; do \
	  "$(GODOT)" --log-file "$(abspath $(LOG_DIR))/engine-quit-after-$$frames.log" --headless --path . --fixed-fps 30 --quit-after $$frames > $(LOG_DIR)/quit-after-$$frames.log 2>&1 || exit $$?; \
	  if grep -i $(LOG_FAILURES) $(LOG_DIR)/quit-after-$$frames.log; then exit 1; fi; \
	done
	"$(GODOT)" --log-file "$(abspath $(LOG_DIR)/engine-shutdown.log)" --headless --path . --script res://scripts/dev/shutdown.gd > $(LOG_DIR)/shutdown.log 2>&1
	grep -q '^shutdown OK$$' $(LOG_DIR)/shutdown.log
	! grep -i $(LOG_FAILURES) $(LOG_DIR)/shutdown.log

# 描画時は実際に音声を再生し、音声リソースを持った終了も検査する。
check-shutdown-windowed: import
	@for frames in 1 8 40; do \
	  "$(GODOT)" --log-file "$(abspath $(LOG_DIR))/engine-quit-windowed-$$frames.log" --path . $(WINDOWED_FLAGS) --fixed-fps 30 --quit-after $$frames > $(LOG_DIR)/quit-windowed-$$frames.log 2>&1 || exit $$?; \
	  if grep -i $(LOG_FAILURES) $(LOG_DIR)/quit-windowed-$$frames.log | grep -v $(WINDOWED_LOG_NOISE) | grep -q .; then exit 1; fi; \
	done
	"$(GODOT)" --log-file "$(abspath $(LOG_DIR)/engine-shutdown-windowed.log)" --path . $(WINDOWED_FLAGS) --script res://scripts/dev/shutdown.gd > $(LOG_DIR)/shutdown-windowed.log 2>&1
	grep -q '^shutdown OK$$' $(LOG_DIR)/shutdown-windowed.log
	! grep -i $(LOG_FAILURES) $(LOG_DIR)/shutdown-windowed.log | grep -v $(WINDOWED_LOG_NOISE) | grep -q .

run: import
	"$(GODOT)" --log-file "$(abspath $(LOG_DIR)/engine-run.log)" --path . $(RUN_FLAGS)

# Godot 4.7 の export templates を利用し、各ログの全文を検査する。
build-macos: import
	@mkdir -p build/macos
	rm -f build/macos/ghostrogue.zip
	"$(GODOT)" --log-file "$(abspath $(LOG_DIR)/engine-build-macos.log)" --headless --path . --export-release "macOS" build/macos/ghostrogue.zip > $(LOG_DIR)/build-macos.log 2>&1
	! grep -i $(LOG_FAILURES) $(LOG_DIR)/build-macos.log
	test -s build/macos/ghostrogue.zip

build-windows: import
	@mkdir -p build/windows
	"$(GODOT)" --log-file "$(abspath $(LOG_DIR)/engine-build-windows.log)" --headless --path . --export-release "Windows Desktop" build/windows/ghostrogue.exe > $(LOG_DIR)/build-windows.log 2>&1
	! grep -i $(LOG_FAILURES) $(LOG_DIR)/build-windows.log
	test -s build/windows/ghostrogue.exe
	test -s build/windows/ghostrogue.pck

build-linux: import
	@mkdir -p build/linux
	"$(GODOT)" --log-file "$(abspath $(LOG_DIR)/engine-build-linux.log)" --headless --path . --export-release "Linux" build/linux/ghostrogue.x86_64 > $(LOG_DIR)/build-linux.log 2>&1
	! grep -i $(LOG_FAILURES) $(LOG_DIR)/build-linux.log
	test -s build/linux/ghostrogue.x86_64
	test -s build/linux/ghostrogue.pck

build-web: import
	@mkdir -p build/web
	"$(GODOT)" --log-file "$(abspath $(LOG_DIR)/engine-build-web.log)" --headless --path . --export-release "Web" build/web/index.html > $(LOG_DIR)/build-web.log 2>&1
	! grep -i $(LOG_FAILURES) $(LOG_DIR)/build-web.log
	test -s build/web/index.html
	test -s build/web/index.wasm
	test -s build/web/index.pck

build-all: build-macos build-windows build-linux

clean:
	rm -rf build $(LOG_DIR)
