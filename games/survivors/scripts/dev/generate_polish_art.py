"""独自の絵本風SVGを決定的に再生成する。ロゴの輪郭化のみfontToolsを使う。"""

import math
from pathlib import Path
import random

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets/art"
INK = "#101e32"
GOLD = "#f4c778"
CREAM = "#fff0c7"
MINT = "#8fe0c5"
CORAL = "#ed927d"
MOTIONS = ("idle", "move", "attack", "hurt", "death")
FRAME_SIZE = 160
FRAME_COUNT = 6


def path(data, fill, stroke=INK, width=2.5, extra=""):
    return (f'<path d="{data}" fill="{fill}" stroke="{stroke}" '
            f'stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round" {extra}/>')


def ellipse(x, y, rx, ry, fill, extra=""):
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}" {extra}/>'


def circle(x, y, radius, fill, extra=""):
    return f'<circle cx="{x}" cy="{y}" r="{radius}" fill="{fill}" {extra}/>'


def group(body, transform="", extra=""):
    return f'<g transform="{transform}" {extra}>{body}</g>'


def sparkle(x, y, radius=5, color=GOLD):
    return path(f'M{x} {y-radius}Q{x+1} {y-1} {x+radius} {y}'
                f'Q{x+1} {y+1} {x} {y+radius}Q{x-1} {y+1} {x-radius} {y}'
                f'Q{x-1} {y-1} {x} {y-radius}', color, "none")


def leaf(x, y, size=12, angle=0, color=MINT):
    return group(path(f'M0 0Q{-size*.9} {-size*.8} 0 {-size*1.7}'
                      f'Q{size*.9} {-size*.8} 0 0', color, "none")
                 + path(f'M0 -1V{-size*1.35}', "none", INK, 1, 'opacity=".28"'),
                 f'translate({x} {y}) rotate({angle})')


def defs():
    return '''<defs>
<linearGradient id="cape" x1="0" y1="0" x2=".8" y2="1"><stop stop-color="#7bc7ae"/><stop offset=".5" stop-color="#3c938f"/><stop offset="1" stop-color="#204b65"/></linearGradient>
<linearGradient id="rose" x1="0" y1="0" x2=".6" y2="1"><stop stop-color="#ffd0a0"/><stop offset=".4" stop-color="#dc857e"/><stop offset="1" stop-color="#793e66"/></linearGradient>
<linearGradient id="stone" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#8aa2a4"/><stop offset=".55" stop-color="#536574"/><stop offset="1" stop-color="#303a57"/></linearGradient>
<linearGradient id="royal" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#c07b89"/><stop offset=".45" stop-color="#62455f"/><stop offset="1" stop-color="#263b55"/></linearGradient>
<radialGradient id="light"><stop stop-color="#fff2b7" stop-opacity=".75"/><stop offset=".2" stop-color="#f2bf67" stop-opacity=".3"/><stop offset="1" stop-color="#e7b36c" stop-opacity="0"/></radialGradient>
<radialGradient id="blue"><stop stop-color="#80cbbb" stop-opacity=".16"/><stop offset="1" stop-color="#488b9b" stop-opacity="0"/></radialGradient>
<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#101c35"/><stop offset=".7" stop-color="#234350"/><stop offset="1" stop-color="#162d3c"/></linearGradient>
<linearGradient id="fog" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#afdcca" stop-opacity="0"/><stop offset=".5" stop-color="#a9d6c5" stop-opacity=".1"/><stop offset="1" stop-color="#afdcca" stop-opacity="0"/></linearGradient>
<clipPath id="frame-clip"><rect width="160" height="160"/></clipPath>
</defs>'''


def svg(name, body, width=160, height=None):
    height = height or width
    ART.mkdir(parents=True, exist_ok=True)
    (ART / f"{name}.svg").write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}">{defs()}{body}</svg>\n', encoding="utf-8")


def lantern(x, y, scale=1, tilt=0):
    body = circle(0, 4, 30, "url(#light)")
    body += path('M-7 -7V-16Q0 -25 7 -16V-7', 'none', GOLD, 2.6)
    body += path('M-12 -8H12L9 16L0 21L-9 16Z', '#805e49', GOLD, 1.8)
    body += path('M-7 -3H7L5 13L0 16L-5 13Z', '#ffe0a0', 'none')
    body += path('M0 -1Q8 9 0 12Q-6 10 0 -1', '#fff9de', 'none')
    body += path('M-13 -8H13M-9 18H9M0 -7V16', 'none', GOLD, 2)
    return group(body, f'translate({x} {y}) rotate({tilt}) scale({scale})')


