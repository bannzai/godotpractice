#!/usr/bin/env python3
"""独自の楽譜と固定 seed から、場面別の BGM / 環境音 / SE を再生成する。"""

from array import array
from functools import lru_cache
from pathlib import Path
import argparse
import io
import json
import math
import random
import sys
import wave


ROOT = Path(__file__).resolve().parents[2] / "assets" / "audio"
RATE = 22050
TAU = math.tau
MUSIC_NAMES = ("title", "map", "battle", "boss", "result", "victory")
AMBIENCE_NAMES = ("ambience_wind", "ambience_fire", "ambience_paper")
EFFECT_NAMES = ("card", "attack", "block", "heal", "power", "death", "transition", "page", "quill")


@lru_cache(maxsize=256)
def instrument(kind, midi, duration):
    """撥弦・笛・持続音・低音・金属音を異なる倍音と包絡で作る。"""
    frequency = 440 * 2 ** ((midi - 69) / 12)
    values = array("f")
    rng = random.Random(410 + midi)
    for frame in range(round(duration * RATE)):
        time = frame / RATE
        phase = TAU * frequency * time
        edge = min(1, time / .008, (duration - time) / .045)
        if kind == "pluck":
            tone = sum(math.sin(phase * harmonic) * math.exp(-time * harmonic * 2.8)
                       / harmonic for harmonic in range(1, 7))
            tone += rng.uniform(-1, 1) * math.exp(-time * 100) * .12
        elif kind == "flute":
            phase += .018 * math.sin(TAU * 5.1 * time)
            tone = (math.sin(phase) + .24 * math.sin(phase * 2)
                    + .11 * math.sin(phase * 3)) * min(1, time / .09)
            tone *= .85 + .15 * math.sin(math.pi * time / duration)
        elif kind == "pad":
            tone = (math.sin(phase) + .3 * math.sin(phase * 2.002)
                    + .2 * math.sin(phase * .998) + .08 * math.sin(phase * 3))
            tone *= min(1, time / .3, (duration - time) / .4) * .6
        elif kind == "bass":
            tone = (math.sin(phase) + .26 * math.sin(phase * 2)
                    + .13 * math.sin(phase * 3)) * math.exp(-time * 2)
        elif kind == "brass":
            tone = sum(math.sin(phase * harmonic) / harmonic
                       for harmonic in range(1, 7))
            tone *= min(1, time / .025) * math.exp(-time * 2.5)
        else:  # ベルは整数倍でない部分音を時間差で減衰させる。
            tone = (math.sin(phase) * math.exp(-time * 2.5)
                    + .45 * math.sin(phase * 2.76) * math.exp(-time * 5)
                    + .18 * math.sin(phase * 5.4) * math.exp(-time * 9))
        values.append(tone * edge)
    return values


@lru_cache(maxsize=8)
def drum(kind):
    """ノイズ、膜のピッチ降下、金属の部分音を打楽器ごとに組み合わせる。"""
    rng = random.Random({"kick": 61, "snare": 63, "hat": 67, "gong": 71}[kind])
    duration = {"kick": .34, "snare": .21, "hat": .09, "gong": 1.8}[kind]
    values = array("f")
    previous = 0
    for frame in range(round(duration * RATE)):
        time = frame / RATE
        noise = rng.uniform(-1, 1)
        if kind == "kick":
            phase = TAU * (48 * time + 65 * (1 - math.exp(-time * 25)) / 25)
            value = math.sin(phase) * math.exp(-time * 15)
            value += noise * math.exp(-time * 150) * .15
        elif kind == "snare":
            value = (.65 * noise + .22 * math.sin(TAU * 178 * time))
            value *= math.exp(-time * 24)
        elif kind == "hat":
            value = (noise - previous) * .5 * math.exp(-time * 65)
        else:
            value = sum(math.sin(TAU * 92 * ratio * time) / (index + 1)
                        for index, ratio in enumerate([1, 1.47, 2.09, 3.17, 4.61]))
            value *= math.exp(-time * 3) * min(1, time / .003)
        previous = noise
        values.append(value * min(1, (duration - time) / .02))
    return values


