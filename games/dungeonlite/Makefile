GODOT ?= /Applications/Godot.app/Contents/MacOS/Godot

.PHONY: run test screenshot
run:
	"$(GODOT)" --path .

test:
	"$(GODOT)" --headless --path . --editor --import --quit
	"$(GODOT)" --headless --path . --script scripts/dev/selfcheck.gd

screenshot:
	"$(GODOT)" --path . --script scripts/dev/playcheck.gd -- --no-save
