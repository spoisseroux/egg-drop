"""Turntable check for the Customization Egg jars, in the in-game look (QA 2026-11-16c pass 4).

  blender --background assets/art-source/jars/customization-jars.blend --python scripts/render_customization_jars_turntable.py -- OUT_DIR
  python scripts/render_customization_jars_turntable.py strips OUT_DIR    (Pillow: per-jar strips and a contact sheet)

Every part is drawn the way Roblox draws its MeshPart: one flat colour, the game transparency and
material from scripts/build_jar_assets.py (look), back faces culled except DoubleSided parts.
Each jar is turned about its axis to 0, 90, 180 and 270 degrees on the reveal-card teal, since
the reveal screen spins it. The .blend is not saved.
"""
import math
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
DEFAULT_OUT = os.path.join(ROOT, "artifacts", "qa-2026-11-16c-v775", "jars-v2")
ANGLES = (0, 90, 180, 270)
ORDER = ["rose", "tide", "citrus", "iris", "reset", "gloss", "matte", "jelly", "charm"]
DOUBLE_SIDED = {"Liquid", "Core", "Dome"}  # matches src/client/JarModel.lua
CARD = "#4FC9B8"  # the reveal card teal behind the jar
FRAME = {"gloss": (.80, 1.95), "matte": (.70, 1.70), "jelly": (.62, 1.62), "charm": (.62, 1.45)}  # target z, ortho


def out_dir():
    if "--" in sys.argv:
        args = sys.argv[sys.argv.index("--") + 1:]
    else:
        args = sys.argv[sys.argv.index("strips") + 1:] if "strips" in sys.argv else []
    return os.path.abspath(args[0]) if args else DEFAULT_OUT


def render():
    import bpy
    from mathutils import Vector
    sys.path.insert(0, os.path.join(ROOT, "scripts"))
    from build_jar_assets import look

    def lin(hex_colour):
        h = hex_colour.lstrip("#")
        c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
        return tuple(x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4 for x in c)

    def mean(obj):
        attr = obj.data.color_attributes.get("Col")
        total = [0.0, 0.0, 0.0]
        for entry in attr.data:
            for i in range(3):
                total[i] += entry.color[i]
        srgb = [(12.92 * t if t <= .0031308 else 1.055 * t ** (1 / 2.4) - .055) for t in (v / len(attr.data) for v in total)]
        return "#%02X%02X%02X" % tuple(max(0, min(255, round(c * 255))) for c in srgb)

    def game_material(name, colour, transparency, material, reflectance, double_sided):
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
        out = next(n for n in nodes if n.type == "OUTPUT_MATERIAL")
        bsdf.inputs["Base Color"].default_value = (*lin(colour), 1)
        bsdf.inputs["Roughness"].default_value = .9 if material == "Sand" else .35
        bsdf.inputs["Alpha"].default_value = 1 - transparency
        if "Coat Weight" in bsdf.inputs:
            bsdf.inputs["Coat Weight"].default_value = min(1, reflectance * 2)
        if material == "Neon" and "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (*lin(colour), 1)
            bsdf.inputs["Emission Strength"].default_value = 1.5
        if not double_sided:  # Roblox culls back faces
            geo = nodes.new("ShaderNodeNewGeometry")
            clear = nodes.new("ShaderNodeBsdfTransparent")
            mix = nodes.new("ShaderNodeMixShader")
            links.new(geo.outputs["Backfacing"], mix.inputs[0])
            links.new(bsdf.outputs[0], mix.inputs[1])
            links.new(clear.outputs[0], mix.inputs[2])
            links.new(mix.outputs[0], out.inputs["Surface"])
        return mat

    scene = bpy.context.scene
    roots = {o["ItemId"]: o for o in scene.objects if o.name.startswith("Jar_") and o.parent is None and "ItemId" in o}
    for item, root in roots.items():
        for child in root.children:
            part = child.name.split("__", 1)[1]
            colour, transparency, material, reflectance = look(item, part, mean(child))
            child.data.materials.clear()
            child.data.materials.append(game_material("Game_" + child.name, colour, transparency, material,
                                                      reflectance, part in DOUBLE_SIDED))
    for name in ("Ground",):
        if name in scene.objects:
            scene.objects[name].hide_render = True

    # teal card behind the jar, but neutral grey light on it (the card does not light the jar)
    wnodes, wlinks = scene.world.node_tree.nodes, scene.world.node_tree.links
    bg = next(n for n in wnodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (.55, .55, .58, 1)
    bg.inputs[1].default_value = .8
    card = wnodes.new("ShaderNodeBackground")
    card.inputs[0].default_value = (*lin(CARD), 1)
    path = wnodes.new("ShaderNodeLightPath")
    pick = wnodes.new("ShaderNodeMixShader")
    wout = next(n for n in wnodes if n.type == "OUTPUT_WORLD")
    wlinks.new(path.outputs["Is Camera Ray"], pick.inputs[0])
    wlinks.new(bg.outputs[0], pick.inputs[1])
    wlinks.new(card.outputs[0], pick.inputs[2])
    wlinks.new(pick.outputs[0], wout.inputs["Surface"])
    try:
        scene.render.engine = "CYCLES"
    except TypeError:
        pass
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.film_transparent = False
    scene.render.resolution_x = scene.render.resolution_y = 420
    cam = scene.camera
    cam.data.type = "ORTHO"
    elevation = math.radians(14)
    direction = Vector((0, -math.cos(elevation), math.sin(elevation)))
    out = out_dir()
    os.makedirs(os.path.join(out, "frames"), exist_ok=True)
    for item in ORDER:
        root = roots[item]
        for other in roots.values():
            for child in other.children:
                child.hide_render = other is not root
        z, scale = FRAME.get(item, (.50, 1.40))
        target = Vector((root.location.x, 0, z))
        cam.location = target + direction * 12
        cam.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
        cam.data.ortho_scale = scale
        for angle in ANGLES:
            root.rotation_euler = (0, 0, math.radians(angle))
            scene.render.filepath = os.path.join(out, "frames", f"{item}-{angle:03d}.png")
            bpy.ops.render.render(write_still=True)
        root.rotation_euler = (0, 0, 0)
    print("TURNTABLE", out)


def strips():
    from PIL import Image, ImageDraw, ImageFont
    out = out_dir()

    def font(size):
        try:
            return ImageFont.truetype("arialbd.ttf", size)
        except OSError:
            return ImageFont.load_default()

    rows = []
    for item in ORDER:
        frames = [Image.open(os.path.join(out, "frames", f"{item}-{a:03d}.png")).convert("RGB") for a in ANGLES]
        w, h = frames[0].size
        strip = Image.new("RGB", (w * 4, h + 28), (16, 32, 36))
        draw = ImageDraw.Draw(strip)
        for i, (frame, angle) in enumerate(zip(frames, ANGLES)):
            strip.paste(frame, (i * w, 28))
            draw.text((i * w + 8, 6), f"{item}  {angle} deg", font=font(15), fill=(230, 244, 240))
        strip.save(os.path.join(out, f"turntable-{item}.png"))
        rows.append(strip.resize((strip.width // 2, strip.height // 2), Image.LANCZOS))
    sheet = Image.new("RGB", (rows[0].width * 3, rows[0].height * 3), (16, 32, 36))
    for i, row in enumerate(rows):
        sheet.paste(row, ((i % 3) * row.width, (i // 3) * row.height))
    sheet.save(os.path.join(out, "turntable-all.png"))
    print("STRIPS", out)


if __name__ == "__main__":
    if "strips" in sys.argv:
        strips()
    else:
        render()
