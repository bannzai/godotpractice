#!/usr/bin/env python3
"""固定の旋律・乱数からステレオの音楽と効果音を再生成する。外部素材・依存なし。"""

from array import array
from functools import lru_cache
import math
from pathlib import Path
import random
import sys
import wave


OUTPUT = Path(__file__).resolve().parents[2] / "assets" / "audio"
RATE = 22050
TAU = math.tau


@lru_cache(maxsize=512)
def voice(instrument: str, note: int, duration: float) -> array:
    frequency = 440.0 * 2 ** ((note - 69) / 12)
    values = array("f")
    for index in range(round(duration * RATE)):
        time = index / RATE
        phase = TAU * frequency * time
        fade = min(1.0, time / .012, (duration - time) / .08)
        if instrument == "bell":
            value = math.sin(phase + 1.8 * math.exp(-time * 4) * math.sin(phase * 2.01))
            envelope = math.exp(-time * 3.4)
        elif instrument == "pluck":
            value = (math.sin(phase) + .35 * math.sin(phase * 2)
                     + .14 * math.sin(phase * 3) + .09 * math.sin(phase * 5)) / 1.58
            envelope = math.exp(-time * 5.2)
        elif instrument == "brass":
            value = math.tanh(1.5 * (math.sin(phase) + .34 * math.sin(phase * 2)
                                    + .19 * math.sin(phase * 3)))
            envelope = min(1.0, time / .07) * math.exp(-time * 1.4)
        elif instrument == "bass":
            value = (math.sin(phase) + .25 * math.sin(phase * 3)
                     + .12 * math.sin(phase * 5)) / 1.37
            envelope = math.exp(-time * 3.8)
        else:
            value = (math.sin(phase) + .4 * math.sin(phase * 1.003)
                     + .16 * math.sin(phase * 2)) / 1.56
            envelope = min(1.0, time / .3) * math.exp(-time / max(duration, .1))
        values.append(value * envelope * fade)
    return values


@lru_cache(maxsize=16)
def percussion(kind: str) -> array:
    random_source = random.Random({"kick": 117, "snare": 218, "hat": 391, "crash": 552}[kind])
    duration = {"kick": .38, "snare": .25, "hat": .095, "crash": .85}[kind]
    values = array("f")
    previous_noise = 0.0
    for index in range(round(duration * RATE)):
        time = index / RATE
        noise = random_source.uniform(-1, 1)
        if kind == "kick":
            phase = TAU * (48 * time + 75 * (1 - math.exp(-time * 24)) / 24)
            value = math.sin(phase) * math.exp(-time * 14)
        elif kind == "snare":
            value = (.68 * noise + .32 * math.sin(TAU * 175 * time)) * math.exp(-time * 22)
        else:
            value = (noise - previous_noise) * .5 * math.exp(-time * (65 if kind == "hat" else 7))
        previous_noise = noise
        values.append(value * min(1.0, time / .002, (duration - time) / .015))
    return values


def mix(buffer: tuple[array, array], samples: array, start: float,
        level: float, pan: float = 0.0, loop: bool = False) -> None:
    # 加算合成は非冪等。生成全体では固定入力と空の波形を使い、同一ファイルを再現する。
    offset = round(start * RATE)
    left, right = buffer
    left_gain = level * math.sqrt((1.0 - pan) / 2)
    right_gain = level * math.sqrt((1.0 + pan) / 2)
    for index, value in enumerate(samples):
        target = index + offset
        if loop:
            target %= len(left)
        elif target >= len(left):
            break
        left[target] += value * left_gain
        right[target] += value * right_gain


def empty(duration: float) -> tuple[array, array]:
    length = round(duration * RATE)
    return array("f", [0.0]) * length, array("f", [0.0]) * length


def write(name: str, buffer: tuple[array, array], peak_limit: float) -> None:
    peak = max(max(abs(sample) for sample in channel) for channel in buffer)
    gain = peak_limit / max(peak, .001)
    pcm = array("h")
    energy = 0.0
    for left, right in zip(*buffer):
        for sample in (left, right):
            value = round(sample * gain * 32767)
            pcm.append(value)
            energy += (value / 32767) ** 2
    if sys.byteorder != "little":
        pcm.byteswap()
    with wave.open(str(OUTPUT / f"{name}.wav"), "wb") as target:
        target.setnchannels(2)
        target.setsampwidth(2)
        target.setframerate(RATE)
        target.writeframes(pcm.tobytes())
    rms_db = 20 * math.log10(math.sqrt(energy / len(pcm)))
    print(f"{name}: {len(buffer[0]) / RATE:.3f} 秒、最大振幅 {peak_limit:.2f}、RMS {rms_db:.1f} dBFS")


def music(scene: str, tempo: int, chords: tuple, melody: tuple, bars: int = 8) -> None:
    beat = 60.0 / tempo
    buffer = empty(bars * 4 * beat)
    for bar in range(bars):
        chord = chords[bar % len(chords)]
        start = bar * 4 * beat
        for index, note in enumerate(chord):
            mix(buffer, voice("pad", note, round(beat * 5, 3)), start,
                .12 if scene != "boss" else .075, (index - 1) * .6, True)
        for step in range(8):
            moment = start + step * beat / 2
            if scene in ("duel", "boss"):
                bass_note = chord[0] - 12 + (12 if step % 3 == 2 else 0)
                mix(buffer, voice("bass", bass_note, round(beat * .7, 3)),
                    moment, .32, 0, True)
                mix(buffer, percussion("hat"), moment,
                    .09 if step % 2 else .14, .32, True)
            if scene != "defeat" and (scene != "title" or step % 2 == 0):
                mix(buffer, voice("pluck", chord[(step + bar) % 3] + 12, .8),
                    moment, .19, -.5 if step % 2 else .5, True)
        for pulse in range(4):
            moment = start + pulse * beat
            if scene in ("duel", "boss", "victory"):
                mix(buffer, percussion("kick"), moment,
                    .38 if pulse % 2 == 0 else .12, 0, True)
                if pulse % 2:
                    mix(buffer, percussion("snare"), moment, .19, -.12, True)
            note = melody[bar % len(melody)][pulse]
            if note < 0:
                continue
            instrument = "brass" if scene in ("boss", "victory") else "bell"
            duration = 1.3 if scene != "defeat" else 2.4
            sound = voice(instrument, note, duration)
            mix(buffer, sound, moment, .23 if scene != "defeat" else .19, -.1, True)
            mix(buffer, sound, moment + beat * .75, .055, .65, True)
        if scene in ("boss", "victory") and bar % 4 == 0:
            mix(buffer, percussion("crash"), start, .16, .3, True)
    write(f"bgm_{scene}", buffer, .72)


