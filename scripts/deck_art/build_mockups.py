"""Mockups for UI-SPEC-2026-11-12.md: every wide-deck screen, the component sheet and a phone check.

Run after the shell and faceplates exist: python scripts/deck_art/build_mockups.py
Each screen is drawn once in LCD pixels (848 x 608 at the reference scale) and saved twice:
  <name>-glass@2x.png   the LCD alone at 2x, for reading sizes
  <name>.png            the whole 1920 x 1080 view: garden backdrop, deck, back arrow
These are concept drawings built from the spec's own numbers, not Studio captures.
"""
from __future__ import annotations

import json
import math

import numpy as np
from PIL import Image, ImageFilter

from build_shell import PAD, compose_deck
from common import (ASSETS, DECK, MOCKUPS, Cv, egg_ball, gradient, hx, icon, mix, rounded_mask, star_pts, ui_theme,
                    DANGER, DIM, GOOD, INK, SOFT, STAR, TEXT)

LW, LH = 848, 608
STROKE = (255, 255, 255, 36)       # 1 px white at 14%
PLATES = {p["id"]: p for p in json.loads((ASSETS / "faceplates" / "faceplates.json").read_text())["faceplates"]}


def theme(pid="sherbet"):
    p = PLATES[pid]
    t = ui_theme(p["accent"], p["deep"])
    t["plate"] = p
    return t


def state(c, kind):
    """Hover lightens 6%, pressed darkens 8%."""
    return mix(c, "#FFFFFF", .06) if kind == "hover" else mix(c, "#000000", .08) if kind == "pressed" else c


# ================================================================== components
def card(cv, x, y, w, h, th, fill="raised", r=14, st="idle"):
    if st == "selected":
        cv.rr(x, y, w, h, r, fill=th["selected"])
        cv.rr(x, y, w, h, r, stroke=th["accent"], sw=2)
    else:
        cv.rr(x, y, w, h, r, fill=state(th[fill], st))
        if st != "disabled":
            cv.rr(x, y, w, h, r, stroke=STROKE, sw=1)


def label(cv, x, y, s, th, color=None, anchor="la", size=13):
    return cv.text(x, y, s.upper(), "b", size, color or th["dim"], anchor, tracking=0.6)


def glyph(cv, x, y, letter, th, on_accent=False, size=24):
    """Input glyph chip. Round for A / B, pill for longer labels."""
    w = size if len(letter) == 1 else cv.tw(letter, "b", size * .5, .5) + size * .7
    fill = (14, 15, 18, 46) if on_accent else (255, 255, 255, 30)
    cv.rr(x, y, w, size, size / 2, fill=fill)
    cv.rr(x, y, w, size, size / 2, stroke=(14, 15, 18, 90) if on_accent else (255, 255, 255, 70), sw=1)
    if letter in ("<", ">", "^", "v", "<>", "^v", "+"):
        cx, cy, a = x + w / 2, y + size / 2, size * .19
        col = th["ink"] if on_accent else th["text"]
        if letter == "+":
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                cv.poly([(cx + dx * a * 1.7, cy + dy * a * 1.7), (cx + dx * a * .5 - dy * a * .7, cy + dy * a * .5 - dx * a * .7), (cx + dx * a * .5 + dy * a * .7, cy + dy * a * .5 + dx * a * .7)], col)
        elif letter == "<>":
            cv.poly([(cx - a * 2.1, cy), (cx - a * .5, cy - a * 1.1), (cx - a * .5, cy + a * 1.1)], col)
            cv.poly([(cx + a * 2.1, cy), (cx + a * .5, cy - a * 1.1), (cx + a * .5, cy + a * 1.1)], col)
    else:
        cv.text(x + w / 2, y + size / 2 + .5, letter, "b", size * (.56 if len(letter) == 1 else .5), th["ink"] if on_accent else th["text"], "mm", tracking=0 if len(letter) == 1 else .5)
    return w


def button(cv, x, y, w, h, text, th, kind="secondary", st="idle", key=None, size=20, ico=None):
    """kind: primary | secondary | ghost | danger | reward. st: idle | hover | pressed | selected | disabled | focus."""
    r = 12
    focus = st == "focus"
    base = "idle" if focus else st
    if kind in ("primary", "reward") and base != "disabled":
        fill = th["accent"] if kind == "primary" else th["star"]
        fill = state(fill, base)
        if base == "pressed":
            cv.rr(x, y + 2, w, h - 2, r, fill=fill)
            ty = y + 2 + (h - 2) / 2
        else:
            cv.rr(x, y, w, h, r, fill=mix(fill, "#000000", .38))
            cv.rr(x, y, w, h - 3, r, fill=fill)
            cv.grad_rr(x, y, w, (h - 3) * .5, r, [(0, (255, 255, 255, 46)), (1, (255, 255, 255, 0))])
            ty = y + (h - 3) / 2
        fg, on_accent = th["ink"] if kind == "primary" else hx(INK), True
    else:
        on_accent = False
        if base == "disabled":
            cv.rr(x, y, w, h, r, fill=th["raised"][:3] + (150,))
            fg = th["dim"][:3] + (150,)
        elif kind == "ghost":
            if base in ("hover", "pressed"):
                cv.rr(x, y, w, h, r, fill=(255, 255, 255, 16 if base == "hover" else 10))
            fg = th["text"]
        elif kind == "danger":
            cv.rr(x, y, w, h, r, fill=state(mix(th["raised"], DANGER, .10), base))
            cv.rr(x, y, w, h, r, stroke=hx(DANGER), sw=1.5)
            fg = hx(DANGER)
        else:
            sel = base == "selected"
            cv.rr(x, y, w, h, r, fill=th["selected"] if sel else state(th["raised"], base))
            cv.rr(x, y, w, h, r, stroke=th["accent"] if sel else STROKE, sw=2 if sel else 1)
            fg = th["text"]
        ty = y + h / 2 + (2 if base == "pressed" else 0)
    tw = cv.tw(text, "b", size)
    gw = (26 + 10) if key else 0
    iw = (size + 8) if ico else 0
    tx = x + (w - tw - gw - iw) / 2
    if key:
        glyph(cv, tx, ty - 13, key, th, on_accent, 26)
    if ico:
        icon(cv, ico, tx + gw + size / 2, ty, size, fg, accent=fg if ico == "star" else None)
    cv.text(tx + gw + iw, ty + .5, text, "b", size, fg, "lm")
    if focus:
        cv.glow_ring(x - 4, y - 4, w + 8, h + 8, r + 4)


def tabs(cv, x, y, w, h, items, sel, th, dots=(), focus=False):
    cv.rr(x, y, w, h, h / 2, fill=th["well"])
    cv.rr(x, y, w, h, h / 2, stroke=STROKE, sw=1)
    sw_ = (w - 8) / len(items)
    for i, s in enumerate(items):
        sx = x + 4 + i * sw_
        if i == sel:
            cv.rr(sx, y + 4, sw_, h - 8, (h - 8) / 2, fill=th["accent"])
        tw = cv.text(sx + sw_ / 2, y + h / 2 + .5, s, "b", 17, th["ink"] if i == sel else th["soft"], "mm")
        if i in dots:
            cv.ell(sx + sw_ / 2 + tw / 2 + 9, y + h / 2 - 7, 4, fill=STAR)
    if focus:
        sx = x + 4 + sel * sw_
        cv.glow_ring(sx - 4, y, sw_ + 8, h, h / 2)


