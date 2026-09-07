#!/usr/bin/env python3
"""黄昏の灯砦の独自図案を固定 seed で冪等に再生成する。"""
from pathlib import Path
import math
import random
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen

ROOT = Path(__file__).resolve().parents[2] / 'assets'
INK = '#172e38'
GOLD = '#e5bd70'
LIGHT = '#fff1bf'
DEFS = '''<defs>
<linearGradient id="stone" x2=".7" y2="1"><stop stop-color="#678991"/><stop offset=".5" stop-color="#314f62"/><stop offset="1" stop-color="#182f45"/></linearGradient>
<linearGradient id="gold" x2=".8" y2="1"><stop stop-color="#fff1bf"/><stop offset=".5" stop-color="#dfaa56"/><stop offset="1" stop-color="#976034"/></linearGradient>
<linearGradient id="leaf" x2=".6" y2="1"><stop stop-color="#90b38a"/><stop offset="1" stop-color="#345f53"/></linearGradient>
<linearGradient id="fur" x2=".8" y2="1"><stop stop-color="#f3b276"/><stop offset=".55" stop-color="#cf754c"/><stop offset="1" stop-color="#703d43"/></linearGradient>
<linearGradient id="ice" x2=".6" y2="1"><stop stop-color="#e2ffec"/><stop offset=".45" stop-color="#87ded9"/><stop offset="1" stop-color="#337d9c"/></linearGradient>
<linearGradient id="wing" x2=".8" y2="1"><stop stop-color="#e1c2e2"/><stop offset=".5" stop-color="#9d82bd"/><stop offset="1" stop-color="#564a82"/></linearGradient>
<linearGradient id="sky" x2="0" y2="1"><stop stop-color="#183944"/><stop offset=".5" stop-color="#587d6c"/><stop offset="1" stop-color="#bed3a1"/></linearGradient>
<radialGradient id="glow"><stop stop-color="#ffe8a4" stop-opacity=".8"/><stop offset=".4" stop-color="#e8bd6b" stop-opacity=".23"/><stop offset="1" stop-color="#f4bd5c" stop-opacity="0"/></radialGradient>
</defs>'''


def path(d, fill='none', stroke=INK, width=1.5, extra=''):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round" {extra}/>'


def ellipse(x, y, rx, ry, fill, extra=''):
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}" {extra}/>'


def circle(x, y, r, fill, stroke='none', width=1):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'


def group(content, transform='', extra=''):
    return f'<g transform="{transform}" {extra}>{content}</g>'


def save(name, w, h, content):
    target = ROOT / f'{name}.svg'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{DEFS}{content}</svg>\n')


def glow(x, y, r):
    return circle(x, y, r, 'url(#glow)')


def leaf(x, y, scale, angle, color='url(#leaf)'):
    art = path('M0 0Q-13-13 0-31Q15-14 0 0Z', color, '#3d6655', .8)
    art += path('M0 0V-26M0-9L-5-16M0-15L5-22', stroke='#c4d2a1', width=.7)
    return group(art, f'translate({x} {y}) rotate({angle}) scale({scale})')


def lantern(x, y, scale=1):
    art = glow(0, 0, 28)
    art += path('M-8-9H8L7 12H-7ZM-10-9L0-15L10-9M-9 13H9M0-15V-21', 'url(#gold)', GOLD)
    art += path('M-5-6H5L4 9H-4Z', '#ffde7d', '#644d37', .8)
    art += path('M0-6V9', stroke=LIGHT, width=1)
    return group(art, f'translate({x} {y}) scale({scale})')


def pedestal():
    art = ellipse(64, 111, 39, 10, '#142932', 'opacity=".38"')
    art += path('M30 93L64 79L98 93V106L64 118L30 106Z', 'url(#stone)', '#152a38', 2)
    art += path('M30 93L64 105L98 93M64 105V118M43 98V109M82 99V110', stroke='#86a1a0', width=1)
    art += path('M42 61L64 51L86 61V96L64 104L42 95Z', 'url(#stone)', '#203847', 2)
    art += path('M42 61L64 70L86 61M64 70V104M43 79L63 86L85 79M52 66V82M75 66V82M53 84V98M76 84V99', stroke='#688f96', width=1)
    art += path('M38 57L64 47L90 57V66L64 76L38 66Z', 'url(#gold)', INK)
    art += path('M40 59L64 68L88 59', stroke=LIGHT, width=1)
    art += circle(64, 89, 6, '#1f404c', GOLD)
    art += path('M64 85L67 89L64 93L61 89Z', '#ffd991', 'none')
    return art


