#!/usr/bin/env python3
"""森の調査手帳をテーマに、独立した画像と部位アニメーションを再生成する。"""

from pathlib import Path
import math
import random
import xml.etree.ElementTree as ET


ASSETS = Path(__file__).resolve().parents[2] / "assets"
INK = "#28483e"
IVORY = "#fff3d4"
GOLD = "#dcb466"
CORAL = "#e88974"
ANIMATIONS = ("idle", "walk", "attack", "hurt", "defeat")
CHARACTERS = ("ember", "tide", "sprout", "moth", "crab", "owl",
              "player", "captain", "healer", "crab_captain")
DEFS = '''<defs>
<linearGradient id="coral" x1="0" y1="0" x2="0.8" y2="1"><stop stop-color="#ffd3a1"/><stop offset="0.48" stop-color="#ee9876"/><stop offset="1" stop-color="#c85b52"/></linearGradient>
<linearGradient id="water" x1="0" y1="0" x2="0.7" y2="1"><stop stop-color="#c6efdc"/><stop offset="0.55" stop-color="#78c9bb"/><stop offset="1" stop-color="#388c94"/></linearGradient>
<linearGradient id="leaf" x1="0" y1="0" x2="0.5" y2="1"><stop stop-color="#d9e29b"/><stop offset="0.48" stop-color="#9cba76"/><stop offset="1" stop-color="#527e5d"/></linearGradient>
<linearGradient id="cream" x1="0" y1="0" x2="0.4" y2="1"><stop stop-color="#fff9e4"/><stop offset="1" stop-color="#e6c990"/></linearGradient>
<linearGradient id="gold" x1="0" y1="0" x2="0.7" y2="1"><stop stop-color="#fff0ac"/><stop offset="0.42" stop-color="#e6ba61"/><stop offset="1" stop-color="#a67738"/></linearGradient>
<linearGradient id="forest" x1="0" y1="0" x2="0.6" y2="1"><stop stop-color="#70a18b"/><stop offset="1" stop-color="#284b43"/></linearGradient>
<linearGradient id="navy" x1="0" y1="0" x2="0.5" y2="1"><stop stop-color="#6c9b9c"/><stop offset="1" stop-color="#28465d"/></linearGradient>
<linearGradient id="skin" x1="0" y1="0" x2="0.3" y2="1"><stop stop-color="#ffe4be"/><stop offset="1" stop-color="#dba078"/></linearGradient>
<radialGradient id="glow"><stop stop-color="#fff3ae" stop-opacity="0.65"/><stop offset="1" stop-color="#fff3ae" stop-opacity="0"/></radialGradient>
</defs>'''


def n(value):
    return f"{value:.2f}" if isinstance(value, float) else str(value)


def path(data, fill="none", stroke=INK, width=3, extra=""):
    return f'<path d="{data}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" {extra}/>'


def ellipse(x, y, rx, ry, fill, stroke=INK, width=3, extra=""):
    return (f'<ellipse cx="{n(x)}" cy="{n(y)}" rx="{n(rx)}" ry="{n(ry)}" '
            f'fill="{fill}" stroke="{stroke}" stroke-width="{width}" {extra}/>')


def rect(x, y, w, h, radius, fill, stroke=INK, width=3, extra=""):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" '
            f'fill="{fill}" stroke="{stroke}" stroke-width="{width}" {extra}/>')


def group(body, transform="", extra=""):
    return f'<g transform="{transform}" {extra}>{body}</g>'


def rotate(body, degrees, x=96, y=110):
    return group(body, f"rotate({n(degrees)} {x} {y})")


def svg(body, width=192, height=192):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
            f'viewBox="0 0 {width} {height}">{DEFS}'
            f'<g stroke-linecap="round" stroke-linejoin="round">{body}</g></svg>\n')


def star(x, y, radius, fill=GOLD):
    return group(path(f"M0 {-radius} Q2 -2 {radius} 0 Q2 2 0 {radius} Q-2 2 {-radius} 0 Q-2 -2 0 {-radius}Z",
                      fill, "none"), f"translate({x} {y})")


def leaf(x, y, size, angle=0, fill="url(#leaf)"):
    body = path("M0 0 Q-19 -17 0 -43 Q20 -19 0 0Z", fill, INK, 2)
    body += path("M0 -4 L0 -34 M0 -15 L-8 -23 M0 -21 L8 -29", "none", "#729363", 1.5)
    return group(body, f"translate({n(x)} {n(y)}) rotate({n(angle)}) scale({n(size)})")


