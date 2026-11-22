"""Write src/shared/DashCourse.lua: the Garden Dash course (V3-SCOPE-2026-11-21 section 4.2, slice S5).

The line is measured from the walk map (assets/world/world-v7-walk.json): hand-placed way points, the ones on
the dirt snapped to the middle of the path tiles ("P"), rounded with Chaikin corner cutting, then nudged by a
seeded hill climb until every rule below holds. Heights come from the same 4-stud ground grid World.groundY
reads, and from the marble deck on the bridge. The script fails if a rule does not hold.

    python scripts/build_dash_course.py          write the module
    python scripts/build_dash_course.py --check  fail when the committed module differs
"""
import json
import math
import random
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WALK = json.loads((ROOT / "assets/world/world-v7-walk.json").read_text())
OUT = ROOT / "src/shared/DashCourse.lua"
SEED = 20261122
S, G = WALK["surface"], WALK["ground"]

# HollowWorldLayout.V7 / ParkLayout (DashCourse.spec checks the same numbers against the live modules).
SPAN = (2.5, 21.0, 21.0, 4.0)  # MainBridge centre x, z, size x, z
DECK = 4.34
PARKS = [(36.0, 66.0), (-38.0, -46.0)]
KERB = (16.0, 11.0)
GROVE = (-24.0, -18.0, -50.0, -30.0)  # the two grove tiles, (-22, -32) to (-21, -48)
KEEP = 6.0
WET = [(e["center"][0], e["center"][2], e["size"][0], e["size"][2], e.get("yaw", 0)) for e in WALK["wet"]]
WET.append((52, 3, 7, 4.4, 0))
BLOCKED = [(-63, 45, 38, 44, 0), (-46, 31.5, 34, 9, math.atan2(-25, -22))]
STATIONS = [(-31, -11), (-17, -15), (-46, -9), (-30, 18.5), (49.5, 14), (54.5, 14)]
LAMPS = [(69.65, 51.97), (29.44, 29.85), (-9, 28), (-12, -44), (-70, -3), (50, -10), (-22, 38)]
# Solid things the walk map's one-stud cells blur, measured by server raycast in Studio: x, z, radius, least
# distance to the centre line (the outside lane is 1.75 studs out). DashCourse.spec checks the same list.
OBSTACLES = [(38.25, 8.0, 1.6, 3.8)]  # 2026-11-22: the base of the leaning tree (W7_Trunks__bark)
BUSHES = [(float(x), float(z)) for x, z in re.findall(
    r"\{(-?[\d.]+),-?[\d.]+,(-?[\d.]+),", (ROOT / "src/shared/WorldDressing.lua").read_text().split("Dressing.Bushes=")[1])]
LANES, LANE_STEP = 8, .5
STEP = 2.0
MIN_RADIUS = 6.0

# (x, z, kind): "P" snaps to the dirt, "F" never moves, "-" may be nudged by the search.
MAIN = [(80.5, 55, "F"), (74, 52.5, "P"), (66, 49, "P"), (57, 44.5, "P"), (51, 40, "-"), (46, 31, "-"), (45, 18, "-"),  # past the garden arch at (85, 58)
        (44, 3, "-"),  # the lawn east of the stream, outside the leaning tree
        (30, 2.5, "-"), (24, 2.5, "-"), (23.5, 21, "-"), (18, 21, "F"), (13.5, 21, "F"), (-8.5, 21, "F"), (-13, 21, "F"),
        (-17.5, 13.2, "-"), (-25, 13.2, "-"), (-36, 13.2, "-"), (-43, 8, "-"), (-50, 0, "-"), (-58, -3.6, "P"),
        (-68, -6.6, "P"), (-77, -9.2, "P"), (-84, -10.6, "P")]
FORK_POINT, REJOIN_POINT = (30.0, 2.7), (-23.0, 13.2)
SAVING, LENGTH = 14.0, 220.0
STONE_TOP = 4.0


def code(x, z):
    i, j = int(round(x - S["x0"])), int(round(z - S["z0"]))
    return (S["rows"][j][i], S["h"][j][i]) if 0 <= i < S["nx"] and 0 <= j < S["nz"] else (".", -999)


def segment_distance(p, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / max(1e-9, dx * dx + dz * dz)))
    return math.hypot(p[0] - a[0] - dx * t, p[1] - a[1] - dz * t)


