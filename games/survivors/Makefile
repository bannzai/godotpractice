# survivors の検証・ビルド入口。target 命名は ~/.claude/rules/makefile-target-naming.md に従う
# (`build-<対象>` = ビルドだけ。配置・起動を伴う `macos` 等の target は本プロジェクトでは持たない)。
# 全ゲーム共通の構成で、リポジトリルートの Makefile から GAMES=<slug> で個別に呼べる。
#
# GODOT は Godot 4.7 の実行ファイル。macOS ローカルの既定値は /Applications/Godot.app。CI では
# 環境変数 GODOT で Linux バイナリを渡す。
GODOT ?= /Applications/Godot.app/Contents/MacOS/Godot
LOG_DIR := tmp

# 描画付きで起動する target (screenshot / movie) の共通オプション。headless では描画されないため付けない。
# CI の Linux では Xvfb + llvmpipe 上で実行する
WINDOWED_FLAGS := --audio-driver Dummy --rendering-driver opengl3 --resolution 1280x720 --windowed --position 0,0
# 描画付き起動でだけ出る、描画に影響しない OS / ドライバ由来の行。ログの WARNING / ERROR 検査から除外する
# (llvmpipe は V-Sync を設定できない WARNING を毎回 1 件出す。macOS は入力メソッドの mach port のエラーを稀に出す)
WINDOWED_LOG_NOISE := -e 'Could not set V-Sync mode' -e 'IMKCFRunLoopWakeUpReliable'
# movie target が録画するフレーム数 (30 fps 固定。150 = 5 秒)
MOVIE_FRAMES ?= 150

.PHONY: import check selfcheck lint test screenshot movie movie-play run runcheck quitcheck build-macos build-windows build-linux build-web build-all clean benchmark inputcheck visualcheck playthrough audiocheck

# アセットのインポート (初回・素材追加後)。.godot/ を生成する
import:
	@mkdir -p $(LOG_DIR)
	"$(GODOT)" --headless --path . --import > $(LOG_DIR)/import.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/import.log; \
	tail -n 1 $(LOG_DIR)/import.log | grep -q '^exit=0$$'
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/import.log

# 起動検証。シーン・スクリプトがロードでき、メインシーンの _ready が走ることを boot 出力で確認する
check: import
	"$(GODOT)" --headless --path . --quit > $(LOG_DIR)/check.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/check.log; \
	grep -q '^survivors boot$$' $(LOG_DIR)/check.log
	tail -n 1 $(LOG_DIR)/check.log | grep -q '^exit=0$$'
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/check.log

# シーンのロードと素材のクレジット記録の検証 (headless)。ゲームのロジック検証もここに足す
selfcheck: import inputcheck visualcheck quitcheck
	"$(GODOT)" --headless --path . --script res://scripts/dev/selfcheck.gd > $(LOG_DIR)/selfcheck.log 2>&1; \
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
	"$(GODOT)" --path . $(WINDOWED_FLAGS) --script res://scripts/dev/screenshot.gd > $(LOG_DIR)/screenshot.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/screenshot.log; \
	tail -n 1 $(LOG_DIR)/screenshot.log | grep -q '^exit=0$$'
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/screenshot.log | grep -v $(WINDOWED_LOG_NOISE) | grep -q .
	grep -q '^screenshot OK$$' $(LOG_DIR)/screenshot.log
	ls $(LOG_DIR)/screenshot-*.png

