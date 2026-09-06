"""外部音源を使わず、固定シードで同じ BGM・効果音を再生成する。

実行: python3 scripts/dev/generate_audio.py （ffmpeg が必要）
生成した波形はこのプロジェクトで新規作成した素材。CC0 とは扱わない。
"""

from array import array
from math import exp, pi, sin
from pathlib import Path
import random
import subprocess
import tempfile
import wave


RATE = 44100
OUT = Path(__file__).resolve().parents[2] / "assets" / "audio"


def write_wave(path, samples):
    """ピークを制限した 16 bit PCM を同じ入力から同じ内容で書く。"""
    peak = max(abs(value) for value in samples) or 1.0
    scale = min(0.82 / peak, 1.0)
    pcm = array("h", (int(value * scale * 32767) for value in samples))
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())


def note(buffer, start, duration, midi, gain, kind="lead"):
    """指定区間の音を合成する。重ね合わせのため buffer を加算更新する。"""
    frequency = 440 * 2 ** ((midi - 69) / 12)
    count = int(duration * RATE)
    offset = int(start * RATE)
    for index in range(count):
        t = index / RATE
        envelope = min(t / 0.008, 1.0) * min((duration - t) / 0.05, 1.0)
        phase = 2 * pi * frequency * t
        if kind == "bass":
            tone = sin(phase) + 0.2 * sin(2 * phase)
            envelope *= exp(-t * 5)
        elif kind == "pad":
            tone = sin(phase) + 0.18 * sin(phase * 1.003)
            envelope *= min(t / 0.2, 1)
        else:
            tone = sin(phase) + 0.3 * sin(2 * phase) + 0.1 * sin(3 * phase)
            envelope *= exp(-t * 3)
        buffer[(offset + index) % len(buffer)] += gain * envelope * tone


def drum(buffer, start, gain, kind, rng):
    """音の重ね合わせのため buffer を加算更新する。"""
    length = 0.22 if kind == "kick" else 0.10
    for index in range(int(length * RATE)):
        t = index / RATE
        if kind == "kick":
            sound = sin(2 * pi * (48 * t + 8 * (1 - exp(-t * 30)))) * exp(-t * 23)
        else:
            sound = rng.uniform(-1, 1) * exp(-t * (45 if kind == "hat" else 28))
        buffer[(int(start * RATE) + index) % len(buffer)] += sound * gain


def music(name, bpm, roots, melody):
    """固定シード・譜面からループを生成する。"""
    beat = 60 / bpm
    samples = [0.0] * round(32 * beat * RATE)
    rng = random.Random(5)
    for bar in range(8):
        root = roots[bar % len(roots)]
        start = bar * 4 * beat
        for interval in (0, 7, 12):
            note(samples, start, 4 * beat, root + 12 + interval, 0.026, "pad")
        for step in range(8):
            current = start + step * beat / 2
            note(samples, current, beat * 0.43, root + (12 if step % 4 == 3 else 0), 0.14, "bass")
            note(samples, current, beat * 0.46, root + 24 + melody[(bar * 8 + step) % len(melody)], 0.075)
            drum(samples, current, 0.028, "hat", rng)
        for step in range(4):
            drum(samples, start + step * beat, 0.21 if step % 2 == 0 else 0.095,
                 "kick" if step % 2 == 0 else "snare", rng)
    # 波形の継ぎ目だけを平滑化し、ループ時のクリックを抑える。
    for index in range(220):
        samples[index] *= index / 220
        samples[-1 - index] *= index / 220
    with tempfile.TemporaryDirectory(prefix="audio-", dir=OUT) as directory:
        source = Path(directory) / "source.wav"
        write_wave(source, samples)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(source),
                        "-c:a", "libvorbis", "-q:a", "5", "-map_metadata", "-1",
                        "-fflags", "+bitexact", "-flags:a", "+bitexact",
                        str(OUT / f"{name}.ogg")], check=True)


def effect(name, duration):
    """固定シードから効果音を生成する。"""
    rng = random.Random(51)
    samples = []
    filtered = 0.0
    for index in range(int(duration * RATE)):
        t = index / RATE
        progress = t / duration
        attack = min(t / 0.002, 1.0)
        if name == "shot":
            sound = sin(2 * pi * (1250 * t - 3400 * t * t)) * exp(-t * 30) * 0.34
        elif name == "item":
            frequency = (659.25, 830.61, 987.77, 1318.51)[min(int(progress * 4), 3)]
            local = t % (duration / 4)
            sound = sin(2 * pi * frequency * local) * sin(pi * local / (duration / 4)) * 0.34
        else:
            filtered = filtered * 0.8 + rng.uniform(-1, 1) * 0.2
            bass = sin(2 * pi * ((70 if name == "bomb" else 105) * t - 15 * t * t))
            sound = (filtered * 0.7 + bass * 0.25) * exp(-progress * 5) * 0.9
        samples.append(sound * attack * min((duration - t) / 0.01, 1.0))
    write_wave(OUT / f"{name}.wav", samples)


def main():
    """生成済みファイルへ同じ内容を再出力する。"""
    OUT.mkdir(parents=True, exist_ok=True)
    music("stage", 120, (45, 41, 48, 43), (0, 7, 12, 15, 12, 7, 3, 7, 0, 7, 10, 14, 10, 7, 2, 7))
    music("boss", 144, (38, 38, 41, 37), (0, 12, 7, 3, 0, 10, 7, 3, 0, 12, 15, 7, 6, 3, 7, 12))
    for name, duration in (("shot", 0.11), ("explosion", 0.55), ("item", 0.4), ("bomb", 1.2)):
        effect(name, duration)
    print("音声生成 OK: BGM 2 曲、効果音 4 種")


if __name__ == "__main__":
    main()
