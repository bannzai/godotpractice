"""潮風カートの独自 SVG / WAV を同じ入力から再生成する。外部素材は使用しない。"""

from array import array
import math
from pathlib import Path
import random
import wave

ROOT = Path(__file__).resolve().parents[2] / "assets"
RATE = 22050
NAVY = "#183548"
CREAM = "#fff4d6"


def svg(folder: str, name: str, width: int, height: int, content: str) -> None:
    destination = ROOT / folder / f"{name}.svg"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}">{content}</svg>\n'
    )


def portraits() -> None:
    common = f'<circle cx="128" cy="128" r="123" fill="{NAVY}"/><circle cx="128" cy="128" r="112" fill="{CREAM}"/>'
    otter = '''<path d="M31 228Q48 171 91 176L164 176Q216 184 226 228" fill="#42cbb0"/>
    <circle cx="68" cy="91" r="27" fill="#987055"/><circle cx="190" cy="91" r="27" fill="#987055"/>
    <ellipse cx="128" cy="124" rx="76" ry="72" fill="#b98860"/>
    <ellipse cx="128" cy="151" rx="48" ry="37" fill="#fff0d0"/>
    <path d="M48 96Q55 38 128 37Q200 39 209 96L183 92L74 92Z" fill="#42cbb0"/>
    <path d="M113 40H139L143 84H109Z" fill="#fff4d6"/>
    <rect x="59" y="81" width="139" height="35" rx="16" fill="#183548"/>
    <rect x="66" y="87" width="54" height="22" rx="10" fill="#b9f5e7"/>
    <rect x="136" y="87" width="54" height="22" rx="10" fill="#b9f5e7"/>
    <ellipse cx="103" cy="132" rx="7" ry="10" fill="#183548"/><ellipse cx="153" cy="132" rx="7" ry="10" fill="#183548"/>
    <ellipse cx="128" cy="148" rx="12" ry="8" fill="#183548"/>
    <path d="M110 166Q128 180 147 166" fill="none" stroke="#183548" stroke-width="5" stroke-linecap="round"/>
    <path d="M94 185L128 209L163 185" fill="#fff4d6"/><circle cx="128" cy="223" r="9" fill="#183548"/>'''
    fox = '''<path d="M29 230Q42 177 87 172H170Q218 185 229 230" fill="#f69340"/>
    <path d="M61 101L56 25L111 71M145 70L204 25L197 112" fill="#e87a36" stroke="#183548" stroke-width="7" stroke-linejoin="round"/>
    <path d="M67 47L75 94L101 77M190 48L181 94L156 77" fill="#ffd9a7"/>
    <path d="M53 102Q128 61 204 102L185 158L128 191L73 158Z" fill="#eb853e"/>
    <path d="M57 115L126 151L199 116L181 162L128 189L74 161Z" fill="#fff4d6"/>
    <path d="M78 76Q129 39 180 76L182 103H74Z" fill="#f69340"/>
    <rect x="67" y="86" width="122" height="24" rx="12" fill="#183548"/>
    <rect x="75" y="91" width="46" height="13" rx="6" fill="#c1edf2"/><rect x="137" y="91" width="44" height="13" rx="6" fill="#c1edf2"/>
    <path d="M86 127L105 131M151 131L169 124" stroke="#183548" stroke-width="7" stroke-linecap="round"/>
    <path d="M116 150H140L128 162Z" fill="#183548"/><path d="M117 174Q128 179 141 170" fill="none" stroke="#183548" stroke-width="4"/>
    <path d="M91 186L133 212L173 180L156 225L121 215L92 229Z" fill="#e25364"/>'''
    owl = '''<path d="M32 230Q40 179 90 173H169Q219 184 225 230" fill="#9c80dd"/>
    <path d="M55 100L56 45L99 69Q129 57 157 70L201 44L199 110Z" fill="#8265a8"/>
    <ellipse cx="128" cy="130" rx="75" ry="68" fill="#9978ba"/>
    <path d="M60 104Q88 82 125 118Q161 83 194 104L178 160L128 189L77 160Z" fill="#fff0d3"/>
    <circle cx="96" cy="129" r="27" fill="#e6c990"/><circle cx="160" cy="129" r="27" fill="#e6c990"/>
    <circle cx="96" cy="129" r="16" fill="#183548"/><circle cx="160" cy="129" r="16" fill="#183548"/>
    <circle cx="101" cy="123" r="6" fill="white"/><circle cx="165" cy="123" r="6" fill="white"/>
    <path d="M116 148L128 168L140 148Z" fill="#f5a244"/>
    <path d="M72 91Q89 54 128 53Q171 53 187 91Z" fill="#9c80dd"/>
    <path d="M112 57H139L142 88H110Z" fill="#fff4d6"/>
    <path d="M74 93H187" stroke="#183548" stroke-width="12" stroke-linecap="round"/>
    <path d="M99 195L128 211L158 195L151 230H106Z" fill="#fff4d6"/><path d="M119 199H138L130 218Z" fill="#ed7980"/>'''
    for name, art in [("otter", otter), ("fox", fox), ("owl", owl)]:
        svg("portraits", name, 256, 256, common + art)