def sweep(duration: float, first: float, last: float, seed: int, metallic: bool) -> array:
    noise_source = random.Random(seed)
    values = array("f")
    phase = 0.0
    previous_noise = 0.0
    for index in range(round(duration * RATE)):
        progress = index / (duration * RATE)
        phase += TAU * (first + (last - first) * progress) / RATE
        noise = noise_source.uniform(-1, 1)
        value = .45 * math.sin(phase) + .35 * (noise - previous_noise)
        if metallic:
            value += .25 * math.sin(phase * 2.71)
        envelope = min(1.0, progress * 60) * (1 - progress) ** 2
        values.append(value * envelope)
        previous_noise = noise
    return values


def effects() -> None:
    specifications = {
        "draw": ("pluck", (79, 86), .055, .38),
        "summon": ("bell", (55, 62, 67, 74), .065, 1.0),
        "victory": ("brass", (60, 64, 67, 72, 76), .12, 1.0),
        "boost": ("bell", (67, 71, 74, 79), .06, .8),
        "trap": ("bell", (74, 68, 63, 56), .048, .6),
    }
    for name, (instrument, notes, spacing, duration) in specifications.items():
        buffer = empty(duration + spacing * len(notes))
        for index, note in enumerate(notes):
            mix(buffer, voice(instrument, note, duration), index * spacing,
                .4, -.3 + .6 * index / len(notes))
        if name in ("summon", "trap"):
            mix(buffer, sweep(.6, 150, 900 if name == "summon" else 65, 102, True), 0, .19)
        write(name, buffer, .78)
    for name, duration, first, last, seed in (
        ("attack", .32, 720, 70, 195),
        ("destroy", .8, 260, 35, 281),
        ("damage", .37, 135, 45, 401),
        ("transition", .55, 160, 980, 590),
    ):
        buffer = empty(duration + .15)
        mix(buffer, sweep(duration, first, last, seed, name == "destroy"), 0, .6)
        if name != "transition":
            mix(buffer, percussion("kick"), 0, .35)
        write(name, buffer, .78)


def ambience() -> None:
    """暖炉、紙、振り子を模した12秒の継ぎ目のない室内環境音を作る。"""
    duration = 12.0
    buffer = empty(duration)
    room = array("f")
    for index in range(round(duration * RATE)):
        time = index / RATE
        value = (.30 * math.sin(TAU * 55 * time)
                 + .10 * math.sin(TAU * 110 * time)
                 + .06 * math.sin(TAU * 220 * time))
        room.append(value)
    mix(buffer, room, 0, .09)
    for index, moment in enumerate((.7, 2.2, 3.8, 5.1, 6.9, 8.4, 10.1, 11.2)):
        crackle = sweep(.18, 520, 1700, 810 + index, True)
        mix(buffer, crackle, moment, .055, -.65 + (index % 4) * .43)
    for index, moment in enumerate((1.5, 3.0, 4.5, 6.0, 7.5, 9.0, 10.5)):
        tick = voice("pluck", 84 if index % 2 == 0 else 79, .12)
        mix(buffer, tick, moment, .035, -.22 if index % 2 == 0 else .22)
    for index, moment in enumerate((4.0, 9.6)):
        rustle = sweep(.55, 900, 160, 1200 + index, False)
        mix(buffer, rustle, moment, .045, -.45 if index == 0 else .45)
    write("ambience", buffer, .46)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    music("title", 84,
          ((57, 60, 64), (53, 57, 60), (48, 55, 60), (55, 59, 62)),
          ((81, -1, 76, 79), (77, -1, 76, -1), (72, 76, 79, -1), (74, -1, 71, 76)))
    music("duel", 112,
          ((50, 53, 57), (46, 50, 53), (48, 52, 55), (45, 49, 52)),
          ((74, 77, 81, 77), (74, 70, 77, 74), (72, 76, 79, 76), (73, 76, 81, 73)))
    music("boss", 140,
          ((45, 48, 52), (41, 45, 48), (44, 47, 50), (40, 44, 47)),
          ((69, 76, 72, 71), (69, 72, 77, 76), (68, 71, 74, 71), (68, 71, 76, 80)))
    music("victory", 108,
          ((48, 52, 55), (53, 57, 60), (55, 59, 62), (48, 52, 55)),
          ((72, 76, 79, 84), (81, -1, 79, 77), (79, 83, 86, 83), (84, -1, 79, -1)))
    music("defeat", 64,
          ((45, 48, 52), (41, 45, 48), (43, 47, 50), (45, 48, 52)),
          ((69, -1, 64, -1), (65, -1, 60, -1), (62, -1, 59, -1), (57, -1, -1, -1)), 4)
    effects()
    ambience()


if __name__ == "__main__":
    main()
