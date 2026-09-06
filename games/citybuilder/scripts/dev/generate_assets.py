"""街の独自 SVG と PCM 音声を、固定シードで冪等に再生成する。"""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[2] / 'assets'
INK = '#28464e'
MINT = '#83bba5'
CREAM = '#f9ebca'
CORAL = '#de826e'
GOLD = '#e8ba64'


def svg(name, body, width=64, height=80):
    """同じ入力から同じ SVG を上書きする。"""
    path = ROOT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}"><g stroke-linejoin="round" stroke-linecap="round">{body}</g></svg>\n')


def rect(x, y, w, h, fill, stroke=INK, r=0):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" stroke="{stroke}" stroke-width="1.3"/>'


def path(d, fill, stroke=INK, sw=1.4):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'


def ellipse(x, y, rx, ry, fill, opacity=1):
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}" opacity="{opacity}"/>'


def line(x, y, xx, yy, color=INK, sw=1):
    return f'<path d="M{x} {y}L{xx} {yy}" fill="none" stroke="{color}" stroke-width="{sw}"/>'


def shadow():
    return ellipse(34, 69, 27, 7, '#234b47', .18)


def windows(xs, ys, width=6, height=8, color='#baded8'):
    out = ''
    for y in ys:
        for x in xs:
            out += rect(x, y, width, height, color, INK, .5)
            out += line(x + 1, y + height, x + width - 1, y + height, CREAM, 1.8)
    return out


def tree(x=32, y=54, scale=1):
    return f'<g transform="translate({x} {y}) scale({scale})">' + ellipse(0, 11, 13, 4, '#28464e', .15) + path('M-2 10L-2 -8L3 -8L3 10Z', '#ad8760') + ellipse(0, -10, 13, 16, '#488b78') + ellipse(-4, -15, 9, 10, '#82b79a') + ellipse(-6, -19, 4, 4, '#b0d1a5') + line(0, 1, -5, -7, '#436f5b', 1.8) + '</g>'


def building(body):
    return shadow() + body


