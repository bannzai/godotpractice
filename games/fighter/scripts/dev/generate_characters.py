"""独自の闘士のセル画を SVG と SpriteFrames に再生成する。出力は決定的。"""

from __future__ import annotations

import json
import math
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets"
CELL = (320, 256)
ORIGIN = (112, 238)
COLUMNS = 12
FRAMES = 8
ANIMATIONS = [
    "idle", "walk", "attack", "hurt", "ko", "guard", "jump", "crouch",
    "special", "crouch_guard",
] + [f"{stance}_{kind}" for stance in ("standing", "crouching", "air")
     for kind in ("lp", "hp", "lk", "hk")]
INK = "#111f31"
PALETTES = {
    "teal": {"main": "#329b9b", "light": "#8eeee1", "shade": "#1a555f",
             "dark": "#183842", "skin": "#eac2a3", "skin_light": "#ffddba",
             "skin_shade": "#b88273", "white": "#e6efe3", "edge": "#a7fff0"},
    "amber": {"main": "#df8642", "light": "#ffd482", "shade": "#9d4b36",
              "dark": "#223349", "skin": "#b7795e", "skin_light": "#dfad7b",
              "skin_shade": "#754f4d", "white": "#d1c6a9", "edge": "#ffe1a0"},
}


def point(value: tuple[float, float]) -> str:
    return f"{value[0]:.2f},{value[1]:.2f}"


def add(a: tuple[float, float], b: tuple[float, float]) -> tuple[float, float]:
    return a[0] + b[0], a[1] + b[1]


def mix(a: tuple[float, float], b: tuple[float, float], t: float) -> tuple[float, float]:
    return a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t


def path(d: str, fill: str, stroke: str = INK, width: float = 1.8, extra: str = "") -> str:
    return (f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" '
            f'stroke-linejoin="round" stroke-linecap="round" {extra}/>')


def polygon(points: list[tuple[float, float]], fill: str,
            stroke: str = INK, width: float = 1.8) -> str:
    return path("M" + " L".join(point(p) for p in points) + "Z", fill, stroke, width)


def ellipse(at: tuple[float, float], rx: float, ry: float, fill: str,
            stroke: str = INK, width: float = 1.8) -> str:
    return (f'<ellipse cx="{at[0]:.2f}" cy="{at[1]:.2f}" rx="{rx}" ry="{ry}" '
            f'fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>')


def group(at: tuple[float, float], content: str, rotation: float = 0) -> str:
    return f'<g transform="translate({point(at)}) rotate({rotation:.2f})">{content}</g>'


def definitions(name: str) -> str:
    p = PALETTES[name]
    gradients = ""
    for material, colors in {
        "armor": (p["light"], p["main"], p["shade"]),
        "cloth": ("#49636d" if name == "teal" else "#526074", p["dark"], INK),
        "skin": (p["skin_light"], p["skin"], p["skin_shade"]),
        "ivory": ("#ffffe9", p["white"], "#829c9a"),
    }.items():
        gradients += (f'<linearGradient id="{material}" x1="0" y1="0" x2="1" y2=".7">'
                      f'<stop stop-color="{colors[0]}"/><stop offset=".4" stop-color="{colors[1]}"/>'
                      f'<stop offset="1" stop-color="{colors[2]}"/></linearGradient>')
    return "<defs>" + gradients + "</defs>"


def segment(start: tuple[float, float], end: tuple[float, float],
            start_width: float, end_width: float, material: str,
            highlight: str, seam: bool = True) -> str:
    length = math.dist(start, end)
    rotation = math.degrees(math.atan2(end[1] - start[1], end[0] - start[0])) - 90
    body = path(f"M{-start_width},0 Q{-start_width - 2},{length * .3:.2f} "
                f"{-end_width},{length:.2f} Q0,{length + 3:.2f} {end_width},{length:.2f} "
                f"Q{start_width + 3},{length * .45:.2f} {start_width},0 "
                f"Q0,-5 {-start_width},0Z", f"url(#{material})")
    body += path(f"M{-start_width + 3},2 Q{-start_width + 1},{length * .35:.2f} "
                 f"{-end_width + 2},{length - 4:.2f}", "none", highlight, 2.2)
    if seam:
        body += path(f"M{start_width * .5:.2f},4 L{end_width * .45:.2f},{length - 3:.2f}",
                     "none", INK, 1.1)
    return group(start, body, rotation)


