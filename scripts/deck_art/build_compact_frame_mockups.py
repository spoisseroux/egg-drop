"""Compact v2 "slim frame" mockups for UI-SPEC-COMPACT-FRAME-2026-11-12.md.

Run: python scripts/deck_art/build_compact_frame_mockups.py            (mockups + compare image)
     python scripts/deck_art/build_compact_frame_mockups.py --tables   (also print the spec tables as markdown)

frame_geometry(W, H) is the whole layout rule. Every picture is drawn from its result and the spec tables are
printed from the same result, so pictures and tables agree by construction. Output is 1:1 (one image pixel =
one Roblox offset pixel); "@2x" files are the same drawing at twice the size for zooming.
Concept drawings from the spec's numbers, not Studio captures.
"""
from __future__ import annotations

import sys

from PIL import Image, ImageChops

import build_compact_mockups as C
from build_compact_mockups import ASPECT, BEZEL, DIFF, back, fit, island, kit_theme, masked_gradient, roblox_bar
from build_mockups import STROKE, button, check_circle, chip, diff_bars, label, progress
from build_shell import button_base, button_gloss, dpad_arrows, dpad_disc, menu_pill, tint, wordmark_sprite
from common import MOCKUPS, Cv, contrast, egg_ball, egg_pts, gradient, hx, icon, mix, rounded_mask, DANGER, STAR

OUT = MOCKUPS / "compact-frame"
KX, KH = 116, 58                     # Roblox top-bar keep-out used in the mockups (runtime: GuiService.TopbarInset)
RIM, BEZ, PAD, GAP = 4, 5, 3, 8      # plate rim above and below the glass, glass bezel, screen padding, gap between cards
SIZES = [(844, 390), (740, 360), (932, 430), (568, 320)]
EXTRA = [(667, 375)]                 # not a reference root; drawn to show the one-column arrangement on a taller phone
GOALS = [("I+I CENTER", 2, 2), ("III+ RIGHT", 1, 2), ("Tier IV", 0, 1)]
GOAL_ICONS = [("merge", 2, False, "center"), ("merge", 3, True, "right"), ("merge", 4, True, "any")]
MARKS = {1: "I", 2: "II", 3: "III", 4: "IV", 5: "V"}
QUESTS = (("Win 2 rounds", 2, 2), ("Chain 4 merges", 3, 4), ("Tier IV on Hard", 0, 1))


# ------------------------------------------------------------------ the layout rule
def R(x, y, w, h):
    return (int(x), int(y), int(w), int(h))


