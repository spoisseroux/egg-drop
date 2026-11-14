"""Little Afternoon: Astra's original score, two local synthesized arrangements.

Only writes artifacts/qa-2026-11-14-v634/audio. No manifests, IDs or uploads.
"""
from pathlib import Path
import hashlib
import json
import math
import re
import subprocess
import wave
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "artifacts/qa-2026-11-14-v634/audio/revision-104bpm"
SR, BPM, BEAT = 48000, 104, 60 / 104
SECONDS = 32 * 4 * BEAT
N = round(SR * SECONDS)
# Each row is four beats; the exact principal melody repeats without alteration.
MELODY = [
    "r:.5 A4:.5 C5:1 D5:.5 C5:.5 A4:1",
    "F5:1.5 E5:.5 D5:1 r:1",
    "Bb4:.5 D5:.5 A5:1 G5:.5 F5:.5 D5:1",
    "E5:1 D5:.5 C5:.5 G4:1 r:1",
    "D5:1 F5:.5 E5:.5 D5:1 A4:1",
    "C5:.5 A4:.5 G4:1 A4:.5 C5:.5 F5:1",
    "D5:1.5 Bb4:.5 A4:.5 G4:.5 r:1",
    "G4:.5 C5:.5 D5:1 E5:1 r:1",
    "A4:.5 D5:1 F5:.5 E5:.5 D5:.5 C5:1",
    "E5:1 C5:1 B4:.5 C5:.5 A4:1",
    "F5:.5 D5:.5 C5:.5 D5:.5 G5:1 F5:1",
    "E5:1.5 D5:.5 G4:1 r:1",
    "Bb4:.5 D5:.5 F5:1 D5:.5 Bb4:.5 A4:1",
    "G4:1 E5:.5 D5:.5 C5:1 Bb4:1",
    "A4:.5 C5:.5 D5:1 C5:.5 A4:.5 G4:1",
    "G4:1 C5:1 r:2",
]
HARMONY = ["F6/9", "Dm7", "Gm9", "C6/9", "Bbmaj7", "F/A", "Gm7", "C7sus>C7",
           "Dm9", "Am7", "Bb6", "Cadd9", "Gm7", "C7", "F6", "C7sus"]
VOICES = {
    "F6/9":"F3 A3 C4 D4 G4", "Dm7":"D3 A3 C4 F4", "Gm9":"G3 Bb3 D4 F4 A4",
    "C6/9":"C3 G3 A3 D4 E4", "Bbmaj7":"Bb2 F3 A3 D4", "F/A":"A2 F3 A3 C4",
    "Gm7":"G2 F3 Bb3 D4", "C7sus":"C3 G3 Bb3 F4", "C7":"C3 G3 Bb3 E4",
    "Dm9":"D3 A3 C4 E4 F4", "Am7":"A2 G3 C4 E4", "Bb6":"Bb2 F3 G3 D4",
    "Cadd9":"C3 G3 D4 E4", "F6":"F3 A3 C4 D4",
}
PITCH = {"C":0,"D":2,"E":4,"F":5,"G":7,"A":9,"B":11}


def hz(note):
    m = re.fullmatch(r"([A-G])([b#]?)(\d)", note)
    assert m, note
    midi = 12*(int(m[3])+1)+PITCH[m[1]]+({"b":-1,"#":1,"":0}[m[2]])
    return 440 * 2 ** ((midi-69)/12)


def envelope(t, duration, attack=.008, release=.05):
    a = .5-.5*np.cos(np.pi*np.clip(t/attack, 0, 1))
    r = .5-.5*np.cos(np.pi*np.clip((duration-t)/release, 0, 1))
    return a*r


def triangle(f, t):
    y = np.zeros_like(t)
    for k in range(min(18, int(5000/f))):
        n = 2*k+1
        if n*f>5000: break
        y += ((-1)**k) * np.sin(2*np.pi*n*f*t)/(n*n)
    return y*(8/np.pi**2)


