#!/usr/bin/env python3
"""燈火の巡礼の独自ベクター素材と音声を同一バイト列で再生成する。"""

from pathlib import Path
import math
import random
import struct
import wave


ROOT = Path(__file__).resolve().parents[2] / "assets"
GOLD = "#d3b778"
INK = "#101f25"
RUST = "#bb654c"


def svg(name, width, height, content):
    """同じ入力から同じ SVG を上書きして素材を同期する。"""
    path = ROOT / "art" / f"{name}.svg"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" '
        f'height="{height}" viewBox="0 0 {width} {height}">'
        '<defs><radialGradient id="glow"><stop stop-color="#edbd6a" '
        'stop-opacity=".42"/><stop offset="1" stop-color="#edbd6a" '
        'stop-opacity="0"/></radialGradient>'
        '<linearGradient id="cloth" x2=".85" y2="1">'
        '<stop stop-color="#497575"/><stop offset="1" stop-color="#132e36"/>'
        '</linearGradient></defs>' + content + '</svg>\n', encoding="utf-8"
    )


def make_background():
    rng = random.Random(31)
    content = '<rect width="1280" height="720" fill="#0d1c22"/>'
    content += '<ellipse cx="858" cy="299" rx="380" ry="350" fill="url(#glow)" opacity=".25"/>'
    content += '<circle cx="880" cy="184" r="99" fill="none" stroke="#8b8762" stroke-width="1" opacity=".33"/>'
    content += '<circle cx="880" cy="184" r="85" fill="none" stroke="#8b8762" stroke-width="1" opacity=".22"/>'
    content += '<path d="M0 406L120 296L219 351L390 220L510 355L629 277L760 344L938 251L1090 350L1190 250L1280 320V720H0Z" fill="#163037"/>'
    content += '<path d="M0 479L91 393L217 460L340 352L490 468L644 382L795 460L916 354L1113 428L1280 345V720H0Z" fill="#12282f"/>'
    for x in [60, 213, 1080, 1200]:
        content += f'<path d="M{x} 610V108L{x+26} 67L{x+52} 108V610M{x-12} 126H{x+64}M{x+12} 104V573M{x+40} 104V573" fill="#0b181f" stroke="#456060" stroke-width="1" opacity=".65"/>'
    content += '<path d="M543 720L714 395L765 395L841 720" fill="#253537" opacity=".7"/>'
    content += '<path d="M585 720L724 423M797 720L754 423" stroke="#8d8465" opacity=".27"/>'
    for _ in range(130):
        x, y = rng.randrange(1280), rng.randrange(50, 660)
        radius = rng.choice([.6, .8, 1.2, 1.7])
        content += f'<circle cx="{x}" cy="{y}" r="{radius}" fill="#d3b778" opacity="{rng.uniform(.08, .42):.2f}"/>'
    for y in range(565, 720, 26):
        content += f'<path d="M0 {y}Q320 {y-20} 640 {y+4}T1280 {y}" fill="none" stroke="#6a7664" stroke-width=".5" opacity=".11"/>'
    content += '<path d="M28 100V28H128M1152 28H1252V100M28 620V692H128M1152 692H1252V620" fill="none" stroke="#a58d5f" opacity=".48"/>'
    svg("background", 1280, 720, content)


