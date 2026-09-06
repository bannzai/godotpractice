#!/usr/bin/env python3
"""こもれび農園の独立 SVG と PCM 音源を固定手順で再生成する。"""

from pathlib import Path
import argparse
import array
import hashlib
import json
import math
import random
import re
import shutil
import struct
import sys
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets"
INK = "#31574a"
CREAM = "#fff1ce"
GOLD = "#e8af52"
LEAF = "#6eaa67"
BGM_NAMES = {"title", "spring", "summer", "festival", "result"}


def ellipse(x, y, rx, ry, fill, stroke=INK, sw=2.5):
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'


def rect(x, y, w, h, fill, radius=0, stroke=INK, sw=2.5):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'


def path(d, fill="none", stroke=INK, sw=2.5):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"/>'


def group(content, transform):
    return f'<g transform="{transform}">{content}</g>'


def write_svg(name, w, h, content):
    # Godot の SVG インポーターでも透明度を保つため8桁hexを独立属性へ展開する。
    content=re.sub(
        r'(fill|stroke)="(#[0-9a-fA-F]{6})([0-9a-fA-F]{2})"',
        lambda match:f'{match[1]}="{match[2]}" {match[1]}-opacity="{int(match[3],16)/255:.6f}"',
        content,
    )
    target = ASSETS / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{content}</svg>\n')


def flower(x, y, color="#f6baac", size=1):
    body = "".join(ellipse(math.cos(i * math.tau / 5) * 5, math.sin(i * math.tau / 5) * 5, 4, 4, color, "none") for i in range(5))
    return group(body + ellipse(0, 0, 3, 3, GOLD, "none"), f"translate({x} {y}) scale({size})")


def farmer(frame, action):
    phase = math.sin(frame * math.pi / 2)
    bob = phase * (2 if action == "walk" else 1)
    lean = [0, -8, 10, 3][frame] if action in ("hoe", "water", "harvest") else (9 if action == "tired" else 0)
    stride = phase * 7 if action == "walk" else 0
    body = ellipse(64, 111, 30, 8, "#31574a22", "none")
    person = path(f"M51 92 L{50-stride} 107 M73 92 L{75+stride} 107", stroke="#44565a", sw=13)
    person += ellipse(47-stride, 110, 10, 5, "#74574c") + ellipse(79+stride, 110, 10, 5, "#74574c")
    person += rect(43, 62, 39, 35, "#f5c686", 12)
    person += path("M49 65 L48 93 Q64 101 79 92 L78 64 M55 65 L55 79 L71 79 L71 65", "#588b98")
    person += rect(56, 80, 14, 12, "#77a7a8", 3) + ellipse(53, 72, 2, 2, GOLD, "none") + ellipse(73, 72, 2, 2, GOLD, "none")
    held = ""
    if action == "hoe":
        angle = [-38, -65, 20, 6][frame]
        held = group(path("M88 73 L106 24", stroke="#ac815a", sw=6) + path("M99 23 L117 28 L115 36 L99 31 Z", "#7a9290") + ellipse(87, 74, 7, 6, "#edb98e"), f"rotate({angle} 84 77)")
    elif action == "water":
        person += group(path("M88 77 L104 73 L111 65", stroke="#719fa6", sw=8) + rect(80, 71, 23, 21, "#6eb8bb", 5) + path("M82 71 Q82 57 95 64 L98 72", stroke="#356b73", sw=4) + ellipse(88, 76, 6, 6, "#edb98e"), f"rotate({[0,12,23,12][frame]} 86 74)")
        if frame > 0:
            person += "".join(ellipse(109 + i * 4, 80 + i * 5 + frame, 1.5, 3, "#bcebee", "none") for i in range(3))
    elif action == "harvest":
        person += path(f"M82 72 L94 {65-frame*3}", stroke="#edb98e", sw=11)
        held = group(crop("turnip", "ripe"), f"translate(79 {34-frame*3}) scale(.55)")
    else:
        person += path(f"M43 72 L{36-stride/2} {88+stride/2} M81 72 L{88+stride/2} {88-stride/2}", stroke="#edb98e", sw=11)
    person += ellipse(64, 50, 23, 24, "#edb98e")
    person += path("M42 42 Q40 20 60 24 Q83 21 88 43 L80 48 L78 38 Q56 42 49 34 L48 50 Z", "#705643")
    person += ellipse(48, 55, 4, 6, "#edb98e") + ellipse(82, 55, 4, 6, "#edb98e")
    if action == "tired":
        person += path("M55 54 L61 56 M68 56 L74 54 M61 65 Q65 61 69 65")
    else:
        person += ellipse(57, 52, 2.5, 3.5, INK, "none") + ellipse(71, 52, 2.5, 3.5, INK, "none") + path("M60 62 Q65 67 70 61", sw=2)
    person += ellipse(53, 59, 4, 2.5, "#dc8e7c", "none") + ellipse(77, 59, 4, 2.5, "#dc8e7c", "none")
    person += ellipse(64, 34, 35, 10, "#edc979") + path("M43 32 L47 14 Q65 7 81 16 L85 33 Z", "#efd99a")
    person += path("M45 27 Q64 33 83 27", stroke="#a88d59", sw=6) + path("M52 17 L51 23 M61 15 L61 24 M72 16 L72 24", stroke="#d4b774", sw=2)
    person += flower(82, 26, "#f6baac", .6) + held
    return body + group(person, f"translate(0 {bob}) rotate({lean} 64 103)")


