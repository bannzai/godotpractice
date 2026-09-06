"""独自の機体・背景・UI を同一の SVG へ冪等に再生成する。外部素材は使用しない。"""

from __future__ import annotations

import math
import random
from pathlib import Path

ASSETS = Path(__file__).resolve().parents[2] / "assets"
POSES = ("idle", "move", "attack", "hit", "death")
INK = "#06121e"
PALE = "#e8fff7"
MINT = "#6dffe0"


def path(points: str, fill: str, stroke: str = INK, width: float = 1.5) -> str:
    return f'<path d="{points}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linejoin="round"/>'


def circle(x: float, y: float, radius: float, fill: str, extra: str = "") -> str:
    return f'<circle cx="{x:g}" cy="{y:g}" r="{radius:g}" fill="{fill}" {extra}/>'


def rect(x: float, y: float, width: float, height: float, fill: str, extra: str = "") -> str:
    return f'<rect x="{x:g}" y="{y:g}" width="{width:g}" height="{height:g}" fill="{fill}" {extra}/>'


def group(content: str, transform: str = "", opacity: float = 1.0) -> str:
    return f'<g transform="{transform}" opacity="{opacity:.3f}">{content}</g>'


def definitions() -> str:
    colors = {
        "silver": ("#effffa", "#9bc7cd", "#376373"),
        "teal": ("#b4fff2", "#2dbda9", "#145164"),
        "red": ("#ffc0ae", "#e46070", "#753249"),
        "gold": ("#ffe2a5", "#db994b", "#705035"),
        "violet": ("#ecd5ff", "#a679d0", "#503d80"),
        "boss": ("#f1a696", "#a14f68", "#482944"),
    }
    gradients = []
    for name, stops in colors.items():
        gradients.append(f'<linearGradient id="{name}" x1="0" y1="0" x2=".7" y2="1">'
                         f'<stop stop-color="{stops[0]}"/><stop offset=".36" stop-color="{stops[1]}"/>'
                         f'<stop offset="1" stop-color="{stops[2]}"/></linearGradient>')
    for name, color in (("aura", MINT), ("fire", "#ffb776"), ("cloud", "#326c8f"),
                        ("violet_cloud", "#5a457e"), ("planet", "#386b81")):
        gradients.append(f'<radialGradient id="{name}"><stop stop-color="{color}" stop-opacity=".65"/>'
                         f'<stop offset=".5" stop-color="{color}" stop-opacity=".19"/>'
                         f'<stop offset="1" stop-color="{color}" stop-opacity="0"/></radialGradient>')
    gradients.append('<linearGradient id="exhaust" x1="0" y1="0" x2="0" y2="1">'
                     '<stop stop-color="#d8ffff"/><stop offset=".3" stop-color="#60fce0"/>'
                     '<stop offset="1" stop-color="#29d8ea" stop-opacity="0"/></linearGradient>')
    return "<defs>" + "".join(gradients) + "</defs>"


def svg(width: int, height: int, content: str) -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
            f'viewBox="0 0 {width} {height}">\n{definitions()}\n{content}\n</svg>\n')


def write(relative: str, width: int, height: int, content: str) -> None:
    destination = ASSETS / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(svg(width, height, content), encoding="utf-8")


def part(content: str, x: float, y: float, pose: str, frame: int, side: int = 0) -> str:
    """状態ごとに装甲を開閉し、死亡時は部位が離れて消える。"""
    opacity = 1.0
    angle = 0.0
    if pose == "move":
        x += side * (0, 1.5, 3, 1.5)[frame]
        angle = side * (0, 2, 4, 2)[frame]
    elif pose == "attack":
        x += side * (0, 2, 4, 2)[frame]
        y += (0, -2, 2, 0)[frame]
    elif pose == "hit":
        x += (0, -3, 2, 0)[frame]
        angle = side * (0, 5, -3, 0)[frame]
    elif pose == "death":
        x += side * frame * 4
        y += (1 if side else -1) * frame * 2
        angle = side * frame * 9
        opacity = (1, .86, .53, .12)[frame]
    return group(content, f"translate({x:g} {y:g}) rotate({angle:g})", opacity)


