"""Before / after mockups for UI-PERSONALITY-SCOPE-2026-11-13.md.

Run: python scripts/deck_art/build_ui_personality_mockups.py
Output: artifacts/ui-personality-2026-11-13/

"Before" is the approved mockup function, untouched (redesign menus, redesign celebrations, round items).
"After" runs the SAME function with the shared components swapped for the personality variants, so every
layout number stays where it is and only the proposed tweaks change:

  T1 display face (Fredoka One) on titles, names and button labels
  T2 pressable things get a bottom lip (tiles, secondary buttons, glyph caps); info cards get a stitched seam
  T3 copy voice (string table COPY)
  T4 the equipped pet peeks from one edge per screen
  T5 one tint per screen: eyebrow, title squiggle, halftone fade
  T6 sticker chips (price, tier, New best)
  T7 LCD dot grid in preview wells
  T9 the Star has a face at 20 px and up

Concept drawings, not Studio captures.
"""
from __future__ import annotations

import math
from contextlib import contextmanager

from PIL import Image

import build_mockups as M
import build_redesign_celebration_mockups as K
import build_redesign_menu_mockups as R
import build_round_items_mockups as I
import common
from build_compact_mockups import kit_theme
from common import ROOT, Cv, hx, icon, mix, INK, STAR, TEXT

OUT = ROOT / "artifacts" / "ui-personality-2026-11-13"
common.FONT_FILES["disp"] = common._find(common._RBX + r"\FredokaOne-Regular.ttf") or common.FONT_FILES["xb"]

TINT = {"hatch": "#FFA98F", "deck": "#C9A7FF", "results": "#FFC14D"}
CREAM = "#FFF6E0"

DISPLAY = {"Hatch eggs", "Deck style", "Toy Egg", "Material Egg", "Hue Egg", "Smileys", "Marbles", "Gumdrops", "Gems", "Planets", "Kittens"}
COPY = {
    "Every egg lists its exact odds before you hatch it.": "Give one a shake. The odds are always on the label.",
    "Odds shown before you hatch": "The odds are on the label",
    "Fixed odds. Shown before you pay.": "No surprises. The odds never change.",
    "A new body finish": "A fresh coat for your pet",
    "Fixed prices. Looks only, never an advantage.": "Just for looks. Never an advantage.",
    "Same sizes, same rules. Looks only.": "Same sizes, same rules. Only cuter.",
    "Leave to garden": "Back to the garden",
    "Saved to your wallet": "Tucked into your wallet",
    "Medium pays 6 to 8": "Brave? Medium pays 6 to 8",
    "Replay keeps Easy. Up on Replay changes difficulty.": "Replay keeps Easy. Press Up to change it.",
}

ST = {"on": False, "lip": True, "th": None, "tint": TINT["hatch"], "lipH": 4}
_text, _wrap, _rr = Cv.text, Cv.wrap, Cv.rr
_button, _card, _chip, _hints, _wallet, _lcd = M.button, M.card, M.chip, M.hints, M.wallet, M.lcd
_header, _well, _dpanel = R.header, R.well, R.dpanel


# ------------------------------------------------------------------ drawing helpers
def rr_path(x, y, w, h, r, step=1.0):
    """Points along a rounded rectangle, clockwise from the top-left arc end."""
    pts = []
    def seg(x0, y0, x1, y1):
        n = max(1, int(math.hypot(x1 - x0, y1 - y0) / step))
        pts.extend((x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n) for i in range(n))
    def arc(cx, cy, a0):
        n = max(2, int(r * math.pi / 2 / step))
        pts.extend((cx + r * math.cos(math.radians(a0 + 90 * i / n)), cy + r * math.sin(math.radians(a0 + 90 * i / n))) for i in range(n))
    seg(x + r, y, x + w - r, y); arc(x + w - r, y + r, -90)
    seg(x + w, y + r, x + w, y + h - r); arc(x + w - r, y + h - r, 0)
    seg(x + w - r, y + h, x + r, y + h); arc(x + r, y + h - r, 90)
    seg(x, y + h - r, x, y + r); arc(x + r, y + r, 180)
    return pts


