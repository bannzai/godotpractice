"""灯守の島の独自SVGと譜面を決定的に再生成する。Python標準ライブラリのみ。"""
from pathlib import Path
from math import sin, cos, pi, exp
from array import array
import random
import wave
import sys

ROOT = Path(__file__).resolve().parents[2] / "assets"
INK = "#142733"
GOLD = "#edc67d"
JADE = "#62b3a3"
DEFS = '''<defs>
<linearGradient id="jade" x2="0.2" y2="1"><stop stop-color="#91dac2"/><stop offset="1" stop-color="#316b72"/></linearGradient>
<linearGradient id="stone" x2="0.3" y2="1"><stop stop-color="#9cadac"/><stop offset="1" stop-color="#46566a"/></linearGradient>
<linearGradient id="gold" x2="0.3" y2="1"><stop stop-color="#fff1bb"/><stop offset="1" stop-color="#b87746"/></linearGradient>
<linearGradient id="cloth" x2="0.3" y2="1"><stop stop-color="#356e80"/><stop offset="1" stop-color="#20354f"/></linearGradient>
<linearGradient id="sky" x2="0.2" y2="1"><stop stop-color="#101c35"/><stop offset="0.65" stop-color="#29435c"/><stop offset="1" stop-color="#4c7879"/></linearGradient>
<radialGradient id="glow"><stop stop-color="#fff0b0" stop-opacity="0.8"/><stop offset="0.4" stop-color="#ebc776" stop-opacity="0.18"/><stop offset="1" stop-color="#ebc776" stop-opacity="0"/></radialGradient>
</defs>'''


def svg(body, width=96, height=96):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">{DEFS}<g stroke-linecap="round" stroke-linejoin="round">{body}</g></svg>'


def path(d, fill, stroke=INK, sw=2):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'


def ellipse(x, y, rx, ry, fill, stroke="none", sw=2):
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'


def rect(x, y, w, h, fill, stroke=INK, radius=3):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{fill}" stroke="{stroke}" stroke-width="2"/>'


def group(body, transform, opacity=1):
    return f'<g transform="{transform}" opacity="{opacity}">{body}</g>'


def save(name, data):
    dest = ROOT / name
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(data, encoding="utf-8")


def eyes(x=48, y=44, gap=9, closed=False):
    if closed:
        return path(f'M{x-gap-2} {y}l4 2m{gap*2-4} -2l4 2', 'none', INK, 2)
    return ellipse(x-gap, y, 2.1, 3.3, INK) + ellipse(x+gap, y, 2.1, 3.3, INK)