def engine(x: float, y: float, pose: str, frame: int, width: float = 5, down: bool = True) -> str:
    if pose == "death":
        return ""
    length = (10, 17, 13, 20)[frame] + (6 if pose == "move" else 0)
    jet = path(f"M{-width} 0L0 {length}L{width} 0Z", "url(#exhaust)", "none")
    jet += path("M-2 0L0 10L2 0Z", PALE, "none")
    return group(jet, f"translate({x:g} {y:g}) rotate({0 if down else 180})")


def burst(x: float, y: float, pose: str, frame: int, color: str) -> str:
    if pose != "attack" or frame not in (1, 2):
        return ""
    rays = path("M0-15L3-4L9 0L3 4L0 15L-3 4L-9 0L-3-4Z", color, "none")
    return group(circle(0, 0, 15, "url(#fire)") + rays + circle(0, 0, 3, PALE),
                 f"translate({x:g} {y:g}) scale({1 if frame == 1 else .65})")


def player(pose: str, frame: int) -> str:
    pieces = engine(-14, 33, pose, frame) + engine(14, 33, pose, frame)
    for side in (-1, 1):
        wing = path("M8-7L19-5L40 20L44 34L19 28L9 17Z", "url(#silver)")
        wing += path("M17 7L35 25L24 23L16 16Z", "url(#teal)", "#69d9d1", .7)
        wing += path("M34 16L38 14L41 29L36 29Z", "#17394a", "#b9f7ec", .8)
        wing += path("M18 28L20 40L9 36L10 27Z", "url(#teal)")
        wing += path("M23 21L28 22M29 27L34 28", "none", PALE, .8)
        pieces += part(group(wing, f"scale({side} 1)"), 0, 0, pose, frame, side)
        pieces += burst(side * 37, 10, pose, frame, MINT)
    body = path("M0-49L8-26L13 15L9 35L0 41L-9 35L-13 15L-8-26Z", "url(#silver)")
    body += path("M0-43L3-20L-3-20Z", PALE, "none")
    body += path("M0-23L6-10L5 8L0 16L-5 8L-6-10Z", "#102e44", "#8affdf", 1.2)
    body += path("M0-18L3-8L2 6L0 9L-2 6L-3-8Z", "#6ee8d5", "none")
    body += path("M-9 20L-4 24V33M9 20L4 24V33", "none", "#306572", 1)
    body += circle(0, 19, 3.8, MINT) + circle(0, 19, 1.8, PALE)
    body += path("M-3 36L0 39L3 36", "none", PALE, 1)
    pieces += part(body, 0, 0, pose, frame)
    return pieces


def scout(pose: str, frame: int) -> str:
    pieces = engine(-10, -22, pose, frame, 4, False) + engine(10, -22, pose, frame, 4, False)
    for side in (-1, 1):
        wing = path("M8-25L26-35L42-19L31 9L14 38L13 5Z", "url(#red)")
        wing += path("M17-21L28-25L32-18L24 3L20 4Z", "#632c43", "#ffb3a4", .9)
        wing += path("M25 11L17 31L18 12Z", "#ffd29d", "none")
        wing += path("M27-17L30-15M25-12L28-10", "none", "#ffcca8", 1.6)
        pieces += part(group(wing, f"scale({side} 1)"), 0, 0, pose, frame, side)
    body = path("M-9-28L9-28L16-8L8 28L0 40L-8 28L-16-8Z", "url(#red)")
    body += path("M-7-17L7-17L10-8L0 2L-10-8Z", "#2c233d", "#ff9b92", 1)
    body += path("M-6-8H6L0-2Z", "#ffe9a8", "none")
    body += path("M-4 7L0 24L4 7", "none", "#57283c", 3)
    body += path("M-2 25V37M2 25V37", "none", "#ffbb8f", 1.2)
    pieces += part(body, 0, 0, pose, frame)
    pieces += burst(0, 40, pose, frame, "#ffb691")
    return pieces