def progress(cv, x, y, w, h, frac, th, color=None):
    cv.rr(x, y, w, h, h / 2, fill=th["well"])
    if frac > 0:
        cv.rr(x, y, max(h, w * min(1, frac)), h, h / 2, fill=color or th["accent"])


def segmented(cv, x, y, n, filled, th, sw_=20, sh=10, gap=4, color=None):
    for i in range(n):
        cv.rr(x + i * (sw_ + gap), y, sw_, sh, 3, fill=(color or th["accent"]) if i < filled else th["well"])
        if i >= filled:
            cv.rr(x + i * (sw_ + gap), y, sw_, sh, 3, stroke=STROKE, sw=1)


def chip(cv, x, y, text, fill, fg, h=26, ico=None, stroke=None, size=13, anchor="l"):
    w = cv.tw(text.upper(), "b", size, .6) + 20 + (18 if ico else 0)
    if anchor == "r":
        x -= w
    cv.rr(x, y, w, h, h / 2, fill=fill)
    if stroke:
        cv.rr(x, y, w, h, h / 2, stroke=stroke, sw=1)
    tx = x + 10
    if ico:
        icon(cv, ico, tx + 7, y + h / 2, 15, fg, accent=fg if ico == "star" else None)
        tx += 18
    cv.text(tx, y + h / 2 + .5, text.upper(), "b", size, fg, "lm", tracking=.6)
    return w


def wallet(cv, xr, y, amount, th, h=40):
    s = f"{amount:,}"
    w = cv.tw(s, "monob", 18) + 58
    cv.rr(xr - w, y, w, h, h / 2, fill=th["well"])
    cv.rr(xr - w, y, w, h, h / 2, stroke=STROKE, sw=1)
    icon(cv, "star", xr - w + 24, y + h / 2, 22)
    cv.text(xr - 18, y + h / 2, s, "monob", 18, th["text"], "rm")
    return w


def stars(cv, x, y, text, th, size=18, anchor="l"):
    w = cv.tw(text, "monob", size) + size + 6
    if anchor == "r":
        x -= w
    icon(cv, "star", x + size / 2, y, size)
    cv.text(x + size + 6, y, text, "monob", size, th["star"], "lm")
    return w


def toggle(cv, x, y, on, th, st="idle"):
    w, h = 52, 30
    a = 120 if st == "disabled" else 255
    cv.rr(x, y, w, h, h / 2, fill=(th["accent"][:3] + (a,)) if on else (th["well"][:3] + (a,)))
    if not on:
        cv.rr(x, y, w, h, h / 2, stroke=STROKE, sw=1)
    cv.ell(x + (w - 15 if on else 15), y + h / 2, 11, fill=(th["ink"][:3] + (a,)) if on else (195, 200, 208, a))
    if st == "focus":
        cv.glow_ring(x - 4, y - 4, w + 8, h + 8, h / 2 + 4)


def toast(cv, cx, y, text, reward, th):
    w = cv.tw(text, "b", 17) + cv.tw(reward, "monob", 17) + 124
    x = cx - w / 2
    cv.shadow(x, y, w, 48, 24, blur=14, color=(0, 0, 0, 130), dy=6)
    cv.rr(x, y, w, 48, 24, fill=th["well"])
    cv.rr(x, y, w, 48, 24, stroke=hx(STAR), sw=1.5)
    icon(cv, "check", x + 28, y + 24, 22, hx(STAR))
    cv.text(x + 50, y + 24, text, "b", 17, th["text"], "lm")
    stars(cv, x + w - 20, y + 24, reward, th, 17, "r")
    return w


def hints(cv, x, y, items, th, right=None):
    for key, text in items:
        x += glyph(cv, x, y - 11, key, th, False, 22) + 6
        x += (cv.text(x, y + .5, text, "r", 14, th["soft"], "lm") + 18) if text else 0
    if right:
        cv.text(LW - 24, y + .5, right, "r", 14, th["dim"], "rm")


def check_circle(cv, cx, cy, done, th, r=11):
    if done:
        cv.ell(cx, cy, r, fill=th["accent"])
        icon(cv, "check", cx, cy, r * 1.5, th["ink"], w=2.4)
    else:
        cv.ell(cx, cy, r, stroke=th["dim"], sw=2)


def quest_row(cv, x, y, w, th, title, sub, cur, goal, reward, st="progress", ico="target", action=None, focus=False, h=92):
    """st: progress | ready | claimed | locked. action: (text, kind) or None."""
    ready, claimed, locked = st == "ready", st == "claimed", st == "locked"
    cv.rr(x, y, w, h, 14, fill=mix(th["raised"], STAR, .07) if ready else th["raised"])
    cv.rr(x, y, w, h, 14, stroke=hx(STAR) if ready else STROKE, sw=2 if ready else 1)
    fade = 150 if (claimed or locked) else 255
    cv.rr(x + 16, y + 18, 56, 56, 14, fill=th["well"])
    icon(cv, "lock" if locked else "check" if claimed else ico, x + 44, y + 46, 28,
         (th["dim"] if locked else th["accent"] if claimed else th["text"])[:3] + (fade,), accent=th["accent"])
    cv.text(x + 88, y + 16, title, "b", 19, th["text"][:3] + (fade,))
    cv.text(x + 88, y + 42, sub, "r", 14, th["soft"][:3] + (fade,))
    bw = w - 88 - 190
    progress(cv, x + 88, y + 68, bw - 56, 8, cur / goal, th, hx(STAR) if ready else (th["accent"][:3] + (fade,)))
    cv.text(x + 88 + bw - 46, y + 72, f"{cur}/{goal}", "monob", 14, th["soft"][:3] + (fade,), "lm")
    stars(cv, x + w - 18, y + 26, f"+{reward}", th, 18, "r")
    if action:
        button(cv, x + w - 138, y + 44, 120, 38, action[0], th, action[1], "focus" if focus else "idle", size=16,
               key="A" if focus else None)
    elif claimed:
        chip(cv, x + w - 18, y + 50, "Claimed", th["well"], th["soft"], anchor="r")
    elif locked:
        chip(cv, x + w - 18, y + 50, "Locked", th["well"], th["dim"], anchor="r")


def list_row(cv, x, y, w, th, left, title, right, st="idle", h=44, done=True):
    if st in ("hover", "pressed", "selected"):
        cv.rr(x, y, w, h, 10, fill=th["selected"] if st == "selected" else state(th["raised"], st))
        if st == "selected":
            cv.rr(x, y, w, h, 10, stroke=th["accent"], sw=2)
    a = 130 if st == "disabled" else 255
    cv.text(x + 14, y + h / 2, left, "mono", 13, th["dim"][:3] + (a,), "lm")
    cv.text(x + 96, y + h / 2, title, "r", 16, th["text"][:3] + (a,), "lm")
    if right:
        stars(cv, x + w - 46, y + h / 2, right, th, 15, "r")
    if done:
        icon(cv, "check", x + w - 22, y + h / 2, 18, th["accent"][:3] + (a,))
    cv.line([(x + 14, y + h), (x + w - 14, y + h)], (255, 255, 255, 14), 1, False)


