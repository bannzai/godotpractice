"""灯守りの深層の独自 SVG 素材を決定的に再生成する。"""
from pathlib import Path
import random
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen

ROOT = Path(__file__).resolve().parents[2] / 'assets'
DEFS = '''<defs>
<linearGradient id="cloth" x2="0.8" y2="1"><stop stop-color="#59a6a4"/><stop offset=".45" stop-color="#245963"/><stop offset="1" stop-color="#112637"/></linearGradient>
<linearGradient id="gold" x2=".7" y2="1"><stop stop-color="#fff0ac"/><stop offset=".45" stop-color="#d8a454"/><stop offset="1" stop-color="#755333"/></linearGradient>
<linearGradient id="stone" x2=".8" y2="1"><stop stop-color="#607e82"/><stop offset=".5" stop-color="#304955"/><stop offset="1" stop-color="#142633"/></linearGradient>
<linearGradient id="bone" x2=".7" y2="1"><stop stop-color="#eee5bd"/><stop offset="1" stop-color="#7c8c86"/></linearGradient>
<radialGradient id="glow"><stop stop-color="#ffe299" stop-opacity=".7"/><stop offset=".3" stop-color="#c89950" stop-opacity=".2"/><stop offset="1" stop-color="#be8d47" stop-opacity="0"/></radialGradient>
</defs>'''

def save(name, body, w=96, h=96):
    path = ROOT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{DEFS}{body}</svg>\n')

def path(d, fill, stroke='#101c28', sw=2):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round" stroke-linecap="round"/>'

def ellipse(x,y,rx,ry,fill,stroke='none',sw=1):
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'

def line(d,c='#e3bd71',sw=1): return path(d,'none',c,sw)
def shadow(): return ellipse(48,84,27,7,'#050f1c',sw=0)
def gem(x,y,s=5,c='#9febd6'): return path(f'M{x} {y-s}l{s} {s} -{s} {s} -{s} -{s}Z',c,'#183c43',1)

hero = shadow()+path('M35 58L31 83 41 83 49 62 53 83 65 83 59 56','url(#stone)')
hero += path('M31 30Q17 49 19 77L31 72 41 82 59 76 72 81Q69 51 59 30Z','url(#cloth)')
hero += path('M29 38L25 70 35 65M58 38L64 72 55 69','none','#83b9ab',1)
hero += path('M34 30L34 59Q47 67 60 58L59 30','url(#stone)')+path('M33 51L60 51 61 58 33 58','url(#gold)')
hero += path('M31 33Q27 11 45 8 64 6 66 33L58 43 37 42Z','url(#cloth)')
hero += path('M34 27Q45 17 60 28L57 39 38 39Z','#0b1b29')+line('M39 30L43 30M51 30L55 30','#f7dc94',2)
hero += path('M34 36L58 36 56 44 40 43Z','#bf8a50')+gem(46,49,4)
hero += path('M62 46L75 52 80 47 70 41','url(#bone)')+path('M22 45L17 58 24 61 32 48','url(#cloth)')
hero += line('M20 54L14 79','#e5d9a2',4)+path('M12 66L22 70','none','#b39150',3)
hero += ellipse(79,63,17,22,'url(#glow)')+path('M73 52L85 52 87 71 72 71Z','url(#gold)')+path('M75 54L83 54 84 67 74 67Z','#674530',sw=1)
hero += path('M78 65Q74 60 80 56Q78 61 82 62L80 66Z','#fff2bd','none')+line('M76 50Q78 43 82 50','#dfb767',2)
save('characters/hero.svg',hero)

body=shadow()
for side in [-1,1]:
    for y in [42,54,65]: body+=line(f'M{48+side*16} {y}L{48+side*31} {y-4} {48+side*37} {y+7}','#88a79c',3)