def eyes(x, y, spread, motion, phase, color=CREAM):
    if motion == "death" or (motion == "idle" and phase == 4):
        return path(f'M{x-spread-3} {y}l6 0m{spread*2-6} 0h6', "none", color, 2.2)
    if motion == "hurt":
        return path(f'M{x-spread-3} {y-3}l5 3 -5 3m{spread*2+6} -6l-5 3 5 3',
                    "none", color, 2.5)
    if motion == "attack":
        return path(f'M{x-spread-4} {y-2}l7 3m{spread*2-6} 0l7 -3', "none", color, 3.2)
    return ellipse(x-spread, y, 2.8, 4.3, color) + ellipse(x+spread, y, 2.8, 4.3, color)


def player(motion, phase):
    wave = math.sin(phase * math.tau / FRAME_COUNT + .32)
    stride = wave * (7 if motion == "move" else 1)
    thrust = [0, -12, 18, 26, 15, 0][phase] if motion == "attack" else wave * 2
    bob = -abs(wave) * (4 if motion == "move" else 1.8)
    body = path(f'M62 116l{-stride} 18h-12l6 -23m29 2l{stride} 21h12l-7 -22',
                '#344650', '#142739', 3)
    cape = (f'M60 60Q77 50 95 63L{111+stride} 118Q98 133 83 125'
            f'Q70 139 {46-stride} 123L57 79Z')
    body += path(cape, 'url(#cape)')
    body += path(f'M77 66Q68 100 {64-stride*.4} 122M91 69Q94 97 {102+stride*.6} 118',
                 'none', '#a4dabb', 2, 'opacity=".65"')
    body += path(f'M54 102Q70 110 104 101L{108+stride} 115Q81 128 {50-stride} 118Z',
                 '#255667', 'none')
    for x in (60, 76, 92):
        body += sparkle(x, 116, 2, '#f1c881')
    arm_angle = -22 if motion == "hurt" else -thrust
    staff = path('M108 48L120 130', 'none', '#d7ad78', 4)
    staff += path('M108 49Q94 36 106 28Q117 22 119 36Q118 42 111 43', 'none', GOLD, 3)
    staff += circle(108, 34, 6, MINT) + sparkle(108, 34, 3, CREAM)
    staff += leaf(117, 58, 6, 60, '#a2c29a')
    body += group(staff, f'rotate({arm_angle} 103 88)')
    body += path(f'M91 74Q101 88 {110+thrust*.25} {86-thrust*.45}',
                 'none', '#76bdb1', 11)
    body += circle(110+thrust*.25, 86-thrust*.45, 5, '#ffe0b6')
    body += path(f'M61 75Q42 81 {39-stride*.3} {94+stride*.4}', 'none', '#80c6b1', 11)
    body += circle(39-stride*.3, 94+stride*.4, 5, '#ffe0b6')
    body += lantern(36-stride*.3, 115+stride*.4, .78, -wave*9)
    body += path('M51 66Q39 42 57 27Q66 13 86 19Q108 23 108 55L95 72Q73 82 51 66Z',
                 'url(#cape)', INK, 3)
    body += path('M48 51Q61 35 81 38Q94 39 103 53L95 67Q70 79 53 63Z', '#142c40')
    body += path('M50 50Q65 39 79 40', 'none', '#addbc1', 2)
    body += eyes(76, 55, 10, motion, phase)
    body += path('M60 26Q71 22 78 25M83 23Q96 25 100 36', 'none', '#a3d7b5', 2)
    body += leaf(102, 43, 9, 40, GOLD)
    body += path('M54 71Q76 88 98 71L94 81Q74 94 54 78Z', '#c5c495', INK, 1.8)
    body += circle(76, 83, 4, GOLD) + circle(76, 83, 1.7, CREAM)
    if motion == "attack" and phase in (2, 3, 4):
        body += sparkle(137, 38, 8+phase, CREAM) + sparkle(145, 59, 4, GOLD)
    return group(body, f'translate(0 {bob})')


