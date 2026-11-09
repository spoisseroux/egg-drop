"""Paint three original shell illustrations from one smooth ovoid surface."""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
SIZE = 768
y, x = np.mgrid[0:SIZE, 0:SIZE]
# Surface-space coordinates. The illustration faces the viewer.
xx = (x + .5 - SIZE * .5) / (SIZE * .405)
yy = (y + .5 - SIZE * .482) / (SIZE * .405)
rad = .755 * (1 + .19 * yy) * np.sqrt(np.maximum(1 - yy * yy, 0))
inside = (np.abs(yy) < 1) & (np.abs(xx) < rad)
front = np.sqrt(np.maximum(rad * rad - xx * xx, 0))
nx = xx / np.maximum(rad, .001)
nz = front / np.maximum(rad, .001)
drdy = .755 * (.19 - yy - .38 * yy * yy) / np.sqrt(np.maximum(1 - yy * yy, .001))
ny = -drdy
length = np.sqrt(nx * nx + ny * ny + nz * nz)
nx, ny, nz = (v / np.maximum(length, .0001) for v in (nx, ny, nz))


def rgb(value):
    return np.array(tuple(bytes.fromhex(value)), dtype=float)


def mix(a, b, weight):
    return a * (1 - weight[..., None]) + b * weight[..., None]


def teardrop(x0, y0, w, h, angle, lean=0):
    dx, dy = xx - x0, yy - y0
    c, s = np.cos(np.deg2rad(angle)), np.sin(np.deg2rad(angle))
    u, v = (dx * c + dy * s) / w, (-dx * s + dy * c) / h
    u -= lean * v
    width = np.maximum(.06, 1 + .38 * v) * np.sqrt(np.maximum(0, 1 - v*v))
    return ((np.abs(v) < 1) & (np.abs(u) < width)).astype(float)


def dash(x0, y0, length, height, angle):
    dx, dy = xx - x0, yy - y0
    c, s = np.cos(np.deg2rad(angle)), np.sin(np.deg2rad(angle))
    u, v = dx*c + dy*s, -dx*s + dy*c
    return ((np.maximum(np.abs(u)-length/2+height/2, 0)**2 + v*v) < (height/2)**2).astype(float)


def paint(kind):
    colors = {
        "companion": ("FFF0AF", "FFE395", "CFC296"),
        "hue": ("77ECD5", "30C6CE", "298AAA"),
        "material": ("F4E1FF", "B6A6EF", "827AAC"),
    }
    top, middle, bottom = map(rgb, colors[kind])
    vertical = np.clip((yy+1)*.5, 0, 1)
    color = mix(top, middle, np.clip(vertical*1.65, 0, 1))
    color = mix(color, bottom, np.clip((vertical-.53)/.47, 0, 1)**1.2)
    # The colored marks are pigmented regions of the shell. Light them together.
    if kind == "companion":
        for data in [(-.28,-.28,.128,.22,-29,.06), (.33,.03,.14,.225,30,-.04),
                     (-.15,.58,.112,.15,18,.02)]:
            color = mix(color, rgb("3452C6"), teardrop(*data))
        path = .37 - .20*xx - .24*xx*xx
        sprout = ((xx>-.74) & (xx<.04) & (np.abs(yy-path)<.05*(1-(xx+.35)**2))).astype(float)
        color = mix(color, rgb("94B82D"), sprout)
    elif kind == "hue":
        petals = [
            ((-.27,-.26,.12,.255,-49,.06), "EF3C83"),
            ((.01,-.31,.122,.24,-15,.01), "3378C8"),
            ((.26,-.17,.119,.235,31,-.02), "FFC045"),
            ((.35,.17,.113,.207,63,.03), "835AE0"),
        ]
        for data, color_id in petals:
            color = mix(color, rgb(color_id), teardrop(*data))
        paths = .47 - .19 * xx + .12 * xx * xx
        wave = ((np.abs(yy-paths)<.042) & (xx<.50)).astype(float)
        color = mix(color, rgb("C4FFF0"), wave)
    else:
        sweep = .08 - .52*xx + .33*xx*xx
        main_band = ((yy>sweep-.14) & (yy<sweep+.17)).astype(float)
        ribbon = mix(rgb("61D6D4"), rgb("299CA9"), np.clip(xx*.55+.5,0,1))
        color = mix(color, ribbon, main_band)
        lower_fold = ((yy>sweep+.06) & (yy<sweep+.17)).astype(float)
        color = mix(color, rgb("36829C"), lower_fold)
        edge = ((np.abs(yy-(sweep-.12))<.019)).astype(float)
        color = mix(color, rgb("D8FFF1"), edge)
        color = mix(color, rgb("6E55AC"), dash(.32,.46,.27,.09,-24))
        color = mix(color, rgb("FFF3C8"), dash(-.32,-.42,.24,.105,-31))
    light = np.clip(-.42*nx - .48*ny + .75*nz, 0, 1)
    # Keep the silhouettes vivid and readable at small native sizes.
    color = color * (.76 + .22*light[...,None])
    edge_light = np.clip(1-nz,0,1)**3 * np.clip(-nx*.8-ny*.3,0,1)*.35
    color = mix(color, rgb("E8FBE9"), edge_light)
    # One soft window reflection with a clean inner scratch.
    u, v = (xx+.32) + .13*(yy+.46), yy+.48
    spec = np.exp(-((u/.115)**2+(v/.34)**2)*2)
    color = mix(color,rgb("FFFFF6"),.45*spec)
    glint = dash(-.32,-.49,.26,.055,-63)
    color = mix(color, rgb("FFFEF4"), .85*glint)
    rim = np.clip((1-nz)**8,0,1) * .25
    color = mix(color, rgb("475A63"), rim)
    rgba = np.zeros((SIZE,SIZE,4), dtype=np.uint8)
    rgba[:,:,:3] = np.clip(color,0,255).astype(np.uint8)
    rgba[:,:,3] = np.where(inside,255,0)
    shell = Image.fromarray(rgba, "RGBA")
    target = ROOT / (kind+"-egg.png")
    shell.resize((384,384),Image.Resampling.LANCZOS).save(target)
    return target


def contact_sheet(paths):
    sheet = Image.new("RGB",(960,420),"#EFF5E9")
    draw = ImageDraw.Draw(sheet)
    family = Path("C:/Windows/Fonts/segoeui.ttf")
    font = ImageFont.truetype(str(family),18) if family.exists() else ImageFont.load_default()
    draw.text((26,15),"Pocket Deck  /  original shell study",font=font,fill="#173D36")
    for index,path in enumerate(paths):
        img = Image.open(path)
        left = 28 + 310*index
        for size, position in [(240,(left+12,53)),(44,(left+20,327)),(28,(left+78,338))]:
            icon = img.resize((size,size),Image.Resampling.LANCZOS)
            sheet.paste(icon,position,icon)
        draw.text((left+12,290), path.stem.replace("-"," ").title(),font=font,fill="#173D36")
    sheet.save(ROOT / "original-egg-study.png")


if __name__ == "__main__":
    contact_sheet([paint(kind) for kind in ("companion","hue","material")])