def ui_images() -> None:
    badge = '<circle cx="64" cy="64" r="61" fill="#183548"/><circle cx="64" cy="64" r="53" fill="#fff4d6"/>'
    svg("items", "pulse", 128, 128, badge + '<path d="M26 64H78M64 44L86 64L64 84" fill="none" stroke="#ef7880" stroke-width="13" stroke-linecap="round" stroke-linejoin="round"/><path d="M88 33Q118 64 88 96" fill="none" stroke="#42cbb0" stroke-width="7"/>')
    svg("items", "buoy", 128, 128, badge + '<path d="M34 86L48 52H80L94 86Z" fill="#f18c3f"/><path d="M42 66H86L90 76H38Z" fill="#fff4d6"/><path d="M64 52V25L86 35L64 43" fill="#e56570" stroke="#183548" stroke-width="4"/><path d="M21 94Q35 85 49 94T77 94T105 94" fill="none" stroke="#42cbb0" stroke-width="6"/>')
    svg("items", "turbo", 128, 128, badge + '<path d="M28 93L40 67L57 88Z" fill="#ed7980"/><path d="M40 86L50 48L82 28L98 32L100 50L80 82Z" fill="#42cbb0" stroke="#183548" stroke-width="4"/><circle cx="78" cy="50" r="10" fill="#fff4d6"/><path d="M50 88L65 73M28 107L44 91M20 87L34 73" stroke="#f69340" stroke-width="8" stroke-linecap="round"/>')
    svg("ui", "trophy", 128, 128, '<path d="M39 25H89V54Q87 77 64 81Q41 76 39 54Z" fill="#f5bd57" stroke="#183548" stroke-width="5"/><path d="M39 32H22V44Q22 67 43 65M89 32H106V44Q107 67 85 65" fill="none" stroke="#f5bd57" stroke-width="10"/><path d="M64 80V101M43 105H85" stroke="#183548" stroke-width="9" stroke-linecap="round"/><path d="M64 34L69 44L80 46L72 54L74 65L64 60L54 65L56 54L48 46L59 44Z" fill="#fff4d6"/>')
    svg("ui", "speed", 128, 128, '<path d="M21 95A49 49 0 1 1 107 95" fill="none" stroke="#fff4d6" stroke-width="13" stroke-linecap="round"/><path d="M65 76L91 43" stroke="#f69340" stroke-width="10" stroke-linecap="round"/><circle cx="65" cy="76" r="12" fill="#42cbb0"/>')
    svg("ui", "flag", 128, 128, '<path d="M31 112V17" stroke="#183548" stroke-width="9" stroke-linecap="round"/><path d="M35 19H107V73H35Z" fill="#fff4d6"/><path d="M35 19H53V37H35ZM71 19H89V37H71ZM53 37H71V55H53ZM89 37H107V55H89ZM35 55H53V73H35ZM71 55H89V73H71Z" fill="#183548"/>')
    svg("ui", "wave", 640, 96, '<path d="M0 45Q80 -10 160 45T320 45T480 45T640 45V96H0Z" fill="#42cbb0"/><path d="M0 63Q80 12 160 63T320 63T480 63T640 63" fill="none" stroke="#b9f5e7" stroke-width="7"/>')
    kart = '<ellipse cx="0" cy="37" rx="115" ry="22" fill="#183548" opacity=".15"/><rect x="-105" y="-8" width="35" height="53" rx="14" fill="#183548"/><rect x="70" y="-8" width="35" height="53" rx="14" fill="#183548"/><path d="M-81 4L-57 -53H54L82 4L67 28H-67Z" fill="#42cbb0" stroke="#183548" stroke-width="6"/><path d="M-41 -43H39L51 -7H-53Z" fill="#b9f5e7"/><path d="M-55 4H55" stroke="#fff4d6" stroke-width="13"/><circle cx="0" cy="-27" r="14" fill="#183548"/><circle cx="0" cy="-27" r="7" fill="#f5bd57"/>'
    svg("ui", "logo", 640, 280, '<path d="M130 169Q215 -40 365 68Q441 -10 520 98Q614 212 441 242H152Q33 232 130 169Z" fill="#fff4d6" stroke="#183548" stroke-width="9"/><path d="M63 220Q114 180 169 220T275 220T381 220T487 220T593 220" fill="none" stroke="#42cbb0" stroke-width="17"/><path d="M481 52V160M484 54L559 65L541 112L484 101" fill="#f69340" stroke="#183548" stroke-width="7"/><g transform="translate(312 164) scale(1.4)">' + kart + '</g><path d="M91 101L137 87M72 136L127 127M499 181L559 175" stroke="#ed7980" stroke-width="10" stroke-linecap="round"/>')
    svg("ui", "keyart", 960, 600, '<defs><linearGradient id="sky" x2="0" y2="1"><stop stop-color="#b9e8e7"/><stop offset="1" stop-color="#fff4d6"/></linearGradient></defs><rect width="960" height="600" rx="36" fill="url(#sky)"/><circle cx="763" cy="115" r="65" fill="#f6c96b"/><path d="M0 234Q120 200 240 238T480 225T720 224T960 214V600H0Z" fill="#5bcdbd"/><path d="M0 310Q220 185 353 303Q479 414 698 280Q823 211 960 270V600H0Z" fill="#f6dba5"/><path d="M-80 580Q250 342 509 391Q772 432 1010 231" fill="none" stroke="#183548" stroke-width="131"/><path d="M-80 580Q250 342 509 391Q772 432 1010 231" fill="none" stroke="#48676c" stroke-width="110"/><path d="M-80 580Q250 342 509 391Q772 432 1010 231" fill="none" stroke="#fff4d6" stroke-width="5" stroke-dasharray="33 27"/><g fill="#fff4d6"><ellipse cx="199" cy="108" rx="76" ry="19"/><ellipse cx="239" cy="95" rx="46" ry="30"/><ellipse cx="520" cy="156" rx="77" ry="17"/></g><g stroke="#e77880" stroke-width="19" stroke-linecap="round" fill="none"><path d="M831 575V465M831 512L798 486V458M831 535L866 503V475M70 388V287M70 321L41 298M70 348L101 319V294"/></g><g transform="translate(560 359) rotate(-8) scale(1.75)">' + kart + '</g><g transform="translate(321 421) rotate(9) scale(.86)">' + kart.replace('#42cbb0', '#f69340') + '</g><path d="M652 378L737 379M661 405L713 411" stroke="#fff4d6" stroke-width="12" stroke-linecap="round"/><g transform="translate(556 233)"><ellipse cy="20" rx="43" ry="42" fill="#b98860"/><circle cx="-32" r="15" fill="#b98860"/><circle cx="31" r="15" fill="#b98860"/><path d="M-44 6Q-37 -36 0 -33Q36 -35 45 6Z" fill="#42cbb0" stroke="#183548" stroke-width="4"/><rect x="-37" y="0" width="74" height="16" rx="8" fill="#183548"/><ellipse cy="36" rx="23" ry="17" fill="#fff4d6"/><circle cx="-15" cy="23" r="4" fill="#183548"/><circle cx="15" cy="23" r="4" fill="#183548"/><ellipse cy="33" rx="7" ry="5" fill="#183548"/></g>')