def mix(channels, values, start, gain, pan=0):
    """循環バッファに一つの発音を足す。同じ楽譜を一度だけ走査して呼ぶ。"""
    offset = round(start * RATE)
    length = len(channels[0])
    left = gain * math.sqrt((1 - pan) / 2)
    right = gain * math.sqrt((1 + pan) / 2)
    for index, value in enumerate(values):
        frame = (offset + index) % length
        channels[0][frame] += value * left
        channels[1][frame] += value * right


def write_wav(name, channels, ambience=False):
    """入力から常に同じ 16 bit stereo PCM を出力し、過大振幅を防ぐ。"""
    length = len(channels[0])
    if ambience:
        dry = [array("f", channel) for channel in channels]
        for delay, decay in [(.113, .13), (.227, .09), (.349, .055)]:
            offset = round(delay * RATE)
            for side in range(2):
                for frame in range(length):
                    channels[side][frame] += dry[1 - side][(frame - offset) % length] * decay
    peak = max(abs(value) for channel in channels for value in channel)
    gain = .84 / max(peak, .01)
    pcm = array("h")
    for frame in range(length):
        edge = min(1, frame / (RATE * .008), (length - 1 - frame) / (RATE * .008))
        for side in range(2):
            pcm.append(round(channels[side][frame] * gain * edge * 32767))
    if sys.byteorder != "little":
        pcm.byteswap()
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    path = ROOT / f"{name}.wav"
    data = buffer.getvalue()
    if path.is_file() and path.read_bytes() == data:
        return
    ROOT.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def make_music(name, bpm, chords, melody, lead, rhythm):
    """8 小節。和声・旋律・伴奏の組み合わせを場面ごとに変える。"""
    beat = 60 / bpm
    channels = [array("f", [0]) * round(beat * 32 * RATE) for _ in range(2)]
    for bar in range(8):
        chord = chords[bar % len(chords)]
        start = bar * 4 * beat
        for index, note in enumerate(chord):
            mix(channels, instrument("pad", note, round(beat * 4.2, 4)),
                start, .11, (index - 1) * .5)
        steps = 8 if rhythm in ("battle", "boss") else 4
        for step in range(steps):
            note = chord[[0, 1, 2, 1, 0, 2, 1, 2][step] % len(chord)] + 12
            mix(channels, instrument("pluck", note, round(beat * 1.3, 4)),
                start + step * beat * 4 / steps, .15, -.4)
        for step in range(4):
            note = melody[(bar * 4 + step) % len(melody)]
            if note:
                mix(channels, instrument(lead, note, round(beat * .91, 4)),
                    start + step * beat, .21, .22)
        for step in ([0, 2] if rhythm not in ("battle", "boss") else [0, 1.5, 2, 3]):
            mix(channels, instrument("bass", chord[0] - 12, round(beat * 1.8, 4)),
                start + step * beat, .20)
        if rhythm in ("battle", "boss", "victory"):
            for step in ([0, 1.5, 2, 3.5] if rhythm == "boss" else [0, 2]):
                mix(channels, drum("kick"), start + step * beat, .40)
            for step in [1, 3]:
                mix(channels, drum("snare"), start + step * beat, .15, .1)
            for step in range(8):
                mix(channels, drum("hat"), start + (step * .5 + .25) * beat, .06, .6)
        if rhythm == "boss" and bar % 2 == 0:
            mix(channels, drum("gong"), start, .20, -.2)
        if rhythm in ("title", "map", "victory"):
            mix(channels, instrument("bell", chord[2] + 24, round(beat * 2.5, 4)),
                start + beat * 2.5, .10, .55)
    write_wav(name, channels, ambience=True)


