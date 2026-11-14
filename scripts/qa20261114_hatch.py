"""Isolated hatch concept frames from copied authored meshes, never production.

Background Blender on pet-bear-attachments.blend. Writes artifact PNG frames only.
"""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
import bpy
import bmesh
from mathutils import Euler, Matrix, Vector

parser=argparse.ArgumentParser()
parser.add_argument("kind",choices=("bear","toy"))
parser.add_argument("--stills",action="store_true")
parser.add_argument("--catalog",action="store_true")
parser.add_argument("--verify-only",action="store_true",help="Recompute exact pose proof without overwriting rendered frames")
parser.add_argument("--tightened",action="store_true",help="Astra v3 tightening; preserve revision-2 outputs")
args=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/"artifacts/qa-2026-11-14-v634/hatch-concept/revision-2"
if args.tightened:OUT=OUT.parent/"revision-3-tightened"
RAW=OUT/(args.kind+"-stills"if args.stills else args.kind)
RAW.mkdir(parents=True,exist_ok=True)
SOURCE=ROOT/"assets/art-source/pets/pet-bear-attachments.blend"
EGGS=ROOT/"assets/art-source/eggs/eggs.blend"
assert Path(bpy.data.filepath).resolve()==SOURCE.resolve(),"Use a separate background Bear source session"
hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()for p in(SOURCE,EGGS)}
scene=bpy.context.scene
for o in scene.objects:o.hide_render=True
base_names=("Body","Head","HandL","HandR","FootL","FootR","EarL","EarR","EarInnerL","EarInnerR","EyeL","EyeR","Mouth","Muzzle","Nose","Tail")
root=bpy.data.objects["PetBear"];inverse=root.matrix_world.inverted()
bear={};rest={}
for name in base_names:
    old=bpy.data.objects["PetBear__"+name]
    assert not any("Wearable"in c.name for c in old.users_collection)
    new=old.copy();new.data=old.data.copy();new.name="QA20261114_Bear_"+name
    new.parent=None;new.matrix_world=inverse@old.matrix_world;new.hide_render=False
    scene.collection.objects.link(new);bear[name]=new;rest[name]=new.matrix_world.copy()
assert len(bear)==16
points=[o.matrix_world@v.co for o in bear.values()for v in o.data.vertices]
H=max(p.z for p in points)-min(p.z for p in points)
assert 1<H<3,("authored Bear height",H)
with bpy.data.libraries.load(str(EGGS),link=False)as(data,loaded):
    loaded.objects=[n for n in data.objects if n in{"Egg__TopShell","Egg__BottomShell","Egg__Core"}]
eggs={}
for ob in loaded.objects:
    if ob:
        ob.name="QA20261114_"+ob.name;ob.parent=None;scene.collection.objects.link(ob);ob.hide_render=False
        eggs[ob.name.removeprefix("QA20261114_")]=ob
top,bottom,core=(eggs[n]for n in("Egg__TopShell","Egg__BottomShell","Egg__Core"))


def rgb(h):
    h=h.lstrip("#");v=[int(h[i:i+2],16)/255 for i in(0,2,4)]
    return tuple(c/12.92 if c<=.04045 else((c+.055)/1.055)**2.4 for c in v)


def material(name,color,rough=.5,emission=0):
    m=bpy.data.materials.new("QA20261114_"+name);m.use_nodes=True
    p=m.node_tree.nodes.get("Principled BSDF");p.inputs["Base Color"].default_value=(*rgb(color),1)
    p.inputs["Roughness"].default_value=rough
    p.inputs["Emission Color"].default_value=(*rgb(color),1);p.inputs["Emission Strength"].default_value=emission
    return m


for ob in(top,bottom):
    ob.data.materials[0]=ob.data.materials[0].copy()
    mat=ob.data.materials[0]
    tex=mat.node_tree.nodes.get("ColorMap")
    assert tex is not None
    tex.image=bpy.data.images.load(str(ROOT/"assets/eggs/textures"/("egg-companion-color.png"if args.kind=="bear"else"egg-toy-color.png")))