def tower(kind, state, frame):
    phase = math.sin((frame + .15) * math.tau / 6)
    attack = (0, .2, 1, .55, .15, 0)[frame] if state == 'attack' else 0
    recoil = attack * 5
    art = pedestal()
    if kind == 'arrow':
        weapon = path('M58 30L68 31L72 62L57 64Z', '#775241', GOLD)
        weapon += path('M23 49Q40 21 62 36Q83 18 106 37L103 45Q82 28 64 45Q40 32 27 56Z', 'url(#gold)', INK, 2)
        weapon += path('M26 53L64 65L104 41M64 65L61 25M57 30L60 17L66 29M61 48L55 57M62 49L69 55', stroke=LIGHT, width=1.3)
        weapon += path('M34 44L39 35M90 33L94 41M49 33L49 42M75 30L77 38', stroke='#88633c', width=2)
        weapon += lantern(80, 61, .5)
        art += group(weapon, f'translate(0 {recoil}) rotate({phase*2} 64 58)')
    elif kind == 'mortar':
        art += path('M35 57L42 76L85 77L93 57L84 47L46 47Z', '#72534c', GOLD, 2)
        barrel = path('M45 64L50 25Q69 10 87 24L83 63Q65 77 45 64Z', 'url(#stone)', GOLD, 2)
        barrel += ellipse(69, 26, 19, 10, '#0f2734', f'stroke="{GOLD}" stroke-width="4"')
        barrel += ellipse(69, 26, 12, 5, '#65483b')
        barrel += path('M48 49Q64 61 85 47M50 34L46 58M81 33L78 60', stroke=GOLD, width=2)
        barrel += circle(64, 54, 7, '#9f5141', GOLD)
        barrel += path('M64 49L67 54L64 59L61 54Z', '#ffe6a5', 'none')
        if attack > .3:
            barrel += glow(69, 21, 26)
            barrel += path('M59 21L56 5L65 11L70 1L75 12L87 6L80 22Z', LIGHT, '#e99c50', 1)
        art += group(barrel, f'translate(0 {recoil}) rotate({phase*1.8} 64 60)')
        art += circle(42, 68, 6, '#3e5963', GOLD, 2) + circle(86, 68, 6, '#3e5963', GOLD, 2)
    elif kind == 'frost':
        art += glow(64, 36, 44)
        for x, y, tilt in [(43, 47, -25), (86, 47, 28), (64, 29, 0)]:
            crystal = path('M0-23L11-5L7 17L0 25L-9 13L-12-5Z', 'url(#ice)', '#baf6e9', 1.4)
            crystal += path('M0-23L-2 1L0 25M-12-5L-2 1L11-5M-2 1L7 17', stroke='#f0ffec', width=.8)
            art += group(crystal, f'translate({x} {y+phase*2-attack*4}) rotate({tilt+phase*4})')
        art += path('M35 59Q64 83 94 59L88 70Q64 89 41 69Z', 'url(#gold)', INK)
        for i in range(5):
            a = (i * math.tau/5) + frame*.2
            art += circle(round(64+math.cos(a)*32, 2), round(40+math.sin(a)*17, 2), 1.7, LIGHT)
    else:
        art += path('M47 65L52 44H76L82 65Z', 'url(#stone)', GOLD, 2)
        art += glow(64, 35, 48)
        ring = ''
        for i in range(12):
            ring += group(path('M0-19L4-27L0-35L-4-27Z', 'url(#gold)', INK, 1), f'rotate({i*30})')
        ring += circle(0, 0, 22, '#b67e42', LIGHT, 1.5)
        ring += circle(0, 0, 16, '#f9d985', '#fff3bc', 2)
        ring += path('M0-12L6-3L12 0L5 5L0 13L-5 5L-12 0L-6-3Z', LIGHT, '#d99e4c', 1)
        ring += circle(0, 0, 4+attack*3, '#fffce0')
        art += group(ring, f'translate(64 {35+phase}) rotate({frame*4+attack*10})')
    return art