def generate_sprites():
    """用途ごとに輪郭と装飾を変えた独立した素材を保存する。"""
    svg('sprites/residential.svg', building(
        rect(14, 38, 37, 29, CREAM) + path('M51 38L58 33V61L51 67Z', '#d8bd94') + path('M8 39L31 16L55 38Z', CORAL) + path('M31 16L38 12L61 33L55 38Z', '#b76056') + rect(43, 15, 5, 14, INK) + windows([20, 40], [44], 7, 9) + rect(29, 49, 8, 18, MINT) + ellipse(35, 58, .8, .8, INK) + line(18, 38, 48, 38, '#f5b39a', 2) + rect(9, 63, 15, 5, '#73a87f', '#73a87f', 2) + ellipse(13, 63, 3, 3, '#93b57d') + ellipse(20, 63, 3, 3, '#93b57d')))
    svg('sprites/residential_mid.svg', building(
        rect(12, 18, 37, 49, '#a8c9b5') + path('M49 18L58 13V62L49 67Z', '#649b8f') + path('M9 18L19 11H58V18Z', '#dae0c4') + rect(9, 18, 42, 5, INK) + windows([17, 28, 39], [29, 44], 6, 9) + rect(28, 57, 9, 10, CREAM) + line(13, 41, 48, 41, '#e8e7cd', 3) + line(13, 56, 48, 56, '#e8e7cd', 3) + rect(20, 7, 11, 5, CORAL) + line(52, 30, 55, 28, '#c5e2ce', 2) + line(52, 44, 55, 42, '#c5e2ce', 2)))
    shop = rect(9, 36, 46, 31, CREAM) + path('M55 36L61 31V62L55 67Z', '#caa975') + rect(9, 28, 46, 11, GOLD) + rect(17, 31, 30, 4, CREAM, CREAM, 1) + windows([15, 40], [48], 10, 14) + rect(29, 48, 8, 19, INK)
    for i in range(8):
        shop += path(f'M{7+i*6} 39h6l2 8h-6Z', CORAL if i % 2 == 0 else CREAM, 'none')
    shop += line(7, 47, 57, 47, INK, 1.4) + rect(7, 63, 8, 7, '#b47a54') + ellipse(11, 61, 4, 4, MINT)
    svg('sprites/commercial.svg', building(shop))
    svg('sprites/commercial_mid.svg', building(
        rect(12, 15, 38, 52, '#e4bf83') + path('M50 15L58 10V62L50 67Z', '#ba925f') + path('M12 15L20 10H58L50 15Z', CREAM) + windows([17, 29, 41], [23, 38], 6, 10, '#689e9f') + rect(13, 53, 37, 5, CORAL) + windows([18, 35], [59], 11, 8) + rect(21, 6, 23, 8, INK, INK, 2) + line(25, 10, 40, 10, GOLD, 2)))
    svg('sprites/industrial.svg', building(
        rect(10, 39, 44, 28, '#b4b7a6') + path('M54 39L61 33V62L54 67Z', '#828f84') + path('M8 39V29L24 39V28L40 39V28L56 39Z', '#72979a') + rect(46, 13, 8, 23, '#b97968') + rect(44, 11, 12, 5, INK) + windows([15, 29], [44], 9, 6) + rect(16, 56, 18, 11, '#607d7c') + line(17, 59, 33, 59, '#a6bfab') + line(17, 63, 33, 63, '#a6bfab') + rect(42, 56, 8, 11, GOLD) + line(6, 68, 57, 68, '#bdad78', 2)))
    svg('sprites/industrial_mid.svg', building(
        rect(9, 31, 45, 36, '#a5adb0') + path('M54 31L61 25V61L54 67Z', '#718a8a') + path('M9 31L16 25H61L54 31Z', '#d1d3bd') + rect(11, 15, 7, 15, CORAL) + rect(9, 13, 11, 4, INK) + rect(25, 8, 8, 22, '#c48b70') + rect(23, 6, 12, 5, INK) + windows([15, 29, 43], [38], 7, 8) + rect(14, 53, 24, 14, '#47666c') + line(15, 57, 37, 57, '#98b7b3') + line(15, 62, 37, 62, '#98b7b3') + rect(43, 52, 7, 15, GOLD)))
    svg('sprites/power.svg', building(
        rect(8, 46, 45, 21, '#d9ceb0') + path('M53 46L60 40V62L53 67Z', '#b0ad96') + path('M8 46L15 40H60L53 46Z', '#92b6ac') + rect(13, 50, 17, 17, '#739598') + rect(36, 49, 11, 14, INK) + path('M43 48L37 56H41L38 64L48 54H44L46 48Z', GOLD, 'none') + path('M18 42L22 6H29L34 42M21 14H30M20 24H31M19 34H33M20 34L31 24L21 14M21 24L32 34', 'none', INK, 2) + line(14, 13, 38, 13, INK, 2) + ellipse(15, 13, 2, 4, '#b4d7d1') + ellipse(37, 13, 2, 4, '#b4d7d1')))
    svg('sprites/park.svg', shadow() + rect(5, 35, 54, 35, '#a6c79a', '#83a788', 7) + path('M13 69Q21 46 48 38', 'none', '#eadfba', 7) + ellipse(40, 56, 13, 8, '#79b8bd') + path('M33 53Q40 50 46 53', 'none', '#c2ded4', 2) + tree(18, 41, .8) + tree(46, 29, .7) + rect(20, 59, 9, 4, '#c09265') + line(21, 63, 21, 66) + line(28, 63, 28, 66))
    svg('sprites/police.svg', building(
        rect(10, 33, 45, 34, '#d5e0ce') + path('M55 33L60 28V62L55 67Z', '#9eb9ae') + path('M7 33L32 17L58 33Z', '#5b8391') + windows([15, 43], [43], 7, 11) + rect(27, 48, 10, 19, '#548292') + rect(22, 39, 20, 6, INK) + path('M31 28L34 30L38 29L37 34L32 38L27 34L26 29L30 30Z', GOLD) + line(52, 18, 52, 29, INK, 1.4) + path('M52 18H60V24H52Z', '#6d9ab0')))
    svg('sprites/fire.svg', building(
        rect(9, 31, 46, 36, '#eab797') + path('M55 31L61 26V62L55 67Z', '#bd8b77') + rect(7, 27, 49, 6, CORAL) + rect(14, 45, 35, 22, INK, INK, 2) + rect(18, 55, 26, 10, '#dd765f', INK, 2) + windows([21, 35], [53], 7, 5, '#c2dfdc') + ellipse(24, 65, 3, 3, INK) + ellipse(39, 65, 3, 3, INK) + rect(27, 49, 8, 3, GOLD) + line(16, 39, 46, 39, '#bd745e', 2) + path('M30 15Q38 23 33 27Q24 30 25 22L28 25Q32 23 30 15Z', CORAL)))
    svg('sprites/tree.svg', tree(32, 55, 1.2))
    svg('sprites/car.svg', ellipse(20, 17, 18, 5, INK, .18) + rect(5, 6, 29, 13, GOLD, INK, 5) + rect(14, 7, 12, 11, '#f2d284', INK, 3) + path('M15 8H19V16H15Z', '#87b9ba') + path('M23 8H26V16H23Z', '#87b9ba') + rect(6, 5, 6, 2, INK) + rect(27, 5, 6, 2, INK) + rect(6, 19, 6, 2, INK) + rect(27, 19, 6, 2, INK) + line(34, 9, 34, 11, CREAM, 2) + line(34, 15, 34, 17, CREAM, 2), 40, 24)
    svg('sprites/walker.svg', ellipse(10, 28, 7, 3, INK, .16) + line(7, 22, 6, 28, INK, 3) + line(13, 22, 14, 28, INK, 3) + rect(5, 12, 10, 12, CORAL, INK, 3) + line(4, 15, 2, 21, '#dfba92', 3) + line(16, 15, 18, 20, '#dfba92', 3) + ellipse(10, 9, 5, 6, '#ebc99b') + ellipse(10, 5, 8, 3, GOLD) + rect(6, 1, 8, 5, GOLD, GOLD, 2), 20, 32)