def human(kind, frame, row):
    step = (0, 5, 0, -5)[frame] if row == 1 else 0
    action = (0, -28, 35, 12)[frame] if row == 2 else (0, 3, 0, -3)[frame]
    body = ellipse(39, 76 + step, 7, 5, INK) + ellipse(57, 76 - step, 7, 5, INK)
    if kind == 'hero':
        body += path('M34 42Q24 52 24 73Q47 82 72 73L64 42Z', 'url(#cloth)')
        body += path('M34 43L48 56L64 43L61 65L48 75L35 65Z', 'url(#jade)')
        body += path('M35 49L58 68', 'none', GOLD, 4)
        body += rect(48, 60, 9, 8, 'url(#gold)')
        body += ellipse(48, 36, 16, 17, '#d8b58e', INK)
        body += path('M30 35Q26 10 48 13Q68 14 67 39L60 31L40 28L34 40Z', '#283c4c')
        body += path('M31 23Q44 7 61 21L67 29L34 26Z', 'url(#jade)')
        body += path('M38 26L50 12L51 26Z', '#b7e1c4', 'none')
        body += eyes(48, 38, 7, row in (3, 4))
        body += group(path('M66 53L78 27L82 30L72 57Z', '#dbebdf') + path('M66 53L76 57M70 56L66 65', 'none', GOLD, 4), f'rotate({action} 64 56)')
        body += ellipse(30, 57, 5, 6, '#d8b58e', INK)
        body += path('M23 56L32 54L36 69L25 72Z', 'url(#gold)')
        body += ellipse(29, 63, 3, 5, '#fff4c1')
    elif kind == 'villager':
        body += path('M34 43L27 77Q48 84 69 77L61 43Z', 'url(#cloth)')
        body += path('M37 48L48 74L59 48', 'none', GOLD, 4)
        body += ellipse(48, 35, 16, 17, '#c7aa8a', INK)
        body += path('M31 34Q25 13 48 13Q70 15 64 35L57 27L38 28Z', '#bfc8bf')
        body += path('M34 43L39 58L48 64L58 56L62 42L54 46L48 42L42 47Z', '#dee0c9')
        body += eyes(48, 36, 7, row in (3, 4))
        body += group(path('M74 76L74 24Q74 14 66 21', 'none', '#aa805b', 5) + ellipse(73, 28, 10, 14, 'url(#glow)') + rect(68, 23, 10, 13, 'url(#gold)'), f'rotate({action/3} 74 64)')
        body += ellipse(68, 56, 5, 5, '#c7aa8a', INK)
    else:
        body += rect(22, 35, 50, 38, '#754e48', INK, 8)
        body += path('M25 44L69 44M28 35L27 69M65 34L65 68', 'none', GOLD, 3)
        body += path('M35 44L28 72Q48 80 68 72L60 44Z', '#b47759')
        body += path('M36 47L48 59L59 47L58 68L37 68Z', 'url(#cloth)')
        body += ellipse(48, 34, 15, 16, '#ddb990', INK)
        body += path('M24 29L34 19Q48 9 61 19L75 31Q51 39 24 29Z', 'url(#gold)')
        body += path('M36 20L58 21', 'none', '#5d4b47', 4)
        body += eyes(48, 37, 7, row in (3, 4))
        body += group(ellipse(72, 59, 8, 10, '#426f73', INK) + path('M67 53Q72 44 77 53', 'none', GOLD, 2), f'rotate({action} 64 53)')
        body += ellipse(29, 57, 5, 5, '#ddb990', INK)
    return body