def back_arrow(cv, x, y, d=56, st="idle"):
    cv.shadow(x, y, d, d, d / 2, blur=10, color=(0, 0, 0, 110), dy=4)
    fill = {"idle": (21, 23, 27, 184), "hover": (40, 43, 50, 200), "pressed": (12, 13, 16, 215), "focus": (21, 23, 27, 184), "disabled": (21, 23, 27, 90)}[st]
    off = 2 if st == "pressed" else 0
    cv.rr(x, y + off, d, d, d / 2, fill=fill)
    cv.rr(x, y + off, d, d, d / 2, stroke=(255, 255, 255, 60), sw=1.5)
    icon(cv, "back", x + d / 2, y + d / 2 + off, d * .46, (243, 244, 246, 110 if st == "disabled" else 255), w=d * .05)
    if st == "focus":
        cv.glow_ring(x - 4, y - 4, d + 8, d + 8, d / 2 + 4)


def diff_bars(cv, x, y, level, color, th):
    for i, hh in enumerate((10, 16, 22)):
        cv.rr(x + i * 9, y + 22 - hh, 6, hh, 2, fill=color if i < level else th["well"])


DIFF = {"easy": ("Easy", "Breezy", 1, GOOD, "0.8"), "medium": ("Medium", "Classic", 2, STAR, "1"), "hard": ("Hard", "Spicy", 3, DANGER, "1.5")}


# ================================================================== screens (LCD pixels)
def lcd(th):
    cv = Cv(LW, LH, z=4, bg=th["panel"])
    cv.paste(gradient(LW * 4, LH * 4, [(0, (255, 255, 255, 8)), (1, (0, 0, 0, 30))]), 0, 0, raw=True)
    return cv


def screen_round(th, diff="hard"):
    cv = lcd(th)
    name, _, level, dcol, mult = DIFF[diff]
    # ---- left column
    card(cv, 12, 12, 231, 96, th)
    label(cv, 26, 24, "Score", th)
    cv.text(26, 43, "2,340", "monob", 34, th["text"])
    cv.text(26, 84, "BEST 2,210", "mono", 13, th["dim"])
    card(cv, 12, 116, 231, 64, th)
    label(cv, 26, 128, "Chain", th)
    cv.text(26, 146, "×3", "monob", 22, th["text"])
    segmented(cv, 96, 152, 5, 3, th)
    card(cv, 12, 188, 231, 244, th)
    label(cv, 26, 200, "Goals", th)
    label(cv, 229, 200, "1/3", th, th["soft"], "ra")
    goals = [("Merge II in the centre", 2, 2), ("Make III on RIGHT", 1, 2), ("Make a tier IV", 0, 1)]
    for i, (t, c, g) in enumerate(goals if diff == "hard" else goals[:2]):
        y = 226 + i * 68
        check_circle(cv, 37, y + 11, c >= g, th)
        used = cv.wrap(58, y, t, 172, "m", 16, th["soft"] if c >= g else th["text"], 19, 2)
        progress(cv, 58, y + used + 8, 130, 6, c / g, th)
        cv.text(229, y + used + 11, f"{c}/{g}", "monob", 13, th["soft"], "rm")
    card(cv, 12, 440, 231, 156, th)
    label(cv, 26, 452, "Daily quests", th)
    for i, (t, c, g) in enumerate((("Win 2 rounds", 1, 2), ("Chain 4 merges", 3, 4), ("Tier IV on Hard", 0, 1))):
        y = 478 + i * 38
        cv.text(26, y, t, "r", 14, th["text"])
        cv.text(229, y + 1, f"{c}/{g}", "monob", 13, th["soft"], "ra")
        progress(cv, 26, y + 22, 203, 4, c / g, th)
    # ---- board
    bx, by, bw, bh = 255, 12, 338, 584
    cv.rr(bx, by, bw, bh, 14, fill=th["well"])
    for gy in range(1, 12):
        cv.line([(bx + 10, by + gy * bh / 12), (bx + bw - 10, by + gy * bh / 12)], (255, 255, 255, 7), 1, False)
    cv.rr(bx, by, bw, bh, 14, stroke=STROKE, sw=1)
    line_y = by + (200 if diff == "hard" else 150)
    for i in range(14):
        cv.line([(bx + 12 + i * 23, line_y), (bx + 24 + i * 23, line_y)], hx(DANGER, 200), 2, False)
    chip(cv, bx + bw - 10, line_y - 30, "Line", mix(th["well"], DANGER, .25), hx(DANGER), 22, anchor="r", size=11)
    ax = bx + 196
    for i in range(9):
        cv.ell(ax, by + 96 + i * 26, 2, fill=(255, 255, 255, 60))
    egg_ball(cv, ax, by + 50, 24, 1)
    cv.poly([(ax - 8, by + 12), (ax + 8, by + 12), (ax, by + 22)], th["accent"])
    for x, y, r, t in ((48, 544, 34, 3), (112, 552, 26, 2), (160, 556, 22, 1), (214, 540, 38, 4), (282, 552, 26, 2), (300, 500, 22, 1),
                       (72, 486, 26, 2), (128, 502, 22, 1), (168, 510, 22, 1), (250, 478, 26, 2), (104, 444, 22, 1), (196, 468, 22, 1)):
        egg_ball(cv, bx + x, by + y, r, t)
    label(cv, bx + 16, by + 14, "Left", th, (255, 255, 255, 90), size=11)
    label(cv, bx + bw - 16, by + 14, "Right", th, (255, 255, 255, 90), "ra", 11)
    # ---- right column
    rx = 605
    card(cv, rx, 12, 231, 140, th)
    label(cv, rx + 14, 24, "Next", th)
    egg_ball(cv, rx + 62, 94, 34, 2)
    label(cv, rx + 132, 62, "Then", th)
    egg_ball(cv, rx + 150, 104, 20, 1)
    egg_ball(cv, rx + 196, 104, 20, 3)
    card(cv, rx, 160, 231, 96, th)
    label(cv, rx + 14, 172, "Eggs left", th)
    w = cv.text(rx + 14, 190, "14", "monob", 34, th["text"])
    cv.text(rx + 18 + w, 204, "/24", "mono", 18, th["dim"])
    progress(cv, rx + 14, 236, 203, 6, 14 / 24, th)
    card(cv, rx, 264, 231, 72, th)
    diff_bars(cv, rx + 16, 289, level, hx(dcol), th)
    cv.text(rx + 52, 300, name, "b", 20, th["text"], "lm")
    chip(cv, rx + 217, 287, f"×{mult}", mix(th["well"], STAR, .14), hx(STAR), 26, "star", anchor="r")
    card(cv, rx, 344, 231, 84, th)
    label(cv, rx + 14, 356, "Win pays", th)
    icon(cv, "star", rx + 28, 388, 26)
    cv.text(rx + 48, 388, {"hard": "9-12", "medium": "6-8", "easy": "5-6"}[diff], "monob", 26, th["star"], "lm")
    cv.text(rx + 14, 413, "Higher with a tidy stack", "r", 13, th["dim"], "lm")
    card(cv, rx, 436, 231, 160, th)
    label(cv, rx + 14, 448, "Controls", th)
    for i, (k, t) in enumerate((("<>", "Aim"), ("A", "Drop"), ("B", "Pause and leave"), ("MENU", "Quest log"))):
        y = 478 + i * 30
        glyph(cv, rx + 14, y, k, th, False, 22)
        cv.text(rx + 76, y + 11.5, t, "r", 14, th["soft"], "lm")
    return cv


