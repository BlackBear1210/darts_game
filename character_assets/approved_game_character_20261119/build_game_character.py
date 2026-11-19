"""승인 리깅을 균일 배치하고 기존 게임의 뼈/추가 동작 계약과 연결한다."""
import bpy,math,json,hashlib
from pathlib import Path
from mathutils import Matrix,Vector,Quaternion
import numpy as np
HERE=Path(__file__).parent;ROOT=HERE.parents[1];PROJECT=ROOT/'다트-';OUT=ROOT/'output/character_nude_base_20261116/game_apply_20261119';SOURCE=ROOT/'character_assets/approved_rig_20261119/character_source.blend';LEGACY=ROOT/'output/character_nude_base_20261116/game_apply_20261118/character_game_rig.blend'
OUT.mkdir(exist_ok=True);bpy.ops.wm.open_mainfile(filepath=str(SOURCE));scene=bpy.context.scene;scene.render.fps=24;rig=bpy.data.objects['Character_Rig'];rig.animation_data.action=None
for track in rig.animation_data.nla_tracks:track.mute=True
for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update()
parts={n:bpy.data.objects[s] for s,n in [('Body_RiggedOutfit','Body'),('Tshirt_Rigged','Top_01'),('Trousers_Rigged','Bottom_01'),('Shoes_Rigged','Shoes_01')]};approved={n:bpy.data.actions[n] for n in ['Walk','Sit_Down','Sit_Idle','Stand_Up']}
def use(o,act):
 o.animation_data.action=act
 if act is not None and act.slots:o.animation_data.action_slot=act.slots[0]
def points(o):
 ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh();p=[v.co.copy() for v in me.vertices];ev.to_mesh_clear();return p
cases=[('Walk',0),('Walk',6),('Walk',12),('Walk',18),('Walk',24),('Sit_Down',0),('Sit_Down',24),('Sit_Down',48)];expected={}
for clip,frame in cases:
 use(rig,approved[clip]);scene.frame_set(frame);bpy.context.view_layer.update();expected[(clip,frame)]={n:points(o) for n,o in parts.items()}
use(rig,None)
for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update()
floor=min(v.co.z for v in parts['Shoes_01'].data.vertices);top=max(v.co.z for v in parts['Body'].data.vertices);scale=1.8/(top-floor)
T=Matrix.Translation((0,0,-floor*scale))@Matrix.Rotation(math.pi/2,4,'Z')@Matrix.Scale(scale,4)@Matrix.Translation((.047,0,0));R=Matrix.Rotation(math.pi/2,3,'Z');rest_errors={};uv_errors={}
for n,o in parts.items():
 old=[v.co.copy() for v in o.data.vertices];uv=np.empty(len(o.data.uv_layers.active.data)*2,dtype=np.float32) if o.data.uv_layers.active else None
 if uv is not None:o.data.uv_layers.active.data.foreach_get('uv',uv)
 normals=[R@v.vector for v in o.data.corner_normals];o.data.transform(T);o.data.normals_split_custom_set(normals);o.name=n
 rest_errors[n]=max((T.inverted()@v.co-p).length for v,p in zip(o.data.vertices,old))
 if uv is not None:
  after=np.empty_like(uv);o.data.uv_layers.active.data.foreach_get('uv',after);uv_errors[n]=float(np.max(np.abs(after-uv)))
rig.data.transform(T)
for act in approved.values():
 for layer in act.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for fc in bag.fcurves:
     if fc.data_path.endswith('.location'):
      for key in fc.keyframe_points:key.co.y*=scale;key.handle_left.y*=scale;key.handle_right.y*=scale
