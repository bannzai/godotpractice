"""外部音源を使わず、玩具工房の音を同じバイト列で再生成する。"""

from array import array
import math
from pathlib import Path
import struct
import wave


RATE = 22050
OUTPUT = Path(__file__).resolve().parents[2] / "assets" / "audio"


def frequency(note):
    """MIDI 音高を周波数へ変換する。"""
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def tone(note, duration, amplitude=0.25, soft=False):
    """倍音と減衰包絡を備えた有限長の音を返す。"""
    count = round(duration * RATE)
    hz = frequency(note)
    result = array("f")
    for index in range(count):
        t = index / RATE
        attack = min(1.0, t / 0.008)
        release = min(1.0, (count - 1 - index) / (RATE * 0.025))
        decay = math.exp(-t * (2.8 if soft else 7.0))
        fundamental = math.sin(math.tau * hz * t)
        harmonic = 0.18 * math.sin(math.tau * hz * 2.0 * t)
        result.append(amplitude * attack * release * decay * (fundamental + harmonic))
    return result


def mix(length, events, loop=False):
    """イベントから波形を新しく構築する。ループでは音の尾を先頭に折り返す。"""
    result = array("f", [0.0]) * round(length * RATE)
    for start, sound in events:
        offset = round(start * RATE)
        for index, value in enumerate(sound):
            target = offset + index
            if loop:
                target %= len(result)
            if target < len(result):
                result[target] += value
    return result


def write_audio(name, sound):
    """固定パラメータで音声を保存するため、再実行しても出力は同一になる。"""
    peak = max(abs(value) for value in sound)
    gain = min(1.0, 0.78 / peak) if peak else 1.0
    pcm = [round(value * gain * 32767) for value in sound]
    with wave.open(str(OUTPUT / name), "wb") as output:
        output.setparams((1, 2, RATE, len(pcm), "NONE", "not compressed"))
        output.writeframes(struct.pack(f"<{len(pcm)}h", *pcm))
    rms = math.sqrt(sum(value * value for value in pcm) / len(pcm)) / 32767
    print(f"{name}: {len(pcm) / RATE:.2f} 秒, 最大振幅 {max(map(abs, pcm)) / 32767:.3f}, RMS {rms:.3f}")


def main():
    """音楽と効果音のオリジナル波形を生成する。"""
    OUTPUT.mkdir(parents=True, exist_ok=True)
    beat = 0.6
    events = []
    chords = [(48, 64, 67, 72), (45, 64, 69, 72), (41, 65, 69, 72), (43, 62, 67, 71)]
    melody = [76, 79, 81, 79, 76, 74, 72, 74, 76, 81, 79, 76, 74, 72, 71, 74]
    for bar in range(8):
        chord = chords[bar // 2]
        start = bar * 4 * beat
        for step in range(4):
            events.append((start + step * beat, tone(chord[0], 0.48, 0.12, soft=True)))
            events.append((start + (step + 0.5) * beat, tone(chord[1 + step % 3], 0.52, 0.095)))
        events.append((start, tone(melody[bar * 2], 0.9, 0.13)))
        events.append((start + 2.5 * beat, tone(melody[bar * 2 + 1], 0.75, 0.13)))
    write_audio("music.wav", mix(32 * beat, events, loop=True))
    write_audio("pickup.wav", mix(0.38, [(0.0, tone(84, 0.22)), (0.07, tone(91, 0.3, 0.2))]))
    write_audio("bump.wav", mix(0.18, [(0.0, tone(43, 0.18, 0.46)), (0.01, tone(55, 0.12, 0.12))]))
    write_audio("win.wav", mix(1.1, [(0.0, tone(72, 0.55)), (0.15, tone(76, 0.6)), (0.3, tone(79, 0.65)), (0.45, tone(84, 0.65))]))
    write_audio("lose.wav", mix(0.8, [(0.0, tone(67, 0.38, 0.23, soft=True)), (0.19, tone(62, 0.4, 0.23, soft=True)), (0.38, tone(55, 0.42, 0.23, soft=True))]))


if __name__ == "__main__":
    main()
