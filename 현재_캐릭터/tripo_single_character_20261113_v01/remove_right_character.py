"""스크린샷 오른쪽 인물만 제거하고 왼쪽 인물의 원래 메시/UV/재질을 보존한다."""
from pathlib import Path
import bpy
import numpy as np
import hashlib
import json
import gc
import tempfile
from mathutils import Vector

out=Path(__file__).resolve().parent
export_temp=(out/'export_tmp').resolve()
export_temp.mkdir(exist_ok=True)
tempfile.tempdir=str(export_temp)
source=next((out/'source').glob('*.fbx'))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
bpy.context.preferences.filepaths.temporary_directory=str(export_temp)
bpy.ops.import_scene.fbx(filepath=str(source))
obj=next(o for o in bpy.data.objects if o.type=='MESH')
old=obj.data
before_vertices=len(old.vertices)
before_faces=len(old.polygons)
coords=np.empty(before_vertices*3,dtype=np.float32)
old.vertices.foreach_get('co',coords)
coords=coords.reshape(-1,3)
loops=np.empty(len(old.loops),dtype=np.int32)
old.loops.foreach_get('vertex_index',loops)
totals=np.empty(before_faces,dtype=np.int32)
old.polygons.foreach_get('loop_total',totals)
assert np.all(totals==3),'Expected the source HD triangle mesh'
triangles=loops.reshape(-1,3)
# 원점 양쪽에 충분한 빈 공간이 있다. 왼쪽 메시를 자르지 않고 오른쪽 인물 전체만 제거한다.
keep_vertices=coords[:,0]<0
keep_face_vertices=keep_vertices[triangles]
crossing=np.any(keep_face_vertices,axis=1)&~np.all(keep_face_vertices,axis=1)
assert not np.any(crossing),'A source triangle crosses the separation plane'
keep_faces=np.all(keep_face_vertices,axis=1)
kept_vertex_indices=np.flatnonzero(keep_vertices)
kept_face_indices=np.flatnonzero(keep_faces)
assert 0<len(kept_vertex_indices)<before_vertices
gap=float(coords[~keep_vertices,0].min()-coords[keep_vertices,0].max())
assert gap>.05,'Need a clear gap between the two characters'
remap=np.full(before_vertices,-1,dtype=np.int32)
remap[kept_vertex_indices]=np.arange(len(kept_vertex_indices),dtype=np.int32)
kept_coords=coords[kept_vertex_indices].copy()
kept_triangles=remap[triangles[keep_faces]]
source_loop_indices=(kept_face_indices[:,None]*3+np.arange(3)).ravel()
smooth=np.empty(before_faces,dtype=np.bool_)
old.polygons.foreach_get('use_smooth',smooth)
material_indices=np.empty(before_faces,dtype=np.int32)
old.polygons.foreach_get('material_index',material_indices)
normal_values=np.empty(len(old.corner_normals)*3,dtype=np.float32)
old.corner_normals.foreach_get('vector',normal_values)
kept_normals=normal_values.reshape(-1,3)[source_loop_indices].copy()
del normal_values,keep_face_vertices,totals

new=bpy.data.meshes.new('left_character_original_hd_mesh')
new.vertices.add(len(kept_coords))
new.vertices.foreach_set('co',kept_coords.ravel())
new.loops.add(kept_triangles.size)
new.loops.foreach_set('vertex_index',kept_triangles.ravel())
new.polygons.add(len(kept_face_indices))
new.polygons.foreach_set('loop_start',np.arange(0,kept_triangles.size,3,dtype=np.int32))
new.polygons.foreach_set('loop_total',np.full(len(kept_face_indices),3,dtype=np.int32))
for mat in old.materials:new.materials.append(mat)
new.polygons.foreach_set('material_index',material_indices[keep_faces])
new.polygons.foreach_set('use_smooth',smooth[keep_faces])
uv_proof={}
for layer in old.uv_layers:
    data=np.empty(len(old.loops)*2,dtype=np.float32)
    layer.data.foreach_get('uv',data)
    kept_uv=data.reshape(-1,2)[source_loop_indices].copy()
    target=new.uv_layers.new(name=layer.name)
    target.data.foreach_set('uv',kept_uv.ravel())
    uv_proof[layer.name]=hashlib.sha256(kept_uv.tobytes()).hexdigest()
    check=np.empty(len(target.data)*2,dtype=np.float32)
    target.data.foreach_get('uv',check)
    assert np.array_equal(check.reshape(-1,2),kept_uv)
    del data,kept_uv,check
