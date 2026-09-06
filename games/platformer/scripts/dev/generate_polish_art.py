"""空の郵便路の独自 SVG を生成する。同じ入力から同じ画像を再生成できる。"""

from pathlib import Path
import math


IMAGES = Path(__file__).resolve().parents[2] / "assets" / "images"
INK = "#234751"
CREAM = "#fff5d8"
DEFS = """
<defs>
  <linearGradient id="coat" x1="0" y1="0" x2=".8" y2="1">
    <stop stop-color="#ffe5a0"/><stop offset=".5" stop-color="#f5bd59"/>
    <stop offset="1" stop-color="#d68c3a"/>
  </linearGradient>
  <linearGradient id="teal" x1="0" y1="0" x2=".8" y2="1">
    <stop stop-color="#98e6cd"/><stop offset=".55" stop-color="#48b8ae"/>
    <stop offset="1" stop-color="#23898d"/>
  </linearGradient>
  <linearGradient id="coral" x1="0" y1="0" x2=".8" y2="1">
    <stop stop-color="#ffd09b"/><stop offset=".55" stop-color="#ef9471"/>
    <stop offset="1" stop-color="#cf6658"/>
  </linearGradient>
  <linearGradient id="skin" x1="0" y1="0" x2=".8" y2="1">
    <stop stop-color="#fff0cb"/><stop offset="1" stop-color="#eab18b"/>
  </linearGradient>
  <linearGradient id="brass" x1="0" y1="0" x2=".9" y2="1">
    <stop stop-color="#fff3b7"/><stop offset=".45" stop-color="#f9ce63"/>
    <stop offset="1" stop-color="#cf873d"/>
  </linearGradient>
  <linearGradient id="rock" x1="0" y1="0" x2=".8" y2="1">
    <stop stop-color="#548895"/><stop offset="1" stop-color="#294956"/>
  </linearGradient>
  <linearGradient id="dirt" x1="0" y1="0" x2="0" y2="1">
    <stop stop-color="#bc8865"/><stop offset="1" stop-color="#916753"/>
  </linearGradient>
</defs>
"""


def path(d, fill="none", stroke=INK, width=1.5, extra=""):
    return (f'<path d="{d}" fill="{fill}" stroke="{stroke}" '
            f'stroke-width="{width}" stroke-linecap="round" '
            f'stroke-linejoin="round" {extra}/>')


def ellipse(cx, cy, rx, ry, fill, stroke="none", width=1.5, extra=""):
    return (f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{fill}" '
            f'stroke="{stroke}" stroke-width="{width}" {extra}/>')


def rect(x, y, w, h, fill, radius=0, stroke="none", width=1.5, extra=""):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" '
            f'fill="{fill}" stroke="{stroke}" stroke-width="{width}" {extra}/>')


def group(body, transform="", extra=""):
    return f'<g transform="{transform}" {extra}>{body}</g>'


def svg(name, width, height, body):
    """決定的な SVG を上書きする。既存の音声や従来の生成コードには触れない。"""
    IMAGES.mkdir(parents=True, exist_ok=True)
    (IMAGES / f"{name}.svg").write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}">{DEFS}{body}</svg>\n', encoding="utf-8")


def envelope(x, y, w, h, fill=CREAM, width=1):
    return (rect(x, y, w, h, fill, 1.2, INK, width)
            + path(f'M{x} {y + h}l{w / 2} {-h * .55} {w / 2} {h * .55}',
                   stroke="#b18c65", width=width)
            + path(f'M{x} {y}l{w / 2} {h * .57} {w / 2} {-h * .57}',
                   stroke=INK, width=width))


def sparkle(x, y, r, color=CREAM):
    return path(f'M{x} {y - r}Q{x + 1} {y - 1} {x + r} {y}'
                f'Q{x + 1} {y + 1} {x} {y + r}'
                f'Q{x - 1} {y + 1} {x - r} {y}'
                f'Q{x - 1} {y - 1} {x} {y - r}Z', color, "none")


