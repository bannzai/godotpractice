#!/usr/bin/env python3
"""こもれびの調査隊専用の SVG と PCM 音源を決定的に生成する。"""
from pathlib import Path
import math
import struct
import wave

ASSETS = Path(__file__).resolve().parents[2] / 'assets'
INK = '#253b4b'


def svg(body, width=192, height=192):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
            f'viewBox="0 0 {width} {height}"><g stroke="{INK}" stroke-width="5" '
            f'stroke-linecap="round" stroke-linejoin="round">{body}</g></svg>\n')


def face(y=109, spread=22):
    return (f'<ellipse cx="{96-spread}" cy="{y}" rx="5" ry="7" fill="{INK}" stroke="none"/>'
            f'<ellipse cx="{96+spread}" cy="{y}" rx="5" ry="7" fill="{INK}" stroke="none"/>'
            f'<path d="M88 {y+14} Q96 {y+22} 104 {y+14}" fill="none" stroke-width="3"/>'
            f'<ellipse cx="{86-spread}" cy="{y+12}" rx="8" ry="4" fill="#efa68c" stroke="none"/>'
            f'<ellipse cx="{106+spread}" cy="{y+12}" rx="8" ry="4" fill="#efa68c" stroke="none"/>')


def write_images():
    monsters = {
        'ember': '''<path d="M143 145 Q188 136 164 108 Q174 145 138 124" fill="#f0ac62"/>
<path d="M52 74 Q24 24 65 40 L84 64 M108 65 L132 34 Q170 34 146 84" fill="#e87d62"/>
<ellipse cx="68" cy="160" rx="22" ry="11" fill="#d96c57"/><ellipse cx="127" cy="160" rx="22" ry="11" fill="#d96c57"/>
<path d="M42 106 Q38 59 94 58 Q151 58 151 109 L144 144 Q129 167 95 164 Q48 163 42 133Z" fill="#ee9272"/>
<path d="M68 135 Q96 100 125 135 L128 150 Q98 172 64 150Z" fill="#ffe3a1" stroke="none"/>
<path d="M84 74 L94 63 102 76" fill="#ffdb89" stroke="none"/>''' + face(108),
        'tide': '''<path d="M49 120 Q9 133 34 153 L64 143 M137 127 Q179 119 170 146 L139 150" fill="#62bdb7"/>
<path d="M63 69 Q46 42 65 24 Q83 48 87 62 M111 65 Q123 30 146 34 Q146 57 127 79" fill="#8bd3ce"/>
<path d="M45 116 Q42 65 94 61 Q148 58 150 114 Q164 161 97 166 Q35 166 45 116Z" fill="#7ccbc4"/>
<ellipse cx="95" cy="139" rx="35" ry="24" fill="#d6eee0" stroke="none"/>
<path d="M68 82 Q79 73 88 76" fill="none" stroke="#b5e5d6" stroke-width="8"/>''' + face(110),
        'sprout': '''<path d="M92 72 Q50 64 52 26 Q91 22 101 65" fill="#8fb86d"/>
<path d="M96 63 Q108 17 151 29 Q147 71 104 73" fill="#b5ce79"/>
<path d="M100 78 L111 43" fill="none" stroke="#53785d" stroke-width="4"/>
<ellipse cx="64" cy="159" rx="19" ry="10" fill="#7da568"/><ellipse cx="129" cy="159" rx="19" ry="10" fill="#7da568"/>
<path d="M41 117 Q44 67 96 67 Q153 67 153 120 Q151 164 96 165 Q39 163 41 117Z" fill="#b9d083"/>
<path d="M47 135 Q96 157 148 132 Q137 161 96 164 Q57 161 47 135" fill="#99ba70" stroke="none"/>
<path d="M67 88 L72 83 M126 85 L131 90" stroke="#ddecac" stroke-width="7"/>''' + face(112),
        'moth': '''<path d="M83 98 Q34 16 20 69 Q14 106 60 121 Q20 139 47 159 Q71 172 88 128" fill="#eec777"/>
<path d="M109 98 Q158 16 172 69 Q178 106 132 121 Q172 139 145 159 Q121 172 104 128" fill="#eec777"/>
<ellipse cx="48" cy="82" rx="14" ry="19" fill="#e79c73" stroke="none"/><ellipse cx="144" cy="82" rx="14" ry="19" fill="#e79c73" stroke="none"/>
<path d="M84 73 Q68 42 76 34 M108 73 Q124 42 116 34" fill="none"/>
<ellipse cx="96" cy="114" rx="27" ry="46" fill="#fff0c2"/>
<path d="M79 138 Q96 145 113 138" fill="none" stroke="#dabc84" stroke-width="4"/>''' + face(101, 12),
        'crab': '''<path d="M51 131 L28 142 22 154 M61 147 L42 161 M141 132 L164 142 170 154 M132 148 L151 161" fill="none" stroke-width="7"/>
<path d="M52 113 L32 93 M140 113 L160 93" fill="none" stroke-width="10"/>
<path d="M32 100 Q3 94 17 60 L33 75 42 53 Q67 76 45 97Z M160 100 Q189 94 175 60 L159 75 150 53 Q125 76 147 97Z" fill="#e89572"/>
<path d="M44 119 Q45 85 96 85 Q147 85 148 119 Q148 154 96 158 Q44 154 44 119Z" fill="#efb087"/>
<path d="M75 92 L75 74 M117 92 L117 74" fill="none"/>
<circle cx="75" cy="74" r="8" fill="#fff2cf"/><circle cx="117" cy="74" r="8" fill="#fff2cf"/>
<circle cx="76" cy="74" r="3" fill="#253b4b" stroke="none"/><circle cx="116" cy="74" r="3" fill="#253b4b" stroke="none"/>
<path d="M81 117 Q96 132 111 117" fill="none" stroke-width="3"/>
<path d="M68 135 Q95 145 125 135" fill="none" stroke="#ffcf9c" stroke-width="8"/>''',
        'owl': '''<path d="M64 151 L60 171 M75 154 L77 171 M117 154 L115 171 M128 152 L132 171" fill="none" stroke="#b99568" stroke-width="6"/>
<path d="M43 105 Q38 63 52 33 L78 56 Q96 49 115 56 L143 33 Q155 66 150 111 Q153 160 96 161 Q38 160 43 105Z" fill="#bba58a"/>
<path d="M47 108 Q24 124 44 148 L59 125 M145 108 Q167 123 148 148 L133 125" fill="#968772"/>
<path d="M58 89 Q68 65 96 86 Q125 64 136 90 Q147 121 96 143 Q45 121 58 89Z" fill="#ffedbf" stroke="none"/>
<ellipse cx="76" cy="101" rx="7" ry="10" fill="#253b4b" stroke="none"/><ellipse cx="116" cy="101" rx="7" ry="10" fill="#253b4b" stroke="none"/>
<path d="M89 118 L96 127 103 118Z" fill="#e6b268" stroke-width="3"/>
<path d="M79 148 L82 152 M96 146 L99 151 M113 147 L116 151" stroke="#e2d2ad" stroke-width="3"/>''',
    }
    for name, body in monsters.items():
        (ASSETS / 'monsters' / f'{name}.svg').write_text(svg(body), encoding='utf-8')
    player = '''<ellipse cx="24" cy="43" rx="13" ry="3" fill="#223b4433" stroke="none"/>
<path d="M16 33 L15 41 21 42 23 33 M26 33 L27 42 33 41 31 32" fill="#485368" stroke-width="2"/>
<rect x="13" y="23" width="22" height="14" rx="6" fill="#eac574" stroke-width="2"/>
<path d="M11 25 L9 33 M37 25 L39 33" stroke="#e8b796" stroke-width="5"/>
<ellipse cx="24" cy="18" rx="11" ry="10" fill="#f4d0a5" stroke-width="2"/>
<path d="M11 15 Q10 4 24 4 Q36 3 37 15Z" fill="#71aa9c" stroke-width="2"/>
<path d="M8 15 L39 15" stroke-width="4"/>
<path d="M20 21 L20 22 M28 21 L28 22" stroke-width="2"/>
<path d="M19 29 L29 32" stroke="#ee8b65" stroke-width="4"/>'''
    (ASSETS / 'player.svg').write_text(svg(player, 48, 48), encoding='utf-8')
    tiles = '''<g stroke="none"><path fill="#b3c995" d="M0 0h48v48H0z"/><path fill="#e4d5aa" d="M48 0h48v48H48z"/>
<path fill="#92b580" d="M96 0h48v48H96z"/><path fill="#709680" d="M144 0h48v48H144z"/>
<path fill="#86bcc0" d="M192 0h48v48H192z"/><path fill="#e9d7ad" d="M240 0h48v48H240z"/>
<path d="M6 13l3-5 2 6 M28 33l3-5 2 6 M35 10l2-4 3 5 M10 40l2-4 3 5" fill="none" stroke="#98b67b" stroke-width="2"/>
<path d="M58 11h8 M81 32h5 M56 38h4" stroke="#d5c394" stroke-width="3"/>
<path d="M100 42l4-17 3 13 5-22 4 20 6-19 4 21 4-23 5 22 7-17 M99 23l3-13 4 12 6-18 3 14 7-16 4 15 4-13 5 13 6-15" fill="none" stroke="#5f9168" stroke-width="3"/>
<circle cx="158" cy="15" r="16" fill="#517c67"/><circle cx="178" cy="14" r="17" fill="#648b6b"/><circle cx="157" cy="35" r="17" fill="#5b856b"/><circle cx="179" cy="34" r="17" fill="#456f60"/>
<path d="M152 10q4-5 9-4 M171 25q5-5 10-3" fill="none" stroke="#7ea078" stroke-width="3"/>
<path d="M197 12q5 3 10 0h8 M217 33q5 3 10 0h8 M195 43h10" fill="none" stroke="#b9d8cf" stroke-width="2"/>
<path d="M240 16h48 M240 32h48 M256 0v16 M273 16v16 M253 32v16" fill="none" stroke="#d5c299" stroke-width="2"/></g>'''
    (ASSETS / 'tiles.svg').write_text(svg(tiles, 288, 48), encoding='utf-8')