def make_ambiences():
    """羊皮紙の本を開く場面へ重ねる、風・焚火・紙の循環環境音を作る。"""
    duration = 8.0
    length = round(duration * RATE)

    rng = random.Random(1201)
    channels = [array("f", [0]) * length for _ in range(2)]
    low = [0.0, 0.0]
    for frame in range(length):
        time = frame / RATE
        gust = .38 + .22 * math.sin(TAU * time / duration * 2)
        gust += .15 * math.sin(TAU * time / duration * 5 + .8)
        shared = rng.uniform(-1, 1)
        for side in range(2):
            source = shared * .72 + rng.uniform(-1, 1) * .28
            low[side] += (source - low[side]) * (.004 + side * .001)
            drift = math.sin(TAU * time / duration * (3 + side) + side * 1.7) * .035
            channels[side][frame] = (low[side] * 5.5 + drift) * gust
    write_wav("ambience_wind", channels)

    rng = random.Random(1207)
    channels = [array("f", [0]) * length for _ in range(2)]
    ember = [0.0, 0.0]
    base = [0.0, 0.0]
    for frame in range(length):
        time = frame / RATE
        shared = rng.uniform(-1, 1)
        for side in range(2):
            noise = shared * .45 + rng.uniform(-1, 1) * .55
            base[side] += (noise - base[side]) * .012
            ember[side] *= .972
            if rng.random() < .00062:
                ember[side] += rng.uniform(.35, 1.0)
            pop = noise * ember[side]
            glow = math.sin(TAU * (64 + side * 3) * time) * .025
            channels[side][frame] = base[side] * .9 + pop * .7 + glow
    write_wav("ambience_fire", channels)

    rng = random.Random(1213)
    channels = [array("f", [0]) * length for _ in range(2)]
    rustles = [(1.15, .23, -.45), (3.45, .34, .38), (5.82, .26, -.12), (7.1, .18, .5)]
    previous = 0.0
    for frame in range(length):
        time = frame / RATE
        noise = rng.uniform(-1, 1)
        dry = noise - previous
        previous = noise
        left = 0.0
        right = 0.0
        for center, width, pan in rustles:
            distance = (time - center) / width
            envelope = math.exp(-distance * distance * 2.4)
            texture = dry * envelope * (.62 + .38 * math.sin(TAU * 37 * time) ** 2)
            left += texture * math.sqrt((1 - pan) / 2)
            right += texture * math.sqrt((1 + pan) / 2)
        channels[0][frame] = left
        channels[1][frame] = right
    write_wav("ambience_paper", channels)


def make_effects():
    for ordinal, name in enumerate(EFFECT_NAMES):
        duration = {"card": .19, "attack": .42, "block": .58, "heal": .95,
                    "power": 1.05, "death": .85, "transition": .45,
                    "page": .72, "quill": .48}[name]
        rng = random.Random(820 + ordinal)
        channels = [array("f", [0]) * round(duration * RATE) for _ in range(2)]
        previous = 0
        for frame in range(len(channels[0])):
            time = frame / RATE
            ratio = time / duration
            noise = rng.uniform(-1, 1)
            if name == "card":
                value = (noise - previous) * math.sin(math.pi * ratio) ** 2 * .26
                value += math.sin(TAU * 1200 * time) * math.exp(-time * 60) * .12
            elif name == "attack":
                value = noise * math.exp(-((time - .055) / .035) ** 2) * .4
                hit = max(0, time - .07)
                value += (math.sin(TAU * (110 * hit - 60 * hit * hit)) + noise * .4)
                value *= math.exp(-hit * 16) * min(1, time / .015)
            elif name == "block":
                value = sum(math.sin(TAU * frequency * time) * amplitude
                            for frequency, amplitude in [(615, .4), (977, .28), (1612, .18)])
                value *= math.exp(-time * 9)
                value += noise * math.exp(-time * 85) * .3
            elif name == "heal":
                value = 0
                for index, note in enumerate([76, 79, 83, 88]):
                    local = time - index * .12
                    if local >= 0:
                        frequency = 440 * 2 ** ((note - 69) / 12)
                        value += (math.sin(TAU * frequency * local)
                                  + .24 * math.sin(TAU * frequency * 2.76 * local)) * math.exp(-local * 7) * .3
            elif name == "power":
                phase = TAU * (180 * time + 460 * time * time)
                value = sum(math.sin(phase * harmonic) / harmonic for harmonic in range(1, 5))
                value *= math.sin(math.pi * ratio) ** 1.4 * .4
            elif name == "death":
                phase = TAU * (180 * time - 80 * time * time)
                value = (math.sin(phase) + .3 * math.sin(phase * 1.47) + noise * .25)
                value *= math.exp(-time * 5) * min(1, time / .012)
            elif name == "transition":
                value = ((noise - previous) * .22
                         + math.sin(TAU * (400 * time + 850 * time * time)) * .12)
                value *= math.sin(math.pi * ratio) ** 2
            elif name == "page":
                sweep = math.sin(math.pi * ratio) ** .65
                fiber = (noise - previous) * (.38 + .32 * math.sin(TAU * 29 * time) ** 2)
                flex = math.sin(TAU * (78 + 105 * ratio) * time) * .08
                value = (fiber + flex) * sweep
                if .72 < ratio < .82:
                    value += noise * math.sin(math.pi * (ratio - .72) / .1) * .34
            else:  # 羽根ペンが羊皮紙を短く走る、細い引っかき音。
                strokes = .35 + .65 * max(0, math.sin(TAU * 8.5 * time))
                scratch = (noise - previous) * strokes
                nib = math.sin(TAU * (920 + 90 * math.sin(TAU * 6 * time)) * time)
                value = (scratch * .26 + nib * .045) * math.sin(math.pi * ratio) ** .55
            previous = noise
            value *= min(1, time / .004, (duration - time) / .04)
            channels[0][frame] = value * math.sqrt(.6 - ratio * .2)
            channels[1][frame] = value * math.sqrt(.4 + ratio * .2)
        write_wav(name, channels)


