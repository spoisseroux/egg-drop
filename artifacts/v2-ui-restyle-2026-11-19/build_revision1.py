"""Toy Shell, Revision 1 (2026-11-19, Fable as Astra). Proposal drawings only: nothing is built.

1. A Toy Shell palette for each of the 18 faceplates in DeckThemes.Order, plus the fixed Classic Shell.
   Hue and saturation are chosen by hand per plate; brightness is SOLVED so every role sits at one fixed
   WCAG luminance. Every deck therefore has the same contrast ratios (checked and printed below).
2. Customize mockups in 6 decks + Classic (reuses build_mockups.py without editing it).
3. The scrolling checker tile (drawn here, 2x, seamless) and a 60-frame preview (GIF + MP4).

No generated art. Run from the repo root:  python artifacts/v2-ui-restyle-2026-11-19/build_revision1.py
"""
import colorsys, json, os, re, shutil, subprocess, sys, tempfile
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = open(os.path.join(HERE, "build_mockups.py"), encoding="utf-8").read()
SRC = re.sub(r"(?m)^(R, OUT = .*)$", r"\1\nR, OUT = _OV.get('R', R), _OV.get('OUT', OUT)", SRC, count=1)
SRC = re.sub(r"(?m)^(DISABLED, DISABLED_LIP.*)$", r"\1\nglobals().update(_OV.get('tokens', {}))", SRC, count=1)
assert "_OV.get('tokens'" in SRC and "_OV.get('R'" in SRC


def kit(tokens=None, R=4, OUT=2):
    """A private copy of build_mockups with its tokens replaced before any drawing code is defined."""
    ns = {"__name__": "bm", "__file__": os.path.join(HERE, "build_mockups.py"), "_OV": {"tokens": tokens or {}, "R": R, "OUT": OUT}}
    exec(compile(SRC, "build_mockups.py", "exec"), ns)
    return ns


def rgb(c): c = c.lstrip("#"); return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))
def hx(t): return "#%02X%02X%02X" % tuple(int(round(v)) for v in t)
def mix(a, b, t): a, b = rgb(a), rgb(b); return hx([a[i] + (b[i] - a[i]) * t for i in range(3)])
def lum(c):
    v = [x / 255 for x in rgb(c)]
    v = [x / 12.92 if x <= .03928 else ((x + .055) / 1.055) ** 2.4 for x in v]
    return .2126 * v[0] + .7152 * v[1] + .0722 * v[2]
def contrast(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True); return (la + .05) / (lb + .05)
def hsv(h, s, v): return hx([x * 255 for x in colorsys.hsv_to_rgb((h % 360) / 360, s, v)])
def solve(h, s, target):
    """The colour of hue h, saturation s whose WCAG luminance is `target` (s gives way if v=1 is too dark)."""
    while lum(hsv(h, s, 1)) < target and s > 0: s = max(0, s - .02)
    lo, hi = 0.0, 1.0
    for _ in range(40):
        mid = (lo + hi) / 2
        if lum(hsv(h, s, mid)) < target: lo = mid
        else: hi = mid
    return hsv(h, s, hi)


# ---- fixed house colours (same on every deck) ----
CREAM, CREAM_LIP, WHITE = "#FFF4DC", "#D6C196", "#FFFFFF"
LEMON, LEMON_LIP, STARS = "#FFE14D", "#D9A31C", "#FFC14D"
GO, GO_LIP, TOMATO, TOMATO_TEXT = "#43DB5F", "#1C8F3C", "#FF5A4D", "#B3261E"
STAGE, STAGE_DOT, STAGE_GLOW = "#4A1D3A", "#7A3458", "#FFB26B"   # warm berry behind every preview and reveal; never deck-tinted

# luminance each role is solved to (so the ratios below hold on every deck)
L = dict(shell=.131, shellHi=.36, shellLip=.042, tray=.058, well=.0105, wellDot=.040, ink=.009, inkSoft=.080, onShellSoft=.80)

