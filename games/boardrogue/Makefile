GODOT ?= /Applications/Godot.app/Contents/MacOS/Godot

.PHONY: run import test screenshot inputcheck build-linux build-windows build-macos
run:
	"$(GODOT)" --path .
import:
	"$(GODOT)" --headless --path . --editor --import
test:
	"$(GODOT)" --headless --path . --script scripts/dev/selfcheck.gd
	"$(GODOT)" --headless --path . --script scripts/dev/runcheck.gd -- --save-path=res://../../tmp/boardrogue-test-save.json
screenshot:
	"$(GODOT)" --path . --script scripts/dev/screenshot.gd -- --save-path=res://../../tmp/boardrogue-capture-save.json
inputcheck:
	"$(GODOT)" --path . --script scripts/dev/inputcheck.gd -- --save-path=res://../../tmp/boardrogue-input-save.json
build-linux:
	mkdir -p build/linux
	"$(GODOT)" --headless --path . --export-release Linux
build-windows:
	mkdir -p build/windows
	"$(GODOT)" --headless --path . --export-release "Windows Desktop"
build-macos:
	mkdir -p build/macos
	"$(GODOT)" --headless --path . --export-release macOS
