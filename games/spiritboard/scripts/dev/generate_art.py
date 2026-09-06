#!/usr/bin/env python3
"""幽契の夜路の独自図案を決定的に生成する。第三者の画像は参照しない。"""

import argparse
import json
import math
from pathlib import Path
import random

ROOT = Path(__file__).resolve().parents[2] / "assets"
INK = "#09171e"
BLUE = "#17333b"
TEAL = "#69b3ac"
GOLD = "#baa572"
PAPER = "#dfd3ab"
RED = "#a9453b"
IDS = ["hero", "ghost", "general", "police", "merchant", "lantern", "fox", "bell",
       "willow", "crow", "mask", "spider", "monk", "hound", "dragon", "empress", "reaper"]
POSES = ["idle", "move", "action", "hit", "vanish"]


def path(d, fill=INK, stroke=GOLD, width=1.5, extra=""):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" {extra}/>'


def ellipse(cx, cy, rx, ry, fill, opacity=1):
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{fill}" opacity="{opacity}"/>'


def group(content, transform="", opacity=1):
    return f'<g transform="{transform}" opacity="{opacity}">{content}</g>'


def defs():
    return '''<defs>
<linearGradient id="cloth" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#385359"/><stop offset=".48" stop-color="#173139"/><stop offset="1" stop-color="#08171f"/></linearGradient>
<linearGradient id="paper" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#eadbb6"/><stop offset=".6" stop-color="#bcaa83"/><stop offset="1" stop-color="#6b7264"/></linearGradient>
<linearGradient id="red" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#c4634e"/><stop offset=".5" stop-color="#953e35"/><stop offset="1" stop-color="#482c2d"/></linearGradient>
<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#07131c"/><stop offset=".55" stop-color="#1b3640"/><stop offset="1" stop-color="#607c78"/></linearGradient>
<radialGradient id="glow"><stop stop-color="#a7e6ce" stop-opacity=".7"/><stop offset=".35" stop-color="#69b3ac" stop-opacity=".22"/><stop offset="1" stop-color="#69b3ac" stop-opacity="0"/></radialGradient>
<pattern id="grain" width="31" height="37" patternUnits="userSpaceOnUse"><path d="M2 3h2m9 8h1m-5 14h2m17-4h1m-4 13h2m-6-31h1M1 18h1" stroke="#e6d7ad" stroke-opacity=".17" stroke-width=".7"/></pattern>
</defs>'''


def svg(content, width=256, height=320):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
            f'viewBox="0 0 {width} {height}">{defs()}{content}</svg>\n')


def eye(x, y, angry=False):
    shape = f"M{x-8} {y-3} Q{x} {y+3} {x+7} {y-1}" if angry else f"M{x-7} {y} Q{x} {y-4} {x+7} {y}"
    return path(shape, "none", INK, 2.5) + ellipse(x + 1, y, 1.8, 2.5, RED)


def flame(x, y, scale=1, bend=0):
    drawing = path(f"M0 4 C-26 -17 -17 -37 {bend+4} -60 C3 -38 29 -24 14 -5 C10 3 4 7 0 4Z", TEAL, "none")
    drawing += path("M1 2 C-7 -7 -8 -17 2 -28 C0 -13 14 -9 6 -1Z", PAPER, "none")
    return group(drawing, f"translate({x} {y}) scale({scale})", .78)


def talisman(x, y, rotation=0, scale=1):
    d = path("M-11 -29 L12 -27 10 30 -12 27Z", "url(#paper)", "#715d49", 1)
    d += path("M-5 -19L5 -17M0 -22V4M-7 -8L6 -6M-5 3L5 0M-6 12L5 9M-3 18L3 20", "none", RED, 2)
    return group(d, f"translate({x} {y}) rotate({rotation}) scale({scale})")


