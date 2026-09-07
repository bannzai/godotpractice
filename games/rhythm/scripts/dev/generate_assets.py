#!/usr/bin/env python3
"""星灯りの祭り囃子の独自 SVG / 音声を同じ入力から再生成する。外部サンプル不要。"""
from array import array
import argparse
from copy import deepcopy
from functools import lru_cache
from pathlib import Path
import math
import random
import subprocess
import wave
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'assets'
RATE = 22050
TAU = math.tau


def svg(name, body, width=200, height=240):
    path = ASSETS / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">{body}</svg>\n')


def pictures():
    """同じ定義の画像を上書きするため再実行しても結果は同じ。"""
    outline = 'stroke="#27364d" stroke-width="5" stroke-linejoin="round" stroke-linecap="round"'
    svg('characters/fox.svg', f'''
    <ellipse cx="100" cy="224" rx="67" ry="10" fill="#101a30" opacity=".32"/>
    <g {outline}>
    <path d="M142 177 Q192 197 185 140 Q157 150 151 134 L130 160" fill="#ed9164"/>
    <path d="M174 145 L185 140 Q189 163 180 176 L166 161" fill="#fff0ce"/>
    <path d="M59 191 L51 217 Q60 231 83 218 L90 185 M112 185 L119 218 Q143 231 150 215 L140 184" fill="#344961"/>
    <path d="M51 136 Q53 104 100 108 Q146 109 150 145 L142 191 Q102 207 59 190Z" fill="#63c5b7"/>
    <path d="M47 59 L36 15 L78 39 M126 40 L165 16 L158 76" fill="#ed9164"/>
    <path d="M48 36 L50 58 L64 47 M142 47 L154 34 L149 62" fill="#d86d66" stroke="none"/>
    <path d="M43 64 Q60 33 102 39 Q141 36 163 68 L150 99 Q112 135 72 110 L41 86Z" fill="#ed9164"/>
    <path d="M46 80 L78 78 L101 94 L123 78 L158 79 Q145 118 101 118 Q59 117 46 80" fill="#fff0ce" stroke="none"/>
    <path d="M74 68 L83 66 M120 65 L128 68" fill="none"/>
    <ellipse cx="79" cy="77" rx="4" ry="6" fill="#27364d" stroke="none"/>
    <ellipse cx="124" cy="77" rx="4" ry="6" fill="#27364d" stroke="none"/>
    <path d="M93 89 Q101 83 110 89 L102 97Z" fill="#27364d" stroke-width="2"/>
    <path d="M93 104 Q101 111 110 104" fill="none" stroke-width="3"/>
    <path d="M67 41 Q99 24 133 40 L130 53 L65 54Z" fill="#344961"/>
    <path d="M75 50 L139 50 Q133 62 93 59" fill="#63c5b7"/>
    <path d="M100 32 L108 42 L101 47 L92 42Z" fill="#f7d58a" stroke-width="2"/>
    <path d="M64 119 L128 184" fill="none" stroke="#fff0ce" stroke-width="11"/>
    <path d="M44 137 Q21 130 24 153 L55 170 M150 136 Q173 129 175 150 L150 168" fill="#ed9164"/>
    <path d="M30 132 L68 156 M173 129 L137 157" stroke="#f7d58a" stroke-width="7"/>
    <path d="M62 151 L142 151 L147 195 Q101 221 59 195Z" fill="#f08379"/>
    <ellipse cx="102" cy="151" rx="41" ry="13" fill="#fff0ce"/>
    <path d="M65 164 L84 197 L102 166 L121 200 L140 164" fill="none" stroke="#fff0ce" stroke-width="4"/>
    <path d="M59 191 Q101 211 147 191" fill="none"/>
    </g>''')
    svg('characters/bird.svg', f'''
    <ellipse cx="100" cy="224" rx="70" ry="10" fill="#101a30" opacity=".32"/>
    <g {outline}>
    <path d="M60 121 Q17 100 26 162 L58 180 M141 120 Q187 107 174 167 L142 181" fill="#79c8bf"/>
    <path d="M72 195 L67 220 L45 221 M120 195 L129 220 L149 222" fill="none" stroke="#f4b86c" stroke-width="9"/>
    <path d="M65 80 Q37 112 48 161 Q49 198 99 204 Q152 203 156 165 Q163 110 136 83Z" fill="#84d3c3"/>
    <path d="M72 136 Q99 118 128 138 L135 176 Q100 192 63 175Z" fill="#fff0ce" stroke="none"/>
    <path d="M86 34 Q63 8 72 3 Q91 6 104 31 Q109 4 127 13 L119 43" fill="#84d3c3"/>
    <path d="M49 71 Q53 34 98 33 Q144 32 152 73 Q160 112 123 127 Q86 142 59 114Z" fill="#84d3c3"/>
    <ellipse cx="74" cy="79" rx="17" ry="23" fill="#fff0ce" stroke="none"/>
    <ellipse cx="124" cy="79" rx="17" ry="23" fill="#fff0ce" stroke="none"/>
    <path d="M69 79 Q75 72 81 79 M117 79 Q123 72 129 79" fill="none" stroke-width="4"/>
    <path d="M92 89 L110 89 L102 104Z" fill="#f4b86c" stroke-width="3"/>
    <path d="M42 68 Q44 24 98 24 Q154 25 158 68" fill="none" stroke="#7a83bc" stroke-width="11"/>
    <rect x="33" y="65" width="18" height="35" rx="8" fill="#f08379"/>
    <rect x="150" y="65" width="18" height="35" rx="8" fill="#f08379"/>
    <path d="M61 127 L91 141 L83 152 L55 138 M92 141 L124 127 L131 139 L99 154" fill="#7a83bc" stroke-width="3"/>
    <rect x="23" y="158" width="157" height="43" rx="9" fill="#344961"/>
    <rect x="32" y="171" width="139" height="21" rx="3" fill="#fff0ce" stroke="none"/>
    <path d="M47 171 V191 M65 171 V191 M83 171 V191 M102 171 V191 M120 171 V191 M138 171 V191 M155 171 V191" stroke-width="2"/>
    <path d="M46 173 V182 M65 173 V182 M102 173 V182 M119 173 V182 M137 173 V182" stroke-width="7"/>
    <circle cx="158" cy="165" r="3" fill="#f08379" stroke="none"/>
    <path d="M48 142 Q31 145 45 163 L64 162 M151 142 Q172 150 153 163 L135 162" fill="#84d3c3"/>
    </g>''')
    svg('characters/rabbit.svg', f'''
    <ellipse cx="100" cy="224" rx="67" ry="10" fill="#101a30" opacity=".32"/>
    <g {outline}>
    <path d="M63 190 L52 216 Q71 232 91 216 L89 183 M112 184 L113 216 Q137 230 150 215 L139 190" fill="#fff0ce"/>
    <path d="M57 129 Q96 109 137 131 L148 193 Q103 212 51 193Z" fill="#7a83bc"/>
    <path d="M70 68 Q42 12 62 6 Q83 3 87 62 M111 61 Q112 5 135 6 Q156 13 131 73" fill="#fff0ce"/>
    <path d="M66 22 L77 55 M132 22 L123 54" stroke="#f4a89c" stroke-width="8"/>
    <path d="M51 88 Q51 59 95 57 Q143 52 151 90 Q160 131 104 141 Q51 139 51 88Z" fill="#fff0ce"/>
    <path d="M57 70 Q97 43 144 71 L138 84 Q95 65 57 85Z" fill="#f08379"/>
    <path d="M140 76 L161 94 L148 103 L134 87" fill="#f08379"/>
    <ellipse cx="78" cy="97" rx="4" ry="6" fill="#27364d" stroke="none"/>
    <ellipse cx="126" cy="97" rx="4" ry="6" fill="#27364d" stroke="none"/>
    <path d="M97 110 L104 110 L101 115 M93 121 Q101 126 109 120" fill="none" stroke-width="3"/>
    <ellipse cx="66" cy="112" rx="9" ry="5" fill="#f4a89c" stroke="none"/>
    <ellipse cx="137" cy="111" rx="9" ry="5" fill="#f4a89c" stroke="none"/>
    <path d="M72 139 L130 199" fill="none" stroke="#f7d58a" stroke-width="9"/>
    <path d="M55 151 Q29 157 51 178 L83 185 M137 145 Q157 137 161 151 L143 168" fill="#fff0ce"/>
    <path d="M95 165 Q71 147 60 174 Q39 191 63 210 Q85 226 103 204 Q124 202 116 182Z" fill="#f08379"/>
    <path d="M90 179 L156 109 L168 121 L105 190" fill="#dca96b"/>
    <path d="M155 109 L161 96 L177 111 L168 124Z" fill="#f7d58a"/>
    <path d="M71 196 L164 113 M75 201 L168 116" fill="none" stroke="#fff0ce" stroke-width="2"/>
    <path d="M72 184 L89 199" fill="none" stroke-width="6"/>
    <circle cx="101" cy="199" r="3" fill="#f7d58a" stroke="none"/>
    </g>''')
    rng = random.Random(43)
    stars = ''.join(f'<circle cx="{rng.randrange(25,1255)}" cy="{rng.randrange(18,440)}" r="{rng.choice([1,1,2,3])}" fill="#ffedc4" opacity="{rng.uniform(.2,.8):.2f}"/>' for _ in range(110))
    svg('backgrounds/sky.svg', f'''<defs><linearGradient id="g" x2="0" y2="1"><stop stop-color="#14263e"/><stop offset="1" stop-color="#53657a"/></linearGradient><radialGradient id="halo"><stop stop-color="#f7d58a" stop-opacity=".17"/><stop offset="1" stop-color="#f7d58a" stop-opacity="0"/></radialGradient></defs><rect width="1280" height="720" fill="url(#g)"/>{stars}<circle cx="1060" cy="142" r="150" fill="url(#halo)"/><circle cx="1060" cy="142" r="52" fill="#ffedc4"/><circle cx="1080" cy="125" r="49" fill="#20334c"/><path d="M35 171 Q134 102 240 165 Q340 207 450 155" fill="none" stroke="#60748a" stroke-opacity=".19" stroke-width="22"/>''',1280,720)
    buildings = []
    for index in range(19):
        x=index*74-25; h=rng.randrange(100,225); y=590-h
        color=['#263e55','#30465c','#385368'][index%3]
        buildings.append(f'<path d="M{x} 620 V{y+20} L{x+32} {y} L{x+65} {y+20} V620Z" fill="{color}"/>')
        for floor in range(2,h//29):
            for col in range(2):
                if rng.random()<.7:
                    buildings.append(f'<rect x="{x+14+col*27}" y="{y+floor*27}" width="10" height="15" rx="3" fill="{rng.choice(["#ecc387","#8dc5b9"])}" opacity=".55"/>')
    svg('backgrounds/city.svg',''.join(buildings)+'<path d="M0 606 Q350 538 700 599 Q1060 549 1280 594 V720 H0Z" fill="#20374b"/>',1280,720)
    svg('backgrounds/foreground.svg','''<path d="M0 649 Q450 607 1280 650 V720 H0Z" fill="#182c40"/><path d="M0 660 Q580 627 1280 660" fill="none" stroke="#647270" stroke-width="3"/><g fill="#f7d58a"><circle cx="61" cy="610" r="5"/><circle cx="283" cy="604" r="5"/><circle cx="527" cy="601" r="5"/><circle cx="783" cy="604" r="5"/><circle cx="1040" cy="609" r="5"/><circle cx="1257" cy="615" r="5"/></g><path d="M0 585 Q320 651 639 585 Q960 650 1280 585" fill="none" stroke="#657774" stroke-width="2"/>''',1280,720)
    for name, color, symbol in [('note-coral','#f08379','<circle cx="48" cy="48" r="13" fill="none" stroke="#fff0ce" stroke-width="6"/>'),('note-mint','#84d3c3','<path d="M48 30 L64 48 L48 66 L32 48Z" fill="#fff0ce"/>'),('note-long','#f7d58a','<path d="M32 48 H64 M54 36 L66 48 L54 60" fill="none" stroke="#344961" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>')]:
        svg(f'ui/{name}.svg',f'<circle cx="48" cy="51" r="40" fill="#10243a" opacity=".5"/><circle cx="48" cy="46" r="38" fill="{color}" stroke="#fff0ce" stroke-width="4"/><path d="M25 29 Q39 17 55 22" fill="none" stroke="#fff9e7" stroke-opacity=".55" stroke-width="5" stroke-linecap="round"/>{symbol}',96,96)
    svg('ui/star.svg','<path d="M32 3 L41 22 L62 25 L46 40 L50 62 L32 52 L13 62 L17 40 L2 25 L23 22Z" fill="#f7d58a" stroke="#fff0ce" stroke-width="3" stroke-linejoin="round"/>',64,64)
    svg('ui/moon.svg','<path d="M49 6 A27 27 0 1 0 58 46 A27 27 0 0 1 49 6" fill="#fff0ce"/>',64,64)
    svg('ui/ticket.svg','<path d="M6 12 H74 V26 Q62 32 74 38 V52 H6 V38 Q18 32 6 26Z" fill="#fff0ce" stroke="#f7d58a" stroke-width="3"/><path d="M52 15 V49" stroke="#ba9d75" stroke-width="2" stroke-dasharray="4 4"/><path d="M29 22 L32 29 L40 30 L34 35 L35 43 L29 39 L22 43 L24 35 L18 30 L26 29Z" fill="#f08379"/>',80,64)
    svg('ui/logo-mark.svg','''<circle cx="90" cy="90" r="78" fill="#21394e" stroke="#f7d58a" stroke-width="3"/><path d="M35 108 Q72 131 131 95" fill="none" stroke="#84d3c3" stroke-width="7" stroke-linecap="round"/><path d="M38 91 Q69 115 135 79" fill="none" stroke="#f08379" stroke-width="7" stroke-linecap="round"/><path d="M88 27 L100 53 L129 56 L107 76 L113 103 L88 89 L63 103 L69 76 L47 56 L76 53Z" fill="#f7d58a" stroke="#fff0ce" stroke-width="3"/><path d="M137 40 L141 49 L151 50 L143 57 L145 67 L137 62 L128 67 L130 57 L122 50 L132 49Z" fill="#84d3c3"/><path d="M59 138 H119" stroke="#fff0ce" stroke-width="3" stroke-linecap="round"/>''',180,180)


def character_sheets():
    """各セルの部位と表情を決定的に変え、5 状態 × 4 フレームを出力する。"""
    ns = '{http://www.w3.org/2000/svg}'
    ET.register_namespace('', 'http://www.w3.org/2000/svg')
    parts = {
        'fox': {'head': range(4, 16), 'ears': [4, 5], 'arms': 17,
                'instrument': range(19, 23), 'eyes': [9, 10], 'mouth': 12},
        'bird': {'head': range(4, 13), 'ears': [4], 'arms': 19,
                 'instrument': range(14, 19), 'eyes': [8], 'mouth': 9},
        'rabbit': {'head': range(2, 12), 'ears': [2, 3], 'arms': 13,
                   'instrument': range(14, 20), 'eyes': [7, 8], 'mouth': 9},
    }
    states = ['idle', 'dance', 'hit', 'miss', 'celebrate']
    for name, spec in parts.items():
        source = ET.parse(ASSETS / 'characters' / f'{name}.svg').getroot()
        cells = []
        for row, state in enumerate(states):
            for frame in range(4):
                phase = [0, 1, -.35, -1][frame]
                figure = deepcopy(source[-1])
                elements = list(figure)
                strength = {'idle': 1, 'dance': 4, 'hit': 6,
                            'miss': 3, 'celebrate': 7}[state]
                head_angle = phase * strength * .6
                if state == 'miss':
                    head_angle += 7
                for i in spec['head']:
                    elements[i].set('transform', f'rotate({head_angle} 100 125)')
                for i in spec['ears']:
                    elements[i].set('transform',
                        f'rotate({head_angle + phase * strength} 100 65)')
                # 左右の腕を肩から逆向きに回し、胴体とは独立して演奏させる。
                arm = elements[spec['arms']]
                left, right = ['M' + piece for piece in arm.get('d').split('M')[1:]]
                arm.clear()
                arm.tag = ns + 'g'
                arm_angle = phase * strength * 2
                if state == 'celebrate':
                    arm_angle -= 27
                if state == 'miss':
                    arm_angle = 12 + phase * 3
                hand_color = {'fox': '#ed9164', 'bird': '#84d3c3',
                              'rabbit': '#fff0ce'}[name]
                ET.SubElement(arm, ns + 'path', {'d': left, 'fill': hand_color,
                    'transform': f'rotate({arm_angle} 55 140)'})
                ET.SubElement(arm, ns + 'path', {'d': right, 'fill': hand_color,
                    'transform': f'rotate({-arm_angle} 146 140)'})
                if name == 'fox':
                    sticks = elements[18]
                    sticks.clear()
                    sticks.tag = ns + 'g'
                    for d, angle, pivot in [('M30 132 L68 156', arm_angle, '55 140'),
                                            ('M173 129 L137 157', -arm_angle, '146 140')]:
                        ET.SubElement(sticks, ns + 'path', {'d': d, 'stroke': '#f7d58a',
                            'stroke-width': '7', 'transform': f'rotate({angle} {pivot})'})
                for i in spec['instrument']:
                    elements[i].set('transform',
                        f'rotate({phase * strength * .35} 100 175) translate(0 {-abs(phase) * strength * .3})')
                # 成功と祝福は笑顔、ミスは困り顔。待機中は一度まばたきする。
                eye_height = 79 if name == 'bird' else (77 if name == 'fox' else 97)
                eye_centers = [75, 123] if name == 'bird' else ([79, 124] if name == 'fox' else [78, 126])
                for eye_index in spec['eyes']:
                    elements[eye_index].set('visibility', 'hidden')
                face = ET.SubElement(figure, ns + 'g', {
                    'transform': f'rotate({head_angle} 100 125)',
                    'stroke': '#27364d', 'stroke-width': '4', 'fill': 'none'})
                for x in eye_centers:
                    y = eye_height
                    if state == 'miss':
                        d = f'M{x-6} {y-4} L{x+5} {y+1} L{x-5} {y+5}'
                    elif state in ('hit', 'celebrate') or (state == 'dance' and frame % 2):
                        d = f'M{x-6} {y+2} Q{x} {y-8-abs(phase)*2} {x+6} {y+2}'
                    elif frame == 2 and state == 'idle':
                        d = f'M{x-5} {y+1} H{x+5}'
                    else:
                        d = f'M{x} {y-3} V{y+3}'
                    ET.SubElement(face, ns + 'path', {'d': d})
                mouth = elements[spec['mouth']]
                if state == 'miss':
                    if name == 'fox':
                        mouth.set('d', 'M93 110 Q101 101 110 110')
                    elif name == 'rabbit':
                        mouth.set('d', 'M97 110 L104 110 L101 115 M93 125 Q101 116 109 125')
                    else:
                        mouth.set('d', 'M93 96 L101 90 L110 96 L102 100Z')
                    ET.SubElement(face, ns + 'path', {
                        'd': f'M145 {eye_height+7} Q135 {eye_height+23} 144 {eye_height+23} Q153 {eye_height+23} 145 {eye_height+7}',
                        'fill': '#91dcea', 'stroke': 'none'})
                elif state == 'celebrate':
                    if name == 'fox':
                        mouth.set('d', 'M91 102 Q101 118 112 102Z')
                        mouth.set('fill', '#d86d66')
                    elif name == 'rabbit':
                        mouth.set('d', 'M97 110 L104 110 L101 115 M91 120 Q101 134 112 120Z')
                        mouth.set('fill', '#d86d66')
                    else:
                        mouth.set('d', 'M90 89 L112 89 L102 110Z')
                body = ET.tostring(figure, encoding='unicode')
                # 余白を確保し、耳とスティックの動きが隣セルへはみ出さないようにする。
                cell = f'<g transform="translate({frame*200} {row*240})"><ellipse cx="100" cy="224" rx="62" ry="8" fill="#101a30" opacity=".25"/><g transform="translate(10 15) scale(.9)">{body}</g>'
                if state == 'celebrate':
                    for x, y in [(20, 64-frame*3), (178, 107+phase*9)]:
                        cell += f'<path d="M{x} {y-8} L{x+3} {y-2} L{x+9} {y} L{x+3} {y+3} L{x} {y+9} L{x-3} {y+3} L{x-9} {y} L{x-3} {y-2}Z" fill="#f7d58a"/>'
                cell += '</g>'
                cells.append(cell)
        svg(f'characters/{name}-sheet.svg', ''.join(cells), 800, 1200)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


@lru_cache(maxsize=384)
def voice(kind, midi, seconds):
    """決まった波形とシードを使い、同じノートは同じ音を返す。"""
    count = int(seconds * RATE)
    f = hz(midi)
    rng = random.Random(43 + midi + count)
    data = array('f')
    for i in range(count):
        t = i / RATE
        phase = TAU * f * t
        release = min(1., (seconds-t)/.055)
        attack = min(1., t/.008)
        if kind == 'lead':
            value = (math.sin(phase)+.32*math.sin(2*phase)+.12*math.sin(3*phase)) * math.exp(-t*3) * attack
        elif kind == 'bell':
            value = (math.sin(phase)+.45*math.sin(phase*2.003)+.18*math.sin(phase*3.998)) * math.exp(-t*7) * attack
        elif kind == 'bass':
            value = (math.sin(phase)+.25*math.sin(2*phase)+.08*math.sin(3*phase))*min(1.,t/.006)*math.exp(-t*2)
        elif kind == 'pad':
            value = (math.sin(phase)+.3*math.sin(phase*1.004)+.14*math.sin(2*phase))*min(1.,t/.12)*.7
        elif kind == 'taiko':
            # 皮の低い基音、胴鳴り、打面の短いノイズを重ねる。
            drop = f * (1.0 + 0.65 * math.exp(-t * 26))
            body = math.sin(TAU * drop * t) + .42 * math.sin(TAU * drop * 1.53 * t)
            value = (body * math.exp(-t * 8) + rng.uniform(-1, 1) * math.exp(-t * 42) * .3)
        elif kind == 'rim':
            # 縁を叩いた木の硬い立ち上がり。太鼓の面と音域・減衰を分ける。
            value = (
                math.sin(phase * 2.71) + .55 * math.sin(phase * 4.16)
                + rng.uniform(-1, 1) * .2
            ) * math.exp(-t * 38)
        elif kind == 'fue':
            breath = rng.uniform(-1, 1) * .055
            value = (
                math.sin(phase) + .22 * math.sin(2 * phase) + .11 * math.sin(3 * phase)
                + breath
            ) * attack * math.exp(-t * 1.6)
        elif kind == 'shamisen':
            pick = rng.uniform(-1, 1) * math.exp(-t * 52) * .32
            value = (
                math.sin(phase) + .48 * math.sin(2 * phase) + .22 * math.sin(3 * phase)
                + pick
            ) * math.exp(-t * 6.5) * attack
        elif kind == 'kick':
            value = math.sin(TAU*(46*t+9*(1-math.exp(-t*33))))*math.exp(-t*17)
        elif kind == 'snare':
            value = (rng.uniform(-1,1)*.8+math.sin(TAU*177*t)*.2)*math.exp(-t*23)
        elif kind == 'hat':
            value = rng.uniform(-1,1)*math.exp(-t*65)
        else:
            value = math.sin(phase)*math.exp(-t*11)
        data.append(value*release)
    return data


def mix(buffer, at, samples, gain):
    start = round(at * RATE)
    if start >= len(buffer):
        return
    for i in range(min(len(samples),len(buffer)-start)):
        buffer[start+i] += samples[i]*gain


def write_audio(name, buffer, stereo=True, ogg=True, fade=True):
    """決まった PCM を生成する。OGG エンコーダのコンテナ識別子だけは毎回異なる。"""
    path = ASSETS/'audio'/f'{name}.wav'
    path.parent.mkdir(parents=True,exist_ok=True)
    peak=max(abs(v) for v in buffer) or 1
    gain=.83/peak
    pcm=array('h')
    delay=round(RATE*.017)
    for i,value in enumerate(buffer):
        ending=min(1.,(len(buffer)-i)/(RATE*.45)) if fade else 1.
        left=math.tanh(value*gain)*ending
        pcm.append(round(left*30000))
        if stereo:
            right=math.tanh((value*.88+(buffer[i-delay] if i>=delay else 0)*.12)*gain)*ending
            pcm.append(round(right*30000))
    target=ROOT/'tmp'/f'{name}.wav' if ogg else path
    target.parent.mkdir(parents=True,exist_ok=True)
    with wave.open(str(target),'wb') as file:
        file.setnchannels(2 if stereo else 1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(pcm.tobytes())
    if ogg:
        subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(target),'-c:a','libvorbis','-q:a','5',str(path.with_suffix('.ogg'))],check=True)
    print(f'生成: {name} / {len(buffer)/RATE:.2f} 秒',flush=True)


