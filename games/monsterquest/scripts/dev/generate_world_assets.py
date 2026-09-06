#!/usr/bin/env python3
"""森の調査隊の地形・建物・家具を独立した原画として決定的に生成する。"""

from pathlib import Path
import math

ASSETS = Path(__file__).resolve().parents[2] / "assets" / "world"
INK = "#334d43"


def svg(body: str, width: int, height: int) -> str:
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}">'
        '<defs><linearGradient id="wall" x2="0" y2="1">'
        '<stop stop-color="#fff0cf"/><stop offset="1" stop-color="#ddbf92"/>'
        '</linearGradient><linearGradient id="glass" x2="0.8" y2="1">'
        '<stop stop-color="#c1e1d6"/><stop offset="1" stop-color="#709f9d"/>'
        '</linearGradient></defs>'
        f'<g stroke="{INK}" stroke-width="2.5" stroke-linejoin="round" '
        f'stroke-linecap="round">{body}</g></svg>\n'
    )


def window(x: int, y: int, width: int = 30, height: int = 32) -> str:
    return (
        f'<rect x="{x-3}" y="{y-3}" width="{width+6}" height="{height+6}" rx="4" fill="#bda77e"/>'
        f'<rect x="{x}" y="{y}" width="{width}" height="{height}" rx="3" fill="url(#glass)"/>'
        f'<path d="M{x+width/2} {y+1}v{height-2}M{x+1} {y+height/2}h{width-2}" '
        'stroke="#fff0cf" stroke-width="3"/>'
        f'<path d="M{x-6} {y+height+5}h{width+12}" stroke="#826c54" stroke-width="5"/>'
    )


def home() -> str:
    body = (
        '<ellipse cx="110" cy="172" rx="103" ry="16" fill="#294e3c" opacity="0.16" stroke="none"/>'
        '<path d="M159 24V6h19v41" fill="#ae7254"/>'
        '<path d="M155 8h27M158 18h19" fill="none" stroke="#7e5548" stroke-width="5"/>'
        '<path d="M22 72h176v101H22z" fill="url(#wall)"/>'
        '<path d="M25 148h170v24H25z" fill="#ad906c" stroke="none"/>'
        '<path d="M22 74h176v10H22z" fill="#9e7359" opacity="0.3" stroke="none"/>'
        '<path d="M9 76L49 24Q112 12 173 24l38 52z" fill="#ad6150"/>'
        '<path d="M15 72L51 29Q112 17 170 29l33 42" fill="none" stroke="#dc9270" stroke-width="4"/>'
        '<path d="M9 76h202" stroke="#794d43" stroke-width="7"/>'
        '<path d="M37 51q71-14 146 0M30 63q78-13 164 0M63 26L45 72M96 21l-5 53'
        'M128 21l5 53M159 25l17 48" fill="none" stroke="#c87d62" stroke-width="2"/>'
        '<path d="M92 173v-44a18 18 0 0136 0v44" fill="#655648"/>'
        '<path d="M98 131v34m11-36v36" stroke="#9c8260"/>'
        '<circle cx="120" cy="149" r="2.5" fill="#ebc96e" stroke="none"/>'
        '<path d="M90 174h40l6 17H83z" fill="#baa78b"/>'
        '<path d="M89 181h40" stroke="#eee0b6" stroke-width="3"/>'
        '<rect x="91" y="184" width="39" height="8" rx="2" fill="#668779" stroke="none"/>'
    ) + window(40, 98) + window(154, 98)
    body += (
        '<path d="M26 147q11-15 27 0l-3 21H31z" fill="#b07858"/>'
        '<path d="M28 143q-7-21 8-12q6-22 13-3q20-8 8 15" fill="#789767"/>'
        '<path d="M180 160v-36m0 20q-20-8-9-19q11 4 9 19m0 3q19-9 16-18q-15 1-16 18" '
        'fill="#759165" stroke="#537258"/>'
        '<circle cx="44" cy="128" r="4" fill="#edce81" stroke="none"/>'
        '<path d="M103 87q7-10 14 0q-7 12-14 0" fill="#7c9d72" stroke-width="1.5"/>'
    )
    return svg(body, 220, 200)


