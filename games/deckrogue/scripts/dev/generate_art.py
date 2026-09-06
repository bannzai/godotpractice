#!/usr/bin/env python3
"""燈火の巡礼の独自切り絵素材を同一バイト列で再生成する。"""

from pathlib import Path
import math
import random


ART = Path(__file__).resolve().parents[2] / "assets" / "art"
INK = "#101c2c"
TEAL = "#173b42"
GOLD = "#d9b66f"
PAPER = "#f2e6ca"
RUST = "#c86e55"
MOSS = "#789182"
STATES = ("idle", "move", "attack", "hurt", "death")
CHARACTERS = ("hero", "enemy_moth", "enemy_sentinel", "enemy_wisp",
              "enemy_brute", "boss", "npc_keeper")
DEFS = '''<defs>
<linearGradient id="night" x2="0" y2="1"><stop stop-color="#101c2c"/><stop offset=".7" stop-color="#173b42"/><stop offset="1" stop-color="#385557"/></linearGradient>
<linearGradient id="cape" x2=".8" y2="1"><stop stop-color="#e39470"/><stop offset=".42" stop-color="#b65d50"/><stop offset="1" stop-color="#592e3d"/></linearGradient>
<linearGradient id="stone" x2=".7" y2="1"><stop stop-color="#82928a"/><stop offset=".48" stop-color="#385b61"/><stop offset="1" stop-color="#152d3b"/></linearGradient>
<linearGradient id="gold" x2=".8" y2="1"><stop stop-color="#f2e6ca"/><stop offset=".35" stop-color="#d9b66f"/><stop offset="1" stop-color="#886943"/></linearGradient>
<linearGradient id="ghost" x2="0" y2="1"><stop stop-color="#f2e6ca"/><stop offset=".28" stop-color="#92bbad"/><stop offset="1" stop-color="#173b42" stop-opacity=".08"/></linearGradient>
<radialGradient id="glow"><stop stop-color="#f2d59a" stop-opacity=".65"/><stop offset=".35" stop-color="#dcaa63" stop-opacity=".19"/><stop offset="1" stop-color="#d9b66f" stop-opacity="0"/></radialGradient>
</defs>'''


def path(d, fill="none", stroke=GOLD, width=1, extra=""):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round" {extra}/>'


def circle(x, y, radius, fill, stroke="none", width=1, extra=""):
    return f'<circle cx="{x}" cy="{y}" r="{radius}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" {extra}/>'


def group(content, transform="", extra=""):
    return f'<g transform="{transform}" {extra}>{content}</g>'


def svg(name, width, height, content):
    """生成済みファイルへ同じ内容を書き、何度実行しても素材を一定に保つ。"""
    ART.mkdir(parents=True, exist_ok=True)
    (ART / f"{name}.svg").write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}">{DEFS}{content}</svg>\n', encoding="utf-8")


def glow(x, y, radius, opacity=1):
    return circle(x, y, radius, "url(#glow)", extra=f'opacity="{opacity}"')


def flame(x, y, scale=1, bend=0):
    shape = path(f"M0 12C-17 5-12-13 {bend}-29C-1-13 20-5 9 9Q5 16 0 12Z", "url(#gold)", GOLD, .8)
    shape += path("M1 9Q-8 2 0-10Q7 0 1 9", PAPER, "none")
    return group(shape, f"translate({x} {y}) scale({scale})")


def lantern(x, y, angle=0, scale=1, phase=0):
    parts = glow(0, 9, 34, .8)
    parts += path("M-10-9V-17Q0-30 10-17V-9M-16-7H16L12 27H-12ZM-18-7L-11-13H11L18-7M-17 29H17M-10 33H10", TEAL, GOLD, 2)
    parts += path("M-9-3H9L7 23H-7Z", "#a77e44", "none")
    parts += flame(0, 12, .53, phase * 3)
    parts += path("M-3-4V24M5-4V24", "none", GOLD, .8)
    return group(parts, f"translate({x} {y}) rotate({angle}) scale({scale})")


def etch_lines(x, y, count, length=15, gap=5):
    return "".join(path(f"M{x+i*gap} {y}l{length} {length*.55}", stroke=PAPER, width=.6,
                        extra='opacity=".24"') for i in range(count))


def pose_values(state, frame):
    phase = math.sin(frame * math.tau / 6)
    attack = (0, -.25, .3, 1, .6, 0)[frame] if state == "attack" else 0
    hurt = (0, 1, .8, .5, .2, 0)[frame] if state == "hurt" else 0
    death = frame / 5 if state == "death" else 0
    walk = phase if state == "move" else 0
    return phase, attack, hurt, death, walk


