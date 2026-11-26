"""Compose Blip v3 actual Blender renders; ordinary Pillow layout, never AI artwork."""
import argparse,json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
p=argparse.ArgumentParser();p.add_argument('directory');a=p.parse_args();D=Path(a.directory);R=D/'raw'
metas=[json.loads((D/f'{tag}-metadata.json').read_text())for tag in ('BEAR','D','E','F')]
assert all(m['render_size']==768 and m['render_spec']==metas[0]['render_spec'] and m['source_sha256']==metas[0]['source_sha256'] and m['source_unchanged']for m in metas),'Mismatched/stale concept metadata'
for tag in ('BEAR','D','E','F'):
    for view in ('front','q','side'):
        assert Image.open(R/f'{tag}-{view}.png').size==(768,768),'Mismatched render size'
BG='#DCE1DE';INK='#24313B';TAGS=('BEAR','D','E','F');NAMES={'BEAR':'Bear (authored materials)','D':'D  Pebblecap','E':'E  Puddlecheek','F':'F  Pillowbud'}
def font(size):
    try:return ImageFont.truetype('arial.ttf',size)
    except OSError:return ImageFont.load_default()
def img(tag,view='front'):return Image.open(R/f'{tag}-{view}.png').convert('RGBA')
def paste(canvas,im,xy,size=None):
    if size:im=im.resize(size,Image.Resampling.LANCZOS)
    canvas.paste(im,xy,im)
sheet=Image.new('RGB',(4*384,78+3*384),BG);draw=ImageDraw.Draw(sheet)
for col,tag in enumerate(TAGS):draw.text((col*384+12,10),NAMES[tag],font=font(24),fill=INK)
draw.text((12,47),'Procedural Blender concepts • equal camera scale • no production rig/import • charm off',font=font(19),fill=INK)
for row,view in enumerate(('front','q','side')):
    for col,tag in enumerate(TAGS):paste(sheet,img(tag,view),(col*384,78+row*384),(384,384))
sheet.save(D/'blip-v3-contact-sheet.png')
for garden in (False,True):
    bg='#457A52' if garden else BG
    out=Image.new('RGB',(4*330,900),bg);draw=ImageDraw.Draw(out)
    label='Procedural backdrop — garden color only, not Studio evidence' if garden else 'True 96px and 48px tiles, then 3x nearest-neighbor enlargements'
    color='#FFF0D2' if garden else INK
    draw.text((12,8),label,font=font(21),fill=color)
    for col,tag in enumerate(TAGS):
        x=col*330;draw.text((x+8,44),NAMES[tag],font=font(19),fill=color)
        im=img(tag);small=im.resize((96,96),Image.Resampling.LANCZOS);tiny=im.resize((48,48),Image.Resampling.LANCZOS)
        paste(out,small,(x+20,85));paste(out,tiny,(x+150,109))
        paste(out,small.resize((288,288),Image.Resampling.NEAREST),(x+16,200))
        paste(out,tiny.resize((144,144),Image.Resampling.NEAREST),(x+16,502))
        sil=Image.new('RGBA',small.size,(0,0,0,0));sil.putalpha(small.getchannel('A').point(lambda v:255 if v>127 else 0))
        paste(out,sil,(x+190,526));paste(out,sil.resize((192,192),Image.Resampling.NEAREST),(x+16,678))
        draw.text((x+170,620),'Silhouette',font=font(17),fill=color)
    out.save(D/('blip-v3-garden-small.png' if garden else 'blip-v3-small-silhouettes.png'))
print('SHEETS',D.resolve())