def sprig(motion, phase):
    wave = math.sin(phase * math.tau / FRAME_COUNT + .32)
    stride = wave * (8 if motion == 'move' else 2)
    attack = [0, -6, 16, 25, 10, 0][phase] if motion == 'attack' else 0
    body = path(f'M65 110L{57-stride} 132L{43-stride} 135m45 -23L{101+stride} 132l12 -2',
                'none', '#794d69', 6)
    body += path(f'M53 86Q{33-attack*.6} 80 {25-attack*.3} {98-attack*.6}'
                 f'M103 85Q{123+attack*.2} 87 {130+attack*.1} {69-attack}',
                 'none', '#965d73', 7)
    body += path(f'M24 {98-attack*.6}l-9 -4m11 4l-3 9M130 {69-attack}l8 -7m-9 8l11 1',
                 'none', '#e9b19a', 3)
    body += path('M48 62Q27 81 44 112L64 118L78 111L96 121L116 110Q132 76 106 58Z',
                 '#825775', INK, 3)
    body += path('M48 84L60 108L78 98L95 112L111 87', 'none', '#c17f89', 2)
    body += leaf(46, 53, 16, -48, '#e5a17d') + leaf(109, 49, 17, 53, '#d98978')
    body += path('M40 65L51 38L75 26L106 43L119 70L98 91L79 104L52 85Z', 'url(#rose)', INK, 3)
    body += path('M77 33L78 91M77 55L54 46M78 70L46 66M79 72L106 58M79 88L103 78',
                 'none', '#6c435d', 1.8, 'opacity=".6"')
    body += path('M47 69Q59 53 71 67L67 81L51 77ZM85 67Q99 53 113 65L107 80L91 82Z',
                 '#4a3452', 'none')
    body += eyes(80, 71, 22, motion, phase, '#ffe2ac')
    body += path('M76 89l5 3 5 -4', 'none', '#4b354e', 2.5)
    body += leaf(76, 30, 10, -12, '#a8c6a0') + circle(96, 49, 3, '#ffdbab')
    return group(body, f'translate(0 {-abs(stride)*.35}) rotate({wave*2} 80 100)')


def moth(motion, phase):
    wave = math.sin(phase * math.tau / FRAME_COUNT + .32)
    flap = (0.48, .76, 1, .82, .55, .72)[phase]
    if motion == 'attack':
        flap = (.9, 1.08, .45, .38, .74, .95)[phase]
    wings = ''
    for sign in (-1, 1):
        wing = path('M0 3Q-12 -50 -54 -50Q-80 -15 -22 22Q-69 15 -54 56Q-19 74 0 13Z',
                    'url(#rose)', INK, 3)
        wing += path('M-5 5Q-25 -17 -51 -36M-13 22Q-34 30 -46 45M-23 -13L-49 -9',
                     'none', '#f7c091', 2.6)
        wing += ellipse(-37, -16, 12, 15, '#70425f')
        wing += ellipse(-36, -17, 7, 9, '#f3cb9a') + ellipse(-35, -18, 3, 4, '#432f4a')
        wing += ellipse(-37, 39, 6, 8, '#a95672')
        for x, y in ((-51, -33), (-56, -18), (-46, 53), (-31, 56)):
            wing += circle(x, y, 2, '#ffddb2')
        wings += group(wing, f'translate(80 77) scale({sign*flap} 1)')
    body = path('M69 75Q58 112 77 126Q92 130 92 101L89 73Z', '#5a3b58', INK, 2.5)
    body += path('M71 98Q80 103 90 98M72 107Q81 112 87 107M74 115L85 117', 'none', '#d58c8c', 3)
    body += path('M69 64Q49 38 57 17Q78 27 79 54M85 53Q88 24 104 16Q114 37 94 66',
                 '#d9988e', INK, 3)
    body += path('M63 30L72 52M98 31L91 52', 'none', '#f2c79f', 3)
    body += path('M63 61L73 48L81 54L91 49L101 64L96 81L84 90L65 81Z', '#deb19b', INK, 2.5)
    body += path('M67 70L74 61L88 60L97 69L89 79L73 78Z', '#513b54', 'none')
    body += eyes(82, 70, 9, motion, phase)
    body += path(f'M70 88l{-7-wave*3} 13m23 -13l{7+wave*3} 13', 'none', '#edbea5', 2.5)
    body += leaf(81, 57, 5, 0, GOLD)
    return group(wings + body, f'translate(0 {-4-wave*5})')