def face(kind, tilt=0):
    if kind == "hero":
        d = path("M106 84Q108 66 132 67Q157 72 153 99L140 126L116 114Z", "url(#paper)")
        d += path("M103 82Q106 57 135 57Q161 57 160 95L145 81L132 96L126 77L118 102L103 107Z", INK, "#36494b")
        d += path("M104 69L87 91Q134 88 173 62L136 30Z", "url(#cloth)", GOLD, 2)
        d += path("M93 88L134 42L160 63M110 79L136 43L145 70M127 75L137 43", "none", GOLD, .8)
        d += eye(140, 99) + path("M136 110l8-3", "none", INK)
    elif kind in ("general", "warrior"):
        d = path("M95 85L103 54L153 51L167 85L158 124L107 122Z", "url(#red)", GOLD, 2)
        d += path("M93 85L88 62L104 44L110 22L126 49L144 48L161 19L166 50L181 69L165 87L144 72L116 77Z", "url(#cloth)", GOLD, 2)
        d += path("M121 54L132 35L144 54L131 63Z", GOLD)
        d += path("M108 114L115 102L128 118L145 100L158 111L144 140L123 138Z", INK, GOLD)
        d += eye(115, 92, True) + eye(147, 89, True)
        d += path("M116 117L125 111L133 123L143 108L150 115", "none", PAPER, 2)
    elif kind == "police":
        d = path("M109 66L152 65L157 105L141 126L116 116L107 93Z", "url(#paper)")
        d += path("M101 65L109 40Q138 30 166 48L164 69Q134 82 97 75Z", BLUE, GOLD, 2)
        d += path("M101 65Q135 77 168 61L166 75L101 83Z", INK, GOLD)
        d += ellipse(138, 54, 7, 7, GOLD) + path("M138 48L139 53L145 54L140 57L140 62L136 58L131 58L134 53Z", INK, "none")
        d += eye(121, 94, True) + eye(146, 91, True)
        d += path("M123 109L140 107", "none", INK, 2)
    elif kind in ("merchant", "monk"):
        d = path("M101 79Q113 53 140 61L158 83L152 119L125 135L104 112Z", "url(#paper)")
        d += path("M82 87L110 54L145 48L177 74L171 92Q123 81 82 99Z", "url(#cloth)", GOLD, 2)
        d += path("M92 83L143 53L165 79M104 83L143 53L149 80M121 83L143 53", "none", GOLD, .9)
        d += eye(116, 104) + eye(143, 100)
        d += path("M120 117Q132 127 146 112", "none", INK, 2)
    else:
        d = path("M108 78Q134 63 151 87L150 116L131 140L107 120Z", "url(#paper)")
        d += eye(118, 106) + eye(141, 106)
        d += path("M124 122Q132 115 138 122", "none", RED, 2)
    return group(d, f"rotate({tilt} 130 103)")


def human(kind, wave, action, hit, fade):
    sleeve = 13 * wave + 40 * action
    robes = RED if kind == "hero" else (BLUE if kind != "merchant" else "#665846")
    d = ""
    if kind == "merchant":
        d += path("M57 88L114 76L159 112L162 247L56 235Z", "url(#cloth)", GOLD, 3)
        d += path("M61 112L124 99M62 141L157 130M60 179L161 168M63 211L155 202M85 94L85 238", "none", GOLD, 2)
        d += talisman(72, 158, -6, .55)
    if kind == "general":
        d += path("M86 137L50 121L58 88L84 114M167 124L191 82L205 127L178 145", "url(#red)", GOLD, 2)
    d += path("M107 246L100 283L82 291L83 299L119 297L132 245", INK, GOLD)
    d += path("M141 245L155 281L174 290L174 298L138 297L124 253", INK, GOLD)
    d += path("M103 115Q84 133 79 176L64 260Q112 286 182 265L169 186Q174 142 151 117Z", "url(#cloth)", GOLD, 2)
    d += path("M103 115L131 147L154 117L145 185L177 262L119 276L94 244L111 180Z", robes, GOLD, 1.4)
    d += path("M108 133L137 156L154 136M98 201L117 267M145 197L164 259M109 210L114 247M156 154L162 180", "none", GOLD, .8)
    d += path("M90 173L162 169L166 193L92 200Z", INK, GOLD, 2)
    d += path("M122 171L136 170L137 197L121 195Z", "url(#paper)", GOLD)
    left = path("M100 123Q81 115 68 151L48 192L64 220L95 196L109 156Z", "url(#cloth)", GOLD, 2)
    left += path("M56 197L67 207L79 195L77 185Z", "url(#paper)")
    left += path("M70 141L61 185M82 139L68 188M67 211L89 191", "none", GOLD, .8)
    d += group(left, f"rotate({-sleeve} 99 136)")
    right = path("M150 123Q174 116 187 149L207 177L194 204L164 191L143 155Z", "url(#cloth)", GOLD, 2)
    right += path("M191 180L204 181L213 172L207 159L195 167Z", "url(#paper)")
    if kind == "hero":
        right += talisman(209, 146, 18, .75) + talisman(200, 142, 1, .65)
    elif kind in ("general", "warrior"):
        right += path("M199 174L182 59L188 35L195 55L212 174Z", "url(#paper)", INK, 2)
        right += path("M188 174L222 169M204 179L208 203", "none", GOLD, 5)
    elif kind == "police":
        right += path("M198 178L195 123L203 120L207 177Z", INK, GOLD, 2)
        right += path("M188 115L216 109L222 82L215 74L184 80L180 105Z", "url(#paper)", GOLD, 2)
        right += path("M190 85L212 82M188 92L216 88M188 101L215 97", "none", RED)
    else:
        right += ellipse(203, 154, 17, 20, "url(#red)") + talisman(201, 152, -4, .36)
    d += group(right, f"rotate({sleeve * .7} 151 133)")
    if kind in ("general", "warrior"):
        for y in range(199, 263, 13):
            d += path(f"M81 {y}Q126 {y+14} 174 {y}", "none", GOLD, 2)
        d += path("M74 129L54 143L60 176L86 177L98 145M161 129L182 122L204 155L181 175L158 151", "url(#red)", GOLD, 2)
    if kind in ("merchant", "monk"):
        for a in range(9):
            d += ellipse(round(131+29*math.cos(a*.35),2), round(142+26*math.sin(a*.35),2), 4, 4, GOLD)
    d += face(kind, wave * 3 - hit * 9)
    d += group(path("M77 229Q126 253 171 228L178 264Q116 281 66 260Z", "url(#grain)", "none"))
    return group(d, f"rotate({hit*8} 126 220)", 1-fade*.95)