def merchant(frame, action):
    wave_angle = [0, -24, -48, -24][frame] if action in ("hoe", "water", "harvest") else 0
    stride = math.sin(frame * math.pi / 2) * 6 if action == "walk" else 0
    bob = math.sin(frame * math.pi / 2) * 1.5
    body = ellipse(64, 112, 29, 7, "#31574a22", "none")
    person = ellipse(53-stride, 108, 9, 5, "#705643") + ellipse(75+stride, 108, 9, 5, "#705643")
    person += path("M45 63 Q63 57 82 64 L91 99 Q66 111 38 100 Z", "#a994c1")
    person += path("M53 64 L54 94 Q65 99 77 94 L76 64", "#dfcde2") + rect(57, 79, 16, 11, "#b19bc4", 3)
    person += group(path("M79 69 L94 76 L100 62", stroke="#efc9a0", sw=10) + ellipse(100, 60, 6, 7, "#efc9a0"), f"rotate({wave_angle} 80 70)")
    person += path("M45 72 L34 84", stroke="#efc9a0", sw=10)
    person += path("M22 81 Q25 66 38 74 L41 83 M19 81 L46 81 L43 100 L23 100 Z", "#bb8d61")
    person += path("M22 88 L44 88 M24 94 L44 94 M28 82 L29 99 M37 82 L37 99", stroke="#8a684c", sw=1.5)
    person += "".join(flower(25+i*7, 77-(i%2)*5, ["#f3ada9", "#f0d476", "#c2b5df"][i], .65) for i in range(3))
    person += ellipse(64, 39, 27, 29, "#d4c4ad") + ellipse(87, 27, 10, 11, "#d4c4ad")
    person += ellipse(64, 49, 22, 24, "#efc9a0")
    person += path("M43 45 Q44 24 61 24 Q68 24 79 32 L81 42 Q68 42 61 30 Q52 43 43 45", "#d4c4ad")
    person += ellipse(55, 50, 9, 8, "#fff1ce44", INK, 2) + ellipse(75, 50, 9, 8, "#fff1ce44", INK, 2) + path("M64 50 L66 50", sw=2)
    person += ellipse(55, 51, 2, 3, INK, "none") + ellipse(75, 51, 2, 3, INK, "none") + path("M60 62 Q66 68 72 61", sw=2)
    person += path("M47 66 Q61 76 80 65 L72 77 L62 72 L54 77 Z", "#f0dcac")
    person += flower(84, 32, "#a994c1", .75)
    if action == "tired":
        person += path("M52 51 L58 51 M72 51 L78 51", sw=3)
    return body + group(person, f"translate(0 {bob})")


