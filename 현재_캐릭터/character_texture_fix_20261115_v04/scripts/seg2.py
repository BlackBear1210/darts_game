import sys,json
from common import *
P=json.loads(sys.argv[1]) if len(sys.argv)>1 else {}
th0=np.radians(P.get("th0",25));lam0=P.get("lam",0.5);iters=P.get("it",400)
d=np.load("faces.npz");fc,fn,fa,fb,cnt,fhair,feye,fbrow,fpur=[d[k] for k in "fc fn fa fb cnt fhair feye fbrow fpur".split()]
F=len(fc)
head=(fc[:,2]>0.70)&(np.abs(fc[:,1])<0.14)
mouth=(fc[:,2]>0.76)&(fc[:,2]<0.84)&(np.abs(fc[:,1])<0.035)&(fc[:,0]<-0.04)
other=(feye>0.5)|(fbrow>0.5)|(fpur>0.5)|mouth
node=head&~other
cosang=np.clip((fn[fa]*fn[fb]).sum(1),-1,1);ang=np.arccos(cosang)
conc=((fc[fb]-fc[fa])*fn[fa]).sum(1)>0
w=np.where(conc,np.exp(-(ang/th0)**2),1.0)
ok=node[fa]&node[fb];A,B,W=fa[ok],fb[ok],w[ok]
conf=np.minimum(cnt/8.0,1.0)*node;lam=lam0*conf
p=fhair.copy()
for it in range(iters):
    num=lam*fhair+np.bincount(A,W*p[B],F)+np.bincount(B,W*p[A],F)
    den=lam+np.bincount(A,W,F)+np.bincount(B,W,F)
    p=np.where(node,num/np.maximum(den,1e-9),p)
lab=np.full(F,-1);lab[node]=(p[node]>0.5).astype(int)
def comps(mask):
    par=np.arange(F)
    def find(x):
        while par[x]!=x:
            par[x]=par[par[x]];x=par[x]
        return x
    e=mask[fa]&mask[fb]
    for a_,b_ in zip(fa[e],fb[e]):
        ra,rb=find(a_),find(b_)
        if ra!=rb:par[ra]=rb
    r=np.array([find(i) for i in range(F)]);r[~mask]=-1;return r
for it in range(2):
    rs=comps(lab==0);u,c=np.unique(rs[rs>=0],return_counts=True);main=u[np.argmax(c)]
    flip=(lab==0)&(rs!=main);lab[flip]=1;print("skin islands->hair",int(flip.sum()),"main skin",c.max())
    rh=comps(lab==1);u,c=np.unique(rh[rh>=0],return_counts=True);big=set(u[c>=300])
    flip=(lab==1)&~np.isin(rh,list(big));lab[flip]=0;print("hair islands->skin",int(flip.sum()),"hair comps kept",sorted(c[c>=300])[::-1][:5])
# ear zone: morphological opening of hair (removes thin hair strips on the ear rim)
earz=node&(np.abs(fc[:,1])>0.095)&(fc[:,2]>0.80)&(fc[:,2]<0.90)
def nbr_all(mask,val):
    # face stays True only if all node neighbours are True
    bad=np.zeros(F,bool)
    e=node[fa]&node[fb]
    bad[fa[e&~mask[fb]]]=True;bad[fb[e&~mask[fa]]]=True
    return mask&~bad
def nbr_any(mask):
    out=mask.copy();e=node[fa]&node[fb]
    out[fa[e&mask[fb]]]=True;out[fb[e&mask[fa]]]=True;return out&node
H=lab==1;Hk=H.copy()
for r in range(2):Hk=nbr_all(Hk,1)
for r in range(2):Hk=nbr_any(Hk)
opened=H&~Hk&earz
lab[opened]=0;print("ear-zone thin hair -> skin",int(opened.sum()))
np.savez("facelab.npz",lab=lab,p=p,node=node,other=other)
print("hair faces",int((lab==1).sum()),"skin faces",int((lab==0).sum()),"changed vs raw",int(((fhair>0.5)!=(p>0.5))[node].sum()))
fidx=np.load("fidx.npy")
dbg=tex*0.3
L=np.where(fidx>=0,lab[np.maximum(fidx,0)],-2)
dbg[L==1]+=np.array([0.7,0.1,0.1]);dbg[L==0]+=np.array([0.1,0.7,0.1])
raw=np.where(fidx>=0,fhair[np.maximum(fidx,0)],0)
Image.fromarray((np.clip(dbg,0,1)*255).astype(np.uint8)).save("r/dbg_seg.png")