def eyes(x, y, spread, action, frame, size=5):
    closed = (action == "idle" and frame == 4) or action in ("hurt", "defeat")
    result = ""
    for side in (-1, 1):
        cx = x + side * spread
        if closed:
            result += path(f"M{cx-size} {y+2} Q{cx} {y-3} {cx+size} {y+2}", width=2.7)
        else:
            result += ellipse(cx, y, size, size * 1.35, INK, "none")
            result += ellipse(cx - 1.1, y - 2, 1.4, 1.8, "#fffbdf", "none")
            if action == "attack":
                result += path(f"M{cx-size-2} {y-9+side*2} L{cx+size+2} {y-9-side*2}", width=2.4)
    return result


def mouth(x, y, action, frame):
    if action == "attack" and frame in (2, 3, 4):
        return ellipse(x, y, 6.5, 8.5, "#704938", INK, 2) + ellipse(x, y + 4, 4, 2.3, CORAL, "none")
    if action in ("hurt", "defeat"):
        return path(f"M{x-5} {y+3} Q{x} {y-2} {x+5} {y+3}", width=2)
    return path(f"M{x-6} {y} Q{x} {y+7} {x+6} {y}", width=2)


def freckles(x, y, spread=24):
    return (ellipse(x-spread, y, 7, 3, "#ec9b80", "none", extra='opacity="0.55"')
            + ellipse(x+spread, y, 7, 3, "#ec9b80", "none", extra='opacity="0.55"'))


def motion(action, frame):
    phase = frame / 6 * math.tau
    sway = math.sin(phase)
    if action == "walk":
        return sway * 15, -abs(sway) * 4, math.sin(phase + .7) * 5
    if action == "attack":
        power = (0, -.3, 1, .8, .35, 0)[frame]
        return power * 26, -max(0, power) * 6, power * 9
    if action == "hurt":
        recoil = (0, 1, -.55, .35, -.1, 0)[frame]
        return recoil * -16, abs(recoil) * 2, recoil * -8
    if action == "defeat":
        return frame * -2, frame * 1.8, frame * 10
    return sway * 4, -math.sin(phase) * 1.9, math.cos(phase) * 1.5


def ember(action, frame, limb):
    result = rotate(path("M126 131 Q156 151 167 119 Q176 95 163 74 Q160 101 143 95 Q148 116 124 114Z", "url(#coral)")
                    + path("M161 113 Q172 91 163 74 Q161 90 151 94 L156 105Z", IVORY, "none"), limb * .7, 130, 126)
    for side in (-1, 1):
        x = 96 + side * 25
        result += rotate(ellipse(x, 153, 19, 12, "#bd6151") + path(f"M{x-7} 154v4 M{x} 155v4", width=1.7), limb * side, x, 139)
    result += path("M52 97 Q43 77 58 64 Q43 40 53 26 Q78 30 86 53 L104 53 Q119 30 143 25 Q155 40 140 69 Q154 80 143 105 L150 119 Q151 153 98 158 Q48 157 43 126Z", "url(#coral)")
    result += rotate(path("M58 60 L56 35 Q77 39 80 57Z", "#703f43", "none") + path("M63 49 L65 41 73 53", "#ffd8ad", "none"), limb * .35, 79, 68)
    result += rotate(path("M110 56 Q124 39 140 34 L134 62Z", "#703f43", "none") + path("M121 54 L134 43 131 55", "#ffd8ad", "none"), -limb * .45, 117, 67)
    result += path("M55 99 Q70 99 84 112 L96 107 109 111 Q128 96 140 101 Q137 126 127 130 L126 144 Q98 160 68 143 L65 129Z", "url(#cream)", "none")
    result += path("M83 72 L94 58 105 72 96 68Z", "#ffdc90", "none")
    result += eyes(96, 97, 21, action, frame) + ellipse(96, 112, 4, 3, INK, "none")
    result += mouth(96, 121, action, frame) + freckles(96, 112, 28)
    result += path("M48 131 Q60 125 70 136 M126 135 Q137 125 146 129", "none", "#9f5149", 2)
    result += path("M86 137 L96 143 106 137 M89 143 L96 148 103 143", "none", "#d5ae73", 2)
    return result