def screen_picker(th, sel=1):
    cv = lcd(th)
    label(cv, 24, 22, "Egg Drop", th)
    cv.text(24, 40, "Pick a difficulty", "b", 26, th["text"])
    wallet(cv, LW - 24, 24, 128, th)
    data = [("easy", ["Calmer egg mix", "Line sits higher", "2 goals"], "Win pays 5 to 6", "Best 1,480"),
            ("medium", ["Today's rules", "Line as now", "2 goals"], "Win pays 6 to 8", "Best 2,210"),
            ("hard", ["Faster egg mix", "Line sits lower", "3 goals"], "Win pays 9 to 12", "Not cleared yet")]
    for i, (key, bullets, pays, best) in enumerate(data):
        name, nick, level, col, mult = DIFF[key]
        x, y, w, h = 24 + i * 272, 96, 256, 356
        card(cv, x, y, w, h, th, st="selected" if i == sel else "idle")
        label(cv, x + 20, y + 20, name, th, hx(col))
        diff_bars(cv, x + w - 46, y + 20, level, hx(col), th)
        cv.text(x + 20, y + 40, nick, "b", 26, th["text"])
        chip(cv, x + 20, y + 86, f"×{mult} Stars", mix(th["well"], STAR, .14), hx(STAR), 32, "star", size=15)
        for j, b in enumerate(bullets):
            cv.ell(x + 26, y + 150 + j * 32, 3.5, fill=hx(col))
            cv.text(x + 42, y + 150 + j * 32, b, "r", 16, th["soft"], "lm")
        cv.line([(x + 20, y + 268), (x + w - 20, y + 268)], (255, 255, 255, 20), 1, False)
        cv.text(x + 20, y + 284, pays, "b", 17, th["text"])
        cv.text(x + 20, y + 312, best, "mono", 13, th["dim"])
        if i == sel:
            cv.glow_ring(x - 4, y - 4, w + 8, h + 8, 18)
    card(cv, 24, 468, 800, 48, th, "well", 12)
    icon(cv, "target", 48, 492, 20, th["soft"], accent=th["accent"])
    cv.text(68, 492.5, "Goal this round: Creek crossing", "r", 15, th["soft"], "lm")
    cv.text(LW - 40, 492.5, "Quest: Win on Medium or higher 1/2", "r", 15, th["soft"], "rm")
    hints(cv, 24, 560, [("<>", "Choose"), ("MENU", "Quests"), ("B", "Garden")], th)
    button(cv, 624, 532, 200, 56, "Start", th, "primary", key="A")
    return cv


def screen_results(th, diff="hard", count=None):
    cv = lcd(th)
    name = DIFF[diff][0]
    label(cv, LW / 2, 22, "Round clear", th, th["accent"], "ma")
    cv.text(LW / 2, 44, f"Creek crossing  ·  {name}", "r", 16, th["soft"], "ma")
    total = "+12 Stars" if count is None else f"+{count} Stars"
    w = cv.tw(total, "xb", 40) + 52
    icon(cv, "star", LW / 2 - w / 2 + 20, 106, 42)
    cv.text(LW / 2 - w / 2 + 52, 105, total, "xb", 40, th["star"], "lm")
    # payout
    card(cv, 24, 150, 392, 250, th)
    label(cv, 44, 166, "Payout", th)
    rows = [("Round win", "6"), ("Tidy stack", "+2"), ("Hard ×1.5", "+4")]
    for i, (a, b) in enumerate(rows):
        y = 208 + i * 40
        cv.text(44, y, a, "r", 16, th["text"], "lm")
        cv.text(396, y, b, "monob", 18, th["star"], "rm")
        cv.line([(44, y + 20), (396, y + 20)], (255, 255, 255, 16), 1, False)
    cv.text(44, 334, "Total", "b", 16, th["text"], "lm")
    stars(cv, 396, 334, "12", th, 18, "r")
    cv.text(44, 372, "Saved to your wallet", "r", 14, th["dim"], "lm")
    wallet(cv, 396, 356, 140, th, 32)
    # goals
    card(cv, 432, 150, 392, 250, th)
    label(cv, 452, 166, "Goals", th)
    label(cv, 804, 166, "3/3", th, th["soft"], "ra")
    for i, g in enumerate(("Merge II in the centre", "Make III on RIGHT", "Make a tier IV")):
        check_circle(cv, 463, 206 + i * 34, True, th)
        cv.text(486, 206 + i * 34, g, "r", 16, th["text"], "lm")
    cv.line([(452, 306), (804, 306)], (255, 255, 255, 16), 1, False)
    for i, (k, v) in enumerate((("Score", "2,340"), ("Best", "2,210"), ("Chain", "×4"))):
        label(cv, 452 + i * 104, 320, k, th, size=12)
        cv.text(452 + i * 104, 340, v, "monob", 18, th["text"])
    chip(cv, 804, 336, "New best", mix(th["well"], STAR, .16), hx(STAR), 26, anchor="r")
    # quest strip
    card(cv, 24, 412, 800, 44, th, "well", 12)
    icon(cv, "quests", 46, 434, 20, th["soft"])
    cv.text(66, 434.5, "Quests", "b", 14, th["text"], "lm")
    cv.text(132, 434.5, "Win 2 rounds 2/2", "r", 14, th["soft"], "lm")
    chip(cv, 250, 423, "Claim in log", mix(th["well"], STAR, .16), hx(STAR), 22, size=11)
    cv.text(360, 434.5, "Chain 4 merges 4/4", "r", 14, th["soft"], "lm")
    chip(cv, 490, 423, "Claim in log", mix(th["well"], STAR, .16), hx(STAR), 22, size=11)
    cv.text(804, 434.5, "Weekly: 5 wins 8/12", "r", 14, th["dim"], "rm")
    button(cv, 24, 472, 392, 64, "Replay", th, "primary", "focus", key="A", size=22)
    button(cv, 432, 472, 392, 64, "Leave to garden", th, "secondary", key="B", size=22)
    hints(cv, 24, 572, [("<>", "Choose"), ("A", "Confirm"), ("B", "Leave")], th, right="Replay keeps Hard. Up on Replay changes difficulty.")
    return cv


