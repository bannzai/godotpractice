#!/usr/bin/env python3
"""墨線・鎧の細線・独立した部位の変形で、墨将紀の美術を決定的に再生成する。"""

import argparse
import json
import math
from pathlib import Path
import random

INK = "#171e22"
PAPER = "#e8ddbd"
GOLD = "#c1a466"
RED = "#aa4839"
JADE = "#7b9990"
BLUE = "#3d6368"
BLACK = "#0d1419"
STATES = ("idle", "move", "attack", "hurt", "death")
CHARACTERS = ("reed", "blade", "veil", "bow", "oracle", "wraith", "shield", "lancer",
              "monk", "drummer", "fox", "dragon", "hero", "scout", "duelist", "general",
              "final", "merchant", "rest")
FRAME_COUNT = 4
DEFS = '''<defs>
<linearGradient id="sky" x2="0" y2="1"><stop stop-color="#15232c"/><stop offset=".54" stop-color="#496465"/><stop offset="1" stop-color="#818478"/></linearGradient>
<linearGradient id="armor" x2=".9" y2="1"><stop stop-color="#617876"/><stop offset=".46" stop-color="#293f44"/><stop offset="1" stop-color="#101d26"/></linearGradient>
<linearGradient id="cloth" x2=".9" y2="1"><stop stop-color="#d47952"/><stop offset=".5" stop-color="#a54839"/><stop offset="1" stop-color="#482932"/></linearGradient>
<linearGradient id="white" x2=".5" y2="1"><stop stop-color="#f6edcf"/><stop offset=".55" stop-color="#d3c5a3"/><stop offset="1" stop-color="#7e887d"/></linearGradient>
<linearGradient id="gold" x2=".7" y2="1"><stop stop-color="#f0d399"/><stop offset=".5" stop-color="#ba9857"/><stop offset="1" stop-color="#735b38"/></linearGradient>
<radialGradient id="halo"><stop stop-color="#d7d0a4" stop-opacity=".42"/><stop offset="1" stop-color="#d7d0a4" stop-opacity="0"/></radialGradient>
<radialGradient id="glow"><stop stop-color="#ffffff"/><stop offset=".2" stop-color="#ffffff" stop-opacity=".8"/><stop offset="1" stop-color="#ffffff" stop-opacity="0"/></radialGradient>
</defs>'''


def path(d, fill="none", stroke=INK, width=1.5, extra=""):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round" {extra}/>'


def circle(x, y, radius, fill="none", stroke="none", width=1, extra=""):
    return f'<circle cx="{x}" cy="{y}" r="{radius}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" {extra}/>'


def group(content, transform="", extra=""):
    return f'<g transform="{transform}" {extra}>{content}</g>'


def svg(content, width, height):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">{DEFS}{content}</svg>\n'


def crest(x, y, scale=1):
    c = circle(0, 0, 14, "none", GOLD, 1.4)
    for angle in (0, 120, 240):
        c += group(path("M0-12Q14-9 10 3L0 1Q5-4 0-12Z", GOLD, "none"), f"rotate({angle})")
    return group(c, f"translate({x} {y}) scale({scale})")


