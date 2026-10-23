import bpy,bmesh,math,os,json
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
from mathutils.geometry import delaunay_2d_cdt
OUT=os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT,'before.blend'))
scene=bpy.context.scene
root=bpy.data.collections['CHARACTER_V07'];root.name='CHARACTER_V08'
skin=bpy.data.materials['Skin_WarmPeach'];inner=bpy.data.materials['Ear_Inner'];hairmat=bpy.data.materials['Hair_DeepChestnut']
browmat=bpy.data.materials['Brow_DarkBrown'];mouthmat=bpy.data.materials['Mouth_Umber']
def color(m,c):
    m.diffuse_color=(*c,1);next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Base Color'].default_value=(*c,1)
color(skin,(.75,.385,.195))
color(inner,(.67,.327,.170))
def remove(name):
    if name in bpy.data.objects:bpy.data.objects.remove(bpy.data.objects[name],do_unlink=True)
def mesh(name,v,f,mat,col):
    remove(name);me=bpy.data.meshes.new(name);me.from_pydata(v,[],f);me.update();ob=bpy.data.objects.new(name,me);bpy.data.collections[col].objects.link(ob);me.materials.append(mat)
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();return ob
section=[(0,-1),(.50,-.99),(.82,-.96),(1,-.72),(1,.08),(.77,.70),(.40,.94),(0,1),(-.40,.94),(-.77,.70),(-1,.08),(-1,-.72),(-.82,-.96),(-.50,-.99)]
def loft(name,rings,mat,col):
    n=len(section);v=[];f=[tuple(reversed(range(n)))]
    for z,rx,ry,cy,rise in rings:
        for x,y in section:v.append((x*rx,cy+y*ry,z+rise*max(0,(y+.55)/1.55)))
    for j in range(len(rings)-1):
        for i in range(n):a=j*n+i;b=j*n+(i+1)%n;f.append((a,b,b+n,a+n))
    f.append(tuple(range((len(rings)-1)*n,len(rings)*n)));return mesh(name,v,f,mat,col)
# Wider forehead/zygoma, a short chin bevel and a slightly projecting mouth plane.
body_section=section
section=[(0,-1),(.23,-.998),(.46,-.992),(.82,-.96),(1,-.72),(1,.08),(.77,.70),(.40,.94),(0,1),(-.40,.94),(-.77,.70),(-1,.08),(-1,-.72),(-.82,-.96),(-.46,-.992),(-.23,-.998)]
head_rings=[(4.10,.145,.242,-.108,.31),(4.20,.202,.271,-.080,.245),(4.31,.240,.300,-.068,.18),(4.43,.270,.326,-.060,.12),(4.55,.298,.339,-.040,.09),(4.58,.308,.342,-.031,.08),(4.61,.318,.344,-.021,.07),(4.80,.375,.366,.022,.02),(5.015,.420,.390,.043,0),(5.105,.425,.397,.047,0),(5.205,.425,.400,.051,0),(5.405,.355,.362,.055,0),(5.54,.245,.255,.080,0),(5.59,.04,.045,.085,0)]
for j,(z,rx,ry,cy,rise) in enumerate(head_rings):
    if 4.43<z<4.80:
        t=(z-4.43)/.37
        head_rings[j]=(z,.270+.105*t,.326+.040*t,-.060+.082*t,.12-.10*t)
head=loft('Head_Master',head_rings,skin,'01_BODY')
attachment_bvh=BVHTree.FromPolygons([v.co.copy() for v in head.data.vertices],[list(p.vertices) for p in head.data.polygons])
# The nose grows out of the same surface as the forehead and cheeks.
nose_sections={4.55:(.073,-.380),4.58:(.055,-.584),4.61:(.070,-.590),4.80:(.0592,-.49899),5.015:(.047,-.396),5.105:(.058,-.353)}
for j,(z,rx,ry,cy,rise) in enumerate(head_rings):
    if z in nose_sections:
        width,depth=nose_sections[z]
        for k,sgn in [(0,0),(1,1),(15,-1)]:
            v=head.data.vertices[j*len(section)+k];v.co.x=width*sgn;v.co.y=depth;v.co.z=z
        wall_width={4.55:.115,4.58:.115,4.61:.115,4.80:.120,5.015:.105,5.105:.125}[z]
        for k,sgn in [(2,1),(14,-1)]:head.data.vertices[j*len(section)+k].co.x=sgn*wall_width
