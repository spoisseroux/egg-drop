"""Blender art source for the five Sprout Hollow babies.

Run with Blender --background --factory-startup --python thisfile -- --pet tikket.
Use --all after the first family has passed review. All authored coordinates use
the game's axes, with front +Z, paws on Y=0, and dimensions in garden studs.
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

OUT = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument("--pet", default="tikket")
parser.add_argument("--all", action="store_true")
parser.add_argument("--refresh", choices=("tikket","nuum","vezzi","kiprik","nolli"), help="refresh one export and reassemble the full editable lineup")
parser.add_argument("--renders-only", action="store_true")
flags = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
PI = math.pi
TAU = math.tau
BASES = {
    "tikket": ("Tikket", "wick", (0.94, 1.52, 0.85), "#DDD6CA", "#C68F84"),
    "nuum": ("Nuum", "orbit", (1.43, 1.22, 0.98), "#D9D9D4", "#9299BB"),
    "vezzi": ("Vezzi", "bloom_pip", (1.40, 1.46, 0.94), "#E4D9CD", "#BF91A3"),
    "kiprik": ("Kiprik", "foxfire_wick", (1.08, 1.56, 0.87), "#DEDAD7", "#AC9DC1"),
    "nolli": ("Nolli", "eclipse_orbit", (1.50, 1.27, 1.01), "#D3D3CC", "#9795AC"),
}
EXPRESSIONS = ("curious", "startled", "pleased", "sleepy", "affectionate")
FACE = {"face": "#383342", "mouth": "#63434C", "ivory": "#FFF4DB", "blush": "#DCA39D"}
FACE_VARIANTS = {"nuum": ("#343448", "#655265", "#C2ABB7"),
                 "kiprik": ("#393044", "#6B475C", "#D9A3AB"),
                 "nolli": ("#363448", "#645265", "#C5A6AF")}
FAMILIES = {}
ART = {}


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def xyz(value):
    return Vector((value[0], -value[2], value[1]))


def rb(value):
    return Vector((value[0], value[2], -value[1]))


def round_vec(value):
    return [round(float(v), 6) for v in value]


def linear_rgb(hexcolor):
    rgb = [int(hexcolor[i:i+2], 16)/255 for i in (1, 3, 5)]
    return tuple(c/12.92 if c <= .04045 else ((c+.055)/1.055)**2.4 for c in rgb)


def material(name, color, role):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    srgb = linear_rgb(color)
    mat.diffuse_color = (*srgb, 1)
    bs = mat.node_tree.nodes["Principled BSDF"]
    bs.inputs["Base Color"].default_value = (*srgb, 1)
    bs.inputs["Roughness"].default_value = .24 if role == "face" else .43
    bs.inputs["Specular IOR Level"].default_value = .42 if role == "face" else .30
    if "Coat Weight" in bs.inputs:
        bs.inputs["Coat Weight"].default_value = .23 if role in ("body", "secondary", "face") else .06
        bs.inputs["Coat Roughness"].default_value = .35
    return mat


def spow(v, power):
    return math.copysign(abs(v)**power, v)


def softly_squared(exponent=.9, corners=.95, taper=0, skew=0, bend=0, asym=0, around=22, rings=12):
    """Superellipsoid with asymmetric cheek/belly, local normalized span ~1."""
    verts, faces = [(0, -.5, 0)], []
    for j in range(1, rings):
        phi = -PI/2 + PI*j/rings
        y = spow(math.sin(phi), exponent)
        belt = spow(math.cos(phi), exponent)
        for i in range(around):
            theta = TAU*i/around
            x = belt*spow(math.cos(theta), corners)
            z = belt*spow(math.sin(theta), corners)
            verts.append((.5*x*(1+taper*y+asym*x*.16) + skew*y*.5,
                          .5*y + bend*x*x*.18, .5*z))
    top = len(verts); verts.append((skew*.5, .5, 0))
    for i in range(around):
        n = (i+1)%around
        faces.append((0, 1+n, 1+i))
        for j in range(rings-2):
            a, b = 1+j*around+i, 1+j*around+n
            faces.append((a, b, b+around, a+around))
        a, b = 1+(rings-2)*around+i, 1+(rings-2)*around+n
        faces.append((a, b, top))
    return verts, faces


def tube(path, widths, depths, sides=12):
    """Smooth closed loft through a sculpted spine in each part's local axes."""
    pts = [Vector(p) for p in path]; vs, fs = [], []
    for j, point in enumerate(pts):
        tangent = (pts[min(j+1,len(pts)-1)]-pts[max(0,j-1)]).normalized()
        across = tangent.cross(Vector((0,0,1)))
        if across.length < .00001:
            across = tangent.cross(Vector((0,1,0)))
        across.normalize(); forward=tangent.cross(across).normalized()
        for i in range(sides):
            a=TAU*i/sides
            vs.append(tuple(point+across*(math.cos(a)*widths[j])+forward*(math.sin(a)*depths[j])))
    fs.append(tuple(reversed(range(sides))))
    for j in range(len(pts)-1):
        for i in range(sides):
            k=(i+1)%sides; a=j*sides
            fs.append((a+i,a+k,a+sides+k,a+sides+i))
    fs.append(tuple(range((len(pts)-1)*sides,len(pts)*sides)))
    return vs,fs