# id: (shell hue, shell saturation, tag colour, note). Hue and tag are hand-tuned from the plate's deep / face / accent.
PLATES = {
    "sherbet":       (166, .88, "#A4F57C", "jade from deep; accent is the retired mint, so the tag moves to spring green"),
    "stone":         (140, .40, "#C9F08A", "grey-green plate: saturation raised .31 to .40 (sage), tag saturation raised"),
    "ice":           (192, .82, "#70ECFF", "cyan side of the three blues"),
    "brick":         (356, .76, "#FF9B70", "red from face and deep"),
    "moss":          (128, .70, "#BCF57B", "leaf green, pushed off jade"),
    "honey":         (34,  .94, "#FF9838", "yellow cannot hold white text, so the shell is caramel; tag is orange, not gold (Stars)"),
    "gloaming":      (240, .52, "#92ECE6", "dusk periwinkle"),
    "copperleaf":    (16,  .74, "#FFBC90", "copper from face, not the maroon deep"),
    "aqua_pop":      (205, .92, "#6FE3FF", "azure"),
    "lime_gel":      (96,  .88, "#B6F24B", "lime from deep"),
    "sorbet_sky":    (338, .72, "#FFB37A", "raspberry from deep, peach tag"),
    "liquid_chrome": (218, .40, "#DCE6F5", "grey plate: steel blue shell, the tag stays silver on purpose"),
    "tidepool":      (216, .86, "#5CD6E8", "ocean blue"),
    "aurora_glass":  (244, .72, "#A8F27A", "navy deep lifted to indigo (kept off Classic blue); mint accent moved to aurora green"),
    "prism_flare":   (296, .56, "#F3B6FF", "orchid"),
    "night_orb":     (262, .74, "#FF7AD9", "near-black deep lifted to violet; hot pink tag"),
    "grape_soda":    (276, .62, "#C9A6FF", "grape"),
    "rose_chrome":   (330, .50, "#FFC2D4", "pale plate: dusty rose shell at full depth, pink tag"),
}
ORDER = ["sherbet", "stone", "ice", "brick", "moss", "honey", "gloaming", "copperleaf", "aqua_pop", "lime_gel", "sorbet_sky",
         "liquid_chrome", "tidepool", "aurora_glass", "prism_flare", "night_orb", "grape_soda", "rose_chrome"]
NAMES = {"sherbet": "Scout", "stone": "Pebble", "ice": "Creek", "brick": "Ember", "moss": "Canopy", "honey": "Honey", "gloaming": "Gloaming",
         "copperleaf": "Copperleaf", "aqua_pop": "Aqua Pop", "lime_gel": "Lime Gel", "sorbet_sky": "Sorbet Sky", "liquid_chrome": "Liquid Chrome",
         "tidepool": "Tidepool", "aurora_glass": "Aurora Glass", "prism_flare": "Prism Flare", "night_orb": "Night Orb", "grape_soda": "Grape Soda",
         "rose_chrome": "Rose Chrome"}
CLASSIC = dict(shell="#2E55E6", shellHi="#7C9BFF", shellLip="#1A2F9C", tray="#1D36A6", well="#10133A", wellDot="#2A2F6B", ink="#15143A",
               inkSoft="#4A4972", onShellSoft="#DCE5FF", tag="#FF8FC0", tagLip=mix("#FF8FC0", "#15143A", .38))
FIELDS = ["shell", "shellHi", "shellLip", "tray", "well", "wellDot", "ink", "inkSoft", "onShellSoft", "tag", "tagLip"]


def palette(pid):
    h, s, tag, _ = PLATES[pid]
    wh = 222 if 140 <= h <= 200 else h          # green and cyan decks get a navy LCD: no grey-teal glass anywhere
    p = dict(shell=solve(h, s, L["shell"]), shellHi=solve(h, s * .55, L["shellHi"]), shellLip=solve(h, min(1, s * 1.05), L["shellLip"]),
             tray=solve(h, min(1, s * 1.02), L["tray"]), well=solve(wh, .70, L["well"]), wellDot=solve(wh, .58, L["wellDot"]),
             ink=solve(h, .62, L["ink"]), inkSoft=solve(h, .40, L["inkSoft"]), onShellSoft=solve(h, .14, L["onShellSoft"]), tag=tag)
    p["tagLip"] = mix(tag, p["ink"], .38)
    return p