def frequency(note: int) -> float:
    return 440 * 2 ** ((note - 69) / 12)


def tone(samples: list[float], start: float, duration: float, note: int, level: float, kind: str) -> None:
    offset = int(start * RATE)
    count = min(int(duration * RATE), len(samples) - offset)
    freq = frequency(note)
    for index in range(max(0, count)):
        t = index / RATE
        phase = math.tau * freq * t
        if kind == "bass":
            value = math.sin(phase) + .23 * math.sin(phase * 2) + .12 * math.sin(phase * 3)
            envelope = min(1, t * 100) * min(1, (duration - t) * 35)
        elif kind == "pad":
            value = .6 * math.sin(phase) + .2 * math.sin(phase * 2) + .15 * math.sin(phase * 3 + .2)
            envelope = min(1, t * 12) * min(1, (duration - t) * 8)
        else:
            value = math.sin(phase) + .42 * math.sin(phase * 2.002) + .2 * math.sin(phase * 3.99)
            envelope = min(1, t * 250) * math.exp(-t * 6 / max(duration, .1))
        samples[offset + index] += value * envelope * level


def percussion(samples: list[float], start: float, kind: str, rng: random.Random) -> None:
    duration = .16 if kind == "kick" else .08
    offset = int(start * RATE)
    for index in range(min(int(duration * RATE), len(samples) - offset)):
        t = index / RATE
        if kind == "kick":
            value = math.sin(math.tau * (70 * t + 1.6 * (1 - math.exp(-40 * t)))) * math.exp(-24 * t) * .22
        else:
            value = rng.uniform(-1, 1) * math.exp(-55 * t) * (.065 if kind == "hat" else .13)
        samples[offset + index] += value


