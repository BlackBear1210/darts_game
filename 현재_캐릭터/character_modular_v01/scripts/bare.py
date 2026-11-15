# rough bare-body mock from v04: classify faces, pull cloth/hair inward, smooth, save new vertex positions + face regions
import numpy as np,json,sys
P=json.loads(sys.argv[1]) if len(sys.argv)>1 else {}
O=r"C:/Users/아버지/AppData/Local/Temp/claude/a20be7e080516bad/c1f1ed85-1c5b-4bc8-93b8-2b3433a2c49f/scratchpad/"
m=np.load(O+"mesh.npz");co=m["co"].astype(np.float64);ls,lt,lv=m["ls"],m["lt"],m["lv"];V=len(co)
d=np.load(O+"faces.npz");fc,fn,fa,fb,eva=d["fc"],d["fn"],d["fa"],d["fb"],d["eva"];F=len(fc)
hairlab=np.load(O+"facelab.npz")["lab"]
c=np.load("facecolor.npz");h,s,v,cnt=c["h"],c["s"],c["v"],c["cnt"]
Z=fc[:,2]
purple=(h>250)&(cnt>0)
dark=(s<0.45)&(v<0.5)
cls=np.zeros(F,int)            # 0 skin, 1 shirt, 2 pants, 3 shoes, 4 hair
cls[purple&(Z>0.3)&(Z<0.75)]=1
cls[(cls==0)&(Z<0.5)&(Z>=P.get("shoe",0.06))&(dark|(v<0.55)&(s<0.5))]=2
cls[(Z<P.get("shoe",0.06))]=3
cls[hairlab==1]=4
# majority smoothing over face adjacency (3 passes), never touching hair/eyes
for it in range(4):
    votes=np.zeros((F,5))
    np.add.at(votes,(fa,cls[fb]),1);np.add.at(votes,(fb,cls[fa]),1)
    new=votes.argmax(1);keep=(cls==4)|(votes.max(1)<3)
    cls=np.where(keep,cls,new)
print("faces per class",np.bincount(cls,minlength=5))
fv=lv[ls[:,None]+np.arange(4)[None]]
# vertex class: cloth class if all faces around it are that class
vc=np.full(V,-1);mixed=np.zeros(V,bool)
for i in range(4):
    cur=vc[fv[:,i]];k=cls
    first=cur==-1
    vc[fv[first,i]]=k[first]
    clash=(~first)&(cur!=k);mixed[fv[clash,i]]=True
movable=(vc>0)&~mixed
# vertex normals
vn=np.zeros((V,3))
for i in range(4):np.add.at(vn,fv[:,i],fn)
vn/=np.maximum(np.linalg.norm(vn,axis=1,keepdims=True),1e-12)
new=co.copy()
off={1:P.get("o_shirt",0.010),2:P.get("o_pants",0.012),3:P.get("o_shoe",0.010)}
for k,o in off.items():
    sel=movable&(vc==k);new[sel]-=vn[sel]*o
# hair -> ellipsoid skull fitted to skin near the hairline
hv=movable&(vc==4)
adjh=np.zeros(V,bool)
skinface=(cls==0)
near=np.zeros(F,bool)
# skin faces within 2 rings of hair faces on the upper head
ring=(cls==4)
for r in range(P.get("rings",6)):
    n2=ring.copy();n2[fb[ring[fa]]]=True;n2[fa[ring[fb]]]=True;ring=n2
sel=ring&skinface&(Z>P.get("fitz",0.82))
Pp=fc[sel];best=None
for cx in np.linspace(-0.03,0.03,13):
    for cz in np.linspace(0.80,0.89,19):
        q=(Pp-np.array([cx,0,cz]))**2
        sol=np.linalg.lstsq(q,np.ones(len(q)),rcond=None)[0]
        if (sol<=0).any():continue
        rr=1/np.sqrt(sol);res=np.abs(q@sol-1).mean()
        top=cz+rr[2];pen=10*max(0,abs(top-P.get("top",0.958))-0.004)
        sc_=res+pen
        if best is None or sc_<best[0]:best=(sc_,cx,cz,rr,res,top)
_,cx,cz,rad,res,top=best;cen=np.array([cx,0,cz])
print("skull fit center",cen.round(4),"radii",rad.round(4),"res",round(res,4),"top",round(top,4),"from",len(Pp))
rad=rad*P.get("skull_scale",1.0)
dv=new[hv]-cen;dn=np.linalg.norm(dv,axis=1);u=dv/dn[:,None]
re=1/np.sqrt(((u/rad)**2).sum(1))
new[hv]=cen+u*np.minimum(dn,re)[:,None]
# Taubin smoothing on moved vertices
a,b=eva[:,0],eva[:,1]
deg=np.bincount(a,minlength=V)+np.bincount(b,minlength=V)
mov=movable.copy()
for it in range(P.get("smooth",60)):
    for lam in (0.5,-0.53):
        acc=np.zeros((V,3));np.add.at(acc,a,new[b]);np.add.at(acc,b,new[a])
        L=acc/np.maximum(deg,1)[:,None]-new
        new[mov]+=lam*L[mov]
# extra plain smoothing on the scalp to kill hair lumps
for it in range(P.get("scalp_smooth",40)):
    acc=np.zeros((V,3));np.add.at(acc,a,new[b]);np.add.at(acc,b,new[a])
    L=acc/np.maximum(deg,1)[:,None]-new;new[hv]+=0.5*L[hv]
    dv=new[hv]-cen;dn=np.linalg.norm(dv,axis=1);u=dv/dn[:,None];re=1/np.sqrt(((u/rad)**2).sum(1))
    new[hv]=cen+u*np.maximum(dn,re*0.985)[:,None]
# regions for shading: 0 textured skin, 1 new bare skin, 2 underwear
reg=np.where(cls==0,0,1)
lo,hi=P.get("uw",[0.40,0.50])
fz=new[fv].mean(1)[:,2]
reg[(cls>0)&(cls<3)&(fz>lo)&(fz<hi)]=2
np.savez("bare_out.npz",co=new.astype(np.float32),reg=reg,cls=cls)
print("moved verts",int(mov.sum()),"hair verts",int(hv.sum()),"underwear faces",int((reg==2).sum()))
