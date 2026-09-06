"""独自作曲の四場面BGMとSEを倍音・打楽器・左右定位から合成する。"""
from array import array
import math
from pathlib import Path
import random
import subprocess
import wave

ROOT = Path(__file__).resolve().parents[2] / 'assets' / 'audio'
RATE = 22050
TAU = math.tau


def note(samples, start, duration, midi, volume, timbre='harp', pan=0., seed=0):
    frequency = 440 * 2 ** ((midi - 69) / 12)
    rng = random.Random(seed)
    length = int(duration * RATE)
    begin = int(start * RATE)
    total = len(samples) // 2
    left, right = (1-pan) / 2, (1+pan) / 2
    for i in range(length):
        t = i / RATE
        phase = TAU * frequency * t
        progress = i / max(1, length - 1)
        release = min(1., (1-progress) * 14)
        if timbre == 'harp':
            v = (math.sin(phase) + .35 * math.sin(phase*2) + .16 * math.sin(phase*3)) * math.exp(-5*t)
            envelope = min(1, t*300) * release
        elif timbre == 'flute':
            v = math.sin(phase + .014*math.sin(TAU*5*t)) + .14 * math.sin(phase*2) + .08 * math.sin(phase*3)
            envelope = min(1, t*12) * release * (.9 + rng.random()*.1)
        elif timbre == 'string':
            v = sum(math.sin(phase*h + h*.025*math.sin(TAU*4*t)) / h for h in range(1, 5)) / 2
            envelope = min(1, t*5) * min(1, (1-progress)*5)
        elif timbre == 'bell':
            v = math.sin(phase)*math.exp(-3*t) + .4*math.sin(phase*2.76)*math.exp(-5*t) + .2*math.sin(phase*5.4)*math.exp(-9*t)
            envelope = min(1, t*180) * release
        elif timbre == 'drum':
            v = math.sin(TAU*(65*t + 5*(1-math.exp(-22*t))))*.7 + rng.uniform(-1, 1)*.3
            envelope = min(1,t*400)*math.exp(-19*t)*release
        else:
            v = rng.uniform(-1, 1)
            envelope = min(1,t*300)*math.exp(-15*t)*release
        value = v * envelope * volume
        # BGM末尾の残響は先頭へ循環させ、ループの空白を作らない。
        index = ((begin+i) % total) * 2
        samples[index] += value * left
        samples[index+1] += value * right


def save(name, samples):
    peak = max(abs(v) for v in samples)
    gain = .78 / max(peak, 1.)
    pcm = array('h', (int(max(-.95, min(.95, value*gain))*32767) for value in samples))
    # Oggのserialとメタデータを固定し、同じ生成器でバイト一致を保つ。
    work = ROOT.parents[1] / 'tmp' / 'audio-generation'
    work.mkdir(parents=True, exist_ok=True)
    (work / '.gdignore').touch()
    wav = work / f'{name}.wav'
    output = work / f'{name}.ogg'
    with wave.open(str(wav), 'wb') as stream:
        stream.setnchannels(2)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(pcm.tobytes())
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-fflags', '+bitexact', '-i', str(wav), '-map_metadata', '-1', '-c:a', 'libvorbis', '-q:a', '4', '-flags:a', '+bitexact', '-fflags', '+bitexact', str(output)], check=True)
    output.replace(ROOT / f'{name}.ogg')
    wav.unlink()


def music(name, bpm, melody, chords, mode):
    beat = 60 / bpm
    samples = [0.] * (int(beat*32*RATE)*2)
    for bar in range(8):
        root = chords[bar % len(chords)]
        start = bar*4*beat
        for chord in (0, 7, 12):
            note(samples, start, beat*4.3, root+chord, .2, 'string', (chord-6)/16, bar)
        for step in range(8):
            note(samples, start+step*beat/2, beat*.95, root+12+(0,7,12,7)[step%4], .25, 'harp', -.5 if step%2 else .5)
        for j in range(4):
            pitch = melody[(bar*4+j)%len(melody)]
            if pitch:
                note(samples, start+j*beat, beat*1.3, pitch, .3, 'flute' if mode != 'result' else 'bell', -.15)
            if mode == 'battle' or (mode == 'stage' and j%2 == 0):
                note(samples, start+j*beat, .35, 40, .27 if j%2 == 0 else .15, 'drum', 0, bar*7+j)
        if mode in ('battle', 'stage'):
            for step in range(8):
                note(samples, start+step*beat/2, .12, 50, .04, 'noise', .55, bar*9+step)
        if bar in (0,4):
            note(samples, start, beat*2, root+36, .17, 'bell', .4)
    save(name, samples)


def effects():
    for cue in ('attack', 'heal', 'level', 'confirm'):
        length = 1.8 if cue in ('heal','level') else .7
        samples = [0.] * (int(length*RATE)*2)
        if cue == 'attack':
            note(samples, 0, .22, 50, .65, 'noise', -.3, 41)
            note(samples, .08, .35, 36, .7, 'drum')
            note(samples, .08, .45, 82, .2, 'bell', .2)
        elif cue in ('heal', 'level'):
            pitches = (72, 76, 79, 84) if cue == 'heal' else (67, 72, 76, 79, 84)
            for i, pitch in enumerate(pitches):
                note(samples, i*.12, .95, pitch, .4, 'bell', -.5+i*.2)
        else:
            note(samples, 0, .35, 79, .5, 'harp', -.1)
            note(samples, .06, .4, 86, .28, 'bell', .1)
        save(cue, samples)


if __name__ == '__main__':
    ROOT.mkdir(parents=True, exist_ok=True)
    music('title', 84, [76,79,81,0,83,81,79,76,74,76,79,81,79,76,74,0], [45,41,48,43], 'title')
    music('stage', 106, [72,76,79,76,74,77,81,79,76,79,84,81,79,76,74,72], [48,43,45,41], 'stage')
    music('battle', 138, [69,72,76,72,71,74,77,74,72,76,79,76,74,77,81,79], [45,41,43,40], 'battle')
    music('result', 92, [76,79,84,0,83,79,76,0,81,84,88,84,79,76,72,0], [48,43,45,41], 'result')
    effects()
    print('tactics BGM4曲・SE4種 Ogg Vorbisを生成')
