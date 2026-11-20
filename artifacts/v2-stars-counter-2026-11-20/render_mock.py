import sys, math
from PIL import Image, ImageDraw, ImageFont
FRED, MONO, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
K=4  # supersample
def hx(h,a=255): h=h.lstrip('#'); return tuple(int(h[i:i+2],16) for i in (0,2,4))+(a,)
INK,CREAM,BUTTER,GOLD,GOLDLIP,WELL,LEMON=map(hx,["#15143A","#FFF4DC","#FFE7B0","#FFC14D","#D9A31C","#10133A","#FFE14D"])
SPEC={44:dict(lip=4,disc=48,star=28,text=22,pad=14),40:dict(lip=4,disc=44,star=26,text=20,pad=13),
      36:dict(lip=3,disc=40,star=22,text=18,pad=12),32:dict(lip=3,disc=34,star=20,text=16,pad=10),28:dict(lip=2,disc=30,star=16,text=15,pad=9)}
def star_pts(cx,cy,r,rot=-90):
    p=[]
    for i in range(10):
        a=math.radians(rot+i*36); rr=r if i%2==0 else r*.52
        p.append((cx+rr*math.cos(a),cy+rr*math.sin(a)))
    return p
def new_wallet(d,x,y,H,txt):
    s=SPEC[H]; f=ImageFont.truetype(FRED,s['text']*K)
    tw=d.textlength(txt,font=f)/K
    over=4; W=math.ceil(s['disc']-over+6+tw+s['pad']); fh=H-s['lip']
    X,Y=x*K,y*K
    # lip (gold) with ink stroke, then face
    d.rounded_rectangle([X-2*K,Y-2*K,X+W*K+2*K,Y+H*K+2*K],radius=(H/2+2)*K,fill=INK)
    d.rounded_rectangle([X,Y,X+W*K,Y+H*K],radius=H/2*K,fill=GOLDLIP)
    d.rounded_rectangle([X-2*K,Y-2*K,X+W*K+2*K,Y+fh*K+2*K],radius=(fh/2+2)*K,fill=INK)
    # face gradient cream->butter
    face=Image.new("RGBA",(W*K,fh*K)); fd=ImageDraw.Draw(face)
    for j in range(fh*K):
        t=j/(fh*K-1); fd.line([(0,j),(W*K,j)],fill=tuple(int(CREAM[i]+(BUTTER[i]-CREAM[i])*t) for i in range(3))+(255,))
    m=Image.new("L",(W*K,fh*K),0); ImageDraw.Draw(m).rounded_rectangle([0,0,W*K-1,fh*K-1],radius=fh/2*K,fill=255)
    d._image.paste(face,(X,Y),m)
    if H>=32:
        gx=X+(s['disc']-over+2)*K
        d.rounded_rectangle([gx,Y+4*K,X+(W-14)*K,Y+6*K],radius=K,fill=(255,255,255,150))
        d.ellipse([X+(W-11)*K,Y+4*K,X+(W-9)*K,Y+6*K],fill=(255,255,255,150))
    # medallion
    D=s['disc']; cx=X+(-over+D/2)*K; cy=Y+fh/2*K
    d.ellipse([cx-D/2*K,cy-D/2*K+2*K,cx+D/2*K,cy+D/2*K+2*K],fill=INK)  # drop/lip
    d.ellipse([cx-D/2*K,cy-D/2*K,cx+D/2*K,cy+D/2*K],fill=INK)
    r=D/2-2; d.ellipse([cx-r*K,cy-r*K,cx+r*K,cy+r*K],fill=WELL)
    rr=r-2; d.ellipse([cx-rr*K,cy-rr*K,cx+rr*K,cy+rr*K],outline=GOLD,width=int(1.5*K))
    sr=s['star']/2*1.05
    d.polygon(star_pts(cx,cy+1*K,sr*K),fill=GOLD)
    d.line(star_pts(cx,cy+1*K,sr*K)+[star_pts(cx,cy+1*K,sr*K)[0]],fill=GOLD,width=3*K,joint="curve")
    if s['star']>=20:
        e=max(2,round(s['star']*.12)); eh=max(3,round(s['star']*.18))
        for sd in(-1,1):
            ex=cx+sd*s['star']*.11*K; ey=cy+s['star']*.06*K
            d.rounded_rectangle([ex-e/2*K,ey-eh/2*K,ex+e/2*K,ey+eh/2*K],radius=e/2*K,fill=hx("#3B2608"))
    d.text((X+(W-s['pad'])*K,cy-1*K),txt,font=f,fill=INK,anchor="rm")
    return W
def old_wallet(d,x,y,H,txt):
    o={44:(22,18,18),40:(22,18,18),36:(18,15,15),32:(18,15,14),28:(16,14,10)}[H]; st,ts,pad=o
    f=ImageFont.truetype(MONO,ts*K); tw=d.textlength(txt,font=f)/K
    W=math.ceil(pad+st+8+tw+pad); X,Y=x*K,y*K
    d.rounded_rectangle([X-2*K,Y-2*K,X+W*K+2*K,Y+H*K+2*K],radius=(H/2+2)*K,fill=INK)
    d.rounded_rectangle([X,Y,X+W*K,Y+H*K],radius=H/2*K,fill=WELL)
    d.polygon(star_pts(X+(pad+st/2)*K,Y+H/2*K,st/2*K),fill=hx("#C9953A"))
    d.text((X+(W-pad)*K,Y+H/2*K),txt,font=f,fill=GOLD,anchor="rm")
    return W
Wd,Hd=720,400
im=Image.new("RGBA",(Wd*K,Hd*K),hx("#0E735B")); d=ImageDraw.Draw(im)
c=24
for i in range(0,Wd//c+1):
    for j in range(0,Hd//c+1):
        if (i+j)%2==0: d.rectangle([i*c*K,j*c*K,(i+1)*c*K,(j+1)*c*K],fill=hx("#127D63"))
lab=ImageFont.truetype(FRED,13*K)
d.text((20*K,14*K),"NOW",font=lab,fill=(255,255,255,255)); d.text((286*K,14*K),"PROPOSED  (20 / 1,280 / 12,345)",font=lab,fill=(255,255,255,255))
y=44
for H in(44,40,36,32,28):
    d.text((20*K,(y+H/2)*K),str(H),font=lab,fill=hx("#CDEFE7"),anchor="lm")
    old_wallet(d,56,y,H,"20"); old_wallet(d,146,y,H,"1,280")
    x=290
    for t in("20","1,280","12,345"):
        x+=new_wallet(d,x,y,H,t)+22
    y+=H+22
# in context: header with round keys
y+=6; d.text((20*K,(y+22)*K),"header",font=lab,fill=hx("#CDEFE7"),anchor="lm")
def key(x,ch):
    d.ellipse([(x-2)*K,(y+4-2)*K,(x+36+2)*K,(y+4+36+2+2)*K],fill=INK); d.ellipse([x*K,(y+6)*K,(x+36)*K,(y+42)*K],fill=hx("#D6C196")); d.ellipse([x*K,(y+4)*K,(x+36)*K,(y+40)*K],fill=CREAM)
    d.text(((x+18)*K,(y+22)*K),ch,font=ImageFont.truetype(FRED,18*K),fill=INK,anchor="mm")
key(290,"?"); w=new_wallet(d,346,y,44,"1,280"); key(346+w+14,"<")
im=im.resize((Wd*2,Hd*2),Image.LANCZOS); im.save(OUT)