def hero(state, frame):
    phase, attack, hurt, death, walk = pose_values(state, frame)
    cape_wave = phase * 5 + attack * 20
    content = path(f"M104 232L{98+walk*9:.1f} 279L{87+walk*9:.1f} 292H116L130 242M142 235L{153-walk*9:.1f} 279L{164-walk*9:.1f} 292H140L125 246", INK, MOSS, 2)
    content += path(f"M96 125Q{57-cape_wave:.1f} 161 {64-cape_wave:.1f} 244L48 270L96 263L126 285L166 266L190 274Q{194+cape_wave:.1f} 197 157 127Z", "url(#cape)", "#e9b98b", 1.6)
    content += path(f"M91 145Q75 191 {71-cape_wave:.1f} 251M115 160Q103 215 118 266M146 146Q166 213 168 254", stroke="#6d3440", width=5)
    content += path("M81 248L99 243L126 264L162 247L178 256M83 254L96 253M104 256L110 260M136 262L144 256M152 251L158 250", stroke=GOLD, width=1.4)
    content += path("M105 140L96 219L126 249L158 219L146 136Z", TEAL, GOLD, 1.4)
    content += path("M111 160L131 157L144 177L132 192L107 184M103 207H152M119 212V237", stroke=MOSS)
    content += etch_lines(106, 170, 5, 11, 6)
    belt = path("M96 206L152 203L154 216L96 220Z", "#665247", GOLD)
    belt += circle(124, 211, 5, INK, GOLD)
    content += belt
    hand = path("M102 145Q74 168 91 196L109 185L109 158", TEAL, MOSS, 2)
    hand += path("M90 192L97 205L110 196L109 184", PAPER, GOLD)
    hand += path("M100 204L80 255M76 253L88 259M83 255L78 281", stroke=GOLD, width=3)
    content += group(hand, f"rotate({-attack*46+walk*9:.1f} 105 146)")
    arm = path("M151 142L172 174L194 162L202 170L173 192L144 169Z", TEAL, MOSS, 2)
    arm += path("M191 161L200 159L207 166L201 176L194 170Z", PAPER, GOLD)
    arm += lantern(204, 194, phase*4-attack*12, .95, phase)
    content += group(arm, f"rotate({-attack*67+hurt*14+death*40:.1f} 149 145)")
    head = path("M91 119Q83 89 103 59L127 39L153 61Q174 89 160 123L128 142Z", "url(#cape)", "#e9b98b", 1.8)
    head += path("M105 88Q129 65 152 89L144 118L127 131L111 116Z", INK, "#673d40", 1)
    head += path("M115 101L122 101M137 101L144 99", stroke=PAPER, width=1.6)
    head += path("M130 102L128 113L134 115M119 123L136 124", stroke="#687b79", width=1)
    head += path("M92 114L126 134L164 119L171 135L128 158L90 139Z", RUST, GOLD, 1.3)
    head += path("M102 129L127 143L153 130M103 72L111 66M146 66L151 77", stroke=PAPER, extra='opacity=".5"')
    content += group(head, f"rotate({phase*1.5-attack*5+hurt*11+death*22:.1f} 129 135) translate(0 {phase*1.5:.1f})")
    return group(content, f"translate({attack*6-hurt*8-death*80:.1f} {death*40:.1f}) rotate({-attack*7+hurt*8+death*68:.1f} 126 222) scale(1 {1-death*.25:.2f})")


def moth(state, frame):
    phase, attack, hurt, death, walk = pose_values(state, frame)
    content = ""
    for side in (-1, 1):
        wing = path("M0 3C-13-66-74-105-99-73C-121-42-92 5-16 29C-76 15-100 41-88 70C-67 100-26 68 2 40Z", "url(#cape)", GOLD, 1.6)
        wing += path("M-8 6L-88-65L-69-14L-98-27L-30 26M-7 35L-75 61L-43 43L-65 74", stroke=GOLD, width=1.5)
        wing += path("M-84-69Q-55-61-19-5M-98-37Q-77-9-31 16M-79 51L-28 44", stroke="#693341", width=4)
        wing += circle(-66, -34, 19, TEAL, GOLD, 2)
        wing += circle(-66, -34, 11, "#c98c60", PAPER, 1)
        wing += path("M-68-48Q-78-32-64-21Q-53-34-68-48", INK, GOLD)
        wing += circle(-66, -34, 3, PAPER)
        wing += path("M-59 44Q-77 55-60 69Q-44 59-59 44", TEAL, GOLD)
        wing += etch_lines(-86, -61, 5, 12, 5)
        for i in range(6):
            wing += circle(-88 + i*10, -62 + i*11, 2, PAPER, extra='opacity=".65"')
        openness = .86 + phase * .13 - attack * .25 - death*.55
        content += group(wing, f"translate(128 164) scale({side*openness:.2f} 1) rotate({phase*7+death*50:.1f})")
    body = path("M126 120Q111 140 118 187L128 225L138 187Q145 140 130 120Z", TEAL, GOLD, 2)
    for y in range(143, 205, 10):
        body += path(f"M119 {y}Q128 {y+6} 138 {y}", stroke=MOSS, width=2)
    body += path("M117 138L128 119L140 138L137 158L127 164L117 154", PAPER, GOLD)
    body += path("M120 145L124 148M131 148L136 144M121 125Q108 84 91 91M134 125Q150 84 164 89", stroke=INK, width=2)
    body += path("M116 167L104 182L97 182M139 167L151 182L158 180M117 180L109 202M138 180L147 202", stroke=GOLD, width=1.6)
    content += group(body, f"rotate({attack*13-hurt*8:.1f} 128 163)")
    return group(content, f"translate({walk*3-death*55:.1f} {phase*5+death*77:.1f}) rotate({hurt*17+death*70:.1f} 128 184) scale(1 {1-death*.28:.2f})")


