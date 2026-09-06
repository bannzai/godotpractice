"""星つむぎの独自 SVG・音声を決定的に再生成する。フォントのみ既存 OFL 素材。"""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets/art"
AUDIO = ROOT / "assets/audio"


def svg(content, width=128, height=128):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">{content}</svg>'


def save(name, content, width=128, height=128):
    (ART / f"{name}.svg").write_text(svg(content, width, height))


def star(x, y, radius, color, arms=4):
    points = []
    for i in range(arms * 2):
        a = math.pi * i / arms - math.pi / 2
        r = radius if i % 2 == 0 else radius * 0.33
        points.append(f"{x + math.cos(a)*r:.2f},{y + math.sin(a)*r:.2f}")
    return f'<polygon points="{" ".join(points)}" fill="{color}"/>'


def pieces():
    designs = [
        ("#ffccb0", "#f48282", "#933e76", 'M26 46 Q17 18 42 32 Q64 18 85 32 Q110 19 103 47 Q120 74 100 99 Q63 122 28 99 Q8 76 26 46Z', '<path d="M37 35 Q36 20 46 14 L57 28 M72 27 Q80 12 86 18 L90 37" fill="#ffe7af" stroke="#965071" stroke-width="3"/><path d="M28 83 Q11 74 15 62 M100 83 Q119 73 114 60" fill="none" stroke="#ffc9bd" stroke-width="6"/>'),
        ("#d3ffe1", "#64d7b9", "#267d88", 'M64 21 C105 23 116 61 102 90 C89 116 35 117 22 87 C6 54 27 29 64 21Z', '<path d="M64 28 Q34 -1 29 14 Q32 36 64 35 Q87 1 103 16 Q99 38 65 39" fill="#8be4a1" stroke="#3d927d" stroke-width="3"/><path d="M39 104 Q24 118 21 103 M87 104 Q106 120 109 103" fill="none" stroke="#71dabc" stroke-width="6"/>'),
        ("#fff3b8", "#f1bd57", "#b57749", 'M64 11 L81 34 L109 29 L104 57 L122 77 L96 90 L92 117 L65 107 L40 119 L33 92 L8 80 L24 59 L18 33 L46 35Z', '<circle cx="64" cy="67" r="29" fill="none" stroke="#fff0a6" stroke-width="2" opacity=".65"/>' + star(102, 18, 10, "#fff4be")),
        ("#eedbff", "#b09be5", "#62579d", 'M65 8 C76 28 111 47 109 77 C107 107 78 120 50 110 C-1 94 18 44 45 31 Q57 25 65 8Z', '<path d="M75 21 Q111 22 113 42 Q93 44 83 33" fill="#d5baff" stroke="#8671b9" stroke-width="2"/><path d="M35 91 Q21 98 18 88" fill="none" stroke="#d8c6fc" stroke-width="6"/>'),
        ("#b8c4d3", "#66788e", "#38485e", 'M49 14 L76 14 L80 25 L92 32 L105 29 L118 51 L110 62 L110 73 L120 83 L107 106 L93 103 L82 111 L78 123 L51 123 L47 110 L35 104 L22 108 L8 85 L17 73 L17 61 L8 51 L20 29 L34 32 L45 25Z', '<circle cx="64" cy="69" r="36" fill="#253e54" stroke="#c1cbce" stroke-width="4"/><circle cx="64" cy="69" r="27" fill="#76899a"/>'),
    ]
    for i, (light, base, dark, body, ornaments) in enumerate(designs, 1):
        content = f'<defs><linearGradient id="body" x2=".25" y2="1"><stop stop-color="{light}"/><stop offset=".55" stop-color="{base}"/><stop offset="1" stop-color="{dark}"/></linearGradient></defs>'
        content += '<ellipse cx="64" cy="115" rx="37" ry="7" fill="#061c31" opacity=".4"/>'
        content += f'<path d="{body}" fill="url(#body)" stroke="{dark}" stroke-width="3" stroke-linejoin="round"/>{ornaments}'
        content += '<path d="M34 48 Q43 34 54 34" fill="none" stroke="#fff" stroke-opacity=".6" stroke-width="5" stroke-linecap="round"/>' if i != 5 else ''
        content += '<ellipse cx="47" cy="66" rx="5" ry="8" fill="#293849"/><ellipse cx="81" cy="66" rx="5" ry="8" fill="#293849"/><circle cx="48" cy="63" r="1.8" fill="#fff"/><circle cx="82" cy="63" r="1.8" fill="#fff"/>'
        content += '<path d="M55 82 Q64 90 73 82" fill="none" stroke="#493d60" stroke-width="3" stroke-linecap="round"/>' if i != 5 else '<path d="M55 88 L63 83 L74 87" fill="none" stroke="#293849" stroke-width="3"/>'
        content += '<ellipse cx="34" cy="80" rx="7" ry="3" fill="#e18c9b" opacity=".5"/><ellipse cx="94" cy="80" rx="7" ry="3" fill="#e18c9b" opacity=".5"/>' if i != 5 else ''
        save(f"piece_{i}", content)