core.data.materials.clear();core.data.materials.append(material("Core","#FFE6A0",.45,.7))
# A short growing light leak follows the existing authored zigzag seam at the
# front. It makes the crack beat readable without replacing the shell texture.
sys.path.insert(0,str(ROOT/"scripts"))
import egg_types as E
curve=bpy.data.curves.new("QA20261114_GrowingSeam","CURVE");curve.dimensions="3D";curve.bevel_depth=.009;curve.bevel_resolution=2
spline=curve.splines.new("POLY");spline.points.add(6)
for point,j in zip(spline.points,range(9,16)):
    t=E.SEAM_T+(E.SEAM_AMP_T if j%2==0 else -E.SEAM_AMP_T)
    radius,z=E.profile(t);dx,dy=E.direction(j/E.SEGMENTS)
    point.co=((radius+.007)*dx,(radius+.007)*dy,z,1)
curve.materials.append(material("WarmCrack","#FFE6A0",.45,1.0))
crack=bpy.data.objects.new(curve.name,curve);scene.collection.objects.link(crack)
# Two local copies of the lower shell split across X. Its source mesh/UV remains intact.
halves=[]
for side in(-1,1):
    ob=bottom.copy();ob.data=bottom.data.copy();scene.collection.objects.link(ob);ob.name="QA20261114_LowerHalf"+str(side)
    bm=bmesh.new();bm.from_mesh(ob.data)
    bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=1e-6,plane_co=(0,0,0),plane_no=(1,0,0),clear_inner=side>0 if args.tightened else side<0,clear_outer=side<0 if args.tightened else side>0)
    bm.to_mesh(ob.data);bm.free();ob.data.update();halves.append(ob)
teal=material("Backdrop","#132F31",.8);floor_mat=material("Floor","#254544",.65)
cream=material("CreamPool","#C6B78B",.9);peach=material("PaperPeach","#F0B6A1",.7);paper=material("PaperCream","#FFF0D2",.7)
# A continuous curved cyclorama, no cone or stage cut.
verts=[]
profile=[(-6,0),(1.1,0)]
for i in range(1,17):
    a=(math.pi/2)*i/16;profile.append((1.1+1.6*math.sin(a),1.6-1.6*math.cos(a)))
profile.append((2.7,6))
for x in(-7,7):
    for y,z in profile:verts.append((x,y,z-.015))
faces=[(i,i+1,len(profile)+i+1,len(profile)+i)for i in range(len(profile)-1)]
me=bpy.data.meshes.new("QA20261114_Cyclorama");me.from_pydata(verts,[],faces);me.materials.append(teal)
stage=bpy.data.objects.new(me.name,me);scene.collection.objects.link(stage)
for p in me.polygons:p.use_smooth=True
bpy.ops.mesh.primitive_plane_add(size=14,location=(0,-1,-.006));floor=bpy.context.object;floor.name="QA20261114_Floor";floor.data.materials.append(floor_mat)
# Warm oval pool is a shaded matte disk, not an emissive spotlight graphic.
bpy.ops.mesh.primitive_circle_add(vertices=80,radius=1,fill_type="NGON",location=(0,0,.002))
pool=bpy.context.object;pool.name="QA20261114_LightPool";pool.scale=(1.22,.67,1);pool.data.materials.append(cream)
confetti=[]
for i in range(8):
    bpy.ops.mesh.primitive_plane_add(size=.045,location=(0,0,0))
    ob=bpy.context.object;ob.name="QA20261114_Paper"+str(i);ob.data.materials.append(peach if i%2 else paper);confetti.append(ob)


def ellipsoid(name,size,location,mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=1,location=location)
    ob=bpy.context.object;ob.name="QA20261114_"+name;ob.scale=Vector(size)*.5;ob.data.materials.append(mat)
    for p in ob.data.polygons:p.use_smooth=True
    # matrix_world must include authored primitive dimensions before caching it.
    bpy.context.view_layer.update()
    return ob