def spirit(kind, wave, action, hit, fade):
    sway = wave * 12
    d = ellipse(130, 168, 104, 128, "url(#glow)")
    tails = path(f"M105 180C52 202 89 232 55 {250+sway}Q105 237 98 273Q139 250 171 285Q150 248 197 225C158 233 177 190 147 174Z", "url(#cloth)", TEAL)
    d += tails
    if kind == "lantern":
        d += path("M91 94Q66 117 83 184Q116 218 164 189Q184 153 174 111L151 91Z", "url(#red)", GOLD, 3)
        for y in range(110, 190, 13):
            d += path(f"M85 {y}Q129 {y+12} 171 {y-1}", "none", GOLD, .8)
        d += path("M99 91L157 88L157 100L99 102ZM98 194L159 191L158 202L98 205Z", INK, GOLD, 2)
        d += ellipse(130, 139, 19, 16, PAPER) + ellipse(136, 139, 7, 12, INK)
        d += path(f"M107 173Q138 164 154 173Q131 179 {139+sway} 228Q109 209 107 173Z", RED, INK, 2)
        d += path("M124 88Q111 44 143 55Q156 62 149 89", "none", GOLD, 4)
    elif kind == "umbrella":
        d += path("M49 152Q73 71 133 62Q193 83 217 151L186 141L162 157L131 144L102 157L74 143Z", "url(#red)", GOLD, 2)
        for x in (49, 74, 102, 131, 162, 186, 217):
            d += path(f"M133 65L{x} 148", "none", GOLD, 1)
        d += ellipse(135, 116, 20, 13, PAPER) + ellipse(139, 114, 7, 10, INK)
        d += path(f"M136 145L131 211Q161 {226+sway} 157 244Q144 263 119 249", "none", GOLD, 7)
        d += path("M115 138Q128 146 144 136L155 171Q127 178 115 138Z", "url(#paper)", INK)
    elif kind == "fox":
        for index in range(4):
            x = 39 + index * 44
            d += path(f"M128 232Q{x-26} 207 {x} {82+index*13+sway}Q{x+9} 151 {x+31} 166Q211 235 128 232Z", "url(#paper)", TEAL, 2)
        d += path("M104 150L98 213L127 251L158 223L151 151Z", "url(#red)", GOLD, 2)
        d += path("M90 61L120 83L151 80L177 54L168 111L143 146L127 158L102 131Z", "url(#paper)", GOLD, 2)
        d += path("M95 73L112 97L102 109M168 66L150 98L162 108M111 124L126 139L142 121", "none", RED, 4)
        d += eye(113, 111, True) + eye(151, 107, True)
        d += ellipse(132, 137, 4, 3, INK)
        d += talisman(132, 189, 5, .58)
    elif kind in ("ghost", "willow", "empress"):
        small = kind == "child"
        d += path(f"M104 122Q67 144 65 192L47 217L82 215L86 255Q141 244 193 274L169 230L179 163L151 120Z", "url(#paper)" if kind != "drowned" else "url(#cloth)", TEAL, 2)
        d += path("M103 128L135 174L155 127M135 174L120 243M152 181L166 247M99 173L89 209", "none", "#526f6d", 2)
        d += path("M101 88Q82 96 98 156L115 175L106 126L156 119L165 173Q183 127 165 88Q128 48 101 88Z", INK, TEAL, 1)
        d += face(kind, wave * 6 + hit * 8)
        d += path("M103 92Q116 70 150 83L146 110L124 93L117 123L105 104Z", INK, "none")
        if kind == "empress":
            d += path("M91 100Q70 44 132 38Q191 39 170 103L148 81L111 85Z", "url(#paper)", GOLD, 2)
            d += path("M89 82Q126 53 174 79", "none", GOLD)
            d += talisman(125, 197, 0, .8)
            d += path("M100 75L97 37L118 56L130 22L143 53L163 34L159 76Z", GOLD, INK, 2)
            for xx in range(84,176,18):
                d += path(f"M128 245Q{xx-24} 206 {xx} 190Q{xx+10} 218 128 245Z", "url(#paper)", TEAL)
        elif kind == "willow":
            d += path(f"M92 148Q40 175 77 {214+sway}M164 140Q211 180 173 227M111 228Q94 279 148 273", "none", TEAL, 3)
            d += path("M103 116L97 207M158 108L169 203", "none", INK, 7)
            for xx in (52,67,179,193):
                d += path(f"M128 55Q{xx} 38 {xx+sway} 214", "none", "#637d65", 2)
                for yy in range(79,193,22):
                    d += path(f"M{xx} {yy}q-13 2 -10 17q12-5 10-17Z", "#758e73", "none")
        elif small:
            d += path("M91 119L131 151L164 114L159 199L93 202Z", "url(#red)", GOLD, 2)
            d += ellipse(129, 181, 14, 14, GOLD) + talisman(126, 179, -9, .3)
            d = group(d, "translate(24 42) scale(.82)")
        else:
            d += flame(70, 114, .5, sway) + flame(185, 171, .5, -sway)
    elif kind == "bell":
        d += path("M93 109Q93 68 130 63Q177 75 174 114L186 190Q130 220 75 190Z", "url(#paper)", GOLD, 3)
        d += path("M86 132L177 130M79 178Q127 197 181 175M111 104L109 173M153 101L156 173", "none", GOLD, 2)
        d += path("M114 81Q99 30 132 36Q162 36 151 79", "none", GOLD, 7)
        d += ellipse(133, 147, 21, 24, INK) + ellipse(136, 145, 8, 15, TEAL)
        d += path(f"M130 198Q110 220 {151+sway} 242L119 276", "none", RED, 6)
        d += flame(73, 160, .55, sway)
    elif kind == "spider":
        for side in (-1, 1):
            for leg in range(4):
                x = 129 + side * (66 + leg * 8)
                d += path(f"M{129+side*21} {158+leg*10}L{x} {103+leg*33+sway}L{129+side*(105-leg*5)} {160+leg*27}", "none", GOLD, 5)
        d += ellipse(127, 186, 45, 61, "url(#red)")
        d += path("M102 163Q87 108 115 95Q157 81 166 122L151 171Z", "url(#paper)", TEAL, 2)
        for x, y in [(113,123),(138,117),(149,133),(121,143)]:
            d += ellipse(x, y, 5, 6, INK) + ellipse(x+1, y, 2, 2, RED)
        d += path("M107 179L127 190L146 175M97 198L126 211L155 192M111 227L126 219L142 230", "none", GOLD, 2)
    elif kind == "crow":
        d += path(f"M119 152Q78 82 37 {63-sway}L54 114L30 103L52 150L29 145L80 198L127 217L198 188L223 151L199 155L219 109L193 124L215 {70+sway}Q163 84 145 148Z", "url(#cloth)", TEAL, 2)
        for side in (-1, 1):
            for f in range(5):
                d += path(f"M{127+side*20} 173L{127+side*(68+f*6)} {97+f*16}", "none", GOLD, 1)
        d += path("M109 126Q90 81 129 71L153 89L184 99L151 114L146 164L132 216L104 237L112 180Z", INK, GOLD, 2)
        d += ellipse(139, 94, 6, 5, RED) + path("M152 90L179 99L151 105Z", "url(#paper)")
        d += talisman(124, 170, -9, .65)
    elif kind == "mask":
        d += path("M118 207L137 207L147 264L108 265Z", "url(#cloth)", GOLD, 3)
        d += ellipse(127, 138, 61, 81, GOLD)
        d += ellipse(127, 138, 53, 73, INK)
        d += ellipse(127, 138, 48, 67, "url(#cloth)")
        d += path("M100 104L124 83L147 95L155 121L142 167L123 183L103 155Z", "url(#paper)", TEAL)
        d += eye(116, 131) + eye(139, 130)
        d += path("M124 149Q132 138 141 153M147 76L133 108L143 127L116 162L131 200", "none", INK, 3)
        d += path("M115 137L110 161M140 136L147 158", "none", RED, 3)
        for a in range(12):
            angle = a * math.tau / 12
            d += ellipse(round(127+56*math.cos(angle),1), round(138+76*math.sin(angle),1), 2, 3, PAPER)
    elif kind == "hound":
        d += path("M82 140Q119 121 179 155L206 135L222 103L232 110L221 154L187 178L186 238L199 249L171 252L159 191L109 190L98 250L73 253L86 235L87 186L54 177Z", "url(#paper)", GOLD, 2)
        d += path("M48 89L71 114L98 95L90 133L99 153L73 185L41 171L28 148L43 132Z", INK, TEAL, 2)
        d += path("M43 143L75 126L89 140L71 158L77 173L42 161Z", "url(#paper)", GOLD, 2)
        d += ellipse(59, 144, 8, 7, INK) + ellipse(60,145,3,3,RED)
        d += path("M37 157L50 156M48 169L55 163L62 171L68 164", "none", INK, 2)
        for xx in range(111,167,14):
            d += path(f"M{xx} 145Q{xx+14} 167 {xx} 183", "none", INK, 5)
        d += flame(168,151,.65,sway)
    elif kind == "dragon":
        d += path("M75 272C243 238 48 216 139 172C234 125 214 96 156 98", "none", GOLD, 43)
        d += path("M75 272C243 238 48 216 139 172C234 125 214 96 156 98", "none", BLUE, 36)
        for xx,yy in [(117,260),(144,243),(112,221),(116,193),(150,173),(180,153),(196,126)]:
            d += path(f"M{xx-8} {yy-8}l9 10l12-6", "none", TEAL, 2)
        d += path("M95 94L90 51L112 76L135 68L151 33L153 79L171 92L155 119L121 127L96 118L75 125L60 104Z", "url(#paper)", GOLD, 2)
        d += eye(120,98,True)+path("M74 105L95 104M102 117Q67 144 45 108M154 108Q199 94 213 58", "none", RED, 3)
        d += path("M142 173L184 198L204 183M117 215L76 207L55 229", "none", GOLD, 6)
        d += flame(85,155,.75,sway)
    elif kind == "reaper":
        d += group(human("monk",wave,action,hit,0),"translate(15 -4) scale(.87)")
        d += path("M28 231Q129 261 231 226L202 266Q122 300 54 268Z", "url(#cloth)", GOLD, 3)
        d += path("M48 250Q130 277 210 246M66 255L69 274M97 264L99 284M132 269L132 287M168 263L167 280", "none", GOLD, 1.5)
        d += path("M58 271L194 75L202 70L206 77L67 279Z", "url(#paper)", GOLD, 2)
        d += flame(58,213,.6,sway)
    else:
        d += human(kind, wave, action, hit, 0)
        if kind == "monk":
            d += path("M66 257L66 86", "none", GOLD, 4) + ellipse(66, 79, 14, 18, GOLD) + ellipse(66, 78, 9, 13, INK)
    d += flame(185, 244, .4 + action * .6, sway)
    return group(d, f"rotate({hit*10} 128 190)", 1-fade*.96)