def normalize_shape(geom):
    verts, faces = geom
    low = Vector(tuple(min(v[i] for v in verts) for i in range(3)))
    high = Vector(tuple(max(v[i] for v in verts) for i in range(3)))
    ctr = (high+low)*.5; span = high-low
    return [tuple((Vector(v)[i]-ctr[i])/max(1e-7,span[i]) for i in range(3)) for v in verts], faces


def catmull(points, segments=4):
    p=[Vector(v) for v in points]; out=[]
    for i in range(len(p)-1):
        a,b,c,d = p[max(0,i-1)],p[i],p[i+1],p[min(i+2,len(p)-1)]
        for j in range(segments):
            t=j/segments
            out.append(tuple(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)))
    return out+[tuple(p[-1])]


def softbend(side, sleepy=False):
    if sleepy:
        points=[(-.18*side,.44,-.22),(-.28*side,.31,-.10),(-.40*side,.04,.07),(-.28*side,-.22,.20),(.20*side,-.37,.30)]
    else:
        points=[(-.3*side,.46,-.20),(.08*side,.32,-.20),(.39*side,.08,-.12),(.35*side,-.18,.04),(-.06*side,-.38,.30),(-.25*side,-.40,.35)]
    path=catmull(points)
    n=len(path); w=[]; d=[]
    for j in range(n):
        t=j/(n-1)
        cap=max(.035,math.sin(PI*t))**.45
        w.append((.13+.11*t**2)*cap)
        d.append((.15+.08*t)*cap)
    return normalize_shape(tube(path,w,d))


def ribbon(which):
    if which=="smile":
        coords=[(-.49,.24,0),(-.35,.02,.20),(-.08,-.20,.36),(.16,-.20,.36),(.36,-.04,.18),(.49,.20,0)]
        widths=[.023,.10,.15,.145,.10,.023]
    else:
        coords=[(-.49,.13,0),(-.32,.40,.14),(-.08,.30,.30),(.15,.06,.34),(.32,-.18,.17),(.48,-.37,0)]
        widths=[.025,.13,.17,.16,.09,.025]
    pp=catmull(coords,4); ww=[]
    for j in range(len(pp)):
        f=j/4;i=min(len(widths)-2,int(f));ww.append(widths[i]*(1-(f-i))+widths[i+1]*(f-i))
    return normalize_shape(tube(pp,ww,[w*.56 for w in ww],10))


def transform_deg(rot):
    # Match Roblox CFrame.Angles (intrinsic X then Y then Z).
    rx,ry,rz=(math.radians(v) for v in rot)
    return Matrix.Rotation(rx,3,'X') @ Matrix.Rotation(ry,3,'Y') @ Matrix.Rotation(rz,3,'Z')


def prim(shape, center, size, rotation=(0,0,0)):
    return {"shape":shape,"center":list(center),"size":list(size),"xyzEulerDeg":list(rotation)}


def squash_fallback():
    return [prim("ellipsoid",(-.18,0,0),(.64,1,.98)),
            prim("ellipsoid",(.18,0,0),(.64,1,.98)),
            prim("ellipsoid",(0,0,0),(1,.91,1))]


def arm_fallback(sign):
    return [prim("ellipsoid",(-.08*sign,.15,-.1),(.76,.73,.72),(0,0,-23*sign)),
            prim("ellipsoid",(.14*sign,-.05,.02),(.71,.65,.72)),
            prim("ellipsoid",(-.08*sign,-.23,.15),(.83,.52,.70),(0,0,-15*sign))]


def smile_fallback():
    return [prim("ellipsoid",(-.30,.13,-.04),(.42,.43,.82),(0,0,-18)),
            prim("ellipsoid",(0,-.16,.08),(.51,.45,.83)),
            prim("ellipsoid",(.30,.13,-.04),(.42,.43,.82),(0,0,18))]