def ground(x, z):  # World.groundY
    h = [v if v is not None else -999 for row in G["heights"] for v in row] if not hasattr(ground, "h") else ground.h
    ground.h = h
    fx, fz = (x - G["x0"]) / G["step"], (z - G["z0"]) / G["step"]
    i, j = math.floor(fx), math.floor(fz)
    c = [h[(j + b) * G["nx"] + i + a] for a, b in ((0, 0), (1, 0), (0, 1), (1, 1))]
    u, v = fx - i, fz - j
    return c[0] * (1 - u) * (1 - v) + c[1] * u * (1 - v) + c[2] * (1 - u) * v + c[3] * u * v


def on_span(x, z, inset=0.0):
    return abs(x - SPAN[0]) <= SPAN[2] / 2 - inset and abs(z - SPAN[1]) <= SPAN[3] / 2 - inset


def in_box(x, z, box, margin=0.0):
    cx, cz, sx, sz, yaw = box
    dx, dz = x - cx, z - cz
    qx, qz = dx * math.cos(yaw) - dz * math.sin(yaw), dx * math.sin(yaw) + dz * math.cos(yaw)
    return abs(qx) <= sx / 2 + margin and abs(qz) <= sz / 2 + margin


def kerb_distance(x, z):
    best = 1e9
    for cx, cz in PARKS:
        inside = ((x - cx) / KERB[0]) ** 2 + ((z - cz) / KERB[1]) ** 2 <= 1
        for k in range(120):
            a = k * math.pi / 60
            d = math.hypot(x - cx - KERB[0] * math.cos(a), z - cz - KERB[1] * math.sin(a))
            best = min(best, 0 if inside else d)
    return best


def grove_distance(x, z):
    x0, x1, z0, z1 = GROVE
    return math.hypot(max(x0 - x, 0, x - x1), max(z0 - z, 0, z - z1))


def snap(x, z):
    cells = [(x + a, z + b) for a in range(-4, 5) for b in range(-4, 5)
             if a * a + b * b <= 16 and code(x + a, z + b)[0] == "P"]
    cells = [(round(a), round(b)) for a, b in cells]
    return (sum(c[0] for c in cells) / len(cells), sum(c[1] for c in cells) / len(cells)) if cells else (x, z)


def smooth(points, rounds=4):
    for _ in range(rounds):
        out = [points[0]]
        for (ax, az), (bx, bz) in zip(points, points[1:]):
            out += [(ax * .75 + bx * .25, az * .75 + bz * .25), (ax * .25 + bx * .75, az * .25 + bz * .75)]
        points = out + [points[-1]]
    return points


def length(points):
    return sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(points, points[1:]))


def resample(points, step=STEP):
    total = length(points)
    count = max(2, int(round(total / step)))
    out, k, walked = [points[0]], 0, 0.0
    for n in range(1, count):
        want = total * n / count
        while True:
            seg = math.hypot(points[k + 1][0] - points[k][0], points[k + 1][1] - points[k][1])
            if walked + seg >= want:
                break
            walked += seg
            k += 1
        t = (want - walked) / seg
        out.append((points[k][0] + (points[k + 1][0] - points[k][0]) * t, points[k][1] + (points[k + 1][1] - points[k][1]) * t))
    return out + [points[-1]]


def radius(a, b, c):
    ab, bc, ca = math.dist(a, b), math.dist(b, c), math.dist(c, a)
    area = abs((b[0] - a[0]) * (c[1] - a[1]) - (c[0] - a[0]) * (b[1] - a[1])) / 2
    return 1e9 if area < 1e-9 else ab * bc * ca / (4 * area)


def nearest(points, p):
    return min(range(len(points)), key=lambda i: math.dist(points[i], p))


def height(x, z):
    return DECK if on_span(x, z) else ground(x, z)


def stones_height(x, z):
    return max(ground(x, z), STONE_TOP) if crossing(x, z) else ground(x, z)


def lanes(points, i):
    a, b = points[max(i - 1, 0)], points[min(i + 1, len(points) - 1)]
    d = math.dist(a, b)
    nx, nz = -(b[1] - a[1]) / d, (b[0] - a[0]) / d
    return [(points[i][0] + nx * o, points[i][1] + nz * o) for o in ((k - (LANES - 1) / 2) * LANE_STEP for k in range(LANES))]


