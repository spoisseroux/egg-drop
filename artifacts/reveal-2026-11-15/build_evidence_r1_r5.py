"""Cuts the R1-R5 follow-up evidence (2026-11-15) from raw Studio Play captures.
Kept as a record: the raw captures live in a session folder (TR), so copy them first to re-run.
Each 4-up capture holds four 812x354 fixture hosts (scripts/RevealCaptureFixture.lua)."""
import glob,os,sys
from PIL import Image,ImageDraw
TR=sys.argv[1] if len(sys.argv)>1 else "."
out=os.path.dirname(os.path.abspath(__file__))+"/r1-r5"
def load(stamp):
    f=glob.glob(os.path.join(TR,"mcp-Roblox_Studio-blob-%s-*.jpg"%stamp));assert len(f)==1,stamp
    return Image.open(f[0]).convert("RGB")
def save(im,path):
    os.makedirs(os.path.dirname(path),exist_ok=True);im.save(path,quality=92)
grid=[("1794736072597","0.07 open"),("1794776878098","1.00 burst"),("1794776885381","1.30"),("1794776895014","1.80"),("1794776901322","3.40 settled"),("1794776908997","leave +0.06"),("1794735610046","leave +0.20 (earlier run)")]
boxes={"toy-pocket-deck":(0,0,812,354),"finish-common-gloss":(824,0,1636,354),"pet-bear":(0,366,812,720),"finish-rare-jelly":(824,366,1636,720)}
seq={k:[] for k in boxes}
for stamp,t in grid:
    im=load(stamp);tag=t.replace(" ","-").replace("+","").replace("(","").replace(")","")
    save(im,f"{out}/frames/phone-812x354/grid/grid-{tag}.jpg")
    if "earlier" in t: continue
    for name,box in boxes.items():
        c=im.crop(box);save(c,f"{out}/frames/phone-812x354/{name}/{name}-{tag}.jpg");seq[name].append((c,t))
save(load("1794776917496"),f"{out}/frames/pc-1649x734/pet-bear-pc-t2.27-waving.jpg")
save(load("1794776927178"),f"{out}/frames/pc-1649x734/finish-rare-jelly-pc-t2.60.jpg")
save(load("1794735182002").crop((0,366,812,720)),f"{out}/frames/phone-812x354/pet-bear/pet-bear-BEFORE-R5-dark-light.jpg")
def sheet(frames,path,cols,scale=1.0):
    w,h=frames[0][0].size;w2,h2=int(w*scale),int(h*scale);rows=(len(frames)+cols-1)//cols;pad=6;bar=18
    s=Image.new("RGB",(cols*(w2+pad)+pad,rows*(h2+pad+bar)+pad),(24,24,24));d=ImageDraw.Draw(s)
    for i,(im,t) in enumerate(frames):
        x=pad+(i%cols)*(w2+pad);y=pad+(i//cols)*(h2+pad+bar)
        s.paste(im.resize((w2,h2),Image.LANCZOS),(x,y+bar));d.text((x+2,y+3),f"t = {t}",fill=(235,235,235))
    save(s,path)
for name in boxes: sheet(seq[name],f"{out}/sheets/phone-812x354-{name}-sheet.jpg",3,.6)
both=[]
for (a,t),(b,_),(c,_),(e,_) in zip(seq["pet-bear"],seq["toy-pocket-deck"],seq["finish-common-gloss"],seq["finish-rare-jelly"]):
    im=Image.new("RGB",(812*2+8,354*2+8),(24,24,24));im.paste(a,(0,0));im.paste(b,(820,0));im.paste(c,(0,362));im.paste(e,(820,362));both.append((im,t))
sheet(both,f"{out}/sheets/phone-all-four-sheet.jpg",2,.5)
# Short GIF: the frames held for their real gaps (beats, not smooth motion), at 0.5x.
frames=[im.resize((812,362),Image.LANCZOS) for im,_ in both]
durs=[900,300,500,1600,400,600][:len(frames)]
os.makedirs(f"{out}/sequences",exist_ok=True)
frames[0].save(f"{out}/sequences/phone-all-four-beats.gif",save_all=True,append_images=frames[1:],duration=durs,loop=0,optimize=True)
print("ok",len(both))