def character(kind, pose="idle", frame=0):
    phase = frame / 5
    wave = math.sin(frame * math.tau / 6)
    action = math.sin(phase * math.pi) if pose == "action" else 0
    hit = math.sin(phase * math.pi) if pose == "hit" else 0
    fade = phase if pose == "vanish" else 0
    y = wave * (6 if pose == "move" else 2) - fade * 16
    if kind == "general" and pose == "vanish":
        # 兜の高さを保ち、消失末尾の上移動でコマ上端を越えないようにする。
        y = max(y, -12)
    x = action * 15 - hit * 10
    d = ellipse(129, 292, 74*(1-fade*.4), 9, INK, .48*(1-fade))
    if kind in ("hero", "general", "police", "merchant"):
        art = human(kind, wave, action, hit, fade)
    else:
        art = spirit(kind, wave, action, hit, fade)
    d += group(art, f"translate({x:.2f} {y:.2f})")
    if action:
        d += group(flame(194, 108, .7, 12), opacity=action)
        d += group(path("M66 198Q98 62 205 123M83 220Q123 88 220 148", "none", PAPER, 2), opacity=action*.7)
    if fade:
        rng = random.Random(98)
        for _ in range(20):
            dx, dy = rng.randrange(40,220), rng.randrange(67,280)
            d += ellipse(dx + fade * 10, dy - fade * 25, 2+fade*5, 1+fade*2, TEAL, math.sin(phase*math.pi)*.7)
    return d