def courier(state, frame):
    """脚、腕、表情と小物を姿勢ごとに描き、単なる一枚絵の変形を避ける。"""
    phase = frame * math.tau / 6
    swing = math.sin(phase)
    bob = -.7 * math.cos(phase)
    lean = 0
    left_foot, right_foot = (26, 72), (40, 73)
    left_hand, right_hand = (16, 49), (48, 48)
    if state == "run":
        bob = -abs(swing) * 2 + math.cos(phase) * .6
        lean = 5
        left_foot = (26 + swing * 12, 70 - max(0, swing) * 8)
        right_foot = (40 - swing * 12, 70 - max(0, -swing) * 8)
        left_hand = (17 - swing * 8, 47 + swing * 5)
        right_hand = (46 + swing * 8, 47 - swing * 5)
    elif state == "jump":
        bob = -2 - math.sin(frame / 5 * math.pi)
        lean = -4 + frame
        left_foot, right_foot = (21 - frame * .4, 65 + frame * .5), (43, 64 - frame * .3)
        left_hand, right_hand = (16 - frame * .4, 37 - frame), (48, 31 + frame)
    elif state == "fall":
        bob = math.sin(phase)
        left_foot, right_foot = (23 - frame * .4, 72), (44 + frame * .3, 70)
        left_hand, right_hand = (11, 36 + swing * 2), (53, 36 - swing * 2)
    elif state == "stomp":
        bob = 1 + math.sin(frame / 5 * math.pi) * 5
        left_foot, right_foot = (24, 72 - bob), (43, 72 - bob)
        left_hand, right_hand = (14, 39 + frame), (51, 40 + frame)
    elif state == "hurt":
        lean = -8 + frame * 2
        bob = -1 + swing
        left_foot, right_foot = (20, 70), (44, 68)
        left_hand, right_hand = (15, 32 + frame), (50, 33 + frame)
    elif state == "death":
        lean = -10 + frame * 3
        bob = min(frame * 1.5, 6)
        left_foot, right_foot = (18 + frame, 63 - frame), (48 - frame, 64 - frame)
        left_hand, right_hand = (12 + frame, 35), (51 - frame, 34)

    body = ""
    # 奥の脚と手を先に描き、左右の重なりを歩行周期で変える。
    for hip, foot, color in ((29, left_foot, "#345560"), (38, right_foot, "#52737c")):
        x, y = foot
        knee_x, knee_y = (hip + x) / 2 - 2, 60
        body += path(f'M{hip} 51Q{knee_x} {knee_y} {x} {y - 3}',
                     stroke=INK, width=9)
        body += path(f'M{hip} 51Q{knee_x} {knee_y} {x} {y - 3}',
                     stroke=color, width=5.7)
        body += path(f'M{x - 4} {y - 5}l7 0 4 5q0 2 -4 2h-9z', "#354a50", width=1.3)
        body += path(f'M{x - 4} {y + 2}h11', stroke="#e3bc82", width=2)
    body += path(f'M23 37Q16 39 {left_hand[0]} {left_hand[1]}',
                 stroke=INK, width=9)
    body += path(f'M23 37Q16 39 {left_hand[0]} {left_hand[1]}',
                 stroke="#e8ac55", width=5.7)
    body += ellipse(*left_hand, 3.8, 4, "url(#skin)", INK, 1.2)
    body += path('M12 31l12-2 4 25-13 2Q9 47 12 31Z', "#a46747")
    body += path('M12 34l13-1 1 8-13 2Z', "#cb9164")
    body += rect(17, 39, 4, 6, "url(#brass)", 1, INK, 1)
    body += path('M22 31Q32 27 42 32l5 22q-13 8-27 0Z', "url(#coat)", width=1.7)
    body += path('M24 35l-1 18M40 35l4 17', stroke="#fff0bf", width=1.3)
    body += path('M32 34v19M23 54q9 3 20-1', stroke="#b97e45", width=1)
    body += ellipse(34, 41, 1, 1, INK) + ellipse(35, 46, 1, 1, INK)
    body += envelope(35, 44, 8, 6, width=.8)
    body += path('M18 30L41 50', stroke=INK, width=4)
    body += path('M18 30L41 50', stroke="#a66948", width=2.3)
    body += path(f'M41 35Q48 40 {right_hand[0]} {right_hand[1]}', stroke=INK, width=9)
    body += path(f'M41 35Q48 40 {right_hand[0]} {right_hand[1]}', stroke="#e9ae54", width=6)
    body += ellipse(*right_hand, 3.8, 4.2, "url(#skin)", INK, 1.2)
    # 浮くマフラー、耳、帽子の郵便章で小さい表示でも配達人と分かる。
    tail = -4 - swing * (4 if state in ("run", "jump", "fall") else 1.5)
    body += path(f'M28 28Q18 25 7 {26 + tail}l3 5-6 2q12 5 24-1Z',
                 "#e97e68", width=1.2)
    body += path(f'M10 {28 + tail}Q17 30 23 28', stroke="#ffbea1", width=1)
    body += path('M24 14Q26 9 38 12q11 3 10 13l4 4-5 2q-1 7-11 6l-11-6Z',
                 "url(#skin)", width=1.5)
    body += ellipse(25, 26, 4, 5, "url(#skin)", INK, 1.2)
    body += path('M24 26q3-3 3 1', stroke="#be886f", width=1)
    body += path('M27 17l-1 7-4 0 1-9Z', "#71504a", width=1)
    if state in ("hurt", "death"):
        body += path('M39 21l5 5m0-5-5 5', stroke=INK, width=1.7)
        body += path('M40 32q3-3 5 0', stroke="#a96157", width=1.4)
    elif state == "idle" and frame == 4:
        body += path('M39 24q3 2 5 0', stroke=INK, width=1.7)
        body += path('M39 32q3 2 6-1', stroke="#a96157", width=1.2)
    else:
        body += ellipse(42, 24, 1.8, 3, INK)
        body += ellipse(42.5, 23, .6, .8, CREAM)
        body += path('M39 32q3 2 6-1', stroke="#a96157", width=1.2)
    body += ellipse(43, 29, 3.5, 1.5, "#e89779", extra='opacity=".65"')
    body += path('M20 19Q18 7 30 7q15-2 18 13l-16 1-5-3Z', "url(#teal)", width=1.6)
    body += path('M22 13Q26 8 33 10', stroke="#d7f4d8", width=2)
    body += path('M31 18Q45 16 52 20q0 3-7 3l-15-1Z', "#2e8285", width=1.2)
    body += envelope(25, 12, 9, 6, width=.65)
    body += path('M28 32q7 3 16 1l-1 5q-9 2-16-2Z', "#e97e68", width=1.2)
    body += path('M32 34l8 2', stroke="#ffba99", width=1)
    return group(body, f'translate(0 {bob:.3f}) rotate({lean} 32 45)')


