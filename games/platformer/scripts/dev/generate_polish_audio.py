"""第 2 ラウンドのオリジナル曲と効果音を Python 標準ライブラリで再現する。"""

from array import array
from functools import lru_cache
from pathlib import Path
import argparse
import math
import random
import sys
import wave


ASSETS = Path(__file__).resolve().parents[2] / "assets" / "audio"
RATE = 32000
TAU = math.tau
LOOPS = ("title", "stage1", "stage2", "result", "game_over")
EFFECTS = ("jump", "stomp", "coin", "power", "death", "clear", "hurt", "ui")


def frequency(note: float) -> float:
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


@lru_cache(maxsize=512)
def instrument(name: str, note: int, duration: float) -> array:
    """倍音と減衰の異なる楽器。キャッシュした波形は呼び出し側で変更しない。"""
    count = round(duration * RATE)
    result = array("d", [0.0]) * count
    pitch = frequency(note)
    noise = random.Random(f"{name}/{note}/{duration}")
    previous_noise = 0.0
    for index in range(count):
        time = index / RATE
        phase = TAU * pitch * time
        attack = min(1.0, time / (0.12 if name == "pad" else 0.006))
        release = min(1.0, (count - 1 - index) / (RATE * 0.06))
        if name == "pluck":
            value = sum(
                gain * math.sin(phase * harmonic) * math.exp(-time * decay)
                for harmonic, gain, decay in ((1, 0.72, 4), (2, 0.24, 9),
                                              (3, 0.15, 14), (4, 0.06, 20))
            )
        elif name == "bell":
            value = sum(
                gain * math.sin(phase * ratio) * math.exp(-time * decay)
                for ratio, gain, decay in ((1, 0.68, 3), (2, 0.2, 5),
                                           (2.76, 0.09, 9), (4.05, 0.05, 13))
            )
        elif name == "lead":
            phase += 0.026 * math.sin(TAU * 5.1 * time)
            value = (0.70 * math.sin(phase) - 0.11 * math.sin(3 * phase)
                     + 0.035 * math.sin(5 * phase)) * math.exp(-time * 0.65)
        elif name == "pad":
            value = (0.55 * math.sin(phase) + 0.21 * math.sin(2 * phase)
                     + 0.08 * math.sin(3 * phase))
            release = min(1.0, (count - 1 - index) / (RATE * 0.22))
        elif name == "bass":
            value = (0.72 * math.sin(phase) + 0.22 * math.sin(2 * phase)
                     + 0.09 * math.sin(3 * phase)) * math.exp(-time * 3.2)
        elif name == "kick":
            phase = TAU * (48 * time + 125 * 0.025 * (1 - math.exp(-time / 0.025)))
            value = math.sin(phase) * math.exp(-time * 22)
        elif name == "snare":
            value = (0.65 * noise.uniform(-1, 1) + 0.20 * math.sin(TAU * 185 * time))
            value *= math.exp(-time * 32)
        elif name == "hat":
            current_noise = noise.uniform(-1, 1)
            value = (current_noise - previous_noise) * 0.33 * math.exp(-time * 72)
            previous_noise = current_noise
        else:
            raise ValueError(f"未対応の音色: {name}")
        result[index] = value * attack * release
    return result


