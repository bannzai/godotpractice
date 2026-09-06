"""玩具アトリエの場面別音楽と効果音を、外部音源なしで決定的に生成する。"""

import argparse
from array import array
from functools import lru_cache
import hashlib
import io
import math
from pathlib import Path
import random
import struct
import wave


RATE = 22050
OUTPUT = Path(__file__).resolve().parents[2] / "assets" / "audio"
MUSIC_NAMES = {"title", "play", "urgent", "finish", "timeout", "music"}


def frequency(note):
    """MIDI 音高を周波数へ変換する。"""
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


@lru_cache(maxsize=256)
def instrument(kind, note, duration):
    """固定シードの弦・打楽器と、減衰の異なる共鳴音を合成する。"""
    count = round(duration * RATE)
    hz = frequency(note)
    sound = array("f")
    seed = int.from_bytes(hashlib.sha256(f"{kind}:{note}".encode()).digest()[:8], "big")
    rng = random.Random(seed)
    # 弦を弾く初期変位を遅延線に入れ、毎周期の平均化で高域から減衰させる。
    delay = max(2, round(RATE / hz - 0.5))
    string = [rng.uniform(-1.0, 1.0) for _ in range(delay)]
    previous_noise = 0.0
    low_noise = 0.0
    for index in range(count):
        t = index / RATE
        phase = math.tau * hz * t
        attack = min(1.0, t / (0.006 if kind != "bass" else 0.015))
        release = min(1.0, (count - 1 - index) / (RATE * 0.035))
        if kind == "pluck":
            position = index % delay
            value = string[position]
            string[position] = 0.496 * (value + string[(position + 1) % delay])
            value = value * 0.85 + 0.12 * math.sin(phase) * math.exp(-3.5 * t)
        elif kind == "marimba":
            value = (
                math.sin(phase) * math.exp(-5.5 * t)
                + 0.42 * math.sin(phase * 3.99) * math.exp(-19.0 * t)
                + 0.13 * math.sin(phase * 9.97) * math.exp(-35.0 * t)
            )
        elif kind == "bell":
            value = (
                0.65 * math.sin(phase) * math.exp(-2.8 * t)
                + 0.28 * math.sin(phase * 2.76) * math.exp(-4.0 * t)
                + 0.16 * math.sin(phase * 5.4) * math.exp(-8.0 * t)
                + 0.07 * math.sin(phase * 8.93) * math.exp(-16.0 * t)
            )
        elif kind == "bass":
            value = math.exp(-2.6 * t) * (
                math.sin(phase) + 0.19 * math.sin(phase * 2) + 0.07 * math.sin(phase * 3)
            )
        elif kind in {"brush", "rim"}:
            noise = rng.uniform(-1.0, 1.0)
            low_noise = 0.72 * low_noise + 0.28 * noise
            if kind == "brush":
                value = (noise - low_noise) * math.exp(-27 * t) * 0.8
            else:
                value = (noise - previous_noise) * math.exp(-65 * t) * 0.25
                value += math.sin(phase * 2.3) * math.exp(-55 * t) * 0.7
            previous_noise = noise
        elif kind == "thud":
            value = math.sin(math.tau * (hz * t + 36 * (1 - math.exp(-25 * t)) / 25))
            value = value * math.exp(-24 * t) + rng.uniform(-0.12, 0.12) * math.exp(-80 * t)
        else:
            raise ValueError(f"未知の楽器: {kind}")
        sound.append(value * attack * release)
    return sound


def event(start, kind, note, duration, gain):
    """音の開始時刻と共有しても書き換えない楽器波形を返す。"""
    return start, instrument(kind, note, duration), gain