def tide(action, frame, limb):
    result = rotate(path("M128 126 Q167 110 169 147 Q151 140 145 160 Q126 150 118 145Z", "url(#water)")
                    + path("M135 140 Q151 129 164 142 M143 151 L150 137", "none", "#4a9a9b", 2), limb, 131, 136)
    for side in (-1, 1):
        fin = path("M64 86 Q34 76 29 45 Q46 47 56 58 Q57 38 69 31 Q80 53 78 73Z", "url(#water)")
        fin += path("M66 75 L37 51 M66 73 L69 41", "none", "#c9efcf", 2)
        if side == 1:
            fin = group(fin, "translate(192 0) scale(-1 1)")
        result += rotate(fin, side * limb * .8, 96 + side * 27, 83)
    result += rotate(ellipse(66, 154, 20, 9, "#53a09a"), limb, 70, 145)
    result += rotate(ellipse(124, 154, 20, 9, "#53a09a"), -limb, 122, 145)
    result += path("M48 113 Q45 65 95 64 Q143 62 146 111 Q155 148 121 157 Q103 166 76 158 Q40 153 48 113Z", "url(#water)")
    result += path("M56 116 Q73 121 95 115 Q123 118 140 111 L139 136 Q137 155 96 158 Q62 154 57 139Z", "#e1efd4", "none")
    result += path("M81 83 Q94 67 108 83 Q99 91 97 99 Q93 91 81 83Z", "#ebf5d9", "none")
    result += eyes(96, 106, 21, action, frame) + mouth(96, 128, action, frame) + freckles(96, 121, 28)
    result += path("M53 128 Q66 118 74 135 M119 136 Q126 118 139 126", "none", "#70aaa0", 2)
    for x, y, size in ((62, 86, 2), (124, 83, 2.5), (131, 90, 1.5), (66, 91, 1.4)):
        result += ellipse(x, y, size, size, IVORY, "none")
    return result


def sprout(action, frame, limb):
    result = rotate(path("M73 143 Q57 156 62 166 Q73 166 84 151", "#8c8560"), limb, 77, 142)
    result += rotate(path("M110 146 Q115 166 130 165 Q132 152 119 140", "#8c8560"), -limb, 113, 143)
    result += path("M93 83 Q62 76 53 37 Q89 32 101 73", "url(#leaf)")
    result += rotate(leaf(100, 84, 1.2, -50), limb * .9, 98, 80)
    result += rotate(leaf(99, 80, 1.6, 39), -limb * 1.1, 99, 80)
    result += leaf(96, 77, .88, -7, "#b9ca80")
    result += path("M55 106 Q56 74 96 76 Q135 73 139 107 Q146 137 121 150 L101 162 72 151 Q46 137 55 106Z", "url(#cream)")
    result += path("M56 117 Q69 124 79 116 L90 128 103 118 116 125 139 113 L139 132 Q124 154 102 160 L72 149 Q59 141 56 117Z", "url(#leaf)", "none")
    result += path("M69 91 L74 98 M84 84 L87 93 M111 85 L109 94 M124 93 L119 99", "none", "#cdb582", 2)
    result += eyes(96, 110, 18, action, frame) + mouth(96, 128, action, frame) + freckles(96, 123, 24)
    result += rotate(path("M62 123 Q39 123 43 142 Q55 145 69 136", "#8ca96d") + leaf(47, 139, .4, -57), limb, 63, 123)
    result += rotate(path("M133 120 Q150 114 155 129 Q148 143 133 136", "#8ca96d") + leaf(146, 132, .4, 70), -limb, 132, 126)
    result += path("M84 147 L88 150 M101 143 L104 147 M114 140 L117 143", "none", "#d6dc9a", 2)
    return result


def moth(action, frame, limb):
    result = ""
    flutter = limb + math.sin(frame / 6 * math.tau) * (12 if action == "idle" else 5)
    for side in (-1, 1):
        wing = path("M82 110 Q54 29 26 36 Q5 42 20 88 Q25 109 55 119 Q22 133 32 153 Q58 177 84 133Z", "url(#gold)")
        wing += path("M76 105 Q50 43 31 44 Q18 47 29 83 Q37 105 64 110 M70 128 Q38 130 40 150 Q61 157 78 132", "#de8b67", INK, 2)
        wing += ellipse(44, 76, 11, 17, "#faf0bc", INK, 2) + ellipse(44, 77, 4, 8, "#668b78", "none")
        wing += path("M35 99 L63 112 M46 139 L69 130 M29 48 L39 61", "none", "#ffe7a3", 2)
        wing += ellipse(36, 119, 3, 3, IVORY, "none") + ellipse(58, 149, 3, 3, IVORY, "none")
        if side == 1:
            wing = group(wing, "translate(192 0) scale(-1 1)")
        result += rotate(wing, side * flutter, 96, 111)
    result += path("M85 79 Q76 56 72 53 M106 78 Q113 54 124 50", width=3)
    result += ellipse(71, 51, 4, 4, CORAL) + ellipse(124, 49, 4, 4, CORAL)
    result += ellipse(96, 115, 20, 43, "url(#cream)")
    result += path("M77 101 L74 112 82 109 80 119 90 113 99 119 106 113 114 117 111 105", "#ffedc5", "none")
    result += eyes(96, 96, 9, action, frame, 3.5) + mouth(96, 109, action, frame)
    result += path("M83 130 Q96 137 109 130 M85 140 Q96 146 107 140 M90 150h12", "none", "#c1a26e", 2)
    result += rotate(path("M80 119 L68 124 M111 119 L124 126", width=2), -limb * .5)
    return result