toy=[];toy_rest={}
if args.kind=="toy":
    # Exact five-part runtime Wobble Top specification, Roblox Y-up -> Blender Z-up.
    colors={"TealBody":"#3FB7B0","CreamEquator":"#FFF0C9","CoralFoot":"#EF786B","BrassStem":"#C69A45","CitrineKnob":"#F6D759"}
    specs=[("TealBody",(.20,.15,.20),(0,0,0)),("CreamEquator",(.205,.04,.205),(0,.01,0)),
           ("CoralFoot",(.05,.07,.05),(0,-.09,0)),("BrassStem",(.04,.10,.04),(0,.11,0)),("CitrineKnob",(.06,.06,.06),(0,.17,0))]
    for name,size,at in specs:
        ob=ellipsoid(name,(size[0]*5,size[2]*5,size[1]*5),(at[0]*5,-at[2]*5,at[1]*5+.625),material(name,colors[name],.35))
        toy.append(ob);toy_rest[ob]=ob.matrix_world.copy()

for engine in("BLENDER_EEVEE","BLENDER_EEVEE_NEXT"):
    try:scene.render.engine=engine;break
    except TypeError:pass
scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage=470,296,100
scene.render.image_settings.file_format="PNG";scene.render.image_settings.color_mode="RGB";scene.render.film_transparent=False
scene.render.threads_mode="FIXED";scene.render.threads=8
scene.view_settings.view_transform="Standard";scene.view_settings.look="None";scene.view_settings.exposure=0
world=bpy.data.worlds.new("QA20261114_HatchWorld");world.use_nodes=True
world.node_tree.nodes["Background"].inputs[0].default_value=(*rgb("#132F31"),1)
world.node_tree.nodes["Background"].inputs[1].default_value=.28;scene.world=world
for name,loc,power,size,color in[("Key",(-2,-3,4),150,3,(1,.94,.82)),("Fill",(3,-2,2),55,3,(.70,1,.85)),("Rim",(0,2,3),95,2,(.58,1,.83))]:
    data=bpy.data.lights.new("QA20261114_"+name,"AREA");data.energy=power;data.size=size;data.color=color
    ob=bpy.data.objects.new(data.name,data);scene.collection.objects.link(ob);ob.location=loc
    ob.rotation_euler=(Vector((0,0,H*.55))-ob.location).to_track_quat("-Z","Y").to_euler()
camdata=bpy.data.cameras.new("QA20261114_Camera");camdata.angle=math.radians(38)
cam=bpy.data.objects.new(camdata.name,camdata);scene.collection.objects.link(cam);scene.camera=cam
target=Vector((0,0,H*.55));distance=3.6*H
cam.location=target+Vector((0,-distance*math.cos(math.radians(8)),distance*math.sin(math.radians(8))))
cam.rotation_euler=(target-cam.location).to_track_quat("-Z","Y").to_euler()


def smooth(a,b,t):
    u=max(0,min(1,(t-a)/(b-a)));return u*u*(3-2*u)


def pivot(point,rotation):
    return Matrix.Translation(point)@Euler(rotation).to_matrix().to_4x4()@Matrix.Translation(-Vector(point))


# All animation affects copied meshes/materials only. Texture eye whites, pupils
# and catchlights are one complete mesh, squashed about its own geometric center.
def center(ob):
    ps=[rest[ob.name.removeprefix("QA20261114_Bear_")]@v.co for v in ob.data.vertices]
    return sum(ps,Vector())/len(ps)
centers={n:center(o)for n,o in bear.items()}
head_names={"Head","EarL","EarR","EarInnerL","EarInnerR","EyeL","EyeR","Mouth","Muzzle","Nose"}
fade_groups={}
def fade_materials(objects,group):
    controls=[];copies={}
    for ob in objects:
        for i,mat in enumerate(ob.data.materials):
            if mat.name not in copies:
                copy=mat.copy();copy.name="QA20261114_Fade_"+group+"_"+mat.name
                copy.surface_render_method="DITHERED"
                tree=copy.node_tree;output=next(n for n in tree.nodes if n.type=="OUTPUT_MATERIAL")
                socket=output.inputs["Surface"];source=socket.links[0].from_socket
                mix=tree.nodes.new("ShaderNodeMixShader");transparent=tree.nodes.new("ShaderNodeBsdfTransparent")
                tree.links.new(transparent.outputs[0],mix.inputs[1]);tree.links.new(source,mix.inputs[2]);tree.links.new(mix.outputs[0],socket)
                mix.inputs[0].default_value=1;controls.append(mix.inputs[0]);copies[mat.name]=copy
            ob.data.materials[i]=copies[mat.name]
    fade_groups[group]=controls