def screen_quests(th, tab=0):
    cv = lcd(th)
    label(cv, 24, 22, "Quest log", th)
    cv.text(24, 40, ("Today", "This week", "History")[tab], "b", 26, th["text"])
    wallet(cv, LW - 24, 24, 128, th)
    tabs(cv, 24, 84, 520, 44, ["Daily 1/3", "Weekly 1/3", "History"], tab, th, dots=(0,) if tab != 0 else ())
    when = ("New in 7 h 12 m", "New in 3 d 7 h", "Last 14 days")[tab]
    icon(cv, "clock", LW - 24 - cv.tw(when, "r", 14) - 16, 106, 18, th["dim"])
    cv.text(LW - 24, 106.5, when, "r", 14, th["dim"], "rm")
    if tab == 0:
        quest_row(cv, 24, 144, 800, th, "Win 2 rounds", "Any difficulty", 2, 2, 4, "ready", "trophy", ("Claim", "reward"), focus=True)
        quest_row(cv, 24, 246, 800, th, "Chain 4 merges", "In one round", 3, 4, 4, "progress", "chain")
        quest_row(cv, 24, 348, 800, th, "Make a tier IV on Hard", "Skill quest. Not started", 0, 1, 4, "progress", "bars", ("Reroll", "secondary"))
        card(cv, 24, 452, 800, 64, th, "well", 12)
        icon(cv, "reroll", 52, 484, 22, th["accent"])
        cv.text(76, 474, "1 free reroll left today", "b", 15, th["text"], "lm")
        cv.text(76, 495, "Swaps one quest you have not started for another of the same kind.", "r", 14, th["soft"], "lm")
        label(cv, 804, 466, "Today", th, anchor="ra", size=12)
        stars(cv, 804, 492, "4/12", th, 16, "r")
        hints(cv, 24, 560, [("L", ""), ("R", "Tabs"), ("+", "Move"), ("A", "Claim"), ("B", "Back")], th)
    elif tab == 1:
        quest_row(cv, 24, 144, 800, th, "Win 12 rounds", "Any difficulty, across the week", 8, 12, 10, "progress", "trophy")
        quest_row(cv, 24, 246, 800, th, "Win 3 rounds on Hard", "Hard pays ×1.5 Stars too", 3, 3, 10, "claimed", "bars")
        quest_row(cv, 24, 348, 800, th, "Clear all 6 goal types", "4 of 6 done: Lantern chain and Mirror marks left", 4, 6, 10, "progress", "target")
        card(cv, 24, 452, 800, 64, th, "well", 12)
        icon(cv, "trophy", 52, 484, 22, th["star"])
        cv.text(76, 474, "Clear all three this week", "b", 15, th["text"], "lm")
        cv.text(76, 495, "Bonus on top of the 30 Stars above.", "r", 14, th["soft"], "lm")
        segmented(cv, 596, 478, 3, 1, th, 34, 12, 6, hx(STAR))
        stars(cv, 804, 484, "+5", th, 18, "r")
        hints(cv, 24, 560, [("L", ""), ("R", "Tabs"), ("+", "Move"), ("B", "Back")], th)
    else:
        rows = [("TODAY", None), ("14:02", "Win 2 rounds", "+4"), ("WED 11", None), ("19:40", "Score 800 in one round", "+4"), ("19:12", "Finish 3 rounds", "+4"),
                ("18:55", "Chain 4 merges", "+4"), ("TUE 10", None), ("20:21", "Weekly: Win 3 rounds on Hard", "+10"), ("20:21", "Make a tier IV on Hard", "+4"), ("17:03", "Win 2 rounds", "+4")]
        y = 142
        for i, r in enumerate(rows):
            if r[1] is None:
                label(cv, 38, y + 8, r[0], th, size=12)
                y += 30
            else:
                list_row(cv, 24, y, 784, th, r[0], r[1], r[2], st="selected" if i == 1 else "idle", h=42)
                y += 44
        cv.rr(816, 142, 6, 396, 3, fill=th["well"])
        cv.rr(816, 142, 6, 150, 3, fill=(255, 255, 255, 70))
        hints(cv, 24, 572, [("L", ""), ("R", "Tabs"), ("+", "Scroll"), ("B", "Back")], th, right="52 Stars from quests this week")
    return cv


_thumbs = {}


def deck_thumb(pid, width):
    if pid not in _thumbs:
        p = PLATES[pid]
        im = compose_deck(Image.open(ASSETS / "faceplates" / p["texture"]), accent=p["accent"], ink=p["ink"], band_tint=p["band"]["tint"], k=0.3,
                          shadow=False, engrave=(p["engrave"]["color"], p["engrave"]["opacity"]))
        pad = round(PAD * 0.3)
        _thumbs[pid] = im.crop((pad - 2, pad - 6, im.width - pad + 2, im.height - pad + 4))
    im = _thumbs[pid]
    return im.resize((round(width), round(width * im.height / im.width)), Image.LANCZOS)


