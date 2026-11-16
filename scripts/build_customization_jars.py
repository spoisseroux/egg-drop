"""Customization Egg item art: hue jars, finish jars and the rare charm capsule.

QA 2026-11-16c (v775) item 5: "we need new icons or models for the hue jars, they suck rn".
Replaces the flat UI-frame jar (src/client/HueJarArt.lua) and the identical teal finish
spheres with one toy "paint pot" family. Original shapes, modelled here from code.

Design rules (art lead):
  * One shared pot: squat, round, 12-sided lathe, smooth shaded. Cream lid.
  * Every item has its own TOPPER silhouette, so it reads without colour:
      rose = flower, tide = droplet, citrus = lemon + leaf, iris = three-petal fan,
      reset = ring, gloss = sparkle star, matte = powder puff, jelly = wobbly dome.
  * Hue jars: pigment colour from HueCatalog, pale "glass" band above the fill line,
    one white highlight (house icon rule: one highlight).
  * Finish jars are one colour all over (the default pet mint) so the SURFACE is the
    message: gloss = big crisp highlight + sparkle, matte = no highlight at all + chalk
    puff, jelly = see-through, leaning, lobed, with bubbles and a lid sliding off.
  * Charm capsule: a ball, not a pot. Clear dome, gold star inside, loop on top.
  * Colour is stored in the "Col" corner attribute, so the meshes need no textures.
  * Budget: 300-800 triangles per item (the manifest lists the real counts).

Two ways to run it:
  blender --background --factory-startup --python scripts/build_customization_jars.py
      builds the scene, saves assets/art-source/jars/customization-jars.blend, writes the
      manifest and renders each item plus the lineup to artifacts/qa-2026-11-16c-v775/jars/
  python scripts/build_customization_jars.py sheets
      (plain Python with Pillow) builds the 64 px icon sheet and the before/after compare
      from those renders.

Nothing here uploads anything. Mesh ids come later, after Spencer approves the renders.
"""
import json
import math
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
BLEND = os.path.join(ROOT, "assets", "art-source", "jars", "customization-jars.blend")
MANIFEST = os.path.join(ROOT, "assets", "art-source", "jars", "customization-jars-manifest.json")
OUT = os.path.join(ROOT, "artifacts", "qa-2026-11-16c-v775", "jars")
BEFORE_HUES = os.path.join(ROOT, "artifacts", "qa-followup-v685-2026-11-14", "native", "final-jars-contact.png")
BEFORE_FINISH = os.path.join(ROOT, "artifacts", "qa-followup-v685-2026-11-14", "native", "jars-and-finishes-contact.png")

# id, label, kind, colour. Hue colours are HueCatalog.Order / Items; finishes use the pet mint.
ITEMS = [
    ("rose", "Rose jar", "hue", "#FF327A"),
    ("tide", "Tide jar", "hue", "#008DFF"),
    ("citrus", "Citrus jar", "hue", "#FFCC00"),
    ("iris", "Iris jar", "hue", "#9350FF"),
    ("reset", "Reset Hue", "hue", "#D4F8FF"),
    ("gloss", "Gloss", "finish", "#58DDC2"),
    ("matte", "Matte", "finish", "#58DDC2"),
    ("jelly", "Jelly", "finish", "#58DDC2"),
    ("charm", "Charm capsule", "charm", "#B79BFF"),
]
SPACING = 1.5
CREAM = "#FFF3D6"
GOLD = "#FFCB3D"
LEAF = "#57C96B"
SEGS = 12
FILL = 0.56  # pigment fill line on the pot

# Pot and lid profiles, (radius, height), bottom to top.
POT = [(0, 0), (.30, 0), (.44, .05), (.52, .20), (.53, .38), (.48, FILL), (.39, .68), (.345, .74), (.345, .80)]
LID = [(.36, .76), (.425, .78), (.44, .84), (.44, .93), (.38, 1.00), (.20, 1.03), (0, 1.035)]
LID_TOP = 1.03
TOPPER_SCALE = 1.55  # pass 2: toppers carry the read at 64 px, so they are big