def beast(motion, phase):
    wave = math.sin(phase * math.tau / FRAME_COUNT + .32)
    stride = wave * (6 if motion == 'move' else 1)
    slam = [0, -6, -12, 7, 4, 0][phase] if motion == 'attack' else 0
    body = path(f'M53 104L{43-stride} 134h25l7 -24m18 -2l{6+stride} 26h23l-9 -33',
                '#43536b', INK, 4)
    body += path('M39 133h29m29 1h27', 'none', '#bdac9c', 3)
    body += path('M27 107L22 79L39 44L64 35L103 41L130 66L140 104L126 120L103 117'
                 'L80 125L50 117L31 122Z', 'url(#stone)', INK, 4)
    body += path('M22 81L43 90L57 64L40 45M107 45L104 75L132 80M80 84L71 121'
                 'M28 105L48 103L49 117M110 101L128 99', 'none', '#263a51', 3)
    for sign in (-1, 1):
        raise_arm = [0, -18, -38, 13, 6, 0][phase] if motion == 'attack' else sign*stride*1.4
        fist = path('M-10 -15L9 -12L16 7L6 18L-12 13L-16 -2Z', 'url(#stone)', INK, 3)
        fist += path('M-13 0L1 4L11 -4M1 4L6 16', 'none', '#263a51', 2)
        fist += path('M-9 8L-8 14M-2 11L0 17', 'none', '#d8b395', 2)
        body += group(fist, f'translate({80+sign*47} {103+raise_arm}) rotate({-sign*raise_arm})')
    body += path('M33 66L27 34L42 18L41 41L55 56M105 51L115 34L116 13L131 32L128 61',
                 '#d8b395', INK, 3)
    body += path('M33 38L39 36M118 33L125 35', 'none', '#8b7c81', 2)
    body += path('M43 65L53 43L91 34L111 55L111 91L93 107L65 105L46 90Z',
                 '#667783', INK, 3)
    body += path('M53 44L74 64L94 37M73 65L69 89L84 98L96 83L109 88', 'none', '#32465d', 3)
    body += path('M51 73L67 69L69 83L55 85ZM87 70L104 66L99 83L86 84Z', '#30334a', 'none')
    body += eyes(78, 76, 20, motion, phase, '#ffd5a0')
    body += path('M64 96L80 92L95 96', 'none', '#e8baa1', 2.5)
    for x, y, angle in ((49, 54, -48), (61, 45, -20), (102, 57, 30), (35, 110, -60)):
        body += leaf(x, y, 6, angle, '#a5b49a')
    body += sparkle(78, 53, 6, CORAL)
    return group(body, f'translate(0 {slam-abs(stride)*.3}) rotate({wave} 80 105)')


def sovereign(motion, phase):
    wave = math.sin(phase * math.tau / FRAME_COUNT + .32)
    spread = [0, 3, 8, 14, 8, 0][phase] if motion == 'attack' else wave*(7 if motion == 'move' else 2)
    sway = wave*3 if motion == 'move' else 0
    cape = path(f'M52 58Q80 42 107 57L{137+spread*.3} 130'
                f'L117 140L99 134L82 144L65 136L43 142L{22-spread*.3} 128Z',
                'url(#royal)', INK, 3.5)
    cape += path('M53 74L43 130M65 87L62 136M94 84L103 133M107 72L120 132',
                 'none', '#ce958c', 2, 'opacity=".45"')
    cape += path('M27 126L44 135L64 129L82 137L99 127L116 133L134 126', 'none', GOLD, 2)
    for x, y in ((44, 117), (67, 115), (97, 114), (119, 116)):
        cape += sparkle(x, y, 3, GOLD)
    branches = path('M55 57L35 43L27 19L17 10M30 27L13 28L7 19M36 43L48 29L44 14'
                    'M105 57L126 41L134 17L145 8M131 28L147 28L154 18M123 43L113 26L118 12',
                    'none', '#c99d8e', 5)
    branches += path('M27 20L30 7M136 17L135 5', 'none', GOLD, 2)
    body = path(f'M49 73Q{32-spread} 90 {32-spread} 107'
                f'M109 73Q{126+spread} 86 {127+spread} 104', 'none', '#70536c', 12)
    body += path(f'M{32-spread} 105l-6 11m6 -11l2 12M{127+spread} 102l7 11m-7 -11l-2 13',
                 'none', '#eac1a2', 3)
    body += path('M57 49L79 32L104 47L109 77L93 93L82 105L64 93L51 77Z',
                 '#c3b6a5', INK, 3)
    body += path('M60 51L71 69L62 78L79 96L81 48M101 53L91 68L100 77L85 96',
                 'none', '#8b7f8a', 2)
    body += path('M54 65L69 62L74 71L62 78ZM86 70L93 60L105 63L99 76Z', '#493750', 'none')
    body += eyes(80, 69, 18, motion, phase, '#ffe2a4')
    body += path('M77 84l4 5 5 -7', 'none', '#65465a', 2)
    body += path('M54 48L50 31L63 39L67 19L79 35L92 18L96 36L110 29L106 48Z',
                 '#ba7e6b', GOLD, 2)
    body += sparkle(81, 46, 7, CREAM) + circle(81, 46, 2, '#bf6f78')
    body += path('M49 81Q80 108 111 80L112 91Q79 119 48 92Z', '#805568', GOLD, 1.8)
    body += circle(80, 103, 6, GOLD) + sparkle(80, 103, 4, CREAM)
    if motion == 'attack' and phase in (2, 3, 4):
        body += circle(80, 52, 56, 'none', f'stroke="{GOLD}" stroke-width="1" opacity=".5"')
        body += sparkle(12, 74, 7, GOLD) + sparkle(147, 71, 7, GOLD)
    return group(cape + branches + body,
                 f'translate(0 {-abs(wave)*(5 if motion == "move" else 2)}) rotate({sway} 80 116)')


