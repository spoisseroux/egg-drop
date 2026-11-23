"""Offline reachability sweep of the island edges (WORLD-PASS-2026-11-22 item 5, stage 1).

Flood-fills the 1-stud surface map in assets/world/world-v7-walk.json from the arrival dais (96, 66) with a
pessimistic Humanoid model and reports every reached cell that is high (above FloorTop + 6 = y 10) or outside the
perimeter ring, clustered into spots with coordinates and the slope feet the fill climbed from. It runs again with
the hand-written wall top-ups in src/shared/IslandBounds.lua, checks them (nothing within 3 studs of the Dash
course, a park kerb, a find spot or a station; no path tile under one; every cell under a wall more than a jump
below its top) and writes the runtime safe-ground mask the server's safe-spot return reads.

    python scripts/sweep_island_edges.py          write the sweep (artifacts/world-pass-2026-11-22/edge-sweep.*)
                                                  and src/shared/IslandGround.lua
    python scripts/sweep_island_edges.py --check  fail when IslandGround.lua differs or a wall check fails

The model ("can a player get onto this cell"):
  walk   8-neighbour steps; a rise of at most STEP (2 studs) per stud, any drop. MaxSlopeAngle is 89, so slope alone
         never stops the walker; only rises above the step height do.
  jump   walk, plus jumps of up to JUMP (7 studs; JumpHeight 7.2) to a cell up to 2 studs away, from a cell with a
         run-up (the cell behind it, against the jump, is within STEP of it).
Blocked: cells under a wall box (perimeter, CaveBlocker, the IslandBounds top-ups; footprint padded by PAD) whose
top is more than the pass's lift (STEP walking, JUMP jumping) above the cell. Void ('.') and water below y 0 (the
falls) end a path: that is a fall.

Limits, read before trusting a spot: the map holds one height per 1-stud cell (the top surface of the render
meshes, not the collision), so roofs hide floors, and overhangs, thin rails, tree crowns, collision boxes and gaps
narrower than a cell are invisible to it; Roblox floor detection on steep faces is worse than this model, so most
jump-pass spots are probably not climbable in practice. Every spot needs a Studio play test (stage 2 in the doc).
"""
import json
import math
import re
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WALK = json.loads((ROOT / "assets/world/world-v7-walk.json").read_text())
OUT = ROOT / "artifacts/world-pass-2026-11-22"
BOUNDS = ROOT / "src/shared/IslandBounds.lua"
GROUND = ROOT / "src/shared/IslandGround.lua"
S = WALK["surface"]
SPAWN = (96, 66)
FLOOR = 4.0
HIGH = FLOOR + 6.0     # flagged above this; also the highest safe ground
DOC_HIGH = 16.0        # the doc's stage-2 line ("above y 16 on rock")
FOOT = FLOOR + 2.5     # the last cell of a path at or below this is the slope foot
STEP, JUMP, REACH = 2.0, 7.0, 2
PAD = .5
FALL = 0.0
CLEAR = 3.0            # walls keep this far from the Dash course, kerbs, find spots and stations
RING_MARGIN = 3.0      # IslandBounds.Margin: outside the ring by more than this is "left the island"
SAFE_RING = 3.0        # safe ground keeps this far inside the ring

# Kept in step with the live modules by IslandBounds.spec (HollowWorldLayout.V7, ParkLayout).
STATIONS = {"Eggs": (-31, -11), "Journal": (-17, -15), "Customize": (-46, -9), "ToyLawn": (-30, 18.5),
            "ArrivalDais": (96, 66), "CreekNook": (1, -33), "SpringRestWest": (49.5, 14), "SpringRestEast": (54.5, 14)}
PARKS = [(36.0, 66.0), (-38.0, -46.0)]
KERB = (16.0, 11.0)


def cell(i, j):
    if 0 <= i < S["nx"] and 0 <= j < S["nz"]:
        return S["rows"][j][i], S["h"][j][i]
    return ".", -999


