#!/usr/bin/env python3
"""青焼き図面の世界に合わせた 16bit PCM 音声だけを決定的に生成する。"""

from array import array
import argparse
import io
import json
import math
from pathlib import Path
import random
import sys
import wave


# 22,050 Hz はゲーム内の環境音、短い効果音、簡素なループ曲に十分な帯域を持ち、
# 44,100 Hz より生成物を小さく保てる。すべての乱数は固定 seed から作る。
RATE = 22050
SEED = 20260907
TAU = math.tau

MUSIC = {
    "title": {
        "seconds": 12.0,
        "chords": ((48, 55, 60, 64), (45, 52, 57, 60), (53, 60, 64, 69), (55, 62, 67, 71)),
        "melody": (72, 76, 79, 76, 74, 72, 67, 71),
        "activity": 0.72,
    },
    "town": {
        "seconds": 10.0,
        "chords": ((48, 55, 60, 64), (57, 64, 69, 72), (53, 60, 65, 69), (55, 62, 67, 71)),
        "melody": (76, 79, 81, 79, 76, 74, 72, 74),
        "activity": 0.88,
    },
    "city": {
        "seconds": 8.0,
        "chords": ((50, 57, 62, 65), (55, 62, 67, 71), (48, 55, 60, 64), (57, 64, 69, 72)),
        "melody": (74, 77, 81, 84, 81, 79, 77, 76),
        "activity": 1.15,
    },
    "result": {
        "seconds": 12.0,
        "chords": ((48, 55, 60, 64), (53, 60, 65, 69), (55, 62, 67, 71), (48, 55, 60, 64)),
        "melody": (79, 84, 83, 79, 81, 79, 76, 72),
        "activity": 0.62,
    },
}

SOUNDS = {
    **{
        name: {
            "path": f"audio/{name}.wav",
            "loop": True,
            "stereo": True,
            "peak": 0.68,
            "build": lambda name=name: music_samples(name),
        }
        for name in MUSIC
    },
    "build": {
        "path": "audio/build.wav",
        "loop": False,
        "stereo": False,
        "peak": 0.72,
        "build": lambda: effect_samples("build"),
    },
    "demolish": {
        "path": "audio/demolish.wav",
        "loop": False,
        "stereo": False,
        "peak": 0.72,
        "build": lambda: effect_samples("demolish"),
    },
    "alert": {
        "path": "audio/alert.wav",
        "loop": False,
        "stereo": False,
        "peak": 0.68,
        "build": lambda: effect_samples("alert"),
    },
    "month": {
        "path": "audio/month.wav",
        "loop": False,
        "stereo": False,
        "peak": 0.70,
        "build": lambda: effect_samples("month"),
    },
    "click": {
        "path": "audio/click.wav",
        "loop": False,
        "stereo": False,
        "peak": 0.62,
        "build": lambda: effect_samples("click"),
    },
    "ambience": {
        "path": "audio/ambience.wav",
        "loop": True,
        "stereo": True,
        "peak": 0.34,
        "build": lambda: ambience_samples(12.0),
    },
}


def pitch(midi):
    """MIDI 音高を周波数へ変換する。"""
    return 440.0 * 2.0 ** ((midi - 69.0) / 12.0)


def empty_buffer(seconds, stereo):
    """指定秒数の無音バッファを作る。"""
    frames = round(seconds * RATE)
    return [[0.0] * frames for _channel in range(2 if stereo else 1)]


def bell_samples(frequency, duration, softness=1.0):
    """図面台のガラスベルを思わせる、減衰の速い倍音音色を作る。"""
    result = []
    for index in range(round(duration * RATE)):
        time = index / RATE
        attack = min(1.0, time / 0.009)
        release = min(1.0, max(0.0, duration - time) / 0.055)
        phase = TAU * frequency * time
        tone = (
            math.sin(phase) * math.exp(-2.8 * time)
            + 0.29 * math.sin(phase * 2.01) * math.exp(-6.5 * time)
            + 0.12 * math.sin(phase * 3.97) * math.exp(-10.0 * time)
        )
        result.append(tone * attack * release * softness)
    return result