def mix(length, events, loop=False):
    """音の尾と短い残響をループ先頭にも折り返し、境界のクリックを抑える。"""
    result = array("f", [0.0]) * round(length * RATE)
    for start, sound, gain in events:
        offset = round(start * RATE)
        for index, value in enumerate(sound):
            target = offset + index
            if loop:
                target %= len(result)
            if 0 <= target < len(result):
                result[target] += value * gain
    dry = result[:]
    for seconds, gain in [(0.079, 0.12), (0.163, 0.065)]:
        offset = round(seconds * RATE)
        for index, value in enumerate(dry):
            target = index + offset
            if loop:
                target %= len(result)
            if target < len(result):
                result[target] += value * gain
    mean = sum(result) / len(result)
    edge = round(RATE * (0.003 if loop else 0.015))
    for index in range(len(result)):
        distance = min(index, len(result) - 1 - index)
        envelope = 0.5 - 0.5 * math.cos(math.pi * min(1.0, distance / edge))
        result[index] = (result[index] - mean) * envelope
    return result


def title():
    """木琴の3拍子と爪弾く弦で、アトリエへ誘う落ち着いた主題を作る。"""
    beat = 60 / 90
    chords = [(48, 64, 67, 71), (45, 60, 64, 69), (41, 60, 65, 69),
              (43, 62, 67, 71), (48, 64, 67, 72), (43, 62, 65, 71)]
    melody = [(76, 79, 74), (76, 72, 69), (72, 77, 76),
              (74, 71, 67), (76, 79, 84), (81, 79, 74)]
    events = []
    for bar, chord in enumerate(chords):
        start = bar * 3 * beat
        events.append(event(start, "bass", chord[0], 1.05, 0.2))
        for step in range(3):
            events.append(event(start + step * beat, "marimba", melody[bar][step], 0.9, 0.2))
            events.append(event(start + (step + 0.5) * beat, "pluck", chord[step + 1], 0.7, 0.2))
        if bar % 2 == 0:
            events.append(event(start + 2 * beat, "bell", chord[3] + 12, 1.15, 0.07))
    return mix(18 * beat, events, loop=True)


def play(urgent=False):
    """通常は弦とブラシ、時間切れ前は木琴の速い刻みとリムで推進感を出す。"""
    beat = 60 / (150 if urgent else 128)
    chords = [(50, 66, 69, 73), (47, 62, 66, 69), (43, 62, 67, 71), (45, 61, 64, 69)]
    melody = [(78, 81, 78, 76), (74, 78, 81, 85), (83, 81, 78, 74), (76, 73, 76, 81),
              (78, 81, 85, 81), (78, 74, 73, 74), (79, 78, 74, 71), (73, 76, 81, 73)]
    events = []
    for bar in range(8):
        chord = chords[bar % 4]
        start = bar * 4 * beat
        for step in range(4):
            bass = chord[0] + (7 if step % 2 else 0)
            events.append(event(start + step * beat, "bass", bass, 0.42, 0.25))
            events.append(event(start + step * beat, "thud", 35, 0.15, 0.15 if urgent else 0.1))
            events.append(event(start + (step + 0.5) * beat, "brush", 75, 0.11, 0.17))
            if step % 2:
                events.append(event(start + step * beat, "rim", 72, 0.12, 0.1 if urgent else 0.065))
            events.append(event(start + (step + 0.5) * beat, "pluck", chord[step % 3 + 1], 0.55, 0.23))
            events.append(event(start + step * beat, "marimba" if urgent else "pluck",
                                melody[bar][step], 0.55, 0.2 if urgent else 0.34))
            if urgent:
                events.append(event(start + (step + 0.5) * beat, "marimba",
                                    chord[step % 3 + 1] + 12, 0.26, 0.09))
        if not urgent and bar % 2 == 0:
            events.append(event(start + 3.5 * beat, "bell", melody[bar][3] + 12, 0.9, 0.075))
    return mix(32 * beat, events, loop=True)


def result_music(success):
    """成功は長調のベル、時間切れは短調の静かな弦で余韻を作る。"""
    beat = 60 / (110 if success else 82)
    chords = ([(41, 65, 69, 72), (48, 64, 67, 72), (38, 62, 65, 69), (43, 62, 67, 71)]
              if success else [(45, 60, 64, 69), (41, 60, 65, 69), (48, 60, 64, 67), (40, 59, 64, 67)])
    melody = [(81, 84), (79, 76), (77, 81), (79, 74)] if success else [(76, 72), (69, 72), (74, 71), (67, 71)]
    events = []
    for bar, chord in enumerate(chords):
        start = bar * 4 * beat
        events.append(event(start, "bass", chord[0], 1.45, 0.2))
        for step in range(8):
            events.append(event(start + step * beat / 2, "pluck", chord[1 + step % 3], 0.8, 0.19))
        for step in range(2):
            events.append(event(start + step * 2 * beat, "bell" if success else "marimba",
                                melody[bar][step], 1.35, 0.19 if success else 0.13))
        if success:
            for step in (1, 3):
                events.append(event(start + step * beat, "brush", 75, 0.15, 0.11))
    return mix(16 * beat, events, loop=True)


