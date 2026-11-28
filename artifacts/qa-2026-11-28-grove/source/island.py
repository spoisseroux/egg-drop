import bpy,os,math
from mathutils import Vector
REPO=r"C:/Users/skunk/Documents/Development/egg-drop"
TEX=REPO+"/assets/world/textures/grounded/"
FLAT={"cloud":(.6,.72,.85),"foam":(1,1,1),"glow_warm":(1,.75,.25),"glow_aqua":(.1,.8,1),"glow_pink":(.55,.9,.15),"water":(.1,.55,.6),
 "water_pool":(.08,.55,.58),"water_stream":(.1,.6,.65),"waterfall_sky":(.75,.93,1),"waterfall_tumble":(.75,.93,1),"bubble":(.8,.93,1),"far_peak":(.6,.75,.9)}
def bsdf(m):return next(n for n in m.node_tree.nodes if n.type=="BSDF_PRINCIPLED")
def load_island(keep_backdrop):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=REPO+"/assets/world/world-v7.fbx")
    drop=("W7_Backdrop","W7_DriftRocks","W7_Islets","W7_Underside")
    for o in list(bpy.data.objects):
        if not keep_backdrop and o.name.startswith(drop):bpy.data.objects.remove(o)
    for m in bpy.data.materials:
        m.use_nodes=True;k=m.name.replace("W1_","").split(".")[0];b=bsdf(m);nt=m.node_tree
        f=TEX+"W1_"+k+".png"
        b.inputs["Roughness"].default_value=.8
        if k=='ground':
            continue
        if k in FLAT:
            c=FLAT[k];b.inputs["Base Color"].default_value=(*c,1)
            if k.startswith(("glow","waterfall","foam")):
                b.inputs["Emission Color"].default_value=(*c,1);b.inputs["Emission Strength"].default_value=2.0 if k.startswith("glow") else .6
            if k.startswith("water"):b.inputs["Roughness"].default_value=.08
            if k=="water_pool" or k=="water_stream":
                b.inputs["Emission Color"].default_value=(.1,.8,.8,1);b.inputs["Emission Strength"].default_value=.25
        elif os.path.exists(f) or k=="palette":
            if k=="palette":f=REPO+"/assets/world/textures/aero/palette-aero.png"
            t=nt.nodes.new("ShaderNodeTexImage");t.image=bpy.data.images.load(f)
            if k=="palette":t.interpolation="Closest"
            # Aero lift: the game's Aero tint brightens grass/foliage
            mix=nt.nodes.new("ShaderNodeHueSaturation")
            mix.inputs["Saturation"].default_value=1.15 if k in("grass","meadow","foliage","ground") else 1.0
            mix.inputs["Value"].default_value=1.25 if k in("grass","meadow","foliage","ground","cliff_rock","boulder_rock") else 1.0
            nt.links.new(t.outputs["Color"],mix.inputs["Color"]);nt.links.new(mix.outputs["Color"],b.inputs["Base Color"])
        if k in("marble","marble_smooth","trim"):b.inputs["Roughness"].default_value=.35