def drafting_pad_samples(frequencies, duration):
    """青焼き機の低い共鳴を模した、柔らかな持続和音を作る。"""
    result = []
    for index in range(round(duration * RATE)):
        time = index / RATE
        attack = min(1.0, time / 0.18)
        release = min(1.0, max(0.0, duration - time) / 0.28)
        tone = 0.0
        for voice, frequency in enumerate(frequencies):
            drift = 1.0 + (voice - 1.5) * 0.0007
            phase = TAU * frequency * drift * time
            tone += math.sin(phase) + 0.14 * math.sin(phase * 2.0)
        result.append(tone * attack * release / len(frequencies))
    return result


def ruler_tap_samples(duration=0.12, bright=True):
    """木製定規を図面台へ置く短い打音を作る。"""
    result = []
    for index in range(round(duration * RATE)):
        time = index / RATE
        attack = min(1.0, time / 0.0015)
        decay = math.exp(-time * (34.0 if bright else 25.0))
        low = math.sin(TAU * 178.0 * time)
        edge = math.sin(TAU * (1180.0 if bright else 720.0) * time)
        result.append((0.72 * low + 0.28 * edge) * attack * decay)
    return result


def pencil_stroke_samples(duration, rng, hardness=1.0):
    """固定乱数の摩擦音を高域差分で整え、鉛筆の線引きを表現する。"""
    result = []
    previous = 0.0
    smooth = 0.0
    count = round(duration * RATE)
    for index in range(count):
        time = index / RATE
        raw = rng.uniform(-1.0, 1.0)
        smooth = smooth * 0.74 + raw * 0.26
        grain = smooth - previous * 0.58
        previous = smooth
        phase_envelope = max(0.0, math.sin(math.pi * index / max(1, count - 1)))
        envelope = phase_envelope**0.55
        tooth = 0.72 + 0.28 * math.sin(TAU * (27.0 + hardness * 5.0) * time)
        result.append(grain * envelope * tooth * hardness)
    return result


def paper_rustle_samples(duration, rng):
    """低域を残した固定乱数で紙をめくる音を作る。"""
    result = []
    smooth = 0.0
    count = round(duration * RATE)
    for index in range(count):
        raw = rng.uniform(-1.0, 1.0)
        smooth = smooth * 0.91 + raw * 0.09
        phase_envelope = max(0.0, math.sin(math.pi * index / max(1, count - 1)))
        envelope = phase_envelope**0.8
        result.append((smooth * 0.8 + raw * 0.12) * envelope)
    return result


def eraser_samples(duration, rng):
    """消しゴムを往復させる、周期的な紙の摩擦音を作る。"""
    stroke = pencil_stroke_samples(duration, rng, 0.72)
    for index in range(len(stroke)):
        time = index / RATE
        stroke[index] *= 0.5 + 0.5 * abs(math.sin(TAU * 8.0 * time))
    return stroke


def mix(buffer, samples, start, gain, pan=0.0, wrap=False):
    """音をバッファへ加算する。呼び出し元は毎回空バッファから始める。"""
    begin = round(start * RATE)
    frame_count = len(buffer[0])
    if len(buffer) == 1:
        gains = (gain,)
    else:
        limited_pan = max(-1.0, min(1.0, pan))
        gains = (
            gain * math.sqrt((1.0 - limited_pan) * 0.5),
            gain * math.sqrt((1.0 + limited_pan) * 0.5),
        )
    for offset, sample in enumerate(samples):
        frame = begin + offset
        if wrap:
            frame %= frame_count
        elif frame < 0 or frame >= frame_count:
            continue
        for channel, channel_gain in enumerate(gains):
            buffer[channel][frame] += sample * channel_gain