def chicken(frame, action):
    flap = [-8, -26, 9, -15][frame] if action in ("hoe", "water", "harvest") else [0, 3, 0, -3][frame]
    stride = math.sin(frame * math.pi / 2) * 7 if action == "walk" else 0
    body = ellipse(64, 107, 26, 7, "#31574a22", "none")
    body += path(f"M55 91 L{54-stride} 105 L{48-stride} 107 M72 91 L{75+stride} 105 L{81+stride} 107", stroke="#c99549", sw=4)
    body += path("M42 69 Q18 57 29 42 Q36 48 39 55 Q26 35 38 33 Q48 45 48 60", "#f5e7c8")
    body += ellipse(64, 78, 28, 22, "#fff4dc")
    body += group(path("M51 68 Q76 62 78 82 Q62 95 47 81 Q59 81 57 74 Z", "#e1d3b6"), f"rotate({flap} 52 73)")
    head_y = 58 + (10 if action == "tired" else 0) + (frame%2)*2
    body += ellipse(83, head_y, 17, 19, "#fff4dc")
    body += path(f"M74 {head_y-15} Q69 {head_y-31} 78 {head_y-25} Q85 {head_y-35} 89 {head_y-23} Q101 {head_y-25} 95 {head_y-12}", "#d98379")
    body += path(f"M96 {head_y-1} L108 {head_y+4} L96 {head_y+9} Z", "#e8af52")
    body += ellipse(95, head_y+13, 5, 7, "#d98379")
    body += ellipse(88, head_y-1, 3, 4 if action != "tired" else 1, INK, "none") + ellipse(89, head_y-2, .8, 1, CREAM, "none")
    return body


def crop(kind, stage):
    colors = {"turnip": "#eee1bf", "carrot": "#e69d54", "tomato": "#dc8172", "corn": "#e5be5c"}
    if stage == "seed":
        return ellipse(32, 47, 13, 5, "#775b43", "none") + ellipse(29, 44, 3, 2, "#e4c592", "none") + ellipse(37, 46, 2, 1.5, "#e4c592", "none")
    scale = {"sprout": .5, "growing": .75, "ripe": 1}[stage]
    plant = path("M32 49 L32 20", stroke="#4f8250", sw=3)
    plant += path("M31 38 Q12 41 14 26 Q27 24 31 38 M33 32 Q49 34 51 20 Q36 19 33 32", LEAF)
    if kind == "corn":
        plant += path("M32 49 L31 10 M31 13 L25 7 M31 10 L36 5", stroke="#bda34e", sw=3)
        plant += path("M29 38 Q12 28 10 15 Q27 20 29 38 M35 44 Q52 39 56 23 Q38 23 35 44", "#8cb973")
    if stage == "ripe" or stage == "growing":
        if kind == "turnip":
            plant += path("M17 39 Q16 27 31 28 Q47 27 47 40 Q45 51 34 54 L31 59 L28 53 Q19 49 17 39", colors[kind]) + path("M20 35 Q31 40 43 34", stroke="#cdafa4", sw=4)
        elif kind == "carrot":
            plant += path("M20 33 Q31 26 43 34 L30 58 Q20 43 20 33", colors[kind]) + path("M23 37 L32 39 M28 45 L34 46", stroke="#bd8149", sw=2)
        elif kind == "tomato":
            plant += ellipse(24, 44, 12, 11, colors[kind]) + ellipse(43, 32, 11, 10, colors[kind]) + path("M17 36 L25 39 L29 34 M37 25 L43 28 L48 23", stroke="#4f8250", sw=3)
            plant += ellipse(20, 41, 3, 2, "#efa99a", "none")
        else:
            plant += ellipse(35, 33, 8, 18, colors[kind]) + path("M28 40 L26 24 Q16 34 31 50 M40 42 L43 21 Q50 41 32 51", "#76a563")
            plant += "".join(ellipse(34+(j%2)*4, 23+j*4, 1, 1.5, "#bd963f", "none") for j in range(5))
    return group(plant, f"translate({32*(1-scale)} {54*(1-scale)}) scale({scale})")


