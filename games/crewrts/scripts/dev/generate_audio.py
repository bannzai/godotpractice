"""庭の五つの楽曲と操作音を数式合成する。外部の楽曲・録音は使用しない。"""

import array
import math
from pathlib import Path
import random
import sys
import wave


RATE = 22050
OUT = Path(__file__).resolve().parents[2] / "assets" / "audio"
TAU = 2.0 * math.pi


def pitch(midi: float) -> float:
    """MIDI 音高を周波数に変換する。"""
    return 440.0 * 2.0 ** ((midi - 69.0) / 12.0)


def voice(kind: str, note: float, duration: float) -> list[float]:
    """固定 seed と倍音・包絡から、毎回同一の独自音色を生成する。"""
    frequency = pitch(note)
    noise = random.Random(817 + round(note * 13))
    result = []
    previous_noise = 0.0
    for index in range(round(duration * RATE)):
        t = index / RATE
        phase = TAU * frequency * t
        release = min(1.0, (duration - t) / min(0.12, duration * 0.3))
        air = noise.uniform(-1.0, 1.0)
        if kind == "wood":
            value = (math.sin(phase) * math.exp(-4.3 * t)
                     + 0.35 * math.sin(phase * 3.98) * math.exp(-15 * t)
                     + 0.12 * math.sin(phase * 9.1) * math.exp(-30 * t))
            value *= min(1.0, t / 0.005)
        elif kind == "string":
            vibrato = 0.025 * math.sin(TAU * 4.1 * t)
            value = sum(math.sin(phase * h + vibrato * h) / h ** 1.8
                        for h in range(1, 7))
            value *= min(1.0, t / 0.22) * (0.76 + 0.08 * math.sin(TAU * 2 * t))
        elif kind == "pluck":
            value = sum(math.sin(phase * h) * math.exp(-(2.0 + h * 2.0) * t) / h
                        for h in range(1, 7))
            value *= min(1.0, t / 0.004)
        elif kind == "reed":
            value = (math.sin(phase + 0.04 * math.sin(TAU * 5.4 * t))
                     + 0.20 * math.sin(phase * 3) + 0.05 * air)
            value *= min(1.0, t / 0.04) * (0.85 + 0.1 * math.sin(TAU * 3.7 * t))
        elif kind == "bass":
            value = (math.sin(phase) + 0.32 * math.sin(phase * 2)
                     + 0.08 * math.sin(phase * 3))
            value *= min(1.0, t / 0.012) * math.exp(-2.4 * t)
        elif kind == "kick":
            value = math.sin(TAU * (48 * t + 2.5 * (1 - math.exp(-30 * t))))
            value *= math.exp(-17 * t) * min(1.0, t / 0.003)
        elif kind == "shaker":
            value = (air - previous_noise) * math.exp(-36 * t)
            value *= min(1.0, t / 0.003)
        else:
            value = (air * 0.6 + math.sin(phase) * 0.4) * math.exp(-22 * t)
            value *= min(1.0, t / 0.003)
        result.append(value * release)
        previous_noise = air
    return result


def write_wav(name: str, samples: list[float], stereo: bool = False) -> None:
    """同じ入力なら同じ PCM を出力する。ピークを抑えて重複 SE の余裕を残す。"""
    maximum = max(abs(value) for value in samples) or 1.0
    scale = 0.68 / maximum
    pcm = array.array("h", (round(value * scale * 32767) for value in samples))
    if sys.byteorder != "little":
        pcm.byteswap()
    with wave.open(str(OUT / name), "wb") as target:
        target.setnchannels(2 if stereo else 1)
        target.setsampwidth(2)
        target.setframerate(RATE)
        target.writeframes(pcm.tobytes())


