# spiritboard の検証・ビルド入口。target 命名は ~/.claude/rules/makefile-target-naming.md に従う
# (`build-<対象>` = ビルドだけ。配置・起動を伴う `macos` 等の target は本プロジェクトでは持たない)。
# 全ゲーム共通の構成で、リポジトリルートの Makefile から GAMES=<slug> で個別に呼べる。
#
# GODOT は Godot 4.7 の実行ファイル。macOS ローカルの既定値は /Applications/Godot.app。CI では
# 環境変数 GODOT で Linux バイナリを渡す。
GODOT ?= /Applications/Godot.app/Contents/MacOS/Godot
LOG_DIR := tmp
RUN_ARGS ?=

# 描画付きで起動する target (screenshot / movie) の共通オプション。headless では描画されないため付けない。
# CI の Linux では Xvfb + llvmpipe 上で実行する
WINDOWED_FLAGS := --audio-driver Dummy --rendering-driver opengl3 --resolution 1280x720 --windowed --position 0,0
# 描画付き起動でだけ出る、描画に影響しない OS / ドライバ由来の行。ログの WARNING / ERROR 検査から除外する
# (llvmpipe は V-Sync を設定できない WARNING を毎回 1 件出す。macOS は入力メソッドの mach port のエラーを稀に出す)
WINDOWED_LOG_NOISE := -e 'Could not set V-Sync mode' -e 'IMKCFRunLoopWakeUpReliable'
# movie target が録画するフレーム数 (30 fps 固定。150 = 5 秒)
MOVIE_FRAMES ?= 150
MOVIE_PLAY_FRAMES := 720

.PHONY: generate-assets import check selfcheck integration lint test screenshot movie movie-play run build-macos build-windows build-linux build-web build-all clean

# 独自素材を同じバイト列で再生成する。外部の認証・サービスは不要。
generate-assets:
	python3 scripts/dev/generate_art.py --out-dir assets
	python3 scripts/dev/generate_audio.py --out-dir assets

# アセットのインポート (初回・素材追加後)。.godot/ を生成する
import:
	@mkdir -p $(LOG_DIR) build
	@touch $(LOG_DIR)/.gdignore build/.gdignore
	"$(GODOT)" --headless --path . --log-file "$(abspath $(LOG_DIR)/engine-import.log)" --import > $(LOG_DIR)/import.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/import.log; \
	tail -n 1 $(LOG_DIR)/import.log | grep -q '^exit=0$$'
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/import.log $(LOG_DIR)/engine-import.log

# 起動検証。シーン・スクリプトがロードでき、メインシーンの _ready が走ることを boot 出力で確認する
check: import
	"$(GODOT)" --headless --path . --log-file "$(abspath $(LOG_DIR)/engine-check.log)" --quit > $(LOG_DIR)/check.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/check.log; \
	grep -q '^spiritboard boot$$' $(LOG_DIR)/check.log
	tail -n 1 $(LOG_DIR)/check.log | grep -q '^exit=0$$'
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/check.log $(LOG_DIR)/engine-check.log

# シーンのロードと素材のクレジット記録の検証 (headless)。ゲームのロジック検証もここに足す
selfcheck: import
	"$(GODOT)" --headless --path . --log-file "$(abspath $(LOG_DIR)/engine-selfcheck.log)" --script res://scripts/dev/selfcheck.gd > $(LOG_DIR)/selfcheck.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/selfcheck.log; \
	grep -q '^selfcheck OK$$' $(LOG_DIR)/selfcheck.log
	tail -n 1 $(LOG_DIR)/selfcheck.log | grep -q '^exit=0$$'
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/selfcheck.log $(LOG_DIR)/engine-selfcheck.log

# 本番シーンへキー・マウス・ゲームパッドの実イベントを送り、操作後の状態を検証する
integration: import
	"$(GODOT)" --headless --path . --log-file "$(abspath $(LOG_DIR)/engine-integration.log)" --fixed-fps 60 --script res://scripts/dev/integration.gd > $(LOG_DIR)/integration.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/integration.log; \
	tail -n 1 $(LOG_DIR)/integration.log | grep -q '^exit=0$$'
	grep -q '^integration OK$$' $(LOG_DIR)/integration.log
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/integration.log $(LOG_DIR)/engine-integration.log

