"""宵森の灯守の画像と音声を現在の生成元から再生成する。"""

from generate_polish_art import make_characters, make_backgrounds, make_icons, make_logo
from generate_polish_audio import make_audio


if __name__ == "__main__":
    make_characters()
    make_backgrounds()
    make_icons()
    make_logo()
    make_audio()
