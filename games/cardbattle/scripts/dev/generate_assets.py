#!/usr/bin/env python3
"""同じ入力から同じ SVG・PCM 音声を作る、外部依存のない素材生成器。"""

from array import array
import math
from pathlib import Path
import random
import wave


ASSETS = Path(__file__).resolve().parents[2] / "assets"
RATE = 22050
TAU = math.tau


def svg_document(width, height, body):
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" '
            f'height="{height}" viewBox="0 0 {width} {height}">{body}</svg>\n')
    return '\n'.join(line.rstrip() for line in svg.splitlines()) + '\n'


def star_field(width, height, count, seed):
    rng = random.Random(seed)
    return "".join(
        f'<circle cx="{rng.randrange(width)}" cy="{rng.randrange(height)}" '
        f'r="{rng.choice([0.6, 0.9, 1.3, 1.8])}" fill="#d1e2df" '
        f'opacity="{rng.uniform(0.14, 0.6):.2f}"/>' for _ in range(count)
    )


def illustrations():
    art = ASSETS / "art"
    art.mkdir(parents=True, exist_ok=True)
    arena = '''<defs>
      <radialGradient id="sky"><stop stop-color="#173747"/>
      <stop offset="1" stop-color="#06101c"/></radialGradient>
      <linearGradient id="floor" x2="0" y2="1">
      <stop stop-color="#142c36"/><stop offset="1" stop-color="#07111f"/>
      </linearGradient></defs>
      <path fill="url(#sky)" d="M0 0h1600v900H0z"/>
      <circle cx="800" cy="320" r="280" fill="none" stroke="#d1b780" opacity=".08"/>
      <circle cx="800" cy="320" r="248" fill="none" stroke="#83d7cb" opacity=".09"/>
      <path d="M800 40L1042 460H558Z M800 600L558 180H1042Z"
      fill="none" stroke="#83d7cb" opacity=".045"/>
      <path d="M0 655L330 620 555 658 800 625 1030 658 1240 620 1600 655V900H0Z"
      fill="url(#floor)"/>
      <ellipse cx="800" cy="773" rx="640" ry="175" fill="none" stroke="#85b1a5" opacity=".065"/>
      <ellipse cx="800" cy="773" rx="580" ry="145" fill="none" stroke="#d1b780" opacity=".075"/>
      <path d="M0 855L800 666 1600 855M400 900L800 666 1200 900"
      fill="none" stroke="#78b9ae" opacity=".045"/>'''
    (art / "arena.svg").write_text(svg_document(1600, 900, arena + star_field(1600, 680, 145, 19)))
    portraits = {
        "fire": ("#eb886c", "#572c3b", '''
          <path d="M155 42C198 76 167 98 213 115C217 82 202 69 210 48
          C268 112 262 167 215 204L119 211C70 184 64 140 105 104
          C98 143 135 144 130 109C127 86 145 74 155 42Z" fill="#713d44"/>
          <path d="M157 74L180 109 168 135 196 183 155 219 111 179
          142 133 129 110Z" fill="#eda777"/>
          <path d="M157 107L168 126 158 143 176 176 156 197 133 177
          151 146 144 127Z" fill="#ffe6ac"/>
          <path d="M75 193L100 175M228 171L249 188M107 58L116 80M239 97L228 117"
          stroke="#ffd397" stroke-width="2"/>
        '''),
        "water": ("#78bdea", "#233f64", '''
          <path d="M55 178Q117 126 160 168T278 154Q253 205 159 207T55 178Z"
          fill="#336b89"/>
          <path d="M77 155Q122 123 153 151T252 154M59 179Q121 149 166 179T273 177"
          fill="none" stroke="#82cde0" stroke-width="2"/>
          <path d="M162 45C151 77 111 105 111 138A50 50 0 0 0 211 138
          C211 105 174 77 162 45Z" fill="#70b6d0"/>
          <path d="M161 65L161 176Q109 163 128 126Z" fill="#a9e3e2"/>
          <path d="M162 86L184 135 161 161 143 136Z" fill="#24485f"/>
          <circle cx="163" cy="134" r="8" fill="#d7f2e7"/>
          <path d="M81 77v12m-6-6h12M244 101v12m-6-6h12" stroke="#b8e6e5"/>
        '''),
        "wind": ("#71d5bb", "#224c48", '''
          <path d="M72 92Q148 148 259 64Q215 143 169 160Q120 179 78 146
          Q125 158 149 141Q100 138 72 92Z" fill="#70bea8"/>
          <path d="M153 140Q181 98 177 51Q197 79 191 106Q220 102 254 75
          Q215 127 153 140Z" fill="#c7edcd"/>
          <path d="M171 116L150 132 135 119 151 115 161 98Z" fill="#e4ecd0"/>
          <path d="M158 128Q124 175 79 189M166 144Q211 149 242 130
          M56 155Q105 208 195 183Q245 168 265 187M98 201Q184 220 229 196"
          fill="none" stroke="#8ad4b6" stroke-width="2"/>
          <path d="M92 67l5 11 12 2-12 4-5 11-4-11-11-4 11-2Z" fill="#c0ddad"/>
        '''),
        "earth": ("#c7a171", "#45423f", '''
          <path d="M62 202L108 140 144 147 170 97 216 145 258 202Z" fill="#746850"/>
          <path d="M118 123L139 62 180 45 210 114 193 183 148 198Z" fill="#c5ae7a"/>
          <path d="M139 62L157 124 180 45 183 122 210 114 193 183 157 124
          148 198 118 123 157 124Z" fill="#8c8366"/>
          <path d="M157 124L180 45 183 122 193 183Z" fill="#d8c697"/>
          <path d="M74 170L91 133 105 163 96 189ZM223 182L238 148 252 181 242 205Z"
          fill="#b3a178"/>
          <ellipse cx="164" cy="207" rx="114" ry="12" fill="none" stroke="#b8aa7e"/>
          <path d="M111 83h12m-6-6v12M229 88h12m-6-6v12" stroke="#d8c697"/>
        '''),
    }
    for element, (color, shadow, shape) in portraits.items():
        body = f'''<defs><radialGradient id="a"><stop stop-color="{shadow}"/>
          <stop offset="1" stop-color="#102130"/></radialGradient></defs>
          <path d="M0 0h320v240H0z" fill="url(#a)"/>
          <circle cx="160" cy="125" r="88" fill="none" stroke="{color}" opacity=".2"/>
          <circle cx="160" cy="125" r="102" fill="none" stroke="{color}" opacity=".09"/>
          <path d="M160 19L252 178H68Z" fill="none" stroke="{color}" opacity=".12"/>
          {star_field(320, 230, 28, 21)}{shape}
          <path d="M12 40V12H40M280 12H308V40M12 200V228H40M280 228H308V200"
          fill="none" stroke="{color}" opacity=".4"/>'''
        (art / f"{element}.svg").write_text(svg_document(320, 240, body))
    back = '''<rect width="240" height="340" rx="16" fill="#0c2030"/>
      <rect x="9" y="9" width="222" height="322" rx="12" fill="none" stroke="#b59a63"/>
      <rect x="16" y="16" width="208" height="308" rx="9" fill="none" stroke="#35544e"/>
      <circle cx="120" cy="170" r="73" fill="none" stroke="#567f72"/>
      <circle cx="120" cy="170" r="63" fill="none" stroke="#b59a63"/>
      <path d="M120 89L190 210H50ZM120 251L50 130H190Z" fill="none" stroke="#7db5a2"/>
      <path d="M120 132L151 170 120 209 89 170Z" fill="#17392f" stroke="#dfbc72"/>
      <circle cx="120" cy="170" r="11" fill="#dfbc72"/>
      <path d="M120 43v29m-8-14h16M120 268v29m-8-14h16" stroke="#b59a63"/>'''
    (art / "card_back.svg").write_text(svg_document(240, 340, back))


