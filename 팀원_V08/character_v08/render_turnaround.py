import bpy,os,math,json,bmesh,sys
from mathutils import Vector,Matrix
OUT=os.path.dirname(os.path.abspath(__file__))
SOURCE=os.path.join(OUT,'character_reference_hair.blend')
bpy.ops.wm.open_mainfile(filepath=SOURCE)
s=bpy.context.scene
def audit(o):
    bm=bmesh.new();bm.from_mesh(o.data);remaining=set(bm.verts);components=0
    while remaining:
        components+=1;stack=[remaining.pop()]
        while stack:
            v=stack.pop()
            for e in v.link_edges:
                q=e.other_vert(v)
                if q in remaining:remaining.remove(q);stack.append(q)
    result={'vertices':len(bm.verts),'faces':len(bm.faces),'components':components,'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges)}
    bm.free();return result
report={'head':audit(bpy.data.objects['Head_Master']),'hair':audit(bpy.data.objects['Hair_ConnectedSculptedLocks']),'hands':{side:audit(bpy.data.objects['Hand.'+side]) for side in ['L','R']},'rigged':False,'views':['FRONT','LEFT SIDE','BACK','3/4'],'reference':'User-supplied turnaround drawing','pixel_identical':False}
with open(os.path.join(OUT,'validation.json'),'w',encoding='utf-8') as f:json.dump(report,f,indent=2)
refpath=os.path.join(OUT,'reference.png')
ref=bpy.data.images.load(refpath,check_existing=True);ref.pack();ref.use_fake_user=True;ref.name='USER_REFERENCE_TURNAROUND'
notes=bpy.data.texts.new('ABOUT_THIS_MODEL');notes.write('Model reconstructed as editable 3D geometry from the supplied drawing.\nShared body, separate hair, shirt, trousers, shoes, accessory sockets.\nActual camera renders, not painted replacements.\nNo armature or production UVs yet.\nA single drawing does not determine identical hidden geometry; this reconstruction has visible differences.\nReference image is packed in USER_REFERENCE_TURNAROUND.\n')
s.camera=bpy.data.objects['Camera_Front'];s.render.resolution_x=1100;s.render.resolution_y=1500;s.cycles.samples=32
for screen in bpy.data.screens:
    for a in screen.areas:
        if a.type=='VIEW_3D':
            a.spaces.active.region_3d.view_perspective='CAMERA';a.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=SOURCE)
for ob in list(bpy.data.collections['03_HAIR'].objects):ob.hide_render=True;ob.hide_set(True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'character_bald.blend'))
bpy.ops.wm.open_mainfile(filepath=SOURCE);s=bpy.context.scene
originals=[o for c in bpy.data.collections['CHARACTER_V08'].children if c.name!='STUDIO' for o in c.objects]
display=bpy.data.collections.new('TURNAROUND_PRESENTATION');s.collection.children.link(display)
def copy_group(name,transform,crop=None):
    for src in originals:
        if src.hide_render or src.type!='MESH':continue
        ob=src.copy();ob.name=name+'__'+src.name;display.objects.link(ob);ob.hide_set(False)
        if crop is None:ob.matrix_world=transform@src.matrix_world
        else:
            ob.data=src.data.copy();ob.data.transform(src.matrix_world)
            bm=bmesh.new();bm.from_mesh(ob.data)
            bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=(0,0,crop),plane_no=(0,0,1),clear_inner=True,clear_outer=False)
            bm.to_mesh(ob.data);bm.free()
            if not len(ob.data.vertices):bpy.data.objects.remove(ob,do_unlink=True);continue
            ob.matrix_world=transform
for name,x,a in [('FRONT',2.63,0),('LEFT_SIDE',6.00,math.pi/2),('BACK',9.34,math.pi),('THREE_QUARTER',13.10,-math.radians(25))]:
    copy_group(name,Matrix.Translation((x,0,4.43))@Matrix.Rotation(a,4,'Z'))
for name,x,a in [('FACE_FRONT',3.58,0),('FACE_LEFT_SIDE',7.64,math.pi/2),('FACE_THREE_QUARTER',12.05,-math.radians(25))]:
    copy_group(name,Matrix.Translation((x,0,.99))@Matrix.Rotation(a,4,'Z')@Matrix.Diagonal((1.90,1.90,1.90,1))@Matrix.Translation((0,0,-4.10)),3.90)
