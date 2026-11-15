# smooth bare body: bi-Laplacian fairing solved with conjugate gradient
import numpy as np,json,sys,time
P=json.loads(sys.argv[1]) if len(sys.argv)>1 else {}
T0=time.time()
O=r"C:/Users/아버지/AppData/Local/Temp/claude/a20be7e080516bad/c1f1ed85-1c5b-4bc8-93b8-2b3433a2c49f/scratchpad/"
m=np.load(O+"mesh.npz");co=m["co"].astype(np.float64);ls,lv=m["ls"],m["lv"];V=len(co)
d=np.load(O+"faces.npz");fc,fn,fa,fb,eva=d["fc"],d["fn"],d["fa"],d["fb"],d["eva"];F=len(fc)
cls=np.load("bare_out.npz")["cls"]
fv=lv[ls[:,None]+np.arange(4)[None]]
a,b=eva[:,0],eva[:,1];deg=np.bincount(a,minlength=V)+np.bincount(b,minlength=V)
def K(x):  # combinatorial Laplacian, x (n,3)
    s=np.zeros_like(x)
    for k in range(3):s[:,k]=np.bincount(a,x[b,k],V)+np.bincount(b,x[a,k],V)
    return deg[:,None]*x-s
# protected faces: eyes, brows, ears, mouth/nose/face front, hands
fidx=np.load(O+"fidx.npy");C=np.load(O+"classes.npy");eye,brow=C[0],C[1]
ok=fidx>=0
def facefrac(mask):
    t=fidx[ok];return np.bincount(t,weights=mask[ok].astype(float),minlength=F)/np.maximum(np.bincount(t,minlength=F),1)
prot=(facefrac(eye)>0.05)|(facefrac(brow)>0.05)
ear=(np.abs(fc[:,1])>0.088)&(fc[:,2]>0.78)&(fc[:,2]<0.885)&(fc[:,0]>-0.035)&(cls==0)
face=(fc[:,0]<-0.045)&(fc[:,2]<0.875)&(fc[:,2]>0.74)&(np.abs(fc[:,1])<0.06)&(cls==0)
hand=(fc[:,2]<0.42)&(cls==0)&(np.abs(fc[:,1])>0.09)
prot|=ear|face|hand
# vertex sets
def vmask(fm):
    out=np.zeros(V,bool)
    for i in range(4):out[fv[fm,i]]=True
    return out
skinv_all=np.ones(V,bool)
for i in range(4):pass
nonskin=vmask(cls>0)
hairv=vmask(cls==4)
clothv=vmask((cls>0)&(cls<4))
onlyskin=~nonskin
protv=vmask(prot)
# ring distance from non-skin (separate for hair and cloth)
def rings(seed,maxr):
    r=np.full(V,99);r[seed]=0;cur=seed.copy()
    for k in range(1,maxr+1):
        n=np.zeros(V,bool);n[b[cur[a]]]=True;n[a[cur[b]]]=True
        n&=r==99;r[n]=k;cur=n
    return r
RH=P.get("rh",10);RC=P.get("rc",5)
rh=rings(hairv,RH);rc=rings(clothv,RC)
band=onlyskin&~protv&((rh<=RH)|(rc<=RC))
free=nonskin|band
free&=~(protv&onlyskin)
# boundary-class rings (where two different non-skin classes or cloth/skin meet)
vcl=np.full(V,-1);mixed=np.zeros(V,bool)
for i in range(4):
    cur=vcl[fv[:,i]];first=cur==-1;vcl[fv[first,i]]=cls[first]
    mixed[fv[(~first)&(cur!=cls),i]]=True
rb=rings(mixed,3)
# vertex normals
vn=np.zeros((V,3))
for i in range(4):np.add.at(vn,fv[:,i],fn)
vn/=np.maximum(np.linalg.norm(vn,axis=1,keepdims=True),1e-12)
# targets and weights
t=co.copy();w=np.zeros(V)
off={1:P.get("o_shirt",0.012),2:P.get("o_pants",0.014)}
ri=rings(onlyskin|(mixed&~hairv),P.get("ri_max",16))
ramp=np.clip((ri-P.get("ri0",4))/P.get("ri1",10),0,1)
for k,o in off.items():
    s_=(vcl==k)&~mixed
    oo=o+(P.get("hem_extra",0.008)*np.clip((0.485-co[s_,2])/0.04,0,1) if k==1 else 0)
    t[s_]=co[s_]-vn[s_]*(oo if np.ndim(oo) else oo)[...,None] if np.ndim(oo) else co[s_]-vn[s_]*oo
    w[s_]=(P.get("w_shoe",0.03) if k==3 else P.get("w_cloth",0.15))*ramp[s_]**2+1e-4
# shoes -> narrower, lower foot around the foot axis; sole rim left to smoothing
sh=(vcl==3)&~mixed
for side,(ya,yt) in {1:(0.053,0.108),-1:(-0.057,-0.121)}.items():
    m_=sh&(np.sign(co[:,1])==side)
    xa,xt=0.053,-0.112
    u_=np.clip((co[m_,0]-xa)/(xt-xa),0,1);ay=ya+u_*(yt-ya)
    tt=co[m_].copy();tt[:,1]=ay+(co[m_,1]-ay)*P.get("foot_w",0.78);tt[:,2]=co[m_,2]*P.get("foot_h",0.85)
    tt[:,0]=np.where(co[m_,0]<-0.09,co[m_,0]+P.get("toe_in",0.006),co[m_,0])
    t[m_]=tt;w[m_]=P.get("w_shoe",0.05)*ramp[m_]**2+1e-4
