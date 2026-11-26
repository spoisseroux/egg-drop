"""Blip v3 procedural concepts only. Run background Blender on Bear attachments:
blender -b assets/art-source/pets/pet-bear-attachments.blend --python scripts/build_blip_v3.py -- D --out artifacts/blip-v3-2026-11-14
D/E/F create new meshes; BEAR preserves authored base geometry/materials. Never exports/updates production.
"""
import argparse, hashlib, json, math, sys
from pathlib import Path
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

args=argparse.ArgumentParser()
args.add_argument('variant',choices=['D','E','F','BEAR'])
args.add_argument('--out',required=True)
args.add_argument('--samples',type=int,default=48)
a=args.parse_args(sys.argv[sys.argv.index('--')+1:])
OUT=Path(a.out).resolve(); (OUT/'raw').mkdir(parents=True,exist_ok=True)
assert Path(bpy.data.filepath).name=='pet-bear-attachments.blend','Read Bear source only'
SOURCE=Path(bpy.data.filepath).resolve();SOURCE_SHA=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
scene=bpy.context.scene
for ob in scene.objects: ob.hide_render=True

def rgb(h):
    values=[int(h[i:i+2],16)/255 for i in (1,3,5)]
    return tuple(x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in values)
def material(name,color,rough=.46):
    m=bpy.data.materials.new(name);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*rgb(color),1)
    bs.inputs['Roughness'].default_value=rough;bs.inputs['IOR'].default_value=1.45;bs.inputs['Metallic'].default_value=0
    return m
mint=material('v3_Mint','#94DFB7');cream=material('v3_Cream','#FFF0D2');ink=material('v3_Ink','#24313B',.12)
blush=material('v3_Blush','#E98F99',.55);shine=material('v3_Shine','#FFFDF4',.22)
created=[]
def mesh(name,verts,faces,mat):
    me=bpy.data.meshes.new('v3_'+name);me.from_pydata(verts,[],faces);me.update()
    ob=bpy.data.objects.new('v3_'+name,me);scene.collection.objects.link(ob);me.materials.append(mat)
    for poly in me.polygons:poly.use_smooth=True
    created.append(ob);return ob

def ellipsoid(name,c,r,mat,power=2,warp=None,segments=96,rings=64,angle=0):
    # Collapsed poles + regular latitude rings, with outward winding.
    exp=2/power
    def signpow(x):return math.copysign(abs(x)**exp,x)
    verts=[]
    for j in range(rings+1):
        lat=-math.pi/2+math.pi*j/rings
        ring=[]
        count=1 if j in (0,rings) else segments
        for i in range(count):
            theta=2*math.pi*i/segments
            q=Vector((r[0]*signpow(math.cos(lat))*signpow(math.cos(theta)),r[1]*signpow(math.cos(lat))*signpow(math.sin(theta)),r[2]*signpow(math.sin(lat))))
            if warp:q=warp(q)
            q=Vector((q.x*math.cos(angle)-q.z*math.sin(angle),q.y,q.x*math.sin(angle)+q.z*math.cos(angle)))+Vector(c)
            ring.append(len(verts));verts.append(q)
        if j==0:prev=ring;continue
        if len(prev)==1:
            for k in range(segments):faces.append((prev[0],ring[(k+1)%segments],ring[k]))
        elif len(ring)==1:
            for k in range(segments):faces.append((prev[k],prev[(k+1)%segments],ring[0]))
        else:
            for k in range(segments):faces.append((prev[k],prev[(k+1)%segments],ring[(k+1)%segments],ring[k]))
        prev=ring
    return mesh(name,verts,faces,mat)

def ball(name,c,r,mat,**kw):
    global faces
    faces=[]
    return ellipsoid(name,c,r,mat,**kw)
def tree(ob):
    ob.data.calc_loop_triangles()
    return BVHTree.FromPolygons([v.co for v in ob.data.vertices],[tuple(t.vertices) for t in ob.data.loop_triangles])