def pulse(f, t):
    y = np.zeros_like(t)
    for k in range(1, min(30, int(5000/f))+1):
        y += 2*np.sin(np.pi*k*.25)/(np.pi*k)*np.cos(2*np.pi*k*(f*t-.125))
    return y


def filtered_noise(count, rng, low=700, high=4500):
    x = rng.normal(0, .35, count)
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(count, 1/SR)
    spec *= (1-np.exp(-(f/max(1,low))**4))*np.exp(-(f/high)**4)
    return np.fft.irfft(spec, n=count)


def voice(note, duration, kind, rng):
    # No discontinuous source waveforms: pulse/triangle are additive band limited.
    f = hz(note)
    tail = .45 if kind in {"mallet","pluck","bell","wood"} else .10
    total = duration+tail
    t = np.arange(round(total*SR))/SR
    if kind == "mallet":
        decay = min(.45, max(.18, duration*.50))
        y = (np.sin(2*np.pi*f*t)*np.exp(-t/decay)+.20*np.sin(4*np.pi*f*t)*np.exp(-t/(decay*.65))+
             .08*np.sin(6*np.pi*f*t)*np.exp(-t/(decay*.45)))
        return y*envelope(t,total,.008,.10)
    if kind == "wood":
        decay = min(.30,max(.18,duration*.65))
        y = np.sin(2*np.pi*f*t)+10**(-14/20)*np.sin(4*np.pi*f*t)+10**(-22/20)*np.sin(6*np.pi*f*t)
        # Exact three partials, then 4 kHz spectral low pass.
        spectrum=np.fft.rfft(y*np.exp(-t/decay)*envelope(t,total,.008,.06))
        spectrum*=np.exp(-(np.fft.rfftfreq(len(t),1/SR)/4000)**8)
        return np.fft.irfft(spectrum,n=len(t))
    if kind in {"reed","reed-scoop","deck-reed","deck-scoop"}:
        scoop=kind.endswith("scoop")
        bend=-2*(1-np.clip(t/.060,0,1)) if scoop else np.zeros_like(t)
        phase=2*np.pi*np.cumsum(f*2**(bend/12))/SR
        if kind.startswith("deck"):
            y=np.sin(phase)+.15*np.sin(phase*3)+.05*np.sin(phase*5)
        else:y=np.sin(phase)+.28*np.sin(phase*2)+.12*np.sin(phase*3)+.05*np.sin(phase*5)
        return y*envelope(t,total,.012,.055)*np.exp(-t/.20)
    if kind == "flute":
        vibrato = .0018*np.sin(2*np.pi*3.5*t)*np.clip((t-.24)/.22,0,1)
        phase = 2*np.pi*f*np.cumsum(1+vibrato)/SR
        y = np.sin(phase)+.10*np.sin(phase*2)+filtered_noise(len(t),rng,550,3800)*.055
        return y*envelope(t,total,.035,.080)
    if kind in {"pluck","bell"}:
        y = (np.sin(2*np.pi*f*t)+.22*np.sin(4*np.pi*f*t)*np.exp(-t/.10)+
             .08*np.sin(6*np.pi*f*t)*np.exp(-t/.07))
        return y*np.exp(-t/(.42 if kind=="pluck"else .52))*envelope(t,total,.008,.10)
    if kind == "deck":
        return (.35*pulse(f,t)+.65*triangle(f,t))*envelope(t,total,.006,.045)*np.exp(-t/1.1)
    if kind == "bass":
        return (.72*np.sin(2*np.pi*f*t)+.28*triangle(f,t))*envelope(t,total,.012,.065)*np.exp(-t/.19)
    if kind == "chipbass":
        return triangle(f,t)*envelope(t,total,.008,.035)*np.exp(-t/.14)
    if kind == "pad":
        y = .66*np.sin(2*np.pi*f*t)+.22*np.sin(2*np.pi*f*1.0014*t)+.12*np.sin(4*np.pi*f*t)
        return y*envelope(t,total,.4,.45)
    raise ValueError(kind)