def enemy(kind, state, frame):
    phase = math.sin((frame+.15)*math.tau/6)
    stride = phase*8 if state == 'move' else phase*1.2
    attack = (0, -.3, 1, .65, .3, 0)[frame] if state == 'attack' else 0
    art = ellipse(64, 107, 36, 8, '#112d31', 'opacity=".32"')
    if kind == 'runner':
        tail = path('M39 71Q8 80 9 42Q20 61 41 49L52 69Z', 'url(#fur)', INK, 2)
        tail += path('M9 42Q13 51 22 54L15 65Q9 57 9 42Z', '#ffe8b9', INK, 1)
        art += group(tail, f'rotate({phase*12} 40 72)')
        for x, swing in [(43, stride), (72, -stride)]:
            art += path(f'M{x} 77L{x+swing-4} 102L{x+swing+11} 104L{x+swing+8} 98L{x+8} 77Z', '#ac6748', INK, 2)
        art += path('M34 62Q44 43 65 48L91 64L82 86Q54 97 34 77Z', 'url(#fur)', INK, 2)
        head = path('M60 48L63 19L78 32L94 18L95 47L113 60L94 72L71 62Z', 'url(#fur)', INK, 2)
        head += path('M66 28L69 44L77 36M90 27L89 43L82 36', '#473b44', 'none')
        head += path('M71 52L87 57L100 52L108 61L94 69L80 64Z', '#ffe8b9', INK, 1)
        head += path('M75 48L82 47M93 47L98 46', stroke=LIGHT, width=2)
        head += circle(79, 48, 2, INK) + circle(95, 47, 2, INK) + path('M107 57L115 60L108 64Z', INK)
        head += path('M62 58L67 70L87 74L94 69L73 62Z', '#708d65', GOLD, 1)
        art += group(head, f'translate({attack*5} {-phase*2})')
        art += path('M42 61L46 68M47 57L51 64M53 54L57 61', stroke='#f8c994', width=1)
    elif kind == 'armor':
        for x, y, v in [(30, 89, stride), (52, 98, -stride), (79, 94, stride), (92, 78, -stride)]:
            art += path(f'M{x} {y-14}L{x+v-9} {y+9}L{x+v+7} {y+9}L{x+10} {y-10}Z', '#648b78', INK, 2)
            art += path(f'M{x+v-5} {y+5}v4M{x+v} {y+5}v4', stroke=LIGHT, width=.8)
        art += path('M22 80Q19 34 57 24Q87 24 98 61L90 88L59 105L29 96Z', 'url(#leaf)', INK, 2.3)
        art += path('M57 27L70 48L60 73L34 70L28 50ZM70 48L91 54L94 75L77 90L60 73ZM34 70L28 92L54 101L60 73', '#567d6e', '#a7bd88', 2)
        art += path('M42 47L50 40L59 46L56 60L44 61ZM72 65L83 61L87 74L76 81ZM42 83L50 88', stroke='#d5d6a2', width=1)
        art += path('M31 40L38 29L44 35M59 25L64 15L72 29M82 38L94 34L94 48', '#c4c999', INK, 1)
        head = path('M81 74Q98 62 111 77L117 89L111 99L91 96L83 86Z', 'url(#leaf)', INK, 2)
        head += circle(106, 81, 3, '#ffe5a0') + circle(107, 81, 1.2, INK)
        head += path('M100 92L111 93M115 88L119 89', stroke=INK, width=1)
        art += group(head, f'translate({attack*5} {phase})')
    elif kind == 'flyer':
        for side in [-1, 1]:
            wing = path('M0 0Q21-45 47-29L42-14L48-4L29 2L23 14Z', 'url(#wing)', INK, 2)
            wing += path('M0 0L43-27M4 1L41-13M7 4L42-3M14 4L24 13', stroke='#e2c1db', width=1)
            wing += path('M15-13L22-10L31-16L28-22Z', '#f3dfac', '#78658c', 1)
            art += group(wing, f'translate(64 57) scale({side} 1) rotate({phase*17-attack*12})')
        art += path('M53 48Q64 32 76 47L80 78L64 99L49 78Z', '#847299', INK, 2)
        art += path('M54 65L74 65M54 74L74 74M59 84L69 84', stroke='#dac09e', width=2)
        art += path('M54 49L50 31L60 42M72 43L82 30L77 51M60 42L57 29M69 42L73 26', stroke=GOLD, width=1.5)
        art += ellipse(64, 52, 13, 11, '#d4bcd0')
        art += circle(59, 51, 3, '#193947') + circle(70, 51, 3, '#193947')
        art += path('M62 56L66 56L64 62Z', GOLD, INK, .5)
        art += path('M57 89L51 103L63 95L74 102L70 88', '#d9b1c1', INK, 1)
    elif kind == 'swarm':
        for x, s, p in [(37, .64, -stride), (91, .52, stride), (64, .9, stride)]:
            mushroom = path(f'M-12 2L{-13+p*.3} 27L-2 28L1 18L7 28L17 27L12 2Z', '#dbcfa4', INK, 2)
            mushroom += path('M-30 1Q-24-27 0-30Q26-25 31 1Q8 15-30 1Z', '#c27568', INK, 2)
            mushroom += path('M-30 1Q0 13 31 1Q20 21-16 14Z', '#f1d8ab', '#754f51', 1)
            for xx, yy, rr in [(-15, -6, 4), (-3, -21, 4), (13, -11, 5), (0, -3, 3)]:
                mushroom += circle(xx, yy, rr, '#f5d8b0')
            mushroom += ellipse(-5, 16, 1.6, 3, INK) + ellipse(7, 16, 1.6, 3, INK)
            mushroom += path('M-12 5L-8 9M0 7V11M11 6L8 10', stroke='#997c70', width=1)
            art += group(mushroom, f'translate({x+attack*3} {75+phase*3}) rotate({p*.5}) scale({s})')
    else:
        for x, swing in [(41, stride*.6), (77, -stride*.6)]:
            art += path(f'M{x} 75L{x+swing-3} 108L{x+swing+13} 108L{x+14} 72Z', '#384e58', INK, 2)
            art += path(f'M{x+swing-3} 108L{x+swing+13} 108L{x+swing+12} 102L{x+swing} 101Z', '#d4b98a', INK, 1)
        art += path('M33 50Q56 35 83 48L99 67L85 90L56 98L26 78Z', 'url(#stone)', INK, 2)
        art += path('M33 54L43 61L39 77L57 88L77 79L86 61M47 48L53 64L69 69L82 57', stroke='#8da9a0', width=1.5)
        for x, y, a in [(30, 57, -60), (41, 46, -20), (55, 46, 25), (28, 72, -80)]:
            art += leaf(x, y, .65, a)
        head = path('M67 50L65 29L77 20L92 29L101 48L96 69L82 77L69 65Z', '#baa078', INK, 2)
        head += path('M65 33L54 24L56 39L68 44M94 34L111 26L107 42L99 48', '#8e9c7d', INK, 1)
        head += path('M72 30L72 13L60 5M72 18L83 7M66 12L57 13M90 32L95 14L109 5M95 18L91 7M102 11L115 13', stroke='#e3c891', width=3.3)
        head += path('M75 38L79 47L74 54M91 40L87 49L94 53M81 54L90 57L85 63Z', '#526c65', '#647d69', 1)
        head += path('M71 48L79 49M89 49L96 46', stroke='#ffdd91', width=3)
        head += path('M77 63L85 71L93 65M83 64L88 64', stroke=INK, width=1.5)
        art += group(head, f'translate({attack*5} {-phase}) rotate({attack*8} 82 65)')
        art += lantern(52, 64, .5)
    return art


