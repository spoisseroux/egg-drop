"""Compact (phone landscape) mockups for UI-SPEC-COMPACT-2026-11-12.md.

Run: python scripts/deck_art/build_compact_mockups.py
Every screen is one function of the root size (W, H), using the same rules the spec gives the implementer,
so the 844 x 390 and 740 x 360 images are the rules evaluated twice, not two hand-drawn pictures.
Output is 1:1 (one image pixel = one Roblox offset pixel) so the PNG reads the way the phone does.
Concept drawings from the spec's numbers, not Studio captures.
"""
from __future__ import annotations

import sys

from PIL import Image

from build_mockups import (PLATES, STROKE, button, check_circle, chip, deck_thumb, diff_bars, label, progress, segmented, theme)
from build_shell import button_base, button_gloss, dpad_arrows, dpad_disc, tint, wordmark_sprite
from common import ASSETS, MOCKUPS, Cv, contrast, egg_ball, gradient, hx, icon, mix, ui_theme, DANGER, GOOD, INK, STAR

OUT = MOCKUPS / "compact"
ASPECT = 11.8 / 19.8          # (Config.Width + .8) / (Config.Height + .8)
KX, KH = 116, 58              # Roblox top-bar keep-out used in the mockups (runtime: GuiService.TopbarInset)
BEZEL = (9, 10, 12, 255)
DIFF = {"easy": ("Easy", "Breezy", 1, GOOD, "0.8", "5 to 6", "6"), "medium": ("Medium", "Classic", 2, STAR, "1", "6 to 8", "8"),
        "hard": ("Hard", "Spicy", 3, DANGER, "1.5", "9 to 12", "12")}
BULLETS = {"easy": ("Calmer egg mix", "Line sits higher", "2 goals"), "medium": ("Today's rules", "Line as now", "2 goals"),
           "hard": ("Faster egg mix", "Line sits lower", "3 goals")}


# ------------------------------------------------------------------ shared pieces
def canvas(W, H, th):
    """The faceplate fills the whole root (the phone is the deck)."""
    cv = Cv(W, H, z=3, bg=(0, 0, 0, 255))
    p = th["plate"]
    tex = Image.open(ASSETS / "faceplates" / p["texture"]).convert("RGBA")
    w, h = tex.size
    tex = tex.crop((round(w * .10), round(h * .12), round(w * .90), round(h * .88))).resize((W * 3, H * 3), Image.LANCZOS)
    cv.paste(tex, 0, 0, raw=True)
    return cv


def roblox_bar(cv):
    """Ghost of the Roblox top-bar controls, to show the keep-out. Not ours to draw at runtime."""
    for i, kind in enumerate(("menu", "chat")):
        x = 12 + i * 52
        cv.rr(x, 7, 44, 44, 22, fill=(18, 19, 22, 205))
        if kind == "menu":
            cv.poly([(x + 22, 18), (x + 33, 29), (x + 22, 40), (x + 11, 29)], (255, 255, 255, 230))
            cv.rr(x + 19, 26, 6, 6, 1, fill=(18, 19, 22, 255))
        else:
            cv.rr(x + 11, 18, 22, 16, 5, fill=(255, 255, 255, 230))
            cv.poly([(x + 15, 33), (x + 15, 40), (x + 23, 33)], (255, 255, 255, 230))


def island(cv, x, y, w, h, th, r=12, fill="panel"):
    """A piece of dark glass set into the faceplate."""
    cv.rr(x - 3, y - 3, w + 6, h + 6, r + 3, fill=BEZEL)
    cv.rr(x - 3, y - 3, w + 6, h + 6, r + 3, stroke=(255, 255, 255, 46), sw=1)
    cv.rr(x, y, w, h, r, fill=th[fill])
    cv.rr(x, y, w, h, r, stroke=STROKE, sw=1)


def back(cv, W, top=8):
    x, d = W - 12 - 44, 44
    cv.shadow(x, top, d, d, d / 2, blur=8, color=(0, 0, 0, 110), dy=3)
    cv.rr(x, top, d, d, d / 2, fill=(21, 23, 27, 235))
    cv.rr(x, top, d, d, d / 2, stroke=(255, 255, 255, 60), sw=1.5)
    icon(cv, "back", x + d / 2, top + d / 2, 22, (243, 244, 246, 255), w=2.2)


def wallet(cv, xr, cy, amount, th):
    s = f"{amount:,}"
    w = cv.tw(s, "monob", 15) + 46
    cv.rr(xr - w, cy - 16, w, 32, 16, fill=th["well"])
    cv.rr(xr - w, cy - 16, w, 32, 16, stroke=STROKE, sw=1)
    icon(cv, "star", xr - w + 19, cy, 17)
    cv.text(xr - 13, cy, s, "monob", 15, th["text"], "rm")
    return w