def generate_backgrounds():
    """独立した多層背景と文字に依存しないロゴを保存する。"""
    terrain = rect(0, 0, 1280, 720, '#f0e5c9', 'none')
    for x in range(0, 1280, 40):
        terrain += line(x, 0, x, 720, '#e4dabe', .6)
    for y in range(0, 720, 40):
        terrain += line(0, y, 1280, y, '#e4dabe', .6)
    terrain += path('M-40 220Q160 80 295 190T550 315Q740 400 875 255T1340 285', 'none', '#c2d0b0', 115)
    terrain += path('M-40 220Q160 80 295 190T550 315Q740 400 875 255T1340 285', 'none', '#9ec6c1', 68)
    terrain += path('M-40 217Q160 77 295 187T550 312Q740 397 875 252T1340 282', 'none', '#bbd8cd', 3)
    for i in range(90):
        x = (i * 137 + 59) % 1280
        y = (i * 83 + 421) % 720
        terrain += path(f'M{x} {y}l3 -4m-3 4l-3 -3', 'none', '#c5c5a5', .8)
    svg('backgrounds/terrain.svg', terrain, 1280, 720)
    mountains = path('M-40 235L80 68L178 188L340 20L485 173L625 70L760 204L908 45L1110 198L1220 87L1320 240Z', '#adc2ad', 'none') + path('M-40 240L185 124L318 216L478 116L688 244L820 162L1005 230L1150 137L1320 240Z', '#84aa99', 'none') + path('M297 70L340 20L389 77L349 58L331 69L318 55Z', '#e1e6ce', 'none')
    svg('backgrounds/mountains.svg', mountains, 1280, 240)
    clouds = ''
    for x, y, scale in [(100, 70, 1), (450, 145, 1.2), (820, 60, .8), (1150, 165, 1.1)]:
        clouds += f'<g transform="translate({x} {y}) scale({scale})" opacity="0.66">' + ellipse(0, 0, 70, 15, '#fff8e4') + ellipse(-28, -10, 25, 21, '#fff8e4') + ellipse(11, -17, 36, 30, '#fff8e4') + ellipse(42, -6, 25, 21, '#fff8e4') + '</g>'
    svg('backgrounds/clouds.svg', clouds, 1280, 240)
    panel = rect(2, 5, 316, 173, '#17383e', '#17383e', 18) + rect(2, 2, 316, 173, '#23494f', '#53726d', 18) + line(22, 4, 298, 4, '#76917e', 1) + line(22, 156, 298, 156, '#3d6263', 1)
    svg('ui/panel.svg', panel, 320, 180)
    svg('ui/button.svg', rect(2, 7, 236, 55, '#47786b', '#1d4746', 15) + rect(2, 2, 236, 55, '#96c8ae', '#d9e9c9', 15) + line(22, 7, 218, 7, '#c7e0be', 2), 240, 64)
    logo = path('M32 128Q122 104 206 128T398 128T577 128', 'none', '#a7c8b3', 6)
    for i, name in enumerate(['residential', 'commercial', 'residential_mid', 'park', 'industrial', 'police', 'fire']):
        source = (ROOT / f'sprites/{name}.svg').read_text().split('<g stroke-linejoin="round" stroke-linecap="round">', 1)[1].rsplit('</g></svg>', 1)[0]
        logo += f'<g transform="translate({36+i*76} 25) scale(1.08)">{source}</g>'
    logo += ellipse(531, 32, 17, 17, GOLD)
    svg('branding/logo.svg', logo, 600, 160)
    keyart = rect(0, 0, 1280, 720, '#efdfb9', 'none') + ellipse(986, 134, 100, 100, '#edc37b') + f'<g transform="translate(0 140)">{mountains}</g>'
    keyart += path('M0 530Q245 395 458 518T840 520T1280 470V720H0Z', '#bacdb1', 'none')
    keyart += path('M630 720Q750 610 600 553T720 443T1020 450T1280 350', 'none', '#82b6b4', 85)
    keyart += path('M610 720Q730 610 580 553T700 443T1000 450T1260 350', 'none', '#c5dad0', 2)
    for row in range(4):
        for col in range(7):
            if col in [3, 4] and row > 1:
                continue
            px = 290 + col * 100 - row * 48
            py = 295 + row * 76
            keyart += rect(px-4, py+64, 110, 18, '#557776', '#eadcbc', 2)
            name = ['residential', 'commercial', 'park', 'residential_mid', 'industrial', 'police', 'fire'][(col + row*3) % 7]
            source = (ROOT / f'sprites/{name}.svg').read_text().split('<g stroke-linejoin="round" stroke-linecap="round">', 1)[1].rsplit('</g></svg>', 1)[0]
            keyart += f'<g transform="translate({px} {py}) scale(1.25)">{source}</g>'
    keyart += f'<g opacity="0.5">{clouds}</g>'
    svg('branding/keyart.svg', keyart, 1280, 720)