def front(bvh,x,z):
    hit=bvh.ray_cast(Vector((x,-3,z)),Vector((0,1,0)))[0]
    assert hit is not None,(x,z)
    return hit.y

def patch(name,bvh,cx,cz,rx,rz,mat,depth=.004,convex=0):
    # Surface-conforming convex oval disk; each vertex samples actual source geometry.
    verts=[(cx,front(bvh,cx,cz)-depth-convex,cz)];fs=[];segs=48;levels=8
    for j in range(1,levels+1):
        t=j/levels
        for k in range(segs):
            theta=2*math.pi*k/segs;x=cx+rx*t*math.cos(theta);z=cz+rz*t*math.sin(theta)
            verts.append((x,front(bvh,x,z)-depth-convex*(1-t*t),z))
        start=1+(j-1)*segs
        if j==1:
            for k in range(segs):fs.append((0,start+k,start+(k+1)%segs))
        else:
            previous=start-segs
            for k in range(segs):fs.append((previous+k,start+k,start+(k+1)%segs,previous+(k+1)%segs))
    return mesh(name,verts,fs,mat)

def stroke(name,points,radius,mat):
    curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.resolution_u=16
    curve.bevel_depth=radius;curve.bevel_resolution=4;curve.resolution_u=16;curve.use_fill_caps=True
    spline=curve.splines.new('POLY');spline.points.add(len(points)-1)
    for p,co in zip(spline.points,points):p.co=(*co,1)
    ob=bpy.data.objects.new('v3_'+name,curve);scene.collection.objects.link(ob);curve.materials.append(mat);created.append(ob)
    for i,point in enumerate((points[0],points[-1])):ball(name+'_cap'+str(i),point,(radius,)*3,mat,segments=16,rings=10)
    return ob

def headwarp(q):
    z=q.z+1.05
    cheek=math.exp(-((z-.95)/.11)**2)
    q.x*=1+.05*cheek
    if a.variant=='E':q.x*=1+.07*cheek-.14*max(0,q.z/.45)
    if a.variant=='F' and q.z>0:
        # Continuous crown raises left broad lobe 0.06, keeps right baseline and soft center saddle.
        t=min(1,q.z/.45)**5
        profile=.072*math.exp(-((q.x+.20)/.16)**2)+.018*math.exp(-((q.x-.22)/.14)**2)-.043*math.exp(-(q.x/.105)**2)
        q.z+=profile*t
    return q

if a.variant=='BEAR':
    root=bpy.data.objects['PetBear'];inv=root.matrix_world.inverted()
    for ob in list(bpy.data.objects):
        if ob.type=='MESH' and ob.name in {'PetBear__'+n for n in ('Body','Head','HandL','HandR','FootL','FootR','EarL','EarR','EarInnerL','EarInnerR','EyeL','EyeR','Mouth','Muzzle','Nose','Tail')}:
            # Wearables live in a separate collection. Keep exact base meshes/materials.
            if any('Wearable' in c.name for c in ob.users_collection):continue
            ob.matrix_world=inv@ob.matrix_world;ob.hide_render=False;created.append(ob)