def clinic() -> str:
    body = (
        '<ellipse cx="110" cy="172" rx="104" ry="16" fill="#294e3c" opacity="0.16" stroke="none"/>'
        '<path d="M20 69h180v105H20z" fill="url(#wall)"/>'
        '<path d="M25 150h171v24H25z" fill="#a0b2a1" stroke="none"/>'
        '<path d="M8 78L36 30h148l28 48z" fill="#578b81"/>'
        '<path d="M16 71L41 35h138l25 37" fill="none" stroke="#83b0a0" stroke-width="4"/>'
        '<path d="M8 78h204" stroke="#3f706b" stroke-width="7"/>'
        '<path d="M27 59h168M40 46h142M63 34L51 73M153 34l15 39" fill="none" '
        'stroke="#6ca093" stroke-width="2"/>'
        '<path d="M88 74V29a22 22 0 0144 0v45" fill="#e9dbb7"/>'
        '<circle cx="110" cy="36" r="17" fill="#83a998" stroke="#587f71" stroke-width="2"/>'
        '<path d="M106 24h8v8h8v8h-8v8h-8v-8h-8v-8h8z" fill="#fff7d8" stroke="none"/>'
        '<rect x="90" y="128" width="40" height="47" rx="4" fill="#628b83"/>'
        '<path d="M110 130v42" stroke="#c5dbc0"/>'
        '<circle cx="105" cy="154" r="2" fill="#f0dd9f" stroke="none"/>'
        '<circle cx="115" cy="154" r="2" fill="#f0dd9f" stroke="none"/>'
        '<path d="M89 175h42l5 17H84z" fill="#b9b899"/>'
        '<path d="M90 182h40" stroke="#f0e4bd" stroke-width="3"/>'
        '<path d="M151 137h38l-4 28h-30z" fill="#d49d75"/>'
        '<path d="M155 137q-11-19 4-15q0-21 10-5q14-17 14 3q14-3 1 17" fill="#73966e"/>'
    ) + window(36, 96, 34, 31) + window(150, 96, 34, 31)
    body += (
        '<path d="M39 157h29l-4 18H43z" fill="#b97859"/>'
        '<path d="M42 153q-7-19 5-15q6-21 12-3q15-5 6 18" fill="#92aa70"/>'
        '<circle cx="57" cy="136" r="4" fill="#e8c980" stroke="none"/>'
    )
    return svg(body, 220, 200)


