#!/usr/bin/env python3
"""Public Domain の古書画像を、ゲーム用の写本風 PNG へ決定的に加工する。"""

from __future__ import annotations

import argparse
import io
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps


PAPER = "#ead9b5"
LIGHT_PAPER = "#f5e8c8"
INK = "#34251b"
RUST = "#963f31"
LAPIS = "#355a82"
VERDIGRIS = "#486449"
GOLD = "#ae812f"

SOURCES = {
    "castle": "castle-landscape.jpg",
    "saint_george": "saint-george.jpg",
    "initial": "initial-q.jpg",
    "forest": "dark-forest.jpg",
    "bestiary": "bestiary-dragon.jpg",
    "tower": "bl-curthose-tower.jpg",
}

CARD_IDS = [
    "aegis",
    "attack",
    "bash",
    "block",
    "charge",
    "expose",
    "feint",
    "fervor",
    "flow",
    "focus",
    "fortress",
    "fracture",
    "guard",
    "heavy",
    "insight",
    "quick",
    "renew",
    "siphon",
    "skill",
    "smoke",
    "strike",
]

CHARACTERS = {
    "hero": ("saint_george", (0.17, 0.08, 0.82, 0.88), RUST),
    "enemy_moth": ("initial", (0.00, 0.35, 0.36, 0.98), VERDIGRIS),
    "enemy_sentinel": ("tower", (0.16, 0.16, 0.83, 0.86), LAPIS),
    "enemy_brute": ("saint_george", (0.20, 0.57, 0.90, 0.99), RUST),
    "enemy_wisp": ("forest", (0.23, 0.15, 0.83, 0.98), VERDIGRIS),
    "boss": ("bestiary", (0.02, 0.02, 0.98, 0.98), GOLD),
    "npc_keeper": ("initial", (0.34, 0.08, 0.88, 0.88), LAPIS),
}


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", required=True, type=Path)
    parser.add_argument("--out-dir", required=True, type=Path)
    return parser.parse_args()


def _load_sources(source_dir: Path) -> dict[str, Image.Image]:
    images: dict[str, Image.Image] = {}
    for key, filename in SOURCES.items():
        path = source_dir / filename
        if not path.is_file():
            raise FileNotFoundError(f"source missing: {path}")
        images[key] = Image.open(path).convert("RGB")
    return images


def _normalized_crop(image: Image.Image, box: tuple[float, float, float, float]) -> Image.Image:
    width, height = image.size
    return image.crop(
        (
            round(width * box[0]),
            round(height * box[1]),
            round(width * box[2]),
            round(height * box[3]),
        )
    )


def _engraving(
    image: Image.Image,
    size: tuple[int, int],
    centering: tuple[float, float] = (0.5, 0.5),
    dark: str = INK,
    light: str = PAPER,
) -> Image.Image:
    fitted = ImageOps.fit(image, size, Image.Resampling.LANCZOS, centering=centering)
    gray = ImageOps.autocontrast(ImageOps.grayscale(fitted), cutoff=1)
    gray = ImageEnhance.Contrast(gray).enhance(1.12)
    return ImageOps.colorize(gray, dark, light).convert("RGBA")


