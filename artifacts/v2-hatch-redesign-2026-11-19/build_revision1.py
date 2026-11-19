"""v2 hatch redesign, Revision 1 mockups and motion preview (Fable as Astra, 2026-11-19). PIL and numpy only.
Reuses build_mockups.py (this folder) and the Toy Shell kit, both unedited. Same real 3D content as before
(egg cut from a Studio capture, Bunny and Stat Egg as before). No generated art.

  05-rare-jackpot-strip.png            six frames of the Rare jackpot, sampled from the same function as the video
  06-vibrant-preview-stages.png        the old berry stage beside the three new tier stages, palettes and contrast
  07-transition-in-out-strip.png       toy lid in from the egg shop, iris out to where the player came from
  08-rare-jackpot-preview.mp4 / .gif   3.4 s of the jackpot (hatch clock 0.80 to 4.20), 60 fps, with the audition mix

python artifacts/v2-hatch-redesign-2026-11-19/build_revision1.py     (mp4/gif need ffmpeg; run synth_hatch_jackpot.py first for sound)
"""
import importlib.util, math, os, random, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("hatch", os.path.join(HERE, "build_mockups.py"))
B = importlib.util.module_from_spec(spec); spec.loader.exec_module(B)
T = B.T
S, R, font, mix, rgb = T.S, T.R, T.font, T.mix, T.rgb
INK, CREAM, WHITE, LEMON = T.INK, T.CREAM, T.WHITE, T.LEMON
W, H = 844, 390
TIER = B.TIER
PAL = {  # the vibrant stages: core sits behind the item, edge at the rim, ray is the light ray, floor the light pool
    "Common": dict(name="Sunny Peach", core="#FF9A2E", edge="#F0541E", ray="#FFBC47", floor="#FFF3C4", deep="#A8300E", pattern="dots"),
    "Uncommon": dict(name="Lime Soda", core="#58C92F", edge="#16994A", ray="#9BE23A", floor="#F6FFC4", deep="#0B6B36", pattern="stripes"),
    "Rare": dict(name="Berry Blast", core="#E845C8", edge="#6B3BEA", ray="#FF79D9", floor="#FFE9F8", deep="#3B1FA0", pattern="diamonds"),
}
CONFETTI = ["#8E7CFF", "#5CC8FF", CREAM, LEMON, "#FF8FC0", "#7CF0A0"]   # never Stars gold, never a five-point star
# ---- the Rare jackpot clock (seconds on the hatch clock) ----
LIFT, FREEZE, BURST, POP, CAN1, CAN2, STAMP, SLIDE, NAME = 0.95, 1.60, 1.72, 1.80, 1.95, 2.07, 2.30, 2.80, 3.15

# ---------- easing (the same curves the spec names) ----------
def clamp(u): return max(0.0, min(1.0, u))
def seg(t, a, b): return clamp((t - a) / (b - a))
def expo_out(u): return 1.0 if u >= 1 else 1 - 2 ** (-10 * u)
def expo_in(u): return 0.0 if u <= 0 else 2 ** (10 * (u - 1))
def quad_in(u): return u * u
def quad_out(u): return 1 - (1 - u) ** 2
def back_out(u, s=1.70158): u -= 1; return 1 + u * u * ((s + 1) * u + s)
def spring(u, cycles=1.5, damp=5.0): return math.exp(-damp * u) * math.cos(u * cycles * math.tau)   # 1 -> 0, rings
def sstep(a, b, x): u = np.clip((x - a) / (b - a), 0, 1); return u * u * (3 - 2 * u)
def lerp(a, b, u): return a + (b - a) * u

# ---------- integrated motion (so speed changes never jump) ----------
_DT = 1 / 240; _TS = np.arange(0, 6, _DT)
def _table(rate): return np.cumsum(np.vectorize(rate)(_TS)) * _DT
def _slow(t): return 0.10 if FREEZE <= t < BURST else 1.0                      # the slow-motion hold
ORBIT = _table(lambda t: 0 if t < LIFT else lerp(0.75, 2.5, quad_in(seg(t, LIFT, FREEZE))) * _slow(t))          # revolutions
CHECK = _table(lambda t: (8 if t < LIFT else lerp(8, 48, seg(t, LIFT, FREEZE)) if t < BURST else lerp(48, 8, quad_out(seg(t, BURST, 3.0)))) * _slow(t))
RAYS = _table(lambda t: (12 if t < LIFT else lerp(12, 40, seg(t, LIFT, FREEZE)) if t < SLIDE else 18) * _slow(t))   # degrees
def at(table, t): return float(table[min(len(table) - 1, max(0, int(t / _DT)))])

