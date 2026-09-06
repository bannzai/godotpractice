#!/usr/bin/env python3
"""和風ホラーの独自楽譜を、固定乱数・倍音・膜振動・息音で再現する。"""

import argparse
from array import array
from functools import lru_cache
import io
import json
import math
from pathlib import Path
import random
import sys
import wave

ROOT = Path(__file__).resolve().parents[2] / "assets"
RATE = 22050
TAU = math.tau
MUSIC = {
    "title": (76, "shakuhachi", [50, 53, 57, 60], [74, 0, 77, 74, 72, 69, 0, 65]),
    "map": (88, "koto", [50, 57, 60, 62], [74, 77, 81, 77, 74, 72, 69, 0]),
    "battle": (112, "shamisen", [50, 53, 57, 62], [74, 74, 77, 81, 77, 74, 72, 69]),
    "boss": (120, "reed", [38, 41, 45, 50], [62, 0, 65, 69, 65, 62, 60, 57]),
    "police": (104, "wood", [49, 53, 56, 60], [73, 73, 0, 72, 73, 68, 0, 65]),
    "result": (64, "bell", [50, 53, 57, 62], [74, 72, 69, 0, 65, 62, 0, 0]),
}
EFFECTS = {"card": .22, "attack": .48, "voice": 1.05, "acquire": 1.1,
           "transition": .75, "hit": .4, "darkness": 1.3, "heal": .9, "victory": 1.7}


@lru_cache(maxsize=256)
def note(kind, midi, seconds):
    """音色ごとに異なる非整数倍音、息、爪のアタックを持つ一発音。"""
    rng = random.Random(501 + midi)
    hz = 440 * 2 ** ((midi - 69) / 12)
    output = array("f")
    previous = 0
    for index in range(round(seconds * RATE)):
        time = index / RATE
        phase = TAU * hz * time
        noise = rng.uniform(-1, 1)
        edge = min(1, time/.005, (seconds-time)/.04)
        if kind in ("koto", "shamisen"):
            tone = sum(math.sin(phase*h) * math.exp(-time*h*3.3) / h
                       for h in range(1, 8 if kind == "shamisen" else 6))
            tone += (noise-previous) * math.exp(-time*65) * .23
            if kind == "shamisen":
                tone += math.sin(phase*2.014) * math.exp(-time*9) * .24
        elif kind == "shakuhachi":
            phase += .035*math.sin(TAU*4.8*time) + .07*math.exp(-time*8)
            tone = math.sin(phase)+.17*math.sin(phase*2)+.11*math.sin(phase*3)
            tone += (noise+previous)*.025
            tone *= min(1,time/.11,(seconds-time)/.13)
        elif kind == "reed":
            tone = sum(math.sin(phase*h)/h for h in (1,2,3,5,7))
            tone *= min(1,time/.09)*math.exp(-time*1.6)
        elif kind == "pad":
            tone = math.sin(phase)+.2*math.sin(phase*1.002)+.12*math.sin(phase*2.003)
            tone *= min(1,time/.35,(seconds-time)/.35)*.6
        elif kind == "wood":
            tone = (math.sin(phase)+.6*math.sin(phase*2.63)+.2*math.sin(phase*4.71))
            tone *= math.exp(-time*18)
        elif kind == "bass":
            tone = (math.sin(phase)+.3*math.sin(phase*2))*math.exp(-time*3)
        else:
            tone = sum(math.sin(phase*r)*math.exp(-time*(1.6+i*2))/(i+1)
                       for i,r in enumerate((1,2.76,4.1,5.47)))
        output.append(tone*edge)
        previous = noise
    return output


@lru_cache(maxsize=8)
def percussion(kind):
    rng = random.Random({"taiko":31,"rim":37,"gong":41,"shaker":43}[kind])
    seconds = {"taiko":.6,"rim":.19,"gong":2.8,"shaker":.16}[kind]
    output = array("f")
    previous = 0
    for index in range(round(seconds*RATE)):
        time = index/RATE
        noise = rng.uniform(-1,1)
        if kind == "taiko":
            phase = TAU*(57*time+43*(1-math.exp(-time*27))/27)
            value = (math.sin(phase)+.28*math.sin(phase*1.58))*math.exp(-time*9)
            value += noise*math.exp(-time*100)*.24
        elif kind == "rim":
            value = (math.sin(TAU*612*time)+.4*noise)*math.exp(-time*35)
        elif kind == "gong":
            value = sum(math.sin(TAU*79*ratio*time)/(i+1)
                        for i,ratio in enumerate((1,1.43,2.19,3.07,4.6,5.87)))
            value *= math.exp(-time*1.6)*min(1,time/.015)
        else:
            value = (noise-previous)*math.exp(-time*25)*.3
        output.append(value*min(1,(seconds-time)/.015))
        previous=noise
    return output


def mix(channels, sound, start, gain, pan=0):
    """各楽譜イベントを一度だけ加算するため非冪等。残響を循環させる。"""
    offset = round(start*RATE)
    length=len(channels[0])
    gains=(gain*math.sqrt((1-pan)/2),gain*math.sqrt((1+pan)/2))
    for i,value in enumerate(sound):
        frame=(offset+i)%length
        channels[0][frame]+=value*gains[0]
        channels[1][frame]+=value*gains[1]