def aim(pose: str, frame: int) -> str:
    pieces = engine(-29, -28, pose, frame, 5, False) + engine(29, -28, pose, frame, 5, False)
    pieces += part(path("M-33-12L33-12L33 13L-33 13Z", "#313344", "#cea770", 1),
                   0, 0, pose, frame)
    for side in (-1, 1):
        pod = path("M19-32L33-32L40-20L39 29L27 39L18 23Z", "url(#gold)")
        pod += path("M24-27L30-27L34-20V-3L24-3Z", "#423b3c", "#ebc68e", .7)
        pod += path("M24 4H35V23L30 29L24 21Z", "#66503f", "#f4cf96", .9)
        pod += path("M27 7V21M31 7V21M22-17H31M22-12H31", "none", "#edc187", 1.3)
        pod += circle(29, -22, 2, "#ffead0")
        pieces += part(group(pod, f"scale({side} 1)"), 0, 0, pose, frame, side)
    turret = path("M-14-19L0-29L14-19L19 4L12 19L-12 19L-19 4Z", "url(#gold)")
    turret += circle(0, -4, 12, "#373344", 'stroke="#f5c389" stroke-width="1.4"')
    turret += circle(0, -4, 7, "#ffcc88") + circle(0, -4, 3.5, PALE)
    recoil = (0, -6, -2, 0)[frame] if pose == "attack" else 0
    turret += group(path("M-6 8H6L5 39H-5Z", "#333341", "#ffcf94", 1.2)
                    + rect(-3, 18, 6, 16, "#d8a260")
                    + rect(-7, 33, 14, 5, "#f6cc94"), f"translate(0 {recoil})")
    pieces += part(turret, 0, 0, pose, frame)
    return pieces + burst(0, 43 + recoil, pose, frame, "#ffd99b")


def fan(pose: str, frame: int) -> str:
    pieces = engine(-19, -28, pose, frame, 5, False) + engine(19, -28, pose, frame, 5, False)
    for side in (-1, 1):
        shell = path("M7-33L28-28L43-10L42 17L24 33L10 25Z", "url(#violet)")
        shell += path("M21-23L34-9L34 13L25 21L20 14L26 8V-4L17-13Z", "#43315f", "#c5a6ee", 1)
        shell += path("M32-10L36-6M31-5L36-1M31 1L36 5", "none", "#f5d3ff", 1.2)
        shell += circle(30, 19, 3, "#f3c6ff")
        pieces += part(group(shell, f"scale({side} 1)"), 0, 0, pose, frame, side)
    core = path("M0-36L17-22L17 20L0 34L-17 20L-17-22Z", "url(#violet)")
    core += path("M0-24L11-13V7L0 18L-11 7V-13Z", "#302844", "#dab4ff", 1.5)
    core += circle(0, -3, 9 + (0, 1, 2, 1)[frame], "#a477cd")
    core += path("M0-12L6-5V1L0 7L-6 1V-5Z", "#f7d8ff", "none")
    for x in (-13, 0, 13):
        core += path(f"M{x-4} 22H{x+4}V35L{x} 39L{x-4} 35Z", "#41344e", "#cea8ef", 1)
        core += rect(x - 2, 29, 4, 7, "#efc3ff")
        pieces += burst(x, 42, pose, frame, "#e3b2ff")
    return pieces + part(core, 0, 0, pose, frame)


