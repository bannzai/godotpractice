"""暁の境界の独自ベクター素材を決定的に再生成する。第三者画像は使わない。"""
from pathlib import Path
import math
import random

ROOT = Path(__file__).resolve().parents[2] / 'assets'
NAVY, JADE, GOLD, CREAM, CORAL = '#15283e', '#43877e', '#dbb66c', '#f5e8c8', '#d47463'
DEFS = '''<defs>
<linearGradient id="cloth" x2="1" y2="1"><stop stop-color="#80b9ac"/><stop offset="1" stop-color="#265651"/></linearGradient>
<linearGradient id="steel" x2="1" y2="0"><stop stop-color="#aac4cd"/><stop offset=".45" stop-color="#f7efce"/><stop offset=".5" stop-color="#6a8c9e"/><stop offset="1" stop-color="#304d66"/></linearGradient>
<linearGradient id="red" x2="1" y2="1"><stop stop-color="#e89d7d"/><stop offset="1" stop-color="#8c3f47"/></linearGradient>
<linearGradient id="sky" x2="0" y2="1"><stop stop-color="#13293e"/><stop offset=".55" stop-color="#617f83"/><stop offset="1" stop-color="#e4bc86"/></linearGradient>
<radialGradient id="sun"><stop stop-color="#fff7d9" stop-opacity=".75"/><stop offset="1" stop-color="#f6db95" stop-opacity="0"/></radialGradient>
</defs>'''


def write(folder, name, body, width=192, height=224):
    dest = ROOT / folder / f'{name}.svg'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">{DEFS}{body}</svg>\n')


def path(d, fill, stroke=NAVY, sw=3):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round" stroke-linecap="round"/>'


def ellipse(x, y, rx, ry, fill, stroke='none', sw=2):
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'


def face(hair, eyes=JADE, beard=False):
    s = ellipse(92, 67, 25, 29, '#edbf99', NAVY, 3)
    s += path('M67 68 Q53 26 88 30 Q124 25 120 71 L109 57 94 43 79 61Z', hair)
    s += path('M68 64 L72 77 M112 63 L110 76', 'none', '#c48e74', 2)
    s += ellipse(83, 68, 2.8, 3, eyes) + ellipse(102, 68, 2.8, 3, eyes)
    s += path('M89 80 Q94 83 99 79', 'none', NAVY, 1.5)
    if beard:
        s += path('M72 79 L79 98 94 105 110 94 115 78 100 88 89 89Z', hair)
    return s