def stitched(cv, x, y, w, h, r, color=(255, 255, 255, 30), dash=5, gap=6, sw=1.0, inset=6):
    """Plush seam: a dashed line just inside a card's edge."""
    pts = rr_path(x + inset, y + inset, w - 2 * inset, h - 2 * inset, max(2, r - inset))
    i = 0
    while i < len(pts):
        part = pts[i:i + dash + 1]
        if len(part) > 1:
            cv.line(part, color, sw, True)
        i += dash + gap


def squiggle(cv, x, y, w, color, amp=2.2, wave=11, sw=2.6):
    pts = [(x + i, y + amp * math.sin(i / wave * 2 * math.pi)) for i in range(int(w) + 1)]
    cv.line(pts, color, sw, True)


def halftone(cv, x, y, w, h, color, rows=8, pitch=9, alpha=26):
    """Print-style dot fade rising from the bottom edge of a rect."""
    c = hx(color)[:3]
    for j in range(rows):
        t = 1 - j / rows
        rad = .5 + 2.3 * t
        yy = y + h - 5 - j * pitch
        off = pitch / 2 if j % 2 else 0
        xx = x + 6 + off
        while xx < x + w - 4:
            cv.ell(xx, yy, rad, fill=c + (int(alpha * (.35 + .65 * t)),))
            xx += pitch


def dot_grid(cv, x, y, w, h, pitch=6, inset=7, alpha=15):
    """LCD pixel grid for preview windows."""
    yy = y + inset
    while yy <= y + h - inset:
        xx = x + inset
        while xx <= x + w - inset:
            cv.ell(xx, yy, .75, fill=(255, 255, 255, alpha))
            xx += pitch
        yy += pitch


def star_face(cv, cx, cy, s):
    """Two eyes (and a smile from 40 px) on the Stars star."""
    u = s / 24
    cy = cy + .6 * u
    for sx in (-1, 1):
        cv.ell(cx + sx * 2.7 * u, cy + .4 * u, 1.15 * u, 1.5 * u, fill=(70, 38, 0, 255))
    if s >= 40:
        cv.arc(cx, cy + 1.6 * u, 2.4 * u, 20, 160, (70, 38, 0, 255), 1.1 * u)
        for sx in (-1, 1):
            cv.ell(cx + sx * 5.2 * u, cy + 2.6 * u, 1.3 * u, .9 * u, fill=(255, 120, 120, 150))


def peek(cv, cx, floor_y, h, show, flip=False):
    """The equipped pet looking over an edge: only the top `show` px of an h-px sprite, cut at floor_y."""
    z = cv.z
    im = K.pet_sprite(round(h * z))
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    im = im.crop((0, 0, im.width, round(show * z)))
    cv.paste(im, round(cx * z - im.width / 2), round((floor_y - show) * z), raw=True)
    cv.refresh()


def cap(cv, x, y, letter, th, size=22):
    """Hint glyph drawn like the deck's own buttons: A is the mint cap, the rest are grey caps with a lip."""
    if letter in ("+", "<>", "<", ">", "^", "v", "^v"):
        return M.glyph(cv, x, y, letter, th, False, size)
    w = size if len(letter) == 1 else cv.tw(letter, "b", size * .5, .5) + size * .7
    a = letter == "A"
    face = th["accent"] if a else mix(th["raised"], "#FFFFFF", .16)
    _rr(cv, x, y + 2, w, size, size / 2, fill=mix(face, "#000000", .5))
    _rr(cv, x, y, w, size, size / 2, fill=face)
    _text(cv, x + w / 2, y + size / 2 + .5, letter, "b", size * (.58 if len(letter) == 1 else .5), th["ink"] if a else th["text"], "mm")
    return w