def crab(action, frame, limb, boss=False):
    result = ""
    shell = "url(#navy)" if boss else "url(#water)"
    for side in (-1, 1):
        for index in range(3):
            foot = path(f"M{96 + side*37} {128+index*8} L{96+side*(57-index*4)} {133+index*9} L{96+side*(63-index*4)} {141+index*9}", width=4)
            result += rotate(foot, limb * side * (1 if index % 2 else -1), 96 + side*38, 140)
        arm = path("M56 116 Q36 110 34 86", "none", "#558e8a", 8)
        arm += path("M33 92 Q8 84 17 56 L30 68 33 43 Q57 44 55 66 Q54 85 33 92Z", "url(#coral)")
        arm += path("M34 76 L40 60 M20 75 Q26 79 31 77", "none", "#ffd4a7", 2)
        if boss:
            arm += path("M16 64 L28 59 28 69 18 73Z", "url(#gold)", INK, 1.5)
        if side == 1:
            arm = group(arm, "translate(192 0) scale(-1 1)")
        result += rotate(arm, side * limb, 96 + side * 42, 117)
    result += path("M47 124 Q47 91 94 87 Q143 87 146 123 Q149 152 95 160 Q42 152 47 124Z", shell)
    result += path("M50 125 Q96 143 143 124 L140 141 Q96 162 52 142Z", "#234f58" if boss else "#548f86", "none")
    result += path("M65 117 Q94 101 126 115 M71 146 Q96 152 120 146", "none", "#adcdbc", 2)
    result += path("M74 100 L72 79 M118 100 L120 79", width=5)
    result += ellipse(72, 78, 8, 10, IVORY, INK, 2) + ellipse(120, 78, 8, 10, IVORY, INK, 2)
    result += eyes(96, 79, 24, action, frame, 3.5) + mouth(96, 124, action, frame)
    for x, y in ((57, 125), (68, 131), (131, 124), (123, 132)):
        result += ellipse(x, y, 2, 2, "#dbddaa", "none")
    if boss:
        result += path("M56 68 Q53 54 65 45 L76 34 Q96 45 116 34 L130 45 Q141 53 135 68 L113 62 Q94 67 76 61Z", "url(#navy)")
        result += path("M57 62 Q75 49 96 57 Q121 46 135 61", "none", GOLD, 3)
        result += ellipse(97, 48, 10, 10, "url(#gold)", INK, 2) + star(97, 48, 6, IVORY)
        result += rotate(path("M119 44 Q149 30 156 14 Q129 12 119 44Z", "#eebc79", INK, 2) + path("M122 39 L151 20", width=1.5), limb * .3, 120, 44)
        result += path("M63 102 L71 118 85 108 95 119 107 109 124 119 131 101", "none", GOLD, 3)
        result += ellipse(97, 136, 10, 10, "url(#gold)", INK, 2) + star(97, 136, 6, IVORY)
    return result


def owl(action, frame, limb):
    result = ""
    for side in (-1, 1):
        x = 96 + side * 19
        result += rotate(path(f"M{x} 145v19 m0 -3 l-9 5 m9 -5 l9 5", "none", "#ae8950", 4), limb * side, x, 150)
    result += path("M53 103 Q48 67 50 40 L78 57 Q97 49 115 56 L143 38 Q146 64 142 99 Q150 143 115 155 Q96 163 72 153 Q46 141 53 103Z", "url(#forest)")
    result += path("M59 71 L56 49 74 66 M121 64 L139 47 134 74", "#8caf86", "none")
    result += path("M60 85 Q77 68 96 87 Q115 66 132 86 Q148 121 96 143 Q45 119 60 85Z", "url(#cream)", "none")
    for side in (-1, 1):
        wing = path("M57 108 Q28 110 38 148 Q60 145 69 123", "url(#leaf)")
        wing += path("M45 121 L42 137 M52 124 L48 140 M59 126 L55 138", "none", "#406852", 1.8)
        if side == 1:
            wing = group(wing, "translate(192 0) scale(-1 1)")
        result += rotate(wing, side * limb * 1.8, 96 + side * 34, 110)
    result += eyes(96, 105, 19, action, frame, 5.5)
    result += ellipse(77, 104, 14, 16, "none", "#ae8545", 2) + ellipse(115, 104, 14, 16, "none", "#ae8545", 2)
    result += path("M91 103 Q96 98 101 103", "none", "#ae8545", 2)
    result += path("M90 121 L96 130 102 121Z", "url(#gold)", INK, 1.8)
    result += path("M75 142 L78 147 82 143 M94 143 L97 150 101 144 M114 140 L117 145 121 140", "none", "#c9d197", 2)
    result += leaf(135, 70, .5, 42, "#d9c778")
    return result