def boss(pose: str, frame: int) -> str:
    pieces = ""
    for side in (-1, 1):
        pieces += engine(side * 67, -44, pose, frame, 10, False)
        wing = path("M23-31L48-45L78-43L102-25L110 10L98 43L76 40L63 16L35 24Z", "url(#boss)", INK, 2)
        wing += path("M45-31L69-34L87-22L95 2L84 9L63-4L43-4Z", "#7e3d57", "#d38c87", 1.3)
        wing += path("M50-25L67-28L79-20M48-18L64-21L81-12M49-10L63-13L81-5", "none", "#e6a797", 2)
        wing += path("M95-10L102 8L94 31L86 29L80 15Z", "#392a40", "#d58d84", 1.2)
        wing += path("M29-20L39-20L45 26L34 38L28 21Z", "url(#gold)")
        for x, y in ((48, 20), (89, 25)):
            wing += path(f"M{x-7} {y-10}H{x+7}V{y+15}L{x+4} {y+23}H{x-4}L{x-7} {y+15}Z", "#31263c", "#cb8785", 1)
            wing += rect(x - 2.5, y + 4, 5, 19, "#ffd1a4")
            pieces += burst(side * x, y + 27, pose, frame, "#ffc597")
        wing += circle(80, -28, 3, "#ffc299")
        pieces += part(group(wing, f"scale({side} 1)"), 0, 0, pose, frame, side)
    core = path("M0-50L25-37L33-7L29 29L15 51L0 61L-15 51L-29 29L-33-7L-25-37Z", "url(#boss)", INK, 2)
    core += path("M0-40L17-28L23-4L16 6L-16 6L-23-4L-17-28Z", "#532d45", "#eeae97", 1)
    core += path("M-13-27L0-34L13-27M-17-17L0-23L17-17", "none", "#cc827f", 1.4)
    core += path("M0-14L18-4L22 16L11 35L0 40L-11 35L-22 16L-18-4Z", "#31253c", "#ffc29e", 2)
    core += circle(0, 12, 24, "url(#fire)")
    core += path("M0-8L12 0L15 15L6 29L0 32L-6 29L-15 15L-12 0Z", "#d68569", "#ffe0ad", 1.5)
    pulse = (1, 1.15, 1.3, 1.15)[frame] if pose == "attack" else (1, 1.04, 1.08, 1.04)[frame]
    core += group(path("M0-3L7 3L9 14L0 26L-9 14L-7 3Z", "#ffe9bc", "none"), f"translate(0 10) scale({pulse}) translate(0 -10)")
    core += path("M-12 40L0 49L12 40M-6 49L0 54L6 49", "none", "#f0b29e", 2)
    return pieces + part(core, 0, 0, pose, frame) + burst(0, 55, pose, frame, "#ffe4a9")


DRAWERS = {"player": player, "scout": scout, "aim": aim, "fan": fan, "boss": boss}


def ship(kind: str, pose: str, frame: int) -> str:
    content = DRAWERS[kind](pose, frame)
    if kind == "boss" and pose == "death":
        content = group(content, f"scale({1-frame*.025:g})")
    if pose == "hit":
        radius = 50 if kind != "boss" else 70
        content += circle(0, 0, radius, "url(#fire)", f'opacity="{(0.5, .95, .5, .12)[frame]}"')
        content += path("M-13-29L-5-6L-13 2L7 26M19-10L5 1L17 17", "none", PALE,
                        (2, 3, 2, .5)[frame])
    if pose == "death":
        radius = (9, 22, 36, 45)[frame]
        content += circle(0, 0, radius, "url(#fire)")
        content += circle(0, 0, radius, "none", f'stroke="#ffd5a1" stroke-width="{3-frame*.7}" opacity="{1-frame*.26}"')
        for index in range(8):
            angle = index * math.tau / 8
            x, y = math.cos(angle) * radius, math.sin(angle) * radius
            content += group(path("M-2-4L3 0L0 5Z", "#ffe4b8", "none"),
                             f"translate({x:g} {y:g}) rotate({index*45+frame*25})", 1-frame*.27)
    return content


def create_ships() -> None:
    icons = {"player": "player", "scout": "enemy_scout", "aim": "enemy_fighter",
             "fan": "enemy_carrier", "boss": "boss"}
    for kind in DRAWERS:
        width, height = (256, 160) if kind == "boss" else (128, 128)
        content = []
        for row, pose in enumerate(POSES):
            for frame in range(4):
                content.append(group(ship(kind, pose, frame),
                                     f"translate({frame*width+width//2} {row*height+height//2})"))
        write(f"sprites/{kind}_sheet.svg", width*4, height*5, "".join(content))
        write(f"sprites/{icons[kind]}.svg", width, height,
              group(ship(kind, "idle", 0), f"translate({width//2} {height//2})"))


