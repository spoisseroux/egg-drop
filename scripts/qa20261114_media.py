"""Actual phone concept composites/contact sheet and local MP4/GIF previews."""
import argparse
import json
import math
import re
from pathlib import Path
import subprocess
import wave
import numpy as np
from PIL import Image,ImageDraw,ImageFont
import qa20261114_music as music

ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/"artifacts/qa-2026-11-14-v634/hatch-concept/revision-2"
TIGHTENED=False
INK="#132F31";CREAM="#FFF0D2";MINT="#94DFB7";SOFT="#ABC7BD";PEACH="#F0B6A1"


def font(n,bold=False):
    return ImageFont.truetype("C:/Windows/Fonts/"+("arialbd.ttf"if bold else"arial.ttf"),n)


def easing(t,a,b):
    u=max(0,min(1,(t-a)/(b-a)));return u*u*(3-2*u)


def composite(kind,frame,t):
    canvas=Image.new("RGB",(812,354),INK)
    canvas.paste(Image.open(frame).convert("RGB"),(0,58))
    d=ImageDraw.Draw(canvas)
    d.rounded_rectangle((12,12,143,43),radius=14,fill="#1B3A3B",outline="#53716D")
    d.text((25,21),"Roblox safe band",fill=SOFT,font=font(13))
    d.text((174,23),"V3 TIGHTENED / NOT LIVE GAME"if TIGHTENED else"CONCEPT  /  NOT LIVE GAME",fill=PEACH,font=font(13,True))
    d.line((478,78,478,329),fill="#3F5D59",width=1)
    label="Your first friend"if kind=="bear"else"Toy Egg · Object preview"
    title="Bear"if kind=="bear"else"Wobble Top"
    ready=2.65 if kind=="bear"else 2.20
    start=2.40 if kind=="bear"else 1.95
    intro=t<(start if TIGHTENED else(2.95 if kind=="bear"else 2.65))
    text=Image.new("RGBA",canvas.size,(0,0,0,0));td=ImageDraw.Draw(text)
    if intro:
        td.text((500,105),"A LITTLE SURPRISE",fill=PEACH,font=font(13,True))
        td.text((500,133),"The display\nwakes up",fill=CREAM,font=font(29,True),spacing=6)
        td.text((500,218),"One small moment.\nA new friend or favourite thing.",fill=SOFT,font=font(16),spacing=6)
    else:
        opacity=easing(t,start if TIGHTENED else(2.95 if kind=="bear"else 2.65),ready if TIGHTENED else(3.15 if kind=="bear"else 2.85))
        td.text((500,99),label,fill=PEACH,font=font(16))
        td.text((498,127),title,fill=CREAM,font=font(35 if kind=="bear"else 29,True))
        copy="A small friend\nwith a big hello."if kind=="bear"else"Spins, leans,\nfinds its feet."
        td.text((500,183),copy,fill=SOFT,font=font(20),spacing=6)
        if kind=="toy":td.text((500,238),"Preview · not equipped",fill=SOFT,font=font(14))
        text.putalpha(text.getchannel("A").point(lambda v:round(v*opacity)))
    canvas=Image.alpha_composite(canvas.convert("RGBA"),text)
    a=easing(t,start if TIGHTENED else(3.0 if kind=="bear"else 2.75),ready if TIGHTENED else(3.3 if kind=="bear"else 3.0))
    if a:
        buttons=Image.new("RGBA",canvas.size,(0,0,0,0));bd=ImageDraw.Draw(buttons)
        if kind=="bear":
            bd.rounded_rectangle((498,273,794,321),radius=12,fill=MINT)
            bd.text((646,297),"Meet Bear",anchor="mm",fill=INK,font=font(20,True))
        else:
            bd.rounded_rectangle((498,273,640,321),radius=12,fill=MINT)
            bd.rounded_rectangle((650,273,794,321),radius=12,fill="#2D504C",outline="#708B7F")
            bd.text((569,297),"Use now",anchor="mm",fill=INK,font=font(19,True))
            bd.text((722,297),"Keep",anchor="mm",fill=CREAM,font=font(19,True))
        buttons.putalpha(buttons.getchannel("A").point(lambda v:round(v*a)))
        canvas=Image.alpha_composite(canvas,buttons)
    # Bounded layout assertions are about this actual composite, not live GUI.
    assert 58+296==354 and 478>812*.58
    assert 498>=812*.58 and 321<=354-12 and 794<=812-12
    assert 321-273>=48
    return canvas.convert("RGB")


def shortterm(path):
    r=subprocess.run(["ffmpeg","-hide_banner","-i",str(path),"-af","ebur128=peak=true","-f","null","-"],capture_output=True,text=True,check=True)
    values=[float(x)for x in re.findall(r"S:\s*(-?\d+(?:\.\d+)?)",r.stderr)]
    assert values
    return max(values)


