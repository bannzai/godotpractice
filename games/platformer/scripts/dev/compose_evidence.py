"""Godotが撮ったPNGを並べる。元画像の内容は加工せず縮小し、比較用の見出しを付ける。"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

PROJECT = Path(__file__).resolve().parents[2]
OUTPUT = PROJECT / "tmp"
FONT = ImageFont.truetype(str(PROJECT / "assets/fonts/MochiyPopOne-Regular.ttf"), 20)


def compose(files, labels, destination, columns=3):
    """入力画像が同じなら同じ一覧を保存する。"""
    width, height, caption = 640, 360, 38
    rows = (len(files) + columns - 1) // columns
    sheet = Image.new("RGB", (width * columns, (height + caption) * rows), "#fff8e8")
    draw = ImageDraw.Draw(sheet)
    for index, (filename, label) in enumerate(zip(files, labels)):
        x, y = index % columns * width, index // columns * (height + caption)
        draw.text((x + 14, y + 4), label, fill="#153e4a", font=FONT)
        with Image.open(OUTPUT / filename) as source:
            sheet.paste(source.convert("RGB").resize((width, height), Image.Resampling.LANCZOS),
                        (x, y + caption))
    sheet.save(OUTPUT / destination)
    print(OUTPUT / destination)


def main():
    effects = {"coin": "コイン取得", "block": "補給ケースの開封", "land": "着地の砂煙",
               "power": "強化", "stomp": "踏みつけ", "hurt": "被弾", "death": "退場",
               "clear": "配達完了"}
    for kind, title in effects.items():
        compose([f"screenshot-effect-{kind}-{index}.png" for index in range(3)],
                [f"{title}  /  {part}" for part in ("開始", "途中", "終端")],
                f"evidence-effect-{kind}.png")
    screens = {"title": "タイトル", "meadow": "風の草原", "cave": "ひかりの洞窟",
               "pause": "一時停止", "stage-clear": "次のステージへ", "complete": "最終クリア",
               "game-over": "ゲームオーバー", "fullscreen": "全画面", "resized": "960×540"}
    compose([f"screenshot-{name}.png" for name in screens], list(screens.values()),
            "evidence-screens.png")


if __name__ == "__main__":
    main()