# GDScript の lint (gdtoolkit の gdlint。設定は ./gdlintrc)
lint:
	gdlint scripts/

# ローカル検証の一括実行 (CI と同じ内容)
test: lint check selfcheck integration

# 実際の描画で代表画面を撮影する (headless の check / selfcheck では見た目の崩れを検出できない)。
# 撮影する画面の並びは scripts/dev/screenshot.gd の _capture_scenes()。撮影した PNG は目視してから完了報告する
screenshot: import
	rm -f $(LOG_DIR)/screenshot-*.png
	"$(GODOT)" --path . --log-file "$(abspath $(LOG_DIR)/engine-screenshot.log)" $(WINDOWED_FLAGS) --script res://scripts/dev/screenshot.gd > $(LOG_DIR)/screenshot.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/screenshot.log; \
	tail -n 1 $(LOG_DIR)/screenshot.log | grep -q '^exit=0$$'
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/screenshot.log $(LOG_DIR)/engine-screenshot.log | grep -v $(WINDOWED_LOG_NOISE) | grep -q .
	ls $(LOG_DIR)/screenshot-*.png

# 操作を伴わない起動〜メインシーン表示を Movie Maker モードで録画して mp4 にする (起動直後の描画崩れ・真っ黒を
# 検出する。headless は dummy レンダラで落ちるため描画付きで起動する)。真っ黒な動画を成功と誤認しないよう、
# 終了 1 秒前のフレームの輝度平均 (Y。limited range のため真っ黒 = 16) が 32 以上であることも検査する
movie: import
	rm -f $(LOG_DIR)/movie.avi $(LOG_DIR)/movie.mp4
	"$(GODOT)" --path . --log-file "$(abspath $(LOG_DIR)/engine-movie.log)" $(WINDOWED_FLAGS) --write-movie $(LOG_DIR)/movie.avi --fixed-fps 30 --quit-after $(MOVIE_FRAMES) --script res://scripts/dev/movie.gd -- $(MOVIE_FRAMES) > $(LOG_DIR)/movie.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/movie.log; \
	tail -n 1 $(LOG_DIR)/movie.log | grep -q '^exit=0$$'
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/movie.log $(LOG_DIR)/engine-movie.log | grep -v $(WINDOWED_LOG_NOISE) | grep -q .
	ffmpeg -loglevel error -y -i $(LOG_DIR)/movie.avi -c:v libx264 -threads 2 -pix_fmt yuv420p $(LOG_DIR)/movie.mp4
	rm -f $(LOG_DIR)/movie.avi
	ffmpeg -v error -sseof -1 -i $(LOG_DIR)/movie.mp4 -frames:v 1 -vf signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=- -f null - \
	  | awk -F= '/YAVG/ { found = 1; exit ($$2 >= 32) ? 0 : 1 } END { if (!found) exit 1 }'

# 実入力で24秒のプレイを録画し、2秒間隔と末尾のフレームを目視用に書き出す
movie-play: import
	rm -f $(LOG_DIR)/movie-play.avi $(LOG_DIR)/movie-play.mp4 $(LOG_DIR)/movie-play-frame-*.png $(LOG_DIR)/movie-play-last.png
	"$(GODOT)" --path . --log-file "$(abspath $(LOG_DIR)/engine-movie-play.log)" $(WINDOWED_FLAGS) --write-movie $(LOG_DIR)/movie-play.avi --fixed-fps 30 --quit-after $(MOVIE_PLAY_FRAMES) --script res://scripts/dev/demo.gd -- $(MOVIE_PLAY_FRAMES) > $(LOG_DIR)/movie-play.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/movie-play.log; \
	tail -n 1 $(LOG_DIR)/movie-play.log | grep -q '^exit=0$$'
	grep -q '^demo OK$$' $(LOG_DIR)/movie-play.log
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/movie-play.log $(LOG_DIR)/engine-movie-play.log | grep -v $(WINDOWED_LOG_NOISE) | grep -q .
	ffmpeg -loglevel error -y -i $(LOG_DIR)/movie-play.avi -c:v libx264 -threads 2 -pix_fmt yuv420p $(LOG_DIR)/movie-play.mp4
	rm -f $(LOG_DIR)/movie-play.avi
	ffmpeg -loglevel error -y -i $(LOG_DIR)/movie-play.mp4 -vf fps=1/2 $(LOG_DIR)/movie-play-frame-%02d.png
	ffmpeg -loglevel error -y -sseof -0.1 -i $(LOG_DIR)/movie-play.mp4 -frames:v 1 $(LOG_DIR)/movie-play-last.png