def props():
    house = ellipse(123, 173, 109, 15, "#31574a25", "none") + rect(31, 69, 183, 100, "#efd9aa", 6)
    house += path("M13 78 L110 10 Q122 2 134 11 L230 78 L218 91 L121 30 L26 92 Z", "#ba7764")
    house += path("M43 61 L122 14 L204 64 M33 72 L122 24 L212 75", stroke="#dd9c7b", sw=4)
    house += rect(165, 13, 22, 36, "#aebda7", 3) + rect(160, 9, 31, 8, "#d6ddc2", 3)
    house += rect(96, 105, 43, 64, "#8caa92", 20) + path("M118 108 L118 164", stroke="#597e6b", sw=2) + ellipse(130, 138, 3, 3, GOLD)
    for x in (48, 160):
        house += rect(x, 102, 33, 31, "#8ac2c1", 6) + path(f"M{x+16} 104 L{x+16} 131 M{x+2} 117 L{x+31} 117", stroke=CREAM, sw=3) + rect(x-5, 135, 43, 10, "#b48862", 3)
        house += "".join(flower(x+4+i*12, 134, "#e8a093", .6) for i in range(3))
    house += rect(86, 166, 63, 10, "#b9b69a", 3)
    write_svg("props/house.svg", 244, 190, house)
    well = ellipse(65, 125, 53, 11, "#31574a25", "none") + ellipse(65, 102, 45, 24, "#96b2a3") + rect(20, 81, 90, 24, "#c3cfb5", 3) + ellipse(65, 81, 45, 18, "#dce0c2") + ellipse(65, 81, 33, 10, "#548c96")
    well += path("M33 92 L33 28 M96 92 L96 28", stroke="#a98962", sw=8) + path("M13 34 L64 6 L118 34 Z", "#c7866b") + path("M33 47 L96 47", stroke="#a98962", sw=7) + path("M65 47 L65 85", stroke="#d5b879", sw=3) + rect(58, 76, 16, 14, "#87aaa8", 3)
    write_svg("props/well.svg", 130, 140, well)
    shipping = ellipse(64, 100, 55, 10, "#31574a25", "none") + rect(14, 40, 100, 60, "#b88f62", 5) + path("M14 43 L35 25 L104 25 L114 43 Z", "#d3af79") + path("M19 57 L109 57 M19 79 L109 79 M32 43 L32 97 M96 43 L96 97", stroke="#866a4c", sw=3) + rect(43, 50, 40, 34, "#f2ddb0", 3)
    shipping += path("M53 73 L62 58 L73 72 M62 58 L62 79", stroke="#5f8962", sw=4) + ellipse(28, 51, 2, 2, INK, "none") + ellipse(100, 88, 2, 2, INK, "none")
    write_svg("props/shipping.svg", 128, 112, shipping)
    shop = ellipse(117, 147, 99, 13, "#31574a25", "none") + path("M30 49 L30 132 M201 49 L201 132", stroke="#967751", sw=8) + rect(22, 95, 190, 46, "#c59b6d", 5)
    shop += path("M9 53 L37 13 L193 13 L223 53 Z", "#a3bfa0")
    for i in range(6):
        x = 11+i*35
        shop += path(f"M{x} 53 L{x+13} 14 L{x+35} 14 L{x+35} 53 Q{x+17} 73 {x} 53", "#f4e2b7" if i%2 == 0 else "#85a99b")
    shop += path("M35 112 L198 112 M35 132 L198 132", stroke="#a07955", sw=2)
    for i, kind in enumerate(("turnip", "carrot", "tomato", "corn")):
        shop += group(crop(kind, "ripe"), f"translate({29+i*43} 59) scale(.7)")
    write_svg("props/shop.svg", 234, 164, shop)
    tree = ellipse(88, 179, 59, 12, "#31574a25", "none") + path("M76 166 L78 82 L105 79 L106 167 L119 179 L65 179 Z", "#a8885b") + path("M85 159 L86 94 M104 122 L117 107", stroke="#805f46", sw=4)
    for x,y,rx,ry,color in [(60,83,49,43,"#598c68"),(114,83,47,45,"#659967"),(91,45,55,42,"#80ae70"),(54,52,35,32,"#92b77a"),(113,36,33,28,"#9abe7e")]:
        tree += ellipse(x,y,rx,ry,color)
    tree += path("M29 62 Q44 41 61 49 M73 29 Q94 13 112 28 M105 83 Q130 64 141 81", stroke="#b4ce91", sw=4)
    tree += ellipse(43,87,5,6,"#e9bd69") + ellipse(120,60,5,6,"#e9bd69")
    write_svg("props/tree.svg", 176, 195, tree)
    fence = path("M7 35 L121 35 M7 57 L121 57", stroke="#b69a70", sw=11)
    for x in (15,64,113):
        fence += path(f"M{x-6} 72 L{x-6} 19 L{x} 11 L{x+6} 19 L{x+6} 72 Z", "#e4c593") + ellipse(x, 35, 1.8, 1.8, "#897657", "none")
    write_svg("props/fence.svg", 128, 80, fence)


