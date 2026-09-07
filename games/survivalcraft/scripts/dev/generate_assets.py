"""灯守の島の独自 SVG・音源を同じ入力から再生成する（外部素材を使わない）。"""
from pathlib import Path
import array
import math
import random
import wave

ROOT = Path(__file__).resolve().parents[2] / 'assets'
RATE = 22050


def svg(name, body, width=128, height=128, directory='icons'):
    target = ROOT / directory / f'{name}.svg'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">{body}</svg>\n')


def cube(top, left, right, detail=''):
    return f'<g stroke="#243c4a" stroke-width="3" stroke-linejoin="round"><path d="M64 16 110 40 64 65 18 40Z" fill="{top}"/><path d="M18 40 64 65 64 115 18 88Z" fill="{left}"/><path d="M64 65 110 40 110 88 64 115Z" fill="{right}"/>{detail}</g>'


def images():
    palettes = {
        'grass': ('#a6c973', '#668d52', '#486f4e'),
        'dirt': ('#b68b67', '#926447', '#6c4d42'),
        'stone': ('#acb9ba', '#788a91', '#536772'),
        'sand': ('#f4ddb2', '#d5b889', '#b99268'),
        'wood': ('#d6af78', '#ac754c', '#80573d'),
        'leaves': ('#93c67c', '#528f65', '#36765c'),
        'crystal': ('#b4efe8', '#59b8b8', '#3c828e'),
        'plank': ('#e7c58c', '#b58c60', '#997348'),
    }
    details = {
        'grass': '<path d="M29 40 39 29 37 43M62 36 68 22 73 36M83 43 94 33" fill="none" stroke="#d2df95"/>',
        'dirt': '<path d="M27 64 36 69M44 87 55 90M79 81 89 75M85 99 96 91" stroke="#c4a27f"/>',
        'stone': '<path d="m32 45 24 9 9-14 21-8M48 59 44 80 57 95M81 58 90 75 86 96" fill="none" stroke="#465e6b"/>',
        'sand': '<path d="M39 37 68 27M53 45 83 34M27 58 51 72M78 81 99 69" stroke="#ffedc6"/>',
        'wood': '<ellipse cx="64" cy="40" rx="23" ry="11" fill="none" stroke="#a5754d"/><ellipse cx="64" cy="40" rx="10" ry="5" fill="none" stroke="#a5754d"/><path d="M30 55v37M46 66v32M81 62v39M97 53v37" stroke="#d3a36b"/>',
        'leaves': '<path d="m29 40 21-8 5 12-13 4ZM67 30l15 5-8 11-14-4ZM28 59l16 12-8 11-10-9ZM83 72l14-9-1 15-12 9Z" stroke="none" fill="#b3d98a"/>',
        'crystal': '<path d="m64 15 10 26-10 23-13-25Z" fill="#e3fff0"/><path d="m71 68 15 6 16-24M26 48l15 14-5 21" fill="none" stroke="#a7eada"/>',
        'plank': '<path d="M31 47 77 23M49 57 96 33M19 62l44 25 46-26M19 79l44 24 46-25" fill="none" stroke="#825c3b"/>',
    }
    for name, colors in palettes.items():
        svg(name, cube(*colors, details[name]))
    svg('torch', '<path d="M54 67h19l-6 48H58Z" fill="#956b49" stroke="#253d49" stroke-width="4"/><path d="M63 12C87 37 101 55 81 75 39 88 25 56 50 34 48 51 68 42 63 12" fill="#f5ac58" stroke="#253d49" stroke-width="4"/><path d="M64 42C45 64 49 73 65 75 83 70 74 52 64 42" fill="#ffedb1"/>')
    svg('bench', '<g stroke="#253d49" stroke-width="4" stroke-linejoin="round"><path d="m24 53 17 8-4 49-13-5Zm58 10 16-10 7 49-15 8Z" fill="#886145"/><path d="m15 45 53-23 47 24-51 29Z" fill="#e1b875"/><path d="M15 45v16l49 29V75Zm49 30 51-29v15L64 90Z" fill="#ad7c51"/><path d="m41 37 46 27M64 28l47 22" fill="none" stroke="#856746"/></g>')
    svg('pickaxe', '<g stroke="#253d49" stroke-width="4" stroke-linejoin="round"><path d="m36 105 11 6 42-80-11-6Z" fill="#a77449"/><path d="M23 46Q45 11 84 24l24 29-37-14-9-4-39 11Z" fill="#acd1d1"/><path d="m69 20 17 6-9 19-17-7Z" fill="#f2c678"/></g>')
    svg('beacon', '<g stroke="#253d49" stroke-width="4" stroke-linejoin="round"><path d="m30 97 33-16 34 17-33 19Z" fill="#6e909b"/><path d="M45 38h36v57l-18 9-18-9Z" fill="#f3c779"/><path d="M51 45h24v31H51Z" fill="#fff3bd"/><path d="m30 37 33-24 34 24-34 13Z" fill="#4a6a79"/><path d="M63 3v10M27 12l9 9M99 12l-9 9" stroke="#f3c779"/></g>')
    svg('player', '<g stroke="#263e4a" stroke-width="4" stroke-linejoin="round"><path d="M29 112V88q35-28 70 0v24" fill="#437b7c"/><path d="M50 79v18h27V79" fill="#ddb388"/><rect x="37" y="35" width="56" height="50" rx="21" fill="#efd3a8"/><path d="M23 45q40-24 82 0v-8L83 24H43L23 37Z" fill="#e3c18b"/><path d="M43 28V16h41v12" fill="#658e7c"/><path d="M51 59h3M74 59h3" stroke-width="7"/><path d="m57 72 13 1" fill="none"/><path d="m30 95 23 16M91 95l-22 16" fill="none" stroke="#eac57f"/></g>')
    svg('mossling', '<g stroke="#273f49" stroke-width="4" stroke-linejoin="round"><path d="m18 89-4 18h23l5-19m47 0 5 19h23l-7-19" fill="#cfcca9"/><path d="M13 78 23 46 44 26 85 25 110 49 116 78 95 97 33 98Z" fill="#657f7b"/><path d="m23 46 24-21 40 1 21 24-16 17-42-1Z" fill="#95ad6d"/><path d="m63 20 10-7 9 19-15 7Z" fill="#ccd296"/><path d="M31 69h67v33H31Z" fill="#425b64"/><path d="M41 79h11m27 0h11" stroke="#ffcf75" stroke-width="8"/><path d="m29 89 11 16 5-20m40 0 5 20 11-16" fill="#f0e6c5"/></g>')
    svg('wisp', '<g stroke="#293d58" stroke-width="4" stroke-linejoin="round"><path d="M32 63 24 100l13 13 6-44m46-6 13 35-14 16-7-45" fill="#83b6ae"/><path d="M42 41h45v44H42Z" fill="#f5c06e"/><path d="M50 47h28v31H50Z" fill="#fff0a7"/><path d="M32 42 64 15 96 42 64 53Z" fill="#557898"/><path d="M41 83h46v13H41ZM49 47v36m30-36v36" fill="#648b97"/><path d="M57 65v7m14-7v7" stroke-width="5"/><circle cx="64" cy="12" r="5" fill="#ffd88a"/></g>')
    extras = {
        'apple': '<path d="M65 35C16 15 9 60 31 96q16 26 34 11 25 13 41-14 25-48-10-62-17-4-31 4Z" fill="#ce765e"/><path d="M65 36 61 14" fill="none"/><path d="M66 26q4-25 29-14-5 19-29 14Z" fill="#8db976"/><path d="M36 48q-13 18-1 34" fill="none" stroke="#f4b886" stroke-width="7"/>',
        'leaf': '<path d="M24 99Q5 32 107 14q3 91-76 89Z" fill="#74a77c"/><path d="m19 116 66-66m-29 43-5-28m22 11 26-2m-5-43 3 25" fill="none" stroke="#dae1a0"/>',
        'ore': '<path d="m17 86 12-41 31-20 43 12 14 48-29 26-47-3Z" fill="#728c94"/><path d="m31 43 22 21-12 44m12-44 47-26M53 64l63 20" fill="none" stroke="#415b69"/><path d="m40 33 16 9 10 21-18-8Zm42 17 11 8-5 24-12-15Zm-28 37 15-10 6 22-19 3Z" fill="#b4e5d7"/>',
        'wood_pick': '<path d="m31 107 12 7 46-78-12-6Z" fill="#967042"/><path d="M19 46Q43 17 85 23l26 30-46-18-46 11Z" fill="#d8b97c"/><path d="m64 23 22 4-9 19-21-7Z" fill="#789d82"/>',
        'stone_pick': '<path d="m32 106 12 7 43-79-11-7Z" fill="#a5744d"/><path d="m18 40 33-19 34 3 25 28-31-13-27 2-34 12Z" fill="#94aeb2"/><path d="m64 23 21 4-9 19-18-7Z" fill="#ead298"/><path d="m42 29 9 12 12-10" fill="none" stroke="#506c78"/>',
        'meat': '<path d="m24 92 52-53 16 16-53 50-17 9-10-10Z" fill="#efe4bd"/><path d="M53 34q31-29 55 0 19 29-12 53-26 20-48-4-16-21 5-49Z" fill="#b96d58"/><path d="M64 42q21-15 34 6 7 18-12 31-17 10-26-6-9-12 4-31Z" fill="#e5a18a"/>',
        'stew': '<path d="M20 59h88l-13 41-31 14-31-14Z" fill="#638d96"/><ellipse cx="64" cy="57" rx="44" ry="22" fill="#d7995f"/><path d="m42 52 14-7 13 9-15 9Z" fill="#f2cf8e"/><path d="m74 49 16-1-3 15-15-1Z" fill="#84ac76"/><path d="M41 34q-12-9 0-22m23 18q-12-9 0-22m24 26q-12-9 0-22" fill="none" stroke="#d8e3ca"/>',
        'bandage': '<path d="m27 34 49-16 29 18-5 61-48 17-29-20Z" fill="#e0d9b0"/><path d="m27 34 25 20 53-18M52 54v60M26 54l25 19 52-18M25 76l27 19 49-19" fill="none" stroke="#a6b592"/><path d="m60 68 13-16 11 2-7 21-17 4Z" fill="#689278"/>',
        'water': '<path d="M64 12C51 38 24 59 24 82a40 34 0 0 0 80 0c0-23-27-44-40-70Z" fill="#63b7c1"/><path d="M40 71q-11 19 7 28" fill="none" stroke="#c2efdf" stroke-width="7"/>',
    }
    for name, body in extras.items():
        svg(name, f'<g stroke="#253d49" stroke-width="4" stroke-linejoin="round" stroke-linecap="round">{body}</g>')
    logo = '<g fill="none" stroke="#f8cd83" stroke-width="5" stroke-linejoin="round"><path d="m60 8 44 34-44 34-44-34Z"/><path d="M45 37h30v30H45Zm-9 31 24 14 24-14M60 4v16M25 91h70"/><path d="M57 57q-12-8 4-23-2 9 6 14 8 12-10 9" fill="#ffe4a5" stroke="none"/></g>'
    svg('logo', logo, 120, 100, 'art')
    title = '''<defs><linearGradient id="sky" x2="0" y2="1"><stop stop-color="#163b52"/><stop offset="1" stop-color="#74b7b1"/></linearGradient><linearGradient id="sea" x2="0" y2="1"><stop stop-color="#388f98"/><stop offset="1" stop-color="#153d57"/></linearGradient><radialGradient id="glow"><stop stop-color="#ffe6a1" stop-opacity=".55"/><stop offset="1" stop-color="#ffcf77" stop-opacity="0"/></radialGradient></defs><rect width="1280" height="720" fill="url(#sky)"/><circle cx="970" cy="169" r="59" fill="#f3deb2"/><circle cx="970" cy="169" r="115" fill="url(#glow)"/><path d="m0 296 134-45 165 45 172-85 166 60 136-29 180 63 162-62 165 38v151H0Z" fill="#326d7d"/><path d="m0 344 221-42 201 61 215-45 221 18 199-14 223 57v118H0Z" fill="#418894"/><path d="M0 395q310-37 600 3t680-1v323H0Z" fill="url(#sea)"/>'''
    rng = random.Random(18)
    for _ in range(55):
        x, y = rng.randrange(0, 1280), rng.randrange(420, 700)
        title += f'<path d="M{x} {y}h{rng.randrange(20, 80)}" stroke="#8bcac1" stroke-width="2" opacity=".24"/>'
    title += '''<path d="m490 501 159-114 253-23 250 111-98 122-302 40Z" fill="#173c4a" opacity=".4"/><path d="m502 452 149-99 252-22 231 104v80l-108 83-271 26-253-92Z" fill="#8b745b"/><path d="m502 452 247 91 278-29 107-79-231-104-252 22Z" fill="#9eb985"/><path d="m608 414 94-70 174-6 164 71v67l-164 39-268-67Z" fill="#8b8060"/><path d="m608 414 208 69 224-74-164-71-174 6Z" fill="#bdce91"/><path d="m716 370 92-64 127 51-96 72Z" fill="#88a971"/><path d="m716 370 123 59v44l-123-37Zm123 59 96-72v48l-96 68Z" fill="#6f855e"/><path d="m665 501 79-52 39 14-79 53Z" fill="#e5d3a1"/><path d="m530 447 18-19 28 9-20 22Z" fill="#dfd1aa"/><path d="m959 481 29-8 31 14-27 14Z" fill="#dfd1aa"/>'''
    for x, y, scale in [(604, 389, 1), (947, 409, .8), (1090, 460, .75), (758, 396, .5)]:
        title += f'<g transform="translate({x} {y}) scale({scale})"><path d="M-7 0h14v-79H-7Z" fill="#805e44"/><path d="m-51-54 6-57 45-26 54 31-4 57-48 23Z" fill="#387664"/><path d="m-45-111 45-26 54 31-46 28Z" fill="#71a271"/><path d="m0-78 48-28-4 57L2-26Z" fill="#2f645d"/></g>'
    title += '''<circle cx="833" cy="274" r="170" fill="url(#glow)"/><path d="m786 349 47-23 47 24-46 28Z" fill="#455f6c"/><path d="M809 241h48v95l-24 15-24-15Z" fill="#d6b575"/><path d="M817 250h31v43h-31Z" fill="#ffeab0"/><path d="m791 238 42-33 42 33-42 19Z" fill="#2f5065"/><path d="M833 176v24m-57-11 20 18m98-18-21 18" stroke="#ffdda2" stroke-width="5"/><path d="M0 654q127-63 252-18 91-72 185-30l-40 114H0Z" fill="#153d46"/><path d="m76 693 24-101 39 46 22-100 38 68 31-54 23 142m793 26-17-91 40 34 36-102 14 65 46-34-15 86" fill="#204f51"/>'''
    svg('title', title, 1280, 720, 'art')


