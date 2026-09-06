#!/usr/bin/env python3
"""独自の音素材を同じ PCM データへ冪等に再生成する。外部音源は使わない。"""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[2] / "assets" / "audio"
TAU = math.tau


def write_audio(name, samples):
    """クリップを防ぎ、16 bit mono WAV に決定的に保存する。"""
    OUT.mkdir(parents=True, exist_ok=True)
    peak = max(abs(value) for value in samples) or 1.0
    gain = min(0.78 / peak, 1.0)
    pcm = b"".join(struct.pack("<h", round(value * gain * 32767)) for value in samples)
    with wave.open(str(OUT / name), "wb") as stream:
        stream.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        stream.writeframes(pcm)


def effects():
    """固定乱数系列と振動波形で衝撃・防御・特殊攻撃を生成する。"""
    noise = random.Random(731)
    hit = []
    guard = []
    special = []
    for index in range(round(RATE * 0.28)):
        t = index / RATE
        transient = noise.uniform(-1, 1) * math.exp(-35 * t)
        body = math.sin(TAU * (105 * t - 120 * t * t)) * math.exp(-20 * t)
        hit.append((0.56 * transient + 0.62 * body) * min(t * 1000, 1))
    for index in range(round(RATE * 0.4)):
        t = index / RATE
        metallic = sum(math.sin(TAU * frequency * t) for frequency in (510, 773, 1231)) / 3
        guard.append(metallic * math.exp(-14 * t) * min(t * 800, 1) * 0.65)
    for index in range(round(RATE * 0.65)):
        t = index / RATE
        sweep = math.sin(TAU * (170 * t + 490 * t * t))
        high = math.sin(TAU * (340 * t + 980 * t * t)) * 0.24
        envelope = math.sin(math.pi * t / 0.65) ** 1.2
        special.append((sweep + high + noise.uniform(-0.08, 0.08)) * envelope * 0.5)
    write_audio("hit.wav", hit)
    write_audio("guard.wav", guard)
    write_audio("special.wav", special)


def music():
    """120 BPM の 8 小節。周期端を含めた音符の減衰で継ぎ目をなくす。"""
    seconds = 16
    samples = [0.0] * (RATE * seconds)
    noise = random.Random(20260906)
    chords = [(45, 52, 57, 60), (41, 48, 53, 57), (48, 55, 60, 64), (43, 50, 55, 59)]

    def add_note(start, duration, midi, volume, bass=False):
        frequency = 440 * 2 ** ((midi - 69) / 12)
        for index in range(round(duration * RATE)):
            t = index / RATE
            envelope = min(t / 0.012, 1) * max(1 - t / duration, 0) ** 2
            tone = math.sin(TAU * frequency * t)
            tone += (0.35 if bass else 0.18) * math.sin(TAU * frequency * 2 * t)
            samples[(round(start * RATE) + index) % len(samples)] += tone * volume * envelope

    for beat in range(32):
        start = beat * 0.5
        chord = chords[beat // 8]
        add_note(start, 0.42, chord[0] - 12, 0.16, bass=True)
        for half in range(2):
            midi = chord[(beat * 2 + half) % 4] + 12
            add_note(start + half * 0.25, 0.22, midi, 0.075)
        for index in range(round(RATE * 0.21)):
            t = index / RATE
            kick = math.sin(TAU * (65 * t + 2.5 * (1 - math.exp(-25 * t)))) * math.exp(-25 * t)
            snare = noise.uniform(-1, 1) * math.exp(-35 * t) if beat % 2 else 0
            samples[round(start * RATE) + index] += 0.24 * kick + 0.10 * snare
        for half in range(2):
            for index in range(round(RATE * 0.07)):
                t = index / RATE
                samples[round((start + half * 0.25) * RATE) + index] += noise.uniform(-1, 1) * math.exp(-65 * t) * 0.043
    # 周期の端で不連続なクリックが出ないよう、境界の無音へ滑らかに接続する。
    for index in range(220):
        samples[index] *= index / 220
        samples[-index - 1] *= index / 220
    write_audio("arena.wav", samples)


def main():
    effects()
    music()
    print("fighter audio OK")


if __name__ == "__main__":
    main()