def _illumination(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    fitted = ImageOps.fit(image, size, Image.Resampling.LANCZOS)
    fitted = ImageEnhance.Color(fitted).enhance(1.08)
    fitted = ImageEnhance.Contrast(fitted).enhance(1.06)
    return fitted.convert("RGBA")


def _framed(image: Image.Image, border: str = INK, width: int = 5) -> Image.Image:
    framed = ImageOps.expand(image, border=width, fill=border)
    return ImageOps.expand(framed, border=3, fill=GOLD)


def _write_png(path: Path, image: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    output = io.BytesIO()
    image.save(output, format="PNG", optimize=True, compress_level=9)
    data = output.getvalue()
    if path.is_file() and path.read_bytes() == data:
        return
    path.write_bytes(data)


def _character_plate(source: Image.Image, box: tuple[float, float, float, float], accent: str) -> Image.Image:
    crop = _normalized_crop(source, box)
    plate = _engraving(crop, (202, 260))
    draw = ImageDraw.Draw(plate)
    draw.rectangle((2, 2, 199, 257), outline=accent, width=4)
    draw.rectangle((10, 10, 191, 249), outline=INK, width=2)
    draw.ellipse((82, 231, 120, 250), fill=accent, outline=INK, width=2)
    return plate


def _character_sheet(plate: Image.Image, accent: str) -> Image.Image:
    sheet = Image.new("RGBA", (1536, 1600), (0, 0, 0, 0))
    for row in range(5):
        for column in range(6):
            progress = column / 5.0
            frame = plate.copy()
            x = 27
            y = 29
            angle = 0.0
            scale = 1.0
            if row == 0:
                y += round(abs(0.5 - progress) * 5)
                angle = (progress - 0.5) * 1.4
            elif row == 1:
                x += round((progress - 0.5) * 24)
                y -= round(10 * (1.0 - abs(progress * 2.0 - 1.0)))
            elif row == 2:
                x += round(progress * 30)
                angle = -4.0 + progress * 9.0
                scale = 1.0 + 0.05 * progress
            elif row == 3:
                x -= round(15 * (1.0 - progress))
                angle = -6.0 * (1.0 - progress)
                red = Image.new("RGBA", frame.size, RUST + "45")
                frame = Image.alpha_composite(frame, red)
            else:
                y += round(progress * 28)
                angle = progress * 68.0
                frame.putalpha(round(255 * (1.0 - progress * 0.58)))
            if scale != 1.0:
                scaled_size = (round(frame.width * scale), round(frame.height * scale))
                frame = frame.resize(scaled_size, Image.Resampling.LANCZOS)
            if angle != 0.0:
                frame = frame.rotate(angle, Image.Resampling.BICUBIC, expand=True)
            frame_canvas = Image.new("RGBA", (256, 320), (0, 0, 0, 0))
            frame_canvas.alpha_composite(frame, (x + (202 - frame.width) // 2, y))
            ink = ImageDraw.Draw(frame_canvas)
            if row == 2:
                ink.line((194, 68, 238, 42 + column * 3), fill=accent, width=5)
            elif row == 3:
                ink.line((20, 82 + column * 3, 63, 62), fill=RUST, width=4)
            sheet.alpha_composite(frame_canvas, (column * 256, row * 320))
    return sheet


def _make_scene_art(images: dict[str, Image.Image], out_dir: Path) -> None:
    _write_png(out_dir / "paper_texture.png", _engraving(images["castle"], (1280, 720), light=LIGHT_PAPER))
    _write_png(out_dir / "map_engraving.png", _framed(_engraving(images["castle"], (1110, 516))))
    _write_png(out_dir / "battle_forest.png", _engraving(images["forest"], (1280, 720), dark="#263126"))
    title = _normalized_crop(images["saint_george"], (0.08, 0.02, 0.96, 0.98))
    _write_png(out_dir / "title_keyart.png", _framed(_engraving(title, (480, 560))))
    _write_png(out_dir / "ornament_initial.png", _framed(_illumination(images["initial"], (370, 320))))
    _write_png(out_dir / "bestiary_dragon.png", _framed(_illumination(images["bestiary"], (430, 350))))
    tower = _normalized_crop(images["tower"], (0.13, 0.12, 0.86, 0.89))
    _write_png(out_dir / "tower_stamp.png", _framed(_engraving(tower, (210, 210))))


def _make_character_art(images: dict[str, Image.Image], out_dir: Path) -> None:
    for name, (source_name, crop, accent) in CHARACTERS.items():
        plate = _character_plate(images[source_name], crop, accent)
        _write_png(out_dir / f"{name}.png", plate)
        _write_png(out_dir / f"{name}_sheet.png", _character_sheet(plate, accent))


def _make_card_art(images: dict[str, Image.Image], out_dir: Path) -> None:
    source_names = list(SOURCES)
    accents = [RUST, LAPIS, VERDIGRIS, GOLD]
    for index, card_id in enumerate(CARD_IDS):
        source = images[source_names[index % len(source_names)]]
        center_x = 0.25 + 0.5 * ((index % 5) / 4.0)
        center_y = 0.28 + 0.44 * (((index * 3) % 7) / 6.0)
        width = 0.46
        height = 0.36
        crop = _normalized_crop(
            source,
            (
                max(0.0, center_x - width / 2),
                max(0.0, center_y - height / 2),
                min(1.0, center_x + width / 2),
                min(1.0, center_y + height / 2),
            ),
        )
        art = _engraving(crop, (154, 76), dark=accents[index % len(accents)])
        draw = ImageDraw.Draw(art)
        draw.rectangle((1, 1, 152, 74), outline=INK, width=2)
        _write_png(out_dir / f"card_{card_id}.png", art)


def _make_small_art(images: dict[str, Image.Image], out_dir: Path) -> None:
    icon_sources = {
        "route_battle": ("saint_george", (0.20, 0.05, 0.70, 0.52)),
        "route_elite": ("tower", (0.18, 0.14, 0.82, 0.80)),
        "route_rest": ("initial", (0.42, 0.20, 0.72, 0.64)),
        "route_card": ("initial", (0.05, 0.48, 0.38, 0.92)),
        "route_event": ("forest", (0.28, 0.38, 0.70, 0.88)),
        "route_boss": ("bestiary", (0.05, 0.04, 0.95, 0.95)),
        "relic_ember": ("initial", (0.00, 0.05, 0.30, 0.43)),
        "relic_seed": ("initial", (0.70, 0.05, 0.99, 0.43)),
        "relic_shell": ("bestiary", (0.00, 0.00, 0.46, 0.56)),
        "icon_attack": ("saint_george", (0.34, 0.08, 0.64, 0.44)),
        "icon_block": ("tower", (0.26, 0.16, 0.76, 0.72)),
        "icon_energy": ("initial", (0.03, 0.03, 0.36, 0.38)),
        "icon_relic": ("bestiary", (0.52, 0.10, 0.96, 0.62)),
        "logo_mark": ("initial", (0.17, 0.10, 0.82, 0.78)),
    }
    for name, (source_name, crop) in icon_sources.items():
        source = _normalized_crop(images[source_name], crop)
        if source_name in ["initial", "bestiary"]:
            art = _illumination(source, (96, 96))
        else:
            art = _engraving(source, (96, 96))
        _write_png(out_dir / f"{name}.png", _framed(art, width=3))
    for name, color in [("fx_glow", GOLD), ("fx_spark", RUST)]:
        effect = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
        draw = ImageDraw.Draw(effect)
        for radius in range(42, 5, -6):
            alpha = round(9 + (42 - radius) * 2.4)
            draw.ellipse((48 - radius, 48 - radius, 48 + radius, 48 + radius), fill=color + f"{alpha:02x}")
        draw.line((12, 48, 84, 48), fill=color, width=3)
        draw.line((48, 12, 48, 84), fill=color, width=3)
        _write_png(out_dir / f"{name}.png", effect.filter(ImageFilter.GaussianBlur(0.5)))


def main() -> None:
    args = _parse_args()
    images = _load_sources(args.source_dir)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    _make_scene_art(images, args.out_dir)
    _make_character_art(images, args.out_dir)
    _make_card_art(images, args.out_dir)
    _make_small_art(images, args.out_dir)


if __name__ == "__main__":
    main()
