#!/usr/bin/env python3
"""CC0の16px原画から「灯守の島」のピクセルアセットを決定的に生成する。"""

from __future__ import annotations

import hashlib
import io
import json
from pathlib import Path
from typing import Iterable
from zipfile import ZipFile

from PIL import Image, ImageDraw


ASSETS = Path(__file__).resolve().parents[2] / "assets"
SOURCES = ASSETS / "source"
TRANSPARENT = (0, 0, 0, 0)
NEAREST = Image.Resampling.NEAREST

# 1枚の出力が使う色は、透過を除き必ず対応する4〜8色の中に収める。
PALETTES = {
    "coast": (
        "#102a36",
        "#244957",
        "#36727a",
        "#5d9b8b",
        "#93c6a3",
        "#d6d7a7",
        "#e8b76b",
        "#fff0bd",
    ),
    "forest": (
        "#142c32",
        "#29483c",
        "#3f674c",
        "#66865b",
        "#8fac72",
        "#c6c184",
        "#d59662",
        "#f0dfad",
    ),
    "ruins": (
        "#182735",
        "#344252",
        "#53616a",
        "#768078",
        "#9da28c",
        "#c4c49f",
        "#d39b60",
        "#f2d99b",
    ),
    "ember": (
        "#261d2e",
        "#493047",
        "#71414e",
        "#9d594f",
        "#c77b58",
        "#e8a866",
        "#f1d28a",
        "#fff0bc",
    ),
    "title": (
        "#0b1c2d",
        "#17374a",
        "#285869",
        "#3d7b78",
        "#70a887",
        "#b8c594",
        "#e0ad62",
        "#f7e3a1",
    ),
}

PALETTE_PURPOSES = {
    "coast": "海岸・水路・旅人。青緑を中心に、灯りの琥珀色をアクセントにする。",
    "forest": "森・草地・集落。暗い常緑色から乾いた葉色までを使う。",
    "ruins": "石造遺跡・構造物。青灰色の石と古い金属色を使う。",
    "ember": "強敵・危険物。暗い紫褐色と赤熱した橙色を使う。",
    "title": "タイトル画面・主人公キービジュアル。夜の藍、翡翠、灯りの金色を使う。",
}

CHARACTERS = {
    "hero": ("Puny-Characters/Warrior-Blue.png", "title"),
    "wanderer": ("Puny-Characters/Mage-Cyan.png", "coast"),
    "charger": ("Puny-Characters/Orc-Grunt.png", "ember"),
    "ranger": ("Puny-Characters/Archer-Green.png", "forest"),
    "splitter": ("Puny-Characters/Slime.png", "ruins"),
    "boss": ("Puny-Characters/Orc-Soldier-Red.png", "ember"),
    "villager": ("Puny-Characters/Human-Worker-Cyan.png", "forest"),
    "merchant": ("Puny-Characters/Human-Worker-Red.png", "coast"),
}

# Puny Characters は32pxセル（像はおよそ16px）で、列方向に動作フレーム、
# 行方向に8方位を収録する。ゲーム側の5動作へ対応する列だけを使う。
MOTION_COLUMNS = (
    (0, 0, 0, 0),  # idle
    (0, 1, 2, 3),  # walk
    (6, 7, 8, 9),  # action
    (18, 19, 20, 21),  # hurt
    (22, 23, 22, 23),  # defeat
)
SLIME_MOTION_COLUMNS = (
    (0, 0, 0, 0),
    (0, 1, 2, 3),
    (4, 5, 6, 7),
    (8, 9, 10, 11),
    (12, 13, 14, 14),
)

# source は "overworld" または "dungeon"。4セル中3セルをOverworld、
# 石床をDungeon由来にして、両タイルセットの主要形状を明確に使う。
TERRAIN = (
    ("grass", "overworld", (0, 0, 16, 16), "forest"),
    ("water", "overworld", (0, 160, 16, 176), "coast"),
    ("stone", "dungeon", (0, 0, 16, 16), "ruins"),
    ("earth", "overworld", (48, 0, 64, 16), "ember"),
)