def boot(at: tuple[float, float], name: str, angle: float = 0) -> str:
    p = PALETTES[name]
    broad = 1.16 if name == "amber" else 1.0
    body = path("M-12,-15 L8,-16 L11,-7 Q19,-6 22,0 L21,7 "
                "L-14,7 Q-17,-1 -12,-15Z", "url(#cloth)")
    body += path("M-13,2 Q3,0 20,2 L20,7 L-14,7Z", "url(#armor)", INK, 1.2)
    body += path("M-10,-13 L6,-13 L9,-4 L-12,-3Z", "url(#ivory)" if name == "teal"
                 else "url(#armor)", INK, 1.3)
    body += path("M-7,-10 L4,-10 M-6,-6 L5,-6", "none", p["shade"], 1.2)
    body += path("M11,-2 L18,0", "none", p["edge"], 1.6)
    return group(at, f'<g transform="scale({broad},1)">{body}</g>', angle)


def glove(at: tuple[float, float], elbow: tuple[float, float], name: str) -> str:
    p = PALETTES[name]
    rotation = math.degrees(math.atan2(at[1] - elbow[1], at[0] - elbow[0])) + 90
    if name == "teal":
        body = path("M-9,6 L-10,-6 L-6,-14 L5,-15 L10,-10 L11,1 L7,8Z",
                    "url(#armor)")
        body += path("M-6,-11 L5,-12 L8,-8 L-7,-7Z", "url(#ivory)", INK, 1.1)
        body += path("M-7,1 L7,0 M-4,-13 L-3,-8 M1,-13 L2,-8", "none", p["shade"], 1.1)
        body += path("M-9,3 L-12,-4 L-9,-8 L-4,-2 L-3,4Z", "url(#skin)", INK, 1.2)
    else:
        body = path("M-17,13 L-21,-4 L-16,-20 L-9,-24 L10,-23 L18,-14 "
                    "L20,6 L13,17 L-9,19Z", "url(#armor)", INK, 2.3)
        body += path("M-16,-17 L-10,-21 L8,-20 L13,-13 L-15,-10Z", "url(#ivory)", INK, 1.2)
        body += path("M-17,-7 L13,-10 L16,4 L10,10 L-12,11Z", p["dark"], INK, 1.2)
        body += path("M-10,-3 L10,-5 L10,1 L-8,3Z", p["light"], "none")
        body += path("M-11,14 L10,13 M-6,-20 L-5,-13 M2,-21 L3,-14", "none", p["shade"], 2)
        body += ellipse((-12,6), 2, 2, p["edge"], "none")
        body += ellipse((10,4), 2, 2, p["edge"], "none")
    return group(at, body, rotation)