def creature(kind, frame, row):
    swing = (0, 7, 0, -7)[frame]
    pulse = (0, -2, -4, 1)[frame] if row == 2 else 0
    if kind == 'wanderer':
        body = ''
        for side in (-1, 1):
            for j in range(3):
                body += path(f'M{48+side*14} {44+j*10}L{48+side*28} {42+j*10+swing*(j%2*2-1)*.4}L{48+side*31} {51+j*10}', 'none', '#b9b48a', 4)
        body += ellipse(48, 53, 22, 25, 'url(#jade)', INK)
        body += path('M48 30L48 77', 'none', INK, 2)
        body += path('M31 43Q35 34 42 35M31 52Q35 43 42 44', 'none', '#a6d8ba', 3)
        body += ellipse(48, 31, 13, 12, '#334b5a', INK)
        body += path(f'M40 25L{34-swing*.2} {15+pulse}M56 25L{62+swing*.2} {15+pulse}', 'none', GOLD, 3)
        body += eyes(48, 31, 6, row in (3, 4))
        body += ellipse(42, 30, 2, 2, GOLD) + ellipse(54, 30, 2, 2, GOLD)
        return body
    if kind == 'charger':
        body = ellipse(31, 69+swing*.4, 8, 7, '#403e48', INK) + ellipse(63, 69-swing*.4, 8, 7, '#403e48', INK)
        body += path('M26 48Q18 29 36 22L39 35M60 32L64 19Q81 28 71 48', '#a87b70')
        body += ellipse(48, 49, 27, 25, '#896359', INK)
        body += path('M30 34L35 22L42 27L47 17L52 27L60 23L65 37', '#4e4247')
        body += path('M27 51L30 66Q38 70 38 55M68 51L65 66Q57 70 57 55', '#efe2bc')
        body += ellipse(48, 58+pulse, 15, 10, '#c29583', INK)
        body += ellipse(42, 58+pulse, 2, 3, '#654c4d') + ellipse(54, 58+pulse, 2, 3, '#654c4d')
        body += eyes(48, 44, 13, row in (3, 4))
        body += path('M30 38L39 41M57 41L66 38', 'none', '#332f3b', 3)
        return body
    if kind == 'ranger':
        body = path(f'M48 42Q{38+swing} 60 48 77M46 62Q25 49 25 65Q33 75 47 70M49 59Q72 47 73 64Q62 75 48 69', '#4b9280', INK, 3)
        for j in range(6):
            a = j*pi/3
            body += group(ellipse(48, 19, 11, 17, '#c797aa', INK), f'rotate({j*60+swing/2} 48 39)')
        body += ellipse(48, 39, 16, 16, 'url(#gold)', INK)
        body += eyes(48, 38, 6, row in (3, 4))
        body += ellipse(48, 47, 4+(3 if row == 2 else 0), 3, INK)
        body += group(path('M70 36Q87 56 70 76M70 36L70 76M61 56L85 56L79 52M85 56L79 60', 'none', GOLD, 2), f'translate({pulse} 0)')
        return body
    if kind == 'splitter':
        body = path(f'M22 67Q19 {40+pulse} 37 33L42 19L52 32Q73 35 76 66Q68 81 47 79Q25 80 22 67Z', 'url(#jade)')
        body += path('M30 43L42 31L40 57L27 67Z', '#98dcce', 'none')
        body += path('M46 38L56 20L63 41L53 53Z', '#a3dce2')
        body += path('M56 20L56 41L63 41M46 38L56 41L53 53', 'none', '#ddf6e7', 1)
        body += ellipse(38, 49, 4, 7, '#c9ede0')
        body += eyes(49, 62, 10, row in (3, 4))
        return body
    body = path('M29 61L22 79L41 79L45 68M55 66L57 79L76 79L67 59', '#526978')
    wing = (0, -10, -25, -5)[frame] if row == 2 else swing/2
    body += group(path('M33 31Q12 33 12 58L22 72L34 63L42 41Z', 'url(#stone)') + path('M21 40L19 58L25 63M28 41L27 54', 'none', '#c3c4ad', 2), f'rotate({wing} 34 36)')
    body += group(path('M62 31Q84 33 84 58L74 72L62 63L54 41Z', 'url(#stone)') + path('M75 40L77 58L71 63M68 41L69 54', 'none', '#c3c4ad', 2), f'rotate({-wing} 62 36)')
    body += path('M27 15L42 23L54 23L69 15L69 46Q74 68 48 76Q21 69 27 46Z', 'url(#stone)')
    body += path('M30 29L45 34L48 46L35 54L28 45ZM66 29L51 34L48 46L61 54L68 45Z', '#263e52', '#c2c6b0', 2)
    body += ellipse(37, 40, 6, 7, 'url(#gold)') + ellipse(59, 40, 6, 7, 'url(#gold)')
    body += eyes(48, 40, 11, row in (3, 4))
    body += path('M43 48L53 48L48 59Z', GOLD)
    body += path('M36 63L43 67L48 62L54 67L61 62M38 27L45 22M53 22L58 27', 'none', '#bfd6ba', 2)
    body += path('M45 13L48 7L51 13L48 19Z', '#c6f1bf', GOLD, 1)
    return body


