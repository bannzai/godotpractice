"""独自の旋律と倍音・撥弦・鐘・打楽器を固定シードで再生成する。"""
from pathlib import Path
import array
import math
import random
import wave

OUT = Path(__file__).resolve().parents[2] / 'assets/audio'
RATE = 22050
TAU = math.tau

def frequency(note): return 440 * 2 ** ((note - 69) / 12)

def instrument(note, duration, kind, strength=1):
    count=int(RATE*duration);hz=frequency(note);samples=array.array('f',[0])*count
    for i in range(count):
        t=i/RATE;p=TAU*hz*t
        attack=min(1,t/.018);release=min(1,(duration-t)/.08)
        if kind=='bell':
            value=(math.sin(p+1.8*math.sin(p*2)*math.exp(-t*5))*.6+math.sin(p*2.76)*.22*math.exp(-t*3)+math.sin(p*4.1)*.1*math.exp(-t*7))*math.exp(-t*2.4)
        elif kind=='pluck':
            value=(math.sin(p)+.42*math.sin(2*p)+.2*math.sin(3*p)+.08*math.sin(5*p))*math.exp(-t*5)*.55
        elif kind=='reed':
            value=(math.sin(p+.006*math.sin(t*TAU*5))+.3*math.sin(3*p)+.13*math.sin(5*p))*.55*min(1,t/.12)*math.exp(-t*.7)
        elif kind=='bass':
            value=(math.sin(p)+.32*math.sin(2*p)+.15*math.sin(3*p))*.6*math.exp(-t*2)
        else:
            value=(math.sin(p)+.28*math.sin(2*p)+.15*math.sin(4*p))*.48*min(1,t/.28)*math.exp(-t*.4)
        samples[i]=value*attack*release*strength
    return samples

def percussion(duration, kind, rng):
    samples=array.array('f',[0])*int(duration*RATE)
    for i in range(len(samples)):
        t=i/RATE
        if kind=='kick': value=math.sin(TAU*(48*t+9*(1-math.exp(-t*22))))*math.exp(-t*18)
        elif kind=='hat':value=rng.uniform(-1,1)*math.exp(-t*65)*.25
        else:value=(rng.uniform(-1,1)*.6+math.sin(TAU*170*t)*.2)*math.exp(-t*23)
        samples[i]=value*min(1,t/.003)
    return samples

def add(buf,samples,start,level=1):
    origin=int(start*RATE)
    for i,value in enumerate(samples):buf[(origin+i)%len(buf)]+=value*level

def save(name,buf,loop=True):
    # 短い左右別の反射音。BGM の残響は先頭へ折り返して連続させる。
    peak=max(.001,max(abs(v) for v in buf));gain=.62/peak
    stereo=array.array('h')
    delay_l=int(.173*RATE);delay_r=int(.229*RATE)
    for i,value in enumerate(buf):
        left=value+(buf[(i-delay_l)%len(buf)]*.19 if loop or i>=delay_l else 0)
        right=value+(buf[(i-delay_r)%len(buf)]*.19 if loop or i>=delay_r else 0)
        stereo.extend([int(max(-.98,min(.98,left*gain))*32767),int(max(-.98,min(.98,right*gain))*32767)])
    with wave.open(str(OUT/(name+'.wav')),'wb') as stream:
        stream.setnchannels(2);stream.setsampwidth(2);stream.setframerate(RATE);stream.writeframes(stereo.tobytes())

# 拍数・旋律・主楽器・調・低音と打楽器密度を場面ごとに変える。
tracks=[
('title',76,62,'bell',[0,7,10,14,12,7,5,3],.08),
('floor1',88,62,'pluck',[0,3,7,10,7,5,3,7],.15),
('floor2',82,59,'reed',[0,7,3,10,12,10,5,3],.12),
('floor3',98,57,'bell',[0,3,8,7,12,10,7,3],.21),
('floor4',104,55,'reed',[0,7,12,10,8,7,3,2],.27),
('floor5',112,50,'pluck',[0,1,7,8,12,8,7,1],.32),
('boss',132,50,'reed',[0,7,0,8,7,3,1,7],.46),
('result',72,62,'bell',[0,4,7,12,11,7,4,2],.025),
]
OUT.mkdir(parents=True,exist_ok=True)
for index,(name,bpm,root,tone,motif,drums) in enumerate(tracks):
    rng=random.Random(990+index);beat=60/bpm;length=beat*32;buf=array.array('f',[0])*round(length*RATE)
    progression=[0,-5,-2,-7] if name!='result' else [0,5,7,0]
    for bar in range(8):
        change=progression[(bar//2)%4]
        for interval in [0,7,10 if name!='result' else 11]:
            add(buf,instrument(root-12+change+interval,beat*4.2,'pad',.075),bar*4*beat)
        for step in range(4):
            note=root+motif[(bar*3+step)%8]+(12 if bar>=4 and step%2==0 else 0)
            add(buf,instrument(note,beat*1.7,tone,.23), (bar*4+step)*beat)
            add(buf,instrument(root-24+change+(7 if step==2 else 0),beat*.85,'bass',.18),(bar*4+step)*beat)
            add(buf,percussion(.17,'hat',rng),(bar*4+step+.5)*beat,drums)
            if step%2==0:add(buf,percussion(.28,'kick',rng),(bar*4+step)*beat,drums)
            elif index>=3:add(buf,percussion(.2,'snare',rng),(bar*4+step)*beat,drums*.6)
        if bar%2==1:add(buf,instrument(root+19,beat*2.4,'bell',.10),(bar*4+3.5)*beat)
    save(name,buf)
    print(name,round(length,2),'秒')

# 低い機械唸り、周期の違う水滴、活字端末の短いクリックを一つの環境層にする。
ambient_rng=random.Random(1205);ambient_length=12;ambient=array.array('f',[0])*int(ambient_length*RATE)
for i in range(len(ambient)):
    t=i/RATE
    hum=(math.sin(TAU*41*t)*.12+math.sin(TAU*57*t+.7)*.07)*(.75+.25*math.sin(TAU*t/7))
    hiss=ambient_rng.uniform(-1,1)*.014*(.5+.5*math.sin(TAU*t/5)**2)
    ambient[i]=hum+hiss
for moment,note in [(1.2,86),(3.8,79),(6.1,91),(9.4,83),(11.1,88)]:
    add(ambient,instrument(note,.48,'bell',.34),moment)
for moment in [0.4,2.7,5.2,7.8,10.3]:
    add(ambient,percussion(.045,'hat',ambient_rng),moment,.22)
save('ambience',ambient)
print('ambience',ambient_length,'秒')

rng=random.Random(231)
for name,notes,tone,dur in [
('hit',[43,62],'pluck',.25),('hurt',[54,42],'reed',.4),
('level',[62,66,69,74,81],'bell',1.1),('stairs',[74,69,65,62],'bell',.85),
('pickup',[74,81],'pluck',.4),('select',[81],'pluck',.16),
('death',[57,53,50,38],'reed',1.35)]:
    buf=array.array('f',[0])*int((dur+.35)*RATE)
    for j,note in enumerate(notes):add(buf,instrument(note,dur*.7,tone,.5),j*dur/len(notes))
    if name in ['hit','hurt']:add(buf,percussion(.19,'snare',rng),0,.45)
    save(name,buf,False)
    print(name,'効果音生成')