def create_items() -> None:
    symbols = {
        "power": path("M-2-16L-12 2H-3L-7 16L12-5H3L8-16Z", PALE, "none"),
        "bomb": circle(0, 2, 11, "#ffe7b0", 'stroke="#935741" stroke-width="2"')
                + path("M-2-7L1-14L8-12M-6 2H6M0-4V8", "none", "#8a493e", 2),
        "score": path("M0-15L5-5L16-3L8 5L10 16L0 11L-10 16L-8 5L-16-3L-5-5Z", "#fff0c4", "#a56d37", 1),
    }
    for name, symbol in symbols.items():
        color = {"power": MINT, "bomb": "#ffb876", "score": "#ffd978"}[name]
        medal = circle(0, 0, 28, "url(#aura)" if name == "power" else "url(#fire)")
        medal += path("M-12-22H12L24-10V10L12 22H-12L-24 10V-10Z", "#0b2334", color, 1.8)
        medal += path("M-10-18H10M-19-8V8M19-8V8M-10 18H10", "none", color, .8)
        write(f"sprites/item_{name}.svg", 64, 64, group(medal + symbol, "translate(32 32)"))
        if name != "score":
            write(f"ui/{name}.svg", 48, 48, group(symbol, "translate(24 24)"))
    bullet = path("M8 0L13 10L11 31L8 46L5 31L3 10Z", "#42e4c3", "none")
    bullet += path("M8 2L10 12L9 31H7L6 12Z", PALE, "none")
    write("sprites/bullet_player.svg", 16, 48, bullet)
    bullet = circle(16, 16, 15, "url(#fire)") + circle(16, 16, 8.5, "#ffd493", 'stroke="#e95068" stroke-width="3"')
    bullet += circle(16, 15, 4.5, "#fffbdb")
    write("sprites/bullet_enemy.svg", 32, 32, bullet)


def stars(seed: int, count: int, near: bool = False) -> str:
    rng = random.Random(seed)
    content = []
    for _ in range(count):
        x, y = rng.randint(3, 717), rng.randint(3, 957)
        r = rng.choice((.6, .8, 1.1, 1.5)) * (1.2 if near else 1)
        color = rng.choice(("#94bfcf", "#d9e7eb", "#8ec8cb"))
        content.append(circle(x, y, r, color, f'opacity="{rng.uniform(.25,.8):.2f}"'))
        if near:
            content.append(path(f"M{x} {y-3}V{y+4}", "none", color, .5))
    return "".join(content)


