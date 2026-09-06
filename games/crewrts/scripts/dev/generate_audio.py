"""庭の伴奏と操作音を標準ライブラリのみで再生成する。外部音源は使用しない。"""

import array
import math
from pathlib import Path
import sys
import wave


RATE = 22050
OUT = Path(__file__).resolve().parents[2] / "assets" / "audio"
TAU = 2.0 * math.pi


def pitch(midi: float) -> float:
    """MIDI 音高を周波数に変換する。"""
    return 440.0 * 2.0 ** ((midi - 69.0) / 12.0)


def bell(t: float, frequency: float, duration: float) -> float:
    """倍音を早く減衰させた柔らかい木琴音を返す。"""
    attack = min(1.0, t / 0.012)
    release = min(1.0, max(0.0, duration - t) / 0.09)
    return attack * release * (
        math.sin(TAU * frequency * t) * math.exp(-3.2 * t)
        + 0.24 * math.sin(TAU * frequency * 2.0 * t) * math.exp(-7.0 * t)
        + 0.08 * math.sin(TAU * frequency * 3.0 * t) * math.exp(-11.0 * t)
    )


def write_wav(name: str, samples: list[float], stereo: bool = False) -> None:
    """同じ入力から同じ PCM ファイルを生成し、既存の生成物を更新する。"""
    pcm = array.array("h", (round(max(-1.0, min(1.0, x)) * 32767) for x in samples))
    if sys.byteorder != "little":
        pcm.byteswap()
    with wave.open(str(OUT / name), "wb") as target:
        target.setnchannels(2 if stereo else 1)
        target.setsampwidth(2)
        target.setframerate(RATE)
        target.writeframes(pcm.tobytes())


def music() -> list[float]:
    """16 秒の循環伴奏。末尾の残響を冒頭へ折り返して継ぎ目を連続させる。"""
    frames = RATE * 16
    left = [0.0] * frames
    right = [0.0] * frames
    chords = ((48, 60, 64, 67, 71), (45, 60, 64, 67, 69),
              (41, 57, 60, 64, 67), (43, 59, 62, 67, 69))
    pattern = (1, 3, 2, 4, 3, 2, 4, 3)
    for bar, chord in enumerate(chords):
        for step, degree in enumerate(pattern):
            start = round((bar * 4.0 + step * 0.5) * RATE)
            pan = 0.3 if step % 2 == 0 else 0.7
            for i in range(round(RATE * 2.1)):
                value = 0.13 * bell(i / RATE, pitch(chord[degree] + 12), 2.1)
                frame = (start + i) % frames
                left[frame] += value * (1.0 - pan)
                right[frame] += value * pan
        for step in (0, 2):
            start = (bar * 4 + step) * RATE
            for i in range(round(RATE * 2.4)):
                t = i / RATE
                value = 0.055 * bell(t, pitch(chord[0]), 2.4)
                frame = (start + i) % frames
                left[frame] += value
                right[frame] += value
    return [sample for pair in zip(left, right) for sample in pair]


def chime(notes: tuple[int, ...], interval: float, duration: float) -> list[float]:
    """和音と短い旋律に共通の合成処理。"""
    last_start = round(RATE * interval * (len(notes) - 1))
    result = [0.0] * (last_start + round(RATE * duration))
    for index, note in enumerate(notes):
        start = round(index * interval * RATE)
        for i in range(round(RATE * duration)):
            result[start + i] += 0.28 * bell(i / RATE, pitch(note), duration)
    return result


def whistle() -> list[float]:
    """呼び寄せには上向きの柔らかい二連音を使う。"""
    result = []
    for i in range(round(RATE * 0.45)):
        t = i / RATE
        local = t if t < 0.20 else t - 0.24
        if local < 0.0:
            result.append(0.0)
            continue
        envelope = math.sin(math.pi * min(local / 0.20, 1.0)) ** 2
        frequency = 900.0 if t < 0.20 else 1150.0
        result.append(0.23 * envelope * math.sin(TAU * frequency * local))
    return result


def throw() -> list[float]:
    """投擲を表す短い下降音。録音や乱数に依存しない。"""
    result = []
    duration = 0.22
    for i in range(round(RATE * duration)):
        t = i / RATE
        envelope = math.sin(math.pi * t / duration) ** 2
        phase = TAU * (620.0 * t - 850.0 * t * t)
        result.append(0.22 * envelope * math.sin(phase))
    return result


def main() -> None:
    """全音声を決定的に更新する。"""
    OUT.mkdir(parents=True, exist_ok=True)
    write_wav("garden.wav", music(), stereo=True)
    write_wav("whistle.wav", whistle())
    write_wav("throw.wav", throw())
    write_wav("delivery.wav", chime((72, 76, 79, 84), 0.09, 0.70))
    write_wav("defeat.wav", chime((55, 62, 67), 0.055, 0.40))
    write_wav("lost.wav", chime((69, 65, 60), 0.17, 0.65))
    print("音声 6 ファイルの生成完了")


if __name__ == "__main__":
    main()