bpy.context.view_layer.update();core=set(rig.data.bones.keys())
with bpy.data.libraries.load(str(LEGACY),link=False) as (src,dst):dst.objects=['Character_Rig']
old=dst.objects[0];scene.collection.objects.link(old);legacy_actions={t.name:s.action for t in old.animation_data.nla_tracks for s in t.strips}
for n,act in legacy_actions.items():act.name='LEGACY_SOURCE_'+n
old.animation_data.action=None
for track in old.animation_data.nla_tracks:track.mute=True
for b in old.pose.bones:b.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update();old_rest={b.name:b.matrix_local.copy() for b in old.data.bones}
# 승인22뼈대의 구조는 유지하고 게임 손가락/소켓용 보조 뼈만 추가한다. 새 메시 가중치는 변경하지 않는다.
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
extra=[]
for ob in old.data.bones:
 if ob.name in core:continue
 anchor=ob.parent
 while anchor and anchor.name not in core:anchor=anchor.parent
 assert anchor is not None
 nb=rig.data.edit_bones.new(ob.name);base=rig.data.edit_bones[anchor.name];ratio=base.length/old.data.bones[anchor.name].length;relative=old_rest[anchor.name].inverted()@ob.matrix_local
 nb.head=base.matrix@ (relative.translation*ratio);q=base.matrix.to_quaternion()@relative.to_quaternion();nb.tail=nb.head+q@Vector((0,max(.002,ob.length*ratio),0));nb.parent=rig.data.edit_bones[ob.parent.name];nb.use_connect=False;nb.use_deform=False;extra.append(nb.name)
bpy.ops.object.mode_set(mode='OBJECT');bpy.context.view_layer.update();bone_names=list(rig.data.bones.keys());B={b.name:b.matrix_local.copy() for b in rig.data.bones};local={n:(B[rig.data.bones[n].parent.name].inverted()@B[n] if rig.data.bones[n].parent else B[n]) for n in bone_names}
for b in rig.pose.bones:b.rotation_mode='QUATERNION'
# 기존 팔 레이어가 읽을 수 있도록 승인 동작에도 보조 뼈의 정지 트랙을 넣는다.
for act in approved.values():
 use(rig,act)
 for frame in [act.frame_range[0],act.frame_range[1]]:
  for n in extra:
   pb=rig.pose.bones[n];pb.location=(0,0,0);pb.rotation_quaternion=(1,0,0,0);pb.scale=(1,1,1)
   for p in ['location','rotation_quaternion','scale']:pb.keyframe_insert(p,frame=frame,group=n)
primary_errors={}
for key,rec in expected.items():
 clip,frame=key;use(rig,approved[clip]);scene.frame_set(frame);bpy.context.view_layer.update();primary_errors[clip+':'+str(frame)]=max(max((p-(T@q)).length for p,q in zip(points(parts[n]),before)) for n,before in rec.items())
assert max(primary_errors.values())<.00001,primary_errors
print('APPROVED_MOTIONS_PRESERVED',max(primary_errors.values()),flush=True)
def snapshot():return {b.name:(b.location.copy(),b.rotation_quaternion.copy(),b.scale.copy()) for b in rig.pose.bones}
def apply(values):
 for n,(l,q,s) in values.items():pb=rig.pose.bones[n];pb.location=l;pb.rotation_quaternion=q;pb.scale=s
use(rig,approved['Sit_Down']);scene.frame_set(0);bpy.context.view_layer.update();idle_pose=snapshot()
use(rig,approved['Sit_Idle']);scene.frame_set(0);bpy.context.view_layer.update();seat_pose=snapshot();pp=points(parts['Bottom_01'])
# 의자 위 엉덩이 아래 면을 기준으로 전체 배치만 올린다. 승인 관절 회전은 그대로다.
region=[p for p,v in zip(pp,parts["Bottom_01"].data.vertices) if v.co.z>.63 and abs(p.x)<.17 and p.y<.02];seat_bottom=min(p.z for p in region);seat_up=.600-seat_bottom;seat_forward=.105*scale
print('SEAT_PLACEMENT',seat_bottom,seat_up,seat_forward,flush=True)
def clear():
 use(rig,None)
 for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
def write_action(name,frames):
 clear();act=bpy.data.actions.new(name);act.use_fake_user=True;use(rig,act)
 for frame,values in enumerate(frames):
  apply(values)
  for pb in rig.pose.bones:
   for p in ['location','rotation_quaternion','scale']:pb.keyframe_insert(p,frame=frame,group=pb.name)
 act.use_frame_range=True;act.frame_start=0;act.frame_end=max(1,len(frames)-1)
 for layer in act.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for fc in bag.fcurves:
     for k in fc.keyframe_points:k.interpolation='LINEAR'
 return act