body+=ellipse(48,54,23,29,'url(#cloth)','#14232b',2)+path('M48 27L48 82','none','#d8b874',2)
body+=path('M45 28Q34 9 31 20L38 33M52 28Q62 9 66 20L58 33','url(#gold)')+ellipse(48,34,15,13,'url(#stone)','#172c33',2)
body+=ellipse(40,32,3,3,'#ffba6c')+ellipse(56,32,3,3,'#ffba6c')
body+=line('M29 49Q37 37 44 43M52 43Q64 38 68 50M30 60Q39 48 44 56M52 56Q65 49 68 61','#699c93',2)
body+=gem(39,67,3)+gem(57,67,3)
save('characters/chaser.svg',body)

body=shadow()+path('M40 58L34 76 29 82 40 83 48 62M53 59L60 76 68 81 57 83 49 67','url(#bone)')
body+=path('M36 39L29 58 21 52M59 40L70 50 78 42','none','#c6c7a4',5)+path('M39 38L37 61 58 61 55 38','url(#stone)')
for y in [43,49,55]: body+=line(f'M40 {y}Q48 {y+7} 56 {y}','#d8d5af',3)
body+=path('M34 17Q48 5 62 20L59 35 52 43 41 41 34 33Z','url(#bone)')+path('M34 18L29 25 32 12 49 7 65 17 61 24','url(#cloth)')
body+=ellipse(40,27,5,5,'#1a3038')+ellipse(55,27,5,5,'#1a3038')+line('M39 27L42 27M54 27L57 27','#f8c785',2)+path('M48 29L44 35 50 35','#30414b',sw=1)
body+=line('M41 39L55 39M45 37L45 42M50 37L50 42','#405253')
body+=path('M78 20Q96 48 76 80','none','#d2a461',4)+line('M78 20L76 80','#a2c8b9')+line('M63 48L88 48','#e5d7a5',2)+path('M89 48L83 44 83 52Z','#ded2ab',sw=1)
save('characters/archer.svg',body)

body=shadow()+path('M17 74Q11 57 28 50 23 30 39 25 46 12 59 30 78 29 74 48 91 57 82 75 58 89 17 74Z','url(#cloth)')
body+=path('M20 65Q26 48 35 52Q32 28 46 30Q57 24 61 43Q83 43 77 64Q64 76 54 64Q43 80 20 65','#69ae97','#246264',1)
for x,y,s in [(25,59,5),(44,40,7),(62,56,6),(51,68,3),(33,72,3),(69,37,4)]:
    body+=ellipse(x,y,s,s,'#afc97c','#619887',1)+ellipse(x-1,y-2,s*.35,s*.3,'#f1deb0')
body+=ellipse(42,56,3,4,'#112d38')+ellipse(54,55,3,4,'#112d38')+line('M44 64Q48 67 52 63','#264855',2)
save('characters/splitter.svg',body)

body=shadow()+path('M29 67L25 85 43 85 48 71 53 85 73 85 67 66','url(#stone)')
body+=path('M26 40L18 67 31 73 37 54 60 54 66 74 80 68 71 40','url(#stone)')
body+=path('M32 36L24 64 37 74 63 74 74 64 64 36Z','url(#stone)')+path('M34 38L39 62 59 62 64 38','none','#72908c',2)
body+=path('M31 16L47 9 64 17 67 38 57 45 36 41 29 32Z','url(#stone)')+path('M30 16L47 11 65 19 60 24 35 21Z','#76938d')
body+=line('M35 29L43 30M53 30L61 28','#d4b478',3)+path('M46 24L44 38 52 38','none','#122b3b',2)
body+=path('M32 15L34 5 45 12M55 12L65 5 63 19','url(#gold)')+gem(49,53,7,'#dfb879')+line('M31 58L42 67 37 73M62 45L56 52 61 62','#112b39',2)
body+=ellipse(21,35,3,2,'#bbd394')+ellipse(72,31,4,2,'#bbd394')
save('characters/sleeper.svg',body)

body=shadow()+path('M44 42Q20 8 9 22L14 46 35 54Q9 51 15 77 32 80 44 59M52 42Q76 8 87 22L82 46 61 54Q87 51 81 77 64 80 52 59','url(#cloth)')
for side in [-1,1]:
    body+=path(f'M{48+side*8} 43L{48+side*33} 27 {48+side*22} 46Z','url(#gold)')
    body+=ellipse(48+side*22,37,5,6,'#102d3c')+ellipse(48+side*22,37,2,3,'#e4c786')
    body+=line(f'M{48+side*7} 57L{48+side*24} 68 {48+side*23} 58','#c5ad77',2)