def write_audio(name, samples):
    output = array.array('h', (int(max(-.98, min(.98, v)) * 32767) for v in samples))
    with wave.open(str(ROOT / 'audio' / f'{name}.wav'), 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(output.tobytes())


def note(samples, start, duration, pitch, volume, instrument='bell'):
    frequency = 440 * 2 ** ((pitch - 69) / 12)
    for i in range(int(duration * RATE)):
        t = i / RATE
        phase = 2 * math.pi * frequency * t
        attack = min(1, t * 90)
        release = min(1, (duration - t) * 10)
        if instrument == 'bell':
            tone = math.sin(phase) + .4 * math.sin(phase * 2.003) + .18 * math.sin(phase * 4.01)
            envelope = math.exp(-t * 4.5)
        elif instrument == 'pluck':
            tone = math.sin(phase) + .32 * math.sin(phase * 2) + .2 * math.sin(phase * 3)
            envelope = math.exp(-t * 6)
        else:
            tone = math.sin(phase) + .2 * math.sin(phase * 2) + .09 * math.sin(phase * 3)
            envelope = .7
        pos = (int(start * RATE) + i) % len(samples)
        samples[pos] += tone * volume * attack * release * envelope


def music():
    # 場面ごとに異なる旋律・テンポ・音色。短いループでも継ぎ目の残響を循環させる。
    tracks = {
        'title': (90, [74, 78, 81, 85, 81, 78, 76, 73, 74, 81, 83, 85, 83, 81, 78, 76], 'bell', 50),
        'day': (112, [74, 78, 81, 78, 83, 81, 78, 76, 74, 76, 78, 81, 85, 83, 81, 78], 'pluck', 50),
        'night': (76, [69, 72, 76, 79, 76, 72, 67, 71, 69, 76, 79, 81, 79, 76, 72, 71], 'bell', 45),
        'clear': (120, [74, 78, 81, 86, 85, 81, 78, 81, 83, 85, 86, 90, 86, 85, 81, 86], 'bell', 50),
        'failed': (66, [69, 67, 64, 60, 62, 64, 62, 59, 57, 60, 64, 67, 65, 64, 60, 57], 'pad', 45),
    }
    for name, (bpm, melody, timbre, root) in tracks.items():
        beat = 60 / bpm
        samples = [0.0] * int(beat * 16 * RATE)
        for index, pitch in enumerate(melody):
            note(samples, index * beat, beat * 1.7, pitch, .17, timbre)
            if index % 4 == 0:
                bass = root + [0, 5, 7, 0][index // 4]
                for chord in [bass, bass + 7, bass + 12]:
                    note(samples, index * beat, beat * 3.8, chord, .045, 'pad')
            if name == 'day' and index % 2 == 1:
                note(samples, index * beat + beat * .5, beat * .8, pitch - 12, .09, 'pluck')
        delayed = list(samples)
        for i, value in enumerate(samples):
            delayed[(i + int(beat * .75 * RATE)) % len(samples)] += value * .22
        write_audio(name, delayed)


def ambience():
    """紙模型の風景を音だけでも識別できる、周期的な紙擦れと波の環境音。"""
    duration = 8.0
    count = int(duration * RATE)
    for name in ('paper_day', 'paper_night'):
        samples = []
        for index in range(count):
            phase = index / count
            ocean = (
                math.sin(math.tau * phase * 2)
                + .45 * math.sin(math.tau * phase * 5 + .8)
                + .2 * math.sin(math.tau * phase * 11 + 1.7)
            )
            fibers = (
                math.sin(math.tau * phase * 317 + .4)
                + .6 * math.sin(math.tau * phase * 521 + 2.1)
                + .35 * math.sin(math.tau * phase * 809 + .9)
            )
            centers = (.18, .47, .76) if name == 'paper_day' else (.29, .63, .91)
            rustle = 0.0
            for center in centers:
                distance = min(abs(phase - center), 1.0 - abs(phase - center))
                rustle += math.exp(-((distance / .035) ** 2))
            if name == 'paper_day':
                value = ocean * .045 + fibers * rustle * .022
            else:
                night_wind = math.sin(math.tau * phase) + .3 * math.sin(math.tau * phase * 7)
                value = night_wind * .026 + fibers * rustle * .014
            samples.append(value)
        samples[-1] = samples[0]
        write_audio(name, samples)


def effects():
    specs = {
        'break_grass': (0.22, 260, .65), 'break_dirt': (.21, 180, .7),
        'break_stone': (.30, 620, .45), 'break_sand': (.27, 110, .78),
        'break_wood': (.27, 310, .38), 'break_leaves': (.28, 390, .8),
        'break_crystal': (.6, 1130, .09), 'place': (.19, 230, .32),
        'step': (.13, 95, .62), 'attack': (.22, 280, .4),
        'hurt': (.35, 125, .4), 'craft': (.62, 740, .03), 'ui': (.16, 860, .01),
    }
    for material, frequency, noise in [
        ('wood', 250, .32), ('stone', 430, .24), ('grass', 180, .7),
        ('dirt', 135, .6), ('sand', 80, .83), ('leaves', 310, .78),
        ('crystal', 870, .12),
    ]:
        specs[f'place_{material}'] = (.23, frequency, noise)
        specs[f'step_{material}'] = (.14, frequency * .68, noise)
    rng = random.Random(46)
    for name, (duration, frequency, noise) in specs.items():
        samples = []
        smooth = 0
        for i in range(int(duration * RATE)):
            t = i / RATE
            smooth = smooth * .55 + rng.uniform(-1, 1) * .45
            pitch = frequency * (1 - t / duration * .48)
            if name in ['craft', 'break_crystal', 'ui']:
                pitch = frequency * [1, 1.25, 1.5][min(2, int(t / duration * 3))]
            tone = math.sin(2 * math.pi * pitch * t) + .28 * math.sin(2 * math.pi * pitch * 2.01 * t)
            envelope = min(1, t * 180) * math.exp(-t / duration * 5.5)
            samples.append((tone * (1 - noise) + smooth * noise * 3) * envelope * .47)
        write_audio(name, samples)


if __name__ == '__main__':
    images()
    music()
    ambience()
    effects()
    print('灯守の島: 画像と音源の生成完了')