def save_audio(name: str, samples: list[float]) -> None:
    destination = ROOT / "audio" / f"{name}.wav"
    destination.parent.mkdir(parents=True, exist_ok=True)
    peak = max(max(abs(value) for value in samples), .75)
    packed = array("h", [int(max(-1, min(1, value / peak * .86)) * 32767) for value in samples])
    with wave.open(str(destination), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(packed.tobytes())


def music(name: str, bpm: int, shift: int, busy: bool) -> None:
    beat = 60 / bpm
    samples = [0.0] * round(32 * beat * RATE)
    rng = random.Random(381)
    roots = [48, 53, 57, 55, 48, 53, 55, 48]
    melody = [72, 76, 79, 76, 74, 77, 81, 77, 76, 79, 84, 81, 74, 79, 77, 74]
    for bar, root in enumerate(roots):
        start = bar * 4 * beat
        for chord_note in [root + 12, root + 16, root + 19]:
            tone(samples, start, beat * 3.85, chord_note + shift, .055, "pad")
        for step in range(8):
            position = start + step * beat / 2
            tone(samples, position, beat * .75, root + shift + (7 if step % 4 == 3 else 0), .12, "bass")
            if busy or step % 2 == 0:
                note = melody[(bar * 2 + step) % len(melody)] + shift
                tone(samples, position, beat * .85, note, .18, "bell")
            percussion(samples, position, "hat", rng)
            if step in [0, 4]:
                percussion(samples, position, "kick", rng)
            if step in [2, 6]:
                percussion(samples, position, "snare", rng)
    save_audio(name, samples)


def effects() -> None:
    patterns = {
        "item": [72, 79, 84], "boost": [48, 60, 72, 84], "countdown": [76],
        "finish": [72, 76, 79, 84, 88], "select": [76, 81], "lap": [79, 84, 88],
        "hit": [47, 40, 35],
    }
    for name, pattern in patterns.items():
        duration = .08 * len(pattern) + .22
        samples = [0.0] * int(duration * RATE)
        for index, note in enumerate(pattern):
            tone(samples, index * .08, .2, note, .36, "bell" if name != "hit" else "bass")
        if name == "hit":
            percussion(samples, 0, "snare", random.Random(24))
        if name == "finish":
            for note in [60, 64, 67]:
                tone(samples, .1, .4, note, .15, "pad")
        save_audio(name, samples)
    samples = [0.0] * RATE
    for index in range(RATE):
        t = index / RATE
        samples[index] = sum(math.sin(math.tau * hz * t) * amplitude for hz, amplitude in [(55, .21), (110, .12), (165, .065), (220, .03)]) * (.8 + .2 * math.sin(math.tau * 15 * t))
    save_audio("engine", samples)


def main() -> None:
    portraits()
    ui_images()
    for name, bpm, shift, busy in [("title", 116, 0, False), ("race", 144, 0, True), ("final", 170, 2, True), ("results", 108, 5, False)]:
        music(name, bpm, shift, busy)
    effects()
    print("潮風カート: SVG 12 点、BGM 4 曲、SE 8 音を生成")


if __name__ == "__main__":
    main()
