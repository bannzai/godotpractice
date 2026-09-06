"""宵森の灯守の独自楽曲・効果音を Python 標準ライブラリだけで再生成する。

作者: bannzai / Codex。外部の旋律・録音・音源サンプルは使用しない。
生成仕様: 青緑の夜森と金の灯に合わせた撥弦・木琴・パッド・ベース・打楽器。
生成物の利用条件と一覧は assets/CREDITS.md を正とする。
"""

from array import array
from functools import lru_cache
import math
from pathlib import Path
import random
import sys
import wave


ROOT = Path(__file__).resolve().parents[2] / "assets" / "audio"
RATE = 22050


@lru_cache(maxsize=256)
def instrument(kind: str, note: int, seconds: float) -> array:
    """同じ楽器・音高・長さから同じ波形を返す。"""
    frequency = 440.0 * 2 ** ((note - 69) / 12)
    count = round(seconds * RATE)
    output = array("d", [0.0]) * count
    rng = random.Random(20260906 + note * 37 + len(kind) * 11)
    delay = max(2, round(RATE / frequency))
    string = [rng.uniform(-1.0, 1.0) for _ in range(delay)]
    previous_noise = 0.0
    filtered = 0.0
    for i in range(count):
        t = i / RATE
        phase = math.tau * frequency * t
        release = min(1.0, (count - i - 1) / (RATE * 0.08))
        attack = min(1.0, t / 0.004)
        if kind == "pluck":
            # Karplus–Strong の遅延線で、弦の倍音が時間とともに減衰する。
            cursor = i % delay
            value = string[cursor]
            string[cursor] = 0.498 * (value + string[(cursor + 1) % delay])
            value *= 2.0 * math.exp(-t * 0.6)
        elif kind == "mallet":
            value = (math.sin(phase) * math.exp(-t * 3.6)
                     + 0.42 * math.sin(phase * 2.76) * math.exp(-t * 11)
                     + 0.16 * math.sin(phase * 5.4) * math.exp(-t * 19))
        elif kind == "bell":
            value = (math.sin(phase) + 0.33 * math.sin(phase * 2.005)
                     + 0.17 * math.sin(phase * 3.98)) * math.exp(-t * 2.0)
        elif kind == "pad":
            value = (math.sin(phase) + 0.22 * math.sin(phase * 2)
                     + 0.14 * math.sin(phase * 3.003)
                     + 0.19 * math.sin(phase * 0.997))
            attack = min(1.0, t / 0.35)
            release = min(1.0, (seconds - t) / 0.65)
            value *= 0.65 + 0.06 * math.sin(math.tau * 0.8 * t)
        elif kind == "bass":
            value = (math.sin(phase) + 0.3 * math.sin(phase * 2)
                     + 0.12 * math.sin(phase * 3)) * math.exp(-t * 2.2)
        elif kind == "kick":
            value = math.sin(math.tau * (47 * t + 8 * (1 - math.exp(-t * 27))))
            value *= math.exp(-t * 12)
        elif kind == "snare":
            noise = rng.uniform(-1.0, 1.0)
            filtered += 0.32 * (noise - filtered)
            value = (filtered * 1.8 + math.sin(math.tau * 170 * t) * 0.25)
            value *= math.exp(-t * 22)
        else:
            noise = rng.uniform(-1.0, 1.0)
            value = (noise - previous_noise) * math.exp(-t * 45) * 0.5
            previous_noise = noise
        output[i] = value * attack * max(0.0, release)
    return output


def mix(channels: list[array], samples: array, when: float, gain: float,
        pan: float = 0.0, loop: bool = True) -> None:
    """合成先への加算は作曲上の音の重なりを表すため非冪等。"""
    start = round(when * RATE)
    count = len(channels[0])
    left = math.sqrt((1 - pan) / 2) * gain
    right = math.sqrt((1 + pan) / 2) * gain
    for i, value in enumerate(samples):
        index = start + i
        if index >= count and not loop:
            break
        index %= count
        channels[0][index] += value * left
        channels[1][index] += value * right