def terrain():
    tiles = []
    for index, color in enumerate(("#9cbd7a", "#d7bf8f", "#a28159", "#785f49", "#78b9be", "#a7c783")):
        tile = rect(0,0,64,64,color,stroke="none")
        if index in (0,5):
            for j in range(7):
                x,y = (j*19+11)%61, (j*29+9)%58
                tile += path(f"M{x-3} {y} L{x} {y+3} L{x+2} {y-3}", stroke="#80a866", sw=1.4)
            if index == 5:
                tile += flower(14,23,"#f5e5b1",.45) + flower(43,45,"#efbca9",.5)
        elif index == 1:
            for j in range(10):
                tile += ellipse((j*19+5)%64,(j*27+12)%64,2.5,1.5,"#bca57b","none")
        elif index in (2,3):
            for y in (12,27,42,57):
                tile += path(f"M5 {y} Q30 {y-3} 58 {y}", stroke="#866746" if index==2 else "#624f40",sw=3)
                tile += path(f"M7 {y+4} L55 {y+4}",stroke="#bc9867" if index==2 else "#8b7761",sw=1.5)
        else:
            tile += path("M3 17 Q12 21 22 17 M35 38 Q47 44 60 38 M8 57 Q20 62 33 57",stroke="#b8dbd4",sw=2)
        tiles.append(group(tile, f"translate({index*64} 0)"))
    write_svg("tiles/terrain.svg",384,64,"".join(tiles))


def backgrounds():
    far = '<defs><linearGradient id="sky" x2="0" y2="1"><stop stop-color="#b7dad3"/><stop offset="1" stop-color="#f8e9ba"/></linearGradient></defs>' + rect(0,0,1280,720,"url(#sky)",stroke="none")
    far += ellipse(1030,118,60,60,"#fff0bf","none")
    for x,y,s in ((130,110,1),(530,63,.7),(880,188,.6)):
        far += group(ellipse(0,0,60,16,"#fff3dbaa","none") + ellipse(-18,-12,30,20,"#fff3dbaa","none") + ellipse(18,-8,28,21,"#fff3dbaa","none"),f"translate({x} {y}) scale({s})")
    far += path("M0 356 Q180 204 389 350 Q573 207 787 334 Q1084 186 1280 320 L1280 720 L0 720Z","#99bba1","none")
    write_svg("backgrounds/far.svg",1280,720,far)
    mid = path("M0 458 Q175 292 406 420 Q674 278 906 422 Q1100 310 1280 420 L1280 720 L0 720Z","#80a978","none")
    mid += path("M0 555 Q219 457 509 528 Q815 407 1280 517 L1280 720 L0 720Z","#a2bd7c","none")
    mid += path("M797 480 Q793 573 965 720 L1144 720 Q910 547 850 486Z","#e2ca98","none")
    for i in range(12):
        x=30+i*109; y=420+(i%3)*22
        mid += ellipse(x,y,13,28,"#679169","none") + path(f"M{x} {y+14} L{x} {y+35}",stroke="#74946c",sw=3)
    write_svg("backgrounds/mid.svg",1280,720,mid)
    near = path("M0 640 Q75 575 178 670 L260 720 L0 720Z","#4c795c","none") + path("M1000 720 Q1110 594 1280 634 L1280 720Z","#537e5d","none")
    for x,y in ((40,677),(115,704),(1180,687),(1250,650)):
        near += path(f"M{x} {y+30} Q{x-40} {y-30} {x-25} {y-35} Q{x+5} {y-24} {x} {y+30} M{x} {y+30} Q{x+45} {y-28} {x+30} {y-35} Q{x+2} {y-26} {x} {y+30}","#79a56b","#426b53",2)
        near += flower(x,y,"#f0c991",.8)
    write_svg("backgrounds/near.svg",1280,720,near)
    title = ellipse(320,285,285,251,"#f7e9bd",INK,4) + ellipse(320,296,265,230,"#a9c485","none")
    title += path("M65 341 Q272 166 581 352 L570 440 Q294 640 81 431Z","#d4bc8a","none")
    house = (ASSETS/"props/house.svg").read_text().split('>',1)[1].rsplit('</svg>',1)[0]
    title += group(house,"translate(167 100) scale(1.3)")
    for i,kind in enumerate(("turnip","carrot","tomato","corn")):
        title += group(crop(kind,"ripe"),f"translate({100+i*109} 354) scale(1.4)")
    title += group(farmer(0,"water"),"translate(346 268) scale(1.8)") + group(chicken(0,"idle"),"translate(140 380) scale(.85)")
    for x,y in ((50,255),(556,227),(103,472),(527,458)):
        title += flower(x,y,"#edb793",1.8)
    write_svg("backgrounds/title.svg",640,580,title)