def tone(duration, frequency, volume=0.2, release=3.0):
    return [volume * min(1.0, t / 0.018) * math.exp(-release * t / duration)
            * min(1.0, (duration - t) / 0.035)
            * (math.sin(TAU * frequency * t) + 0.13 * math.sin(TAU * frequency * 2 * t))
            for t in (i / RATE for i in range(round(duration * RATE)))]


def mix_note(buffer, samples, start, wrap=False):
    # 複数音を重ねる合成処理なので加算は非冪等。完成品の生成全体は毎回空の波形から行う。
    offset = round(start * RATE)
    for index, value in enumerate(samples):
        if wrap or offset + index < len(buffer):
            buffer[(offset + index) % len(buffer)] += value


def write_wave(name, samples):
    peak = max(abs(value) for value in samples)
    gain = min(1, 0.8 / peak) if peak else 1
    pcm = array("h", (round(value * gain * 32767) for value in samples))
    with wave.open(str(ASSETS / "audio" / f"{name}.wav"), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    print(f"{name}: {len(samples) / RATE:.2f} 秒、最大振幅 {peak * gain:.3f}")


def audio_assets():
    (ASSETS / "audio").mkdir(parents=True, exist_ok=True)
    music = [0.0] * (16 * RATE)
    # 末尾を先頭に折り返して残響を重ね、ループ境界の波形と音量を連続にする。
    chords = [(57, 60, 64), (53, 57, 60), (48, 55, 60), (55, 59, 62)]
    for bar in range(8):
        chord = chords[bar % 4]
        for note in chord:
            mix_note(music, tone(2.7, 440 * 2 ** ((note - 69) / 12), .048, 1.7), bar * 2, True)
        for beat in range(4):
            note = chord[(beat + bar) % 3] + 12
            mix_note(music, tone(1.15, 440 * 2 ** ((note - 69) / 12), .045), bar * 2 + beat * .5, True)
    write_wave("bgm", music)
    for name, notes, spacing, duration in [
        ("draw", [659, 880], .055, .22),
        ("summon", [330, 440, 659], .08, .5),
        ("attack", [220, 165, 110], .035, .23),
        ("destroy", [330, 247, 165, 82], .075, .4),
        ("damage", [130, 98], .06, .28),
        ("victory", [440, 554, 659, 880, 1109], .15, .95),
    ]:
        samples = [0.0] * round((duration + len(notes) * spacing) * RATE)
        for step, note in enumerate(notes):
            mix_note(samples, tone(duration, note, .26), step * spacing)
        write_wave(name, samples)


if __name__ == "__main__":
    illustrations()
    audio_assets()