def human(action, frame, limb, role):
    captain = role == "captain"
    healer = role == "healer"
    result = rect(119, 101, 24, 39, 8, "#b98053") + path("M123 111h15 M130 114v12", width=2)
    for side in (-1, 1):
        x = 96 + side * 14
        leg = path(f"M{x-7} 139 L{x-8} 164 Q{x+1} 169 {x+10} 164 L{x+6} 139Z", "#496260")
        leg += path(f"M{x-8} 157 L{x-9} 168 Q{x+3} 174 {x+13} 169 L{x+10} 161Z", "#76583e")
        leg += path(f"M{x-5} 160 L{x+7} 162", "none", "#ccaa71", 2)
        result += rotate(leg, side * limb * .6, x, 140)
    coat = "url(#cream)" if healer else "url(#forest)" if captain else "url(#gold)"
    result += path("M70 100 Q96 92 121 101 L129 145 Q98 158 65 146Z", coat)
    result += path("M94 109v36 M77 121v9h10 M112 121v9h-10", "none", "#719077" if healer else "#715f45", 2)
    result += path("M66 140 Q98 149 128 139", "none", "#614f39", 5)
    result += rect(91, 139, 11, 8, 1, "url(#gold)", INK, 1.5)
    for side in (-1, 1):
        x = 96 + side * 29
        arm = path(f"M{x} 105 Q{x+side*8} 115 {x+side*10} 130", "none", "#42776d" if captain else "#fff0ca" if healer else "#d8ac62", 13)
        arm += ellipse(x+side*10, 132, 7, 8, "url(#skin)", INK, 2)
        if side == 1:
            if healer:
                arm += rect(131, 130, 12, 18, 4, "url(#water)", INK, 2) + rect(133, 125, 8, 6, 1, GOLD, INK, 1.5)
                arm += leaf(138, 145, .19, 22, IVORY)
            elif captain:
                arm += path("M139 123 L145 160", "none", GOLD, 4) + ellipse(139, 123, 4, 4, IVORY, INK, 2)
            else:
                arm += rect(134, 126, 15, 20, 2, "#786846", INK, 2) + path("M138 130h7 M138 134h7 M138 138h5", "none", IVORY, 1.5)
        result += rotate(arm, -side * limb, x, 106)
    result += path("M72 97 L86 112 95 104 106 113 121 98", "#64a993" if healer else CORAL, INK, 2)
    result += rotate(path("M112 101 L135 105 129 114 112 109Z", "#77b09c" if healer else CORAL, INK, 2), -limb, 113, 104)
    result += ellipse(96, 76, 29, 29, "url(#skin)")
    result += ellipse(67, 78, 5, 8, "url(#skin)", INK, 2) + ellipse(125, 78, 5, 8, "url(#skin)", INK, 2)
    result += path("M69 79 Q61 46 90 44 Q125 39 124 78 L116 69 113 59 Q101 69 84 62 L76 82Z", "#ded0b0" if captain else "#805439", "none")
    result += eyes(96, 79, 11, action, frame, 3) + freckles(96, 90, 17)
    result += mouth(96, 92, action, frame)
    if captain:
        result += path("M83 90 Q90 83 96 89 Q104 83 111 90 Q103 100 96 94 Q88 99 83 90Z", "#e3d5b6", INK, 1.5)
        result += path("M63 57 L66 40 Q95 26 125 40 L131 57 Q94 67 63 57Z", "url(#forest)")
        result += path("M63 54 Q96 64 131 54 L136 60 Q98 77 58 61Z", "url(#gold)")
        result += ellipse(96, 48, 8, 8, "url(#gold)", INK, 1.5) + star(96, 48, 5, IVORY)
        result += rotate(leaf(120, 44, .78, 40, IVORY), limb * .5, 120, 44)
        result += ellipse(116, 120, 5, 7, GOLD, INK, 1.2)
    elif healer:
        result += path("M63 65 Q58 34 96 30 Q134 33 130 66 L118 58 Q96 51 75 61Z", "url(#cream)")
        result += path("M67 50 Q93 34 124 51", "none", "#91b393", 4)
        result += leaf(96, 52, .4, 18, "#588568")
        result += path("M76 113 L82 139 Q98 146 114 139 L119 113 105 119 87 119Z", IVORY, INK, 1.5)
        result += leaf(97, 136, .32, 24)
    else:
        result += path("M68 56 Q65 26 95 25 Q123 24 128 55Z", "url(#forest)")
        result += path("M66 48 Q96 56 128 47 L129 57 Q98 65 65 58Z", "url(#gold)", INK, 1.5)
        result += path("M53 58 Q62 52 78 59 Q107 66 131 55 Q147 57 142 64 Q100 79 56 68Z", "url(#gold)")
        result += ellipse(111, 53, 5, 6, "url(#cream)", INK, 1.4) + leaf(124, 48, .43, 35, "#d8d694")
        result += path("M73 115 L118 142", "none", "#705439", 4)
    return result