def write_wave(name: str, channels: list[array], peak_target: float) -> None:
    """正規化後に PCM16 を保存し、無音・クリッピング・非有限値を検査する。"""
    peak = max(abs(value) for channel in channels for value in channel)
    if not math.isfinite(peak) or peak < 0.001:
        raise ValueError(f"音声が無効: {name} peak={peak}")
    gain = peak_target / peak
    pcm = array("h", (round(channels[c][i] * gain * 32767)
                       for i in range(len(channels[0])) for c in range(2)))
    if sys.byteorder != "little":
        pcm.byteswap()
    with wave.open(str(ROOT / f"{name}.wav"), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    with wave.open(str(ROOT / f"{name}.wav"), "rb") as source:
        decoded = array("h", source.readframes(source.getnframes()))
        if sys.byteorder != "little":
            decoded.byteswap()
        clipped = sum(abs(value) >= 32767 for value in decoded)
        rms = math.sqrt(sum((value / 32768) ** 2 for value in decoded) / len(decoded))
        boundary = max(abs(decoded[c] - decoded[-2 + c]) / 32768 for c in range(2))
        if clipped or not (0.005 < rms < 0.5):
            raise ValueError(f"音量検査失敗: {name} clip={clipped}, rms={rms}")
        if name.startswith("bgm-") and boundary > 0.04:
            raise ValueError(f"ループ境界が不連続: {name} {boundary}")
        print(f"{name}.wav: {source.getnframes() / RATE:.2f} 秒、"
              f"peak={peak_target:.2f}、RMS={rms:.3f}、飽和={clipped}、境界差={boundary:.4f}")


def make_track(scene: str, bpm: int, chords: list[tuple[int, ...]],
               melody: list[tuple[int, ...]]) -> None:
    """旋律と伴奏を固定譜面から合成し、残響をループの先頭へつなぐ。"""
    beat = 60 / bpm
    channels = [array("d", [0.0]) * round(beat * 32 * RATE) for _ in range(2)]
    for bar in range(8):
        chord = chords[bar % len(chords)]
        start = bar * 4 * beat
        for j, note in enumerate(chord):
            mix(channels, instrument("pad", note + 12, beat * 4 + 0.6),
                start, 0.052 if scene != "boss" else 0.03, (j - 1.5) * 0.3)
        for step in range(8):
            time = start + step * beat / 2
            note = chord[(step + bar % 2) % 4] + 12
            kind = {"play": "mallet", "result": "bell"}.get(scene, "pluck")
            mix(channels, instrument(kind, note, 1.2), time,
                0.11 if scene != "boss" else 0.16, -0.45 if step % 2 else 0.45)
            if scene in ("play", "boss"):
                mix(channels, instrument("shaker", 60, 0.09), time,
                    0.025 if scene == "play" else 0.05, 0.35)
        notes = melody[bar % len(melody)]
        for j, note in enumerate(notes):
            time = start + j * beat
            kind = "bell" if scene == "title" else "mallet"
            voice = instrument(kind, note, 1.5)
            mix(channels, voice, time, 0.16, -0.12)
            mix(channels, voice, time + beat * 0.75, 0.035, 0.55)
        for step in (0, 2):
            mix(channels, instrument("bass", chord[0] - 12, beat * 1.8),
                start + step * beat, 0.15 if scene != "boss" else 0.24)
        if scene in ("play", "boss"):
            for step in (0, 2, 2.75) if scene == "boss" else (0, 2):
                mix(channels, instrument("kick", 36, 0.3), start + step * beat, 0.19)
            for step in (1, 3):
                mix(channels, instrument("snare", 48, 0.2), start + step * beat,
                    0.085 if scene == "play" else 0.15, -0.08)
    # オフライン残響は元の信号だけを参照し、再生成時に同じ残響になる。
    dry = [array("d", channel) for channel in channels]
    for delay, gain in ((0.113, 0.12), (0.229, 0.08), (0.347, 0.045)):
        offset = round(delay * RATE)
        for c in range(2):
            for i in range(len(channels[c])):
                channels[c][(i + offset) % len(channels[c])] += dry[1 - c][i] * gain
    write_wave(f"bgm-{scene}", channels, 0.70)


def make_audio() -> None:
    """固定音列と固定 seed から全楽曲・効果音を再生成する。"""
    ROOT.mkdir(parents=True, exist_ok=True)
    make_track("title", 80,
               [(45, 52, 57, 60), (41, 48, 53, 57), (48, 55, 60, 64), (43, 50, 55, 59)],
               [(76, 72, 69, 71), (72, 69, 65), (79, 76, 72, 74), (74, 71, 67)])
    make_track("play", 112,
               [(45, 52, 57, 60), (48, 55, 60, 64), (41, 48, 53, 57), (43, 50, 55, 59)],
               [(69, 72, 76, 74), (72, 76, 79, 76), (77, 76, 72, 69), (74, 71, 67, 71)])
    make_track("boss", 144,
               [(38, 45, 50, 53), (34, 41, 46, 50), (41, 48, 53, 56), (45, 52, 57, 61)],
               [(74, 69, 74, 77), (70, 65, 70, 74), (77, 72, 77, 80), (73, 69, 76, 73)])
    make_track("result", 96,
               [(48, 55, 60, 64), (43, 50, 55, 59), (45, 52, 57, 60), (41, 48, 53, 57)],
               [(72, 76, 79), (74, 71, 67), (76, 72, 69), (77, 76, 72)])
    for cue, notes, kind, step, length in [
        ("attack", (83, 76), "pluck", 0.025, 0.16),
        ("hurt", (42, 37), "snare", 0.04, 0.24),
        ("level", (72, 76, 79, 84), "bell", 0.10, 0.85),
        ("pickup", (88, 93), "mallet", 0.025, 0.18),
        ("heal", (72, 76, 79), "bell", 0.085, 0.62),
        ("boss", (38, 45, 50, 53), "bass", 0.13, 1.0),
        ("result", (72, 76, 79, 84), "bell", 0.15, 1.2),
        ("magnet", (72, 74, 76, 79, 84), "mallet", 0.045, 0.45),
        ("ui", (81, 88), "mallet", 0.025, 0.16),
    ]:
        channels = [array("d", [0.0]) * round(RATE * length) for _ in range(2)]
        for j, note in enumerate(notes):
            mix(channels, instrument(kind, note, length - j * step), j * step,
                0.30, (j / max(1, len(notes) - 1) - 0.5) * 0.5, False)
        write_wave(cue, channels, 0.48 if cue in ("pickup", "attack", "ui") else 0.64)


if __name__ == "__main__":
    make_audio()