PROPS = {
    "chest": ("overworld", (32, 464, 48, 480), "ember"),
    "grass": ("overworld", (0, 496, 16, 512), "forest"),
    "rock": ("overworld", (0, 64, 16, 80), "ruins"),
    "block": ("dungeon", (0, 0, 16, 16), "ruins"),
    "switch": ("dungeon", (320, 128, 336, 144), "ruins"),
    "door": ("dungeon", (0, 80, 32, 112), "ruins"),
    "heart": ("dungeon", (384, 128, 400, 144), "ember"),
    "coin": ("overworld", (16, 464, 32, 480), "title"),
    "key": ("dungeon", (320, 128, 336, 144), "title"),
    "boomerang": ("dungeon", (272, 96, 288, 112), "coast"),
    "bomb": ("dungeon", (352, 128, 368, 144), "ember"),
    "potion": ("overworld", (0, 400, 16, 416), "coast"),
    "treasure": ("overworld", (48, 464, 64, 480), "title"),
}

SCENERY = {
    "tree": ("overworld", (0, 112, 48, 160), "forest"),
    "lily": ("overworld", (0, 496, 16, 512), "coast"),
    "arch": ("dungeon", (0, 80, 64, 128), "ruins"),
    "column": ("dungeon", (336, 240, 368, 288), "ruins"),
    "crystals": ("dungeon", (256, 144, 320, 192), "coast"),
    "house": ("overworld", (64, 416, 96, 448), "forest"),
    "ruins": ("dungeon", (0, 0, 64, 64), "ruins"),
    "stall": ("overworld", (144, 480, 192, 512), "ember"),
}


def rgb(hex_color: str) -> tuple[int, int, int]:
    """#rrggbbをRGBへ変換する。"""
    value = hex_color.removeprefix("#")
    return tuple(int(value[index : index + 2], 16) for index in (0, 2, 4))


def colors(name: str) -> tuple[tuple[int, int, int], ...]:
    """名前付きパレットをRGBで返す。"""
    return tuple(rgb(value) for value in PALETTES[name])


def rgba(name: str, index: int, alpha: int = 255) -> tuple[int, int, int, int]:
    """名前付きパレットの1色をRGBAで返す。"""
    return (*colors(name)[index], alpha)


def validate_source(path: Path, expected_size: tuple[int, int]) -> Image.Image:
    """入力の存在と寸法を検査し、RGBA画像として返す。"""
    if not path.is_file():
        raise FileNotFoundError(f"入力素材がありません: {path}")
    image = Image.open(path).convert("RGBA")
    if image.size != expected_size:
        raise ValueError(f"{path.name}: expected {expected_size}, got {image.size}")
    return image


def load_character_sources(path: Path) -> dict[str, Image.Image]:
    """Puny Charactersを展開せずZIPから読み、収録寸法を検査する。"""
    if not path.is_file():
        raise FileNotFoundError(f"入力素材がありません: {path}")
    images: dict[str, Image.Image] = {}
    with ZipFile(path) as archive:
        available = set(archive.namelist())
        for member in sorted({member for member, _palette in CHARACTERS.values()}):
            if member not in available:
                raise FileNotFoundError(f"{path.name} に {member} がありません")
            with archive.open(member) as source_file:
                image = Image.open(io.BytesIO(source_file.read())).convert("RGBA")
            expected = (480, 32) if member.endswith("/Slime.png") else (768, 256)
            if image.size != expected:
                raise ValueError(f"{member}: expected {expected}, got {image.size}")
            images[member] = image
    return images


def recolor(image: Image.Image, palette_name: str) -> Image.Image:
    """透明領域を保ち、可視ピクセルを指定した8色の不透明色へ写像する。"""
    palette = colors(palette_name)
    result = Image.new("RGBA", image.size, TRANSPARENT)
    converted: list[tuple[int, int, int, int]] = []
    for red, green, blue, alpha in image.get_flattened_data():
        if alpha == 0:
            converted.append(TRANSPARENT)
            continue
        # 輝度の差を強めに評価し、元の陰影と輪郭を保ちながら色相を地域色へ寄せる。
        source_luma = red * 3 + green * 6 + blue
        mapped = min(
            palette,
            key=lambda candidate: (
                (source_luma - (candidate[0] * 3 + candidate[1] * 6 + candidate[2])) ** 2
                + (red - candidate[0]) ** 2
                + (green - candidate[1]) ** 2
                + (blue - candidate[2]) ** 2
            ),
        )
        converted.append((*mapped, 255))
    result.putdata(converted)
    return result


