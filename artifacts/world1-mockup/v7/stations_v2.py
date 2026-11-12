"""Egg Drop station definitions, v2 (marble-garden style). Shared by build_world_v6.py and build_stations_v2.py.

Each st_*() returns a list of parts: (part name, mesh builder, material names, smooth?). Local space: origin on the
ground at the station centre, front is -Y, up is +Z, 1 unit = 1 stud. All shapes and motifs are original.
"""


def b_deck_kiosk(mb):
    """Front is -Y. Counter footprint 5.3 x 2.4 as before; sign frame stands on the back edge."""
    def handheld(cx, cy, cz, w, tilt=0.0):
        """Our own friendly handheld: wide shell with two round 'ears', glowing screen, cross pad, two buttons."""
        hgt = w * .56; M = Matrix.Translation((cx, cy, cz)) @ Matrix.Rotation(tilt, 4, 'X'); th_ = w * .09
        v, f = box(w, th_, hgt); mb.add(v, f, 3, M=M)
        for sx_ in (-1, 1):
            v, f, uv = lathe([(w * .13, -th_ / 2), (w * .13, th_ / 2)], 10, True, True); mb.add(v, f, 3, uvs=uv, M=M @ Matrix.Translation((sx_ * w * .36, 0, hgt * .5)) @ Matrix.Rotation(math.pi / 2, 4, 'X'))
            v, f, uv = lathe([(w * .07, -th_ * .7), (w * .07, th_ * .7)], 8, True, True); mb.add(v, f, 4, uvs=uv, M=M @ Matrix.Translation((sx_ * w * .36, 0, hgt * .5)) @ Matrix.Rotation(math.pi / 2, 4, 'X'))
        v, f = box(w * .40, th_ * .3, hgt * .62, (0, -th_ * .55, hgt * .02)); mb.add(v, f, 5, M=M)                       # screen
        v, f = box(w * .44, th_ * .2, hgt * .70, (0, -th_ * .5, hgt * .02)); mb.add(v, f, 4, M=M)                        # cream bezel
        for (bw, bh) in ((w * .15, w * .05), (w * .05, w * .15)):                                                        # cross pad
            v, f = box(bw, th_ * .3, bh, (-w * .35, -th_ * .6, -hgt * .02)); mb.add(v, f, 4, M=M)
        for (bx_, bz_, rr, m_) in ((w * .38, hgt * .06, w * .05, 2), (w * .30, -hgt * .14, w * .04, 6)):                  # A (gold) and B (pink)
            v, f, uv = lathe([(rr, th_ * .4), (rr, th_ * .8)], 8, True, True); mb.add(v, f, m_, uvs=uv, M=M @ Matrix.Translation((bx_, 0, bz_)) @ Matrix.Rotation(math.pi / 2, 4, 'X'))
    for sx_ in (-1, 1):                                              # marble counter legs, wood top, carved fascia
        v, f = box(1.0, 2.1, 2.2, (sx_ * 2.05, 0, 1.1)); mb.add(v, f, 0, scale=.2)
    v, f = box(3.1, .3, 1.7, (0, .85, 1.1)); mb.add(v, f, 1, scale=.25)                                                   # wood back panel under the top
    v, f = box(5.4, 2.5, .28, (0, 0, 2.34)); mb.add(v, f, 1, scale=.25)
    trim_box(mb, 5.2, .14, .5, 1, Matrix.Translation((0, -1.2, 2.0)), 9)
    for sx_ in (-1, 1):                                              # sign frame: two slim columns, wood beam, lanterns
        v, f, uv = lathe([(.42, 2.48), (.3, 2.75), (.24, 6.2), (.36, 6.45)], 8); mb.add(v, f, 0, uvs=uv, colfn=flute, M=Matrix.Translation((sx_ * 2.35, .95, 0)))
        v, f = box(.8, .8, .22, (sx_ * 2.35, .95, 6.56)); mb.add(v, f, 2)
        v, f = box(.06, .06, .7, (sx_ * 2.95, .95, 6.25)); mb.add(v, f, 2)
        v, f = blob(1, 4, rough=0, squash=(.3, .3, .36), center=(sx_ * 2.95, .95, 5.72)); mb.add(v, f, 8)
    v, f = box(6.4, .5, .34, (0, .95, 6.82)); mb.add(v, f, 1, scale=.25)
    v, f = box(5.0, .16, .1, (0, .95, 7.04)); mb.add(v, f, 2)
    handheld(0, .82, 4.72, 3.7)                                      # the big sign
    handheld(-1.3, -.35, 2.86, 1.05, tilt=-.9)                       # a deck on the bench, propped up
    v, f = box(.5, .5, .5, (-1.3, .05, 2.6)); mb.add(v, f, 1, scale=.25)
    for k, (px_, m_) in enumerate(((.5, 6), (1.05, 7), (1.6, 5))):   # paint pots for restyling
        v, f, uv = lathe([(.2, 2.48), (.22, 2.85)], 8, cap_top=True); mb.add(v, f, 4, uvs=uv, M=Matrix.Translation((px_, -.3 + .25 * (k % 2), 0)))
        v, f, uv = lathe([(.17, 2.86), (.17, 2.88)], 8, cap_top=True); mb.add(v, f, m_, uvs=uv, M=Matrix.Translation((px_, -.3 + .25 * (k % 2), 0)))
    v, f = box(1.0, .7, .04, (1.5, .55, 2.5)); mb.add(v, f, 4)                                                             # sticker sheet
    for k in range(6):
        v, f = box(.2, .2, .02, (1.2 + (k % 3) * .3, .4 + (k // 3) * .3, 2.53)); mb.add(v, f, (2, 6, 7, 5, 6, 2)[k])


# ------------------------------------------------------------------ helpers (defined here so the module also works standalone)
def st_flute(p, n):
    a = math.atan2(p[1], p[0]); k = (.94 if math.sin(a * 10) > 0 else 1.0) * (.9 + .12 * (n[2] * .5 + .5))
    return (k, k, k)


if 'flute' not in globals(): flute = st_flute
if 'row_v' not in globals():
    def row_v(row): return (.75 - .25 * row, 1.0 - .25 * row)

    def trim_box(mb, L, D, Hh, row, M, mat):
        v, f = box(L, D, Hh); uv = []
        for k, p in enumerate(v):
            face = k // 4; vv = (row_v(row)[0] + (p[2] / Hh + .5) * .25)
            if face in (2, 3): uv.append((p[0] / (4 * Hh), vv))
            elif face in (4, 5): uv.append((p[1] / (4 * Hh), vv))
            else: uv.append((p[0] / (4 * Hh), .02 + (p[1] / D + .5) * .2))
        mb.add(v, f, mat, uvs=uv, M=M)


def trim_ring(mb, r, z0, z1, row, reps, mat, sides=16):
    """Carved band wrapped round a drum (row 0 paw/star, 1 zig-zag, 2 egg/leaf)."""
    v, f, uv = lathe([(r, z0), (r, z1)], sides)
    v0, v1 = row_v(row)
    mb.add(v, f, mat, uvs=[((n_ % (sides + 1)) / sides * reps, v0 + .02 + (n_ // (sides + 1)) * (v1 - v0 - .04)) for n_ in range(len(v))])


def arch_half(ri, ro, dp, n=12):
    """Half-ring (springing at z = 0, depth along Y) with outward-facing quads."""
    V = []; F = []
    for k in range(n + 1):
        a = math.pi * k / n; c, s_ = math.cos(a), math.sin(a)
        V += [(-c * ri, -dp / 2, s_ * ri), (-c * ri, dp / 2, s_ * ri), (-c * ro, -dp / 2, s_ * ro), (-c * ro, dp / 2, s_ * ro)]
    for k in range(n):
        a = k * 4; b = a + 4
        for q in ([a, b, b + 1, a + 1], [a + 2, a + 3, b + 3, b + 2], [a, a + 2, b + 2, b], [a + 1, b + 1, b + 3, a + 3]):
            p0, p1, p2 = Vector(V[q[0]]), Vector(V[q[1]]), Vector(V[q[2]])
            cen = sum((Vector(V[i]) for i in q), Vector()) / 4; am = math.pi * (k + .5) / n
            core = Vector((-math.cos(am) * (ri + ro) / 2, 0, math.sin(am) * (ri + ro) / 2))
            F.append(q if (p1 - p0).cross(p2 - p0).dot(cen - core) > 0 else q[::-1])
    return V, F


def TL(x, y, z=0.0): return Matrix.Translation((x, y, z))


STATION_MATS = {
    'marble': ('tex', 'marble_block', .55, .2), 'marble_smooth': ('tex', 'marble_smooth', .32, .45), 'trim': ('tex', 'marble_trim', .5, .2),
    'wood_plank': ('tex', 'wood_plank', .7, .25), 'foliage': ('tex', 'foliage', .8, .25), 'grass': ('tex', 'grass', .9, .25),
    'gold': ('flat', '#F2B62E', dict(rough=.3, spec=.8, coat=.3)), 'teal': ('flat', '#12B0A8', dict(rough=.35, coat=.3)),
    'deck_shell': ('flat', '#3B4A78', dict(rough=.35, coat=.4)), 'deck_cream': ('flat', '#FFF3D6', dict(rough=.4)),
    'glow_aqua': ('flat', '#4FE6FF', dict(emit=1.3, rough=.2)), 'glow_warm': ('flat', '#FFD98A', dict(emit=1.4)), 'glow_pink': ('flat', '#FF9FD0', dict(emit=1.0)),
    'ph_pink': ('flat', '#FF8FBE', dict(rough=.45)), 'ph_mint': ('flat', '#7DEBAA', dict(rough=.45)), 'ph_yellow': ('flat', '#FFD84A', dict(rough=.45)),
    'ph_lilac': ('flat', '#B79BFF', dict(rough=.45)), 'ph_white': ('flat', '#FFFFFF', dict(rough=.3, coat=.3)), 'ph_aqua': ('flat', '#35C7F5', dict(rough=.25, coat=.4)),
    'care_sage': ('flat', '#B4E6B9', dict(rough=.6)), 'care_teal': ('flat', '#3CC9BE', dict(rough=.3, coat=.4)), 'care_blush': ('flat', '#FFC9DC', dict(rough=.6)),
    'book_green': ('flat', '#2F7A4D', dict(rough=.5)), 'egg': ('flat', '#FFF9F0', dict(rough=.3, coat=.5, vcol=True)),
    'avatar_skin': ('flat', '#F2D3B1', dict(rough=.6)), 'avatar_shirt': ('flat', '#F4573B', dict(rough=.6)), 'avatar_pants': ('flat', '#3B4C8C', dict(rough=.6)),
}


def ensure_station_mats():
    for nm, spec in STATION_MATS.items():
        if nm in MAT: continue
        if spec[0] == 'tex': mat_tex(nm, spec[1], spec[2], spec=spec[3])
        else: mat_flat(nm, lin(spec[1]), **spec[2])


def _part(parts, name, mats, smooth=False):
    mb = MB(); parts.append((name, mb, mats, smooth)); return mb


def _post(mb, x, y, h, r=.2, mat=0, sides=8):
    v, f, uv = lathe([(r * 1.9, 0), (r * 1.9, .2), (r * 1.2, .34), (r, .6), (r * .85, h - .22), (r * 1.4, h)], sides); mb.add(v, f, mat, uvs=uv, colfn=st_flute, M=TL(x, y))


# ================================================================== CARE CRADLE (the "Care machine": dock a pet, restyle hue / charm, open companions)
def st_care():
    parts = []; M3 = ['marble', 'gold', 'trim']
    mb = _part(parts, 'Dais', M3)
    v, f, uv = lathe([(2.75, -.3), (2.75, .22), (2.45, .22), (2.45, .5)], 16, cap_top=True); mb.add(v, f, 0, uvs=uv)
    trim_ring(mb, 2.46, .24, .48, 2, 5, 2)
    mb = _part(parts, 'Cradle_Pedestal', ['care_teal', 'deck_cream'], True)
    v, f, uv = lathe([(1.25, .5), (1.02, .72), (.8, 1.25), (1.15, 1.52)], 12); mb.add(v, f, 0, uvs=uv)
    v, f, uv = lathe([(1.15, 1.52), (1.58, 1.6), (1.62, 1.76), (1.42, 1.82), (1.3, 1.7)], 14); mb.add(v, f, 1, uvs=uv)
    mb = _part(parts, 'Cradle_Cushion', ['care_sage', 'ph_mint'], True)
    v, f, uv = lathe([(1.32, 1.72), (1.22, 1.9), (.62, 1.99), (.02, 2.0)], 14); mb.add(v, f, 0, uvs=uv)
    for sx_ in (-1, 1):                                              # two soft paw marks where the pet stands
        v, f, uv = lathe([(.02, 2.0), (.2, 2.0)], 8); mb.add(v, f, 1, uvs=uv, M=TL(sx_ * .34, -.35, .012))
    mb = _part(parts, 'Canopy_Arch', ['marble', 'gold'])
    for sx_ in (-1, 1):
        _post(mb, sx_ * 2.05, 1.0, 4.4, .23); v, f = box(.72, .72, .2, (sx_ * 2.05, 1.0, 4.5)); mb.add(v, f, 1)
    V, F = arch_half(1.83, 2.27, .55, 12); mb.add(V, F, 0, scale=.2, M=TL(0, 1.0, 4.6))
    v, f, uv = lathe([(.02, 6.86), (.34, 7.1), (.02, 7.6)], 4); mb.add(v, f, 1, uvs=uv, M=TL(0, 1.0))        # little gold spark on the crown
    mb = _part(parts, 'Canopy_Mobile_Glow', ['gold', 'glow_warm', 'care_blush', 'care_sage'], True)
    for k, (dx, L, m_) in enumerate(((-.9, .9, 2), (0, 1.3, 1), (.9, .9, 3))):                               # a three-piece mobile: the middle orb glows
        top = 4.6 + math.sqrt(1.83 ** 2 - dx * dx)
        v, f = box(.04, .04, L, (dx, 1.0, top - L / 2)); mb.add(v, f, 0)
        v, f = blob(1, 3 + k, rough=0, squash=(.26, .26, .3) if m_ != 1 else (.34, .34, .34), center=(dx, 1.0, top - L - .2)); mb.add(v, f, m_)
    mb = _part(parts, 'Gauge_Post', ['marble_smooth', 'gold', 'glow_aqua'])
    _post(mb, 2.0, -1.5, 1.95, .19)
    Mg = TL(2.0, -1.55, 2.2) @ Matrix.Rotation(.5, 4, 'X')
    v, f = box(.9, .14, .56); mb.add(v, f, 0, M=Mg, scale=.2)
    v, f = box(.62, .06, .16, (0, -.09, .08)); mb.add(v, f, 2, M=Mg)                                          # the glowing care bar
    v, f, uv = lathe([(.1, .0), (.1, .08)], 8, cap_top=True); mb.add(v, f, 1, uvs=uv, M=Mg @ TL(.26, -.07, -.14) @ Matrix.Rotation(math.pi / 2, 4, 'X'))
    mb = _part(parts, 'Journal_Lectern', ['marble_smooth', 'book_green', 'deck_cream', 'gold'])
    _post(mb, -2.0, -1.5, 1.95, .19)
    Mj = TL(-2.0, -1.55, 2.12) @ Matrix.Rotation(.5, 4, 'X')
    v, f = box(1.15, .1, .8); mb.add(v, f, 0, M=Mj, scale=.2)
    v, f = box(1.02, .06, .66, (0, -.08, 0)); mb.add(v, f, 1, M=Mj)
    for sx_ in (-1, 1):
        v, f = box(.46, .05, .58, (sx_ * .25, -.13, 0)); mb.add(v, f, 2, M=Mj)
    v, f = box(.06, .07, .7, (0, -.14, 0)); mb.add(v, f, 3, M=Mj)
    return parts


# ================================================================== EGG NEST (hatch spot under the Hatch Tree: "Browse eggs")
def st_egg():
    parts = []
    mb = _part(parts, 'Steps', ['marble', 'gold', 'trim'])
    v, f, uv = lathe([(3.4, -.3), (3.4, .25), (2.8, .25), (2.8, .5), (2.2, .5), (2.2, .78)], 16, cap_top=True); mb.add(v, f, 0, uvs=uv)
    trim_ring(mb, 2.21, .52, .76, 2, 4, 2)
    mb = _part(parts, 'Nest_Cup', ['gold', 'foliage'], True)
    v, f, uv = lathe([(.9, .78), (1.3, .95), (1.5, 1.25), (1.38, 1.32), (1.12, 1.06)], 12); mb.add(v, f, 0, uvs=uv)
    v, f, uv = lathe([(.02, 1.02), (1.14, 1.08)], 12); mb.add(v, f, 1, uvs=uv)
    for k in range(6):                                               # leaf tips round the rim
        a = k / 6 * 6.283
        mb.add([(math.cos(a - .22) * 1.4, math.sin(a - .22) * 1.4, 1.26), (math.cos(a + .22) * 1.4, math.sin(a + .22) * 1.4, 1.26), (math.cos(a) * 1.95, math.sin(a) * 1.95, 1.5)], [[0, 1, 2], [2, 1, 0]], 1, scale=.3)
    mb = _part(parts, 'Egg', ['egg'], True)
    v, f, uv = lathe([(.02, 1.0), (.55, 1.15), (.95, 1.7), (1.02, 2.2), (.85, 2.8), (.5, 3.25), (.02, 3.4)], 12)
    mb.add(v, f, 0, uvs=uv, colfn=lambda p, n: (.45, .88, 1.0) if math.sin(p[2] * 5.5 + math.atan2(p[1], p[0]) * 2) > .55 else (1, 1, 1))
    mb = _part(parts, 'Glow_Halo', ['glow_warm'])
    v, f, uv = lathe([(1.02, 1.09), (1.34, 1.2)], 12); mb.add(v, f, 0, uvs=uv)
    mb = _part(parts, 'Sign_Stele', ['marble_smooth', 'gold'], False)
    v, f = box(1.0, .26, 1.5, (2.75, .9, 1.0)); mb.add(v, f, 0, scale=.2)
    v, f, uv = lathe([(.5, -.13), (.5, .13)], 10, True, True); mb.add(v, f, 0, uvs=uv, M=TL(2.75, .9, 1.75) @ Matrix.Rotation(math.pi / 2, 4, 'X'))
    v, f = box(1.3, .5, .25, (2.75, .9, .37)); mb.add(v, f, 0, scale=.2)
    v, f = blob(1, 2, rough=0, squash=(.24, .07, .33), center=(2.75, .74, 1.45)); mb.add(v, f, 1)                 # gold egg emblem
    return parts


# ================================================================== TOY LAWN (toys the pets chase and play with)
def st_toys():
    parts = []
    mb = _part(parts, 'ToyChest', ['marble', 'gold', 'wood_plank', 'ph_pink', 'ph_yellow', 'ph_mint'])
    v, f = box(2.4, 1.5, 1.0, (-1.7, .7, .5)); mb.add(v, f, 0, scale=.2)
    for z_ in (.12, .9):
        v, f = box(2.5, 1.6, .12, (-1.7, .7, z_)); mb.add(v, f, 1)
    Ml = TL(-1.7, 1.45, 1.0) @ Matrix.Rotation(-1.05, 4, 'X')
    v, f = box(2.5, 1.6, .16, (0, -.8, .08)); mb.add(v, f, 2, M=Ml, scale=.25)
    for k, (dx, dy, m_) in enumerate(((-.6, 0, 3), (0, .15, 4), (.6, -.05, 5))):
        v, f = blob(1, 10 + k, rough=.1, squash=(.42, .42, .42), center=(-1.7 + dx, .7 + dy, 1.05)); mb.add(v, f, m_)
    mb = _part(parts, 'Ball', ['egg'], True)
    v, f = blob(2, 0, rough=0, squash=(.85, .85, .85), center=(1.2, -.7, .85))
    mb.add(v, f, 0, colfn=lambda p, n: (1, 1, 1) if (math.atan2(p[1] + .7, p[0] - 1.2) * 3 / 3.1416) % 2 < 1 else (.45, .85, 1))
    mb = _part(parts, 'StackingRings', ['marble_smooth', 'gold', 'ph_pink', 'ph_yellow', 'ph_mint'], True)
    v, f, uv = lathe([(.7, 0), (.7, .16), (.16, .22), (.12, 1.6), (.02, 1.75)], 8); mb.add(v, f, 1, uvs=uv, M=TL(2.3, 1.0))
    for k, (rr, m_) in enumerate(((.62, 2), (.5, 3), (.38, 4))):
        z_ = .42 + k * .36
        v, f, uv = lathe([(rr + .17, z_), (rr, z_ + .17), (rr - .17, z_), (rr, z_ - .17), (rr + .17, z_)], 10); mb.add(v, f, m_, uvs=uv, M=TL(2.3, 1.0))
    mb = _part(parts, 'Blocks', ['ph_lilac', 'ph_yellow', 'ph_mint', 'gold'])
    for k, (x, y, z_, s, m_, rz) in enumerate(((.2, 1.3, .5, 1.0, 0, .2), (1.15, 1.6, .5, 1.0, 1, -.3), (.65, 1.45, 1.5, 1.0, 2, .5))):
        v, f = box(s, s, s); mb.add(v, f, m_, M=TL(x, y, z_) @ Matrix.Rotation(rz, 4, 'Z'))
        v, f = box(s * .45, s * 1.02, s * .45); mb.add(v, f, 3, M=TL(x, y, z_) @ Matrix.Rotation(rz, 4, 'Z'))
    return parts


# ================================================================== NAP DAIS (rest anchors: creek nook, spring meadow)
def st_nap(cushion='ph_pink'):
    parts = []
    mb = _part(parts, 'Dais', ['marble', 'trim'])
    v, f, uv = lathe([(2.3, -.3), (2.3, .3), (2.05, .36)], 14, cap_top=True); mb.add(v, f, 0, uvs=uv)
    trim_ring(mb, 2.31, .03, .27, 0, 5, 1, 14)
    mb = _part(parts, 'Cushion', [cushion, 'gold'], True)
    v, f, uv = lathe([(.1, .36), (1.7, .4), (1.95, .62), (1.7, .86), (.5, .95), (.02, .9)], 14); mb.add(v, f, 0, uvs=uv)
    v, f, uv = lathe([(.02, .9), (.18, .94), (.02, .99)], 8); mb.add(v, f, 1, uvs=uv)
    mb = _part(parts, 'StarLamp', ['marble_smooth', 'gold', 'glow_warm'], True)
    _post(mb, 0, 1.95, 2.3, .13, sides=6)
    v, f, uv = lathe([(.02, 2.3), (.3, 2.62), (.02, 2.95)], 4); mb.add(v, f, 2, uvs=uv, M=TL(0, 1.95))
    v, f, uv = lathe([(.02, 2.95), (.1, 3.0), (.02, 3.2)], 4); mb.add(v, f, 1, uvs=uv, M=TL(0, 1.95))
    return parts


# ================================================================== BENCH + PICNIC TABLE
def st_bench():
    parts = []
    mb = _part(parts, 'Supports', ['marble', 'gold'])
    for sx_ in (-1, 1):
        v, f = box(.8, 1.75, .2, (sx_ * 2.2, 0, .1)); mb.add(v, f, 0, scale=.2)
        v, f = box(.5, 1.5, .9, (sx_ * 2.2, 0, .62)); mb.add(v, f, 0, scale=.2)
        v, f = box(.42, .32, 1.4, (sx_ * 2.2, .7, 1.75)); mb.add(v, f, 0, scale=.2)
        v, f = box(.56, .46, .14, (sx_ * 2.2, .7, 2.5)); mb.add(v, f, 1)
    mb = _part(parts, 'Seat_Slats', ['wood_plank'])
    for y_ in (-.48, 0, .48):
        v, f = box(5.0, .42, .14, (0, y_, 1.14)); mb.add(v, f, 0, scale=.25)
    for z_ in (1.62, 2.12):
        v, f = box(5.0, .12, .36, (0, .66, z_)); mb.add(v, f, 0, scale=.25)
    return parts


def st_picnic():
    parts = []
    mb = _part(parts, 'Trestles', ['marble', 'gold'])
    for sx_ in (-1, 1):
        v, f = box(.9, 2.3, .2, (sx_ * 1.8, 0, .1)); mb.add(v, f, 0, scale=.2)
        v, f = box(.5, 1.9, 1.0, (sx_ * 1.8, 0, .7)); mb.add(v, f, 0, scale=.2)
        for sy_ in (-1, 1):
            v, f = box(.5, .8, .68, (sx_ * 1.9, sy_ * 2.15, .34)); mb.add(v, f, 0, scale=.2)
    v, f = box(5.3, 2.5, .08, (0, 0, 1.2)); mb.add(v, f, 1)
    mb = _part(parts, 'Top_And_Seats', ['wood_plank'])
    v, f = box(5.2, 2.4, .22, (0, 0, 1.35)); mb.add(v, f, 0, scale=.25)
    for sy_ in (-1, 1):
        v, f = box(5.4, .9, .18, (0, sy_ * 2.15, .77)); mb.add(v, f, 0, scale=.25)
    return parts


# ================================================================== ARRIVAL DAIS (spawn pad) + LAMP
def st_spawn():
    parts = []
    mb = _part(parts, 'Dais', ['marble', 'trim'])
    v, f, uv = lathe([(4.3, -.3), (4.3, .2), (3.5, .2), (3.5, .34)], 20, cap_top=True); mb.add(v, f, 0, uvs=uv)
    V = []; U = []; F = []
    for k in range(21):
        a = k / 20 * 6.283
        V += [(math.cos(a) * 2.45, math.sin(a) * 2.45, .35), (math.cos(a) * 3.3, math.sin(a) * 3.3, .35)]; U += [(k * .25, .52), (k * .25, .73)]
    for k in range(20): F.append([k * 2, k * 2 + 1, k * 2 + 3, k * 2 + 2])
    mb.add(V, F, 1, uvs=U)
    mb = _part(parts, 'Glow_Disc', ['glow_aqua', 'gold'])
    v, f, uv = lathe([(.02, .36), (2.3, .36)], 20); mb.add(v, f, 0, uvs=uv)
    V = [(0, 0, .375)] + [(math.cos(k / 16 * 6.283) * (1.5 if k % 2 == 0 else .65), math.sin(k / 16 * 6.283) * (1.5 if k % 2 == 0 else .65), .375) for k in range(16)]
    mb.add(V, [[0, 1 + k, 1 + (k + 1) % 16] for k in range(16)], 1)
    return parts


def st_lamp():
    parts = []
    mb = _part(parts, 'Post', ['marble_smooth', 'gold'], True)
    v, f, uv = lathe([(.46, 0), (.46, .24), (.27, .4), (.2, .72), (.15, 3.5), (.32, 3.72)], 8); mb.add(v, f, 0, uvs=uv, colfn=st_flute)
    v, f, uv = lathe([(.38, 3.72), (.38, 3.86)], 8, cap_top=True); mb.add(v, f, 1, uvs=uv)
    v, f, uv = lathe([(.52, 4.98), (.14, 5.25), (.02, 5.55)], 6); mb.add(v, f, 1, uvs=uv)
    mb = _part(parts, 'Orb_Glow', ['glow_warm'], True)
    v, f = blob(1, 0, rough=0, squash=(.58, .58, .6), center=(0, 0, 4.42)); mb.add(v, f, 0)
    return parts


def st_kiosk():
    mb = MB(); b_deck_kiosk(mb)
    return [('Kiosk', mb, ['marble', 'wood_plank', 'gold', 'deck_shell', 'deck_cream', 'glow_aqua', 'ph_pink', 'ph_mint', 'glow_warm', 'trim'], False)]


STATION_DEFS = {'CareCradle': st_care, 'EggNest': st_egg, 'PocketDeckKiosk': st_kiosk, 'ToyLawn': st_toys, 'NapDais': st_nap, 'Bench': st_bench,
                'PicnicTable': st_picnic, 'ArrivalDais': st_spawn, 'Lamp': st_lamp}
