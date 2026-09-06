#!/usr/bin/env python3
"""同じ入力で個別イラストと場面別音源を再生成する入口。"""

from generate_card_art import main as illustrations
from generate_audio import main as audio_assets


if __name__ == "__main__":
    illustrations()
    audio_assets()