else:
    body=ball('Body',(0,.015,.405),(.29,.245,.285),mint,warp=lambda q:Vector((q.x*(1-.12*max(0,q.z/.285)),q.y,q.z)))
    head=ball('Head',(0,0,1.05),(.58 if a.variant=='E' else .51 if a.variant=='F' else .55,.37,.45),mint,power=2 if a.variant=='E' else 2.25 if a.variant=='F' else 2.3,warp=headwarp)
    for side in (-1,1):
        ball('Hand'+str(side),(side*.31,-.015,.48),(.12,.14,.17),mint,angle=-side*math.radians(12))
        ball('Foot'+str(side),(side*.15,-.055,.105),(.145,.19,.105),mint)
    if a.variant=='D':
        # Squishy backward fold: overlapping broad ellipsoids, no stalk or tip sphere.
        fold=[]
        for i in range(13):
            t=i/12;u=1-t
            fold.append(Vector((u*u*-.13+2*u*t*-.13+t*t*-.10,u*u*.04+2*u*t*.24+t*t*.32,u*u*1.41+2*u*t*1.61+t*t*1.43)))
        # Voxel unify fold with skull gives a continuous root while retaining the face dimensions.
        for i,p in enumerate(fold):ball('CrownFold'+str(i),p,(.105-.03*i/12,)*3,mint,segments=24,rings=16)
        bpy.ops.object.select_all(action='DESELECT')
        fold_objects=[o for o in created if 'CrownFold' in o.name]
        for ob in [head]+fold_objects:ob.select_set(True)
        created=[o for o in created if o not in fold_objects]
        bpy.context.view_layer.objects.active=head;bpy.ops.object.join()
        rem=head.modifiers.new('Concept continuous fold','REMESH');rem.mode='VOXEL';rem.voxel_size=.009;rem.use_smooth_shade=True
        bpy.ops.object.modifier_apply(modifier=rem.name)
        smooth=head.modifiers.new('Soft root','SMOOTH');smooth.factor=.6;smooth.iterations=3;bpy.ops.object.modifier_apply(modifier=smooth.name)
        created=[o for o in created if o.name in bpy.data.objects]
    if a.variant=='E':
        for side in (-1,1):
            for i in range(7):
                t=i/6;u=1-t
                p=(side*(u*u*.48+2*u*t*.60+t*t*.59),u*u*.01+2*u*t*.10+t*t*.20,u*u*.98+2*u*t*.88+t*t*.82)
                ball('CheekFin'+str(side)+'_'+str(i),p,(.12*(1-.2*t),.095,.14*(1-.35*t)),mint,segments=24,rings=16)
        bpy.ops.object.select_all(action='DESELECT')
        fin_objects=[o for o in created if 'CheekFin' in o.name]
        for ob in [head]+fin_objects:ob.select_set(True)
        created=[o for o in created if o not in fin_objects]
        bpy.context.view_layer.objects.active=head;bpy.ops.object.join()
        rem=head.modifiers.new('Concept continuous cheeks','REMESH');rem.mode='VOXEL';rem.voxel_size=.009;rem.use_smooth_shade=True
        bpy.ops.object.modifier_apply(modifier=rem.name)
        smooth=head.modifiers.new('Soft joins','SMOOTH');smooth.factor=.6;smooth.iterations=3;bpy.ops.object.modifier_apply(modifier=smooth.name)
        created=[o for o in created if o.name in bpy.data.objects]
    if a.variant=='F':ball('RearNub',(0,.27,.42),(.10,.12,.10),mint)
    hb=tree(head);bb=tree(body)
    patch('Belly',bb,0,.39,.18,.185,cream)
    for side in (-1,1):
        eye=patch('Eye'+str(side),hb,side*.18,.96,.12,.17,ink,depth=.004,convex=.035);eb=tree(eye)
        for n,(dx,dz,r) in enumerate(((-.036,.065,.034),(.039,-.050,.013))):
            patch('Shine'+str(side)+'_'+str(n),eb,side*.18+dx,.96+dz,r,r,shine,depth=.001)
        patch('Blush'+str(side),hb,side*.335,.81,.0475,.0225,blush,depth=.003)
    points=[]
    for i in range(21):
        t=i/20;x=-.033+.066*t;z=.789-.028*math.sin(math.pi*t)
        points.append((x,front(hb,x,z)-.007,z))
    stroke('Mouth',points,.005,ink)
    for name,co in {'Eyes':(0,-.35,.96),'Mouth':(0,-.35,.775),'Crown':(0,0,1.5),'Chest':(0,-.23,.39)}.items():
        ob=bpy.data.objects.new('v3_REFERENCE_'+name,None);scene.collection.objects.link(ob);ob.location=co;ob['concept_reference_only']=True
    for ob in created:
        ob.hide_render=False
        if ob.type=='MESH':
            for poly in ob.data.polygons:poly.use_smooth=True

