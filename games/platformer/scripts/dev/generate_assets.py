"""外部素材を使わず、同一内容の SVG と PCM 音声を再現する。"""

from pathlib import Path
import math
import struct
import wave


ASSETS = Path(__file__).resolve().parents[2] / "assets"
RATE = 22050


def svg(name, width, height, body):
    """決まった寸法の SVG を上書きし、何度実行しても同じ素材を得る。"""
    path = ASSETS / "images" / f"{name}.svg"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}">{body}</svg>\n', encoding="utf-8"
    )


def images():
    """独自の空の配達人と、草原・地下で共通利用する素材を生成する。"""
    svg("player", 32, 48, '''
      <path d="M6 27H1v12h8" fill="#b87646" stroke="#334c63" stroke-width="2"/>
      <path d="M8 38H15v8H6v-4zM19 37h7l2 9h-9z" fill="#29465c"/>
      <path d="M8 21h17l3 18H5z" fill="#f4b544" stroke="#334c63" stroke-width="2"/>
      <path d="M6 26l-3 7 5 2M25 25l5 7-4 3" fill="#eab48f" stroke="#334c63" stroke-width="2"/>
      <rect x="9" y="8" width="17" height="16" rx="6" fill="#ffe0b2" stroke="#334c63" stroke-width="2"/>
      <path d="M7 14V9Q9 1 18 2q9 0 10 10H14v3z" fill="#30b8bc" stroke="#334c63" stroke-width="2"/>
      <path d="M16 5l3 4-7 2" fill="#dcfcdf"/>
      <rect x="21" y="15" width="2.5" height="4" rx="1" fill="#263d50"/>
      <path d="M11 23h14v5H12l-9 5v-6z" fill="#ef725b"/>
      <rect x="13" y="30" width="9" height="6" rx="1" fill="#fff2c9"/>
      <path d="M13 30l4.5 3 4.5-3" fill="none" stroke="#c68745"/>
    ''')
    svg("walker", 40, 32, '''
      <ellipse cx="20" cy="29" rx="16" ry="2" fill="#263b4e" opacity=".25"/>
      <path d="M7 25l-3 5h10l1-6M27 24l-1 6h10l-4-6" fill="#344b61"/>
      <path d="M4 23Q3 7 19 7q18 0 17 16z" fill="#ed8672" stroke="#394c62" stroke-width="2"/>
      <path d="M10 9L7 2l11 6M25 8l8-6-1 10" fill="#ffb890" stroke="#394c62" stroke-width="2"/>
      <path d="M9 16h23v10H9z" fill="#f7c7a2"/>
      <rect x="13" y="16" width="4" height="6" rx="1" fill="#263b4e"/>
      <rect x="25" y="16" width="4" height="6" rx="1" fill="#263b4e"/>
      <path d="M18 24h5" stroke="#ad574f" stroke-width="2"/>
    ''')
    svg("shell", 40, 32, '''
      <ellipse cx="20" cy="29" rx="17" ry="2" fill="#263b4e" opacity=".25"/>
      <path d="M6 25l-3 5h12l2-6M27 24l-2 6h12l-4-5" fill="#345365"/>
      <path d="M5 24Q3 6 19 3q18 1 17 21z" fill="#3cb8ad" stroke="#315068" stroke-width="2"/>
      <path d="M19 4l-6 9 7 8 10-7z" fill="#86dfb9" stroke="#278c8b" stroke-width="2"/>
      <path d="M4 23h32v5H4z" fill="#fce5b1" stroke="#315068" stroke-width="2"/>
      <path d="M7 15l7-2M29 14l7 3M20 21v3" stroke="#278c8b" stroke-width="2"/>
    ''')
    svg("coin", 24, 24, '''
      <ellipse cx="12" cy="12" rx="9" ry="11" fill="#dc8a2b"/>
      <ellipse cx="11" cy="11" rx="8" ry="10" fill="#ffd764" stroke="#fff2b1" stroke-width="2"/>
      <path d="M11 5l2 4 3 2-3 2-2 4-2-4-3-2 3-2z" fill="#f8ab3e"/>
    ''')
    svg("power", 32, 32, '''
      <path d="M16 1l12 9-3 16-9 5-9-5-3-16z" fill="#fef3b8" stroke="#f8b345" stroke-width="2"/>
      <path d="M7 18l5-2 4-10 4 10 5 2-6 3-3 6-3-6z" fill="#33bdb6"/>
      <path d="M12 16l4-10v12z" fill="#a9efcc"/>
    ''')
    svg("ground", 48, 48, '''
      <path d="M0 0h48v48H0z" fill="#a96d51"/>
      <path d="M0 17h48v7L0 37z" fill="#bc825b"/>
      <path d="M0 2h48v11l-6 5-7-4-7 5-8-4-7 3-7-4-6 3z" fill="#64bd83"/>
      <path d="M0 0h48v6H0z" fill="#a5e6a0"/>
      <path d="M4 29h9v4H4zM28 38h12v5H28zM33 25h7v4h-7zM9 44h8v4H9z" fill="#805549"/>
      <path d="M5 7l3 3 4-3M30 7l4 3 4-3" fill="none" stroke="#3f9b70" stroke-width="2"/>
    ''')
    svg("underground", 48, 48, '''
      <path d="M0 0h48v48H0z" fill="#304b68"/>
      <path d="M0 0h48v6H0z" fill="#568ba0"/>
      <path d="M0 24h48M23 5v19M11 24v24M37 24v24" stroke="#233d58" stroke-width="3"/>
      <path d="M27 10l7-3 5 6-6 7z" fill="#397693"/>
      <path d="M15 31l5-3 6 8-7 5z" fill="#477c97"/>
      <path d="M4 10h7M29 31h5" stroke="#699da7" stroke-width="2"/>
    ''')
    svg("ground_fill", 48, 48, '''
      <path d="M0 0h48v48H0z" fill="#a96d51"/>
      <path d="M0 17h48v7L0 37z" fill="#bc825b"/>
      <path d="M4 29h9v4H4zM28 38h12v5H28zM33 25h7v4h-7zM9 44h8v4H9z" fill="#805549"/>
    ''')
    svg("underground_fill", 48, 48, '''
      <path d="M0 0h48v48H0z" fill="#304b68"/>
      <path d="M0 24h48M23 0v24M11 24v24M37 24v24" stroke="#233d58" stroke-width="3"/>
      <path d="M27 10l7-3 5 6-6 7z" fill="#397693"/>
      <path d="M15 31l5-3 6 8-7 5z" fill="#477c97"/>
      <path d="M4 10h7M29 31h5" stroke="#699da7" stroke-width="2"/>
    ''')
    svg("item_block", 48, 48, '''
      <rect x="1" y="1" width="46" height="46" rx="7" fill="#b46f35" stroke="#f4d27a" stroke-width="2"/>
      <rect x="4" y="4" width="40" height="37" rx="5" fill="#efb64e"/>
      <path d="M24 10l4 8 9 2-7 7 1 10-7-5-8 5 2-10-7-7 9-2z" fill="#fff3bd" stroke="#d18e3c" stroke-width="2"/>
      <circle cx="8" cy="8" r="2" fill="#fff4c6"/><circle cx="40" cy="8" r="2" fill="#fff4c6"/>
    ''')
    svg("cloud", 192, 80, '''
      <path d="M20 67Q-2 64 5 44q6-14 28-12Q38 2 70 5q26 0 35 22 14-13 33-5 15 5 17 21 30-4 32 15 2 12-24 13H22z" fill="#fff9df"/>
      <path d="M25 69h134q20 0 24-9-29 8-48-2-12 8-28 5-19 7-37-2-18 10-45 0z" fill="#d1eeea"/>
    ''')
    svg("crystal", 64, 96, '''
      <path d="M26 3L8 31l10 50 17 11 19-28-4-41z" fill="#306ca1"/>
      <path d="M26 3l9 32-17 46L8 31z" fill="#69ddd7"/>
      <path d="M26 3l24 20-15 12z" fill="#b9ffea"/>
      <path d="M35 35l19 29-19 28z" fill="#489bd2"/>
      <path d="M50 23l4 41-19-29z" fill="#58c8dd"/>
      <path d="M4 61l9-8 12 32-9 6z" fill="#8ae7cf"/>
    ''')
    svg("goal", 64, 120, '''
      <path d="M8 115h49v5H8z" fill="#3b5f65"/>
      <path d="M26 13h7v101h-7z" fill="#d7bc81" stroke="#6d6863" stroke-width="2"/>
      <circle cx="29.5" cy="10" r="7" fill="#ffe392" stroke="#c48e46" stroke-width="2"/>
      <path d="M34 18h27L52 32l9 14H34z" fill="#ee816b"/>
      <path d="M39 25h13v12H39z" fill="#fff0d0"/>
      <path d="M39 25l7 6 6-6" fill="none" stroke="#dc9c76" stroke-width="2"/>
      <rect x="8" y="70" width="44" height="28" rx="4" fill="#32aca7" stroke="#375d67" stroke-width="2"/>
      <path d="M13 78h34v4H13z" fill="#205971"/>
      <path d="M14 89h12" stroke="#a5e5ce" stroke-width="3"/>
    ''')
    svg("logo", 480, 144, '''
      <path d="M59 111Q27 109 31 83q4-21 28-22Q65 20 110 29q30 0 39 29 27-16 45 9 32-8 38 20 5 24-31 24z" fill="#fff5ce" opacity=".9"/>
      <path d="M212 110Q184 104 191 80q7-15 24-15 6-38 45-34 33 0 44 25 31-16 45 10 48-4 51 24 1 20-32 20z" fill="#fff5ce" opacity=".9"/>
      <path d="M180 20h121v78H180z" fill="#f5b95a" stroke="#37556a" stroke-width="4"/>
      <path d="M181 22l59 46 59-46" fill="#ffe3a0" stroke="#37556a" stroke-width="4"/>
      <path d="M180 45l-49-13 10 18-21 1 19 12-12 9 53 6M301 45l49-13-10 18 21 1-19 12 12 9-53 6" fill="#75d8c2" stroke="#37556a" stroke-width="3"/>
      <circle cx="240" cy="89" r="14" fill="#ee806b"/><path d="M233 89h14M240 82v14" stroke="#ffe7b8" stroke-width="3"/>
    ''')