def alpha(group,value):
    for socket in fade_groups[group]:socket.default_value=value

# Astra's actual-render revision: keep the original smile. The full eye mesh
# changes size modestly for joy; compression is reserved for a short blink.
fade_materials(list(bear.values()),"bear")
fade_materials([top],"cap")
fade_materials([bottom,core]+halves,"shell")
if toy:fade_materials(toy,"toy")
contact=None
if toy:
    bpy.ops.mesh.primitive_plane_add(size=1,location=(0,0,.00205))
    contact=bpy.context.object;contact.name="QA20261114_ToyContactShadow";contact.scale=(.22,.16,1)
    mat=bpy.data.materials.new(contact.name);mat.use_nodes=True;mat.surface_render_method="DITHERED"
    tree=mat.node_tree;tree.nodes.clear()
    output=tree.nodes.new("ShaderNodeOutputMaterial");mix=tree.nodes.new("ShaderNodeMixShader")
    transparent=tree.nodes.new("ShaderNodeBsdfTransparent");diffuse=tree.nodes.new("ShaderNodeBsdfDiffuse")
    diffuse.inputs["Color"].default_value=(*rgb("#354134"),1)
    uv=tree.nodes.new("ShaderNodeTexCoord");subtract=tree.nodes.new("ShaderNodeVectorMath");subtract.operation="SUBTRACT";subtract.inputs[1].default_value=(.5,.5,0)
    length=tree.nodes.new("ShaderNodeVectorMath");length.operation="LENGTH"
    falloff=tree.nodes.new("ShaderNodeMapRange");falloff.clamp=True;falloff.interpolation_type="SMOOTHERSTEP"
    falloff.inputs["From Min"].default_value=0;falloff.inputs["From Max"].default_value=.5
    falloff.inputs["To Min"].default_value=.33;falloff.inputs["To Max"].default_value=0
    tree.links.new(uv.outputs["UV"],subtract.inputs[0]);tree.links.new(subtract.outputs[0],length.inputs[0]);tree.links.new(length.outputs["Value"],falloff.inputs["Value"])
    tree.links.new(falloff.outputs[0],mix.inputs[0]);tree.links.new(transparent.outputs[0],mix.inputs[1]);tree.links.new(diffuse.outputs[0],mix.inputs[2]);tree.links.new(mix.outputs[0],output.inputs[0]);contact.data.materials.append(mat)
metrics=[]

def mesh_min(objects):return min((ob.matrix_world@v.co).z for ob in objects for v in ob.data.vertices)

def anchor(objects,hop=0,clearance=None):
    before=mesh_min(objects);target=.002+(.005*H if clearance is None else clearance)+hop
    correction=Matrix.Translation((0,0,target-before))
    for ob in objects:ob.matrix_world=correction@ob.matrix_world
    return mesh_min(objects),target

def pulse(t,start,end):return math.sin(math.pi*(t-start)/(end-start))if start<t<end else 0