rim=sh&(co[:,2]<0.016)&(np.abs(vn[:,2])<0.7);w[rim]=1e-4
# hair -> ellipsoid
cen=np.array(P.get("cen",[-0.005,0,0.86]));rad=np.array(P.get("rad",[0.0902,0.0924,0.0906]))
hs=hairv&~mixed
dv=co[hs]-cen;dn=np.linalg.norm(dv,axis=1);u=dv/dn[:,None];re=1/np.sqrt(((u/rad)**2).sum(1))
t[hs]=cen+u*re[:,None]
# spread the scalp vertices evenly over the skull (uniform averaging + projection) so no faces stay folded
def to_ell(Q):
    dv_=Q-cen;dn_=np.linalg.norm(dv_,axis=1);u_=dv_/dn_[:,None];return cen+u_*(1/np.sqrt(((u_/rad)**2).sum(1)))[:,None]
skinface_v=vmask(cls==0)
mv=hairv&~skinface_v
y=co.copy();y[mv]=to_ell(co[mv])
for it in range(P.get("relax_it",600)):
    acc=np.zeros((V,3));np.add.at(acc,a,y[b]);np.add.at(acc,b,y[a])
    avg=acc/np.maximum(deg,1)[:,None]
    y[mv]=to_ell(0.5*y[mv]+0.5*avg[mv])
t[mv]=y[mv]
rsk=rings(onlyskin,P.get("hr_max",30))
rh2=np.clip((rsk-P.get("hr0",2))/P.get("hr1",14),0,1);rh2=rh2*rh2*(3-2*rh2)
w[hs]=P.get("w_hair",1.0)*rh2[hs]**2+1e-4
w[free&(rb<=P.get("rb0",2))&nonskin]=0
# band skin: anchor to original, ramp
bs=band
rr=np.minimum(np.where(rh<=RH,rh/RH,9),np.where(rc<=RC,rc/RC,9))
w[bs]=P.get("w_band",0.6)*np.clip(rr[bs],0,1)**2+0.002;t[bs]=co[bs]
lam=P.get("lam",1.0)
fx=~free
# everything that will sit under a clothing/hair item must end up at least gap2 below that item
hvv=np.load("hv_vert.npy")
hairface=(cls==4)|((hvv[fv].max(1)>0.02)&(cls==0))
itemface=hairface|((cls>0)&(cls<4))
under=np.zeros(V,bool)
for i in range(4):under[fv[itemface,i]]=True
gap2=P.get("gap2",0.0032)
hvc=np.clip(hvv,0,1);ramp_h=np.clip((hvc-0.15)/0.45,0,1);ramp_h=ramp_h*ramp_h*(3-2*ramp_h)
bu=band&under;t[bu]=co[bu]-vn[bu]*(gap2*ramp_h[bu])[:,None]
under=under&(ramp_h>0.99)&~vmask((cls>0)&(cls<4))  # only opaque hair needs the guaranteed gap
print("free",int(free.sum()),"band",int(band.sum()),"hair",int(hs.sum()),"cloth",int(((vcl>0)&(vcl<4)).sum()),round(time.time()-T0,1))
# solve (W + lam K K) x = W t on free set, x fixed elsewhere = co
def A(z):  # z full-size with zeros on fixed
    r=w[:,None]*z+lam*K(K(z));r[fx]=0;return r
def solve(x_init):
    base=co.copy();base[free]=0
    rhs=w[:,None]*t-lam*K(K(base));rhs[fx]=0
    z=x_init.copy();z[fx]=0
    r=rhs-A(z);p=r.copy();rs=(r*r).sum(0)
    for it in range(P.get("iters",2500)):
        Ap=A(p);al=rs/np.maximum((p*Ap).sum(0),1e-30);z+=al*p;r-=al*Ap
        rn=(r*r).sum(0)
        if np.sqrt(rn).max()<1e-9:break
        p=r+(rn/rs)*p;rs=rn
    x=z+base;x[fx]=co[fx];return x,it
x0=co.copy();x0[free]=t[free]
x,it=solve(x0)
for rnd in range(P.get("gap_rounds",4)):
    s=((x-co)*vn).sum(1);viol=under&free&(s>-gap2*0.95)
    print("gap round",rnd,"violations",int(viol.sum()))
    if viol.sum()==0:break
    t[viol]=co[viol]-vn[viol]*gap2;w[viol]=np.maximum(w[viol],P.get("w_gap",0.5))
    x,it=solve(x)
zmin=co[:,2].min();x[:,2]=np.maximum(x[:,2],zmin)
# blend factor for colour: 1 on non-skin, ramp to 0 across band
bl=np.zeros(V);bl[nonskin]=1
bl[band]=1-np.clip(rr[band],0,1)
print("done",it,round(time.time()-T0,1))
np.savez("fair_dbg.npz",w=w,free=free,protv=protv,band=band,hairv=hairv,rsk=rsk,rh=rh)
np.savez("fair_out.npz",co=x.astype(np.float32),blend=bl.astype(np.float32),vcl=vcl,mixed=mixed,free=free)