def head(at: tuple[float, float], name: str, tilt: float = 0) -> str:
    p = PALETTES[name]
    if name == "teal":
        body = path("M-11,7 L-13,-11 L-5,-20 L11,-17 L15,-7 L18,-1 "
                    "L13,2 L13,12 L3,19 L-7,15Z", "url(#skin)")
        body += path("M-13,-1 L-16,-14 L-9,-24 L-15,-27 L1,-26 L9,-32 "
                     "L11,-26 L20,-25 L15,-19 L20,-15 L11,-12 L4,-16 "
                     "L-1,-8 L-4,-13 L-8,1Z", "url(#cloth)", INK, 1.7)
        body += path("M-9,-21 L2,-22 L10,-27 M-9,-15 L1,-17", "none", "#65838b", 1.3)
        body += ellipse((-8,3), 4, 6, p["skin"], p["skin_shade"], 1.1)
        body += path("M4,-4 L12,-5 M6,-1 L12,-2", "none", INK, 1.3)
        body += path("M9,-2 L11,-2", "none", "#b2fff1", 1.5)
        body += path("M7,10 L12,9 M0,14 L5,15", "none", p["skin_shade"], 1)
        body += path("M-4,5 L-1,12 L2,13", "none", "#ffdec0", 1.3)
        body += ellipse((-10,9), 1.6, 1.6, p["edge"], INK, .6)
    else:
        body = path("M-16,4 L-18,-16 L-9,-25 L12,-23 L19,-12 L20,-3 "
                    "L25,2 L20,5 L18,20 L5,27 L-11,21Z", "url(#skin)", INK, 2.2)
        body += path("M-17,-3 L-22,-10 L-18,-23 L-8,-29 L8,-27 L17,-20 "
                     "L16,-12 L6,-17 L-6,-15 L-10,0Z", "url(#cloth)")
        body += path("M-12,-24 L-12,-34 L-5,-31 L-3,-38 L5,-34 L8,-37 "
                     "L13,-27 L14,-20 L3,-22Z", "url(#armor)", INK, 1.6)
        body += path("M-17,-12 L-10,-18 M-17,-7 L-11,-12", "none", "#68747c", 1.1)
        body += path("M-8,8 L0,16 L15,13 L19,7 L18,22 L5,28 L-9,20Z",
                     "url(#cloth)", INK, 1.3)
        body += path("M3,19 L13,17 M-4,16 L0,23", "none", "#68747c", 1.2)
        body += path("M2,-6 L16,-8 L17,-4 L3,-3Z", p["shade"], INK, 1)
        body += path("M8,-2 L15,-3", "none", INK, 1.5)
        body += path("M12,-2 L14,-2", "none", p["edge"], 1.5)
        body += ellipse((-11,4), 5, 6, p["skin"], p["skin_shade"], 1.3)
        body += path("M1,3 L5,8 L15,6", "none", p["skin_light"], 1.5)
    return group(at, body, tilt)


def torso(hip: tuple[float, float], chest: tuple[float, float], name: str) -> str:
    p = PALETTES[name]
    height = math.dist(hip, chest)
    rotation = math.degrees(math.atan2(hip[1] - chest[1], hip[0] - chest[0])) - 90
    if name == "teal":
        body = path(f"M-19,-5 Q0,-14 21,-5 L22,13 L12,{height:.2f} "
                    f"L-13,{height:.2f} L-20,17Z", "url(#cloth)")
        body += path(f"M-19,-5 L-3,-8 L-8,17 L-4,{height - 4:.2f} "
                     f"L-17,{height + 9:.2f} L-22,{height - 2:.2f} L-18,20Z", "url(#armor)")
        body += path(f"M8,-9 L21,-5 L18,18 L9,{height + 2:.2f} "
                     f"L0,{height - 3:.2f} L3,18Z", "url(#ivory)", INK, 1.6)
        body += path("M-13,0 L-6,2 L-10,16 M13,-1 L8,17", "none", p["edge"], 1.5)
        body += path(f"M-17,{height - 7:.2f} Q0,{height - 3:.2f} 14,{height - 9:.2f} "
                     f"L14,{height + 1:.2f} L-15,{height + 4:.2f}Z", "url(#ivory)")
        body += polygon([(-2,height-5),(6,height-6),(8,height+3),(0,height+5)], p["main"], INK, 1)
        body += path(f"M-11,{height + 1:.2f} Q-20,{height + 21:.2f} -39,{height + 26:.2f} "
                     f"L-28,{height + 11:.2f} L-20,{height - 1:.2f}Z", "url(#armor)", INK, 1.3)
    else:
        body = path(f"M-29,-9 Q-4,-20 30,-9 L33,17 L22,{height + 4:.2f} "
                    f"L-22,{height + 3:.2f} L-32,17Z", "url(#cloth)", INK, 2.4)
        body += path("M-25,-9 L-9,-11 L-2,5 L18,-9 L30,-6 L28,23 "
                     "L4,32 L-23,21Z", "url(#armor)", INK, 2)
        body += path("M-20,-6 L-11,-7 L-3,9 L20,-3 L24,4 L0,20 L-20,11Z",
                     "url(#ivory)", INK, 1.4)
        body += path("M-21,25 L1,35 L22,28 M-23,35 L-2,42 L20,37", "none", "#627282", 2)
        body += ellipse((2,16), 7, 7, p["shade"], INK, 1.5)
        body += polygon([(2,10),(6,16),(2,22),(-2,16)], p["edge"], "none")
        body += path(f"M-23,{height - 7:.2f} L22,{height - 6:.2f} "
                     f"L24,{height + 6:.2f} L-24,{height + 6:.2f}Z", "url(#armor)")
        body += polygon([(-7,height-6),(8,height-6),(10,height+5),(-8,height+6)],
                        "url(#ivory)", INK, 1.4)
        body += path(f"M-20,{height + 7:.2f} L-21,{height + 20:.2f} L-7,{height + 24:.2f} "
                     f"L-3,{height + 7:.2f} M6,{height + 8:.2f} L10,{height + 25:.2f} "
                     f"L24,{height + 19:.2f} L22,{height + 7:.2f}", "url(#cloth)")
    return group(chest, body, rotation)