def body(kind):
    s = ellipse(96, 213, 55, 7, '#101e32', 'none')
    # マント、髪、帽子、盾の形を分け、盤面でも職種の輪郭を保つ。
    if kind == 'enemy_sword':
        s += path('M71 88 L42 116 30 204 76 183 92 156 121 185 151 205 141 116 117 85Z', '#51445e', GOLD, 2)
        s += path('M77 151 L66 208 86 213 97 171 116 212 138 212 121 151Z', '#293648')
        s += path('M72 87 L117 85 126 143 106 170 72 163 62 120Z', '#536172', GOLD, 3)
        s += path('M76 92 L104 146 M75 146 L121 143', 'none', '#a27d80', 7)
        s += path('M59 102 L48 122 58 152 73 141 M120 100 L141 115 141 144 126 141', '#536172', GOLD, 2)
        s += path('M66 52 L81 20 94 8 112 28 123 57 114 86 88 97 69 81Z', '#344256', GOLD, 2)
        s += path('M71 60 L87 53 111 55 118 64 102 77 77 74Z', '#15283e')
        s += path('M79 62 L87 62 M102 62 L111 60', 'none', CORAL, 3)
        s += path('M94 15 L94 51 M93 78 L96 88', 'none', '#aab8bf', 3)
        s += path('M67 89 L91 106 119 89 111 114 80 113Z', CORAL)
    elif kind == 'enemy_lance':
        s += path('M62 82 L43 184 71 174 95 190 131 173 146 182 127 83Z', '#624851', GOLD, 2)
        s += path('M70 157 L60 211 87 213 97 170 110 213 137 211 125 155Z', '#2a384b')
        s += path('M62 87 L125 85 136 142 116 173 65 169 51 117Z', '#586271', GOLD, 3)
        s += path('M74 93 L93 130 116 94 M72 148 L121 148', 'none', '#afbfc1', 5)
        s += path('M65 43 L79 29 113 29 125 45 122 74 107 93 82 88 67 69Z', '#405066', GOLD, 3)
        s += path('M77 29 L73 13 83 24 111 24 122 12 119 32', '#a6b5bc', GOLD, 2)
        s += path('M70 54 L121 52 118 65 73 66Z', '#142338')
        s += path('M77 59 L88 59 M103 59 L115 58', 'none', CORAL, 3)
        s += path('M96 65 L96 84', 'none', '#adb9bb', 3)
        s += path('M36 99 L76 92 89 143 66 179 31 151Z', '#4c4b67', GOLD, 4)
        s += path('M60 105 L70 143 62 159 43 141Z', '#bd8990', GOLD, 2)
    elif kind == 'sword':
        s += path('M76 86 Q39 117 39 192 L67 183 87 199 130 184 140 110 106 85Z', 'url(#red)')
        s += path('M54 165 Q45 117 71 101 M65 173 L64 129', 'none', '#efb792', 2)
        s += path('M76 160 L70 204 91 207 96 167 106 204 129 204 117 153Z', NAVY)
        s += path('M70 197 L66 211 92 211 92 201 M107 198 L106 212 133 212 126 200', '#5e5c61')
        s += path('M72 92 L114 90 125 139 116 166 68 163 66 119Z', 'url(#steel)')
        s += path('M76 95 L94 123 112 94 M70 144 L120 144 M78 150 L113 151', 'none', GOLD, 4)
        s += path('M66 102 L50 114 55 148 71 141 M117 100 L137 113 138 141 124 144', 'url(#steel)')
        s += face('#334457')
        s += path('M78 34 L88 17 94 32 117 28 112 44', '#334457')
        s += path('M70 90 L94 104 115 89 106 112 85 113Z', CORAL)
    elif kind == 'lance':
        s += path('M70 86 L42 170 71 186 99 162 125 186 145 163 118 86Z', 'url(#cloth)')
        s += path('M70 155 L67 209 86 212 96 170 107 211 131 211 120 155Z', '#416273')
        s += path('M69 90 L116 90 129 153 111 174 72 170 62 128Z', 'url(#steel)')
        s += path('M75 105 L93 131 112 105 M71 147 L118 147', 'none', GOLD, 4)
        s += face('#90765d')
        s += path('M65 58 Q64 27 93 26 Q121 28 121 59 L109 57 95 37 80 57Z', 'url(#steel)')
        s += path('M89 27 Q76 2 64 13 Q79 9 100 27', JADE)
        s += path('M53 109 L79 103 87 150 64 166 42 144Z', JADE, GOLD, 4)
        s += path('M62 116 L67 153 M52 132 L78 127', 'none', CREAM, 3)
    elif kind == 'axe' or kind == 'raider':
        enemy = kind == 'raider'
        leather = '#a36e49' if not enemy else '#794456'
        s += path('M63 96 L38 125 37 172 58 174 70 130 M124 95 L149 120 156 163 132 171 118 132', '#d4a782')
        s += path('M69 155 L52 207 77 212 96 169 112 210 142 210 126 155Z', '#3d4a53')
        s += path('M61 88 L124 88 136 156 117 179 65 169 54 121Z', leather)
        s += path('M56 94 L72 85 122 144 113 157Z', '#d8c7a3')
        s += path('M68 145 L125 144 128 161 65 164Z', '#343b44')
        s += path('M50 98 L65 86 77 101 59 117Z', 'url(#steel)')
        s += ellipse(103, 153, 9, 8, GOLD, NAVY, 3)
        s += face('#523d3c' if enemy else '#a25840', CORAL if enemy else JADE, True)
        if enemy:
            s += path('M64 48 L44 29 57 66 M116 47 L141 30 127 68', '#d9d1b7')
            s += path('M68 54 L83 42 104 42 120 57 109 73 76 73Z', '#635862')
            s += path('M77 63 L87 63 M100 63 L111 63', 'none', CORAL, 3)
        else:
            s += path('M64 47 L76 30 107 30 121 49 101 44 85 49Z', '#a25840')
    elif kind in ('bow', 'archer'):
        enemy = kind == 'archer'
        color = '#777395' if enemy else JADE
        s += path('M68 96 L42 110 49 166 77 157 117 176 140 132 116 94Z' if enemy else 'M68 96 L51 128 55 199 89 180 123 197 139 137 116 94Z', color)
        s += path('M78 151 L64 208 84 211 100 165 112 209 132 208 121 153Z', '#384959')
        s += path('M77 91 L112 95 122 147 104 175 72 164 65 127Z', '#bd9368')
        s += path('M74 97 L112 152 M71 150 L116 144', 'none', '#654d4c', 7)
        s += face('#d7bc91' if not enemy else '#bebbc2')
        if enemy:
            s += path('M62 58 Q61 28 93 27 Q122 31 122 59 L108 54 99 44 75 61Z', '#535676', GOLD, 2)
            s += path('M75 31 Q81 11 115 9 L94 29Z', CORAL)
            s += path('M65 68 L88 59 114 63 109 74 82 75Z', '#303e53', GOLD, 1)
            s += path('M106 97 Q150 63 177 95 L158 90 168 114 127 106Z', color)
            s += path('M72 174 L84 178 78 205 62 206Z M114 177 L127 179 135 205 115 205Z', 'url(#steel)')
        else:
            s += path('M57 73 Q50 30 89 19 Q126 29 127 77 L112 60 98 40 77 52 67 76Z', color)
        s += path('M66 88 L94 104 124 86 116 117 88 111Z', color)
        s += path('M125 96 L139 87 151 155 136 162Z', '#725040')
        s += path('M131 92 L123 52 M139 91 L139 50 M145 93 L152 55', 'none', CREAM, 3)
        s += path('M117 49 L129 53 124 63 M134 45 L144 51 136 60', color, GOLD, 2)
    elif kind == 'healer':
        s += path('M69 69 Q51 91 47 150 L66 139 58 111 M112 69 Q131 103 135 149 L117 137 118 98', '#cfb5a7')
        s += path('M73 94 L111 92 126 133 150 202 Q100 223 45 204 L65 134Z', CREAM)
        s += path('M74 99 L86 148 68 210 50 204 65 146 M109 96 L99 151 117 212 142 204 124 147Z', 'url(#cloth)')
        s += path('M83 102 L95 137 105 102 M72 192 Q95 201 120 192', 'none', GOLD, 3)
        s += face('#d9c2ad')
        s += path('M64 58 Q64 25 92 25 Q123 26 125 59 L111 49 96 39 80 49Z', CREAM)
        s += path('M69 49 L94 37 119 51', 'none', GOLD, 4)
        s += ellipse(94, 42, 5, 7, JADE)
        s += path('M66 119 L49 131 65 156 79 148 M122 115 L139 130 132 150 115 144', CREAM)
    else:
        s += path('M60 77 L30 204 71 192 96 220 126 191 162 203 137 79Z', '#5d4054', GOLD, 4)
        s += path('M70 161 L59 209 88 212 97 170 110 211 139 211 127 158Z', '#2a334a')
        s += path('M60 87 L128 84 146 140 121 176 67 171 46 129Z', 'url(#steel)', GOLD, 4)
        s += path('M56 85 L35 99 44 124 68 122 M128 85 L154 98 155 122 131 122', '#384b61', GOLD, 4)
        s += path('M73 98 L96 151 119 97 M68 150 L127 150', 'none', GOLD, 4)
        s += path('M70 41 L119 41 125 78 107 96 82 92 65 70Z', '#39465b', GOLD, 3)
        s += path('M71 58 L87 64 M103 64 L118 57', 'none', CORAL, 4)
        s += path('M91 47 L97 79 102 46', 'none', GOLD, 3)
        s += path('M67 43 L61 20 80 29 93 8 106 29 125 19 120 44Z', GOLD)
        s += ellipse(94, 29, 5, 6, CORAL)
    return s