def periodic_room_tone(buffer, seconds, seed, gain):
    """整数周期の正弦波群で、端点が連続する静かな製図室の空気を重ねる。"""
    frames = len(buffer[0])
    for channel in range(len(buffer)):
        rng = random.Random(seed + channel * 101)
        components = [
            (rng.randint(190, 510), rng.uniform(0.0, TAU), rng.uniform(0.35, 1.0))
            for _component in range(18)
        ]
        hum_phase = rng.uniform(0.0, TAU)
        for frame in range(frames):
            position = frame / frames
            texture = sum(
                weight * math.sin(TAU * cycles * position + phase)
                for cycles, phase, weight in components
            ) / len(components)
            hum = math.sin(TAU * round(55.0 * seconds) * position + hum_phase)
            buffer[channel][frame] += gain * (texture * 0.78 + hum * 0.06)


def interleave(buffer):
    """チャンネル別バッファをWAV用のインターリーブ配列へ変換する。"""
    if len(buffer) == 1:
        return buffer[0]
    return [sample for frame in zip(*buffer) for sample in frame]


def music_samples(name):
    """ベル、鉛筆、定規、青焼き機の共鳴を場面ごとに組み合わせる。"""
    config = MUSIC[name]
    seconds = config["seconds"]
    activity = config["activity"]
    buffer = empty_buffer(seconds, True)
    rng = random.Random(SEED + sum(ord(character) for character in name))
    periodic_room_tone(buffer, seconds, SEED + len(name) * 17, 0.022)
    bar_duration = seconds / len(config["chords"])

    for bar, chord in enumerate(config["chords"]):
        bar_start = bar * bar_duration
        pad = drafting_pad_samples([pitch(note) for note in chord], bar_duration * 0.84)
        mix(buffer, pad, bar_start + bar_duration * 0.06, 0.11, -0.12 if bar % 2 == 0 else 0.12)
        for step in range(4):
            event_time = bar_start + bar_duration * (step + 0.18) / 4.0
            note = config["melody"][(bar * 2 + step) % len(config["melody"])]
            # 最終拍でもループ終端より前にリリースを完了させ、波形を途中で切らない。
            bell = bell_samples(pitch(note), min(0.42, bar_duration * 0.18), 0.92)
            mix(buffer, bell, event_time, 0.19 * activity, -0.62 if step % 2 == 0 else 0.62)
            if name in ("town", "city") or step % 2 == 0:
                tap = ruler_tap_samples(0.09, bright=step % 2 == 0)
                mix(buffer, tap, event_time, 0.055 * activity, 0.34 if step % 2 == 0 else -0.34)
        stroke_count = 4 if name == "city" else 2
        for stroke_index in range(stroke_count):
            start = bar_start + bar_duration * (0.34 + stroke_index * 0.5 / stroke_count)
            stroke = pencil_stroke_samples(0.13 if name == "city" else 0.19, rng, 0.72)
            mix(buffer, stroke, start, 0.035 * activity, -0.5 + stroke_index * 0.35)

    return interleave(buffer)


def ambience_samples(seconds):
    """紙、鉛筆、定規と静かな製図室だけで構成する環境音ループを作る。"""
    buffer = empty_buffer(seconds, True)
    rng = random.Random(SEED + 4000)
    periodic_room_tone(buffer, seconds, SEED + 4100, 0.10)
    for index, start in enumerate((1.15, 2.72, 4.48, 6.36, 8.05, 10.22)):
        stroke = pencil_stroke_samples(0.44 + (index % 3) * 0.11, rng, 0.78 + (index % 2) * 0.12)
        mix(buffer, stroke, start, 0.11, -0.68 if index % 2 == 0 else 0.56)
    for index, start in enumerate((3.38, 8.88)):
        paper = paper_rustle_samples(0.82, rng)
        mix(buffer, paper, start, 0.10, 0.58 if index == 0 else -0.58)
    for index, start in enumerate((5.62, 9.82)):
        mix(buffer, ruler_tap_samples(0.10, bright=index == 0), start, 0.055, -0.25 + index * 0.5)
    return interleave(buffer)