def walker(state, frame):
    phase = frame * math.tau / 6
    swing = math.sin(phase)
    bob = -.8 * math.cos(phase)
    squash = 1
    if state == "walk":
        bob = -abs(swing) * 2 + math.cos(phase) * .7
    if state == "attack":
        bob, squash = -2 * abs(swing) + math.cos(phase) * .7, .93
    if state == "hurt":
        bob, squash = 2 + frame * .4, .86
    if state == "death":
        bob, squash = 13 + frame * 2, .56 - frame * .045
    foot_shift = swing * (7 if state == "walk" else 1)
    body = path(f'M20 42l{-foot_shift:.2f} 6h-8q-1-5 4-7Z', "#765147")
    body += path(f'M39 42l{foot_shift:.2f} 6h8q1-5-4-7Z', "#a36148")
    body += path('M10 29Q7 16 19 13Q27 5 39 14q18 4 16 20 2 12-18 13Q14 50 10 38Z',
                 "url(#coral)", width=1.7)
    body += path('M15 25Q19 13 28 15', stroke="#ffe1ad", width=2.8)
    body += path('M15 33q2-7 7-3 9-7 14-3 7-3 13 2l1 9q-5 9-18 7-14 0-17-12Z',
                 "#f8d5ab", "none")
    body += path('M11 29l-4-3m3 9-5 1M51 23l4-4m0 10 5-1', stroke="#c37657", width=1.5)
    sprout = 2 * swing
    body += path(f'M30 15Q{29 + sprout} 5 35 3', stroke="#38785c", width=2)
    body += path(f'M31 10Q{17 + sprout} 0 17 6q0 7 14 4Z', "#8bc580", "#38785c", 1.2)
    body += path(f'M32 8Q43 {-1 + sprout} 45 4q1 8-13 4Z', "#b4dd95", "#38785c", 1.2)
    body += path('M19 6l10 3m7-4 6-1', stroke="#d3eeb4", width=1)
    if state in ("hurt", "death"):
        body += path('M27 28l5 5m0-5-5 5m13-5 5 5m0-5-5 5', width=1.7)
        body += ellipse(36, 38, 3, 2.4, "#84504b")
    elif state == "idle" and frame == 4:
        body += path('M27 31q3 2 5 0m8 0q3 2 5 0', width=1.7)
        body += path('M34 38q3 2 5-1', stroke="#aa6654", width=1.4)
    else:
        body += ellipse(30, 30, 2.5, 3.5, INK) + ellipse(43, 30, 2.5, 3.5, INK)
        body += ellipse(30.7, 28.6, .7, 1, CREAM) + ellipse(43.7, 28.6, .7, 1, CREAM)
        body += path('M34 38q3 2 5-1', stroke="#aa6654", width=1.4)
        if state == "attack":
            body += path('M27 24l6 3m6 0 7-3', width=1.8)
    body += ellipse(24, 35, 3, 1.7, "#eaa181") + ellipse(47, 35, 3, 1.7, "#eaa181")
    body += ellipse(18, 22, 1.2, 1.2, "#f7bd92") + ellipse(48, 19, 1.2, 1.2, "#f7bd92")
    if state == "death":
        return group(body, f'translate(0 3) translate(32 49) scale(1 {squash:.3f}) translate(-32 -49)')
    return group(body, f'translate(0 {3 + bob:.3f}) translate(32 45) scale(1 {squash:.3f}) translate(-32 -45)')