def author_uv(mesh, normalized):
    # One UV island per rounded primitive, +Z front at U=.5. Allow a seam
    # wrap beyond U=1 so an individual polygon never crosses the whole image.
    uv=mesh.uv_layers.new(name="PigmentUV")
    coords=[]
    for x,y,z in normalized:
        coords.append((.5+math.atan2(x,z)/TAU, max(0,min(1,y+.5))))
    for face in mesh.polygons:
        facecoords=[coords[mesh.loops[i].vertex_index] for i in face.loop_indices]
        wraps=max(u for u,v in facecoords)-min(u for u,v in facecoords)>.5
        for index,(u,v) in zip(face.loop_indices,facecoords):
            uv.data[index].uv=(u+int(wraps and u<.5),v)


def part(f, name, channel, center, size, role, geom=None, rotation=(0,0,0), kind="ellipsoid", fallback=None, hidden=False):
    if geom is None: geom=softly_squared(around=16,rings=9)
    vertices,faces=normalize_shape(geom)
    local_rot=transform_deg(rotation)
    scaled=[local_rot @ Vector((v[0]*size[0],v[1]*size[1],v[2]*size[2])) for v in vertices]
    mesh=bpy.data.meshes.new(f["display"]+"__"+name)
    mesh.from_pydata([xyz(v) for v in scaled],[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free()
    for polygon in mesh.polygons: polygon.use_smooth=True
    author_uv(mesh,vertices)
    obj=bpy.data.objects.new(mesh.name,mesh);f["collection"].objects.link(obj)
    obj.location=xyz(center);obj.data.materials.append(f["materials"][role])
    obj["channel"]=channel;obj["colorRole"]=role
    obj.hide_render=hidden or name=="CharmDot"
    native=prim(kind,center,size,rotation)
    native.update({"name":name,"channel":channel,"colorRole":role})
    if fallback:native["fallbackParts"]=fallback
    f["parts"].append((obj,native,scaled))
    return obj


def head_site(f,x,y,front_bias=0):
    """Place face pieces on the actual sculpt, raycasting in face-local space."""
    head=f["head"]; center=Vector(head[1]["center"])
    geo=head[0]; rot=transform_deg(head[1]["xyzEulerDeg"])
    from mathutils.bvhtree import BVHTree
    if "bvh" not in f:
        f["bvh"]=BVHTree.FromPolygons([rb(v.co) for v in geo.data.vertices],[tuple(poly.vertices) for poly in geo.data.polygons])
    xy=(rot @ Vector((x,y,0)));hit=f["bvh"].ray_cast(Vector((xy.x,xy.y,2)),Vector((0,0,-1)),4)[0]
    if hit is None: raise ValueError(f"Face attachment missed {f['display']}: {x}, {y}")
    return (center.x+xy.x, center.y+xy.y, center.z+hit.z+front_bias)


def arth_profile(f):
    return f["key"] in ("tikket","kiprik")


def add_face(f,spec):
    headwidth,headh=f["head"][1]["size"][:2]; tilt=f["head"][1]["xyzEulerDeg"][2]
    sleepy=spec in ("nuum","nolli"); grin=spec=="vezzi"
    eyex=headwidth*(.189 if spec=="nolli" else (.218 if sleepy else .220)); eyey=headh*(.04 if sleepy else .095)
    for sign,side in [(-1,"L"),(1,"R")]:
        eyelid=(.067 if sign<0 else .121) if spec=="nolli" else (.091 if sleepy else (.100 if spec in ("tikket","kiprik") and sign>0 else .151))
        offset=eyex*sign; yy=eyey+(sign*.007 if sleepy else 0)
        e=head_site(f,offset,yy,.010)
        part(f,"Eye"+side,"Face",e,(.120 if not sleepy else .142,eyelid,.048),"face",
             softly_squared(.85,.92,around=18,rings=10),rotation=(0,sign*15,tilt+sign*(5 if sleepy else -2)))
        part(f,"Glint"+side,"Face",(e[0]-.020,e[1]+eyelid*.17,e[2]+.025),(.033,.034,.018),"ivory",
             softly_squared(around=10,rings=6))
        cheek=head_site(f,sign*(eyex+.105),eyey-.078,.006)
        part(f,"Cheek"+side,"Face",cheek,(.103,.050,.031),"blush",
             softly_squared(around=12,rings=7),rotation=(0,sign*19,tilt+sign*7))
    m=head_site(f,(.050 if spec in ("tikket","kiprik") else .014) if not sleepy else (-.046 if spec=="nolli" else .027),-headh*(.18 if not grin else .17),.012)
    mw=.37 if grin else (.175 if sleepy else .225)
    part(f,"MouthSmile","Face",m,(mw,.086 if grin else .044,.042),"mouth",ribbon("smile"),
         rotation=(0,0,tilt+(4 if grin else (9 if arth_profile(f) else 0))),kind="smile",fallback=smile_fallback())
    part(f,"MouthO","Face",(m[0],m[1],m[2]+.008),(.088,.118,.042),"mouth",hidden=True)
    if grin:
        geom=([],[])
        for i in range(4):
            data=softly_squared(.62,.76,taper=.92,around=10,rings=7)
            v,fc=data;ofs=len(geom[0]);x=(i-1.5)*.25
            geom[0].extend([(a*.20+x,b*.92+.035*(i-1.5)**2,c*.60) for a,b,c in v])
            geom[1].extend([tuple(k+ofs for k in face) for face in fc])
        part(f,"Teeth","Face",(m[0],m[1]+.008,m[2]+.023),(.218,.044,.023),"ivory",geom,
             rotation=(0,0,tilt+4),fallback=[prim("ellipsoid",((i-1.5)*.25,.035*(i-1.5)**2,0),(.20,.87,.9)) for i in range(4)])
def make_pet(key):
    display,stable,target,body,accent=BASES[key]
    palette={"body":body,"secondary":accent,**FACE}
    if key in FACE_VARIANTS:
        palette["face"],palette["mouth"],palette["blush"]=FACE_VARIANTS[key]
    collection=bpy.data.collections.new(display);bpy.context.scene.collection.children.link(collection)
    f={"display":display,"key":key,"legacy":stable,"target":target,"palette":palette,"collection":collection,
       "materials":{r:material(display+"_"+r,c,r) for r,c in palette.items()},"parts":[]}
    arthropod=key in ("tikket","kiprik")
    sleeper=key in ("nuum","nolli")
    if arthropod:
        rare=key=="kiprik";sgn=1 if not rare else -1
        head_pos=(-.045*sgn,1.108+(.016 if rare else 0),.0)
        head_size=(.855 if not rare else .888,.737,.683)
        part(f,"Head","Head",head_pos,head_size,"body",
             softly_squared(.59,.66,taper=.09,skew=.03*sgn,bend=-.045,around=28,rings=15),
             rotation=(0,0,-13*sgn),kind="softbox",fallback=squash_fallback())
        f["head"]=f["parts"][-1]
        part(f,"Body","Body",(0,.472,-.015),(.506,.632,.508),"body",softly_squared(.9,.9,taper=-.18,bend=.02,around=22,rings=12),rotation=(0,0,2*sgn))
        for side,sign in [("L",-1),("R",1)]:
            left=sign<0
            arm_pos=(sign*(.334 if left else .312),.689 if left else .596,.041 if left else -.005)
            part(f,"Hand"+side,"Hand"+side,arm_pos,(.272 if left else .215,.406 if left else .476,.312 if left else .276),"body",
                 softbend(sign),rotation=(-20 if left else 12,-sign*9,sign*(23 if left else -6)),kind="mitten",fallback=arm_fallback(sign))
            # Joined by silhouette to the curved sleeve: a deliberately blunt mitten.
            end=(arm_pos[0]-.028*sign,arm_pos[1]-.137 if left else arm_pos[1]-.186,arm_pos[2]+.105)
            if not rare or left:
                part(f,"MittenTip"+side,"Hand"+side,end,(.168,.154,.193),"secondary",
                     softly_squared(.70,.76,taper=-.10,around=16,rings=9),rotation=(-9,sign*8,sign*15))
            part(f,"Foot"+side,"Foot"+side,(sign*(.157 if sign<0 else .174),.133,.104 if sign<0 else .051),
                 (.263 if sign<0 else .238,.266,.391 if sign<0 else .340),"secondary",
                 softly_squared(.81,.84,taper=-.08,skew=.04*sign,around=18,rings=9),rotation=(0,sign*9,0))
            part(f,"HipFlap"+side,"Body",(sign*.249,.408 if sign<0 else .493,-.104),(.248,.319 if sign<0 else .202,.297),"secondary",
                 softly_squared(.68,.80,taper=.41,skew=.17*sign,around=18,rings=11),rotation=(sign*3,sign*18,-sign*26),kind="fold")
        if rare:
            for side,sign in [("L",-1),("R",1)]:
                part(f,"FinnedCheek"+side,"Head",(sign*.484,1.055 if sign<0 else 1.117,-.185),(.320,.410 if sign<0 else .345,.488),
                     "secondary",softly_squared(.68,.8,taper=.28,skew=-.22*sign,around=20,rings=12),
                     rotation=(-32,sign*24,sign*24),kind="fold")
    elif sleeper:
        rare=key=="nolli";sgn=-1 if rare else 1
        head_pos=(.012*sgn,.815+(.028 if rare else 0),.016)
        head_size=(1.26 if not rare else 1.235,.737 if not rare else .782,.836)
        part(f,"Head","Head",head_pos,head_size,"body",
             softly_squared(.88,.81,taper=-.16,skew=-.03*sgn,bend=.14,asym=.2*sgn,around=30,rings=15),
             rotation=(0,0,(7 if rare else -2)*sgn))
        f["head"]=f["parts"][-1]
        part(f,"Body","Body",(0,.393,-.030),(.944,.48,.740),"body",softly_squared(.82,.80,taper=-.15,around=22,rings=12))
        for side,sign in [("L",-1),("R",1)]:
            tucked=sign==sgn
            part(f,"Hand"+side,"Hand"+side,(sign*(.547 if tucked else .475),.575 if tucked else .399,.218 if tucked else .054),
                 (.260 if tucked else .228,.251 if tucked else .259,.288),"body",softly_squared(.77,.84,taper=-.28,skew=.16*sign,around=18,rings=10),
                 rotation=(-22 if tucked else 15,sign*11,sign*(16 if tucked else 3)),kind="mitten",fallback=arm_fallback(sign))
            part(f,"Foot"+side,"Foot"+side,(sign*.263,.104,.119 if sign<0 else .169),
                 (.273,.208,.310 if sign<0 else .354),"secondary",softly_squared(.77,.83,around=17,rings=9),
                 rotation=(0,sign*12,0))
        if rare:
            # An unbroken C-shaped padded fold, below cheek at one end and
            # rising behind the opposing temple. Its open side exposes the face.
            path=catmull([(-.37,.17,.48),(-.58,.13,.20),(-.63,.11,-.08),(-.54,.12,-.28),(-.27,.16,-.40),
                          (.10,.20,-.41),(.46,.14,-.28),(.62,.04,-.04),(.56,-.10,.20),(.38,-.21,.32)],4)
            n=len(path)
            geom=tube(path,[.12*max(.025,math.sin(PI*i/(n-1)))**.40 for i in range(n)],
                     [.136*max(.025,math.sin(PI*i/(n-1)))**.40 for i in range(n)],12)
            part(f,"Cowl","Head",(.014,.684,.057),(1.49,.565,.871),"secondary",geom,
                 fallback=[prim("ellipsoid",(-.38,-.04,.05),(.24,.62,.52),(0,0,-18)),
                           prim("ellipsoid",(0,.13,-.24),(.96,.66,.52)),
                           prim("ellipsoid",(.39,.10,-.02),(.22,.69,.60),(0,0,17))])
            lid=head_site(f,-head_size[0]*.189,.068,.016)
            part(f,"LidFold","Head",lid,(.191,.062,.064),"body",ribbon("brow"),rotation=(0,-11,9))
        else:
            part(f,"CheekFold","Head",(.584,.770,.112),(.293,.403,.525),"secondary",
                 softly_squared(.84,.78,taper=-.34,skew=.10,around=20,rings=12),rotation=(12,-11,-18),kind="fold")
    else:
        head_pos=(-.030,.914,.012);head_size=(1.201,.790,.844)
        part(f,"Head","Head",head_pos,head_size,"body",
             softly_squared(.79,.85,taper=-.11,skew=.015,bend=.15,around=30,rings=14),rotation=(0,0,4))
        f["head"]=f["parts"][-1]
        part(f,"Body","Body",(0,.432,-.013),(.741,.626,.687),"body",softly_squared(.84,.89,taper=-.2,around=22,rings=12))
        for side,sign in [("L",-1),("R",1)]:
            part(f,"Hand"+side,"Hand"+side,(sign*.378,.487,.078),(.219,.326,.276),"body",
                 softly_squared(.86,.87,taper=-.16,skew=.13*sign,around=17,rings=10),rotation=(7,sign*11,sign*12))
            part(f,"Foot"+side,"Foot"+side,(sign*.278,.111,.104),(.305,.222,.350),"secondary",
                 softly_squared(.80,.85,around=18,rings=9),rotation=(0,sign*12,0))
        part(f,"FoldedEar","Head",(-.506,1.227,-.022),(.327,.375,.289),"secondary",
             softly_squared(.59,.70,taper=-.25,skew=.15,around=20,rings=11),rotation=(-11,-14,29),kind="fold")
        part(f,"EarSeam","Head",(-.536,1.264,.095),(.149,.195,.046),"body",softly_squared(.68,.70,taper=-.35),
             rotation=(-16,-22,27))
        part(f,"BrowFold","Head",(.370,1.242,.022),(.301,.138,.285),"body",
             softly_squared(.77,.75,taper=-.05,skew=-.04),rotation=(0,11,-9))
    add_face(f,key)
    chip=(head_pos[0],head_pos[1]+head_size[1]*.5+.225,head_pos[2]-.015)
    if key=="vezzi":chip=(0,1.56,-.003)
    part(f,"CharmDot","Charm",chip,(.174,.181,.170),"secondary",softly_squared(around=16,rings=8))
    normalize_family(f)
    add_morphs(f)
    FAMILIES[key]=f
    return f


def normalize_family(f):
    # Anatomical extents exclude the independently switchable floating charm,
    # and the alternative O-mouth. Normalize translation and size in one pass.
    vs=[]
    for obj,desc,verts in f["parts"]:
        if desc["name"] not in ("CharmDot","MouthO"):
            center=Vector(desc["center"]);vs.extend([center+v for v in verts])
    lo=Vector(tuple(min(v[i] for v in vs) for i in range(3)))
    hi=Vector(tuple(max(v[i] for v in vs) for i in range(3)))
    span=hi-lo; target=Vector(f["target"])
    # Preserve sculpt proportions; very small corrections to the declared height
    # and width are preferable to stretching an expression to fit a box.
    change=target.y/span.y
    sx=target.x/span.x; sz=target.z/span.z
    scales=Vector((sx,change,sz))
    origin=Vector(((hi.x+lo.x)*.5,lo.y,(hi.z+lo.z)*.5))
    for obj,desc,verts in f["parts"]:
        old=Vector(desc["center"]);new=old-origin
        desc["center"]=round_vec(Vector((new.x*sx,new.y*change,new.z*sz)))
        size=Vector(desc["size"]);desc["size"]=round_vec(Vector((size.x*sx,size.y*change,size.z*sz)))
        obj.location=xyz(desc["center"])
        for index,v in enumerate(verts):
            rv=Vector((v.x*sx,v.y*change,v.z*sz));obj.data.vertices[index].co=xyz(rv)
        obj.data.update()
    f["scaleCorrections"]=round_vec(scales)
    f["width"],f["height"],f["depth"]=f["target"]


def add_morphs(f):
    for obj,d,_ in f["parts"]:
        name=d["name"];role=d["channel"]
        if name.startswith(("Foot","Charm","Glint","CheekL","CheekR")) or name=="MouthO": continue
        basis=obj.shape_key_add(name="Basis")
        for expr in EXPRESSIONS:
            key=obj.shape_key_add(name=expr)
            for idx,vtx in enumerate(basis.data):
                v=rb(vtx.co);x,y,z=v
                if name.startswith("Eye"):
                    factors={"curious":(1.02,1.13),"startled":(1.08,1.26),"pleased":(1.09,.66),
                             "sleepy":(1.10,.36),"affectionate":(1.08,.51)}
                    xs,ys=factors[expr];v=Vector((x*xs,y*ys+.09*(1-ys)*(x*x/max(.02,d["size"][0]**2)),z))
                elif name=="MouthSmile":
                    ys={"curious":.75,"startled":.18,"pleased":1.50,"sleepy":.48,"affectionate":1.18}[expr]
                    v=Vector((x*(1.14 if expr=="pleased" else 1),y*ys,z))
                elif name=="Head":
                    squish={"curious":1.015,"startled":1.055,"pleased":.96,"sleepy":.96,"affectionate":.98}[expr]
                    v=Vector((x/(squish**.40),y*squish,z/(squish**.18)))
                elif name=="Body":
                    squish={"curious":1.02,"startled":1.06,"pleased":.96,"sleepy":.95,"affectionate":.98}[expr]
                    v=Vector((x/(squish**.45),y*squish,z/(squish**.2)))
                elif role in ("HandL","HandR"):
                    v=Vector((x,y*(.87 if expr in ("pleased","affectionate") else 1.02),z))
                else:
                    v=Vector((x,y*(1.10 if expr=="startled" else .98),z))
                key.data[idx].co=xyz(v)


def export_data(f):
    selected=[obj for obj,_,_ in f["parts"]]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in selected:
        obj.hide_set(False);obj.select_set(True)
    bpy.context.view_layer.objects.active=selected[0]
    # Native source remains +Z-front. FBX is game-import convention -Z-forward,
    # Y-up. The existing Studio importer rotates its template exactly once.
    path=OUT/(f["key"]+".fbx")
    bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,axis_forward="-Z",axis_up="Y",
        global_scale=1.0,apply_unit_scale=True,use_mesh_modifiers=False,object_types={"MESH"},
        add_leaf_bones=False,bake_anim=False,path_mode="AUTO",mesh_smooth_type="FACE")
    manifest=[]
    for obj,p,_ in f["parts"]:
        mesh=obj.data;mesh.calc_loop_triangles()
        world=[rb(obj.matrix_world @ vertex.co) for vertex in mesh.vertices]
        low=Vector(tuple(min(v[i] for v in world) for i in range(3)));high=Vector(tuple(max(v[i] for v in world) for i in range(3)))
        manifest.append({"name":obj.name,"channel":p["channel"],"role":p["name"],"colorRole":p["colorRole"],
                         "centerRoblox":round_vec((low+high)/2),"sizeRoblox":round_vec(high-low),
                         "triangles":len(mesh.loop_triangles),"exprKeys":[k.name for k in mesh.shape_keys.key_blocks][1:] if mesh.shape_keys else []})
    by_name={p["name"]:p for _,p,_ in f["parts"]}
    anchors={"Root":[0,0,0],"EyeLine":round_vec((Vector(by_name["EyeL"]["center"])+Vector(by_name["EyeR"]["center"]))/2)}
    for key in ["Head","Body","HandL","HandR","FootL","FootR"]:
        anchors[key]=by_name[key]["center"]
    anchors["CharmAnchor"]=by_name["CharmDot"]["center"]
    anchors["HandCatch"]=round_vec((Vector(anchors["HandL"])+Vector(anchors["HandR"]))/2+Vector((0,0,.20)))
    native={"schema":1,"id":f["key"],"legacyId":f["legacy"],"axes":{"up":"+Y","front":"+Z","right":"+X"},
            "units":"studs at garden size","nativeScaleFactor":1/.72,"palette":f["palette"],"anchors":anchors,"pieces":[p for _,p,_ in f["parts"]]}
    write_json(OUT/(f["key"]+"-native.json"),native)
    triangles=sum(row["triangles"] for row in manifest)
    if len(manifest)>20 or triangles>7500:
        raise ValueError(f"{f['display']}: {len(manifest)} pieces and {triangles} triangles exceed budget")
    write_json(OUT/(f["key"]+"-mesh-manifest.json"),
               {"asset":f["key"],"displayName":f["display"],"legacyId":f["legacy"],"coordinateSystem":native["axes"],
                "sourceUnits":native["units"],"neutralBoundsExcludingCharm":list(f["target"]),
                "bodyHeightTarget":f["height"],"triangles":triangles,"meshCount":len(manifest),
                "fbxSha256":hashlib.sha256(path.read_bytes()).hexdigest(),"objects":manifest})
    print("EXPORTED",f["display"],len(manifest),triangles)
def make_stage():
    sc=bpy.context.scene
    sc.render.engine="CYCLES"
    sc.cycles.samples=18
    sc.cycles.use_denoising=True
    sc.render.resolution_x=420;sc.render.resolution_y=420;sc.render.resolution_percentage=100
    sc.render.image_settings.file_format="PNG";sc.render.film_transparent=False
    sc.world.use_nodes=True; bg=sc.world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value=(.51,.70,.77,1);bg.inputs["Strength"].default_value=.36
    sc.view_settings.view_transform="AgX"
    sc.view_settings.look="AgX - Medium High Contrast"
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0,0,-.007))
    ground=bpy.context.object;ground.name="Studio floor";ground.data.materials.append(material("Studio_mint","#C2D7CD","floor"))
    def area(name,pos,power,size,tint):
        lamp=bpy.data.lights.new(name,"AREA");lamp.energy=power;lamp.shape="DISK";lamp.size=size;lamp.color=tint
        obj=bpy.data.objects.new(name,lamp);sc.collection.objects.link(obj);obj.location=pos
        obj.rotation_euler=(Vector((0,0,.70))-obj.location).to_track_quat("-Z","Y").to_euler()
    area("Large softbox",(-3.0,-4.2,5.2),305,3.9,(1.0,.95,.85))
    area("Cool fill",(3.2,-2.3,2.2),58,3.8,(.74,.89,1.0))
    area("Rim on folds",(1.1,2.5,3.7),190,2.8,(.76,.87,1.0))
    data=bpy.data.cameras.new("Study camera");data.type="ORTHO"
    cam=bpy.data.objects.new("Study camera",data);sc.collection.objects.link(cam);sc.camera=cam
    return cam


