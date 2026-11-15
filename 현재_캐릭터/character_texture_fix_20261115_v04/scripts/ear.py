import numpy as np,sys,json
from common import *
P=json.loads(sys.argv[1]) if len(sys.argv)>1 else {}
wthr=P.get("w",0.5);th0=np.radians(25)
d=np.load("faces.npz");fc,fn,fa,fb=d["fc"],d["fn"],d["fa"],d["fb"]
L=np.load("facelab.npz");lab=L["lab"].copy();node=L["node"];F=len(fc)
ang=np.arccos(np.clip((fn[fa]*fn[fb]).sum(1),-1,1));conc=((fc[fb]-fc[fa])*fn[fa]).sum(1)>0
w=np.where(conc,np.exp(-(ang/th0)**2),1.0)
box=node&(np.abs(fc[:,1])>0.085)&(fc[:,0]>-0.035)&(fc[:,2]>0.785)&(fc[:,2]<0.88)
seed=box&(lab==0)&(np.abs(fc[:,1])>0.095)&(fc[:,0]>-0.03)
ear=seed.copy()
e=(w>wthr)&box[fa]&box[fb]
for it in range(P.get("rings",2)):
    n=ear.copy();n[fb[e&ear[fa]]]=True;n[fa[e&ear[fb]]]=True
    if n.sum()==ear.sum():break
    ear=n
newskin=ear&(lab==1)
print("ear faces",int(ear.sum()),"hair->skin",int(newskin.sum()),"iters",it)
for side in [1,-1]:
    m=newskin&(fc[:,1]*side>0)
    if m.sum():print(side,"x",fc[m,0].min().round(3),fc[m,0].max().round(3),"y",np.abs(fc[m,1]).min().round(3),np.abs(fc[m,1]).max().round(3),"z",fc[m,2].min().round(3),fc[m,2].max().round(3))
# keep only the largest connected ear-skin piece per side; detached skin strips behind the rim -> hair
par=np.arange(F)
def find(x):
    while par[x]!=x:
        par[x]=par[par[x]];x=par[x]
    return x
sk=(lab==0)&box
e2=sk[fa]&sk[fb]
for a_,b_ in zip(fa[e2],fb[e2]):
    ra,rb=find(a_),find(b_)
    if ra!=rb:par[ra]=rb
root=np.array([find(i) for i in range(F)])
detached=np.zeros(F,bool)
for side in [1,-1]:
    m=sk&(fc[:,1]*side>0)
    u,c=np.unique(root[m],return_counts=True)
    print("side",side,"skin comps in ear box",sorted(c)[::-1][:6])
    main=u[np.argmax(c)]
    detached|=m&(root!=main)
lab[detached]=1;seed=seed&~detached
print("detached skin->hair",int(detached.sum()))
LL0=dict(L);LL0["lab"]=lab
earskin_f=seed
earc=(ear|detached)&(lab==1)
# skin strip behind the rim: grow from the contact hair into ear skin, never across up-facing rim faces
grow=earc.copy();cand=seed&(fn[:,2]<P.get("nz",0.45))&(fn[:,0]<0.5)
for r in range(P.get("back",3)):
    g=grow.copy();g[fb[grow[fa]&cand[fb]]]=True;g[fa[grow[fb]&cand[fa]]]=True;grow=g
strip=grow&seed
lab[strip]=1;seed=seed&~strip;earc=earc|strip;earskin_f=seed
LL0["lab"]=lab
print("strip skin->hair",int(strip.sum()))
np.save("strip_faces.npy",strip)
# up-facing hair faces lying on the rim top, touching ear skin -> skin
sk0=(lab==0)
adj=np.zeros(F,bool);e3=sk0[fa]&(lab[fb]==1);adj[fb[e3]]=True;e3=sk0[fb]&(lab[fa]==1);adj[fa[e3]]=True
rimtop=adj&(lab==1)&box&(np.abs(fc[:,1])>0.084)&(fc[:,2]>0.84)&(fc[:,2]<0.87)&(fn[:,2]>P.get("rimz",0.6))&~strip
lab[rimtop]=0;seed=seed|rimtop;earc=earc&~rimtop;earskin_f=seed;LL0["lab"]=lab
print("rim-top hair->skin",int(rimtop.sum()))
# ear back: hair faces continuing the ear's back surface (facing +x) next to ear skin -> skin
backs=np.zeros(F,bool)
for r in range(2):
    adj=np.zeros(F,bool);e4=seed[fa]&(lab[fb]==1);adj[fb[e4]]=True;e4=seed[fb]&(lab[fa]==1);adj[fa[e4]]=True
    nb=adj&(lab==1)&box&(fn[:,0]>0.8)&(np.abs(fn[:,1])<0.45)
    lab[nb]=0;seed=seed|nb;backs|=nb
earc=earc&~backs;earskin_f=seed;LL0["lab"]=lab
print("ear-back hair->skin",int(backs.sum()))
LL=dict(LL0);LL["lab"]=lab;LL["ear"]=earskin_f;LL["earc"]=earc;np.savez("facelab.npz",**LL)
print("ear skin faces",int(seed.sum()),"contact hair faces",int(earc.sum()))
fidx=np.load("fidx.npy")
dbg=tex*0.3
tl=np.where(fidx>=0,lab[np.maximum(fidx,0)],-3);te=np.where(fidx>=0,ear[np.maximum(fidx,0)],False)
dbg[tl==1]+=(0.6,0.1,0.1);dbg[tl==0]+=(0.1,0.6,0.1);dbg[te&(tl==1)]=(1,1,0);dbg[te&(tl==0)]+=(0,0,0.5)
Image.fromarray((np.clip(dbg,0,1)*255).astype(np.uint8)).save("r/dbg_ear.png")