def shoulder(at: tuple[float, float], name: str) -> str:
    if name == "teal":
        body = path("M-10,-11 Q0,-19 13,-11 L17,2 L4,9 L-12,4Z", "url(#ivory)")
        body += path("M-8,-10 Q0,-14 10,-9 L13,-3 L-8,0Z", "url(#armor)", INK, 1)
    else:
        body = path("M-22,-9 L-15,-25 L5,-29 L24,-15 L25,6 L11,17 "
                    "L-14,11Z", "url(#armor)", INK, 2.4)
        body += path("M-14,-21 L3,-25 L19,-13 L18,-6 L0,-14 L-18,-6Z",
                     "url(#ivory)", INK, 1.4)
        body += path("M-17,0 L1,-7 L18,0 L11,11 L-12,6Z", PALETTES[name]["shade"], INK, 1.3)
        body += path("M-13,1 L-5,-2 M3,-3 L12,1", "none", PALETTES[name]["edge"], 1.5)
        for at_x in (-14, 14):
            body += ellipse((at_x,-7), 2, 2, PALETTES[name]["edge"], INK, .7)
    return group(at, body)


def read_normals() -> dict[str, list]:
    normals = {}
    stance = ""
    for line in (ROOT / "scripts/combat_rules.gd").read_text().splitlines():
        match = re.match(r'\s*"(standing|crouching|air)": \{', line)
        if match:
            stance = match[1]
        match = re.match(r'\s*"(lp|hp|lk|hk)": (\[.*\]),', line)
        if match:
            normals[f"{stance}_{match[1]}"] = json.loads(match[2])
    return normals


