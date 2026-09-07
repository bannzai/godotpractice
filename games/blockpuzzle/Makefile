GODOT ?= /Applications/Godot.app/Contents/MacOS/Godot
.PHONY: run test screenshot import
import:
	"$(GODOT)" --headless --path . --editor --import --quit
run: import
	"$(GODOT)" --path .
test:
	"$(GODOT)" --headless --path . --script scripts/dev/selfcheck.gd
screenshot: import
	"$(GODOT)" --path . --script scripts/dev/screenshot.gd