def music(scene: str) -> list[float]:
    """場面別に旋律・和声・編成を変えた八小節の循環伴奏を合成する。"""
    scores = {
        "title": (82, ((48, 60, 64, 67), (45, 57, 60, 64),
                        (41, 57, 60, 65), (43, 55, 59, 62)),
                  ((76, 0, 79, 81, 79, 76, 74, 0), (72, 0, 76, 79, 76, 72, 71, 0),
                   (69, 0, 72, 76, 74, 72, 69, 0), (71, 74, 79, 0, 74, 71, 72, 0))),
        "garden": (108, ((48, 60, 64, 67), (53, 57, 60, 65),
                           (50, 57, 62, 65), (43, 59, 62, 67)),
                   ((79, 76, 0, 72, 76, 79, 81, 79), (77, 0, 76, 72, 69, 72, 77, 76),
                    (74, 77, 81, 0, 79, 77, 74, 72), (71, 74, 79, 76, 74, 71, 72, 0))),
        "battle": (138, ((45, 57, 60, 64), (41, 57, 60, 65),
                           (50, 57, 62, 65), (40, 56, 59, 64)),
                   ((69, 0, 72, 69, 76, 72, 69, 67), (69, 72, 77, 76, 72, 0, 69, 72),
                    (74, 69, 77, 74, 81, 77, 74, 72), (71, 68, 76, 71, 80, 76, 71, 68))),
        "clear": (94, ((48, 60, 64, 67), (53, 60, 65, 69),
                         (43, 59, 62, 67), (48, 60, 64, 67)),
                  ((72, 76, 79, 84, 0, 79, 84, 0), (81, 0, 77, 81, 84, 0, 89, 0),
                   (86, 83, 79, 74, 79, 83, 86, 0), (84, 0, 79, 76, 72, 0, 0, 0))),
        "failed": (72, ((45, 57, 60, 64), (41, 57, 60, 65),
                          (43, 55, 59, 62), (45, 57, 60, 64)),
                   ((76, 0, 0, 72, 71, 0, 69, 0), (72, 0, 0, 69, 65, 0, 64, 0),
                    (67, 0, 0, 71, 74, 0, 71, 0), (72, 0, 71, 0, 69, 0, 0, 0))),
    }
    tempo, chords, melody = scores[scene]
    beat = 60.0 / tempo
    frames = round(RATE * beat * 32)
    left, right = [0.0] * frames, [0.0] * frames

    def add(kind: str, note: int, at: float, length: float, gain: float, pan: float) -> None:
        """作曲イベントを合成バッファへ一度加算するので非冪等。"""
        start = round(at * beat * RATE)
        samples = voice(kind, note, length * beat)
        for i, value in enumerate(samples):
            frame = (start + i) % frames
            left[frame] += value * gain * math.sqrt(1 - pan)
            right[frame] += value * gain * math.sqrt(pan)

    for bar, chord in enumerate(chords + chords):
        # 長い弦は和声、短い撥弦は拍、木琴・リードは歌う旋律を担当する。
        for index, note in enumerate(chord[1:]):
            add("string", note, bar * 4, 4.4, 0.032, 0.2 + index * 0.3)
        for step in range(4):
            note = chord[0] if step % 2 == 0 else chord[0] + 7
            add("bass", note, bar * 4 + step, 0.9, 0.17, 0.5)
            if scene != "failed":
                add("pluck", chord[1 + step % 3], bar * 4 + step + 0.5,
                    0.8, 0.065, 0.25 if step % 2 == 0 else 0.75)
        for step, note in enumerate(melody[bar % 4]):
            if note:
                kind = "reed" if scene in ("title", "failed") else "wood"
                if bar >= 4:
                    kind = "wood" if kind == "reed" else "reed"
                    note -= 12 if scene == "battle" else 0
                add(kind, note, bar * 4 + step * 0.5, 0.85,
                    0.105 if kind == "reed" else 0.17, 0.55)
        if scene in ("garden", "battle", "clear"):
            for step in range(8):
                add("shaker", 60, bar * 4 + step * 0.5, 0.22, 0.055, 0.77)
            for step in (0, 2):
                add("kick", 36, bar * 4 + step, 0.6, 0.17, 0.5)
            for step in (1, 3):
                add("tap", 49, bar * 4 + step, 0.32, 0.09, 0.28)
        if scene == "battle":
            for step in range(8):
                add("pluck", chord[step % 3 + 1] + 12, bar * 4 + step * 0.5,
                    0.38, 0.095, 0.32)
        if scene == "clear":
            add("wood", chord[3] + 24, bar * 4, 2.5, 0.055, 0.8)
    # 残響を循環させることで、ループの境界でも余韻が途切れない。
    wet_left, wet_right = left.copy(), right.copy()
    for seconds, gain in ((0.093, 0.14), (0.181, 0.10), (0.307, 0.055)):
        offset = round(seconds * RATE)
        for i in range(frames):
            wet_left[(i + offset) % frames] += right[i] * gain
            wet_right[(i + offset) % frames] += left[i] * gain
    return [sample for pair in zip(wet_left, wet_right) for sample in pair]