def encode(channels, loop=False):
    """加算元を変更せず反射音を追加し、余裕を残したPCMを返す。"""
    length=len(channels[0])
    wet=[array("f",channel) for channel in channels]
    for delay,decay in ((.139,.13),(.281,.07)):
        offset=round(delay*RATE)
        for side in range(2):
            for i in range(length):
                if loop or i>=offset:
                    wet[side][i]+=channels[1-side][(i-offset)%length]*decay
    peak=max(abs(value) for side in wet for value in side)
    gain=.82/max(.01,peak)
    data=array("h")
    for i in range(length):
        # 量子化後も端点をゼロにし、ループ境界のクリックを防ぐ。
        edge=min(1,i/(RATE*.008),(length-1-i)/(RATE*.008))
        for side in wet:
            data.append(round(side[i]*gain*edge*32767))
    if sys.byteorder!="little":
        data.byteswap()
    buffer=io.BytesIO()
    with wave.open(buffer,"wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(data.tobytes())
    return buffer.getvalue()


def music(name, definition):
    bpm,lead,scale,melody=definition
    beat=60/bpm
    channels=[array("f",[0])*round(beat*32*RATE) for _ in range(2)]
    for bar in range(8):
        root=scale[(bar//2)%4]
        start=bar*4*beat
        for i,pitch in enumerate((root,root+7,root+12)):
            mix(channels,note("pad",pitch,round(beat*4.2,4)),start,.105,(i-1)*.5)
        steps=8 if name in ("battle","boss","police") else 4
        for step in range(steps):
            pitch=scale[(step+bar)%4]+12
            mix(channels,note("shamisen" if name=="battle" else "koto",pitch,1.1),
                start+step*beat*4/steps,.13,-.4)
        for step in range(4):
            pitch=melody[(bar*4+step)%len(melody)]
            if pitch:
                mix(channels,note(lead,pitch,round(beat*.92,4)),start+step*beat,.22,.22)
        mix(channels,note("bass",root-12,1.1),start,.18)
        if name in ("battle","boss","police"):
            for step in ((0,1.5,2,3.5) if name=="boss" else (0,2)):
                mix(channels,percussion("taiko"),start+step*beat,.36)
            for step in (1,3):
                mix(channels,percussion("rim"),start+step*beat,.14,.3)
            for step in range(8):
                mix(channels,percussion("shaker"),start+step*.5*beat,.13,.6)
        if name=="boss" and bar%2==0:
            mix(channels,percussion("gong"),start,.25,-.2)
        if name in ("title","map","result"):
            mix(channels,note("bell",scale[2]+24,1.8),start+beat*2.5,.09,.55)
    return encode(channels,True)


def effect(name,seconds):
    rng=random.Random(420+list(EFFECTS).index(name))
    channels=[array("f",[0])*round(seconds*RATE) for _ in range(2)]
    previous=0
    for i in range(len(channels[0])):
        time=i/RATE
        ratio=time/seconds
        noise=rng.uniform(-1,1)
        if name=="card":
            value=(noise-previous)*math.sin(math.pi*ratio)**2*.3
            value+=math.sin(TAU*960*time)*math.exp(-time*60)*.16
        elif name in ("attack","hit"):
            value=noise*math.exp(-((time-.055)/.035)**2)*.45
            hit=max(0,time-.07)
            value+=(math.sin(TAU*(110*hit-45*hit*hit))+.3*noise)*math.exp(-hit*16)
        elif name=="voice":
            phase=TAU*(157*time-37*time*time)
            value=sum(math.sin(phase*h)/h for h in (1,2,3,5))*.2
            value+=noise*.045
            value*=math.sin(math.pi*ratio)**2*(.8+.2*math.sin(TAU*6*time))
        elif name in ("transition","darkness"):
            value=(noise+previous)*.16*math.sin(math.pi*ratio)**2
            if name=="darkness":
                value+=math.sin(TAU*(78*time-23*time*time))*.4*math.sin(math.pi*ratio)
        else:
            value=0
        previous=noise
        channels[0][i]=value*.7
        channels[1][i]=value*.68
    if name in ("acquire","heal","victory"):
        pitches={"acquire":(74,77,81),"heal":(69,74,77),"victory":(62,69,74,77,81)}[name]
        for i,pitch in enumerate(pitches):
            mix(channels,note("bell",pitch,seconds-i*.14),i*.14,.25,(i%3-1)*.4)
    return encode(channels)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--out-dir",type=Path,default=ROOT)
    parser.add_argument("--print-spec",action="store_true")
    args=parser.parse_args()
    if args.print_spec:
        print(json.dumps({"rate":RATE,"images":[],"audio":[
            {"path":f"audio/{name}.wav","loop":name in MUSIC,"stereo":True}
            for name in [*MUSIC,*EFFECTS]]}))
        return
    dest=args.out_dir/"audio"
    dest.mkdir(parents=True,exist_ok=True)
    for name,definition in [*MUSIC.items(),*EFFECTS.items()]:
        data=music(name,definition) if name in MUSIC else effect(name,definition)
        path=dest/f"{name}.wav"
        if not path.exists() or path.read_bytes()!=data:
            path.write_bytes(data)
        print(f"音声生成: {name}",flush=True)


if __name__=="__main__":
    main()
