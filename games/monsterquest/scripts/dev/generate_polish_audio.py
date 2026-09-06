#!/usr/bin/env python3
"""場面別のオリジナル曲と効果音を、標準ライブラリだけで同じ WAV に再生成する。"""
from __future__ import annotations

import argparse
from array import array
from functools import lru_cache
import hashlib
import math
from pathlib import Path
import random
import struct
import wave


AUDIO = Path(__file__).resolve().parents[2] / "assets" / "audio"
RATE = 32000
TAU = math.tau


@lru_cache(maxsize=384)
def voice(kind: str, midi: int, duration: float) -> array:
    frequency = 440.0 * 2 ** ((midi - 69) / 12)
    count = round(duration * RATE)
    samples = array("f", [0.0]) * count
    # キャッシュの有無と生成順に音色が依存しないよう、各音に固定の乱数列を持たせる。
    noise = random.Random(f"monsterquest:{kind}:{midi}:{duration}")
    low_noise = 0.0
    for index in range(count):
        time = index / RATE
        phase = TAU * frequency * time
        attack = min(time / 0.009, 1.0)
        release = min((duration - time) / 0.055, 1.0)
        if kind == "flute":
            wobble = 0.035 * math.sin(TAU * 5.1 * time)
            low_noise = low_noise * 0.88 + noise.uniform(-1, 1) * 0.12
            value = (math.sin(phase + wobble) + 0.20 * math.sin(phase * 2 + wobble)
                     + 0.08 * math.sin(phase * 3) + low_noise * 0.10)
            envelope = min(time / 0.045, 1.0) * release * math.exp(-time * 0.5)
        elif kind == "reed":
            wobble = 0.022 * math.sin(TAU * 5.8 * time)
            value = (math.sin(phase + wobble) + 0.33 * math.sin(phase * 3)
                     + 0.14 * math.sin(phase * 5) + 0.05 * math.sin(phase * 7))
            envelope = min(time / 0.025, 1.0) * release * math.exp(-time * 0.9)
        elif kind == "string":
            value = (math.sin(phase) + 0.38 * math.sin(phase * 1.003)
                     + 0.19 * math.sin(phase * 2) + 0.09 * math.sin(phase * 3))
            envelope = min(time / 0.19, 1.0) * min((duration - time) / 0.24, 1.0)
            envelope *= 0.80 + 0.20 * math.sin(math.pi * time / duration)
        elif kind == "pluck":
            value = 0.0
            for harmonic in range(1, 7):
                value += (math.sin(phase * harmonic) / harmonic ** 1.3
                          * math.exp(-time * harmonic * 4.2))
            envelope = min(time / 0.003, 1.0) * release
        elif kind in ("bell", "mallet"):
            metal = kind == "bell"
            value = (math.sin(phase) * math.exp(-time * 2.4)
                     + 0.46 * math.sin(phase * (2.756 if metal else 3.99))
                     * math.exp(-time * 7.0)
                     + 0.20 * math.sin(phase * (5.404 if metal else 9.01))
                     * math.exp(-time * 14.0))
            envelope = min(time / 0.003, 1.0) * release
        elif kind == "bass":
            value = math.sin(phase) + 0.28 * math.sin(phase * 2) + 0.10 * math.sin(phase * 3)
            envelope = attack * release * math.exp(-time * 3.2)
        else:
            raise ValueError(f"未定義の音色: {kind}")
        samples[index] = value * envelope
    return samples


@lru_cache(maxsize=16)
def percussion(kind: str) -> array:
    durations = {"kick": 0.30, "snare": 0.17, "shaker": 0.085, "tom": 0.34, "sweep": 0.30}
    duration = durations[kind]
    count = round(duration * RATE)
    samples = array("f", [0.0]) * count
    noise = random.Random(f"monsterquest:percussion:{kind}")
    previous = 0.0
    low_noise = 0.0
    for index in range(count):
        time = index / RATE
        raw = noise.uniform(-1, 1)
        high = raw - previous
        previous = raw
        low_noise = low_noise * 0.76 + raw * 0.24
        if kind == "kick":
            phase = TAU * (48 * time + 62 / 28 * (1 - math.exp(-28 * time)))
            value = math.sin(phase) * math.exp(-time * 13) + high * 0.07 * math.exp(-time * 150)
        elif kind == "snare":
            value = high * math.exp(-time * 26) * 0.44 + math.sin(TAU * 176 * time) * math.exp(-time * 38) * 0.36
        elif kind == "shaker":
            value = high * math.exp(-time * 52) * 0.31
        elif kind == "tom":
            phase = TAU * (82 * time + 38 / 20 * (1 - math.exp(-20 * time)))
            value = (math.sin(phase) + 0.28 * math.sin(phase * 1.59)) * math.exp(-time * 11)
            value += low_noise * math.exp(-time * 45) * 0.16
        else:
            value = low_noise * math.sin(math.pi * time / duration) ** 2
        samples[index] = value * min(time / 0.002, 1.0) * min((duration - time) / 0.025, 1.0)
    return samples