def cue_track(kind,duration):
    rng=np.random.default_rng(20261114)
    out=np.zeros((round(duration*music.SR),2),dtype=np.float32);ledger=[]
    def add(at,sound,gain,label,pan=0):
        if TIGHTENED:
            shared={.91:.78,.925:.795,1.27:.96,1.68:1.20}
            specific={2.06:1.50,2.17:1.64,2.48:1.98,2.58:2.08,2.68:2.18,2.89:2.31,3.08:2.48}if kind=="bear"else{1.86:1.44,2.08:1.55,2.18:1.65,2.28:1.75,2.56:2.05}
            at=specific.get(at,shared.get(at,at))
        start=round(at*music.SR);count=min(len(sound),len(out)-start)
        if count<=0:return
        gains=np.array([math.cos((pan+1)*math.pi/4),math.sin((pan+1)*math.pi/4)])
        out[start:start+count]+=sound[:count,None]*gain*gains
        ledger.append(dict(time=at,label=label,duration=len(sound)/music.SR,gain=gain))
    def noise(length,lo,hi,decay):
        t=np.arange(round(length*music.SR))/music.SR
        return music.filtered_noise(len(t),rng,lo,hi)*np.exp(-t/decay)*music.envelope(t,length,.003,.025)
    def glide(length,start,end,decay):
        t=np.arange(round(length*music.SR))/music.SR
        f=end+(start-end)*np.exp(-t/.035)
        return np.sin(2*np.pi*np.cumsum(f)/music.SR)*np.exp(-t/decay)*music.envelope(t,length,.006,.035)
    add(.20,music.voice("C5",.045,"wood",rng),.11,"rounded wood tick")
    add(.45,music.voice("D5",.045,"wood",rng),.12,"higher wood tick")
    add(.91,noise(.16,600,6000,.035),.38,"dry shell crack")
    add(.925,music.voice("A6",.07,"mallet",rng),.065,"small glass overtone")
    add(1.27,noise(.18,450,5000,.11)[::-1].copy(),.42,"cap upward swish")
    add(1.68,glide(.19,340,130,.085),.32,"original rubber bup")
    if kind=="bear":
        for at,n in((2.06,"C5"),(2.17,"D5")):add(at,music.voice(n,.10,"wood",rng),.15,"curious answer "+n)
        for at,n,g in((2.48,"F5",.27),(2.58,"A5",.28),(2.68,"C6",.29)):add(at,music.voice(n,.18,"pluck",rng),g,"reward flourish "+n)
        add(2.89,glide(.18,120,62,.06),.22,"soft landing thump")
        add(3.08,glide(.225,950,1450,.095),.085,"short happy chirrup")
    else:
        add(1.86,music.voice("F5",.10,"wood",rng),.25,"recognition wood tap")
        for at,n,g in((2.08,"F5",.27),(2.18,"A5",.28),(2.28,"C6",.29)):add(at,music.voice(n,.17,"pluck",rng),g,"toy reward flourish "+n)
        add(2.56,music.voice("C5",.06,"wood",rng),.16,"wobble contact")
    path=OUT/(kind+"-concept-cues.wav")
    out*=.40/max(.001,float(np.max(np.abs(out))));music.write(path,out)
    meter=music.measure(path);initial_s=shortterm(path)
    out*=10**(min(-18-initial_s,-3.2-meter["true_peak_dbfs"])/20)
    pcm=music.write(path,out);meter=music.measure(path);actual_s=shortterm(path)
    assert meter["true_peak_dbfs"]<=-3 and np.isfinite(pcm).all()
    assert abs(actual_s+18)<1.0,(kind,actual_s,meter)
    # Local audition mix, existing game routing/mute owner is unchanged.
    if TIGHTENED:bed=np.zeros_like(pcm)
    else:
        with wave.open(str(music.OUT/"little-afternoon-garden-104bpm-full.wav"),"rb")as f:
            bed=np.frombuffer(f.readframes(len(out)),dtype="<i2").reshape(-1,2).astype(np.float32)/32767
    time=np.arange(len(out))/music.SR
    end=3.35 if kind=="bear"else 2.65
    recovery=np.clip((time-end)/.60,0,1)
    duck=np.where(time<1.25,1,np.where(time<end,10**(-6/20),10**((-6*(1-recovery))/20)))
    mixed=pcm+bed*(10**(-7/20)*duck[:,None])
    mix=OUT/(kind+"-concept-mix.wav");music.write(mix,mixed)
    mixmeter=music.measure(mix)
    assert mixmeter["true_peak_dbfs"]<=-3,mixmeter
    music.write(OUT/(kind+"-concept-muted.wav"),np.zeros_like(mixed))
    return mix,dict(cues=path.name,events=ledger,loudest_3s_shortterm_lufs=actual_s,**meter,mix=mixmeter,
                    duck_db=-6,recovery_seconds=.6,music_bed_gain_db=None if TIGHTENED else -7,music_bed_present=not TIGHTENED,mute_sample_zero=True,native_mute_verified=False)