def beetle(state, frame):
    phase = frame * math.tau / 6
    swing = math.sin(phase)
    withdrawn = state in ("idle", "attack", "hurt", "death")
    body = ""
    for side in (-1, 1):
        for leg in range(3):
            x = 18 + leg * 10
            shift = swing * 4 * (-1 if leg % 2 else 1) if state == "walk" else 0
            body += path(f'M{x} 38q{side * 5} 5 {side * 8 + shift} 9', stroke=INK, width=4)
            body += path(f'M{x} 38q{side * 5} 5 {side * 8 + shift} 9', stroke="#72a69e", width=2)
    if not withdrawn:
        body += path(f'M43 34Q55 {26 + swing} 58 34l-1 8-13 2Z', "#b9dab4", width=1.4)
        body += path(f'M50 29Q51 {20 + swing} 55 19', stroke=INK, width=1.5)
        body += ellipse(55, 19 + swing * .3, 2, 2, "#f3d894", INK, 1)
        body += ellipse(54, 34, 1.6, 2.3, INK)
        body += ellipse(54.5, 33.4, .5, .7, CREAM)
    body += path('M9 38Q7 19 21 13L35 6l14 13q8 7 5 19l-11 8H20Z',
                 "url(#teal)", width=1.8)
    body += path('M21 13L35 6l-5 21-13-4Z', "#b5efce", "#368f87", 1.2)
    body += path('M35 6l14 13-19 8Z', "#75d6bd", "#368f87", 1.2)
    body += path('M17 23l13 4-7 14-14-3Z', "#4ba997", "#337f7d", 1.2)
    body += path('M30 27l19-8 5 19-14 5Z', "#2e9995", "#337f7d", 1.2)
    body += path('M30 27l10 16-17-2Z', "#80d7bd", "#337f7d", 1.2)
    body += path('M35 9l-3 14M23 16l-3 5', stroke="#e2ffe1", width=2)
    body += path('M10 39q23 10 43-1l-1 7q-20 10-41 0Z', "#efdca6", width=1.4)
    body += path('M16 43q16 5 31 0', stroke="#fff2ca", width=1.6)
    if state == "attack":
        glints = ((17, 21), (35, 10), (48, 24), (37, 35), (21, 34), (14, 27))
        body += sparkle(*glints[frame], 5, "#e9ffd1")
    if state in ("hurt", "death"):
        body += path('M27 35l4 4m0-4-4 4m10-4 4 4m0-4-4 4', width=1.7)
    elif state == "idle":
        body += path('M29 43h3m5 0h3', stroke="#385d61", width=1.6)
        body += sparkle(35 + swing * 6, 16, 2 + abs(swing), "#e8ffe1")
    bob = -abs(swing) + math.cos(phase) * .55 if state == "walk" else .5 * math.cos(phase)
    if state == "death":
        return group(body, f'translate(0 3) translate(32 48) scale(1 {.65 - frame * .05}) translate(-32 -48)')
    if state == "hurt":
        compression = .82 + math.cos(phase) * .035
        return group(body, f'translate({swing * 1.3:.3f} 6) translate(32 40) scale(1 {compression:.3f}) translate(-32 -40)')
    return group(body, f'translate(0 {3 + bob:.3f})')


def sheets():
    for name, height, states, draw in (
        ("player_sheet", 80, ("idle", "run", "jump", "fall", "stomp", "hurt", "death"), courier),
        ("walker_sheet", 56, ("idle", "walk", "attack", "hurt", "death"), walker),
        ("shell_sheet", 56, ("idle", "walk", "attack", "hurt", "death"), beetle),
    ):
        cells = []
        for row, state in enumerate(states):
            for frame in range(6):
                cells.append(group(draw(state, frame), f'translate({frame * 64} {row * height})'))
        svg(name, 384, height * len(states), "".join(cells))