def sentinel(state, frame):
    phase, attack, hurt, death, walk = pose_values(state, frame)
    content = path(f"M84 218L{73+walk*9:.1f} 276L{67+walk*9:.1f} 296H111L122 230M143 230L150 296H193L182 276L174 218Z", "url(#stone)", MOSS, 2)
    content += path("M78 273L102 279L109 291M156 280L184 276M95 237L92 262M165 237L170 263", stroke=GOLD)
    torso = path("M79 123L104 108H151L181 130L170 223L146 244H112L83 222Z", "url(#stone)", GOLD, 1.5)
    torso += path("M82 147L111 162L125 191L105 210M172 146L143 163L132 191L152 212", stroke=INK, width=4)
    torso += path("M105 211L127 198L153 210L147 226L126 232L110 225Z", INK, GOLD)
    torso += glow(128, 178, 43, .4) + circle(128, 178, 13, INK, GOLD, 3)
    torso += flame(128, 181, .43, phase*3)
    torso += path("M91 129L106 142L107 156M152 132L159 151M112 232L108 246M138 234L141 245", stroke=PAPER, width=1)
    torso += etch_lines(98, 120, 7, 13, 6)
    for x, y in [(78,134), (91,216), (159,151), (165,216)]:
        torso += path(f"M{x} {y}q-8 3-3 12q7-11 12-6q-6 6-2 13", stroke=MOSS, width=3)
    content += group(torso, f"translate(0 {phase*1.1+death*30:.1f}) rotate({hurt*6:.1f} 128 220)")
    for side in (-1, 1):
        arm = path("M0 0L26 11L32 57L21 83L-4 77L-12 42Z", "url(#stone)", GOLD, 1.4)
        arm += path("M-10 17L24 30M-8 30L25 43M-2 59L25 63M4 68V78M13 68V80", stroke=INK, width=3)
        if side == 1:
            arm += path("M18 72V160M5 91H33", stroke=GOLD, width=5)
            arm += path("M19 95L44 133L20 151L-5 132Z", "url(#stone)", GOLD, 2)
            arm += path("M20 105V141M6 132H33", stroke=MOSS)
        else:
            arm += path("M-5 42L-21 52L-19 107L6 130L31 105L28 52Z", TEAL, GOLD, 2)
            arm += path("M4 61V115M-11 81L4 74L19 82L4 103Z", stroke=MOSS, width=2)
        content += group(arm, f"translate({128+side*47} {129+death*46:.1f}) rotate({side*(-8+walk*12+death*22)-attack*side*12:.1f}) scale({side*.8} .8)")
    head = path("M96 74L107 46L144 42L162 70L157 112L130 127L101 113Z", "url(#stone)", GOLD, 1.7)
    head += path("M119 48L111 74L128 89L116 110M143 47L139 68L155 80", stroke=INK, width=3)
    head += path("M105 87L124 93L149 84L148 94L126 101L108 96Z", INK, GOLD)
    head += path("M111 92L124 96L142 90", stroke=PAPER, width=2)
    head += path("M118 114L128 119L143 111M102 59Q87 54 92 74M108 51Q99 38 112 38", stroke=MOSS, width=3)
    content += group(head, f"translate({death*12:.1f} {phase+death*42:.1f}) rotate({hurt*15+death*27:.1f} 127 105)")
    return group(content, f"translate(0 {death*85:.1f}) scale(1 {1-death*.38:.2f})")


def wisp(state, frame):
    phase, attack, hurt, death, walk = pose_values(state, frame)
    content = glow(128, 150, 121, .38)
    content += path(f"M125 83Q87 106 92 137Q{45+phase*8:.1f} 150 85 204Q39 216 74 247Q43 266 67 272Q102 308 143 273Q185 294 213 247Q187 260 183 235Q226 204 179 160Q192 103 149 84Z", "url(#ghost)", MOSS, 1)
    content += path(f"M104 154Q{73+phase*8:.1f} 188 118 226Q82 244 104 273M153 157Q196 191 146 245Q165 249 159 270", stroke=PAPER, width=1.4, extra='opacity=".6"')
    mask = path("M90 90Q95 63 128 65Q167 65 169 98L159 146L129 172L98 146Z", PAPER, GOLD, 1.8)
    mask += path("M98 87Q126 74 160 87L149 101L130 92L110 102Z", MOSS, TEAL)
    mask += path("M99 109Q110 100 122 111L112 120ZM139 110Q151 101 161 108L151 119Z", INK, TEAL)
    mask += path("M129 107L123 135L136 137M116 149Q129 155 144 147", stroke=TEAL, width=2)
    mask += path("M132 66L126 82L138 95L131 107M153 137L148 145L152 154", stroke="#ac8b64", width=1.2)
    mask += path("M94 100L86 96L89 137M167 98L176 96L171 136", stroke=GOLD, width=2)
    content += group(mask, f"translate({attack*11:.1f} {phase*3:.1f}) rotate({phase*3+hurt*18+death*35:.1f} 130 140)")
    for side in (-1, 1):
        x = 128+side*(77+attack*15)
        content += flame(x, 164+phase*side*16, .65, phase*5)
        content += path(f"M{x} {191+phase*side*16:.1f}q{-side*31} 24 {-side*13} 41", stroke=MOSS, width=1)
    return group(content, f"translate({walk*5:.1f} {phase*4+death*105:.1f}) scale(1 {1-death*.48:.2f})", f'opacity="{1-death*.66:.2f}"')