def weapon(kind):
    # 支点は(48,100)。腕の位置に合わせてNode2Dで回転する。
    if kind == 'enemy_sword':
        return path('M43 92 Q68 67 72 9 Q96 59 57 96Z', 'url(#steel)', NAVY, 2) + path('M33 89 L65 99 60 106 31 97Z', GOLD) + path('M43 100 L37 129 47 132 53 105Z', '#6b4554')
    if kind == 'enemy_lance':
        return path('M46 33 L46 158 53 158 53 33Z', '#946e69') + path('M49 2 L29 34 43 30 44 48 56 48 58 29 72 35Z', 'url(#steel)', NAVY, 2) + path('M55 45 L82 48 68 64 55 60Z', CORAL, GOLD, 1)
    if kind in ('sword', 'boss'):
        s = path('M43 92 L40 27 49 7 58 27 53 92Z', 'url(#steel)', NAVY, 2)
        s += path('M30 91 L68 91 66 99 31 99Z', GOLD)
        s += path('M44 101 L43 125 54 125 53 101Z', '#74544d')
        s += ellipse(49, 128, 8, 6, GOLD)
        if kind == 'boss':
            s += path('M40 48 L28 30 33 75 43 89 M57 47 L72 29 67 75 53 91', '#624457', GOLD, 2)
        return s
    if kind == 'lance':
        return path('M46 36 L46 158 52 158 52 36Z', '#b19066', NAVY, 2) + path('M49 1 L37 33 49 51 61 32Z', 'url(#steel)', NAVY, 2) + path('M54 39 Q85 51 76 67 L54 58Z', CORAL, GOLD, 1)
    if kind in ('axe', 'raider'):
        return path('M45 52 L45 150 54 150 54 52Z', '#a98558') + path('M47 34 Q27 44 8 26 Q-1 63 16 83 Q36 62 49 66 L53 65 Q78 71 87 83 Q99 52 87 25 Q69 46 54 35Z', 'url(#steel)', NAVY, 3) + path('M49 27 L49 75', 'none', GOLD, 7)
    if kind == 'archer':
        return path('M35 6 Q16 31 53 44 Q87 81 52 115 Q16 129 36 154', 'none', '#afbdcf', 7) + path('M36 9 L36 152', 'none', CREAM, 1.5) + path('M7 84 L90 84 M83 78 L92 84 83 89', 'none', CORAL, 3)
    if kind == 'bow':
        return path('M37 12 Q91 76 38 150 Q70 77 37 12', '#d9b270', NAVY, 3) + path('M37 12 L37 150', 'none', CREAM, 1.5) + path('M8 84 L90 84 M83 78 L92 84 83 89', 'none', CREAM, 2)
    return path('M47 53 L47 150 54 150 54 53Z', '#ba9565') + path('M50 11 Q16 25 27 53 Q45 71 70 51 Q84 24 50 11Z', GOLD) + path('M50 21 L36 41 50 59 65 40Z', JADE, CREAM, 2) + ellipse(50, 37, 5, 8, CREAM)