def add_wrapped(out, seconds, sound, gain, pan=0):
    assert -.2 <= pan <= .2
    at = int(round(seconds*SR)) % N
    # Equal-power stereo; centered sources preserve phone mono.
    gains = (math.cos((pan+1)*np.pi/4),math.sin((pan+1)*np.pi/4))
    for channel in range(2):
        sig = (sound*gain*gains[channel]).astype(np.float32)
        first = min(len(sig), N-at)
        out[at:at+first,channel] += sig[:first]
        if first < len(sig): out[:len(sig)-first,channel] += sig[first:]


ANSWERS={2:[("A4",.25),("G4",.25),("F4",.5)],4:[("D5",.25),("C5",.75)],
         7:[("Bb4",.25),("A4",.25),("G4",.5)],8:[("G4",.5),("C5",.5)],
         12:[("E5",.25),("D5",.25),("C5",.5)]}


def swung(beat):
    # 56:44 accompaniment only: move the latter half of each beat by .06 beat.
    return beat+.06 if abs(beat%1-.5)<1e-8 else beat


def make(arrangement):
    rng=np.random.default_rng(20261114 if arrangement=="garden"else 20261115)
    out=np.zeros((N,2),dtype=np.float32);ledger=[]
    for bar in range(32):
        phrase=bar%16;number=bar+1;last=bar==31
        events=[(n,float(d))for token in MELODY[phrase].split()for n,d in[token.split(":")]]
        assert sum(d for _,d in events)==4
        beat=0;short_count=0
        kind="flute"if arrangement=="garden"and phrase in range(4,8)else"wood"if arrangement=="garden"else"deck"
        for index,(note,length)in enumerate(events):
            gate=.92
            if length==.5:
                short_count+=1
                if short_count%2==0:gate=.80
            gain=.65 if index==len(events)-1 or(index+1<len(events)and events[index+1][0]=="r")else .55 if length==.5 else .78
            ledger.append(dict(role="principal",bar=number,beat=beat,note=note,beats=length,gate=gate,gain=gain,voice=kind))
            if note!="r":add_wrapped(out,(bar*4+beat)*BEAT,voice(note,length*BEAT*gate,kind,rng),.23*gain)
            beat+=length
        answer=ANSWERS.get(phrase+1)
        if answer:
            answer=list(answer)
            if bar>=16:
                # Keep one rest in place of the omitted final note; timing stays aligned.
                n,d=answer[-1];answer[-1]=("r",d)
            beat=3.
            for index,(note,length)in enumerate(answer):
                reed=("reed-scoop"if number in(4,20)and index==0 else"reed")if arrangement=="garden"else("deck-scoop"if number in(4,20)and index==0 else"deck-reed")
                ledger.append(dict(role="answer",bar=number,beat=beat,note=note,beats=length,gate=.80,gain=.65*10**(-9/20),voice=reed))
                if note!="r":add_wrapped(out,(bar*4+beat)*BEAT,voice(note,length*BEAT*.8,reed,rng),.23*.65*10**(-9/20),.08)
                beat+=length
        changes=[(0,2,"C7sus"),(2,2,"C7")]if HARMONY[phrase]=="C7sus>C7"else[(0,4,HARMONY[phrase])]
        for start,span,chord in changes:
            notes=VOICES[chord].split()
            # Dyad / sparse harp bars alternate. Keep the final breathing rest empty.
            for j,off in enumerate((.5,2.25)if bar%2==0 else(.75,2.5)):
                if not start<=off<start+span or(last and off>=2):continue
                selected=notes[1:3]if bar%2==0 else[notes[2+(j%(len(notes)-2))]]
                for k,note in enumerate(selected):
                    add_wrapped(out,(bar*4+swung(off))*BEAT,voice(note,.22 if arrangement=="deck"else .34,"deck"if arrangement=="deck"else"pluck",rng),.045 if arrangement=="garden"else .035,(-.12 if k else .12)if arrangement=="garden"else .04)
            # Exactly one bass pattern per bar, following the chord at each event.
            for off,choice,length,gain in((0,0,.65,.16),(1.75,1,.4,.105),(2.5,-1,.45,.115)):
                if not start<=off<start+span or(last and off>=2):continue
                note=notes[choice]if choice>=0 else notes[0][:-1]+str(int(notes[0][-1])+1)
                add_wrapped(out,(bar*4+off)*BEAT,voice(note,length*BEAT,"bass"if arrangement=="garden"else"chipbass",rng),gain)
            if number%4==0 and not last and start<=3.5<start+span:
                add_wrapped(out,(bar*4+swung(3.5))*BEAT,voice(notes[1],.25*BEAT,"bass"if arrangement=="garden"else"chipbass",rng),.045)
            if arrangement=="garden"and phrase in range(8,12):
                for j,note in enumerate(notes[1:4]):add_wrapped(out,(bar*4+start)*BEAT,voice(note,span*BEAT,"pad",rng),.013,(-.12,0,.12)[j])
        if not last:
            duration=.105 if bar%2==0 else .075;t=np.arange(round(duration*SR))/SR
            if bar%2==0:
                sig=(np.sin(2*np.pi*620*t)+.30*np.sin(2*np.pi*970*t))*np.exp(-t/.022)*envelope(t,duration,.002,.025)
            else:sig=filtered_noise(len(t),rng,1800,5800)*np.exp(-t/.018)*envelope(t,duration,.003,.025)
            add_wrapped(out,(bar*4+2.75)*BEAT,sig,.023 if arrangement=="garden"else .018,.06)
    # All delays wrap in PCM, preserving the loop including its natural room tail.
    wet=np.zeros_like(out)
    for k,delay in enumerate((.031,.047,.073,.109,.149,.197,.257,.337,.431,.547,.677,.797)):
        shifted=np.roll(out,round(delay*SR),axis=0)
        if k%2:shifted=shifted[:,::-1]
        wet+=shifted*math.exp(-delay/.24)
    wet/=3.8;ratio=.10 if arrangement=="garden"else .035
    out=(1-ratio)*out+ratio*wet;out-=out.mean(axis=0)
    assert np.isfinite(out).all()
    assert not any(e["bar"]==32 and e["beat"]>=2 and e["note"]!="r"for e in ledger)
    return out,ledger