new_actions=dict(approved);new_actions['Idle']=write_action('Idle',[idle_pose]*25)
for dst,src,direction in [('Sit_Stool','Sit_Down',1),('Seated_Stool','Sit_Idle',0),('Stand_Stool','Stand_Up',-1)]:
 rows=[];act=approved[src];end=int(act.frame_range[1])
 for frame in range(end+1):
  use(rig,act);scene.frame_set(frame);bpy.context.view_layer.update();row=snapshot();f=1. if direction==0 else frame/end if direction==1 else 1-frame/end
  # 원래 앉기 root의 진행률과 같은 보간으로 의자 높이/중심 위치를 맞춘다.
  f=f*f*(3-2*f);offset=rig.data.bones['root'].matrix_local.to_3x3().inverted()@Vector((0,seat_forward*f,seat_up*f));l,q,s=row['root'];row['root']=(l+offset,q,s);rows.append(row)
 new_actions[dst]=write_action(dst,rows)
# 기존 추가 기능의 동작은 회전 차이를 새 기본 뼈대에 옮긴다.
for name,act in legacy_actions.items():
 if name in ['Idle','Walk','Sit_Stool','Seated_Stool','Stand_Stool']:continue
 count=max(1,round((act.frame_range[1]-act.frame_range[0])*24/30));frames=[]
 use(old,act)
 for fi in range(count+1):
  frame=float(act.frame_range[0])+(act.frame_range[1]-act.frame_range[0])*fi/count;scene.frame_set(int(frame),subframe=frame-int(frame));bpy.context.view_layer.update();goals={};values={}
  for n in bone_names:
   old_pose=old.pose.bones[n].matrix;delta=old_pose.to_quaternion()@old_rest[n].to_quaternion().inverted();rot=delta@B[n].to_quaternion();parent=rig.data.bones[n].parent
   pos=(goals[parent.name]@local[n].translation) if parent else B[n].translation+(old_pose.translation-old_rest[n].translation)
   if n=='hips':
    op=old.pose.bones['root'].matrix;ol=old_rest['root'].inverted()@old_rest['hips'];pos+=old_pose.translation-(op@ol.translation)
   mat=Matrix.LocRotScale(pos,rot,Vector((1,1,1)));goals[n]=mat;basis=local[n].inverted()@(goals[parent.name].inverted()@mat if parent else mat);l,q,s=basis.decompose();values[n]=(l if parent is None or n=='hips' else Vector((0,0,0)),q,Vector((1,1,1)))
  frames.append(values)
 new_actions[name]=write_action(name,frames);print('RETARGETED',name,count+1,flush=True)
clear();use(old,None);bpy.data.objects.remove(old,do_unlink=True)
for act in legacy_actions.values():bpy.data.actions.remove(act)
# 손·카드·머리 소켓. 얼굴 메시를 분리하거나 새 눈을 그리지 않는다.
legacy_contract=json.loads((OUT/'legacy_contract.json').read_text(encoding='utf-8'));sockets=[]
for rec in legacy_contract['sockets']:
 n=rec['name'];bn=rec['bone'];rel=old_rest[bn].inverted()@Matrix(rec['matrix']);ratio=rig.data.bones[bn].length/(old_rest[bn].col[1].xyz.length if False else (Vector(next(b['tail'] for b in legacy_contract['bones'] if b['name']==bn))-Vector(next(b['head'] for b in legacy_contract['bones'] if b['name']==bn))).length)
 rel.translation*=ratio
 if n=='Socket_Mouth':
  rel=rig.data.bones['head'].matrix_local.inverted()@Matrix.Translation(T@Vector((.054,0,.313)))
 if n in ['Socket_Card_L','Socket_Hand_L','Socket_Dart_R','Socket_Hand_R']:rel.translation=Vector((0,rig.data.bones[bn].length*(.52 if n=='Socket_Card_L' else .48),0))
 o=bpy.data.objects.new(n,None);scene.collection.objects.link(o);o.parent=rig;o.parent_type='BONE';o.parent_bone=bn;bpy.context.view_layer.update();o.matrix_world=rig.matrix_world@rig.data.bones[bn].matrix_local@rel;sockets.append(o)