def world(i, j):
    return S["x0"] + i, S["z0"] + j


def index(x, z):
    return int(round(x - S["x0"])), int(round(z - S["z0"]))


def make_box(kind, n, x, z, top, bottom, length, thick, yaw):
    return {"kind": kind, "n": n, "x": x, "z": z, "top": top, "bottom": bottom, "hx": length / 2 + PAD,
            "hz": thick / 2 + PAD, "cos": math.cos(yaw), "sin": math.sin(yaw)}


def ring_boxes():
    out = []
    for kind, entries in (("perimeter", WALK["perimeter"]), ("cave", [WALK["CaveBlocker"]])):
        for n, e in enumerate(entries):
            c, s = e["center"], e["size"]
            out.append(make_box(kind, n + 1, c[0], c[2], c[1] + s[1] / 2, c[1] - s[1] / 2, s[0], s[2], e.get("yaw", 0.0)))
    return out


def bounds_walls():
    """The hand-written top-ups: wall("id", x1, z1, x2, z2, base, top) rows of IslandBounds.Walls."""
    text = BOUNDS.read_text(encoding="utf-8")
    thick = float(re.search(r"Bounds\.Thick=([\d.]+)", text).group(1))
    number = r"(-?[\d.]+)"
    rows = re.findall(r'wall\("(\w+)",' + ",".join([number] * 6) + r"\)", text)
    walls = []
    for wid, *values in rows:
        x1, z1, x2, z2, base, top = map(float, values)
        length = math.hypot(x2 - x1, z2 - z1)
        walls.append({"id": wid, "a": (x1, z1), "b": (x2, z2), "base": base, "top": top, "length": round(length, 2),
                      "box": make_box("bounds", wid, (x1 + x2) / 2, (z1 + z2) / 2, top, base, length, thick,
                                      math.atan2(-(z2 - z1), x2 - x1))})
    assert walls, "no walls parsed from IslandBounds.lua"
    return walls


def covers(b, x, z):
    # Roblox CFrame.Angles(0, yaw, 0): local x axis = (cos, 0, -sin), local z axis = (sin, 0, cos).
    dx, dz = x - b["x"], z - b["z"]
    return abs(dx * b["cos"] - dz * b["sin"]) <= b["hx"] and abs(dx * b["sin"] + dz * b["cos"]) <= b["hz"]


def footprint(b):
    r = int(max(b["hx"], b["hz"])) + 2
    ci, cj = index(b["x"], b["z"])
    for i in range(ci - r, ci + r + 1):
        for j in range(cj - r, cj + r + 1):
            if covers(b, *world(i, j)):
                yield i, j


RING = [(e["center"][0], e["center"][2]) for e in WALK["perimeter"]]


def inside(x, z):
    hit = False
    for k in range(len(RING)):
        (x1, z1), (x2, z2) = RING[k], RING[k - 1]
        if (z1 > z) != (z2 > z) and x < x1 + (z - z1) * (x2 - x1) / (z2 - z1):
            hit = not hit
    return hit


def seg_distance(px, pz, a, b):
    (ax, az), (bx, bz) = a, b
    dx, dz = bx - ax, bz - az
    t = 0.0 if dx == dz == 0 else max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz)))
    return math.hypot(px - ax - t * dx, pz - az - t * dz)


def ring_distance(x, z):
    return min(seg_distance(x, z, RING[k - 1], RING[k]) for k in range(len(RING)))


def tops_for(boxes):
    tops = {}
    for b in boxes:
        for n in footprint(b):
            tops[n] = max(tops.get(n, -999), b["top"])
    return tops