for o in originals:o.hide_render=True;o.hide_set(True)
def emission(name,c):
    m=bpy.data.materials.new(name);m.use_nodes=True;nodes=m.node_tree.nodes;nodes.clear();e=nodes.new('ShaderNodeEmission');e.inputs['Color'].default_value=(*c,1);out=nodes.new('ShaderNodeOutputMaterial');m.node_tree.links.new(e.outputs[0],out.inputs['Surface']);return m
def mesh(name,v,f,m):
    me=bpy.data.meshes.new(name);me.from_pydata(v,[],f);me.update();o=bpy.data.objects.new(name,me);display.objects.link(o);me.materials.append(m);return o
paper=emission('Paper',(.525,.525,.525));ink=emission('Ink',(.092,.096,.105));guide=emission('Guides',(.43,.43,.43))
mesh('Backdrop',[(-5,2.5,-3),(21,2.5,-3),(21,2.5,14),(-5,2.5,14)],[(0,1,2,3)],paper)
v=[];f=[]
for z in [9.92,8.59,7.75,7.06,6.06,5.39,4.61]:
    x=.21
    while x<15.14:
        j=len(v);v.extend([(x,2.3,z-.003),(x+.075,2.3,z-.003),(x+.075,2.3,z+.003),(x,2.3,z+.003)]);f.append((j,j+1,j+2,j+3));x+=.12
mesh('DashedGuidelines',v,f,guide)
def label(text,x,z):
    d=bpy.data.curves.new('Label_'+text,'FONT');d.body=text;d.size=.185;d.align_x='CENTER';d.space_character=1.1
    o=bpy.data.objects.new(d.name,d);display.objects.link(o);o.location=(x,-2,z);o.rotation_euler=(math.pi/2,0,0);d.materials.append(ink)
for txt,x in [('FRONT',2.63),('LEFT SIDE',6),('BACK',9.34),('3/4',13.1)]:label(txt,x,4.19)
for txt,x in [('FRONT',3.58),('LEFT SIDE',7.64),('3/4',12.05)]:label(txt,x,.34)
for ob in bpy.data.collections['STUDIO'].objects:
    if ob.type=='LIGHT':ob.hide_render=True
def sun(name,loc,power,color):
    d=bpy.data.lights.new(name,'SUN');d.energy=power;d.angle=.60;d.color=color
    o=bpy.data.objects.new(name,d);display.objects.link(o);o.location=loc;o.rotation_euler=(-Vector(loc)).to_track_quat('-Z','Y').to_euler()
sun('Sheet_Key',(-5,-8,10),2.10,(1,.95,.90));sun('Sheet_Fill',(6,-4,6),.465,(.95,.97,1))
next(n for n in s.world.node_tree.nodes if n.type=='BACKGROUND').inputs['Strength'].default_value=.85
d=bpy.data.cameras.new('Camera_Turnaround');cam=bpy.data.objects.new(d.name,d);display.objects.link(cam)
def aim(loc,scale):
    cam.location=loc;cam.rotation_euler=(math.pi/2,0,0);cam.data.type='ORTHO';cam.data.ortho_scale=scale;s.camera=cam
def render(name,w,h,samples):
    s.render.resolution_x=w;s.render.resolution_y=h;s.render.resolution_percentage=100;s.cycles.samples=samples;s.render.filepath=os.path.join(OUT,name);bpy.ops.render.render(write_still=True)
aim((7.68,-30,5.12),15.36)
if '--preview' in sys.argv:
    render('turnaround_draft.png',1536,1024,12)
    print('SHEET_PREVIEW_READY',flush=True)
    sys.exit(0)
render('turnaround.png',2304,1536,32)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'turnaround_scene.blend'))
hair_copies=[ob for ob in display.objects if '__Hair_' in ob.name]
for ob in hair_copies:ob.hide_render=True
render('turnaround_bald.png',2304,1536,24)
for ob in hair_copies:ob.hide_render=False
# Four separate frames, rendered directly by Blender from the same presentation geometry.
for name,x,prefix in [('front',2.63,'FRONT__'),('left_side',6.0,'LEFT_SIDE__'),('back',9.34,'BACK__'),('three_quarter',13.1,'THREE_QUARTER__')]:
    for ob in display.objects:
        if ob.name.startswith('Label_') or ob.name=='DashedGuidelines':ob.hide_render=True
        elif '__' in ob.name:ob.hide_render=not ob.name.startswith(prefix)
    aim((x,-30,7.31),6.1)
    render(name+'.png',1100,1500,24)
print('TURNAROUND_COMPLETE',flush=True)