def ui():
    icon_hoe = path("M17 52 L48 13",stroke="#b69064",sw=7) + path("M36 14 L54 29 L60 22 L43 7Z","#83a0a0")
    icon_seed = path("M15 14 L47 14 L51 55 L11 55Z","#eddaaa") + rect(14,8,34,8,"#c3aa73",3) + path("M31 43 L31 29 M31 35 Q14 35 20 24 Q28 23 31 35 M32 31 Q44 32 43 22 Q35 23 32 31","#8daf70")
    icon_water = rect(12,28,31,25,"#87b9ba",6) + path("M16 28 Q14 8 31 12 Q38 13 38 28",stroke="#68989d",sw=5) + path("M42 38 L54 30 L59 17",stroke="#87b9ba",sw=8) + ellipse(57,18,5,3,"#c0d9cd")
    icon_hand = path("M19 52 Q7 37 15 32 L23 39 L22 16 Q24 10 28 16 L29 30 L31 11 Q35 7 38 12 L37 31 L41 18 Q47 14 48 20 L44 35 Q51 29 55 34 Q59 39 50 49 L42 58Z","#e9bf98")
    for name, content in (("hoe",icon_hoe),("seed",icon_seed),("water",icon_water),("hand",icon_hand)):
        write_svg(f"ui/{name}.svg",64,64,content)
    logo = ellipse(96,58,43,43,"#eed59a",INK,3) + ellipse(96,58,29,29,"#efb952","none")
    logo += path("M96 108 L96 54 M94 79 Q46 83 37 47 Q83 36 94 79 M98 93 Q147 92 154 55 Q111 51 98 93","#83aa70",INK,3)
    logo += path("M35 118 Q98 137 159 118",stroke=INK,sw=4)
    for i in range(5):
        logo += ellipse(31+i*7, 107-i*11, 5, 10, GOLD,INK,1.5)
        logo += ellipse(161-i*7,107-i*11,5,10,GOLD,INK,1.5)
    write_svg("ui/logo.svg",192,144,logo)


