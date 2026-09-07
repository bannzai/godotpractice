#!/usr/bin/env python3
"""町とルートの8-bit風環境音を決定的に生成し、数値検査する。"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path
import struct
import sys
import wave


GAME_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUT = GAME_ROOT / "assets" / "audio"
RATE = 32_000
DURATION = 8.0
FRAMES = int(RATE * DURATION)
CHANNELS = 2
TRACKS = ("town_ambience", "route_ambience")


def square(cycles: int, index: int) -> float:
    return 1.0 if (index * cycles) % FRAMES < FRAMES // 2 else -1.0


def triangle(cycles: int, index: int) -> float:
    phase = ((index * cycles) % FRAMES) / FRAMES
    return 1.0 - 4.0 * abs(phase - 0.5)


def event_envelope(local_time: float, duration: float) -> float:
    if local_time < 0.0 or local_time >= duration:
        return 0.0
    attack = min(1.0, local_time / 0.012)
    release = min(1.0, (duration - local_time) / 0.055)
    return attack * release * (1.0 - local_time / duration)


def event_square(time: float, start: float, duration: float, frequency: float) -> float:
    local_time = time - start
    envelope = event_envelope(local_time, duration)
    if envelope == 0.0:
        return 0.0
    phase = int(local_time * frequency * 2.0)
    return envelope * (1.0 if phase % 2 == 0 else -1.0)


def circular_noise() -> list[float]:
    state = 0x6D2B
    raw: list[float] = []
    for _ in range(1024):
        bit = ((state >> 0) ^ (state >> 2) ^ (state >> 3) ^ (state >> 5)) & 1
        state = (state >> 1) | (bit << 15)
        raw.append(1.0 if state & 1 else -1.0)
    # 前後も巡回させて平滑化し、ループ境界だけに段差を作らない。
    return [sum(raw[(index + offset) % 1024] for offset in range(-12, 13)) / 25.0
            for index in range(1024)]


def town_sample(index: int) -> tuple[float, float]:
    time = index / RATE
    # 整数周期の矩形波と三角波で、遠くの機械時計と町のざわめきを表す。
    bed = 0.018 * square(880, index) + 0.014 * triangle(440, index)
    chime = 0.0
    for start, first, second in ((0.65, 659.25, 783.99), (2.65, 523.25, 659.25),
                                 (4.65, 587.33, 739.99), (6.65, 523.25, 783.99)):
        chime += 0.105 * event_square(time, start, 0.24, first)
        chime += 0.075 * event_square(time, start + 0.16, 0.28, second)
    step_left = 0.0
    step_right = 0.0
    for start in (1.45, 1.72, 5.42, 5.69):
        step_left += 0.038 * event_square(time, start, 0.055, 82.0)
        step_right += 0.026 * event_square(time, start + 0.28, 0.055, 88.0)
    chatter_left = 0.0
    chatter_right = 0.0
    # 左右の短い掛け合いを不規則に置き、時計だけでなく人のいる町だと伝える。
    for start, frequency, pan in (
        (0.18, 294.0, -1), (0.29, 370.0, -1), (0.43, 330.0, -1),
        (2.06, 262.0, 1), (2.18, 330.0, 1),
        (3.54, 349.0, -1), (3.66, 294.0, -1),
        (5.92, 277.0, 1), (6.04, 349.0, 1), (6.18, 311.0, 1),
    ):
        voice = 0.032 * event_square(time, start, 0.075, frequency)
        if pan < 0:
            chatter_left += voice
            chatter_right += voice * 0.34
        else:
            chatter_left += voice * 0.34
            chatter_right += voice
    return (
        bed + chime + step_left + chatter_left,
        bed + chime * 0.82 + step_right + chatter_right,
    )


NOISE = circular_noise()


def route_sample(index: int) -> tuple[float, float]:
    time = index / RATE
    # 1024サンプルの巡回LFSRノイズを平滑化し、草と水辺の環境音にする。
    rustle_left = NOISE[index % 1024]
    rustle_right = NOISE[(index + 211) % 1024]
    bed_left = 0.038 * rustle_left + 0.012 * triangle(256, index)
    bed_right = 0.038 * rustle_right + 0.012 * triangle(256, index)
    chirp = 0.0
    for start, frequency in ((0.85, 820.0), (2.35, 980.0), (4.2, 880.0), (6.35, 1060.0)):
        local = time - start
        if 0.0 <= local < 0.26:
            rising_frequency = frequency + local * 420.0
            chirp += 0.044 * event_square(time, start, 0.26, rising_frequency)
    return bed_left + chirp, bed_right + chirp * 0.72


def encode_track(name: str) -> bytes:
    sample_function = town_sample if name == "town_ambience" else route_sample
    pcm = bytearray()
    for index in range(FRAMES):
        left, right = sample_function(index)
        for sample in (left, right):
            value = round(max(-0.9, min(0.9, sample)) * 32767)
            pcm.extend(struct.pack("<h", value))
    output = io.BytesIO()
    with wave.open(output, "wb") as wav:
        wav.setparams((CHANNELS, 2, RATE, FRAMES, "NONE", "not compressed"))
        wav.writeframes(bytes(pcm))
    return output.getvalue()


def write_if_changed(path: Path, data: bytes) -> bool:
    if path.is_file() and path.read_bytes() == data:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return True


def inspect_wav(path: Path) -> dict[str, float | int | str]:
    with wave.open(str(path), "rb") as wav:
        channels = wav.getnchannels()
        width = wav.getsampwidth()
        rate = wav.getframerate()
        frames = wav.getnframes()
        raw = wav.readframes(frames)
    values = struct.unpack(f"<{len(raw) // 2}h", raw)
    peak = max(abs(value) for value in values) / 32767.0
    clipped = sum(value in (-32768, 32767) for value in values)
    first = values[:channels]
    last = values[-channels:]
    boundary_jump = max(abs(first[channel] - last[channel]) for channel in range(channels))
    near = []
    window_frames = min(frames - 1, rate // 100)
    for frame in list(range(window_frames)) + list(range(frames - window_frames, frames - 1)):
        for channel in range(channels):
            current = values[frame * channels + channel]
            following = values[(frame + 1) * channels + channel]
            near.append(abs(current - following))
    local_jump = max(near) if near else 0
    return {
        "path": str(path), "channels": channels, "sample_width": width,
        "rate": rate, "frames": frames, "peak": peak, "clipped": clipped,
        "boundary_jump": boundary_jump, "local_jump": local_jump,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }


def validate(out_dir: Path) -> None:
    failures: list[str] = []
    reports = []
    for name in TRACKS:
        path = out_dir / f"{name}.wav"
        if not path.is_file():
            failures.append(f"missing {path}")
            continue
        report = inspect_wav(path)
        reports.append(report)
        if report["channels"] != CHANNELS or report["sample_width"] != 2:
            failures.append(f"format {name}")
        if report["rate"] != RATE or report["frames"] != FRAMES:
            failures.append(f"duration {name}")
        if not 0.02 <= report["peak"] <= 0.95:
            failures.append(f"peak {name}: {report['peak']:.4f}")
        if report["clipped"] != 0:
            failures.append(f"clip {name}: {report['clipped']}")
        if report["boundary_jump"] > max(1, report["local_jump"]):
            failures.append(
                f"loop {name}: boundary={report['boundary_jump']} local={report['local_jump']}"
            )
        if path.read_bytes() != encode_track(name):
            failures.append(f"reproducibility {name}")
    if failures:
        raise ValueError("\n".join(failures))
    for report in reports:
        print(
            f"OK {Path(str(report['path'])).name}: {report['rate']} Hz stereo "
            f"peak={report['peak']:.4f} clip={report['clipped']} "
            f"loop={report['boundary_jump']}/{report['local_jump']} "
            f"sha256={report['sha256']}"
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--print-spec", action="store_true")
    arguments = parser.parse_args()
    if arguments.print_spec:
        print(json.dumps({
            "rate": RATE, "channels": CHANNELS, "sample_width": 2, "duration": DURATION,
            "audio": [{"path": f"{name}.wav", "loop": True} for name in TRACKS],
        }, ensure_ascii=False, indent=2))
        return 0
    try:
        if arguments.check:
            validate(arguments.out_dir)
            print(f"環境音検査 OK: {len(TRACKS)} WAV、形式・音量・クリップ・ループ・再生成一致")
            return 0
        changed = 0
        for name in TRACKS:
            changed += int(write_if_changed(arguments.out_dir / f"{name}.wav", encode_track(name)))
        print(f"環境音生成 OK: {len(TRACKS)} WAV（更新 {changed}、変更なし {len(TRACKS)-changed}）")
        return 0
    except (OSError, ValueError, wave.Error) as error:
        print(f"環境音生成 FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