body+=ellipse(48,51,7,23,'url(#gold)','#18313b',2)+ellipse(48,31,9,9,'url(#stone)','#17303a',2)
body+=line('M43 25Q35 10 30 15M53 25Q61 10 66 15','#d5bb80',2)+ellipse(44,30,2,3,'#e3f0bf')+ellipse(52,30,2,3,'#e3f0bf')
save('characters/swift.svg',body)

body=shadow()+path('M29 55L17 86 38 86 49 65 57 86 82 86 68 52','url(#stone)')
body+=path('M20 33L8 60 21 67 36 45 59 45 77 70 90 60 75 31','url(#stone)')
body+=path('M28 27L17 56 27 76 69 76 82 58 69 25Z','url(#stone)')+path('M26 31L40 43 37 69 25 57M69 31L56 43 59 69 71 57','url(#gold)')
body+=path('M31 23Q14 17 16 4L32 13 41 20M62 22Q83 17 82 4L65 12 55 19','url(#gold)')
body+=path('M32 19L48 12 65 21 61 39 50 46 36 37Z','url(#stone)')+line('M36 28L44 31M54 31L61 28','#ffd992',3)
body+=ellipse(48,55,25,29,'url(#glow)')+path('M40 38L57 38 61 68 36 68Z','#242d31')+path('M40 40L56 40 58 65 39 65Z','none','#cc9c55',3)
body+=path('M45 63Q35 53 47 44Q44 51 52 51Q60 59 50 66Z','#edb967','none')+path('M45 62Q43 54 49 52Q54 58 50 63Z','#fff4b7','none')
body+=line('M22 45L29 40M71 40L78 47M27 79L35 79M63 79L73 79','#7eaaa1',2)
save('characters/boss.svg',body)

items={
'weapon': path('M17 50L23 57 49 21 49 9 39 16Z','url(#bone)')+line('M19 39L33 49','#d2a15b',5)+line('M21 47L13 57','#4a8583',6),
'shield':path('M12 14L32 6 52 14 48 42Q42 53 32 59 18 50 15 39Z','url(#gold)')+path('M18 19L32 13 46 19 43 39 32 50 22 39Z','url(#cloth)')+gem(32,29,8),
'herb':line('M29 57Q32 27 44 12','#a4bc6e',4)+path('M32 40Q9 45 10 20 32 22 32 40M35 30Q38 8 58 13 53 32 35 30M30 51Q42 36 55 41 52 57 30 51','url(#cloth)')+line('M32 40L16 27M35 30L52 18','#c4d788'),
'food':path('M12 36Q16 8 32 8 46 9 55 39L48 54 18 54Z','url(#gold)')+path('M16 33Q24 17 31 16M34 16L45 34','none','#f6e5b2',3)+path('M11 39L54 39 49 57 17 57Z','url(#cloth)')+line('M20 46L47 46','#6b9e8b',2),
'wand':line('M15 56L43 20','#96774f',7)+line('M19 49L39 22','#dcc586',2)+path('M34 19L35 7 50 5 56 18 47 29Z','url(#gold)')+gem(45,16,7),
'stairs':path('M7 8L57 8 57 58 7 58Z','#101e2a')+path('M12 16L51 16 51 25 18 25 18 33 45 33 45 41 25 41 25 49 39 49','none','#8da79a',5)+line('M30 13L50 13','#d6bb79',2),
'coin':ellipse(32,34,19,23,'url(#gold)','#78573a',2)+ellipse(32,32,14,17,'none','#fae2a0',2)+gem(32,32,9,'#8d633b'),
}
# 強化装備は色だけでなく、二股刃・放射状の鍔・大型菱形の輪郭で見分ける。
items['sunblade'] = path('M18 42L38 10 49 5 44 19 56 11 52 26 28 48Z','url(#gold)')
items['sunblade'] += path('M25 38L44 16 39 29 49 23 31 43Z','#fff0ba','#b88243',1)
items['sunblade'] += path('M18 34L24 35 29 31 30 39 37 42 30 46 28 53 22 49 15 50 16 43 11 38Z','url(#gold)')
items['sunblade'] += ellipse(24,42,7,7,'#bf8a43','#fff0ae',1)+gem(24,42,4,'#fff0b3')
items['sunblade'] += line('M19 49L12 58','#947041',6)+line('M18 50L14 55','#f0d48b',2)
items['sunblade'] += path('M8 55L14 52 18 58 12 62Z','url(#gold)',sw=1)
items['ironshield'] = path('M32 3L59 25 48 46 32 62 16 46 5 25Z','url(#stone)')
items['ironshield'] += path('M32 8L53 26 44 43 32 55 20 43 11 26Z','url(#bone)')
items['ironshield'] += path('M32 14L46 27 40 40 32 48 24 40 18 27Z','url(#stone)')
items['ironshield'] += line('M32 13V49M17 27H47','#889e98',3)+gem(32,28,8,'#caac71')
for x,y in [(32,9),(11,25),(53,25),(20,43),(44,43),(32,55)]:
    items['ironshield'] += ellipse(x,y,2,2,'#f1d799','#40535a',.7)