def tree(x, y, scale=1):
    d = path("M-18 0L-12 -77L-33 -118L-65 -134L-86 -167L-43 -137L-23 -121L-30 -189L-15 -165L-9 -113L8 -139L19 -204L21 -159L47 -187L66 -186L37 -161L16 -128L2 -72L14 0Z", INK, "#51605a", 1)
    return group(d, f"translate({x} {y}) scale({scale})")


def house(x, y, scale=1):
    d = path("M-70 0L-70 -81L68 -85L71 0Z", BLUE, GOLD, .7)
    d += path("M-96 -79Q-29 -95 0 -139Q34 -99 96 -86L83 -71L-75 -65Z", INK, "#738174", 1.2)
    for xx in range(-48, 55, 26):
        d += path(f"M{xx} -63L{xx+14} -63L{xx+14} -11L{xx} -11Z", "#bc9d65", INK, 4)
    d += path("M-70 -5H70M-65 -75L68 -81M-37 -109L40 -107", "none", INK, 4)
    return group(d, f"translate({x} {y}) scale({scale})", .8)


def background(layer):
    if layer == "bg_sky":
        d = '<rect width="1280" height="720" fill="url(#sky)"/>'
        d += ellipse(939, 149, 111, 111, "#c7c4a1", .84)
        d += ellipse(908, 128, 110, 110, "#657e7c", .24)
        rng = random.Random(91)
        for _ in range(85):
            d += ellipse(rng.randrange(1280), rng.randrange(500), .8, .8, PAPER, rng.uniform(.1,.3))
        for j in range(6):
            y = 137+j*78
            d += path(f"M-40 {y}Q280 {y-49} 586 {y+7}T1350 {y-13}L1340 {y+14}Q788 {y+52} 416 {y+12}T-40 {y+23}Z", "#0c222c", "none", extra='opacity=".3"')
        d += '<rect width="1280" height="720" fill="url(#grain)"/>'
    elif layer == "bg_village":
        d = path("M0 503Q149 438 285 468T573 439T861 452T1280 410V720H0Z", "#28474b", "none")
        for x, y, s in [(63,560,.75),(250,520,.7),(424,550,.9),(1040,499,.7),(1200,546,1.05)]:
            d += house(x,y,s)
        d += path("M734 560L726 248L744 244L759 560M949 558L963 245L981 251L974 560", "url(#red)", INK, 4)
        d += path("M690 237Q849 276 1018 232L1016 252Q850 294 693 260ZM711 284L999 283L997 301L713 302Z", "url(#red)", GOLD, 1)
        d += path("M720 317Q853 347 988 316", "none", GOLD, 5)
        for x in range(760,971,51):
            d += path(f"M{x} 327l-7 21l14 11l-11 18l4-22l-13-9Z", PAPER, "none")
        d += tree(41,640,1.9) + tree(1183,650,1.6)
        d += path("M0 592Q296 535 558 577T1280 559V720H0Z", "#172d34", "none")
    else:
        d = path("M0 657Q266 610 501 669T925 650T1280 625V720H0Z", INK, "none")
        d += tree(-26,719,2.8) + tree(1310,720,2.7)
        rng = random.Random(71)
        for _ in range(95):
            x, y = rng.randrange(1280), rng.randrange(675,741)
            d += path(f"M{x} {y}Q{x-11} {y-38} {x-26} {y-48}M{x} {y}Q{x+4} {y-35} {x+13} {y-54}", "none", "#20373a", 2)
        for x in (165, 1113):
            d += path(f"M{x-13} 672L{x-10} 598L{x-24} 587L{x} 568L{x+24} 587L{x+10} 598L{x+13} 672Z", "url(#cloth)", GOLD, 1)
            d += ellipse(x,607,10,14,"url(#glow)")
    return d