def furniture() -> dict[str, str]:
    bench = svg(
        '<ellipse cx="50" cy="53" rx="45" ry="7" fill="#294e3c" opacity="0.15" stroke="none"/>'
        '<path d="M19 35l-3 18m67-18l3 18" stroke="#526151" stroke-width="6"/>'
        '<path d="M17 19v28m66-28v28" stroke="#596550" stroke-width="5"/>'
        '<rect x="9" y="9" width="82" height="11" rx="3" fill="#b28b5c"/>'
        '<rect x="9" y="23" width="82" height="9" rx="2" fill="#cca26a"/>'
        '<path d="M8 37h84l4 10H4z" fill="#ddba80"/>'
        '<path d="M18 13h59M17 27h62" stroke="#dfb882" stroke-width="2"/>', 100, 64)
    sign = svg(
        '<path d="M87 31v34h9V31" fill="#977e58"/>'
        '<path d="M8 3q84-5 165 1l3 36q-79-3-168 0z" fill="#ecdbad"/>'
        '<path d="M14 9q79-4 151 0M15 32q75-3 151 0" fill="none" stroke="#cfb88a"/>'
        '<circle cx="16" cy="19" r="2" fill="#8f7b53" stroke="none"/>'
        '<circle cx="167" cy="19" r="2" fill="#8f7b53" stroke="none"/>', 184, 72)
    bed = svg(
        '<path d="M11 25h191v90H11z" fill="#9b795b"/>'
        '<path d="M17 20h180v86H17z" fill="#fff0ca"/>'
        '<rect x="22" y="24" width="53" height="75" rx="10" fill="#f7edcf"/>'
        '<path d="M29 35q21-9 40 0M29 88q21 8 40 0" fill="none" stroke="#d9d5b2"/>'
        '<path d="M83 19h112v87H80q8-45 3-87" fill="#679787"/>'
        '<path d="M96 24v79M112 23v81" stroke="#a8c1a1" stroke-width="4"/>'
        '<path d="M136 50q16-20 29 0q-13 24-29 0" fill="#bbcea3" stroke="none"/>'
        '<path d="M6 14h12v107H6zM198 17h11v104h-11z" fill="#9b795b"/>'
        '<path d="M7 12h201" stroke="#bc9870" stroke-width="7"/>', 216, 128)
    shelf = '<path d="M5 8h206v111H5z" fill="#80644f"/>'
    shelf += '<path d="M13 16h190v43H13zM13 66h190v42H13z" fill="#675a46"/>'
    for row in range(2):
        for column in range(4):
            x, y = 21 + column * 46, 22 + row * 49
            shelf += (f'<rect x="{x}" y="{y}" width="33" height="30" rx="6" fill="#c8b484"/>'
                      f'<path d="M{x+4} {y+6}h25" stroke="#e6d3a0" stroke-width="2"/>'
                      f'<circle cx="{x+17}" cy="{y+17}" r="8" fill="#82a493" stroke-width="1.5"/>'
                      f'<path d="M{x+13} {y+17}h8" stroke-width="1.5"/>')
    shelf += '<path d="M5 60h206M5 114h206M5 8h206" stroke="#b39168" stroke-width="7"/>'
    table = svg(
        '<ellipse cx="108" cy="109" rx="101" ry="12" fill="#294e3c" opacity="0.15" stroke="none"/>'
        '<path d="M15 58h187v59H15z" fill="#9f805b"/>'
        '<rect x="6" y="15" width="204" height="76" rx="11" fill="#d8c397"/>'
        '<rect x="15" y="24" width="186" height="58" rx="8" fill="#f1e4bc" stroke="#b9a780"/>'
        '<ellipse cx="108" cy="50" rx="33" ry="24" fill="#78a293"/>'
        '<path d="M102 32h12v12h13v12h-13v12h-12V56H89V44h13z" fill="#fff6d5" stroke="none"/>'
        '<path d="M35 39v20m-7-10h14M177 39v20m-7-10h14" stroke="#abbea0" stroke-width="4"/>'
        '<path d="M29 99h157" stroke="#c5a577" stroke-width="3"/>', 216, 128)
    rug = svg(
        '<rect x="3" y="5" width="314" height="149" rx="12" fill="#819e86" stroke="none"/>'
        '<rect x="12" y="13" width="296" height="133" rx="8" fill="#bac6a3" stroke="#e7dcba" stroke-width="3"/>'
        '<path d="M30 80l18-18 18 18-18 18zM254 80l18-18 18 18-18 18z" fill="#89a68a" stroke="none"/>'
        '<path d="M139 77q-29-29-11-41q28 1 27 37q18-39 39-31q9 29-33 35l-6 24" '
        'fill="#a4b797" stroke="#90a58a" stroke-width="2"/>', 320, 160)
    plaza = svg(
        '<rect x="4" y="4" width="178" height="90" rx="12" fill="#b8b698" stroke="#728d75"/>'
        '<rect x="11" y="11" width="164" height="76" rx="8" fill="#d7ccaa" stroke="#ede1ba"/>'
        '<path d="M25 31h25m-12-12v24M138 68h23m-11-11v23" stroke="#b5b48d" stroke-width="2"/>'
        '<circle cx="93" cy="49" r="22" fill="#b9c4a0" stroke="#7c9a7b"/>'
        '<path d="M84 61q-20-28 4-29q10 9 5 21q7-25 19-19q4 17-16 23l-5 10" '
        'fill="#779875" stroke="none"/>', 186, 98)
    return {"bench.svg": bench, "sign.svg": sign, "bed.svg": bed,
            "storage_shelf.svg": svg(shelf, 216, 128), "healing_table.svg": table,
            "rug.svg": rug, "captain_plaza.svg": plaza}