def backgrounds():
    rng = random.Random(42)
    sky = '<defs><linearGradient id="sky" x2=".2" y2="1"><stop stop-color="#090f27"/><stop offset=".55" stop-color="#142e49"/><stop offset="1" stop-color="#36575d"/></linearGradient><radialGradient id="haze"><stop stop-color="#729ca0" stop-opacity=".35"/><stop offset="1" stop-color="#729ca0" stop-opacity="0"/></radialGradient></defs><path d="M0 0H1280V720H0Z" fill="url(#sky)"/><ellipse cx="810" cy="285" rx="500" ry="320" fill="url(#haze)"/>'
    for _ in range(150):
        x, y = rng.randrange(1280), rng.randrange(650)
        sky += f'<circle cx="{x}" cy="{y}" r="{rng.choice([.6,.8,1,1.5])}" fill="#d6e5d2" opacity="{rng.uniform(.2,.8):.2f}"/>'
    sky += '<circle cx="1020" cy="136" r="56" fill="#c7d7be"/><circle cx="1040" cy="117" r="55" fill="#19354b"/>'
    save("sky", sky, 1280, 720)
    glass = '<g fill="none" stroke="#72958e" stroke-opacity=".22" stroke-width="3">'
    for x in [-160, 160, 480, 800, 1120]:
        glass += f'<path d="M{x} 720V320 Q{x} 90 {x+160} 14 Q{x+320} 90 {x+320} 320V720 M{x+160} 14V720 M{x} 300H{x+320} M{x} 510H{x+320}"/>'
    glass += '</g><path d="M0 615 Q250 571 450 622 T850 615 T1280 610 V720H0Z" fill="#142c39" opacity=".65"/>'
    save("greenhouse", glass, 1280, 720)
    leaf = ''
    for mirror in [False, True]:
        leaf += '<g transform="translate(1280 0) scale(-1 1)">' if mirror else '<g>'
        for j in range(7):
            x = 12 + j * 27
            h = 130 + (j % 3) * 45
            leaf += f'<path d="M{x} 740 Q{x+35} {720-h} {x-4} {680-h}" fill="none" stroke="#36706b" stroke-width="4"/>'
            for k in range(4):
                y = 684 - k * h / 5
                leaf += f'<path d="M{x+15} {y} Q{x-42} {y-9} {x-24} {y-48} Q{x+12} {y-43} {x+15} {y} M{x+16} {y-15} Q{x+56} {y-78} {x+74} {y-52} Q{x+65} {y-11} {x+16} {y-15}" fill="{["#183c45", "#225153", "#2d6260"][j%3]}" stroke="#497b6b" stroke-width="1"/>'
        leaf += '</g>'
    save("foliage", leaf, 1280, 720)
    panel = '<defs><linearGradient id="p" x2=".2" y2="1"><stop stop-color="#1c3849"/><stop offset="1" stop-color="#0d202f"/></linearGradient></defs><rect x="2" y="2" width="396" height="496" rx="22" fill="url(#p)" stroke="#6b9390" stroke-width="2"/><rect x="9" y="9" width="382" height="482" rx="17" fill="none" stroke="#acc3a3" stroke-opacity=".17"/><path d="M25 28H104 M296 28H375" stroke="#baa974" stroke-width="2"/>'
    save("panel", panel, 400, 500)


def title_art():
    art = '<defs><radialGradient id="a"><stop stop-color="#82b5a0" stop-opacity=".24"/><stop offset="1" stop-color="#82b5a0" stop-opacity="0"/></radialGradient></defs><circle cx="360" cy="350" r="325" fill="url(#a)"/><g fill="none" stroke="#b7c4a0"><circle cx="360" cy="350" r="249" opacity=".3"/><circle cx="360" cy="350" r="261" opacity=".13"/><ellipse cx="360" cy="350" rx="270" ry="94" transform="rotate(-25 360 350)" opacity=".45"/><ellipse cx="360" cy="350" rx="270" ry="94" transform="rotate(30 360 350)" opacity=".2"/></g>'
    for i, (x, y, scale, rot) in enumerate([(284, 186, 1.65, -8), (400, 338, 1.5, 10), (150, 369, 1.4, -12), (424, 122, 1.15, 8)], 1):
        src = (ART / f"piece_{i}.svg").read_text().split('>', 1)[1].rsplit('</svg>', 1)[0].replace('id="body"', f'id="body{i}"').replace('url(#body)', f'url(#body{i})')
        art += f'<g transform="translate({x} {y}) rotate({rot} 64 64) scale({scale})">{src}</g>'
    for x, y, r in [(149,192,12),(508,546,16),(184,540,10),(565,281,13),(303,105,8),(336,551,7)]:
        art += star(x,y,r,"#e0d39d")
    save("keyart", art, 720, 720)
    from fontTools.ttLib import TTFont
    from fontTools.pens.svgPathPen import SVGPathPen
    from fontTools.varLib.instancer import instantiateVariableFont
    font = TTFont(ROOT / "assets/fonts/NotoSansJP.ttf")
    if "fvar" in font:
        font = instantiateVariableFont(font, {"wght": 600}, inplace=True)
    glyphs, cmap = font.getGlyphSet(), font.getBestCmap()
    logo = '<defs><linearGradient id="l" x2="0" y2="1"><stop stop-color="#f9efd1"/><stop offset="1" stop-color="#bda775"/></linearGradient></defs>'
    for index, char in enumerate("星つむぎ"):
        pen = SVGPathPen(glyphs)
        glyphs[cmap[ord(char)]].draw(pen)
        logo += f'<path d="{pen.getCommands()}" transform="translate({158+index*106} 125) scale(.098 -.098)" fill="url(#l)"/>'
    logo += star(92, 76, 31, '#e6d6a2') + '<circle cx="92" cy="76" r="40" fill="none" stroke="#b1c7b3" opacity=".6"/>'
    logo += '<path d="M176 152H542" fill="none" stroke="#a9bdae" opacity=".35"/>'
    save("logo", logo, 720, 180)


