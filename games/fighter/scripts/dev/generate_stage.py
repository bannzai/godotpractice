"""独自の黄昏闘技場とUIを生成する。同じ入力から同一SVGを保存する。"""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'assets'


def save(name, body, width=1280, height=720):
    target = ASSETS / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">{body}</svg>\n')


def generate():
    save('stage/sky.svg', '''<defs><linearGradient id="s" x2="0" y2="1"><stop stop-color="#101d36"/><stop offset=".5" stop-color="#805776"/><stop offset=".8" stop-color="#e4a275"/><stop offset="1" stop-color="#fdcc8a"/></linearGradient><radialGradient id="a"><stop stop-color="#ffc78a" stop-opacity=".6"/><stop offset="1" stop-color="#ffc78a" stop-opacity="0"/></radialGradient></defs><rect width="1280" height="720" fill="url(#s)"/><circle cx="880" cy="310" r="240" fill="url(#a)"/><circle cx="880" cy="310" r="96" fill="#fdd39a"/><path d="M0 274 Q210 205 426 270T845 272T1280 225L1280 255Q1020 328 801 302T384 301T0 301Z" fill="#d9a2a0" opacity=".24"/><path d="M0 388L136 304 272 361 420 284 526 338 710 300 860 368 998 313 1132 350 1280 295V620H0Z" fill="#6d5979" opacity=".55"/>''')
    city = ['<g stroke="#bfa1a1" stroke-opacity=".12">']
    for i in range(31):
        x = -50 + i * 47
        h = 72 + (i * 53) % 137
        y = 465 - h
        city.append(f'<path d="M{x} 480V{y}h12v-14h15v14h17v{480-y}Z" fill="#{["35445d","414660","4c4c69"][i%3]}"/>')
        for dx in range(7, 40, 9):
            for dy in range(10, h, 17):
                if (i + dx + dy) % 4 != 0:
                    city.append(f'<rect x="{x+dx}" y="{y+dy}" width="3" height="6" fill="#f3c694" opacity="{.25+(i%4)*.1}" stroke="none"/>')
    city.append('</g><path d="M0 447H1280M0 461H1280" stroke="#f6bf89" opacity=".5" stroke-width="2"/>')
    save('stage/city.svg', ''.join(city))
    arena = ['''<defs><linearGradient id="deck" x2="0" y2="1"><stop stop-color="#355666"/><stop offset="1" stop-color="#0c1d30"/></linearGradient><linearGradient id="metal"><stop stop-color="#112e40"/><stop offset=".5" stop-color="#466272"/><stop offset="1" stop-color="#162b40"/></linearGradient></defs><path d="M0 466Q640 540 1280 466V570H0Z" fill="#132a40"/><path d="M0 464Q640 538 1280 464M0 485Q640 559 1280 485" fill="none" stroke="#9d9292" stroke-width="2"/>''']
    for i in range(75):
        x = i * 18
        y = 480 + 29 * (1 - ((x - 640) / 640) ** 2)
        arena.append(f'<path d="M{x} {y:.2f}v7m0 9v7" stroke="{["#68bdb4","#b9b3a0","#dfb17b"][i%3]}" stroke-width="4" opacity=".55"/>')
    arena.append('''<path d="M0 548Q640 605 1280 548V574H0Z" fill="#0e2034"/><path d="M0 550Q640 607 1280 550" fill="none" stroke="#f5c68e" stroke-width="3"/><path d="M0 570H1280V720H0Z" fill="url(#deck)"/><path d="M0 570H1280" stroke="#9fe2d3" stroke-width="3"/><path d="M0 577H1280" stroke="#152b3c" stroke-width="5"/>''')
    for x in range(-640, 1921, 140):
        arena.append(f'<path d="M640 510L{x} 720" stroke="#8ba7a8" opacity=".14"/>')
    for y in [591, 615, 647, 691]:
        arena.append(f'<path d="M0 {y}H1280" stroke="#98a7ad" opacity=".14"/>')
    arena.append('''<ellipse cx="640" cy="639" rx="420" ry="53" fill="none" stroke="#e5bc86" stroke-width="2" opacity=".6"/><ellipse cx="640" cy="639" rx="389" ry="42" fill="none" stroke="#78b9b0" opacity=".35"/><path d="M589 631H691L718 641 691 651H589L562 641Z" fill="none" stroke="#c7ab82" opacity=".55"/>''')
    # 両端の照明塔とトラスは対称な舞台装置。キャラクターと重ならない位置にする。
    for x, direction in [(0, 1), (1280, -1)]:
        arena.append(f'<g transform="translate({x},0) scale({direction},1)"><path d="M20 483V200H82V483Z" fill="url(#metal)" stroke="#5c7887" stroke-width="2"/><path d="M28 198V171H72V198M39 170V143H58V170" fill="#263d56"/><path d="M16 252H87M16 332H87M16 420H87" stroke="#8a9295" stroke-width="8"/><path d="M42 213H58V239H42ZM42 270H58V316H42ZM42 350H58V398H42Z" fill="#efb77d"/><path d="M75 233L274 141 287 163 82 263Z" fill="#1d354b" stroke="#597182" stroke-width="2"/><path d="M100 235L117 217M144 216L161 197M188 194L205 174M232 172L249 154" stroke="#708797" stroke-width="5"/><path d="M276 160V207" stroke="#243b4c" stroke-width="4"/><path d="M257 209Q276 185 295 209V214H257Z" fill="#ffe2ad"/></g>')
    save('stage/arena.svg', ''.join(arena))
    save('stage/haze.svg', '''<defs><linearGradient id="h" x2="0" y2="1"><stop stop-color="#f8c891" stop-opacity="0"/><stop offset=".7" stop-color="#f8c891" stop-opacity=".09"/><stop offset="1" stop-color="#f8c891" stop-opacity="0"/></linearGradient></defs><path d="M0 393Q240 361 480 405T960 398T1280 378V548H0Z" fill="url(#h)"/>''')
    save('effects/spark.svg', '<path d="M16 0L20 12 32 16 20 20 16 32 12 20 0 16 12 12Z" fill="#fff7d8"/>', 32, 32)
    save('effects/guard.svg', '<path d="M64 6L112 30V72L64 122 16 72V30Z" fill="#67e6df" fill-opacity=".12" stroke="#b5fff1" stroke-width="6"/><path d="M64 24L95 40V66L64 98 33 66V40Z" fill="none" stroke="#67e6df" stroke-width="3"/>',128,128)
    save('effects/impact.svg', '<path d="M94 3L99 51 135 21 116 68 180 69 126 90 163 134 106 109 95 175 77 115 23 149 58 100 1 76 63 69 39 17 79 54Z" fill="#fff4bd"/><path d="M90 43L105 71 136 84 108 98 88 131 73 101 46 80 77 71Z" fill="#fffdfa"/>',180,180)
    save('effects/wave-teal.svg', '<path d="M4 43Q42 14 83 23L61 4Q127 8 153 48Q124 93 57 88L80 72Q41 85 4 59L48 51Z" fill="#3fd5c9" fill-opacity=".65"/><path d="M32 47Q86 14 143 48Q90 82 32 55L90 48Z" fill="#bffff0"/><path d="M85 24Q120 21 139 48Q121 72 87 74" fill="none" stroke="#fcfff0" stroke-width="4"/>',160,96)
    save('effects/wave-amber.svg', '<path d="M8 15L81 28 70 4 116 26 107 5 156 48 108 90 117 66 71 92 81 68 8 81 40 50Z" fill="#ef853e" fill-opacity=".75"/><path d="M40 34L110 34 134 48 110 65 40 66 64 50Z" fill="#ffcf78"/><path d="M74 43L121 44 132 48 121 53 74 55 92 49Z" fill="#fffee3"/>',160,96)
    save('ui/health-frame.svg','<path d="M1 1H484L499 15V37H1Z" fill="#091726" stroke="#739ca6" stroke-width="2"/><path d="M6 5H480L490 15H6Z" fill="#d6ecdd" opacity=".08"/>',500,38)
    save('ui/round-medal.svg','<path d="M20 1L37 11V29L20 39 3 29V11Z" fill="#f3c98c" stroke="#fff0cf" stroke-width="2"/><path d="M20 8L24 17 31 20 24 23 20 32 16 23 9 20 16 17Z" fill="#684833"/>',40,40)
    # 同梱OFLフォントを輪郭に変換し、SVGのフォント依存をなくす。
    font = TTFont(ASSETS / 'fonts/font.ttf')
    glyphs = font.getGlyphSet(location={'wght': 900})
    cmap = font.getBestCmap()
    title = ['<path d="M0 99H513L483 115H0Z" fill="#5ae2d0"/><path d="M368 99H513L483 115H350Z" fill="#ffc37b"/>']
    for i, char in enumerate('燈環闘技'):
        pen = SVGPathPen(glyphs)
        glyphs[cmap[ord(char)]].draw(pen)
        path = pen.getCommands()
        title.append(f'<path transform="translate({8+i*126},91) scale(.114,-.114)" d="{path}" fill="#fff1d1"/>')
    save('ui/title-logo.svg',''.join(title),520,120)
    print('舞台4層・エフェクト5種・UI3種を生成')


if __name__ == '__main__':
    generate()