def mix(buffer: tuple[array, array], samples: array, start: float, gain: float,
        pan: float = 0.0, loop: bool = True) -> None:
    """重なった発音を加える作曲処理のため非冪等。生成全体は空のバッファから開始する。"""
    left_gain = gain * math.sqrt((1.0 - pan) / 2.0)
    right_gain = gain * math.sqrt((1.0 + pan) / 2.0)
    begin = round(start * RATE)
    left, right = buffer
    for index, value in enumerate(samples):
        target = begin + index
        if target >= len(left):
            if not loop:
                break
            target %= len(left)
        left[target] += value * left_gain
        right[target] += value * right_gain


def add_note(buffer: tuple[array, array], instrument: str, pitch: int, start: float,
             duration: float, gain: float, pan: float = 0.0, loop: bool = True) -> None:
    """同じタイミングの和音を重ねるため非冪等。"""
    mix(buffer, voice(instrument, pitch, round(duration, 5)), start, gain, pan, loop)


def finish(buffer: tuple[array, array], loop: bool, peak: float) -> bytes:
    left, right = array("f", buffer[0]), array("f", buffer[1])
    length = len(left)
    # 循環する遅延で、曲の終わりの残響を次の周回へ引き継ぐ。
    original_left, original_right = array("f", left), array("f", right)
    for delay_seconds, gain in ((0.071, 0.13), (0.113, 0.10), (0.173, 0.065)):
        delay = round(delay_seconds * RATE)
        for index in range(length):
            source = index - delay
            if source < 0 and not loop:
                continue
            left[index] += original_right[source] * gain
            right[index] += original_left[source] * gain
    for channel in (left, right):
        center = sum(channel) / length
        for index in range(length):
            channel[index] -= center
    largest = max(max(abs(value) for value in left), max(abs(value) for value in right))
    gain = peak / max(largest, 0.000001)
    pcm = bytearray(length * 4)
    for index in range(length):
        envelope = 1.0
        if not loop:
            envelope = min(index / (RATE * 0.003), 1.0, (length - 1 - index) / (RATE * 0.04))
        struct.pack_into("<hh", pcm, index * 4,
                         round(left[index] * gain * envelope * 32767),
                         round(right[index] * gain * envelope * 32767))
    return bytes(pcm)


