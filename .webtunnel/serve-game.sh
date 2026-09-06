#!/usr/bin/env bash
# webtunnel のセッション (GHA ubuntu runner) で games/<game> の Web エクスポートを配信する。
#   setup <game>: Godot 4.7 の Linux バイナリと Web (nothreads) の export template を取得し、import → Web エクスポート
#   serve <game>: build/web を PORT (webtunnel の port input。既定 8000) で配信する (フォアグラウンド)
# Web エクスポートは variant/thread_support=false (COOP/COEP ヘッダ不要) で、python の http.server は .wasm を
# application/wasm で返すため Node は不要。
# 注意: runner の Chromium は既定では WebGL2 が無効で Godot が起動しない。webtunnel 側のソフトウェア WebGL
# (SwiftShader) の起動オプション ( https://github.com/bannzai/webtunnel/issues/22 ) が入るまで、この経路は成立しない。
set -euo pipefail

mode="${1:?setup | serve}"
game="${2:?games/<game> の slug}"
project="games/$game"
[ -f "$project/project.godot" ] || { echo "games/$game に project.godot が無い" >&2; exit 1; }

GODOT_RELEASE="4.7-stable"
GODOT_VERSION_DIR="4.7.stable"
GODOT_BIN="$HOME/godot-bin/Godot_v${GODOT_RELEASE}_linux.x86_64"
TEMPLATES_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION_DIR}"

case "$mode" in
  setup)
    if [ ! -x "$GODOT_BIN" ]; then
      mkdir -p "$HOME/godot-bin"
      curl -sL -o /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_RELEASE}/Godot_v${GODOT_RELEASE}_linux.x86_64.zip"
      unzip -q -o /tmp/godot.zip -d "$HOME/godot-bin"
    fi
    if [ ! -f "$TEMPLATES_DIR/web_nothreads_release.zip" ]; then
      mkdir -p "$TEMPLATES_DIR"
      curl -sL -o /tmp/templates.tpz "https://github.com/godotengine/godot/releases/download/${GODOT_RELEASE}/Godot_v${GODOT_RELEASE}_export_templates.tpz"
      unzip -q -o -j /tmp/templates.tpz "templates/version.txt" "templates/web_nothreads_release.zip" "templates/web_nothreads_debug.zip" -d "$TEMPLATES_DIR"
    fi
    make -C "$project" build-web GODOT="$GODOT_BIN"
    ;;
  serve)
    exec python3 -m http.server "${PORT:-8000}" --bind 127.0.0.1 --directory "$project/build/web"
    ;;
  *)
    echo "未知のモード: $mode (setup | serve)" >&2
    exit 1
    ;;
esac