def brute(state, frame):
    phase, attack, hurt, death, walk = pose_values(state, frame)
    content = ""
    for x, direction in [(66,1), (94,-1), (159,1), (194,-1)]:
        leg = path(f"M{x} 191L{x-10+walk*direction*9:.1f} 263L{x+12+walk*direction*9:.1f} 268L{x+23} 202Z", "url(#stone)", MOSS, 1.6)
        leg += path(f"M{x-7+walk*direction*9:.1f} 256l-6 13h31l-5-12M{x+3} 220l-5 19", TEAL, GOLD, 1)
        content += group(leg, f"rotate({death*direction*33:.1f} {x} 214)")
    content += path("M52 160Q56 117 94 108L146 103L193 132L218 179L196 217L150 207L117 229L70 217Z", "url(#stone)", GOLD, 1.6)
    content += path("M68 148L57 117L88 117L89 88L112 106L130 81L145 108L170 97L174 123L199 119L196 150", TEAL, MOSS, 2)
    content += path("M94 121L104 147L82 169L101 189L85 211M133 120L126 154L144 175L125 196M169 133L158 155L178 192", stroke=INK, width=4)
    content += etch_lines(86, 128, 11, 13, 7)
    content += path("M90 110Q93 93 103 96M120 112Q131 105 135 121M156 127Q170 115 172 132", stroke=MOSS, width=4)
    head = path("M172 156L203 135L226 156L234 197L217 219L178 211L160 180Z", "url(#stone)", GOLD, 1.7)
    head += path("M181 150Q159 115 168 97Q182 125 197 137M216 144Q219 102 237 89Q226 124 232 157", "url(#gold)", PAPER, 1.1)
    head += path("M175 175L196 183L206 172M220 172L229 168M199 197L221 193L222 206L204 209Z", INK, GOLD, 1)
    head += path("M181 178L193 183M218 175L226 172", stroke=PAPER, width=3)
    head += path("M182 192L173 208L194 222L200 209", TEAL, MOSS, 1)
    content += group(head, f"rotate({-attack*29+hurt*18+death*35:.1f} 174 178) translate({attack*3:.1f} {phase*2:.1f})")
    content += path(f"M59 164Q{18+phase*5:.1f} 155 27 126L40 139", stroke=MOSS, width=8)
    return group(content, f"translate({attack*4-hurt*9-death*6:.1f} {death*105:.1f}) scale({1-death*.1:.2f} {1-death*.45:.2f})")


def boss(state, frame):
    phase, attack, hurt, death, walk = pose_values(state, frame)
    content = glow(128, 104, 113, .3)
    content += circle(128, 99, 78, "none", GOLD, 1.2, 'opacity=".55"')
    content += circle(128, 99, 87, "none", GOLD, .7, 'opacity=".36"')
    for i in range(16):
        angle = i*math.tau/16
        content += path(f"M{128+90*math.cos(angle):.1f} {99+90*math.sin(angle):.1f}L{128+96*math.cos(angle):.1f} {99+96*math.sin(angle):.1f}", stroke=GOLD)
    for side in (-1, 1):
        for row in range(3):
            arm = path("M0 0L23 16L42 0L49 9L26 34L1 22Z", "url(#stone)", GOLD, 1.3)
            arm += path("M8 5L7 23M18 12L16 28M29 20L42 8", stroke=MOSS, width=2)
            arm += path("M40 1L40-8L43-10L46-2L47-13L51-12L52-1L57-8L60-5L56 10L48 13Z", TEAL, GOLD)
            if row == 0:
                arm += flame(52, -19, .65, phase*4)
            if row == 2:
                arm += path("M51 5V85M40 78H63", stroke=GOLD, width=2)
                arm += lantern(52, 88, phase*5, .53, phase)
            content += group(arm, f"translate({128+side*(32+row*3)} {119+row*35}) scale({side} 1) rotate({-39+row*23+phase*(3+row)-attack*(35-row*9)+death*40:.1f})")
    robe = path("M98 123L69 200L38 290L88 277L125 306L165 279L218 290L185 198L155 123Z", "url(#cape)", GOLD, 1.7)
    robe += path("M103 133L90 260L128 284L165 259L150 135Z", TEAL, GOLD, 1.5)
    robe += path("M128 142V278M100 167H155M96 192H159M93 218H163M90 244H166", stroke=GOLD, width=1.2)
    for y in (167,192,218,244):
        robe += path(f"M119 {y-6}L128 {y-12}L137 {y-6}L128 {y+4}Z", "url(#gold)", PAPER, .5)
    robe += path("M74 269L89 256M172 256L185 272M62 271L77 240M179 233L199 274", stroke=PAPER, width=1.2)
    robe += etch_lines(86, 144, 12, 10, 6)
    content += group(robe, f"translate(0 {phase*2+death*45:.1f}) scale(1 {1-death*.15:.2f})")
    crown = path("M83 79L78 30L92 49L107 15L120 46L128 3L139 47L160 17L165 51L179 28L173 83L152 101H104Z", "url(#gold)", PAPER, 1.3)
    crown += path("M88 74L170 73M94 66L107 36L113 70M126 63L129 20L136 70M145 68L159 40L160 70", stroke="#896445", width=2)
    crown += path("M98 83L158 84L153 116L128 137L104 117Z", INK, GOLD, 1.2)
    crown += path("M106 98L121 105M138 104L151 97M125 110L128 120L134 112", stroke=PAPER, width=2.5)
    crown += path("M103 110L113 117M143 117L153 108M119 128L136 128", stroke=MOSS, width=1)
    crown += circle(129, 72, 6, RUST, PAPER)
    content += group(crown, f"translate({hurt*8+death*14:.1f} {phase*1.5+death*70:.1f}) rotate({hurt*10+death*26:.1f} 128 104)")
    return group(content, f"translate({walk*2:.1f} {2+death*66:.1f}) scale(1 {1-death*.34:.2f})")


