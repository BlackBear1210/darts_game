"""승인한 중간 로우폴리 시안의 독립적인 전신 모델과 검토 렌더를 만든다."""
from pathlib import Path
import math
import random
import json
import bpy
import bmesh
from mathutils import Vector

OUT = Path(__file__).resolve().parent
REFERENCE = OUT.parent / 'imagegen/character_midpoint_full_body_front_side_20261112_v02.png'
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
character = bpy.data.collections.new('CHARACTER_midpoint')
studio = bpy.data.collections.new('STUDIO')
scene.collection.children.link(character)
scene.collection.children.link(studio)


def linear(x):
    return x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4


def material(name, color, roughness=.84):
    color = color.lstrip('#')
    rgb = [linear(int(color[i:i+2], 16) / 255) for i in (0, 2, 4)]
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*rgb, 1)
    bsdf.inputs['Roughness'].default_value = roughness
    return mat


SKIN = material('skin_warm_peach', 'EEA36B')
SKIN_LIGHT = material('skin_light_plane', 'F0A76F')
SKIN_DARK = material('skin_soft_plane', 'E89B64')
EAR_INNER = material('ear_inner', 'CE8C60')
HAIR = material('hair_brown', '4D2818')
HAIR_LIGHT = material('hair_light_plane', '5B301D')
BROW = material('eyebrows_brown', '51301F')
EYE = material('eyes_cream', 'FFF7E7', .58)
PUPIL = material('pupils_brown', '35251D', .5)
MOUTH = material('mouth', '795036')
TOP = material('shirt_muted_purple', '652044')
TOP_LIGHT = material('shirt_light_plane', '6A2548')
PANTS = material('trousers_charcoal', '3C3838')
PANTS_LIGHT = material('trousers_light_plane', '413C3B')
SHOE = material('sneakers_dark', '39322E')
SOLE = material('sneakers_sole', 'E7DBBF')
LACES = material('laces', '4C423A')
FLOOR = material('studio_floor', 'D1C7BE')
LABEL = material('labels', '393531')


def put(obj, collection=character):
    for col in list(obj.users_collection):
        col.objects.unlink(obj)
    collection.objects.link(obj)
    return obj


def mesh(name, verts, faces, mat, collection=character, palette=()):
    data = bpy.data.meshes.new(name + '_mesh')
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    data.materials.append(mat)
    for m in palette:
        data.materials.append(m)
    for f in data.polygons:
        f.use_smooth = False
        if palette and f.index % 13 in (2, 9):
            f.material_index = 1 + f.index % len(palette)
    return obj


def ellipsoid(name, center, scale, mat, segments=14, rings=8, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=center)
    obj = put(bpy.context.object)
    obj.name = name
    obj.scale = scale
    obj.rotation_euler = rotation
    obj.data.materials.append(mat)
    for f in obj.data.polygons:
        f.use_smooth = False
    return obj


def tube(name, points, radii, mat, sides=10, palette=()):
    points = [Vector(p) for p in points]
    verts = []
    for i, p in enumerate(points):
        tangent = (points[min(i+1, len(points)-1)] - points[max(i-1, 0)]).normalized()
        helper = Vector((0, 1, 0)) if abs(tangent.y) < .9 else Vector((1, 0, 0))
        u = tangent.cross(helper).normalized()
        v = tangent.cross(u).normalized()
        for j in range(sides):
            a = 2 * math.pi * j / sides
            verts.append(tuple(p + radii[i] * (math.cos(a)*u + math.sin(a)*v)))
    faces = [tuple(range(sides-1, -1, -1))]
    for i in range(len(points)-1):
        for j in range(sides):
            k = (j+1) % sides
            faces.append((i*sides+j, i*sides+k, (i+1)*sides+k, (i+1)*sides+j))
    faces.append(tuple((len(points)-1)*sides+j for j in range(sides)))
    return mesh(name, verts, faces, mat, palette=palette)