def pose(name: str, animation: str, frame: int, normals: dict[str, list]) -> dict:
    heavy = name == "amber"
    phase = frame / FRAMES * math.tau
    sway = math.sin(phase)
    p = {"hip": (-5.0,-83.0 if heavy else -76.0),
         "chest": (0.0,-133.0 if heavy else -124.0),
         "head": (6.0,-169.0 if heavy else -159.0),
         "rear_knee": (-31.0,-46.0), "rear_foot": (-42.0,-8.0),
         "front_knee": (24.0,-44.0), "front_foot": (43.0,-8.0),
         "rear_elbow": (-37.0,-103.0), "rear_hand": (-22.0,-138.0),
         "front_elbow": (32.0,-105.0), "front_hand": (50.0,-132.0),
         "rotation": 0.0, "translation": (0.0,0.0), "tilt": 0.0, "scarf": sway}
    if animation in ("idle", "guard", "crouch", "crouch_guard"):
        for joint in ("hip", "chest", "head", "rear_elbow", "front_elbow", "rear_hand", "front_hand"):
            p[joint] = add(p[joint], (math.cos(phase) * .7, sway * 1.8))
    if animation == "walk":
        for side, sign in (("rear",1),("front",-1)):
            p[f"{side}_foot"] = (sway * 35 * sign, -8 - max(0, math.cos(phase)*sign)*16)
            p[f"{side}_knee"] = (sway * 22 * sign + 3, -44 - max(0, math.cos(phase)*sign)*10)
        for joint in ("hip", "chest", "head", "rear_hand", "front_hand"):
            p[joint] = add(p[joint], (sway*2, math.cos(phase*2)*2))
    crouch = animation in ("crouch", "crouch_guard") or animation.startswith("crouching_")
    air = animation == "jump" or animation.startswith("air_")
    if crouch:
        for joint in ("hip", "chest", "head", "rear_elbow", "rear_hand", "front_elbow", "front_hand"):
            p[joint] = add(p[joint], (4, 50 if joint != "hip" else 33))
        p["rear_knee"] = (-31,-23)
        p["front_knee"] = (36,-27)
        p["rear_foot"] = (-33,-8)
        p["front_foot"] = (48,-8)
    if air:
        tuck = math.sin(frame / 7 * math.pi)
        p["rear_knee"] = (-37,-59 - tuck*15)
        p["rear_foot"] = (-24,-24 - tuck*25)
        p["front_knee"] = (35,-68 - tuck*9)
        p["front_foot"] = (24,-28 - tuck*16)
        p["front_hand"] = add(p["front_hand"], (-6,-10*tuck))
        p["head"] = add(p["head"], (tuck*3,-tuck*2))
        p["scarf"] = -1 + frame*.25
    if animation in ("guard", "crouch_guard"):
        p["front_hand"] = add(p["head"], (30,12 + sway*2))
        p["front_elbow"] = add(p["chest"], (35,25))
        p["rear_hand"] = add(p["head"], (14,29))
        p["rear_elbow"] = add(p["chest"], (7,29))
        p["tilt"] = -8
    if animation == "hurt":
        bend = (0,.35,.8,1,.87,.52,.2,.05)[frame]
        p["chest"] = add(p["chest"], (-24*bend,5*bend))
        p["head"] = add(p["head"], (-34*bend,6*bend))
        p["front_hand"] = add(p["front_hand"], (-35*bend,18*bend))
        p["rear_hand"] = add(p["rear_hand"], (-25*bend,-12*bend))
        p["tilt"] = -18*bend
    if animation == "ko":
        t = frame/7
        p["rotation"] = -88 * math.sin(t * math.pi/2)
        p["translation"] = (115*math.sin(t*math.pi/2), -18*t + math.sin(t*math.pi)*-20)
        p["hip"] = mix(p["hip"], (15,p["hip"][1]), t)
        p["chest"] = mix(p["chest"], (25,p["chest"][1]), t)
        p["head"] = mix(p["head"], (24,p["head"][1]), t)
        p["rear_knee"] = mix(p["rear_knee"], (3,-46), t)
        p["rear_foot"] = mix(p["rear_foot"], (0,-7), t)
        p["front_knee"] = mix(p["front_knee"], (18,-43), t)
        p["front_foot"] = mix(p["front_foot"], (7,-17), t)
        p["rear_elbow"] = mix(p["rear_elbow"], (0,-104), t)
        p["rear_hand"] = mix(p["rear_hand"], (8,-135), t)
        p["front_elbow"] = mix(p["front_elbow"], (41,-113), t)
        p["front_hand"] = mix(p["front_hand"], (36,-140), t)
        p["tilt"] = -15*t
    attack = "standing_hp" if animation == "attack" else animation
    if attack in normals or animation == "special":
        extension = (0,-.12,.22,.98,1,.73,.32,.035)[frame]
        p["scarf"] = -extension * 2 + sway*.6
        kind = attack.rsplit("_",1)[-1]
        strong = kind in ("hp", "hk") or animation == "special"
        if animation == "special":
            p["chest"] = add(p["chest"], (22*extension,3*extension))
            p["head"] = add(p["head"], (17*extension,3*extension))
            p["front_hand"] = mix(p["front_hand"], (86,-91), extension)
            p["rear_hand"] = mix(p["rear_hand"], (63,-93), extension)
            p["front_elbow"] = mix(p["front_elbow"], (52,-91), extension)
            p["rear_elbow"] = mix(p["rear_elbow"], (14,-97), extension)
            p["front_foot"] = add(p["front_foot"], (7*extension,0))
        else:
            reach = float(normals[attack][4]) * (1.10 if heavy else 1)
            target = (reach - (14 if heavy else 8), float(normals[attack][5]))
            if kind in ("lp", "hp"):
                p["hip"] = add(p["hip"], (8*extension,0))
                p["chest"] = add(p["chest"], ((34 if strong else 15)*extension,3*extension))
                p["head"] = add(p["head"], ((32 if strong else 13)*extension,5*extension))
                p["front_hand"] = mix(p["front_hand"], target, extension)
                p["front_elbow"] = mix(p["front_elbow"],
                                           ((target[0]+p["chest"][0]+14)*.5,target[1]+5), extension)
                p["rear_hand"] = add(p["rear_hand"], (-9*extension,8*extension))
                p["front_foot"] = add(p["front_foot"], (12*extension,0))
                p["tilt"] = 8*extension
            else:
                p["hip"] = add(p["hip"], (12*extension,-3*extension))
                p["chest"] = add(p["chest"], (-16*extension,-5*extension))
                p["head"] = add(p["head"], (-28*extension,-5*extension))
                p["front_foot"] = mix(p["front_foot"], target, extension)
                p["front_knee"] = mix(p["front_knee"],
                                          ((target[0]+p["hip"][0])*.5,target[1]-12), extension)
                p["front_hand"] = add(p["front_hand"], (-36*extension,0))
                p["rear_hand"] = add(p["rear_hand"], (-15*extension,16*extension))
                p["tilt"] = -11*extension
    return p