# 操作を伴わない起動〜メインシーン表示を Movie Maker モードで録画して mp4 にする (起動直後の描画崩れ・真っ黒を
# 検出する。headless は dummy レンダラで落ちるため描画付きで起動する)。真っ黒な動画を成功と誤認しないよう、
# 終了 1 秒前のフレームの輝度平均 (Y。limited range のため真っ黒 = 16) が 20 以上であることも検査する。
# 音声トラックの平均音量も -60 dB を上回ることを確認し、無音の録画を検出する。
movie: import
	rm -f $(LOG_DIR)/movie.avi $(LOG_DIR)/movie.mp4
	SURVIVORS_MOVIE_FRAMES=$(MOVIE_FRAMES) "$(GODOT)" --path . $(WINDOWED_FLAGS) --write-movie $(LOG_DIR)/movie.avi --fixed-fps 30 --quit-after $(MOVIE_FRAMES) > $(LOG_DIR)/movie.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/movie.log; \
	tail -n 1 $(LOG_DIR)/movie.log | grep -q '^exit=0$$'
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/movie.log | grep -v $(WINDOWED_LOG_NOISE) | grep -q .
	ffmpeg -loglevel error -y -i $(LOG_DIR)/movie.avi -c:v libx264 -pix_fmt yuv420p $(LOG_DIR)/movie.mp4
	rm -f $(LOG_DIR)/movie.avi
	ffmpeg -hide_banner -nostats -i $(LOG_DIR)/movie.mp4 -vn -af volumedetect -f null - > $(LOG_DIR)/movie-audio.log 2>&1
	awk '/mean_volume:/ { found = 1; audible = $$(NF-1) != "-inf" && $$(NF-1) > -60 } END { exit !(found && audible) }' $(LOG_DIR)/movie-audio.log
	ffmpeg -v error -sseof -1 -i $(LOG_DIR)/movie.mp4 -frames:v 1 -vf signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=- -f null - \
	  | awk -F= '/YAVG/ { found = 1; exit ($$2 >= 20) ? 0 : 1 } END { if (!found) exit 1 }'

# 26 秒の操作付き映像。実入力でタイトル→移動・回復・強化→ボス→結果→タイトルを通す。
# 敵・武器・経験値・時刻は録画専用に設定する。通常ルールの生存検証は playthrough が担当する。
# 2 秒ごとのフレーム一覧と末尾 PNG を、動画と合わせて目視確認する。
movie-play: import
	"$(GODOT)" --path . $(WINDOWED_FLAGS) --write-movie $(LOG_DIR)/movie-play.avi --fixed-fps 30 --script res://scripts/dev/demo.gd > $(LOG_DIR)/movie-play.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/movie-play.log; \
	tail -n 1 $(LOG_DIR)/movie-play.log | grep -q '^exit=0$$'
	grep -q '^demo OK$$' $(LOG_DIR)/movie-play.log
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/movie-play.log | grep -v $(WINDOWED_LOG_NOISE) | grep -q .
	ffmpeg -loglevel error -y -i $(LOG_DIR)/movie-play.avi -c:v libx264 -pix_fmt yuv420p $(LOG_DIR)/movie-play.mp4
	rm -f $(LOG_DIR)/movie-play.avi
	ffmpeg -hide_banner -nostats -i $(LOG_DIR)/movie-play.mp4 -vn -af volumedetect -f null - > $(LOG_DIR)/movie-play-audio.log 2>&1
	awk '/mean_volume:/ { found = 1; audible = $$(NF-1) != "-inf" && $$(NF-1) > -60 } END { exit !(found && audible) }' $(LOG_DIR)/movie-play-audio.log
	ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 $(LOG_DIR)/movie-play.mp4 \
	  | awk '{ exit ($$1 >= 20 && $$1 <= 30) ? 0 : 1 }'
	ffmpeg -loglevel error -y -i $(LOG_DIR)/movie-play.mp4 -vf 'fps=1/2,scale=384:216,tile=4x4:padding=4:margin=4:color=0x102b33' -frames:v 1 $(LOG_DIR)/movie-play-frames.png
	ffmpeg -loglevel error -y -sseof -0.1 -i $(LOG_DIR)/movie-play.mp4 -frames:v 1 $(LOG_DIR)/movie-play-last.png

# 固定フレーム数での終了でもリソースが残らないことを CI で継続確認する。
quitcheck: import
	"$(GODOT)" --headless --path . --quit-after 90 > $(LOG_DIR)/quitcheck.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/quitcheck.log; \
	tail -n 1 $(LOG_DIR)/quitcheck.log | grep -q '^exit=0$$'
	grep -q '^survivors boot$$' $(LOG_DIR)/quitcheck.log
	! grep -i -e 'WARNING' -e 'ERROR' -e 'instances were leaked' -e 'resources still in use' $(LOG_DIR)/quitcheck.log

# エディタなしでゲームを起動する (ローカルの手動確認用)
run: import
	"$(GODOT)" --path .

# 通常の run 起動経路・音声ドライバでタイトルを撮り、終了時のログまで検査する。
runcheck: import
	SURVIVORS_RUN_CAPTURE=1 $(MAKE) --silent run > $(LOG_DIR)/runcheck.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/runcheck.log; \
	tail -n 1 $(LOG_DIR)/runcheck.log | grep -q '^exit=0$$'
	grep -q '^runcheck OK$$' $(LOG_DIR)/runcheck.log
	! grep -i -e 'WARNING' -e 'ERROR' -e 'instances were leaked' -e 'resources still in use' $(LOG_DIR)/runcheck.log | grep -v $(WINDOWED_LOG_NOISE) | grep -q .
	test -f $(LOG_DIR)/run-title.png