def tiles() -> dict[str, str]:
    meadow = '<path d="M0 0h48v48H0z" fill="#afc395" stroke="none"/>'
    meadow += ('<path d="M6 11l3-4 3 5m16 19 3-5 2 6m4-25 2-3 2 4M9 39l3-3 2 4" '
               'fill="none" stroke="#9ab282" stroke-width="1.5"/>')
    meadow += '<circle cx="22" cy="17" r="1" fill="#d9d6a3" stroke="none"/>'
    path = ('<path d="M0 0h48v48H0z" fill="#ddd0a7" stroke="none"/>'
            '<path d="M3 9l9-2 5 6-7 4-8-2M31 24l12-2 3 8-9 2-7-3M12 37l8-2 4 7-9 3z" '
            'fill="#e8ddba" stroke="#d1c199" stroke-width="0.8"/>'
            '<path d="M31 8h3M4 29h2m23 15h3" stroke="#bcaf87" stroke-width="1.5"/>')
    grass = '<path d="M0 0h48v48H0z" fill="#8ca975" stroke="none"/>'
    for x, y, shade in [(5, 20, "#678d62"), (23, 16, "#729765"), (40, 23, "#668c62"),
                        (9, 46, "#688e63"), (26, 42, "#597f5d"), (43, 46, "#749568")]:
        grass += (f'<path d="M{x-8} {y}l-3-13 9 8 3-18 4 16 7-10-3 17z" '
                  f'fill="{shade}" stroke="none"/>')
        grass += f'<path d="M{x} {y-3}l1-9" stroke="#a6bc80" stroke-width="1.5"/>'
    hedge = ('<path d="M0 0h48v48H0z" fill="#557b5f" stroke="none"/>'
             '<path d="M22 9v39" stroke="#52644e" stroke-width="7"/>')
    for x, y, radius, fill in [(8, 12, 16, "#64885f"), (31, 9, 18, "#6c9167"),
                               (43, 28, 16, "#60865f"), (14, 32, 20, "#71966a"),
                               (27, 25, 16, "#7ca071")]:
        hedge += f'<circle cx="{x}" cy="{y}" r="{radius}" fill="{fill}" stroke="none"/>'
    hedge += ('<path d="M5 28q5-7 11-5m8-12q5-4 10-2m-6 28 6-2" '
              'fill="none" stroke="#9ab47d" stroke-width="2.3"/>')
    water = ('<path d="M0 0h48v48H0z" fill="#75a7a3" stroke="none"/>'
             '<path d="M-4 13q8 5 17 0t18 0 21 0M-5 38q8 5 19 0t19 0 20 0" '
             'fill="none" stroke="#91bdb1" stroke-width="2"/>'
             '<path d="M21 23h12M3 45h7" stroke="#acd1bf" stroke-width="1"/>')
    wood = ('<path d="M0 0h48v48H0z" fill="#ddc59b" stroke="none"/>'
            '<path d="M0 16h48M0 32h48M17 0v16m16 0v16M12 32v16" stroke="#bfaa83" '
            'stroke-width="1.3"/><path d="M4 7h9m11 3h19M3 23h22m10 1h7M19 40h24" '
            'stroke="#ebd7af" stroke-width="1.5"/>')
    return {f"tile_{name}.svg": svg(body, 48, 48) for name, body in [
        ("meadow", meadow), ("path", path), ("grass", grass),
        ("hedge", hedge), ("water", water), ("wood", wood)]}