items['ironshield'] += line('M41 17L37 22M19 31L23 36','#e1d1a4',1)
for key,col in [('scroll_fire','#e9ad6d'),('scroll_warp','#8bd8cb')]:
    items[key]=path('M20 11L49 11 44 51 15 51Z','url(#bone)')+path('M17 9Q7 9 10 19L23 19Q18 9 27 9M16 46Q25 46 22 56L47 56Q54 48 46 46Z','url(#gold)')+gem(32,32,9,col)+line('M29 19L41 19M23 43L38 43','#7c8c7f')
for key,body in items.items(): save('items/'+key+'.svg',ellipse(32,56,22,5,'#081523')+body,64,64)

rng=random.Random(714)
body=path('M0 0H64V64H0Z','#223942','none')
for x,y,w,h in [(2,2,29,28),(33,2,29,28),(2,33,19,28),(23,33,39,28)]:
    body+=path(f'M{x+2} {y}H{x+w-1}L{x+w} {y+h-2} {x+w-2} {y+h}H{x}V{y+2}Z',rng.choice(['#2b454b','#2e484d','#314b4f']),'#1b313b',1)
    body+=line(f'M{x+2} {y+2}H{x+w-3}', '#425b5b')
for _ in range(23):
    x,y=rng.randrange(64),rng.randrange(64);body+=ellipse(x,y,1,.6,'#536964')
save('tiles/floor.svg',body,64,64)
body=path('M0 0H64V64H0Z','#12232e','none')
for row in range(3):
    for x in range(-32 if row%2 else 0,64,32):
        y=row*20;body+=path(f'M{x+1} {y+1}H{x+30}V{y+18}H{x+1}Z','url(#stone)','#101f2c',2)+line(f'M{x+3} {y+3}H{x+28}','#69807c')
body+=path('M0 60H64V64H0Z','#091725','none')+line('M40 21L35 30 42 38M13 43L20 49 18 57','#172c36',2)
save('tiles/wall.svg',body,64,64)

# 奥・中・手前の独立レイヤー。左半分はタイトルと操作のため余白を残す。
body='<defs><linearGradient id="night" x2=".6" y2="1"><stop stop-color="#071321"/><stop offset=".65" stop-color="#173e47"/><stop offset="1" stop-color="#071322"/></linearGradient></defs>'
body+=path('M0 0H1280V720H0Z','url(#night)','none')
body+=ellipse(912,328,450,440,'url(#glow)')
for i in range(60):
    x,y=rng.randrange(1280),rng.randrange(600)
    body+=ellipse(x,y,rng.choice([.7,1,1.4]),rng.choice([.7,1,1.4]),'#9ebca2' if i%3 else '#d7b577')
