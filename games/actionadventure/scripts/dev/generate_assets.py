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
    keyart=ellipse(48,79,26,7,'#091b29')+human('hero',2,0)
    save('backgrounds/hero-keyart.svg',svg(group(keyart,'scale(5)'),480,480))
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


def scenery():
    """装飾は透過の独立画像とし、ゲームの当たり判定には干渉しない。"""
    # 葉冠の輪郭・葉脈・枝を重ね、遠くからも樹木の塊と接地が読めるようにする。
    tree=ellipse(130,228,103,20,'#102c33')
    tree+=path('M113 143L149 143Q139 184 155 213L179 231L144 225L133 214L114 232L80 231Z','#6d6351',INK,3)
    tree+=path('M122 164L119 208M135 172L139 212M114 215L101 224','none','#aa9168',3)
    tree+=path('M124 177L80 137L78 120L129 152L167 108L180 112L148 171Z','#5b6553',INK,3)
    for x,y,scale,color in ((76,113,.95,'#285d53'),(176,111,.92,'#285851'),(124,77,1.18,'#347462'),(61,78,.74,'#397967'),(192,79,.68,'#306c60'),(127,37,.72,'#438675')):
        leaf=path('M-56 17Q-66 -3 -49 -16Q-52 -39 -24 -42Q-8 -63 12 -42Q35 -50 45 -25Q68 -13 52 13Q59 32 33 40Q5 55 -11 43Q-44 48 -56 17Z',color,INK,2.5)
        leaf+=path('M-40 -14Q-30 -32 -10 -30Q6 -44 20 -28M5 7Q24 -1 39 10M-40 17Q-26 26 -13 20','none','#71ac87',3)
        leaf+=path('M-25 -7L-16 -12L-6 -8M16 24L26 19L34 22','none','#9fc298',2)
        tree+=group(leaf,f'translate({x} {y}) scale({scale})')
    for x,y in ((47,113),(97,62),(158,98),(185,55),(114,127)):
        tree+=ellipse(x,y,3,4,GOLD)
    save('scenery/tree.svg',svg(tree,256,256))

    house=ellipse(165,229,140,22,'#102b34')
    house+=path('M34 205L222 205L288 181L293 215L228 247L33 234Z','#40545c')
    house+=path('M40 214L228 225L282 204M81 215L79 232M148 221L148 239M229 226L230 242','none','#879383',2)
    house+=path('M43 110L224 112L224 219L43 211Z','#b4ae8a',INK,3)
    house+=path('M224 112L276 82L276 194L224 219Z','#777f69',INK,3)
    house+=path('M44 145L223 152M44 192L223 201M58 113L58 211M208 117L208 216','none','#615f50',5)
    house+=path('M23 117L84 36L257 37L225 128Z','url(#cloth)',INK,4)
    house+=path('M225 128L257 37L296 86L278 94L258 68L239 131Z','#386871',INK,3)
    for y in (57,77,98):
        x=84-(y-36)*.75
        end=257-(y-37)*.35
        house+=path(f'M{x:.1f} {y}L{end:.1f} {y+5}','none','#699796',3)
        for j in range(6):
            px=x+13+j*26
            if px<end-5:
                house+=path(f'M{px:.1f} {y}l-8 16','none','#203e50',2)
    house+=path('M24 117L224 129L240 128M83 36L257 37','none','#ccbf8b',5)
    house+=rect(143,55,28,36,'#637973',INK,3)+path('M139 57L142 44L173 44L176 57Z','#a1b19a')
    house+=path('M99 211L99 167Q121 138 143 168L143 214Z','#3a4548',INK,3)
    house+=path('M106 207L106 170Q121 153 136 171L136 210Z','#735e49','#bda476',2)
    house+=path('M121 163V209M108 188L135 188','none','#b79b6c',2)
    house+=ellipse(131,191,2.5,3,GOLD)
    for x,y in ((66,154),(167,158)):
        house+=rect(x,y,25,28,'url(#gold)',INK,3)
        house+=path(f'M{x+12} {y}v28M{x} {y+13}h25','none','#5e6354',3)
        house+=rect(x-4,y+28,33,7,'#526d5d',INK,2)
        for j in range(4):
            house+=path(f'M{x+j*7} {y+31}q-5 -11 1 -15q7 5 3 15','#608b63','none')
    house+=path('M246 137L263 128L263 151L246 160Z','url(#gold)',INK,2)
    house+=path('M254 133V156','none','#56645a',2)
    house+=path('M37 197L35 158L24 156','none','#858d72',3)
    house+=ellipse(25,172,27,31,'url(#glow)')+rect(18,158,14,23,'url(#gold)')
    house+=path('M49 202Q60 188 74 201M174 211Q181 198 196 208','none','#648164',5)
    save('scenery/house.svg',svg(house,320,256))

    stall=ellipse(128,169,112,18,'#102c33')
    stall+=path('M35 53L39 169M214 51L210 167','none','#776a52',8)
    stall+=path('M34 51L217 51','none','#d4b57b',5)
    stall+=path('M38 26L201 26L236 87L19 87Z','#c5b287',INK,3)
    for j in range(6):
        x=38+j*27
        low=19+j*36
        if j%2==0:
            stall+=path(f'M{x} 27h27L{low+36} 87H{low}Z','#4c8d80','none')
        stall+=path(f'M{low} 87h36v12q-18 13 -36 0Z','#71a490' if j%2==0 else '#ddc998',INK,2)
    stall+=path('M38 27L201 27','none',GOLD,4)
    stall+=path('M42 136L209 136L209 167L42 167Z','#886c50',INK,3)
    stall+=path('M35 122L214 122L222 140L34 140Z','#c5a16b',INK,3)
    stall+=path('M47 144L47 162M76 144V164M106 144V164M137 144V164M168 144V164M199 144V164','none','#bea473',2)
    for x in (60,82,104):
        stall+=ellipse(x,122,10,5,'#263f48')
        stall+=path(f'M{x-6} 121L{x-4} 102H{x+4}L{x+7} 121Z','#7eae92',INK,1.5)
        stall+=rect(x-4,100,8,5,GOLD,INK,1)
    stall+=rect(135,106,56,20,'#745d4c',INK,2)
    for j in range(4):
        stall+=ellipse(143+j*13,108,6,6,['#dba875','#bc7970','#b4bc78','#dba875'][j],INK,1)
    stall+=path('M216 109L216 133','none','#d3b379',2)+rect(204,115,23,18,'#294c52',GOLD,2)
    stall+=path('M211 121L219 124L211 128','none',GOLD,2)
    save('scenery/stall.svg',svg(stall,256,192))

    crystals=ellipse(96,139,85,15,'#102b35')
    for x,y,w,h,c in ((39,131,28,62,'#63999a'),(134,130,34,72,'#487d8e'),(76,133,43,110,'#85c6bb'),(109,141,29,67,'#b4d5c7')):
        crystals+=path(f'M{x-w/2} {y-14}L{x-w/2} {y-h+22}L{x} {y-h}L{x+w/2} {y-h+22}L{x+w/2} {y-14}L{x} {y}Z',c,INK,2.5)
        crystals+=path(f'M{x} {y-h}V{y}M{x-w/2} {y-h+22}L{x} {y-h+32}L{x+w/2} {y-h+22}','none','#d2eed6',2)
        crystals+=path(f'M{x+2} {y-h+35}L{x+w/2-2} {y-h+25}V{y-16}L{x+2} {y-4}Z','#497c85','none')
        crystals+=path(f'M{x-w/2+5} {y-h+29}V{y-h+46}','none','#eff8d4',3)
    for x,y in ((23,141),(158,138),(128,147),(56,148)):
        crystals+=path(f'M{x-9} {y}L{x-3} {y-12}L{x+7} {y-7}L{x+10} {y+2}Z','#658d86',INK,1.5)
    crystals+=ellipse(76,48,30,30,'url(#glow)')
    save('scenery/crystals.svg',svg(crystals,192,160))

    ruins=ellipse(128,167,114,18,'#102c33')
    ruins+=path('M21 152L199 152L233 168L218 180L31 180L13 170Z','#425b62')
    ruins+=path('M30 149L30 55L69 41L112 48L112 91L151 84L151 59L191 64L205 152Z','url(#stone)',INK,3)
    ruins+=path('M31 56L68 64L112 49M68 64V151M112 91L112 153M151 85L153 153','none','#2f4854',3)
    for y in (82,107,132):
        ruins+=path(f'M32 {y}L68 {y+6}L110 {y-4}M115 {y+8}L151 {y}L200 {y+5}','none','#334f59',2)
        ruins+=path(f'M37 {y-3}L62 {y+1}M76 {y}L105 {y-7}','none','#acb9a1',1.5)
    ruins+=path('M78 43L82 73L94 83L88 101M168 68L173 91L166 104L178 124','none','#233e4b',2)
    ruins+=path('M145 149L160 127L202 132L217 155L198 168L158 166Z','#718b85')
    ruins+=path('M160 128L178 149L216 155M178 149L174 165','none','#b6bfa7',2)
    ruins+=path('M27 65Q41 47 70 49Q94 40 109 52M137 91Q150 71 185 72','none','#638566',8)
    ruins+=path('M48 49Q37 75 52 94Q62 114 44 139','none','#7c9a6a',4)
    for x,y in ((43,72),(52,91),(54,111),(45,128),(152,76),(172,73)):
        ruins+=path(f'M{x} {y}q-18 -12 -17 0q8 11 17 0q12 -17 16 -9q3 11 -16 9','#829a66',INK,1)
    save('scenery/ruins.svg',svg(ruins,256,192))

    column=ellipse(48,144,41,11,'#102b33')
    column+=path('M16 127L72 124L83 139L70 149L20 148L10 139Z','#667f7e')
    column+=path('M26 39L67 37L68 129L53 138L26 130Z','url(#stone)',INK,3)
    column+=path('M54 39V137M34 51V121M43 53V126M62 49V124','none','#b1bda9',2)
    column+=path('M20 34L30 18L70 21L78 36L68 49L22 43Z','#8da299',INK,3)
    column+=path('M25 33L68 38L75 31M68 38V47','none','#d0ceb0',2)
    column+=path('M32 20L38 8L56 11L68 22Z','#5f7c76')
    column+=path('M29 77L46 82L46 103L29 97Z','#31545a','#c9c099',1.5)
    column+=path('M37 85L41 92L37 97L33 90Z',GOLD,'none')
    column+=path('M16 134Q26 120 35 131M53 137Q64 124 77 133','none','#77926a',5)
    save('scenery/column.svg',svg(column,96,160))

    lily=''
    for x,y,rx,ry,c in ((40,63,31,14,'#3e776d'),(87,40,25,12,'#57917c'),(90,74,29,13,'#447e6d')):
        lily+=ellipse(x,y+3,rx+5,ry+3,'#183e4c')
        lily+=path(f'M{x} {y}L{x+rx} {y-2}A{rx} {ry} 0 1 0 {x+rx-4} {y+6}Z',c,INK,1.5)
        lily+=path(f'M{x-rx+6} {y-2}Q{x-8} {y-ry+2} {x+rx-8} {y-3}','none','#8bb399',1.5)
    for j in range(7):
        lily+=group(path('M46 46Q24 30 38 26Q51 26 46 46Z','#d4b5b5',INK,1.2),f'rotate({j*51} 46 46)')
    lily+=ellipse(46,46,7,5,GOLD,INK,1)
    lily+=path('M82 37L89 23L96 37L89 44Z','#b7c7a5',INK,1)
    save('scenery/lily.svg',svg(lily,128,96))

    arch=ellipse(162,232,144,20,'#102c33')
    arch+=path('M24 218L270 209L302 226L287 242L33 246L13 233Z','#4e6b70',INK,3)
    arch+=path('M32 218L32 84L78 37L142 18L206 32L265 74L279 215L226 222L218 93Q160 45 96 97L95 225Z','url(#stone)',INK,4)
    arch+=path('M49 212L49 88L90 53L142 35L199 48L248 84L262 211','none','#bcc7a9',4)
    arch+=path('M97 97L79 84M120 79L112 47M148 68L147 35M176 72L188 46M202 85L228 65M218 98L249 87','none','#314c58',3)
    for y in (119,151,185):
        arch+=path(f'M34 {y}L95 {y+7}M225 {y+3}L272 {y-5}','none','#314c58',3)
        arch+=path(f'M42 {y-3}L88 {y+2}M232 {y}L262 {y-5}','none','#a6baa5',1.5)
    arch+=path('M33 218L95 224L102 232L26 235Z','#739085')
    arch+=path('M224 217L277 209L285 221L222 231Z','#739085')
    arch+=path('M137 37L160 19L181 39L159 59Z','#2e5059',GOLD,2)
    arch+=path('M158 28L168 38L159 51L151 39Z','#9bd5b7',GOLD,1.5)
    for x in (62,247):
        arch+=rect(x-10,146,20,25,'#294b56','#9fba9e',1)
        arch+=path(f'M{x} 151L{x+5} 158L{x} 166L{x-5} 158Z',GOLD,'none')
    arch+=path('M44 80Q68 46 116 36M211 41Q238 46 262 76M40 203Q65 194 85 211','none','#678b69',9)
    arch+=path('M83 48Q68 71 79 103Q89 128 72 151','none','#8caa79',4)
    for x,y in ((79,58),(77,85),(82,107),(80,126),(73,145),(230,51),(247,63)):
        arch+=path(f'M{x} {y}q-15 -16 -19 -6q0 11 19 6q16 -14 19 -4q-4 10 -19 4','#84a071',INK,1)
    arch+=path('M117 226L117 191L133 186L138 221M179 222L191 196L206 203L213 222','#49676a',INK,2)
    save('scenery/arch.svg',svg(arch,320,256))


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
    scenery()
    if '--visual-only' not in sys.argv:
        audio()
    print('素材を再生成しました')