def tone(samples, start, length, frequency, gain, timbre=0):
    """指定区間の合成は加算操作なので非冪等。呼出側は毎回ゼロから生成する。"""
    begin = round(start * RATE)
    total = round(length * RATE)
    for offset in range(total):
        if begin + offset >= len(samples):
            break
        t = offset / RATE
        envelope = min(t / 0.008, 1.0) * min((length - t) / 0.04, 1.0)
        angle = 2 * math.pi * frequency * t
        sound = math.sin(angle) + timbre * math.sin(2 * angle) * 0.3
        samples[begin + offset] += gain * envelope * sound


def write_wave(name, samples):
    """飽和を避けたモノラル PCM を決定的に書き出す。"""
    target = ASSETS / "audio" / f"{name}.wav"
    target.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(target), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(b"".join(
            struct.pack("<h", round(max(-0.95, min(0.95, value)) * 32767))
            for value in samples
        ))


def frequency(note):
    return 440.0 * 2 ** ((note - 69) / 12)


def music(name, melody, bass, beat):
    """各ループの先頭・末尾をゼロにし、再生境界のクリックを防ぐ。"""
    samples = [0.0] * round(len(melody) * beat * RATE)
    for index, note in enumerate(melody):
        if note:
            tone(samples, index * beat, beat * 0.8, frequency(note), 0.13, 0.7)
        if index % 2 == 0:
            tone(samples, index * beat, beat * 1.7,
                 frequency(bass[index // 8]), 0.1)
        tone(samples, index * beat, 0.045, 115, 0.07)
    write_wave(name, samples)


def effects():
    patterns = {
        "jump": ([60, 67, 76], 0.06),
        "stomp": ([48, 36], 0.055),
        "coin": ([83, 90], 0.09),
        "power": ([60, 64, 67, 72, 76, 79], 0.09),
        "death": ([67, 63, 60, 55, 48], 0.13),
        "clear": ([72, 76, 79, 84, 79, 84, 88], 0.13),
    }
    for name, (notes, beat) in patterns.items():
        samples = [0.0] * round((len(notes) * beat + 0.04) * RATE)
        for index, note in enumerate(notes):
            tone(samples, index * beat, beat, frequency(note), 0.25, 1)
        write_wave(name, samples)


def main():
    images()
    music("stage1", [72, 76, 79, 76, 74, 72, 67, 0,
                     69, 72, 76, 72, 74, 76, 79, 0,
                     77, 76, 74, 72, 69, 72, 74, 0,
                     67, 71, 74, 79, 76, 74, 71, 0], [48, 45, 41, 43], 0.26)
    music("stage2", [69, 0, 76, 72, 0, 71, 76, 0,
                     65, 0, 72, 69, 0, 67, 72, 0,
                     62, 0, 69, 65, 0, 64, 69, 0,
                     64, 0, 71, 68, 0, 71, 68, 0], [45, 41, 38, 40], 0.32)
    effects()


if __name__ == "__main__":
    main()