def create_backgrounds() -> None:
    space = rect(0, 0, 720, 960, "#081625")
    space += '<ellipse cx="240" cy="420" rx="530" ry="550" fill="url(#cloud)" opacity=".22"/>'
    write("backgrounds/space.svg", 720, 960, space)
    nebula = '<ellipse cx="610" cy="290" rx="470" ry="410" fill="url(#cloud)"/>'
    nebula += '<ellipse cx="110" cy="650" rx="370" ry="320" fill="url(#violet_cloud)"/>'
    nebula += '<ellipse cx="560" cy="730" rx="370" ry="270" fill="url(#cloud)" opacity=".4"/>'
    for i in range(9):
        nebula += path(f"M-100 {750+i*10}Q220 {430+i*6} 770 {290+i*8}", "none", "#4c7a88", 2+i*3)
    write("backgrounds/nebula.svg", 720, 960, group(nebula, opacity=.38))
    write("backgrounds/stars_far.svg", 720, 960, stars(716, 115))
    write("backgrounds/stars_near.svg", 720, 960, stars(1721, 38, True))
    orbit = ""
    for radius in (230, 270, 275, 350):
        orbit += circle(570, 450, radius, "none", 'stroke="#537e8f" stroke-width="1" opacity=".28"')
    orbit += circle(570, 450, 290, "none", 'stroke="#85a5b0" stroke-width="8" stroke-dasharray="1 41" opacity=".13"')
    orbit += path("M290 450H320M570 160V190M570 710V740M145 835L235 745M155 835H145V825", "none", "#8cadb7", 1)
    write("backgrounds/orbital.svg", 720, 960, orbit)
    keyart = space + nebula + stars(1921, 130)
    keyart += circle(640, 320, 300, "#152e40", 'stroke="#5997a3" stroke-width="2"')
    keyart += circle(640, 320, 312, "none", 'stroke="#477887" stroke-width="7" opacity=".2"')
    keyart += '<ellipse cx="660" cy="550" rx="420" ry="105" fill="none" stroke="#8dafb3" stroke-width="2" transform="rotate(-31 660 550)" opacity=".55"/>'
    keyart += '<ellipse cx="660" cy="550" rx="450" ry="117" fill="none" stroke="#62929c" stroke-width="8" transform="rotate(-31 660 550)" opacity=".16"/>'
    keyart += circle(610, 245, 185, "url(#planet)")
    keyart += group(ship("boss", "idle", 1), "translate(435 178) rotate(-16) scale(1.05)", .58)
    keyart += group(ship("scout", "move", 1), "translate(180 329) rotate(-24) scale(.6)", .8)
    keyart += group(ship("fan", "idle", 0), "translate(574 372) rotate(-20) scale(.65)", .85)
    trails = path("M-18 31L-15 170L-11 31M11 31L15 210L18 31", "url(#exhaust)", "none")
    keyart += group(trails + ship("player", "move", 2), "translate(355 584) rotate(-22) scale(3.1)")
    keyart += path("M125 744L164 659M541 418L563 373M160 248L184 195", "none", "#81d3c9", 1)
    write("backgrounds/title_keyart.svg", 720, 960, keyart)


def create_ui() -> None:
    panel = path("M15 1H383V223L368 239H1V17Z", "#102737", "#446270", 1)
    panel += path("M1 48V17L15 1H90M294 239H368L383 223V192", "none", "#85bea9", 2)
    panel += path("M18 8H112M270 231H364", "none", "#243e4d", 1)
    write("ui/panel.svg", 384, 240, panel)
    hud = rect(0, 0, 320, 720, "#102333")
    hud += path("M319 0V720M308 0V720", "none", "#3e6874", 1)
    hud += path("M0 132H291L308 149M0 657H285L308 634", "none", "#294553", 1)
    for y in range(170, 612, 15):
        hud += path(f"M312 {y}H317", "none", "#699394", .7)
    hud += path("M4 0H125L146 18H307M3 719H200L215 705H307", "none", "#40656e", 1)
    write("ui/hud_frame.svg", 320, 720, hud)
    emblem = circle(80, 56, 37, "none", 'stroke="#7ee2ca" stroke-width="1.4"')
    emblem += '<ellipse cx="80" cy="56" rx="72" ry="21" fill="none" stroke="#7ee2ca" stroke-width="1.5" transform="rotate(-23 80 56)"/>'
    emblem += path("M80 11L88 41L113 67L89 62L80 91L71 62L47 67L72 41Z", "#d8f7e8", "#173a46", 2)
    emblem += path("M80 29L83 48L80 64L77 48Z", "#4cbfa6", "none")
    emblem += circle(136, 31, 3, "#f9c48b")
    write("ui/emblem.svg", 160, 112, emblem)
    logo = group(emblem, "translate(40 0)")
    logo += path("M5 56H40M200 56H235M10 63H35M205 49H230", "none", "#7ba99c", 1)
    write("ui/title_logo.svg", 240, 112, logo)
    life = path("M24 5L30 24L42 37L29 33L24 40L19 33L6 37L18 24Z", "#b3f4df", "#224652", 1.5)
    life += path("M24 16V28", "none", "#328e84", 2)
    write("ui/life.svg", 48, 48, life)


def main() -> None:
    create_ships()
    create_items()
    create_backgrounds()
    create_ui()
    print("shooter 独自 SVG の再生成完了")


if __name__ == "__main__":
    main()
