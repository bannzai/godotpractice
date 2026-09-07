#!/usr/bin/env python3
"""CC0 写真と紙目から、版画調の PNG 素材を固定手順で再生成・検査する。"""

from __future__ import annotations

from pathlib import Path
import argparse
import array
import hashlib
import io
import json
import math
import shutil
import struct
import sys
import tempfile
import wave

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets"
INK = "#332c26"
PAPER = "#ead7ab"
RED = "#a83f2f"
GREEN = "#315c43"
GOLD = "#c98b32"
BLUE = "#426a72"
GENERATED_FILES: list[str] = []
GENERATED_AUDIO_FILES: list[str] = []


def _write_png(path: Path, image: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    stream = io.BytesIO()
    image.save(stream, "PNG", optimize=False, compress_level=9)
    payload = stream.getvalue()
    if not path.exists() or path.read_bytes() != payload:
        path.write_bytes(payload)


def _source(name: str) -> Image.Image:
    return Image.open(ASSETS / "source_photos" / name).convert("RGB")


def _paper(size: tuple[int, int], tint: str = PAPER) -> Image.Image:
    texture = ImageOps.fit(_source("paper_cc0.jpg"), size, method=Image.Resampling.LANCZOS)
    values = ImageOps.autocontrast(ImageOps.grayscale(texture), cutoff=1)
    colored = ImageOps.colorize(values, black="#8e6c42", white=tint)
    return Image.blend(Image.new("RGB", size, tint), colored, 0.34)


def _woodcut_photo(
    source_name: str,
    size: tuple[int, int],
    colors: tuple[str, str, str] = (INK, GREEN, PAPER),
) -> Image.Image:
    photo = ImageOps.fit(_source(source_name), size, method=Image.Resampling.LANCZOS)
    values = ImageOps.autocontrast(ImageOps.grayscale(photo), cutoff=2)
    values = values.filter(ImageFilter.GaussianBlur(0.55))
    values = values.point(lambda value: 25 if value < 92 else 138 if value < 176 else 235)
    print_layer = ImageOps.colorize(
        values,
        black=colors[0],
        mid=colors[1],
        white=colors[2],
        blackpoint=0,
        midpoint=128,
        whitepoint=255,
    )
    return ImageChops.multiply(print_layer, _paper(size, colors[2]))


def _distress(image: Image.Image, seed: int, strength: int = 36) -> Image.Image:
    result = image.convert("RGBA")
    alpha = result.getchannel("A")
    marks = Image.new("L", image.size, 255)
    draw = ImageDraw.Draw(marks)
    width, height = image.size
    for index in range(strength):
        x = (seed * 31 + index * 67) % max(1, width)
        y = (seed * 19 + index * 43) % max(1, height)
        length = 2 + (index * 5 + seed) % max(3, min(15, width // 4 + 1))
        draw.line((x, y, min(width - 1, x + length), y), fill=80, width=1)
    result.putalpha(ImageChops.multiply(alpha, marks))
    return result


def _actor_frame(kind: str, action: str, frame: int) -> Image.Image:
    image = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    phase = (-1, 0, 1, 0)[frame]
    bob = phase * (2 if action == "walk" else 1)
    tired = action == "tired"
    if kind == "chicken":
        draw.ellipse((35, 103, 98, 114), fill="#4e41385c")
        stride = phase * 6 if action == "walk" else 0
        draw.line((55, 88, 53 - stride, 107), fill=GOLD, width=4)
        draw.line((75, 88, 78 + stride, 107), fill=GOLD, width=4)
        draw.ellipse((34, 52 + bob, 92, 96 + bob), fill="#e8d6a8", outline=INK, width=4)
        wing_y = 58 + (-8 if action in ("hoe", "water", "harvest") and frame % 2 else 4)
        draw.polygon(((48, 61), (77, wing_y), (82, 84), (52, 90)), fill=RED, outline=INK)
        draw.ellipse((72, 39 + bob, 106, 73 + bob), fill="#eadbb9", outline=INK, width=4)
        draw.polygon(((78, 41), (83, 26), (90, 40), (98, 27), (100, 45)), fill=RED)
        draw.polygon(((101, 53), (119, 60), (101, 67)), fill=GOLD, outline=INK)
        draw.ellipse((91, 49 if not tired else 55, 97, 55 if not tired else 57), fill=INK)
        return _distress(image, 503 + frame * 11 + len(action), 17)

    stride = phase * 7 if action == "walk" else 0
    skin = "#cb9569"
    draw.ellipse((35, 106, 94, 117), fill="#4e41385c")
    draw.line((51, 88, 48 - stride, 108), fill=INK, width=10)
    draw.line((76, 88, 80 + stride, 108), fill=INK, width=10)
    draw.ellipse((39 - stride, 104, 60 - stride, 114), fill=RED, outline=INK, width=2)
    draw.ellipse((70 + stride, 104, 91 + stride, 114), fill=RED, outline=INK, width=2)
    if kind == "farmer":
        draw.rounded_rectangle((42, 57 + bob, 85, 98 + bob), radius=9, fill=BLUE, outline=INK, width=4)
        draw.rectangle((53, 72 + bob, 74, 93 + bob), fill="#ba7b3d", outline=INK, width=3)
    else:
        draw.polygon(((38, 61 + bob), (87, 58 + bob), (96, 101 + bob), (30, 101 + bob)), fill=RED, outline=INK)
        draw.rectangle((53, 65 + bob, 73, 96 + bob), fill=PAPER, outline=INK, width=3)
    arm_shift = -10 if action in ("hoe", "water", "harvest") and frame in (1, 2) else 0
    draw.line((42, 67 + bob, 30, 86 + bob - arm_shift), fill=skin, width=10)
    draw.line((84, 67 + bob, 99, 82 + bob + arm_shift), fill=skin, width=10)
    if action == "hoe":
        draw.line((96, 82 + bob + arm_shift, 113, 35 + frame * 5), fill="#7a4b2d", width=5)
        draw.line((103, 35 + frame * 5, 121, 40 + frame * 5), fill=INK, width=6)
    elif action == "water":
        draw.rounded_rectangle((87, 68 + bob, 111, 91 + bob), radius=4, fill=BLUE, outline=INK, width=3)
        draw.line((106, 72 + bob, 121, 61 + bob), fill=BLUE, width=6)
        if frame > 0:
            for drop in range(3):
                draw.ellipse((116 - drop * 5, 76 + drop * 5, 120 - drop * 5, 83 + drop * 5), fill="#7faaa5")
    elif action == "harvest":
        draw.ellipse((92, 38 - frame * 3, 116, 61 - frame * 3), fill=PAPER, outline=INK, width=3)
        draw.line((104, 39 - frame * 3, 98, 28 - frame * 3), fill=GREEN, width=5)
    head_y = 32 + bob + (7 if tired else 0)
    draw.ellipse((42, head_y, 86, head_y + 43), fill=skin, outline=INK, width=4)
    if kind == "farmer":
        draw.polygon(((37, head_y + 5), (47, head_y - 16), (80, head_y - 14), (94, head_y + 5)), fill=GOLD, outline=INK)
        draw.line((31, head_y + 5, 100, head_y + 5), fill=GOLD, width=8)
        draw.line((31, head_y + 7, 100, head_y + 7), fill=INK, width=3)
    else:
        draw.arc((35, head_y - 11, 90, head_y + 36), 185, 355, fill="#ddd0b2", width=12)
        draw.ellipse((79, head_y - 4, 96, head_y + 13), fill="#ddd0b2", outline=INK, width=3)
        draw.ellipse((48, head_y + 14, 62, head_y + 26), outline=INK, width=3)
        draw.ellipse((68, head_y + 14, 82, head_y + 26), outline=INK, width=3)
        draw.line((62, head_y + 20, 68, head_y + 20), fill=INK, width=2)
    eye_y = head_y + (25 if tired else 21)
    if tired:
        draw.line((52, eye_y, 59, eye_y), fill=INK, width=3)
        draw.line((70, eye_y, 77, eye_y), fill=INK, width=3)
    else:
        draw.ellipse((53, eye_y, 58, eye_y + 6), fill=INK)
        draw.ellipse((71, eye_y, 76, eye_y + 6), fill=INK)
    draw.arc((57, head_y + 26, 73, head_y + 37), 15, 165, fill=INK, width=2)
    return _distress(image, (109 if kind == "farmer" else 307) + frame * 11 + len(action), 20)


def _make_characters() -> None:
    for kind in ("farmer", "merchant", "chicken"):
        sheet = Image.new("RGBA", (512, 768), (0, 0, 0, 0))
        for row, action in enumerate(("idle", "walk", "hoe", "water", "harvest", "tired")):
            for frame in range(4):
                sheet.alpha_composite(_actor_frame(kind, action, frame), (frame * 128, row * 128))
        name = f"characters/{kind}.png"
        _write_png(ASSETS / name, sheet)
        GENERATED_FILES.append(name)


def _crop_mask(kind: str, stage: str) -> Image.Image:
    mask = Image.new("L", (64, 64), 0)
    draw = ImageDraw.Draw(mask)
    if stage == "seed":
        draw.ellipse((21, 40, 43, 51), fill=255)
        return mask
    scale = {"sprout": 0.48, "growing": 0.74, "ripe": 1.0}[stage]
    draw.line((32, 53, 32, int(17 + 16 * (1 - scale))), fill=255, width=max(2, int(5 * scale)))
    draw.ellipse((32 - int(23 * scale), 21, 33, 37), fill=255)
    draw.ellipse((31, 15, 32 + int(23 * scale), 33), fill=255)
    if stage != "sprout":
        if kind == "turnip":
            draw.ellipse((15, 30, 49, 60), fill=255)
        elif kind == "carrot":
            draw.polygon(((16, 31), (49, 31), (30, 62)), fill=255)
        elif kind == "tomato":
            draw.ellipse((9, 35, 34, 59), fill=255)
            draw.ellipse((31, 28, 56, 52), fill=255)
        else:
            draw.rounded_rectangle((23, 19, 43, 59), radius=8, fill=255)
    return mask


def _make_crop(kind: str, stage: str) -> Image.Image:
    mask = _crop_mask(kind, stage)
    palettes = {
        "turnip": (INK, "#d7ba80", PAPER),
        "carrot": (INK, RED, GOLD),
        "tomato": (INK, RED, "#dc9c62"),
        "corn": (INK, GOLD, "#e7c879"),
    }
    texture = _woodcut_photo(f"{kind}_cc0.jpg", (64, 64), palettes[kind]).convert("RGBA")
    image = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    image.paste(texture, mask=mask)
    edge = mask.filter(ImageFilter.FIND_EDGES).point(lambda value: 255 if value > 18 else 0)
    image.paste(Image.new("RGBA", (64, 64), INK), mask=edge)
    if stage != "seed":
        draw = ImageDraw.Draw(image)
        draw.line((32, 52, 32, 19), fill=GREEN, width=3)
        draw.line((31, 35, 17, 27), fill=GREEN, width=4)
        draw.line((33, 30, 47, 21), fill=GREEN, width=4)
    return _distress(image, 701 + sum(map(ord, kind + stage)), 10)


def _make_crops() -> None:
    for kind in ("turnip", "carrot", "tomato", "corn"):
        for stage in ("seed", "sprout", "growing", "ripe"):
            name = f"crops/{kind}_{stage}.png"
            _write_png(ASSETS / name, _make_crop(kind, stage))
            GENERATED_FILES.append(name)


def _save_prop(name: str, image: Image.Image, seed: int) -> None:
    path = f"props/{name}.png"
    _write_png(ASSETS / path, _distress(image, seed, 24))
    GENERATED_FILES.append(path)


def _make_props() -> None:
    image = Image.new("RGBA", (244, 190), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((28, 78, 215, 168), fill=PAPER, outline=INK, width=6)
    draw.polygon(((10, 83), (121, 8), (234, 83), (217, 101), (121, 36), (28, 102)), fill=RED, outline=INK)
    for offset in range(3):
        draw.line((31, 79 - offset * 10, 121, 19 - offset * 3, 213, 80 - offset * 10), fill="#d38c54", width=4)
    draw.rounded_rectangle((96, 106, 143, 170), radius=18, fill=GREEN, outline=INK, width=5)
    for x in (48, 164):
        draw.rectangle((x, 106, x + 35, 139), fill=BLUE, outline=INK, width=4)
        draw.line((x + 17, 107, x + 17, 138), fill=PAPER, width=3)
        draw.line((x, 122, x + 35, 122), fill=PAPER, width=3)
    _save_prop("house", image, 41)

    image = Image.new("RGBA", (130, 140), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.ellipse((16, 77, 114, 128), fill="#9a6b42", outline=INK, width=5)
    draw.ellipse((22, 72, 108, 105), fill=BLUE, outline=INK, width=5)
    draw.line((32, 85, 32, 29), fill=INK, width=8)
    draw.line((98, 85, 98, 29), fill=INK, width=8)
    draw.polygon(((10, 37), (65, 5), (121, 37)), fill=RED, outline=INK)
    _save_prop("well", image, 43)

    image = Image.new("RGBA", (128, 112), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((13, 39, 115, 102), fill="#9a6037", outline=INK, width=5)
    draw.polygon(((14, 40), (34, 22), (104, 22), (115, 40)), fill=GOLD, outline=INK)
    for y in (58, 81):
        draw.line((17, y, 111, y), fill=INK, width=3)
    draw.rectangle((46, 52, 83, 84), fill=PAPER, outline=INK, width=3)
    draw.line((56, 75, 64, 59, 75, 74), fill=GREEN, width=4)
    _save_prop("shipping", image, 47)

    image = Image.new("RGBA", (234, 164), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((23, 57, 211, 145), fill="#9a6037", outline=INK, width=5)
    for index in range(6):
        x = 10 + index * 36
        draw.polygon(((x, 58), (x + 15, 14), (x + 35, 14), (x + 35, 58)), fill=PAPER if index % 2 == 0 else GREEN, outline=INK)
    draw.rectangle((50, 79, 182, 137), fill="#d6b56f", outline=INK, width=4)
    _save_prop("shop", image, 53)

    image = Image.new("RGBA", (176, 195), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.polygon(((67, 182), (77, 79), (106, 79), (111, 181)), fill="#70472f", outline=INK)
    for box in ((15, 42, 99, 117), (70, 21, 161, 105), (38, 4, 135, 87)):
        draw.ellipse(box, fill=GREEN, outline=INK, width=5)
    _save_prop("tree", image, 59)

    image = Image.new("RGBA", (128, 80), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.line((5, 33, 123, 33), fill="#7a4b2d", width=10)
    draw.line((5, 58, 123, 58), fill="#7a4b2d", width=10)
    for x in (15, 64, 113):
        draw.polygon(((x - 8, 73), (x - 8, 20), (x, 8), (x + 8, 20), (x + 8, 73)), fill=GOLD, outline=INK)
    _save_prop("fence", image, 61)


def _make_terrain() -> None:
    atlas = Image.new("RGB", (384, 64), PAPER)
    colors = ("#627643", "#c19958", "#8a5437", "#61402e", "#477479", "#7b8c4d")
    for tile_index, color in enumerate(colors):
        tile = Image.blend(_paper((64, 64), color), Image.new("RGB", (64, 64), color), 0.56)
        draw = ImageDraw.Draw(tile)
        if tile_index in (2, 3):
            for y in range(9, 64, 13):
                draw.line((3, y, 61, y + tile_index % 2), fill=INK, width=3)
        elif tile_index == 4:
            for y in (14, 34, 53):
                draw.arc((5, y - 6, 35, y + 7), 15, 165, fill="#b9c8ad", width=2)
        else:
            for index in range(9):
                x = (tile_index * 11 + index * 19) % 61
                y = (tile_index * 17 + index * 23) % 59
                draw.line((x, y, x + 4, y - 5), fill=INK, width=1)
        atlas.paste(tile, (tile_index * 64, 0))
    name = "tiles/terrain.png"
    _write_png(ASSETS / name, atlas)
    GENERATED_FILES.append(name)


def _make_backgrounds() -> None:
    far = _woodcut_photo("farm_cc0.jpg", (1280, 720), (INK, "#6b7551", PAPER)).convert("RGBA")
    far = Image.alpha_composite(far, Image.new("RGBA", far.size, "#d39a5538"))
    _write_png(ASSETS / "backgrounds/far.png", _distress(far, 79, 70))
    GENERATED_FILES.append("backgrounds/far.png")

    mid = Image.new("RGBA", (1280, 720), (0, 0, 0, 0))
    draw = ImageDraw.Draw(mid)
    draw.polygon(((0, 411), (194, 322), (403, 398), (643, 288), (872, 403), (1071, 317), (1280, 391), (1280, 720), (0, 720)), fill="#7f7b4f8c")
    for index in range(13):
        x = 35 + index * 101
        draw.line((x, 392 + index % 3 * 18, x, 458), fill=INK, width=5)
        draw.ellipse((x - 15, 365 + index % 3 * 18, x + 15, 413), fill="#486044", outline=INK, width=3)
    _write_png(ASSETS / "backgrounds/mid.png", _distress(mid, 83, 42))
    GENERATED_FILES.append("backgrounds/mid.png")

    near = Image.new("RGBA", (1280, 720), (0, 0, 0, 0))
    draw = ImageDraw.Draw(near)
    draw.polygon(((0, 625), (96, 579), (214, 682), (263, 720), (0, 720)), fill="#273e33cc")
    draw.polygon(((1017, 720), (1110, 604), (1280, 623), (1280, 720)), fill="#273e33cc")
    for x in (42, 112, 1174, 1248):
        draw.line((x, 716, x - 10, 659), fill=INK, width=4)
        draw.ellipse((x - 31, 640, x - 5, 688), fill=GREEN, outline=INK, width=2)
        draw.ellipse((x + 2, 635, x + 34, 684), fill=GREEN, outline=INK, width=2)
    _write_png(ASSETS / "backgrounds/near.png", _distress(near, 89, 25))
    GENERATED_FILES.append("backgrounds/near.png")

    title = _woodcut_photo("farm_cc0.jpg", (640, 580), (INK, GREEN, PAPER)).convert("RGBA")
    title.alpha_composite(Image.new("RGBA", title.size, "#7f32172c"))
    border = ImageDraw.Draw(title)
    for offset in range(6):
        border.rounded_rectangle((10 + offset, 10 + offset, 629 - offset, 569 - offset), radius=12, outline=INK, width=2)
    title.alpha_composite(_actor_frame("farmer", "water", 2).resize((218, 218), Image.Resampling.NEAREST), (388, 327))
    for index, crop in enumerate(("turnip", "carrot", "tomato", "corn")):
        title.alpha_composite(_make_crop(crop, "ripe").resize((90, 90), Image.Resampling.NEAREST), (55 + index * 112, 430))
    _write_png(ASSETS / "backgrounds/title.png", _distress(title, 97, 54))
    GENERATED_FILES.append("backgrounds/title.png")

    village = _paper((1280, 720), "#dfc28d").convert("RGBA")
    draw = ImageDraw.Draw(village)
    for offset in range(5):
        draw.rounded_rectangle((48 + offset, 44 + offset, 1231 - offset, 675 - offset), radius=23, outline=INK, width=2)
    draw.line((310, 472, 460, 380, 618, 429, 777, 302, 972, 233), fill="#8b3f2f", width=20, joint="curve")
    draw.line((310, 472, 460, 380, 618, 429, 777, 302, 972, 233), fill=PAPER, width=8, joint="curve")
    draw.ellipse((232, 411, 371, 548), fill=GREEN, outline=INK, width=7)
    draw.rectangle((267, 443, 336, 504), fill=PAPER, outline=INK, width=5)
    draw.polygon(((252, 447), (301, 407), (352, 447)), fill=RED, outline=INK)
    draw.ellipse((896, 158, 1046, 308), fill=RED, outline=INK, width=7)
    draw.rectangle((927, 211, 1012, 279), fill=GOLD, outline=INK, width=5)
    for index, (x, y) in enumerate(((460, 380), (618, 429), (777, 302))):
        draw.ellipse((x - 17, y - 17, x + 17, y + 17), fill=GOLD if index == 1 else GREEN, outline=INK, width=4)
    _write_png(ASSETS / "backgrounds/village_map.png", _distress(village, 101, 82))
    GENERATED_FILES.append("backgrounds/village_map.png")


def _make_ui() -> None:
    for name in ("hoe", "water", "seed", "hand"):
        image = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        if name == "hoe":
            draw.line((15, 55, 50, 10), fill="#794b2c", width=8)
            draw.polygon(((39, 9), (61, 26), (54, 34), (32, 15)), fill=INK)
        elif name == "water":
            draw.rounded_rectangle((9, 26, 44, 56), radius=6, fill=BLUE, outline=INK, width=4)
            draw.arc((12, 7, 43, 42), 180, 355, fill=INK, width=5)
            draw.line((42, 36, 58, 18), fill=BLUE, width=8)
        elif name == "seed":
            draw.polygon(((13, 13), (50, 13), (54, 57), (8, 57)), fill=GOLD, outline=INK)
            draw.line((32, 48, 32, 26), fill=GREEN, width=4)
            draw.ellipse((20, 27, 33, 38), fill=GREEN)
            draw.ellipse((31, 22, 46, 34), fill=GREEN)
        else:
            draw.polygon(((14, 53), (8, 37), (16, 31), (24, 39), (22, 14), (30, 10), (33, 31), (38, 12), (45, 15), (44, 36), (52, 29), (58, 35), (46, 57)), fill="#c68e65", outline=INK)
        path = f"ui/{name}.png"
        _write_png(ASSETS / path, _distress(image, 113 + len(name), 9))
        GENERATED_FILES.append(path)

    logo = Image.new("RGBA", (192, 144), (0, 0, 0, 0))
    draw = ImageDraw.Draw(logo)
    draw.ellipse((49, 6, 143, 100), fill=GOLD, outline=INK, width=6)
    draw.line((96, 124, 96, 55), fill=INK, width=7)
    draw.ellipse((36, 47, 95, 87), fill=GREEN, outline=INK, width=4)
    draw.ellipse((97, 51, 157, 92), fill=GREEN, outline=INK, width=4)
    draw.arc((25, 88, 168, 139), 5, 175, fill=INK, width=6)
    _write_png(ASSETS / "ui/logo.png", _distress(logo, 127, 18))
    GENERATED_FILES.append("ui/logo.png")


def generate_images() -> None:
    GENERATED_FILES.clear()
    _make_characters()
    _make_crops()
    _make_props()
    _make_terrain()
    _make_backgrounds()
    _make_ui()


def _write_wav(path: Path, samples: list[tuple[float, float]], rate: int = 22050) -> None:
    peak = max(max(abs(left), abs(right)) for left, right in samples) or 1.0
    gain = 0.72 / max(1.0, peak)
    payload = bytearray()
    for left, right in samples:
        payload.extend(struct.pack(
            "<hh",
            round(max(-1.0, min(1.0, left * gain)) * 32767),
            round(max(-1.0, min(1.0, right * gain)) * 32767),
        ))
    stream = io.BytesIO()
    with wave.open(stream, "wb") as output:
        output.setparams((2, 2, rate, 0, "NONE", "not compressed"))
        output.writeframes(payload)
    path.parent.mkdir(parents=True, exist_ok=True)
    contents = stream.getvalue()
    if not path.exists() or path.read_bytes() != contents:
        path.write_bytes(contents)


def _rural_ambience() -> list[tuple[float, float]]:
    rate = 22050
    seconds = 8
    samples: list[tuple[float, float]] = []
    for index in range(rate * seconds):
        time = index / rate
        breeze = (
            math.sin(math.tau * 137 * time)
            + 0.42 * math.sin(math.tau * 263 * time)
            + 0.28 * math.sin(math.tau * 521 * time)
        ) * (0.055 + 0.016 * math.sin(math.tau * 0.25 * time))
        brook_left = 0.025 * math.sin(math.tau * 631 * time)
        brook_right = 0.025 * math.sin(math.tau * 947 * time)
        bird = 0.0
        for onset, pitch in ((1.25, 1460.0), (4.55, 1780.0), (6.2, 1320.0)):
            local = time - onset
            if 0.0 <= local < 0.34:
                envelope = math.sin(math.pi * local / 0.34) ** 2
                bird += math.sin(math.tau * (pitch + local * 580.0) * local) * envelope * 0.13
        samples.append((breeze + brook_left + bird, breeze * 0.9 + brook_right + bird * 0.7))
    return samples


def _map_chime() -> list[tuple[float, float]]:
    rate = 22050
    samples: list[tuple[float, float]] = []
    for index in range(rate):
        time = index / rate
        envelope = min(1.0, time * 90.0) * math.exp(-time * 5.2)
        wooden = (
            math.sin(math.tau * 392.0 * time)
            + 0.38 * math.sin(math.tau * 1074.0 * time)
            + 0.17 * math.sin(math.tau * 2031.0 * time)
        ) * envelope * 0.42
        samples.append((wooden, wooden * 0.82))
    return samples


def generate_audio() -> None:
    GENERATED_AUDIO_FILES.clear()
    for name, samples in (("rural_ambience", _rural_ambience()), ("map", _map_chime())):
        relative = f"audio/{name}.wav"
        _write_wav(ASSETS / relative, samples)
        GENERATED_AUDIO_FILES.append(relative)


def _audio_report(directory: Path) -> tuple[list[dict[str, object]], list[str]]:
    reports: list[dict[str, object]] = []
    problems: list[str] = []
    for source in sorted((directory / "audio").glob("*.wav")):
        with wave.open(str(source), "rb") as stream:
            channels = stream.getnchannels()
            rate = stream.getframerate()
            frames = stream.getnframes()
            if (channels, stream.getsampwidth(), rate) != (2, 2, 22050) or frames == 0:
                problems.append(f"{source.name}: PCM形式・フレーム数が不正")
                continue
            samples = array.array("h", stream.readframes(frames))
        if sys.byteorder != "little":
            samples.byteswap()
        peak = max(abs(value) for value in samples) / 32768
        rms = math.sqrt(sum(value * value for value in samples) / len(samples)) / 32768
        clipped = sum(value <= -32768 or value >= 32767 for value in samples)
        reports.append({
            "file": source.name,
            "seconds": round(frames / rate, 5),
            "peak": round(peak, 6),
            "rms_dbfs": round(20 * math.log10(rms), 3) if rms else None,
            "clipped_samples": clipped,
        })
        if clipped or rms < 0.001:
            problems.append(f"{source.name}: クリッピングまたは無音を検出")
    return reports, problems


def _hashes(directory: Path, names: list[str]) -> dict[str, str]:
    return {name: hashlib.sha256((directory / name).read_bytes()).hexdigest() for name in sorted(names)}


def asset_counts(directory: Path) -> str:
    return (
        f"PNG {len(list(directory.rglob('*.png')))}枚 / "
        f"CC0写真 {len(list(directory.rglob('*.jpg')))}枚 / "
        f"WAV {len(list(directory.rglob('*.wav')))}本"
    )


def verify() -> None:
    global ASSETS
    original = ASSETS
    problems: list[str] = []
    if list(original.rglob("*.svg")):
        problems.append("assets に SVG が残っています")
    if not (original / "fonts" / "Yomogi-Regular.ttf").exists():
        problems.append("Yomogi-Regular.ttf がありません")
    if (original / "fonts" / "MPLUSRounded1c-Regular.ttf").exists():
        problems.append("禁止された M PLUS Rounded 1c が残っています")
    (ROOT / "tmp").mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="asset-verify-", dir=ROOT / "tmp") as temporary:
        temporary_assets = Path(temporary)
        shutil.copytree(original / "source_photos", temporary_assets / "source_photos")
        try:
            ASSETS = temporary_assets
            generate_images()
            generate_audio()
            expected_names = GENERATED_FILES.copy() + GENERATED_AUDIO_FILES.copy()
            regenerated_hashes = _hashes(temporary_assets, expected_names)
        finally:
            ASSETS = original
    missing = [name for name in expected_names if not (original / name).exists()]
    if missing:
        problems.append("生成済み素材が不足しています: " + ", ".join(missing))
    actual_hashes = _hashes(original, [name for name in expected_names if name not in missing])
    if actual_hashes != regenerated_hashes:
        problems.append("版画 PNG・生成音声の再生成 SHA-256 が一致しません")
    audio_reports, audio_problems = _audio_report(original)
    problems.extend(audio_problems)
    report_path = ROOT / "tmp" / "asset-verification.json"
    report_path.write_text(
        json.dumps({
            "counts": asset_counts(original),
            "generated_sha256": actual_hashes,
            "audio": audio_reports,
            "problems": problems,
        }, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    if problems:
        for problem in problems:
            print(f"素材検証失敗: {problem}", file=sys.stderr)
        raise SystemExit(1)
    print(f"素材検証 OK: PNG {len(GENERATED_FILES)}枚・生成音声 {len(GENERATED_AUDIO_FILES)}本の再生成一致 / 音声 {len(audio_reports)}本")
    print(f"検証記録: {report_path}")


def main() -> None:
    generate_images()
    generate_audio()
    print(f"版画素材生成 OK: {asset_counts(ASSETS)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--verify", action="store_true", help="PNGの再生成一致と既存WAVを検査する")
    mode.add_argument("--images-only", action="store_true", help="版画PNGだけを再生成する")
    arguments = parser.parse_args()
    if arguments.verify:
        verify()
    elif arguments.images_only:
        generate_images()
        print(f"版画PNG生成 OK: {asset_counts(ASSETS)}")
    else:
        main()