class Mix:
    """曲単位で作り直すステレオバッファ。音符の余韻はループ先頭へ折り返す。"""

    def __init__(self, duration: float, loop: bool = False) -> None:
        self.count = round(duration * RATE)
        self.loop = loop
        self.left = array("d", [0.0]) * self.count
        self.right = array("d", [0.0]) * self.count

    def add(self, samples: array, start: float, gain: float, pan: float = 0.0) -> None:
        """音の重ね合わせなので非冪等。生成時は毎回新しい Mix にだけ加算する。"""
        begin = round(start * RATE)
        left_gain = math.sqrt((1.0 - pan) / 2.0) * gain
        right_gain = math.sqrt((1.0 + pan) / 2.0) * gain
        for offset, sample in enumerate(samples):
            index = begin + offset
            if self.loop:
                index %= self.count
            elif index >= self.count:
                break
            self.left[index] += sample * left_gain
            self.right[index] += sample * right_gain

    def note(self, name: str, note: int, start: float, duration: float,
             gain: float, pan: float = 0.0) -> None:
        """重ね合わせなので非冪等。音符の合成自体は決定的に行う。"""
        self.add(instrument(name, note, duration), start, gain, pan)

    def write(self, name: str) -> None:
        """バッファを変更せず、短い残響と音量調整を施した同じ WAV を書き出す。"""
        channels = (array("d", self.left), array("d", self.right))
        if self.loop:
            for index in range(self.count):
                # 循環ディレイなので、末尾の残響も先頭に連続してつながる。
                channels[0][index] += self.right[(index - 2656) % self.count] * 0.12
                channels[1][index] += self.left[(index - 5344) % self.count] * 0.10
        # SE は両端の 5 ms フェード込みで DC を除き、端点の無音も保持する。
        fades = array("d", (1.0 if self.loop else min(1.0, index / 160,
                              (self.count - 1 - index) / 160)
                            for index in range(self.count)))
        for channel in channels:
            dc = sum(value * fade for value, fade in zip(channel, fades)) / sum(fades)
            for index in range(self.count):
                channel[index] = (channel[index] - dc) * fades[index]
        peak = max(max(map(abs, channel)) for channel in channels)
        gain = (0.62 if self.loop else 0.70) / max(peak, 0.0001)
        pcm = array("h")
        for index in range(self.count):
            pcm.extend(round(channel[index] * gain * 32767) for channel in channels)
        if sys.byteorder != "little":
            pcm.byteswap()
        ASSETS.mkdir(parents=True, exist_ok=True)
        with wave.open(str(ASSETS / f"{name}.wav"), "wb") as output:
            output.setnchannels(2)
            output.setsampwidth(2)
            output.setframerate(RATE)
            output.writeframes(pcm.tobytes())


def arrange(name: str, bpm: int, chords: list[tuple[int, int, int]],
            melody: list[list[int]], voice: str) -> None:
    """8 分音符の旋律、和音、ベース、場面固有の伴奏を 8 小節に編曲する。"""
    beat = 60 / bpm
    mix = Mix(len(melody) * 4 * beat, loop=True)
    for bar, phrase in enumerate(melody):
        chord = chords[bar % len(chords)]
        start = bar * 4 * beat
        for step, note in enumerate(phrase):
            if note:
                mix.note(voice, note, start + step * beat / 2,
                         beat * (1.8 if voice == "bell" else 0.75), 0.29, -0.1)
        for index, note in enumerate(chord):
            mix.note("pad", note, start, 4 * beat, 0.07, (index - 1) * 0.45)
        for pulse in range(4):
            bass_note = chord[0] - 12 + (7 if pulse == 2 else 0)
            mix.note("bass", bass_note, start + pulse * beat, beat * 0.9, 0.24)
        if name == "game_over":
            mix.note("bell", chord[1] + 12, start + 2.5 * beat, beat * 1.7, 0.09, 0.5)
            continue
        for step in range(8):
            arpeggio = chord[step % 3] + (12 if name == "stage2" else 0)
            mix.note("pluck", arpeggio, start + (step / 2 + 0.25) * beat,
                     beat * 0.9, 0.12 if name == "stage1" else 0.09, 0.4)
            mix.note("hat", 0, start + step * beat / 2, 0.065,
                     0.065 if step % 2 else 0.045, 0.25)
        for pulse in (0, 2):
            mix.note("kick", 0, start + pulse * beat, 0.24,
                     0.30 if name in ("stage1", "result") else 0.15)
        for pulse in (1, 3):
            mix.note("snare", 0, start + pulse * beat, 0.16,
                     0.13 if name in ("stage1", "result") else 0.055, -0.25)
        if name == "stage2":
            # 地下はベルの応答を反対側へ置き、草原と空間の印象を変える。
            note = next(note for note in phrase if note)
            mix.note("bell", note + 12, start + 2.75 * beat, beat * 1.7, 0.07, 0.65)
        if bar >= 4 and name in ("stage1", "result"):
            # 後半は高音の応答が加わり、単一パターンの反復から展開する。
            mix.note("bell", phrase[0] + 12, start + 3 * beat, beat, 0.095, 0.5)
    mix.write(name)


