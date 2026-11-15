import bpy,numpy as np,sys
S=sys.argv[sys.argv.index("--")+1]
sc=bpy.context.scene
obj=next(o for o in sc.objects if o.type=="MESH");rig=next(o for o in sc.objects if o.type=="ARMATURE")
rig.data.pose_position="REST";bpy.context.view_layer.update()
cov=np.load(S+"/posmap.npz")["pos"][:,:,0]>-8
def dilate(img,have,iters):
    img=img.copy();have=have.copy()
    for _ in range(iters):
        acc=np.zeros_like(img);cnt=np.zeros(have.shape,np.float32)
        for dy,dx in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)]:
            cnt+=np.roll(np.roll(have,dy,0),dx,1);acc+=np.roll(np.roll(img*have[...,None],dy,0),dx,1)
        g=~have&(cnt>0);img[g]=acc[g]/cnt[g][:,None];have|=g
    return img
mat=obj.data.materials[0];nt=mat.node_tree;N=nt.nodes;L=nt.links
P=next(n for n in N if n.type=="BSDF_PRINCIPLED")
src=bpy.data.images.new("nwsrc",2048,2048,alpha=True,float_buffer=True);src.colorspace_settings.name="Non-Color"
tn=N.new("ShaderNodeTexImage");tn.image=src;tn.interpolation="Linear"
L.new(tn.outputs["Color"],P.inputs["Normal"])
dst=bpy.data.images.new("tan",2048,2048,alpha=True,float_buffer=True);dst.colorspace_settings.name="Non-Color"
dn=N.new("ShaderNodeTexImage");dn.image=dst;N.active=dn
for n in N:n.select=(n==dn)
sc.render.engine="CYCLES";sc.cycles.device="CPU";sc.cycles.samples=1
b=sc.render.bake;b.margin=0;b.use_clear=True;b.normal_space="TANGENT"
for o in sc.objects:o.select_set(False)
obj.select_set(True);bpy.context.view_layer.objects.active=obj
for name in ["nw","nw_clean"]:
    a=np.load(S+f"/{name}.npy");a=dilate(a,cov,12)
    src.pixels.foreach_set(np.concatenate([a,np.ones(a.shape[:2]+(1,),np.float32)],-1).ravel())
    src.update()
    bpy.ops.object.bake(type="NORMAL",use_clear=True,margin=0)
    r=np.empty(2048*2048*4,np.float32);dst.pixels.foreach_get(r)
    np.save(S+f"/tan_{name}.npy",r.reshape(2048,2048,4)[:,:,:3])
    print("BAKED",name)
