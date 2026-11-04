"""Egg Drop — Pocket Apricot. Original composition and procedural instruments.
No borrowed recordings or melodies. Run with Python + numpy + ffmpeg.
16 bars at 72 BPM, lightly swung, with an audition-only release tail.
"""
from pathlib import Path
import math, subprocess, wave
import numpy as np

ROOT=Path(__file__).resolve().parent
SR=44100
BPM=72
BEAT=60/BPM
LENGTH=16*4*BEAT
rng=np.random.default_rng(140926)
out=np.zeros((int((LENGTH+3)*SR),2),dtype=np.float64)

def hz(m): return 440*2**((m-69)/12)

def voice(note,duration,kind):
    t=np.arange(int(duration*SR))/SR
    f=hz(note)
    fade=np.minimum(1,np.maximum(0,(duration-t)/.045))
    if kind=='key':
        # Small felt-and-metal keyboard: a woody fundamental and bent tine.
        x=(np.sin(2*np.pi*f*t)*np.exp(-t/.57)
           +.23*np.sin(2*np.pi*f*2.002*t)*np.exp(-t/.18)
           +.065*np.sin(2*np.pi*f*3.99*t)*np.exp(-t/.075))
        x*=1-np.exp(-t/.004)
    elif kind=='bass':
        phase=2*np.pi*f*(t+.0009*(1-np.exp(-t/.025)))
        x=(np.sin(phase)+.22*np.sin(2*phase)+.06*np.sin(3*phase))
        x*=(1-np.exp(-t/.007))*np.exp(-t/.28)
    elif kind=='mouth':
        # Synthetic "bwop": pitch droop plus moving harmonic formants.
        phase=2*np.pi*f*(t+.006*(1-np.exp(-t/.023)))
        formant=3.4+2.4*np.exp(-t/.08)
        x=np.zeros_like(t)
        for harmonic in range(1,10):
            weight=np.exp(-((harmonic-formant)/1.4)**2)
            x+=weight*np.sin(harmonic*phase)/3
        x+=.48*np.sin(phase)
        x*=(1-np.exp(-t/.009))*np.exp(-t/.12)
    elif kind=='bottle':
        x=np.sin(2*np.pi*f*t+1.3*np.sin(2*np.pi*f*2.71*t)*np.exp(-t/.018))
        x*=(1-np.exp(-t/.003))*np.exp(-t/.18)
    elif kind=='wood':
        x=(np.sin(2*np.pi*f*t)+.5*np.sin(2*np.pi*f*1.72*t))*np.exp(-t/.023)
        x*=1-np.exp(-t/.0008)
    elif kind=='brush':
        noise=rng.normal(size=len(t))
        x=(noise-np.roll(noise,1))*.2*np.exp(-t/.035)*(1-np.exp(-t/.002))
    elif kind=='kick':
        phase=2*np.pi*(51*t+2.5*(1-np.exp(-t/.035)))
        x=np.sin(phase)*np.exp(-t/.09)*(1-np.exp(-t/.001))
    elif kind=='squeak':
        phase=2*np.pi*f*(t+.012*np.sin(2*np.pi*4*t))
        x=np.sin(phase+1.5*np.sin(2*phase))*.5*np.sin(np.pi*t/duration)**2
    else: raise ValueError(kind)
    return x*fade

def add(beat,note,dur,amp,pan=0,kind='key'):
    # Delay offbeat eighths: subtle 58% swing, no quantized machine-gun feel.
    if abs((beat%1)-.5)<.001: beat+=.08
    start=max(0,int((beat*BEAT+.025)*SR))
    x=voice(note,dur,kind)*amp
    n=min(len(x),len(out)-start)
    if n<=0:return
    angle=(pan+1)*np.pi/4
    out[start:start+n,0]+=x[:n]*np.cos(angle)
    out[start:start+n,1]+=x[:n]*np.sin(angle)

# F6/9, Dm9, Bbmaj9, C13; a contrasting Gm9 / C13 middle phrase.
chords=[(41,[57,60,62,67]),(38,[53,57,60,64]),
        (34,[53,57,60,62]),(36,[52,57,58,62]),
        (41,[57,60,62,67]),(38,[53,57,60,64]),
        (43,[53,57,58,62]),(36,[52,57,58,62]),
        (34,[53,57,60,62]),(45,[55,60,64,67]),
        (43,[53,57,58,62]),(36,[52,57,58,62]),
        (41,[57,60,62,67]),(38,[53,57,60,64]),
        (34,[53,57,60,62]),(41,[57,60,62,67])]

