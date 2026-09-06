#!/usr/bin/env python3
"""独自の五音音階と撥弦・息・膜・金属の合成音を固定 seed で再生成する。"""

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

RATE = 22050
MUSIC = ("title", "map", "battle", "boss", "result_win", "result_loss")
SFX = ("card", "blade", "arrow", "drum", "hit", "reward")


@lru_cache(maxsize=384)
def instrument(kind, note, duration):
    frequency = 440 * 2 ** ((note-69)/12)
    rng = random.Random(192 + note)
    result = array("f")
    last_noise = 0
    for frame in range(round(duration*RATE)):
        time = frame/RATE
        phase = math.tau*frequency*time
        envelope = min(1, time/.004, (duration-time)/.035)
        noise = rng.uniform(-1,1)
        if kind == "pluck":
            value = sum(math.sin(phase*harmonic) * math.exp(-time*harmonic*3.5)
                        / harmonic for harmonic in range(1,8))
            value += (noise-last_noise)*math.exp(-time*95)*.14
        elif kind == "flute":
            phase += .029*math.sin(math.tau*4.7*time)
            value = (math.sin(phase)+.20*math.sin(phase*2)+.095*math.sin(phase*3))
            value *= min(1,time/.14)*(.88+.12*math.sin(math.pi*time/duration))
            value += noise*.035*min(1,time/.1)
        elif kind == "pad":
            value = (math.sin(phase)+.26*math.sin(phase*1.002)+.15*math.sin(phase*2))
            value *= min(1,time/.35,(duration-time)/.4)*.5
        elif kind == "bass":
            value = (math.sin(phase)+.25*math.sin(phase*2)+.09*math.sin(phase*3))
            value *= math.exp(-time*2.7)
        else:
            value = (math.sin(phase)*math.exp(-time*2.6)
                     +.43*math.sin(phase*2.71)*math.exp(-time*4)
                     +.20*math.sin(phase*5.31)*math.exp(-time*7))
        result.append(value*envelope)
        last_noise = noise
    return result


@lru_cache(maxsize=8)
def percussion(kind):
    duration = {"taiko":.72,"wood":.19,"gong":2.2}[kind]
    rng = random.Random({"taiko":940,"wood":944,"gong":955}[kind])
    result = array("f")
    for frame in range(round(duration*RATE)):
        time = frame/RATE
        noise = rng.uniform(-1,1)
        if kind == "taiko":
            phase = math.tau*(52*time + 76*(1-math.exp(-time*24))/24)
            value = (math.sin(phase) + .32*math.sin(phase*1.61))*math.exp(-time*7)
            value += noise*math.exp(-time*75)*.18
        elif kind == "wood":
            value = (.7*math.sin(math.tau*843*time)+.3*math.sin(math.tau*1381*time))
            value *= math.exp(-time*43)
            value += noise*math.exp(-time*90)*.15
        else:
            value = sum(math.sin(math.tau*78*ratio*time)/(index+1)
                        for index,ratio in enumerate((1,1.49,2.13,3.09,4.37,6.43)))
            value *= math.exp(-time*2.5)
        result.append(value*min(1,time/.003,(duration-time)/.035))
    return result


def mix(channels, values, start, gain, pan=0):
    """譜面の発音を一度ずつ加算するため、この内部関数は非冪等。"""
    offset = round(start*RATE)
    length = len(channels[0])
    weights = (gain*math.sqrt((1-pan)/2), gain*math.sqrt((1+pan)/2))
    for frame,value in enumerate(values):
        target = (offset+frame)%length
        for side in range(2):
            channels[side][target] += value*weights[side]


