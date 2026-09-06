#!/usr/bin/env python3
"""独自の版画風ベクター素材。同じ引数から同じバイト列を生成する。"""
import argparse
from functools import lru_cache
import json
import math
from pathlib import Path
import random
import re
from fontTools.pens.basePen import BasePen
from fontTools.svgLib.path.parser import parse_path

INK = "#101b25"
PALE = "#e3d6b9"
BLUE = "#789da6"
RED = "#ba5148"
GOLD = "#b99563"
IDS = ["child", "warrior", "water", "fox", "headless", "doll", "monk",
       "moth", "bride", "crow", "bell", "beast", "hero_0", "hero_1",
       "hero_2", "hero_3", "police", "boss"]
DEFS = '''<defs>
<linearGradient id="cloth" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#75949c"/><stop offset="1" stop-color="#263f4d"/></linearGradient>
<linearGradient id="pale" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#eee2c7"/><stop offset="1" stop-color="#9da99f"/></linearGradient>
<linearGradient id="red" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#d57259"/><stop offset="1" stop-color="#652e37"/></linearGradient>
<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#0d1924"/><stop offset=".65" stop-color="#30454e"/><stop offset="1" stop-color="#60716f"/></linearGradient>
<radialGradient id="light"><stop stop-color="#eee4b2" stop-opacity=".9"/><stop offset=".3" stop-color="#d8d4a0" stop-opacity=".5"/><stop offset="1" stop-color="#c4d5c9" stop-opacity="0"/></radialGradient>
<linearGradient id="mist" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#acbfba" stop-opacity="0"/><stop offset=".5" stop-color="#acbfba" stop-opacity=".18"/><stop offset="1" stop-color="#acbfba" stop-opacity="0"/></linearGradient>
<pattern id="weave" width="13" height="13" patternUnits="userSpaceOnUse"><path d="M0 13 13 0 M-3 3 3-3 M10 16 16 10" stroke="#dacba9" opacity=".12" stroke-width=".65"/></pattern>
<pattern id="waves" width="22" height="14" patternUnits="userSpaceOnUse"><path d="M-11 14Q0-5 11 14Q22-5 33 14M-11 18Q0-1 11 18Q22-1 33 18" fill="none" stroke="#e8d9b8" opacity=".3" stroke-width=".7"/></pattern>
</defs>'''


def path(d, fill=INK, stroke=None, width=1.2, opacity=1):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke or INK}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round" opacity="{opacity}"/>'


def ellipse(x, y, rx, ry, fill=PALE, stroke=INK, width=1):
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'


def line(d, color=PALE, width=1.2, opacity=1):
    return path(d, "none", color, width, opacity)


class OutlinePen(BasePen):
    """柄の線を衣服の輪郭内に収めるための、曲線のサンプル点。"""

    def __init__(self):
        super().__init__(None)
        self.points = []

    def _moveTo(self, point):
        self.points.append(point)

    def _lineTo(self, point):
        self.points.append(point)

    def _curveToOne(self, first, second, end):
        start = self.points[-1]
        for index in range(1, 13):
            t = index / 12
            self.points.append(tuple((1-t)**3*start[axis] + 3*(1-t)**2*t*first[axis] +
                                     3*(1-t)*t*t*second[axis] + t**3*end[axis] for axis in [0,1]))

    def _closePath(self):
        pass


def inside(x, y, points):
    contained = False
    previous = points[-1]
    for point in points:
        if (point[1] > y) != (previous[1] > y):
            edge = (previous[0]-point[0])*(y-point[1])/(previous[1]-point[1])+point[0]
            if x < edge:
                contained = not contained
        previous = point
    return contained


@lru_cache(maxsize=None)
def cloth_pattern(d, pattern):
    # Godot の SVG 読み込みで pattern が省略されるため、通常の線へ展開する。
    pen = OutlinePen()
    parse_path(d, pen)
    commands = []
    for row in range(-30, 45):
        drawing = False
        for x in range(5, 196, 2):
            y = row*14 - (6*abs(math.sin(x*math.pi/22)) if pattern=="waves" else x)
            if inside(x, y, pen.points):
                commands.append(f"{'L' if drawing else 'M'}{x} {y:.1f}")
                drawing = True
            else:
                drawing = False
    return line("".join(commands), PALE, .75, .27 if pattern=="waves" else .13)


