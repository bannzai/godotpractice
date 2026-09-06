"""宵森の灯守の独自 SVG と合成音声を決定的に再生成する。外部画像・音源は使わない。"""

from array import array
import math
from pathlib import Path
import random
import wave

ROOT = Path(__file__).resolve().parents[2] / "assets"
RATE = 22050


def svg(name, body, size=128):
    """同じ入力から同じ SVG を保存する。"""
    (ROOT / "art" / f"{name}.svg").write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
        f'viewBox="0 0 128 128">{body}</svg>\n'
    )


def make_art():
    """輪郭と色の対比を統一した、拡縮可能な独自素材を生成する。"""
    (ROOT / "art").mkdir(parents=True, exist_ok=True)
    floor = '<rect width="128" height="128" fill="#183c3b"/>'
    rng = random.Random(2026)
    for _ in range(36):
        x, y = rng.randrange(7, 121), rng.randrange(7, 121)
        color = rng.choice(["#204543", "#234c46", "#1a3538", "#2b524b"])
        floor += f'<path d="M{x-3} {y+2}q2 -8 7 -8q-1 7 -7 8" fill="{color}"/>'
    floor += '<path d="M22 42l7 -2m58 51l6 -2M44 116l5 -2" stroke="#44665a" stroke-width="2" opacity=".5"/>'
    svg("floor", floor)
    svg("player", '''<ellipse cx="65" cy="111" rx="29" ry="9" fill="#08282c" opacity=".5"/>
<path d="M50 99v13h12v-14m7 0v14h12V96" fill="#142c36" stroke="#072c31" stroke-width="5"/>
<path d="M33 99l10 -46h42l18 48q-36 17 -70 -2" fill="#61bbaa" stroke="#173e48" stroke-width="5"/>
<path d="M58 52l-4 51m26 -46l9 45" stroke="#b5e9cf" stroke-width="4"/>
<path d="M38 60Q29 17 62 10q39 -3 37 46L82 72H52Z" fill="#398f85" stroke="#123d44" stroke-width="5"/>
<path d="M43 47q20 -20 46 1v17q-23 15 -44 -1Z" fill="#112d3b"/>
<path d="M54 52v7m20 -7v7" stroke="#fff0b6" stroke-width="5" stroke-linecap="round"/>
<path d="M31 78L16 88m75 -11l15 8" stroke="#a2ddbd" stroke-width="10" stroke-linecap="round"/>
<path d="M15 92v-9q0 -10 10 -10q10 0 10 10v8" fill="none" stroke="#edbc69" stroke-width="4"/>
<path d="M11 90h28l-3 24H14Z" fill="#f3c06c" stroke="#634d34" stroke-width="4"/>
<path d="M20 94h10v15H20Z" fill="#fff4ba"/><circle cx="89" cy="34" r="6" fill="#c5e6b2"/>''')
    svg("enemy-0", '''<ellipse cx="62" cy="111" rx="33" ry="8" fill="#08282c" opacity=".4"/>
<path d="M27 90Q10 52 37 37l-6 -22 24 12q18 -7 29 2l22 -16 -6 29q22 24 1 53l-18 -5 -18 14 -14 -13 -18 10Z" fill="#9c79d9" stroke="#392e60" stroke-width="6"/>
<path d="M39 52q23 -13 49 0l-6 28H45Z" fill="#554275"/>
<path d="M48 59l10 5m14 0l10 -5" stroke="#f6dcb7" stroke-width="6" stroke-linecap="round"/>
<circle cx="42" cy="39" r="5" fill="#cab1ee"/><path d="M55 81l9 4 10 -5" fill="none" stroke="#cab1ee" stroke-width="3"/>''')
    svg("enemy-1", '''<path d="M57 50Q17 1 9 44q-4 27 35 33Q12 81 27 106q18 20 36 -21q18 41 36 21q15 -25 -17 -29q40 -6 36 -33Q109 1 69 50" fill="#d77986" stroke="#653f58" stroke-width="5"/>
<path d="M50 59L21 34l9 27m46 -2l29 -25 -9 27M45 83l-8 16m44 -16l8 16" fill="none" stroke="#f3bd9d" stroke-width="5"/>
<path d="M57 43L45 25m25 18l13 -18" stroke="#d8b6c6" stroke-width="4"/>
<ellipse cx="63" cy="65" rx="12" ry="28" fill="#53415c"/><circle cx="58" cy="48" r="4" fill="#ffe7a9"/><circle cx="69" cy="48" r="4" fill="#ffe7a9"/>''')
    svg("enemy-2", '''<path d="M29 86l-6 28h23l8 -19m22 0l7 19h22l-7 -30" fill="#314f4a" stroke="#173936" stroke-width="5"/>
<path d="M17 86l7 -36 16 -18 28 -9 30 15 17 32 -10 29 -43 7Z" fill="#719879" stroke="#284c46" stroke-width="6"/>
<path d="M22 46l-5 -22 22 9 12 -18 14 16 20 -13 4 20 18 -3 -3 25 -17 -8 -14 10 -16 -14 -19 14Z" fill="#a2b97b"/>
<path d="M36 65l17 4m24 -1l16 -4" stroke="#e9e5b0" stroke-width="7" stroke-linecap="round"/>
<path d="M49 86l14 5 16 -6" fill="none" stroke="#284c46" stroke-width="5"/>
<path d="M21 77l14 9m58 -33l7 10" stroke="#a3b994" stroke-width="4"/>''')
    svg("enemy-3", '''<ellipse cx="64" cy="114" rx="45" ry="10" fill="#08282c" opacity=".5"/>
<path d="M28 60L8 40l8 -29 7 26 19 9m59 14l19 -20 -8 -29 -7 26 -20 9" fill="#a9a58a" stroke="#48564c" stroke-width="5"/>
<path d="M22 106l-8 -25 19 -35 32 -14 32 14 18 35 -8 25 -29 12H50Z" fill="#52686a" stroke="#233d45" stroke-width="6"/>
<path d="M25 51l13 -26 18 11 9 -24 12 23 19 -9 9 29 -18 1 -9 19 -20 -8 -14 11 -4 -19Z" fill="#7b927b"/>
<path d="M34 74l21 3m20 0l19 -4" stroke="#ffc879" stroke-width="7"/>
<path d="M46 96l18 -7 19 7 -19 10Z" fill="#233d45"/>
<path d="M23 85l6 13m69 -13l-6 13" stroke="#a7b28d" stroke-width="5"/>
<circle cx="65" cy="48" r="9" fill="#c9e5a4"/><circle cx="65" cy="48" r="4" fill="#f2f7c8"/>''')
    svg("gem", '''<path d="M64 13l34 43 -34 59 -34 -59Z" fill="#6edaca" stroke="#214d59" stroke-width="5"/><path d="M64 13l-8 43 8 59 12 -59Z" fill="#c6fff0"/><path d="M31 56h66" stroke="#8fecdc" stroke-width="3"/>''')
    svg("heal", '''<path d="M33 42h62l11 57q-39 20 -84 0Z" fill="#df92a4" stroke="#694957" stroke-width="5"/><path d="M46 21h35v22H46Z" fill="#ebc995" stroke="#694957" stroke-width="5"/><path d="M54 57h20v14h14v19H74v14H54V90H40V71h14Z" fill="#ffead8"/>''')
    svg("magnet", '''<path d="M23 18v54a41 41 0 0 0 82 0V18H78v54a14 14 0 0 1 -28 0V18Z" fill="#cf99e5" stroke="#5b4475" stroke-width="5"/><path d="M23 18h27v23H23m55 -23h27v23H78" fill="#ecdcf7"/><path d="M57 22l7 12 8 -12m-9 -9v7" stroke="#fff0b7" stroke-width="5"/>''')
    svg("bolt", '''<path d="M117 13L43 35l20 18 -52 62 76 -34 -22 -16Z" fill="#9cebd0" stroke="#397c79" stroke-width="4"/><path d="M97 32L63 58 31 96 73 67 61 54Z" fill="#edffdc"/>''')
    svg("orbit", '''<circle cx="64" cy="64" r="43" fill="none" stroke="#b8a2ed" stroke-width="7"/><circle cx="99" cy="37" r="17" fill="#eee0ff" stroke="#856cc1" stroke-width="4"/><path d="M61 45l7 13 14 5 -14 5 -7 15 -6 -15 -15 -5 15 -5Z" fill="#ddcff7"/>''')
    svg("pulse", '''<circle cx="64" cy="64" r="49" fill="none" stroke="#d9be77" stroke-width="4"/><circle cx="64" cy="64" r="35" fill="none" stroke="#f5daa1" stroke-width="7"/><path d="M64 40l7 16 17 8 -17 7 -7 17 -8 -17 -16 -7 16 -8Z" fill="#ffedbd"/>''')
    svg("title-emblem", '''<circle cx="64" cy="64" r="56" fill="#214643" stroke="#799781" stroke-width="1"/><circle cx="64" cy="64" r="47" fill="none" stroke="#597b68" stroke-width="1"/>
<path d="M35 102Q4 67 35 28m58 74q31 -35 0 -74M27 78l-12 -8 13 -1M26 59l-10 -14 15 4m0 -7l-1 -15 11 9m59 42l12 -8 -13 -1m2 -10l10 -14 -15 4m0 -7l1 -15 -11 9" fill="none" stroke="#91b492" stroke-width="3" stroke-linecap="round"/>
<path d="M52 46V32q0 -13 12 -13t12 13v14" fill="none" stroke="#e3bc79" stroke-width="5"/>
<path d="M43 48h42l-4 47 -17 9 -18 -9Z" fill="#d8aa65" stroke="#f4d9a2" stroke-width="2"/>
<path d="M51 55h26l-3 35 -10 6 -11 -6Z" fill="#2b5b54"/>
<path d="M64 58q19 21 0 30q-17 -7 0 -30" fill="#ffe4a0"/><path d="M64 70q9 11 0 15q-7 -4 0 -15" fill="#fffbe2"/>
<path d="M45 43h39m-40 59h41" stroke="#f4d9a2" stroke-width="4"/><circle cx="21" cy="95" r="2" fill="#f8d48e"/><circle cx="101" cy="20" r="2" fill="#f8d48e"/>''', 256)


