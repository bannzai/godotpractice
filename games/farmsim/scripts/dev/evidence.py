#!/usr/bin/env python3
"""撮影済み PNG の画素を変更せず縮小整列し、目視確認用の一覧を作る。"""

from pathlib import Path
import math
import subprocess


def create_contact_sheet(directory: Path) -> None:
    """同じ PNG 群から同じ並びの一覧を作り直す。"""
    files = sorted(
        path.resolve()
        for path in directory.glob("screenshot-*.png")
        if not path.name.startswith("screenshot-characters-")
    )
    if not files:
        raise SystemExit("代表画面の PNG がありません")
    sequence = directory / "screens-contact.txt"
    sequence.write_text(
        "".join("file '" + str(path).replace("'", "'\\''") + "'\n" for path in files),
        encoding="utf-8",
    )
    subprocess.run(
        [
            "ffmpeg", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0",
            "-i", str(sequence), "-vf",
            f"scale=384:216,tile=4x{math.ceil(len(files) / 4)}:padding=4:margin=4:color=0x182b25",
            "-frames:v", "1", str(directory / "screens-contact.png"),
        ],
        check=True,
    )
    print(f"代表画面の一覧: {len(files)} 枚 → {directory / 'screens-contact.png'}")


if __name__ == "__main__":
    create_contact_sheet(Path("tmp"))