def robe(d, color="url(#cloth)", pattern="weave"):
    return path(d, color, INK, 2) + cloth_pattern(d, pattern)


def moving(body):
    return f'<g data-art-part="moving">{body}</g>'


def face(x=100, y=62, rx=17, ry=23, sad=False):
    return (ellipse(x, y, rx, ry, "url(#pale)") +
            line(f"M{x-11} {y-2}l7 {2 if sad else -1}m8 0 7 {1 if sad else -2}", INK, 2.5) +
            path(f"M{x} {y+1}l-3 8h4", "none", "#84756b", .8) +
            line(f"M{x-3} {y+14}h6", RED, 1.8))


def strands(d, count=8, color=BLUE):
    return "".join(line(d, color, .6, .3).replace('<path ', f'<path transform="translate({i*2-7} 0)" ', 1) for i in range(count))


def aura():
    return (ellipse(100, 217, 62, 10, "#213943", "none") +
            line("M37 195Q15 152 39 128Q16 95 46 57M163 190Q187 141 166 121Q181 75 150 42", BLUE, 1, .5) +
            line("M32 175Q18 163 32 150M175 108Q190 90 177 79", PALE, .8, .45))


def figure(name):
    s = aura()
    if name == "child":
        s += path("M60 100Q40 76 49 45Q52 11 101 16Q147 17 148 54L137 108Z")
        s += face(100, 58, 27, 29, True)
        s += path("M68 53 76 25 131 28 136 49 118 45 110 35 102 48 83 46 73 54")
        s += robe("M72 90 126 87 153 151 127 157 135 206Q95 198 65 209L73 150 48 157 48 129Z", "url(#red)", "waves")
        s += path("M77 89 100 124 121 89 112 147 85 147Z", PALE)
        s += path("M71 143 130 140 130 153 70 156Z", INK)
        s += moving(ellipse(150, 152, 14, 14, GOLD) + line("M149 139v26m-12-13h25", PALE, 3))
        s += line("M80 190l-8 26m47-25 10 25", PALE, 3)
        s += ellipse(86, 47, 5, 4, RED)
    elif name == "warrior":
        s += path("M44 83 58 37 89 22 126 25 153 85Z", "#354c56", PALE)
        s += path("M62 39Q34 31 40 9L74 30 100 20 127 30 159 9Q164 34 138 41L129 64 72 64Z", GOLD)
        s += face(100, 67, 20, 25)
        s += path("M80 68 85 91 115 91 123 69 111 76 91 75Z", "#35434a", GOLD)
        s += robe("M65 95 132 93 153 161 139 210 60 209 52 158Z", "#314953")
        for row in range(4):
            y = 102 + row * 18
            s += path(f"M72 {y}h58l-2 13H70Z", "#53656a", GOLD, .7)
            s += line(f"M82 {y}v13m15-13v13m16-13v13", RED, 2)
        s += path("M62 96 35 102 28 136 63 137Z", "#354c56", GOLD)
        s += path("M137 96 163 101 171 137 136 135Z", "#354c56", GOLD)
        s += line("M38 112h20m-24 11h22m85-11h19m-17 11h20", GOLD)
        s += moving(path("M40 194 158 44 163 50 48 201Z", PALE, BLUE) + line("M37 190 52 203", RED, 5))
    elif name == "water":
        s += path("M66 37Q107 0 135 38Q144 71 131 104L158 195 43 200 64 115Q41 70 66 37Z")
        s += robe("M83 86 117 86 150 164Q151 198 170 215Q121 199 99 223Q79 204 39 216L56 170Z", "url(#pale)", "waves")
        s += face(104, 56, 17, 26, True)
        s += path("M83 33Q116 17 125 50L116 83 115 43 108 30 98 69 90 113 75 122 87 72Z")
        s += moving(strands("M81 54Q68 115 72 172", 8) + path("M77 52Q64 130 49 161Q61 161 76 146L87 57Z", INK, BLUE, .7))
        s += path("M92 92 104 117 121 93 114 159 94 155Z", "#6e8588")
        s += line("M58 185Q99 172 144 191M51 202Q84 193 109 203M119 213q22-15 43-1", BLUE, 2)
        s += line("M58 129 42 174 57 180M132 129 148 174 133 179", PALE, 5)
    elif name == "fox":
        for i in range(4):
            s += moving(path(f"M{72+i*15} 179Q{12+i*11} {146-i*13} {23+i*10} {77-i*12}Q{44+i*8} {142-i*4} {131-i*2} 163Z", "url(#pale)", BLUE))
        s += robe("M69 108 124 94 148 174 169 213 68 219 46 169Z", "#46596a", "waves")
        s += path("M75 108 52 44 88 64 117 53 154 26 140 98 105 127Z", "url(#pale)", INK, 2)
        s += path("M68 57 79 87 88 74M137 49 118 72 132 77", RED, RED)
        s += path("M81 87 100 95 87 98 79 91M114 89 133 78 128 91 116 96", INK)
        s += path("M100 112 109 110 105 117Z", RED)
        s += line("M75 106 93 109m22-4 21-6M89 138 125 131", RED, 4)
        s += ellipse(108, 149, 9, 10, GOLD)
    elif name == "headless":
        s += robe("M70 87 129 86 161 141 144 155 130 132 139 209 60 212 69 134 54 156 36 141Z", "#546974")
        s += ellipse(101, 86, 25, 7, INK, RED, 3)
        s += line("M81 73Q68 58 85 42M99 74Q119 50 100 26M117 75Q132 59 120 43", BLUE, 4)
        s += path("M77 97 101 117 125 96 110 147 87 147Z", "#c5b695")
        s += path("M65 150 135 147 134 159 65 162Z", INK, GOLD)
        s += line("M100 168 92 209m18-42 17 42M39 140 29 108", PALE, 4)
        s += moving(path("M20 106 39 102 43 132 17 135Z", "url(#red)", GOLD) + line("M21 114h18m-19 9h20", GOLD))
    elif name == "doll":
        s += path("M61 87 54 61Q52 15 99 16Q145 16 146 66L139 98Z")
        s += face(100, 61, 26, 29, True)
        s += path("M67 50 71 28 131 30 135 53 111 46 108 33 100 48 74 48Z")
        s += path("M64 34 44 24 49 44 63 51 77 42 82 27Z", RED)
        s += robe("M75 90 124 88 160 145 126 159 136 201 59 201 71 156 39 148Z", "url(#red)", "weave")
        s += path("M72 141 129 141 129 155 72 155Z", GOLD)
        s += path("M85 93 102 121 118 93 104 144Z", PALE)
        s += ellipse(73, 206, 12, 6, PALE) + ellipse(124, 206, 12, 6, PALE)
        s += line("M88 57l-5 6m1-6 5 6m20-6 6 6m0-6-6 6", INK, 2)
        s += path("M46 144 34 161 43 164 58 150Z", PALE)
        s += moving(path("M145 145 160 160 166 153 156 137Z", PALE))
        s += ellipse(100, 175, 14, 12, "none", GOLD) + line("M88 175h24m-12-12v24", GOLD)
    elif name == "monk":
        s += robe("M75 72 128 77 161 165 139 214 61 214 46 160Z", "#5f6865", "waves")
        s += path("M58 69Q100-16 147 72Z", "#a99470", PALE, 2)
        s += line("M67 64 100 9 100 66 132 66 105 17M78 66 102 15 121 67", INK, 1)
        s += path("M77 75 123 77 115 94 86 94Z", INK)
        s += line("M118 97 82 168 124 193", GOLD, 18)
        for i in range(9):
            x, y = 80 + math.sin(i*.5)*35, 98 + i*5
            s += ellipse(round(x,2), round(y,2), 4, 4, RED)
        s += moving(line("M153 75 153 222", GOLD, 4) + ellipse(153, 55, 15, 20, "none", GOLD, 3))
        for x in [143, 152, 162]:
            s += moving(ellipse(x, 75, 5, 8, "none", GOLD, 1.3))
    elif name == "moth":
        s += moving(path("M93 98Q73 43 20 33Q9 95 55 118Q4 145 36 197Q84 191 99 141Q127 201 173 195Q194 139 147 117Q195 70 175 33Q115 39 104 98Z", "url(#pale)", BLUE, 2))
        for x, flip in [(55,1), (146,-1)]:
            s += moving(ellipse(x, 82, 19, 24, "#405561", GOLD, 2))
            s += moving(ellipse(x, 83, 8, 10, RED) + ellipse(x, 82, 3, 5, INK))
            s += moving(ellipse(x+flip*6, 157, 16, 17, "#405561", GOLD, 2))
        s += robe("M94 91 108 90 123 184 101 215 82 183Z", "#7c8884")
        s += face(101, 70, 12, 17)
        s += line("M93 53 75 30m31 22 19-23M92 107 65 132m44-27 29 30", INK, 2)
        s += moving(line("M29 45 88 114 46 182M169 46 115 114 164 182", GOLD, 1.5))
    elif name == "bride":
        s += moving(path("M55 81Q42 5 102 11Q156 12 147 86L122 109 78 109Z", "url(#pale)", GOLD, 2))
        s += path("M64 63Q76 22 115 35L134 71 126 106 74 106Z")
        s += face(100, 70, 17, 26, True)
        s += robe("M72 101 129 101 165 181 144 224 52 222 33 184Z", "url(#pale)", "waves")
        s += path("M77 104 100 135 123 104 111 165 88 165Z", "#b59885")
        s += path("M61 161 141 161 141 174 61 174Z", "url(#red)", GOLD)
        s += path("M112 167 150 153 147 193Z", RED)
        s += line("M77 120 63 191m61-69 16 71M86 189l-4 23m36-23 3 23", "#697a79", 1.2)
        s += line("M88 70v17m22-17v17", RED, 1)
    elif name == "crow":
        s += moving(path("M89 95Q46 55 11 73L27 90 15 98 36 109 26 121 47 130 42 146 81 140L66 210 101 190 140 215 126 143 162 150 158 133 183 124 166 112 186 99 169 88 186 73Q142 66 112 97Z", "#273d4b", BLUE, 1.4))
        s += path("M91 45Q115 36 131 51L130 68 158 82 123 90 111 105 90 87 83 63Z", INK, BLUE)
        s += ellipse(118, 62, 5, 4, RED, GOLD)
        s += path("M129 73 153 81 129 82Z", GOLD)
        s += robe("M87 102 116 102 126 178 101 203 75 175Z", "#5b6c70", "waves")
        for offset in range(4):
            s += moving(line(f"M80 {104+offset*8} {29+offset*5} {80+offset*14}M120 {104+offset*8} {172-offset*5} {81+offset*14}", BLUE, 1, .5))
        s += line("M89 191 77 218m30-24 14 25", GOLD, 3)
    elif name == "bell":
        s += path("M55 69Q99 10 145 66L153 141 131 163 64 164 43 144Z", "url(#cloth)", GOLD, 2)
        s += path("M59 136Q100 124 145 136L149 151Q97 174 49 149Z", "#768382", GOLD, 2)
        s += ellipse(101, 35, 15, 12, "none", GOLD, 5)
        s += line("M64 80q38-15 73-1M60 100q38-15 82-1M56 119q38-15 89-1M79 62 71 126m52-64 8 65", GOLD, 1.5)
        s += path("M74 87 88 91 79 98M111 92 128 85 120 97", RED, RED, 2)
        s += moving(line("M69 170Q49 194 63 220M95 172Q83 198 104 224M124 169Q140 188 127 218", BLUE, 8))
        s += moving(line("M68 174Q62 193 68 210M98 176 98 204M124 174Q132 191 126 205", PALE, 1.3))
    elif name == "beast":
        s += moving(path("M76 94Q6 72 16 28Q37 68 91 66Z", "url(#cloth)", BLUE, 2))
        s += path("M53 114Q55 78 83 69Q134 29 166 78L184 104 158 117 139 146 144 194 169 211 139 217 111 170 97 161 78 196 80 218 51 218 58 190 66 152 41 158 30 181 10 184 19 151Z", "url(#cloth)", BLUE, 2)
        s += path("M96 72 107 30 127 57 159 24 154 80 169 101 137 121 115 110Z", "url(#pale)", INK, 2)
        s += path("M110 67 119 79 129 84 124 90 109 80M145 75 157 70 153 84 139 92", INK)
        s += path("M129 109 139 105 135 116Z", RED)
        s += line("M42 116 68 125m-34 9 27 4M91 83l-9 48m16-50-6 61m17-59-4 58", PALE, 1.2, .6)
        s += path("M124 113 127 128 132 116 139 123 142 112Z", PALE)
    elif name.startswith("hero_"):
        stage = int(name[-1])
        s += robe("M76 78 122 78 143 153 134 216 111 216 101 166 90 217 63 217 66 145 49 166 39 158 57 101Z", "#344852" if stage < 2 else "#28343f")
        s += path("M76 80 100 106 121 80 114 151 81 151Z", "#9bafa7")
        s += path("M75 147 124 143 125 156 75 161Z", "url(#red)")
        s += face(100, 55, 19, 26)
        s += path("M74 57Q66 21 92 22Q124 12 131 45L125 76 115 52 110 34 100 50 78 43 78 65Z")
        s += moving(path("M129 111 156 120 148 158 125 148Z", "#c5bda2", GOLD) + line("M136 124 148 128m-13 3 12 4m-14 3 11 4", RED, 1.3))
        s += line("M68 184 83 176M117 178 131 185", BLUE, 1.3)
        if stage:
            s += path("M108 42 114 51 109 63 118 69 109 72 116 85", "none", RED, 2)
            s += ellipse(109, 53, 3, 1.8, RED, RED)
            s += line("M78 102 70 124 78 137m41 23 9 30", RED, 1.5)
        if stage > 1:
            s += path("M75 34 69 9 89 26M119 30 137 8 129 47Z", "url(#red)", GOLD)
            s += line("M41 148Q17 115 37 87M158 166Q186 134 167 85", RED, 2)
        if stage > 2:
            s += path("M73 98 27 54 34 90 12 108 48 142 64 196 79 159M124 97 170 60 158 94 188 116 151 141 140 199 122 162", "#25323c", RED)
            s += ellipse(92, 53, 3, 2, RED, RED)
    elif name == "police":
        s += robe("M76 84 126 85 151 141 138 153 124 124 131 212 109 214 99 161 87 214 65 213 74 128 62 160 46 156 57 108Z", "#293e50")
        s += face(100, 57, 20, 24)
        s += path("M73 50 71 29 128 27 130 47 142 53 87 57Z", "#31485c", BLUE)
        s += path("M87 36 102 33 111 38 106 47 94 49Z", GOLD)
        s += path("M84 89 99 108 115 87 113 125 87 126Z", "#9aa7a2")
        s += path("M97 98 103 98 106 127 99 137 94 127Z", INK)
        s += path("M73 143 129 142 129 151 72 153Z", INK, GOLD)
        s += ellipse(120, 107, 5, 7, GOLD)
        s += moving(path("M46 145 60 146 58 178 46 178Z", "#16252f", GOLD) + ellipse(52, 177, 6, 3, "#f5e3b5"))
    elif name == "boss":
        s += ellipse(100, 97, 82, 82, "none", RED, 2)
        s += ellipse(100, 97, 75, 75, "none", GOLD, .7)
        for i in range(12):
            a = i*math.tau/12
            x, y = 100+math.cos(a)*78, 97+math.sin(a)*78
            s += line(f"M{x-3:.1f} {y-5:.1f}l6 10m-7-3 8-4", GOLD, 1)
        s += moving(path("M80 95 26 78 38 99 10 123 32 127 20 149 54 143 73 159M119 93 174 76 160 100 190 117 172 128 183 151 145 145 127 160", "url(#pale)", INK, 2))
        s += robe("M79 82 120 82 148 202 177 225 134 216 109 228 86 216 55 229 30 220 55 199Z", "#2c424b", "waves")
        s += path("M64 39 45 8 82 25 100 12 121 27 153 8 136 43 129 78 103 99 74 79Z", "url(#pale)", GOLD, 2)
        s += path("M73 47 93 54 84 65 72 55M108 54 131 43 126 58 117 65", INK)
        s += ellipse(84, 55, 3, 2, RED, RED) + ellipse(119, 54, 3, 2, RED, RED)
        s += path("M100 59 93 75 108 74Z", INK)
        s += path("M85 80 114 79 103 94Z", "#793c3e")
        s += line("M91 80v7m7-7v11m7-11v10m5-10v7", PALE, 2)
        s += path("M79 102 104 133 122 99 119 152 84 156Z", "url(#red)")
        s += line("M84 167 65 209m34-44-2 48m18-48 24 47", BLUE, 2)
    return s


