#!/usr/bin/env python3
"""CC0 の小さなスプライトを、fighter 用のドット絵 PNG 群へ組み直す。"""

from __future__ import annotations

import hashlib
import io
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets"
CHARACTERS = ASSETS / "characters"
VIGILANTE = CHARACTERS / "source" / "vigilante"
SOLDIER = CHARACTERS / "source" / "soldier"
STAGE_SOURCE = ASSETS / "stage" / "source"
FONT_PATH = ASSETS / "fonts" / "DelaGothicOne-Regular.ttf"
CELL = (320, 256)
SHEET_COLUMNS = 12
ANIMATIONS = [
    "idle",
    "walk",
    "attack",
    "hurt",
    "ko",
    "guard",
    "jump",
    "crouch",
    "special",
    "crouch_guard",
    "standing_lp",
    "standing_hp",
    "standing_lk",
    "standing_hk",
    "crouching_lp",
    "crouching_hp",
    "crouching_lk",
    "crouching_hk",
    "air_lp",
    "air_hp",
    "air_lk",
    "air_hk",
]


def _save_png(path: Path, image: Image.Image) -> None:
    """同じ PNG は書き直さず、生成コマンドを冪等に保つ。"""
    buffer = io.BytesIO()
    image.save(buffer, format="PNG", optimize=True, compress_level=9)
    payload = buffer.getvalue()
    if path.exists() and path.read_bytes() == payload:
        print(f"unchanged {path.relative_to(ROOT)}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)
    print(f"wrote {path.relative_to(ROOT)}")


def _open(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def _strip(path: Path, frame_width: int = 16) -> list[Image.Image]:
    image = _open(path)
    return [image.crop((x, 0, x + frame_width, image.height)) for x in range(0, image.width, frame_width)]


def _repeat(frames: list[Image.Image]) -> list[Image.Image]:
    return [frames[index % len(frames)].copy() for index in range(8)]


def _recolor(image: Image.Image, character: int) -> Image.Image:
    result = image.copy()
    pixels = result.load()
    bounds = result.getbbox() or (0, 0, result.width, result.height)
    center_x = (bounds[0] + bounds[2]) * 0.5
    for y in range(result.height):
        for x in range(result.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                continue
            if character == 0:
                # Renegade の青いズボンを青緑へ、胴の橙を明るいシアンへ変更する。
                if blue > red * 1.2 and blue > green * 1.2:
                    pixels[x, y] = (12, max(80, green + 62), max(116, blue), alpha)
                elif (
                    red > 170
                    and green > 45
                    and blue < 65
                    and bounds[1] + 8 <= y <= bounds[3] - 9
                    and abs(x - center_x) <= max(2.0, (bounds[2] - bounds[0]) * 0.24)
                ):
                    pixels[x, y] = (28, min(232, green + 105), min(224, blue + 145), alpha)
            else:
                # Soldier の黄緑を橙と深紅へ寄せ、相手の輪郭を一目で分ける。
                if green > red * 1.15 and green > blue * 1.4:
                    pixels[x, y] = (238, max(66, red), 24, alpha)
                elif red > 145 and green > 115 and blue < 80:
                    pixels[x, y] = (255, 173, 43, alpha)
    return result


def _transform(image: Image.Image, *, squash: float = 1.0, angle: float = 0.0) -> Image.Image:
    result = image
    if squash != 1.0:
        result = result.resize((result.width, max(1, round(result.height * squash))), Image.Resampling.NEAREST)
    if angle:
        result = result.rotate(angle, Image.Resampling.NEAREST, expand=True)
    return result


def _cell(image: Image.Image, character: int, *, dx: int = 0, dy: int = 0, squash: float = 1.0, angle: float = 0.0) -> Image.Image:
    pose = _transform(_recolor(image, character), squash=squash, angle=angle)
    scale = 6 if character == 0 else 7
    pose = pose.resize((pose.width * scale, pose.height * scale), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", CELL, (0, 0, 0, 0))
    shadow = ImageDraw.Draw(canvas)
    shadow.rectangle((112 + dx, 211 + dy, 207 + dx, 220 + dy), fill=(4, 4, 16, 125))
    x = (CELL[0] - pose.width) // 2 + dx
    y = 212 - pose.height + dy
    canvas.alpha_composite(pose, (x, y))
    bounds = canvas.getbbox()
    if bounds is None:
        return canvas
    shift_x = 2 - bounds[0] if bounds[0] < 2 else min(0, CELL[0] - 2 - bounds[2])
    shift_y = 2 - bounds[1] if bounds[1] < 2 else min(0, CELL[1] - 2 - bounds[3])
    if shift_x == 0 and shift_y == 0:
        return canvas
    fitted = Image.new("RGBA", CELL, (0, 0, 0, 0))
    fitted.alpha_composite(canvas, (shift_x, shift_y))
    return fitted


def _attack(idle: Image.Image, pose: Image.Image) -> list[tuple[Image.Image, dict[str, float]]]:
    return [
        (idle, {}),
        (idle, {"dx": -3}),
        (pose, {"dx": 2}),
        (pose, {"dx": 8}),
        (pose, {"dx": 11}),
        (pose, {"dx": 6}),
        (idle, {"dx": -2}),
        (idle, {}),
    ]


def _animation_sources(character: int) -> dict[str, list[tuple[Image.Image, dict[str, float]]]]:
    if character == 0:
        idle_frames = _strip(VIGILANTE / "Renegade_Idle_1_strip4.png")
        walk_frames = _strip(VIGILANTE / "Renegade_Walk_1_strip4.png")
        run_frames = _strip(VIGILANTE / "Renegade_Run_1_strip4.png")
        daze_frames = _strip(VIGILANTE / "Renegade_Daze_strip4.png")
        punch_light = _open(VIGILANTE / "Renegade_Punch_1.png")
        punch_heavy = _open(VIGILANTE / "Renegade_Punch_2.png")
        kick_light = _open(VIGILANTE / "Renegade_Kick_1.png")
        kick_heavy = _open(VIGILANTE / "Renegade_Kick_2.png")
        hurt = _open(VIGILANTE / "Renegade_Hurt.png")
        knocked_out = _open(VIGILANTE / "Renegade_Knock_Out.png")
    else:
        idle_frames = _strip(SOLDIER / "SMS_Soldier_IDLE_EAST_strip4.png")
        walk_frames = _strip(SOLDIER / "SMS_Soldier_WALK_EAST_strip4.png")
        run_frames = _strip(SOLDIER / "SMS_Soldier_RUN_EAST_strip4.png")
        punch_light = _open(SOLDIER / "SMS_Soldier_ATTACKPUNCH_EAST.png")
        punch_heavy = punch_light
        kick_light = _open(SOLDIER / "SMS_Soldier_ATTACKKICK_EAST.png")
        kick_heavy = kick_light
        hurt = _open(SOLDIER / "SMS_Soldier_HITHURT_EAST.png")
        knocked_out = hurt
        daze_frames = [hurt] * 4

    idle = idle_frames[0]
    jump = kick_light if character == 0 else _open(SOLDIER / "SMS_Soldier_JUMP_EAST.png")
    sources: dict[str, list[tuple[Image.Image, dict[str, float]]]] = {}
    sources["idle"] = [(frame, {}) for frame in _repeat(idle_frames)]
    sources["walk"] = [(frame, {"dx": (index % 4 - 1) * 2}) for index, frame in enumerate(_repeat(walk_frames))]
    sources["attack"] = _attack(idle, punch_light)
    sources["hurt"] = [(daze_frames[index % 4], {"dx": -index * 2}) for index in range(8)]
    sources["ko"] = [
        (hurt, {"angle": angle, "dy": max(0, index - 1) * 7, "dx": -index * 3})
        for index, angle in enumerate((0, 0, -8, -18, -32, -48, -66, -82))
    ]
    sources["guard"] = [(hurt if index in (2, 3, 4, 5) else idle, {"dx": -5}) for index in range(8)]
    sources["jump"] = [(jump, {"dy": -18 - abs(3 - index) * 4, "angle": (index - 3) * 2}) for index in range(8)]
    sources["crouch"] = [(idle_frames[index % 4], {"squash": 0.72, "dy": 36}) for index in range(8)]
    sources["special"] = _attack(idle, punch_heavy)
    sources["crouch_guard"] = [(hurt, {"squash": 0.72, "dy": 36, "dx": -5}) for _ in range(8)]

    attacks = {
        "standing_lp": punch_light,
        "standing_hp": punch_heavy,
        "standing_lk": kick_light,
        "standing_hk": kick_heavy,
    }
    for name, pose in attacks.items():
        sources[name] = _attack(idle, pose)
        sources[name.replace("standing", "crouching")] = [
            (frame, {**options, "squash": 0.76, "dy": 34}) for frame, options in _attack(idle, pose)
        ]
        sources[name.replace("standing", "air")] = [
            (frame, {**options, "dy": -28, "angle": -5 if "p" in name else 7})
            for frame, options in _attack(jump, pose)
        ]
    return sources


def _character_sheet(character: int) -> Image.Image:
    rows = (len(ANIMATIONS) * 8 + SHEET_COLUMNS - 1) // SHEET_COLUMNS
    sheet = Image.new("RGBA", (SHEET_COLUMNS * CELL[0], rows * CELL[1]), (0, 0, 0, 0))
    sources = _animation_sources(character)
    for animation_index, name in enumerate(ANIMATIONS):
        for frame_index, (pose, options) in enumerate(sources[name]):
            index = animation_index * 8 + frame_index
            frame = _cell(pose, character, **options)
            sheet.alpha_composite(frame, ((index % SHEET_COLUMNS) * CELL[0], (index // SHEET_COLUMNS) * CELL[1]))
    return sheet


def _portrait(character: int) -> Image.Image:
    canvas = Image.new("RGBA", (320, 320), (0, 0, 0, 0))
    if character == 0:
        pose = _open(VIGILANTE / "Renegade_Punch_2.png")
    else:
        pose = _open(SOLDIER / "SMS_Soldier_AVATAR_ANGRY.png")
    pose = _recolor(pose, character)
    scale = 9
    pose = pose.resize((pose.width * scale, pose.height * scale), Image.Resampling.NEAREST)
    canvas.alpha_composite(pose, ((320 - pose.width) // 2, 300 - pose.height))
    return canvas


def _tint(image: Image.Image, color: tuple[int, int, int]) -> Image.Image:
    overlay = Image.new("RGBA", image.size, (*color, 78))
    return Image.alpha_composite(image.convert("RGBA"), overlay)


def _stage(index: int) -> Image.Image:
    palettes = [
        ((9, 8, 28), (25, 8, 62), (255, 38, 150), "NEON MARKET // TOKYO"),
        ((5, 18, 38), (13, 47, 76), (34, 224, 255), "SKY RING // SEOUL"),
        ((39, 10, 24), (100, 25, 34), (255, 184, 46), "SUNSET PIER // RIO"),
    ]
    top, bottom, accent, title = palettes[index]
    canvas = Image.new("RGBA", (1280, 720), (*top, 255))
    draw = ImageDraw.Draw(canvas)
    for y in range(0, 720, 4):
        mix = y / 719.0
        color = tuple(round(top[channel] * (1.0 - mix) + bottom[channel] * mix) for channel in range(3))
        draw.rectangle((0, y, 1279, y + 3), fill=(*color, 255))
    draw.rectangle((0, 70, 1279, 75), fill=(*accent, 255))
    draw.rectangle((0, 81, 1279, 84), fill=(255, 235, 150, 255))

    market = _open(STAGE_SOURCE / "SMS_C_Street_16x16_128_x128.png")
    market = _tint(market.resize((640, 640), Image.Resampling.NEAREST), accent)
    canvas.alpha_composite(market, (0, 16))
    canvas.alpha_composite(ImageOps.mirror(market), (640, 16))

    props = _open(STAGE_SOURCE / "SMS_Sprites.png")
    props = props.crop(props.getbbox()).resize((384, 384), Image.Resampling.NEAREST)
    props = _tint(props, accent)
    canvas.alpha_composite(props, (760 if index != 2 else 128, 172))

    draw = ImageDraw.Draw(canvas)
    draw.rectangle((0, 438, 1279, 570), fill=(7, 5, 18, 240))
    crowd_colors = [(237, 42, 131), (35, 225, 247), (255, 183, 44), (122, 255, 98)]
    for person in range(29):
        x = 14 + person * 45
        height = 54 + (person * 17 % 48)
        color = crowd_colors[(person + index) % len(crowd_colors)]
        head_y = 505 - height
        draw.rectangle((x + 12, head_y, x + 25, head_y + 13), fill=(*color, 255))
        draw.rectangle((x + 8, head_y + 14, x + 29, 516), fill=(color[0] // 2, color[1] // 2, color[2] // 2, 255))
        arm_y = head_y + 22
        if person % 3 == 0:
            draw.rectangle((x + 1, arm_y - 17, x + 7, arm_y + 18), fill=(*color, 255))
            draw.rectangle((x + 30, arm_y - 12, x + 36, arm_y + 20), fill=(*color, 255))
        else:
            draw.rectangle((x, arm_y, x + 37, arm_y + 6), fill=(*color, 255))

    draw.rectangle((0, 534, 1279, 719), fill=(12, 12, 28, 255))
    draw.rectangle((0, 540, 1279, 549), fill=(*accent, 255))
    for y in (594, 644, 688):
        draw.rectangle((0, y, 1279, y + 3), fill=(58, 47, 83, 255))
    for x in range(-180, 1460, 130):
        draw.line((640, 540, x, 720), fill=(72, 60, 104, 255), width=3)
    draw.rectangle((0, 526, 1279, 531), fill=(235, 235, 255, 255))
    draw.rectangle((0, 511, 1279, 516), fill=(*accent, 255))
    font = ImageFont.truetype(FONT_PATH, 23)
    draw.rectangle((36, 96, 402, 136), fill=(4, 4, 15, 235), outline=(*accent, 255), width=4)
    draw.text((52, 102), title, font=font, fill=(255, 245, 194, 255))
    return canvas


def _world_map() -> Image.Image:
    canvas = Image.new("RGBA", (1280, 720), (4, 8, 28, 255))
    draw = ImageDraw.Draw(canvas)
    for x in range(0, 1280, 40):
        draw.line((x, 0, x, 720), fill=(15, 58, 96, 255), width=2)
    for y in range(0, 720, 40):
        draw.line((0, y, 1280, y), fill=(15, 58, 96, 255), width=2)
    continents = [
        [(92, 168), (195, 113), (325, 136), (385, 207), (315, 264), (267, 347), (181, 326), (146, 242)],
        [(357, 364), (436, 347), (475, 409), (445, 541), (387, 612), (342, 493)],
        [(559, 167), (697, 112), (861, 129), (957, 202), (907, 289), (790, 295), (735, 377), (637, 339), (599, 257)],
        [(865, 395), (972, 365), (1066, 425), (1012, 516), (900, 503)],
        [(1040, 528), (1140, 505), (1202, 567), (1134, 618), (1059, 590)],
    ]
    for polygon in continents:
        draw.polygon(polygon, fill=(14, 112, 124, 255), outline=(53, 236, 219, 255))
    for offset in range(8, 24, 8):
        for polygon in continents:
            shifted = [(x + offset, y + offset // 2) for x, y in polygon]
            draw.line(shifted + [shifted[0]], fill=(6, 61, 79, 180), width=2)
    draw.rectangle((0, 650, 1279, 719), fill=(5, 4, 18, 245))
    return canvas


def _title_logo() -> Image.Image:
    small = Image.new("RGBA", (320, 92), (0, 0, 0, 0))
    draw = ImageDraw.Draw(small)
    font = ImageFont.truetype(FONT_PATH, 52)
    draw.text((9, 5), "燈環闘技", font=font, fill=(255, 225, 75, 255), stroke_width=4, stroke_fill=(214, 24, 93, 255))
    draw.rectangle((12, 71, 305, 77), fill=(36, 236, 229, 255))
    draw.rectangle((56, 82, 271, 86), fill=(255, 52, 157, 255))
    return small.resize((640, 184), Image.Resampling.NEAREST)


def _emblem() -> Image.Image:
    image = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((4, 4, 59, 59), fill=(12, 8, 35, 255), outline=(35, 232, 222, 255), width=4)
    draw.rectangle((15, 25, 48, 47), fill=(255, 57, 153, 255))
    for x in (15, 24, 33, 42):
        draw.rectangle((x, 15, x + 7, 31), fill=(255, 219, 70, 255))
    draw.rectangle((12, 40, 51, 50), fill=(255, 219, 70, 255))
    return image


def _health_frame() -> Image.Image:
    image = Image.new("RGBA", (496, 36), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, 495, 35), fill=(3, 4, 18, 255), outline=(243, 231, 167, 255), width=3)
    draw.rectangle((5, 5, 490, 30), outline=(35, 232, 222, 255), width=2)
    return image


def _round_medal() -> Image.Image:
    image = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((2, 2, 21, 21), fill=(255, 48, 140, 255), outline=(255, 229, 77, 255), width=3)
    draw.rectangle((8, 8, 15, 15), fill=(9, 7, 32, 255))
    return image


def _spark() -> Image.Image:
    image = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((6, 0, 9, 15), fill=(255, 236, 128, 255))
    draw.rectangle((0, 6, 15, 9), fill=(255, 68, 155, 255))
    draw.rectangle((4, 4, 11, 11), fill=(255, 255, 255, 255))
    return image


def _burst(blocked: bool) -> Image.Image:
    image = Image.new("RGBA", (160, 160), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    if blocked:
        draw.polygon([(80, 10), (142, 38), (130, 118), (80, 150), (30, 118), (18, 38)], fill=(22, 229, 238, 80), outline=(255, 255, 255, 255))
        draw.line((35, 124, 128, 31), fill=(255, 224, 71, 255), width=12)
    else:
        points = [(80, 0), (98, 54), (153, 27), (118, 75), (160, 94), (105, 101), (125, 160), (80, 119), (35, 160), (51, 104), (0, 94), (43, 75), (8, 27), (63, 54)]
        draw.polygon(points, fill=(255, 51, 150, 210), outline=(255, 241, 117, 255))
    return image


def _wave(color: tuple[int, int, int]) -> Image.Image:
    image = Image.new("RGBA", (160, 96), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((18, 38, 141, 57), fill=(*color, 160))
    draw.rectangle((34, 24, 126, 71), outline=(255, 244, 183, 255), width=7)
    draw.rectangle((55, 12, 106, 83), outline=(*color, 255), width=8)
    draw.rectangle((70, 26, 91, 69), fill=(255, 255, 255, 245))
    return image


def main() -> None:
    required = [
        FONT_PATH,
        VIGILANTE,
        SOLDIER,
        STAGE_SOURCE / "SMS_C_Street_16x16_128_x128.png",
        STAGE_SOURCE / "SMS_Sprites.png",
    ]
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        raise SystemExit("素材不足: " + ", ".join(missing))

    _save_png(CHARACTERS / "teal-sheet.png", _character_sheet(0))
    _save_png(CHARACTERS / "amber-sheet.png", _character_sheet(1))
    _save_png(ASSETS / "portrait-teal.png", _portrait(0))
    _save_png(ASSETS / "portrait-amber.png", _portrait(1))
    for index, name in enumerate(("tokyo", "seoul", "rio")):
        _save_png(ASSETS / "stage" / f"{name}.png", _stage(index))
    _save_png(ASSETS / "stage" / "world-map.png", _world_map())
    _save_png(ASSETS / "ui" / "title-logo.png", _title_logo())
    _save_png(ASSETS / "ui" / "emblem.png", _emblem())
    _save_png(ASSETS / "ui" / "health-frame.png", _health_frame())
    _save_png(ASSETS / "ui" / "round-medal.png", _round_medal())
    _save_png(ASSETS / "effects" / "spark.png", _spark())
    _save_png(ASSETS / "effects" / "impact.png", _burst(False))
    _save_png(ASSETS / "effects" / "guard.png", _burst(True))
    _save_png(ASSETS / "effects" / "wave-teal.png", _wave((28, 229, 220)))
    _save_png(ASSETS / "effects" / "wave-amber.png", _wave((255, 80, 145)))
    manifest = hashlib.sha256((CHARACTERS / "teal-sheet.png").read_bytes()).hexdigest()[:12]
    print(f"pixel assets OK {manifest}")


if __name__ == "__main__":
    main()
