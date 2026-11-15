# per-vertex hair field from face labels, smoothed along the surface without crossing creases
import json,sys
import numpy as np
P=json.loads(sys.argv[1]) if len(sys.argv)>1 else {}
K=P.get("K",3);th0=np.radians(P.get("th0",25))
m=np.load("mesh.npz");co,ls,lt,lv=m["co"],m["ls"],m["lt"],m["lv"];Vn=len(co)
d=np.load("faces.npz");fa,fb,eva,fn,fc,area=d["fa"],d["fb"],d["eva"],d["fn"],d["fc"],d["area"]
L=np.load("facelab.npz");lab=L["lab"];node=L["node"];F=len(lab)
fv=lv[ls[:,None]+np.arange(4)[None]]  # all quads
num=np.zeros(Vn);den=np.zeros(Vn)
for i in range(4):
    msk=node
    np.add.at(num,fv[msk,i],area[msk]*lab[msk]);np.add.at(den,fv[msk,i],area[msk])
has=den>0;hv=np.where(has,num/np.maximum(den,1e-12),-1.0)
ang=np.arccos(np.clip((fn[fa]*fn[fb]).sum(1),-1,1));conc=((fc[fb]-fc[fa])*fn[fa]).sum(1)>0
w=np.where(conc,np.exp(-(ang/th0)**2),1.0)
a,b=eva[:,0],eva[:,1];ok=has[a]&has[b];a,b,w=a[ok],b[ok],w[ok]
for it in range(K):
    s=np.bincount(a,w*hv[b],Vn)+np.bincount(b,w*hv[a],Vn);c=np.bincount(a,w,Vn)+np.bincount(b,w,Vn)
    hv=np.where(has&(c>0),0.5*hv+0.5*s/np.maximum(c,1e-12),hv)
np.save("hv_vert.npy",hv.astype(np.float32))
print("verts with field",int(has.sum()),"transition verts",int(((hv>0.02)&(hv<0.98)).sum()))
