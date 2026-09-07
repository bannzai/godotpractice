#!/usr/bin/env python3
"""CC0 原典と直接描画から monsterquest の4階調PNGを決定的に生成する。"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys
import zlib


GAME_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUT = GAME_ROOT / "assets" / "pixel"
SOURCE_DIR = DEFAULT_OUT / "source"
SOURCE_HASHES = {
    "spritesheet_58.png": "27e1d8a583a84a88b17e5e79a1b822ef0022ef3073da8dca84c76c51a545f890",
    "rpg_16x16_0.png": "edaf9cbd192f52778caa6c0818d050042ea8d3356a8a2f0d77b112d7c55c0e2d",
}

TRANSPARENT = (0, 0, 0, 0)
DARK = (15, 56, 15, 255)
MID = (48, 98, 48, 255)
LIGHT = (139, 172, 15, 255)
PALE = (155, 188, 15, 255)
ACCENT = (195, 66, 63, 255)
PALETTE = (DARK, MID, LIGHT, PALE)

ACTIONS = ("idle", "walk", "attack", "hurt", "defeat")
CHARACTERS = (
    "captain", "crab", "crab_captain", "ember", "healer",
    "moth", "owl", "player", "sprout", "tide",
)


def _paeth(left: int, up: int, upper_left: int) -> int:
    estimate = left + up - upper_left
    left_distance = abs(estimate - left)
    up_distance = abs(estimate - up)
    upper_left_distance = abs(estimate - upper_left)
    if left_distance <= up_distance and left_distance <= upper_left_distance:
        return left
    return up if up_distance <= upper_left_distance else upper_left


def read_png(path: Path) -> tuple[int, int, list[tuple[int, int, int, int]]]:
    """8 bit、非インターレースのRGBA/RGB/indexed PNGを標準ライブラリだけで読む。"""
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"PNGではありません: {path}")
    position = 8
    width = height = bit_depth = color_type = interlace = 0
    palette: list[tuple[int, int, int]] = []
    transparency = b""
    compressed = bytearray()
    while position < len(data):
        length = struct.unpack(">I", data[position:position + 4])[0]
        kind = data[position + 4:position + 8]
        payload = data[position + 8:position + 8 + length]
        position += 12 + length
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(
                ">IIBBBBB", payload
            )
        elif kind == b"PLTE":
            palette = [tuple(payload[index:index + 3]) for index in range(0, len(payload), 3)]
        elif kind == b"tRNS":
            transparency = payload
        elif kind == b"IDAT":
            compressed.extend(payload)
        elif kind == b"IEND":
            break
    if bit_depth != 8 or interlace != 0 or color_type not in (2, 3, 6):
        raise ValueError(f"未対応PNG形式: bit={bit_depth} color={color_type} interlace={interlace}")
    channels = {2: 3, 3: 1, 6: 4}[color_type]
    stride = width * channels
    raw = zlib.decompress(bytes(compressed))
    rows: list[bytearray] = []
    offset = 0
    previous = bytearray(stride)
    for _ in range(height):
        filter_type = raw[offset]
        encoded = raw[offset + 1:offset + 1 + stride]
        offset += stride + 1
        row = bytearray(stride)
        for index, value in enumerate(encoded):
            left = row[index - channels] if index >= channels else 0
            up = previous[index]
            upper_left = previous[index - channels] if index >= channels else 0
            if filter_type == 0:
                decoded = value
            elif filter_type == 1:
                decoded = value + left
            elif filter_type == 2:
                decoded = value + up
            elif filter_type == 3:
                decoded = value + ((left + up) // 2)
            elif filter_type == 4:
                decoded = value + _paeth(left, up, upper_left)
            else:
                raise ValueError(f"未対応PNGフィルタ: {filter_type}")
            row[index] = decoded & 0xFF
        rows.append(row)
        previous = row
    pixels: list[tuple[int, int, int, int]] = []
    for row in rows:
        for x in range(width):
            index = x * channels
            if color_type == 6:
                pixels.append(tuple(row[index:index + 4]))
            elif color_type == 2:
                pixels.append((*row[index:index + 3], 255))
            else:
                palette_index = row[index]
                red, green, blue = palette[palette_index]
                alpha = transparency[palette_index] if palette_index < len(transparency) else 255
                pixels.append((red, green, blue, alpha))
    return width, height, pixels


def _chunk(kind: bytes, payload: bytes) -> bytes:
    checksum = zlib.crc32(kind)
    checksum = zlib.crc32(payload, checksum)
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", checksum)


def png_bytes(width: int, height: int, pixels: list[tuple[int, int, int, int]]) -> bytes:
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for pixel in pixels[y * width:(y + 1) * width]:
            rows.extend(pixel)
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", header)
        + _chunk(b"IDAT", zlib.compress(bytes(rows), 9))
        + _chunk(b"IEND", b"")
    )


class Canvas:
    def __init__(self, width: int, height: int, color=TRANSPARENT) -> None:
        self.width = width
        self.height = height
        self.pixels = [color] * (width * height)

    def set(self, x: int, y: int, color) -> None:
        if 0 <= x < self.width and 0 <= y < self.height:
            self.pixels[y * self.width + x] = color

    def get(self, x: int, y: int):
        if 0 <= x < self.width and 0 <= y < self.height:
            return self.pixels[y * self.width + x]
        return TRANSPARENT

    def rect(self, x: int, y: int, width: int, height: int, color) -> None:
        for py in range(y, y + height):
            for px in range(x, x + width):
                self.set(px, py, color)

    def line(self, x0: int, y0: int, x1: int, y1: int, color, thickness: int = 1) -> None:
        delta_x = abs(x1 - x0)
        step_x = 1 if x0 < x1 else -1
        delta_y = -abs(y1 - y0)
        step_y = 1 if y0 < y1 else -1
        error = delta_x + delta_y
        while True:
            self.rect(x0 - thickness // 2, y0 - thickness // 2, thickness, thickness, color)
            if x0 == x1 and y0 == y1:
                return
            twice_error = 2 * error
            if twice_error >= delta_y:
                error += delta_y
                x0 += step_x
            if twice_error <= delta_x:
                error += delta_x
                y0 += step_y

    def circle(self, center_x: int, center_y: int, radius: int, color) -> None:
        for y in range(center_y - radius, center_y + radius + 1):
            for x in range(center_x - radius, center_x + radius + 1):
                if (x - center_x) ** 2 + (y - center_y) ** 2 <= radius ** 2:
                    self.set(x, y, color)

    def triangle(self, points: tuple[tuple[int, int], tuple[int, int], tuple[int, int]], color) -> None:
        (x1, y1), (x2, y2), (x3, y3) = points
        minimum_x, maximum_x = min(x1, x2, x3), max(x1, x2, x3)
        minimum_y, maximum_y = min(y1, y2, y3), max(y1, y2, y3)
        denominator = (y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3)
        if denominator == 0:
            return
        for y in range(minimum_y, maximum_y + 1):
            for x in range(minimum_x, maximum_x + 1):
                a = ((y2 - y3) * (x - x3) + (x3 - x2) * (y - y3)) / denominator
                b = ((y3 - y1) * (x - x3) + (x1 - x3) * (y - y3)) / denominator
                c = 1.0 - a - b
                if a >= 0 and b >= 0 and c >= 0:
                    self.set(x, y, color)

    def paste(self, other: "Canvas", x: int, y: int, flip_x: bool = False) -> None:
        for source_y in range(other.height):
            for source_x in range(other.width):
                color = other.get(source_x, source_y)
                if color[3] == 0:
                    continue
                target_x = other.width - source_x - 1 if flip_x else source_x
                self.set(x + target_x, y + source_y, color)


def quantize(red: int, green: int, blue: int, alpha: int):
    if alpha < 128:
        return TRANSPARENT
    luminance = (red * 299 + green * 587 + blue * 114) // 1000
    if luminance < 64:
        return DARK
    if luminance < 128:
        return MID
    if luminance < 192:
        return LIGHT
    return PALE


def source_sprite(
    source: tuple[int, int, list[tuple[int, int, int, int]]],
    crop: tuple[int, int, int, int],
    width: int,
    height: int,
    background: tuple[int, int, int] | None = None,
) -> Canvas:
    source_width, source_height, source_pixels = source
    crop_x, crop_y, crop_width, crop_height = crop
    result = Canvas(width, height)
    for y in range(height):
        source_y = crop_y + min(crop_height - 1, y * crop_height // height)
        for x in range(width):
            source_x = crop_x + min(crop_width - 1, x * crop_width // width)
            if not (0 <= source_x < source_width and 0 <= source_y < source_height):
                continue
            red, green, blue, alpha = source_pixels[source_y * source_width + source_x]
            if background is not None and (red, green, blue) == background:
                continue
            result.set(x, y, quantize(red, green, blue, alpha))
    return result


def movement(action: str, frame: int) -> tuple[int, int, int]:
    if action == "idle":
        return 0, (0, 0, -1, -1, 0, 0)[frame], frame % 2
    if action == "walk":
        return (0, 1, 0, -1, 0, 1)[frame], (0, -1, 0, -1, 0, -1)[frame], frame % 2
    if action == "attack":
        return (0, 1, 3, 4, 2, 0)[frame], (0, 0, -1, -1, 0, 0)[frame], frame % 2
    if action == "hurt":
        return (0, -2, 2, -2, 1, 0)[frame], (0, 1, 0, 1, 0, 0)[frame], frame % 2
    return 0, (0, 1, 2, 4, 7, 10)[frame], frame % 2


def draw_face(canvas: Canvas, x: int, y: int, action: str, frame: int, spread: int = 3) -> None:
    if (action == "idle" and frame == 4) or action in ("hurt", "defeat"):
        canvas.line(x - spread - 1, y, x - spread + 1, y, DARK)
        canvas.line(x + spread - 1, y, x + spread + 1, y, DARK)
    else:
        canvas.set(x - spread, y, DARK)
        canvas.set(x + spread, y, DARK)
    canvas.line(x - 1, y + 3, x + 1, y + 3, DARK)


def draw_monster(canvas: Canvas, name: str, action: str, frame: int) -> None:
    offset_x, offset_y, phase = movement(action, frame)
    x, y = 16 + offset_x, 16 + offset_y
    if name in ("crab", "crab_captain"):
        canvas.rect(x - 10, y + 4, 20, 9, MID)
        canvas.rect(x - 8, y + 2, 16, 8, LIGHT)
        claw_y = y - (2 if action == "attack" and frame in (2, 3) else 0)
        canvas.circle(x - 11, claw_y, 4, LIGHT)
        canvas.circle(x + 11, claw_y, 4, LIGHT)
        canvas.rect(x - 13, claw_y - 1, 4, 2, DARK)
        canvas.rect(x + 9, claw_y - 1, 4, 2, DARK)
        for leg in (-8, -3, 3, 8):
            canvas.line(x + leg, y + 12, x + leg + (-2 if leg < 0 else 2), y + 15, DARK)
        draw_face(canvas, x, y + 5, action, frame, 4)
        if name == "crab_captain":
            canvas.rect(x - 8, y - 4, 16, 4, DARK)
            canvas.rect(x - 5, y - 7, 10, 4, MID)
            canvas.set(x, y - 5, PALE)
    elif name == "ember":
        canvas.circle(x, y + 4, 9, LIGHT)
        canvas.triangle(((x - 8, y), (x - 6, y - 9), (x - 1, y - 2)), MID)
        canvas.triangle(((x + 8, y), (x + 6, y - 9), (x + 1, y - 2)), MID)
        tail_x = x - 10 + (phase * 2)
        canvas.circle(tail_x, y + 10, 5, MID)
        canvas.triangle(((tail_x - 5, y + 8), (tail_x - 9, y + 3), (tail_x - 6, y + 13)), PALE)
        canvas.rect(x - 6, y + 9, 12, 5, MID)
        draw_face(canvas, x, y + 3, action, frame)
    elif name == "tide":
        canvas.circle(x, y + 4, 9, MID)
        canvas.rect(x - 8, y, 16, 10, LIGHT)
        canvas.triangle(((x - 7, y + 1), (x - 13, y - 4 - phase), (x - 10, y + 7)), PALE)
        canvas.triangle(((x + 7, y + 1), (x + 13, y - 4 + phase), (x + 10, y + 7)), PALE)
        canvas.triangle(((x, y + 10), (x - 5, y + 16), (x + 6, y + 15)), LIGHT)
        draw_face(canvas, x, y + 3, action, frame)
        canvas.set(x - 7, y + 7, PALE)
        canvas.set(x + 7, y + 6, PALE)
    elif name == "sprout":
        canvas.circle(x, y + 6, 9, LIGHT)
        canvas.rect(x - 7, y + 9, 14, 7, MID)
        canvas.triangle(((x, y - 1), (x - 9, y - 10 - phase), (x - 4, y + 1)), MID)
        canvas.triangle(((x, y - 1), (x + 9, y - 11 + phase), (x + 4, y + 2)), PALE)
        canvas.line(x, y - 5, x, y + 1, DARK)
        draw_face(canvas, x, y + 5, action, frame)
    elif name == "moth":
        wing_y = y + (phase if action in ("idle", "walk") else 0)
        canvas.circle(x - 8, wing_y + 2, 7, LIGHT)
        canvas.circle(x + 8, wing_y + 2, 7, LIGHT)
        canvas.circle(x - 9, wing_y + 8, 5, MID)
        canvas.circle(x + 9, wing_y + 8, 5, MID)
        canvas.set(x - 9, wing_y + 2, PALE)
        canvas.set(x + 9, wing_y + 2, PALE)
        canvas.rect(x - 3, y - 2, 6, 18, PALE)
        canvas.line(x - 1, y - 2, x - 5, y - 8, DARK)
        canvas.line(x + 1, y - 2, x + 5, y - 8, DARK)
        draw_face(canvas, x, y + 3, action, frame, 1)
    elif name == "owl":
        canvas.circle(x, y + 5, 10, MID)
        canvas.triangle(((x - 8, y), (x - 7, y - 7), (x - 2, y - 2)), LIGHT)
        canvas.triangle(((x + 8, y), (x + 7, y - 7), (x + 2, y - 2)), LIGHT)
        canvas.circle(x - 4, y + 3, 4, PALE)
        canvas.circle(x + 4, y + 3, 4, PALE)
        draw_face(canvas, x, y + 3, action, frame, 4)
        canvas.triangle(((x, y + 6), (x - 2, y + 9), (x + 2, y + 9)), LIGHT)
        canvas.line(x - 6, y + 14, x - 9 + phase, y + 16, DARK)
        canvas.line(x + 6, y + 14, x + 9 - phase, y + 16, DARK)
    if action == "attack" and frame in (2, 3):
        canvas.line(25, 10 + frame, 30, 7 + frame, PALE)
        canvas.set(29, 8 + frame, DARK)
    if action == "hurt" and frame in (1, 3):
        canvas.set(3, 6, PALE)
        canvas.set(4, 5, PALE)
        canvas.set(4, 7, PALE)


def draw_human(
    canvas: Canvas,
    name: str,
    action: str,
    frame: int,
    tiny_source,
    rpg_source,
) -> None:
    offset_x, offset_y, phase = movement(action, frame)
    if name == "player":
        column = frame % 4 if action in ("idle", "walk") else 0
        sprite = source_sprite(
            tiny_source,
            (94 + column * 300, 44, 106, 156),
            18,
            25,
            (133, 199, 188),
        )
    else:
        group_x = 64 if name == "captain" else 128
        sprite = source_sprite(rpg_source, (group_x + (frame % 3) * 16, 0, 16, 24), 16, 24)
    if action == "defeat":
        offset_y += frame
    canvas.paste(sprite, 7 + offset_x, 4 + offset_y, action == "hurt" and frame % 2 == 1)
    center = 16 + offset_x
    if name == "player":
        canvas.rect(center - 7, 5 + offset_y, 14, 3, MID)
        canvas.rect(center - 5, 3 + offset_y, 10, 3, LIGHT)
        canvas.rect(center + 3, 18 + offset_y, 5, 6, PALE)
        canvas.line(center + 4, 19 + offset_y, center + 7, 22 + offset_y, DARK)
    elif name == "captain":
        canvas.rect(center - 7, 4 + offset_y, 14, 3, DARK)
        canvas.rect(center - 5, 2 + offset_y, 10, 3, MID)
        canvas.set(center, 3 + offset_y, PALE)
        canvas.line(center - 3, 13 + offset_y, center + 3, 13 + offset_y, DARK)
        canvas.set(center + 6, 18 + offset_y, PALE)
    else:
        canvas.rect(center - 7, 18 + offset_y, 14, 8, PALE)
        canvas.rect(center - 1, 19 + offset_y, 3, 6, MID)
        canvas.rect(center - 3, 21 + offset_y, 7, 2, MID)
        canvas.triangle(((center, 4 + offset_y), (center - 6, 9 + offset_y),
                         (center + 5, 9 + offset_y)), LIGHT)
    if action == "attack" and frame in (2, 3):
        canvas.line(center + 5, 16 + offset_y, center + 12, 10 + offset_y - phase, PALE, 2)


def build_character_sheet(name: str, tiny_source, rpg_source) -> Canvas:
    sheet = Canvas(32 * 6, 32 * 5)
    for row, action in enumerate(ACTIONS):
        for frame in range(6):
            cell = Canvas(32, 32)
            if name in ("player", "captain", "healer"):
                draw_human(cell, name, action, frame, tiny_source, rpg_source)
            else:
                draw_monster(cell, name, action, frame)
            sheet.paste(cell, frame * 32, row * 32)
    return sheet


def tile(name: str) -> Canvas:
    canvas = Canvas(16, 16, LIGHT)
    if name == "meadow":
        for x, y in ((2, 3), (7, 11), (12, 5), (14, 13), (4, 15)):
            canvas.set(x, y, MID)
            canvas.set(x - 1, y - 1, PALE)
    elif name == "path":
        canvas.rect(0, 0, 16, 16, PALE)
        for x, y in ((1, 3), (8, 1), (12, 7), (4, 11), (10, 14)):
            canvas.rect(x, y, 3, 2, LIGHT)
    elif name == "grass":
        canvas.rect(0, 0, 16, 16, MID)
        for x in (1, 5, 9, 13):
            canvas.line(x, 15, x + (1 if x % 3 else -1), 8, LIGHT)
            canvas.line(x + 2, 15, x + 3, 10, PALE)
    elif name == "hedge":
        canvas.rect(0, 0, 16, 16, DARK)
        for x, y in ((2, 3), (7, 2), (12, 4), (4, 10), (10, 11), (15, 9)):
            canvas.circle(x, y, 4, MID)
        for x, y in ((3, 2), (9, 5), (6, 12), (14, 10)):
            canvas.set(x, y, LIGHT)
    elif name == "water":
        canvas.rect(0, 0, 16, 16, MID)
        for y in (3, 9, 14):
            canvas.line(0, y, 5, y, LIGHT)
            canvas.line(8, y + 1, 14, y + 1, PALE)
    else:
        canvas.rect(0, 0, 16, 16, PALE)
        for y in (0, 5, 10, 15):
            canvas.line(0, y, 15, y, MID)
        canvas.line(5, 0, 5, 5, LIGHT)
        canvas.line(11, 5, 11, 10, LIGHT)
        canvas.line(4, 10, 4, 15, LIGHT)
    return canvas


def world_prop(name: str) -> Canvas:
    sizes = {
        "home": (80, 64), "clinic": (80, 64), "flowers": (32, 16),
        "room_walls": (320, 180), "canopy_shadow": (320, 180), "pollen": (4, 4),
        "lily": (16, 16), "bench": (32, 16), "sign": (64, 24), "bed": (64, 32),
        "storage_shelf": (64, 40), "healing_table": (64, 40), "rug": (96, 48),
        "captain_plaza": (64, 32),
    }
    width, height = sizes[name]
    canvas = Canvas(width, height)
    if name in ("home", "clinic"):
        canvas.rect(8, 22, width - 16, height - 25, PALE if name == "home" else LIGHT)
        roof = MID if name == "home" else DARK
        for y in range(18):
            canvas.rect(5 + y // 2, 21 - y, width - 10 - y, 1, roof)
        canvas.rect(width // 2 - 6, height - 24, 12, 21, DARK)
        canvas.rect(15, 31, 14, 12, LIGHT if name == "home" else PALE)
        canvas.rect(width - 29, 31, 14, 12, LIGHT if name == "home" else PALE)
        if name == "clinic":
            canvas.rect(width // 2 - 2, 4, 5, 15, PALE)
            canvas.rect(width // 2 - 7, 9, 15, 5, PALE)
    elif name == "flowers":
        for x, y in ((4, 7), (10, 4), (16, 9), (23, 5), (28, 10)):
            canvas.line(x, y, x, 15, MID)
            canvas.circle(x, y, 2, PALE)
            canvas.set(x, y, DARK)
    elif name == "room_walls":
        canvas.rect(0, 0, width, height, MID)
        canvas.rect(24, 24, width - 48, height - 48, TRANSPARENT)
        for x in range(24, width - 24, 16):
            canvas.rect(x, 20, 8, 4, LIGHT)
        canvas.rect(width // 2 - 12, height - 24, 24, 24, TRANSPARENT)
    elif name == "canopy_shadow":
        for x, y, radius in ((12, 8, 35), (72, 2, 28), (300, 12, 42),
                             (15, 170, 40), (306, 165, 46)):
            canvas.circle(x, y, radius, DARK)
    elif name == "pollen":
        canvas.set(1, 1, PALE)
        canvas.set(2, 1, LIGHT)
        canvas.set(1, 2, LIGHT)
    elif name == "lily":
        canvas.circle(8, 9, 6, MID)
        canvas.triangle(((8, 9), (15, 5), (15, 12)), TRANSPARENT)
        canvas.circle(8, 7, 3, PALE)
        canvas.set(8, 7, DARK)
    elif name == "bench":
        canvas.rect(3, 3, 26, 4, LIGHT)
        canvas.rect(2, 9, 28, 4, PALE)
        canvas.rect(5, 13, 3, 3, DARK)
        canvas.rect(24, 13, 3, 3, DARK)
    elif name == "sign":
        canvas.rect(2, 2, 60, 14, PALE)
        canvas.rect(4, 4, 56, 2, LIGHT)
        canvas.rect(30, 16, 4, 8, DARK)
    elif name == "bed":
        canvas.rect(2, 5, 60, 25, DARK)
        canvas.rect(5, 7, 56, 20, LIGHT)
        canvas.rect(7, 8, 16, 18, PALE)
        canvas.rect(26, 8, 34, 18, MID)
    elif name == "storage_shelf":
        canvas.rect(2, 2, 60, 36, DARK)
        for row in range(2):
            for column in range(4):
                x, y = 6 + column * 14, 6 + row * 15
                canvas.rect(x, y, 10, 10, PALE)
                canvas.rect(x + 2, y + 3, 6, 4, MID)
    elif name == "healing_table":
        canvas.rect(2, 10, 60, 26, LIGHT)
        canvas.rect(6, 14, 52, 18, PALE)
        canvas.rect(29, 15, 6, 16, MID)
        canvas.rect(24, 20, 16, 6, MID)
    elif name == "rug":
        canvas.rect(1, 1, 94, 46, MID)
        canvas.rect(5, 5, 86, 38, LIGHT)
        canvas.rect(9, 9, 78, 30, PALE)
        canvas.triangle(((48, 10), (66, 24), (48, 38)), MID)
        canvas.triangle(((48, 10), (30, 24), (48, 38)), MID)
    elif name == "captain_plaza":
        canvas.rect(1, 1, 62, 30, LIGHT)
        canvas.rect(5, 5, 54, 22, PALE)
        canvas.circle(32, 16, 9, MID)
        canvas.line(32, 9, 32, 23, LIGHT)
        canvas.line(25, 16, 39, 16, LIGHT)
    return canvas


def ui_icon(name: str) -> Canvas:
    if name == "logo":
        canvas = Canvas(96, 48)
        canvas.rect(8, 9, 80, 30, DARK)
        canvas.rect(11, 12, 74, 24, PALE)
        canvas.rect(16, 16, 64, 16, MID)
        canvas.triangle(((48, 5), (39, 18), (57, 18)), LIGHT)
        canvas.line(20, 40, 76, 40, LIGHT, 2)
        return canvas
    canvas = Canvas(16, 16)
    if name == "cursor":
        canvas.triangle(((2, 1), (2, 14), (14, 8)), PALE)
        canvas.triangle(((4, 4), (4, 11), (11, 8)), DARK)
    elif name == "capture_ball":
        canvas.circle(8, 8, 7, DARK)
        canvas.circle(8, 8, 5, PALE)
        canvas.rect(2, 6, 12, 4, MID)
        canvas.circle(8, 8, 2, PALE)
    elif name == "potion":
        canvas.rect(6, 1, 5, 4, PALE)
        canvas.rect(4, 5, 9, 10, DARK)
        canvas.rect(6, 7, 5, 6, LIGHT)
        canvas.set(7, 8, PALE)
    elif name == "emblem":
        canvas.circle(8, 8, 7, DARK)
        canvas.circle(8, 8, 5, LIGHT)
        canvas.line(8, 3, 8, 13, PALE)
        canvas.line(3, 8, 13, 8, PALE)
    elif name == "type_fire":
        canvas.triangle(((9, 1), (3, 11), (8, 15)), MID)
        canvas.triangle(((9, 1), (13, 10), (8, 15)), LIGHT)
        canvas.triangle(((8, 7), (6, 12), (9, 14)), PALE)
    elif name == "type_water":
        canvas.triangle(((8, 1), (2, 10), (14, 10)), MID)
        canvas.circle(8, 10, 6, LIGHT)
        canvas.line(5, 10, 8, 13, PALE)
    else:
        canvas.triangle(((8, 14), (2, 4), (9, 7)), MID)
        canvas.triangle(((8, 14), (14, 3), (9, 7)), LIGHT)
        canvas.line(8, 13, 9, 5, PALE)
    return canvas


def effect(name: str) -> Canvas:
    canvas = Canvas(16, 16)
    if name == "spark":
        canvas.line(8, 0, 8, 15, ACCENT, 2)
        canvas.line(0, 8, 15, 8, PALE, 2)
        canvas.line(3, 3, 13, 13, ACCENT)
        canvas.line(13, 3, 3, 13, PALE)
    elif name == "projectile_fire":
        canvas.triangle(((9, 1), (3, 10), (8, 15)), ACCENT)
        canvas.triangle(((9, 1), (14, 10), (8, 15)), LIGHT)
        canvas.rect(7, 8, 3, 5, PALE)
    elif name == "projectile_water":
        canvas.triangle(((8, 1), (2, 10), (14, 10)), MID)
        canvas.circle(8, 10, 6, LIGHT)
        canvas.rect(5, 9, 3, 3, PALE)
    else:
        canvas.triangle(((8, 15), (2, 4), (9, 7)), MID)
        canvas.triangle(((8, 15), (14, 3), (9, 7)), PALE)
        canvas.line(8, 14, 9, 5, DARK)
    return canvas


def background(name: str) -> Canvas:
    canvas = Canvas(329, 180)
    if name == "forest_far":
        canvas.rect(0, 0, 329, 180, PALE)
        canvas.circle(236, 34, 17, LIGHT)
        for x in range(0, 329, 3):
            height = 64 + ((x * 17) % 37)
            canvas.line(x, 120, x + 18, height, LIGHT)
        canvas.rect(0, 120, 329, 60, MID)
        canvas.line(112, 180, 204, 116, PALE, 8)
    elif name == "forest_mid":
        for x in range(0, 329, 23):
            trunk_height = 48 + (x * 7) % 37
            canvas.rect(x + 8, 180 - trunk_height, 5, trunk_height, DARK)
            canvas.circle(x + 10, 180 - trunk_height, 18, MID)
            canvas.circle(x + 2, 177 - trunk_height, 11, LIGHT)
        canvas.rect(0, 158, 329, 22, MID)
    else:
        for x, side in ((0, 1), (328, -1)):
            canvas.rect(x if side > 0 else x - 10, 0, 11, 180, DARK)
            for y in range(0, 180, 17):
                canvas.circle(x + side * 10, y, 13, MID)
                canvas.circle(x + side * 15, y + 4, 8, LIGHT)
        canvas.rect(0, 169, 329, 11, DARK)
    return canvas


def title_keyart(assets: dict[str, Canvas]) -> Canvas:
    canvas = Canvas(160, 143, PALE)
    canvas.circle(112, 24, 13, LIGHT)
    canvas.rect(0, 82, 160, 61, LIGHT)
    canvas.triangle(((49, 143), (82, 70), (111, 143)), PALE)
    canvas.line(78, 143, 85, 78, LIGHT, 3)
    for x, y, radius in ((4, 25, 29), (28, 13, 22), (151, 31, 32), (137, 4, 24)):
        canvas.rect(max(0, x - 3), y, 6, 118 - y, DARK)
        canvas.circle(x, y, radius, MID)
        canvas.circle(x + 5, y - 3, max(3, radius - 8), LIGHT)
    canvas.rect(9, 76, 42, 20, DARK)
    canvas.rect(12, 79, 36, 14, PALE)
    canvas.line(30, 95, 30, 114, DARK, 3)
    canvas.line(16, 84, 44, 84, LIGHT, 2)
    for sprite_name, at in (
        ("ember", (21, 105)),
        ("player", (61, 86)),
        ("sprout", (99, 104)),
        ("tide", (126, 96)),
    ):
        sheet = assets[f"characters/{sprite_name}.png"]
        frame = Canvas(32, 32)
        for y in range(32):
            for x in range(32):
                frame.set(x, y, sheet.get(x, y))
        canvas.paste(frame, *at)
    for x, y in ((57, 16), (77, 29), (93, 11), (124, 45), (47, 54)):
        canvas.set(x, y, DARK)
        canvas.set(x + 1, y, DARK)
        canvas.set(x, y + 1, DARK)
    return canvas


def region_map() -> Canvas:
    canvas = Canvas(320, 180, DARK)
    canvas.rect(8, 8, 304, 164, PALE)
    canvas.rect(14, 14, 292, 152, LIGHT)
    canvas.rect(31, 34, 258, 108, MID)
    for x, y, radius in ((40, 40, 20), (278, 43, 25), (45, 135, 24), (276, 132, 24)):
        canvas.circle(x, y, radius, DARK)
        canvas.circle(x, y, radius - 4, MID)
    points = ((62, 98), (96, 86), (132, 105), (168, 80), (211, 94), (258, 72))
    for start, end in zip(points, points[1:]):
        canvas.line(*start, *end, PALE, 5)
        canvas.line(*start, *end, LIGHT, 2)
    for index, (x, y) in enumerate(points):
        canvas.circle(x, y, 7, DARK)
        canvas.circle(x, y, 4, PALE if index in (0, len(points) - 1) else LIGHT)
    canvas.rect(51, 106, 24, 18, DARK)
    canvas.triangle(((49, 107), (63, 94), (77, 107)), LIGHT)
    canvas.rect(250, 47, 17, 23, DARK)
    canvas.rect(254, 51, 9, 15, LIGHT)
    return canvas


def build_assets(tiny_source, rpg_source) -> dict[str, Canvas]:
    assets: dict[str, Canvas] = {}
    for name in CHARACTERS:
        assets[f"characters/{name}.png"] = build_character_sheet(name, tiny_source, rpg_source)
    for name in ("forest_far", "forest_mid", "forest_near"):
        assets[f"backgrounds/{name}.png"] = background(name)
    assets["backgrounds/title_keyart.png"] = title_keyart(assets)
    for name in ("meadow", "path", "grass", "hedge", "water", "wood"):
        assets[f"world/tile_{name}.png"] = tile(name)
    for name in (
        "home", "clinic", "flowers", "room_walls", "canopy_shadow", "pollen", "lily",
        "bench", "sign", "bed", "storage_shelf", "healing_table", "rug", "captain_plaza",
    ):
        assets[f"world/{name}.png"] = world_prop(name)
    assets["world/region_map.png"] = region_map()
    for name in (
        "capture_ball", "cursor", "emblem", "logo", "potion",
        "type_fire", "type_water", "type_leaf",
    ):
        assets[f"ui/{name}.png"] = ui_icon(name)
    for name in ("projectile_fire", "projectile_water", "projectile_leaf", "spark"):
        assets[f"effects/{name}.png"] = effect(name)
    return assets


def check_sources() -> None:
    for filename, expected_hash in SOURCE_HASHES.items():
        path = SOURCE_DIR / filename
        if not path.is_file():
            raise ValueError(f"CC0原典がありません: {path}")
        actual_hash = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual_hash != expected_hash:
            raise ValueError(f"CC0原典のSHA-256不一致: {path}")


def load_sources():
    check_sources()
    return read_png(SOURCE_DIR / "spritesheet_58.png"), read_png(SOURCE_DIR / "rpg_16x16_0.png")


def write_if_changed(path: Path, data: bytes) -> bool:
    if path.is_file() and path.read_bytes() == data:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return True


def validate(out_dir: Path, assets: dict[str, Canvas]) -> None:
    failures: list[str] = []
    for relative_path, expected in assets.items():
        path = out_dir / relative_path
        if not path.is_file():
            failures.append(f"missing {relative_path}")
            continue
        try:
            width, height, pixels = read_png(path)
        except ValueError as error:
            failures.append(f"invalid {relative_path}: {error}")
            continue
        if (width, height) != (expected.width, expected.height):
            failures.append(f"size {relative_path}: {width}x{height}")
        allowed = set(PALETTE) | {TRANSPARENT}
        if relative_path.startswith("effects/"):
            allowed.add(ACCENT)
        unexpected = set(pixels) - allowed
        if unexpected:
            failures.append(f"palette {relative_path}: {sorted(unexpected)[:3]}")
        if path.read_bytes() != png_bytes(expected.width, expected.height, expected.pixels):
            failures.append(f"reproducibility {relative_path}")
    if failures:
        raise ValueError("\n".join(failures))


def print_spec(assets: dict[str, Canvas]) -> None:
    print(json.dumps({
        "palette": ["#0F380F", "#306230", "#8BAC0F", "#9BBC0F"],
        "battle_accent": "#C3423F",
        "sources": SOURCE_HASHES,
        "images": [
            {"path": path, "width": image.width, "height": image.height}
            for path, image in sorted(assets.items())
        ],
    }, ensure_ascii=False, indent=2))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--print-spec", action="store_true")
    arguments = parser.parse_args()
    try:
        tiny_source, rpg_source = load_sources()
        assets = build_assets(tiny_source, rpg_source)
        if arguments.print_spec:
            print_spec(assets)
            return 0
        if arguments.check:
            validate(arguments.out_dir, assets)
            print(f"ピクセル素材検査 OK: {len(assets)} PNG、4階調・寸法・再生成一致")
            return 0
        changed = 0
        for relative_path, canvas in assets.items():
            changed += int(write_if_changed(
                arguments.out_dir / relative_path,
                png_bytes(canvas.width, canvas.height, canvas.pixels),
            ))
        print(f"ピクセル素材生成 OK: {len(assets)} PNG（更新 {changed}、変更なし {len(assets)-changed}）")
        return 0
    except (OSError, ValueError, zlib.error) as error:
        print(f"ピクセル素材生成 FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