def fighter(name: str, animation: str, frame: int, normals: dict[str, list]) -> str:
    p = pose(name, animation, frame, normals)
    color = PALETTES[name]
    heavy = name == "amber"
    shoulder_width = 25 if heavy else 17
    rear_shoulder = add(p["chest"], (-shoulder_width,-1))
    front_shoulder = add(p["chest"], (shoulder_width,-1))
    body = ""
    if not heavy:
        wave = p["scarf"]
        scarf = path(f"M-7,9 Q-30,{4 + wave*4:.2f} -48,{-7 + wave*5:.2f} "
                     f"Q-67,{-11 + wave*7:.2f} -77,{-3 + wave*6:.2f} "
                     f"L-69,{8 + wave*5:.2f} Q-46,{4 + wave*4:.2f} -28,21 L-8,23Z",
                     "url(#ivory)", INK, 1.6)
        scarf += path(f"M-24,12 Q-46,{-1 + wave*6:.2f} -67,{3 + wave*6:.2f}",
                      "none", "#96b9b5", 1.3)
        if animation == "ko":
            scarf = f'<g transform="scale({1 - frame/7*.82:.3f},1)">{scarf}</g>'
        body += group(p["head"], scarf)
    for side in ("rear",):
        body += segment(add(p["hip"],(-9,0)), p[f"{side}_knee"], 15 if heavy else 11,
                        12 if heavy else 9, "cloth", "#70868d")
        body += segment(p[f"{side}_knee"], p[f"{side}_foot"], 12 if heavy else 9,
                        10 if heavy else 8, "armor" if heavy else "cloth", color["main"])
        body += boot(p[f"{side}_foot"], name, -6)
    body += segment(rear_shoulder, p["rear_elbow"], 15 if heavy else 10, 12 if heavy else 8,
                    "skin" if heavy else "armor", color["skin_light"] if heavy else color["edge"])
    body += segment(p["rear_elbow"], p["rear_hand"], 13 if heavy else 9, 14 if heavy else 7,
                    "armor", color["light"])
    body += glove(p["rear_hand"], p["rear_elbow"], name)
    body += segment(add(p["hip"],(7,0)), p["front_knee"], 17 if heavy else 13,
                    13 if heavy else 10, "cloth", "#839499")
    body += segment(p["front_knee"], p["front_foot"], 13 if heavy else 10,
                    10 if heavy else 8, "armor" if heavy else "cloth", color["light"])
    body += group(p["front_knee"], path("M-10,-7 L6,-10 L11,-1 L6,9 L-8,7Z",
                                       "url(#armor)" if heavy else "url(#ivory)", INK, 1.4))
    kick = animation.endswith("lk") or animation.endswith("hk")
    body += boot(p["front_foot"], name, -20 if kick and frame in (3,4,5) else 0)
    body += segment(add(p["head"],(-3,12)), add(p["chest"],(0,2)), 10 if heavy else 7,
                    13 if heavy else 10, "skin", color["skin_light"], False)
    body += torso(p["hip"], p["chest"], name)
    body += shoulder(rear_shoulder, name)
    body += head(p["head"], name, p["tilt"])
    if not heavy:
        body += group(add(p["head"],(0,20)), path("M-14,-6 L9,-6 L17,1 L7,12 L-13,8 L-18,0Z",
                                                "url(#ivory)", INK, 1.6)
                      + path("M-12,0 L6,5 L13,1", "none", "#8dadaa", 1.2))
    body += segment(front_shoulder, p["front_elbow"], 17 if heavy else 10,
                    13 if heavy else 8, "skin" if heavy else "armor",
                    color["skin_light"] if heavy else color["edge"])
    body += shoulder(front_shoulder, name)
    body += segment(p["front_elbow"], p["front_hand"], 15 if heavy else 9,
                    16 if heavy else 7, "armor", color["edge"])
    body += glove(p["front_hand"], p["front_elbow"], name)
    return group(p["translation"], body, p["rotation"])