def make_units():
    for kind in ('sword', 'lance', 'axe', 'bow', 'healer', 'raider', 'archer', 'boss', 'enemy_sword', 'enemy_lance'):
        b, w = body(kind), weapon(kind)
        write('units', kind + '_body', b)
        write('units', kind + '_weapon', w, 96, 160)
        write('units', kind, b + f'<g transform="translate(92,25)">{w}</g>')


def mountain(x, y, scale, color):
    return f'<g transform="translate({x},{y}) scale({scale})">' + path('M-210 190 L-127 66 -89 113 5 -30 79 79 132 51 250 190Z', color, 'none') + path('M-54 60 L5 -30 59 45 28 33 6 8 -17 46Z', '#adc0b6', 'none') + '</g>'


def tree(x, y, scale, color):
    return f'<g transform="translate({x},{y}) scale({scale})">' + path('M0 -105 L-29 -51 -17 -51 -42 -15 -21 -15 -48 19 49 19 22 -15 42 -15 17 -51 29 -51Z', color, 'none') + path('M-5 14 L-5 45 6 45 5 14Z', '#203f48', 'none') + '</g>'


def make_backgrounds():
    sky = '<path d="M0 0H1280V720H0Z" fill="url(#sky)"/>'
    sky += ellipse(900, 300, 260, 260, 'url(#sun)') + ellipse(900, 300, 91, 91, '#e8cca0')
    for j in range(8):
        y = 107 + j * 48
        sky += path(f'M{240+j*47} {y} Q{550+j*48} {y-32} 1280 {y+8}', 'none', '#d4d6bd', .6)
    rng = random.Random(41)
    for _ in range(65):
        x, y = rng.randrange(30, 1240), rng.randrange(20, 270)
        sky += ellipse(x, y, .8, .8, '#ece9ca')
    write('backgrounds', 'sky', sky, 1280, 720)
    mountains = mountain(250, 398, 1.4, '#496774') + mountain(630, 350, 1.1, '#567880') + mountain(1100, 348, 1.3, '#5e7c82')
    mountains += path('M0 489 Q180 377 343 463 T710 450 T1280 423 V720H0Z', '#365e65', 'none')
    # 谷をまたぐ橋と境界の塔。
    mountains += path('M723 451 Q895 382 1087 409 L1087 432 Q900 410 723 481Z', '#273f50', GOLD, 1)
    for x, y, h in ((767, 359, 87), (1031, 270, 151), (1076, 312, 102)):
        mountains += path(f'M{x} {y+h} V{y} H{x+34} V{y+h}Z', '#294955', '#a3aa8b', 1)
        mountains += path(f'M{x-6} {y} L{x+17} {y-35} {x+40} {y}Z', '#293c51', GOLD, 1)
        mountains += path(f'M{x+13} {y+16} H{x+21} V{y+32} H{x+13}Z', GOLD, 'none')
    write('backgrounds', 'mountains', mountains, 1280, 720)
    fore = path('M0 610 Q179 553 333 617 Q681 676 882 571 Q1110 502 1280 560 V720H0Z', '#172f40', 'none')
    fore += path('M600 720 L792 616 988 583 1115 525 1188 526 1013 602 880 653 807 720Z', '#386567', 'none')
    for x, y, scale in ((-10, 560, 2.8), (111, 596, 1.9), (212, 631, 1.3), (1249, 503, 2.6), (1146, 538, 1.8), (1188, 589, 1.7)):
        fore += tree(x, y, scale, '#132b3a')
    for _ in range(50):
        x, y = rng.randint(5, 1275), rng.randint(620, 712)
        fore += path(f'M{x} {y} l4 -15 4 15 m-4 -4 10 -9', 'none', '#527d73', 1)
    write('backgrounds', 'foreground', fore, 1280, 720)
    # キーアートは右側に人物、左側をタイトル文言用の静かな空間にする。
    keyart = ''
    keyart += '<g transform="translate(975,388) scale(1.08)">' + body('lance') + '<g transform="translate(92,25)">' + weapon('lance') + '</g></g>'
    keyart += '<g transform="translate(740,411) scale(1.28)">' + body('healer') + '<g transform="translate(92,25)">' + weapon('healer') + '</g></g>'
    keyart += '<g transform="translate(876,368) scale(1.48)">' + body('sword') + '<g transform="translate(92,25) rotate(14,48,100)">' + weapon('sword') + '</g></g>'
    write('backgrounds', 'keyart', keyart, 1280, 720)