def scenery(kind, near=False):
    rng = random.Random(93 + len(kind) + int(near))
    s = ""
    color = "#142831" if near else "#334e57"
    edge = "#527079" if near else "#4e6870"
    base = 627 if near else 460
    if kind == "town":
        for i in range(13):
            x = i*112-40
            height = rng.randint(105, 240)
            y = base-height
            s += path(f"M{x} {base}V{y+27}l-16 2 74-55 73 46-14 3V{base}Z", color, edge)
            s += line(f"M{x-10} {y+26} {x+58} {y-24} {x+131} {y+20}M{x+3} {y+32}h112", edge)
            for column in range(4):
                wx = x+12+column*25
                s += path(f"M{wx} {y+53}h16v32h-16Z", "#9c9979" if rng.random()>.78 else "#1f3742", edge, .7)
                s += line(f"M{wx+8} {y+53}v32m-8-16h16", color, 1)
            for row in range(5):
                s += line(f"M{x+3} {y+105+row*18}h112", edge, .6, .5)
        s += path(f"M0 {base-5}Q380 {base-20} 650 {base+16}T1280 {base-8}V720H0Z", color, color)
        if near:
            s += path("M980 99 991 93 1006 620 992 628Z", "#10222a", edge)
            s += line("M849 162 1090 131M874 167Q525 110 0 160M1077 145Q1180 154 1280 183", edge, 2)
            s += path("M815 720 987 457 1010 463 968 720Z", "#748179", "none", 1, .15)
    elif kind == "graveyard":
        for i in range(16):
            x = i*86 + rng.randint(-20,20)
            y = base + rng.randint(-50,40)
            h = rng.randint(65,140)
            s += path(f"M{x} {y}v-{h}l16-13 22 5v{h+8}Z", color, edge)
            s += line(f"M{x+12} {y-h+9}v{h-25}m9-{h-30}v{h-30}", edge, 2)
            s += path(f"M{x-12} {y}h68v16h-68Z", color, edge)
        s += path(f"M0 {base+37}Q350 {base-15} 690 {base+25}T1280 {base+24}V720H0Z", color, color)
        if near:
            s += path("M78 700 89 466 62 350 74 342 116 445 109 322 119 319 143 488 179 384 187 389 161 521 142 702Z", color, edge)
            s += line("M86 426 22 401 3 355M113 371 164 304 167 253M168 416 250 389 279 334", color, 11)
    else:
        s += path("M115 698V218L49 229 374 73 924 100 1240 230 1178 230V702Z", color, edge, 2)
        s += line("M69 226 382 94 922 119 1222 226M117 248h1063M127 264h1045", edge, 3)
        for x in range(159,1180,125):
            s += path(f"M{x} 286h95v237h-95Z", "#0e222c", edge)
            s += line(f"M{x+46} 286v237m-46-128h95m-95 38h95", edge, 2)
        s += path("M559 690V320h181v370Z", "#0a1c26", edge, 2)
        s += line("M123 575h440m180 0h433M118 603h445m180 0h431M124 632h439m180 0h433", edge, 2)
        if near:
            s += path("M0 720V0h32l6 247 15 146-10 327M1237 0h43v720h-53l25-251-14-167Z", "#0c2029", edge)
    return s