def character(name, action="idle", frame=0):
    limb, bob, angle = motion(action, frame)
    functions = {"ember": ember, "tide": tide, "sprout": sprout, "moth": moth,
                 "crab": crab, "owl": owl}
    if name in functions:
        body = functions[name](action, frame, limb)
    elif name == "crab_captain":
        body = crab(action, frame, limb, True)
    else:
        body = human(action, frame, limb, name)
    if action == "defeat":
        body = group(body, f"translate(96 122) scale({n(1-frame*.025)}) translate(-96 -122)")
    body = group(rotate(body, angle, 96, 116), f"translate(0 {n(bob)})")
    # 翼・はさみ・隊長の羽飾りが最大に開いたフレームもセル内へ収める。
    padding_scale = .86 if name in ("moth", "crab", "crab_captain") else .94 if name == "tide" else 1
    body = group(body, f"translate(96 96) scale({padding_scale}) translate(-96 -96)")
    shadow = ellipse(96, 171, 46 if name in ("moth", "crab", "crab_captain") else 36, 6,
                     "#183c32", "none", extra='opacity="0.13"')
    if action == "hurt" and frame in (1, 3):
        body += star(154, 43, 9, "#fff1ad") + star(41, 62, 6, CORAL)
    if action == "defeat":
        body += star(70 + frame*7, 45, 5, GOLD)
    return shadow + body


def write_characters():
    for name in CHARACTERS:
        frames = []
        for row, action in enumerate(ANIMATIONS):
            for column in range(6):
                x, y = column * 192, row * 192
                # Godot の SVG インポーターでも描画できるよう入れ子の svg は使わない。
                frames.append(group(character(name, action, column), f"translate({x} {y})"))
        (ASSETS / "characters" / f"{name}.svg").write_text(svg("".join(frames), 1152, 960))
        if name in CHARACTERS[:6]:
            (ASSETS / "monsters" / f"{name}.svg").write_text(svg(character(name)))


def element_icon(kind):
    if kind == "fire":
        return path("M46 17 Q51 34 40 41 Q51 35 55 29 Q72 49 57 65 Q43 79 29 63 Q18 50 34 32 Q32 47 40 46 Q48 34 46 17Z", "url(#coral)", INK, 2) + path("M45 45 Q58 59 45 67 Q32 64 39 55Z", "#fff2b5", "none")
    if kind == "water":
        return path("M43 16 Q51 32 61 43 Q76 65 46 71 Q18 72 23 49 Q27 37 43 16Z", "url(#water)", INK, 2) + path("M32 49 Q27 60 37 63", "none", "#e3f8e2", 4)
    return leaf(40, 71, 1.25, 16) + leaf(43, 67, .75, -41, "#c4d690")