def keeper(state, frame):
    phase, attack, hurt, death, walk = pose_values(state, frame)
    content = path("M100 224L89 288H120L127 241L139 288H168L155 223Z", INK, MOSS, 2)
    content += path(f"M98 130Q76 187 {67-phase*4:.1f} 274L105 265L131 282L172 267L186 277L159 130Z", "url(#stone)", GOLD, 1.5)
    content += path("M109 149L102 245L128 264L155 244L147 147Z", INK, GOLD)
    for y in (174,198,222):
        content += path(f"M107 {y}L127 {y+12}L150 {y}M113 {y+1}L127 {y+7}L143 {y}", stroke=MOSS)
    content += path("M88 257L106 250L128 272L165 252L172 261", stroke=GOLD, width=2)
    left = path("M103 139L78 176L92 199L108 184L117 155", TEAL, GOLD)
    left += path("M91 192L107 198L119 189L106 182Z", PAPER, GOLD)
    left += lantern(108, 216, phase*5, .64, phase)
    content += group(left, f"rotate({attack*30:.1f} 111 143)")
    right = path("M153 140L172 164L184 157L192 167L172 187L145 163Z", TEAL, GOLD)
    right += path("M188 95V288M175 101Q158 72 183 58Q212 56 208 77Q204 94 188 91", stroke=GOLD, width=4)
    right += path("M181 100Q194 122 206 108L199 134L187 126", RUST, GOLD)
    right += circle(188, 74, 6, PAPER)
    content += group(right, f"rotate({-attack*28+walk*4:.1f} 151 149)")
    head = path("M96 117L87 85L108 60L148 59L167 84L159 127L125 145Z", TEAL, GOLD, 1.4)
    head += path("M89 85L99 49L125 40L147 55L168 52L160 75L184 85L156 103L145 135L112 126L105 107L75 98Z", "url(#gold)", PAPER, 1.5)
    head += path("M96 82L110 78L123 91L111 99ZM138 83L155 78L153 92L137 101Z", INK, GOLD)
    head += path("M125 91L142 103L129 138L121 108Z", PAPER, "#9f8057", 1.2)
    head += path("M104 64L124 55L142 64M91 96L113 107M145 108L156 98", stroke="#937449")
    head += path("M110 123L101 145L120 136M147 125L154 144L136 136", RUST, GOLD)
    content += group(head, f"rotate({phase*2+attack*8+hurt*12+death*30:.1f} 128 131)")
    return group(content, f"translate({walk*3-death*65:.1f} {phase+death*55:.1f}) rotate({death*42:.1f} 128 235) scale(1 {1-death*.28:.2f})")


DRAW = dict(zip(CHARACTERS, (hero, moth, sentinel, wisp, brute, boss, keeper)))


def character(name, state, frame):
    death = frame/5 if state == "death" else 0
    content = '<ellipse cx="128" cy="299" rx="86" ry="10" fill="#08121e" opacity=".5"/>'
    content += group(DRAW[name](state, frame), "", f'opacity="{1-death*.27:.2f}"')
    if death:
        rng = random.Random(903)
        for _ in range(round(death*21)):
            x, y = rng.randrange(46, 216), rng.randrange(214, 293)
            content += path(f"M{x} {y}l4-7l6 8l-4 4Z", GOLD, "none", extra=f'opacity="{death*.65:.2f}"')
    return content


def make_characters():
    for name in CHARACTERS:
        svg(name, 320, 400, group(character(name, "idle", 0), "scale(1.25)"))
        sheet = ""
        for row, state in enumerate(STATES):
            for frame in range(6):
                # Godot の SVG 取り込みは入れ子 svg の x/y を扱わないため g で移動する。
                sheet += group(character(name, state, frame), f"translate({frame*256} {row*320})")
        svg(name+"_sheet", 1536, 1600, sheet)


def tower(x, y, width, height, opacity=1):
    c = path(f"M{x} {y}V{y-height*.84}L{x+width*.19} {y-height*.84}V{y-height*.94}L{x+width*.4} {y-height*.94}L{x+width*.5} {y-height}L{x+width*.6} {y-height*.94}H{x+width*.81}V{y-height*.84}H{x+width}V{y}Z", TEAL, "#53716a", 1)
    c += path(f"M{x+width*.5} {y-height*.98}V{y-height*.72}M{x-5} {y-height*.82}H{x+width+5}M{x-5} {y-height*.57}H{x+width+5}M{x-5} {y-height*.3}H{x+width+5}", stroke="#829281", width=1)
    for row in range(3):
        for col in range(3):
            wx, wy = x+width*(.17+col*.26), y-height*(.76-row*.26)
            c += path(f"M{wx} {wy+height*.13}V{wy+5}Q{wx+width*.06} {wy-5} {wx+width*.12} {wy+5}V{wy+height*.13}Z", INK, "#53716a", .7)
            if (row+col) % 3 == 1:
                c += path(f"M{wx+width*.04} {wy+height*.1}V{wy+height*.06}", stroke=GOLD, width=2)
    return group(c, extra=f'opacity="{opacity}"')