RATE = 22050


def add_note(samples, start, duration, frequency, gain, voice='bell'):
    """バッファへの加算合成は音の重なりを表すため非冪等。呼び出し元で毎回空にする。"""
    begin = round(start * RATE)
    count = round(duration * RATE)
    for i in range(count):
        t = i / RATE
        phase = 2 * math.pi * frequency * t
        attack = min(t / .015, 1)
        release = min((duration - t) / .055, 1)
        if voice == 'bell':
            tone = math.sin(phase) * math.exp(-t * 5) + .32 * math.sin(phase * 2) * math.exp(-t * 10) + .12 * math.sin(phase * 3) * math.exp(-t * 13)
        elif voice == 'bass':
            tone = .8 * math.sin(phase) + .24 * math.sin(phase * 2) + .1 * math.sin(phase * 3)
        else:
            tone = .6 * math.sin(phase) + .24 * math.sin(phase * 2) + .09 * math.sin(phase * 4)
        samples[(begin + i) % len(samples)] += tone * attack * release * gain


def add_drum(samples, start, duration, gain, rng, kick=False):
    """ノイズ打楽器を加算するため非冪等。固定シードを使う生成元が再現性を保証する。"""
    begin = round(start * RATE)
    for i in range(round(duration * RATE)):
        t = i / RATE
        tone = math.sin(2 * math.pi * (62 * t + 6 * (1 - math.exp(-t * 24)))) if kick else rng.uniform(-1, 1)
        env = math.exp(-t * (24 if kick else 44)) * min(t / .002, 1)
        samples[(begin + i) % len(samples)] += tone * env * gain