# ------------------------------------------------------------------ patched components
def p_text(self, x, y, s, key="r", size=16, fill=TEXT, anchor="la", tracking=0.0):
    if ST["on"]:
        s = COPY.get(s, s)
        if key in ("b", "xb") and s in DISPLAY:
            key = "disp"
    return _text(self, x, y, s, key, size, fill, anchor, tracking)


def p_wrap(self, x, y, s, width, key="r", size=16, fill=TEXT, lh=None, max_lines=3):
    return _wrap(self, x, y, COPY.get(s, s) if ST["on"] else s, width, key, size, fill, lh, max_lines)


def p_rr(self, x, y, w, h, r, fill=None, stroke=None, sw=1.0):
    th = ST["th"]
    if ST["on"] and th and fill is not None and stroke is None:
        f = self._c(fill)[:3]
        if ST["lip"] and r in (12, 14) and h >= 50 and f in (tuple(th["raised"][:3]), tuple(th["selected"][:3])):
            sel = f == tuple(th["selected"][:3])
            _rr(self, x, y + ST["lipH"], w, h, r, fill=mix(th["accent"], "#000000", .5) if sel else mix(th["raised"], "#000000", .55))
        _rr(self, x, y, w, h, r, fill, stroke, sw)
        if r in (8, 10) and w > 100 and f == tuple(th["well"][:3]):
            dot_grid(self, x, y, w, h, 5 if h < 50 else 6, 5 if h < 50 else 7)
        return
    _rr(self, x, y, w, h, r, fill, stroke, sw)


def p_button(cv, x, y, w, h, text, th, kind="secondary", st="idle", key=None, size=20, ico=None):
    r = 14 if h >= 50 else 12
    text = COPY.get(text, text)
    focus = st == "focus"
    if kind in ("primary", "reward"):
        fill = th["accent"] if kind == "primary" else th["star"]
        e = 6 if h >= 50 else 5
        _rr(cv, x, y, w, h, r, fill=mix(fill, "#000000", .46))
        _rr(cv, x, y, w, h - e, r, fill=fill)
        cv.grad_rr(x, y, w, (h - e) * .5, r, [(0, (255, 255, 255, 60)), (1, (255, 255, 255, 0))])
        cv.refresh()
        ty = y + (h - e) / 2
        fg, on_accent = (th["ink"] if kind == "primary" else hx(INK)), True
    else:
        _rr(cv, x, y, w, h, r, fill=mix(th["raised"], "#000000", .45))
        _rr(cv, x, y, w, h - 4, r, fill=mix(th["raised"], "#FFFFFF", .04))
        _rr(cv, x, y, w, h - 4, r, stroke=M.STROKE, sw=1)
        ty = y + (h - 4) / 2
        fg, on_accent = th["text"], False
    fs = size + 1
    tw = cv.tw(text, "disp", fs)
    gw = (26 + 10) if key else 0
    iw = (size + 8) if ico else 0
    tx = x + (w - tw - gw - iw) / 2
    if key:
        M.glyph(cv, tx, ty - 13, key, th, on_accent, 26)
    if ico:
        icon(cv, ico, tx + gw + size / 2, ty, size, fg, accent=fg if ico == "star" else None)
    _text(cv, tx + gw + iw, ty + .5, text, "disp", fs, fg, "lm")
    if focus:
        cv.glow_ring(x - 4, y - 4, w + 8, h + 8, r + 4)


def p_card(cv, x, y, w, h, th, fill="raised", r=14, st="idle"):
    keep = ST["lip"]
    ST["lip"] = False
    _card(cv, x, y, w, h, th, fill, r, st)
    ST["lip"] = keep
    if w >= 200 and h >= 150:
        stitched(cv, x, y, w, h, r, inset=6 if h >= 300 else 5)