def sky():
    rng = random.Random(731)
    c = '<rect width="1280" height="720" fill="url(#night)"/>'
    c += glow(892, 198, 337, .38)
    c += circle(896, 170, 88, "#637b77", "#849084", 1, 'opacity=".23"')
    c += circle(896, 170, 78, "none", GOLD, .7, 'opacity=".33"')
    c += circle(930, 145, 64, "#213b47", extra='opacity=".9"')
    for _ in range(150):
        x, y = rng.randrange(1280), rng.randrange(25, 410)
        c += circle(x, y, rng.choice([.6,.8,1.2]), PAPER, extra=f'opacity="{rng.uniform(.15,.62):.2f}"')
    for index, color in enumerate(["#24444d", "#203c45", "#1b333f"]):
        y = 290+index*77
        c += path(f"M0 {y+90}Q150 {y-25} 277 {y+28}L428 {y-46}L535 {y+69}L681 {y+21}L794 {y+55}L952 {y-32}L1101 {y+17}L1280 {y-37}V720H0Z", color, "none")
    for x,y in [(55,180),(530,245),(1030,310)]:
        c += path(f"M{x} {y}q82-12 164 3t156-4M{x+20} {y+9}q78-7 165 3", stroke=MOSS, width=.7, extra='opacity=".16"')
    return c


def ruins():
    c = tower(817, 471, 146, 329, .55) + tower(756, 460, 48, 175, .45) + tower(978, 464, 43, 228, .42)
    c += path("M706 472L1280 455V720H571Z", "#132a35", "none")
    c += path("M720 720L846 466H909L1032 720Z", "#314b50", "#6d8175", .8)
    for i in range(14):
        t = i/13
        y = 479+t*t*241
        left, right = 846-(y-466)*.497, 909+(y-466)*.486
        c += path(f"M{left:.1f} {y:.1f}H{right:.1f}", stroke="#728679", width=.6, extra='opacity=".35"')
    for x,y,scale in [(93,509,1.3),(1146,531,1.1),(363,473,.55)]:
        column = path("M0 0V-225L9-239V-305L20-324L36-299V-238L44-223V0ZM-9-226H53M-5-235H49M9-239V-210M34-238V-211M9-196V-23M34-195V-23M-10 0H54", "#102630", "#3b565c", 1)
        column += path("M11-180L24-172L17-150L33-138M2-41L15-56L35-48", stroke="#6f7f70", width=.7)
        c += group(column, f"translate({x} {y}) scale({scale})")
    c += path("M-20 148Q235-20 456 182M-10 180Q223 5 427 189", stroke="#17313c", width=34)
    c += path("M-20 148Q235-20 456 182", stroke="#426069", width=1.5)
    c += path("M0 560Q200 524 455 574Q610 558 731 606L1280 625V720H0Z", "#102632", "none")
    for i in range(21):
        x = i*67
        c += path(f"M{x} 605l38-5l20 9M{x+12} 656l46 5l21-5", stroke=MOSS, width=.6, extra='opacity=".18"')
    return c


def foreground():
    rng = random.Random(421)
    c = path("M0 670Q156 647 303 683Q668 665 854 688Q1060 655 1280 650V720H0Z", "#091724", "none")
    for _ in range(55):
        x = rng.randrange(1280)
        height = rng.randrange(13, 73)
        base = 701+rng.randrange(17)
        c += path(f"M{x} {base}q-3-{height//2} 10-{height}M{x+4} {base-height//2}q-20-3-15-19M{x+6} {base-height//2-8}q21-5 19-21", stroke="#345352", width=1.4)
    for x,y,scale in [(48,638,.65),(1220,607,.8)]:
        c += group(lantern(0,0,0,1,0), f"translate({x} {y}) scale({scale})")
        c += path(f"M{x} {y+24}V720", stroke=TEAL, width=7)
    return c


def make_backgrounds():
    svg("bg_sky", 1280, 720, sky())
    svg("bg_ruins", 1280, 720, ruins())
    svg("bg_foreground", 1280, 720, foreground())
    svg("background", 1280, 720, sky()+ruins()+foreground())
    keyart = group(sky()+ruins(), "translate(-240 0) scale(1.2)")
    keyart += glow(473, 405, 286, .65)
    keyart += path("M0 746L181 626L356 651L529 578L699 661L1000 626V800H0Z", INK, "#6f7763", 1)
    keyart += path("M389 800L559 612L623 619L560 800Z", "#2c4347", MOSS, .8)
    for i in range(8):
        keyart += path(f"M{539-i*15} {638+i*19}l{84+i*4} 5", stroke=GOLD, extra='opacity=".22"')
    keyart += group(hero("idle", 1), "translate(234 170) scale(1.65)")
    keyart += group(foreground(), "translate(-150 90) scale(1.1)")
    keyart += path("M740 160Q781 141 813 162M754 171Q776 160 794 171", stroke=GOLD, width=.7, extra='opacity=".45"')
    svg("title_keyart", 1000, 800, keyart)
    emblem = circle(160, 160, 130, "none", GOLD, 1.2)
    emblem += circle(160, 160, 116, "none", GOLD, .7)
    for i in range(12):
        a = i*math.tau/12
        x,y = 160+124*math.cos(a), 160+124*math.sin(a)
        emblem += circle(round(x,2), round(y,2), 2.4, GOLD)
    emblem += path("M160 16L168 40L160 49L152 40ZM160 271L168 280L160 304L152 280ZM16 160L40 152L49 160L40 168ZM271 160L280 152L304 160L280 168Z", GOLD, PAPER, .8)
    emblem += group(lantern(160,155,0,2.8,0))
    emblem += path("M66 178Q61 234 128 260M254 178Q259 234 192 260M70 189l-18-9M73 205l-21-3M81 221l-20 6M92 236l-17 12M250 189l18-9M247 205l21-3M239 221l20 6M228 236l17 12", stroke=GOLD, width=1.2)
    svg("logo_mark", 320, 320, emblem)


