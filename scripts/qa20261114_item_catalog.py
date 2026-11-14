"""Source-based item contact strip and original material-accent audition.

Artifact only. Hue art follows HueJarArt's native UI geometry; Bear/hat/finish
images are isolated authored-mesh renders. No invented egg acquisition paths.
"""
import json
import math
from pathlib import Path
import subprocess
import numpy as np
from PIL import Image, ImageDraw
import qa20261114_media as media
import qa20261114_music as music

OUT=media.OUT
CAT=OUT/"catalog"


def fruit():
    image=Image.new("RGBA",(470,296),media.INK);scale=260;left=105;top=15
    def blob(box,color,rotation=0,alpha=255,stroke=None):
        x,y,w,h=box
        layer=Image.new("RGBA",image.size,(0,0,0,0));draw=ImageDraw.Draw(layer)
        rect=(left+x*scale,top+y*scale,left+(x+w)*scale,top+(y+h)*scale)
        draw.rounded_rectangle(rect,radius=min(w,h)*scale*.5,fill=color,outline=stroke,width=2)
        if alpha!=255:layer.putalpha(layer.getchannel("A").point(lambda v:round(v*alpha/255)))
        if rotation:layer=layer.rotate(rotation,Image.Resampling.BICUBIC,center=((rect[0]+rect[2])/2,(rect[1]+rect[3])/2))
        image.alpha_composite(layer)
    # Exact normalized Rose geometry and colours from src/client/HueJarArt.lua.
    blob((.13,.20,.74,.68),"#E7FFFF",alpha=89,stroke="#234D61")
    def f(box,color,rotation=0):
        x,y,w,h=box;blob((.18+x*.64,.24+y*.58,w*.64,h*.58),color,rotation)
    f((.05,.25,.55,.65),"#FF327A",-12);f((.43,.16,.53,.66),"#FF327A",12)
    f((.34,.02,.51,.21),"#2E963E",-24)
    for y in(.16,.23):blob((.13,y,.74,.08),"#E9FFFF",stroke="#234D61")
    blob((.20,.31,.08,.25),"#FFFFFF",12,alpha=230)
    return image.convert("RGB")