def characters():
    for kind in ('hero', 'wanderer', 'charger', 'ranger', 'splitter', 'boss', 'villager', 'merchant'):
        sheet = ''
        for row in range(5):
            for frame in range(4):
                shadow = ellipse(48, 79, 26, 7, '#091b29', 'none')
                body = human(kind, frame, row) if kind in ('hero', 'villager', 'merchant') else creature(kind, frame, row)
                bob = (0, -1.5, 0, 1)[frame]
                turn = (0, -3, 3, 0)[frame] if row == 3 else 0
                alpha = 1
                if row == 4:
                    turn = (0, 15, 47, 76)[frame]
                    alpha = (1, 1, .8, .45)[frame]
                    body = group(body, f'translate(48 64) rotate({turn}) scale({1-frame*.06}) translate(-48 -64)', alpha)
                else:
                    body = group(body, f'translate(0 {bob}) rotate({turn} 48 60)')
                if row == 3 and frame in (1, 2):
                    body += path('M16 25L22 30M78 23L73 29M47 9L47 16', 'none', '#fff0bd', 3)
                sheet += group(shadow+body, f'translate({frame*96} {row*96})')
        save(f'characters/{kind}.svg', svg(sheet, 384, 480))


def props():
    items = {
        'chest': path('M19 44Q20 24 48 24Q76 24 77 44L77 73L19 73Z', '#785146') + rect(20, 44, 56, 28, '#a27351') + path('M29 30L29 72M66 30L66 72M19 46L77 46', 'none', GOLD, 5) + rect(42, 43, 12, 17, 'url(#gold)') + ellipse(48, 50, 2, 3, INK),
        'grass': ''.join(path(f'M48 81Q{18+i*9} 51 {15+i*11} {28+(i%2)*12}Q{45+i*3} 41 48 81Z', ['#347d70','#60ad88','#88b799'][i%3]) for i in range(6)),
        'rock': path('M14 66L21 37L39 24L68 30L83 57L73 75L34 81Z', 'url(#stone)') + path('M21 37L44 44L68 30M44 44L47 66L73 75M47 66L14 66', 'none', '#405c68', 2) + path('M26 37L40 30L60 33', 'none', '#c0c9b7', 3),
        'block': path('M16 30L34 17L80 25L79 71L62 84L16 75Z', '#536b74') + path('M16 30L62 37L80 25M62 37L62 84', 'none', '#bfd0bc', 2) + path('M25 41L53 45L53 69L25 66Z', '#344d60', '#93b4a6', 2) + path('M33 49L46 51L45 61L33 59Z', 'none', GOLD, 2),
        'switch': ellipse(48, 65, 31, 16, '#344855', INK) + ellipse(48, 59, 28, 15, '#728f86', INK) + ellipse(48, 53, 19, 11, 'url(#gold)', INK) + path('M39 53L47 47L57 53L48 59Z', '#6f7958'),
        'door': path('M15 84L15 31Q48 -2 81 31L81 84Z', 'url(#stone)') + path('M26 84L26 37Q48 12 70 37L70 84Z', '#182d3f') + path('M32 82L32 39Q48 22 64 39L64 82Z', '#5d6155', GOLD, 2) + path('M48 30L48 82M35 51L61 51M35 69L61 69', 'none', '#192d39', 3) + ellipse(54, 60, 3, 4, GOLD),
        'heart': path('M48 77Q9 52 18 32Q29 11 48 32Q67 11 78 32Q87 52 48 77Z', '#d88681', '#663f55', 3) + path('M25 39Q25 27 36 28', 'none', '#ffd0aa', 5),
        'coin': ellipse(48, 49, 23, 29, 'url(#gold)', '#8b6442', 3) + ellipse(48, 48, 17, 22, 'none', '#fff0b1', 2) + path('M48 32L56 48L48 64L40 48Z', '#a57748', '#ffeeb0', 1),
        'key': ellipse(35, 35, 16, 16, 'url(#gold)', INK) + ellipse(35, 35, 7, 7, '#243e4c') + path('M43 44L71 73L77 66L69 59L74 54L68 48L62 53L51 42Z', 'url(#gold)'),
        'boomerang': path('M17 28Q19 18 29 24L54 45L76 20Q85 20 80 34L58 73L48 77L20 39Z', 'url(#gold)') + path('M24 30L52 59L76 30', 'none', '#70584d', 3) + path('M44 55L56 48M48 62L61 52', 'none', '#e8dfb3', 3),
        'bomb': ellipse(48, 56, 26, 27, 'url(#cloth)', INK) + rect(41, 25, 14, 12, '#727d80') + path('M48 27Q43 12 64 17', 'none', '#caac79', 4) + path('M65 17L72 9M66 18L79 19M64 17L63 7', 'none', GOLD, 3) + ellipse(38, 44, 6, 9, '#567e8c'),
        'potion': path('M36 19L60 19L57 38Q79 55 68 75Q48 90 28 75Q17 55 39 38Z', '#a9d9c8') + path('M28 59Q48 65 69 57L67 73Q48 84 30 73Z', '#55a482', 'none') + rect(36, 17, 24, 12, 'url(#gold)') + path('M48 47L48 67M39 57L57 57', 'none', '#e6edd0', 5),
        'treasure': ellipse(48, 51, 39, 39, 'url(#glow)') + path('M28 35L48 16L69 35L62 66L48 80L34 65Z', 'url(#gold)') + path('M28 35L48 43L69 35M48 16L48 43L48 80M34 65L48 43L62 66', 'none', '#fff1b8', 2) + path('M40 36L48 28L56 36L48 57Z', '#67b7a3', '#d6efd0', 2),
    }
    for name, body in items.items():
        save(f'props/{name}.svg', svg(ellipse(48, 81, 29, 6, '#102932')+body))