def items():
    svg("coin", 24, 24,
        ellipse(12.4, 12.4, 9.6, 10.6, "#b77937", INK, 1)
        + ellipse(11, 11, 8.5, 9.6, "url(#brass)", "#f9ebae", 1)
        + ellipse(11, 11, 5.8, 7.2, "none", "#ca9246", .8)
        + path('M7 11l8-4-3 8-1-4Z', CREAM, "#ce9242", .6)
        + path('M11 11l4-4', stroke="#ce9242", width=.6)
        + sparkle(6, 5, 2.2) + path('M20 10v4m-1 3-1 2', stroke="#f4c05c", width=1))
    svg("power", 32, 32,
        path('M16 1l11 7 3 15-14 8L2 23 3 8Z', "url(#brass)", INK, 1.4)
        + path('M16 4l9 5 2 12-11 7L5 21 6 9Z', "#fff3c5", "#d9a559", 1)
        + path('M8 21l2-9 7-6 6 9-3 9Z', "url(#teal)", INK, 1)
        + path('M17 6l-3 10 6 8-10-12Z', "#baf2d3", "#409c92", .7)
        + sparkle(24, 8, 3.5) + path('M7 24l4 2', stroke=CREAM, width=1.4))
    svg("item_block", 48, 48,
        rect(1, 1, 46, 46, "#a9693d", 7, INK, 1.7)
        + rect(3, 2, 42, 40, "url(#brass)", 6, "#f9e8a5", 1.5)
        + rect(7, 6, 34, 32, "#ebba65", 4, "#c99043", 1)
        + envelope(12, 14, 24, 17, CREAM, 1.2)
        + ellipse(24, 26, 3.6, 3.6, "#e68069", "#b86a52", .8)
        + path('M23 26l1 1 2-2', stroke=CREAM, width=1)
        + ''.join(ellipse(x, y, 1.6, 1.6, "#fff3c1", "#c28b43", .6)
                  for x in (7, 41) for y in (6, 38))
        + path('M8 44h30', stroke="#dca45d", width=1.2))
    svg("item_block_used", 48, 48,
        rect(1, 1, 46, 46, "#7f7461", 7, INK, 1.7)
        + rect(3, 2, 42, 40, "#baaa86", 6, "#d9c99f", 1.5)
        + rect(8, 8, 32, 28, "#8b856f", 4, "#77735f", 1)
        + path('M12 13h24v16H12Z', "#66756d", "#d0c29a", 1)
        + path('M13 14l11 8 11-8M14 28l8-6m4 0 8 6', stroke="#a1ab91", width=1)
        + ellipse(24, 32, 2, 2, "#e0cba0", "#756b53", .8)
        + ''.join(ellipse(x, y, 1.6, 1.6, "#dbcea9", "#81765b", .6)
                  for x in (7, 41) for y in (6, 38))
        + path('M8 44h30', stroke="#aa9b78", width=1.2))
    post = path('M9 114Q31 109 55 114l2 5H7Z', "#528d79", INK, 1.4)
    post += rect(27, 15, 8, 100, "#ad7951", 2, INK, 1.5)
    post += path('M30 19v90', stroke="#e4b976", width=2)
    post += ellipse(31, 11, 6, 7, "url(#brass)", INK, 1.4)
    post += path('M36 18Q45 14 60 18l-8 13 8 11q-12-4-24 0Z', "#eb8d73", INK, 1.3)
    post += envelope(41, 23, 12, 8, CREAM, .8)
    post += path('M6 72Q5 60 18 60h26q13 0 13 12v26H6Z', "url(#teal)", INK, 1.7)
    post += path('M6 73h51M12 92h39', stroke="#278885", width=1.2)
    post += rect(13, 70, 34, 5, "#244954", 2)
    post += rect(17, 82, 26, 11, "#f4d798", 2, INK, 1)
    post += envelope(24, 84, 12, 7, CREAM, .8)
    post += path('M10 97h43v5H10Z', "#367e76", INK, 1.3)
    post += path('M7 110l-3-6m6 5 2-9m41 12 5-6', stroke="#8abe87", width=2)
    svg("goal", 64, 120, post)


def terrain():
    dirt = rect(0, 0, 48, 48, "url(#dirt)")
    dirt += path('M0 21Q14 15 26 22T48 21M0 45q18-10 33-3t15 0', stroke="#d7a079", width=1)
    for x, y, size in ((7, 28, 4), (30, 22, 3), (35, 37, 5), (16, 43, 3), (41, 11, 2)):
        dirt += path(f'M{x} {y}l{size} -2 {size + 1} 3-{size} 3Z', "#805b4f", "none")
        dirt += path(f'M{x} {y}l{size} -2 {size + 1} 3', stroke="#d3a47c", width=.8)
    dirt += path('M5 17l4 5m14 10 3 2m14 12 3-1m-27-6 2-1', stroke="#d8aa82", width=1)
    svg("ground_fill", 48, 48, dirt)
    grass = path('M0 0h48v10l-4 3-4-2-5 5-6-4-6 3-6-3-5 4-7-4-5 2Z',
                 "#77b983", "none")
    grass += path('M0 1h48v5l-7 2-7-2-6 3-5-2-7 1-7-3-9 2Z', "#bbdf9d", "none")
    grass += path('M5 7l2 2 2-3m12 2 2 2 2-4m11 1 2 2 3-2', stroke="#589a70", width=1)
    grass += path('M3 1h9m8 1h4m10-1h8', stroke="#e0efb7", width=1)
    svg("ground", 48, 48, dirt + grass)
    stone = rect(0, 0, 48, 48, "#345763")
    stone += path('M0 4l14-4 14 4 20-3v18l-14 5-19-3L0 25Z', "#436775", "none")
    stone += path('M0 27l16-4 18 3 14-5v22l-16 5-20-4-12 3Z', "#3c606d", "none")
    stone += path('M0 24l14-3 20 4 14-5m-21-16-3 18M14 26l1 21', stroke="#284a58", width=2)
    stone += path('M2 5l12-3 7 2m9 25 12-4M19 43l9 2', stroke="#679398", width=1)
    stone += path('M31 10l6-5 4 7-5 6Z', "#77adab", "#2c6675", .8)
    stone += path('M37 5l-1 13-5-8Z', "#a2d2bc", "none")
    stone += path('M4 36l4-3 4 6-5 3Z', "#619b9e", "none")
    svg("underground_fill", 48, 48, stone)
    svg("underground", 48, 48, stone + path('M0 0h48v5l-5 1-6-2-8 3-6-2-9 2-8-2-6 1Z',
                                           "#84b6ad", "none")
        + path('M1 1h17m5 0h9m6 0h8', stroke="#b4d6bf", width=1.2))


