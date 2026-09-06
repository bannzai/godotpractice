#!/usr/bin/env python3
"""燈火の巡礼の画像と音声を同一バイト列で再生成する。"""

import generate_art
import generate_audio


def main():
    """画像と音声の生成を分離し、同じ入力から既存素材を同期する。"""
    generate_art.main()
    generate_audio.main()


if __name__ == "__main__":
    main()
