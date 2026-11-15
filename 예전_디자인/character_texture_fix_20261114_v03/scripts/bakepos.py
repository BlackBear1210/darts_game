import bpy,numpy as np,sys
out=sys.argv[sys.argv.index("--")+1]
sc=bpy.context.scene
obj=next(o for o in sc.objects if o.type=="MESH");rig=next(o for o in sc.objects if o.type=="ARMATURE")
rig.data.pose_position="REST";bpy.context.view_layer.update()
mat=obj.data.materials[0];nt=mat.node_tree;N=nt.nodes;L=nt.links
outn=next(n for n in N if n.type=="OUTPUT_MATERIAL")
geo=N.new("ShaderNodeNewGeometry");em=N.new("ShaderNodeEmission");L.new(em.outputs[0],outn.inputs["Surface"])
img=bpy.data.images.new("bk",2048,2048,alpha=True,float_buffer=True)
tn=N.new("ShaderNodeTexImage");tn.image=img;N.active=tn
for n in N:n.select=(n==tn)
sc.render.engine="CYCLES";sc.cycles.device="CPU";sc.cycles.samples=1
sc.render.bake.margin=0;sc.render.bake.use_clear=False
for o in sc.objects:o.select_set(False)
obj.select_set(True);bpy.context.view_layer.objects.active=obj
res={}
for key in ["Position","Normal"]:
    img.pixels.foreach_set(np.full(2048*2048*4,-9,np.float32))
    L.new(geo.outputs[key],em.inputs["Color"])
    bpy.ops.object.bake(type="EMIT",use_clear=False,margin=0)
    a=np.empty(2048*2048*4,np.float32);img.pixels.foreach_get(a);res[key]=a.reshape(2048,2048,4)[:,:,:3]
np.savez_compressed(out,pos=res["Position"],nrm=res["Normal"])
print("BAKED",(res["Position"][:,:,0]>-8).mean())
