"""Create original audio and original in-game horror overlay. Not needed to run game."""
import numpy as np
import soundfile as sf
from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path

root = Path(__file__).resolve().parent
snd = root / 'assets/audio'
ui = root / 'assets/ui'
snd.mkdir(parents=True, exist_ok=True)
ui.mkdir(parents=True, exist_ok=True)
SR = 22050
rng = np.random.default_rng(21027)

def write(name, samples, vol=0.75):
    sample = np.asarray(samples, dtype=np.float64)
    if sample.ndim == 1:
        sample = np.column_stack([sample * .93, np.roll(sample, 11) * .94])
    peak = np.max(np.abs(sample))
    if peak > 0:
        sample = sample / peak * vol
    sf.write(snd / name, sample.astype(np.float32), SR, format='OGG', subtype='VORBIS')

def note(freq, x, amp=.2, brightness=.14):
    return amp * (np.sin(2*np.pi*freq*x) + brightness*np.sin(2*np.pi*freq*2.007*x))

def echo(x, delay=.24, gain=.19, repeats=3):
    output = x.copy()
    shift = int(SR*delay)
    for i in range(1, repeats+1):
        output[shift*i:] += x[:-shift*i] * (gain**i)
    return output

# Original atmospheric electronic loop: do not copy any film, series, or commercial soundtrack.
length=48
n=SR*length
t=np.arange(n,dtype=np.float64)/SR
music=np.zeros(n,dtype=np.float64)
chords=[(110,138.59,164.81),(92.5,123.47,164.81),(82.41,123.47,146.83),(98,146.83,185)]
for part in range(4):
    start=part*12
    idx=np.arange(start*SR,(start+12)*SR)
    u=(idx-start*SR)/SR
    env=(.12+ .88*np.minimum(u/2.2,1))*np.minimum((12-u)/2.0,1)
    for tone in chords[part]:
        drift=np.sin(2*np.pi*.13*u)*.002
        phase=2*np.pi*tone*(u+drift)
        music[idx] += .043 *env*(np.sin(phase)+.2*np.sin(phase*2.005))
    music[idx] += .019*env*np.sin(2*np.pi*chords[part][0]/2*u)
# add original alternating minimal arp and reverberant metallic accents
arp_notes=[220.0,277.18,329.63,277.18,246.94,329.63,369.99,277.18]
for k in range(int(length/.72)):
    start = int(k*.72*SR)
    end=min(start+int(.48*SR),n)
    u=np.arange(end-start)/SR
    shape=(1-np.exp(-u*37))*np.exp(-u*6)
    music[start:end] += .015*shape*(np.sin(2*np.pi*arp_notes[k%len(arp_notes)]*u) +.25*np.sin(2*np.pi*arp_notes[k%len(arp_notes)]*2*u))
# irregular bass pulse, original sound-design, suspense rather than pop song
for k in range(64):
    pos=int(k*.75*SR)
    end=min(pos+int(.42*SR),n)
    u=np.arange(end-pos)/SR
    kick=.095*np.exp(-u*17)*np.sin(2*np.pi*(43+60*np.exp(-u*28))*u)
    music[pos:end]+=kick
    if k%4 == 2:
        noise=rng.normal(0,1,end-pos)
        music[pos:end]+=.010*noise*np.exp(-u*26)
# airy stereo width
music=echo(music,.31,.3,3)
left = music * (.88+0.11*np.sin(2*np.pi*.08*t))
right= np.roll(music, 250) * (.84+0.12*np.sin(2*np.pi*.072*t+1.3))
write('ambient.ogg',np.column_stack([left,right]),.72)

# Original dark techno tension / chase layer
n=32*SR
t=np.arange(n)/SR
beat=np.zeros(n)
for k in range(64):
    pos=int(k*.5*SR)
    if pos>=n: continue
    end=min(pos+int(.27*SR),n)
    u=np.arange(end-pos)/SR
    beat[pos:end]+=.24*np.sin(2*np.pi*(53+90*np.exp(-u*35))*u)*np.exp(-u*14)
    if k%2 == 1:
        beat[pos:end]+=.037*rng.standard_normal(end-pos)*np.exp(-u*30)
    if k%4 == 2:
        h_end=min(pos+int(.12*SR),n)
        u2=np.arange(h_end-pos)/SR
        beat[pos:h_end]+=.026*rng.standard_normal(h_end-pos)*np.exp(-u2*48)
for i in range(4):
    start=i*8*SR
    u=np.arange(8*SR)/SR
    root=[55,61.74,73.42,65.41][i]
    beat[start:start+8*SR]+=.035*np.sin(2*np.pi*root*u+0.02*np.sin(2*np.pi*3*u))
for k in range(128):
    pos=int(k*.25*SR)
    if pos>=n: break
    end=min(pos+int(.18*SR),n)
    u=np.arange(end-pos)/SR
    freq=[220,246.94,329.63,440,369.99,329.63,246.94,185][k%8]
    beat[pos:end]+=.029*(np.sin(2*np.pi*freq*u)+.38*np.sin(2*np.pi*freq*1.005*u))*np.exp(-u*11)
beat=echo(beat,.21,.22,3)
write('tension.ogg',beat,.72)

# 2.4s jump-scare stinger: original reversed scrape + sub hit
n=int(2.4*SR)
u=np.arange(n)/SR
noise=rng.standard_normal(n)
freq=140+630*(u/2.4)**2
phase=2*np.pi*np.cumsum(freq)/SR
sting=.21*np.sin(phase)*np.minimum(1,u*5)*np.exp(-u*.75)
sting+= .27*noise*(.1+.9*u/2.4)*np.exp(-u*.48)
sting+= .3*np.sin(2*np.pi*(47+90*np.exp(-u*13))*u)*np.exp(-u*3)
write('sting.ogg',sting,.8)

# short picked up evidence shimmer
u=np.arange(int(.73*SR))/SR
pickup=(.22*np.sin(2*np.pi*(660+380*u)*u)+.08*np.sin(2*np.pi*1320*u))*np.exp(-u*7)
write('pickup.ogg',pickup,.68)

# Stylized, original creepy face for < 1 second scare, no use of stock art.
W,H=750,720
im=Image.new('RGBA',(W,H),(2,3,8,0))
d=ImageDraw.Draw(im,'RGBA')
for j in range(180):
    x=int(rng.uniform(0,W)); y=int(rng.uniform(0,H))
    w=int(rng.uniform(20,320))
    d.rectangle((x,y,x+w,y+int(rng.uniform(1,7))),fill=(205,25,int(rng.integers(70,138)),int(rng.integers(15,95))))
d.ellipse((194,48,563,638), fill=(8,7,17,245),outline=(130,18,72,122),width=8)
d.polygon([(216,172),(287,126),(309,390),(249,552)],fill=(0,0,7,255))
d.polygon([(542,153),(471,115),(448,392),(500,578)],fill=(0,0,7,255))
for x in [294,457]:
    d.ellipse((x-62,254,x+55,303),fill=(105,5,33,205))
    d.ellipse((x-37,263,x+36,300),fill=(255,35,100,245))
    d.ellipse((x-14,264,x+14,295),fill=(249,242,237,255))
d.polygon([(375,304),(337,430),(394,430)],fill=(9,9,15,255))
d.arc((288,415,469,560),5,172,fill=(225,33,76,255),width=11)
for y in range(500,580,11):
    d.line((280,y,480,y-15),fill=(241,53,99,150),width=2)
im=im.filter(ImageFilter.GaussianBlur(radius=1.3))
im.save(ui/'glitch_face.png',optimize=True)
print('Generated original OGG audio and horror image.')