def sky():
    s = '<rect width="1280" height="720" fill="url(#sky)"/>'
    s += ellipse(963, 173, 103, 103, "#c3c0a5", "none")
    s += ellipse(927, 153, 20, 8, "#aaaE99", "none")
    s += ellipse(987, 201, 32, 19, "#b1b69e", "none")
    rng = random.Random(29)
    for _ in range(260):
        x,y = rng.randint(0,1280), rng.randint(0,720)
        s += line(f"M{x} {y}h{rng.randint(2,11)}", PALE, .5, .035)
    s += path("M0 265Q150 175 318 260Q516 337 746 232Q1000 305 1280 239L1280 300Q998 355 735 297Q434 361 241 297Q99 256 0 300Z", "#90aaa7", "none", 1, .07)
    return s


def logo():
    # 同梱 OFL フォントの輪郭を使い、SVG 表示側の日本語フォント依存をなくす。
    from fontTools.ttLib import TTFont
    from fontTools.pens.svgPathPen import SVGPathPen
    font_path = Path(__file__).resolve().parents[2]/"assets/fonts/ZenOldMincho-Regular.ttf"
    font = TTFont(font_path)
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()
    s = line("M18 117H545", GOLD, 1, .8)
    x = 16
    for char in "夜を継ぐ者":
        pen = SVGPathPen(glyphs)
        glyphs[cmap[ord(char)]].draw(pen)
        s += f'<g transform="translate({x} 104) scale(.095 -.095)">{path(pen.getCommands(), PALE, "none")}</g>'
        x += 105
    s += path("M553 28h35v78h-35Z", RED, "none")
    s += line("M562 44h17m-10-7v51m-8-29h18m-18 14h18m-12 10h11", PALE, 1.4)
    return s