def make_terrain():
    for kind, fill in [('plain', '#72988a'), ('forest', '#4f806f'), ('mountain', '#7c8b85'), ('water', '#4a8093'), ('fort', '#9b9c87')]:
        s = path('M0 0H96V96H0Z', fill, '#bac0a2', 1)
        s += path('M2 93H94V3', 'none', '#28484d', 3)
        if kind == 'plain':
            for x, y in [(18, 31), (67, 68), (43, 49), (79, 22)]:
                s += path(f'M{x} {y} l-3 -8 m3 8 4 -10 m-4 10 8 -5', 'none', '#476e60', 2)
                s += ellipse(x + 8, y - 5, 2, 2, GOLD)
        if kind == 'forest':
            s += tree(28, 51, .36, '#284f48') + tree(68, 38, .45, '#315d51') + tree(52, 69, .43, '#397262')
        if kind == 'mountain':
            s += mountain(35, 49, .2, '#4c6366') + mountain(64, 56, .17, '#627b79')
        if kind == 'water':
            for y in (19, 39, 60, 79):
                s += path(f'M9 {y} Q25 {y-8} 43 {y} T86 {y}', 'none', '#9bc2bd', 2)
        if kind == 'fort':
            s += path('M19 32H28V25H37V33H59V25H69V33H78V73H19Z', '#d3c5a2', '#526365', 3)
            s += path('M39 73V54Q49 37 58 54V73 M20 46H77 M25 58H34 M63 59H74', '#51646a', '#526365', 3)
            s += path('M48 28V9L70 15 48 20', CORAL, GOLD, 2)
        write('terrain', kind, s, 96, 96)
    crest = path('M96 9 L113 54 163 30 145 84 184 112 133 128 148 181 102 158 71 209 66 154 15 171 41 127 8 93 56 83 46 30 85 56Z', GOLD, NAVY, 3)
    crest += path('M96 35 L104 89 141 105 103 116 96 163 84 118 52 104 86 88Z', CREAM, NAVY, 3)
    crest += ellipse(96, 103, 15, 15, JADE, GOLD, 4)
    write('ui', 'crest', crest)
    write('ui', 'potion', path('M35 16H61V35L76 58V81Q48 100 20 81V58L35 35Z', '#bad4c7', NAVY, 3) + path('M25 59Q49 65 71 58V78Q50 90 25 78Z', JADE, 'none') + path('M35 12H61V25H35Z', GOLD) + path('M47 52V76 M36 64H59', 'none', CREAM, 5), 96, 96)
    write('ui', 'cursor', path('M2 25V2H25 M71 2H94V25 M94 71V94H71 M25 94H2V71', 'none', '#fff0b6', 5), 96, 96)
    write('ui', 'panel', path('M12 2H308L318 12V148L308 158H12L2 148V12Z', NAVY, GOLD, 2) + path('M12 35V13H34 M286 13H307V35 M307 125V146H286 M34 146H13V125', 'none', '#567c79', 1), 320, 160)


if __name__ == '__main__':
    make_units()
    make_backgrounds()
    make_terrain()
    print('tactics 独自SVG 43点を生成')