PAIRS = [  # (label, fg, bg, floor)
    ("white/shell", lambda p: WHITE, "shell", 4.5), ("soft/shell", "onShellSoft", "shell", 4.5), ("white/tray", lambda p: WHITE, "tray", 4.5),
    ("soft/tray", "onShellSoft", "tray", 4.5), ("white/lip", lambda p: WHITE, "shellLip", 4.5), ("stars/tray", lambda p: STARS, "tray", 4.5),
    ("stars/well", lambda p: STARS, "well", 4.5), ("white/well", lambda p: WHITE, "well", 4.5),
    ("ink/cream", "ink", lambda p: CREAM, 4.5), ("inkSoft/cream", "inkSoft", lambda p: CREAM, 4.5), ("ink/lemon", "ink", lambda p: LEMON, 4.5),
    ("inkSoft/lemon", "inkSoft", lambda p: LEMON, 4.5), ("ink/tag", "ink", "tag", 4.5), ("ink/go", "ink", lambda p: GO, 4.5),
    ("white/stage", lambda p: WHITE, lambda p: STAGE, 4.5), ("stars/stage", lambda p: STARS, lambda p: STAGE, 4.5),
    ("outline/shell", "ink", "shell", 3.0), ("lemon/shell", lambda p: LEMON, "shell", 3.0),
]
DOC_COLS = ["white/shell", "soft/shell", "soft/tray", "stars/tray", "stars/well", "inkSoft/cream", "inkSoft/lemon", "ink/tag", "white/well", "outline/shell"]


def check(p):
    get = lambda k: k(p) if callable(k) else p[k]
    return {name: (contrast(get(a), get(b)), floor) for name, a, b, floor in PAIRS}


def tokens(p):
    return dict(SHELL=p["shell"], SHELL_HI=p["shellHi"], SHELL_LIP=p["shellLip"], TRAY=p["tray"], WELL=p["well"], WELL_DOT=p["wellDot"],
                INK=p["ink"], INK_SOFT=p["inkSoft"], ON_SHELL_SOFT=p["onShellSoft"], PINK=p["tag"])


# ---------------- the moving pattern ----------------
TILE_PX, SPEED = 32, 8          # tile 32 px (two 16 px squares each way); 8 px/s on each axis = 11.3 px/s on the diagonal; loop 4 s
def make_tile():
    """64 x 64 (2x of a 32 px tile): white squares on transparent, two per side, so it tiles on both axes with no seam."""
    t = Image.new("RGBA", (64, 64), (255, 255, 255, 0)); d = ImageDraw.Draw(t)
    d.rectangle((0, 0, 31, 31), fill=(255, 255, 255, 255)); d.rectangle((32, 32, 63, 63), fill=(255, 255, 255, 255))
    t.save(os.path.join(HERE, "toy-checker-tile-32@2x.png"))
    a = np.asarray(t)[..., 3]                                    # seam proof: shifting by half a tile on both axes is the same image
    assert (np.roll(a, (32, 32), (0, 1)) == a).all() and (np.tile(a, (2, 2))[32:96, 32:96] == a).all()
    return t