def write(path, signal):
    assert np.isfinite(signal).all()and np.max(np.abs(signal))<1
    pcm=np.rint(signal*32767).astype("<i2")
    with wave.open(str(path),"wb")as f:
        f.setnchannels(1 if pcm.ndim==1 else pcm.shape[1]);f.setsampwidth(2);f.setframerate(SR);f.writeframes(pcm.tobytes())
    return pcm.astype(np.float32)/32767


def measure(path):
    result=subprocess.run(["ffmpeg","-hide_banner","-nostats","-i",str(path),"-af","loudnorm=I=-20:TP=-1:LRA=11:print_format=json","-f","null","-"],capture_output=True,text=True,check=True)
    match=re.findall(r'\{\s*"input_i".*?\}',result.stderr,re.S)
    assert match,result.stderr[-1500:]
    row=json.loads(match[-1])
    return dict(integrated_lufs=float(row["input_i"]),true_peak_dbfs=float(row["input_tp"]),loudness_range=float(row["input_lra"]))


def statistics(signal):
    mono=signal.mean(axis=1)if signal.ndim==2 else signal
    stereo_rms=float(np.sqrt(np.mean(signal.astype(np.float64)**2)))
    mono_rms=float(np.sqrt(np.mean(mono.astype(np.float64)**2)))
    seam=float(np.max(np.abs(signal[0]-signal[-1])))
    derivative=float(np.percentile(np.abs(np.diff(signal,axis=0)),99.99))
    assert seam<=derivative*1.05+2/32767,(seam,derivative)
    assert np.max(np.abs(signal))<.90
    assert abs(float(np.mean(signal)))<1e-5
    assert mono_rms>=stereo_rms*.90,"unexpected stereo cancellation"
    return dict(sample_peak_dbfs=20*math.log10(float(np.max(np.abs(signal)))),rms_dbfs=20*math.log10(stereo_rms),
                mono_rms_dbfs=20*math.log10(mono_rms),mono_peak_dbfs=20*math.log10(float(np.max(np.abs(mono)))),
                mono_vs_stereo_rms_db=20*math.log10(mono_rms/stereo_rms),dc=float(signal.mean()),
                boundary_jump=seam,derivative_p9999=derivative,clipped_samples=int(np.sum(np.abs(signal)>=1)))


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    report=dict(title="Little Afternoon",composer="Original Astra score / Sol synthesis",key="F major",bpm=BPM,bars=32,
                sample_rate=SR,channels=2,duration=SECONDS,pcm_samples=N,actual_pcm_duration=N/SR,production_installed=False,tracks={})
    tracks={}
    for name,target in (("garden",-20),("pocket-deck",-19)):
        signal,ledger=make("garden"if name=="garden"else"deck")
        signal*=.35/max(.001,float(np.max(np.abs(signal))))
        wav=OUT/("little-afternoon-"+name+"-104bpm-full.wav")
        write(wav,signal)
        raw=measure(wav)
        gain=min(target-raw["integrated_lufs"],-1.25-raw["true_peak_dbfs"])
        signal*=10**(gain/20)
        pcm=write(wav,signal)
        metered=measure(wav)
        if metered["true_peak_dbfs"]> -1.0:
            signal*=10**((-1.2-metered["true_peak_dbfs"])/20)
            pcm=write(wav,signal);metered=measure(wav)
        assert len(pcm)==N and metered["true_peak_dbfs"]<=-1
        stats=statistics(pcm)
        principal=[e for e in ledger if e["role"]=="principal"]
        assert principal[:len(principal)//2]==[dict(e,bar=e["bar"]-16)for e in principal[len(principal)//2:]],"principal score changed on repeat"
        assert principal[-1]["note"]=="r"and principal[-1]["beats"]==2
        tracks[name]=pcm
        write(OUT/("little-afternoon-"+name+"-seam-last4-first4-twice.wav"),np.concatenate([pcm[-4*SR:],pcm[:4*SR],pcm[-4*SR:],pcm[:4*SR]]))
        write(OUT/("little-afternoon-"+name+"-mono-20s.wav"),pcm[:20*SR].mean(axis=1))
        report["tracks"][name]=dict(file=wav.name,**metered,**stats,sha256=hashlib.sha256(wav.read_bytes()).hexdigest(),score=ledger)
    excerpts={}
    for name,signal in tracks.items():
        path=OUT/("little-afternoon-"+name+"-20s.wav")
        write(path,signal[:20*SR]);excerpts[name]=(path,measure(path))
    matched_target=min(-20.,*(row[1]["integrated_lufs"] for row in excerpts.values()))
    for name,(path,meter)in excerpts.items():
        signal=tracks[name][:20*SR]*10**((matched_target-meter["integrated_lufs"])/20)
        write(path,signal);report["tracks"][name]["preview20s"]=measure(path)
    levels=[v["preview20s"]["integrated_lufs"] for v in report["tracks"].values()]
    assert max(levels)-min(levels)<=1
    (OUT/"music-report.json").write_text(json.dumps(report,indent=2))
    for name,r in report["tracks"].items():
        print(name,"104bpm32bars48kstereo",r["integrated_lufs"],"LUFS",r["true_peak_dbfs"],"dBTP","mono",r["mono_vs_stereo_rms_db"],"dB","preview",r["preview20s"]["integrated_lufs"])


if __name__=="__main__":main()