def write_wave(name, samples):
    """クリッピングを防ぎ、同じ波形を同じ PCM データで保存する。"""
    peak = max(max(abs(v) for v in samples), .001)
    attenuation = min(1, .58 / peak)
    pcm = b''.join(struct.pack('<h', round(max(-1, min(1, v * attenuation)) * 32767)) for v in samples)
    with wave.open(str(ROOT / f'audio/{name}.wav'), 'wb') as stream:
        stream.setparams((1, 2, RATE, len(samples), 'NONE', 'not compressed'))
        stream.writeframes(pcm)


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def generate_audio():
    """場面ごとの旋律・伴奏・ベース・打楽器を固定シードで再生成する。"""
    tracks = {'title': (108, [60, 65, 57, 67], [72, 76, 79, 76, 77, 81, 79, 76]), 'town': (112, [60, 57, 65, 67], [76, 79, 81, 79, 77, 76, 74, 72]), 'city': (132, [62, 67, 60, 69], [74, 77, 81, 84, 81, 79, 77, 76]), 'result': (100, [60, 65, 67, 60], [79, 84, 83, 79, 81, 79, 76, 72])}
    for index, (name, (bpm, chords, melody)) in enumerate(tracks.items()):
        beat = 60 / bpm
        samples = [0.] * round(beat * 16 * RATE)
        rng = random.Random(711 + index)
        for bar, root in enumerate(chords):
            for semitone in [0, 4 if root not in [57, 62, 69] else 3, 7]:
                add_note(samples, bar * beat * 4, beat * 3.8, hz(root + semitone), .027, 'pad')
            for n in range(4):
                time = (bar * 4 + n) * beat
                add_note(samples, time, beat * .72, hz(root - 12 + (7 if n == 2 else 0)), .09, 'bass')
                add_drum(samples, time, .18, .09, rng, kick=True)
                add_drum(samples, time + beat * .5, .08, .035, rng)
                add_note(samples, time + beat * .5, beat * .75, hz(melody[(bar*2+n) % len(melody)]), .09, 'bell')
                if name == 'city':
                    add_drum(samples, time + beat * .75, .055, .024, rng)
        write_wave(name, samples)
    for index, name in enumerate(['build', 'demolish', 'alert', 'month', 'click']):
        duration = {'build': .5, 'demolish': .45, 'alert': .65, 'month': .65, 'click': .13}[name]
        samples = [0.] * round(duration * RATE)
        rng = random.Random(500 + index)
        if name == 'build':
            for n, midi in enumerate([67, 72, 79]):
                add_note(samples, .08*n, .25, hz(midi), .15)
            add_drum(samples, 0, .09, .09, rng)
        elif name == 'demolish':
            add_drum(samples, 0, .32, .22, rng)
            for n, midi in enumerate([55, 48, 43]):
                add_note(samples, n*.08, .2, hz(midi), .12, 'bass')
        elif name == 'alert':
            for n in range(2):
                add_note(samples, n*.24, .2, hz(71), .13, 'pad')
                add_note(samples, n*.24, .2, hz(77), .07, 'pad')
        elif name == 'month':
            for n, midi in enumerate([72, 76, 79, 84]):
                add_note(samples, n*.09, .28, hz(midi), .11)
        else:
            add_note(samples, 0, .09, hz(81), .12)
            add_drum(samples, 0, .035, .065, rng)
        write_wave(name, samples)


if __name__ == '__main__':
    generate_sprites()
    generate_backgrounds()
    generate_audio()
    print('独自素材生成完了: SVG 20 ファイル、WAV 9 ファイル')