def flowers() -> str:
    body = '<ellipse cx="42" cy="45" rx="38" ry="7" fill="#7f9d6c" opacity="0.3" stroke="none"/>'
    for index in range(8):
        x, y = 9 + (index * 23) % 67, 13 + (index * 11) % 26
        body += f'<path d="M{x} {y+14}v-14m0 10-5-3" stroke="#69885a" stroke-width="2"/>'
        fill = ["#e6bc85", "#f0d5a1", "#db9b88"][index % 3]
        for petal in range(5):
            angle = math.tau * petal / 5
            body += (f'<circle cx="{x + math.cos(angle)*3:.2f}" '
                     f'cy="{y + math.sin(angle)*3:.2f}" r="3" fill="{fill}" stroke="none"/>')
        body += f'<circle cx="{x}" cy="{y}" r="2" fill="#f6e7b6" stroke="none"/>'
    return svg(body, 86, 58)


def room() -> str:
    return svg(
        '<path d="M0 0h960v560H0zM80 80v400h800V80z" fill="#668277" fill-rule="evenodd" stroke="none"/>'
        '<path d="M80 80V57h800v23M80 480h360v40H80M480 480h400v40H480" fill="#829d88" stroke="none"/>'
        '<path d="M80 80h800M80 479h360m40 0h400" stroke="#d4d7ae" stroke-width="5"/>'
        '<path d="M0 82h80v398H0M880 82h80v398h-80" fill="#758f80" stroke="none"/>'
        '<path d="M67 80v400m826-400v400" stroke="#91a58a" stroke-width="3"/>'
        '<path d="M439 480h42v42h-42" fill="#d8be8e"/>'
        '<path d="M445 499h30" stroke="#f1ddb2" stroke-width="3"/>'
        '<path d="M112 25h60M800 25h50" stroke="#a0b095" stroke-width="2"/>', 960, 560)


def canopy() -> str:
    body = '<g opacity="0.08" fill="#183f32" stroke="none">'
    for x, y, radius in [(21, 17, 70), (156, 1, 80), (72, 77, 66), (842, 27, 92),
                          (950, 88, 72), (896, 523, 101), (5, 524, 95)]:
        body += f'<ellipse cx="{x}" cy="{y}" rx="{radius}" ry="{radius * 0.72:.1f}"/>'
    body += '</g><path d="M95 0h66L485 560h-52zM640 0h25L950 500v60z" fill="#fff5c7" opacity="0.05" stroke="none"/>'
    return svg(body, 960, 560)


def main() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    images = {"home.svg": home(), "clinic.svg": clinic(), "flowers.svg": flowers(),
              "room_walls.svg": room(), "canopy_shadow.svg": canopy(),
              "pollen.svg": svg('<circle cx="8" cy="8" r="6" fill="#fff8cb" opacity="0.25" stroke="none"/>'
                                '<circle cx="8" cy="8" r="2" fill="#fff7c6" stroke="none"/>', 16, 16),
              "lily.svg": svg('<ellipse cx="24" cy="27" rx="21" ry="12" fill="#5b9279" stroke="none"/>'
                              '<path d="M24 27l14 11H24z" fill="#75a7a3" stroke="none"/>'
                              '<path d="M24 25q-16-4-9-12q9 0 9 12q-3-19 5-17q7 12-5 17q14-16 17-6q-6 11-17 6" '
                              'fill="#e9c59e" stroke="#b9987b" stroke-width="1"/>'
                              '<circle cx="25" cy="23" r="3" fill="#efd493" stroke="none"/>', 48, 48)}
    images.update(furniture())
    images.update(tiles())
    for filename, body in images.items():
        (ASSETS / filename).write_text(body, encoding="utf-8")
    print(f"フィールド素材生成 OK: 独立した SVG {len(images)} 点")


if __name__ == "__main__":
    main()