def make_characters():
    shadow = '<ellipse cx="160" cy="374" rx="101" ry="15" fill="#030e15" opacity=".48"/>'
    hero = shadow + '''<circle cx="155" cy="176" r="119" fill="url(#glow)" opacity=".28"/>
    <path d="M106 162Q69 253 77 357L126 345L152 362L184 345L230 358Q220 252 187 161Z" fill="url(#cloth)" stroke="#c0ab77" stroke-width="2"/>
    <path d="M117 350L112 373H139L150 326M177 345L179 374H208L192 330" fill="#0a1720" stroke="#8a8e76"/>
    <path d="M114 168Q94 119 115 84Q143 53 167 64Q207 84 203 123L183 168L161 155Z" fill="#35545a" stroke="#cbb784" stroke-width="2"/>
    <path d="M128 111Q157 88 185 111L171 149L147 154Z" fill="#0c2027"/>
    <path d="M137 128L145 128M164 128H171" stroke="#e4c88d" stroke-width="2"/>
    <path d="M108 176L164 194L198 163L208 190L161 225L98 200Z" fill="#af634c" stroke="#d5a27a"/>
    <path d="M105 216L142 240L120 279L95 254M194 211L224 245L245 215" fill="none" stroke="#658480" stroke-width="18"/>
    <path d="M122 222L111 332M155 232L148 343M184 216L207 341" stroke="#aac3a8" fill="none" opacity=".4"/>
    <path d="M88 350Q155 330 221 350" fill="none" stroke="#d4b475" stroke-width="2"/>
    <circle cx="246" cy="246" r="62" fill="url(#glow)"/>
    <path d="M235 219V205Q246 188 257 205V219M231 219H261L257 260H235Z" fill="#1c3031" stroke="#d9b878" stroke-width="3"/>
    <path d="M240 226H253V252H240Z" fill="#ebbf6d"/>
    <path d="M244 248Q238 238 247 230Q257 242 244 248Z" fill="#fff0bc"/>
    <path d="M229 263H263" stroke="#dbbd7d" stroke-width="3"/>
    <path d="M92 206Q80 265 61 310" stroke="#bd9d61" stroke-width="3" fill="none"/>'''
    svg("hero", 320, 400, hero)
    moth = shadow + '''<ellipse cx="160" cy="199" rx="123" ry="123" fill="url(#glow)" opacity=".16"/>
    <path d="M150 188Q49 42 22 130Q11 216 131 237Q35 239 47 303Q78 347 151 256M170 188Q271 42 298 130Q309 216 189 237Q285 239 273 303Q242 347 169 256" fill="#9d684f" stroke="#d6b682" stroke-width="2"/>
    <path d="M143 195L39 139L90 190L38 196L139 225M177 195L281 139L230 190L282 196L181 225M140 251L72 295M180 251L248 295" stroke="#edcc98" fill="none" opacity=".65"/>
    <path d="M160 159Q134 201 153 277L160 300L167 277Q186 201 160 159Z" fill="#263f45" stroke="#dfc78d" stroke-width="2"/>
    <path d="M152 176Q134 118 115 119M168 176Q186 118 205 119" stroke="#dfc78d" fill="none" stroke-width="2"/>
    <ellipse cx="81" cy="169" rx="16" ry="24" fill="#293f43" stroke="#debd86"/>
    <ellipse cx="239" cy="169" rx="16" ry="24" fill="#293f43" stroke="#debd86"/>
    <circle cx="81" cy="169" r="7" fill="#e2ae68"/><circle cx="239" cy="169" r="7" fill="#e2ae68"/>'''
    svg("enemy_moth", 320, 400, moth)
    sentinel = shadow + '''<path d="M98 216L83 345L135 353L161 320L184 353L232 347L215 212Z" fill="#36515a" stroke="#a09f83" stroke-width="2"/>
    <path d="M100 210L80 151L113 129L201 129L240 162L216 215L183 198L141 217Z" fill="#627575" stroke="#b8b490" stroke-width="2"/>
    <path d="M120 136L116 91L139 65L188 75L205 116L187 146L151 159Z" fill="#53686b" stroke="#b5b18d" stroke-width="2"/>
    <path d="M137 113L150 120L181 112" stroke="#efbf72" stroke-width="6" fill="none"/>
    <path d="M155 73L150 99L170 107L160 135L181 151M107 155L145 187L129 214M201 163L177 192L200 236L178 265L198 301" stroke="#112e36" fill="none" stroke-width="4"/>
    <path d="M80 164L59 268L91 283L116 202M220 177L245 275L216 289L193 208" fill="#465e63" stroke="#a7a889" stroke-width="2"/>
    <path d="M75 282L63 368M65 290L83 289" stroke="#b6a16f" stroke-width="8"/>
    <path d="M128 232L155 244L182 228L183 275L155 291L129 276Z" fill="#283f49" stroke="#b9a574"/>
    <circle cx="156" cy="257" r="11" fill="#dcab68"/>'''
    svg("enemy_sentinel", 320, 400, sentinel)
    wisp = shadow + '''<circle cx="160" cy="204" r="142" fill="url(#glow)" opacity=".4"/>
    <path d="M162 71Q237 144 194 200Q254 245 215 305Q252 292 264 260Q264 359 161 353Q58 357 67 284Q93 316 111 301Q53 233 119 177Q96 136 162 71Z" fill="#406c6b" stroke="#b7c0a0" stroke-width="2"/>
    <path d="M167 106Q124 177 155 194Q89 231 123 279Q140 305 160 322Q199 282 194 253Q147 221 176 184Q202 147 167 106Z" fill="#bdd0ab" opacity=".8"/>
    <path d="M134 222L148 226M169 226L183 220" fill="none" stroke="#152d36" stroke-width="5"/>
    <path d="M116 173Q79 133 106 92M218 210Q260 175 239 123" fill="none" stroke="#b7c0a0" stroke-width="2" opacity=".6"/>
    <circle cx="99" cy="77" r="5" fill="#d9c69a"/><circle cx="244" cy="103" r="3" fill="#d9c69a"/>'''
    svg("enemy_wisp", 320, 400, wisp)
    boss = shadow + '''<circle cx="160" cy="157" r="126" fill="url(#glow)" opacity=".37"/>
    <circle cx="160" cy="157" r="103" stroke="#ba965b" fill="none" stroke-width="2"/>
    <path d="M156 14V42M59 52L80 72M16 149H48M261 53L242 74M274 149H306" stroke="#ba965b" stroke-width="3"/>
    <path d="M109 151L41 350L106 332L157 369L213 335L281 350L210 151Z" fill="#743f39" stroke="#c4a777" stroke-width="2"/>
    <path d="M122 166L91 320L160 349L224 316L196 166Z" fill="#263f48" stroke="#baaa80" stroke-width="2"/>
    <path d="M124 154L103 85L117 49L132 88L155 50L175 87L200 50L216 86L197 154L159 172Z" fill="#c1a86f" stroke="#e2c891" stroke-width="2"/>
    <path d="M124 108L155 121L193 109L184 148L159 158L137 147Z" fill="#0e232d"/>
    <path d="M139 129L150 133M169 133L181 128" stroke="#f2c274" stroke-width="4"/>
    <path d="M109 181L76 264L44 244M209 181L248 252L280 225" stroke="#627577" stroke-width="17" fill="none"/>
    <path d="M155 181V317M130 209L181 209M123 243H191M115 279H203" stroke="#b4a277" opacity=".6"/>
    <path d="M43 214V348M28 218L44 184L59 218L44 238Z" fill="#d2b775" stroke="#efd296" stroke-width="2"/>
    <circle cx="277" cy="213" r="44" fill="url(#glow)"/>
    <path d="M278 172Q301 201 279 220Q256 205 278 172Z" fill="#e8b965"/>
    <path d="M77 341L107 308M214 313L244 342" stroke="#dfb384" stroke-width="3"/>'''
    svg("boss", 320, 400, boss)