def sheet(kind):
    frames = ''
    for row, state in enumerate(('idle', 'move', 'attack', 'hurt', 'death')):
        for frame in range(6):
            art = tower(kind, state, frame) if kind in ('arrow', 'mortar', 'frost', 'sun') else enemy(kind, state, frame)
            if state == 'hurt':
                art = group(art, f'translate({(0,-5,4,-2,1,0)[frame]} 0)')
                art += path('M30 21L23 13M95 19L102 11', stroke='#fff3c9', width=2) if frame in (1, 2) else ''
            if state == 'death':
                d = frame/5
                art = group(art, f'translate(64 {108+d*6}) scale({1-d*.16} {1-d*.72}) rotate({d*16}) translate(-64 -108)', f'opacity="{1-d*.8}"')
                for i in range(7):
                    art += circle(34+i*10, 77-d*26+(i%3)*8, 1+d*1.7, GOLD)
            art = group(art, 'translate(64 64) scale(.80) translate(-64 -64)')
            frames += group(art, f'translate({frame*128} {row*128})')
    save(f'actors/{kind}', 768, 640, frames)


def pine(x, y, scale, shade):
    art = path('M-3 0L-3-110H3V0Z', '#38534d', 'none')
    for index in range(5):
        yy = -35-index*19
        ww = 38-index*6
        art += path(f'M0 {yy-44}L{-ww} {yy+12}L-13 {yy+8}L-21 {yy+21}L0 {yy+17}L21 {yy+21}L13 {yy+8}L{ww} {yy+12}Z', shade, 'none')
        art += path(f'M0 {yy-28}L{-ww*.64} {yy+4}M0 {yy-16}L{ww*.64} {yy+10}', stroke='#b6c2a0', width=.6, extra='opacity=".15"')
    return group(art, f'translate({x} {y}) scale({scale})')