def faults(points, wet_ok=None, height=height):
    """Every broken rule as (amount, text). wet_ok(i) frees the stones' crossing from the water rule."""
    out = []
    for i, (x, z) in enumerate(points):
        y, name = height(x, z), f"({x:.1f},{z:.1f})"
        free = wet_ok is not None and wet_ok(x, z)
        if not free and not on_span(x, z):
            if code(x, z)[0] not in "PGg":
                out.append((4, f"{name} is {code(x, z)[0]}"))
            if any(in_box(x, z, w, .1) for w in WET):
                out.append((4, f"{name} wet"))
            for lx, lz in lanes(points, i):
                c, h = code(lx, lz)
                if on_span(lx, lz):
                    continue
                if c in "TRW." or abs(h - y) > .5:
                    out.append((1, f"{name} lane ({lx:.1f},{lz:.1f}) {c} {h}"))
        if on_span(x, z) and not all(on_span(lx, lz) for lx, lz in lanes(points, i) if abs(lx - SPAN[0]) < SPAN[2] / 2):
            out.append((3, f"{name} lane off the deck"))
        if any(in_box(x, z, b, 1) for b in BLOCKED):
            out.append((4, f"{name} blocked"))
        for what, spots, room in (("station", STATIONS, 4.5), ("lamp", LAMPS, 2.6), ("bush", BUSHES, 2.6)):
            for s in spots:
                if math.dist(s, (x, z)) < room:
                    out.append((room - math.dist(s, (x, z)), f"{name} {what} {s}"))
        for ox, oz, _, room in OBSTACLES if i else ():
            d = segment_distance((ox, oz), points[i - 1], (x, z))
            if d < room + .05:
                out.append((room + .05 - d + .5, f"{name} obstacle ({ox},{oz}) {d:.2f}"))
        for what, d in (("kerb", kerb_distance(x, z)), ("grove", grove_distance(x, z))):
            if d < KEEP:
                out.append((KEEP - d + 1, f"{name} {what} {d:.1f}"))
        if 0 < i and abs(height(*points[i - 1]) - y) > .8:
            out.append((1, f"{name} step {height(*points[i - 1]) - y:.2f}"))
        if 2 <= i < len(points) - 2:
            r = radius(points[i - 2], points[i], points[i + 2])
            if r < MIN_RADIUS:
                out.append((2 * (MIN_RADIUS - r), f"{name} turn radius {r:.1f}"))
    return out


def build(control):
    main = resample(smooth(control))
    f, r = nearest(main, FORK_POINT), nearest(main, REJOIN_POINT)
    fp, rp = main[f], main[r]
    fd = (main[f][0] - main[f - 1][0], main[f][1] - main[f - 1][1])
    rd = (main[r + 1][0] - main[r][0], main[r + 1][1] - main[r][1])
    k, m = 6 / math.hypot(*fd), 6 / math.hypot(*rd)
    branch = resample(smooth([fp, (fp[0] + fd[0] * k, fp[1] + fd[1] * k), (rp[0] - rd[0] * m, rp[1] - rd[1] * m), rp]))
    return main, f, r, branch


def crossing(x, z):  # the stream bed between the two banks, with the marble edging
    return any(in_box(x, z, w, .6) for w in WET[:-1])


def cost(control):
    main, f, r, branch = build(control)
    bad = sum(a for a, _ in faults(main)) + sum(a for a, _ in faults(branch, crossing, stones_height))
    saving = length(main[f:r + 1]) - length(branch)
    return bad * 10 + 3 * abs(saving - SAVING) + .5 * abs(length(main) - LENGTH)


def search():
    rng = random.Random(SEED)
    best = [snap(x, z) if kind == "P" else (float(x), float(z)) for x, z, kind in MAIN]
    score = cost(best)
    move = [i for i, p in enumerate(MAIN) if p[2] == "-"] + [len(MAIN) - 1]
    for n in range(1600):
        trial = list(best)
        i = rng.choice(move)
        reach = 1.6 if n < 900 else .5
        dx, dz = rng.uniform(-reach, reach), rng.uniform(-reach, reach)
        x, z = trial[i][0] + dx, trial[i][1] + dz
        trial[i] = (x, snap(x, z)[1] if MAIN[i][2] == "P" else z)
        c = cost(trial)
        if c < score:
            best, score = trial, c
    return best


def cs(v):  # hundredths of a stud, the module's integer unit
    return int(math.floor(v * 100 + .5))