def main():
    global OUT,TIGHTENED
    parser=argparse.ArgumentParser();parser.add_argument("--stills",action="store_true");parser.add_argument("--tightened",action="store_true");args=parser.parse_args()
    if args.tightened:TIGHTENED=True;OUT=OUT.parent/"revision-3-tightened"
    summary={"concept_only":True,"not_live_game":True,"production_installed":False,"kinds":{}}
    for kind in("bear","toy"):
        path=OUT/(kind+("-stills"if args.stills else "")+"-metadata.json")
        if not path.exists():continue
        meta=json.loads(path.read_text());folder=OUT/(kind+"-phone-stills"if args.stills else kind+"-phone");folder.mkdir(exist_ok=True)
        for i,t in enumerate(meta["times"]):
            composite(kind,OUT/(kind+"-stills"if args.stills else kind)/f"frame-{i:03d}.png",t).save(folder/f"frame-{i:03d}.png")
        assert all(Image.open(p).size==(812,354)for p in folder.glob("frame-*.png"))
        if kind=="bear":
            targets=[.20,.85,1.30,1.64,2.14,2.80]if TIGHTENED else[.20,1.0,1.75,1.95,2.6666667,3.6]
            captions=["Store match","Crack / gather","Grounded curious entrance","Full eye-mesh blink","Joy / actual hop","Pleased / clear receipt"]
            sheet=Image.new("RGB",(1624,3*392+62),"#102829");d=ImageDraw.Draw(sheet)
            d.text((16,15),"V3 tightened / accepted V2 base / concept, not live game"if TIGHTENED else"Hatch display comes alive  /  concept, not live game",font=font(27,True),fill=CREAM)
            for k,t in enumerate(targets):
                index=min(range(len(meta["times"])),key=lambda i:abs(meta["times"][i]-t))
                x=(k%2)*812;y=62+(k//2)*392
                sheet.paste(Image.open(folder/f"frame-{index:03d}.png"),(x,y))
                d.text((x+14,y+361),f"{meta['times'][index]:.2f}s  ·  {captions[k]}",font=font(18),fill=MINT)
            sheet.save(OUT/("hatch-six-frame-storyboard"+("-stills"if args.stills else "")+".png"))
            strip=Image.new("RGB",(4*470,340),INK);sd=ImageDraw.Draw(strip)
            targets=((1.30,"Curious"),(1.64,"Blink"),(2.14,"Joy"),(2.8,"Pleased"))if TIGHTENED else((1.75,"Curious"),(1.95,"Blink"),(2.6666667,"Joy"),(3.6,"Pleased"))
            for j,(t,label)in enumerate(targets):
                index=min(range(len(meta["times"])),key=lambda i:abs(meta["times"][i]-t))
                strip.paste(Image.open(OUT/(kind+"-stills"if args.stills else kind)/f"frame-{index:03d}.png"),(470*j,0))
                sd.text((470*j+12,305),label+" · isolated mesh equivalent",font=font(17),fill=CREAM)
            strip.save(OUT/"bear-expression-strip.png")
            Image.open(folder/f"frame-{len(meta['times'])-1:03d}.png").save(OUT/"bear-settled-812x354.png")
        else:Image.open(folder/f"frame-{len(meta['times'])-1:03d}.png").save(OUT/"toy-settled-812x354.png")
        if not args.stills:
            assert len(meta["times"])==round(meta["duration"]*meta["fps"])
            cues,audio=cue_track(kind,meta["duration"])
            movie=OUT/(kind+"-hatch-concept.mp4")
            subprocess.run(["ffmpeg","-y","-loglevel","error","-framerate",str(meta["fps"]),"-i",str(folder/"frame-%03d.png"),"-i",str(cues),
                            "-c:v","libx264","-crf","19","-pix_fmt","yuv420p","-c:a","aac","-b:a","160k","-shortest","-movflags","+faststart",str(movie)],check=True)
            gif=OUT/(kind+"-hatch-concept.gif")
            subprocess.run(["ffmpeg","-y","-loglevel","error","-i",str(movie),"-filter_complex","fps=12,split[a][b];[a]palettegen=max_colors=192[p];[b][p]paletteuse=dither=bayer:bayer_scale=3","-loop","0",str(gif)],check=True)
            probe=subprocess.run(["ffprobe","-v","error","-show_streams","-show_format","-of","json",str(movie)],capture_output=True,text=True,check=True)
            details=json.loads(probe.stdout);video=next(s for s in details["streams"]if s["codec_type"]=="video")
            assert (video["width"],video["height"])==(812,354)and abs(float(details["format"]["duration"])-meta["duration"])<.15
            summary["kinds"][kind]=dict(mp4=movie.name,gif=gif.name,audio=audio,**meta,ffprobe=details)
        print("COMPOSITE",kind,len(meta["times"]),"frames812x354",flush=True)
    (OUT/"media-report.json").write_text(json.dumps(summary,indent=2))


if __name__=="__main__":main()