RATE = 22050


def tone(buffer, start, duration, midi, amplitude=0.14, bright=False):
    frequency = 440.0 * 2 ** ((midi - 69) / 12)
    for i in range(int(duration * RATE)):
        index = int(start * RATE) + i
        if index >= len(buffer):
            break
        t = i / RATE
        envelope = min(t / 0.012, 1.0) * min((duration - t) / 0.045, 1.0)
        envelope *= math.exp(-t * (3.8 if bright else 1.7))
        value = math.sin(math.tau * frequency * t)
        value += (0.24 if bright else 0.12) * math.sin(math.tau * frequency * 2 * t)
        buffer[index] += amplitude * envelope * value


def write_wav(name, samples):
    with wave.open(str(ASSETS / 'audio' / f'{name}.wav'), 'wb') as output:
        output.setparams((1, 2, RATE, len(samples), 'NONE', 'not compressed'))
        output.writeframes(b''.join(struct.pack('<h', round(max(-1, min(1, v)) * 32767)) for v in samples))


def write_audio():
    melodies = {
        'field': [72, 76, 79, 76, 74, 72, 69, 67, 69, 72, 76, 79, 77, 76, 74, 72,
                  76, 79, 84, 79, 77, 76, 74, 72, 69, 72, 74, 76, 74, 71, 72, 67],
        'battle': [69, 72, 76, 72, 69, 76, 79, 76, 67, 71, 74, 71, 67, 74, 77, 74,
                   65, 69, 72, 69, 65, 72, 76, 72, 64, 68, 71, 74, 76, 74, 71, 68],
    }
    for name, melody in melodies.items():
        samples = [0.0] * (16 * RATE)
        step = 0.5 if name == 'field' else 0.25
        for i in range(int(16 / step)):
            tone(samples, i * step, step * 0.82, melody[i % 32], 0.12, name == 'battle')
        roots = [48, 45, 53, 55] if name == 'field' else [45, 43, 41, 40]
        for i in range(32):
            root = roots[(i // 8) % 4]
            tone(samples, i * 0.5, 0.37, root if i % 2 == 0 else root + 7, 0.10)
        for i in range(8):
            root = roots[(i // 2) % 4] + 12
            for interval in [0, 4 if name == 'field' else 3, 7]:
                tone(samples, i * 2, 1.8, root + interval, 0.032)
        write_wav(name, samples)
    for name, notes in [('attack', [64, 52]), ('capture', [72, 76, 79, 84]), ('heal', [67, 72, 76, 79])]:
        samples = [0.0] * int((0.35 if name == 'attack' else 0.9) * RATE)
        for i, note in enumerate(notes):
            tone(samples, i * (0.06 if name == 'attack' else 0.13), 0.20 if name == 'attack' else 0.32, note, 0.24, True)
        write_wav(name, samples)


def main():
    for directory in ['monsters', 'audio']:
        (ASSETS / directory).mkdir(parents=True, exist_ok=True)
    write_images()
    write_audio()
    print('素材生成 OK: SVG 8 点、WAV 5 点')


if __name__ == '__main__':
    main()