def flood(jumps, tops):
    start = index(*SPAWN)
    parent, how = {start: None}, {start: "start"}
    queue = deque([start])
    lift = JUMP if jumps else STEP

    def open_cell(n, limit):
        code, h = cell(*n)
        if code == "." or h < -900:
            return False
        top = tops.get(n)
        return top is None or top - h <= limit

    moves = [(a, b, "walk") for a in (-1, 0, 1) for b in (-1, 0, 1) if a or b]
    if jumps:
        moves += [(a, b, "jump") for a in range(-REACH, REACH + 1) for b in range(-REACH, REACH + 1) if a or b]
    while queue:
        i, j = queue.popleft()
        code, h = cell(i, j)
        if h < FALL and code in ".W":
            continue  # a fall: nothing goes on from here
        for a, b, kind in moves:
            n = (i + a, j + b)
            if n in parent or not open_cell(n, lift):
                continue
            rise = cell(*n)[1] - h
            if kind == "walk":
                if rise > STEP:
                    continue
            else:
                if not (STEP < rise <= JUMP):
                    continue
                if abs(cell(i - (a > 0) + (a < 0), j - (b > 0) + (b < 0))[1] - h) > STEP:
                    continue  # no run-up
                mid = (i + round(a / 2), j + round(b / 2))
                if mid != (i, j) and not open_cell(mid, JUMP):
                    continue
            parent[n] = (i, j)
            how[n] = kind
            queue.append(n)
    return parent, how


def foot(parent, n):
    """The last cell at or below FOOT on the fill's path to n: where the climb starts."""
    out = None
    while n is not None:
        if cell(*n)[1] <= FOOT:
            return n
        out = n
        n = parent[n]
    return out


def clusters(cells):
    left, out = set(cells), []
    while left:
        seed = left.pop()
        group, queue = [seed], deque([seed])
        while queue:
            i, j = queue.popleft()
            for a in (-1, 0, 1):
                for b in (-1, 0, 1):
                    n = (i + a, j + b)
                    if n in left:
                        left.remove(n)
                        group.append(n)
                        queue.append(n)
        out.append(group)
    return out


def report(parent, how):
    high, outside = [], []
    for n in parent:
        h = cell(*n)[1]
        x, z = world(*n)
        if h < FALL:
            continue
        if not inside(x, z) and ring_distance(x, z) > RING_MARGIN:
            outside.append(n)
        elif h > HIGH:
            high.append(n)
    spots = []
    for kind, cells in (("high", high), ("outside", outside)):
        for group in clusters(cells):
            hs = [cell(*n)[1] for n in group]
            xs, zs = [world(*n)[0] for n in group], [world(*n)[1] for n in group]
            codes = {}
            for n in group:
                codes[cell(*n)[0]] = codes.get(cell(*n)[0], 0) + 1
            feet = {}
            for n in group:
                f = foot(parent, n)
                if f is not None:
                    feet[f] = feet.get(f, 0) + 1
            spots.append({
                "kind": kind, "cells": len(group),
                "centre": [round(sum(xs) / len(xs), 1), round(sum(zs) / len(zs), 1)],
                "bbox": [min(xs), min(zs), max(xs), max(zs)],
                "maxY": round(max(hs), 2), "top": list(world(*max(group, key=lambda n: cell(*n)[1]))),
                "codes": dict(sorted(codes.items())), "aboveDocLine": sum(1 for v in hs if v > DOC_HIGH),
                "jumpedCells": sum(1 for n in group if how[n] == "jump"),
                "feet": [{"x": world(*f)[0], "z": world(*f)[1], "y": cell(*f)[1], "paths": c}
                         for f, c in sorted(feet.items(), key=lambda kv: -kv[1])[:8]],
            })
    spots.sort(key=lambda s: (s["kind"], -s["cells"]))
    return spots, len(high), len(outside)


def lua_numbers(name, text):
    block = re.search(name + r"=table\.freeze\(\{(.*?)\}\)", text, re.S).group(1)
    return [int(v) for v in re.findall(r"-?\d+", block)]