def terrain():
    rng = random.Random(44)
    tile = ''
    for k, color in enumerate(('#284c47', '#847d62', '#364e5b', '#244657')):
        body = rect(0, 0, 64, 64, color, 'none', 0)
        if k == 0:
            for _ in range(15):
                x,y=rng.randrange(4,60),rng.randrange(4,60)
                body += path(f'M{x-2} {y+2}L{x} {y-2}L{x+3} {y}', 'none', '#3e6657', 1)
        if k == 1:
            for _ in range(11):
                body += ellipse(rng.randrange(4,60),rng.randrange(4,60),rng.randrange(1,4),1,'#a39a78')
        if k == 2:
            body += path('M0 0H64V64H0ZM0 32H64M32 0V32M16 32V64M53 32V64', 'none', '#223b4c', 2)
            body += path('M3 4H28M36 4H59M3 36H12M20 36H49', 'none', '#516d70', 1)
        if k == 3:
            for y in (12,32,52):
                body += path(f'M4 {y}Q14 {y-4} 24 {y}T44 {y}T64 {y}', 'none', '#3b6470', 1.5)
        tile += group(body, f'translate({k*64} 0)')
    save('terrain/tiles.svg', svg(tile,256,64))


def backgrounds():
    rng=random.Random(81)
    sky=rect(0,0,1280,720,'url(#sky)','none',0)
    sky+=ellipse(886,167,150,150,'url(#glow)')+ellipse(886,167,58,58,'#e5d9ae')+ellipse(868,151,52,53,'#294059')
    for _ in range(90):
        sky+=ellipse(rng.randrange(20,1260),rng.randrange(16,470),rng.choice((.7,1,1.4)),1,'#9eafa9')
    far=''
    for x,y,w,h in ((70,365,200,165),(310,330,190,170),(650,360,210,140),(918,312,260,225)):
        far+=path(f'M{x} {y+100}Q{x+w*.2} {y-55} {x+w*.5} {y}Q{x+w*.8} {y-50} {x+w} {y+110}L{x+w*.7} {y+h}L{x+w*.35} {y+h+25}Z','#263f50','none')
    mid=path('M0 569Q149 482 305 556Q503 442 703 555Q901 476 1114 512L1280 570V720H0Z','#203c44','none')
    mid+=path('M518 606L560 493L721 493L768 606Z','#58695f','none')
    mid+=path('M548 546L739 546M536 568L750 568M526 590L760 590','none','#b3b38c',3)
    mid+=path('M570 489V266Q642 196 709 266V489L679 489V281Q642 244 601 281V489Z','url(#stone)','#182f3e',3)
    mid+=path('M582 283L584 478M694 282L694 477M586 267Q640 218 696 266','none','#b6c6aa',3)
    mid+=ellipse(640,380,115,145,'url(#glow)')
    mid+=path('M618 431L640 335L661 431L653 477L628 477Z','url(#gold)','#b8b794',2)
    mid+=path('M630 370L640 350L650 370L640 413Z','#edf6c5','none')
    front=path('M0 657Q159 590 292 671L445 720H0ZM813 720Q1050 586 1280 633V720Z','#122c36','none')
    for x in (44,128,1160,1232):
        front+=path(f'M{x} 720Q{x-30} 552 {x+10} 425L{x+28} 420Q{x+7} 539 {x+36} 720Z','#142e3b','none')
        for j in range(5):
            y=440+j*35
            front+=path(f'M{x+14} {y+37}Q{x-95} {y+11} {x-111} {y-32}Q{x-30} {y-20} {x+14} {y+13}Q{x+73} {y-26} {x+113} {y-17}Q{x+92} {y+29} {x+14} {y+37}Z','#193c43','none')
    for _ in range(32):
        x,y=rng.randrange(70,1210),rng.randrange(470,720)
        front+=ellipse(x,y,2,2,'#a9c79a')
    save('backgrounds/distant.svg',svg(sky+far,1280,720))
    save('backgrounds/middle.svg',svg(mid,1280,720))
    save('backgrounds/foreground.svg',svg(front,1280,720))
    save('backgrounds/title.svg',svg(sky+far+mid+front,1280,720))