def screen_shop(th, sel="aurora_glass", equipped="sherbet", owned=("sherbet", "stone", "ice", "brick", "moss", "honey", "aqua_pop"), stars_have=128):
    cv = lcd(th)
    label(cv, 24, 22, "Deck style", th)
    cv.text(24, 40, "Faceplates", "b", 26, th["text"])
    wallet(cv, LW - 24, 24, stars_have, th)
    p = PLATES[sel]
    # preview pane
    card(cv, 24, 84, 328, 452, th)
    t = deck_thumb(sel, 296)
    cv.shadow(40, 104, 296, t.height, 26, blur=12, color=(0, 0, 0, 120), dy=6)
    cv.paste(t, 40, 100)
    cv.text(44, 268, p["name"], "b", 26, th["text"])
    tier_col = {"starter": th["soft"], "common": hx("#9BE3A8"), "rare": hx("#8CC8FF"), "showcase": hx("#E6B3FF")}[p["tier"]]
    chip(cv, 332, 272, p["tier"], th["well"], tier_col, 26, anchor="r", stroke=STROKE)
    cv.text(44, 302, p["finish"].capitalize(), "r", 15, th["soft"])
    label(cv, 44, 340, "Tints your menus", th, size=12)
    pt = ui_theme(p["accent"], p["deep"])
    cv.rr(44, 362, 288, 56, 12, fill=pt["panel"])
    cv.rr(44, 362, 288, 56, 12, stroke=STROKE, sw=1)
    cv.rr(54, 374, 104, 32, 10, fill=pt["accent"])
    cv.text(106, 390.5, "Primary", "b", 15, pt["ink"], "mm")
    progress(cv, 172, 386, 110, 8, .62, pt)
    icon(cv, "star", 306, 390, 18)
    price = p["priceStars"]
    if sel in owned:
        button(cv, 44, 464, 288, 56, "Equip", th, "primary", key="A")
    elif price <= stars_have:
        cv.text(44, 440, "You have enough Stars", "r", 14, th["soft"], "lm")
        button(cv, 44, 464, 288, 56, f"Buy  {price}", th, "primary", key="A", ico="star")
    else:
        cv.text(44, 440, f"{price - stars_have} more Stars needed", "r", 14, hx(DANGER), "lm")
        button(cv, 44, 464, 288, 56, f"Buy  {price}", th, "secondary", "disabled", ico="star")
    # grid
    ids = list(PLATES)
    gx, gy, tw, thh, gap = 368, 84, 105, 104, 12
    for i, pid in enumerate(ids):
        x, y = gx + (i % 4) * (tw + gap), gy + (i // 4) * (thh + gap)
        q = PLATES[pid]
        is_sel = pid == sel
        cv.rr(x, y, tw, thh, 12, fill=th["selected"] if is_sel else th["raised"])
        cv.rr(x, y, tw, thh, 12, stroke=th["accent"] if is_sel else STROKE, sw=2 if is_sel else 1)
        tm = deck_thumb(pid, 89)
        cv.paste(tm, x + 8, y + 8)
        cv.text(x + 8, y + 62, q["name"], "b", 12, th["text"])
        if pid == equipped:
            cv.text(x + 8, y + 82, "EQUIPPED", "b", 11, th["accent"], tracking=.6)
        elif pid in owned or q["tier"] == "starter" and pid in owned:
            icon(cv, "check", x + 15, y + 88, 14, th["soft"])
            cv.text(x + 26, y + 82, "Owned", "r", 12, th["soft"])
        elif q["tier"] == "starter":
            icon(cv, "lock", x + 15, y + 88, 14, th["dim"])
            cv.text(x + 26, y + 82, {"rankI": "Win 3", "rankII": "Win 10"}.get(q.get("unlock"), "Win 1"), "r", 12, th["dim"])
        else:
            afford = q["priceStars"] <= stars_have
            icon(cv, "star", x + 15, y + 88, 14, accent=STAR if afford else DIM)
            cv.text(x + 26, y + 81, str(q["priceStars"]), "monob", 13, th["star"] if afford else th["dim"])
        if is_sel:
            cv.glow_ring(x - 4, y - 4, tw + 8, thh + 8, 16)
    hints(cv, 24, 572, [("+", "Browse"), ("A", "Buy or equip"), ("B", "Back")], th, right="Fixed prices. No random plates.")
    return cv


# ================================================================== full-view composites
def backdrop(w, h, th, seed=3):
    deep = th["deep"]
    g = gradient(w, h, [(0, mix(deep, "#0B1418", .55)), (0.55, mix(deep, "#0B1418", .72)), (1, mix(deep, "#05080A", .86))])
    rng = np.random.default_rng(seed)
    blobs = Cv(w, h, z=1)
    for _ in range(26):
        x, y, r = rng.random() * w, rng.random() * h, 40 + rng.random() * 160
        col = mix(deep, th["plate"]["accent"], rng.random() * .5, int(18 + rng.random() * 26))
        blobs.ell(x, y, r, r * (.5 + rng.random() * .4), fill=col)
    g.alpha_composite(blobs.im.filter(ImageFilter.GaussianBlur(38)))
    return g


def full_view(screen_cv, th, name, press=None, back_state="idle", W=1920, H=1080, toast_args=None):
    lcd_img = screen_cv.im
    lcd_img.resize((LW * 2, LH * 2), Image.LANCZOS).save(MOCKUPS / f"{name}-glass@2x.png")
    p = th["plate"]
    k = 1.0
    out = backdrop(W, H, th)
    deck = compose_deck(Image.open(ASSETS / "faceplates" / p["texture"]), accent=p["accent"], ink=p["ink"], band_tint=p["band"]["tint"], k=k,
                        lcd=lcd_img, press=press, lcd_fill=to_hex_rgba(th["panel"]), engrave=(p["engrave"]["color"], p["engrave"]["opacity"]))
    dx, dy = (W - 1600) // 2, (H - 800) // 2 + 10
    out.alpha_composite(deck, (dx - PAD, dy - PAD))
    over = Cv(W, H, z=2)
    back_arrow(over, W - 24 - 56, 24, 56, back_state)
    if toast_args:
        toast(over, W / 2, 30, *toast_args, th)
    out.alpha_composite(over.out())
    out.convert("RGB").save(MOCKUPS / f"{name}.png")
    return out


def to_hex_rgba(c):
    return "#%02X%02X%02X" % tuple(int(v) for v in c[:3])


# ================================================================== component sheet
def components(th):
    W, H = 1920, 1500
    cv = Cv(W, H, z=2, bg=hx("#0B0C10"))
    cv.text(40, 28, "Deck glass components", "xb", 38, TEXT)
    cv.text(40, 78, "Every state at 1x, Scout plate. Sizes in px at the reference scale. Hover +6% white, pressed settles 2 px and darkens 8%, disabled 45% content, focus = 2.5 px white ring 4 px outside with a soft glow.", "r", 18, SOFT)
    cv.rr(24, 116, W - 48, H - 140, 20, fill=th["panel"])
    cv.rr(24, 116, W - 48, H - 140, 20, stroke=STROKE)

    def head(x, y, s):
        label(cv, x, y, s, th, th["soft"], size=14)

    def cap(x, y, s):
        cv.text(x, y, s, "r", 13, th["dim"])

    states = ["idle", "hover", "pressed", "selected", "disabled", "focus"]
    y = 140
    head(56, y, "Button  ·  secondary 180 x 48, radius 12, Heading 20")
    for i, s in enumerate(states):
        button(cv, 56 + i * 204, y + 30, 180, 48, "Leave", th, "secondary", s, key="B" if s == "focus" else None)
        cap(56 + i * 204, y + 88, s)
    head(1300, y, "Ghost, destructive")
    button(cv, 1300, y + 30, 130, 48, "Details", th, "ghost")
    button(cv, 1444, y + 30, 130, 48, "Details", th, "ghost", "hover")
    button(cv, 1600, y + 30, 150, 48, "Reset", th, "danger")
    cap(1300, y + 88, "ghost idle"); cap(1444, y + 88, "ghost hover"); cap(1600, y + 88, "destructive")
    y = 270
    head(56, y, "Primary button  ·  200 x 56 (results 392 x 64), accent fill, ink text, 3 px lower edge")
    for i, s in enumerate(["idle", "hover", "pressed", "disabled", "focus"]):
        button(cv, 56 + i * 224, y + 30, 200, 56, "Replay", th, "primary", s, key="A" if s in ("idle", "focus") else None)
        cap(56 + i * 224, y + 98, s)
    head(1200, y, "Reward (claim) button  ·  120 x 38, Stars gold")
    button(cv, 1200, y + 36, 120, 38, "Claim", th, "reward", size=16)
    button(cv, 1340, y + 36, 120, 38, "Claim", th, "reward", "pressed", size=16)
    button(cv, 1480, y + 36, 120, 38, "Claim", th, "reward", "focus", size=16, key="A")
    cap(1200, y + 98, "idle"); cap(1340, y + 98, "pressed"); cap(1480, y + 98, "focus")
    y = 410
    head(56, y, "Tabs  ·  track 520 x 44, pill inset 4, Heading 17; gold dot = something to claim")
    tabs(cv, 56, y + 30, 520, 44, ["Daily 1/3", "Weekly 1/3", "History"], 0, th, dots=(1,))
    tabs(cv, 620, y + 30, 520, 44, ["Daily 1/3", "Weekly 1/3", "History"], 1, th, focus=True)
    cap(56, y + 84, "selected = accent pill, ink text; idle = soft text"); cap(620, y + 84, "gamepad focus on the selected tab (L / R shoulders switch)")
    head(1200, y, "Toggle  ·  52 x 30")
    for i, (on, s) in enumerate(((False, "idle"), (True, "idle"), (True, "focus"), (True, "disabled"))):
        toggle(cv, 1200 + i * 110, y + 36, on, th, s)
        cap(1200 + i * 110, y + 84, ("off", "on", "focus", "disabled")[i])
    y = 540
    head(56, y, "Card  ·  radius 14, 1 px white 14% stroke; selected = selected fill + 2 px accent")
    for i, s in enumerate(["idle", "hover", "pressed", "selected", "disabled", "focus"]):
        x = 56 + i * 204
        card(cv, x, y + 30, 180, 104, th, st="selected" if s in ("selected", "focus") else s)
        a = 120 if s == "disabled" else 255
        label(cv, x + 16, y + 44, "Medium", th, hx(STAR, a))
        cv.text(x + 16, y + 62, "Classic", "b", 22, th["text"][:3] + (a,))
        cv.text(x + 16, y + 100, "Win pays 6 to 8", "r", 14, th["soft"][:3] + (a,))
        if s == "focus":
            cv.glow_ring(x - 4, y + 26, 188, 112, 18)
        cap(x, y + 144, s)
    head(1300, y, "Progress  ·  bar 8 (HUD 6) high, segmented <= 10")
    progress(cv, 1300, y + 40, 300, 8, .64, th)
    cv.text(1614, y + 44, "320/500", "monob", 14, th["soft"], "lm")
    segmented(cv, 1300, y + 70, 10, 6, th, 24, 10, 6)
    progress(cv, 1300, y + 104, 300, 8, 1, th, hx(STAR))
    cap(1614, y + 100, "complete = Stars gold")
    y = 730
    head(56, y, "Quest row  ·  800 x 92, icon well 56, title 19, sub 14, bar 8, action 120 x 38")
    quest_row(cv, 56, y + 30, 800, th, "Chain 4 merges", "In one round", 3, 4, 4, "progress", "chain", ("Reroll", "secondary"))
    quest_row(cv, 56, y + 132, 800, th, "Win 2 rounds", "Any difficulty", 2, 2, 4, "ready", "trophy", ("Claim", "reward"), focus=True)
    quest_row(cv, 900, y + 30, 800, th, "Win 3 rounds on Hard", "Hard pays ×1.5 Stars too", 3, 3, 10, "claimed", "bars")
    quest_row(cv, 900, y + 132, 800, th, "Make a tier V", "Unlocks after your first Hard win", 0, 1, 4, "locked", "target")
    cap(56, y + 232, "in progress (unstarted quests show Reroll)   ·   ready: gold 2 px edge, Claim focused")
    cap(900, y + 232, "claimed: 60% content, chip   ·   locked: padlock, reason in the sub-line")
    y = 1010
    head(56, y, "List row  ·  784 x 42, Body 16, mono time 13")
    for i, s in enumerate(["idle", "hover", "selected", "disabled"]):
        list_row(cv, 56, y + 30 + i * 46, 784, th, "19:40", "Score 800 in one round", "+4", st=s, h=42)
        cv.text(852, y + 51 + i * 46, s, "r", 13, th["dim"], "lm")
    head(1000, y, "Toast  ·  top centre, 48 high, 2.4 s, one at a time")
    toast(cv, 1230, y + 34, "Quest done: Chain 4 merges", "+4", th)
    head(1000, y + 110, "Back arrow  ·  56 circle (phone 44)")
    for i, s in enumerate(["idle", "hover", "pressed", "focus", "disabled"]):
        back_arrow(cv, 1000 + i * 96, y + 144, 56, s)
        cap(1000 + i * 96, y + 210, s)
    head(1500, y, "Wallet pill, chips, glyphs")
    wallet(cv, 1620, y + 30, 128, th)
    chip(cv, 1640, y + 37, "×1.5", mix(th["well"], STAR, .14), hx(STAR), 26, "star")
    chip(cv, 1500, y + 84, "New best", mix(th["well"], STAR, .16), hx(STAR))
    chip(cv, 1600, y + 84, "Locked", th["well"], th["dim"])
    chip(cv, 1690, y + 84, "Line", mix(th["well"], DANGER, .25), hx(DANGER))
    x = 1500
    for kx in ("A", "B", "L", "R", "<>", "+", "MENU"):
        x += glyph(cv, x, y + 132, kx, th, False, 26) + 8
    y = 1260
    head(56, y, "Type  ·  Builder Sans + Roboto Mono")
    cv.text(56, y + 26, "+12 Stars", "xb", 40, th["star"]); cap(56, y + 76, "Display 40 ExtraBold")
    cv.text(300, y + 36, "Round clear", "b", 26, th["text"]); cap(300, y + 76, "Title 26 Bold")
    cv.text(500, y + 42, "Daily quests", "b", 20, th["text"]); cap(500, y + 76, "Heading 20 Bold")
    cv.text(680, y + 46, "Make III on RIGHT", "r", 16, th["text"]); cap(680, y + 76, "Body 16 Regular")
    label(cv, 880, y + 48, "Eggs left", th, th["soft"]); cap(880, y + 76, "Label 13 Bold caps +0.6")
    cv.text(1060, y + 44, "14/24  ×3", "monob", 18, th["text"]); cap(1060, y + 76, "Counter 18 Mono Bold")
    cv.text(1230, y + 30, "2,340", "monob", 34, th["text"]); cap(1230, y + 76, "Counter L 34 Mono Bold")
    head(1400, y, "Icons  ·  24 grid, 2 px stroke")
    for i, n in enumerate(("back", "quests", "star", "replay", "reroll", "lock", "bars", "faceplate", "check", "settings", "clock", "trophy")):
        cv.rr(1400 + i * 40, y + 30, 34, 34, 9, fill=th["well"])
        icon(cv, n, 1417 + i * 40, y + 47, 20, th["text"], accent=th["accent"] if n != "star" else None)
    cv.out().convert("RGB").save(MOCKUPS / "components.png")


# ================================================================== phone check (733 x 307 safe root)
def phone(th):
    k = 299 / 608
    lw, lh = round(LW * k), round(LH * k)   # 417 x 299
    cv = Cv(lw, lh, z=4, bg=th["panel"])
    bh = lh - 12
    bw = round(bh * 338 / 584)
    bx = (lw - bw) // 2
    cw = bx - 12
    # left
    card(cv, 6, 6, cw, 54, th, r=10)
    label(cv, 14, 12, "Score", th, size=12)
    cv.text(14, 28, "2,340", "monob", 22, th["text"])
    card(cv, 6, 66, cw, 136, th, r=10)
    label(cv, 14, 72, "Goals 1/3", th, size=12)
    for i, (t, d) in enumerate((("II centre", True), ("III RIGHT", False), ("Tier IV", False))):
        check_circle(cv, 23, 103 + i * 34, d, th, 9)
        cv.text(38, 103 + i * 34, t, "m", 14, th["soft"] if d else th["text"], "lm")
    card(cv, 6, 208, cw, 85, th, r=10)
    label(cv, 14, 214, "Chain", th, size=12)
    cv.text(14, 232, "×3", "monob", 18, th["text"])
    segmented(cv, 14, 268, 5, 3, th, 14, 8, 3)
    # board
    cv.rr(bx, 6, bw, bh, 10, fill=th["well"])
    cv.rr(bx, 6, bw, bh, 10, stroke=STROKE)
    for i in range(7):
        cv.line([(bx + 8 + i * 23, 104), (bx + 18 + i * 23, 104)], hx(DANGER, 200), 1.5, False)
    egg_ball(cv, bx + 96, 26, 12, 1)
    s = bh / 584
    for x, y, r, t in ((48, 544, 34, 3), (112, 552, 26, 2), (160, 556, 22, 1), (214, 540, 38, 4), (282, 552, 26, 2), (300, 500, 22, 1), (72, 486, 26, 2), (128, 502, 22, 1), (250, 478, 26, 2)):
        egg_ball(cv, bx + x * s, 6 + y * s, r * s, t)
    # right
    rx = bx + bw + 6
    card(cv, rx, 6, cw, 84, th, r=10)
    label(cv, rx + 8, 12, "Next", th, size=12)
    egg_ball(cv, rx + 32, 56, 20, 2)
    egg_ball(cv, rx + 80, 62, 12, 1)
    card(cv, rx, 96, cw, 64, th, r=10)
    label(cv, rx + 8, 102, "Eggs left", th, size=12)
    w = cv.text(rx + 8, 118, "14", "monob", 22, th["text"])
    cv.text(rx + 10 + w, 126, "/24", "mono", 13, th["dim"])
    progress(cv, rx + 8, 148, cw - 16, 5, 14 / 24, th)
    card(cv, rx, 166, cw, 60, th, r=10)
    diff_bars(cv, rx + 10, 176, 3, hx(DANGER), th)
    cv.text(rx + 44, 188, "Hard", "b", 15, th["text"], "lm")
    chip(cv, rx + 8, 200, "×1.5", mix(th["well"], STAR, .14), hx(STAR), 20, "star", size=11)
    card(cv, rx, 232, cw, 61, th, r=10)
    label(cv, rx + 8, 238, "Win pays", th, size=12)
    icon(cv, "star", rx + 18, 270, 16)
    cv.text(rx + 30, 270, "9-12", "monob", 17, th["star"], "lm")
    lcd_img = cv.im
    lcd_img.resize((lw * 2, lh * 2), Image.LANCZOS).save(MOCKUPS / "phone-round-glass@2x.png")
    W, H = 749, 381                  # emulator viewport; safe root 733 x 307 sits inside it
    sx, sy = 8, 37
    out = backdrop(W, H, th)
    p = th["plate"]
    deck = compose_deck(Image.open(ASSETS / "faceplates" / p["texture"]), accent=p["accent"], ink=p["ink"], k=k, lcd=lcd_img, lcd_fill=to_hex_rgba(th["panel"]))
    dw, dh = 1600 * k, 800 * k
    dx, dy = sx + (733 - dw) / 2, sy + (307 - dh) / 2
    out.alpha_composite(deck, (round(dx - PAD * k), round(dy - PAD * k)))
    over = Cv(W, H, z=2)
    over.rr(sx, sy, 733, 307, 0, stroke=(255, 255, 255, 90), sw=1)
    over.rr(0, 0, W, 26, 0, fill=(8, 9, 12, 235))
    over.text(10, 13, "Phone landscape, 749 x 381 viewport. White outline = safe root 733 x 307. Deck scale 0.492: the LCD fills the safe height and the case bleeds past it.", "r", 10.5, (235, 238, 242, 255), "lm")
    back_arrow(over, sx + 733 - 12 - 44, sy + 12, 44)
    out.alpha_composite(over.out())
    out = out.resize((W * 2, H * 2), Image.LANCZOS)
    out.convert("RGB").save(MOCKUPS / "phone-round.png")


def tint_variations():
    ids = ["sherbet", "brick", "tidepool", "night_orb"]
    tiles = []
    for pid in ids:
        th = theme(pid)
        tiles.append(full_view(screen_results(th), th, "_tmp").resize((960, 540), Image.LANCZOS))
    sheet = Image.new("RGB", (1920, 1080))
    for i, t in enumerate(tiles):
        sheet.paste(t.convert("RGB"), ((i % 2) * 960, (i // 2) * 540))
    sheet.save(MOCKUPS / "tint-variations.png")
    for f in ("_tmp.png", "_tmp-glass@2x.png"):
        (MOCKUPS / f).unlink()


ICONS = ["back", "quests", "star", "replay", "reroll", "lock", "bars", "faceplate", "check", "settings", "clock", "trophy", "chain", "target", "close", "egg"]


def export_ui_assets():
    """Icon sheet (white, tint with ImageColor3) and the focus-ring glow, for the implementer."""
    out = ASSETS / "ui"
    out.mkdir(parents=True, exist_ok=True)
    cell, cols = 64, 8
    cv = Cv(cell * cols, cell * 2, z=4)
    rects = {}
    for i, n in enumerate(ICONS):
        x, y = (i % cols) * cell, (i // cols) * cell
        icon(cv, n, x + cell / 2, y + cell / 2, 48, (255, 255, 255, 255), accent=(255, 255, 255, 255))
        rects[n] = [x, y, cell, cell]
    cv.out().save(out / "icons.png")
    g = Cv(96, 96, z=4)
    g.glow_ring(24, 24, 48, 48, 16, width=0.01, glow=10, glow_alpha=110)
    ring = g.out()
    ring.save(out / "focus-glow-9slice.png")
    (out / "ui-assets.json").write_text(json.dumps({
        "icons": {"file": "icons.png", "cell": cell, "drawn": 48, "rects": rects,
                  "use": "ImageRectOffset / ImageRectSize; white art, tint with ImageColor3; display at 24 px (20 in rows, 28 in quest wells); never recolour the star, it is always #FFC14D"},
        "focusGlow": {"file": "focus-glow-9slice.png", "sliceCenter": [40, 40, 56, 56], "inset": 24,
                      "use": "optional soft glow behind the focus ring: size = target + 2 * (4 + 20) px, white, ImageTransparency 0.35. The crisp ring itself is a UIStroke (2.5 px white)."},
    }, indent=1), newline="\n")


def main():
    MOCKUPS.mkdir(parents=True, exist_ok=True)
    export_ui_assets()
    th = theme("sherbet")
    full_view(screen_round(th), th, "01-round-hud")
    full_view(screen_picker(th), th, "02-difficulty-picker")
    full_view(screen_results(th), th, "03-results", back_state="idle")
    full_view(screen_quests(th, 0), th, "04-quest-log-daily", toast_args=("Quest done: Win 2 rounds", "+4"))
    full_view(screen_quests(th, 1), th, "05-quest-log-weekly")
    full_view(screen_quests(th, 2), th, "06-quest-log-history")
    full_view(screen_shop(th), th, "07-faceplate-shop")
    components(th)
    phone(th)
    tint_variations()
    print("mockups written to", MOCKUPS)


if __name__ == "__main__":
    main()