CHARACTERS = (('player', player), ('enemy-0', sprig), ('enemy-1', moth),
              ('enemy-2', beast), ('enemy-3', sovereign))


def actor_frame(draw, motion, phase):
    body = draw(motion, phase)
    shadow = ellipse(80, 141, 37, 7, '#070f23', 'opacity=".35"')
    if motion == 'hurt':
        body = group(body, f'rotate({[-5, 7, -6, 4, -2, 0][phase]} 80 100)')
        body += sparkle(129-phase*3, 41+phase*3, 5, CORAL)
    if motion == 'death':
        # 消滅は時刻によって進むため、手足を崩しながら光片へ変える。
        progress = phase / 5
        body = group(body, f'translate({phase*2} {phase*3}) rotate({phase*6} 80 120)'
                     f' translate(80 120) scale({1-progress*.35} {1-progress*.45}) translate(-80 -120)',
                     f'opacity="{1-progress*.93}"')
        for i in range(7):
            x = 80 + math.sin(i*2.6+phase)* (12+phase*6)
            y = 97 - phase*9 - i*6
            body += sparkle(round(x, 2), y, 2+progress*2, GOLD if draw == player else CORAL)
        shadow = group(shadow, extra=f'opacity="{1-progress}"')
    return group(group(shadow + body, 'translate(8 8) scale(.9)'),
                 extra='clip-path="url(#frame-clip)"')


def make_characters():
    for name, draw in CHARACTERS:
        svg(name, actor_frame(draw, 'idle', 0))
        frames = []
        for row, motion in enumerate(MOTIONS):
            for frame in range(FRAME_COUNT):
                frames.append(group(actor_frame(draw, motion, frame),
                                    f'translate({frame*FRAME_SIZE} {row*FRAME_SIZE})'))
        svg(name + '-sheet', ''.join(frames), FRAME_SIZE*FRAME_COUNT, FRAME_SIZE*len(MOTIONS))


def tree(x, base, size, color, detail=False):
    body = path('M-25 0Q-7 -75 -16 -143L-48 -188L-69 -200L-71 -211L-41 -200L-18 -173'
                'L-25 -240L-45 -274L-38 -283L-13 -250L-2 -298L5 -298L3 -212L24 -235'
                'L29 -277L36 -279L38 -230L10 -189L17 -104Q21 -49 42 0Z', color, 'none')
    body += path('M-5 -166L-65 -148L-92 -158L-100 -153L-71 -137L-4 -148'
                 'M10 -99L65 -129L93 -176L101 -175L77 -123L18 -79', color, 'none')
    if detail:
        body += path('M-7 -24Q-18 -84 -10 -118M4 -188L-4 -239M19 -46L12 -76',
                     'none', '#6ca292', 1.6, 'opacity=".25"')
        for xx, yy, a in ((-57, -155, -20), (50, -120, 45), (-36, -212, -60)):
            body += leaf(xx, yy, 10, a, '#456d71')
        for yy in range(-144, -20, 19):
            body += path(f'M1 {yy}q-7 5 -4 13M8 {yy+9}l2 6', 'none', '#79aa98', .8,
                         'opacity=".18"')
    return group(body, f'translate({x} {base}) scale({size})')