bm=bmesh.new();bm.from_mesh(head.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(head.data);bm.free()
section=body_section
remove('Nose')
bvh=BVHTree.FromPolygons([v.co for v in head.data.vertices],[list(p.vertices) for p in head.data.polygons])
def front_y(x,z,offset=.005):
    hit=attachment_bvh.ray_cast(Vector((x,-2,z)),Vector((0,1,0)))
    return hit[0].y-offset if hit[0] is not None else -.30
loft('Neck',[(3.84,.283,.191,.185,0),(4.05,.260,.181,.148,0),(4.24,.210,.160,.102,0),(4.57,.140,.137,.030,0)],skin,'01_BODY')
for s,side in [(-1,'L'),(1,'R')]:
    # A shallow asymmetric ear fold, not a uniform hexagonal ring.
    outline=[(.367,4.930),(.428,4.969),(.503,4.945),(.548,4.877),(.547,4.795),(.506,4.716),(.446,4.679),(.399,4.697),(.363,4.770)]
    ev=[(s*x,-.045,z) for x,z in outline]
    ev +=[(s*(.445+(x-.445)*.68),-.060,4.838+(z-4.825)*.65) for x,z in outline]
    ev +=[(s*(.445+(x-.445)*.40),-.019,4.835+(z-4.825)*.44) for x,z in outline]
    ev +=[(s*x,.027,z) for x,z in outline]
    n=len(outline);ef=[]
    for j in range(2):
        for i in range(n):ef.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    ef.append(tuple(range(2*n,3*n)))
    for i in range(n):ef.append((i,3*n+i,3*n+(i+1)%n,(i+1)%n))
    ef.append(tuple(reversed(range(3*n,4*n))))
    ear=mesh('Ear.'+side,ev,ef,skin,'01_BODY');ear.data.materials.append(inner)
    for p in ear.data.polygons:
        if n<=p.index<2*n and p.index%n in [0,1,2,3,4]:p.material_index=1
    pivot=Vector((s*.435,0,4.825));rot=Matrix.Rotation(s*math.radians(55),3,'Z')
    for v in ear.data.vertices:
        v.co.x=s*.435+(v.co.x-s*.435)*1.6
        v.co=pivot+rot@(v.co-pivot)
        v.co.x-=s*.020;v.co.y+=.04
        v.co.z=4.795+(v.co.z-4.825)*1.19
        v.co.z+=.050*max(0,min(1,(v.co.z-4.68)/.28))
    # A shallow convex eye with a broad front plane and a faceted peripheral bevel.
    cz=4.982-(.008 if s==1 else 0);cx=s*.230
    ev=[];ef=[];n=18
    for radius,y in [(1,-.378),(1.015,-.402),(.90,-.432),(.65,-.443)]:
        for i in range(n):
            a=math.tau*i/n;ev.append((cx+.110*radius*math.cos(a),y,cz+.1116*radius*math.sin(a)))
    for j in range(3):
        for i in range(n):ef.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    ef.append(tuple(range(3*n,4*n)));ef.append(tuple(reversed(range(n))))
    eye=mesh('Eye.'+side,ev,ef,bpy.data.materials['Eye_Ivory'],'02_FACE')
    for p in eye.data.polygons:p.use_smooth=True
    pupil=bpy.data.objects['Pupil.'+side];pupil.location.y=-.445;pupil.location.z=cz-.002
    v=[]
    for ring in range(2):
        for i in range(14):
            a=math.tau*i/14;rx,rz=(.150,.148) if ring==0 else (.109,.111)
            x=cx+math.cos(a)*rx;z=cz+math.sin(a)*rz
            y=front_y(x,z,-.002) if ring==0 else -.385+max(0,abs(x)-.29)*.36
            v.append((x,y,z))
    socket=mesh('EyeSocket.'+side,v,[(i,(i+1)%14,(i+1)%14+14,i+14) for i in range(14)],skin,'02_FACE')
    bv=[]
    for k in range(25):
        x=.100+.253*k/24;z=5.181-.020*abs((x-.20)/.153)-(.008 if s==1 else 0)
        for zz in [z-.011,z+.011]:bv.append((s*x,front_y(s*x,zz,.008),zz))
    mesh('Brow.'+side,bv,[(2*i,2*i+1,2*i+3,2*i+2) for i in range(24)],browmat,'02_FACE')
# A wider root and narrow lower bevel avoid the previous rectangular nose-end block.
nv=[(-.052,-.319,5.185),(.052,-.319,5.185),(-.047,-.396,5.025),(.047,-.396,5.025),(-.086,-.621,4.602),(.086,-.621,4.602),(-.064,-.616,4.581),(.064,-.616,4.581),(-.077,-.346,4.551),(.077,-.346,4.551),(-.145,-.326,4.800),(.145,-.326,4.800)]
# The integrated head surface above replaces the old separate nose object.
mv=[]
for i in range(25):
    x=-.145+.290*i/24;z=4.418-.010*(x/.145)**2-.002*x/.145
    thickness=.0035+.0025*max(0,1-abs(x)/.145)
    for dz in [-thickness,thickness]:mv.append((x,front_y(x,z+dz,.006),z+dz))
mesh('Mouth',mv,[(2*i,2*i+1,2*i+3,2*i+2) for i in range(24)],mouthmat,'02_FACE')
# Chin plane is a subtle broad facet, like the reference's small lower-lip/chin patch.
chinmat=bpy.data.materials.new('Chin_Plane');chinmat.use_nodes=True;color(chinmat,(.725,.365,.181))
mesh('Chin_SubtleFacet',[(-.081,front_y(-.081,4.34,.001),4.34),(.081,front_y(.081,4.34,.001),4.34),(.070,front_y(.070,4.28,.001),4.28),(-.070,front_y(-.070,4.28,.001),4.28)],[(0,1,2,3)],chinmat,'02_FACE')

# Front hair locks are traced explicitly, then connected to a triangulated rear volume.
for ob in list(bpy.data.collections['03_HAIR'].objects):bpy.data.objects.remove(ob,do_unlink=True)
P=[(-.395,-.22,4.88),(-.485,-.13,5.08),(-.525,-.085,5.27),(-.475,-.14,5.42),(-.30,-.21,5.56),(-.235,-.20,5.55),(-.205,-.20,5.69),(.085,-.20,5.63),(.19,-.16,5.68),(.34,-.12,5.57),(.47,-.07,5.52),(.515,-.035,5.37),(.56,-.005,5.32),(.465,-.08,5.22),(.515,-.025,5.12),(.395,-.20,4.88)]
Q=[P[0],(-.375,-.26,5.08),(-.37,-.30,5.28),(-.31,-.35,5.41),(-.25,-.37,5.45),(-.19,-.39,5.43),(-.095,-.42,5.42),(-.025,-.45,5.29),(.045,-.445,5.32),(.095,-.42,5.47),(.21,-.38,5.42),(.30,-.34,5.38),(.365,-.30,5.32),(.38,-.27,5.22),(.375,-.25,5.06),P[-1]]
Q[7]=(-.025,-.43,5.34);Q[8]=(.045,-.425,5.37)
R=[]
for i,(x,y,z) in enumerate(P):
    R.append((x*.94,.16+.18*max(0,1-abs(x)/.56),z+(.015 if i not in [0,15] else .015)))
# The silhouette's high points belong to the crown, behind the lower front locks.
for i,drop in [(4,.025),(5,.025),(6,.095),(7,.065),(8,.075),(9,.025),(10,.015)]:
    x,y,z=P[i];P[i]=(x,y,z-drop)
bottom=[(.355,.245,4.745),(.265,.325,4.615),(.195,.335,4.535),(.130,.350,4.505),(.065,.360,4.54),(-.015,.365,4.49),(-.100,.350,4.53),(-.185,.335,4.50),(-.275,.300,4.62),(-.360,.240,4.75)]
hv=[Vector(v) for v in P+Q+R+bottom];hf=[]
for i in range(15):
    face=(i,i+1,16+i+1,16+i)
    if i in [1,2,9,11,13]:hf.extend([(face[0],face[1],face[3]),(face[1],face[2],face[3])])
    else:hf.append(face)
    quad=(i,32+i,32+i+1,i+1)
    center=sum((hv[k] for k in quad),Vector())*.25
    center.z+=.025*math.sin(i*1.7);center.x+=math.copysign(.018,center.x)
    ci=len(hv);hv.append(center)
    hf.extend([(quad[k],quad[(k+1)%4],ci) for k in range(4)])
outline=list(range(32,58))
backpoints=[(-.29,5.30),(-.08,5.44),(.16,5.41),(.34,5.28),(-.35,5.10),(-.14,5.19),(.10,5.21),(.32,5.04),(-.28,4.88),(-.04,4.98),(.18,4.87),(-.12,4.72),(.10,4.68)]
input3=[hv[i].copy() for i in outline]
for i,(x,z) in enumerate(backpoints):
    y=.575-.18*(x/.50)**2-.13*((z-5.12)/.65)**2+.023*math.sin(i*2.3)
    input3.append(Vector((x,y,z)))
cdt=delaunay_2d_cdt([Vector((p.x,p.z)) for p in input3],[],[list(range(len(outline)))],1,1e-6,True)
mapping=[]
for p,orig in zip(cdt[0],cdt[3]):
    if orig and orig[0]<len(outline):mapping.append(outline[orig[0]])
    else:
        v=input3[orig[0]] if orig else Vector((p.x,.51,p.y));mapping.append(len(hv));hv.append(v)
for f in cdt[2]:hf.append(tuple(mapping[i] for i in f))
hair=mesh('Hair_ConnectedSculptedLocks',hv,hf,hairmat,'03_HAIR')
bm=bmesh.new();bm.from_mesh(hair.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0001);bm.to_mesh(hair.data);bm.free()
# Minimal outward fitting only where a flat hair face cuts through the skull.
for _ in range(15):
    corr={}
    for f in hair.data.polygons:
        ids=list(f.vertices);pts=[hair.data.vertices[i].co.copy() for i in ids]
        for p in pts+[sum(pts,Vector())/len(pts)]+[(pts[k]+pts[(k+1)%len(pts)])*.5 for k in range(len(pts))]:
            near,no,_,_=bvh.find_nearest(p);gap=(p-near).dot(no)
            if gap<.012:
                for i in ids:corr.setdefault(i,[]).append(no*min(.04,.012-gap))
    if not corr:break
    for i,vals in corr.items():hair.data.vertices[i].co+=sum(vals,Vector())/len(vals)*.8
bm=bmesh.new();bm.from_mesh(hair.data);edge=[e for e in bm.edges if e.is_boundary];copies={}
for v in set(v for e in edge for v in e.verts):
    near,no,_,_=bvh.find_nearest(v.co);copies[v]=bm.verts.new(near-no*.02)
for e in edge:
    a,b=e.verts
    try:bm.faces.new((b,a,copies[a],copies[b]))
    except ValueError:pass
bmesh.ops.holes_fill(bm,edges=[e for e in bm.edges if e.is_boundary],sides=0);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(hair.data);bm.free()
for k,mul in enumerate([.91,1.04,1.10]):
    m=hairmat.copy();m.name='HandDesigned_HairTone_'+str(k);color(m,tuple(c*mul for c in (.053,.024,.014)));hair.data.materials.append(m)
for p in hair.data.polygons:p.material_index=[0,0,0,1,0,2,0,3][(p.index*5+p.index//8)%8]

# Flared neck base and a larger, lower rounded collar opening.
shirt=bpy.data.objects['TShirt_Plum']
for i in [18,19,20,21,40,41,42,43]:
    v=shirt.data.vertices[i];v.co.y=.005+(v.co.y-.005)*.82
for i in [15,16,17,37,38,39,44,45,46,47]:
    v=shirt.data.vertices[i];v.co.x*=1.30;v.co.z-=.045
# The middle chest vertex must stay below the opening; otherwise its face covers the neck.
shirt.data.vertices[13].co.z=3.76
for i in [15,17]:
    shirt.data.vertices[i].co.x=math.copysign(.260,shirt.data.vertices[i].co.x)
    shirt.data.vertices[i].co.z=4.11
for i in [12,14,34,36]:shirt.data.vertices[i].co.z=4.02
shirt.data.vertices[16].co.z=3.94
for i in [44,47]:
    shirt.data.vertices[i].co.x=math.copysign(.26,shirt.data.vertices[i].co.x)
    shirt.data.vertices[i].co.z=4.02
for i in [45,46]:
    shirt.data.vertices[i].co.x=math.copysign(.15,shirt.data.vertices[i].co.x)
    shirt.data.vertices[i].co.z=3.95
# A bevel at broad sewn panel transitions, before the fabric thickness modifier.
bev=shirt.modifiers.new('Soft garment corners','BEVEL');bev.width=.035;bev.segments=1
bev.limit_method='ANGLE';bev.angle_limit=.60
bpy.context.view_layer.objects.active=shirt
while list(shirt.modifiers).index(bev)>0:bpy.ops.object.modifier_move_up(modifier=bev.name)
# Subtle knee break in the trouser planes.
pants=bpy.data.objects['Trousers']
for v in pants.data.vertices:
    if v.co.y<-.05:
        v.co.y-=.010*max(0,1-abs(v.co.z-1.38)/.17)
for side in ['L','R']:
    ob=bpy.data.objects['Shoe.'+side];be=ob.modifiers.new('Softened shoe edge','BEVEL');be.width=.023;be.segments=1;be.limit_method='ANGLE';be.angle_limit=.45
    # Quiet hand planes and a narrower palm depth.
    hand=bpy.data.objects['Hand.'+side]
    for v in hand.data.vertices:
        t=max(0,1-abs(v.co.z-2.25)/.22);v.co.y=-.022+(v.co.y+.022)*(1-.10*t)
# Reference side view places the torso behind the head, not directly under it.
for collection in ['04_TSHIRT','05_TROUSERS','06_SHOES']:
    for ob in bpy.data.collections[collection].objects:ob.location.y+=.17
for ob in bpy.data.collections['01_BODY'].objects:
    if ob.name.startswith(('Arm.','Hand.')):ob.location.y+=.17
for ob in bpy.data.collections['07_SOCKETS'].objects:
    if 'Hand.' in ob.name:ob.location.y+=.17
scene['detail_pass']='V08: traced forelock, wider forehead and cheek planes, flared leaning neck, shallow asymmetric ears, smaller higher eyes, finer nose end, garment corners, knee break, softened shoes.'
scene.camera=bpy.data.objects['Camera_Front'];scene.render.resolution_x=1000;scene.render.resolution_y=1500
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'character_reference_hair.blend'))
# Native close-up inspections, no image synthesis or painted replacement.
cam=bpy.data.objects['Camera_Face']
scene.render.resolution_x=600;scene.render.resolution_y=760;scene.cycles.samples=12
for name,loc in [('front',(0,-10,4.89)),('side',(-10,0,4.89)),('quarter',(5,-10,4.89))]:
    cam.location=loc;cam.rotation_euler=(Vector((0,0,4.89))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=2.02;scene.camera=cam
    scene.render.filepath=os.path.join(OUT,'detail_'+name+'.png');bpy.ops.render.render(write_still=True)
print('DETAIL_PASS_READY',flush=True)