# ---------- pixel helpers ----------
def np_blend(c, colour, alpha, x0=0, y0=0):
    """colour: (3,) or (h,w,3) 0..255; alpha: (h,w) 0..1; both in device pixels, placed at x0,y0."""
    h, w = alpha.shape
    a = np.asarray(c.im.crop((x0, y0, x0 + w, y0 + h)), dtype=np.float32)
    out = a + (np.asarray(colour, dtype=np.float32) - a) * alpha[..., None]
    c.im.paste(Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB"), (x0, y0)); c._redraw()

def hsv(h, s=0.78, v=1.0):
    k = np.clip(np.abs(((h[..., None] * 6 + np.array([0, 4, 2])) % 6) - 3) - 1, 0, 1)
    return 255 * v * (1 - s + s * k)

def put(c, im, cx, cy, sx=1.0, sy=1.0, rot=0.0, alpha=1.0, base=False):
    """Paste a sprite at a sub-pixel point with scale, squash and rotation. base=True: cy is the sprite's foot."""
    w, h = max(1, round(im.width * sx)), max(1, round(im.height * sy))
    t = im.resize((w, h), Image.LANCZOS) if (w, h) != im.size else im
    if rot: t = t.rotate(rot, Image.BICUBIC, expand=True)
    if alpha < 1: t = t.copy(); t.putalpha(t.getchannel("A").point(lambda v: int(v * alpha)))
    y = cy * R - (t.height if base else t.height / 2)
    c.im.paste(t, (round(cx * R - t.width / 2), round(y)), t); c._redraw()

def overlay(c, draw_fn):
    g = Image.new("RGBA", c.im.size, (0, 0, 0, 0)); draw_fn(ImageDraw.Draw(g)); c.im.paste(g, (0, 0), g); c._redraw()

# ---------- the vibrant stage ----------
def vstage(c, box, tier, rot=0.0, rays=1.0, rim=1.0, rainbow=0.0, t=0.0, pool=True, r=22):
    """Radial gradient (core to edge) + 12 light rays that stay out of the middle + an edge-only pattern + vignette."""
    p = PAL[tier]; x0, y0, x1, y1 = box
    c.rr((x0, y0, x1, y1 + 4), r, fill=INK)
    c.rr((x0 + 3, y0 + 3, x1 - 3, y1 + 1), r - 3, fill=p["deep"])
    X0, Y0, X1, Y1 = S(x0 + 3), S(y0 + 3), S(x1 - 3), S(y1 - 3)
    yy, xx = np.mgrid[Y0:Y1, X0:X1].astype(np.float32)
    dx, dy = xx - (x0 + x1) / 2 * R, yy - ((y0 + y1) / 2 + 10) * R
    rad = np.hypot(dx, dy); dist = rad / (0.60 * max(X1 - X0, Y1 - Y0))
    core, edge, ray, deep = (np.array(rgb(p[k]), dtype=np.float32) for k in ("core", "edge", "ray", "deep"))
    k = sstep(.18, 1.0, dist)[..., None]; col = core * (1 - k) + edge * k
    sinv = np.sin(np.arctan2(dy, dx) * 12 + math.radians(rot) * 12)
    m = np.clip(.5 + sinv * rad / 12 / 1.5, 0, 1) * sstep(.16, .42, dist) * rays * .85
    col += (ray - col) * m[..., None]
    q = S(14)
    if p["pattern"] == "dots":
        ox = np.where((yy // q) % 2 == 0, 0, q / 2); pm = (((xx + ox) % q - q / 2) ** 2 + (yy % q - q / 2) ** 2) < S(2.3) ** 2
    elif p["pattern"] == "stripes":
        pm = ((xx + yy) % S(18)) < S(5)
    else:
        q = S(20); ox = np.where((yy // q) % 2 == 0, 0, q / 2); pm = (np.abs((xx + ox) % q - q / 2) + np.abs(yy % q - q / 2)) < S(3.4)
    col += (255 - col) * (pm * .20 * sstep(.50, .85, dist))[..., None]
    col += (deep - col) * (.30 * sstep(.75, 1.25, dist))[..., None]
    mask = Image.new("L", (X1 - X0, Y1 - Y0), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, X1 - X0 - 1, Y1 - Y0 - 1), S(r - 3), fill=255)
    c.im.paste(Image.fromarray(np.clip(col, 0, 255).astype(np.uint8), "RGB"), (X0, Y0), mask); c._redraw()
    if pool:
        cx = (x0 + x1) / 2
        def glow(d): d.ellipse((S(cx - 96), S(y1 - 68), S(cx + 96), S(y1 - 28)), fill=rgb(p["floor"]) + (190,))
        g = Image.new("RGBA", c.im.size, (0, 0, 0, 0)); glow(ImageDraw.Draw(g)); g = g.filter(ImageFilter.GaussianBlur(S(7)))
        g.putalpha(Image.composite(g.getchannel("A"), Image.new("L", g.size, 0), _region_mask(c, (X0, Y0), mask)))
        c.im.paste(g, (0, 0), g); c._redraw()
        c.ellipse((cx - 72, y1 - 59, cx + 72, y1 - 38), outline=p["floor"], width=1.8)
    if rim > 0:
        c.rr((x0 + 3, y0 + 3, x1 - 3, y1 - 3), r - 3, outline=mix(p["deep"], TIER[tier][0], rim), width=3)
    if rainbow > 0:
        ring = Image.new("L", (X1 - X0, Y1 - Y0), 0)
        ImageDraw.Draw(ring).rounded_rectangle((0, 0, X1 - X0 - 1, Y1 - Y0 - 1), S(r - 3), outline=255, width=S(4))
        hue = (np.arctan2(dy, dx) / math.tau + .6 * t) % 1.0
        np_blend(c, hsv(hue, .70), np.asarray(ring, dtype=np.float32) / 255 * rainbow, X0, Y0)

def _region_mask(c, origin, mask):
    full = Image.new("L", c.im.size, 0); full.paste(mask, origin); return full

def item_lip(c, im, cx, base_y, sx=1.0, sy=1.0, a=.42):
    """The readability rule: one ink copy of the item 4 px below it, so every item has a dark lower edge."""
    put(c, B.silhouette(im), cx, base_y + 4, sx, sy, alpha=a, base=True)

# ---------- screen-level effects ----------
_YY, _XX = np.mgrid[0:S(H), 0:S(W)].astype(np.float32)
def shafts(c, cx, cy, pal, a, rot):
    """Deck-colour light shafts behind the well: twelve soft wedges of a lighter shell colour."""
    if a <= 0: return
    dx, dy = _XX - cx * R, _YY - cy * R; rad = np.hypot(dx, dy)
    m = np.clip(.5 + np.sin(np.arctan2(dy, dx) * 12 - math.radians(rot) * 12) * rad / 12 / 3, 0, 1)
    np_blend(c, rgb(mix(pal["shell"], WHITE, .62)), m * a * .46 * sstep(S(120), S(260), rad))

def rainbow_edge(c, a, t):
    """A band of travelling hue along the screen edge. Constant brightness: it is colour, not a flash."""
    if a <= 0: return
    d = np.minimum(np.minimum(_XX, S(W) - 1 - _XX), np.minimum(_YY, S(H) - 1 - _YY)) / R
    hue = (np.arctan2(_YY - S(H) / 2, (_XX - S(W) / 2) * H / W) / math.tau + .6 * t) % 1.0
    np_blend(c, hsv(hue, .72), np.exp(-d / 9.0) * a * .92)

def piece(c, x, y, size, col, rot):
    """One confetti chip: a rotated rounded square with an ink edge (or a four-point sparkle)."""
    def sq(h): return [(x + math.cos(rot + k * math.pi / 2 + math.pi / 4) * h * 1.414, y + math.sin(rot + k * math.pi / 2 + math.pi / 4) * h * 1.414 * .8) for k in range(4)]
    c.poly(sq(size / 2 + 1.3), INK); c.poly(sq(size / 2), col)

def cannon(c, t, t0, side, seed):
    """A confetti cannon from a bottom corner: 26 pieces, 620 to 1180 px/s, 40 to 80 degrees, drag 1.1/s, gravity 520 px/s2."""
    tau = t - t0
    if tau < 0 or tau > 1.9: return
    rnd = random.Random(seed)
    for i in range(26):
        ang = math.radians(rnd.uniform(40, 80)); v = rnd.uniform(620, 1180); size = rnd.uniform(9, 15); spin = rnd.uniform(-9, 9); col = rnd.choice(CONFETTI)
        drag = (1 - math.exp(-1.1 * tau)) / 1.1
        x = (-8 if side < 0 else W + 8) - side * math.cos(ang) * v * drag
        y = H + 6 - math.sin(ang) * v * drag + .5 * 950 * tau * tau * .55
        if y > H + 20 or tau > 1.9: continue
        if i % 4 == 3: B.spark(c, x, y, size * .62, col)
        else: piece(c, x, y, size, col, spin * tau + i)

# ---------- sprites ----------
SPR = {}
def sprites():
    B.EGG = B.egg_cut(); B.BUNNY = B.rgba("artifacts/v2-pet-redesign-2026-11-19/raw/solo-bunny-threeq.png")
    B.JAR = B.jar_cut(); B.STATEGG = B.stat_egg(150)
    B.SNACK = B.rgba("artifacts/v2-pet-snacks-2026-11-19/raw/snack-grid.png", (386, 411, 586, 603))
    egg = B.fit(B.EGG, 150); bun = B.fit(B.BUNNY, 196)
    SPR.update(egg=egg, bun=bun, sil=B.silhouette(bun), top=egg.crop((0, 0, egg.width, egg.height // 2)), bot=egg.crop((0, egg.height // 2, egg.width, egg.height)))
    t = B.blank(380, 150); f = font("disp", 70)
    t.text((190, 82), "RARE!", f, INK, "mm", stroke=8); t.text((190, 77), "RARE!", f, TIER["Rare"][0], "mm", stroke=6, stroke_fill=INK)
    t.text((190, 72), "RARE!", f, WHITE, "mm", stroke=4, stroke_fill=INK)
    SPR["stamp"] = t.im.rotate(6, Image.BICUBIC)
    n = B.blank(260, 80); B.title(n, 6, 34, "BUNNY", 38, under=TIER["Rare"][0]); SPR["name"] = n.im

# ---------- the Rare jackpot, one function of time ----------
def jackpot_frame(t, pal=B.CLASSIC, shake=True):
    c = T.Canvas(W, H, fill=pal["shell"]); B.checker(c, at(CHECK, t))
    slide = expo_out(seg(t, SLIDE, SLIDE + .34))
    popk = back_out(seg(t, BURST, BURST + .22), 2.4) * (1 - slide) if t >= BURST else 0.0       # the frame punches open
    box = [lerp(a, b, slide) for a, b in zip(B.CENTRE, B.SEAT)]
    box = (box[0] - 24 * popk, box[1] - 6 * popk, box[2] + 24 * popk, box[3] + 6 * popk)
    cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
    foot = box[3] - 40                                                                           # where things stand in the well
    sh = lerp(0, .55, seg(t, LIFT, FREEZE)) if t < BURST else lerp(1.0, .30, quad_out(seg(t, BURST + .3, SLIDE + .3)))
    shafts(c, cx, cy, pal, sh, at(RAYS, t))
    rb = quad_out(seg(t, BURST, BURST + .15)) * lerp(1, .45, seg(t, SLIDE, NAME))
    rainbow_edge(c, rb, t)
    ray_a = .35 if t < LIFT else lerp(.35, .75, seg(t, LIFT, FREEZE)) if t < BURST else 1.0
    vstage(c, box, "Rare", rot=at(RAYS, t), rays=ray_a, rim=lerp(.6, 1, seg(t, .65, LIFT)), rainbow=rb, t=t, pool=t < BURST or t > POP + .2)
    # shockwave: a line ring, not a filled flash
    u = seg(t, BURST, BURST + .50)
    if 0 < u < 1:
        rr_ = 40 + 560 * expo_out(u); wd = lerp(10, 2, u); a = int(255 * (1 - u) ** 1.5)
        overlay(c, lambda d: (d.ellipse((S(cx - rr_), S(cy - rr_ * .72), S(cx + rr_), S(cy + rr_ * .72)), outline=rgb(WHITE) + (a,), width=S(wd)),
                              d.ellipse((S(cx - rr_ * .86), S(cy - rr_ * .62), S(cx + rr_ * .86), S(cy + rr_ * .62)), outline=rgb(TIER["Rare"][1]) + (a // 2,), width=S(wd * .6))))
    # orbiting rune stones and sparkles; they explode at the burst
    stones = []
    if t >= LIFT:
        fade = seg(t, LIFT, LIFT + .12); ex = expo_out(seg(t, BURST, BURST + .60)) if t >= BURST else 0
        if ex < 1:
            orad = lerp(132, 92, quad_in(seg(t, LIFT, FREEZE))) + 560 * ex
            for i in range(12):
                th = (i / 12 + at(ORBIT, min(t, BURST))) * math.tau
                stones.append((math.sin(th), cx + math.cos(th) * orad, cy - 14 + math.sin(th) * orad * .62, i, fade * (1 - ex * .25)))
    def draw_stones(front):
        for depth, x, y, i, k in stones:
            if (depth >= 0) != front: continue
            size = (15 + 4 * depth) * k
            if size < 5: continue
            if i % 3 == 2: B.spark(c, x, y, size * .45, LEMON if i % 2 else CREAM)
            else: T.stone(c, x, y, size, *B.STATS["Jump"])
    draw_stones(False)
    if t < BURST:
        # the egg: lift, shiver, then squash down as anticipation in the freeze
        lift = 10 * expo_out(seg(t, LIFT, LIFT + .20))
        wob = 3.2 * math.sin(at(ORBIT, t) * math.tau * 3) * seg(t, LIFT, FREEZE) if t < FREEZE else 0
        sq = quad_out(seg(t, FREEZE, BURST)); sx, sy = 1 + .14 * sq, 1 - .14 * sq
        glow = seg(t, LIFT, FREEZE)
        if glow > 0: B.bloom(c, cx, foot - 86, 70 + 16 * glow, TIER["Rare"][1], int(120 * glow))
        item_lip(c, SPR["egg"], cx, foot - 12 - lift, sx, sy)
        put(c, SPR["egg"], cx, foot - 12 - lift, sx, sy, rot=wob, base=True)
        if t >= .65: B.crack(c, cx + 2, foot - 96 - lift + 10 * sq, 84 + 14 * seg(t, .80, LIFT), light=TIER["Rare"][1 if t >= LIFT else 0])
    else:
        tau = t - BURST
        ub = seg(t, BURST, BURST + .40)                                    # the one bloom: 60% white, inside the well
        if ub < 1: B.bloom(c, cx, cy - 6, 150 * expo_out(min(1, ub * 2.5)), WHITE, int(153 * min(1, tau / .05) * (1 - ub) ** 2))
        for im, vx, vy, spin in ((SPR["top"], -430, -560, 300), (SPR["bot"], 400, -340, -240)):
            x, y = cx + vx * tau, foot - 110 + vy * tau + .5 * 1500 * tau * tau
            if y < H + 80: put(c, im, x, y, rot=spin * tau)
        if t >= POP:
            up = seg(t, POP, POP + .28); sc = lerp(.30, 1.0, back_out(up, 2.2))
            land = spring(seg(t, POP + .20, POP + .62), 1.5, 4.5) * (1 if t >= POP + .20 else 0)
            hop = spring(seg(t, STAMP, STAMP + .40), 1.0, 5.0) * (1 if t >= STAMP else 0)
            sx, sy = sc * (1 + .08 * land + .05 * hop), sc * (1 - .10 * land - .06 * hop)
            k = seg(t, POP + .22, POP + .40)
            im = SPR["sil"] if k <= 0 else SPR["bun"] if k >= 1 else Image.blend(SPR["sil"], SPR["bun"], k)
            if k > 0: item_lip(c, SPR["bun"], cx, foot + 6, sx, sy, a=.42 * k)
            put(c, im, cx, foot + 6, sx, sy, base=True)
    draw_stones(True)
    cannon(c, t, CAN1, -1, 21); cannon(c, t, CAN2, 1, 22)
    # the stamp-slam title: falls in big, hits, squashes, settles; later shrinks into the sticker
    if STAMP - .12 <= t < SLIDE + .20:
        fall = expo_in(seg(t, STAMP - .12, STAMP)); sc = lerp(2.6, 1.0, fall)
        sqz = spring(seg(t, STAMP, STAMP + .30), 1.5, 5.0) * (1 if t >= STAMP else 0)
        away = quad_in(seg(t, SLIDE, SLIDE + .20))
        sc *= lerp(1, .45, away)
        put(c, SPR["stamp"], lerp(422, 500, away), lerp(74, 52, away), sc * (1 + .12 * sqz), sc * (1 - .12 * sqz), alpha=seg(t, STAMP - .12, STAMP - .06) * (1 - away))
        ud = seg(t, STAMP, STAMP + .26)
        if 0 < ud < 1:
            rr_ = 60 + 150 * expo_out(ud); a = int(220 * (1 - ud))
            overlay(c, lambda d: d.ellipse((S(422 - rr_), S(80 - rr_ * .30), S(422 + rr_), S(80 + rr_ * .30)), outline=rgb(CREAM) + (a,), width=S(3)))
    # the result card
    if t >= SLIDE + .12:
        k = back_out(seg(t, SLIDE + .12, SLIDE + .30), 2.0)
        f = font("xb", 10.5); s = "RARE  ·  NEW FRIEND"; w = c.tw(s, f) + 26
        st = B.blank(int(w + 30), 50); st.sticker((w + 30) / 2, 25, w, 24, s, face=TIER["Rare"][0], tilt=-3, f=f)
        put(c, st.im, 420 + w / 2, 52, k, k)
    if t >= NAME:
        k = back_out(seg(t, NAME, NAME + .20), 2.2); put(c, SPR["name"], 420 + 130 * k, 106, k, k)
    rise = expo_out(seg(t, SLIDE + .25, SLIDE + .55))
    if rise > 0:
        dy = round(70 * (1 - rise))
        if t >= NAME + .10: c.text((420, 148), "All ears, mostly for snacks.", font("m", 14), WHITE)
        c.tray((420, 172 + dy, 820, 226 + dy), 12, fill=pal["tray"]); T.stone(c, 448, 199 + dy, 26, *B.STATS["Jump"])
        c.text((472, 191 + dy), "Loves Jump", font("disp", 14), WHITE); c.text((472, 209 + dy), "Jump snacks make it extra happy.", font("m", 12), pal["soft"])
        T.key(c, (420, 326 + dy, 616, 370 + dy), "Back", size=14); T.primary(c, (626, 326 + dy, 820, 370 + dy), "Meet Bunny")
        if rise >= 1: B.close(c); B.chip(c, 214, 348, "Drag to spin", fill=INK)
    if shake:                                                              # 3 px at the burst, 4 px at the stamp, both decaying
        amp = 3 * (1 - seg(t, BURST, BURST + .20)) * (t >= BURST) + 4 * (1 - seg(t, STAMP, STAMP + .18)) * (t >= STAMP)
        if amp > .05:
            ox, oy = round(S(amp) * math.sin(t * 97)), round(S(amp) * math.cos(t * 83))
            bg = Image.new("RGB", c.im.size, rgb(pal["lip"])); bg.paste(c.im, (ox, oy)); c.im = bg; c._redraw()
    return c

def beat(t):
    for end, name in ((LIFT, "CRACKS  (as before)"), (FREEZE, "WIND-UP  orbit tightens, deck light shafts fan out"), (BURST, "FREEZE  0.12 s at one-tenth speed"),
                      (POP, "BURST  frame punches open, one bloom, shockwave ring"), (STAMP, "POP + CONFETTI CANNONS  left 1.95, right 2.07"),
                      (SLIDE, "STAMP SLAM  2.30"), (NAME, "SLIDE TO SEAT"), (99, "NAME, BUTTONS LIVE  3.15")):
        if t < end: return name

def video():
    fps, t0, t1 = 60, 0.80, 4.20; n = int(round((t1 - t0) * fps)); bar = 26
    mp4 = os.path.join(HERE, "08-rare-jackpot-preview.mp4"); gif = os.path.join(HERE, "08-rare-jackpot-preview.gif")
    audio = os.path.join(HERE, "audio", "rare-jackpot-over-rare-cue.wav")
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (W * 2, (H + bar) * 2), "-r", str(fps), "-i", "-"]
    if os.path.exists(audio): cmd += ["-ss", "%.3f" % (t0 - (BURST - 1.05)), "-i", audio, "-c:a", "aac", "-b:a", "192k"]   # the layer starts at 0.67 on the clock
    cmd += ["-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "17", "-preset", "slow", "-t", "%.3f" % (t1 - t0), "-movflags", "+faststart", mp4]
    ff = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    for i in range(n):
        t = t0 + i / fps; c = jackpot_frame(t)
        out = Image.new("RGB", (S(W), S(H + bar)), rgb("#15152A")); out.paste(c.im, (0, 0)); d = ImageDraw.Draw(out)
        d.text((S(12), S(H + bar / 2)), "%.2f s" % t, font=font("mono", 12), fill=rgb(LEMON), anchor="lm")
        d.text((S(70), S(H + bar / 2)), beat(t), font=font("xb", 11), fill=rgb(CREAM), anchor="lm")
        d.text((S(W - 12), S(H + bar / 2)), "drawn preview, not a Studio capture", font=font("m", 10.5), fill=rgb("#9AA0C8"), anchor="rm")
        ff.stdin.write(out.resize((W * 2, (H + bar) * 2), Image.LANCZOS).tobytes())
        if i % 40 == 0: print("frame %d/%d" % (i, n), flush=True)
    ff.stdin.close(); ff.wait(); print("wrote", os.path.basename(mp4))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", mp4, "-vf",
                    "fps=25,scale=720:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=160[p];[b][p]paletteuse=dither=bayer:bayer_scale=4", gif], check=True)
    print("wrote", os.path.basename(gif))

def jackpot_strip():
    shots = ((1.45, "0.95 to 1.60  WIND-UP", "Egg lifts 10 px. Eight stones and four sparkles orbit, tightening and speeding up. Deck-colour light shafts fan out behind the well."),
             (1.70, "1.60 to 1.72  FREEZE", "Everything drops to one-tenth speed for 0.12 s. The egg squashes 14% (anticipation). The new layer goes silent."),
             (1.78, "1.72  BURST", "The frame punches open 24 px, one bloom inside the well, a shockwave ring crosses the screen, the stones fly, the edge goes rainbow."),
             (2.24, "1.80 to 2.30  POP AND CANNONS", "The pet pops (silhouette, then colour). Confetti cannons fire from the left corner at 1.95 and the right at 2.07."),
             (2.34, "2.30  STAMP SLAM", "RARE! falls from 2.6x in 0.12 s, hits with a 4 px shake and a 12% squash, and the fanfare chord lands with it."),
             (3.70, "2.80 to 3.15  SEAT AND NAME", "The well slides to its seat, the stamp shrinks into the sticker, the name pops, the buttons rise and go live at 3.15."))
    frames = [(jackpot_frame(t, shake=False), title, note) for t, title, note in shots]
    return B.strip(frames, 3, "05-rare-jackpot-strip.png", "Rare JACKPOT, six frames from the motion preview  ·  Toy Shell, Classic deck  ·  phone 844x390 at 2x  ·  a drawing, not a Studio capture")

# ---------- the vibrant stages sheet ----------
def stages_sheet():
    cw, pad = 250, 22; Wc, Hc = pad + 4 * (cw + pad), 566
    c = T.Canvas(Wc, Hc, fill="#15152A")
    c.text((pad, 26), "Item preview stages: the dull berry (before) and the three vibrant tier stages (Revision 1)", font("disp", 15), CREAM)
    items = {"Common": B.fit(B.JAR, 124), "Uncommon": B.fit(B.SNACK, 128), "Rare": B.fit(B.BUNNY, 150)}
    bun, toy = B.fit(B.BUNNY, 74), B.silhouette(B.fit(B.SNACK, 60), "#3A2A4A")
    for i, tier in enumerate((None, "Common", "Uncommon", "Rare")):
        x = pad + i * (cw + pad); box = (x, 50, x + cw, 276); cx = x + cw / 2
        if tier is None:
            B.stage(c, box, tier="Common", burst=.7); im = items["Common"]; head, sub = "BEFORE  berry #4A1D3A", "fixed for every tier"
        else:
            vstage(c, box, tier, rot=8); im = items[tier]; head, sub = "%s  ·  %s" % (tier.upper(), PAL[tier]["name"]), PAL[tier]["pattern"] + " on the edge only"
            item_lip(c, im, cx, 236)
        put(c, im, cx, 236, base=True)
        c.text((x, 298), head, font("xb", 12), LEMON if tier else "#9AA0C8"); c.text((x, 315), sub, font("m", 11), "#DCE5FF")
        for j, (spr, lab) in enumerate(((bun, "white pet"), (toy, "dark toy"))):
            mb = (x + j * (cw / 2 + 3), 330, x + j * (cw / 2 + 3) + cw / 2 - 3, 432); mx = (mb[0] + mb[2]) / 2
            if tier is None: B.stage(c, mb, pool=False)
            else:
                vstage(c, mb, tier, rot=8, pool=False, r=14); item_lip(c, spr, mx, 420)
            put(c, spr, mx, 420, base=True)
        if tier is None:
            c.text((x, 452), "white 13.9 : 1, but the stage is the", font("m", 11), "#DCE5FF"); c.text((x, 468), "same dark plum behind every item,", font("m", 11), "#DCE5FF")
            c.text((x, 484), "and dark toys sink into it (1.3 : 1)", font("m", 11), "#DCE5FF"); continue
        p = PAL[tier]
        for j, k in enumerate(("core", "edge", "ray", "floor")):
            sx = x + j * 63; c.rr((sx, 446, sx + 57, 476), 7, fill=INK); c.rr((sx + 2, 448, sx + 55, 474), 5, fill=p[k])
            c.text((sx + 28.5, 488), k, font("xb", 10), CREAM, "mm"); c.text((sx + 28.5, 503), p[k], font("mono", 9.5), "#DCE5FF", "mm")
        c.text((x, 526), "behind the item: white %.1f : 1, ink %.1f : 1" % (T.contrast(p["core"], WHITE), T.contrast(p["core"], INK)), font("m", 11), "#DCE5FF")
        c.text((x, 544), "rim stays the tier colour %s" % TIER[tier][0], font("m", 11), "#DCE5FF")
    im = c.out(); im.save(os.path.join(HERE, "06-vibrant-preview-stages.png"), optimize=True); print("wrote 06", im.size); return im

# ---------- transitions ----------
def shop(pal, pressed=False, lift=0.0, hide_egg=False, focus=True):
    c = B.shell_bg(pal, 3)
    c.plate(34, 34, "HATCH EGGS", font("disp", 16), pal["tag"]); T.wallet(c, (700, 20, 820, 48), "240")
    for i, (name, price, egg) in enumerate((("Toy Egg", 20, B.fit(B.EGG, 108)), ("Stat Egg", 15, B.fit(B.STATEGG, 108)), ("Customization Egg", 12, B.fit(B.EGG, 108)))):
        x = 34 + i * 262; sel = i == 1
        c.toy((x, 66, x + 250, 300), 14, CREAM, T.CREAM_LIP, lip=4)
        if sel and focus: c.focus((x, 66, x + 250, 300), 14, lip=4)
        B.stage(c, (x + 12, 78, x + 238, 216), pool=False) if False else vstage(c, (x + 12, 78, x + 238, 216), "Common", rot=6, rays=.6, pool=False, r=12)
        if not (sel and hide_egg): put(c, egg, x + 125, 206 - (lift if sel else 0), base=True)
        c.text((x + 16, 238), name, font("disp", 14), INK)
        kb = (x + 16, 256, x + 234, 288)
        if sel and pressed: c.toy(kb, 9, T.GO, T.GO_LIP, lip=3, pressed=True); c.text((x + 125, 275), "Hatch   %d" % price, font("disp", 13), INK, "mm")
        elif sel: T.primary(c, kb, "Hatch   %d" % price, glyph=None, size=13, lip=3)
        else: T.key(c, kb, "Hatch   %d" % price, size=13)
    c.text((34, 340), "Simplified egg shop, drawn only to show where the transition starts and ends.", font("m", 11.5), pal["soft"])
    return c

def lid(c, pal, p, off=0):
    """Two shell halves closing like a toy lid. p = 0 open, 1 shut."""
    if p <= 0: return
    face = B.shell_bg(pal, off).im; hh = H / 2 * p
    top = face.crop((0, S(H / 2 - hh), S(W), S(H / 2))); bot = face.crop((0, S(H / 2), S(W), S(H / 2 + hh)))
    c.im.paste(top, (0, 0)); c.im.paste(bot, (0, S(H - hh))); c._redraw()
    for y, sgn in ((hh, -1), (H - hh, 1)):
        c.d.rectangle((0, S(min(y, y - sgn * 7)), S(W), S(max(y, y - sgn * 7))), fill=rgb(pal["lip"]))
        c.d.rectangle((0, S(y - 1.5), S(W), S(y + 1.5)), fill=rgb(INK))
        c.d.rectangle((0, S(y - sgn * 7 - 1), S(W), S(y - sgn * 7 + 1)), fill=rgb(mix(pal["shell"], WHITE, .35)))
    if p >= 1:
        c.rr((W / 2 - 34, H / 2 - 9, W / 2 + 34, H / 2 + 11), 10, fill=INK); c.rr((W / 2 - 32, H / 2 - 7, W / 2 + 32, H / 2 + 7), 8, fill=CREAM)

def iris(outer, inner, cx, cy, rad, pal):
    """Show `inner` through a round hole in `outer`, with an ink and cream ring."""
    m = Image.new("L", outer.im.size, 0); ImageDraw.Draw(m).ellipse((S(cx - rad), S(cy - rad), S(cx + rad), S(cy + rad)), fill=255)
    outer.im = Image.composite(inner.im, outer.im, m); outer._redraw()
    if rad > 2:
        outer.ellipse((cx - rad - 5, cy - rad - 5, cx + rad + 5, cy + rad + 5), outline=INK, width=5.5)
        outer.ellipse((cx - rad - 3.4, cy - rad - 3.4, cx + rad + 3.4, cy + rad + 3.4), outline=CREAM, width=2.4)
    return outer

def hatch_ready(pal):
    c = B.shell_bg(pal, 6); vstage(c, B.CENTRE, "Common", rot=4, rays=.35, rim=.25)
    egg = B.fit(B.STATEGG, 150); item_lip(c, egg, 422, 314); put(c, egg, 422, 314, base=True)
    B.chip(c, 84, 36, "STAT EGG", fill=pal["tag"], text=INK); return c

def transition_strip():
    pal = B.CLASSIC; egg = B.fit(B.STATEGG, 150); small = B.fit(B.STATEGG, 108); out = []
    c = shop(pal, pressed=True, lift=6)
    out.append((c, "IN  0.00  PRESS", "The Hatch key goes down 3 px for 60 ms. The chosen egg lifts 6 px off its card (anticipation)."))
    c = shop(pal, pressed=True, hide_egg=True, focus=False); lid(c, pal, quad_in(.14 / .22) * 1.25, 4)
    put(c, small, lerp(421, 422, .5), lerp(152, 195, .55), 1.18, 1.18)
    out.append((c, "IN  0.14  LID CLOSING", "Two shell halves close from top and bottom, Quad In, 0.22 s. The egg rides on top, growing from 108 to 150 px."))
    c = shop(pal, hide_egg=True, focus=False); lid(c, pal, 1, 6); put(c, egg, 422, 262, 1.12, .88, base=True)
    for sgn in (-1, 1):
        for k in range(3): c.line([(422 + sgn * (96 + k * 16), 190 + k * 22), (422 + sgn * (120 + k * 16), 184 + k * 22)], WHITE, 2.6 - k * .6)
    B.chip(c, 422, 352, "the lid stays shut here until the server answers", fill=INK)
    out.append((c, "IN  0.22  CLACK", "Lid shut: 6 px overshoot, settles in 0.10 s. The egg lands with a 12% squash. This is also the waiting state."))
    c = shop(pal, hide_egg=True, focus=False); lid(c, pal, 1, 7); iris(c, hatch_ready(pal), 422, 222, 40 + 420 * expo_out(.10 / .30) * .42, pal)
    out.append((c, "IN  0.32  IRIS OPENS", "A round window opens from the egg, Exponential Out, 0.30 s, showing the stage already drawn underneath."))
    out.append((hatch_ready(pal), "IN  0.52  HATCH CLOCK 0.00", "The hatch stage, egg in the well. The first rock starts at 0.12 as before. Added time before the hatch: 0.52 s."))
    card = jackpot_frame(4.2, shake=False)
    c = jackpot_frame(4.2, shake=False); c.toy((626, 326, 820, 370), 10, T.GO, T.GO_LIP, lip=4, pressed=True); c.text((723, 352), "Meet Bunny", font("disp", 14), INK, "mm")
    out.append((c, "OUT  0.00  PRESS", "The pressed button goes down 3 px for 60 ms. Sparkles and sheen stop; nothing else moves yet."))
    shut = B.shell_bg(pal, 8); lid(shut, pal, 1, 8)
    c = iris(shut, card, 214, 166, 400 * (1 - expo_in(.10 / .24)) * .46 + 20, pal)
    out.append((c, "OUT  0.10  IRIS CLOSES", "The window closes on the item, Exponential In, 0.24 s. Outside it is the shut lid in the deck colour."))
    shut = B.shell_bg(pal, 9); lid(shut, pal, 1, 9); c = iris(shut, card, 214, 150, 44, pal)
    out.append((c, "OUT  0.24  HELD", "The window holds at 44 px on the pet's face for 0.06 s (follow-through), then pops shut. Destination loads behind the lid."))
    c = shop(pal, focus=True); lid(c, pal, 1 - expo_out(.12 / .26) * .62, 10)
    out.append((c, "OUT  0.42  LID OPENS", "The halves open, Exponential Out, 0.26 s, onto wherever the player came from (here the egg shop)."))
    c = shop(pal, focus=True)
    out.append((c, "OUT  0.56  BACK", "Focus is on the egg card that was used. Meet, Feed now and Use now use the same wipe into pet focus or Customize."))
    return B.strip(out, 5, "07-transition-in-out-strip.png", "Into and out of the hatch: toy lid in, iris out  ·  Toy Shell, Classic deck  ·  phone 844x390 at 2x  ·  a drawing, not a Studio capture")

def main():
    sprites()
    for tier, p in PAL.items():
        print(tier, p["name"], "core vs white %.2f, vs ink %.2f, edge vs white %.2f" % (T.contrast(p["core"], WHITE), T.contrast(p["core"], INK), T.contrast(p["edge"], WHITE)))
    if "--video-only" not in sys.argv:
        stages_sheet(); jackpot_strip(); transition_strip()
    if "--no-video" not in sys.argv: video()

if __name__ == "__main__":
    main()