# エディタなしでゲームを起動する (ローカルの手動確認用)
run: import
	"$(GODOT)" --path . --log-file "$(abspath $(LOG_DIR)/engine-run.log)" $(RUN_ARGS) > $(LOG_DIR)/run.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/run.log; \
	tail -n 1 $(LOG_DIR)/run.log | grep -q '^exit=0$$'
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/run.log $(LOG_DIR)/engine-run.log | grep -v $(WINDOWED_LOG_NOISE) | grep -q .

# エクスポート。プリセット名は export_presets.cfg と一致させる。
# 実行には Godot 4.7 の export templates (Godot_v4.7-stable_export_templates.tpz) の展開が必要
# (AGENTS.md「検証方法」参照)
build-macos: import
	@mkdir -p build/macos
	rm -f build/macos/spiritboard.zip
	"$(GODOT)" --headless --path . --log-file "$(abspath $(LOG_DIR)/engine-build-macos.log)" --export-release "macOS" build/macos/spiritboard.zip > $(LOG_DIR)/build-macos.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/build-macos.log; \
	tail -n 1 $(LOG_DIR)/build-macos.log | grep -q '^exit=0$$'
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/build-macos.log $(LOG_DIR)/engine-build-macos.log
	test -f build/macos/spiritboard.zip
	cp assets/CREDITS.md assets/fonts/OFL.txt build/macos/

build-windows: import
	@mkdir -p build/windows
	"$(GODOT)" --headless --path . --log-file "$(abspath $(LOG_DIR)/engine-build-windows.log)" --export-release "Windows Desktop" build/windows/spiritboard.exe > $(LOG_DIR)/build-windows.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/build-windows.log; \
	tail -n 1 $(LOG_DIR)/build-windows.log | grep -q '^exit=0$$'
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/build-windows.log $(LOG_DIR)/engine-build-windows.log
	test -f build/windows/spiritboard.exe
	test -f build/windows/spiritboard.pck
	cp assets/CREDITS.md assets/fonts/OFL.txt build/windows/

build-linux: import
	@mkdir -p build/linux
	"$(GODOT)" --headless --path . --log-file "$(abspath $(LOG_DIR)/engine-build-linux.log)" --export-release "Linux" build/linux/spiritboard.x86_64 > $(LOG_DIR)/build-linux.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/build-linux.log; \
	tail -n 1 $(LOG_DIR)/build-linux.log | grep -q '^exit=0$$'
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/build-linux.log $(LOG_DIR)/engine-build-linux.log
	test -f build/linux/spiritboard.x86_64
	test -f build/linux/spiritboard.pck
	cp assets/CREDITS.md assets/fonts/OFL.txt build/linux/

# Web エクスポート (動作確認専用。配布はデスクトップ 3 種)。webtunnel での確認に使う
build-web: import
	@mkdir -p build/web
	"$(GODOT)" --headless --path . --log-file "$(abspath $(LOG_DIR)/engine-build-web.log)" --export-release "Web" build/web/index.html > $(LOG_DIR)/build-web.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/build-web.log; \
	tail -n 1 $(LOG_DIR)/build-web.log | grep -q '^exit=0$$'
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/build-web.log $(LOG_DIR)/engine-build-web.log
	test -f build/web/index.html
	test -f build/web/index.wasm
	test -f build/web/index.pck
	cp assets/CREDITS.md assets/fonts/OFL.txt build/web/

build-all: build-macos build-windows build-linux

clean:
	rm -rf build $(LOG_DIR)