def node_icon(kind):
    d = ellipse(64,64,53,53,INK) + ellipse(64,64,49,49,BLUE)
    d += '<circle cx="64" cy="64" r="45" fill="none" stroke="#baa572" stroke-width="1.5"/>'
    if kind in ("battle", "boss", "police"):
        paths = {
            "battle": "M39 29L81 82L87 80L91 86L84 94L78 88L78 81L31 37ZM87 31L47 83L42 79L35 87L42 94L49 87L48 81L94 39Z",
            "boss": "M34 72L39 48L48 55L48 29L64 51L82 28L78 55L92 49L96 73L82 89L45 87ZM46 69L58 73L64 84L69 73L84 67",
            "police": "M64 27L74 48L96 52L80 69L82 94L64 82L43 94L47 69L31 52L53 48Z"}
        d += path(paths[kind], "url(#red)" if kind=="boss" else "url(#paper)", GOLD, 2)
    elif kind == "grave":
        d += path("M41 92L44 42Q64 22 82 43L86 92ZM34 96H94M54 52H73M63 46V81M53 69H75", "url(#cloth)", PAPER, 3)
        d += flame(88,61,.4)
    elif kind == "hunt":
        d += path("M32 38L52 49L79 47L98 32L92 68L71 94L57 95L36 71Z", "url(#paper)", GOLD, 2)
        d += path("M43 64L54 68M77 68L89 60M59 81L69 81L64 87Z", "none", RED, 3)
    elif kind == "rest":
        d += path("M30 56H90L84 83Q62 100 38 82ZM90 62Q113 55 106 73Q101 83 88 80M41 44Q31 31 49 25M65 45Q53 32 71 22", "none", PAPER, 4)
    else:
        d += path("M38 50L48 36H81L91 51L85 68Q107 93 64 97Q21 94 41 68Z", "url(#red)", GOLD, 2)
        d += ellipse(65,72,15,15,GOLD) + path("M62 64H68V80H62Z", INK, "none")
    return d