def keep_out():
    """(label, x, z) points no wall may come within CLEAR of."""
    out = []
    dash = (ROOT / "src/shared/DashCourse.lua").read_text(encoding="utf-8")
    for name in ("Course.Main", "Course.Branch"):
        v = lua_numbers(re.escape(name), dash)
        out += [(f"dash {name[7:]} d={v[k]}", v[k + 1] / 100, v[k + 3] / 100) for k in range(0, len(v), 4)]
    pad = re.search(r"Course\.Pad=table\.freeze\(\{x=(-?\d+),y=-?\d+,z=(-?\d+)", dash)
    out.append(("dash pad", int(pad.group(1)) / 100, int(pad.group(2)) / 100))
    for k, m in enumerate(re.finditer(r"x=(-?\d+),y=-?\d+,z=(-?\d+)", (ROOT / "src/shared/FindSpots.lua").read_text())):
        out.append((f"find spot {k + 1}", int(m.group(1)) / 100, int(m.group(2)) / 100))
    out += [(f"station {k}", x, z) for k, (x, z) in STATIONS.items()]
    for cx, cz in PARKS:
        out += [(f"park kerb ({cx:g}, {cz:g})", cx + KERB[0] * math.cos(t * math.pi / 64), cz + KERB[1] * math.sin(t * math.pi / 64))
                for t in range(128)]
    return out


def check_walls(walls, tops):
    problems, notes = [], []
    points = keep_out()
    for w in walls:
        near = min(points, key=lambda p: seg_distance(p[1], p[2], w["a"], w["b"]))
        d = seg_distance(near[1], near[2], w["a"], w["b"])
        w["nearest"] = {"what": near[0], "studs": round(d, 2)}
        if d < CLEAR:
            problems.append(f"{w['id']}: {d:.2f} studs from {near[0]}")
        for cx, cz in PARKS:  # never inside a park either
            if any(((x - cx) / KERB[0]) ** 2 + ((z - cz) / KERB[1]) ** 2 < 1 for x, z in (w["a"], w["b"])):
                problems.append(f"{w['id']}: inside the park at ({cx:g}, {cz:g})")
        cells = list(footprint(w["box"]))
        hs = [cell(*n)[1] for n in cells if cell(*n)[1] > -900]
        paths = [world(*n) for n in cells if cell(*n)[0] == "P"]
        if paths:
            problems.append(f"{w['id']}: over path tiles {paths[:3]}")
        low = min(hs)
        if w["base"] > low + .5:
            problems.append(f"{w['id']}: base {w['base']} leaves a gap over ground {low:.2f}")
        if w["top"] - max(hs) <= JUMP:
            problems.append(f"{w['id']}: top {w['top']:.1f} is within a jump of ground {max(hs):.1f} under it")
        w["ground"] = [round(low, 2), round(max(hs), 2)]
    return problems, notes


def buried(boxes):
    """Ring boxes whose top is within a jump of ground beside them: holes once someone is up there."""
    out = []
    for b in boxes:
        wide = dict(b, hx=b["hx"] + 2, hz=b["hz"] + 2)
        hs = [cell(*n)[1] for n in footprint(wide) if cell(*n)[1] > -900]
        if hs and b["top"] - max(hs) < JUMP:
            out.append({"kind": b["kind"], "n": b["n"], "centre": [round(b["x"], 1), round(b["z"], 1)],
                        "top": round(b["top"], 1), "ground": round(max(hs), 1)})
    return out


