import bpy,numpy as np,sys
out=sys.argv[sys.argv.index("--")+1]
sc=bpy.context.scene
obj=next(o for o in sc.objects if o.type=="MESH");rig=next(o for o in sc.objects if o.type=="ARMATURE")
rig.data.pose_position="REST";bpy.context.view_layer.update()
mat=obj.data.materials[0];nt=mat.node_tree;N=nt.nodes;L=nt.links
outn=next(n for n in N if n.type=="OUTPUT_MATERIAL")
nmn=next(n for n in N if n.type=="NORMAL_MAP")
print("normal map space",nmn.space,"uv",nmn.uv_map,"strength",nmn.inputs["Strength"].default_value)
em=N.new("ShaderNodeEmission");L.new(em.outputs[0],outn.inputs["Surface"])
L.new(nmn.outputs["Normal"],em.inputs["Color"])
img=bpy.data.images.new("bk",2048,2048,alpha=True,float_buffer=True)
tn=N.new("ShaderNodeTexImage");tn.image=img;N.active=tn
for n in N:n.select=(n==tn)
sc.render.engine="CYCLES";sc.cycles.device="CPU";sc.cycles.samples=1
sc.render.bake.margin=0;sc.render.bake.use_clear=False
for o in sc.objects:o.select_set(False)
obj.select_set(True);bpy.context.view_layer.objects.active=obj
img.pixels.foreach_set(np.full(2048*2048*4,-9,np.float32))
bpy.ops.object.bake(type="EMIT",use_clear=False,margin=0)
a=np.empty(2048*2048*4,np.float32);img.pixels.foreach_get(a)
np.save(out,a.reshape(2048,2048,4)[:,:,:3])
print("DONE")
