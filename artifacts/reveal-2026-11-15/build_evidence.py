import glob,os,subprocess
from PIL import Image,ImageDraw
TR=r"<session tool-results folder, not kept>"
out="artifacts/reveal-2026-11-15"
def load(stamp):
    f=glob.glob(os.path.join(TR,"mcp-Roblox_Studio-blob-%s-*.jpg"%stamp));assert len(f)==1,stamp
    return Image.open(f[0]).convert("RGB")
def save(im,path):
    os.makedirs(os.path.dirname(path),exist_ok=True);im.save(path,quality=92)
grid=[("1794719792149","0.10"),("1794719798798","0.50"),("1794719805748","0.90"),("1794719810832","1.00"),("1794719816721","1.10"),("1794719822031","1.20"),("1794719826799","1.33"),("1794719831882","1.50"),("1794719837048","1.60"),("1794719842182","1.70"),("1794719847015","1.80"),("1794719852349","2.20"),("1794719857314","3.20")]
boxes={"pet-bear":(0,0,812,354),"item-common-gloss":(824,0,1636,354),"item-rare-jelly":(0,366,812,720),"item-toy-untiered":(824,366,1636,720)}
seq={k:[] for k in boxes};seq["grid"]=[]
for stamp,t in grid:
    im=load(stamp);save(im,f"{out}/frames/phone-812x354/grid/grid-t{t}.jpg");seq["grid"].append((im,t))
    for name,box in boxes.items():
        c=im.crop(box);save(c,f"{out}/frames/phone-812x354/{name}/{name}-t{t}.jpg");seq[name].append((c,t))
pc={"pet-bear":[("1794718864584","0.60"),("1794718870650","1.00"),("1794718875533","1.33"),("1794718880800","1.57"),("1794718885718","1.80"),("1794718892117","3.20")],
 "item-common-gloss":[("1794719867095","0.80"),("1794719872162","1.03"),("1794719877246","1.20"),("1794719882295","1.73"),("1794719887595","3.20")],
 "item-rare-jelly":[("1794719893460","0.80"),("1794719898410","1.03"),("1794719903278","1.20"),("1794719908294","1.73"),("1794719913777","3.20")]}
pcseq={}
for name,frames in pc.items():
    pcseq[name]=[]
    for stamp,t in frames:
        im=load(stamp);save(im,f"{out}/frames/pc-1649x734/{name}/{name}-pc-t{t}.jpg");pcseq[name].append((im,t))
# 844x390, Reduced Motion, reopen
a10=load("1794719921161");a32=load("1794719926312");b103=load("1794719934493");b32=load("1794719939744");c32=load("1794719946976")
save(a10.crop((0,0,844,390)),f"{out}/frames/phone-844x390/pet-bear-844-t0.10.jpg")
save(a32.crop((0,0,844,390)),f"{out}/frames/phone-844x390/pet-bear-844-t3.20-settled.jpg")
save(b103.crop((0,0,844,390)),f"{out}/frames/phone-844x390/item-rare-jelly-844-t1.03-burst.jpg")
save(b32.crop((0,0,844,390)),f"{out}/frames/phone-844x390/item-rare-jelly-844-t3.20-settled.jpg")
save(c32.crop((0,0,844,390)),f"{out}/frames/phone-844x390/item-common-gloss-844-t3.20-settled.jpg")
save(a10.crop((856,0,1636,360)),f"{out}/frames/reduced-motion-780x360/item-rare-jelly-reduced-t0.10-midfade.jpg")
save(a32.crop((856,0,1636,360)),f"{out}/frames/reduced-motion-780x360/item-rare-jelly-reduced-t0.15-settled.jpg")
save(a10.crop((856,372,1636,732)),f"{out}/frames/reduced-motion-780x360/pet-bear-reduced-t0.10.jpg")
save(a32.crop((856,372,1636,732)),f"{out}/frames/reduced-motion-780x360/pet-bear-reduced-settled.jpg")
save(b32.crop((856,372,1636,732)),f"{out}/frames/reduced-motion-780x360/item-common-gloss-reduced-settled.jpg")
save(b103.crop((856,0,1636,360)),f"{out}/frames/reopen-780x360/item-toy-saved-receipt-reopen-instant.jpg")
save(c32.crop((856,0,1636,360)),f"{out}/frames/reopen-780x360/item-toy-first-toy-give-settled.jpg")
# real game flow (Studio window not focused, so the hatch clock waits on the egg)
save(load("1794719756216"),f"{out}/real-flow/real-first-bear-hatch-waiting-unfocused.jpg")
save(load("1794719769083"),f"{out}/real-flow/real-toy-egg-purchase-waiting-unfocused.jpg")
save(load("1794719339838"),f"{out}/real-flow/real-hatch-eggs-shop-before-toy-hatch.jpg")
# contact sheets
def sheet(frames,path,cols,scale=1.0,label=True):
    w,h=frames[0][0].size;w2,h2=int(w*scale),int(h*scale);rows=(len(frames)+cols-1)//cols;pad=6;bar=18
    s=Image.new("RGB",(cols*(w2+pad)+pad,rows*(h2+pad+bar)+pad),(24,24,24));d=ImageDraw.Draw(s)
    for i,(im,t) in enumerate(frames):
        x=pad+(i%cols)*(w2+pad);y=pad+(i//cols)*(h2+pad+bar)
        s.paste(im.resize((w2,h2),Image.LANCZOS),(x,y+bar));d.text((x+2,y+3),f"t = {t} s",fill=(235,235,235))
    save(s,path)
for name in boxes: sheet(seq[name],f"{out}/sheets/phone-812x354-{name}-contact-sheet.jpg",4,.6)
for name in pcseq: sheet(pcseq[name],f"{out}/sheets/pc-1649x734-{name}-contact-sheet.jpg",3,.4)
# side by side: Common vs Rare at matching times
pairs=[]
for (c,t),(r,_) in zip(seq["item-common-gloss"],seq["item-rare-jelly"]):
    im=Image.new("RGB",(812*2+8,354),(24,24,24));im.paste(c,(0,0));im.paste(r,(820,0));pairs.append((im,t))
sheet(pairs,f"{out}/sheets/phone-common-vs-rare-side-by-side.jpg",2,.55)
# sequences: frames held for their real gaps (GIF + MP4), real-time and 0.4x
def movie(frames,stem,size):
    os.makedirs(f"{out}/sequences",exist_ok=True)
    times=[float(t) for _,t in frames]
    durs=[(times[i+1]-times[i]) for i in range(len(times)-1)]+[1.2]
    ims=[im.resize(size,Image.LANCZOS) for im,_ in frames]
    ims[0].save(f"{out}/sequences/{stem}-realtime.gif",save_all=True,append_images=ims[1:],duration=[max(40,int(d*1000)) for d in durs],loop=0)
    ims[0].save(f"{out}/sequences/{stem}-slow-0.4x.gif",save_all=True,append_images=ims[1:],duration=[max(100,int(d*2500)) for d in durs],loop=0)
for name in boxes: movie(seq[name],f"phone-812x354-{name}",(812,354))
movie(seq["grid"],"phone-812x354-all-four-grid",(1236,550))
for name in pcseq: movie(pcseq[name],f"pc-{name}",(1100,490))
print("ok",sum(len(f) for _,_,f in os.walk(out)))