def ground_module(walk_parent):
    """Safe ground: G/g/P cells at or below HIGH, SAFE_RING inside the ring, reached walking with the top-ups."""
    rows = []
    count = 0
    for j in range(S["nz"]):
        runs, start = [], None
        for i in range(S["nx"] + 1):
            ok = False
            if i < S["nx"]:
                code, h = cell(i, j)
                x, z = world(i, j)
                ok = (code in "GgP" and -900 < h <= HIGH and (i, j) in walk_parent and inside(x, z)
                      and ring_distance(x, z) >= SAFE_RING)
            if ok and start is None:
                start = i
            elif not ok and start is not None:
                runs += [start, i - 1]
                count += i - start
                start = None
        rows.append(runs)
    lines = ["-- Generated by scripts/sweep_island_edges.py from assets/world/world-v7-walk.json; do not edit by hand.",
             "-- Island edges (WORLD-PASS-2026-11-22 item 5): the ground the server may record as a player's safe spot,",
             f"-- and the perimeter ring. Safe: grass, soft ground or path (G g P) at or below y {HIGH:g}, {SAFE_RING:g} studs inside",
             "-- the ring, reached walking from the arrival dais with the IslandBounds top-ups standing. One-stud cells:",
             "-- Rows[k] is z = Z0 + k - 1, a flat list of inclusive x index runs (x = X0 + index).",
             f"-- {count} safe cells.",
             "return table.freeze({",
             f"\tX0={S['x0']},Z0={S['z0']},NX={S['nx']},NZ={S['nz']},",
             "\t-- The perimeter wall centres in order (tenths of a stud, x then z): a closed ring.",
             "\tRing=table.freeze({"]
    flat = [v for x, z in RING for v in (round(x * 10), round(z * 10))]
    for k in range(0, len(flat), 24):
        lines.append("\t\t" + ",".join(str(v) for v in flat[k:k + 24]) + ",")
    lines += ["\t}),", "\tRows=table.freeze({"]
    for runs in rows:
        lines.append("\t\ttable.freeze({" + ",".join(str(v) for v in runs) + "}),")
    lines += ["\t}),", "})", ""]
    return "\n".join(lines), count


def png(path, base, after, walls):
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        return False
    k = 3
    img = Image.new("RGB", (S["nx"] * k, S["nz"] * k))
    d = ImageDraw.Draw(img)
    ring = tops_for(ring_boxes())
    for j in range(S["nz"]):
        for i in range(S["nx"]):
            code, h = cell(i, j)
            if code == ".":
                continue
            g = max(0, min(255, int(40 + h * 4)))
            col = (40, 80, min(255, g + 60)) if code == "W" else (g, int(g * .8), int(g * .5)) if code == "P" else (g, g, g)
            n = (i, j)
            if n in after["walk"] and h > HIGH:
                col = (230, 40, 40)
            elif n in after["jump"] and h > HIGH:
                col = (240, 150, 30)
            elif n in base["walk"] and h > HIGH:
                col = (150, 60, 160)
            if n in ring:
                col = (40, 90, 255)
            d.rectangle([i * k, j * k, i * k + k - 1, j * k + k - 1], fill=col)
    for w in walls:
        (x1, z1), (x2, z2) = w["a"], w["b"]
        d.line([((x1 - S["x0"]) * k, (z1 - S["z0"]) * k), ((x2 - S["x0"]) * k, (z2 - S["z0"]) * k)], fill=(0, 255, 120), width=3)
    sx, sz = index(*SPAWN)
    d.ellipse([sx * k - 6, sz * k - 6, sx * k + 6, sz * k + 6], outline=(255, 255, 0), width=2)
    for v in range(-100, 121, 20):
        d.text(((v - S["x0"]) * k + 2, 2), f"x{v}", fill=(255, 255, 0))
    for v in range(-100, 91, 20):
        d.text((2, (v - S["z0"]) * k + 2), f"z{v}", fill=(255, 255, 0))
    img.save(path)
    return True


def table(spots, limit=None):
    md = ["| kind | centre (x, z) | cells | max y | above y 16 | codes | main foot (x, z, y) |", "|---|---|---|---|---|---|---|"]
    shown = 0
    for s in spots:
        if s["cells"] < 3 and s["maxY"] < DOC_HIGH:
            continue
        shown += 1
        if limit and shown > limit:
            md.append(f"| ... | {len(spots) - limit} more in the JSON | | | | | |")
            break
        f = s["feet"][0] if s["feet"] else None
        codes = " ".join(f"{k}{v}" for k, v in s["codes"].items())
        md.append(f"| {s['kind']} | {s['centre'][0]}, {s['centre'][1]} | {s['cells']} | {s['maxY']} | {s['aboveDocLine']} | {codes} | "
                  + (f"{f['x']}, {f['z']}, {f['y']}" if f else "-") + " |")
    return md