def effect_samples(name):
    """建設操作を製図道具の動作として聞かせる5種類の効果音を作る。"""
    durations = {"build": 0.58, "demolish": 0.62, "alert": 0.76, "month": 0.82, "click": 0.16}
    buffer = empty_buffer(durations[name], False)
    rng = random.Random(SEED + 5000 + sum(ord(character) for character in name))
    if name == "build":
        mix(buffer, pencil_stroke_samples(0.34, rng, 1.05), 0.0, 0.30)
        for index, note in enumerate((67, 72, 79)):
            mix(buffer, bell_samples(pitch(note), 0.31), 0.11 + index * 0.09, 0.23)
        mix(buffer, ruler_tap_samples(0.08), 0.04, 0.16)
    elif name == "demolish":
        mix(buffer, eraser_samples(0.46, rng), 0.0, 0.42)
        mix(buffer, ruler_tap_samples(0.18, bright=False), 0.02, 0.32)
        for index, note in enumerate((55, 50, 43)):
            mix(buffer, bell_samples(pitch(note), 0.24, 0.65), 0.18 + index * 0.09, 0.15)
    elif name == "alert":
        for index in range(2):
            start = index * 0.29
            mix(buffer, ruler_tap_samples(0.12), start, 0.24)
            mix(buffer, bell_samples(pitch(71), 0.27), start, 0.24)
            mix(buffer, bell_samples(pitch(77), 0.27), start, 0.13)
    elif name == "month":
        mix(buffer, paper_rustle_samples(0.38, rng), 0.0, 0.24)
        for index, note in enumerate((72, 76, 79, 84)):
            mix(buffer, bell_samples(pitch(note), 0.35), 0.23 + index * 0.10, 0.20)
    else:
        mix(buffer, ruler_tap_samples(0.07), 0.0, 0.34)
        mix(buffer, bell_samples(pitch(84), 0.11, 0.75), 0.018, 0.16)
    return buffer[0]


def wave_bytes(samples, stereo, target_peak):
    """波形を指定ピーク以下に正規化した16bit PCM WAVへ変換する。"""
    peak = max((abs(value) for value in samples), default=0.0)
    scale = target_peak / peak if peak else 1.0
    pcm = array(
        "h",
        (
            round(max(-1.0, min(1.0, value * scale)) * 32767)
            for value in samples
        ),
    )
    if sys.byteorder != "little":
        pcm.byteswap()
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as target:
        target.setnchannels(2 if stereo else 1)
        target.setsampwidth(2)
        target.setframerate(RATE)
        target.writeframes(pcm.tobytes())
    return buffer.getvalue()


def write_asset(path, data):
    """同じバイト列なら書き直さず、再実行でmtimeを変えない。"""
    if path.is_file() and path.read_bytes() == data:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return True


def asset_spec():
    """game-asset-searchの検査スクリプトが読む素材定義を返す。"""
    return {
        "rate": RATE,
        "images": [],
        "audio": [
            {"path": sound["path"], "loop": sound["loop"], "stereo": sound["stereo"]}
            for sound in SOUNDS.values()
        ],
    }


def generate(out_dir):
    """定義した音声をすべて生成する。"""
    for name, sound in SOUNDS.items():
        samples = sound["build"]()
        data = wave_bytes(samples, sound["stereo"], sound["peak"])
        changed = write_asset(out_dir / sound["path"], data)
        channels = "stereo" if sound["stereo"] else "mono"
        status = "更新" if changed else "変更なし"
        print(f"{name}: {sound['path']} ({channels}, {RATE} Hz, {status})")


def main():
    """--out-dirで生成し、--print-specではJSON定義だけを出力する。"""
    parser = argparse.ArgumentParser(description="青焼き図面を題材にしたPCM音声を生成する")
    parser.add_argument("--out-dir", help="生成先のassetsディレクトリ")
    parser.add_argument("--print-spec", action="store_true", help="生成せず定義をJSONで出力する")
    args = parser.parse_args()
    if args.print_spec:
        print(json.dumps(asset_spec(), ensure_ascii=False))
        return 0
    if not args.out_dir:
        parser.error("--out-dir を指定してください")
    generate(Path(args.out_dir))
    return 0


if __name__ == "__main__":
    sys.exit(main())