def encode(channels, loop=False):
    # 残響を先頭に折り返し、循環する音楽の末尾で残響を切断しない。
    length = len(channels[0])
    wet = [array("f",channel) for channel in channels]
    if loop:
        for delay,gain in ((.127,.12),(.283,.07),(.421,.035)):
            offset = round(delay*RATE)
            for side in range(2):
                for frame in range(length):
                    wet[side][frame] += channels[1-side][(frame-offset)%length]*gain
    peak = max(abs(value) for channel in wet for value in channel)
    gain = .82/max(peak,.01)
    pcm = array("h")
    for frame in range(length):
        edge = min(1, frame/(RATE*.006), (length-1-frame)/(RATE*.006))
        for side in range(2):
            pcm.append(round(wet[side][frame]*gain*edge*32767))
    if sys.byteorder != "little":
        pcm.byteswap()
    output = io.BytesIO()
    with wave.open(output,"wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm.tobytes())
    return output.getvalue()


def music(name, bpm, roots, melody, lead):
    beat = 60/bpm
    channels = [array("f",[0])*round(32*beat*RATE) for _ in range(2)]
    martial = name in ("battle","boss")
    for bar in range(8):
        root = roots[bar%len(roots)]
        start = bar*4*beat
        notes = (root,root+7,root+12)
        for index,note in enumerate(notes):
            mix(channels,instrument("pad",note,round(beat*4.2,4)),start,.08,(index-1)*.6)
        for step in range(8 if martial else 4):
            pitch = (root+12,root+19,root+24,root+19)[step%4]
            mix(channels,instrument("pluck",pitch,round(beat*1.25,4)),
                start+step*beat*(.5 if martial else 1),.19 if martial else .10,-.32)
        for step in range(4):
            note = melody[(bar*4+step)%len(melody)]
            if note:
                mix(channels,instrument(lead,note,round(beat*.95,4)),start+step*beat,.22,.24)
        for step in ((0,1.5,2,3.5) if name=="boss" else (0,2)):
            mix(channels,instrument("bass",root-12,round(beat*1.6,4)),start+step*beat,.19)
            if martial or name=="result_win":
                mix(channels,percussion("taiko"),start+step*beat,.38 if name=="boss" else .28)
        if martial:
            for step in (1,2.5,3):
                mix(channels,percussion("wood"),start+step*beat,.13,.55)
        if name=="boss" and bar%2==0:
            mix(channels,percussion("gong"),start,.18,-.2)
        if name in ("title","map","result_win"):
            mix(channels,instrument("bell",root+31,round(beat*2,4)),start+2.5*beat,.085,.65)
    return encode(channels,True)


def sfx(name):
    durations = {"card":.21,"blade":.55,"arrow":.43,"drum":.84,"hit":.6,"reward":1.1}
    duration = durations[name]
    channels = [array("f",[0])*round(duration*RATE) for _ in range(2)]
    rng = random.Random(501+SFX.index(name))
    last_noise = 0
    for frame in range(len(channels[0])):
        time = frame/RATE
        ratio = time/duration
        noise = rng.uniform(-1,1)
        if name=="card":
            value = (noise-last_noise)*math.sin(math.pi*ratio)**2*.38
            value += math.sin(math.tau*1084*time)*math.exp(-time*65)*.16
        elif name=="blade":
            value = noise*math.exp(-((time-.07)/.043)**2)*.42
            strike = max(0,time-.09)
            value += (math.sin(math.tau*841*strike)+.37*math.sin(math.tau*1367*strike))
            value *= math.exp(-strike*10)*min(1,time/.02)
        elif name=="arrow":
            phase = math.tau*(1720*time-1150*time*time)
            value = (math.sin(phase)*.3+(noise-last_noise)*.48)*math.sin(math.pi*ratio)**1.8
            value += math.sin(math.tau*204*time)*math.exp(-time*80)*.28
        elif name=="drum":
            phase = math.tau*(52*time+76*(1-math.exp(-time*24))/24)
            value = (math.sin(phase)+.36*math.sin(phase*1.6))*math.exp(-time*7)
            value += noise*math.exp(-time*85)*.15
        elif name=="hit":
            phase = math.tau*(134*time-66*time*time)
            value = (math.sin(phase)+noise*.44)*math.exp(-time*11)
            value += .2*math.sin(math.tau*619*time)*math.exp(-time*17)
        else:
            value = 0
            for index,note in enumerate((74,77,81,86)):
                local = time-index*.13
                if local>=0:
                    frequency=440*2**((note-69)/12)
                    value += (math.sin(math.tau*frequency*local)+.30*math.sin(math.tau*frequency*2.71*local))*math.exp(-local*5)*.35
        value *= min(1,time/.003,(duration-time)/.035)
        channels[0][frame] = value*math.sqrt(.58-ratio*.16)
        channels[1][frame] = value*math.sqrt(.42+ratio*.16)
        last_noise = noise
    return encode(channels)


def generate():
    arrangements = {
        "title":(76,(50,48,46,45),(74,0,77,81,79,77,74,0,72,74,77,0,69,0,72,74),"flute"),
        "map":(92,(50,55,48,50),(74,77,81,77,79,0,74,72,74,69,72,74,77,0,81,79),"pluck"),
        "battle":(128,(50,48,50,45),(74,74,81,77,72,77,79,77,74,81,86,81,81,77,74,72),"pluck"),
        "boss":(152,(38,39,38,45),(62,62,69,65,63,67,70,67,62,65,69,74,69,65,62,61),"pluck"),
        "result_win":(104,(50,55,57,50),(74,77,81,86,84,81,79,77,81,86,89,86,81,79,77,74),"flute"),
        "result_loss":(64,(50,46,43,45),(77,0,74,0,70,0,65,0,67,0,70,0,69,0,0,0),"bell"),
    }
    output = {f"audio/{name}.wav":music(name,*arrangements[name]) for name in MUSIC}
    output.update({f"audio/{name}.wav":sfx(name) for name in SFX})
    return output


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir",type=Path,default=Path(__file__).resolve().parents[2]/"assets")
    parser.add_argument("--print-spec",action="store_true")
    args=parser.parse_args()
    if args.print_spec:
        print(json.dumps({"rate":RATE,"images":[],"audio":[{"path":f"audio/{name}.wav","loop":name in MUSIC,"stereo":True} for name in MUSIC+SFX]}))
        return
    for name,data in generate().items():
        target=args.out_dir/name
        target.parent.mkdir(parents=True,exist_ok=True)
        if not target.exists() or target.read_bytes()!=data:
            target.write_bytes(data)
    print("独自 BGM 6 曲・効果音 6 点を生成しました（22050 Hz / 16 bit stereo PCM）。")


if __name__=="__main__":
    main()