def pose(t):
    actual_t=t
    if args.tightened:
        # Re-time the accepted rigid expressions/gestures, with a generic new
        # forward entrance and rearward same-side shell clearance below.
        pairs=[(0,0),(.65,.65),(.95,1.25),(1.10,1.55),(1.48,2.05),(1.85,2.35),(2.35,2.95),(2.95,3.75),(4.4,6)]
        if args.kind=="toy":pairs=[(0,0),(.65,.65),(.95,1.25),(1.10,1.60),(1.48,2.05),(2.2,2.95),(3.1,4)]
        for (a,c),(b,d)in zip(pairs,pairs[1:]):
            if a<=t<=b:t=c+(d-c)*(t-a)/(b-a);break
    rock=math.radians(-5)*pulse(t,.12,.31)+math.radians(8)*pulse(t,.34,.62)+math.radians(10)*pulse(t,.76,1.22)
    egg=pivot((0,0,0),(rock*.25,rock,rock*.45))
    opening=smooth(1.25,1.55,t)
    shell_fade=1-smooth(2.0,2.30,t);alpha("shell",shell_fade);alpha("cap",shell_fade)
    crack.matrix_world=egg;crack.hide_render=t<.65 or t>=1.25
    curve.bevel_factor_end=max(.001,smooth(.65,1.2,t))
    top.matrix_world=Matrix.Translation((opening*1.05,opening*.45,opening*.85))@pivot((0,0,.73),(opening*.4,opening*.7,0))@egg
    top.hide_render=t>=2.30
    bottom.matrix_world=egg;bottom.hide_render=opening>.001
    core.hide_render=t<.78 or t>=1.25
    for i,ob in enumerate(halves):
        side=-1 if i==0 else 1;ob.hide_render=opening<=.001 or t>=2.30
        ob.matrix_world=Matrix.Translation((side*opening*.90,opening*.25,.03))@pivot((0,0,0),(0,side*opening*.65,side*opening*.15))@egg
    if t>=1.55:assert core.hide_render and bottom.hide_render
    if t>=2.30:assert top.hide_render and all(ob.hide_render for ob in halves)
    # Contact anchored scale/fade; there is no translation up from below ground.
    appear=smooth(1.55,1.82,t)
    size=.72+((.31 if args.tightened else .32)*smooth(1.55,1.83,t))-(.03 if args.tightened else .04)*smooth(1.83,2.05,t)
    crouch=.08*pulse(t,2.35,2.47)
    hop=.11*H*pulse(t,2.47,2.88)
    stretch=.04*pulse(t,2.47,2.88)-.06*pulse(t,2.88,3.02)-crouch
    expression="curious"if t<2.35 else"joy"if t<3.30 else"pleased"if t<4.65 else"neutral"
    eye={"curious":1.16,"joy":.95,"pleased":.90,"neutral":1}[expression]
    blink=1
    for at in((1.57,3.80)if args.tightened else(1.875,4.93)):
        age=(actual_t if args.tightened else t)-at
        if 0<=age<.15:
            blink=.06+.94*(1-smooth(0,.055,age))if age<.055 else .06 if age<.09 else .06+.94*smooth(.09,.15,age)
    tilt=math.radians(8)*smooth(2.05,2.30,t)*(1-smooth(3.75,4.7,t))
    wave=(pulse(t,2.99,3.23)+pulse(t,3.31,3.55))
    tilt-=math.radians(4)*wave
    head=pivot(centers["Head"],(0,tilt,math.radians(7)*(1-smooth(1.55,2.10,t))))
    root_pose=Matrix.Diagonal((size*(1-stretch*.35),size*(1-stretch*.35),size*(1+stretch),1))
    alpha("bear",appear)
    for name,ob in bear.items():
        ob.hide_render=args.kind!="bear"or t<1.55
        part=Matrix.Identity(4)
        if name.startswith("Eye"):
            c=centers[name];part=Matrix.Translation(c)@Matrix.Diagonal((1,1,max(.035,eye*blink),1))@Matrix.Translation(-c)
        if name in{"EarL","EarR","EarInnerL","EarInnerR"}:
            part=pivot(centers[name],(0,math.radians(10)*(1 if"L"in name else -1)*(1 if expression in{"curious","joy"}else 0),0))@part
        if name in head_names:part=head@part
        if name=="HandR":part=pivot(centers[name]+Vector((0,0,.10*H)),(.12,-.24-.95*wave,0))
        elif name=="HandL":part=pivot(centers[name]+Vector((0,0,.10*H)),(.15,.20 if expression=="joy"else .1,0))
        if name=="Tail":part=pivot(centers[name],(0,0,.12*math.sin(t*13)*(1 if expression=="joy"else .25)))
        ob.matrix_world=root_pose@part@rest[name]
    lowest,target=anchor(list(bear.values()),hop)
    if args.kind=="bear"and t>=1.55:
        assert lowest>=.002+.005*H-1e-6,("floor penetration",t,lowest)
    for i,ob in enumerate(confetti):
        ob.hide_render=not 2.48<t<3.25 or args.kind!="bear"
        u=max(0,t-2.48);angle=i*math.tau/8
        ob.location=(math.cos(angle)*(.35+u*.35),math.sin(angle)*.28,.8+u*1.2-u*u*.9)
        ob.rotation_euler=(u*3+i,u*4,u*2)
    if toy:
        assert all(ob.hide_render for ob in bear.values()),"Object-only toy reveal contains a Bear"
        present=smooth(1.60,1.86,t);alpha("toy",present)
        scale=(H*.60/1.5)*((.72 if args.tightened else .80)+(.31 if args.tightened else .23)*smooth(1.60,1.87,t)-.03*smooth(1.87,2.05,t))
        u=max(0,t-2.05);wobble=math.radians(12)*math.exp(-u*2.0)*math.sin(u*math.tau*2)
        if t>=2.75:wobble*=1-smooth(2.75,2.95,t)
        transform=Euler((wobble,wobble*.45,math.radians(18)*smooth(2.05,2.75,t))).to_matrix().to_4x4()@Matrix.Scale(scale,4)
        for ob in toy:ob.hide_render=t<1.60;ob.matrix_world=transform@toy_rest[ob]
        low,toy_target=anchor(toy,clearance=.0001)
        contact.hide_render=t<1.60
        point=min((ob.matrix_world@v.co for ob in toy for v in ob.data.vertices),key=lambda p:p.z)
        contact.location=(point.x,point.y,.00205)
        if t>=1.60:assert low>=.0021-1e-6
    if args.tightened:
        opening=smooth(.95,1.18,actual_t);shell_scale=1-.8*smooth(.95,1.18,actual_t)
        alpha("shell",1-smooth(.98,1.18,actual_t));alpha("cap",1-smooth(.96,1.10,actual_t))
        scale_matrix=Matrix.Scale(shell_scale,4)
        top.matrix_world=Matrix.Translation((opening*.72,opening*1.10,opening*.70))@Euler((opening*.4,opening*.7,0)).to_matrix().to_4x4()@scale_matrix
        top.hide_render=actual_t>=1.10;bottom.matrix_world=scale_matrix@egg;bottom.hide_render=opening>.001
        core.hide_render=True
        crack.hide_render=actual_t<.65 or actual_t>=.95;curve.bevel_factor_end=max(.001,smooth(.65,.93,actual_t))
        for i,ob in enumerate(halves):
            side=-1 if i==0 else 1;ob.hide_render=opening<=.001 or actual_t>=1.18
            ob.matrix_world=Matrix.Translation((side*opening*.65,opening*.75,.03))@Euler((0,side*opening*.65,side*opening*.15)).to_matrix().to_4x4()@scale_matrix
            if not ob.hide_render:
                xs=[(ob.matrix_world@v.co).x*side for v in ob.data.vertices]
                assert min(xs)>=-1e-6,("shell crossed centre",actual_t,side,min(xs))
        entry_hop=.035*H*pulse(actual_t,1.10,1.48)
        forward=.08*H*smooth(1.10,1.48,actual_t)
        shift=Matrix.Translation((0,-forward,entry_hop))
        for ob in bear.values():ob.matrix_world=shift@ob.matrix_world
        for ob in toy:ob.matrix_world=shift@ob.matrix_world
        lowest+=entry_hop;hop+=entry_hop
        if toy:low+=entry_hop
        if actual_t>=1.55:assert top.hide_render and all(ob.hide_render for ob in halves)
    bpy.context.view_layer.update()
    row=dict(time=actual_t,source_pose_age=t,expression=expression,eye_scale=eye*blink,bear_scale=size,hop=hop,minimum_mesh_z=lowest,target_z=target,shell_opacity=1-smooth(.98,1.18,actual_t)if args.tightened else shell_fade,bear_opacity=appear)
    if toy:row.update(toy_minimum_mesh_z=low,toy_target_z=toy_target,toy_visible=t>=1.60)
    metrics.append(row)