def make_ui():
    symbols = {
        "attack": '<path d="M19 45L45 12L48 26L25 48M16 36L31 48M16 48L12 53" fill="none" stroke="currentColor" stroke-width="4"/>',
        "block": '<path d="M14 15L32 9L50 15V32Q49 45 32 55Q15 45 14 32Z" fill="none" stroke="currentColor" stroke-width="3"/><path d="M32 17V44M23 29H41" stroke="currentColor" stroke-width="2"/>',
        "energy": '<path d="M36 5L15 35H30L26 59L50 27H35Z" fill="none" stroke="currentColor" stroke-width="3"/>',
        "relic": '<path d="M20 22H44L42 50H22ZM24 20V12Q32 3 40 12V20M18 54H46" fill="none" stroke="currentColor" stroke-width="3"/><path d="M33 27Q20 40 33 44Q44 39 33 27Z" fill="currentColor"/>',
    }
    for name, shape in symbols.items():
        svg("icon_" + name, 64, 64, f'<g color="{GOLD}">{shape}</g>')
    for name, color, icon in [("attack", RUST, "attack"), ("block", "#477673", "block"), ("skill", "#8d794c", "energy")]:
        content = f'<rect x="3" y="3" width="234" height="314" rx="12" fill="#182b31" stroke="{GOLD}" stroke-width="2"/>'
        content += f'<rect x="11" y="11" width="218" height="298" rx="7" fill="none" stroke="{color}"/>'
        content += f'<path d="M13 42H227V164H13Z" fill="{color}" opacity=".3"/>'
        content += '<circle cx="120" cy="101" r="46" fill="none" stroke="#c4aa72" opacity=".45"/>'
        content += f'<g color="{GOLD}" transform="translate(88 69)">{symbols[icon]}</g>'
        content += '<path d="M26 174H214M26 275H214" stroke="#baa171" opacity=".45"/>'
        content += '<path d="M17 31V17H31M209 17H223V31M17 289V303H31M209 303H223V289" fill="none" stroke="#d3b778"/>'
        svg("card_" + name, 240, 320, content)


