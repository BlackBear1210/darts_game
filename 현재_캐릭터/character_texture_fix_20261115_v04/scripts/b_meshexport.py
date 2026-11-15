import bpy,numpy as np,sys
S=sys.argv[sys.argv.index("--")+1]
sc=bpy.context.scene
obj=next(o for o in sc.objects if o.type=="MESH");rig=next(o for o in sc.objects if o.type=="ARMATURE")
rig.data.pose_position="REST";bpy.context.view_layer.update()
me=obj.data;mw=np.array(obj.matrix_world)
co=np.empty(len(me.vertices)*3,np.float32);me.vertices.foreach_get("co",co);co=co.reshape(-1,3)
co=(np.c_[co,np.ones(len(co))]@mw.T)[:,:3]
ls=np.empty(len(me.polygons),np.int32);me.polygons.foreach_get("loop_start",ls)
lt=np.empty(len(me.polygons),np.int32);me.polygons.foreach_get("loop_total",lt)
lv=np.empty(len(me.loops),np.int32);me.loops.foreach_get("vertex_index",lv)
np.savez(S+"/mesh.npz",co=co,ls=ls,lt=lt,lv=lv)
# face index bake
a=me.attributes.new("fidx","FLOAT","FACE");a.data.foreach_set("value",np.arange(len(me.polygons),dtype=np.float32))
mat=me.materials[0];nt=mat.node_tree;N=nt.nodes;L=nt.links
outn=next(n for n in N if n.type=="OUTPUT_MATERIAL")
at=N.new("ShaderNodeAttribute");at.attribute_name="fidx"
em=N.new("ShaderNodeEmission");L.new(at.outputs["Fac"],em.inputs["Color"]);L.new(em.outputs[0],outn.inputs["Surface"])
img=bpy.data.images.new("bk",2048,2048,alpha=True,float_buffer=True)
tn=N.new("ShaderNodeTexImage");tn.image=img;N.active=tn
for n in N:n.select=(n==tn)
sc.render.engine="CYCLES";sc.cycles.device="CPU";sc.cycles.samples=1
sc.render.bake.margin=0;sc.render.bake.use_clear=False
for o in sc.objects:o.select_set(False)
obj.select_set(True);bpy.context.view_layer.objects.active=obj
img.pixels.foreach_set(np.full(2048*2048*4,-1,np.float32))
bpy.ops.object.bake(type="EMIT",use_clear=False,margin=0)
r=np.empty(2048*2048*4,np.float32);img.pixels.foreach_get(r)
f=r.reshape(2048,2048,4)[::-1,:,0]
np.save(S+"/fidx.npy",np.where(f<0,-1,np.rint(f)).astype(np.int32))
print("DONE",len(me.polygons),np.abs(f[f>=0]-np.rint(f[f>=0])).max())
