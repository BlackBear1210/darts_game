from pathlib import Path
import bpy,numpy as np,json
base=Path(r"C:/Users/아버지/Desktop/다트/output/character_design_review_20261113")
out=Path(r"C:/Users/아버지/Desktop/다트/output/character_texture_fix_20261113_v01")
out.mkdir(exist_ok=True,parents=True)
bpy.ops.wm.open_mainfile(filepath=str(base/"diagnostic_setup.blend"))
obj=next(o for o in bpy.context.scene.objects if o.type=="MESH")
mesh=obj.data
info=[]
image=None
for mat in mesh.materials:
    nodes=[]
    for n in mat.node_tree.nodes:
        nd={"name":n.name,"type":n.type}
        if n.type=="TEX_IMAGE":
            nd.update({"image":n.image.name if n.image else None,"filepath":n.image.filepath if n.image else None,"size":list(n.image.size) if n.image else None,"colorspace":n.image.colorspace_settings.name if n.image else None})
        nodes.append(nd)
    links=[{"from":l.from_node.name,"output":l.from_socket.name,"to":l.to_node.name,"input":l.to_socket.name} for l in mat.node_tree.links]
    info.append({"name":mat.name,"nodes":nodes,"links":links})
    principled=next(n for n in mat.node_tree.nodes if n.type=="BSDF_PRINCIPLED")
    color_link=principled.inputs["Base Color"].links[0]
    assert color_link.from_node.type=="TEX_IMAGE"
    image=color_link.from_node.image
(out/"material_inspection.json").write_text(json.dumps(info,ensure_ascii=False,indent=2),encoding="utf-8")
coords=np.array([obj.matrix_world@v.co for v in mesh.vertices],dtype=np.float32)
loops=np.array([l.vertex_index for l in mesh.loops],dtype=np.int32)
uv=np.array([d.uv[:] for d in mesh.uv_layers.active.data],dtype=np.float32)
pixels=np.array(image.pixels[:],dtype=np.float32).reshape(image.size[1],image.size[0],4)
xy=np.floor(uv*np.array(image.size)).astype(int)
xy[:,0]=np.clip(xy[:,0],0,image.size[0]-1)
xy[:,1]=np.clip(xy[:,1],0,image.size[1]-1)
colors=pixels[xy[:,1],xy[:,0],:3]
np.savez_compressed(out/"surface_samples.npz",coords=coords,loop_indices=loops,uv=uv,colors=colors)
c=coords[loops]
r,g,b=colors.T
white=(np.minimum.reduce([r,g,b])>.48)&(np.maximum.reduce([r,g,b])-np.minimum.reduce([r,g,b])<.20)&(c[:,2]>.80)&(c[:,2]<.91)
purple=(r>g*1.12)&(b>g*1.10)&(r>b*.85)
skin=(r>g*1.17)&(g>b*1.05)&(r>b*1.5)
for label,mask in [("face_white",white),("armpit_purple",purple&(c[:,2]>.52)&(c[:,2]<.65)),("armpit_skin",skin&(c[:,2]>.55)&(c[:,2]<.65))]:
    a=c[mask];print(label,len(a),"min",a.min(axis=0).tolist() if len(a) else None,"max",a.max(axis=0).tolist() if len(a) else None,flush=True)
print(json.dumps(info,ensure_ascii=False),flush=True)