# 実音声ドライバを使うためローカルで実行する。CI の Dummy 音声とは別にループと SE を検査する。
audiocheck: import
	"$(GODOT)" --path . --script res://scripts/dev/audio_check.gd > $(LOG_DIR)/audiocheck.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/audiocheck.log; \
	tail -n 1 $(LOG_DIR)/audiocheck.log | grep -q '^exit=0$$'
	grep -q '^audiocheck OK$$' $(LOG_DIR)/audiocheck.log
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/audiocheck.log | grep -v $(WINDOWED_LOG_NOISE) | grep -q .

# エクスポート。プリセット名は export_presets.cfg と一致させる。
# 実行には Godot 4.7 の export templates (Godot_v4.7-stable_export_templates.tpz) の展開が必要
# (AGENTS.md「検証方法」参照)
build-macos: import
	@mkdir -p build/macos
	"$(GODOT)" --headless --path . --export-release "macOS" build/macos/survivors.zip
	test -f build/macos/survivors.zip

build-windows: import
	@mkdir -p build/windows
	"$(GODOT)" --headless --path . --export-release "Windows Desktop" build/windows/survivors.exe
	test -f build/windows/survivors.exe
	test -f build/windows/survivors.pck

build-linux: import
	@mkdir -p build/linux
	"$(GODOT)" --headless --path . --export-release "Linux" build/linux/survivors.x86_64
	test -f build/linux/survivors.x86_64
	test -f build/linux/survivors.pck

# Web エクスポート (動作確認専用。配布はデスクトップ 3 種)。webtunnel での確認に使う
build-web: import
	@mkdir -p build/web
	"$(GODOT)" --headless --path . --export-release "Web" build/web/index.html
	test -f build/web/index.html
	test -f build/web/index.wasm
	test -f build/web/index.pck

build-all: build-macos build-windows build-linux

clean:
	rm -rf build $(LOG_DIR)

# 実際の入力イベントを UI まで通す結合検証。F11 は描画付き実行時に追加確認する。
inputcheck: import
	"$(GODOT)" --headless --path . --script res://scripts/dev/input_check.gd > $(LOG_DIR)/inputcheck.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/inputcheck.log; \
	tail -n 1 $(LOG_DIR)/inputcheck.log | grep -q '^exit=0$$'
	grep -q '^inputcheck OK$$' $(LOG_DIR)/inputcheck.log
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/inputcheck.log

# キャラのフレーム再生・死亡終了・演出の解放・画面遷移の完了を検査する。
visualcheck: import
	"$(GODOT)" --headless --path . --script res://scripts/dev/visual_check.gd > $(LOG_DIR)/visualcheck.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/visualcheck.log; \
	tail -n 1 $(LOG_DIR)/visualcheck.log | grep -q '^exit=0$$'
	grep -q '^visualcheck OK$$' $(LOG_DIR)/visualcheck.log
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/visualcheck.log

# 通常の初期状態から移動と強化選択だけで10分間生き残る自動プレイ。
playthrough: import
	"$(GODOT)" --headless --path . --script res://scripts/dev/playthrough.gd > $(LOG_DIR)/playthrough.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/playthrough.log; \
	tail -n 1 $(LOG_DIR)/playthrough.log | grep -q '^exit=0$$'
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/playthrough.log

# 描画付きの負荷試験。fps は実時間で測り、固定fpsの録画とは別に実行する。
benchmark: import
	"$(GODOT)" --path . $(WINDOWED_FLAGS) --disable-vsync --max-fps 0 --script res://scripts/dev/benchmark.gd > $(LOG_DIR)/benchmark.log 2>&1; \
	echo "exit=$$?" >> $(LOG_DIR)/benchmark.log; \
	tail -n 1 $(LOG_DIR)/benchmark.log | grep -q '^exit=0$$'
	grep -q '^benchmark OK$$' $(LOG_DIR)/benchmark.log
	! grep -i -e 'WARNING' -e 'ERROR' $(LOG_DIR)/benchmark.log | grep -v $(WINDOWED_LOG_NOISE) | grep -q .