def song(name,bpm,seconds,root,pattern,melody_kind='fue'):
    beat=60/bpm
    buffer=array('f',[0.])*round(seconds*RATE)
    chords=[0,5,9,7]
    scale=[0,2,4,7,9,12,14,16]
    total=math.ceil(seconds/beat)
    for b in range(total):
        bar=b//4
        chord=chords[(bar//2)%4]
        at=b*beat
        # 最初の 8 拍もテンポを聴ける。中盤で引き算し、後半に高音と細分を足す。
        energy=1. if b>=total*.58 else .75
        breakdown=total*.42<b<total*.51
        if b%4==0 or (b%4==2 and not breakdown):
            mix(buffer,at,voice('taiko',38,.42),.57)
        if b%4 in (1,3):
            mix(buffer,at,voice('rim',67,.16),.25 if breakdown else .37)
        mix(buffer,at,voice('hat',40,.08),.09)
        if not breakdown:
            mix(buffer,at+beat*.5,voice('hat',40,.06),.055*energy)
        bassnote=root-24+chord+(12 if b%4==3 else 0)
        mix(buffer,at,voice('bass',bassnote,round(beat*.8,3)),.42)
        if b%4==0:
            minor=chord==9
            for interval in [0,3 if minor else 4,7,11 if chord==0 else 10]:
                mix(buffer,at,voice('pad',root+chord+interval,round(beat*3.8,3)),.052)
        if b>=8 and not breakdown:
            degree=pattern[b%len(pattern)]
            melody=root+12+scale[degree]
            mix(buffer,at,voice(melody_kind,melody,round(beat*.75,3)),.24*energy)
            mix(buffer,at+beat*.75,voice('bell',melody,round(beat*.4,3)),.05)
            if b%4==3 or b>total*.6:
                second=root+12+scale[pattern[(b+3)%len(pattern)]]
                mix(buffer,at+beat*.5,voice('bell',second,round(beat*.4,3)),.16*energy)
        if breakdown or b%8==0:
            mix(buffer,at,voice('bell',root+24+scale[(bar+2)%8],round(beat*1.5,3)),.14)
        if b>=total*.7 and b%4==3:
            for step in range(4):
                mix(buffer,at+beat*step/4,voice('hat',40,.055),.06)
    write_audio(name,buffer)


def festival_ambience(seconds=24):
    """ざわめき、拍子木、遠花火、風鈴を重ねた決定的な境内環境音を作る。"""
    count = round(seconds * RATE)
    buffer = array('f', [0.]) * count
    rng = random.Random(4307)
    # 声そのものには聞こえない帯域のざわめきを滑らかにし、環境の奥行きだけを足す。
    murmur = 0.0
    slow = 0.0
    for i in range(count):
        murmur = murmur * .965 + rng.uniform(-1, 1) * .035
        slow = slow * .9994 + rng.uniform(-1, 1) * .0006
        buffer[i] = murmur * .055 + slow * .09
    for at in [1.6, 1.82, 7.4, 7.62, 14.1, 14.32, 20.2, 20.42]:
        mix(buffer, at, voice('rim', 77, .13), .11)
    for at, note in [(3.2, 88), (8.8, 91), (12.7, 86), (18.0, 93), (22.1, 89)]:
        mix(buffer, at, voice('bell', note, 1.2), .075)
    for at in [5.6, 16.4]:
        mix(buffer, at, voice('taiko', 31, 1.3), .12)
    write_audio('festival-ambience', buffer, fade=False)


def jingle(name,notes,beat,kind='bell',ogg=True):
    seconds=len(notes)*beat+.65
    buffer=array('f',[0.])*round(seconds*RATE)
    for i,note in enumerate(notes):
        mix(buffer,i*beat,voice(kind,note,beat+.3),.5)
        mix(buffer,i*beat,voice('pad',note-12,beat+.2),.16)
    write_audio(name,buffer,stereo=ogg,ogg=ogg)


def audio_assets():
    song('starlight',112,72,60,[0,2,4,3,2,1,2,4,5,4,2,3,1,0,2,1],'fue')
    song('moonride',128,75,62,[2,4,5,3,4,2,1,2,4,6,5,4,2,3,1,0],'shamisen')
    song('comet',144,70,64,[0,3,2,5,4,3,6,5,2,4,3,6,7,5,4,2],'fue')
    song('title',96,20,60,[0,2,4,2,5,4,2,1],'shamisen')
    song('select',112,18,65,[2,4,2,1,0,2,3,4],'fue')
    festival_ambience()
    jingle('result-clear',[72,76,79,84,79,84],.22)
    jingle('result-fail',[67,64,62,60],.35,'lead')
    jingle('hit-coral',[38],.09,'taiko',False)
    jingle('hit-mint',[76],.07,'rim',False)
    jingle('hold',[72,76,79],.055,'shamisen',False)
    jingle('fever',[72,76,79,84],.07,'fue',False)
    jingle('miss',[45],.1,'bass',False)


if __name__=='__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--images-only', action='store_true', help='画像だけを再生成する')
    options = parser.parse_args()
    pictures()
    character_sheets()
    if not options.images_only:
        audio_assets()