def sound_effects():
    """回収・衝突・成長・成功・時間切れを異なる音域と発音で区別する。"""
    sounds = {
        "pickup": mix(0.48, [event(0, "marimba", 88, 0.26, 0.42),
                              event(0.055, "bell", 95, 0.4, 0.28)]),
        "bump": mix(0.28, [event(0, "thud", 42, 0.22, 0.75),
                            event(0.01, "rim", 55, 0.17, 0.25)]),
    }
    success = [event(step * 0.12, "bell", note, 0.92, 0.28)
               for step, note in enumerate((72, 76, 79, 84))]
    success += [event(0.36, "pluck", note, 0.9, 0.25) for note in (60, 64, 67)]
    sounds["win"] = mix(1.5, success)
    sounds["lose"] = mix(1.18, [event(step * 0.18, "pluck", note, 0.7, 0.55)
                               for step, note in enumerate((67, 64, 59, 52))])
    sounds["growth"] = mix(1.12, [event(step * 0.07, "bell", note, 0.67, 0.21)
                                 for step, note in enumerate((72, 76, 79, 84, 88, 91))]
                            + [event(0.1, "bass", 48, 0.75, 0.28)])
    return sounds


def encode(sound):
    """ピークと実効値の両方に余裕を残し、固定形式の WAV をメモリ上に作る。"""
    peak = max(abs(value) for value in sound)
    rms = math.sqrt(sum(value * value for value in sound) / len(sound))
    if not peak or not rms:
        raise ValueError("生成波形が無音です")
    gain = min(0.78 / peak, 0.14 / rms)
    pcm = [round(value * gain * 32767) for value in sound]
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as output:
        output.setparams((1, 2, RATE, len(pcm), "NONE", "not compressed"))
        output.writeframes(struct.pack(f"<{len(pcm)}h", *pcm))
    return buffer.getvalue(), pcm


def main():
    """固定条件で上書き再生成し、検証モードでは既存ファイルとの一致を検査する。"""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true", help="再生成と保存済み WAV の全バイトを照合する")
    args = parser.parse_args()
    sounds = {"title": title(), "play": play(), "urgent": play(urgent=True),
              "finish": result_music(True), "timeout": result_music(False)}
    # 初回実装の参照を壊さず、旧名も通常プレイの新しい編曲で再生成する。
    sounds["music"] = sounds["play"]
    sounds.update(sound_effects())
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, sound in sounds.items():
        data, pcm = encode(sound)
        peak = max(map(abs, pcm)) / 32767
        rms = math.sqrt(sum(value * value for value in pcm) / len(pcm)) / 32767
        assert 0.02 < rms < 0.2 and peak < 0.8, f"音量の範囲外: {name}"
        assert pcm[0] == pcm[-1] == 0, f"端点が無音ではありません: {name}"
        if name in MUSIC_NAMES:
            assert 8 <= len(pcm) / RATE <= 20, f"ループ時間の範囲外: {name}"
        path = OUTPUT / f"{name}.wav"
        if args.verify:
            assert path.read_bytes() == data, f"再生成結果が一致しません: {name}"
        else:
            path.write_bytes(data)
        digest = hashlib.sha256(data).hexdigest()[:12]
        print(f"{name}.wav: {len(pcm) / RATE:.2f} 秒, 最大振幅 {peak:.3f}, RMS {rms:.3f}, "
              f"端点 {pcm[0]}/{pcm[-1]}, SHA256 {digest}" + (" 一致" if args.verify else ""))


if __name__ == "__main__":
    main()