# New scene lighting; Bear materials never replaced.
world=bpy.data.worlds.new('v3_NeutralWorld');world.use_nodes=True;world.node_tree.nodes['Background'].inputs['Color'].default_value=(*rgb('#DCE1DE'),1);world.node_tree.nodes['Background'].inputs['Strength'].default_value=.35;scene.world=world
for name,loc,power,size in [('Key',(-3,-4,5),160,4),('Fill',(4,-2,3),85,4),('Rim',(0,3,4),45,3)]:
    data=bpy.data.lights.new('v3_'+name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    ob=bpy.data.objects.new('v3_'+name,data);scene.collection.objects.link(ob);ob.location=loc;ob.rotation_euler=(Vector((0,0,.8))-ob.location).to_track_quat('-Z','Y').to_euler()
camdata=bpy.data.cameras.new('v3_Camera');cam=bpy.data.objects.new('v3_Camera',camdata);scene.collection.objects.link(cam);scene.camera=cam;camdata.type='ORTHO';camdata.ortho_scale=2.05
scene.render.threads_mode='FIXED';scene.render.threads=8
scene.render.engine='CYCLES';scene.cycles.samples=a.samples;scene.cycles.use_denoising=True
scene.render.resolution_x=scene.render.resolution_y=768;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=True
scene.view_settings.view_transform='Standard';scene.view_settings.look='None';scene.view_settings.exposure=0;scene.view_settings.gamma=1
scene.render.image_settings.color_mode='RGBA'
bpy.context.view_layer.update()
visible=[o for o in scene.objects if o.type=='MESH'and not o.hide_render]
assert created and visible and all(o in created for o in visible),'unexpected visible mesh'
if a.variant=='BEAR':assert len(visible)==16,('Bear base count',len(visible))
metadata={'source_sha256':SOURCE_SHA,'render_spec':{'revision':2,'samples':a.samples,'body_roughness':.46,'world_strength':.35,'lights':[160,85,45],'views':{'front':[0,-5,.95],'q':[3.6,-5,2],'side':[5,0,1]},'target':[0,0,.8],'color_transform':'Standard','exposure':0,'gamma':1,'ortho_scale':2.05},'variant':a.variant,'source':str(Path(bpy.data.filepath).resolve()),'production':False,'ortho_scale':2.05,'parts':[]}
for ob in created:
    if ob.type=='MESH':metadata['parts'].append({'name':ob.name,'vertices':len(ob.data.vertices),'triangles':sum(len(p.vertices)-2 for p in ob.data.polygons)})
for view,pos in [('front',(0,-5,.95)),('q',(3.6,-5,2)),('side',(5,0,1))]:
    cam.location=pos;cam.rotation_euler=(Vector((0,0,.8))-cam.location).to_track_quat('-Z','Y').to_euler()
    # All meshes keep authored scale. Camera-space framing is checked for every view.
    bpy.context.view_layer.update();inverse=cam.matrix_world.inverted()
    for ob in visible:
        for corner in ob.bound_box:
            point=inverse@(ob.matrix_world@Vector(corner))
            assert abs(point.x)<=1.025 and abs(point.y)<=1.025,(a.variant,view,ob.name,'camera crop',tuple(point))
    scene.render.filepath=str(OUT/'raw'/f'{a.variant}-{view}.png');bpy.ops.render.render(write_still=True)
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==SOURCE_SHA,'Source blend changed'
metadata['source_unchanged']=True
metadata['render_size']=768
(OUT/f'{a.variant}-metadata.json').write_text(json.dumps(metadata,indent=2),encoding='utf-8')
if a.variant!='BEAR':bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'blip-v3-{a.variant}.blend'),copy=True)
print('BLIP_V3_COMPLETE',a.variant,str(OUT))
