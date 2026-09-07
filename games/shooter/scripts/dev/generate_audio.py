"""固定譜面から、このプロジェクト独自の BGM と効果音を再生成する。

実行: python3 scripts/dev/generate_audio.py （ffmpeg が必要）
検証: python3 scripts/dev/generate_audio.py --check
外部音源や既存曲は使わない。この生成物を CC0 とは扱わない。
"""

from array import array
from functools import lru_cache
from math import cos, exp, pi, sin, sqrt, tanh
from pathlib import Path
import random
import subprocess
import sys
import tempfile
import wave


RATE = 44100
OUT = Path(__file__).resolve().parents[2] / "assets" / "audio"
SCORES = {
    "title": (84, ((40, 3), (36, 4), (43, 4), (38, 4)),
              (12, 7, 14, 10, 7, 3, 7, 10)),
    "stage": (132, ((45, 3), (41, 4), (48, 4), (43, 4)),
              (0, 7, 12, 15, 14, 7, 3, 10, 12, 7, 10, 14, 15, 12, 7, 3)),
    "boss": (156, ((38, 3), (38, 3), (41, 4), (37, 3)),
             (0, 12, 7, 3, 0, 10, 7, 3, 12, 15, 14, 7, 6, 3, 7, 12)),
    "result": (100, ((48, 4), (53, 4), (45, 3), (43, 4)),
               (0, 4, 7, 12, 11, 7, 4, 2)),
}
EFFECTS = {"shot": 0.11, "explosion": 0.55, "item": 0.48, "bomb": 1.2, "scan": 0.82}


@lru_cache(maxsize=256)
def voice(midi, duration, kind):
    """同じ音高・長さ・音色から同じ単音を返す。"""
    frequency = 440 * 2 ** ((midi - 69) / 12)
    samples = array("f")
    for index in range(round(duration * RATE)):
        t = index / RATE
        phase = 2 * pi * frequency * t
        attack = 0.12 if kind == "pad" else 0.006
        release = 0.20 if kind == "pad" else min(0.045, duration * 0.25)
        envelope = min(t / attack, 1.0) * min((duration - t) / release, 1.0)
        if kind == "pad":
            tone = (sin(phase) + 0.35 * sin(phase * 1.003)
                    + 0.18 * sin(phase * 0.997) + 0.12 * sin(phase * 2)) / 1.65
        elif kind == "bell":
            tone = sin(phase + 2.5 * sin(phase * 2) * exp(-t * 8))
            envelope *= exp(-t * 3.4)
        elif kind == "bass":
            tone = tanh(1.6 * (sin(phase) + 0.30 * sin(phase * 2)
                              + 0.17 * sin(phase * 3))) * 0.75
            envelope *= 0.35 + 0.65 * exp(-t * 9)
        elif kind == "pulse":
            tone = (sin(phase) + sin(phase * 3) / 3 + sin(phase * 5) / 5
                    + sin(phase * 7) / 7) * 0.7
            envelope *= exp(-t * 2.3)
        else:
            tone = (sin(phase) + 0.38 * sin(phase * 2) + 0.22 * sin(phase * 3)
                    + 0.12 * sin(phase * 4)) * 0.65
            envelope *= exp(-t * 4)
        samples.append(tone * envelope)
    return samples


@lru_cache(maxsize=8)
def percussion(kind):
    """固定ノイズにより再実行時にも打楽器の波形を一致させる。"""
    duration = {"kick": 0.28, "snare": 0.20, "hat": 0.075, "open_hat": 0.26}[kind]
    rng = random.Random(510)
    samples = array("f")
    previous = 0.0
    for index in range(round(duration * RATE)):
        t = index / RATE
        noise = rng.uniform(-1, 1)
        high = noise - previous
        previous = noise
        if kind == "kick":
            tone = sin(2 * pi * (47 * t + 6 * (1 - exp(-t * 42)))) * exp(-t * 18)
            tone += 0.09 * high * exp(-t * 160)
        elif kind == "snare":
            tone = (high * 0.32 + sin(2 * pi * 185 * t) * 0.3) * exp(-t * 23)
        else:
            tone = high * exp(-t * (65 if kind == "hat" else 18)) * 0.42
        samples.append(tone * min(t / 0.001, 1) * min((duration - t) / 0.01, 1))
    return samples