def audio():
    rate=22050
    random_source=random.Random(37)
    def add_note(samples, onset, duration, midi, amp, voice="pluck", pan=0):
        freq=440*2**((midi-69)/12)
        start=int(onset*rate); length=int(duration*rate)
        for j in range(length):
            at=(start+j)%len(samples); t=j/rate
            if voice=="wood":
                value=(math.sin(math.tau*freq*t)+.36*math.sin(math.tau*freq*2.73*t)+.15*math.sin(math.tau*freq*5.19*t))*math.exp(-t*13)
            elif voice=="brush":
                value=random_source.uniform(-1,1)*math.exp(-t*42)*.35
            elif voice=="bass":
                value=(math.sin(math.tau*freq*t)+.22*math.sin(math.tau*freq*2*t))*math.exp(-t*3)*min(1,t*45)
            else:
                value=sum(math.sin(math.tau*freq*k*t)/k**1.7*math.exp(-t*(3+k*1.3)) for k in range(1,6))*min(1,t*160)
            fade=min(1,(length-j)/(rate*.035))
            samples[at][0]+=value*amp*fade*(1-pan*.4)
            samples[at][1]+=value*amp*fade*(1+pan*.4)
    def save(name,samples):
        if name in BGM_NAMES:
            # 終端8msだけを滑らかに補正し、ループ接続点の振幅を一致させる。
            blend_frames=min(int(rate*.008),len(samples)-1)
            corrections=[samples[0][side]-samples[-1][side] for side in (0,1)]
            for index in range(blend_frames):
                progress=index/(blend_frames-1)
                blend=progress*progress*(3-2*progress)
                for side in (0,1):
                    samples[len(samples)-blend_frames+index][side]+=corrections[side]*blend
        else:
            # 単発効果音は先頭2msと末尾10msに音量包絡を付けて再生・停止音を抑える。
            for index in range(len(samples)):
                envelope=min(1,index/(rate*.002),(len(samples)-1-index)/(rate*.010))
                for side in (0,1):
                    samples[index][side]*=envelope
        peak=max(max(abs(a),abs(b)) for a,b in samples) or 1
        multiplier=.77/max(1,peak)
        payload=bytearray()
        for left,right in samples:
            payload.extend(struct.pack("<hh",int(max(-1,min(1,left*multiplier))*32767),int(max(-1,min(1,right*multiplier))*32767)))
        with wave.open(str(ASSETS/"audio"/f"{name}.wav"),"wb") as output:
            output.setparams((2,2,rate,0,"NONE","not compressed")); output.writeframes(payload)
    (ASSETS/"audio").mkdir(parents=True,exist_ok=True)
    arrangements={"title":(96,[72,76,79,81,79,76,74,72],0),"spring":(112,[72,74,76,79,76,74,67,71],0),"summer":(122,[79,81,83,86,83,81,79,76],-5),"festival":(140,[72,79,84,83,81,79,76,74],0),"result":(108,[72,76,79,84,83,79,81,84],0)}
    for name,(bpm,melody,transpose) in arrangements.items():
        beat=60/bpm; samples=[[0.,0.] for _ in range(int(beat*16*rate))]
        roots=[48,53,55,48]
        for index in range(32):
            onset=index*beat/2; chord=roots[index//8]+transpose
            add_note(samples,onset,beat*.9,melody[index%8]+transpose,.16,"wood" if name=="summer" else "pluck",-.4)
            add_note(samples,onset,beat*1.1,chord+12+[0,4,7,12][index%4],.10,"pluck",.5)
            if index%2==0:
                add_note(samples,onset,beat*1.5,chord,.16,"bass",0)
                add_note(samples,onset,.1,40,.16,"brush",.7)
            if name=="festival" or index%4==2:
                add_note(samples,onset+beat/4,.11,76,.08,"wood",-.6)
        # 一周の残響を循環加算し、ループ境界で余韻を途切れさせない。
        dry=[row[:] for row in samples]; delay=int(beat*.75*rate)
        for index in range(len(samples)):
            for side in (0,1): samples[index][side]+=dry[(index-delay)%len(samples)][1-side]*.15
        save(name,samples)
    effects={"hoe":([43,50],.25,"wood"),"seed":([76,81],.24,"wood"),"water":([79,83,86,91],.55,"brush"),"harvest":([72,76,79,84],.5,"pluck"),"ship":([60,67,72,79],.65,"wood"),"next_day":([67,72,76,79,84],1.2,"pluck"),"ui":([81,88],.16,"wood"),"success":([72,76,79,84,88],1.5,"pluck"),"fail":([55,52,48],.6,"wood")}
    for name,(notes,duration,voice) in effects.items():
        samples=[[0.,0.] for _ in range(int((duration+.25)*rate))]
        for i,note in enumerate(notes):
            add_note(samples,i*duration/len(notes),.3 if voice!="pluck" else .5,note,.32,voice,(i%3-1)*.4)
            if name=="water":add_note(samples,i*.08,.2,note,.13,"wood")
        save(name,samples)


def generate_images():
    for kind,draw in (("farmer",farmer),("merchant",merchant),("chicken",chicken)):
        frames=[]
        for row,action in enumerate(("idle","walk","hoe","water","harvest","tired")):
            for column in range(4):
                frames.append(group(draw(column,action),f"translate({column*128} {row*128})"))
        write_svg(f"characters/{kind}.svg",512,768,"".join(frames))
    for kind in ("turnip","carrot","tomato","corn"):
        for stage in ("seed","sprout","growing","ripe"):
            write_svg(f"crops/{kind}_{stage}.svg",64,64,crop(kind,stage))
    props(); terrain(); backgrounds(); ui()


def main():
    generate_images()
    audio()
    (ASSETS/"fonts").mkdir(parents=True,exist_ok=True)
    for name in ("MPLUSRounded1c-Regular.ttf","OFL.txt"):
        shutil.copyfile(ROOT.parent/"monsterquest"/"assets"/"fonts"/name,ASSETS/"fonts"/name)
    print(f"素材生成 OK: {asset_counts(ASSETS)}")


def asset_counts(directory):
    counts={suffix:len(list(directory.rglob(f"*{suffix}"))) for suffix in (".svg",".wav",".ttf")}
    return f"SVG {counts['.svg']}枚 / WAV {counts['.wav']}本 / フォント {counts['.ttf']}本"


def source_hashes(directory):
    return {
        str(source.relative_to(directory)):hashlib.sha256(source.read_bytes()).hexdigest()
        for source in sorted(directory.rglob("*"))
        if source.is_file() and (source.suffix in (".svg",".wav",".ttf") or source.name=="OFL.txt")
    }


def verify():
    """既存素材を変更せずに再生成の一致と PCM の実データを検証する。"""
    global ASSETS
    original=ASSETS
    actual_hashes=source_hashes(original)
    reports=[]
    problems=[]
    for source in sorted((original/"audio").glob("*.wav")):
        with wave.open(str(source),"rb") as stream:
            channels=stream.getnchannels()
            rate=stream.getframerate()
            frames=stream.getnframes()
            if (channels,stream.getsampwidth(),rate)!=(2,2,22050) or frames==0:
                problems.append(f"{source.name}: PCM形式・フレーム数が不正")
                continue
            samples=array.array("h",stream.readframes(frames))
        if sys.byteorder!="little":
            samples.byteswap()
        peak=max(abs(value) for value in samples)/32768
        rms=math.sqrt(sum(value*value for value in samples)/len(samples))/32768
        clipped=sum(value<=-32768 or value>=32767 for value in samples)
        boundary=max(abs(samples[side]-samples[-channels+side]) for side in range(channels))/32768
        report={"file":source.name,"seconds":round(frames/rate,5),"peak":round(peak,6),
                "rms_dbfs":round(20*math.log10(rms),3) if rms else None,
                "clipped_samples":clipped,"boundary_delta":round(boundary,7)}
        reports.append(report)
        if clipped or rms<.001 or any(not any(samples[side::channels]) for side in range(channels)):
            problems.append(f"{source.name}: クリッピングまたは無音を検出")
        if source.stem in BGM_NAMES and boundary>1/32768:
            problems.append(f"{source.name}: ループ境界の差が1 PCM段階を超える")
        print(f"音声検証: {json.dumps(report,ensure_ascii=False)}")
    temporary_root=ROOT/"tmp"
    temporary_root.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="asset-verify-",dir=temporary_root) as temporary:
        try:
            ASSETS=Path(temporary)
            main()
            regenerated_hashes=source_hashes(ASSETS)
        finally:
            ASSETS=original
    if actual_hashes!=regenerated_hashes:
        changed=sorted(name for name in actual_hashes.keys()|regenerated_hashes.keys()
                       if actual_hashes.get(name)!=regenerated_hashes.get(name))
        problems.append(f"再生成のSHA-256が不一致: {', '.join(changed)}")
    report_path=temporary_root/"asset-verification.json"
    report_path.write_text(json.dumps({"counts":asset_counts(original),"sha256":actual_hashes,
                                      "audio":reports,"problems":problems},ensure_ascii=False,indent=2)+"\n")
    if problems:
        for problem in problems:
            print(f"素材検証失敗: {problem}",file=sys.stderr)
        raise SystemExit(1)
    print(f"素材検証 OK: SHA-256 {len(actual_hashes)}ファイル一致 / {asset_counts(original)}")
    print(f"検証記録: {report_path}")


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    mode=parser.add_mutually_exclusive_group()
    mode.add_argument("--verify",action="store_true",help="既存素材を検査し、一時ディレクトリへの再生成とSHA-256で照合する")
    mode.add_argument("--images-only",action="store_true",help="SVG画像だけを再生成する")
    arguments=parser.parse_args()
    if arguments.verify:
        verify()
    elif arguments.images_only:
        generate_images()
        print(f"画像生成 OK: {asset_counts(ASSETS)}")
    else:
        main()
