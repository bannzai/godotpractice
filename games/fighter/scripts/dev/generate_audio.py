#!/usr/bin/env python3
"""独自の旋律・音色・固定乱数から同じ PCM を冪等に再生成する。外部音源は使わない。"""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[2] / "assets" / "audio"
TAU = math.tau


def write_audio(name, samples):
    """両端を短く減衰し、クリップしない 16 bit mono WAV を保存する。"""
    samples = samples.copy()
    fade = min(round(RATE * 0.004), len(samples) // 2)
    for index in range(fade):
        gain = 0.5 - 0.5 * math.cos(math.pi * index / fade)
        samples[index] *= gain
        samples[-index - 1] *= gain
    gain = 0.82 / (max(abs(value) for value in samples) or 1.0)
    pcm = b"".join(struct.pack("<h", round(value * gain * 32767)) for value in samples)
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / name), "wb") as stream:
        stream.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        stream.writeframes(pcm)


def tone(midi, duration, voice):
    """倍音、FM、非整数倍の共鳴を使い分けた楽器音を返す。"""
    frequency = 440 * 2 ** ((midi - 69) / 12)
    samples = []
    for index in range(round(duration * RATE)):
        t = index / RATE
        phase = TAU * frequency * t
        progress = t / duration
        release = min((duration - t) / 0.06, 1)
        attack = min(t / (0.045 if voice == "pad" else 0.008), 1)
        if voice == "bell":
            value = math.sin(phase + 2.2 * math.exp(-7 * t) * math.sin(phase * 2))
            value += 0.22 * math.sin(phase * 2.76) * math.exp(-10 * t)
            envelope = math.exp(-3.5 * t) * release
        elif voice == "bass":
            value = math.sin(phase) + 0.42 * math.sin(phase * 2)
            value += 0.17 * math.sin(phase * 3)
            envelope = (1 - progress) ** 0.6 * release
        elif voice == "lead":
            value = math.sin(phase + 1.4 * math.sin(phase * 2) * math.exp(-4 * t))
            value += 0.25 * math.sin(phase * 3)
            envelope = (1 - progress) ** 0.45 * release
        elif voice == "brass":
            value = sum(math.sin(phase * h) / h for h in range(1, 7))
            envelope = (1 - progress) ** 0.35 * release
        else:
            value = math.sin(phase) + 0.32 * math.sin(phase * 1.003)
            value += 0.17 * math.sin(phase * 3)
            envelope = math.sin(math.pi * progress) ** 0.55
        samples.append(value * attack * envelope)
    return samples


def drum(kind, seed):
    """固定乱数のドラム。高域のノイズと低域の胴鳴りを組み合わせる。"""
    noise = random.Random(seed)
    duration = {"kick": 0.24, "snare": 0.19, "hat": 0.055, "open": 0.18,
                "clap": 0.2, "tom": 0.26}[kind]
    samples = []
    previous = 0.0
    for index in range(round(duration * RATE)):
        t = index / RATE
        raw = noise.uniform(-1, 1)
        bright = (raw - previous) * 0.5
        previous = raw
        if kind == "kick":
            phase = TAU * (48 * t + 2.4 * (1 - math.exp(-32 * t)))
            value = math.sin(phase) * math.exp(-19 * t) + bright * math.exp(-100 * t) * 0.15
        elif kind == "snare":
            value = (0.7 * bright + 0.3 * math.sin(TAU * 185 * t)) * math.exp(-24 * t)
        elif kind == "clap":
            burst = sum(math.exp(-100 * (t - s)) for s in (0, 0.012, 0.024) if t >= s)
            value = bright * (0.45 * burst + 0.3 * math.exp(-21 * t))
        elif kind == "tom":
            phase = TAU * (110 * t + 1.7 * (1 - math.exp(-22 * t)))
            value = math.sin(phase) * math.exp(-17 * t)
        else:
            value = bright * math.exp(-(65 if kind == "hat" else 21) * t)
        samples.append(value * min(t / 0.0015, 1) * min((duration - t) / 0.015, 1))
    return samples