def mix(channels, sound, start, gain, pan=0.0):
    """重ね合わせのため加算する。末尾の余韻はループ先頭へ持ち越す。"""
    offset = round(start * RATE)
    length = len(channels[0])
    gains = (gain * cos((pan + 1) * pi / 4), gain * sin((pan + 1) * pi / 4))
    for channel, level in zip(channels, gains):
        for index, value in enumerate(sound):
            channel[(offset + index) % length] += value * level


def note(channels, start, duration, midi, gain, kind="pluck", pan=0.0, echo=0.0):
    """音とディレイを重ね合わせるため、出力バッファを加算更新する。"""
    sound = voice(midi, duration, kind)
    mix(channels, sound, start, gain, pan)
    if echo:
        mix(channels, sound, start + echo, gain * 0.24, -pan)
        mix(channels, sound, start + echo * 2, gain * 0.09, pan)


def write_wave(path, channels):
    """ピーク制限と継ぎ目の短いフェードでクリップ・クリックを抑える。"""
    peak = max(max(abs(value) for value in channel) for channel in channels) or 1.0
    scale = 0.76 / peak if len(channels) == 2 else min(0.76 / peak, 1.0)
    count = len(channels[0])
    pcm = array("h")
    for index in range(count):
        edge = min(index / 220, (count - 1 - index) / 220, 1.0)
        for channel in channels:
            pcm.append(round(channel[index] * scale * edge * 32767))
    if sys.byteorder != "little":
        pcm.byteswap()
    with wave.open(str(path), "wb") as output:
        output.setnchannels(len(channels))
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())


def phrase_interval(interval, third):
    """三度と七度を和音に合わせ、不意の半音衝突を避ける。"""
    if interval % 12 in (3, 4):
        return interval - interval % 12 + third
    if interval % 12 in (10, 11):
        return interval - interval % 12 + (10 if third == 3 else 11)
    return interval


def music(name):
    """場面別の固定譜面から、同じステレオループを生成する。"""
    bpm, chords, melody = SCORES[name]
    beat = 60 / bpm
    channels = [array("f", [0]) * round(32 * beat * RATE) for _ in range(2)]
    for bar in range(8):
        root, third = chords[bar % len(chords)]
        start = bar * 4 * beat
        for interval, pan in ((0, -0.6), (third, 0.1), (7, 0.6), (14, -0.2)):
            note(channels, start, 4.25 * beat, root + 12 + interval,
                 0.055 if name in ("title", "result") else 0.026, "pad", pan)
        if name == "title":
            for step in range(4):
                interval = phrase_interval(melody[(bar * 4 + step) % len(melody)], third)
                note(channels, start + step * beat, beat * 1.2,
                     root + 24 + interval,
                     0.10, "bell", -0.45 + step * 0.3, beat * 0.75)
            note(channels, start, beat * 3.7, root - 12, 0.12, "bass")
            mix(channels, percussion("hat"), start + beat * 2, 0.07, 0.3)
        elif name == "result":
            for step in range(4):
                interval = phrase_interval(melody[(bar * 4 + step) % len(melody)], third)
                note(channels, start + step * beat, beat * 0.85, root + 12 + interval,
                     0.13, "bell", 0.15, beat * 0.75)
                note(channels, start + (step + 0.5) * beat, beat * 0.38,
                     root + 24 + (0, third, 7, 12)[step], 0.055, "pluck", -0.4)
            for step in (0, 2):
                note(channels, start + step * beat, beat * 1.7, root - 12, 0.17, "bass")
                mix(channels, percussion("kick"), start + step * beat, 0.14)
            mix(channels, percussion("snare"), start + beat * 3, 0.10, -0.1)
        else:
            is_boss = name == "boss"
            for step in range(8):
                current = start + step * beat / 2
                note(channels, current, beat * 0.41, root + (12 if step % 4 == 3 else 0),
                     0.21 if is_boss else 0.19, "bass")
                interval = phrase_interval(melody[(bar * 8 + step) % len(melody)], third)
                note(channels, current, beat * 0.39, root + 24 + interval,
                     0.11, "pulse" if is_boss else "pluck", 0.2, beat * 0.75)
                mix(channels, percussion("open_hat" if step == 7 else "hat"),
                    current, 0.10, -0.55 if step % 2 else 0.55)
                if is_boss:
                    note(channels, current + beat / 4, beat * 0.18,
                         root + 12 + (0, 7, 12, third)[step % 4], 0.055, "pulse", -0.45)
            for step in range(4):
                if is_boss or step % 2 == 0:
                    mix(channels, percussion("kick"), start + step * beat, 0.34)
                if step % 2:
                    mix(channels, percussion("snare"), start + step * beat, 0.22)
            if bar % 4 == 3:
                for step in (6, 7):
                    mix(channels, percussion("snare"), start + (3 + step / 8) * beat, 0.13)
    with tempfile.TemporaryDirectory(prefix="audio-", dir=OUT) as directory:
        source = Path(directory) / "source.wav"
        write_wave(source, channels)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(source),
                        "-c:a", "libvorbis", "-q:a", "5", "-threads", "1",
                        "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact",
                        str(OUT / f"{name}.ogg")], check=True)
    voice.cache_clear()