def chime(notes: tuple[int, ...], interval: float, duration: float,
          instrument: str = "wood") -> list[float]:
    """短い旋律を持つ操作音を生成する。"""
    result = [0.0] * round(RATE * (interval * (len(notes) - 1) + duration))
    for index, note in enumerate(notes):
        start = round(index * interval * RATE)
        for i, value in enumerate(voice(instrument, note, duration)):
            if start + i < len(result):
                result[start + i] += value * 0.28
    return result


def gesture(kind: str) -> list[float]:
    """息を含む笛、風切り、打撃、柔らかな破裂音を別々の包絡で生成する。"""
    durations = {"whistle": 0.48, "throw": 0.27, "hit": 0.19, "defeat": 0.56}
    duration = durations[kind]
    noise = random.Random(302)
    result = []
    for i in range(round(RATE * duration)):
        t = i / RATE
        air = noise.uniform(-1.0, 1.0)
        envelope = math.sin(math.pi * t / duration) ** 2
        if kind == "whistle":
            local = t if t < 0.22 else t - 0.26
            if local < 0:
                result.append(0.0)
                continue
            frequency = 880 if t < 0.22 else 1174
            envelope = math.sin(math.pi * min(local / 0.22, 1.0)) ** 2
            phase = TAU * (frequency * local + 0.02 * math.sin(TAU * 7 * local))
            value = math.sin(phase) + 0.12 * math.sin(phase * 2) + 0.05 * air
        elif kind == "throw":
            phase = TAU * (760 * t - 960 * t * t)
            value = 0.65 * math.sin(phase) + air * 0.35
        elif kind == "hit":
            envelope = math.exp(-28 * t) * min(1.0, t / 0.002)
            value = 0.75 * air + 0.55 * math.sin(TAU * (130 * t - 70 * t * t))
        else:
            envelope = math.exp(-8 * t) * min(1.0, t / 0.003)
            value = 0.60 * air + math.sin(TAU * (120 * t - 55 * t * t))
        result.append(0.3 * envelope * value)
    return result


def main() -> None:
    """全音声を決定的に更新する。"""
    OUT.mkdir(parents=True, exist_ok=True)
    for scene in ("title", "garden", "battle", "clear", "failed"):
        write_wav(f"{scene}.wav", music(scene), stereo=True)
    for effect in ("whistle", "throw", "hit", "defeat"):
        write_wav(f"{effect}.wav", gesture(effect))
    write_wav("delivery.wav", chime((72, 76, 79, 84), 0.08, 0.7))
    write_wav("lost.wav", chime((76, 72, 69), 0.13, 0.48, "reed"))
    write_wav("switch.wav", chime((76, 81), 0.04, 0.2, "pluck"))
    print("音声 12 ファイルの生成完了")


if __name__ == "__main__":
    main()