new.update(calc_edges=True)
new.normals_split_custom_set(kept_normals)
obj.data=new
obj.name='left_character_kept'
check=np.empty(len(new.vertices)*3,dtype=np.float32)
new.vertices.foreach_get('co',check)
assert np.array_equal(check.reshape(-1,3),kept_coords),'Kept vertex positions changed'
texture_hashes={}
for image in bpy.data.images:
    path=Path(bpy.path.abspath(image.filepath))
    if path.is_file():texture_hashes[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
report={
    'source_fbx':source.name,'source_fbx_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
    'removed':'right-side profile character in user screenshot',
    'retained':'left front-facing character in user screenshot',
    'source_vertices':before_vertices,'source_faces':before_faces,
    'retained_vertices':len(new.vertices),'retained_faces':len(new.polygons),
    'removed_vertices':before_vertices-len(new.vertices),'removed_faces':before_faces-len(new.polygons),
    'gap_between_characters':gap,'crossing_faces':int(crossing.sum()),
    'kept_vertex_positions_exact':True,'kept_original_faces':True,
    'kept_uv_exact':True,'uv_sha256':uv_proof,'texture_sha256':texture_hashes,
    'kept_geometry_sha256':hashlib.sha256(kept_coords.tobytes()).hexdigest(),
    'bounds_local_min':kept_coords.min(axis=0).tolist(),'bounds_local_max':kept_coords.max(axis=0).tolist(),
    'object_transform_preserved':True,'decimated':False,
}
del coords,loops,triangles,kept_normals,remap,check,smooth,material_indices,kept_triangles,source_loop_indices
bpy.data.meshes.remove(old)
gc.collect()
obj.select_set(True)
bpy.context.view_layer.objects.active=obj
minimum=kept_coords.min(axis=0)
maximum=kept_coords.max(axis=0)
world_points=[obj.matrix_world@Vector((x,y,z))
              for x in (minimum[0],maximum[0])
              for y in (minimum[1],maximum[1])
              for z in (minimum[2],maximum[2])]
world_min=Vector(tuple(min(v[i] for v in world_points) for i in range(3)))
world_max=Vector(tuple(max(v[i] for v in world_points) for i in range(3)))
center=(world_min+world_max)*.5
report['bounds_world_min']=list(world_min)
report['bounds_world_max']=list(world_max)
(out/'removal_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.ops.file.pack_all()
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_location=center
        area.spaces.active.region_3d.view_distance=1.7
        area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(out/'character_left_only.blend'))
bpy.ops.export_scene.gltf(filepath=str(out/'character_left_only.glb'),export_format='GLB',
    use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
bpy.ops.export_scene.fbx(filepath=str(out/'character_left_only.fbx'),use_selection=True,
    object_types={'MESH'},bake_anim=False,path_mode='COPY',embed_textures=True,
    axis_forward='-Z',axis_up='Y')
(out/'removal_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('REMOVAL_COMPLETE',json.dumps(report),flush=True)

# 원본과 같은 재질을 사용해 남긴 캐릭터만 검토용으로 렌더한다.
scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=900
scene.render.resolution_y=1200
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.world=bpy.data.worlds.new('review_world')
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.23,.23,.23,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
scene.view_settings.view_transform='AgX'
for name,offset,energy,size in [('key',(-2,-3,4),450,3),('fill',(3,-2,2),200,3),('back',(0,3,3),250,3)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.shape='DISK';data.size=size
    light=bpy.data.objects.new(name,data);scene.collection.objects.link(light)
    light.location=center+Vector(offset)
    light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('review_camera');data.type='ORTHO';data.ortho_scale=1.10
cam=bpy.data.objects.new('review_camera',data);scene.collection.objects.link(cam);scene.camera=cam
for name,offset in [('kept_front',(0,-4,.10)),('kept_three_quarter',(-2,-4,.10)),('kept_back',(0,4,.10))]:
    cam.location=center+Vector(offset)
    cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(out/(name+'.png'))
    bpy.ops.render.render(write_still=True)
print('PREVIEWS_COMPLETE',flush=True)
