"""灯守の島のチップチューン楽曲・効果音・環境音を決定的に再生成する。"""

from array import array
from math import exp, pi, sin
from pathlib import Path
import random
import sys
import wave


ROOT = Path(__file__).resolve().parents[2] / "assets"
SAMPLE_RATE = 22050


def add_note(buffer, start, duration, midi, volume, voice="square", pan=0.0):
    """譜面上の一音を循環バッファへ加算するため非冪等。"""
    frequency = 440 * 2 ** ((midi - 69) / 12)
    frame_count = len(buffer) // 2
    length = int(SAMPLE_RATE * duration)
    base = int(start * SAMPLE_RATE)
    left, right = (1 - pan) * 0.5, (1 + pan) * 0.5
    for index in range(length):
        time = index / SAMPLE_RATE
        attack = min(time / 0.01, 1.0)
        release = min((duration - time) / 0.05, 1.0)
        phase = 2 * pi * frequency * time
        if voice == "triangle":
            sound = 2.0 / pi * (sin(phase) - sin(phase * 3) / 9 + sin(phase * 5) / 25)
            envelope = attack * release
        elif voice == "pluck":
            sound = sin(phase) + 0.38 * sin(phase * 2) + 0.16 * sin(phase * 4)
            envelope = attack * exp(-time * 5 / duration) * release
        elif voice == "bass":
            sound = sin(phase) + 0.2 * sin(phase * 2)
            envelope = attack * release * exp(-time * 1.4)
        elif voice == "bell":
            sound = sin(phase) * exp(-time * 2) + 0.42 * sin(phase * 2.76) * exp(-time * 5)
            envelope = attack * release
        else:
            sound = 1.0 if sin(phase) >= 0 else -1.0
            sound += 0.18 * sin(phase * 0.5)
            envelope = attack * release
        value = sound * envelope * volume
        target = ((base + index) % frame_count) * 2
        buffer[target] += value * left
        buffer[target + 1] += value * right


def add_drum(buffer, start, volume, seed, sharp=False):
    """打音を重ねる譜面イベントなので非冪等。"""
    generator = random.Random(seed)
    frame_count = len(buffer) // 2
    for index in range(int(SAMPLE_RATE * 0.18)):
        time = index / SAMPLE_RATE
        noise = generator.uniform(-1, 1) * (0.8 if sharp else 0.15)
        tone = sin(2 * pi * (80 * time - 90 * time * time))
        sound = (noise + tone) * exp(-time * (36 if sharp else 22)) * volume
        target = ((int(start * SAMPLE_RATE) + index) % frame_count) * 2
        buffer[target] += sound * 0.5
        buffer[target + 1] += sound * 0.5


def write_wav(name, buffer, peak_target=0.72):
    peak = max(abs(value) for value in buffer) or 1.0
    gain = peak_target / peak
    pcm = array("h", (int(max(-1, min(1, value * gain)) * 32767) for value in buffer))
    if sys.byteorder != "little":
        pcm.byteswap()
    destination = ROOT / "audio" / f"{name}.wav"
    destination.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(destination), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm.tobytes())


