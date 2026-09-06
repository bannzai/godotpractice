#!/usr/bin/env python3
"""既存の旋律・録音を参照しない、倍音・残響・雑音による独自の音声。"""
import argparse
import io
import json
import math
from pathlib import Path
import random
import struct
import wave

RATE = 22050
TAU = math.tau
BGM = ["title", "map", "battle", "police", "boss", "result"]
SFX = ["attack", "hurt", "spirit", "step", "siren", "heartbeat", "acquire",
       "select", "transition", "dissolve", "heal"]


def hz(note):
    return 440 * 2 ** ((note - 69) / 12)


def add_voice(channels, start, duration, pitch, kind, gain, pan=0, seed=1, wrap=True):
    rng = random.Random(seed)
    total = len(channels[0])
    delay = int(.039 * RATE)
    noise = 0
    for frame in range(int(duration * RATE)):
        t = frame / RATE
        attack = min(1, t / .012)
        fade = min(1, (duration-t)/.07)
        phase = TAU * pitch * t
        noise = noise*.82 + rng.uniform(-1,1)*.18
        if kind == "bell":
            value = sum(math.sin(phase*o + .12*math.sin(t*4))*a*math.exp(-t*d)
                        for o,a,d in [(1,.65,2),(2.71,.22,3.1),(4.09,.12,4.2),(5.43,.06,6)])
        elif kind == "pluck":
            value = sum(math.sin(phase*o)*(.5/o)*math.exp(-t*(4+o*1.2)) for o in range(1,7))
            value += noise*.13*math.exp(-t*30)
        elif kind == "breath":
            value = (.6*math.sin(phase+.014*math.sin(t*TAU*4.7))+.14*math.sin(phase*2)+noise*.13)
            value *= math.sin(math.pi*t/duration)**2
        elif kind == "drum":
            value = math.sin(phase*(1+.38*math.exp(-t*32)))*math.exp(-t*11)
            value += noise*.7*math.exp(-t*36)
        elif kind == "wood":
            value = (math.sin(phase)+.5*math.sin(phase*2.31)+noise)*math.exp(-t*34)
        elif kind == "siren":
            phase = TAU * (pitch*t + 70*(1-math.cos(t*TAU*2.5))/(TAU*2.5))
            value = (.52*math.sin(phase)+.15*math.sin(phase*3)+.06*math.sin(phase*5))
            value *= math.sin(math.pi*t/duration)
        else:
            value = (noise*.7+math.sin(phase*.7)*.18)*math.sin(math.pi*t/duration)
        sample = value*gain*attack*fade
        index = int(start*RATE)+frame
        if not wrap and index >= total:
            break
        channels[0][index%total] += sample*(.72-pan*.28)
        channels[1][index%total] += sample*(.72+pan*.28)
        echo = index+delay
        if wrap or echo < total:
            channels[1][echo%total] += sample*.16


def bgm(name):
    beat = {"title":.6,"map":.42,"battle":.28,"police":.25,"boss":.3,"result":.6}[name]
    count = 16 if name in ["title","result"] else 32
    duration = beat*count
    data = [[0.0]*int(duration*RATE) for _ in range(2)]
    root = {"title":45,"map":50,"battle":43,"police":42,"boss":38,"result":50}[name]
    melody = [0,7,10,14,12,7,3,2,0,3,7,12,10,7,2,-2]
    if name == "result":
        melody = [0,7,12,14,16,14,12,7,4,7,12,16,14,12,7,0]
    for i in range(count):
        note = root+12+melody[i%len(melody)]
        if i%2 == 0 or name in ["map","battle","boss"]:
            kind = "bell" if name in ["title","result"] else "pluck"
            add_voice(data,i*beat,beat*3,hz(note),kind,.17,.55*math.sin(i),i+13)
        if i%8 == 0:
            for interval in [0,7,12]:
                add_voice(data,i*beat,beat*9,hz(root+interval),"breath",.085,interval/12-.5,i)
        if name in ["battle","boss","police"]:
            if i%4 == 0 or (name=="boss" and i%4==3):
                add_voice(data,i*beat,.65,55 if name=="boss" else 72,"drum",.31,0,i)
            if i%2:
                add_voice(data,i*beat,.15,330,"wood",.11,-.4,i)
        if name == "map" and i%4 == 2:
            add_voice(data,i*beat,.18,290,"wood",.07,.3,i)
        if name == "police" and i%8 == 0:
            add_voice(data,i*beat,beat*7.5,280,"siren",.08,.45,i)
        if name == "boss" and i%8 == 4:
            add_voice(data,i*beat,beat*7,hz(root+25),"bell",.12,-.7,i)
    return data


def sfx(name):
    duration = {"attack":.45,"hurt":.48,"spirit":1.25,"step":.24,"siren":1.6,
                "heartbeat":1.45,"acquire":.9,"select":.19,"transition":.8,
                "dissolve":1.35,"heal":.95}[name]
    data = [[0.0]*int(duration*RATE) for _ in range(2)]
    if name in ["heartbeat","step","hurt"]:
        add_voice(data,0,duration,55 if name=="heartbeat" else 115,"drum",.55,wrap=False)
        if name == "heartbeat":
            add_voice(data,.28,.6,72,"drum",.4,wrap=False)
            add_voice(data,.82,.58,52,"drum",.35,wrap=False)
    elif name == "siren":
        add_voice(data,0,duration,440,"siren",.43,wrap=False)
    elif name in ["select","acquire","heal"]:
        notes = [74] if name=="select" else [62,69,74]
        for i,note in enumerate(notes):
            add_voice(data,i*.14,duration-i*.14,hz(note),"bell",.4,wrap=False)
    else:
        add_voice(data,0,duration,150,"wind",.44,wrap=False)
        if name in ["spirit","dissolve"]:
            add_voice(data,0,duration,180 if name=="spirit" else 90,"breath",.35,wrap=False)
        if name == "attack":
            add_voice(data,.06,.25,210,"wood",.5,wrap=False)
    return data


def wav_bytes(data):
    peak = max(abs(value) for channel in data for value in channel)
    gain = .72/max(peak,.001)
    pcm = bytearray()
    for left,right in zip(*data):
        pcm += struct.pack("<hh",round(left*gain*32767),round(right*gain*32767))
    buf = io.BytesIO()
    with wave.open(buf,"wb") as audio:
        audio.setnchannels(2)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(pcm)
    return buf.getvalue()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir",type=Path,default=Path(__file__).resolve().parents[2]/"assets")
    parser.add_argument("--print-spec",action="store_true")
    args = parser.parse_args()
    if args.print_spec:
        print(json.dumps({"rate":RATE,"images":[],"audio":[{"path":f"audio/{name}.wav","loop":name in BGM,"stereo":True} for name in BGM+SFX]}))
        return
    for name in BGM+SFX:
        dest=args.out_dir/f"audio/{name}.wav"
        dest.parent.mkdir(parents=True,exist_ok=True)
        content=wav_bytes(bgm(name) if name in BGM else sfx(name))
        if not dest.exists() or dest.read_bytes()!=content:
            dest.write_bytes(content)
        print(f"音声を生成: {name}")


if __name__ == "__main__":
    main()