def frame_geometry(W, H, kx=KX, kh=KH, goals=3):
    """Compact v2 as built. All rects are (x, y, w, h) in root px. DeckScreen.resolveCompact returns the same numbers.

    Spencer's decisions (spec section 9): shoulders 106 / 94 / 80, B not drawn on the touch HUD, the board is centred on
    every phone; side columns under 144 wide use icon-only goals ("narrow"). Under 96 the v1-style one column is kept.
    """
    g = {"W": W, "H": H, "kx": kx, "kh": kh}
    tier = 0 if H >= 380 else 1 if H >= 340 else 2
    SW = (106, 94, 80)[tier]         # shoulder width (decision 2)
    D = (88, 80, 68)[tier]           # d-pad diameter
    A = (92, 82, 70)[tier]           # A diameter; with its well (+10) it stays on the shoulder
    g.update(tier=tier, SW=SW, D=D, A=A, B=0)
    g["glass"] = R(SW, RIM, W - 2 * SW, H - 2 * RIM)                       # dark bezel, radius 16
    g["screen"] = R(SW + BEZ, RIM + BEZ, W - 2 * SW - 2 * BEZ, H - 2 * RIM - 2 * BEZ)   # lit LCD, radius 11
    x0, y0 = SW + BEZ + PAD, RIM + BEZ + PAD
    x1, y1 = W - x0, H - y0
    LW, LH = x1 - x0, y1 - y0
    g.update(x0=x0, y0=y0, x1=x1, y1=y1, LW=LW, LH=LH)
    # board: full screen height unless that would squeeze the side columns under 96
    bw = min(round(LH * ASPECT), LW - 2 * GAP - 2 * 96)
    bh = LH if bw == round(LH * ASPECT) else round(bw / ASPECT)
    c2 = (LW - bw - 2 * GAP) // 2
    mode = "wide" if c2 >= 144 else "narrow" if c2 >= 96 else "one"
    if mode == "one":                                                      # odd small windows only
        bw = min(round(LH * ASPECT), LW - GAP - 160)
        bh = LH if bw == round(LH * ASPECT) else round(bw / ASPECT)
    g["mode"] = mode
    g["columns"] = 1 if mode == "one" else 2
    by = y0 + (LH - bh) // 2
    p = 34 if H >= 340 else 26                                             # goal row pitch
    g["goalPitch"] = p
    t0 = max(x0, kx + 4) if y0 < kh else x0                                # first row keeps clear of the Roblox controls
    g["t0"] = t0
    g["quests"] = g["handle"] = g["drawer"] = g["controls"] = g["chain"] = None
    g["controlRows"] = 0
    if mode != "one":
        bx = x0 + (LW - bw) // 2
        L0, L1, R0, R1 = x0, bx - GAP, bx + bw + GAP, x1
        c, rc = L1 - L0, R1 - R0
        g.update(L0=L0, L1=L1, R0=R0, R1=R1, col=c, colR=rc)
        tw = L1 - t0
        if mode == "wide":
            if tw >= 154:
                g["chain"] = R(L1 - 64, y0, 64, 44)
                g["score"] = R(t0, y0, tw - 64 - GAP, 44)
                g["chainIn"] = "pill"
            else:
                g["score"] = R(t0, y0, tw, 44)
                g["chainIn"] = "score" if tw >= 130 else "goals"   # Chain shares the Score card, or drops to the Goals header
            gy = y0 + 52
        else:                                                   # narrow: Chain in the first row, Score under it
            if tw >= 64:
                g["chain"] = R(t0, y0, tw, 44)
                g["chainIn"] = "pill"
            else:
                g["chainIn"] = "goals"
            g["score"] = R(L0, y0 + 52, c, 44)
            gy = y0 + 104
        g["goalsTop"] = gy
        g["goals"] = R(L0, gy, c, 24 + goals * p + 6)
        gmax = gy + 24 + 3 * p + 6
        qp = 36 if H >= 380 else 34
        qh = 24 + 3 * qp + 8
        if mode == "wide" and y1 - qh >= gmax + GAP:
            g["quests"] = R(L0, y1 - qh, c, qh)
            g["questPitch"] = qp
        else:
            g["handle"] = R(L0, y1 - 44, c, 44)                  # opens the quest log
        nh = 64 if H >= 340 else 44
        g["next"] = R(R0, y0, rc, nh)
        g["eggs"] = R(R0, y0 + nh + GAP, rc, 44)
        g["difficulty"] = R(R0, y0 + nh + GAP + 52, rc, 44)
        g["winPays"] = R(R0, y0 + nh + GAP + 104, rc, 44)
        top = y0 + nh + GAP + 156
        rows = min(3, (y1 - top - 30) // 28)
        g["controls"] = R(R0, y1 - (30 + rows * 28), rc, 30 + rows * 28) if rows >= 2 else None
        g["controlRows"] = rows if rows >= 2 else 0
        g["toast"] = (R0 + rc // 2, y1 - 48)                               # centre x, top y; covers the Controls card
    else:
        bx = x1 - bw
        L0, L1 = x0, bx - GAP
        c = L1 - L0
        g.update(L0=L0, L1=L1, R0=None, R1=None, col=c, colR=0)
        tw = L1 - t0
        g["next"] = R(L1 - 76, y0, 76, 44)
        if tw >= 76 + GAP + 64 + GAP + 84:
            g["chain"] = R(L1 - 76 - GAP - 64, y0, 64, 44)
            g["score"] = R(t0, y0, tw - 76 - 64 - 2 * GAP, 44)
            g["chainIn"] = "pill"
        else:
            g["score"] = R(t0, y0, tw - 76 - GAP, 44)
            g["chainIn"] = "goals"
        gh = 24 + 3 * p + 6
        g["goalsTop"] = y0 + 52
        g["goals"] = R(L0, y0 + 52, c, 24 + goals * p + 6)
        ry = y0 + 52 + gh + GAP
        ew = 88 if c >= 200 else 58
        g["eggs"] = R(L0, ry, ew, 44)
        g["difficulty"] = R(L0 + ew + GAP, ry, c - ew - GAP, 44)
        wy = ry + 52
        g["winPays"] = R(L0, wy, c, 44 if wy + 44 <= y1 - 52 else y1 - 52 - wy)
        g["handle"] = R(L0, y1 - 44, c, 44)
        g["toast"] = (L0 + c // 2, y1 - 44 - 48)                           # covers the Win pays row
    g["board"] = R(bx, by, bw, bh)
    # shoulders
    dcy = kh + (H - kh - 52) // 2
    cx = SW // 2
    g["dpad"] = R(cx - D // 2, dcy - D // 2, D, D)
    hw, hh = max(44, D // 2), max(44, D)                                   # each half of the d-pad is a target
    shift = max(0, hw - cx)
    g["dpadLeft"] = R(cx - hw + shift, dcy - hh // 2, hw, hh)
    g["dpadRight"] = R(cx + shift, dcy - hh // 2, hw, hh)
    mw, hwm = min(72, SW - 16), min(84, SW - 8)
    g["menuHit"] = R(cx - hwm // 2, H - 52, hwm, 44)
    g["menu"] = R(cx - mw // 2, H - 44, mw, 28)
    ww = SW - 28
    g["wordmark"] = R(14, kh + 6, ww, round(ww * 16 / 41)) if ww >= 64 else None
    g["back"] = R(W - 56, 8, 44, 44)
    acy = round(H * .49)
    g["a"] = (W - SW // 2, acy)
    g["aHit"] = R(W - SW // 2 - (A + 8) // 2, acy - (A + 8) // 2, A + 8, A + 8)
    g["b"] = None                                                          # decision 4: B is unassigned on touch
    g["speaker"] = (W - 30, H - 26)
    # menu sheet: the same sheet as Compact v1, with wider plate grips left and right on wider phones
    mg = 40 if W >= 800 else 24 if W >= 700 else 6
    g["mg"] = mg
    g["sheetBezel"] = R(mg, 6, W - 2 * mg, H - 12)
    g["sheet"] = R(mg + 2, 8, W - 2 * mg - 4, H - 16)
    g["hx"] = max(kx + 12, mg + 18)
    g["cw"] = (W - 2 * mg - 48) // 3
    g["ch"] = H - 140
    g["actionY"] = H - 66
    g["pocket"] = pocket_geometry(g)
    return g


def pocket_geometry(g):
    """Pocket Menu inside the screen rect (decision 6). Rows 44 high, 8 apart; one column when five fit, else two."""
    sx, sy, sw, sh = g["screen"]
    pad = 12
    top = max(sy + pad + 36, g["kh"] + 4)                                 # under the title and clear of the keep-out
    avail = sy + sh - pad - top
    cols = 1 if 5 * 44 + 4 * GAP <= avail else 2
    rows = 5 if cols == 1 else 3
    iw = min(300, sw - 2 * pad) if cols == 1 else min(220, (sw - 2 * pad - GAP) // 2)
    total_w = iw * cols + GAP * (cols - 1)
    gx = sx + (sw - total_w) // 2
    gh = rows * 44 + (rows - 1) * GAP
    gy = top + max(0, (avail - gh) // 2)
    order = [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)] if cols == 1 else [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1)]
    items = [R(gx + col * (iw + GAP), gy + row * (44 + GAP), iw, 44) for col, row in order]
    tx = max(sx + pad, g["kx"] + 4) if sy + pad < g["kh"] else sx + pad
    return {"cols": cols, "items": items, "title": R(tx, sy + pad, sx + sw - pad - tx, 28)}


def v1_board(W, H):
    bh = H - 16
    return round(bh * ASPECT), bh


def targets(g):
    """Touch targets on the round HUD: name -> rect. Used for the 44 px, 8 px gap and keep-out checks."""
    t = {"dpadLeft": g["dpadLeft"], "dpadRight": g["dpadRight"], "menu": g["menuHit"], "back": g["back"], "a": g["aHit"],
         "board": g["board"]}
    if g["quests"]:
        t["quests"] = g["quests"]
    if g["handle"]:
        t["handle"] = g["handle"]
    return t


def inside(r, o):
    x, y, w, h = r
    ox, oy, ow, oh = o
    return x >= ox and y >= oy and x + w <= ox + ow and y + h <= oy + oh


def apart(r, o):
    x, y, w, h = r
    ox, oy, ow, oh = o
    return x + w <= ox or ox + ow <= x or y + h <= oy or oy + oh <= y


def check(g):
    W, H = g["W"], g["H"]
    t = targets(g)
    for n, (x, y, w, h) in t.items():
        assert w >= 44 and h >= 44, (W, H, n, "under 44")
        assert not (x < g["kx"] and y < g["kh"]), (W, H, n, "in the keep-out")
        assert x >= 0 and y >= 0 and x + w <= W and y + h <= H, (W, H, n, "off the root")
    names = list(t)
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            if {a, b} == {"dpadLeft", "dpadRight"}:     # two halves of one control
                continue
            ax, ay, aw, ah = t[a]
            bx, by, bw, bh = t[b]
            dx = max(bx - (ax + aw), ax - (bx + bw))
            dy = max(by - (ay + ah), ay - (by + bh))
            assert max(dx, dy) >= 8, (W, H, a, b, "closer than 8")
    screen = (g["x0"], g["y0"], g["LW"], g["LH"])
    for n in ("score", "chain", "next", "eggs", "difficulty", "winPays", "goals", "quests", "handle", "controls", "board"):
        if g.get(n):
            x, y, w, h = g[n]
            assert not (x < g["kx"] and y < g["kh"]), (W, H, n, "text in the keep-out")
            assert inside(g[n], screen), (W, H, n, "outside the screen")
    # glass: 4 px of plate above and below, hardware outside it (drawn rects)
    gx, gy, gw, gh = g["glass"]
    assert gy == 4 and gy + gh == H - 4 and gx == g["SW"], (W, H, "glass rim")
    A = g["A"]
    for n, r in (("dpad", g["dpad"]), ("menu", g["menu"]), ("back", g["back"]),
                 ("a", (g["a"][0] - A // 2, g["a"][1] - A // 2, A, A))):
        assert apart(r, g["glass"]), (W, H, n, "on the glass")
    bx, by, bw, bh = g["board"]
    assert abs(bw / bh - ASPECT) < .004, (W, H, "board aspect")
    for r in g["pocket"]["items"]:
        assert r[3] >= 44 and inside(r, g["screen"]), (W, H, "pocket row")
        assert not (r[0] < g["kx"] and r[1] < g["kh"]), (W, H, "pocket row in the keep-out")
    items = g["pocket"]["items"]
    for i in range(len(items)):
        for j in range(i + 1, len(items)):
            ax, ay, aw, ah = items[i]
            bx_, by_, bw_, bh_ = items[j]
            assert max(bx_ - (ax + aw), ax - (bx_ + bw_), by_ - (ay + ah), ay - (by_ + bh_)) >= 8, (W, H, "pocket rows closer than 8")


# ------------------------------------------------------------------ drawing: shell
def plate_canvas(W, H, th):
    """Faceplate over the whole root with the moulded lip and shade from the desktop plate overlay."""
    cv = C.canvas(W, H, th)
    z = cv.z
    cv.paste(gradient(W * z, int(H * z * .30), [(0, (255, 255, 255, 64)), (1, (255, 255, 255, 0))]), 0, 0, raw=True)
    sh = gradient(W * z, int(H * z * .38), [(0, (0, 0, 0, 0)), (1, (0, 0, 0, 74))])
    cv.paste(sh, 0, H * z - sh.height, raw=True)
    return cv


def well(cv, cx, cy, dia):
    r = dia / 2
    cv.shadow(cx - r, cy - r, dia, dia, r, blur=5, color=(0, 0, 0, 120), dy=2)
    cv.ell(cx, cy, r, fill=(0, 0, 0, 86))
    cv.arc(cx, cy, r, 20, 160, (255, 255, 255, 96), 1.5)
    cv.arc(cx, cy, r, 200, 340, (0, 0, 0, 90), 1.5)


def glass(cv, rect, r=16):
    x, y, w, h = rect
    cv.shadow(x, y, w, h, r, blur=8, color=(0, 0, 0, 150), dy=3, spread=2)
    cv.rr(x - 2, y - 2, w + 4, h + 4, r + 2, stroke=(255, 255, 255, 60), sw=1.5)
    cv.grad_rr(x, y, w, h, r, [(0, "#16181D"), (0.5, "#08090B"), (1, "#020203")])
    cv.rr(x, y, w, h, r, stroke=(255, 255, 255, 46), sw=1)
    cv.refresh()


def screen_fill(cv, rect, th, r=11):
    x, y, w, h = rect
    cv.rr(x, y, w, h, r, fill=th["panel"])
    cv.paste(masked_gradient(w, h, r, cv.z), x * cv.z, y * cv.z, raw=True)
    cv.rr(x, y, w, h, r, stroke=(255, 255, 255, 22), sw=1)


def shoulders(cv, g, th):
    W, H, SW, D, A = g["W"], g["H"], g["SW"], g["D"], g["A"]
    p = th["plate"]
    # left: wordmark, d-pad, MENU
    if g["wordmark"]:
        x, y, w, h = g["wordmark"]
        wm = wordmark_sprite(8).resize((w * 3, h * 3), Image.LANCZOS)
        dark = hx(p["engrave"]["color"])[0] < 128
        for col, alpha, off in ((("#FFFFFF" if dark else "#000000"), .30 if dark else .45, 1), (p["engrave"]["color"], p["engrave"]["opacity"], 0)):
            lay = tint(wm, col)
            lay.putalpha(lay.getchannel("A").point(lambda v, a=alpha: int(v * a)))
            cv.paste(lay, (x + off * .6) * 3, (y + off) * 3, raw=True)
    dx, dy, _, _ = g["dpad"]
    well(cv, dx + D / 2, dy + D / 2, D + 10)
    cv.paste(dpad_disc(D * 3), dx * 3, dy * 3, raw=True)
    cv.paste(tint(dpad_arrows(D * 3), p["accent"]), dx * 3, dy * 3, raw=True)
    mx, my, mw, mh = g["menu"]
    cv.rr(mx - 3, my - 3, mw + 6, mh + 6, mh / 2 + 3, fill=(0, 0, 0, 80))
    cv.rr(mx - 3, my - 3, mw + 6, mh + 6, mh / 2 + 3, stroke=(255, 255, 255, 44), sw=1)
    cv.paste(menu_pill(mw * 3, mh * 3, 1), mx * 3, my * 3, raw=True)
    cv.text(mx + mw / 2, my + mh / 2 + .5, "MENU", "b", 12, (230, 233, 238, 255), "mm", tracking=1.2)
    # right: back arrow, A, speaker seeds (B is unassigned on touch: decision 4)
    back(cv, W)
    ax, ay = g["a"]
    well(cv, ax, ay + 2, A + 10)
    cv.paste(tint(button_base(A * 3), p["accent"]), (ax - A / 2) * 3, (ay - A / 2) * 3, raw=True)
    cv.paste(button_gloss(A * 3), (ax - A / 2) * 3, (ay - A / 2) * 3, raw=True)
    cv.text(ax, ay + A * .02, "A", "xb", A * .46, p["ink"], "mm")
    sx, sy = g["speaker"]
    import math
    for ox, oy, rot in ((-34, -6, -20), (0, -16, 0), (34, -6, 20), (-18, 22, -10), (18, 22, 10)):
        pts = []
        for a, b in egg_pts(0, 0, 9.5, 14):
            c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
            pts.append((sx + (ox + a * c - b * s) * .3, sy + (oy + a * s + b * c) * .3))
        cv.poly([(q[0], q[1] + .8) for q in pts], (255, 255, 255, 70))
        cv.poly(pts, (10, 11, 14, 215))


# ------------------------------------------------------------------ drawing: screen content
def card(cv, rect, th, r=10, fill="raised"):
    x, y, w, h = rect
    cv.rr(x, y, w, h, r, fill=th[fill])
    cv.rr(x, y, w, h, r, stroke=STROKE, sw=1)


def board(cv, rect, th):
    bx, by, bw, bh = rect
    cv.rr(bx, by, bw, bh, 8, fill=th["well"])
    for gy in range(1, 12):
        cv.line([(bx + 8, by + gy * bh / 12), (bx + bw - 8, by + gy * bh / 12)], (255, 255, 255, 7), 1, False)
    cv.rr(bx, by, bw, bh, 8, stroke=STROKE, sw=1)
    s = bh / 584
    line_y = by + 200 * s
    for i in range(int((bw - 16) // 20)):
        cv.line([(bx + 10 + i * 20, line_y), (bx + 20 + i * 20, line_y)], hx(DANGER, 200), 2, False)
    chip(cv, bx + bw - 8, line_y - 26, "Line", mix(th["well"], DANGER, .25), hx(DANGER), 20, anchor="r", size=12)
    ax = bx + 196 * s
    for i in range(7):
        cv.ell(ax, by + (104 + i * 30) * s, 1.6, fill=(255, 255, 255, 60))
    egg_ball(cv, ax, by + 52 * s, 24 * s, 1)
    cv.poly([(ax - 7, by + 6), (ax + 7, by + 6), (ax, by + 15)], th["accent"])
    for x, y, r, t in ((48, 544, 34, 3), (112, 552, 26, 2), (160, 556, 22, 1), (214, 540, 38, 4), (282, 552, 26, 2), (300, 500, 22, 1),
                       (72, 486, 26, 2), (128, 502, 22, 1), (168, 510, 22, 1), (250, 478, 26, 2), (104, 444, 22, 1), (196, 468, 22, 1)):
        egg_ball(cv, bx + x * s, by + y * s, r * s, t)
    # one faint glare streak, board only
    z = cv.z
    gl = Image.new("L", (bw * z, bh * z), 0)
    from PIL import ImageDraw, ImageFilter
    d = ImageDraw.Draw(gl)
    d.polygon([(bw * z * .62, 0), (bw * z * .86, 0), (bw * z * .40, bh * z), (bw * z * .16, bh * z)], fill=13)
    gl = ImageChops.multiply(gl.filter(ImageFilter.GaussianBlur(6 * z)), rounded_mask(bw * z, bh * z, 8 * z, 1))
    lay = Image.new("RGBA", gl.size, (255, 255, 255, 0))
    lay.putalpha(gl)
    cv.paste(lay, bx * z, by * z, raw=True)


def stat(cv, rect, th, name, value, sub=None, chain=None):
    """Label over a Counter 18 value (Score, Chain)."""
    x, y, w, h = rect
    card(cv, rect, th)
    label(cv, x + 10, y + 5, name, th, size=12)
    tw = cv.text(x + 10, y + 39, value, "monob", 18, th["text"], "ls")
    if sub:
        cv.text(x + 12 + tw, y + 39, sub, "mono", 13, th["soft"], "ls")
    if chain:                                  # Chain shares the card, right-aligned
        label(cv, x + w - 10, y + 5, "Chain", th, anchor="ra", size=12)
        cv.text(x + w - 10, y + 39, chain, "monob", 18, th["text"], "rs")
        assert 10 + tw + 14 + cv.tw("CHAIN", "b", 12, .6) + 10 <= w, ("score and chain do not fit", w)


def row_card(cv, rect, th, name, value, vcol="text", star=False, vsize=17, sub=None):
    """One line: Label 12 left, Counter right (Eggs left, Win pays)."""
    x, y, w, h = rect
    card(cv, rect, th)
    pad = 12 if w >= 160 else 10
    if w < 160:
        vsize = min(vsize, 15)
    lw_ = label(cv, x + pad, y + h / 2 - 7, name, th, size=12)
    xr = x + w - pad
    if sub:
        xr -= cv.text(xr, y + h / 2 + 1, sub, "mono", 13, th["soft"], "rm") + 2
    tw = cv.text(xr, y + h / 2, value, "monob", vsize, th[vcol], "rm")
    left = xr - tw
    if star:
        icon(cv, "star", xr - tw - vsize * .5 - 4, y + h / 2 - .5, vsize)
        left -= vsize + 4
    assert x + pad + lw_ + 4 <= left, ("row card does not fit", name, w)


def stacked(cv, rect, th, name, value, sub=None, star=False, vsize=18):
    """Narrow column: Label 12 over a Counter (Eggs left, Win pays, Score)."""
    x, y, w, h = rect
    card(cv, rect, th)
    label(cv, x + 10, y + 5, name, th, size=12)
    vx = x + 10
    if star:
        icon(cv, "star", vx + vsize * .5, y + 33, vsize)
        vx += vsize + 4
    tw = cv.text(vx, y + 39, value, "monob", vsize, th["star"] if star else th["text"], "ls")
    if sub:
        tw += 2 + cv.text(vx + tw + 2, y + 39, sub, "mono", 13, th["soft"], "ls")
    assert vx - x + tw + 8 <= w, ("stacked card does not fit", name, w)
    assert cv.tw(name.upper(), "b", 12, .6) + 20 <= w, ("stacked label does not fit", name, w)


def zone_glyph(cv, x, cy, zone, th):
    """A mini tray split in thirds; the goal's third is lit. 18 x 12."""
    cv.rr(x, cy - 6, 18, 12, 3, stroke=th["soft"], sw=1.2)
    k = {"left": 0, "center": 1, "right": 2}[zone]
    cv.rr(x + 1.5 + k * 5, cy - 4.5, 5, 9, 1.5, fill=th["soft"])


def icon_goals_card(cv, rect, th, p, chain_inline):
    """Narrow column: one icon row per goal (decision 5). Tier egg with its mark, + for 'or higher', the zone glyph."""
    x, y, w, h = rect
    card(cv, rect, th)
    done = sum(1 for _, c, t in GOALS if c >= t)
    label(cv, x + 10, y + 8, f"Goals {done}/{len(GOALS)}", th, size=12)
    if chain_inline:
        cv.text(x + w - 10, y + 15, "×3", "monob", 13, th["text"], "rm")
    for i, ((_, c, gl), (kind, tier, plus, zone)) in enumerate(zip(GOALS, GOAL_ICONS)):
        cy = y + 24 + p / 2 + i * p
        egg_ball(cv, x + 19, cy, 11, tier, label=False)
        cv.text(x + 19, cy + .5, MARKS[tier], "xb", 12, (255, 255, 255, 240), "mm")
        gx = x + 33
        if plus:
            cv.text(gx, cy - 3, "+", "xb", 12, th["text"], "lm")
            gx += 9
        if zone != "any":
            zone_glyph(cv, gx, cy, zone, th)
        if c >= gl:
            check_circle(cv, x + w - 20, cy, True, th, 10)
        else:
            cnt = f"{c}/{gl}"
            tw = cv.text(x + w - 10, cy + .5, cnt, "monob", 13, th["soft"], "rm")
            assert gx + 18 + 6 <= x + w - 10 - tw, ("icon goal does not fit", w)


def goals_card(cv, rect, th, p, chain_inline):
    x, y, w, h = rect
    card(cv, rect, th)
    done = sum(1 for _, c, t in GOALS if c >= t)
    label(cv, x + 12, y + 8, f"Goals {done}/{len(GOALS)}", th, size=12)
    if chain_inline:
        cw_ = cv.text(x + w - 12, y + 15, "×3", "monob", 13, th["text"], "rm")
        label(cv, x + w - 16 - cw_, y + 8, "Chain", th, anchor="ra", size=12)
    for i, (t, c, gl) in enumerate(GOALS):
        cy = y + 24 + p / 2 + i * p
        check_circle(cv, x + 18, cy, c >= gl, th, 10)
        cnt = f"{c}/{gl}"
        cv.text(x + w - 10, cy + .5, cnt, "monob", 13, th["soft"], "rm")
        room = w - 34 - 10 - cv.tw(cnt, "monob", 13) - 6
        assert cv.tw(t, "m", 14) <= room, ("goal text does not fit", t, w)
        cv.text(x + 34, cy + .5, t, "m", 14, th["soft"] if c >= gl else th["text"], "lm")


def quests_card(cv, rect, th, qp):
    x, y, w, h = rect
    card(cv, rect, th)
    title = "Daily quests" if w >= 170 else "Quests"
    lw_ = label(cv, x + 12, y + 8, title, th, size=12)
    cv.line([(x + w - 17, y + 10), (x + w - 12, y + 15), (x + w - 17, y + 20)], th["soft"], 2)     # it opens the quest log
    cv.text(x + w - 26, y + 15, "1/3", "monob", 13, th["soft"], "rm")
    cv.ell(x + 12 + lw_ + 9, y + 15, 3.5, fill=STAR)
    stacked = w < 170                          # narrow: the count moves down beside the bar so the name gets the full line
    for i, (t, c, gl) in enumerate(QUESTS):
        ry = y + 24 + i * qp
        done = c >= gl
        col = hx(STAR) if done else th["soft"]
        if stacked:
            cv.text(x + 12, ry + 10, fit(cv, t, w - 24, "r", 14), "r", 14, th["text"], "lm")
            cv.text(x + w - 12, ry + 25, f"{c}/{gl}", "monob", 13, col, "rm")
            progress(cv, x + 12, ry + 23, w - 24 - 34, 4, c / gl, th, hx(STAR) if done else None)
        else:
            cv.text(x + 12, ry + qp / 2 - 4, fit(cv, t, w - 62, "r", 14), "r", 14, th["text"], "lm")
            cv.text(x + w - 12, ry + qp / 2 - 4, f"{c}/{gl}", "monob", 13, col, "rm")
            progress(cv, x + 12, ry + qp - 8, w - 24, 4, c / gl, th, hx(STAR) if done else None)


def handle(cv, rect, th):
    """Quest handle: opens the quest log (no drawer in v2). The word goes first when the column is narrow."""
    x, y, w, h = rect
    cv.rr(x, y, w, h, 12, fill=th["well"])
    cv.rr(x, y, w, h, 12, stroke=STROKE, sw=1)
    icon(cv, "quests", x + 22, y + 22, 18, th["text"])
    cv.ell(x + 31, y + 13, 4, fill=STAR)
    if w >= 130:
        cv.text(x + 38, y + 22.5, "Quests", "b", 14, th["text"], "lm")
    cv.text(x + w - 26, y + 22.5, "1/3", "monob", 13, th["soft"], "rm")
    cv.line([(x + w - 17, y + 17), (x + w - 12, y + 22), (x + w - 17, y + 27)], th["soft"], 2)


def drawer(cv, rect, th):
    x, y, w, h = rect
    cv.shadow(x, y, w, h, 10, blur=8, color=(0, 0, 0, 140), dy=2)
    card(cv, rect, th, fill="raised")
    cv.rr(x, y, w, h, 10, stroke=(255, 255, 255, 60), sw=1)
    label(cv, x + 12, y + 16, "Daily quests", th, size=12)
    cx, cy = x + w - 22, y + 22
    cv.line([(cx - 6, cy - 3), (cx, cy + 3), (cx + 6, cy - 3)], th["text"], 2.2)
    for i, (t, c, gl) in enumerate(QUESTS):
        ry = y + 46 + i * 44
        done = c >= gl
        cv.text(x + 12, ry + 12, fit(cv, t, w - 70, "r", 14), "r", 14, th["text"], "lm")
        cv.text(x + w - 12, ry + 12, f"{c}/{gl}", "monob", 13, hx(STAR) if done else th["soft"], "rm")
        progress(cv, x + 12, ry + 28, w - 24, 4, c / gl, th, hx(STAR) if done else None)
    button(cv, x + 12, y + h - 56, w - 24, 44, "Open quest log", th, "secondary", size=15)


def next_card(cv, rect, th, tall):
    x, y, w, h = rect
    card(cv, rect, th)
    if tall:                                  # two-column, H >= 340: labels over the eggs, like desktop
        label(cv, x + 12, y + 7, "Next", th, size=12)
        egg_ball(cv, x + 30, y + 40, 18, 2)
        tx = x + 70
        label(cv, tx, y + 7, "Then", th, size=12)
        egg_ball(cv, tx + 12, y + 42, 12, 1)
        if w >= 150:
            egg_ball(cv, tx + 40, y + 42, 12, 3)
    else:                                     # 44 high pill
        with_label = w >= 124
        content = (40 if with_label else 0) + 32 + 30
        nx = x + (w - content) / 2
        if with_label:
            label(cv, nx, y + 16, "Next", th, size=12)
            nx += 40
        egg_ball(cv, nx + 16, y + 22, 16, 2)
        egg_ball(cv, nx + 32 + 8 + 11, y + 22, 11, 1)


def difficulty_card(cv, rect, th, diff):
    x, y, w, h = rect
    name, _, level, dcol, mult, pays, _ = DIFF[diff]
    card(cv, rect, th)
    nx = 46 if w >= 120 else 40
    diff_bars(cv, x + (12 if w >= 120 else 9), y + 11, level, hx(dcol), th)
    ns = 15 if w >= 120 else 14                       # Strong 14 in a narrow column (spec 3.4 allows 14 / 15)
    cv.text(x + nx, y + h / 2 + .5, name, "b", ns, th["text"], "lm")
    if w >= 170:
        chip(cv, x + w - 10, y + 11, f"×{mult}", mix(th["well"], STAR, .14), hx(STAR), 22, "star", anchor="r", size=12)
    assert nx + cv.tw("Medium", "b", ns) + 6 <= w, ("difficulty name does not fit", w)


def controls_card(cv, rect, th, rows, touch=True):
    x, y, w, h = rect
    card(cv, rect, th)
    label(cv, x + 12, y + 8, "Controls", th, size=12)
    p = th["plate"]
    items = (("drag", "Drag the board", "Aim"), ("A", "", "Drop"))[:rows]      # touch: no B row (decision 4)
    for i, (k, _, what) in enumerate(items):
        cy = y + 24 + 14 + i * 28
        if k == "drag":
            cv.rr(x + 12, cy - 10, 38, 20, 10, fill=th["well"])
            cv.rr(x + 12, cy - 10, 38, 20, 10, stroke=STROKE, sw=1)
            cv.line([(x + 21, cy), (x + 41, cy)], th["soft"], 1.8)
            cv.line([(x + 25, cy - 4), (x + 21, cy), (x + 25, cy + 4)], th["soft"], 1.8)
            cv.line([(x + 37, cy - 4), (x + 41, cy), (x + 37, cy + 4)], th["soft"], 1.8)
        else:
            col = p["accent"] if k == "A" else "#3A3E47"
            cv.ell(x + 31, cy, 10, fill=hx(col))
            cv.text(x + 31, cy + .5, k, "xb", 12, p["ink"] if k == "A" else "#E6E9EE", "mm")
        cv.text(x + 60, cy + .5, what, "r", 14, th["text"], "lm")
        if k == "drag" and w >= 170:
            cv.text(x + w - 12, cy + .5, "drag board", "r", 12, th["soft"], "rm")


def pocket_menu(cv, g, th, armed=1):
    """Decision 6: the Pocket Menu on the deck screen. Row `armed` shows the mid-round one-tap confirm."""
    sx, sy, sw, sh = g["screen"]
    cv.rr(sx, sy, sw, sh, 11, fill=th["panel"])
    cv.paste(masked_gradient(sw, sh, 11, cv.z), sx * cv.z, sy * cv.z, raw=True)
    pm = g["pocket"]
    tx, ty, tw_, _ = pm["title"]
    cv.text(tx, ty + 14, "Pocket menu", "b", 20, th["text"], "lm")
    cv.text(sx + sw - 12, ty + 14, "Round paused", "r", 14, th["soft"], "rm")
    names = ("Resume", "Restart round", "Quit to garden", "Hatch eggs", "Customize")
    for i, (r, n) in enumerate(zip(pm["items"], names)):
        x, y, w, h = r
        if i == armed:
            n = "Tap again to restart"
            button(cv, x, y, w, h, n, th, "danger", "focus", size=16)
        else:
            button(cv, x, y, w, h, n, th, "primary" if i == 0 else "secondary", size=16)
        assert cv.tw(n, "b", 16) + 24 <= w, ("pocket row text", n, w)


def screen_hud(W, H, th, diff="hard", open_drawer=False, bar=True, pocket=False):
    g = frame_geometry(W, H)
    check(g)
    cv = plate_canvas(W, H, th)
    glass(cv, g["glass"])
    screen_fill(cv, g["screen"], th)
    name, _, level, dcol, mult, pays, _ = DIFF[diff]
    board(cv, g["board"], th)
    narrow = g["mode"] == "narrow"
    if narrow:
        stacked(cv, g["score"], th, "Score", "2,340")
    else:
        stat(cv, g["score"], th, "Score", "2,340", chain="×3" if g["chainIn"] == "score" else None)
    if g["chain"]:
        stat(cv, g["chain"], th, "Chain", "×3")
    two = g["columns"] == 2
    next_card(cv, g["next"], th, tall=g["next"][3] >= 64)
    if narrow:
        stacked(cv, g["eggs"], th, "Eggs left", "14", sub="/24")
    elif two or g["eggs"][2] >= 88:
        if two:
            row_card(cv, g["eggs"], th, "Eggs left", "14", vsize=18, sub="/24")
        else:
            stat(cv, g["eggs"], th, "Eggs", "14", "/24")
    else:
        stat(cv, g["eggs"], th, "Eggs", "14")
    difficulty_card(cv, g["difficulty"], th, diff)
    if narrow:
        stacked(cv, g["winPays"], th, "Win pays", pays.replace(" to ", "–"), star=True, vsize=15)
    else:
        row_card(cv, g["winPays"], th, "Win pays", pays.replace(" to ", "–"), "star", star=True)
    if g["controls"]:
        x, y, w, h = g["controls"]
        n = min(2, g["controlRows"])                       # touch rows; the card follows them, bottom-anchored
        controls_card(cv, (x, y + h - (30 + 28 * n), w, 30 + 28 * n), th, n, touch=True)
    if open_drawer and g["drawer"]:
        drawer(cv, g["drawer"], th)
    else:
        if narrow:
            icon_goals_card(cv, g["goals"], th, g["goalPitch"], chain_inline=g["chainIn"] == "goals")
        else:
            goals_card(cv, g["goals"], th, g["goalPitch"], chain_inline=g["chainIn"] == "goals")
        if g["quests"]:
            quests_card(cv, g["quests"], th, g["questPitch"])
        if g["handle"]:
            handle(cv, g["handle"], th)
    if pocket:
        pocket_menu(cv, g, th)
    shoulders(cv, g, th)
    if bar:
        roblox_bar(cv)
    return cv


# ------------------------------------------------------------------ menu sheets in the frame
def grips(cv, g, th):
    """Detail on the plate strips either side of a menu sheet (only when they are at least 24 wide)."""
    mg, W, H = g["mg"], g["W"], g["H"]
    if mg < 24:
        return
    for cx in (mg / 2, W - mg / 2):
        for i in (-2, -1, 0, 1, 2):          # moulded thumb ridges
            y = H / 2 + i * 11
            cv.rr(cx - mg * .26, y - 2, mg * .52, 4, 2, fill=(0, 0, 0, 78))
            cv.rr(cx - mg * .26 + 1, y + 2, mg * .52 - 2, 1, 0, fill=(255, 255, 255, 60))


def sheet_screen(fn, W, H, th, **kw):
    """Draw a Compact v1 sheet screen at the narrower width, then set it into the framed plate.

    The v1 functions lay everything out from W with a 6 px rim, so drawing them at W - 2 * (mg - 6) and
    shifting by (mg - 6) is the v2 rule: same sheet, wider plate grips, header still clear of the keep-out.
    """
    g = frame_geometry(W, H)
    off = g["mg"] - 6
    C.KX = max(KX - off, 6)                    # the keep-out in the narrower sheet's coordinates
    inner = fn(W - 2 * off, H, th, **kw)
    C.KX = KX
    cv = plate_canvas(W, H, th)
    z = cv.z
    bx, by, bw, bh = g["sheetBezel"]
    cv.shadow(bx, by, bw, bh, 18, blur=8, color=(0, 0, 0, 150), dy=3, spread=2)
    cv.rr(bx - 2, by - 2, bw + 4, bh + 4, 20, stroke=(255, 255, 255, 60), sw=1.5)
    part = inner.im.crop((6 * z, 6 * z, (6 + bw) * z, (6 + bh) * z)).convert("RGBA")
    part.putalpha(rounded_mask(bw * z, bh * z, 18 * z, 1))
    cv.paste(part, bx * z, by * z, raw=True)
    grips(cv, g, th)
    roblox_bar(cv)
    return cv


# ------------------------------------------------------------------ output
def save(cv, name, x2=False):
    OUT.mkdir(parents=True, exist_ok=True)
    cv.out().convert("RGB").save(OUT / f"{name}.png")
    if x2:
        cv.im.resize((cv.w * 2, cv.h * 2), Image.LANCZOS).convert("RGB").save(OUT / f"{name}@2x.png")


def stack(images, captions, name, gap=14, cap_h=30, cols=1):
    """Contact sheet: captioned 1:1 images on a dark ground."""
    w = max(i.width for i in images)
    h = max(i.height for i in images)
    rows = -(-len(images) // cols)
    sheet = Cv(cols * w + (cols + 1) * gap, rows * (h + cap_h + gap) + gap, z=1, bg=(16, 18, 22, 255))
    for n, (im, cap) in enumerate(zip(images, captions)):
        x = gap + (n % cols) * (w + gap)
        y = gap + (n // cols) * (h + cap_h + gap)
        sheet.text(x + 2, y + cap_h / 2 - 1, cap, "b", 15, (230, 233, 238, 255), "lm")
        sheet.paste(im.convert("RGBA"), x, y + cap_h, raw=True)
    OUT.mkdir(parents=True, exist_ok=True)
    sheet.out().convert("RGB").save(OUT / f"{name}.png")


def tables():
    gs = [frame_geometry(W, H) for W, H in SIZES + EXTRA]
    head = "| | " + " | ".join(f"{g['W']}×{g['H']}" for g in gs) + " |"
    sep = "|---|" + "---|" * len(gs)

    def r(v):
        return "none" if v is None else f"{v[0]}, {v[1]}, {v[2]}×{v[3]}"

    def row(name, f):
        return f"| {name} | " + " | ".join(str(f(g)) for g in gs) + " |"
    out = ["### Shell and screen", head, sep,
           row("Shoulder `SW`", lambda g: g["SW"]),
           row("Glass (bezel)", lambda g: r(g["glass"])),
           row("Screen content `x0..x1, y0..y1`", lambda g: f"{g['x0']}..{g['x1']}, {g['y0']}..{g['y1']}"),
           row("`LW × LH`", lambda g: f"{g['LW']}×{g['LH']}"),
           row("Layout", lambda g: g["mode"]),
           row("Board", lambda g: r(g["board"])),
           row("Board today (v1)", lambda g: "%d×%d" % v1_board(g["W"], g["H"])),
           row("Height lost", lambda g: f"{v1_board(g['W'], g['H'])[1] - g['board'][3]} px ({(v1_board(g['W'], g['H'])[1] - g['board'][3]) / v1_board(g['W'], g['H'])[1] * 100:.1f}%)"),
           row("Info column width", lambda g: f"{g['col']}" + (f" and {g['colR']}" if g["columns"] == 2 else "")),
           "", "### Shoulders", head, sep,
           row("D-pad", lambda g: f"{g['dpad'][0]}, {g['dpad'][1]}, Ø {g['D']}"),
           row("MENU pill (drawn)", lambda g: r(g["menu"])),
           row("MENU hit", lambda g: r(g["menuHit"])),
           row("Wordmark", lambda g: r(g["wordmark"])),
           row("Back arrow", lambda g: r(g["back"])),
           row("A centre, Ø", lambda g: f"{g['a'][0]}, {g['a'][1]}, {g['A']}"),
           row("A hit", lambda g: r(g["aHit"])),
           row("D-pad halves (hit)", lambda g: r(g["dpadLeft"]) + " / " + r(g["dpadRight"])),
           "", "### Screen cards", head, sep,
           row("Score", lambda g: r(g["score"])),
           row("Chain", lambda g: r(g["chain"]) if g["chain"] else "in the Score card" if g["chainIn"] == "score" else "in Goals header"),
           row("Goals (3 goals)", lambda g: r(g["goals"])),
           row("Daily quests card", lambda g: r(g["quests"])),
           row("Quest handle", lambda g: r(g["handle"])),

           row("Next", lambda g: r(g["next"])),
           row("Eggs", lambda g: r(g["eggs"])),
           row("Difficulty", lambda g: r(g["difficulty"])),
           row("Win pays", lambda g: r(g["winPays"])),
           row("Controls (max rows; touch shows 2)", lambda g: (r(g["controls"]) + f" ({g['controlRows']} rows)") if g["controls"] else "none"),
           row("Toast (centre x, top y)", lambda g: f"{g['toast'][0]}, {g['toast'][1]}"),
           "", "### Menu sheet", head, sep,
           row("Side grip `mg`", lambda g: g["mg"]),
           row("Sheet", lambda g: r(g["sheet"])),
           row("`hx`", lambda g: g["hx"]),
           row("`cw × ch`", lambda g: f"{g['cw']}×{g['ch']}"),
           row("Action row y", lambda g: g["actionY"]),
           "", "### Pocket Menu", head, sep,
           row("Columns", lambda g: g["pocket"]["cols"]),
           row("Title", lambda g: r(g["pocket"]["title"])),
           row("Resume (first row)", lambda g: r(g["pocket"]["items"][0])),
           row("Customize (last row)", lambda g: r(g["pocket"]["items"][4]))]
    print("\n".join(out))


def main():
    th = kit_theme("sherbet")
    for W, H in SIZES + EXTRA:
        save(screen_hud(W, H, th), f"01-round-hud-{W}x{H}", x2=(W, H) in SIZES)
    for W, H in ((844, 390), (740, 360), (568, 320)):
        save(screen_hud(W, H, th, pocket=True), f"05-pocket-menu-{W}x{H}")
    for W, H in SIZES:
        save(sheet_screen(C.screen_results, W, H, th), f"03-results-{W}x{H}", x2=(W, H) == (844, 390))
    for W, H in ((844, 390), (568, 320)):
        save(sheet_screen(C.screen_picker, W, H, th), f"02-difficulty-picker-{W}x{H}")
        save(sheet_screen(C.screen_quests, W, H, th), f"04-quest-log-daily-{W}x{H}")
    save(sheet_screen(C.screen_shop, 844, 390, th), "07-faceplate-shop-844x390")
    # faceplates: the plate must still recolour the phone
    plates = (("sherbet", "Scout"), ("night_orb", "Night Orb"), ("aqua_pop", "Aqua Pop"))
    huds, res, small = [], [], []
    for pid, _ in plates:
        t = kit_theme(pid)
        h = screen_hud(844, 390, t)
        r_ = sheet_screen(C.screen_results, 844, 390, t)
        s = screen_hud(568, 320, t)
        if pid != "sherbet":
            save(h, f"01-round-hud-844x390-{pid}")
            save(r_, f"03-results-844x390-{pid}")
            save(s, f"01-round-hud-568x320-{pid}")
        huds.append(h.out())
        res.append(r_.out())
        small.append(s.out())
    stack(huds + res, [f"{n}: round HUD 844×390" for _, n in plates] + [f"{n}: results 844×390" for _, n in plates], "faceplates-844x390", cols=2 if False else 1)
    stack(small, [f"{n}: round HUD 568×320" for _, n in plates], "faceplates-568x320")
    # side by side: today's Compact against the slim frame
    old = C.screen_hud(844, 390, th)
    roblox_bar(old)
    stack([old.out(), screen_hud(844, 390, th).out()],
          ["Before: Compact v1, glass islands on a full-screen plate (board 223×374)",
           "Compact v2 as built: slim frame, one LCD between two shoulders (board %d×%d)" % frame_geometry(844, 390)["board"][2:]],
          "compare-844x390", cols=2)
    for pid in ("sherbet", "night_orb", "aqua_pop", "liquid_chrome", "brick"):
        t = kit_theme(pid)
        print(pid, f"text/raised {contrast(t['text'], t['raised']):.2f}; soft/raised {contrast(t['soft'], t['raised']):.2f}; dim/raised {contrast(t['dim'], t['raised']):.2f};"
              f" dim/panel {contrast(t['dim'], t['panel']):.2f}; soft/well {contrast(t['soft'], t['well']):.2f}; star/raised {contrast(t['star'], t['raised']):.2f};"
              f" menu label {contrast((230, 233, 238), hx('#353941')):.2f}")
    if "--tables" in sys.argv:
        tables()


if __name__ == "__main__":
    main()
