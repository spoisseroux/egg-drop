"""Compose the approved Blender renders without changing their pixel content."""
from pathlib import Path
from tempfile import gettempdir
from PIL import Image, ImageDraw, ImageFont
import argparse

ROOT=Path(__file__).resolve().parent
SRC=Path(gettempdir())/"egg-drop-overnight-pet-renders"
KEYS=("tikket","nuum","vezzi","kiprik","nolli")
EXPRS=("neutral","curious","startled","pleased","sleepy","affectionate")
FONTS=Path("C:/Windows/Fonts")
def font(size,bold=False):
    path=FONTS/("segoeuib.ttf" if bold else "segoeui.ttf")
    return ImageFont.truetype(str(path),size) if path.exists() else ImageFont.load_default(size=size)
BG="#F3F4E9";INK="#173D3D";MUTED="#47675F"
def card(im):
    return ImageDraw.Draw(im)
def paste(im,f,xy,size):
    src=Image.open(SRC/f).convert("RGB")
    src=src.resize((size,size),Image.Resampling.LANCZOS)
    im.paste(src,xy)
def sheet(pet):
    w=1240;h=712;im=Image.new("RGB",(w,h),BG);dr=card(im)
    dr.text((35,16),pet.title(),font=font(47,True),fill=INK)
    labels=["Front","Three-quarter","Profile"]
    views=["front","three-quarter","profile"]
    for j,(view,label) in enumerate(zip(views,labels)):
        x=36+j*398; paste(im,pet+"-"+view+".png",(x,85),315)
        dr.text((x,403),label,font=font(16,True),fill=MUTED)
    for j,ex in enumerate(EXPRS):
        x=36+j*198
        paste(im,pet+"-"+("front" if ex=="neutral" else ex)+".png",(x,457),164)
        dr.text((x,626),ex.title(),font=font(16),fill=INK)
    im.save(ROOT/(pet+"-art-review.png"),optimize=True)
def group():
    w,h=1560,1120;im=Image.new("RGB",(w,h),BG);dr=card(im)
    dr.text((32,17),"Sprout Hollow babies",font=font(47,True),fill=INK)
    for j,pet in enumerate(KEYS):
        x=32+j*301;dr.text((x,94),pet.title(),font=font(25,True),fill=INK)
        for k,ex in enumerate(("three-quarter","profile","startled")):
            paste(im,pet+"-"+ex+".png",(x,140+k*315),273)
    im.save(ROOT/"five-babies-gallery.png",optimize=True)
    w,h=1600,1330;im=Image.new("RGB",(w,h),BG);dr=card(im)
    dr.text((30,14),"Expressions",font=font(43,True),fill=INK)
    for j,ex in enumerate(EXPRS):dr.text((154+j*238,82),ex.title(),font=font(19,True),fill=MUTED)
    for row,pet in enumerate(KEYS):
        top=121+row*238;dr.text((22,top+86),pet.title(),font=font(28,True),fill=INK)
        for j,ex in enumerate(EXPRS):
            paste(im,pet+"-"+("front" if ex=="neutral" else ex)+".png",(154+j*238,top),215)
    im.save(ROOT/"five-babies-expressions.png",optimize=True)
    variants=(("front","Original"),("rose-tide","Rose / Tide"),("tide-citrus","Tide / Citrus"),("iris-rose","Iris / Rose"),("rose-tide-mix","Rose + Tide / Iris"))
    im=Image.new("RGB",(1460,1340),BG);dr=card(im)
    dr.text((30,16),"Main and Secondary",font=font(43,True),fill=INK)
    for j,(_,label) in enumerate(variants):dr.text((146+j*261,83),label,font=font(20,True),fill=MUTED)
    for row,pet in enumerate(KEYS):
        top=126+row*238;dr.text((18,top+84),pet.title(),font=font(28,True),fill=INK)
        for j,(label,_) in enumerate(variants):
            paste(im,pet+"-"+label+".png",(146+j*261,top),216)
    im.save(ROOT/"five-babies-hue-study.png",optimize=True)
if __name__=="__main__":
    ap=argparse.ArgumentParser()
    ap.add_argument("--pet",default="tikket");ap.add_argument("--all",action="store_true")
    a=ap.parse_args()
    if a.all:
        for k in KEYS:sheet(k)
        group()
    else:sheet(a.pet)