def camera_view(cam, angle, h, zoom=2.05, distance=7, cx=0):
    yaw=math.radians(angle);target=Vector((cx,0,h*.50))
    cam.location=target+Vector((math.sin(yaw)*distance,-math.cos(yaw)*distance,distance*.155))
    cam.rotation_euler=(target-cam.location).to_track_quat("-Z","Y").to_euler()
    cam.data.ortho_scale=zoom


def display_pose(f,expr):
    head=f["head"][0]
    center=xyz(f["head"][1]["center"])
    tilt={"neutral":0,"curious":8,"startled":-5,"pleased":-6,"sleepy":-7,"affectionate":10}[expr]
    lift={"neutral":0,"curious":.010,"startled":.047,"pleased":.009,"sleepy":-.045,"affectionate":-.012}[expr]
    rot=Matrix.Rotation(math.radians(tilt),3,'Y')
    for obj,p,_ in f["parts"]:
        obj.location=xyz(p["center"]);obj.rotation_euler=(0,0,0)
        obj.hide_render=p["name"]=="CharmDot" or (p["name"]=="MouthO" and expr!="startled") or (p["name"] in ("MouthSmile","Teeth") and expr=="startled")
        if obj.data.shape_keys:
            for k in obj.data.shape_keys.key_blocks:
                if k.name!="Basis":k.value=float(k.name==expr)
        if p["channel"] in ("Face","Head","Charm"):
            obj.location=center +rot @ (obj.location-center)+Vector((0,0,lift))
            obj.rotation_euler=rot.to_euler()
        elif p["channel"] in ("HandL","HandR"):
            bend={"neutral":0,"curious":-.08,"startled":.33,"pleased":.14,"sleepy":-.11,"affectionate":.19}[expr]
            sign=-1 if p["channel"]=="HandL" else 1
            obj.rotation_euler.x=bend
            obj.rotation_euler.y=bend*.8*sign
            obj.location.z+=max(0,bend)*.10