def asset_spec():
    """game-asset-search の数値検査と再生成比較へ渡す音声定義。"""
    loops = set(MUSIC_NAMES + AMBIENCE_NAMES)
    return {
        "rate": RATE,
        "images": [],
        "audio": [
            {"path": f"{name}.wav", "loop": name in loops, "stereo": True}
            for name in MUSIC_NAMES + AMBIENCE_NAMES + EFFECT_NAMES
        ],
    }


def main():
    global ROOT
    parser = argparse.ArgumentParser(description="固定 seed の BGM・環境音・効果音を生成する")
    parser.add_argument("--out-dir", type=Path, default=ROOT, help="WAV の生成先")
    parser.add_argument("--print-spec", action="store_true", help="検査用の音声定義だけを JSON 出力する")
    arguments = parser.parse_args()
    if arguments.print_spec:
        print(json.dumps(asset_spec(), ensure_ascii=False))
        return 0
    ROOT = arguments.out_dir
    minor = [(50, 53, 57), (46, 50, 53), (48, 52, 55), (45, 49, 52)]
    make_music("title", 80, minor,
               [74, 0, 77, 76, 74, 69, 0, 72, 76, 0, 79, 77, 73, 76, 69, 0], "flute", "title")
    make_music("map", 94, [(50, 53, 57), (48, 52, 55), (46, 50, 53), (48, 52, 55)],
               [74, 69, 77, 76, 72, 67, 76, 74, 70, 65, 74, 72, 72, 76, 79, 76], "pluck", "map")
    make_music("battle", 132, minor,
               [74, 77, 81, 77, 70, 74, 77, 81, 72, 76, 79, 76, 73, 76, 81, 73], "pluck", "battle")
    make_music("boss", 156, [(38, 41, 45), (39, 43, 46), (38, 41, 45), (37, 41, 44)],
               [62, 62, 69, 65, 63, 67, 70, 67, 62, 65, 69, 70, 61, 65, 68, 73], "brass", "boss")
    make_music("result", 62, [(50, 53, 57), (46, 50, 53), (43, 46, 50), (45, 49, 52)],
               [77, 0, 74, 0, 74, 0, 70, 0, 70, 0, 67, 0, 69, 0, 73, 0], "bell", "result")
    make_music("victory", 112, [(50, 54, 57), (55, 59, 62), (47, 50, 54), (45, 49, 52)],
               [74, 78, 81, 86, 83, 81, 79, 78, 78, 81, 83, 86, 85, 81, 78, 73], "flute", "victory")
    make_ambiences()
    make_effects()
    print("独自 BGM 6 曲、環境音 3 点、効果音 9 点を生成しました（22050 Hz / stereo PCM）。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