def icon_shapes():
    return {
        "attack": path("M18 46L43 11L47 11L47 26L27 48ZM17 36L31 47M19 44L11 55", INK, GOLD, 2.5),
        "block": path("M13 16L32 8L51 16L47 39L32 55L17 40ZM32 17V44M21 27L32 21L43 27L32 40Z", TEAL, GOLD, 2),
        "energy": path("M35 5L14 35H28L24 59L51 26H36Z", TEAL, GOLD, 2),
        "relic": lantern(32, 28, 0, .85),
        "battle": path("M13 10L34 38L30 43L10 20ZM50 10L32 36L37 42L54 20ZM21 36L9 52M43 35L55 52M12 34L28 46M52 34L36 47", TEAL, GOLD, 2),
        "elite": path("M8 21L17 28L15 9L28 22L33 7L40 23L53 11L49 30L57 23L49 44L33 56L16 43ZM20 35L28 39M38 39L46 34M29 46H36", TEAL, GOLD, 2),
        "rest": flame(32, 35, 1) + path("M11 51L52 58M12 58L52 50", stroke=GOLD, width=3),
        "card": path("M13 8L48 12L53 55L17 57ZM21 18L42 20L45 44L25 46ZM24 48L44 48", TEAL, GOLD, 2) + flame(34, 34, .4),
        "event": path("M12 21L32 6L53 22ZM18 25H46V54H18ZM10 57H54M25 53V34Q32 27 39 34V53", TEAL, GOLD, 2),
        "boss": path("M11 10L21 25L32 5L42 26L55 9L49 41L32 57L15 41ZM19 31L28 36M36 36L45 30M26 43L32 49L38 43", TEAL, GOLD, 2),
    }


def make_ui():
    icons = icon_shapes()
    for name in ("attack", "block", "energy", "relic"):
        svg("icon_"+name, 64, 64, icons[name])
    for name in ("battle", "elite", "rest", "card", "event", "boss"):
        svg("route_"+name, 64, 64, icons[name])
    for name, icon in [("attack", "attack"), ("block", "block"), ("skill", "energy")]:
        color = RUST if name == "attack" else MOSS
        c = '<rect x="3" y="3" width="234" height="314" rx="12" fill="#172c37" stroke="#d9b66f" stroke-width="2"/>'
        c += '<rect x="10" y="10" width="220" height="300" rx="8" fill="none" stroke="#61736c"/>'
        c += path("M13 44H227V159H13Z", color, "none", extra='opacity=".18"')
        c += circle(120, 101, 46, "none", GOLD, 1, 'opacity=".5"')
        c += group(icons[icon], "translate(88 69)")
        c += path("M26 174H214M26 275H214M18 33V18H33M207 18H222V33M18 287V302H33M207 302H222V287", stroke=GOLD, extra='opacity=".65"')
        svg("card_"+name, 240, 320, c)
    svg("fx_spark", 16, 32, path("M8 1L12 15L8 31L4 15Z", "#ffffff", "none"))
    svg("fx_glow", 32, 32, '<defs><radialGradient id="particle"><stop stop-color="#ffffff"/><stop offset=".3" stop-color="#ffffff" stop-opacity=".8"/><stop offset="1" stop-color="#ffffff" stop-opacity="0"/></radialGradient></defs><circle cx="16" cy="16" r="16" fill="url(#particle)"/>')


def make_relics():
    ember = glow(48, 48, 45, .6)
    ember += path("M29 16L61 12L82 42L71 78L34 86L13 57Z", "url(#stone)", GOLD, 1.5)
    ember += path("M32 23L45 42L35 52L56 60L53 80M62 24L59 43L72 53M22 60L36 54", stroke=RUST, width=3)
    ember += flame(50, 48, .62)
    shell = path("M47 82Q1 58 17 29Q33 5 56 15Q88 23 81 55Q75 83 47 82Z", "url(#gold)", PAPER, 1.5)
    shell += path("M48 80Q21 61 27 37Q35 20 53 28Q70 32 67 51Q66 65 52 66Q40 65 40 51Q41 42 50 43Q58 45 52 52M20 30L30 35M14 44L26 46M19 62L31 59M29 74L38 68", stroke="#886046", width=2)
    seed = path("M44 82Q13 76 22 51Q33 39 46 48Q64 34 76 48Q88 78 44 82Z", "url(#gold)", PAPER, 1.5)
    seed += path("M46 68Q34 39 52 19M48 34Q22 32 21 12Q43 8 48 34M49 28Q52 7 77 10Q77 30 49 34", MOSS, GOLD, 1.3)
    seed += path("M46 51L39 57L43 74M54 51L58 63L52 77M30 20L42 29M69 16L54 28", stroke=TEAL, width=1.4)
    for name, c in [("ember", ember), ("shell", shell), ("seed", seed)]:
        svg("relic_"+name, 96, 96, c)