def background():
    rng = random.Random(39)
    art = path('M0 0H1280V720H0Z', '#496d55', 'none')
    # 地面の細かな草と石は経路配置と独立した静的テクスチャ。
    for _ in range(580):
        x, y = rng.randrange(0, 1280), rng.randrange(0, 720)
        art += ellipse(x, y, rng.randrange(4, 24), rng.randrange(2, 8), rng.choice(['#50755b', '#56795e', '#426750', '#5b7b5e']), 'opacity=".5"')
    for _ in range(280):
        x, y = rng.randrange(0, 1250), rng.randrange(0, 700)
        art += path(f'M{x} {y}l-3-5M{x+2} {y+1}l3-7', stroke='#87a278', width=.7, extra='opacity=".35"')
    for x in range(-20, 1300, 45):
        art += pine(x, 46+rng.randrange(-8, 15), rng.uniform(.65, 1.0), '#284e43')
    for x in range(10, 1290, 130):
        art += lantern(x, 34, .8)
    for x, y in [(18, 165), (14, 370), (18, 595), (945, 180), (944, 412), (944, 604)]:
        art += path(f'M{x-12} {y+12}l5-30l19-4l14 19l-8 20Z', 'url(#stone)', '#2d504b', 1)
        art += leaf(x+8, y-2, .8, -25)
        art += leaf(x-4, y+5, .55, -70)
    save('background', 1280, 720, art)
    foreground = ''
    for x in range(-10, 965, 24):
        y = 722+rng.randrange(0, 10)
        foreground += leaf(x, y, rng.uniform(.8, 1.8), rng.randrange(-45, 45), '#284c42')
        if x % 3 == 0:
            foreground += leaf(x+9, y+3, .8, -40, '#527650')
    save('foreground', 1280, 720, foreground)


def keyart():
    art = path('M0 0H1280V720H0Z', 'url(#sky)', 'none')
    art += glow(848, 215, 305) + circle(849, 182, 56, '#e9d7a3')
    art += path('M0 355L140 214L240 309L365 132L510 309L667 189L820 310L1005 211L1280 359V720H0Z', '#385c59', 'none')
    art += path('M0 465L172 321L313 447L540 297L727 444L882 333L1070 435L1280 325V720H0Z', '#294a48', 'none')
    for x in range(-20, 1300, 60):
        art += pine(x, 480+45*math.sin(x*.011), 1.5, '#2e5146')
    art += path('M0 575Q300 487 569 543Q899 530 1280 426V720H0Z', '#486c51', 'none')
    art += path('M540 720Q750 551 991 495L1040 505Q840 581 763 720Z', '#92a177', 'none')
    # 遠景の灯砦は主役の塔と同じ石と金の意匠を繰り返す。
    fort = path('M-83 140V-56L-59-67V-83H-40V-65L-15-56V140M10 140V-72L40-86V-106H59V-82L83-72V140', 'url(#stone)', '#718c83', 2)
    fort += path('M-90-57L-45-90L-6-57M0-72L48-113L94-72', 'url(#gold)', INK, 2)
    fort += path('M-90 140V55H89V140M-87 55V38H-67V55H-47V38H-27V55H-7V38H13V55H33V38H53V55H73V38H92V140', 'url(#stone)', '#9aad94', 2)
    fort += path('M-12 140V101Q15 72 40 101V140Z', '#182e38', GOLD, 2)
    for x,y in [(-49,-30),(-49,10),(47,-37),(47,7),(-57,88),(65,88)]:
        fort += lantern(x, y, .7)
    fort += path('M-30-80V-148L6-137L-28-123M66-100V-164L105-153L67-140', '#bf7662', GOLD, 1)
    art += group(fort, 'translate(975 369) scale(1.15)')
    art += group(tower('sun', 'idle', 0), 'translate(570 377) scale(2.5)')
    art += group(tower('arrow', 'idle', 1), 'translate(211 469) scale(1.7)')
    art += group(enemy('runner', 'move', 1), 'translate(793 565) scale(1.2)')
    art += group(enemy('flyer', 'move', 2), 'translate(739 198) scale(.8)')
    rng = random.Random(82)
    for _ in range(85):
        x,y = rng.randint(20,1260),rng.randint(330,700)
        art += glow(x,y,5) + circle(x,y,1.1,LIGHT)
    for x in range(-20,1300,100):
        art += pine(x, 800, 1.0, '#163b35') if x<170 or x>1110 else leaf(x,740,2.5,-25,'#274b3c')
    save('keyart',1280,720,art)