def effect(name, duration):
    """同じ固定シードと包絡から効果音を再生成する。"""
    rng = random.Random(51)
    samples = array("f")
    filtered = 0.0
    for index in range(round(duration * RATE)):
        t = index / RATE
        progress = t / duration
        if name == "scan":
            sweep = 310 + 980 * progress * progress
            phase = 2 * pi * sweep * t
            ping = sin(phase + 1.8 * sin(phase * 0.25)) * exp(-progress * 3.4)
            carrier = sin(2 * pi * 71 * t) * (0.35 + 0.65 * sin(pi * progress))
            sound = ping * 0.44 + carrier * 0.12
        elif name == "shot":
            phase = 2 * pi * (1500 * t - 4200 * t * t)
            sound = (sin(phase) + 0.25 * sin(phase * 2)) * exp(-t * 36) * 0.44
            sound += rng.uniform(-1, 1) * exp(-t * 130) * 0.08
        elif name == "item":
            segment = duration / 4
            frequency = (659.25, 830.61, 987.77, 1318.51)[min(int(progress * 4), 3)]
            local = t % segment
            phase = 2 * pi * frequency * local
            sound = sin(phase + sin(phase * 2) * exp(-local * 18))
            sound *= sin(pi * local / segment) * 0.39
        else:
            filtered = filtered * 0.82 + rng.uniform(-1, 1) * 0.18
            bass = sin(2 * pi * ((62 if name == "bomb" else 115) * t - 17 * t * t))
            debris = rng.uniform(-1, 1) * exp(-progress * 14)
            sound = (filtered * 1.8 + bass * 0.4) * exp(-progress * 5) + debris * 0.23
        samples.append(sound * min(t / 0.002, 1) * min((duration - t) / 0.01, 1))
    write_wave(OUT / f"{name}.wav", [samples])


def check():
    """圧縮後の実ファイルを検査し、破損・無音・飽和・継ぎ目を検出する。"""
    for name in (*SCORES, *EFFECTS):
        path = OUT / f"{name}.{'ogg' if name in SCORES else 'wav'}"
        result = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path),
                                 "-f", "f32le", "-acodec", "pcm_f32le", "-"],
                                check=True, capture_output=True)
        samples = array("f")
        samples.frombytes(result.stdout)
        if sys.byteorder != "little":
            samples.byteswap()
        peak = max(abs(value) for value in samples)
        rms = sqrt(sum(value * value for value in samples) / len(samples))
        channels = 2 if name in SCORES else 1
        seam = max(abs(samples[channel] - samples[-channels + channel])
                   for channel in range(channels))
        duration = len(samples) / channels / RATE
        expected = 32 * 60 / SCORES[name][0] if name in SCORES else EFFECTS[name]
        if not (0.05 < peak < 0.98 and 0.015 < rms < 0.3 and seam < 0.012
                and abs(duration - expected) < 0.01):
            raise ValueError(f"音声検証失敗: {name}, peak={peak}, rms={rms}, seam={seam}")
        print(f"{path.name}: {duration:.3f} 秒、ピーク {peak:.4f}、RMS {rms:.4f}、境界差 {seam:.6f}")
    print("音声検証 OK: BGM 4 曲、効果音 5 種（試聴の代替にはならない）")


def main():
    """同じ条件で実行すると生成済みの全ファイルを同じ内容にする。"""
    OUT.mkdir(parents=True, exist_ok=True)
    if sys.argv[1:] != ["--check"]:
        for name in SCORES:
            music(name)
            print(f"生成: {name}.ogg", flush=True)
        for name, duration in EFFECTS.items():
            effect(name, duration)
    check()


if __name__ == "__main__":
    main()