def compose_music(name: str) -> bytes:
    # 和声・フレーズ・編成を場面ごとに定義し、独立した曲として識別できるようにする。
    settings = {
        "title": (96, 3, [60, 57, 53, 55, 60, 57, 53, 55], "bell"),
        "field": (104, 4, [60, 65, 57, 55, 60, 65, 62, 55], "flute"),
        "battle": (144, 4, [57, 53, 60, 55, 57, 53, 62, 64], "mallet"),
        "boss": (126, 4, [50, 46, 53, 45, 50, 46, 43, 45], "reed"),
        "result": (114, 3, [60, 65, 67, 60, 57, 65, 67, 60], "bell"),
    }
    bpm, beats, roots, lead = settings[name]
    beat = 60.0 / bpm
    count = round(len(roots) * beats * beat * RATE)
    buffer = (array("f", [0.0]) * count, array("f", [0.0]) * count)
    melodies = {
        "title": [[76, 79, 84, 83, 79, 76], [76, 81, 79, 76, 72, 76],
                  [77, 81, 84, 81, 79, 77], [74, 79, 83, 81, 79, 74],
                  [84, 83, 79, 76, 79, 84], [81, 84, 88, 84, 81, 79],
                  [81, 79, 77, 76, 74, 72], [74, 79, 83, 79, 74, 71]],
        "field": [[76, 79, 81, 79, 76, 74, 72, 0], [77, 81, 84, 81, 79, 77, 76, 0],
                  [76, 81, 79, 76, 72, 71, 69, 0], [74, 76, 79, 83, 81, 79, 74, 0],
                  [79, 84, 83, 81, 79, 76, 74, 0], [81, 84, 86, 84, 81, 79, 77, 0],
                  [77, 81, 79, 77, 76, 74, 72, 0], [74, 79, 83, 81, 79, 74, 71, 0]],
        "battle": [[81, 0, 81, 84, 88, 84, 81, 79], [77, 0, 77, 81, 84, 81, 79, 77],
                   [79, 0, 79, 84, 88, 86, 84, 79], [79, 83, 86, 83, 81, 79, 77, 74],
                   [81, 84, 88, 93, 88, 84, 81, 79], [81, 84, 89, 88, 84, 81, 79, 77],
                   [81, 86, 89, 88, 86, 84, 81, 77], [80, 83, 88, 86, 83, 80, 76, 80]],
        "boss": [[74, 0, 74, 77, 81, 0, 77, 76], [70, 0, 74, 77, 82, 81, 77, 74],
                 [77, 0, 81, 84, 81, 77, 76, 74], [73, 0, 76, 81, 79, 76, 73, 69],
                 [86, 81, 77, 74, 77, 81, 86, 84], [82, 81, 77, 74, 70, 74, 77, 81],
                 [79, 0, 82, 86, 84, 82, 79, 77], [81, 0, 85, 88, 85, 81, 76, 73]],
        "result": [[84, 0, 79, 84, 88, 0], [89, 88, 84, 81, 84, 0],
                   [86, 0, 83, 79, 83, 86], [88, 0, 84, 79, 76, 0],
                   [81, 84, 88, 0, 84, 81], [81, 84, 89, 88, 84, 81],
                   [83, 86, 91, 86, 83, 79], [84, 88, 91, 0, 88, 0]],
    }
    minor_roots = {57, 62, 50, 43}
    for bar, root in enumerate(roots):
        start = bar * beats * beat
        minor = root in minor_roots
        if name == "boss":
            minor = root in (50, 43)
        chord = [root, root + (3 if minor else 4), root + 7]
        pad_gain = 0.080 if name in ("title", "result") else 0.045
        for part, pitch in enumerate(chord):
            add_note(buffer, "string", pitch, start, beats * beat + 0.26,
                     pad_gain, (part - 1) * 0.45)
        for step, pitch in enumerate(melodies[name][bar]):
            if pitch:
                length = beat * (0.90 if lead in ("flute", "reed") else 1.5)
                add_note(buffer, lead, pitch, start + step * beat * 0.5, length,
                         0.21 if name != "boss" else 0.16, -0.12)
        for step in range(beats * 2):
            at = start + step * beat * 0.5
            pitch = chord[(step + bar % 2) % 3] + 12
            if name == "boss":
                pitch = root if step % 3 == 0 else root + 7
            add_note(buffer, "pluck", pitch, at, beat * 1.1,
                     0.11 if name in ("field", "title") else 0.075, 0.36)
            if name in ("battle", "boss"):
                mix(buffer, percussion("shaker"), at, 0.09 if step % 2 else 0.045, 0.40)
        for step in range(beats):
            at = start + step * beat
            bass_pitch = root - 12 + (7 if step % 2 else 0)
            add_note(buffer, "bass", bass_pitch, at, beat * 0.84, 0.22, 0.0)
            if name in ("battle", "boss"):
                drum = ("kick" if step % 2 == 0 else "snare") if name == "battle" else ("tom" if step % 2 else "kick")
                mix(buffer, percussion(drum), at, 0.29 if drum == "kick" else 0.20, -0.22 if drum == "tom" else 0.0)
            elif name == "field":
                mix(buffer, percussion("shaker"), at + beat * 0.5, 0.05, -0.30)
        if name == "boss":
            for offset in (1.75, 2.75, 3.5):
                mix(buffer, percussion("tom"), start + offset * beat, 0.16, 0.28)
        if name == "result" and bar in (0, 3, 7):
            for part, pitch in enumerate(chord):
                add_note(buffer, "reed", pitch + 12, start + part * beat * 0.25,
                         beat * 1.9, 0.085, (part - 1) * 0.2)
    return finish(buffer, True, 0.77)