def patch(ns, tile, state):
    """Draw the checker from the real tile at a scroll offset; previews sit on the warm stage with drifting dots."""
    S, Canvas = ns["S"], ns["Canvas"]
    def checker(self, box, r, a, b, size=12, fade=(1.0, .35), o=3):
        x0, y0, x1, y1 = (S(v) for v in box); w, h = x1 - x0, y1 - y0
        n = S(TILE_PX); al = np.asarray(tile.resize((n, n), Image.NEAREST))[..., 3].astype(np.float32) / 255
        big = np.tile(al, (h // n + 3, w // n + 3)); off = int(round(S(state["t"] * SPEED % TILE_PX)))
        m = big[n - off:n - off + h, n - off:n - off + w] * np.linspace(fade[0], fade[1], h, dtype=np.float32)[:, None]
        mask = Image.new("L", (w, h), 0)
        ImageDraw.Draw(mask).rounded_rectangle((S(o), S(o), w - S(o) - 1, h - S(o) - 1), S(r - o), fill=255)
        m = (m * np.asarray(mask, dtype=np.float32)).astype(np.uint8)
        self.im.paste(Image.new("RGB", (w, h), ns["rgb"](b)), (x0, y0), Image.fromarray(m, "L")); self._redraw()
    plain = Canvas.well
    def well(self, box, r, o=2, dots=True, fill=None):
        if not dots: return plain(self, box, r, o, False, ns["WELL"])
        x0, y0, x1, y1 = box; w, h = S(x1 - x0), S(y1 - y0)
        self.rr(box, r, fill=ns["INK"])
        lay = Image.new("RGB", (w, h), rgb(STAGE)); d = ImageDraw.Draw(lay); off = (state["t"] * 3) % 6
        y = off - 6
        while y < (y1 - y0) + 6:
            x = off - 6
            while x < (x1 - x0) + 6:
                d.ellipse((S(x - .7), S(y - .7), S(x + .7), S(y + .7)), fill=rgb(STAGE_DOT)); x += 6
            y += 6
        mask = Image.new("L", (w, h), 0); ImageDraw.Draw(mask).rounded_rectangle((S(o), S(o), w - S(o) - 1, h - S(o) - 1), S(r - o), fill=255)
        self.im.paste(lay, (S(x0), S(y0)), mask); self._redraw()
        self.line([(x0 + r * .8, y1 - o - 2.2), (x1 - r * .8, y1 - o - 2.2)], mix(STAGE, WHITE, .16), 1.2)
    Canvas.checker, Canvas.well = checker, well


def customize(p, tile, t=0.0, R=3, OUT=1.5):
    ns = kit(tokens(p), R, OUT); patch(ns, tile, {"t": t})
    _, c = ns["screen_customize"]()
    return c.im.resize((round(c.w * OUT), round(c.h * OUT)), Image.LANCZOS), ns


def swatch_sheet(pals, tile):
    cw, ch, cols = 372, 96, 3
    ids = ORDER + ["classic"]; rows = -(-len(ids) // cols)
    base = kit(R=3, OUT=1)
    sheet = Image.new("RGB", (cw * cols * 2 + 32, rows * ch * 2 + 96), rgb("#15152A")); d = ImageDraw.Draw(sheet)
    d.text((16, 14), "Toy Shell: one palette per Pocket Deck (18) + Classic Shell", font=base["font"]("disp", 13, 2), fill=(255, 255, 255))
    d.text((16, 52), "Each card: tag plate, white and soft text on the shell, tray with LCD wallet, cream key, lemon selected key. Cream, lemon, go and Stars gold never change.",
           font=base["font"]("xb", 8, 2), fill=rgb("#AEB4D6"))
    for i, pid in enumerate(ids):
        p = pals[pid]; ns = kit(tokens(p), 4, 2); patch(ns, tile, {"t": 0}); f = ns["font"]
        c = ns["Canvas"](cw, ch, fill="#15152A")
        c.toy((4, 4, 368, 86), 14, p["shell"], p["shellLip"], lip=4, o=3, glint=False)
        c.checker((4, 4, 368, 86), 14, p["shell"], mix(p["shell"], WHITE, .09))
        c.plate(18, 24, "Classic Shell" if pid == "classic" else NAMES[pid], f("disp", 12), p["tag"], h=22)
        c.text((356, 18), "white text", f("b", 9.5), WHITE, "rm"); c.text((356, 31), "soft text  " + p["shell"], f("m", 9), p["onShellSoft"], "rm")
        c.tray((14, 44, 150, 78), 9)
        c.text((23, 56), "Tray title", f("disp", 10), WHITE); c.text((23, 68.5), "soft line", f("m", 8.5), p["onShellSoft"])
        c.text((141, 62), "172", f("mono", 10), STARS, "rm")
        ns["wallet"](c, (158, 46, 226, 74), "172")
        ns["key"](c, (234, 46, 294, 71), "Key", r=9, size=10.5)
        ns["key"](c, (302, 46, 358, 71), "On", r=9, size=10.5, face=LEMON, lip_col=LEMON_LIP)
        sheet.paste(c.out(), (16 + (i % cols) * cw * 2, 88 + (i // cols) * ch * 2))
    sheet.save(os.path.join(HERE, "06-toy-shell-18-deck-palettes.png"), optimize=True); print("wrote swatches", sheet.size)


def mock_sheet(pals, tile):
    picks = [("sherbet", "Scout (the default deck)"), ("brick", "Ember"), ("honey", "Honey"), ("stone", "Pebble"), ("night_orb", "Night Orb"),
             ("liquid_chrome", "Liquid Chrome"), ("rose_chrome", "Rose Chrome"), ("classic", "Classic Shell (Settings: fixed blue)")]
    base = kit(R=3, OUT=1); f = base["font"]
    ims = []
    for pid, _ in picks:
        im, _ns = customize(pals[pid], tile); ims.append(im)
        im.save(os.path.join(HERE, "07-customize-%s.png" % pid.replace("_", "-")), optimize=True)
    w, h = ims[0].size; pad, head, cap = 20, 64, 34
    sheet = Image.new("RGB", (w * 2 + pad * 3, head + (h + cap + pad) * 4), rgb("#15152A")); d = ImageDraw.Draw(sheet)
    d.text((pad, 16), "Customize in seven deck colours and Classic Shell. Same rects; previews sit on the fixed warm stage.", font=f("disp", 12, 2), fill=(255, 255, 255))
    for i, (im, (pid, label)) in enumerate(zip(ims, picks)):
        x, y = pad + (i % 2) * (w + pad), head + (i // 2) * (h + cap + pad)
        d.text((x, y + 6), label, font=f("xb", 10, 2), fill=rgb(LEMON))
        sheet.paste(im, (x, y + cap))
    sheet.save(os.path.join(HERE, "07-customize-deck-colours.png"), optimize=True); print("wrote mock sheet", sheet.size)


def animation(p, tile):
    frames = []
    for i in range(60):                                  # 60 frames at 15 fps = 4 s = exactly one tile of travel
        im, _ = customize(p, tile, t=i / 15, R=2, OUT=1); frames.append(im.crop((0, 24, 750, 402)))
    q = [f.quantize(colors=160, method=Image.MEDIANCUT, dither=Image.NONE) for f in frames]
    q[0].save(os.path.join(HERE, "08-grid-scroll-preview.gif"), save_all=True, append_images=q[1:], duration=67, loop=0, optimize=False)
    tmp = tempfile.mkdtemp()
    for i, f in enumerate(frames): f.save(os.path.join(tmp, "f%03d.png" % i))
    ff = shutil.which("ffmpeg")
    if ff:
        subprocess.run([ff, "-y", "-loglevel", "error", "-stream_loop", "2", "-framerate", "15", "-i", os.path.join(tmp, "f%03d.png"),
                        "-vf", "scale=1500:756:flags=neighbor,fps=30", "-pix_fmt", "yuv420p", "-crf", "16",
                        os.path.join(HERE, "08-grid-scroll-preview.mp4")], check=True)
    shutil.rmtree(tmp, ignore_errors=True)
    a, b = np.asarray(frames[0]).astype(int), np.asarray(customize(p, tile, t=4.0, R=2, OUT=1)[0].crop((0, 24, 750, 402))).astype(int)
    print("loop check: frame 60 equals frame 0:", int(np.abs(a - b).max()) == 0)


def main():
    pals = {pid: palette(pid) for pid in ORDER}; pals["classic"] = dict(CLASSIC)
    bad = []; rows = []
    for pid in ORDER + ["classic"]:
        r = check(pals[pid]); bad += [(pid, k, round(v, 2)) for k, (v, floor) in r.items() if v < floor and (pid, k) != ("classic", "outline/shell")]  # Classic is the approved blue, unchanged: its ornamental outline measures 2.98
        rows.append("| %s | %s | %.2f |" % (pid, " | ".join("%.1f" % r[k][0] for k in DOC_COLS), min(v / fl for v, fl in r.values()) ))
    print("| plate | " + " | ".join(DOC_COLS) + " | worst / floor |"); print("\n".join(rows))
    print("fixed pairs:", {k: round(v[0], 1) for k, v in check(pals["sherbet"]).items() if k in ("ink/go", "white/stage", "stars/stage")})
    print("FAILURES:", bad or "none", "| pairs checked:", len(PAIRS) * 19)
    lua = ["-- proposed: Plates[id].toyShell (Astra, Revision 1). Generated by artifacts/v2-ui-restyle-2026-11-19/build_revision1.py"]
    for pid in ORDER:
        lua.append(" %s={%s}, -- %s" % (pid, ",".join('%s="%s"' % (k, pals[pid][k]) for k in FIELDS), PLATES[pid][3]))
    open(os.path.join(HERE, "toy-shell-palettes.lua.txt"), "w", encoding="utf-8").write("\n".join(lua) + "\n")
    json.dump({"fixed": dict(cream=CREAM, creamLip=CREAM_LIP, onShell=WHITE, selected=LEMON, selectedLip=LEMON_LIP, stars=STARS, go=GO, goLip=GO_LIP,
                             tomato=TOMATO, tomatoText=TOMATO_TEXT, stage=STAGE, stageDot=STAGE_DOT, stageGlow=STAGE_GLOW),
               "classic": pals["classic"], "plates": {k: pals[k] for k in ORDER},
               "contrast": {pid: {k: round(v[0], 2) for k, v in check(pals[pid]).items()} for pid in ORDER + ["classic"]}},
              open(os.path.join(HERE, "toy-shell-palettes.json"), "w"), indent=1)
    print("\n".join(lua))
    if "--tables" in sys.argv: return
    tile = make_tile()
    swatch_sheet(pals, tile); mock_sheet(pals, tile); animation(pals["sherbet"], tile)


if __name__ == "__main__":
    main()