def make_assets():
    assets = {}
    for kind in IDS:
        assets[f"art/{kind}.svg"] = (svg(character(kind)),256,320,True)
        sheet = "".join(group(character(kind,pose,frame), f"translate({frame*256} {row*320})")
                        for row, pose in enumerate(POSES) for frame in range(6))
        assets[f"art/{kind}_sheet.svg"] = (svg(sheet,1536,1600),1536,1600,True)
    for layer in ("bg_sky","bg_village","bg_foreground"):
        assets[f"art/{layer}.svg"] = (svg(background(layer),1280,720),1280,720,layer!="bg_sky")
    # 背景の端まで描く層は四隅透過を要件にしない。
    for layer in ("bg_village","bg_foreground"):
        v = assets[f"art/{layer}.svg"]
        assets[f"art/{layer}.svg"] = (*v[:3],False)
    for kind in ("battle","boss","grave","hunt","police","rest","merchant"):
        assets[f"art/node_{kind}.svg"] = (svg(node_icon(kind),128,128),128,128,True)
    logo = path("M128 14L209 59L225 151L174 249L125 294L75 247L31 151L45 63Z",INK,GOLD,3)
    logo += path("M128 34L192 71L207 148L161 236L126 271L91 234L48 148L61 77Z","none",GOLD,1)
    logo += flame(126,197,1.9,10) + talisman(128,165,-7,1.1)
    assets["art/logo_mark.svg"]=(svg(logo),256,320,True)
    # 月・樹木・鳥居は背景3層に任せ、人物と重複する背景を持たせない。
    seal = path("M0 0L50 2L49 51L1 48Z", RED, "none")
    seal += path("M8 8H41V41H8ZM16 14V35M23 14H34L25 25L35 34H23", "none", PAPER, 2)
    art = group(seal,"translate(99 119) rotate(-5)",.85)
    art += group(character("general"),"translate(343 94) scale(1.5)",.72)
    art += group(character("fox"),"translate(24 255) scale(1.04)")
    art += group(character("hero"),"translate(191 169) scale(1.54)")
    art += group(character("lantern"),"translate(433 361) scale(.79)")
    art += flame(244,257,.9) + flame(473,153,.8) + flame(135,417,.5)
    assets["art/title_keyart.svg"]=(svg(art,720,720),720,720,True)
    back = '<rect x="6" y="6" width="180" height="260" rx="9" fill="#112b33" stroke="#baa572" stroke-width="3"/>'
    back += '<rect x="14" y="14" width="164" height="244" rx="5" fill="url(#grain)" stroke="#6b7770"/>'
    back += group(logo,"translate(37 57) scale(.47)")
    assets["art/card_back.svg"]=(svg(back,192,272),192,272,True)
    for name, color in [("card_frame",GOLD),("card_frame_rare",TEAL),("card_frame_epic",RED)]:
        border = f'<rect x="4" y="4" width="184" height="264" rx="8" fill="none" stroke="{color}" stroke-width="4"/>'
        for x, y, rot in [(12,12,0),(180,12,90),(180,260,180),(12,260,270)]:
            border += group(path("M0 21V0H21M5 15V5H15","none",color,2),f"translate({x} {y}) rotate({rot})")
        assets[f"art/{name}.svg"]=(svg(border,192,272),192,272,True)
    for name, content in {
        "prop_talisman": talisman(64,65,-8,1.7),
        "prop_coin": ellipse(64,64,39,39,GOLD)+ellipse(64,64,31,31,"#756b50")+path("M55 51H73V77H55Z",INK,GOLD,3),
        "prop_grave": node_icon("grave"),
        "fx_glow": ellipse(64,64,62,62,"url(#glow)"),
        "fx_spark": path("M64 7L73 53L119 64L75 75L64 119L53 75L7 64L52 53Z",PAPER,"none"),
        "icon_king": path("M25 46L46 62L64 29L81 62L106 45L94 96L36 96Z","url(#paper)",GOLD,3),
        "icon_darkness": flame(65,98,1.45),
        "icon_attack": path("M35 19L84 79L94 77L107 89L91 106L79 94L80 84L24 30Z","url(#paper)",GOLD,3),
    }.items():
        assets[f"art/{name}.svg"]=(svg(content,128,128),128,128,True)
    return assets