def emit(control):
    main, f, r, branch = build(control)
    problems = [t for _, t in faults(main)] + ["stones: " + t for _, t in faults(branch, crossing, stones_height)]
    # Distances are measured on the rounded points, so the module's own numbers add up exactly.
    def rows(points, stones=False):
        out, d = [], 0
        for i, (x, z) in enumerate(points):
            y = stones_height(x, z) if stones else height(x, z)
            p = (cs(x), cs(y), cs(z))
            if i:
                d += int(math.floor(math.hypot(p[0] - out[-1][1], p[2] - out[-1][3]) + .5))
            out.append((d, *p))
        return out
    m, b = rows(main), rows(branch, True)
    fork, rejoin, total, stones_len = m[f][0], m[r][0], m[-1][0], b[-1][0]
    saving = rejoin - fork - stones_len
    # Stones: the branch's wet stretch, three centres spread evenly.
    wet = [row[0] for row, p in zip(b, branch) if code(*p)[0] == "W"]
    lo, hi = wet[0] - 100, wet[-1] + 100
    centres = [lo + (hi - lo) * k // 8 for k in (1, 4, 7)]
    if not 1200 <= lo <= stones_len - 1200:
        problems.append(f"stones too close to the fork: {lo}")
    if abs(saving - SAVING * 100) > 100:
        problems.append(f"saving {saving}")
    if not 20000 <= total <= 24000:
        problems.append(f"length {total}")
    if min(kerb_distance(x, z) for x, z in main + branch) < KEEP or min(grove_distance(x, z) for x, z in main + branch) < KEEP:
        problems.append("kerb or grove")
    if problems:
        raise SystemExit("course breaks its rules:\n  " + "\n  ".join(problems))
    a0, a1, b0, b1 = 1600, fork - 900, rejoin + 900, total - 1400
    def spread(lo, hi, n):
        return [lo + (hi - lo) * k // (n - 1) for k in range(n)]
    pair = 700  # two hoops close together: never nearer than the early-press reach at any speed
    layouts = [
        ("even", spread(a0, a1, 3) + spread(b0, b1, 3)),
        ("pairs", [a0 + 600, a1 - 600 - pair, a1 - 600, b0 + 400, b0 + 400 + pair, b1]),
        ("early", spread(a0, a1, 4) + spread(b0 + 600, b1 - 200, 2)),
        ("late", spread(a0 + 800, a1 - 400, 2) + spread(b0, b1, 4)),
    ]
    def flat(values):
        lines, text = [], ""
        for v in values:
            if len(text) > 150:
                lines.append(text)
                text = ""
            text += f"{v},"
        return "\n\t".join(lines + [text])
    def table(data):
        return "{\n\t" + flat([v for row in data for v in row]) + "\n}"
    stone = []
    for c in centres:
        k = max(i for i in range(len(b)) if b[i][0] <= c)
        t = (c - b[k][0]) / (b[k + 1][0] - b[k][0])
        stone.append((c, *(int(round(b[k][j] + (b[k + 1][j] - b[k][j]) * t)) for j in (1,)), cs(STONE_TOP),
                      int(round(b[k][3] + (b[k + 1][3] - b[k][3]) * t))))
    text = TEMPLATE
    for key, value in {
        "SEED": SEED, "LENGTH": total, "FORK": fork, "REJOIN": rejoin, "STONES": stones_len, "SAVING": saving,
        "MAIN": table(m), "BRANCH": table(b),
        "STONELIST": ",".join("table.freeze({d=%d,x=%d,y=%d,z=%d})" % s for s in stone),
        "LAYOUTS": "\n".join("\t%s=table.freeze({%s})," % (n, ",".join(map(str, v))) for n, v in layouts),
        "ORDER": ",".join('"%s"' % n for n, _ in layouts),
    }.items():
        text = text.replace("@" + key + "@", str(value))
    turn = min(radius(main[i - 2], main[i], main[i + 2]) for i in range(2, len(main) - 2))
    print(f"length {total / 100} fork {fork / 100} rejoin {rejoin / 100} stones {stones_len / 100} saving {saving / 100} "
          f"obstacle {min(segment_distance(o, a, b) for o in OBSTACLES for a, b in zip(main, main[1:])):.2f} min turn radius {turn:.1f} kerb {min(kerb_distance(*p) for p in main):.1f} "
          f"start {main[0]} finish {main[-1]} bushes {len(BUSHES)} layouts {layouts}")
    return text


TEMPLATE = '''-- Generated by scripts/build_dash_course.py (seed @SEED@) from assets/world/world-v7-walk.json.
-- Do not edit by hand: change the script and rerun it. V3-SCOPE-2026-11-21 section 4.2, slice S5.
--
-- The Garden Dash course: a rail line from near the arrival end of the dirt path, over the lawn and the marble
-- bridge, round the edge of the hub plaza and along the west path. Pure data and maths: no instances, no
-- requires. Every stored number is a whole number of hundredths of a stud ("cs"); the race (DashSim) counts
-- only the centre line, so a lane is a drawing offset and no lane is shorter on a bend.
--   Main      d, x, y, z per point, d = distance from the start arch
--   Branch    the stepping stones, d from the fork; shorter than the same stretch of Main by Saving
--   Layouts   hurdle distances on Main: six hoops each, none between the fork and the rejoin
-- Heights are World.groundY (and the marble deck), the same ground the park pets stand on.
local Course={}

Course.Version=1
Course.Length=@LENGTH@
Course.Fork=@FORK@
Course.Rejoin=@REJOIN@
Course.StonesLength=@STONES@
Course.Saving=@SAVING@
Course.LaneCount=8
Course.LaneStep=50 -- eight lanes inside the 4-stud path
Course.HurdleHeight=80
Course.CloverPast=150 -- a lucky clover grows this far past its hurdle [P]
Course.Main=table.freeze(@MAIN@)
Course.Branch=table.freeze(@BRANCH@)
-- Stone centres: d along Branch (where the hop is judged), then the world spot.
Course.Stones=table.freeze({@STONELIST@})
Course.LayoutOrder=table.freeze({@ORDER@})
Course.Layouts=table.freeze({
@LAYOUTS@
})

-- Headings at the points (unit dx, dz pairs), so a lane bends smoothly. The branch borrows the main line's own
-- heading where they meet.
local function headings(list)
	local out,n={},#list//4
	for i=1,n do
		local a,b=math.max(i-1,1)*4-3,math.min(i+1,n)*4-3
		local dx,dz=list[b+1]-list[a+1],list[b+3]-list[a+3]
		local run=math.sqrt(dx*dx+dz*dz)
		out[i*2-1],out[i*2]=dx/run,dz/run
	end
	return out
end
local mainHeading,branchHeading=headings(Course.Main),headings(Course.Branch)
for i=1,#Course.Main//4 do
	local d=Course.Main[i*4-3]
	local at=if d==Course.Fork then 1 elseif d==Course.Rejoin then #Course.Branch//4 else nil
	if at then branchHeading[at*2-1],branchHeading[at*2]=mainHeading[i*2-1],mainHeading[i*2]end
end

-- The point at distance `cs` on a flat d,x,y,z list: x, y, z in studs and the heading
-- (atan2(dx, dz), the GardenActivity convention). Clamped at both ends; about seven comparisons.
local function sample(list,heading,cs,offset)
	local n=#list//4
	cs=math.clamp(cs,0,list[n*4-3])
	local lo,hi=1,n-1
	while lo<hi do
		local mid=(lo+hi+1)//2
		if list[mid*4-3]<=cs then lo=mid else hi=mid-1 end
	end
	local a,b=lo*4-3,lo*4+1
	local t=(cs-list[a])/(list[b]-list[a])
	local hx=heading[lo*2-1]+(heading[lo*2+1]-heading[lo*2-1])*t
	local hz=heading[lo*2]+(heading[lo*2+2]-heading[lo*2])*t
	local run=math.sqrt(hx*hx+hz*hz)
	return (list[a+1]+(list[b+1]-list[a+1])*t-hz/run*offset)/100,(list[a+2]+(list[b+2]-list[a+2])*t)/100,
		(list[a+3]+(list[b+3]-list[a+3])*t+hx/run*offset)/100,math.atan2(hx,hz)
end

-- Sideways offset of a lane in cs (lane 1..8; a missing lane is the centre line).
function Course.laneOffset(lane)
	if type(lane)~="number"then return 0 end
	return (lane-(Course.LaneCount+1)/2)*Course.LaneStep
end
-- Where to draw a runner. cs is the distance on Main, or along Branch when onStones.
function Course.at(cs,onStones,lane)
	if onStones then return sample(Course.Branch,branchHeading,cs,Course.laneOffset(lane))end
	return sample(Course.Main,mainHeading,cs,Course.laneOffset(lane))
end
function Course.hurdles(layout)
	return Course.Layouts[layout]or Course.Layouts.even
end

return table.freeze(Course)
'''


def main():
    text = emit(search())
    if "--check" in sys.argv:
        if OUT.read_bytes().decode().replace("\r\n", "\n") != text:
            raise SystemExit("DashCourse.lua is stale: rerun scripts/build_dash_course.py")
        print("DashCourse.lua is current")
        return
    OUT.write_text(text, encoding="utf-8", newline="\r\n")
    print(f"-> {OUT}")


if __name__ == "__main__":
    main()