def write_wave(name, channels):
    """固定ゲインで PCM16 音声を保存し、クリッピングがないことを検証する。"""
    peak = max(abs(sample) for channel in channels for sample in channel)
    assert peak < 0.95, (name, peak)
    pcm = array("h", (round(channels[c][i] * 32767)
                       for i in range(len(channels[0])) for c in range(len(channels))))
    with wave.open(str(ROOT / "audio" / f"{name}.wav"), "wb") as output:
        output.setnchannels(len(channels))
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    print(f"{name}.wav: {len(channels[0]) / RATE:.2f}秒 peak={peak:.4f}")


def make_audio():
    """独自の音列と正弦波で幻想的なループと控えめな操作音を生成する。"""
    (ROOT / "audio").mkdir(parents=True, exist_ok=True)
    duration = 24
    count = RATE * duration
    channels = [[0.0] * count, [0.0] * count]
    chords = [(45, 52, 57, 60), (41, 48, 53, 57), (48, 55, 60, 64), (43, 50, 55, 59)]
    melody = [69, 72, 76, 72, 69, 67, 65, 69, 72, 76, 79, 76, 74, 71, 67, 71]
    for i in range(count):
        t = i / RATE
        chord_t = t % 6
        # 各和音の両端を無音にしてループ境界で波形を連続にする。
        envelope = min(1.0, chord_t / 1.0, (6 - chord_t) / 1.5)
        chord = chords[int(t / 6)]
        pad = sum(math.sin(math.tau * (440 * 2 ** ((note - 69) / 12)) * t)
                  for note in chord) * 0.018 * envelope
        note_t = t % 1.5
        frequency = 440 * 2 ** ((melody[int(t / 1.5)] - 69) / 12)
        bell_env = math.sin(math.pi * min(note_t / 0.015, 0.5)) * math.exp(-note_t * 3.4)
        bell_env *= min(1, (1.5 - note_t) / 0.08)
        bell = (math.sin(math.tau * frequency * note_t)
                + 0.2 * math.sin(math.tau * frequency * 2 * note_t)) * 0.07 * bell_env
        pan = 0.75 + math.sin(t * math.tau / 24) * 0.2
        channels[0][i] = pad + bell * pan
        channels[1][i] = pad + bell * (1.5 - pan)
    write_wave("bgm", channels)
    for name, seconds, start, end in [("attack", .10, 800, 320), ("hurt", .22, 150, 60),
                                      ("pickup", .10, 1000, 1450), ("level", .65, 500, 900)]:
        samples = []
        for i in range(round(RATE * seconds)):
            t = i / RATE
            phase = math.tau * (start * t + (end - start) * t * t / (2 * seconds))
            env = math.sin(math.pi * t / seconds) ** 2
            sample = math.sin(phase) * env * 0.15
            if name == "level":
                sample += math.sin(phase * 1.5) * env * .06
            samples.append(sample)
        write_wave(name, [samples])


if __name__ == "__main__":
    make_art()
    make_audio()