def check_frame_bounds(work):
    """余白付きで全コマを描画し、本来の256×320を越える画素を検出する。"""
    import subprocess
    from PIL import Image

    work.mkdir(parents=True, exist_ok=True)
    failures = []
    for kind in IDS:
        body = "".join(group(character(kind, pose, frame),
                       f"translate({frame*384+64} {row*448+64})")
                       for row, pose in enumerate(POSES) for frame in range(6))
        source = work / f"{kind}.svg"
        source.write_text(svg(body, 2304, 2240))
        output = work / f"{kind}.png"
        subprocess.run(["rsvg-convert", "-o", str(output), str(source)], check=True)
        alpha = Image.open(output).convert("RGBA").getchannel("A")
        for row, pose in enumerate(POSES):
            for frame in range(6):
                tile = alpha.crop((frame*384, row*448, (frame+1)*384, (row+1)*448))
                bounds = tile.getbbox()
                valid = (bounds is not None and bounds[0] >= 64 and bounds[1] >= 64
                         and bounds[2] <= 320 and bounds[3] <= 384)
                relative = tuple(value-64 for value in bounds) if bounds else None
                print("OK" if valid else "NG", kind, pose, frame, "bounds=", relative)
                if not valid:
                    failures.append((kind, pose, frame, relative))
    print(f"全{len(IDS)*len(POSES)*6}コマ検査、境界外{len(failures)}件")
    return not failures


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", type=Path, default=ROOT)
    parser.add_argument("--print-spec", action="store_true")
    parser.add_argument("--check-frame-bounds", action="store_true",
                        help="rsvg-convert と Pillow で全510コマのはみ出しを検査")
    parser.add_argument("--check-dir", type=Path, default=ROOT.parent / "tmp" / "frame-bounds")
    args = parser.parse_args()
    if args.check_frame_bounds:
        raise SystemExit(0 if check_frame_bounds(args.check_dir) else 1)
    assets = make_assets()
    if args.print_spec:
        print(json.dumps({"rate":22050,"images":[{"path":name,"width":v[1],"height":v[2],"transparent":v[3]}
              for name,v in assets.items()],"audio":[]}))
        return
    for name, value in assets.items():
        dest = args.out_dir / name
        dest.parent.mkdir(parents=True,exist_ok=True)
        data = value[0].encode()
        if not dest.exists() or dest.read_bytes() != data:
            dest.write_bytes(data)
    print(f"独自画像 {len(assets)} ファイルを生成しました")


if __name__ == "__main__":
    main()