def p_chip(cv, x, y, text, fill, fg, h=26, ico=None, stroke=None, size=13, anchor="l"):
    sticker = h >= 22 and text.lower() not in ("starter",)
    if not sticker:
        return _chip(cv, x, y, text, fill, fg, h, ico, stroke, size, anchor)
    w = cv.tw(text.upper(), "b", size, .6) + 20 + (18 if ico else 0)
    if anchor == "r":
        x -= w
    z, pad = cv.z, 8
    t = Cv(w + pad * 2, h + pad * 2, z=z)
    _rr(t, pad - 2, pad - 2, w + 4, h + 4, h / 2 + 2, fill=hx(CREAM))
    _rr(t, pad, pad, w, h, h / 2, fill=fg)
    tx = pad + 10
    ink = hx(INK)
    if ico:
        icon(t, ico, tx + 7, pad + h / 2, 15, ink, accent=ink if ico == "star" else None)
        tx += 18
    _text(t, tx, pad + h / 2 + .5, text.upper(), "b", size, ink, "lm", .6)
    im = t.im.rotate(4 if anchor == "r" else -4, resample=Image.BICUBIC, expand=True)
    cv.shadow(x + 1, y + 1, w - 2, h - 2, h / 2, blur=5, color=(0, 0, 0, 110), dy=3)
    cv.paste(im, round((x + w / 2) * z - im.width / 2), round((y + h / 2) * z - im.height / 2), raw=True)
    cv.refresh()
    return w


def p_hints(cv, x, y, items, th, right=None):
    for key, text in items:
        x += cap(cv, x, y - 11, key, th, 22) + 6
        x += (cv.text(x, y + .5, text, "r", 14, th["soft"], "lm") + 18) if text else 0
    if right:
        cv.text(M.LW - 24, y + .5, right, "r", 14, th["dim"], "rm")


def p_wallet(cv, xr, y, amount, th, h=40):
    w = _wallet(cv, xr, y, amount, th, h)
    star_face(cv, xr - w + 24, y + h / 2, 22)
    return w


def p_header(cv, xl, xr, cy, title, th, hh, tsize, stars=128, eyebrow=None, ey=0):
    wx = _header(cv, xl, xr, cy, "", th, hh, tsize, stars, None, ey)
    star = round(hh * .5)
    star_face(cv, wx + hh * .40 + star / 2, cy, star)
    tint = hx(ST["tint"])
    if eyebrow:
        cv.ell(xl + 4, ey + 8, 3.5, fill=tint)
        _text(cv, xl + 13, ey, eyebrow.upper(), "b", 13, mix(tint, "#FFFFFF", .25), "la", .6)
    ty = cy + (4 if eyebrow else 0)
    tw = _text(cv, xl, ty, title, "disp", tsize + 1, th["text"], "lm")
    squiggle(cv, xl + 1, ty + tsize * .66 + 2, tw * .62, tint, amp=1.8 if hh >= 44 else 1.4, wave=11 if hh >= 44 else 9, sw=2.4 if hh >= 44 else 2)
    return wx


def p_well(cv, x, y, w, h, th, r=12):
    _well(cv, x, y, w, h, th, r)
    dot_grid(cv, x, y, w, h)


def p_dpanel(th):
    cv = _dpanel(th)
    halftone(cv, 0, 0, 848, 608, ST["tint"])
    return cv


def p_lcd(th):
    cv = _lcd(th)
    halftone(cv, 0, 0, M.LW, M.LH, ST["tint"], rows=7)
    return cv


@contextmanager
def after(th, tint, lip=True, lip_h=4):
    ST.update(on=True, th=th, tint=tint, lip=lip, lipH=lip_h)
    Cv.text, Cv.wrap, Cv.rr = p_text, p_wrap, p_rr
    M.button, M.card, M.chip, M.hints, M.wallet, M.lcd = p_button, p_card, p_chip, p_hints, p_wallet, p_lcd
    for mod in (R, I):
        mod.button, mod.card, mod.chip, mod.hints = p_button, p_card, p_chip, p_hints
    R.header, R.well, R.dpanel = p_header, p_well, p_dpanel
    try:
        yield
    finally:
        ST["on"] = False
        Cv.text, Cv.wrap, Cv.rr = _text, _wrap, _rr
        M.button, M.card, M.chip, M.hints, M.wallet, M.lcd = _button, _card, _chip, _hints, _wallet, _lcd
        for mod in (R, I):
            mod.button, mod.card, mod.chip, mod.hints = _button, _card, _chip, _hints
        R.header, R.well, R.dpanel = _header, _well, _dpanel