class Score:
    """拍からループへ配置する。音の追加は非冪等だが、曲全体の再構築は冪等。"""

    def __init__(self, bpm, bars, seed):
        self.beat = 60 / bpm
        self.samples = [0.0] * round(bars * 4 * self.beat * RATE)
        self.drums = {kind: drum(kind, seed + index) for index, kind in
                      enumerate(("kick", "snare", "hat", "open", "clap", "tom"))}

    def mix(self, beat, values, volume):
        """音源を加算するため非冪等。末尾の余韻を先頭へ回してループにつなぐ。"""
        start = round(beat * self.beat * RATE)
        length = len(self.samples)
        for index, value in enumerate(values):
            self.samples[(start + index) % length] += value * volume

    def note(self, beat, duration, midi, volume, voice):
        """指定拍へ加算するため非冪等。毎回新規 Score を作り同じ結果を得る。"""
        self.mix(beat, tone(midi, duration * self.beat, voice), volume)

    def percussion(self, beat, kind, volume):
        """打音を加算するため非冪等。音源自体は固定乱数で決定的に生成する。"""
        self.mix(beat, self.drums[kind], volume)


def title_music():
    """96 BPM、6 小節。ベルの呼びかけと広い和音、ゆったりしたハーフタイム。"""
    score = Score(96, 6, 130)
    chords = ((52, 55, 59), (48, 52, 55), (43, 47, 50),
              (50, 54, 57), (48, 52, 55), (47, 54, 57))
    melody = ((76, 71, 74), (72, 76, 79), (74, 71, 67),
              (69, 74, 78), (76, 72, 67), (71, 74, 78))
    for bar, chord in enumerate(chords):
        start = bar * 4
        for midi in chord:
            score.note(start, 4.4, midi, 0.06, "pad")
        score.note(start, 2.8, chord[0] - 12, 0.2, "bass")
        for offset, midi in zip((0.5, 1.5, 3), melody[bar]):
            score.note(start + offset, 1.25, midi, 0.10, "bell")
        score.percussion(start, "kick", 0.35)
        score.percussion(start + 2, "clap", 0.14)
        for offset in (0.5, 1.5, 2.5, 3.5):
            score.percussion(start + offset, "hat", 0.09)
    write_audio("title.wav", score.samples)


def arena_music():
    """128 BPM、8 小節。FM リードと細かいベース、力強いバックビート。"""
    score = Score(128, 8, 470)
    chords = ((45, 48, 52), (41, 45, 48), (48, 52, 55), (43, 47, 50))
    phrases = ((69, 72, 76, 74, 72, 69), (69, 72, 77, 76, 72, 69),
               (72, 76, 79, 76, 74, 72), (71, 74, 79, 77, 74, 71))
    for bar in range(8):
        chord = chords[bar % 4]
        start = bar * 4
        for offset in (0, 0.75, 1.5, 2, 2.75, 3.5):
            score.note(start + offset, 0.44, chord[0] - 12, 0.23, "bass")
        for offset in (0, 2):
            for midi in chord:
                score.note(start + offset, 0.9, midi + 12, 0.04, "brass")
        for offset, midi in zip((0.5, 1, 1.75, 2.5, 3, 3.5), phrases[bar % 4]):
            score.note(start + offset, 0.42, midi + (12 if bar == 7 else 0), 0.1, "lead")
        for offset in (0, 1.5, 2, 3.25):
            score.percussion(start + offset, "kick", 0.44)
        for offset in (1, 3):
            score.percussion(start + offset, "snare", 0.32)
        for half in range(8):
            score.percussion(start + half * 0.5, "open" if half == 7 else "hat", 0.11)
        if bar in (3, 7):
            for offset in (3.25, 3.5, 3.75):
                score.percussion(start + offset, "tom", 0.17)
    write_audio("arena.wav", score.samples)


def final_music():
    """160 BPM、8 小節。鋭いブラスと短い反復音、倍速ハイハットで決着を急ぐ。"""
    score = Score(160, 8, 810)
    chords = ((38, 41, 45), (34, 38, 41), (36, 40, 43), (33, 37, 40))
    for bar in range(8):
        chord = chords[bar % 4]
        start = bar * 4
        for eighth in range(8):
            score.note(start + eighth * 0.5, 0.4, chord[0] + (12 if eighth % 3 == 2 else 0),
                       0.20, "bass")
            score.note(start + eighth * 0.5, 0.25, chord[(eighth + bar) % 3] + 36,
                       0.065, "brass")
        for offset in (0, 1.5, 2.75):
            for midi in chord:
                score.note(start + offset, 0.65, midi + 24, 0.048, "brass")
        for offset in (0, 1, 2, 2.5, 3.5):
            score.percussion(start + offset, "kick", 0.48)
        for offset in (1, 3):
            score.percussion(start + offset, "snare", 0.38)
            score.percussion(start + offset, "clap", 0.11)
        for sixteenth in range(16):
            score.percussion(start + sixteenth * 0.25, "hat", 0.07 if sixteenth % 2 else 0.14)
    write_audio("final.wav", score.samples)