def compose_effect(name: str) -> bytes:
    durations = {"attack": 0.44, "capture": 1.3, "heal": 1.6,
                 "levelup": 1.8, "defeat": 1.6, "ui": 0.18}
    count = round(durations[name] * RATE)
    buffer = (array("f", [0.0]) * count, array("f", [0.0]) * count)
    if name == "attack":
        mix(buffer, percussion("sweep"), 0.0, 0.60, -0.3, False)
        mix(buffer, percussion("snare"), 0.07, 0.38, 0.1, False)
        for index, pitch in enumerate((62, 50, 38)):
            add_note(buffer, "bass", pitch, 0.055 + index * 0.035, 0.20, 0.29, 0.0, False)
    elif name == "capture":
        for index, pitch in enumerate((72, 76, 79, 84)):
            add_note(buffer, "pluck", pitch, index * 0.12, 0.42, 0.24, -0.5 + index * 0.30, False)
        for index, pitch in enumerate((84, 88, 91)):
            add_note(buffer, "bell", pitch, 0.49 + index * 0.08, 0.65, 0.19, 0.0, False)
    elif name == "heal":
        for index, pitch in enumerate((72, 76, 79, 83, 84, 88)):
            add_note(buffer, "bell", pitch, index * 0.13, 0.85, 0.18, -0.4 + index * 0.16, False)
        for pitch in (60, 64, 67):
            add_note(buffer, "string", pitch, 0.0, 1.5, 0.15, 0.0, False)
    elif name == "levelup":
        for index, pitch in enumerate((72, 76, 79, 84, 88, 91, 96)):
            add_note(buffer, "bell", pitch, index * 0.115, 0.95, 0.24, -0.5 + index / 6, False)
        for pitch in (60, 64, 67, 72):
            add_note(buffer, "reed", pitch, 0.72, 0.80, 0.12, 0.0, False)
        mix(buffer, percussion("tom"), 0.73, 0.12, 0.0, False)
    elif name == "defeat":
        for index, pitch in enumerate((69, 65, 62, 57)):
            add_note(buffer, "reed", pitch, index * 0.22, 0.64, 0.19, 0.0, False)
        for pitch in (45, 48, 52):
            add_note(buffer, "string", pitch, 0.12, 1.3, 0.15, 0.0, False)
    else:
        add_note(buffer, "mallet", 88, 0.0, 0.14, 0.24, -0.15, False)
        add_note(buffer, "pluck", 95, 0.032, 0.13, 0.10, 0.15, False)
    return finish(buffer, False, 0.74)


def verify(path: Path, loop: bool) -> str:
    with wave.open(str(path), "rb") as source:
        if (source.getnchannels(), source.getsampwidth(), source.getframerate()) != (2, 2, RATE):
            raise ValueError(f"音声形式の不一致: {path.name}")
        raw = source.readframes(source.getnframes())
    values = array("h")
    values.frombytes(raw)
    if struct.pack("=h", 1) != struct.pack("<h", 1):
        values.byteswap()
    peak = max(abs(value) for value in values) / 32768
    rms = math.sqrt(sum(value * value for value in values) / len(values)) / 32768
    if not 0.05 < rms < 0.4 or peak >= 0.95:
        raise ValueError(f"無音または音量の異常: {path.name}, peak={peak}, rms={rms}")
    boundary = max(abs(values[-2] - values[0]), abs(values[-1] - values[1])) / 32768
    if loop:
        largest_step = max(abs(values[index] - values[index - 2]) for index in range(2, len(values))) / 32768
        if boundary > max(0.025, largest_step):
            raise ValueError(f"ループ境界の不連続: {path.name}, step={boundary}")
        for index in range(0, len(values) - RATE // 5, RATE // 5):
            if max(abs(value) for value in values[index:index + RATE // 5]) < 64:
                raise ValueError(f"BGM に無音区間: {path.name}")
    elif any(values[index] for index in (0, 1, -2, -1)):
        raise ValueError(f"効果音の始端・終端がゼロでない: {path.name}")
    digest = hashlib.sha256(path.read_bytes()).hexdigest()[:16]
    return (f"{path.name}: {len(values) / (2 * RATE):.3f}秒 peak={peak:.3f} "
            f"RMS={rms:.3f} 境界差={boundary:.5f} SHA256={digest}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true", help="既存 WAV の形式・音量・境界を検証する")
    args = parser.parse_args()
    AUDIO.mkdir(parents=True, exist_ok=True)
    music = ("title", "field", "battle", "boss", "result")
    effects = ("attack", "capture", "heal", "levelup", "defeat", "ui")
    for name in music + effects:
        path = AUDIO / f"{name}.wav"
        if not args.verify:
            pcm = compose_music(name) if name in music else compose_effect(name)
            with wave.open(str(path), "wb") as output:
                output.setparams((2, 2, RATE, len(pcm) // 4, "NONE", "not compressed"))
                output.writeframes(pcm)
        print(verify(path, name in music), flush=True)
    print("音源の検証 OK: BGM 5 曲・効果音 6 点", flush=True)


if __name__ == "__main__":
    main()