def cloud(x, y, scale=1, shade="#eaf4dc", opacity=1):
    shape = path('M0 34Q-4 16 20 20Q24-4 47 5q17-3 28 13 23-10 32 10 22-2 23 11'
                 'Q107 52 83 44q-20 8-38 0Q10 52 0 34Z', shade, "none")
    shape += path('M9 39q22 8 42-1 18 7 34 0 19 4 35-1', stroke="#beded1", width=2, extra='opacity=".35"')
    return group(shape, f'translate({x} {y}) scale({scale})', f'opacity="{opacity}"')


def floating_island(x, y, scale, palette=0):
    colors = ("#9dbfad", "#779e99", "#d8ddba") if palette == 0 else ("#649e91", "#477e79", "#b7d598")
    body = path('M0 25l23 53 25 10 15 21 16-40 22-10 19-34Z', colors[1], "none")
    body += path('M23 28l25 60 15 21-4-67 21-13Z', colors[0], "none")
    body += path('M0 25Q18 6 45 15Q82-5 120 25l-9 13-20-6-18 8-23-5-22 4Z', colors[2], "none")
    body += path('M11 25q34-9 52 0 21-10 44-1', stroke=CREAM, width=2, extra='opacity=".45"')
    body += path('M22 45l6 25m64-25-6 12', stroke=colors[0], width=2)
    return group(body, f'translate({x} {y}) scale({scale})')


def tree(x, y, scale, pale=False):
    fill = "#8fb8a0" if pale else "#528f7e"
    body = path('M27 61l3-43h5l4 43Z', "#779681" if pale else "#577969", "none")
    body += path('M32 36l-9-13m11 4 10-10', stroke="#789780" if pale else "#557668", width=3)
    body += path('M6 24Q-2 6 18 4Q29-8 42 4q18-1 18 14 7 15-12 20l-16-5-14 6Z', fill, "none")
    body += path('M13 18Q22 10 29 15m10-5 9 5', stroke="#b5d2a8" if pale else "#83b393", width=3)
    return group(body, f'translate({x} {y}) scale({scale})')


def landscapes():
    far = ""
    for x, y, scale in ((70, 240, .8), (410, 305, 1.1), (950, 245, 1.4), (1290, 330, .8)):
        far += cloud(x, y, scale, "#f4f4db", .64)
    far += path('M0 610Q95 405 258 521Q411 347 593 509Q787 377 955 514Q1114 366 1286 501'
                'Q1491 397 1600 610V720H0Z', "#a5c7ad", "none")
    far += path('M0 658Q230 467 421 623Q651 447 834 615Q1080 461 1290 634Q1470 546 1600 658V720H0Z',
                "#8eb9a4", "none")
    for x, y, scale in ((45, 440, .65), (548, 340, .72), (1120, 367, .65)):
        far += floating_island(x, y, scale)
        far += tree(x + 20 * scale, y - 22 * scale, scale * .6, True)
    far += path('M87 543Q191 431 347 493T624 453', stroke="#d2dec0", width=2, extra='opacity=".45" stroke-dasharray="3 10"')
    svg("landscape_far", 1600, 720, far)
    near = path('M0 663Q98 536 219 632Q397 481 563 622Q760 530 960 668Q1100 556 1272 655'
                'Q1419 550 1600 663V720H0Z', "#73a894", "none")
    near += path('M0 709Q180 625 357 684Q493 626 642 710Q928 616 1096 704'
                 'Q1340 631 1600 709V720H0Z', "#61998a", "none")
    for x, y, scale in ((140, 565, 1.0), (487, 548, .8), (801, 609, 1.1), (1235, 592, 1.15), (1462, 616, .8)):
        near += tree(x, y, scale)
    near += floating_island(949, 414, 1.0, 1)
    near += path('M997 427v-45l16-15 21 15v43Z', "#e6ce9e", "#719083", 1.5)
    near += path('M992 383l23-21 26 20Z', "#b27e67", "none")
    near += rect(1010, 397, 12, 28, "#548a85", 4)
    near += envelope(1009, 383, 13, 9, "#f4deaf", .8)
    for x, y in ((170, 670), (540, 654), (690, 704), (1277, 690)):
        near += path(f'M{x} {y}q8-13 14 0m-9 2 4-9', stroke="#b8ce9d", width=2)
    svg("landscape_near", 1600, 720, near)