def etch(x, y, width, rows=5, spacing=6, tint=GOLD):
    c = ""
    for row in range(rows):
        c += path(f"M{x} {y+row*spacing}l{width} 2", stroke=tint, width=.8, extra='opacity=".68"')
        for column in range(1, max(2, int(width // 8))):
            xx = x + column*8 + (row % 2)*2
            c += path(f"M{xx} {y+row*spacing-1}v3", stroke=BLACK, width=1)
    return c


def values(state, frame):
    phase = (0, 1, -.55, -1)[frame]
    attack = (0, -.45, 1, .45)[frame] if state == "attack" else 0
    hurt = (0, 1, .6, .15)[frame] if state == "hurt" else 0
    death = frame / 3 if state == "death" else 0
    walk = phase if state == "move" else 0
    return phase, attack, hurt, death, walk


def blade(x, y, angle=0, long=False):
    tip = -110 if long else -83
    c = path(f"M-3 0L-2 {tip+13}L4 {tip}L6-3Z", "url(#white)", GOLD, 1)
    c += path(f"M1-9L2 {tip+13}", stroke=JADE, width=.7)
    c += path("M-11 1H13M-3 3L-2 29H5L5 4Z", INK, GOLD, 2)
    c += path("M-2 8L4 12M-2 15L4 19M-2 22L4 26", stroke=RED, width=2)
    return group(c, f"translate({x} {y}) rotate({angle})")


def spear(x, y, angle=0, banner=False):
    c = path("M0-115V112", stroke=GOLD, width=3)
    c += path("M0-144L-8-117L0-104L8-117Z", "url(#white)", INK, 1)
    c += path("M0-138V-110", stroke=JADE, width=.8)
    if banner:
        c += path("M3-107Q32-116 44-104L39-38Q24-47 4-37Z", "url(#cloth)", GOLD, 1)
        c += crest(22, -76, .7)
        c += path("M8-44L31-47M9-101L31-104", stroke=PAPER, width=.6)
    return group(c, f"translate({x} {y}) rotate({angle})")


def talisman(x, y, angle=0, scale=1):
    c = path("M-10-21H10L12 22L-8 25Z", "url(#white)", GOLD, .9)
    c += path("M-5-12H5M0-17V-5M-5-1L5 2M2-5L-3 13M-5 8L5 7M-3 17H6", stroke=RED, width=1.4)
    return group(c, f"translate({x} {y}) rotate({angle}) scale({scale})")


def head(style, phase, attack, hurt, death):
    face = path("M108 84L113 114L128 126L143 113L147 82Z", "url(#white)", INK, 2)
    face += path("M114 100L122 99M135 99L142 97M128 101L125 109L131 111M122 117L134 116", stroke=INK, width=1.7)
    if style in ("veil", "scout"):
        face = path("M98 78Q102 57 132 57Q156 61 160 86L153 122L128 132L105 117Z", INK, JADE, 1.2)
        face += path("M108 89L149 84L147 98L111 102Z", PAPER, BLACK)
        face += path("M113 94L122 95M135 93L143 90", stroke=BLACK, width=2)
        face += path("M106 106L150 101M111 114L145 112M127 62L122 80", stroke=BLUE, width=2)
        face += path(f"M147 72Q185 {55+phase*7} 218 {82-phase*10}L191 90L157 82Z", RED, INK)
    elif style == "oracle":
        face += path("M104 87L106 59L116 49L113 15L143 9L147 55L156 64L153 88Z", INK, GOLD, 1.6)
        face += path("M118 48L138 43M118 24L136 20M109 74H150", stroke=BLUE, width=3)
        face += talisman(129, 69, 0, .55)
    elif style in ("reed", "lancer"):
        face += path("M74 88L125 48L181 89Q127 103 74 88Z", "url(#gold)", INK, 2.5)
        for index in range(8):
            face += path(f"M126 54L{83+index*13} 88", stroke="#695f43", width=1.1)
        face += path("M83 88Q127 96 170 87M106 88L109 117M150 89L145 118", stroke=INK, width=2)
    elif style == "monk":
        face += path("M106 85Q103 56 128 56Q154 55 150 86", "url(#white)", INK, 2)
        face += path("M109 77L148 77M116 72L139 69", stroke=RED, width=4)
        face += circle(128, 87, 2.5, RED)
        face += path("M119 120Q128 145 140 117L128 124Z", PAPER, INK)
    elif style == "merchant":
        face += path("M99 87L105 68Q132 50 154 68L161 87Z", BLUE, GOLD, 1.7)
        face += path("M100 79Q130 66 156 78", stroke=GOLD, width=3)
        face += path("M113 110L125 106L132 110L142 106M117 119Q129 128 141 116", stroke=INK, width=2)
    elif style == "rest":
        face += path("M94 101Q88 51 126 51Q164 49 163 104L151 119L143 90L105 92L106 119Z", INK, GOLD, 1.3)
        face += path("M101 71Q131 85 156 66M105 66Q128 76 145 61", stroke=BLUE, width=2)
        face += path("M151 67L172 60M156 60L162 76", stroke=GOLD, width=3)
        face += path("M118 115L132 114", stroke=RED, width=2)
    else:
        noble = style in ("hero", "general", "final")
        face += path("M89 91L96 65Q126 46 154 64L169 93L157 100L153 120L144 126L148 90L109 91L111 124L96 114L96 97Z", "url(#armor)", GOLD, 1.8)
        face += path("M95 87Q128 72 163 87M124 60L124 82M105 67L104 84M145 65L150 84", stroke=GOLD, width=1.3)
        face += crest(129, 79, .5)
        if style == "general":
            face += path("M91 65Q73 34 92 18Q81 45 121 51Q158 53 170 21Q174 60 139 70Z", "url(#gold)", PAPER, 1)
            face += path("M82 87L59 73L64 111L91 117M169 89L185 73L189 108L164 119", "url(#cloth)", GOLD, 1.4)
        elif noble:
            face += path("M123 76Q86 56 84 22L102 39L105 54L126 64L150 50L160 21L170 14Q174 55 136 76Z", "url(#gold)", PAPER, 1)
        if style == "final":
            face += path("M122 61L127 15L137 3L146 21L137 59Z", "url(#cloth)", GOLD, 1)
            face += path("M109 105L119 108L127 103L135 107L147 102L141 129L125 139L111 128Z", RED, GOLD, 1.1)
            face += path("M116 117L125 114L137 115M121 125L134 123", stroke=PAPER, width=1)
        elif style == "duelist":
            face += path("M111 103L117 112L128 110L138 114L146 102L139 132L119 134Z", INK, RED, 1)
        elif style == "bow":
            face += path("M150 57L175 25L177 66L154 80Z", PAPER, GOLD, 1)
    return group(face, f"rotate({phase*1.8+hurt*14+death*30:.2f} 128 111)")


def humanoid(style, state, frame):
    phase, attack, hurt, death, walk = values(state, frame)
    noble = style in ("hero", "general", "final")
    cloth = style in ("oracle", "monk", "rest", "merchant")
    slim = style in ("veil", "scout", "bow", "duelist")
    c = ""
    if style == "general":
        c += path("M57 48L46 226M61 48L31 45L19 120L49 123Z", "url(#cloth)", GOLD, 2)
        c += crest(41, 84, .78)
    elif style == "final":
        c += path("M97 113L57 63L41 56L53 112L28 100L57 155L77 171M154 114L193 62L210 51L198 109L225 95L204 155L180 173", "url(#armor)", GOLD, 2)
    if noble:
        c += path(f"M92 116Q47 143 {49-attack*12:.1f} 266L83 254L98 276L135 260L179 277L207 269Q191 163 156 118Z", "url(#cloth)", INK, 2.6)
        c += path(f"M80 151Q66 213 69 255M178 151Q190 205 195 258M94 181L98 260M165 185L176 262", stroke=GOLD, width=1.1, extra='opacity=".7"')
    elif style in ("veil", "scout"):
        c += path(f"M105 122Q56 95 {25+phase*6} {150+phase*10}L64 139L89 152L113 138Z", "url(#cloth)", INK, 2)
    if style == "bow":
        c += path("M152 156L167 78L180 80L166 174Z", BLUE, GOLD, 2)
        c += path("M168 95L178 48M173 97L185 49M178 98L192 53M179 49L176 41L175 51M186 49L184 39L182 52M192 53L193 43L188 54", stroke=PAPER, width=1.8)
    if style == "merchant":
        c += path("M86 137L59 134L41 187L57 242L105 238Z", "url(#gold)", INK, 2)
        c += path("M54 151L91 171M51 207L87 204M50 224L94 215", stroke=BLUE, width=4)
    for side in (-1, 1):
        leg = path("M103 221L127 223L122 274L120 290L96 290L95 282L103 274Z", INK, GOLD, 1.4)
        leg += path("M103 248L121 248M102 259L119 260M99 273L118 274", stroke=JADE, width=1.5)
        if side == 1:
            leg = group(leg, "translate(256 0) scale(-1 1)")
        c += group(leg, f"rotate({side*walk*13:.1f} {128+side*14} 222)")
    if cloth:
        garment = path("M104 119L151 120L177 247L193 280L151 274L127 284L91 276L63 282L78 247Z", "url(#white)" if style in ("oracle", "rest") else "url(#cloth)", INK, 2.5)
        garment += path("M104 126L132 157L151 127M129 158L117 268M149 153L158 262M89 186L83 264M172 199L178 265", stroke=BLUE, width=2)
        garment += path("M84 219L118 221M141 241L168 242M92 273L111 269", stroke=GOLD, width=1.3)
        garment += path("M91 179L159 177L161 192L88 195Z", BLUE, GOLD, 1.4)
        garment += crest(129, 185, .45)
    elif slim:
        garment = path("M102 122L149 122L162 197L150 234L125 217L107 239L92 208Z", "url(#armor)", INK, 2)
        garment += path("M103 128L148 186M146 128L102 177M93 187L155 187L158 201L94 205Z", INK, GOLD, 1)
        garment += etch(111, 153, 30, 4)
        garment += path("M98 216L112 207M133 215L151 223", stroke=RED, width=4)
    else:
        garment = path("M98 120L155 120L167 179L163 207L180 251L151 260L129 248L105 260L77 249L92 207L88 177Z", "url(#armor)", INK, 2.6)
        garment += path("M103 123L106 180L149 180L150 125M98 192L158 192M91 206L165 206M107 209L99 250M128 211V245M149 209L156 251", stroke=GOLD, width=2)
        garment += etch(109, 132, 36, 7)
        garment += etch(90, 218, 70, 5, 6, JADE)
        garment += path("M88 183L164 180L166 192L89 197Z", RED, GOLD, 1.5)
        garment += crest(126, 189, .55)
    rng = random.Random(115+CHARACTERS.index(style))
    for _ in range(23):
        x, y = rng.randrange(107,148), rng.randrange(144,238)
        garment += path(f"M{x} {y}l{rng.randrange(2,6)}-1", stroke=INK, width=.75, extra='opacity=".33"')
    c += group(garment, f"translate({hurt*-5:.1f} {phase*1.4:.1f})")
    # 左右の肩・袖は武具から独立した支点で回転する。
    for side in (-1, 1):
        shoulder = 102 if side == -1 else 151
        width = 32 if noble or style in ("shield", "drummer") else 23
        sleeve = path(f"M{shoulder} 125L{shoulder+side*width} 132L{shoulder+side*(width+7)} 178L{shoulder+side*12} 190L{shoulder-side*5} 159Z", "url(#white)" if cloth else "url(#armor)", INK, 2)
        if not cloth:
            sleeve += path(f"M{shoulder-side*3} 132L{shoulder+side*(width+6)} 137L{shoulder+side*(width+8)} 157L{shoulder+side*3} 153Z", "url(#cloth)" if noble else "url(#armor)", GOLD, 1.2)
            for row in range(3):
                sleeve += path(f"M{shoulder+side*2} {136+row*6}l{side*(width+1)} 4", stroke=GOLD, width=1)
        sleeve += path(f"M{shoulder+side*12} 179l{side*12}-5l6 14l-13 7Z", "url(#white)", INK, 1.5)
        angle = side*(phase*2 + walk*7) + (attack*46 if side == 1 else -attack*22) + hurt*side*13
        c += group(sleeve, f"rotate({angle:.2f} {shoulder} 133)")
    c += equipment(style, phase, attack, hurt, death)
    c += head(style, phase, attack, hurt, death)
    return group(c, f"translate({walk*3+attack*8-death*16:.2f} {phase*1.1+death*54:.2f}) rotate({hurt*-6+death*24:.2f} 128 218) scale(1 {1-death*.22:.3f})")


def equipment(style, phase, attack, hurt, death):
    c = ""
    if style in ("reed", "lancer", "scout"):
        c += spear(187, 160, -8-attack*28+phase*2, style == "lancer")
    elif style == "bow":
        bow = path("M189 59Q224 100 193 148Q220 189 179 238M189 63L164 148L179 234", stroke=GOLD, width=3)
        bow += path(f"M189 59L{160-attack*22:.1f} 146L179 238M{158-attack*22:.1f} 146H221M215 143L223 147L214 151", stroke=PAPER, width=1)
        c += group(bow, f"rotate({attack*-8:.1f} 180 148)")
    elif style == "oracle":
        c += talisman(77-attack*17, 171-attack*16, phase*10-attack*35)
        c += talisman(192+attack*8, 153-attack*31, phase*-10+attack*26)
        c += path("M178 175L186 135L188 101", stroke=INK, width=4)
        c += path("M188 99L205 86L200 104L215 99L204 118L216 124L199 135L203 147L188 146Z", PAPER, GOLD, 1)
    elif style == "shield":
        c += path("M49 145L84 127L104 147L107 245L74 271L44 242Z", "url(#armor)", GOLD, 3)
        c += path("M55 157L81 145L93 158V236L75 253L55 234ZM75 146V253", stroke=GOLD, width=1.5)
        c += crest(75, 190, 1.1)
        c += blade(183, 183, 18-attack*55)
    elif style == "monk":
        c += path("M187 70V284", stroke=GOLD, width=4)
        c += circle(187, 62, 20, "none", GOLD, 3)
        for x, y in ((174, 70), (181, 78), (193, 78), (201, 69)):
            c += circle(x, y, 6, "none", PAPER, 1)
        for index in range(9):
            angle = math.pi*index/8
            c += circle(round(127-33*math.cos(angle), 2), round(137+36*math.sin(angle), 2), 4, "url(#gold)", INK, .9)
    elif style == "drummer":
        c += path("M80 149L171 152L178 213L82 212Z", "url(#cloth)", INK, 3)
        c += '<ellipse cx="127" cy="154" rx="47" ry="21" fill="url(#white)" stroke="#c1a466" stroke-width="2"/>'
        c += path("M84 166L95 210L108 172L126 210L144 172L162 212L172 164", stroke=GOLD, width=2)
        c += group(path("M71 164L102 121", stroke=PAPER, width=5), f"rotate({attack*65+phase*3:.1f} 72 170)")
        c += group(path("M185 168L158 117", stroke=GOLD, width=5), f"rotate({attack*-60-phase*4:.1f} 183 174)")
    elif style == "merchant":
        c += path("M159 178L173 164L192 178L188 210Q173 225 157 210Z", "url(#gold)", INK, 2)
        c += path("M159 178H190M166 180L164 207M179 181L181 209", stroke=INK, width=1.2)
        c += circle(174, 198, 8, "none", PAPER, 1.5)
        c += path("M70 180L82 151L108 161L101 191Z", PAPER, GOLD, 1)
        c += path("M82 162L99 168M79 168L98 175M77 175L97 181", stroke=RED, width=1.5)
    elif style == "rest":
        c += path("M61 184H99L96 201Q80 216 65 200Z", "url(#armor)", GOLD, 2)
        c += path(f"M76 184Q{60+phase*4} 166 79 151Q91 138 78 125M85 176Q97 160 88 149", stroke=PAPER, width=1.3, extra='opacity=".75"')
        c += path("M168 172L203 161L194 184L179 194Z", "url(#cloth)", GOLD, 1.8)
    else:
        c += blade(180, 184, 23-attack*62+phase*2, style in ("general", "final"))
        if style == "duelist":
            c += blade(82, 179, -44+attack*40, True)
        if style == "hero":
            fan = path("M67 184L38 151Q68 125 94 148Z", "url(#white)", GOLD, 1.2)
            for x in (45, 55, 67, 79, 87):
                fan += path(f"M67 184L{x} 148", stroke=INK, width=.7)
            fan += circle(67, 157, 9, RED)
            c += group(fan, f"rotate({attack*35:.1f} 68 184)")
    return c


def spirit(style, state, frame):
    phase, attack, hurt, death, walk = values(state, frame)
    c = circle(128, 139, 103, "url(#halo)")
    if style == "fox":
        for index in range(5):
            tail = path("M132 237Q31 248 37 126Q17 140 13 174Q-1 255 112 271Z", "url(#white)", INK, 2.2)
            tail += path("M22 180Q31 226 90 247M35 158L21 183L33 188", stroke=RED, width=2)
            c += group(tail, f"rotate({index*24+phase*(index+1):.1f} 130 254)")
        body = path("M110 136Q92 169 99 211L84 249L126 269L169 248L151 209L150 145Z", "url(#cloth)", INK, 2)
        body += path("M118 151L127 229L138 151M99 215L155 215M106 244L149 244", stroke=GOLD, width=2)
        body += path("M98 146L57 172L65 188L116 176M153 150L184 130L192 149L158 178", PAPER, INK, 2)
        body += talisman(187, 137-attack*30, attack*40, .7)
        face = path("M92 102L83 41L117 71L146 67L180 38L165 105L142 136L115 134Z", "url(#white)", INK, 2.5)
        face += path("M92 53L110 78L98 85ZM169 53L150 80L164 83Z", RED, INK, 1)
        face += path("M103 102L118 108L106 91M143 107L157 99L157 87M119 122L131 128L142 121M125 118L136 117L131 123Z", RED, INK, .8)
        face += crest(132, 89, .46)
        c += body + group(face, f"rotate({phase*3+hurt*14+attack*-9:.1f} 128 123)")
    elif style == "dragon":
        coils = path(f"M149 237Q43 287 51 215Q54 177 118 201Q187 225 195 165Q202 106 151 83Q103 64 91 105", "none", INK, 39)
        coils += path("M149 237Q43 287 51 215Q54 177 118 201Q187 225 195 165Q202 106 151 83Q103 64 91 105", "none", JADE, 32)
        coils += path("M147 235Q61 271 64 220Q77 202 123 220Q204 233 207 161Q211 98 153 78", "none", GOLD, 8)
        for index in range(14):
            x, y = 52+index*10, 218+math.sin(index*.55)*13
            coils += path(f"M{x} {y:.1f}l6-7l5 8M{x} {y+8:.1f}l6-7l5 8", stroke=BLUE, width=1.3)
        coils += path("M191 152L223 170L233 158M215 165L211 183M166 213L183 247L199 251M181 242L174 257M77 204L57 178L35 183M53 179L47 163", stroke=INK, width=7)
        coils += path("M191 152L223 170L233 158M166 213L183 247L199 251M77 204L57 178L35 183", stroke=GOLD, width=3)
        face = path("M89 102L64 95L47 115L56 136L88 145L107 132L117 107L112 79L96 87Z", "url(#armor)", GOLD, 2)
        face += path("M92 96L86 50L72 38L73 58L82 68M108 86L125 49L143 42L134 63L118 73", stroke=GOLD, width=6)
        face += path("M67 116L89 117L77 109M54 132L84 133L89 127M66 139Q36 164 25 143M106 128Q121 145 150 137", stroke=PAPER, width=2)
        face += path("M93 81L104 53L106 78L123 60L118 92L132 81L122 107", RED, GOLD, 1)
        c += group(coils, f"rotate({phase*2:.1f} 127 178)")
        c += group(face, f"translate({-attack*13:.1f} {attack*-6:.1f}) rotate({phase*3+attack*-15:.1f} 106 113)")
    else:
        for index in range(3):
            c += path(f"M{72+index*37} 235Q{30+index*44} {269+phase*7} {80+index*36} 289Q{53+index*42} 270 {101+index*31} 249Z", BLUE, GOLD, .9, extra='opacity=".7"')
        body = path(f"M106 121L154 119Q171 157 171 214Q186 250 219 {248+phase*4}L171 276L139 252L118 280L99 252L58 268Q85 196 80 159Z", "url(#armor)", INK, 2.7)
        body += path("M115 133L98 217L115 250L130 164L148 244L163 232L146 137", stroke=JADE, width=2)
        body += path("M92 153L52 183L35 169L45 196L27 213L58 205L107 179M152 147L186 166L207 147L195 180L218 190L187 190L154 180", BLUE, GOLD, 1.4)
        face = path("M100 112L89 69L110 45L146 49L172 82L157 117L129 137Z", INK, JADE, 1.8)
        face += path("M104 87L120 95L113 100L101 97M138 94L155 86L155 95L142 100M118 117L129 107L140 116L132 130Z", PAPER, GOLD, 1)
        face += path("M107 56L88 27L111 38L121 57M145 53L167 25L159 62", "url(#gold)", INK, 1)
        c += group(body, f"rotate({attack*7:.1f} 128 188)")
        c += group(face, f"rotate({phase*4+hurt*15:.1f} 129 113)")
        c += talisman(128, 78, phase*4, .7)
    return group(c, f"translate({walk*5+hurt*8:.1f} {phase*4+death*60:.1f}) rotate({death*18:.1f} 128 230) scale(1 {1-death*.35:.3f})")


def character(name, state, frame):
    death = frame/3 if state == "death" else 0
    c = '<ellipse cx="128" cy="269" rx="72" ry="7" fill="#0d1419" opacity=".38"/>'
    draw = spirit if name in ("fox", "dragon", "wraith") else humanoid
    # 全コマに余白を確保し、鍬形や攻撃武器が隣のコマへ漏れないようにする。
    transform = "translate(22 17) scale(.83)"
    if name == "fox":
        transform = "translate(37 37) scale(.71)"
    elif name == "duelist":
        transform = "translate(29 28) scale(.77)"
    c += group(draw(name, state, frame), transform, f'opacity="{1-death*.68:.3f}"')
    if death:
        rng = random.Random(93+CHARACTERS.index(name))
        for _ in range(round(death*27)):
            x, y = rng.randrange(36, 220), rng.randrange(80, 282)
            c += path(f"M{x} {y}l-3-7l8 2l4 9l-7 2Z", INK, GOLD, .45, f'opacity="{death*.8:.3f}"')
    return c


def mountain(y, tint, seed, opacity=1):
    rng = random.Random(seed)
    points = [(0, y+110)]
    for index in range(15):
        points.append((index*95-20, y+rng.randrange(-110, 95)))
    d = "M" + "L".join(f"{x} {yy}" for x, yy in points) + "V720H0Z"
    c = path(d, tint, tint, 2, f'opacity="{opacity}"')
    for x, yy in points[2:12]:
        c += path(f"M{x} {yy+9}l-18 58l36-19l-27 66M{x+14} {yy+61}l20 33", stroke=JADE, width=1, extra='opacity=".12"')
    return c


def castle(x, y, scale=1):
    c = path("M-94 0L-74-80H77L98 0Z", "#263b40", INK, 2)
    c += path("M-67-80V-134H68V-80M-54-137V-188H55V-137M-37-188V-221H38V-188", "#a2aaa0", INK, 3)
    for yy, half in ((-86, 86), (-139, 72), (-190, 58), (-225, 45)):
        c += path(f"M{-half-13} {yy}Q{-half+18} {yy-3} 0 {yy-28}Q{half-18} {yy-3} {half+13} {yy}L{half-3} {yy+9}H{-half+3}Z", "#172b34", GOLD, 1.1)
        c += path(f"M{-half+8} {yy+1}H{half-8}", stroke=JADE, width=1)
        if yy > -225:
            for xx in range(-half+27, half-15, 23):
                c += path(f"M{xx} {yy+14}v20", stroke=INK, width=5)
    c += path("M-64-45L-35-32L-15-50L12-28L43-47L75-24M-81-18L-50-29M34-22L51-5M-31-5L-19-25", stroke=JADE, width=1.4)
    c += path("M-5-247L0-258L6-247M0-257V-229", stroke=GOLD, width=3)
    return group(c, f"translate({x} {y}) scale({scale})")


def pine(x, y, scale, mirrored=False):
    c = path("M0 0Q-18-77 6-141Q27-195-17-249M3-123Q-21-164-76-175M7-165Q61-186 83-225M-4-58Q-51-84-77-126", stroke=BLACK, width=13)
    c += path("M-2-4Q-10-72 13-147M3-121L-65-172", stroke="#3e5351", width=2)
    for xx, yy, radius in ((-26,-244,58), (68,-220,57), (-75,-176,61), (17,-155,55), (-63,-127,52)):
        for index in range(6):
            offset = index*14-radius*.7
            c += path(f"M{xx+offset} {yy+8}l-12-19l20 5l8-17l11 18l21-1l-15 12Z", BLACK, "#253b3e", .7)
    return group(c, f"translate({x} {y}) scale({-scale if mirrored else scale} {scale})")


def sky():
    c = '<rect width="1280" height="720" fill="url(#sky)"/>'
    c += circle(867, 167, 155, "url(#halo)")
    c += circle(867, 167, 77, "#d0c5a3", "none", extra='opacity=".72"')
    c += circle(867, 167, 70, "none", PAPER, .9, 'opacity=".6"')
    rng = random.Random(71)
    for _ in range(800):
        x, y = rng.randrange(1280), rng.randrange(720)
        c += path(f"M{x} {y}l{rng.randrange(2,10)}-1", stroke=PAPER, width=.4, extra=f'opacity="{rng.uniform(.025,.1):.3f}"')
    c += mountain(310, "#577272", 11)
    c += mountain(403, "#3b565d", 24)
    for index in range(11):
        y = 256+index*30
        c += path(f"M-20 {y}Q228 {y-26} 502 {y+2}T1299 {y-5}", stroke=PAPER, width=1.4+index*.3, extra='opacity=".065"')
    for x,y in ((1020,117),(1077,105),(1120,128)):
        c += path(f"M{x-9} {y}q8-8 13 0q6-6 13-2", stroke=INK, width=1.5)
    return c


def landscape():
    c = mountain(517, "#233d45", 49)
    c += castle(972, 496, 1.13)
    c += castle(1154, 498, .5)
    c += path("M0 602Q310 549 500 600Q664 588 854 626L1280 606V720H0Z", "#162d37", "none")
    c += path("M853 504Q788 567 722 603Q719 646 801 720H624Q625 651 657 607Q799 543 836 504Z", "#9aa291", "none", extra='opacity=".16"')
    for x in range(11):
        c += path(f"M{300+x*36} 609l30-20v39M{303+x*36} 631v-38", stroke=INK, width=2)
    c += pine(75, 602, 1.33)
    c += pine(190, 600, .7, True)
    c += path("M22 535H145M38 534V489H134V535M54 490V464H118V490", fill=INK, stroke="#516964", width=1.1)
    return c


def foreground():
    c = path("M0 690Q207 645 319 691Q463 686 644 710L930 676Q1088 656 1280 686V720H0Z", BLACK, "none")
    rng = random.Random(96)
    for _ in range(76):
        x = rng.randrange(1280)
        y = rng.randrange(684, 721)
        height = rng.randrange(12, 54)
        c += path(f"M{x} {y}q-8-{height//2}-3-{height}M{x} {y}q12-{height//2} 23-{height+7}", stroke="#536761", width=1.2)
    c += pine(1268, 628, 1.47, True)
    for x, scale in ((46,1.1), (1188,.85)):
        c += group(path("M0 0V-179M-25-166H23L28-97H-29ZM-23-150H23M-25-111H25", "url(#cloth)", INK, 3)+crest(0,-135,.83), f"translate({x} 713) scale({scale})")
    return c


def icons():
    return {
        "attack": group(blade(31, 41, 40), "translate(0 14) scale(.5) translate(31 28)"),
        "health": path("M32 53Q5 35 9 20Q17 5 32 20Q47 5 55 20Q59 35 32 53Z", RED, GOLD, 2),
        "coin": circle(32,32,24,"url(#gold)",PAPER,1.2)+path("M25 25H39V39H25Z",INK,GOLD,1),
        "card": path("M17 7L48 10L50 57L14 54ZM22 15H42V47H21Z",BLUE,GOLD,2)+crest(32,31,.65),
        "battle": path("M11 8L46 48M51 8L17 48M33 41L46 30M15 31L31 44M41 43L53 58M23 43L11 56",stroke=GOLD,width=4),
        "general": path("M13 17L22 28L32 6L42 28L54 13L49 44L32 58L16 44ZM20 35L27 38M37 38L45 34M27 47H37",BLUE,GOLD,2),
        "reward": path("M18 12L48 17L44 58L13 52ZM22 6L55 11L52 49",BLUE,GOLD,2)+crest(31,33,.8),
        "rest": path("M11 33H50L46 47Q31 62 16 47ZM50 35Q64 34 55 46L47 47M21 26Q9 14 25 6M34 25Q47 13 33 4",BLUE,GOLD,2),
        "merchant": path("M7 28L15 10H50L59 28ZM13 29V55H53V29M7 57H58M21 32H34V54M39 33H47V43",BLUE,GOLD,2)+path("M21 12L18 26M34 12V26M46 12L50 26",stroke=RED,width=3),
        "final": path("M12 7L26 22L32 3L39 22L55 7L48 39L32 60L16 39ZM20 31L28 35M37 35L44 30M23 44L32 39L40 44L32 53Z",RED,GOLD,2),
    }


def generate():
    output = {}
    for name in CHARACTERS:
        output[f"art/{name}.svg"] = (256, 320, True, character(name,"idle",0))
        sheet = ""
        for row,state in enumerate(STATES):
            for frame in range(FRAME_COUNT):
                sheet += group(character(name,state,frame), f"translate({frame*256} {row*320})")
        output[f"art/{name}_sheet.svg"] = (1024,1600,True,sheet)
    output["art/bg_sky.svg"] = (1280,720,False,sky())
    output["art/bg_landscape.svg"] = (1280,720,False,landscape())
    output["art/bg_foreground.svg"] = (1280,720,False,foreground())
    keyart = group(sky()+landscape(), "translate(-370 0) scale(1.25)")
    keyart += circle(414,445,350,"url(#halo)")
    keyart += group(character("hero","idle",1), "translate(141 253) scale(1.85)")
    keyart += group(character("general","idle",0), "translate(498 186) scale(1.55)", 'opacity=".84"')
    keyart += group(character("veil","attack",1), "translate(19 470) scale(1.4)")
    keyart += group(foreground(), "translate(-180 137) scale(1.1)")
    output["art/title_keyart.svg"] = (900,900,False,keyart)
    mark = circle(160,160,130,"none",GOLD,2)+circle(160,160,116,"none",GOLD,.8)
    mark += path("M159 28L241 66L258 247L161 293L61 248L80 67Z",INK,GOLD,3)
    mark += path("M157 47L224 79L239 235L160 271L81 234L95 80Z",BLUE,GOLD,1)
    mark += crest(160,151,5)
    mark += path("M113 229H209M116 237H204",stroke=GOLD,width=1.2)
    output["art/logo_mark.svg"] = (320,320,True,mark)
    for name,content in icons().items():
        prefix = "icon_" if name in ("attack","health","coin","card") else "route_"
        output[f"art/{prefix}{name}.svg"] = (64,64,True,content)
    card = path("M9 5H191L196 12V277L187 288H11L4 280V12Z",INK,GOLD,2)
    card += path("M15 17H183V273H15Z",BLUE,GOLD,.8)
    card += crest(100,138,3)
    card += path("M25 29H174M25 258H174M28 40L173 247M29 247L174 40",stroke=GOLD,width=.6,extra='opacity=".3"')
    output["art/card_back.svg"] = (200,294,True,card)
    output["art/fx_ink.svg"] = (32,32,True,path("M11 6L20 3L24 12L28 17L21 27L12 23L4 16L8 12Z","#ffffff","none"))
    output["art/fx_glow.svg"] = (64,64,True,circle(32,32,31,"url(#glow)"))
    output["art/fx_spark.svg"] = (16,32,True,path("M8 2L11 14L8 30L5 14Z","#ffffff","none"))
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", type=Path, default=Path(__file__).resolve().parents[2]/"assets")
    parser.add_argument("--print-spec", action="store_true")
    args = parser.parse_args()
    assets = generate()
    if args.print_spec:
        print(json.dumps({"rate":22050,"images":[{"path":name,"width":values[0],"height":values[1],"transparent":values[2]} for name,values in assets.items()],"audio":[]}))
        return
    for name,(width,height,_transparent,content) in assets.items():
        target = args.out_dir/name
        data = svg(content,width,height).encode()
        target.parent.mkdir(parents=True,exist_ok=True)
        if not target.exists() or target.read_bytes()!=data:
            target.write_bytes(data)
    print(f"独自 SVG {len(assets)} 点を生成しました。人物 {len(CHARACTERS)} 種、各 5 動作 × {FRAME_COUNT} コマ。")


if __name__ == "__main__":
    main()