def music_and_cues():
    configs = {
        "title": (84, [50, 46, 53, 48], [74, 77, 81, 79, 77, 74, 72, 69], "bell"),
        "field": (112, [50, 53, 48, 46], [74, 77, 79, 81, 79, 77, 72, 74], "triangle"),
        "dungeon": (72, [38, 41, 36, 37], [62, 65, 69, 68, 65, 62, 61, 57], "square"),
        "boss": (138, [38, 37, 41, 36], [62, 65, 68, 69, 68, 65, 61, 60], "pluck"),
        "result": (96, [53, 48, 50, 46], [77, 81, 84, 86, 84, 81, 79, 77], "triangle"),
    }
    for name, (bpm, roots, melody, voice) in configs.items():
        beat = 60 / bpm
        buffer = array("f", [0]) * (int(SAMPLE_RATE * beat * 32) * 2)
        for bar in range(8):
            root = roots[bar % 4]
            at = bar * 4 * beat
            for interval in (0, 7, 15):
                add_note(buffer, at, beat * 4, root + 12 + interval, 0.09, "triangle", (interval - 7) / 13)
            for step in range(4):
                add_note(buffer, at + step * beat, beat * 0.78, root, 0.17, "bass")
                if name != "title":
                    add_drum(buffer, at + step * beat, 0.09, bar * 20 + step, step % 2 == 1)
            for step in range(8):
                pitch = root + 24 + (0, 7, 12, 15, 12, 7, 15, 7)[step]
                add_note(buffer, at + step * beat * 0.5, beat * 0.95, pitch, 0.08, "square", -0.5 if step % 2 else 0.5)
            for step in range(4):
                pitch = melody[(bar * 2 + step) % 8] + (12 if name == "title" and bar >= 4 else 0)
                add_note(buffer, at + step * beat, beat * (1.6 if step == 3 else 0.85), pitch, 0.18, voice, -0.13)
        write_wav(name, buffer)

    durations = {"sword": 0.28, "tool": 0.5, "hurt": 0.4, "door": 0.8, "chest": 1.3, "defeat": 1.6}
    for name, duration in durations.items():
        buffer = array("f", [0]) * (int(SAMPLE_RATE * duration) * 2)
        if name == "chest":
            for index, pitch in enumerate((74, 78, 81, 86)):
                add_note(buffer, index * 0.14, 0.68, pitch, 0.35, "bell", index * 0.2 - 0.3)
        elif name == "defeat":
            for index, pitch in enumerate((62, 58, 55, 50)):
                add_note(buffer, index * 0.2, 0.65, pitch, 0.3, "triangle")
        elif name == "tool":
            for index, pitch in enumerate((81, 86, 93)):
                add_note(buffer, index * 0.1, 0.25, pitch, 0.28, "pluck", index * 0.3 - 0.3)
        elif name == "door":
            add_drum(buffer, 0.04, 0.3, 4)
            add_note(buffer, 0.08, 0.6, 43, 0.45, "bass")
            add_note(buffer, 0.24, 0.4, 55, 0.3, "bell")
        else:
            add_drum(buffer, 0.01, 0.7, 18, name == "sword")
            add_note(buffer, 0.015, duration * 0.8, 86 if name == "sword" else 40, 0.3, "pluck")
        for index in range(len(buffer) // 2):
            fade = min(1, index / (SAMPLE_RATE * 0.006), (len(buffer) // 2 - 1 - index) / (SAMPLE_RATE * 0.04))
            buffer[index * 2] *= fade
            buffer[index * 2 + 1] *= fade
        write_wav(name, buffer)


def ambience():
    """島の4地域を音だけでも判別できる8秒ループを生成する。"""
    duration = 8.0
    frame_count = int(SAMPLE_RATE * duration)
    for name in ("coast", "forest", "marsh", "ruins"):
        generator = random.Random({"coast": 31, "forest": 43, "marsh": 59, "ruins": 71}[name])
        phases = [generator.uniform(0, 2 * pi) for _ in range(12)]
        buffer = array("f", [0]) * (frame_count * 2)
        for index in range(frame_count):
            time = index / SAMPLE_RATE
            smooth = sum(
                sin(2 * pi * harmonic * time / duration + phases[harmonic - 1]) / harmonic
                for harmonic in range(1, 13)
            ) / 3.2
            if name == "coast":
                signal = smooth * 0.34 + sin(2 * pi * 0.25 * time) * 0.12 + sin(2 * pi * 3 * time) * 0.018
            elif name == "forest":
                chirp = sin(2 * pi * (880 + 70 * sin(2 * pi * 0.5 * time)) * time)
                gate = max(0.0, sin(2 * pi * 0.5 * time)) ** 12
                signal = smooth * 0.2 + chirp * gate * 0.08
            elif name == "marsh":
                bubble = sin(2 * pi * (110 + 45 * sin(2 * pi * 0.75 * time)) * time)
                gate = max(0.0, sin(2 * pi * 0.75 * time)) ** 18
                signal = smooth * 0.15 + bubble * gate * 0.12
            else:
                signal = sin(2 * pi * 55 * time) * 0.09 + sin(2 * pi * 82.5 * time) * 0.045 + smooth * 0.08
            pan = 0.18 * sin(2 * pi * time / duration)
            buffer[index * 2] = signal * (1 - pan)
            buffer[index * 2 + 1] = signal * (1 + pan)
        write_wav(name, buffer, 0.34)


if __name__ == "__main__":
    if "--ambience-only" not in sys.argv:
        music_and_cues()
    ambience()
    print("チップチューン楽曲・効果音・地域別環境音を再生成しました")