eye_native=Vector((.050,0,.374));hat_native=Vector((-.02,0,.482));mouth_native=Vector((.054,0,.313))
def godot(v):p=T@v;return [p.x,p.z,-p.y]
anchors={'eyes':godot(eye_native),'hat':godot(hat_native),'mouth':godot(mouth_native),'cigar':godot(mouth_native+Vector((.004,-.014,-.002)))}
rig['approved_walk_sit']=True;rig['source_approved_rig']=str(SOURCE.relative_to(ROOT));rig['game_profile']='approved_20261119';rig['game_height']=1.8
for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
for act in new_actions.values():
 act.use_fake_user=True;track=rig.animation_data.nla_tracks.new();track.name=act.name;strip=track.strips.new(act.name,0,act);strip.action_slot=act.slots[0];track.mute=True
clear();scene.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'character_game_source.blend'))
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for o in list(parts.values())+sockets:o.select_set(True)
bpy.context.view_layer.objects.active=rig
DEST=PROJECT/'art/characters/rigged/approved_character.glb'
for i,image in enumerate(bpy.data.images):image.name='skin_color_%02d'%(i+1)
bpy.ops.export_scene.gltf(filepath=str(DEST),export_format='GLB',use_selection=True,export_skins=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_bake_animation=True,export_frame_range=False,export_optimize_animation_size=False,export_all_influences=True,export_extras=True)
# 실제 게임 전체 모션 검수에서 확정한 가중치/동작 보정. 기본 정점·법선·UV는 유지한다.
import importlib.util
spec=importlib.util.spec_from_file_location('motion_review_patch',HERE/'motion_review_patch.py');review=importlib.util.module_from_spec(spec);spec.loader.exec_module(review)
review.ankle_weights(DEST);review.apply_cached_clips(HERE/'reviewed_clips.npz',DEST)
vec=lambda a:'Vector3('+', '.join(format(v,'.9g') for v in a)+')'
face_dict='{'+', '.join('"'+k+'": '+vec(v) for k,v in anchors.items())+'}'
wrapper='[gd_scene load_steps=2 format=3]\n\n[ext_resource type="PackedScene" path="res://art/characters/rigged/approved_character.glb" id="1"]\n\n[node name="ApprovedPlayer" instance=ExtResource("1")]\nmetadata/approved_walk_sit = true\nmetadata/face_anchors = '+face_dict+'\nmetadata/face_fit_scale = 0.78\nmetadata/hat_fit_scale = 0.93\n'
(PROJECT/'art/characters/rigged/approved_player.tscn').write_text(wrapper,encoding='utf-8')
report={'source':str(SOURCE.relative_to(ROOT)),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'game_asset':str(DEST.relative_to(ROOT)),'game_asset_sha256':hashlib.sha256(DEST.read_bytes()).hexdigest(),'scale':scale,'transform':[list(row) for row in T],'uniform_placement_only':True,'bind_inverse_transform_errors':rest_errors,'uv_errors':uv_errors,'approved_motion_transform_errors':primary_errors,'approved_core_bones':22,'compatibility_extra_bones':len(extra),'game_bones':len(bone_names),'animations':sorted(new_actions),'visible_parts':list(parts),'seat_bottom_before_adjustment':seat_bottom,'seat_root_up':seat_up,'seat_root_forward':seat_forward,'seat_joint_rotations_unchanged':True,'face_anchors_godot':anchors,'generator':str(Path(__file__).relative_to(ROOT))}
report['reviewed_motion_cache'] = 'reviewed_clips.npz'
report['postprocessed_skin_weights'] = ['Bottom_01', 'Shoes_01']
(HERE/'game_manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');(OUT/'game_manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print('GAME_CHARACTER_GENERATED',json.dumps(report),flush=True)