if args.catalog:
    assert args.kind=="bear"
    catalog=OUT/"catalog";catalog.mkdir(exist_ok=True)
    pose(5.5)
    for finish,roughness in(("standard",82/255),("gloss",36/255)):
        for name,ob in bear.items():
            if name in{"EyeL","EyeR","Mouth","Nose"}:continue
            for mat in ob.data.materials:
                node=mat.node_tree.nodes.get("Principled BSDF")
                node.inputs["Roughness"].default_value=roughness
                node.inputs["Metallic"].default_value=0
        scene.render.filepath=str(catalog/(finish+"-bear.png"));bpy.ops.render.render(write_still=True)
    # This is a direct-purchase authored Sun Hat, not an egg outcome.
    pose(5.5)
    correction=bear["Head"].matrix_world@rest["Head"].inverted()
    wearable=[]
    for name in("Hat_SunHat","Hat_SunHat_Band"):
        old=bpy.data.objects["PetBear__"+name];new=old.copy();new.data=old.data.copy();new.parent=None
        new.matrix_world=correction@inverse@old.matrix_world;new.hide_render=False;scene.collection.objects.link(new);wearable.append(new)
    target=Vector((0,0,H*.73));distance=2.6*H
    cam.location=target+Vector((0,-distance,math.tan(math.radians(8))*distance))
    cam.rotation_euler=(target-cam.location).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath=str(catalog/"sunhat-bust-direct-purchase.png");bpy.ops.render.render(write_still=True)
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in hashes.items())
    (catalog/"metadata.json").write_text(json.dumps(dict(source_unchanged=True,source_hashes=hashes,
        standard_roughness=82/255,gloss_roughness=36/255,metalness=0,
        provenance="assets/pet-materials/README.md and manifest.json; Blender visual equivalents, not native SurfaceAppearance proof",
        wearable="Hat_SunHat + Hat_SunHat_Band, authored direct-purchase wearable, not egg outcome"),indent=2))
    raise SystemExit(0)