def fern(x, y, size, angle, color):
    body = path('M0 0Q-3 -25 2 -54', 'none', color, 1.5)
    for i in range(6):
        yy = -7-i*7
        extent = 18-i*2.4
        body += path(f'M0 {yy}Q{-extent} {yy+2} {-extent} {yy-9}Q-4 {yy-10} 0 {yy-3}'
                     f'Q{extent} {yy-14} {extent} {yy-6}Q10 {yy+2} 0 {yy}', color, 'none')
    return group(body, f'translate({x} {y}) rotate({angle}) scale({size})')


def make_backgrounds():
    rng = random.Random(9047)
    floor = '<rect width="160" height="160" fill="#182f3d"/>'
    floor += path('M-30 63Q35 36 87 78T190 80M-30 130Q44 103 95 139T180 143',
                  'none', '#213a45', 14, 'opacity=".55"')
    for _ in range(25):
        x, y = rng.randrange(8, 152), rng.randrange(10, 150)
        floor += leaf(x, y, rng.randrange(2, 5), rng.randrange(-80, 80),
                      rng.choice(('#284751', '#284d50', '#335458')))
    for x, y in ((24, 41), (101, 123), (128, 22)):
        floor += path(f'M{x-6} {y}q5 -4 12 0l-3 4h-7Z', '#314956', 'none')
    svg('floor', floor)
    far = ''
    for i in range(18):
        far += tree(i*82-45, 595+rng.randrange(-35, 45), 1.5+rng.random()*.4,
                    rng.choice(('#213b4b', '#284350', '#263e50')))
    far += path('M0 565Q200 503 418 570T800 554T1280 566V720H0Z', '#263f48', 'none')
    far += path('M0 612Q180 575 359 617T750 616T1280 602V720H0Z', '#203744', 'none')
    svg('forest-far', far, 1280, 720)
    near = tree(-25, 720, 2.6, '#101f33', True) + tree(1325, 740, 2.7, '#101f33', True)
    near += path('M0 710Q60 690 129 720H0M1280 711Q1200 682 1143 720H1280', '#0e2232', 'none')
    for side in (0, 1280):
        for i in range(12):
            x = side + (1 if side == 0 else -1) * rng.randrange(2, 127)
            y = rng.randrange(672, 730)
            near += leaf(x, y, rng.randrange(9, 22), rng.randrange(-70, 70),
                         rng.choice(('#193644', '#284d51', '#305c5b')))
    svg('forest-near', near, 1280, 720)
    mist = ''
    for x, y, rx, ry in ((180, 460, 430, 65), (870, 510, 570, 90), (450, 630, 650, 70)):
        mist += ellipse(x, y, rx, ry, 'url(#fog)')
    svg('mist', mist, 1280, 720)
    art = '<rect width="800" height="720" rx="36" fill="url(#sky)"/>'
    art += circle(441, 208, 250, 'url(#blue)')
    art += circle(432, 136, 95, 'url(#blue)')
    art += circle(432, 136, 65, '#c4d4bc', 'opacity=".38"')
    art += circle(456, 118, 59, '#172c41')
    for i in range(48):
        x, y = rng.randrange(50, 770), rng.randrange(25, 450)
        art += circle(x, y, rng.choice((.7, 1, 1.4)), '#c7d4bb', 'opacity=".5"')
    for x in (-10, 75, 156, 241, 594, 680, 769, 853):
        art += tree(x, 600, 1.15+rng.random()*.35,
                    rng.choice(('#243f50', '#2a4c55', '#274651')))
    for x, y, size, a in ((62, 117, 39, -42), (121, 83, 29, 13), (213, 37, 27, -14),
                          (683, 84, 31, 35), (735, 161, 25, 69), (752, 218, 21, 58)):
        art += leaf(x, y, size, a, '#294c54')
        art += leaf(x+15, y+7, size*.58, a+25, '#356068')
    art += path('M0 591Q169 518 350 574T800 572V720H0Z', '#294752', 'none')
    art += path('M0 660Q115 565 387 610Q611 580 800 655V720H0Z', '#182e40', 'none')
    art += path('M400 720Q217 659 391 614Q526 577 463 548Q454 571 324 591'
                'Q169 636 218 720Z', '#3c5d60', 'none', extra='opacity=".45"')
    art += group(sovereign('idle', 0), 'translate(534 326) scale(1.25)', 'opacity=".75"')
    art += group(moth('idle', 2), 'translate(133 295) scale(.58)', 'opacity=".9"')
    art += group(sprig('idle', 0), 'translate(88 525) scale(.64)')
    art += circle(310, 525, 192, 'url(#light)')
    art += group(player('idle', 0), 'translate(207 289) scale(2.46)')
    art += tree(-11, 756, 2.65, '#101f32', True) + tree(840, 738, 2.8, '#0c1c2c', True)
    for i in range(50):
        x, y = rng.randrange(0, 800), rng.randrange(655, 750)
        art += leaf(x, y, rng.randrange(8, 24), rng.randrange(-70, 70),
                    rng.choice(('#1b3d46', '#2b5257', '#3e6d66')))
    for x, y, size, angle in ((86, 703, 1.5, -24), (721, 713, 1.7, 24),
                              (182, 741, 1.3, -15), (621, 740, 1.4, 30)):
        art += fern(x, y, size, angle, '#477b6f')
    for x, y, size in ((589, 643, 1), (626, 657, .7), (164, 628, .5)):
        mushroom = path('M-3 0L-1 -22H4L5 0Z', '#c5b8a2', 'none')
        mushroom += path('M-18 -19Q-15 -45 4 -37Q19 -32 21 -19Q0 -11 -18 -19Z',
                         '#c17f78', '#172d3d', 2)
        mushroom += circle(-5, -29, 2.5, '#efd0ae') + circle(7, -26, 2, '#efd0ae')
        art += group(mushroom, f'translate({x} {y}) scale({size})')
    for x, y in ((168, 416), (251, 339), (546, 512), (427, 279), (650, 268), (509, 571)):
        art += circle(x, y, 17, 'url(#light)') + sparkle(x, y, 3, GOLD)
    svg('key-art', art, 800, 720)