def ring_body(name, levels, sides, mat, palette=(), triangulate=False):
    # levels: z, center_x, center_y, radius_x, front_depth, back_depth.
    verts = []
    for i, (z, cx, cy, rx, front, back) in enumerate(levels):
        for j in range(sides):
            a = math.tau*j/sides
            co = math.cos(a)
            verts.append((cx+rx*math.sin(a), cy-(front if co >= 0 else back)*co, z))
    faces = [tuple(range(sides-1, -1, -1))]
    for i in range(len(levels)-1):
        for j in range(sides):
            k=(j+1)%sides
            q=(i*sides+j, i*sides+k, (i+1)*sides+k, (i+1)*sides+j)
            if triangulate and (i+j)%3 == 0:
                faces.extend([(q[0],q[1],q[2]),(q[0],q[2],q[3])])
            else:
                faces.append(q)
    faces.append(tuple((len(levels)-1)*sides+j for j in range(sides)))
    return mesh(name, verts, faces, mat, palette=palette)


def bevel_box(name, location, dimensions, mat, bevel=.003, rotation=(0,0,0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj=put(bpy.context.object)
    obj.name=name
    obj.dimensions=dimensions
    obj.rotation_euler=rotation
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod=obj.modifiers.new('small_edge_planes','BEVEL')
        mod.width=bevel
        mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


# 머리: 기존에 가까운 윤곽을 유지하면서 면을 적당히 드러낸다.
head_levels = [
    (1.275,0,-.060,.058,.052,.050),
    (1.300,0,-.057,.083,.071,.065),
    (1.355,0,-.056,.103,.081,.084),
    (1.430,0,-.055,.116,.088,.096),
    (1.510,0,-.053,.126,.091,.101),
    (1.585,0,-.050,.123,.086,.100),
    (1.645,0,-.047,.106,.071,.091),
    (1.680,0,-.045,.052,.035,.048),
]
head=ring_body('head_face',head_levels,16,SKIN,(SKIN_LIGHT,SKIN_DARK),True)
for vertex in head.data.vertices:
    vertex.co.x *= 1.06
    # 앞면의 볼과 이마를 완만하게 펴서 원통처럼 보이는 인상을 줄인다.
    level=min(head_levels,key=lambda row:abs(row[0]-vertex.co.z))
    cy,depth=level[2],level[4]
    if vertex.co.y < cy and depth:
        fraction=max(0,min(1,(cy-vertex.co.y)/depth))
        vertex.co.y=cy-depth*fraction**.45
head['design']='approved midpoint: moderate facets, gentle jaw silhouette'

nose_verts=[(-.018,-.150,1.535),(.018,-.150,1.535),
            (-.025,-.207,1.397),(.025,-.207,1.397),
            (-.022,-.202,1.380),(.022,-.202,1.380),
            (-.027,-.143,1.383),(.027,-.143,1.383)]
mesh('nose_wedge',nose_verts,[(0,2,3,1),(2,4,5,3),(0,6,4,2),(1,3,5,7),(4,6,7,5),(0,1,7,6)],SKIN)

for sign, suffix in [(-1,'r'),(1,'l')]:
    x=sign*.064
    ellipsoid('eye_white_'+suffix,(x,-.153,1.532),(.044,.031,.046),EYE,20,12)
    ellipsoid('pupil_'+suffix,(x,-.184,1.530),(.007,.0024,.007),PUPIL,12,6)
    bevel_box('eyebrow_'+suffix,(sign*.065,-.148,1.592),(.071,.010,.013),BROW,.0015,
              (0,sign*.14,0))
    # 귀 윤곽과 안쪽을 나누어 편집할 수 있게 한다.
    contour=[(.004,.047),(.025,.050),(.040,.030),(.044,.002),
             (.036,-.030),(.013,-.046),(-.005,-.029),(-.012,.012)]
    outer=[(sign*(.139+u),-.062,1.493+z) for u,z in contour]
    inner=[(sign*(.139+u*.57),-.072,1.493+z*.57) for u,z in contour]
    back=[(sign*(.139+u*.88),-.029,1.493+z*.88) for u,z in contour]
    verts=outer+inner+back
    faces=[]
    for i in range(8):
        j=(i+1)%8
        faces.extend([(i,j,8+j,8+i),(i,16+i,16+j,j)])
    faces.append(tuple(16+i for i in reversed(range(8))))
    mesh('ear_'+suffix,verts,faces,SKIN)
    mesh('ear_inner_'+suffix,inner,[tuple(range(8))],EAR_INNER)

mesh('mouth_line',[(-.039,-.135,1.340),(0,-.139,1.338),(.039,-.135,1.340),
                   (-.038,-.1355,1.336),(0,-.1395,1.334),(.038,-.1355,1.336)],
     [(0,3,4,1),(1,4,5,2)],MOUTH)
tube('neck',[(0,.014,1.175),(0,-.015,1.250),(0,-.032,1.356)],
     [.052,.049,.048],SKIN,12)

# 흐름이 이어지는 넓은 머리카락 면과 앞머리. 둥근 덩어리의 반복은 피한다.
verts=[]
segs=24
for ring in range(6):
    t=ring/5
    for j in range(segs):
        a=math.tau*j/segs
        co=math.cos(a)
        base=1.625 if co>.3 else (1.545 if co>-.4 else 1.495)
        base += .010*math.sin(a*5+.5)
        z=base+(1.765-base)*math.sin(t*math.pi/2)
        rad=(math.cos(t*math.pi/2)*.99+.01)*(1+.035*math.sin(a*5+.7))
        verts.append((.151*math.sin(a)*rad,-.040-.120*co*rad,z))
faces=[]
for i in range(5):
    for j in range(segs):
        k=(j+1)%segs
        faces.append((i*segs+j,i*segs+k,(i+1)*segs+k,(i+1)*segs+j))
faces.append(tuple(5*segs+j for j in range(segs)))
mesh('hair_cap',verts,faces,HAIR,palette=(HAIR_LIGHT,))
locks=[
    [(-.055,-.112,1.712),(-.008,-.146,1.772),(.064,-.126,1.752),
     (.087,-.120,1.696),(.032,-.171,1.610),(-.010,-.166,1.671),
     (-.042,-.040,1.717),(.051,-.035,1.733),(.042,-.093,1.645)],
    [(-.144,-.077,1.644),(-.124,-.117,1.690),(-.046,-.142,1.743),
     (-.025,-.126,1.701),(-.079,-.166,1.660),(-.134,-.132,1.615),
     (-.129,-.023,1.648),(-.053,-.035,1.718)],
    [(.079,-.116,1.700),(.121,-.082,1.708),(.149,-.060,1.651),
     (.143,-.112,1.607),(.103,-.138,1.653),(.085,-.046,1.676)],
]
for i,points in enumerate(locks):
    data=bpy.data.meshes.new('hair_lock_%02d_mesh'%i)
    data.from_pydata(points,[],[])
    bm=bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.convex_hull(bm,input=list(bm.verts),use_existing_faces=False)
    bm.to_mesh(data)
    bm.free()
    obj=bpy.data.objects.new('hair_lock_%02d'%i,data)
    character.objects.link(obj)
    data.materials.append(HAIR)

# 아주 약한 라운드 숄더: 어깨만 약간 앞에 두고 골반과 발은 곧게 유지한다.
ring_body('shirt_body',[(.735,0,.014,.144,.078,.078),(.820,0,.016,.145,.080,.079),
          (.950,0,.013,.155,.087,.088),(1.075,0,.004,.174,.092,.095),
          (1.155,0,-.006,.177,.081,.094),(1.190,0,-.005,.060,.044,.044)],
          16,TOP,(TOP_LIGHT,),True)
# 襟の細い別パーツ。
ring_body('shirt_collar',[(1.181,0,-.006,.062,.046,.046),(1.197,0,-.006,.060,.044,.044)],12,TOP)
ring_body('trousers_hips',[(.684,0,.014,.124,.067,.075),(.772,0,.014,.136,.078,.080)],12,PANTS)

for sign,suffix in [(-1,'r'),(1,'l')]:
    shoulder=(sign*.125,-.017,1.090)
    sleeve_end=(sign*.190,-.026,1.005)
    elbow=(sign*.209,-.019,.866)
    wrist=(sign*.230,-.035,.685)
    tube('shirt_sleeve_'+suffix,[shoulder,(sign*.175,-.023,1.055),sleeve_end],
         [.071,.060,.054],TOP,12)
    tube('upper_arm_'+suffix,[(sign*.184,-.026,1.024),elbow],[.038,.033],SKIN,10)
    ellipsoid('elbow_'+suffix,elbow,(.033,.032,.034),SKIN,12,6)
    tube('forearm_'+suffix,[elbow,(sign*.223,-.029,.783),wrist],[.033,.031,.024],SKIN,10)
    # 손바닥과 손가락을 나눈다. 일반 손가락 4개와 엄지 1개다.
    ring_body('hand_palm_'+suffix,[(.688,sign*.230,-.035,.025,.018,.018),
              (.649,sign*.233,-.038,.032,.019,.019),(.617,sign*.233,-.036,.028,.017,.017)],
              10,SKIN)
    lengths=[.055,.069,.065,.050]
    for k,offset in enumerate([-.022,-.007,.008,.022]):
        x=sign*(.233+offset)
        z=.626-(.002 if k in (0,3) else 0)
        length=lengths[k]
        pts=[(x,-.037,z),(x+sign*.002,-.047,z-length*.53),
             (x+sign*.002,-.038,z-length)]
        tube('finger_%s_%d'%(suffix,k+1),pts,[.0085,.0077,.0061],SKIN,8)
        ellipsoid('fingertip_%s_%d'%(suffix,k+1),pts[-1],(.0062,.0061,.0065),SKIN,8,4)
    pts=[(sign*.207,-.038,.655),(sign*.192,-.050,.634),(sign*.189,-.060,.607)]
    tube('thumb_'+suffix,pts,[.012,.010,.008],SKIN,8)
    ellipsoid('thumb_tip_'+suffix,pts[-1],(.008,.008,.008),SKIN,8,4)
    ring_body('trouser_leg_'+suffix,[(.737,sign*.083,.014,.065,.070,.069),
         (.635,sign*.089,.015,.062,.064,.066),(.444,sign*.091,-.001,.052,.052,.056),
         (.397,sign*.091,-.003,.051,.052,.054),(.234,sign*.094,.008,.046,.045,.047),
         (.087,sign*.095,.012,.042,.042,.044)],12,PANTS,(PANTS_LIGHT,),True)
    # 신발 밑창과 갑피. 앞쪽은 -Y다.
    centerx=sign*.095
    outline=[(-.040,-.175),(.040,-.175),(.053,-.151),(.052,.059),
             (.038,.078),(-.038,.078),(-.052,.059),(-.053,-.151)]
    verts=[(centerx+x,y,z) for z in (.009,.032) for x,y in outline]
    faces=[tuple(reversed(range(8))),tuple(8+i for i in range(8))]
    faces += [(i,(i+1)%8,8+(i+1)%8,8+i) for i in range(8)]
    mesh('shoe_sole_'+suffix,verts,faces,SOLE)
    verts=[(centerx+x*.96,y*.98,.033) for x,y in outline]
    for x,y in outline:
        height=.067 if y<-.145 else (.102 if y>-.02 else .090)
        verts.append((centerx+x*.76,y*.94,height))
    faces=[tuple(reversed(range(8))),tuple(8+i for i in range(8))]
    faces += [(i,(i+1)%8,8+(i+1)%8,8+i) for i in range(8)]
    mesh('shoe_upper_'+suffix,verts,faces,SHOE)
    for k in range(3):
        lace_y=-.055-k*.020
        lace_z=.067+(lace_y+.165)/.24*.035+.002
        bevel_box('shoelace_%s_%d'%(suffix,k),(centerx,lace_y,lace_z),
                  (.056,.004,.003),LACES,.0006)

# 몸통과 소매를 실제로 이어 붙여 어깨 틈과 내부 겹침을 없앤다.
bpy.ops.object.select_all(action='DESELECT')
shirt_parts=[o for o in character.objects if o.name.startswith('shirt_')]
for obj in shirt_parts:obj.select_set(True)
bpy.context.view_layer.objects.active=shirt_parts[0]
bpy.ops.object.join()
shirt=bpy.context.object
shirt.name='shirt_connected'
remesh=shirt.modifiers.new('connected_fabric','REMESH')
remesh.mode='VOXEL'
remesh.voxel_size=.004
bpy.ops.object.modifier_apply(modifier=remesh.name)
smooth=shirt.modifiers.new('gentle_cloth_shape','SMOOTH')
smooth.factor=.9
smooth.iterations=12
bpy.ops.object.modifier_apply(modifier=smooth.name)
decimate=shirt.modifiers.new('moderate_polygon_planes','DECIMATE')
decimate.ratio=.08
bpy.ops.object.modifier_apply(modifier=decimate.name)
shirt.data.materials.clear()
shirt.data.materials.append(TOP)

# 기존 모델의 머리 실루엣을 중간 시안에 맞게 재사용하고, 편집 가능한 면으로 정리한다.
source=OUT.parents[1]/'다트-/art/characters/rigged/tripo_character.glb'
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(source))
imported=set(bpy.data.objects)-before
source_hair=next(o for o in imported if o.name=='tripo_part_2')
for obj in imported:
    if obj.type=='ARMATURE':
        obj.animation_data_clear()
        for bone in obj.pose.bones:bone.matrix_basis.identity()
bpy.context.view_layer.update()
evaluated=source_hair.evaluated_get(bpy.context.evaluated_depsgraph_get())
data=bpy.data.meshes.new_from_object(evaluated)
world=[source_hair.matrix_world@v.co for v in data.vertices]
lo=Vector(tuple(min(v[i] for v in world) for i in range(3)))
hi=Vector(tuple(max(v[i] for v in world) for i in range(3)))
center=(lo+hi)*.5
for vertex,co in zip(data.vertices,world):
    vertex.co=(-(co.x-center.x)*.90,-(co.y-center.y)*.72-.040,
               (co.z-lo.z)/(hi.z-lo.z)*.298+1.482)
for obj in list(character.objects):
    if obj.name.startswith('hair_'):bpy.data.objects.remove(obj,do_unlink=True)
hair=bpy.data.objects.new('hair_sculpted_midpoint',data)
character.objects.link(hair)
data.materials.clear()
data.materials.append(HAIR)
bpy.ops.object.select_all(action='DESELECT')
hair.select_set(True)
bpy.context.view_layer.objects.active=hair
mod=hair.modifiers.new('broad_lowpoly_locks','DECIMATE')
mod.ratio=.42
bpy.ops.object.modifier_apply(modifier=mod.name)
for obj in imported:bpy.data.objects.remove(obj,do_unlink=True)
for action in list(bpy.data.actions):
    if action.users==0:bpy.data.actions.remove(action)

# 원통의 생성 방향과 무관하게 닫힌 표면 법선을 밖으로 맞춘다.
for obj in character.objects:
    if obj.type!='MESH':continue
    bm=bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    for poly in obj.data.polygons:poly.use_smooth=False

# 모델의 출처와 용도를 Blender 파일 안에서도 확인할 수 있다.
info=bpy.data.texts.new('README_model')
info.write('DARTY approved midpoint character — standalone editable modeling draft.\n'
           'Z up; front = -Y; metres. Separate face, eyes, brows, hair, clothes, fingers and shoes.\n'
           'Forward head and extremely slight rounded shoulders are built into the neutral pose.\n'
           'No armature, animation or game integration in this draft.\n'
           'Reference: character_midpoint_full_body_front_side_20261112_v02.png\n')
if REFERENCE.exists():
    image=bpy.data.images.load(str(REFERENCE))
    image.pack()
    image.name='APPROVED_full_body_reference'
    image.use_fake_user=True


def studio_setup(scn,collection):
    scn.render.engine='BLENDER_EEVEE'
    scn.render.image_settings.file_format='PNG'
    scn.render.film_transparent=False
    scn.render.resolution_percentage=100
    scn.render.image_settings.color_mode='RGBA'
    scn.world=bpy.data.worlds.new(scn.name+'_world')
    scn.world.use_nodes=True
    scn.world.node_tree.nodes['Background'].inputs[0].default_value=(.80,.76,.71,1)
    scn.world.node_tree.nodes['Background'].inputs[1].default_value=.8
    scn.view_settings.view_transform='AgX'
    scn.view_settings.look='AgX - Medium High Contrast'
    for name,location,power,size in [('key',(-3,-4,5),500,4),('fill',(3,-2,3),180,3),('rim',(0,3,4),280,3)]:
        data=bpy.data.lights.new(scn.name+'_'+name,'AREA')
        data.energy=power
        data.shape='DISK'
        data.size=size
        obj=bpy.data.objects.new(data.name,data)
        collection.objects.link(obj)
        obj.location=location
        obj.rotation_euler=(Vector((0,0,1))-obj.location).to_track_quat('-Z','Y').to_euler()
    floor=mesh(scn.name+'_floor',[(-200,-200,0),(200,-200,0),(200,200,0),(-200,200,0)],[(0,1,2,3)],FLOOR,collection)
    floor.location.z=-.002


def camera(scn,collection,name,location,target,scale):
    data=bpy.data.cameras.new(name)
    data.type='ORTHO'
    data.ortho_scale=scale
    obj=bpy.data.objects.new(name,data)
    collection.objects.link(obj)
    obj.location=location
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
    scn.camera=obj
    return obj


studio_setup(scene,studio)
front=camera(scene,studio,'CAM_front',(0,-6,1.02),(0,0,.900),2.03)
side=camera(scene,studio,'CAM_side',(-6,0,1.02),(0,0,.900),2.03)
quarter=camera(scene,studio,'CAM_quarter',(-4,-6,2.10),(0,0,.94),2.06)
scene.render.resolution_x=1000
scene.render.resolution_y=1200
for cam,name in [(front,'front'),(side,'side'),(quarter,'three_quarter')]:
    scene.camera=cam
    scene.render.filepath=str(OUT/(name+'.png'))
    bpy.ops.render.render(write_still=True)
scene.camera=front

comparison=bpy.data.scenes.new('FRONT_AND_SIDE_review')
reviewstudio=bpy.data.collections.new('REVIEW_studio')
comparison.collection.children.link(reviewstudio)
studio_setup(comparison,reviewstudio)
for name,x,angle in [('front_instance',-.45,0),('side_instance',.45,math.pi/2)]:
    obj=bpy.data.objects.new(name,None)
    obj.instance_type='COLLECTION'
    obj.instance_collection=character
    reviewstudio.objects.link(obj)
    obj.location.x=x
    obj.rotation_euler.z=angle
cam=camera(comparison,reviewstudio,'CAM_comparison',(0,-6,1.0),(0,0,.88),2.25)
comparison.render.resolution_x=1500
comparison.render.resolution_y=1400
fontpath=Path('C:/Windows/Fonts/malgun.ttf')
font=bpy.data.fonts.load(str(fontpath)) if fontpath.exists() else None
for x,label in [(-.45,'정면' if font else 'FRONT'),(.45,'측면' if font else 'SIDE')]:
    data=bpy.data.curves.new('label_'+label,'FONT')
    data.body=label
    data.align_x='CENTER'
    data.size=.045
    if font:data.font=font
    obj=bpy.data.objects.new(data.name,data)
    reviewstudio.objects.link(obj)
    obj.location=(x,-1.9,.018)
    obj.rotation_euler.x=math.pi/2
    data.materials.append(LABEL)
comparison.render.filepath=str(OUT/'front_and_side.png')
bpy.ops.render.render(write_still=True,scene=comparison.name)

bpy.context.window.scene=scene
scene.camera=front
bpy.ops.object.select_all(action='DESELECT')
for obj in character.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active=head
bpy.ops.export_scene.gltf(filepath=str(OUT/'character_midpoint_v01.glb'),export_format='GLB',
                          use_selection=True,export_animations=False,export_cameras=False,
                          export_lights=False,export_apply=True)
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_distance=3.1
        area.spaces.active.region_3d.view_location=Vector((0,0,.91))
        area.spaces.active.clip_start=.01
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'character_midpoint_v01.blend'))
summary={'mesh_objects':len(character.objects),'vertices':sum(len(o.data.vertices) for o in character.objects if o.type=='MESH'),
         'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in character.objects if o.type=='MESH'),
         'height_metres':max((o.matrix_world @ v.co).z for o in character.objects if o.type=='MESH' for v in o.data.vertices),
         'reference':str(REFERENCE),'rigged':False,'game_model_modified':False}
(OUT/'model_report.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
print('MODEL_COMPLETE',json.dumps(summary))