def sprite_frames(name: str, count: int) -> str:
    lines = [f'[gd_resource type="SpriteFrames" load_steps={count+2} format=3]', "",
             f'[ext_resource type="Texture2D" path="res://assets/characters/{name}-sheet.svg" id="1"]']
    for index in range(count):
        col, row = index % COLUMNS, index // COLUMNS
        lines += ["", f'[sub_resource type="AtlasTexture" id="Frame_{index}"]',
                  'atlas = ExtResource("1")',
                  f'region = Rect2({col*CELL[0]}, {row*CELL[1]}, {CELL[0]}, {CELL[1]})',
                  "filter_clip = true"]
    animations = []
    for row, animation in enumerate(ANIMATIONS):
        frames = ",\n".join('{"duration": 1.0, "texture": SubResource("Frame_%d")}'
                            % (row*FRAMES+frame) for frame in range(FRAMES))
        loop = animation in ("idle", "walk", "guard", "crouch", "crouch_guard")
        speed = 12 if animation == "walk" else 8
        animations.append('{"frames": [\n' + frames + '\n], "loop": '
                          + str(loop).lower() + ', "name": &"' + animation
                          + '", "speed": ' + str(float(speed)) + '}')
    return "\n".join(lines) + '\n\n[resource]\nanimations = [\n' + ",\n".join(animations) + '\n]\n'


def portrait(name: str, normals: dict[str, list]) -> str:
    canvas = '<svg xmlns="http://www.w3.org/2000/svg" width="420" height="420" viewBox="0 0 420 420">'
    canvas += definitions(name)
    canvas += '<g transform="translate(218,545) scale(2.55)">'
    canvas += fighter(name,"idle",0,normals) + '</g>'
    return canvas + '</svg>\n'


def main() -> None:
    target = ASSETS / "characters"
    target.mkdir(parents=True, exist_ok=True)
    normals = read_normals()
    count = len(ANIMATIONS) * FRAMES
    rows = math.ceil(count / COLUMNS)
    for name in PALETTES:
        canvas = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{COLUMNS*CELL[0]}" '
                  f'height="{rows*CELL[1]}" viewBox="0 0 {COLUMNS*CELL[0]} {rows*CELL[1]}">')
        canvas += definitions(name)
        for row, animation in enumerate(ANIMATIONS):
            for frame in range(FRAMES):
                index = row*FRAMES+frame
                at = (index%COLUMNS*CELL[0]+ORIGIN[0], index//COLUMNS*CELL[1]+ORIGIN[1])
                canvas += f'\n<!-- {animation} {frame} -->\n'
                canvas += group(at, fighter(name,animation,frame,normals))
        (target / f"{name}-sheet.svg").write_text(canvas + "</svg>\n")
        (target / f"{name}-frames.tres").write_text(sprite_frames(name,count))
        (ASSETS / f"portrait-{name}.svg").write_text(portrait(name,normals))
    print(f"キャラクター 2 体 / 各 {len(ANIMATIONS)} 動作 × {FRAMES} フレームを生成")


if __name__ == "__main__":
    main()