def write_icons():
    capture = ellipse(48, 51, 34, 34, "url(#cream)")
    capture += path("M15 50 Q15 15 48 16 Q81 16 82 50 Q47 66 15 50Z", "url(#forest)")
    capture += path("M17 50 Q47 62 80 50", "none", GOLD, 5)
    capture += ellipse(48, 54, 11, 12, "url(#gold)", INK, 2) + leaf(48, 61, .32, 12, IVORY)
    capture += path("M28 29 Q38 22 49 24", "none", "#b4d1a7", 4)
    potion = path("M35 33v12 Q16 55 22 77 Q47 89 73 77 Q80 55 59 45V33Z", "url(#water)")
    potion += path("M23 61 Q45 51 72 62 L72 75 Q45 85 24 76Z", "#65a88f", "none")
    potion += rect(33, 24, 28, 13, 3, "url(#gold)") + rect(30, 36, 34, 10, 4, "url(#cream)", INK, 2)
    potion += ellipse(48, 65, 12, 13, "url(#cream)", INK, 2) + leaf(48, 73, .4, 15)
    potion += path("M29 57 L28 69", "none", "#d8efcb", 4) + ellipse(61, 58, 3, 3, IVORY, "none")
    emblem = ellipse(48, 48, 37, 37, "url(#gold)", INK, 2)
    emblem += ellipse(48, 48, 30, 30, "url(#forest)", IVORY, 1)
    emblem += path("M48 24 L54 43 72 48 54 54 48 73 42 54 24 48 42 42Z", "url(#cream)", INK, 1.5)
    emblem += ellipse(48, 48, 5, 5, CORAL, INK, 1)
    for name, content in (("capture_ball", capture), ("potion", potion), ("emblem", emblem)):
        (ASSETS / "ui" / f"{name}.svg").write_text(svg(content, 96, 96))
    for kind in ("fire", "water", "leaf"):
        (ASSETS / "ui" / f"type_{kind}.svg").write_text(svg(element_icon(kind), 88, 88))
        projectile = group(element_icon(kind), "translate(4 4) scale(1.35)")
        projectile += star(102, 27, 8, CORAL if kind == "fire" else GOLD) + star(21, 103, 5, IVORY)
        (ASSETS / "effects" / f"projectile_{kind}.svg").write_text(svg(projectile, 128, 128))
    spark = star(32, 32, 29, IVORY) + star(32, 32, 14, GOLD)
    (ASSETS / "effects" / "spark.svg").write_text(svg(spark, 64, 64))
    logo = group(emblem, "translate(88 8) scale(2.2)")
    logo += path("M98 155 Q62 150 33 123 M302 155 Q338 150 367 123", "none", GOLD, 3)
    for side in (-1, 1):
        for i in range(5):
            logo += leaf(200 + side * (111 + i*10), 139-i*6, .65, side*(65+i*10), "#a1bd87")
    logo += path("M119 180 Q200 200 281 180 L294 207 Q201 230 107 207Z", "url(#cream)", INK, 3)
    logo += path("M137 196 Q200 209 263 196", "none", GOLD, 2)
    (ASSETS / "ui" / "logo.svg").write_text(svg(logo, 400, 240))


def tree(x, y, scale, fill, seed):
    rng = random.Random(seed)
    body = path("M-9 0 L-5 -119 8 -132 15 0Z", "#476b58" if fill != "#244c40" else "#264f42", "none")
    for i in range(8):
        cy = -84 - i*13
        rx = 35 - i*2 + rng.randrange(9)
        body += ellipse(rng.randrange(-10, 11), cy, rx, 25, fill, "none")
    for i in range(14):
        detail_x = rng.randrange(-22, 23)
        detail_y = rng.randrange(-166, -74)
        body += path(f"M{detail_x-4} {detail_y+3} q4 -8 10 -8", "none", "#c0d094", 1.5, 'opacity="0.18"')
    body += path("M0 -7 L0 -121 M0 -75 L-17 -96 M0 -102 L19 -125", "none", "#76947a", 2, 'opacity="0.38"')
    return group(body, f"translate({x} {y}) scale({scale})")