def crop_recolored(
    image: Image.Image,
    box: tuple[int, int, int, int],
    palette_name: str,
) -> Image.Image:
    """原画をピクセル境界で切り出し、固定パレットへ再着色する。"""
    return recolor(image.crop(box), palette_name)


def paste_centered(
    canvas: Image.Image,
    source: Image.Image,
    cell_box: tuple[int, int, int, int],
    scale: int | None = None,
    offset: tuple[int, int] = (0, 0),
) -> None:
    """整数倍の最近傍拡大で、画像をセル中央へ合成する。"""
    left, top, right, bottom = cell_box
    cell_width = right - left
    cell_height = bottom - top
    if scale is None:
        scale = max(1, min(cell_width // source.width, cell_height // source.height))
    enlarged = source.resize((source.width * scale, source.height * scale), NEAREST)
    x = left + (cell_width - enlarged.width) // 2 + offset[0]
    y = top + (cell_height - enlarged.height) // 2 + offset[1]
    canvas.alpha_composite(enlarged, (x, y))


def save_png(path: Path, image: Image.Image) -> bool:
    """バイト列が変わった時だけPNGを更新する。"""
    path.parent.mkdir(parents=True, exist_ok=True)
    buffer = io.BytesIO()
    image.save(buffer, format="PNG", optimize=False, compress_level=9)
    payload = buffer.getvalue()
    if path.is_file() and path.read_bytes() == payload:
        return False
    path.write_bytes(payload)
    return True


def generate_characters(sources: dict[str, Image.Image]) -> dict[str, dict[str, object]]:
    """8体の56pxセル・4列×5動作のスプライトシートを生成する。"""
    records: dict[str, dict[str, object]] = {}
    for name, (member, palette_name) in CHARACTERS.items():
        source = sources[member]
        motion_columns = SLIME_MOTION_COLUMNS if member.endswith("/Slime.png") else MOTION_COLUMNS
        sheet = Image.new("RGBA", (224, 280), TRANSPARENT)
        for motion, source_columns in enumerate(motion_columns):
            for frame_index, source_column in enumerate(source_columns):
                # 32pxセルの中央24pxを切り出す。攻撃時の武器を残しつつ、
                # 56pxセルへ2倍で収まる最大の整数倍率になる。
                box = (source_column * 32 + 4, 4, source_column * 32 + 28, 28)
                frame = crop_recolored(source, box, palette_name)
                paste_centered(
                    sheet,
                    frame,
                    (frame_index * 56, motion * 56, (frame_index + 1) * 56, (motion + 1) * 56),
                    scale=2,
                )
        relative_path = f"characters/{name}.png"
        save_png(ASSETS / relative_path, sheet)
        records[relative_path] = {
            "size": [224, 280],
            "palette": palette_name,
            "source": "source/puny-charactersorcs_included.zip",
            "source_member": member,
            "source_frame_size": [32, 32],
            "source_subject_bounds": [4, 4, 28, 28],
            "transform": (
                "24px center crop from 32px cells; palette mapping; "
                "2x nearest-neighbor; centered in 56px cells"
            ),
            "layout": {"columns": 4, "motions": ["idle", "walk", "action", "hurt", "defeat"]},
        }
    return records


def generate_terrain(sources: dict[str, Image.Image]) -> dict[str, dict[str, object]]:
    """草地・水・石床・土の4タイルを横一列に生成する。"""
    sheet = Image.new("RGBA", (224, 56), TRANSPARENT)
    cells = []
    for index, (name, source_name, box, palette_name) in enumerate(TERRAIN):
        tile = crop_recolored(sources[source_name], box, palette_name).resize((56, 56), NEAREST)
        sheet.alpha_composite(tile, (index * 56, 0))
        cells.append(
            {
                "name": name,
                "source": source_path(source_name),
                "source_crop": list(box),
                "palette": palette_name,
            }
        )
    relative_path = "terrain/tiles.png"
    save_png(ASSETS / relative_path, sheet)
    return {
        relative_path: {
            "size": [224, 56],
            "palettes": [entry[3] for entry in TERRAIN],
            "sources": [
                "source/punyworld-overworld-tileset_0.png",
                "source/punyworld-dungeon-tileset.png",
            ],
            "cells": cells,
            "transform": "16px crops; palette mapping; nearest-neighbor resize to 56px",
        }
    }


def add_prop_details(image: Image.Image, name: str, palette_name: str) -> None:
    """原画にない道具だけ、固定パレットの最小限の記号を重ねる。"""
    draw = ImageDraw.Draw(image)
    if name == "heart":
        draw.polygon(
            ((16, 20), (23, 14), (28, 19), (33, 14), (40, 20), (40, 29), (28, 43), (16, 29)),
            fill=rgba(palette_name, 5),
        )
        draw.rectangle((21, 19, 24, 22), fill=rgba(palette_name, 7))
    elif name == "key":
        draw.rectangle((25, 25, 43, 30), fill=rgba(palette_name, 6))
        draw.rectangle((38, 30, 43, 40), fill=rgba(palette_name, 6))
        draw.rectangle((33, 35, 38, 40), fill=rgba(palette_name, 6))
        draw.rectangle((14, 19, 28, 34), fill=rgba(palette_name, 6))
        draw.rectangle((18, 23, 24, 30), fill=rgba(palette_name, 1))
    elif name == "boomerang":
        draw.polygon(((12, 16), (20, 13), (29, 27), (42, 14), (46, 22), (30, 44), (24, 44)), fill=rgba(palette_name, 6))
        draw.line(((17, 18), (28, 36), (42, 18)), fill=rgba(palette_name, 7), width=2)
    elif name == "bomb":
        draw.ellipse((15, 18, 42, 46), fill=rgba(palette_name, 2), outline=rgba(palette_name, 0), width=3)
        draw.rectangle((24, 14, 32, 20), fill=rgba(palette_name, 5))
        draw.line(((29, 14), (34, 8), (41, 11)), fill=rgba(palette_name, 6), width=3)
    elif name == "switch":
        draw.rectangle((13, 33, 43, 42), fill=rgba(palette_name, 1))
        draw.rectangle((18, 28, 38, 36), fill=rgba(palette_name, 4))
        draw.rectangle((23, 24, 33, 32), fill=rgba(palette_name, 6))
    elif name == "treasure":
        draw.polygon(((28, 9), (42, 27), (28, 47), (14, 27)), fill=rgba(palette_name, 6))
        draw.polygon(((28, 14), (36, 27), (28, 39), (20, 27)), fill=rgba(palette_name, 7))


def source_path(source_name: str) -> str:
    """内部の素材キーをマニフェスト用の相対パスへ変換する。"""
    if source_name == "overworld":
        return "source/punyworld-overworld-tileset_0.png"
    if source_name == "dungeon":
        return "source/punyworld-dungeon-tileset.png"
    raise ValueError(f"不明な素材キーです: {source_name}")


def generate_props(sources: dict[str, Image.Image]) -> dict[str, dict[str, object]]:
    """13種の56px小物を生成する。"""
    records: dict[str, dict[str, object]] = {}
    for name, (source_name, box, palette_name) in PROPS.items():
        image = Image.new("RGBA", (56, 56), TRANSPARENT)
        cropped = crop_recolored(sources[source_name], box, palette_name)
        paste_centered(image, cropped, (0, 0, 56, 56), scale=3 if cropped.width == 16 else 1)
        add_prop_details(image, name, palette_name)
        relative_path = f"props/{name}.png"
        save_png(ASSETS / relative_path, image)
        records[relative_path] = {
            "size": [56, 56],
            "palette": palette_name,
            "source": source_path(source_name),
            "source_crop": list(box),
            "transform": "source crop; palette mapping; integer nearest-neighbor enlargement; optional pixel detail",
        }
    return records


def generate_scenery(sources: dict[str, Image.Image]) -> dict[str, dict[str, object]]:
    """8種の112px景観素材を生成する。"""
    records: dict[str, dict[str, object]] = {}
    for name, (source_name, box, palette_name) in SCENERY.items():
        image = Image.new("RGBA", (112, 112), TRANSPARENT)
        cropped = crop_recolored(sources[source_name], box, palette_name)
        paste_centered(image, cropped, (0, 0, 112, 112))
        draw = ImageDraw.Draw(image)
        if name in {"tree", "house", "stall", "arch", "column", "ruins"}:
            draw.rectangle((18, 102, 93, 107), fill=rgba(palette_name, 0, 180))
        if name == "crystals":
            draw.polygon(((29, 88), (45, 45), (57, 88)), fill=rgba(palette_name, 4))
            draw.polygon(((50, 89), (70, 26), (84, 89)), fill=rgba(palette_name, 6))
            draw.line(((45, 45), (45, 88), (70, 26), (70, 89)), fill=rgba(palette_name, 7), width=3)
        relative_path = f"scenery/{name}.png"
        save_png(ASSETS / relative_path, image)
        records[relative_path] = {
            "size": [112, 112],
            "palette": palette_name,
            "source": source_path(source_name),
            "source_crop": list(box),
            "transform": "source crop; palette mapping; integer nearest-neighbor enlargement; optional pixel detail",
        }
    return records


def repeat_tile(
    canvas: Image.Image,
    source: Image.Image,
    box: tuple[int, int, int, int],
    palette_name: str,
    y: int,
    scale: int = 2,
) -> None:
    """16px原画タイルを低解像度背景の横幅に繰り返す。"""
    tile = crop_recolored(source, box, palette_name)
    tile = tile.resize((tile.width * scale, tile.height * scale), NEAREST)
    for x in range(0, canvas.width, tile.width):
        canvas.alpha_composite(tile, (x, y))


def make_background_layers(source: Image.Image, palette_name: str) -> tuple[Image.Image, Image.Image, Image.Image]:
    """320×180で遠景・中景・前景を描き、最後に4倍へ拡大できる形で返す。"""
    distant = Image.new("RGBA", (320, 180), rgba(palette_name, 0))
    draw = ImageDraw.Draw(distant)
    draw.rectangle((0, 0, 319, 55), fill=rgba(palette_name, 0))
    draw.rectangle((0, 56, 319, 110), fill=rgba(palette_name, 1))
    draw.rectangle((0, 111, 319, 179), fill=rgba(palette_name, 2))
    draw.rectangle((247, 21, 271, 45), fill=rgba(palette_name, 7))
    draw.rectangle((253, 17, 265, 49), fill=rgba(palette_name, 7))
    draw.rectangle((243, 27, 275, 39), fill=rgba(palette_name, 7))
    for x, y in ((19, 20), (43, 31), (71, 14), (102, 38), (133, 24), (166, 11), (199, 33), (227, 15), (292, 27)):
        draw.rectangle((x, y, x + 1, y + 1), fill=rgba(palette_name, 6))
    draw.polygon(((0, 126), (42, 77), (78, 126)), fill=rgba(palette_name, 1))
    draw.polygon(((48, 128), (113, 66), (171, 128)), fill=rgba(palette_name, 2))
    draw.polygon(((139, 128), (206, 82), (250, 128)), fill=rgba(palette_name, 1))
    draw.polygon(((215, 128), (280, 71), (319, 111), (319, 128)), fill=rgba(palette_name, 2))
    repeat_tile(distant, source, (0, 160, 16, 176), palette_name, 148)

    middle = Image.new("RGBA", (320, 180), TRANSPARENT)
    draw = ImageDraw.Draw(middle)
    draw.polygon(
        (
            (0, 163),
            (36, 139),
            (75, 151),
            (111, 130),
            (154, 153),
            (196, 135),
            (239, 151),
            (282, 132),
            (319, 151),
            (319, 180),
            (0, 180),
        ),
        fill=rgba(palette_name, 2),
    )
    draw.rectangle((132, 104, 187, 161), fill=rgba(palette_name, 3))
    draw.rectangle((138, 96, 181, 104), fill=rgba(palette_name, 4))
    draw.rectangle((143, 113, 176, 161), fill=rgba(palette_name, 0))
    draw.rectangle((151, 106, 168, 111), fill=rgba(palette_name, 6))
    for x in (18, 72, 235, 286):
        tree = crop_recolored(source, (0, 112, 48, 160), palette_name)
        middle.alpha_composite(tree, (x, 111))

    foreground = Image.new("RGBA", (320, 180), TRANSPARENT)
    draw = ImageDraw.Draw(foreground)
    draw.polygon(
        (
            (0, 165),
            (40, 153),
            (76, 169),
            (121, 155),
            (163, 171),
            (206, 154),
            (256, 166),
            (289, 150),
            (319, 158),
            (319, 180),
            (0, 180),
        ),
        fill=rgba(palette_name, 0),
    )
    bush = crop_recolored(source, (0, 112, 48, 160), palette_name).resize((32, 32), NEAREST)
    for x in range(0, 320, 32):
        foreground.alpha_composite(bush, (x, 149 + (x // 32 % 2) * 5))
    return distant, middle, foreground


def generate_backgrounds(source: Image.Image) -> dict[str, dict[str, object]]:
    """視差用3層とタイトル用合成背景を生成する。"""
    records: dict[str, dict[str, object]] = {}
    layer_specs = (("distant", "coast", 0), ("middle", "ruins", 1), ("foreground", "forest", 2))
    for name, palette_name, layer_index in layer_specs:
        layer = make_background_layers(source, palette_name)[layer_index]
        output = layer.resize((1280, 720), NEAREST)
        relative_path = f"backgrounds/{name}.png"
        save_png(ASSETS / relative_path, output)
        records[relative_path] = {
            "size": [1280, 720],
            "palette": palette_name,
            "source": "source/punyworld-overworld-tileset_0.png",
            "source_crops": [[0, 160, 16, 176], [0, 112, 48, 160]],
            "transform": "source crops and pixel geometry composed at 320x180; 4x nearest-neighbor",
            "layer": name,
        }

    title_layers = make_background_layers(source, "title")
    title = Image.alpha_composite(Image.alpha_composite(title_layers[0], title_layers[1]), title_layers[2])
    relative_path = "backgrounds/title.png"
    save_png(ASSETS / relative_path, title.resize((1280, 720), NEAREST))
    records[relative_path] = {
        "size": [1280, 720],
        "palette": "title",
        "source": "source/punyworld-overworld-tileset_0.png",
        "source_crops": [[0, 160, 16, 176], [0, 112, 48, 160]],
        "transform": "three source-derived layers composed at 320x180; 4x nearest-neighbor",
        "layer": "flattened title",
    }
    return records


def generate_keyart(source: Image.Image) -> dict[str, dict[str, object]]:
    """別版スプライトの主人公から448pxキービジュアルを生成する。"""
    palette_name = "title"
    low_resolution = Image.new("RGBA", (112, 112), TRANSPARENT)
    draw = ImageDraw.Draw(low_resolution)
    draw.rectangle((8, 53, 103, 58), fill=rgba(palette_name, 6, 120))
    draw.rectangle((53, 8, 58, 103), fill=rgba(palette_name, 6, 120))
    draw.rectangle((19, 19, 24, 24), fill=rgba(palette_name, 7, 150))
    draw.rectangle((88, 23, 93, 28), fill=rgba(palette_name, 7, 150))
    draw.rectangle((84, 87, 89, 92), fill=rgba(palette_name, 7, 150))
    hero = crop_recolored(source, (4, 4, 28, 28), palette_name)
    paste_centered(low_resolution, hero, (8, 8, 104, 104), scale=4)
    output = low_resolution.resize((448, 448), NEAREST)
    relative_path = "backgrounds/hero-keyart.png"
    save_png(ASSETS / relative_path, output)
    return {
        relative_path: {
            "size": [448, 448],
            "palette": palette_name,
            "source": "source/puny-charactersorcs_included.zip",
            "source_member": "Puny-Characters/Warrior-Blue.png",
            "source_crop": [4, 4, 28, 28],
            "transform": (
                "24px center crop from first 32px cell; palette mapping; "
                "4x then 4x nearest-neighbor with pixel accents"
            ),
        }
    }


def source_record(path: Path, **metadata: object) -> dict[str, object]:
    """入力素材の再現性情報を返す。"""
    return {
        **metadata,
        "path": f"source/{path.name}",
        "size_bytes": path.stat().st_size,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }


def allowed_colors(record: dict[str, object]) -> set[tuple[int, int, int]]:
    """出力レコードが許可するRGB集合を返す。"""
    palette_names: Iterable[str]
    if "palette" in record:
        palette_names = (str(record["palette"]),)
    else:
        palette_names = (str(name) for name in record["palettes"])
    return {color for name in palette_names for color in colors(name)}


def verify_outputs(records: dict[str, dict[str, object]]) -> dict[str, dict[str, object]]:
    """全PNGの寸法とユニークRGB色数を実データから検査する。"""
    verification: dict[str, dict[str, object]] = {}
    for relative_path, record in sorted(records.items()):
        image = Image.open(ASSETS / relative_path).convert("RGBA")
        expected_size = tuple(record["size"])
        if image.size != expected_size:
            raise ValueError(f"{relative_path}: expected {expected_size}, got {image.size}")
        used = {
            (red, green, blue)
            for red, green, blue, alpha in image.get_flattened_data()
            if alpha > 0
        }
        if not used:
            raise ValueError(f"{relative_path}: 可視ピクセルがありません")
        unexpected = used - allowed_colors(record)
        if unexpected:
            raise ValueError(f"{relative_path}: palette外の色があります: {sorted(unexpected)}")
        verification[relative_path] = {
            "size": list(image.size),
            "unique_rgb_colors": len(used),
            "palette_limit": len(allowed_colors(record)),
        }
    return verification


def write_manifest(records: dict[str, dict[str, object]], verification: dict[str, dict[str, object]]) -> bool:
    """パレット、由来源、実測結果を機械可読JSONへ保存する。"""
    manifest = {
        "schema_version": 1,
        "generator": "scripts/dev/generate_pixel_assets.py",
        "method": "source crops, fixed regional palette mapping, nearest-neighbor scaling, deterministic PNG encoding",
        "sources": [
            source_record(
                SOURCES / "punyworld-overworld-tileset_0.png",
                title="16x16 Puny World Tileset",
                creator="Shade",
                license="CC0-1.0",
                url="https://opengameart.org/content/16x16-puny-world-tileset",
                dimensions=[432, 1040],
                used_for=["terrain", "props", "scenery", "backgrounds"],
            ),
            source_record(
                SOURCES / "punyworld-dungeon-tileset.png",
                title="16x16 Puny Dungeon Tileset",
                creator="Shade",
                license="CC0-1.0",
                url="https://opengameart.org/content/16x16-puny-dungeon-tileset",
                dimensions=[416, 320],
                used_for=["terrain", "props", "scenery"],
            ),
            source_record(
                SOURCES / "puny-charactersorcs_included.zip",
                title="Puny Characters",
                creator="Shade",
                license="CC0-1.0",
                url="https://opengameart.org/content/puny-characters",
                archive_members=sorted({member for member, _palette in CHARACTERS.values()}),
                used_for=["characters", "hero-keyart"],
            ),
        ],
        "palettes": {
            name: {"purpose": PALETTE_PURPOSES[name], "colors": list(values)}
            for name, values in PALETTES.items()
        },
        "outputs": {
            relative_path: {**record, "verification": verification[relative_path]}
            for relative_path, record in sorted(records.items())
        },
    }
    payload = (json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode()
    path = ASSETS / "palettes.json"
    if path.is_file() and path.read_bytes() == payload:
        return False
    path.write_bytes(payload)
    return True


def main() -> None:
    """入力を検査し、全アセットとマニフェストを生成・検証する。"""
    tile_sources = {
        "overworld": validate_source(SOURCES / "punyworld-overworld-tileset_0.png", (432, 1040)),
        "dungeon": validate_source(SOURCES / "punyworld-dungeon-tileset.png", (416, 320)),
    }
    character_sources = load_character_sources(SOURCES / "puny-charactersorcs_included.zip")

    records: dict[str, dict[str, object]] = {}
    records.update(generate_characters(character_sources))
    records.update(generate_terrain(tile_sources))
    records.update(generate_props(tile_sources))
    records.update(generate_scenery(tile_sources))
    records.update(generate_backgrounds(tile_sources["overworld"]))
    records.update(generate_keyart(character_sources["Puny-Characters/Warrior-Blue.png"]))
    verification = verify_outputs(records)
    manifest_changed = write_manifest(records, verification)

    for relative_path, result in verification.items():
        print(
            f"OK {relative_path}: {result['size'][0]}x{result['size'][1]}, "
            f"unique RGB {result['unique_rgb_colors']}/{result['palette_limit']}"
        )
    print(f"OK palettes.json: {'updated' if manifest_changed else 'unchanged'}")


if __name__ == "__main__":
    main()