SR=22050


def note(buffer, start, duration, midi, volume, voice='bell', pan=0):
    """固定した譜面を循環加算する。音声合成の加算は音符の重なりを表すため非冪等。"""
    freq=440*2**((midi-69)/12)
    length=int(SR*duration)
    base=int(start*SR)
    n=len(buffer)//2
    left,right=(1-pan)*.5,(1+pan)*.5
    for i in range(length):
        t=i/SR
        attack=min(t/.012,1)
        release=min((duration-t)/.055,1)
        phase=2*pi*freq*t
        if voice=='pad':
            sound=(sin(phase)+.28*sin(phase*2+.15*sin(t*3))+.11*sin(phase*3))*.6
            envelope=min(t/.14,1)*release
        elif voice=='flute':
            sound=sin(phase+.008*sin(t*31))+.16*sin(phase*2)+.06*sin(phase*3)
            envelope=attack*release*(.75+.25*sin(pi*t/duration))
        elif voice=='pluck':
            sound=sin(phase)+.42*sin(phase*2)+.22*sin(phase*3)+.1*sin(phase*4)
            envelope=attack*exp(-t*5/duration)*release
        elif voice=='bass':
            sound=sin(phase)+.2*sin(phase*2)
            envelope=attack*release*exp(-t*1.4)
        else:
            sound=sin(phase)*exp(-t*2)+.45*sin(phase*2.76)*exp(-t*5)+.16*sin(phase*5.4)*exp(-t*8)
            envelope=attack*release
        value=sound*envelope*volume
        index=((base+i)%n)*2
        buffer[index]+=value*left
        buffer[index+1]+=value*right


def drum(buffer, start, volume, seed, sharp=False):
    """独自打楽器波形を加算する。譜面イベントとして重ねるため非冪等。"""
    rng=random.Random(seed)
    n=len(buffer)//2
    for i in range(int(SR*.18)):
        t=i/SR
        sound=(rng.uniform(-1,1)*(.8 if sharp else .15)+sin(2*pi*(80*t-90*t*t))) * exp(-t*(36 if sharp else 22))*volume
        j=((int(start*SR)+i)%n)*2
        buffer[j]+=sound*.5
        buffer[j+1]+=sound*.5