def main():
    CAT.mkdir(exist_ok=True)
    rose=fruit();rose.save(CAT/"rose-fruit-native-art-equivalent.png")
    standard=Image.open(CAT/"standard-bear.png").convert("RGB")
    gloss=Image.open(CAT/"gloss-bear.png").convert("RGB")
    finish=Image.new("RGB",(470,296),media.INK);d=ImageDraw.Draw(finish)
    finish.paste(standard.resize((235,148),Image.Resampling.LANCZOS),(0,74))
    finish.paste(gloss.resize((235,148),Image.Resampling.LANCZOS),(235,74))
    d.text((75,234),"Standard",font=media.font(17),fill=media.CREAM)
    d.text((316,234),"Gloss",font=media.font(17),fill=media.CREAM)
    finish.save(CAT/"standard-to-gloss.png")
    cards=[("Wobble Top","Toy Egg outcome",Image.open(OUT/"toy/frame-047.png").convert("RGB")),
           ("Rose fruit","Hue Egg outcome · 8 Stars",rose),
           ("Gloss finish","Material Egg outcome · 16 Stars",finish),
           ("Sun Hat","Direct purchase · NOT an egg",Image.open(CAT/"sunhat-bust-direct-purchase.png").convert("RGB"))]
    strip=Image.new("RGB",(1624,445),media.INK);draw=ImageDraw.Draw(strip)
    draw.text((16,14),"Existing items / source-based preview equivalents / not live game",font=media.font(25,True),fill=media.CREAM)
    for i,(name,label,picture)in enumerate(cards):
        strip.paste(picture.resize((406,256),Image.Resampling.LANCZOS),(406*i,60))
        draw.text((406*i+14,328),name,font=media.font(25,True),fill=media.CREAM)
        draw.text((406*i+14,366),label,font=media.font(17),fill=media.MINT)
    draw.text((16,413),"Faceplates: fixed-price purchases. Backgrounds: free/earned. Neither is presented as an egg outcome.",font=media.font(17),fill=media.SOFT)
    strip.save(OUT/"existing-item-contact-strip.png")
    # Four distinct synthesized timbres, no recordings or external samples.
    rng=np.random.default_rng(20261114);audio=np.zeros((music.SR*4,2),dtype=np.float32)
    accents=[]
    for i,label in enumerate(("wood toy tap","fruit plop","cloth flutter","finish shimmer")):
        duration=.30;t=np.arange(round(duration*music.SR))/music.SR
        if i==0:sound=music.voice("F5",.09,"wood",rng)
        elif i==1:
            pitch=185+320*np.exp(-t/.025)
            sound=np.sin(2*np.pi*np.cumsum(pitch)/music.SR)*np.exp(-t/.07)*music.envelope(t,duration,.005,.04)
        elif i==2:
            sound=music.filtered_noise(len(t),rng,700,4500)*(np.exp(-t/.045)+.5*np.exp(-((t-.09)/.035)**2))*music.envelope(t,duration,.008,.04)
        else:
            sound=sum(music.voice(n,.12,"mallet",rng)*g for n,g in(("D6",.5),("F6",.35),("A6",.2)))
        at=round((i+.15)*music.SR);count=min(len(sound),len(audio)-at)
        audio[at:at+count]+=sound[:count,None]*.25/math.sqrt(2)
        accents.append(dict(time=i+.15,label=label))
    wav=OUT/"item-material-accent-audition.wav";music.write(wav,audio)
    meter=music.measure(wav);short=media.shortterm(wav)
    audio*=10**(min(-18-short,-3.2-meter["true_peak_dbfs"])/20)
    music.write(wav,audio);meter=music.measure(wav)
    assert meter["true_peak_dbfs"]<=-3
    frames=OUT/"item-accent-frames";frames.mkdir(exist_ok=True)
    for frame in range(48):
        i=min(3,frame//12);name,label,picture=cards[i]
        image=Image.new("RGB",(812,354),media.INK);image.paste(picture,(0,58));d=ImageDraw.Draw(image)
        d.text((16,22),"ITEM / MATERIAL ACCENT AUDITION · NOT LIVE GAME",font=media.font(15,True),fill=media.PEACH)
        d.text((494,112),name,font=media.font(30,True),fill=media.CREAM)
        # Two lines fit the real phone panel without inventing an action.
        lines=label.replace(" · ","\n").replace(" outcome","\noutcome")
        d.multiline_text((496,167),lines,font=media.font(19),fill=media.MINT,spacing=7)
        d.text((496,272),accents[i]["label"],font=media.font(18),fill=media.SOFT)
        image.save(frames/f"frame-{frame:03d}.png")
    subprocess.run(["ffmpeg","-y","-loglevel","error","-framerate","12","-i",str(frames/"frame-%03d.png"),"-i",str(wav),"-c:v","libx264","-crf","19","-pix_fmt","yuv420p","-c:a","aac","-b:a","160k","-shortest","-movflags","+faststart",str(OUT/"item-material-accent-audition.mp4")],check=True)
    report=dict(concept_only=True,native_render_proof=False,events=accents,meter=meter,loudest_3s_shortterm_lufs=media.shortterm(wav),
        sources=["src/client/HueJarArt.lua:3-24","src/client/PetToyGeometry.lua:45-53","src/shared/HueCatalog.lua:3-8,67-71","src/shared/MaterialCatalog.lua:10-15","src/shared/WearableCatalog.lua:1-4","src/client/FaceplateShop.lua:1-7","src/client/BackgroundShop.lua:1-5"],
        limitations=["Fruit reproduces existing flat native UI art, not a new 3D fruit mesh.","Gloss is a Blender scalar-map equivalent, not native Roblox acceptance.","Wearable remains a direct purchase and faceplate/background are intentionally not fabricated egg outcomes."])
    (OUT/"item-catalog-report.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    print("ITEM STRIP 4 outcomes; original accents;",report["loudest_3s_shortterm_lufs"],"LUFS shortterm",meter["true_peak_dbfs"],"dBTP")


if __name__=="__main__":main()