for bar,(root,notes) in enumerate(chords):
    b=bar*4
    sparse=bar in (3,7,11,15)
    # A gently loping bass; phrase endings have an extra breath.
    for off,pitch,vol in [(0,root,.19),(1.5,root+12,.095),(2.5,root+7,.125)]:
        if sparse and off==1.5:continue
        add(b+off,pitch,.62,vol,0,'bass')
    for off,vol in [(0,.047),(1.5,.035),(3,.033)]:
        if sparse and off==3:continue
        for j,n in enumerate(notes):
            add(b+off+j*.014,n,.85,vol*rng.uniform(.9,1.06),-.25+j*.09)
    # Quiet paper-brush pulse and wood-block conversation.
    for off in [0,2]:add(b+off,35,.24,.12,0,'kick')
    for off in [1,3]:
        add(b+off,82,.15,.12,.22,'brush')
        add(b+off,76 if bar%2 else 72,.13,.035,-.35,'wood')
    for off in [.5,2.5]:add(b+off,88,.1,.033,.4,'brush')
    if bar in (1,5,9,13):
        add(b+3.5,86,.16,.035,-.6,'wood')

# A singable asymmetric original theme; gaps let the odd timbres answer.
phrases={
 0:[(.5,69),(1,72),(2.5,74),(3,72)],
 1:[(.5,69),(2,65),(2.5,64)],
 2:[(0,65),(1.5,69),(2,72)],
 3:[(.5,67),(1,64)],
 4:[(.5,69),(1,72),(2.5,74),(3,77)],
 5:[(.5,76),(1.5,72),(2.5,69)],
 6:[(0,70),(1.5,69),(2.5,65)],
 7:[(.5,64),(1,67)],
 8:[(.5,72),(1.5,74),(2,77)],
 9:[(.5,76),(1,72),(2.5,67)],
 10:[(0,70),(1,69),(2,65)],
 11:[(.5,64),(1.5,62)],
 12:[(.5,69),(1,72),(2.5,74),(3,72)],
 13:[(.5,69),(1.5,65),(2.5,64)],
 14:[(0,65),(1.5,69),(2.5,67)],
 15:[(0,65)]}
for bar,phrase in phrases.items():
    for k,(off,note) in enumerate(phrase):
        # The middle eight switch to bottle tones then return to the keyboard.
        kind='bottle' if bar in (8,9,10) else 'key'
        add(bar*4+off,note,.9,.105*rng.uniform(.88,1.04),.15,kind)

# Deliberate call-and-response one-shots, made here instead of sampled.
for bar,note in [(1,57),(3,55),(5,60),(7,52),(9,60),(11,55),(13,57)]:
    add(bar*4+3,note,.3,.105,-.36,'mouth')
    if bar%4==3:add(bar*4+3.5,note+7,.24,.07,.32,'mouth')
for beat,note in [(11.5,77),(27.5,79),(43.5,74),(58.5,72)]:
    add(beat,note,.22,.028,.48,'squeak')
for beat in [14.5,30.5,46.5]:
    add(beat,84,.4,.04,-.48,'bottle')

# Small room, not a cloud of reverb. Crossfeed creates gentle stereo depth.
dry=out.copy()
for delay,gain in [(.071,.12),(.113,.09),(.181,.055),(.283,.026)]:
    n=int(delay*SR)
    out[n:]+=dry[:-n,::-1]*gain
out*=1.65
out*=.63/max(.63,np.max(np.abs(out)))
out[:int(.015*SR)]*=np.linspace(0,1,int(.015*SR))[:,None]
out[-SR:]*=np.linspace(1,0,SR)[:,None]

wav=ROOT/'egg_drop_pocket_apricot_quirky.wav'
mp3=ROOT/'egg_drop_pocket_apricot_quirky.mp3'
with wave.open(str(wav),'wb') as w:
    w.setnchannels(2);w.setsampwidth(2);w.setframerate(SR)
    w.writeframes((out*32767).astype('<i2').tobytes())
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(wav),
    '-codec:a','libmp3lame','-b:a','192k','-metadata',
    'title=Egg Drop - Pocket Apricot (quirky lounge draft)',str(mp3)],check=True)
print(mp3)
print(f'Duration {len(out)/SR:.2f}s; peak {20*np.log10(np.max(np.abs(out))):.2f} dBFS; RMS {20*np.log10(np.sqrt(np.mean(out**2))):.2f} dBFS')