def music() -> None:
    arrange("title", 92, [(48, 52, 55), (53, 57, 60), (45, 48, 52), (43, 47, 50)], [
        [72, 0, 76, 79, 0, 76, 74, 0], [72, 0, 69, 72, 0, 77, 76, 0],
        [76, 0, 72, 69, 0, 72, 76, 0], [74, 0, 71, 67, 0, 71, 74, 0],
        [79, 0, 76, 72, 0, 76, 79, 81], [77, 0, 76, 72, 0, 69, 72, 0],
        [76, 0, 79, 76, 0, 72, 69, 0], [71, 0, 74, 79, 0, 74, 71, 0],
    ], "bell")
    arrange("stage1", 118, [(50, 54, 57), (55, 59, 62), (47, 50, 54), (45, 49, 52)], [
        [74, 78, 81, 0, 78, 74, 76, 78], [79, 0, 78, 74, 71, 74, 79, 0],
        [78, 74, 71, 0, 74, 78, 81, 78], [76, 0, 73, 69, 73, 76, 81, 0],
        [81, 78, 74, 78, 81, 0, 83, 81], [79, 78, 74, 0, 71, 74, 79, 81],
        [83, 81, 78, 74, 78, 0, 74, 71], [73, 76, 81, 0, 76, 73, 69, 0],
    ], "lead")
    arrange("stage2", 102, [(45, 48, 52), (41, 45, 48), (38, 41, 45), (40, 44, 47)], [
        [69, 0, 76, 72, 0, 71, 0, 72], [69, 0, 72, 77, 0, 76, 0, 72],
        [69, 0, 74, 77, 0, 76, 0, 74], [68, 0, 71, 76, 0, 71, 0, 68],
        [76, 0, 81, 79, 0, 76, 0, 72], [77, 0, 81, 77, 0, 76, 0, 72],
        [74, 0, 77, 81, 0, 77, 0, 74], [71, 0, 68, 71, 0, 76, 0, 68],
    ], "bell")
    arrange("result", 108, [(48, 52, 55), (53, 57, 60), (43, 47, 50), (48, 52, 55)], [
        [72, 0, 76, 79, 84, 0, 79, 0], [81, 0, 77, 72, 77, 0, 81, 0],
        [79, 0, 74, 71, 74, 79, 83, 0], [84, 0, 79, 76, 72, 0, 0, 0],
        [76, 79, 84, 0, 79, 76, 72, 0], [77, 81, 84, 0, 81, 77, 72, 0],
        [79, 83, 86, 0, 83, 79, 74, 0], [84, 0, 79, 76, 72, 0, 0, 0],
    ], "lead")
    arrange("game_over", 74, [(45, 48, 52), (41, 45, 48), (38, 41, 45), (40, 43, 47)], [
        [76, 0, 72, 0, 69, 0, 0, 0], [72, 0, 69, 0, 65, 0, 0, 0],
        [69, 0, 65, 0, 62, 0, 0, 0], [67, 0, 71, 0, 64, 0, 0, 0],
    ], "bell")


def sweep(start_pitch: float, end_pitch: float, duration: float,
          noise_gain: float = 0.0) -> array:
    """位相を連続させた上昇・下降音。固定シードの雑音で同じ音を再現する。"""
    count = round(duration * RATE)
    samples = array("d")
    phase = 0.0
    noise = random.Random(7381)
    for index in range(count):
        progress = index / max(count - 1, 1)
        phase += TAU * frequency(start_pitch + (end_pitch - start_pitch) * progress) / RATE
        envelope = math.sin(math.pi * progress) ** 0.8
        samples.append((0.75 * math.sin(phase) + 0.14 * math.sin(2 * phase)
                        + noise_gain * noise.uniform(-1, 1)) * envelope)
    return samples