def write_backgrounds():
    rng = random.Random(20916)
    sky = '''<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#ede8c9"/><stop offset="0.55" stop-color="#d8e2bd"/><stop offset="1" stop-color="#9bc2a7"/></linearGradient></defs>'''
    far = rect(0, 0, 1280, 720, 0, "url(#sky)", "none")
    far += ellipse(878, 151, 116, 116, "#fff4c9", "none", extra='opacity="0.75"')
    far += ellipse(878, 151, 180, 180, "url(#glow)", "none")
    far += path("M0 354 Q172 277 290 350 Q450 245 640 343 Q832 250 1010 310 Q1177 275 1280 340V720H0Z", "#a8bfa0", "none")
    far += path("M0 438 Q249 326 420 432 Q684 338 853 412 Q1086 330 1280 398V720H0Z", "#8bb096", "none")
    for i in range(24):
        x = i*58 + rng.randrange(-15, 16)
        far += tree(x, 427+rng.randrange(30), .6 + rng.random()*.5, "#81a68a", i)
    far += path("M0 577 Q281 451 520 525 Q792 477 1280 534V720H0Z", "#a9c198", "none")
    for x, y in ((215, 150), (294, 111), (734, 82)):
        far += path(f"M{x} {y} q10 -7 19 0 q8 -7 17 -2", "none", "#7e9b80", 2, 'opacity="0.6"')
    far += path("M413 546 Q729 473 874 542 Q994 604 671 679 L352 720H860 Q1232 614 1114 535 Q965 458 683 493Z", "#bcd2ae", "none")
    (ASSETS / "backgrounds" / "forest_far.svg").write_text(svg(sky+far, 1280, 720))
    middle = path("M0 615 Q174 513 345 593 Q532 643 716 572 Q942 490 1280 584V720H0Z", "#81a881", "none")
    for i, (x, scale) in enumerate(((30, 2.9), (131, 2.5), (235, 1.8), (1168, 2.8), (1059, 2), (1275, 3.3))):
        middle += tree(x, 645, scale, "#538669" if i % 2 else "#608f70", 100+i)
    middle += path("M0 689 Q351 576 582 656 Q820 577 1280 651V720H0Z", "#608e6e", "none")
    for i in range(45):
        x = rng.randrange(1280)
        y = rng.randrange(637, 720)
        middle += path(f"M{x} {y} l-5 -12 m5 12 l4 -16 m-4 16 l10 -8", "none", "#b1c98e", 1.4)
    (ASSETS / "backgrounds" / "forest_mid.svg").write_text(svg(middle, 1280, 720))
    near = path("M0 0H102 Q47 112 75 285 Q36 390 52 571 L0 636Z M1280 0H1187 Q1218 157 1199 293 Q1238 437 1230 586L1280 642Z", "#315e49", "none")
    near += path("M0 0H1280V36 Q1132 2 1071 71 Q894 9 793 32 Q651 3 576 43 Q331 17 192 93 Q78 12 0 57Z", "#3b674f", "none")
    for side in (-1, 1):
        for i in range(14):
            x = 40+i*11 if side < 0 else 1240-i*11
            y = 727-(i%4)*14
            near += leaf(x, y, 1.8-(i%3)*.25, side*(28+i%5*15), "#315f49" if i%2 else "#4a7853")
        for i in range(9):
            x = 25+i*23 if side < 0 else 1255-i*23
            near += leaf(x, 70-(i%3)*16, 1.3, side*(110+i*7), "#719359" if i%2 else "#527d52")
    for x, y in ((181, 655), (1133, 648)):
        near += path(f"M{x} {y}v26 M{x+18} {y+11}v16", "none", "#d9c69d", 6)
        near += ellipse(x, y, 15, 8, CORAL, INK, 1.5) + ellipse(x+18, y+11, 11, 6, GOLD, INK, 1.5)
        near += ellipse(x-4, y-2, 3, 2, IVORY, "none")
    (ASSETS / "backgrounds" / "forest_near.svg").write_text(svg(near, 1280, 720))


def write_keyart():
    body = ellipse(333, 304, 257, 267, "#e7dfb8", "none")
    body += ellipse(333, 285, 226, 236, "url(#forest)", GOLD, 3)
    body += ellipse(345, 198, 147, 147, "#9bb891", "none")
    body += ellipse(375, 154, 78, 78, "#f7e8b8", "none")
    for i, (x, y, scale) in enumerate(((143, 378, 1.4), (500, 395, 1.8), (447, 406, 1.3), (205, 379, 1.1))):
        body += tree(x, y, scale, "#648b6a", 400+i)
    body += path("M128 410 Q283 308 516 407 Q494 499 328 519 Q179 506 128 410Z", "#87a476", "none")
    body += path("M283 344 Q336 349 382 415 Q347 462 286 502 L403 498 Q466 453 415 403 Q364 355 283 344Z", "#d4c798", "none")
    body += group(character("player", "walk", 1), "translate(155 153) scale(1.9)")
    body += group(character("tide", "idle", 0), "translate(391 331) scale(1.03)")
    body += group(character("sprout", "idle", 0), "translate(26 333) scale(1.1)")
    body += group(character("ember", "idle", 0), "translate(178 363) scale(1.15)")
    for side in (-1, 1):
        for i in range(7):
            body += leaf(321 + side * (223-i*11), 439+i*15, .95, side*(30+i*8), "#688e60" if i%2 else "#a8b677")
    for x, y, size in ((158, 169, 7), (483, 126, 9), (448, 281, 5), (117, 292, 6), (377, 86, 5), (534, 368, 6)):
        body += star(x, y, size, GOLD)
    body += path("M161 548 Q318 577 473 540", "none", GOLD, 2)
    body += ellipse(320, 554, 4, 4, CORAL, "none")
    (ASSETS / "backgrounds" / "title_keyart.svg").write_text(svg(body, 640, 600))


def main():
    for directory in ("characters", "monsters", "ui", "effects", "backgrounds"):
        (ASSETS / directory).mkdir(parents=True, exist_ok=True)
    write_characters()
    write_icons()
    write_backgrounds()
    write_keyart()
    generated = [*ASSETS.glob("characters/*.svg"), *ASSETS.glob("monsters/*.svg"),
                 *ASSETS.glob("ui/*.svg"), *ASSETS.glob("effects/*.svg"), *ASSETS.glob("backgrounds/*.svg")]
    for image in generated:
        ET.parse(image)
    print(f"画像生成 OK: {len(generated)} SVG、10 体 × 5 種 × 6 フレーム。XML 検証済み")


if __name__ == "__main__":
    main()