def crystal_cluster(x, y, scale, light=False):
    body = path('M4 80L0 30 18 10l20 63-11 22Z', "#4d8792" if light else "#376b80", "none")
    body += path('M18 10l-3 47 12 38 11-22Z', "#659a9c" if light else "#458794", "none")
    body += path('M22 80l8-67 23-13 14 34-18 63Z', "#71aaa9" if light else "#4b8d9c", "none")
    body += path('M53 0L43 42l6 55 18-63Z', "#387589", "none")
    body += path('M30 13l13 29L53 0Z', "#abcfba" if light else "#6caeb0", "none")
    body += path('M54 81l11-37 15-10 8 35-20 31Z', "#568e99", "none")
    body += path('M65 44l4 30 11-40Z', "#9cc8b7", "none")
    body += path('M32 17l-5 43M6 32l8-10', stroke="#bee0c0", width=2, extra='opacity=".5"')
    return group(body, f'translate({x} {y}) scale({scale})')


def caves():
    far = path('M0 480L51 420 139 523 183 366 258 314 370 516 481 495 582 362 691 524'
               ' 820 422 915 471 1003 278 1095 417 1171 379 1261 560 1341 503 1412 565'
               ' 1500 443 1600 480V720H0Z', "#29485d", "none")
    far += path('M0 710L109 565 239 660 414 577 553 667 710 581 830 683 969 547'
                ' 1091 657 1256 565 1409 679 1510 635 1600 710V720H0Z', "#315668", "none")
    for x, y, scale in ((90, 463, 1.3), (392, 530, .9), (811, 503, 1.3), (1258, 459, 1.5)):
        far += group(crystal_cluster(x, y, scale), extra='opacity=".58"')
    for index in range(30):
        x = (index * 137 + 41) % 1600
        y = 295 + (index * 83) % 350
        far += ellipse(x, y, 1.5, 1.5, "#8ec1b8", extra='opacity=".38"')
    svg("cave_far", 1600, 720, far)
    near = path('M0 682L118 594 193 656 269 639 364 692 485 588 620 678 741 613 832 704'
                ' 945 629 1118 705 1242 605 1380 672 1500 577 1600 682V720H0Z', "#356270", "none")
    for x, y, scale in ((14, 585, 1.1), (332, 558, 1.4), (728, 619, .9), (1117, 540, 1.7), (1450, 615, 1)):
        near += crystal_cluster(x, y, scale, True)
    for x, y in ((200, 645), (570, 669), (940, 625), (1350, 680)):
        near += path(f'M{x} {y + 20}v-17m9 20v-12', stroke="#7bb09e", width=2)
        near += ellipse(x, y, 9, 4, "#b3dbc0") + ellipse(x + 9, y + 8, 6, 3, "#91c8b6")
    svg("cave_near", 1600, 720, near)


