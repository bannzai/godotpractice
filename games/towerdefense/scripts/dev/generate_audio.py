#!/usr/bin/env python3
"""黄昏の灯砦の独自譜面と固定 seed から場面別 BGM / SE を再生成する。"""

from array import array
from functools import lru_cache
from pathlib import Path
import math
import random
import sys
import wave


ROOT = Path(__file__).resolve().parents[2] / "assets" / "audio"
RATE = 22050
TAU = math.tau


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
    ROOT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(ROOT / f"{name}.wav"), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())


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


def make_effects():
    """弦、爆風、氷の部分音、太陽砲の唸りを別々の包絡で合成する。"""
    names = ['arrow', 'mortar', 'frost', 'sun', 'build', 'hit', 'death', 'wave', 'base']
    durations = [.24, .7, .65, .9, .55, .22, .58, 1.1, .8]
    for ordinal, (name, duration) in enumerate(zip(names, durations)):
        rng = random.Random(3939 + ordinal)
        channels = [array('f', [0]) * round(duration * RATE) for _ in range(2)]
        previous = 0
        for frame in range(len(channels[0])):
            time = frame / RATE
            ratio = time / duration
            noise = rng.uniform(-1, 1)
            if name == 'arrow':
                phase = TAU * (720 * time - 850 * time * time)
                value = (.6 * math.sin(phase) + .25 * math.sin(phase * 2.7)) * math.exp(-time * 28)
                value += (noise - previous) * .25 * math.exp(-((time-.045)/.03)**2)
            elif name == 'mortar':
                phase = TAU * (91 * time + 30 * (1-math.exp(-time*30))/30)
                value = (math.sin(phase) + noise * .55) * math.exp(-time*7)
                value += noise * math.exp(-time*95) * .8
            elif name == 'frost':
                value = sum(math.sin(TAU * frequency * time) * math.exp(-time * decay) * gain
                            for frequency, decay, gain in [(1480, 7, .6), (2247, 12, .3), (3963, 18, .2)])
                value += (noise-previous)*math.exp(-time*25)*.15
            elif name == 'sun':
                phase = TAU * (124 * time + 490 * time*time)
                value = sum(math.sin(phase * harmonic)/harmonic for harmonic in range(1,7))
                value *= math.sin(math.pi*ratio)**1.4 * .5
                value += math.sin(TAU*1776*time) * math.exp(-((time-.22)/.15)**2)*.2
            elif name == 'build':
                value = noise * math.exp(-time*65) * .55
                for index, frequency in enumerate([523.25, 659.25, 783.99]):
                    local = max(0, time-index*.09)
                    if time >= index*.09:
                        value += (math.sin(TAU*frequency*local)+.24*math.sin(TAU*frequency*2.76*local))*math.exp(-local*12)*.3
            elif name == 'hit':
                value = (noise*.6 + math.sin(TAU*185*time)) * math.exp(-time*28)
            elif name == 'death':
                phase = TAU*(230*time-160*time*time)
                value = (math.sin(phase)+.28*math.sin(phase*1.47)+noise*.18)*math.exp(-time*8)
            elif name == 'wave':
                value = 0
                for index, frequency in enumerate([392,523.25,659.25,783.99]):
                    local = time-index*.16
                    if local >= 0:
                        phase = TAU*frequency*local
                        value += sum(math.sin(phase*h)/h for h in range(1,5))*math.exp(-local*5)*.22
            else:
                value = (math.sin(TAU*72*time) + .5*math.sin(TAU*106*time)+noise*.25)*math.exp(-time*5)
            previous = noise
            value *= min(1,time/.003,(duration-time)/.03)
            channels[0][frame] = value*math.sqrt(.6-ratio*.2)
            channels[1][frame] = value*math.sqrt(.4+ratio*.2)
        write_wav(name, channels)


def main():
    """各場面の独自旋律を上書き再生成し、同じバイト列を得る。"""
    make_music('title', 86, [(55,59,62),(52,55,59),(48,52,55),(50,54,57)],
               [79,0,74,76, 79,83,81,0, 79,76,74,72, 74,78,81,0], 'flute', 'title')
    make_music('stage', 118, [(52,55,59),(48,52,55),(55,59,62),(50,54,57)],
               [76,79,83,79, 76,72,79,76, 74,79,83,86, 81,78,74,78], 'pluck', 'battle')
    make_music('boss', 146, [(40,43,47),(41,45,48),(38,42,45),(47,51,54)],
               [64,67,71,70, 65,69,72,69, 66,69,74,73, 71,75,78,75], 'brass', 'boss')
    make_music('win', 108, [(55,59,62),(60,64,67),(52,55,59),(50,54,57)],
               [79,83,86,91, 88,86,84,83, 83,79,76,79, 81,86,83,79], 'flute', 'victory')
    make_music('lose', 64, [(52,55,59),(48,52,55),(45,48,52),(47,51,54)],
               [79,0,76,0, 76,72,0,71, 72,0,69,0, 71,66,0,0], 'bell', 'result')
    make_effects()
    print('独自 BGM 5 曲、効果音 9 点を生成しました（22050 Hz / stereo PCM）。')


if __name__ == '__main__':
    main()