RATE = 22050


def add_note(buffer, start, duration, midi, volume=.2, timbre="bell", loop=False):
    frequency = 440 * 2 ** ((midi - 69) / 12)
    for n in range(int(duration * RATE)):
        t = n / RATE
        envelope = min(t / .012, 1) * math.exp(-t * (4 if timbre == "bell" else 2.2)) * min((duration-t)/.04,1)
        phase = 2 * math.pi * frequency * t
        if timbre == "bell":
            value = math.sin(phase + 1.5 * math.sin(phase * 2.01) * math.exp(-t*7)) + .22 * math.sin(phase*3.997)*math.exp(-t*10)
        else:
            value = .62*math.sin(phase) + .2*math.sin(phase*2) + .13*math.sin(phase*3) + .05*math.sin(phase*5)
        at = int(start * RATE) + n
        if loop:
            at %= len(buffer)
        if at < len(buffer):
            buffer[at] += volume * envelope * value


def wav(name, buffer):
    peak = max(1., max(abs(v) for v in buffer) / .92)
    pcm = b''.join(struct.pack('<h', round(max(-1,min(1,v/peak))*32767)) for v in buffer)
    with wave.open(str(AUDIO / f"{name}.wav"), 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(pcm)


def sounds():
    for scene, beat, notes, bass in [
        ("title", .45, [76,79,83,86,83,79,74,79,81,83,86,88,86,83,79,74], [52,55,48,50]),
        ("play", .32, [76,79,83,79,86,83,79,74,72,76,79,83,81,78,74,78], [52,48,55,50]),
        ("danger", .24, [76,77,83,77,76,71,74,77,76,77,83,86,83,77,74,71], [40,41,43,47]),
        ("result", .5, [79,83,86,88,86,83,79,76,74,79,83,86,83,79,76,74], [48,55,52,50]),
    ]:
        length = beat * 32
        buf = [0.] * round(length*RATE)
        for i in range(32):
            add_note(buf, i*beat, beat*3, notes[i%16], .13, loop=True)
            add_note(buf, i*beat+.13, beat*3, notes[i%16], .035, loop=True)
            if i % 4 == 0:
                add_note(buf, i*beat, beat*5, bass[(i//8)%4], .18, "pad", True)
                add_note(buf, i*beat, beat*5, bass[(i//8)%4]+7, .05, "pad", True)
            if scene in ("play", "danger") and i % 2 == 0:
                for j in range(round(.055*RATE)):
                    t = j/RATE
                    at = (round(i*beat*RATE)+j)%len(buf)
                    buf[at] += .04*math.sin(2*math.pi*(90*t-350*t*t))*math.exp(-t*65)
        wav(f"bgm_{scene}", buf)
    effects = {"move": [79], "rotate": [76,83], "land": [48,60], "clear": [76,79,83], "chain": [79,83,86,91], "garbage": [44,43,39], "victory": [72,76,79,84,88], "defeat": [64,60,59,52]}
    for name, notes in effects.items():
        gap = .065 if name not in ("victory", "defeat") else .15
        duration = .2 if name in ("move", "rotate", "land") else .65
        buf = [0.] * int((len(notes)*gap+duration)*RATE)
        for i, midi in enumerate(notes):
            add_note(buf, i*gap, duration, midi, .22, "pad" if name in ("land","garbage","defeat") else "bell")
        wav(name, buf)


if __name__ == "__main__":
    ART.mkdir(parents=True, exist_ok=True)
    AUDIO.mkdir(parents=True, exist_ok=True)
    pieces()
    backgrounds()
    title_art()
    sounds()
    print("星つむぎ: SVG 11 点・音声 12 点を生成")