def title_art():
    art = ellipse(317, 270, 232, 229, "#b9dcca", extra='opacity=".45"')
    art += ellipse(317, 267, 215, 214, "none", "#e6eccd", 1.5, 'stroke-dasharray="4 9" opacity=".8"')
    art += cloud(360, 109, 1.35, "#fff4d6") + cloud(18, 303, 1.3, "#fff4d6")
    art += cloud(435, 390, .9, "#fff4d6")
    art += group(floating_island(0, 0, 2.75, 1), 'translate(135 333) scale(1 .7)')
    art += path('M192 466l17 30 18-11m135-28 14 19 17-32', stroke="#385f65", width=3)
    art += path('M198 416q24 21 22 49m199-59q-18 21-17 43', stroke="#618d74", width=5)
    art += path('M212 439q-20-4-20 13 16 2 20-13m196-9q18-6 17 8-13 2-17-8',
                "#9fbe82", "none")
    art += tree(370, 273, 1.75)
    art += tree(135, 304, 1.25)
    # 遠い郵便局と風向計。
    art += path('M353 324v-99l41-29 43 29v100Z', "#f4dab0", INK, 2)
    art += path('M343 226l51-39 53 39-5 9-48-33-48 32Z', "#ca8468", INK, 2)
    art += path('M360 240h68M360 278h68M360 310h68', stroke="#e2b98d", width=1.5)
    art += rect(386, 277, 24, 48, "#588f88", 10, INK, 2)
    art += ellipse(394, 254, 12, 12, "#aed8c5", INK, 2)
    art += path('M394 243v22m-11-11h22', stroke=CREAM, width=2)
    art += path('M397 189v-39m-18 8h34l-7-5m7 5-7 5', stroke=INK, width=2)
    art += envelope(388, 142, 20, 13, CREAM, 1)
    # 大きな配達人は同じ手描き風パーツの跳躍ポーズから再構成する。
    art += group(courier("jump", 2), 'translate(116 64) rotate(-5 128 190) scale(4.0)')
    art += path('M413 382v-48', stroke=INK, width=8)
    art += path('M413 382v-48', stroke="#ce9d6c", width=5)
    art += path('M383 319q0-18 16-18h31q17 0 17 18v27h-64Z', "url(#teal)", INK, 2)
    art += rect(390, 315, 48, 6, INK, 2) + envelope(399, 329, 23, 14, CREAM, 1.2)
    art += path('M64 167q-27-68 58-82M441 145q114 6 105 87', stroke="#faf1cd", width=2,
                extra='stroke-dasharray="4 8"')
    plane = path('M0 22L75 0 40 49 32 29 0 22Z', CREAM, INK, 1.8)
    plane += path('M32 29L75 0 40 49l-2-18Z', "#badbd1", INK, 1.2)
    plane += path('M32 29l6 2 37-31', stroke="#6ba298", width=1)
    art += group(plane, 'translate(37 148) rotate(-12) scale(.85)')
    art += group(plane, 'translate(444 148) rotate(9) scale(.85)')
    for x, y, r in ((121, 102, 7), (498, 284, 8), (69, 285, 6), (417, 81, 6), (345, 482, 7)):
        art += sparkle(x, y, r, "#fff5d3")
    art += group(envelope(0, 0, 35, 24, CREAM, 1.3), 'translate(464 362) rotate(16)')
    svg("title_keyart", 600, 560, art)
    logo = ""
    logo += path('M203 76Q171 36 118 50l19 18-34 6 23 18-40 16q59 28 118 11',
                 "url(#teal)", INK, 3)
    logo += path('M497 76q32-40 85-26l-19 18 34 6-23 18 40 16q-59 28-118 11',
                 "url(#teal)", INK, 3)
    logo += path('M126 78l61 18m-64 13 65-3m385-28-61 18m64 13-65-3', stroke="#c2ebcd", width=3)
    logo += rect(205, 26, 292, 118, "url(#brass)", 15, INK, 3)
    logo += path('M211 32l139 78 140-78', "#fff0bd", INK, 2.5)
    logo += path('M211 137l112-67m168 67-112-67', stroke="#c99653", width=2)
    logo += ellipse(350, 116, 26, 26, "#e68770", INK, 2.2)
    logo += path('M337 119l27-14-11 26-5-11Z', CREAM, "#b66d59", 1)
    logo += path('M348 120l16-15', stroke="#b66d59", width=1)
    for x, y in ((71, 68), (626, 91), (174, 25), (526, 31)):
        logo += sparkle(x, y, 8, "#f6d687")
    svg("title_logo", 700, 180, logo)


def ui_icons():
    svg("ui_coin", 32, 32,
        ellipse(17, 17, 11, 12, "#b78342", INK, 1.3)
        + ellipse(14, 14, 10, 11, "url(#brass)", "#fff0b1", 1.3)
        + ellipse(14, 14, 7, 8, "none", "#ce974c", 1)
        + path('M9 14l11-5-5 12-2-6Z', CREAM, "#bd873b", .8)
        + sparkle(7, 5, 3))
    svg("ui_life", 32, 32,
        path('M16 28Q0 17 3 8q4-8 13-1 8-7 13 1 4 9-13 20Z', "url(#coral)", INK, 1.5)
        + path('M6 11q0-5 6-4', stroke="#ffe8bf", width=2)
        + envelope(10, 13, 12, 8, CREAM, .8))
    svg("ui_time", 32, 32,
        rect(13, 1, 6, 5, "url(#brass)", 1, INK, 1)
        + path('M25 7l3 3', stroke=INK, width=3)
        + ellipse(16, 18, 12, 12, "url(#brass)", INK, 1.5)
        + ellipse(16, 18, 9, 9, CREAM, "#c3924f", 1)
        + path('M16 11v7l5 3M16 26v-1M8 18h1M23 18h1', stroke=INK, width=1.5)
        + ellipse(16, 18, 1.8, 1.8, "#dd8867"))
    svg("ui_score", 32, 32,
        path('M9 22L5 31l10-4 10 4-3-10Z', "#d87e67", INK, 1.2)
        + ellipse(16, 13, 11, 11, "url(#teal)", INK, 1.5)
        + ellipse(16, 13, 8, 8, "url(#brass)", CREAM, 1)
        + path('M16 6l2 4 5 1-4 3 1 5-4-2-4 2 1-5-4-3 5-1Z', CREAM, "#c48e42", .7))
    svg("particle", 16, 16, sparkle(8, 8, 7, "#ffffff"))


def main():
    sheets()
    items()
    terrain()
    landscapes()
    caves()
    title_art()
    ui_icons()


if __name__ == "__main__":
    main()
