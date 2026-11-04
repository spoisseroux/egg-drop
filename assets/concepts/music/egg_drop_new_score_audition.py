"""Two original quiet score sketches. No samples, MIDI files, or outside music.
00:00-00:52 A / Window Seat — 70 BPM, warm triangle-key miniature.
00:55-01:47 B / Paper Moon — unmetered, suspended bell/pulse soundscape.
Run: python egg_drop_new_score_audition.py (numpy and ffmpeg required).
"""
from pathlib import Path
import math, wave, subprocess
import numpy as np

SR = 44100
ROOT = Path(__file__).resolve().parent
rng = np.random.default_rng(94827)

def hz(m): return 440 * 2 ** ((m - 69) / 12)

def tone(m, dur, kind):
    t = np.arange(int(dur * SR)) / SR
    f = hz(m)
    if kind == 'key':
        # Rounded triangle fundamental, soft tine overtone, no piercing click.
        x = (np.sin(2*np.pi*f*t) + .105*np.sin(2*np.pi*3*f*t)
             + .024*np.sin(2*np.pi*5*f*t)) * np.exp(-t/1.12)
        x += .065*np.sin(2*np.pi*2.002*f*t)*np.exp(-t/.34)
        env = (1-np.exp(-t/.012)) * np.minimum(1, (dur-t)/.22)
    elif kind == 'bass':
        x = np.sin(2*np.pi*f*t) + .17*np.sin(2*np.pi*2*f*t)
        env = (1-np.exp(-t/.035))*np.exp(-t/.85)*np.minimum(1,(dur-t)/.2)
    elif kind == 'bell':
        x = (np.sin(2*np.pi*f*t)*np.exp(-t/2.7)
             + .13*np.sin(2*np.pi*2*f*t)*np.exp(-t/1.1)
             + .035*np.sin(2*np.pi*3.01*f*t)*np.exp(-t/.45))
        env = (1-np.exp(-t/.032))*np.minimum(1,(dur-t)/.5)
    elif kind == 'air':
        # Long, almost static low-harmonic pulse, with slow voice beating.
        x = (.72*np.sin(2*np.pi*f*t) + .20*np.sin(2*np.pi*f*1.0013*t)
             + .045*np.sin(2*np.pi*3*f*t))
        env = np.sin(np.pi*t/dur)**1.6
    return x * env

def add(buf, start, m, dur, amp, pan=0, kind='key'):
    x = tone(m,dur,kind)*amp
    pos=int(start*SR)
    n=min(len(x), len(buf)-pos)
    if n<=0:return
    angle=(pan+1)*math.pi/4
    buf[pos:pos+n,0] += x[:n]*math.cos(angle)
    buf[pos:pos+n,1] += x[:n]*math.sin(angle)

def room(buf, amount):
    wet = buf.copy()
    for delay, gain in [(.083,.19),(.137,.15),(.229,.12),(.347,.09),(.509,.055),(.733,.035)]:
        n=int(delay*SR)
        wet[n:] += buf[:-n,::-1]*gain*amount
    return wet

def finish(buf):
    # Gentle edge fades; retain natural dynamics, no loudness maximization.
    n=int(2*SR)
    buf[:n]*=np.linspace(0,1,n)[:,None]
    n=int(3*SR)
    buf[-n:]*=np.linspace(1,0,n)[:,None]
    return buf

def window_seat():
    out=np.zeros((52*SR,2))
    beat=60/70
    # Six changing two-bar voicings, shared inner tones, no ostinato melody.
    # Dmaj9, Bm9, Gmaj9, A13sus, F#m11, Em9 -> a soft D6/9 landing.
    harmony=[(38,[57,61,64,66]),(35,[57,61,62,66]),
             (31,[54,57,59,62]),(33,[55,59,62,66]),
             (30,[57,59,61,64]),(40,[55,59,62,66]),
             (38,[54,57,59,64])]
    for bar,(bass,notes) in enumerate(harmony):
        base=1.0+bar*8*beat
        add(out,base,bass,2.5,.075,0,'bass')
        # A little human spacing, enough silence to hear game events.
        offsets=[.08,3.35,6.0] if bar%2==0 else [.28,4.65]
        for k,off in enumerate(offsets):
            for j,note in enumerate(notes):
                add(out,base+off*beat+j*.018,note,2.7,
                    .026*(1 if k==0 else .68)*rng.uniform(.88,1.08),
                    (j-1.5)*.16)
        if bar in (0,2,3,5):
            add(out,base+4.7*beat,bass+12,1.7,.030,-.05,'bass')
    # Short, asymmetrical phrases with several-bar breaths.
    melody=[(3.15,73,.043),(4.0,71,.036),(6.45,69,.039),
            (11.25,66,.035),(12.9,69,.031),(14.0,73,.033),
            (21.4,71,.039),(23.55,69,.031),(25.0,66,.033),
            (31.7,68,.033),(33.1,66,.035),
            (41.2,66,.031),(42.65,64,.028),(47.4,66,.029)]
    for t,m,a in melody: add(out,t,m,3.2,a,.22,'key')
    return finish(room(out,.65))

def paper_moon():
    out=np.zeros((52*SR,2))
    # Gently interlocking open fifths and seconds, no drum grid or arpeggiator.
    # Centred on C lydian; low strings move slowly while bells leave room.
    beds=[(0,48,17,.028),(1.2,55,17,.021),(3.0,62,17,.016),
          (12,45,18,.025),(14,52,18,.021),(16,59,18,.016),
          (26,41,18,.025),(27,48,18,.021),(30,55,17,.017),
          (39,48,13,.024),(40,55,12,.019),(41,62,11,.015)]
    for t,m,d,a in beds:add(out,t,m,d,a,(-.25 if m%2 else .25),'air')
    bells=[(2.3,76,.040,-.35),(6.9,74,.031,.3),
           (10.2,69,.035,-.12),(15.6,71,.032,.38),
           (17.1,76,.025,-.27),(23.4,78,.031,.22),
           (28.8,76,.034,-.3),(32.7,71,.028,.36),
           (36.2,69,.032,-.15),(43.8,74,.029,.28),
           (47.3,76,.026,-.2)]
    for t,m,a,p in bells:
        add(out,t,m,4.5,a,p,'bell')
        # Barely audible octave-down response, not a rhythmic echo.
        if m in (76,69):add(out,t+1.34,m-12,4,.010,-p,'bell')
    return finish(room(out,1.4))

def main():
    a,b=window_seat(),paper_moon()
    audio=np.concatenate([a,np.zeros((3*SR,2)),b])
    # This is an intentionally quiet mix: peak below -15 dBFS.
    peak=np.max(np.abs(audio))
    audio*=min(1,.17/peak)
    wav=ROOT/'egg_drop_new_score_audition.wav'
    mp3=ROOT/'egg_drop_new_score_audition.mp3'
    with wave.open(str(wav),'wb') as w:
        w.setnchannels(2);w.setsampwidth(2);w.setframerate(SR)
        w.writeframes((audio*32767).astype('<i2').tobytes())
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(wav),
        '-codec:a','libmp3lame','-b:a','192k','-metadata',
        'title=Egg Drop — Window Seat (0:00) / Paper Moon (0:55)',str(mp3)],check=True)
    print(mp3)
    print(f'Duration {len(audio)/SR:.1f}s; peak {20*np.log10(np.max(np.abs(audio))):.1f} dBFS; RMS {20*np.log10(np.sqrt(np.mean(audio**2))):.1f} dBFS')

if __name__=='__main__':main()