def effects() -> None:
    jump = Mix(0.27)
    jump.add(sweep(57, 83, 0.22), 0, 0.7)
    jump.note("pluck", 81, 0.09, 0.17, 0.15, 0.2)
    jump.write("jump")
    stomp = Mix(0.25)
    stomp.note("kick", 0, 0, 0.24, 0.7)
    stomp.note("pluck", 43, 0, 0.20, 0.45)
    stomp.note("snare", 0, 0, 0.09, 0.22)
    stomp.write("stomp")
    coin = Mix(0.46)
    coin.note("bell", 88, 0, 0.33, 0.48, -0.25)
    coin.note("bell", 95, 0.07, 0.38, 0.5, 0.25)
    coin.write("coin")
    power = Mix(0.94)
    for index, note in enumerate((60, 64, 67, 72, 76, 79, 84)):
        power.note("bell", note, index * 0.07, 0.48, 0.32, (index - 3) / 6)
    power.add(sweep(48, 84, 0.64), 0, 0.18)
    power.write("power")
    hurt = Mix(0.36)
    hurt.add(sweep(67, 42, 0.24, 0.20), 0, 0.60)
    hurt.note("snare", 0, 0, 0.14, 0.4)
    hurt.note("pluck", 49, 0.08, 0.24, 0.24)
    hurt.write("hurt")
    death = Mix(1.10)
    for index, note in enumerate((72, 68, 65, 60, 53)):
        death.note("pluck", note, index * 0.13, 0.4, 0.5)
    death.add(sweep(57, 33, 0.75), 0.15, 0.22)
    death.write("death")
    clear = Mix(1.70)
    for index, note in enumerate((72, 76, 79, 84)):
        clear.note("lead", note, index * 0.13, 0.22, 0.35)
    for note, pan in ((72, -0.4), (76, 0.0), (79, 0.4), (84, 0.0)):
        clear.note("bell", note, 0.60, 1.06, 0.28, pan)
    clear.note("kick", 0, 0.60, 0.28, 0.35)
    clear.write("clear")
    ui = Mix(0.20)
    ui.note("pluck", 79, 0, 0.19, 0.4)
    ui.note("bell", 86, 0.025, 0.15, 0.18)
    ui.write("ui")


def verify() -> None:
    """既存 WAV のピーク、DC、ループ境界と SE の無音端を測定する。"""
    for name in LOOPS + EFFECTS:
        with wave.open(str(ASSETS / f"{name}.wav"), "rb") as source:
            if (source.getnchannels(), source.getsampwidth(), source.getframerate()) != (2, 2, RATE):
                raise ValueError(f"{name}: PCM 形式が不正")
            samples = array("h", source.readframes(source.getnframes()))
        if sys.byteorder != "little":
            samples.byteswap()
        peak = max(map(abs, samples)) / 32768
        rms = math.sqrt(sum(sample * sample for sample in samples) / len(samples)) / 32768
        dc = abs(sum(samples) / len(samples)) / 32768
        boundary = max(abs(samples[0] - samples[-2]), abs(samples[1] - samples[-1])) / 32768
        if peak > 0.701 or dc > 0.001:
            raise ValueError(f"{name}: 音量または DC オフセットが範囲外")
        if name in LOOPS and boundary > 0.025:
            raise ValueError(f"{name}: ループ境界に大きな段差 {boundary:.6f}")
        if name in EFFECTS and any(samples[index] != 0 for index in (0, 1, -2, -1)):
            raise ValueError(f"{name}: 効果音の両端が無音でない")
        print(f"{name}.wav: {len(samples) / (2 * RATE):.3f} 秒, "
              f"ピーク {peak:.4f}, RMS {rms:.4f}, DC {dc:.7f}, 境界差 {boundary:.5f}")
    print("音声検査 OK")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="生成せず既存 WAV のみを検査する")
    args = parser.parse_args()
    if not args.check:
        music()
        effects()
    verify()


if __name__ == "__main__":
    main()