def main():
    check = "--check" in sys.argv
    walls = bounds_walls()
    ring = ring_boxes()
    base_tops, all_tops = tops_for(ring), tops_for(ring + [w["box"] for w in walls])
    passes, reach = {}, {"before": {}, "after": {}}
    for stage, tops in (("before", base_tops), ("after", all_tops)):
        for mode in ("walk", "jump"):
            parent, how = flood(mode == "jump", tops)
            spots, high, outside = report(parent, how)
            passes[f"{mode} {stage}"] = {"reached": len(parent), "highCells": high, "outsideCells": outside, "spots": spots}
            reach[stage][mode] = parent
    problems, _ = check_walls(walls, all_tops)
    # Must stay reachable: every Dash point, find spot, station and park centre a walker reached before still is.
    def near(parent, x, z):
        ci, cj = index(x, z)
        return any((ci + a, cj + b) in parent for a in (-1, 0, 1) for b in (-1, 0, 1))
    musts = [p for p in keep_out() if not p[0].startswith("park kerb")] + [(f"park ({x:g}, {z:g})", x, z) for x, z in PARKS]
    lost = [p[0] for p in musts if near(reach["before"]["walk"], p[1], p[2]) and not near(reach["after"]["walk"], p[1], p[2])]
    if lost:
        problems.append("no longer reachable walking: " + ", ".join(lost[:6]))
    unreached = [p[0] for p in musts if not near(reach["after"]["walk"], p[1], p[2])]
    text, safe = ground_module(reach["after"]["walk"])
    if check:
        current = GROUND.read_text(encoding="utf-8").replace("\r\n", "\n") if GROUND.exists() else ""
        if current != text:
            problems.append("src/shared/IslandGround.lua is out of date: run python scripts/sweep_island_edges.py")
        for p in problems:
            print("FAIL", p)
        sys.exit(1 if problems else 0)
    OUT.mkdir(parents=True, exist_ok=True)
    GROUND.write_text(text, encoding="utf-8")
    holes = buried(ring)
    result = {"source": "assets/world/world-v7-walk.json", "spawn": SPAWN,
              "model": {"step": STEP, "jump": JUMP, "jumpReach": REACH, "wallPad": PAD, "flagAboveY": HIGH, "docLineY": DOC_HIGH,
                        "footY": FOOT, "outsideMargin": RING_MARGIN, "cell": 1},
              "limits": "1-stud render-surface heights, not collision; roofs hide floors; real walls, rails, crowns and floor "
                        "detection differ. Candidates, not proof: verify each spot in Studio.",
              "walls": [{k: w[k] for k in ("id", "a", "b", "base", "top", "length", "ground", "nearest")} for w in walls],
              "wallProblems": problems, "buriedRingBoxes": holes, "safeCells": safe, "passes": passes}
    (OUT / "edge-sweep.json").write_text(json.dumps(result, indent=1) + "\n")
    drew = png(OUT / "edge-sweep.png", reach["before"], reach["after"], walls)
    p = passes
    md = ["# Island edge sweep (offline, stage 1)", "",
          f"`python scripts/sweep_island_edges.py` over `assets/world/world-v7-walk.json`, flood-filled from the arrival dais {SPAWN}. "
          f"Flagged: reached cells above y {HIGH:g} (FloorTop + 6), or more than {RING_MARGIN:g} studs outside the perimeter ring. "
          f"Walk pass: a rise of up to {STEP:g} studs per stud (MaxSlopeAngle 89: slope alone never stops it). Jump pass: also "
          f"jumps of up to {JUMP:g} studs to a cell up to {REACH} studs away, from a cell with a run-up. Walls: the 122 perimeter "
          f"boxes and the CaveBlocker (padded {PAD:g} stud), then again with the {len(walls)} `IslandBounds` top-ups.", "",
          "**Limits.** One render-surface height per 1-stud cell: not collision. Roofs hide floors (the rotunda), and rails, "
          "crowns, collision boxes and gaps under a stud are invisible to it; Roblox floor detection on steep faces is worse than "
          "this model, so the jump pass over-reports on purpose. Every spot is a candidate for the Studio play test, not proof.", "",
          "## Summary", "",
          "| pass | reached | high cells | above y 16 | outside cells |", "|---|---|---|---|---|"]
    for name, v in p.items():
        above = sum(s["aboveDocLine"] for s in v["spots"] if s["kind"] == "high")
        md.append(f"| {name} | {v['reached']} | {v['highCells']} | {above} | {v['outsideCells']} |")
    md += ["", "## Walking (before the top-ups)", "", "The climbable lines the walls answer:", ""]
    md += table(p["walk before"]["spots"])
    md += ["", "## Walking, with the top-ups", "",
           "What is left is the rotunda terrace (legitimate, must stay reachable; the map sees its roof, not its floor) and any "
           "small rock shelves listed here: check them in Studio.", ""]
    md += table(p["walk after"]["spots"])
    md += ["", "## Jumping, with the top-ups (pessimistic: Studio candidates, not walled)", "",
           "Chained full jumps up cliff faces. The jump feet are in the JSON (`passes['jump after'].spots[].feet`): drive a test "
           "avatar at each from the low side, jumping, as the doc's stage 2 says.", ""]
    md += table(p["jump after"]["spots"], 12)
    md += ["", "## The top-ups (src/shared/IslandBounds.lua)", "", "| id | from (x, z) | to (x, z) | base y | top y | ground under | nearest keep-out |",
           "|---|---|---|---|---|---|---|"]
    for w in walls:
        md.append(f"| {w['id']} | {w['a'][0]:g}, {w['a'][1]:g} | {w['b'][0]:g}, {w['b'][1]:g} | {w['base']:g} | {w['top']:g} | "
                  f"{w['ground'][0]}..{w['ground'][1]} | {w['nearest']['what']} at {w['nearest']['studs']} |")
    md += ["", "Wall checks: " + ("all pass." if not problems else "; ".join(problems)) + f" Of {len(musts)} must-reach points "
           f"(Dash points and pad, find spots, stations, park centres), {len(musts) - len(unreached)} are reached walking with the "
           "top-ups" + (f"; not reached before or after (structures the map sees from above): {', '.join(unreached)}." if unreached else "."), "",
           "## Ring boxes within a jump of the ground beside them", "",
           f"{len(holes)} perimeter boxes (and the CaveBlocker, which the cave roof buries by design) stand lower than a jump "
           "above the ground next to them, all on the mountains. They are holes only for someone already up there; the top-ups "
           "keep walkers off the mountains and the safe-spot return catches anyone who still gets out. Listed in the JSON "
           "(`buriedRingBoxes`) for the Studio rim walk.", "",
           f"Safe ground for the return: {safe} one-stud cells (`src/shared/IslandGround.lua`)."
           + (" Heat map: `edge-sweep.png` (red: walkable high after the top-ups, orange: jump-only, purple: walkable before "
              "only, blue: ring boxes, green: top-ups)." if drew else "")]
    (OUT / "edge-sweep.md").write_text("\n".join(md) + "\n")
    for name, v in p.items():
        print(f"{name}: reached {v['reached']}, high {v['highCells']}, outside {v['outsideCells']}, spots {len(v['spots'])}")
    print(f"walls {len(walls)}, safe cells {safe}, buried ring boxes {len(holes)}")
    for q in problems:
        print("FAIL", q)
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