for x in [600,735,870,1005,1140]:
    body+=path(f'M{x} 590V230Q{x} 175 {x+45} 145Q{x+90} 175 {x+90} 230V590Z','#112c38','#31545a',2)
    body+=path(f'M{x+19} 540V247Q{x+19} 207 {x+45} 187Q{x+71} 207 {x+71} 247V540Z','#0b202e','none')
body+=path('M0 605Q350 525 690 575T1280 560V720H0Z','#0b202d','none')
save('backgrounds/title_back.svg',body,1280,720)
body=''
for x in [618,1174]:
    body+=path(f'M{x} 0H{x+66}V585L{x+84} 628H{x-18}L{x} 585Z','url(#stone)','#112631',3)
    body+=line(f'M{x+14} 12V570M{x+51} 12V570','#466664',3)
    for y in range(60,570,70):body+=line(f'M{x} {y}H{x+65}','#0c2530',3)
    body+=path(f'M{x-17} 0H{x+83}V29H{x-17}Z','url(#gold)')
body+=path('M657 126Q901 -56 1192 126','none','#51716b',14)+path('M671 132Q912 -20 1170 132','none','#b09a61',3)
for i in range(9):
    y=502+i*20;inset=i*24
    body+=path(f'M{798-inset} {y}H{1006+inset}L{1027+inset} {y+20}H{777-inset}Z','#263d43','#52615a',1)
body+=ellipse(901,492,150,48,'url(#glow)')+path('M835 291L835 462H960V291Q897 205 835 291Z','#081a28','#5a817b',6)
body+=path('M851 291V456H943V291Q897 233 851 291Z','#1c494d','#b99e63',2)+ellipse(899,369,90,135,'url(#glow)')
body+=path('M894 270L902 270 902 449 894 449Z','#dbb36c','none')
for x in [745,1066]:
    body+=path(f'M{x-13} 382H{x+13}L{x+6} 411V475H{x-6}V411Z','url(#stone)')+ellipse(x,364,54,68,'url(#glow)')
    body+=path(f'M{x-8} 383Q{x-25} 361 {x+2} 337Q{x-5} 357 {x+10} 362Q{x+20} 375 {x+5} 385Z','#e2b467','none')
save('backgrounds/title_middle.svg',body,1280,720)
body=path('M0 678L160 650 341 699 440 677 584 717 751 653 948 683 1101 638 1280 664V720H0Z','#06121d','none')
body+='<g transform="translate(866 409) scale(2.85)">'+hero+'</g>'
for x in [25,85,1210,1250]:
    body+=path(f'M{x} 0Q{x+80} 145 {x+8} 360Q{x-45} 491 {x+15} 720','none','#07141e',13)
for x,y in [(722,593),(1150,581),(580,669),(1057,651)]:
    body+=path(f'M{x} {y}l-13 -30 5 -21 17 36 11 -18 9 30 -15 5Z','url(#stone)',sw=2)
save('backgrounds/title_front.svg',body,1280,720)

# フォントを輪郭にして SVG 内の文字依存をなくす。フォントは OFL のまま同梱する。
font=TTFont(ROOT/'fonts/NotoSansJP.ttf');glyphs=font.getGlyphSet();cmap=font.getBestCmap()
text='灯守りの深層';body='';x=45;scale=.09
for c in text:
    pen=SVGPathPen(glyphs);g=glyphs[cmap[ord(c)]];g.draw(pen)
    body+=f'<path d="{pen.getCommands()}" transform="translate({x} 116) scale({scale} {-scale})" fill="url(#gold)"/>'
    x+=g.width*scale+6
body+=line('M44 145H598','#7e927f',1)+gem(325,145,6,'#d8bd7d')
save('ui/logo.svg',body,680,180)
body=line('M0 32H216M296 32H512','#7c927e')+path('M227 32L256 9 285 32 256 55Z','none','#ceac6f',2)+gem(256,32,9)
save('ui/ornament.svg',body,512,64)
print('画像素材 25 点を生成しました')