def write_wav(name, buffer):
    peak=max(abs(v) for v in buffer) or 1
    gain=.76/peak
    pcm=array('h',(int(max(-1,min(1,v*gain))*32767) for v in buffer))
    if sys.byteorder!='little':
        pcm.byteswap()
    dest=ROOT/'audio'/f'{name}.wav'
    dest.parent.mkdir(parents=True,exist_ok=True)
    with wave.open(str(dest),'wb') as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(SR)
        out.writeframes(pcm.tobytes())


def audio():
    configs={
        'title':(84,[50,46,53,48],[74,77,81,79,77,74,72,69],'bell'),
        'field':(112,[50,53,48,46],[74,77,79,81,79,77,72,74],'flute'),
        'dungeon':(72,[38,41,36,37],[62,65,69,68,65,62,61,57],'bell'),
        'boss':(138,[38,37,41,36],[62,65,68,69,68,65,61,60],'pluck'),
        'result':(96,[53,48,50,46],[77,81,84,86,84,81,79,77],'flute'),
    }
    for name,(bpm,roots,melody,voice) in configs.items():
        beat=60/bpm
        duration=beat*32
        buf=array('f',[0])*(int(SR*duration)*2)
        for bar in range(8):
            root=roots[bar%4]
            at=bar*4*beat
            for interval in (0,7,15):
                note(buf,at,beat*4,root+12+interval,.105,'pad',(interval-7)/13)
            for k in range(4):
                note(buf,at+k*beat,beat*.78,root,.19,'bass',0)
                if name!='title':
                    drum(buf,at+k*beat,.11,bar*20+k,k%2==1)
            for k in range(8):
                pitch=root+24+(0,7,12,15,12,7,15,7)[k]
                note(buf,at+k*beat*.5,beat*.95,pitch,.10,'pluck',(-.55 if k%2 else .55))
            for k in range(4):
                pitch=melody[(bar*2+k)%8]+(12 if name=='title' and bar>=4 else 0)
                note(buf,at+k*beat,beat*(1.6 if k==3 else .85),pitch,.20,voice,-.13)
                note(buf,at+k*beat+beat*.75,beat*1.5,pitch,.045,'bell',.65)
        write_wav(name,buf)
    for name in ('sword','tool','hurt','door','chest','defeat'):
        duration={'sword':.28,'tool':.5,'hurt':.4,'door':.8,'chest':1.3,'defeat':1.6}[name]
        buf=array('f',[0])*(int(SR*duration)*2)
        if name=='chest':
            for k,pitch in enumerate((74,78,81,86)):
                note(buf,k*.14,.68,pitch,.35,'bell',k*.2-.3)
        elif name=='defeat':
            for k,pitch in enumerate((62,58,55,50)):
                note(buf,k*.2,.65,pitch,.3,'pad',0)
        elif name=='tool':
            for k,pitch in enumerate((81,86,93)):
                note(buf,k*.10,.25,pitch,.28,'pluck',k*.3-.3)
        elif name=='door':
            drum(buf,.04,.3,4)
            note(buf,.08,.6,43,.45,'bass')
            note(buf,.24,.4,55,.3,'bell')
        else:
            drum(buf,.01,.7,18,name=='sword')
            note(buf,.015,duration*.8,86 if name=='sword' else 40,.3,'pluck')
        # 単発音は循環再生しないので両端をフェードさせる。
        for i in range(len(buf)//2):
            fade=min(1,i/(SR*.006),(len(buf)//2-1-i)/(SR*.04))
            buf[i*2]*=fade
            buf[i*2+1]*=fade
        write_wav(name,buf)


if __name__=='__main__':
    characters()
    props()
    terrain()
    backgrounds()
    if '--visual-only' not in sys.argv:
        audio()
    print('素材を再生成しました')