# ------------------------------------------------------------------ the screens
def hatch_after(th):
    with after(th, TINT["hatch"]):
        cv = R.hatch_desktop(th)
        peek(cv, 742, 251, 150, 78)                     # in the preview window, watching the egg
    return cv


def hatch_phone_after(th):
    with after(th, TINT["hatch"], lip_h=3):
        cv = R.hatch_phone(th)
    return cv


def themes_after(th):
    with after(th, TINT["deck"]):
        cv = I.themes_desktop(th)
        peek(cv, 548, 84, 104, 43)                      # over the tab bar
        cv.rr(24, 84, 800, 44, 22, stroke=M.STROKE, sw=1)
    return cv


def results_after(th):
    st = K.results_state(K.WIN)
    with after(th, TINT["results"], lip=False):
        cv = K.results_lcd(th, st)
        for x in (24, M.LW - 24 - 248):
            stitched(cv, x, 124, 248, 276, 14)
        peek(cv, 536, 412, 118, 50, flip=True)          # over the come-back strip, beside the count
        _rr(cv, 24, 412, 800, 56, 12, stroke=M.STROKE, sw=1)
        star_face(cv, M.LW / 2, 212 - 4, 164 * .82)
    return cv


# ------------------------------------------------------------------ sheets
def panel_img(cv, scale=1):
    return cv.im.resize((round(cv.w * scale), round(cv.h * scale)), Image.LANCZOS).convert("RGB")


def pair(before, after_, name, captions, scale=1, stack=False, notes=()):
    a, b = panel_img(before, scale), panel_img(after_, scale)
    gap, cap_h, pad = 24 * scale, 40 * scale, 24 * scale
    note_h = (22 * scale * len(notes) + 12 * scale) if notes else 0
    if stack:
        W, H = a.width + pad * 2, a.height * 2 + cap_h * 2 + gap + pad + note_h
    else:
        W, H = a.width * 2 + gap + pad * 2, a.height + cap_h + pad + note_h
    sheet = Cv(W, H, z=1, bg=(12, 14, 17, 255))
    spots = ((pad, cap_h), (pad, cap_h * 2 + a.height + gap)) if stack else ((pad, cap_h), (pad + a.width + gap, cap_h))
    for im, (x, y), text, col in zip((a, b), spots, captions, ((149, 155, 165, 255), (118, 246, 176, 255))):
        sheet.im.paste(im, (x, y))
        sheet.refresh()
        sheet.text(x, y - cap_h / 2, text, "b", 16 * scale, col, "lm", .6)
    y = H - note_h + 2 * scale
    for n in notes:
        sheet.text(pad, y + 8 * scale, n, "r", 14 * scale, (195, 200, 208, 255), "lm")
        y += 22 * scale
    OUT.mkdir(parents=True, exist_ok=True)
    sheet.im.save(OUT / f"{name}.png")