def make_card_illustrations():
    blade = path("M65 70L127 14L137 13L134 24L78 76ZM61 58L82 77M67 68L53 82", "url(#gold)", PAPER, 1)
    shield = group(icon_shapes()["block"], "translate(65 8) scale(1.05)")
    arts = {
        "strike": blade+flame(136,30,.55)+path("M58 23Q130 9 155 55", stroke=RUST, width=3),
        "guard": shield+path("M48 63Q95 86 151 63M55 22L48 37M145 23L153 40", stroke=MOSS, width=2),
        "fracture": blade+path("M79 60L111 51L131 61L126 84H86ZM102 58L97 70L108 75L106 83M117 53L125 42M134 66L150 69", TEAL, GOLD, 1.5),
        "quick": group(blade, "translate(19 -6) scale(.85)")+path("M34 37H84M24 49H72M39 59H65", stroke=PAPER, width=2),
        "heavy": path("M107 4L74 41H100L87 78L130 31H105Z", "url(#gold)", PAPER, 1)+path("M61 71L86 63L106 83L130 64L153 77", stroke=RUST, width=2),
        "siphon": flame(104,49,1.4)+path("M50 68Q52 32 78 28M145 23Q165 61 132 72M48 69L45 55M131 71L146 69", stroke=MOSS, width=2),
        "feint": group(blade,"translate(16 -5)")+path("M23 59Q55 38 101 54T175 47M27 70Q71 49 116 65", stroke=MOSS, width=4, extra='opacity=".7"'),
        "flow": blade+path("M31 68Q63 31 114 40Q151 49 170 21M29 77Q71 43 126 52Q154 57 177 37", stroke=MOSS, width=2),
        "fortress": path("M51 77V25H67V37H81V18H97V37H111V18H127V37H141V25H153V77ZM53 50H151M52 65H150M71 50V64M119 50V64M96 65V77M91 76V58Q102 44 113 58V76", TEAL, GOLD, 1.8),
        "insight": path("M39 47Q98-3 161 47Q101 92 39 47Z", TEAL, GOLD, 1.4)+circle(100,47,19,"url(#gold)")+circle(100,47,9,INK)+path("M100 11V2M100 84V89M44 22L36 14M155 23L164 16", stroke=MOSS),
        "renew": glow(100,48,43)+path("M70 73Q113 70 112 22M105 56Q72 50 74 28Q102 28 109 48M112 39Q116 14 143 20Q142 46 109 48", MOSS, GOLD, 1.4)+circle(97,66,4,PAPER),
        "charge": lantern(100,41,0,1.15)+path("M47 29L71 43M148 24L128 39M43 65L70 57M150 62L130 53", stroke=RUST, width=2.5),
        "smoke": path("M36 65Q23 43 49 39Q38 17 65 19Q74 4 96 22Q124 7 138 29Q169 24 168 50Q179 68 148 73H50Z", "url(#stone)", MOSS, 1.5)+path("M44 51Q61 34 78 49T118 47T155 49M55 65Q86 56 108 64", stroke=PAPER, extra='opacity=".6"'),
        "expose": shield+path("M105 13L88 39L103 47L83 79M117 39L143 30M114 50L153 54M113 62L139 73", stroke=RUST, width=3),
        "fervor": flame(104,54,1.8)+circle(102,47,35,"none",GOLD,.7)+path("M53 58L43 65M151 57L162 64M68 14L61 4M136 14L143 3", stroke=RUST, width=2),
        "aegis": shield+lantern(98,41,0,.6)+path("M50 68Q31 42 52 14M147 14Q169 45 149 69", stroke=MOSS, width=2),
        "focus": circle(100,44,31,"none",GOLD,1)+circle(100,44,22,"none",MOSS,1)+path("M75 64Q100 14 125 64Q99 46 75 64Z", TEAL, GOLD, 1.5)+circle(100,36,5,PAPER)+path("M54 45H40M147 45H161M100 8V1M100 80V88", stroke=GOLD),
        "bash": group(shield,"rotate(-16 99 45)")+path("M139 19L134 35L160 36L139 50L149 65M152 13L155 5M162 49L177 51", stroke=RUST, width=3),
    }
    for name, art in arts.items():
        c = '<rect width="200" height="90" rx="6" fill="#162e38"/>'
        c += glow(103,45,82,.3)
        for i in range(5):
            c += path(f"M{12+i*37} 81l19-7M{19+i*38} 9l13 4", stroke=MOSS, width=.6, extra='opacity=".25"')
        c += art
        c += path("M8 22V8H23M177 8H192V22M8 68V82H23M177 82H192V68", stroke=GOLD, width=.7, extra='opacity=".5"')
        svg("card_"+name, 200, 90, c)


def main():
    make_characters()
    make_backgrounds()
    make_ui()
    make_relics()
    make_card_illustrations()
    print(f"独自 SVG {len(list(ART.glob('*.svg')))}点を生成しました。")


if __name__ == "__main__":
    main()