def write_wav(name, samples, rate=22050):
    path = ROOT / "audio" / f"{name}.wav"
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = max(1.0, max(abs(value) for value in samples))
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(rate)
        output.writeframes(b"".join(struct.pack("<h", int(value / peak * 26000)) for value in samples))


def make_music(name, bpm, melody, bass, percussion):
    rate = 22050
    beat = 60.0 / bpm
    duration = beat * 32
    samples = [0.0] * round(duration * rate)
    for index, midi in enumerate(melody * 2):
        start = index * beat
        frequency = 440 * 2 ** ((midi - 69) / 12)
        for step in range(round(beat * 1.8 * rate)):
            t = step / rate
            envelope = min(t / .014, 1) * math.exp(-t * 3.6)
            tone = math.sin(2 * math.pi * frequency * t) + .25 * math.sin(4 * math.pi * frequency * t)
            samples[(round(start * rate) + step) % len(samples)] += tone * envelope * .18
    for index in range(8):
        frequency = 440 * 2 ** ((bass[index % len(bass)] - 69) / 12)
        for step in range(round(beat * 4 * rate)):
            t = step / rate
            envelope = math.sin(math.pi * t / (beat * 4)) ** 2
            value = sum(math.sin(2 * math.pi * frequency * ratio * t) / (n + 2) for n, ratio in enumerate([1, 1.5, 2]))
            samples[(round(index * beat * 4 * rate) + step) % len(samples)] += value * envelope * .17
    if percussion:
        rng = random.Random(22)
        for index in range(32):
            for step in range(int(rate * .14)):
                t = step / rate
                value = math.sin(2 * math.pi * (73 * t - 110 * t * t)) * math.exp(-t * 29)
                value += rng.uniform(-1, 1) * math.exp(-t * 67) * .14
                samples[(round(index * beat * rate) + step) % len(samples)] += value * percussion
    write_wav(name, samples)


def make_audio():
    make_music("map", 96, [69, 76, 72, 76, 67, 74, 71, 74, 65, 72, 69, 72, 67, 71, 74, 71], [45, 43, 41, 43], 0)
    make_music("battle", 128, [69, 72, 76, 72, 69, 77, 76, 72, 67, 71, 74, 71, 68, 71, 76, 71], [45, 45, 43, 44], .17)
    make_music("boss", 144, [57, 64, 69, 70, 69, 64, 60, 64, 56, 63, 68, 69, 68, 63, 59, 63], [33, 33, 32, 32], .26)
    rate = 22050
    rng = random.Random(7)
    effects = {
        "card": [.2 * rng.uniform(-1, 1) * math.exp(-i / rate * 30) + .12 * math.sin(2 * math.pi * 880 * i / rate) * math.exp(-i / rate * 24) for i in range(int(rate * .18))],
        "attack": [(.42 * rng.uniform(-1, 1) + .35 * math.sin(2 * math.pi * 95 * i / rate)) * math.exp(-i / rate * 18) for i in range(int(rate * .32))],
        "block": [(math.sin(2 * math.pi * 740 * i / rate) * .18 + math.sin(2 * math.pi * 1120 * i / rate) * .13) * math.exp(-i / rate * 12) for i in range(int(rate * .4))],
    }
    for name, samples in effects.items():
        write_wav(name, samples)


if __name__ == "__main__":
    make_background()
    make_characters()
    make_ui()
    make_audio()
    print("独自 SVG 13点、BGM 3曲、効果音 3点を生成しました。")