def render_single(f,cam):
    from tempfile import gettempdir
    path=Path(gettempdir())/"egg-drop-overnight-pet-renders";path.mkdir(exist_ok=True)
    for other in FAMILIES.values():
        other["collection"].hide_render=other is not f
    sc=bpy.context.scene
    sc.render.resolution_x=sc.render.resolution_y=420
    frames=[("front",0,"neutral"),("three-quarter",28,"neutral"),("profile",90,"neutral")]
    frames += [(e,15,e) for e in EXPRESSIONS]
    for label,ang,expr in frames:
        display_pose(f,expr);camera_view(cam,ang,f["height"],2.04)
        sc.render.filepath=str(path/(f["key"]+"-"+label+".png"))
        bpy.ops.render.render(write_still=True)
    display_pose(f,"neutral");camera_view(cam,20,f["height"],2.23)
    pairs=[("rose-tide","#FF327A","#008DFF"),("tide-citrus","#008DFF","#FFCC00"),
           ("iris-rose","#9350FF","#FF327A"),("rose-tide-mix","#AC4BFA","#9350FF")]
    for label,body,secondary in pairs:
        for role,color in [("body",body),("secondary",secondary)]:
            mat=f["materials"][role];rgba=(*linear_rgb(color),1)
            mat.diffuse_color=rgba;mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=rgba
        for obj,p,_ in f["parts"]:
            if p["name"]=="CharmDot":obj.hide_render=False
        sc.render.filepath=str(path/(f["key"]+"-"+label+".png"))
        bpy.ops.render.render(write_still=True)
    for role in ("body","secondary"):
        mat=f["materials"][role];rgba=(*linear_rgb(f["palette"][role]),1)
        mat.diffuse_color=rgba;mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=rgba
    display_pose(f,"neutral")
    print("RENDERED",f["display"],path)