def details(pairs, name):
    """2x crops of the same rect before and after. pairs: [(before cv, after cv, rect, caption)]."""
    rows = []
    for b, a, (x, y, w, h), text in pairs:
        ims = []
        for cv in (b, a):
            z = cv.z
            ims.append(cv.im.crop((round(x * z), round(y * z), round((x + w) * z), round((y + h) * z))).resize((w * 2, h * 2), Image.LANCZOS).convert("RGB"))
        rows.append((ims, text))
    colw = max(r[0][0].width for r in rows)
    W = colw * 2 + 24 * 3
    H = 56 + sum(r[0][0].height + 44 for r in rows)
    sheet = Cv(W, H, z=1, bg=(12, 14, 17, 255))
    sheet.text(24, 28, "NOW", "b", 16, (149, 155, 165, 255), "lm", .6)
    sheet.text(48 + colw, 28, "PROPOSED", "b", 16, (118, 246, 176, 255), "lm", .6)
    y = 56
    for ims, text in rows:
        sheet.im.paste(ims[0], (24, y))
        sheet.im.paste(ims[1], (48 + colw, y))
        sheet.refresh()
        sheet.text(24, y + ims[0].height + 16, text, "r", 15, (195, 200, 208, 255), "lm")
        y += ims[0].height + 44
    sheet.im.save(OUT / f"{name}.png")


def save_views(th, hatch_cv, themes_cv, results_cv, phone_cv):
    """The proposed screens in their real settings: 1920x1080 desktop and the 812x354 phone."""
    keep_r, keep_k = R.OUT, K.OUT
    R.OUT = K.OUT = OUT
    try:
        R.save_desktop(hatch_cv, th, "01-hatch-eggs-after")
        R.save_desktop(themes_cv, th, "03-deck-style-balls-after")
        K.desk_view(results_cv, th, "02-results-after-desktop")
    finally:
        R.OUT, K.OUT = keep_r, keep_k
    for extra in ("01-hatch-eggs-after-desktop-1920x1080@2x.png", "03-deck-style-balls-after-desktop-1920x1080@2x.png", "02-results-after-desktop-lcd@2x.png"):
        (OUT / extra).unlink(missing_ok=True)
    phone_cv.out().convert("RGB").save(OUT / "04-hatch-eggs-after-phone-812x354.png")


def main():
    th = kit_theme("sherbet")
    hb, ha = R.hatch_desktop(th), hatch_after(th)
    tb, ta = I.themes_desktop(th), themes_after(th)
    rb, ra = K.results_lcd(th, K.results_state(K.WIN)), results_after(th)
    pb, pa = R.hatch_phone(th), hatch_phone_after(th)
    cap = ("NOW (approved mockup)", "PROPOSED (same layout, personality tweaks)")
    pair(hb, ha, "01-hatch-eggs-desktop-before-after", cap,
         notes=("T1 Fredoka titles and names   T2 tiles and buttons get a lip, the info card gets a seam   T3 copy   T4 Bear watches the egg",
                "T5 peach screen tint (eyebrow dot, squiggle, halftone)   T6 sticker price   T7 dot grid in the preview   T9 the Star has eyes"))
    pair(rb, ra, "02-results-desktop-before-after", cap,
         notes=("Same tweaks on the round results: buttons, seams, sticker NEW BEST, Bear cheering over the strip, a face on the Star, warmer lines.",))
    pair(tb, ta, "03-deck-style-balls-desktop-before-after", cap,
         notes=("Deck style, Balls tab: lilac screen tint, lips on the six tiles, seam on the detail card, sticker tier chip, Bear over the tab bar.",))
    pair(pb, pa, "04-hatch-eggs-phone-before-after-812x354", cap, stack=True,
         notes=("Phone keeps every size. The pet peek and the halftone are dropped here; type, lips (3 px), seam, sticker and copy stay.",))
    details([(hb, ha, (16, 4, 400, 76), "Header: display face, screen tint on the eyebrow and squiggle"),
             (hb, ha, (16, 160, 344, 92), "Selectable tile: a 4 px lip says 'you can press me'"),
             (hb, ha, (376, 252, 440, 56), "Name in the display face; the price is a sticker"),
             (hb, ha, (376, 456, 440, 72), "Primary button: deeper ledge, display label"),
             (hb, ha, (16, 552, 400, 40), "Hint glyphs look like the deck's own A and B caps"),
             (rb, ra, (580, 4, 260, 60), "Wallet: the Star has eyes from 20 px up")], "05-details-2x")
    save_views(th, ha, ta, ra, pa)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