def hex_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) / 255 for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def pot_radius(z, profile=POT):
    for (r0, z0), (r1, z1) in zip(profile, profile[1:]):
        if z1 > z0 and z0 <= z <= z1:
            return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
    return profile[-1][0]


# --------------------------------------------------------------------------- Blender build
def build():
    import bmesh
    import bpy
    from mathutils import Matrix, Vector

    def lin(c):
        return tuple(x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4 for x in c)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    scene = bpy.context.scene

    # ---- materials: colour always comes from the "Col" attribute
    def material(name, rough=.4, coat=0.0, alpha=1.0, emit=0.0, spec=.5):
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
        col = nodes.new("ShaderNodeAttribute")
        col.attribute_name = "Col"

        def put(key, value):
            if key in bsdf.inputs:
                bsdf.inputs[key].default_value = value

        links.new(col.outputs["Color"], bsdf.inputs["Base Color"])
        put("Roughness", rough)
        put("Coat Weight", coat)
        put("Coat Roughness", .03)
        put("Specular IOR Level", spec)
        put("Alpha", alpha)
        if emit > 0:
            if True:
                links.new(col.outputs["Color"], bsdf.inputs["Emission Color"])
            put("Emission Strength", emit)
        if alpha < 1:
            try:
                mat.surface_render_method = "BLENDED"
            except (AttributeError, TypeError):
                mat.blend_method = "BLEND"
            for prop in ("use_transparency_overlap", "show_transparent_back"):
                if hasattr(mat, prop):
                    setattr(mat, prop, False)
        return mat

    M = {
        "jar": material("Jar_Satin", rough=.32, coat=.35),
        "lid": material("Jar_Lid", rough=.55),
        "shine": material("Jar_Shine", rough=1, emit=1.0, spec=0),
        "gloss": material("Finish_Gloss", rough=.04, coat=1.0, spec=.9),
        "matte": material("Finish_Matte", rough=1.0, spec=0.0),
        "jelly": material("Finish_Jelly", rough=.08, coat=.6, alpha=.72, emit=.3),
        "clear": material("Capsule_Clear", rough=.05, coat=1.0, alpha=.34),
        "gold": material("Charm_Gold", rough=.25, coat=.5),
    }

    # ---- geometry helpers
    def lathe(bm, profile, colour, segs=SEGS, matrix=None, warp=None, smooth=True):
        """Revolve (radius, height) points round Z. colour: rgb, or fn(vertex, face_centre)."""
        matrix = matrix or Matrix.Identity(4)
        rings = []
        for r, z in profile:
            if r <= 1e-6:
                rings.append([Vector((0, 0, z))])
            else:
                rings.append([Vector((r * math.sin(2 * math.pi * i / segs), -r * math.cos(2 * math.pi * i / segs), z))
                              for i in range(segs)])
        verts = []
        for ring in rings:
            row = []
            for co in ring:
                if warp:
                    co = warp(co)
                row.append(bm.verts.new(matrix @ co))
            verts.append(row)
        faces = []
        for a, b in zip(verts, verts[1:]):
            for i in range(segs):
                j = (i + 1) % segs
                if len(a) == 1 and len(b) == 1:
                    continue
                if len(a) == 1:
                    loop = (a[0], b[j], b[i])
                elif len(b) == 1:
                    loop = (a[i], a[j], b[0])
                else:
                    loop = (a[i], a[j], b[j], b[i])
                faces.append(bm.faces.new(loop))
        paint(bm, faces, colour, smooth)
        return faces

    def paint(bm, faces, colour, smooth=True):
        layer = bm.loops.layers.float_color.get("Col") or bm.loops.layers.float_color.new("Col")
        for face in faces:
            face.smooth = smooth
            centre = face.calc_center_median()
            for loop in face.loops:
                rgb = colour(loop.vert.co, centre) if callable(colour) else colour
                loop[layer] = (*lin(rgb), 1)

    def ball(bm, radius, colour, centre=(0, 0, 0), scale=(1, 1, 1), segs=6, bands=4, rot=None):
        profile = [(radius * math.sin(math.pi * k / bands), -radius * math.cos(math.pi * k / bands)) for k in range(bands + 1)]
        matrix = Matrix.Translation(centre) @ (rot or Matrix.Identity(4)) @ Matrix.Diagonal((*scale, 1))
        return lathe(bm, profile, colour, segs, matrix)

    def spindle(bm, radius, length, colour, matrix, segs=6, belly=.42, flat=1.0):
        """A petal / leaf / lemon: pointed both ends, widest at `belly` of its length."""
        profile = [(0, 0), (radius * .72, length * belly * .5), (radius, length * belly),
                   (radius * .62, length * (belly + (1 - belly) * .6)), (0, length)]
        return lathe(bm, profile, colour, segs, matrix @ Matrix.Diagonal((1, flat, 1, 1)))

    def shine(bm, profile, azimuth, z0, z1, width, lift=.012, warp=None):
        """The one white highlight: a round-ended dash lying on the surface, plus a dot."""
        def strip(za, zb, w):
            rows = []
            steps = 4
            for k in range(steps + 1):
                t = k / steps
                z = za + (zb - za) * t
                half = math.radians(w) * (.35 if k in (0, steps) else 1)
                row = []
                for a in (azimuth - half, azimuth + half):
                    r = pot_radius(z, profile) + lift
                    co = Vector((r * math.sin(a), -r * math.cos(a), z))
                    row.append(bm.verts.new(warp(co) if warp else co))
                rows.append(row)
            faces = [bm.faces.new((a[0], a[1], b[1], b[0])) for a, b in zip(rows, rows[1:])]
            paint(bm, faces, (1, 1, 1), smooth=True)
        azimuth = math.radians(azimuth)
        strip(z0, z1, width)
        strip(z1 + .05, z1 + .10, width * .8)

    def finish(name, parent, bm, mat):
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(mat)
        obj = bpy.data.objects.new(name, mesh)
        scene.collection.objects.link(obj)
        obj.parent = parent
        return obj

    def tris(obj):
        return sum(len(p.vertices) - 2 for p in obj.data.polygons)

    # ---- toppers (each sits on the lid at height `h`)
    def topper(bm, item, colour, h):
        up = Matrix.Translation((0, 0, h)) @ Matrix.Scale(TOPPER_SCALE, 4)
        k = TOPPER_SCALE  # balls are placed by point, so their radius is scaled here
        if item == "rose":  # five round petals and a cream heart, facing the camera
            tilt = Matrix.Rotation(math.radians(-14), 4, "X")
            centre = Vector((0, 0, .19))
            for i in range(5):
                a = math.radians(90 + 72 * i)
                p = up @ tilt @ (centre + Vector((.125 * math.cos(a), 0, .125 * math.sin(a))))
                ball(bm, .098 * k, mix(colour, (1, 1, 1), .12), p, scale=(1, .8, 1))
            ball(bm, .075 * k, hex_rgb(GOLD), up @ tilt @ (centre + Vector((0, -.06, 0))), scale=(1, .8, 1))
        elif item == "tide":  # one fat droplet
            profile = [(0, 0), (.10, .015), (.165, .10), (.15, .20), (.085, .30), (.03, .37), (0, .40)]
            lathe(bm, profile, lambda co, c: mix(colour, (1, 1, 1), .10 + .35 * max(0, co.z - h - .2)), 8, up)
        elif item == "citrus":  # a lemon lying down with one leaf
            lemon = up @ Matrix.Translation((-.19, 0, .15)) @ Matrix.Rotation(math.radians(78), 4, "Y")
            spindle(bm, .155, .40, mix(colour, (1, 1, 1), .08), lemon, segs=8, belly=.5)
            leaf = up @ Matrix.Translation((.05, 0, .22)) @ Matrix.Rotation(math.radians(38), 4, "Y")
            spindle(bm, .075, .22, hex_rgb(LEAF), leaf, segs=6, flat=.45)
        elif item == "iris":  # three pointed petals, fanned
            for angle, length in ((0, .40), (48, .30), (-48, .30)):
                m = up @ Matrix.Rotation(math.radians(angle), 4, "Y")
                spindle(bm, .095, length, mix(colour, (1, 1, 1), .14), m, segs=6, flat=.7)
            ball(bm, .055 * k, hex_rgb(GOLD), up @ Vector((0, -.06, .07)))
        elif item == "reset":  # a ring: "back to the original"
            R, r = .13, .045
            faces, rows = [], []
            for i in range(10):
                a = 2 * math.pi * i / 10
                row = []
                for j in range(5):
                    b = 2 * math.pi * j / 5
                    row.append(bm.verts.new(up @ Vector(((R + r * math.cos(b)) * math.cos(a), r * math.sin(b),
                                                         .17 + (R + r * math.cos(b)) * math.sin(a)))))
                rows.append(row)
            for i in range(10):
                a, b = rows[i], rows[(i + 1) % 10]
                for j in range(5):
                    k = (j + 1) % 5
                    faces.append(bm.faces.new((a[j], a[k], b[k], b[j])))
            paint(bm, faces, hex_rgb(CREAM))
        elif item == "gloss":  # a four-point sparkle, kept faceted on purpose, and a small one
            for cx, cz, R in ((0, .25, .25), (.22, .46, .10)):
                ring = []
                for i in range(8):
                    a = math.pi / 2 + i * math.pi / 4
                    rad = R if i % 2 == 0 else R * .34
                    ring.append(bm.verts.new(up @ Vector((cx + rad * math.cos(a), 0, cz + rad * math.sin(a)))))
                front = bm.verts.new(up @ Vector((cx, -R * .32, cz)))
                back = bm.verts.new(up @ Vector((cx, R * .32, cz)))
                faces = []
                for i in range(8):
                    faces.append(bm.faces.new((ring[i], ring[(i + 1) % 8], front)))
                    faces.append(bm.faces.new((ring[(i + 1) % 8], ring[i], back)))
                paint(bm, faces, hex_rgb("#FFE56B"), smooth=False)
        elif item == "matte":  # a chalky powder puff: three soft lumps
            pale = mix(colour, (1, 1, 1), .55)
            ball(bm, .17 * k, pale, up @ Vector((0, 0, .15)), segs=8)
            ball(bm, .12 * k, pale, up @ Vector((-.15, 0, .10)), segs=6)
            ball(bm, .11 * k, pale, up @ Vector((.15, 0, .09)), segs=6)

    # ---- one item
    def make(index, item, label, kind, hex_colour):
        colour = hex_rgb(hex_colour)
        x = (index - (len(ITEMS) - 1) / 2) * SPACING
        root = bpy.data.objects.new("Jar_" + item, None)
        root.empty_display_size = .2
        root.location = (x, 0, 0)
        root["ItemId"], root["Label"], root["Kind"] = item, label, kind
        scene.collection.objects.link(root)
        parts = []

        if kind == "hue":
            if item == "reset":
                colour = mix(colour, (.36, .80, .88), .6)
            deep = mix(colour, (.10, .05, .25), .22)
            glass = mix(colour, (1, 1, 1), .72)

            def body_colour(co, centre):
                if centre.z > FILL:
                    return glass
                return mix(deep, mix(colour, (1, 1, 1), .10), min(1, co.z / FILL))

            bm = bmesh.new()
            lathe(bm, POT, body_colour)
            parts.append(finish(f"Jar_{item}__Body", root, bm, M["jar"]))
            bm = bmesh.new()
            lathe(bm, LID, hex_rgb(CREAM))
            parts.append(finish(f"Jar_{item}__Lid", root, bm, M["lid"]))
            bm = bmesh.new()
            topper(bm, item, colour, LID_TOP - .02)
            parts.append(finish(f"Jar_{item}__Topper", root, bm, M["jar"]))
            bm = bmesh.new()
            shine(bm, POT, -38, .18, .40, 7)
            parts.append(finish(f"Jar_{item}__Shine", root, bm, M["shine"]))

        elif kind == "finish" and item != "jelly":
            mat = M[item]
            base = colour if item == "gloss" else mix(colour, (1, 1, 1), .38)
            deep = mix(base, (.05, .20, .30), .22 if item == "gloss" else .10)
            bm = bmesh.new()
            lathe(bm, POT, lambda co, c: mix(deep, base, min(1, co.z / .6)))
            lathe(bm, LID, mix(base, (1, 1, 1), .18))
            parts.append(finish(f"Jar_{item}__Body", root, bm, mat))
            bm = bmesh.new()
            topper(bm, item, colour, LID_TOP - .02)
            parts.append(finish(f"Jar_{item}__Topper", root, bm, M["shine"] if item == "gloss" else mat))
            if item == "gloss":  # the big crisp highlight is the whole point
                bm = bmesh.new()
                shine(bm, POT, -36, .16, .46, 15)
                shine(bm, LID, -36, .82, .86, 12, lift=.01)
                parts.append(finish(f"Jar_{item}__Shine", root, bm, M["shine"]))

        elif item == "jelly":
            def wobble(co):  # three soft lobes, and the whole thing leans
                a = math.atan2(co.x, -co.y)
                k = 1 + .075 * math.sin(3 * a + co.z * 5)
                return Vector((co.x * k + .16 * co.z * co.z, co.y * k, co.z * .96))

            jelly_pot = [(0, 0), (.33, 0), (.48, .06), (.56, .22), (.55, .42), (.47, .60), (.40, .72), (.34, .86), (.22, .96), (0, 1.0)]
            pale = mix(colour, (1, 1, 1), .25)
            bm = bmesh.new()
            lathe(bm, jelly_pot, lambda co, c: mix(mix(colour, (.0, .45, .5), .12), mix(colour, (1, 1, 1), .4), min(1, co.z)), warp=wobble)
            parts.append(finish(f"Jar_{item}__Body", root, bm, M["jelly"]))
            bm = bmesh.new()  # bubbles and a darker heart, seen through the jelly
            ball(bm, .20, mix(colour, (.0, .30, .42), .4), (.05, .0, .32), scale=(1.15, 1, .85))
            for cx, cz, r in ((-.20, .52, .07), (.20, .40, .05), (.04, .70, .055), (-.12, .22, .04)):
                ball(bm, r, (1, 1, 1), (cx, -.18, cz))
            parts.append(finish(f"Jar_{item}__Core", root, bm, M["jar"]))
            bm = bmesh.new()  # the lid is sliding off
            slide = (Matrix.Translation((.27, 0, 1.0)) @ Matrix.Rotation(math.radians(24), 4, "Y")
                     @ Matrix.Translation((0, 0, -.90)) @ Matrix.Diagonal((.85, .85, .85, 1)))
            lathe(bm, LID, hex_rgb(CREAM), matrix=slide)
            parts.append(finish(f"Jar_{item}__Lid", root, bm, M["lid"]))
            bm = bmesh.new()
            shine(bm, jelly_pot, -40, .22, .44, 10, lift=.02, warp=wobble)
            parts.append(finish(f"Jar_{item}__Shine", root, bm, M["shine"]))

        else:  # charm capsule
            R, cz = .50, .52
            lower = [(R * math.sin(math.pi * k / 8), cz - R * math.cos(math.pi * k / 8)) for k in range(0, 5)]
            upper = [(R * math.sin(math.pi * k / 8), cz - R * math.cos(math.pi * k / 8)) for k in range(4, 9)]
            deep = mix(colour, (.2, .1, .5), .25)
            bm = bmesh.new()
            lathe(bm, lower, lambda co, c: mix(deep, colour, min(1, co.z / cz)))
            band = [(R, cz - .045), (R + .045, cz - .03), (R + .045, cz + .03), (R, cz + .045)]
            lathe(bm, band, hex_rgb(CREAM))
            parts.append(finish(f"Jar_{item}__Base", root, bm, M["jar"]))
            bm = bmesh.new()
            lathe(bm, upper, mix(colour, (1, 1, 1), .55))
            parts.append(finish(f"Jar_{item}__Dome", root, bm, M["clear"]))
            bm = bmesh.new()  # the prize: a fat five-point star, standing in the capsule
            ring = []
            for i in range(10):
                a = math.pi / 2 + i * math.pi / 5
                rad = .27 if i % 2 == 0 else .135
                ring.append(bm.verts.new(Vector((rad * math.cos(a), 0, cz + .14 + rad * math.sin(a)))))
            front = bm.verts.new(Vector((0, -.10, cz + .14)))
            back = bm.verts.new(Vector((0, .10, cz + .14)))
            faces = []
            for i in range(10):
                faces.append(bm.faces.new((ring[i], ring[(i + 1) % 10], front)))
                faces.append(bm.faces.new((ring[(i + 1) % 10], ring[i], back)))
            paint(bm, faces, hex_rgb(GOLD), smooth=False)
            parts.append(finish(f"Jar_{item}__Charm", root, bm, M["gold"]))
            bm = bmesh.new()  # hanging loop on top
            rows, faces = [], []
            for i in range(8):
                a = 2 * math.pi * i / 8
                rows.append([bm.verts.new(Vector(((.09 + .032 * math.cos(2 * math.pi * j / 4)) * math.cos(a),
                                                  .032 * math.sin(2 * math.pi * j / 4),
                                                  cz + R + .06 + (.09 + .032 * math.cos(2 * math.pi * j / 4)) * math.sin(a))))
                             for j in range(4)])
            for i in range(8):
                a, b = rows[i], rows[(i + 1) % 8]
                for j in range(4):
                    faces.append(bm.faces.new((a[j], a[(j + 1) % 4], b[(j + 1) % 4], b[j])))
            paint(bm, faces, hex_rgb(CREAM))
            parts.append(finish(f"Jar_{item}__Loop", root, bm, M["lid"]))
            bm = bmesh.new()
            ball_profile = [(R * math.sin(math.pi * k / 16), cz - R * math.cos(math.pi * k / 16)) for k in range(17)]
            shine(bm, ball_profile, -40, .66, .82, 11, lift=.012)
            parts.append(finish(f"Jar_{item}__Shine", root, bm, M["shine"]))

        count = sum(tris(p) for p in parts)
        root["Triangles"] = count
        return {"id": item, "label": label, "kind": kind, "colour": hex_colour, "triangles": count,
                "parts": {p.name: tris(p) for p in parts}, "x": x}

    manifest = [make(i, *item) for i, item in enumerate(ITEMS)]

    # ---- light, camera, render settings
    world = bpy.data.worlds.new("JarWorld")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (*lin(hex_rgb("#DDF3E4")), 1)
    bg.inputs[1].default_value = .42
    scene.world = world

    def sun(name, strength, rot, angle=25, shadow=True, colour=(1, 1, 1)):
        data = bpy.data.lights.new(name, "SUN")
        data.energy, data.angle, data.color = strength, math.radians(angle), colour
        data.use_shadow = shadow
        obj = bpy.data.objects.new(name, data)
        obj.rotation_euler = [math.radians(v) for v in rot]
        scene.collection.objects.link(obj)

    sun("Key", 2.1, (48, 0, -38))
    sun("Fill", .35, (70, 0, 60), shadow=False, colour=(.9, .95, 1))
    sun("Rim", .5, (-60, 0, 170), shadow=False, colour=(1, .95, .85))

    ground_mesh = bpy.data.meshes.new("Ground")
    half = SPACING * len(ITEMS) * 2
    ground_mesh.from_pydata([(-half, -60, 0), (half, -60, 0), (half, 60, 0), (-half, 60, 0)], [], [(0, 1, 2, 3)])
    attr = ground_mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    for d in attr.data:
        d.color = (*lin(hex_rgb("#CDEBD3")), 1)
    ground_mesh.materials.append(material("Ground", rough=1, spec=0))
    ground = bpy.data.objects.new("Ground", ground_mesh)
    scene.collection.objects.link(ground)

    cam_data = bpy.data.cameras.new("JarCam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("JarCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    elevation = math.radians(16)
    direction = Vector((0, -math.cos(elevation), math.sin(elevation)))

    def aim(target, scale):
        cam.location = Vector(target) + direction * 12
        cam.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
        cam_data.ortho_scale = scale

    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    if hasattr(scene.eevee, "taa_render_samples"):
        scene.eevee.taa_render_samples = 64
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"

    # the saved file opens on the lineup
    aim((0, 0, .80), SPACING * len(ITEMS) + .4)
    scene.render.resolution_x, scene.render.resolution_y = 2160, 560
    scene.render.film_transparent = False

    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    with open(MANIFEST, "w", encoding="utf-8") as handle:
        json.dump({"source": "scripts/build_customization_jars.py", "note": "No mesh ids yet: renders first.",
                   "items": manifest}, handle, indent=1)
        handle.write("\n")
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    for row in manifest:
        print("TRIS", row["id"], row["triangles"])

    if "--no-render" in sys.argv:
        return
    scene.render.filepath = os.path.join(OUT, "lineup.png")
    bpy.ops.render.render(write_still=True)

    # each item alone, transparent, square
    ground.hide_render = True
    scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = 512
    roots = [o for o in scene.objects if o.name.startswith("Jar_") and o.parent is None]
    for row in manifest:
        for r in roots:
            hidden = r.name != "Jar_" + row["id"]
            for child in r.children:
                child.hide_render = hidden
        aim((row["x"] + (.06 if row["id"] == "jelly" else 0), 0, .82 if row["kind"] != "charm" else .62), 1.9)
        scene.render.filepath = os.path.join(OUT, row["id"] + ".png")
        bpy.ops.render.render(write_still=True)
    print("RENDERED", OUT)


# --------------------------------------------------------------------------- Pillow sheets
def sheets():
    from PIL import Image, ImageDraw, ImageFont

    def font(size):
        try:
            return ImageFont.truetype("arialbd.ttf", size)
        except OSError:
            return ImageFont.load_default()

    card, light, ink, pale = (22, 38, 42, 255), (240, 246, 238, 255), (20, 40, 48, 255), (226, 240, 236, 255)
    art = {item: Image.open(os.path.join(OUT, item + ".png")).convert("RGBA") for item, *_ in ITEMS}

    def at(item, size):
        return art[item].resize((size, size), Image.LANCZOS)

    # ---- icon sheet: real phone sizes, on the dark card and on a light page
    cell, pad, left = 96, 20, 150
    rows = [("64 px, dark card", 64, card, 1), ("64 px, light", 64, light, 1), ("32 px, dark card", 32, card, 1),
            ("64 px shown at 2x", 64, card, 2)]
    width = left + cell * 2 * len(ITEMS) // 2 + pad
    width = left + len(ITEMS) * 140 + pad
    height = pad + 30 + sum(max(cell, size * zoom + 32) for _, size, _, zoom in rows) + pad
    sheet = Image.new("RGBA", (width, height), (12, 30, 34, 255))
    draw = ImageDraw.Draw(sheet)
    for i, (item, label, *_rest) in enumerate(ITEMS):
        draw.text((left + i * 140 + 70, pad + 8), label, font=font(14), fill=pale, anchor="mm")
    y = pad + 30
    for label, size, bg, zoom in rows:
        h = max(cell, size * zoom + 32)
        draw.text((pad, y + h // 2), label, font=font(13), fill=pale, anchor="lm")
        for i, (item, *_rest) in enumerate(ITEMS):
            shown = size * zoom
            tile = Image.new("RGBA", (shown + 20, shown + 20), bg)
            icon = at(item, size)
            if zoom > 1:
                icon = icon.resize((shown, shown), Image.NEAREST)
            tile.alpha_composite(icon, (10, 10))
            sheet.paste(tile, (left + i * 140 + 70 - tile.width // 2, y + (h - tile.height) // 2))
        y += h
    sheet.save(os.path.join(OUT, "icon-sheet-64px.png"))
    for item in art:  # the loose 64 px icons too
        os.makedirs(os.path.join(OUT, "icons-64"), exist_ok=True)
        at(item, 64).save(os.path.join(OUT, "icons-64", item + ".png"))

    # ---- before / after: the v775 jars as captured in-game, against the new ones, same size
    hues = Image.open(BEFORE_HUES).convert("RGBA")
    fin = Image.open(BEFORE_FINISH).convert("RGBA")
    before = {
        "rose": hues.crop((167, 82, 311, 226)), "tide": hues.crop((647, 82, 791, 226)),
        "citrus": hues.crop((167, 397, 311, 541)), "iris": hues.crop((647, 397, 791, 541)),
        "gloss": fin.crop((647, 394, 791, 538)), "matte": fin.crop((1127, 394, 1271, 538)),
    }
    order = ["rose", "tide", "citrus", "iris", "gloss", "matte", "jelly", "charm"]
    names = {item: label for item, label, *_ in ITEMS}
    tile, gap, left, top = 144, 16, 120, 56
    width = left + len(order) * (tile + gap) + gap
    cmp_img = Image.new("RGBA", (width, top + 2 * (tile + gap) + 110), (12, 30, 34, 255))
    draw = ImageDraw.Draw(cmp_img)
    draw.text((gap, 14), "Customization Egg items: before (v775, in game) and after (new models, Blender render)",
              font=font(16), fill=pale)
    for r, label in enumerate(("Before", "After")):
        draw.text((gap, top + r * (tile + gap) + tile // 2), label, font=font(18), fill=pale, anchor="lm")
    for i, item in enumerate(order):
        x = left + i * (tile + gap)
        if item in before:
            cmp_img.paste(before[item], (x, top))
        else:
            ImageDraw.Draw(cmp_img).rounded_rectangle([x, top, x + tile, top + tile], 10, outline=(70, 96, 100, 255))
            draw.text((x + tile // 2, top + tile // 2), "no art yet", font=font(13), fill=(130, 160, 160, 255), anchor="mm")
        after = Image.new("RGBA", (tile, tile), (22, 43, 44, 255))
        after.alpha_composite(at(item, tile))
        cmp_img.paste(after, (x, top + tile + gap))
        draw.text((x + tile // 2, top + 2 * (tile + gap) + 4), names[item], font=font(14), fill=pale, anchor="ma")
        y = top + 2 * (tile + gap) + 34  # and how each survives at 64 px
        for source, dx in ((before.get(item), 4), (at(item, 64), 76)):
            if source is None:
                continue
            small = Image.new("RGBA", (64, 64), (22, 43, 44, 255))
            small.alpha_composite(source.resize((64, 64), Image.LANCZOS))
            cmp_img.paste(small, (x + dx, y))
    draw.text((gap, top + 2 * (tile + gap) + 66), "at 64 px", font=font(13), fill=pale, anchor="lm")
    draw.text((gap, top + 2 * (tile + gap) + 84), "old | new", font=font(11), fill=(150, 180, 180, 255), anchor="lm")
    cmp_img.save(os.path.join(OUT, "before-after.png"))
    print("SHEETS", OUT)


if __name__ == "__main__":
    if "sheets" in sys.argv:
        sheets()
    else:
        build()
