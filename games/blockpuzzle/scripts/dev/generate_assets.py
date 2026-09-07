"""連鎖設計室の音声を決定的に再生成する。画面は Godot の単色図形だけで描く。"""

import argparse
import io
import json
import math
from pathlib import Path
import struct
import wave


RATE = 22050
BGM_NAMES = ["title", "play", "danger", "result"]
EFFECT_NAMES = [
    "move",
    "rotate",
    "land",
    "clear",
    "chain",
    "garbage",
    "victory",
    "defeat",
    "select",
]


def add_note(buffer, start, duration, midi, volume=0.2, timbre="bell", loop=False):
    frequency = 440 * 2 ** ((midi - 69) / 12)
    for index in range(int(duration * RATE)):
        time = index / RATE
        envelope = (
            min(time / 0.012, 1)
            * math.exp(-time * (4 if timbre == "bell" else 2.2))
            * min((duration - time) / 0.04, 1)
        )
        phase = 2 * math.pi * frequency * time
        if timbre == "bell":
            value = math.sin(
                phase + 1.5 * math.sin(phase * 2.01) * math.exp(-time * 7)
            ) + 0.22 * math.sin(phase * 3.997) * math.exp(-time * 10)
        else:
            value = (
                0.62 * math.sin(phase)
                + 0.2 * math.sin(phase * 2)
                + 0.13 * math.sin(phase * 3)
                + 0.05 * math.sin(phase * 5)
            )
        position = int(start * RATE) + index
        if loop:
            position %= len(buffer)
        if position < len(buffer):
            buffer[position] += volume * envelope * value


def wav_bytes(buffer):
    peak = max(1.0, max(abs(value) for value in buffer) / 0.92)
    pcm = b"".join(
        struct.pack("<h", round(max(-1, min(1, value / peak)) * 32767))
        for value in buffer
    )
    result = io.BytesIO()
    with wave.open(result, "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm)
    return result.getvalue()


def save_wav(audio_dir, name, buffer):
    path = audio_dir / f"{name}.wav"
    content = wav_bytes(buffer)
    if not path.exists() or path.read_bytes() != content:
        path.write_bytes(content)


def ambience(audio_dir):
    duration = 8.0
    buffer = []
    for index in range(round(duration * RATE)):
        time = index / RATE
        hum = 0.035 * math.sin(2 * math.pi * 55.0 * time)
        data_pulse = 0.018 * math.sin(2 * math.pi * 440.0 * time) * (
            0.5 + 0.5 * math.sin(2 * math.pi * 0.5 * time)
        )
        air = 0.012 * math.sin(2 * math.pi * 1760.0 * time) * (
            0.5 + 0.5 * math.sin(2 * math.pi * 0.25 * time)
        )
        buffer.append(hum + data_pulse + air)
    save_wav(audio_dir, "ambient", buffer)


def background_music(audio_dir):
    definitions = [
        ("title", 0.45, [76, 79, 83, 86, 83, 79, 74, 79, 81, 83, 86, 88, 86, 83, 79, 74], [52, 55, 48, 50]),
        ("play", 0.32, [76, 79, 83, 79, 86, 83, 79, 74, 72, 76, 79, 83, 81, 78, 74, 78], [52, 48, 55, 50]),
        ("danger", 0.24, [76, 77, 83, 77, 76, 71, 74, 77, 76, 77, 83, 86, 83, 77, 74, 71], [40, 41, 43, 47]),
        ("result", 0.50, [79, 83, 86, 88, 86, 83, 79, 76, 74, 79, 83, 86, 83, 79, 76, 74], [48, 55, 52, 50]),
    ]
    for scene, beat, notes, bass in definitions:
        buffer = [0.0] * round(beat * 32 * RATE)
        for index in range(32):
            add_note(buffer, index * beat, beat * 3, notes[index % 16], 0.13, loop=True)
            add_note(buffer, index * beat + 0.13, beat * 3, notes[index % 16], 0.035, loop=True)
            if index % 4 == 0:
                add_note(buffer, index * beat, beat * 5, bass[(index // 8) % 4], 0.18, "pad", True)
                add_note(buffer, index * beat, beat * 5, bass[(index // 8) % 4] + 7, 0.05, "pad", True)
            if scene in ("play", "danger") and index % 2 == 0:
                for sample in range(round(0.055 * RATE)):
                    time = sample / RATE
                    position = (round(index * beat * RATE) + sample) % len(buffer)
                    buffer[position] += (
                        0.04
                        * math.sin(2 * math.pi * (90 * time - 350 * time * time))
                        * math.exp(-time * 65)
                    )
        save_wav(audio_dir, f"bgm_{scene}", buffer)


def effects(audio_dir):
    definitions = {
        "move": [79],
        "rotate": [76, 83],
        "land": [48, 60],
        "clear": [76, 79, 83],
        "chain": [79, 83, 86, 91],
        "garbage": [44, 43, 39],
        "victory": [72, 76, 79, 84, 88],
        "defeat": [64, 60, 59, 52],
        "select": [84, 91],
    }
    for name, notes in definitions.items():
        gap = 0.065 if name not in ("victory", "defeat") else 0.15
        duration = 0.16 if name == "select" else (0.2 if name in ("move", "rotate", "land") else 0.65)
        buffer = [0.0] * int((len(notes) * gap + duration) * RATE)
        for index, midi in enumerate(notes):
            timbre = "pad" if name in ("land", "garbage", "defeat") else "bell"
            add_note(buffer, index * gap, duration, midi, 0.22, timbre)
        save_wav(audio_dir, name, buffer)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--out-dir", type=Path, default=Path(__file__).resolve().parents[2] / "assets"
    )
    parser.add_argument("--print-spec", action="store_true")
    args = parser.parse_args()
    audio = [
        {"path": "audio/ambient.wav", "loop": True, "stereo": False},
        *[
            {"path": f"audio/bgm_{name}.wav", "loop": True, "stereo": False}
            for name in BGM_NAMES
        ],
        *[
            {"path": f"audio/{name}.wav", "loop": False, "stereo": False}
            for name in EFFECT_NAMES
        ],
    ]
    if args.print_spec:
        print(json.dumps({"rate": RATE, "images": [], "audio": audio}, ensure_ascii=False))
        return
    audio_dir = args.out_dir / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)
    ambience(audio_dir)
    background_music(audio_dir)
    effects(audio_dir)
    print("連鎖設計室: 環境音1点・BGM4点・SE9点を生成")


if __name__ == "__main__":
    main()