def result_music():
    """112 BPM、6 小節。長調の上行するベルと軽い跳ねたリズムで試合を締める。"""
    score = Score(112, 6, 950)
    chords = ((48, 52, 55), (43, 47, 50), (45, 48, 52),
              (41, 45, 48), (43, 47, 50), (48, 52, 55))
    phrases = ((72, 76, 79, 84), (74, 79, 83, 79), (76, 81, 84, 81),
               (77, 81, 84, 86), (79, 83, 86, 83), (84, 79, 76, 72))
    for bar, chord in enumerate(chords):
        start = bar * 4
        for midi in chord:
            score.note(start, 3.9, midi + 12, 0.055, "pad")
        bass = (chord[0] - 12, chord[0], chord[0] - 12, chord[2] - 12)
        for offset, midi in zip((0, 1.5, 2, 3.5), bass):
            score.note(start + offset, 0.7, midi, 0.19, "bass")
        for offset, midi in zip((0, 0.75, 1.5, 2.75), phrases[bar]):
            score.note(start + offset, 0.95, midi, 0.10, "bell")
        for offset in (0, 2):
            score.percussion(start + offset, "kick", 0.30)
        for offset in (1, 3):
            score.percussion(start + offset, "clap", 0.16)
        for offset in (0.0, 0.66, 1, 1.66, 2, 2.66, 3, 3.66):
            score.percussion(start + offset, "hat", 0.075)
    write_audio("result.wav", score.samples)


def effects():
    """衝撃・金属共鳴・空気の流れに、決定音と KO の低い余韻を加える。"""
    noise = random.Random(731)
    for name, duration in (("hit", 0.30), ("guard", 0.42), ("special", 0.68),
                           ("confirm", 0.24), ("ko", 0.95)):
        samples = []
        for index in range(round(RATE * duration)):
            t = index / RATE
            raw = noise.uniform(-1, 1)
            if name == "hit":
                body = math.sin(TAU * (62 * t + 1.1 * (1 - math.exp(-42 * t))))
                value = body * math.exp(-20 * t) + 0.6 * raw * math.exp(-47 * t)
            elif name == "guard":
                value = sum(math.sin(TAU * frequency * t) for frequency in (610, 977, 1543))
                value = value * math.exp(-15 * t) * 0.26 + 0.3 * raw * math.exp(-72 * t)
            elif name == "special":
                phase = TAU * (150 * t + 540 * t * t)
                value = math.sin(phase + 1.6 * math.sin(phase * 2)) * 0.6 + raw * 0.20
                value *= math.sin(math.pi * t / duration) ** 1.3
            elif name == "confirm":
                frequency = 784 if t < 0.075 else 1174.66
                local_t = t if t < 0.075 else t - 0.075
                value = math.sin(TAU * frequency * local_t)
                value += 0.25 * math.sin(TAU * frequency * 3 * local_t)
                note_length = 0.075 if t < 0.075 else duration - 0.075
                value *= min(local_t / 0.004, 1) * min((note_length - local_t) / 0.01, 1)
                value *= math.exp(-11 * local_t) * 0.6
            else:
                phase = TAU * (38 * t + 4 * (1 - math.exp(-9 * t)))
                value = math.sin(phase) * math.exp(-5 * t)
                value += raw * math.exp(-19 * t) * 0.6
                value += math.sin(TAU * 233 * t) * math.exp(-7 * t) * 0.15
            samples.append(value * min(t / 0.002, 1) * min((duration - t) / 0.04, 1))
        write_audio(f"{name}.wav", samples)


def main():
    effects()
    title_music()
    arena_music()
    final_music()
    result_music()
    print("fighter audio OK: 独自制作 BGM 4 曲・効果音 5 種")


if __name__ == "__main__":
    main()