def make_icons():
    svg('spark', sparkle(8, 8, 7, '#fff0d2') + sparkle(8, 8, 3.5, '#ffffff'), 16)
    svg('gem', circle(80, 80, 70, 'url(#blue)') + path('M80 19L117 66L80 137L43 66Z',
        '#63c4ba', INK, 4) + path('M80 19L72 66L80 137L94 66Z', '#cff6d7', 'none')
        + path('M44 66H116M80 20L94 66', 'none', MINT, 2) + sparkle(56, 36, 8, CREAM))
    svg('heal', path('M64 36H99V57Q119 71 117 110Q88 141 48 115Q40 83 65 57Z',
        '#915569', INK, 4) + path('M53 83Q87 91 110 78L111 109Q88 130 53 110Z', '#eea997', 'none')
        + path('M62 28H101V46H62Z', '#c5a37d', INK, 3)
        + path('M80 56Q68 36 82 22Q93 44 80 56', '#8cbea5', INK, 2)
        + path('M79 58Q93 34 112 44Q103 65 79 58', '#bdd6aa', INK, 2)
        + path('M61 72Q50 89 56 100', 'none', '#ffe4c5', 4)
        + sparkle(83, 99, 16, '#fff0c7') + circle(100, 93, 3, '#ffe4c5'))
    svg('magnet', circle(80, 83, 52, '#35506a', f'stroke="{GOLD}" stroke-width="3"')
        + path('M80 20L100 78L80 132L58 79Z', '#987b9e', INK, 3)
        + path('M80 20L80 84L100 78Z', '#e7bea7', 'none')
        + path('M80 84L80 132L58 79Z', '#d6abc7', 'none')
        + circle(80, 81, 11, GOLD) + sparkle(80, 81, 8, CREAM)
        + path('M36 38L27 26M124 38L135 25M23 78H11M138 78H149', 'none', MINT, 4))
    svg('bolt', path('M143 23Q80 25 55 71L12 137L90 104L130 62L89 78Z', '#4d9499', INK, 3)
        + path('M144 23L59 81L15 136L86 94L71 81Z', '#ade7ca', 'none')
        + path('M141 26L75 79L94 72L41 115L92 89L84 79Z', '#fff0bf', 'none')
        + sparkle(128, 37, 10, CREAM))
    svg('orbit', circle(80, 80, 51, 'none', 'stroke="#aa91ba" stroke-width="3"')
        + path('M32 110Q1 51 67 29M100 131Q154 105 132 48', 'none', '#e3bdba', 6)
        + leaf(59, 40, 14, -66, '#cdb1cb') + leaf(117, 133, 14, 56, '#cdb1cb')
        + sparkle(83, 78, 30, '#f4d6c5') + sparkle(119, 43, 17, '#ffedc8')
        + circle(83, 78, 8, '#aa809e'))
    svg('pulse', circle(80, 80, 58, 'none', f'stroke="{GOLD}" stroke-width="3"')
        + circle(80, 80, 42, 'none', 'stroke="#e39d78" stroke-width="6"')
        + sparkle(80, 80, 27, CREAM)
        + ''.join(sparkle(80+math.cos(i*math.pi/2)*57, 80+math.sin(i*math.pi/2)*57, 9, GOLD)
                  for i in range(4)))
    emblem = circle(80, 80, 69, '#1c3545', f'stroke="{GOLD}" stroke-width="1.5"')
    emblem += circle(80, 80, 61, 'none', 'stroke="#759b91" stroke-width="1"')
    for sign in (-1, 1):
        emblem += path(f'M{80+sign*20} 135Q{80+sign*73} 95 {80+sign*42} 37',
                       'none', '#9cc6a5', 2)
        for i in range(5):
            emblem += leaf(80+sign*(43+math.sin(i*.6)*9), 125-i*16, 8, sign*50, '#9cc6a5')
    emblem += lantern(80, 84, 2.0) + sparkle(80, 26, 6, CREAM)
    svg('title-emblem', emblem)
    icons = {
        'icon-health': path('M80 127L33 81Q12 53 36 34Q64 16 80 48Q97 16 124 34'
                            'Q148 54 127 82Z', '#e49988', INK, 4)
                        + path('M43 49Q56 42 64 58', 'none', '#ffdbb1', 5),
        'icon-clock': circle(80, 83, 49, '#314b5c', f'stroke="{GOLD}" stroke-width="5"')
                      + path('M80 51V85L103 101M65 19H95M80 21V33', 'none', GOLD, 6)
                      + circle(80, 84, 5, CREAM),
        'icon-kills': path('M48 109L113 33L130 22L124 47L59 120Z', '#c0d8cc', INK, 3)
                      + path('M32 95L66 126M45 116L30 134', 'none', GOLD, 7)
                      + leaf(49, 85, 16, -58, '#dd9a88'),
        'icon-speed': path('M110 23L74 84L125 82L45 142L73 95H35Z', '#9ad0bf', INK, 4)
                      + path('M25 52H61M18 70H48M100 115H133', 'none', GOLD, 5),
        'icon-armor': path('M80 21L127 43L120 101L80 141L39 102L32 43Z', '#65818d', INK, 4)
                      + path('M80 33V124M44 51L80 35L115 51', 'none', '#b5c9bd', 3)
                      + sparkle(80, 76, 23, GOLD),
        'icon-pause': path('M47 34H66V127H47ZM94 34H113V127H94Z', '#c1d9c7', INK, 4),
        'icon-sound': path('M27 65H50L83 34V126L50 96H27Z', '#adcdbf', INK, 4)
                      + path('M102 52Q129 80 102 110M118 37Q154 80 118 126', 'none', GOLD, 5),
    }
    for name, body in icons.items():
        svg(name, body)


def make_logo():
    from fontTools.pens.svgPathPen import SVGPathPen
    from fontTools.ttLib import TTFont

    font = TTFont(ROOT / 'assets/fonts/RocknRollOne-Regular.ttf')
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    units = font['head'].unitsPerEm
    body = path('M48 153Q300 140 552 153M194 169H268M332 169H408', 'none', GOLD, 1.3)
    x = 25
    for char in '宵森の灯守':
        pen = SVGPathPen(glyphs)
        glyph = glyphs[cmap[ord(char)]]
        glyph.draw(pen)
        body += group(path(pen.getCommands(), CREAM, GOLD, 5),
                      f'translate({x} 125) scale({.105*1000/units} {-.105*1000/units})')
        x += 110
    body += sparkle(300, 166, 5, GOLD)
    svg('logo', body, 600, 180)
    font.close()


if __name__ == '__main__':
    make_characters()
    make_backgrounds()
    make_icons()
    make_logo()
    print('独自SVGの生成完了')