def save_lineup(cam):
    sc=bpy.context.scene
    keys=list(FAMILIES); widths=[FAMILIES[k]["width"] for k in keys]
    extent=sum(widths)+.45*(len(keys)-1)
    x=-extent/2
    for key,w in zip(keys,widths):
        f=FAMILIES[key];display_pose(f,"neutral");f["collection"].hide_render=False
        holder=bpy.data.objects.new(f["display"]+" lineup",None);f["collection"].objects.link(holder)
        holder.empty_display_type="PLAIN_AXES";holder.empty_display_size=.2
        for obj,_,_ in f["parts"]:obj.parent=holder
        holder.location.x=x+w/2;x+=w+.45
    camera_view(cam,0,1.52,extent+.9)
    sc.render.resolution_x=1500;sc.render.resolution_y=480
    sc.render.filepath=str(OUT/"five-neutral-lineup.png")
    bpy.ops.render.render(write_still=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"five-garden-babies.blend"),compress=True)


def run():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.world=bpy.data.worlds.new("Garden studio environment")
    families=list(BASES) if flags.all or flags.refresh else [flags.pet]
    for key in families:
        f=make_pet(key);bpy.context.view_layer.update()
        if not flags.renders_only and (not flags.refresh or key==flags.refresh): export_data(f)
    cam=make_stage()
    for key in families:
        if not flags.refresh or key==flags.refresh:render_single(FAMILIES[key],cam)
    if flags.all or flags.refresh:save_lineup(cam)
    print("BABY ART COMPLETE")


if __name__=="__main__":run()