def sheet(W, H, th, title=None):
    """Menu sheet: glass over the whole root with a 6 px faceplate rim. Returns the canvas."""
    cv = canvas(W, H, th)
    cv.rr(6, 6, W - 12, H - 12, 18, fill=BEZEL)
    cv.rr(8, 8, W - 16, H - 16, 16, fill=th["panel"])
    cv.paste(masked_gradient(W - 16, H - 16, 16, cv.z), 8 * cv.z, 8 * cv.z, raw=True)
    cv.rr(8, 8, W - 16, H - 16, 16, stroke=STROKE, sw=1)
    cv.line([(20, 60), (W - 20, 60)], (255, 255, 255, 18), 1, False)
    if title:
        cv.text(KX + 12, 30, title, "b", 20, th["text"], "lm")
    back(cv, W)
    return cv


def masked_gradient(w, h, r, z):
    from common import rounded_mask
    g = gradient(w * z, h * z, [(0, (255, 255, 255, 8)), (1, (0, 0, 0, 30))])
    from PIL import ImageChops
    g.putalpha(ImageChops.multiply(g.getchannel("A"), rounded_mask(w * z, h * z, r * z, 1)))
    return g


def tabs(cv, x, y, w, items, sel, th, dots=()):
    h = 36
    cv.rr(x, y, w, h, h / 2, fill=th["well"])
    cv.rr(x, y, w, h, h / 2, stroke=STROKE, sw=1)
    sw_ = (w - 8) / len(items)
    for i, s in enumerate(items):
        sx = x + 4 + i * sw_
        if i == sel:
            cv.rr(sx, y + 4, sw_, h - 8, (h - 8) / 2, fill=th["accent"])
        tw = cv.text(sx + sw_ / 2, y + h / 2 + .5, s, "b", 14, th["ink"] if i == sel else th["soft"], "mm")
        if i in dots:
            cv.ell(sx + sw_ / 2 + tw / 2 + 7, y + h / 2 - 7, 3.5, fill=STAR)


def fit(cv, s, width, key, size):
    """TextTruncate.AtEnd."""
    if cv.tw(s, key, size) <= width:
        return s
    while s and cv.tw(s + "…", key, size) > width:
        s = s[:-1]
    return s.rstrip() + "…"


def save(cv, name, W, H):
    OUT.mkdir(parents=True, exist_ok=True)
    roblox_bar(cv)
    cv.out().convert("RGB").save(OUT / f"{name}-{W}x{H}.png")


# ------------------------------------------------------------------ 01 round HUD
def hud_geometry(W, H):
    bh = H - 16
    bw = round(bh * ASPECT)
    bx = (W - bw) // 2
    g = {"board": (bx, 8, bw, bh), "L0": 12, "L1": bx - 14, "R0": bx + bw + 14, "R1": W - 12}
    g["D"] = 104 if H >= 380 else 96 if H >= 340 else 88
    g["A"] = g["D"]
    return g


