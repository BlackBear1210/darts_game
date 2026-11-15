import time
from common import *
from vox import Grid,blur
T0=time.time()
nw=np.load("nw.npy")[::-1].copy()
cls=np.load("classes.npy");eye=cls[0]
HEAD=cov&(Z>0.66)&(np.abs(Y)<0.14)
out=nw.copy()
def unit(a):return a/np.maximum(np.linalg.norm(a,axis=-1,keepdims=True),1e-9)
# eyes: smooth geometric normal
out[eye]=unit(nrm[eye])
# head: directional-bucket 3D blur
G=Grid((-0.125,-0.15,0.65),(0.125,0.15,1.0),0.001)
sel=HEAD&~eye
P=pos[sel];Ng=unit(nrm[sel]);Nw=unit(nw[sel])
acc=np.zeros((len(P),3),np.float32);wsum=np.zeros(len(P),np.float32)
axes=np.array([[1,0,0],[-1,0,0],[0,1,0],[0,-1,0],[0,0,1],[0,0,-1]],np.float32)
for a in axes:
    w=np.clip(Ng@a,0,None)**2
    m=w>1e-3
    A=blur(G.splat(P[m],np.c_[Nw[m]*w[m,None],w[m]]),1.0)
    o=G.sample(A,P)
    acc+=w[:,None]*o[:,:3]/np.maximum(o[:,3:],1e-6);wsum+=w
    print("axis",a,round(time.time()-T0,1))
sm=unit(acc/np.maximum(wsum,1e-6)[:,None])
# guard: keep within 60deg of geometric normal
bad=(sm*Ng).sum(1)<0.5
sm[bad]=Ng[bad]
out[sel]=sm
np.save("nw_clean.npy",out[::-1].copy())   # back to blender row order
np.save("head_mask_bl.npy",(HEAD)[::-1].copy())
print("done",round(time.time()-T0,1),"bad",bad.sum())