def logo():
    font = TTFont(ROOT / 'fonts/ZenKurenaido-Regular.ttf')
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    text = ''
    for i, char in enumerate('黄昏の灯砦'):
        pen = SVGPathPen(glyphs)
        glyphs[cmap[ord(char)]].draw(pen)
        text += group(path(pen.getCommands(), LIGHT, '#bb8b46', 6),
                      f'translate({64+i*105} 148) scale(.105 -.105)')
    art = path('M45 168H589M72 178H562', stroke=GOLD, width=1)
    art += group(lantern(0,0,1.5),'translate(320 38)') + text
    art += path('M32 165L24 153L32 141L40 153ZM602 165L594 153L602 141L610 153Z', GOLD, 'none')
    save('logo',640,195,art)


def interface():
    art = path('M10 1H310L319 10V710L310 719H10L1 710V10Z', '#203c40', GOLD, 2)
    art += path('M11 22V698M309 22V698M22 11H298M22 709H298', stroke='#56786b', width=1)
    for x,y,sx,sy in [(17,17,1,1),(303,17,-1,1),(17,703,1,-1),(303,703,-1,-1)]:
        art += group(path('M0 22V0H22M5 16V5H16M11 0L0 11',stroke=GOLD,width=1),f'translate({x} {y}) scale({sx} {sy})')
    save('ui/panel',320,720,art)
    art = circle(32,32,26,'url(#gold)',INK,2) + circle(32,32,20,'#c38d45','#fff0b7',1.5)
    art += path('M32 15L39 27L49 32L39 37L32 49L25 37L15 32L25 27Z',LIGHT,'#9e693a',1)
    art += circle(32,32,5,'#d79c49')
    save('ui/coin',64,64,art)
    art = path('M32 55C17 44 4 30 8 18Q16 1 32 16Q48 1 57 18C63 32 45 47 32 55Z','#bd7567',GOLD,2)
    art += path('M16 24Q14 15 24 17M13 31L27 45',stroke='#f6bd9a',width=3)
    save('ui/heart',64,64,art)
    art = ellipse(48,37,43,19,'#284c43', 'opacity=".8"')
    art += path('M9 32L48 14L86 32L48 50Z','#607e67','#bdd1a0',1.5)
    art += path('M9 32V40L48 58L86 40V32M48 50V58',fill='none',stroke='#3b5d50',width=2)
    art += path('M48 25V41M40 33H56',stroke='#f2dfac',width=2)
    art += path('M19 33L31 27M65 26L77 32M34 44L45 49M55 48L66 42',stroke='#91a67d',width=1)
    save('ui/site',96,64,art)
    art = ellipse(64,147,55,11,'#132c30','opacity=".4"')
    art += path('M19 66L64 49L110 65V141L64 155L19 140Z','url(#stone)',INK,2)
    art += path('M19 65L64 82L110 65M64 82V155M21 103L64 118L108 102M42 75V109M86 74V109M42 112V148M87 110V147',stroke='#76959a',width=1)
    art += path('M14 62V43L26 39V49L39 44V33L51 29V42L64 37L78 42V29L90 33V45L102 49V39L115 43V63L64 83Z','url(#stone)',GOLD,1.5)
    art += path('M48 145V112Q64 96 80 112V145Z','#142e3b',GOLD,2)
    art += path('M55 144V116Q64 106 73 116V144Z','#d6a965','#f4d493',1)
    art += lantern(64,109,.9)
    art += lantern(35,89,.58) + lantern(95,88,.58)
    art += path('M63 41V5L91 13L65 23','#b6755e',GOLD,1.5)
    art += path('M73 11L77 16L72 18Z',LIGHT,'none')
    save('base',128,160,art)


def main():
    for kind in ('arrow','mortar','frost','sun','runner','armor','flyer','swarm','boss'):
        sheet(kind)
    background()
    keyart()
    logo()
    interface()
    print('独自画像 18 点を再生成しました。各キャラ 5 動作 × 6 フレーム。')


if __name__ == '__main__':
    main()