def screen_hud(W, H, th, diff="hard", drawer=False):
    cv = canvas(W, H, th)
    g = hud_geometry(W, H)
    bx, by, bw, bh = g["board"]
    L0, L1, R0, R1, D, A = g["L0"], g["L1"], g["R0"], g["R1"], g["D"], g["A"]
    name, _, level, dcol, mult, pays, _ = DIFF[diff]
    # ---- board glass
    cv.rr(bx - 6, by - 6, bw + 12, bh + 12, 18, fill=BEZEL)
    cv.rr(bx - 6, by - 6, bw + 12, bh + 12, 18, stroke=(255, 255, 255, 50), sw=1)
    cv.rr(bx, by, bw, bh, 12, fill=th["well"])
    for gy in range(1, 12):
        cv.line([(bx + 8, by + gy * bh / 12), (bx + bw - 8, by + gy * bh / 12)], (255, 255, 255, 7), 1, False)
    cv.rr(bx, by, bw, bh, 12, stroke=STROKE, sw=1)
    s = bh / 584
    line_y = by + 200 * s
    n = int((bw - 16) // 20)
    for i in range(n):
        cv.line([(bx + 10 + i * 20, line_y), (bx + 20 + i * 20, line_y)], hx(DANGER, 200), 2, False)
    chip(cv, bx + bw - 8, line_y - 26, "Line", mix(th["well"], DANGER, .25), hx(DANGER), 20, anchor="r", size=12)
    ax = bx + 196 * s
    for i in range(7):
        cv.ell(ax, by + (104 + i * 30) * s, 1.6, fill=(255, 255, 255, 60))
    egg_ball(cv, ax, by + 52 * s, 24 * s, 1)
    cv.poly([(ax - 7, by + 8), (ax + 7, by + 8), (ax, by + 17)], th["accent"])
    for x, y, r, t in ((48, 544, 34, 3), (112, 552, 26, 2), (160, 556, 22, 1), (214, 540, 38, 4), (282, 552, 26, 2), (300, 500, 22, 1),
                       (72, 486, 26, 2), (128, 502, 22, 1), (168, 510, 22, 1), (250, 478, 26, 2), (104, 444, 22, 1), (196, 468, 22, 1)):
        egg_ball(cv, bx + x * s, by + y * s, r * s, t)
    # ---- top strip, left wing: Score (+ Chain when it fits)
    x0 = max(KX + 8, L0)
    wing = L1 - x0
    chain_in_strip = wing >= 154
    strip_left = wing >= 84
    top = 60
    if strip_left:
        sw_ = min(132, wing - 70) if chain_in_strip else min(132, wing)
        sx = L1 - sw_ - (70 if chain_in_strip else 0)
        island(cv, sx, 8, sw_, 44, th)
        label(cv, sx + 10, 13, "Score", th, size=12)
        cv.text(sx + 10, 47, "2,340", "monob", 18, th["text"], "ls")
        if chain_in_strip:
            island(cv, L1 - 64, 8, 64, 44, th)
            label(cv, L1 - 54, 13, "Chain", th, size=12)
            cv.text(L1 - 54, 47, "×3", "monob", 18, th["text"], "ls")
    else:      # no room beside the Roblox controls: Score drops under the top bar
        island(cv, L0, 60, L1 - L0, 44, th)
        label(cv, L0 + 10, 76, "Score", th, size=12)
        cv.text(L1 - 10, 82, "2,340", "monob", 18, th["text"], "rm")
        top = 112
    # ---- top strip, right wing: Next, Eggs left, back arrow
    wing_r = (W - 12 - 44 - 8) - R0
    ew = 88 if wing_r >= 150 else 58
    nw = min(140, wing_r - ew - 6)
    island(cv, R0, 8, nw, 44, th)
    second = nw >= 80
    with_label = nw >= 124
    content = (36 if with_label else 0) + 32 + (30 if second else 0)
    nx = R0 + (nw - content) / 2
    if with_label:
        label(cv, nx, 24, "Next", th, size=12)
        nx += 36
    egg_ball(cv, nx + 16, 30, 16, 2)
    if second:
        egg_ball(cv, nx + 32 + 8 + 11, 30, 11, 1)
    ex = R0 + nw + 6
    island(cv, ex, 8, ew, 44, th)
    label(cv, ex + 10, 13, "Eggs", th, size=12)
    tw = cv.text(ex + 10, 47, "14", "monob", 18, th["text"], "ls")
    if ew >= 88:
        cv.text(ex + 12 + tw, 47, "/24", "mono", 13, th["soft"], "ls")
    back(cv, W)
    # ---- right column: difficulty, win pays, A and B
    rw = R1 - R0
    island(cv, R0, 60, rw, 44, th)
    diff_bars(cv, R0 + 12, 71, level, hx(dcol), th)
    cv.text(R0 + 46, 82.5, name, "b", 15, th["text"], "lm")
    if rw >= 190:
        chip(cv, R1 - 10, 71, f"×{mult}", mix(th["well"], STAR, .14), hx(STAR), 22, "star", anchor="r", size=12)
    island(cv, R0, 112, rw, 44, th)
    label(cv, R0 + 12, 128, "Win pays", th, size=12)
    wtxt = pays.replace(" to ", "–")
    tw = cv.tw(wtxt, "monob", 17)
    cv.text(R1 - 12, 134.5, wtxt, "monob", 17, th["star"], "rm")
    icon(cv, "star", R1 - 12 - tw - 13, 134, 17)
    acx, acy = W - 16 - A / 2, H - 16 - A / 2
    p = th["plate"]
    cv.paste(tint(button_base(A * 3), p["accent"]), (acx - A / 2) * 3, (acy - A / 2) * 3, raw=True)
    cv.paste(button_gloss(A * 3), (acx - A / 2) * 3, (acy - A / 2) * 3, raw=True)
    cv.text(acx, acy + A * .02, "A", "xb", A * .46, p["ink"], "mm")
    B = 56
    bcx, bcy = acx - A / 2 - 14 - B / 2, H - 16 - B / 2
    cv.paste(tint(button_base(B * 3), "#3A3E47"), (bcx - B / 2) * 3, (bcy - B / 2) * 3, raw=True)
    cv.paste(button_gloss(B * 3), (bcx - B / 2) * 3, (bcy - B / 2) * 3, raw=True)
    cv.text(bcx, bcy + 1, "B", "xb", B * .46, "#C3C8D0", "mm")
    # ---- left column
    lw = L1 - L0
    dx, dy = 16, H - (12 if H >= 340 else 8) - D
    hx0 = dx + D + 12
    hy = H - 12 - 44
    goals = [("II centre", 2, 2), ("III RIGHT", 1, 2), ("Tier IV", 0, 1)]
    gp = 34 if H >= 340 else 26
    if not drawer:
        gh = 24 + gp * 3 + 6
        island(cv, L0, top, lw, gh, th)
        label(cv, L0 + 12, top + 8, "Goals 1/3", th, size=12)
        if not chain_in_strip:
            w = cv.text(L1 - 12, top + 15, "×3", "monob", 13, th["text"], "rm")
            label(cv, L1 - 16 - w, top + 8, "Chain", th, anchor="ra", size=12)
        for i, (t, c, gl) in enumerate(goals):
            cy = top + 24 + gp / 2 + i * gp
            check_circle(cv, L0 + 22, cy, c >= gl, th, 10)
            cv.text(L0 + 40, cy + .5, t, "m", 14, th["soft"] if c >= gl else th["text"], "lm")
            cv.text(L1 - 12, cy + .5, f"{c}/{gl}", "monob", 13, th["soft"], "rm")
        # d-pad
        cv.paste(dpad_disc(D * 3), dx * 3, dy * 3, raw=True)
        cv.paste(tint(dpad_arrows(D * 3), p["accent"]), dx * 3, dy * 3, raw=True)
        # wordmark engraving above the handle when there is room
        wm_w = min(123, L1 - hx0)
        wm_top, wm_bot = top + gh + 10, hy - 10
        if wm_w >= 100 and wm_bot - wm_top >= wm_w * 16 / 41:
            wm = wordmark_sprite(8).resize((round(wm_w * 3), round(wm_w * 16 / 41 * 3)), Image.LANCZOS)
            lay = tint(wm, p["engrave"]["color"])
            lay.putalpha(lay.getchannel("A").point(lambda v: int(v * p["engrave"]["opacity"])))
            cv.paste(lay, (hx0 + (L1 - hx0 - wm_w) / 2) * 3, ((wm_top + wm_bot) / 2 - wm_w * 16 / 82) * 3, raw=True)
        # quest drawer handle (left thumb)
        hw = L1 - hx0
        island(cv, hx0, hy, hw, 44, th, r=22, fill="well")
        icon(cv, "quests", hx0 + 22, hy + 22, 18, th["text"])
        if hw >= 110:
            cv.text(hx0 + 36, hy + 22.5, "Quests", "b", 14, th["text"], "lm")
        if hw >= 150:
            cv.text(hx0 + hw - 30, hy + 22.5, "1/3", "monob", 13, th["soft"], "rm")
        elif hw < 110 and hw >= 84:
            cv.text(hx0 + 36, hy + 22.5, "1/3", "monob", 13, th["soft"], "lm")
        cv.line([(hx0 + hw - 22, hy + 25), (hx0 + hw - 17, hy + 20), (hx0 + hw - 12, hy + 25)], th["soft"], 2)
        cv.ell(hx0 + 31, hy + 13, 4, fill=STAR)
    else:
        top = 60                     # the drawer always opens from under the top bar
        ph = H - top - 12
        island(cv, L0, top, lw, ph, th)
        label(cv, L0 + 12, top + 16, "Daily quests", th, size=12)
        cx, cy = L1 - 22, top + 22
        cv.line([(cx - 6, cy - 3), (cx, cy + 3), (cx + 6, cy - 3)], th["text"], 2.2)
        rows = (("Win 2 rounds", 2, 2), ("Chain 4 merges", 3, 4), ("Tier IV on Hard", 0, 1))
        for i, (t, c, gl) in enumerate(rows):
            y = top + 46 + i * 44
            done = c >= gl
            cv.text(L0 + 12, y + 12, fit(cv, t, lw - 70, "r", 14), "r", 14, th["text"], "lm")
            cv.text(L1 - 12, y + 12, f"{c}/{gl}", "monob", 13, hx(STAR) if done else th["soft"], "rm")
            progress(cv, L0 + 12, y + 28, lw - 24, 4, c / gl, th, hx(STAR) if done else None)
        button(cv, L0 + 12, top + ph - 56, lw - 24, 44, "Open quest log", th, "secondary", size=15)
    return cv


# ------------------------------------------------------------------ 02 difficulty picker
def screen_picker(W, H, th, sel=1):
    cv = sheet(W, H, th, "Pick a difficulty")
    wallet(cv, W - 66, 30, 128, th)
    cw = (W - 40 - 20) // 3
    ch = H - 140
    bullets = ch >= 205 and cw >= 200
    tidy = ch >= 244
    for i, key in enumerate(("easy", "medium", "hard")):
        name, nick, level, col, mult, pays, top_pay = DIFF[key]
        x, y = 20 + i * (cw + 10), 64
        on = i == sel
        cv.rr(x, y, cw, ch, 14, fill=th["selected"] if on else th["raised"])
        cv.rr(x, y, cw, ch, 14, stroke=th["accent"] if on else STROKE, sw=2 if on else 1)
        chip(cv, x + 12, y + 10, name, th["well"], hx(col), 20, size=12)      # tone on well: 4.5:1 on every plate, selected or not
        diff_bars(cv, x + cw - 36, y + 9, level, hx(col), th)
        cv.text(x + 12, y + 47, nick, "b", 20, th["text"], "lm")
        chip(cv, x + 12, y + 64, f"×{mult} Stars", mix(th["well"], STAR, .14), hx(STAR), 24, "star", size=12)
        if bullets:
            for j, b in enumerate(BULLETS[key]):
                by = y + 108 + j * 22
                cv.ell(x + 16, by, 3, fill=hx(col))
                cv.text(x + 28, by + .5, b, "r", 14, th["soft"], "lm")
        hy = y + ch - (62 if tidy else 44)
        cv.line([(x + 12, hy), (x + cw - 12, hy)], (255, 255, 255, 26), 1, False)
        cv.text(x + 12, hy + 20, f"Win pays {pays}", "b", 14, th["text"], "lm")
        if tidy:
            cv.text(x + 12, hy + 42, f"Tidy stack pays {top_pay}", "mono", 12, th["soft"], "lm")
    by = H - 66
    button(cv, 20, by, 148, 48, "Quests 1/3", th, "secondary", size=15, ico="quests")
    cv.ell(160, by + 8, 4, fill=STAR)
    sw_ = 200 if W >= 600 else 160
    button(cv, W - 20 - sw_, by, sw_, 48, "Start", th, "primary", size=16)
    gx, gw = 180, W - 20 - sw_ - 12 - 180
    icon(cv, "target", gx + 9, by + 24, 18, th["soft"], accent=th["soft"])
    cv.wrap(gx + 26, by + 6, "Goal this round: Make two tier III eggs on RIGHT", gw - 26, "r", 14, th["soft"], 18, 2)
    return cv


# ------------------------------------------------------------------ 03 results
def screen_results(W, H, th, diff="hard"):
    cv = sheet(W, H, th)
    name, _, level, dcol, mult, pays, _ = DIFF[diff]
    label(cv, KX + 12, 15, "Round clear", th, th["accent"], size=12)
    cv.text(KX + 12, 41, fit(cv, f"Creek crossing  ·  {name}", W - 66 - 90 - KX - 24, "r", 14), "r", 14, th["soft"], "lm")
    wallet(cv, W - 66, 30, 140, th)
    cw = (W - 40 - 20) // 3
    ch = H - 140
    y = 64
    pitch = 28 if ch >= 200 else 26
    # payout
    x = 20
    cv.rr(x, y, cw, ch, 14, fill=th["raised"])
    cv.rr(x, y, cw, ch, 14, stroke=STROKE, sw=1)
    label(cv, x + 12, y + 10, "Payout", th, size=12)
    for i, (t, a) in enumerate((("Round win", "8"), ("Tidy stack", "+2"), (f"{name} ×{mult}", "+2"))):
        ry = y + 46 + i * pitch
        cv.text(x + 12, ry, t, "r", 14, th["text"], "lm")
        cv.text(x + cw - 12, ry, a, "monob", 15, th["star"], "rm")
        cv.line([(x + 12, ry + pitch / 2), (x + cw - 12, ry + pitch / 2)], (255, 255, 255, 18), 1, False)
    ty = y + 46 + 3 * pitch + 4
    cv.text(x + 12, ty, "Total", "b", 14, th["text"], "lm")
    tw = cv.tw("12", "monob", 15)
    cv.text(x + cw - 12, ty, "12", "monob", 15, th["star"], "rm")
    icon(cv, "star", x + cw - 12 - tw - 12, ty - .5, 15)
    if ch >= 186:
        cv.text(x + 12, y + ch - 18, "Saved to your wallet", "r", 12, th["soft"], "lm")
    # hero
    x = 20 + cw + 10
    cx = x + cw / 2
    mid = y + (ch - 62) / 2
    tw = cv.tw("+12 Stars", "xb", 30)
    icon(cv, "star", cx - tw / 2 - 6, mid - 14, 34)
    cv.text(cx + 20, mid - 13, "+12 Stars", "xb", 30, th["star"], "mm")
    cw_ = cv.tw("NEW BEST", "b", 12, .6) + 20
    chip(cv, cx - cw_ / 2, mid + 14, "New best", mix(th["well"], STAR, .14), hx(STAR), 22, size=12)
    my = y + ch - 50
    cv.line([(x + 8, my - 10), (x + cw - 8, my - 10)], (255, 255, 255, 18), 1, False)
    metrics = (("Score", "2,340"), ("Best", "2,340"), ("Chain", "×4")) if cw >= 200 else (("Score", "2,340"), ("Chain", "×4"))
    for i, (l, v) in enumerate(metrics):
        mx = x + 8 + i * (cw - 16) / len(metrics)
        label(cv, mx, my, l, th, size=12)
        cv.text(mx, my + 30, v, "monob", 15, th["text"], "lm")
    # goals
    x = W - 20 - cw
    cv.rr(x, y, cw, ch, 14, fill=th["raised"])
    cv.rr(x, y, cw, ch, 14, stroke=STROKE, sw=1)
    label(cv, x + 12, y + 10, "Goals", th, size=12)
    cv.text(x + cw - 12, y + 17, "2/3", "monob", 13, th["soft"], "rm")
    gp = 32 if ch >= 200 else 28
    for i, (t, d) in enumerate((("Merge II in the centre", True), ("Make III on RIGHT", True), ("Make a tier IV", False))):
        gy = y + 48 + i * gp
        check_circle(cv, x + 22, gy, d, th, 10)
        cv.text(x + 40, gy + .5, fit(cv, t, cw - 52, "r", 14), "r", 14, th["text"] if d else th["soft"], "lm")
    # bottom row: Leave (left thumb), quest shortcut, difficulty, Replay (right thumb)
    by = H - 66
    lw = 160 if W >= 600 else 100
    button(cv, 20, by, lw, 48, "Leave to garden" if W >= 600 else "Leave", th, "secondary", size=15)
    rw = cw
    rx = W - 20 - rw
    button(cv, rx, by, rw, 48, "Replay", th, "primary", size=16, ico="replay")
    dx = rx - 58
    cv.rr(dx, by, 48, 48, 12, fill=th["raised"])
    cv.rr(dx, by, 48, 48, 12, stroke=STROKE, sw=1)
    diff_bars(cv, dx + 8, by + 13, level, hx(dcol), th)
    cv.line([(dx + 33, by + 22), (dx + 37, by + 26), (dx + 41, by + 22)], th["soft"], 1.8)
    qx, qw = 20 + lw + 10, dx - 10 - (20 + lw + 10)
    cv.rr(qx, by, qw, 48, 12, fill=mix(th["well"], STAR, .06))
    cv.rr(qx, by, qw, 48, 12, stroke=hx(STAR), sw=1.5)
    icon(cv, "check", qx + 20, by + 24, 18, hx(STAR))
    if qw >= 200:
        cwid = cv.tw("CLAIM", "b", 12, .6) + 20
        cv.text(qx + 36, by + 24.5, fit(cv, "Win 2 rounds", qw - 36 - cwid - 18, "b", 14), "b", 14, th["text"], "lm")
        chip(cv, qx + qw - 10, by + 13, "Claim", hx(STAR), hx(INK), 22, anchor="r", size=12)
    else:
        cv.text(qx + 36, by + 24.5, fit(cv, "Claim 1 quest", qw - 46, "b", 14), "b", 14, th["text"], "lm")
    return cv


# ------------------------------------------------------------------ 04 quest log
def quest_row(cv, x, y, w, h, th, title, sub, cur, goal, reward, st, ico, action):
    ready, claimed = st == "ready", st == "claimed"
    cv.rr(x, y, w, h, 14, fill=mix(th["raised"], STAR, .07) if ready else th["raised"])
    cv.rr(x, y, w, h, 14, stroke=hx(STAR) if ready else STROKE, sw=2 if ready else 1)
    fade = 150 if claimed else 255
    cv.rr(x + 12, y + (h - 44) / 2, 44, 44, 12, fill=th["well"])
    icon(cv, "check" if claimed else ico, x + 34, y + h / 2, 22, (th["accent"] if claimed else th["text"])[:3] + (fade,), accent=th["accent"])
    roomy = h >= 64
    t1 = y + (19 if roomy else 16)
    cv.text(x + 68, t1, title, "b", 16, th["text"][:3] + (fade,), "lm")
    cv.text(x + 68, t1 + 20, sub, "r", 12, th["soft"][:3] + (fade,), "lm")
    bar_w = w - 68 - 250
    by = y + h - (14 if roomy else 11)
    progress(cv, x + 68, by, bar_w, 6, cur / goal, th, hx(STAR) if ready else (th["accent"][:3] + (fade,)))
    cv.text(x + 68 + bar_w + 10, by + 3, f"{cur}/{goal}", "monob", 13, th["soft"][:3] + (fade,), "lm")
    tw = cv.tw(f"+{reward}", "monob", 15)
    cv.text(x + w - 128, y + h / 2, f"+{reward}", "monob", 15, th["star"][:3] + (fade,), "rm")
    icon(cv, "star", x + w - 128 - tw - 12, y + h / 2 - .5, 15)
    ax, ay = x + w - 116, y + (h - 44) / 2
    if action:
        button(cv, ax, ay, 104, 44, action[0], th, action[1], size=15)
    elif claimed:
        chip(cv, x + w - 12, y + h / 2 - 12, "Claimed", th["well"], th["soft"], 24, anchor="r", size=12)


def screen_quests(W, H, th):
    cv = sheet(W, H, th)
    tx = KX + 12
    tw_ = min(312, W - tx - 66 - 96 - 12)
    tabs(cv, tx, 12, tw_, ["Daily 1/3", "Weekly 0/3", "History"], 0, th, dots=(0,))
    ww = wallet(cv, W - 66, 30, 128, th)
    timer_gap = (W - 66 - ww) - (tx + tw_)
    if timer_gap >= 130:
        tr = W - 66 - ww - 12
        t = cv.tw("New in 7 h 12 m", "r", 12)
        cv.text(tr, 30.5, "New in 7 h 12 m", "r", 12, th["soft"], "rm")
        icon(cv, "clock", tr - t - 12, 30, 15, th["soft"])
    gap = 8 if H >= 340 else 6
    rh = max(56, min(76, (H - 64 - 18 - 44 - 8 - 2 * gap) // 3))
    rows = (("Win 2 rounds", "Any difficulty  ·  Ready to claim", 2, 2, 4, "ready", "trophy", ("Claim", "reward")),
            ("Chain 4 merges", "In one round", 3, 4, 4, "progress", "chain", None),
            ("Make a tier IV on Hard", "Skill quest  ·  Not started", 0, 1, 4, "progress", "bars", ("Reroll", "secondary")))
    for i, r in enumerate(rows):
        quest_row(cv, 20, 64 + i * (rh + gap), W - 40, rh, th, *r)
    fy = H - 62
    cv.rr(20, fy, W - 40, 44, 12, fill=th["well"])
    cv.rr(20, fy, W - 40, 44, 12, stroke=STROKE, sw=1)
    icon(cv, "reroll", 42, fy + 22, 18, th["accent"])
    t = cv.text(60, fy + 22.5, "1 free reroll left today", "b", 14, th["text"], "lm")
    if W >= 800:
        cv.text(60 + t + 12, fy + 22.5, "Swaps one quest you have not started.", "r", 12, th["soft"], "lm")
    mx = W - 20 - 84
    cv.line([(mx, fy + 10), (mx, fy + 34)], (255, 255, 255, 30), 1, False)
    cv.text(mx + 16, fy + 22.5, "Menu", "b", 14, th["text"], "lm")
    cv.line([(mx + 62, fy + 17), (mx + 67, fy + 22), (mx + 62, fy + 27)], th["soft"], 2)
    sx = mx - 14
    s = cv.tw("4/12", "monob", 15)
    cv.text(sx, fy + 22, "4/12", "monob", 15, th["star"], "rm")
    icon(cv, "star", sx - s - 12, fy + 21.5, 15)
    if not timer_gap >= 130 or W >= 640:
        label(cv, sx - s - 26, fy + 15, "Today", th, anchor="ra", size=12)
    return cv


# ------------------------------------------------------------------ 07 faceplate shop
def screen_shop(W, H, th, sel="aurora_glass", equipped="sherbet", owned=("sherbet", "stone", "ice", "brick", "moss", "honey", "aqua_pop"), have=128):
    cv = sheet(W, H, th, "Faceplates")
    tx = KX + 12 + cv.tw("Faceplates", "b", 20) + 14
    cv.rr(tx, 12, 122, 36, 12, stroke=STROKE, sw=1)
    cv.text(tx + 61, 30.5, "Backgrounds", "b", 14, th["text"], "mm")
    wallet(cv, W - 66, 30, have, th)
    pw = 232 if W >= 700 else 200
    px, py, ph = W - 20 - pw, 64, H - 82
    p = PLATES[sel]
    # ---- grid (left, scrolls)
    gw = px - 12 - 20
    cols = 2 if gw >= 420 else 1
    tw_ = (gw - 8 - (cols - 1) * 8) // cols          # 8 px scrollbar gutter
    ids = list(PLATES)
    order = [sel] + [i for i in ids if i != sel]      # mock scroll position: keep the selected tile in view
    start = max(0, (ids.index(sel) // cols) - 2) * cols
    clip_bottom = py + ph
    for n, pid in enumerate(ids[start:]):
        x, y = 20 + (n % cols) * (tw_ + 8), py + (n // cols) * 72
        if y >= clip_bottom:
            break
        q = PLATES[pid]
        on = pid == sel
        cv.rr(x, y, tw_, 64, 12, fill=th["selected"] if on else th["raised"])
        cv.rr(x, y, tw_, 64, 12, stroke=th["accent"] if on else STROKE, sw=2 if on else 1)
        cv.paste(deck_thumb(pid, 88), x + 10, y + 9)
        nx = x + 108
        cv.text(nx, y + 22, fit(cv, q["name"], tw_ - 118, "b", 14), "b", 14, th["text"], "lm")
        sy = y + 43
        if pid == equipped:
            cv.text(nx, sy, "EQUIPPED", "b", 12, th["accent"], "lm", tracking=.6)
        elif pid in owned:
            icon(cv, "check", nx + 6, sy, 13, th["soft"])
            cv.text(nx + 17, sy, "Owned", "r", 12, th["soft"], "lm")
        elif q["tier"] == "starter":
            icon(cv, "lock", nx + 6, sy, 13, th["soft"])
            cv.text(nx + 17, sy, {"rankI": "Win 3", "rankII": "Win 10"}.get(q.get("unlock"), "Win 1"), "r", 12, th["soft"], "lm")
        else:
            ok = q["priceStars"] <= have
            icon(cv, "star", nx + 6, sy - .5, 13, accent=STAR if ok else th["soft"])
            cv.text(nx + 17, sy, str(q["priceStars"]), "monob", 13, th["star"] if ok else th["soft"], "lm")
    # fade the cut row into the sheet edge, and a scrollbar
    fade = gradient((gw) * 3, 26 * 3, [(0, th["panel"][:3] + (0,)), (1, mix(th["panel"], "#000000", .1))])
    cv.paste(fade, 20 * 3, (clip_bottom - 26) * 3, raw=True)
    cv.rr(18, clip_bottom, gw + 6, H - 8 - clip_bottom - 1, 0, fill=mix(th["panel"], "#000000", .1))
    cv.rr(20 + gw - 4, py + 60, 4, 96, 2, fill=(255, 255, 255, 70))
    # ---- preview pane (right, pinned; the action sits under the right thumb)
    cv.rr(px, py, pw, ph, 14, fill=th["raised"])
    cv.rr(px, py, pw, ph, 14, stroke=STROKE, sw=1)
    dw = pw - 24 if H >= 340 else 144
    t = deck_thumb(sel, dw)
    dx = px + (pw - dw) / 2
    cv.shadow(dx, py + 14, dw, t.height - 6, 14, blur=8, color=(0, 0, 0, 110), dy=4)
    cv.paste(t, dx, py + 10)
    ny = py + 10 + t.height + 16
    cv.text(px + 12, ny, p["name"], "b", 18, th["text"], "lm")
    tier_col = {"starter": th["soft"], "common": hx("#9BE3A8"), "rare": hx("#8CC8FF"), "showcase": hx("#E6B3FF")}[p["tier"]]
    chip(cv, px + pw - 12, ny - 11, p["tier"], th["well"], tier_col, 22, anchor="r", stroke=STROKE, size=12)
    cv.text(px + 12, ny + 22, p["finish"].capitalize(), "r", 12, th["soft"], "lm")
    by = py + ph - 60
    if by - 26 - (ny + 34) >= 44:
        pt = ui_theme(p["accent"], p["deep"])
        sy = ny + 38
        cv.rr(px + 12, sy, pw - 24, 36, 10, fill=pt["panel"])
        cv.rr(px + 12, sy, pw - 24, 36, 10, stroke=STROKE, sw=1)
        cv.rr(px + 18, sy + 6, 70, 24, 8, fill=pt["accent"])
        cv.text(px + 53, sy + 18.5, "Primary", "b", 12, pt["ink"], "mm")
        progress(cv, px + 98, sy + 15, pw - 24 - 98 - 20, 6, .62, pt)
        icon(cv, "star", px + pw - 26, sy + 18, 14)
    price = p["priceStars"]
    if sel in owned:
        button(cv, px + 12, by, pw - 24, 48, "Equip", th, "primary", size=16)
    elif price <= have:
        cv.text(px + 12, by - 14, "You have enough Stars", "r", 14, th["soft"], "lm")
        button(cv, px + 12, by, pw - 24, 48, f"Buy  {price}", th, "primary", size=16, ico="star")
    else:
        cv.text(px + 12, by - 14, f"{price - have} more Stars needed", "r", 14, hx("#FF8090"), "lm")
        button(cv, px + 12, by, pw - 24, 48, f"Buy  {price}", th, "secondary", "disabled", size=16, ico="star")
    return cv


# ------------------------------------------------------------------ contrast check
def report(th):
    pairs = [("text", "raised"), ("soft", "raised"), ("soft", "selected"), ("dim", "raised"), ("dim", "panel"), ("soft", "well"), ("star", "raised"),
             ("ink", "accent"), ("accent", "panel")]
    out = []
    for a, b in pairs:
        out.append(f"{a} on {b}: {contrast(th[a], th[b]):.2f}")
    out.append(f"danger on raised: {contrast(hx(DANGER), th['raised']):.2f}")
    out.append(f"danger on selected: {contrast(hx(DANGER), th['selected']):.2f}")
    for alt in ("#FF7286", "#FF8090", "#FF8A99"):
        out.append(f"{alt} on raised/selected: {contrast(hx(alt), th['raised']):.2f}/{contrast(hx(alt), th['selected']):.2f}")
    out.append(f"dim on selected: {contrast(th['dim'], th['selected']):.2f}; dim on well {contrast(th['dim'], th['well']):.2f}")
    out.append(f"good on raised: {contrast(hx(GOOD), th['raised']):.2f}")
    return out


def kit_theme(pid):
    th = theme(pid)
    th["dim"] = hx("#959BA5")       # DeckKit's dim, not the older #8A909A
    return th


def main():
    th = kit_theme("sherbet")
    sizes = [(844, 390), (740, 360)]
    if "--all" in sys.argv:
        sizes += [(932, 430), (568, 320)]
    for W, H in sizes:
        save(screen_hud(W, H, th), "01-round-hud", W, H)
        save(screen_hud(W, H, th, drawer=True), "01b-round-hud-quest-drawer", W, H)
        save(screen_picker(W, H, th), "02-difficulty-picker", W, H)
        save(screen_results(W, H, th), "03-results", W, H)
        save(screen_quests(W, H, th), "04-quest-log-daily", W, H)
        save(screen_shop(W, H, th), "07-faceplate-shop", W, H)
    for pid in ("sherbet", "liquid_chrome", "night_orb", "brick"):
        print(pid, "; ".join(report(kit_theme(pid))))


if __name__ == "__main__":
    main()