def svg(body, width, height):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">{DEFS}{body}</svg>\n'


def images():
    art = {f"art/{name}.svg": (200, 240, True, figure(name)) for name in IDS}
    for name in IDS:
        complete = art[f"art/{name}.svg"][3]
        parts = re.findall(r'<g data-art-part="moving">(.*?)</g>', complete)
        body = re.sub(r'<g data-art-part="moving">.*?</g>', '', complete)
        art[f"art/{name}_body.svg"] = (200,240,True,body)
        art[f"art/{name}_detail.svg"] = (200,240,True,"".join(parts))
    art["art/night_sky.svg"] = (1280,720,False,sky())
    for scene in ["town", "graveyard", "house"]:
        for near in [False,True]:
            art[f"art/{scene}_{'near' if near else 'far'}.svg"] = (1280,720,False,scenery(scene,near))
    art["art/fog.svg"] = (1280,720,False,'<path d="M0 470Q290 370 610 490T1280 450V720H0Z" fill="url(#mist)"/>')
    art["art/flashlight.svg"] = (512,512,True,'<circle cx="256" cy="256" r="252" fill="url(#light)"/>')
    art["art/spark.svg"] = (32,32,True,path("M16 2 20 12 29 16 20 19 16 30 12 19 2 16 12 12Z",PALE,"none"))
    art["art/logo.svg"] = (600,136,True,logo())
    key = ellipse(383,238,208,208,"#a7b1a0","none")
    key += line("M170 246Q389-9 599 238",GOLD,1,.6)
    for name,x,y,scale in [("boss",236,4,1.62),("water",400,262,1.19),("warrior",90,255,1.3),("child",463,432,.82),("fox",110,465,.87),("hero_1",247,281,1.54)]:
        key += f'<g transform="translate({x} {y}) scale({scale})">{figure(name)}</g>'
    key += path("M8 692Q127 616 271 670T751 660L741 711H18Z", "#122731", "none")
    art["art/keyart.svg"] = (760,720,True,key)
    icons = {
        "battle": "M24 12 49 38 46 42 20 17ZM14 42 20 36 28 44 22 50ZM44 12 20 37 23 41 49 17Z",
        "grave": "M17 49V20L23 13H40L46 20V49ZM12 50H51V56H12Z",
        "living": "M13 45 10 31 18 16 27 27 38 27 48 14 53 36 43 48 31 54Z",
        "police": "M13 17 31 10 51 18 48 39 32 54 16 39ZM22 20H42V27H22Z",
        "rest": "M16 18H45V42L38 50H23L16 42ZM45 22H54V37H46Z",
        "story": "M12 14H48V46H26L16 55V46H12ZM19 22H41V25H19ZM19 32H35V35H19Z",
        "boss": "M14 13 27 20 36 16 51 12 46 33 49 43 33 55 17 44 19 31Z",
        "spirit": "M16 50V27Q16 9 32 10Q49 9 49 27V52L41 46 34 53 26 46Z",
        "darkness": "M33 9Q9 33 19 48Q33 62 46 46Q55 33 43 22L34 39 29 30Z",
        "item": "M20 10H45L43 53 18 54ZM26 18H39V22H26ZM25 30H37V34H25Z",
    }
    for name,d in icons.items():
        art[f"art/icon_{name}.svg"] = (64,64,True,path(d,PALE,INK,1.6))
    return art


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", type=Path, default=Path(__file__).resolve().parents[2]/"assets")
    parser.add_argument("--print-spec", action="store_true")
    args = parser.parse_args()
    art = images()
    if args.print_spec:
        print(json.dumps({"rate":22050,"images":[{"path":name,"width":v[0],"height":v[1],"transparent":v[2]} for name,v in art.items()],"audio":[]}))
        return
    for name,(width,height,_,body) in art.items():
        dest = args.out_dir/name
        dest.parent.mkdir(parents=True,exist_ok=True)
        data = svg(body,width,height).encode()
        if not dest.exists() or dest.read_bytes()!=data:
            dest.write_bytes(data)
    print(f"画像 {len(art)} 件を生成しました。")


if __name__ == "__main__":
    main()
