from pathlib import Path
import bpy,numpy as np,json
from mathutils import Vector
out=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(out/"character_texture_fixed.blend"))
scene=bpy.context.scene;obj=next(o for o in scene.objects if o.type=="MESH")
rig=next(o for o in scene.objects if o.type=="ARMATURE");rig.data.pose_position="REST";bpy.context.view_layer.update()
cam=scene.camera;h=.9987189173698425;target=Vector((0,0,h*.865));cam.data.ortho_scale=h*.32
cam.location=target+Vector((-4,0,.02))*h;cam.rotation_euler=(target-cam.location).to_track_quat("-Z","Y").to_euler()
q=cam.rotation_euler.to_quaternion();right=q@Vector((1,0,0));up=q@Vector((0,1,0));direction=q@Vector((0,0,-1))
orig=bpy.data.images.load(str(out.parent/"character_design_review_20261113/source/tripo_convert_954d3209-6b1c-413f-9c5c-acc1b483b08f.fbm/tripo_image_954d3209-6b1c-413f-9c5c-acc1b483b08f_0_0.jpg"),check_existing=False)
fixed=next(im for im in bpy.data.images if im.name=="character_basecolor_repaired")
arrays={im.name:np.array(im.pixels[:]).reshape(im.size[1],im.size[0],4) for im in [orig,fixed]}
deps=bpy.context.evaluated_depsgraph_get();records=[]
for px in [350,375,400,425,675,700,725,750]:
    for py in [492,498,504]:
        rayorig=cam.location+right*((px+.5)/1100-.5)*cam.data.ortho_scale+up*(.5-(py+.5)/1100)*cam.data.ortho_scale
        hit,loc,norm,index,hitobj,matrix=scene.ray_cast(deps,rayorig,direction)
        if not hit:continue
        local=obj.matrix_world.inverted()@loc
        poly=obj.data.polygons[index];ids=list(poly.loop_indices)
        found=None
        for t in [(0,i,i+1) for i in range(1,len(ids)-1)]:
            inds=[ids[i] for i in t];ps=[obj.data.vertices[obj.data.loops[j].vertex_index].co for j in inds]
            a=np.array(ps[0]);A=np.column_stack([np.array(ps[1])-a,np.array(ps[2])-a]);w=np.linalg.lstsq(A,np.array(local)-a,rcond=None)[0];weights=np.array([1-w.sum(),w[0],w[1]])
            if min(weights)>-.001:
                uv=sum((obj.data.uv_layers.active.data[j].uv*float(v) for j,v in zip(inds,weights)),Vector((0,0)));found=uv;break
        if found is None:continue
        colors={}
        for im in [orig,fixed]:
            x=int(np.clip(found.x*im.size[0],0,im.size[0]-1));y=int(np.clip(found.y*im.size[1],0,im.size[1]-1))
            colors[im.name]=arrays[im.name][y,x,:3].tolist()
        records.append({"pixel":[px,py],"world":list(loc),"uv":list(found),"colors":colors})
(out/"brow_pixel_debug.json").write_text(json.dumps(records,indent=2),encoding="utf-8")
print(json.dumps(records,ensure_ascii=False),flush=True)