fps=20 if args.tightened else 12;duration=(4.4 if args.kind=="bear"else 3.1)if args.tightened else(6 if args.kind=="bear"else 4)
times=([.2,.85,1.30,1.64,2.14,2.8]if args.tightened else[.2,1.0,1.75,1.95,2.6666666667,3.6])if args.stills else[i/fps for i in range(round(duration*fps))]
for index,t in enumerate(times):
    pose(t)
    from bpy_extras.object_utils import world_to_camera_view
    inspect=toy if args.kind=="toy"and t>=1.60 else list(bear.values())if args.kind=="bear"and t>=1.55 else []
    for ob in inspect:
        for corner in ob.bound_box:
            p=world_to_camera_view(scene,cam,ob.matrix_world@Vector(corner))
            assert .02<=p.x<=.98 and .02<=p.y<=.98,(args.kind,index,ob.name,"stage crop",tuple(p))
    scene.render.filepath=str(RAW/f"frame-{index:03d}.png")
    if not args.verify_only:bpy.ops.render.render(write_still=True)
    print("HATCH CONCEPT",args.kind,index,round(t,3),flush=True)
assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in hashes.items()),"Input blend changed"
metadata=dict(concept_only=True,not_live_game=True,kind=args.kind,duration=duration,fps=fps,render_size=[470,296],composite_size=[812,354],bear_visible=args.kind=="bear",
              source_hashes=hashes,source_unchanged=True,bear_parts=list(base_names),bear_height=H,bear_original_scale=args.kind=="bear",pose_metrics=metrics,
              bear_uniform_scale=1 if args.kind=="bear"else None,camera_fov_degrees=38,
              camera_distance_heights=3.6,camera_elevation_degrees=8,times=times,
              limitations=["Lower shell is split only in copied diagnostic meshes; production rig/receipt routing unchanged.",
                           "Bear uses rigid copied-part expression equivalents; full textured eye meshes compress together during blink. Astra actual-frame revision keeps authored smile and joy/pleased eyes at .95/.90. No native rig proof claimed.",
                           "Wobble Top recreated from its five-part runtime procedural specification."if args.kind=="toy"else"Authored base Bear materials/geometry retained."])
(OUT/(args.kind+("-stills"if args.stills else "")+"-metadata.json")).write_text(json.dumps(metadata,indent=2))
