import numpy as np
class Grid:
    def __init__(s,lo,hi,res):
        s.lo=np.array(lo,np.float32);s.res=res;s.shape=tuple(int(np.ceil((h-l)/res))+1 for l,h in zip(lo,hi))
    def idx(s,P):
        f=(P-s.lo)/s.res;return f
    def splat(s,P,vals):
        """vals: (n,k). nearest-voxel splat -> (shape..., k)"""
        f=np.rint(s.idx(P)).astype(np.int64)
        ok=np.all((f>=0)&(f<np.array(s.shape)),1)
        f=f[ok];v=vals[ok]
        lin=np.ravel_multi_index(f.T,s.shape)
        n=np.prod(s.shape)
        return np.stack([np.bincount(lin,weights=v[:,k],minlength=n).reshape(s.shape).astype(np.float32) for k in range(v.shape[1])],-1)
    def sample(s,G,P):
        f=s.idx(P);i0=np.floor(f).astype(np.int64);t=(f-i0).astype(np.float32)
        out=np.zeros((len(P),G.shape[-1]),np.float32)
        sh=np.array(s.shape)
        for dx in (0,1):
            for dy in (0,1):
                for dz in (0,1):
                    ii=np.clip(i0+np.array([dx,dy,dz]),0,sh-1)
                    w=(t[:,0] if dx else 1-t[:,0])*(t[:,1] if dy else 1-t[:,1])*(t[:,2] if dz else 1-t[:,2])
                    out+=w[:,None]*G[ii[:,0],ii[:,1],ii[:,2]]
        return out
def blur(G,sigma_vox):
    r=int(np.ceil(3*sigma_vox));k=np.exp(-0.5*(np.arange(-r,r+1)/sigma_vox)**2);k/=k.sum()
    for ax in range(3):
        out=np.zeros_like(G)
        n=G.shape[ax]
        for i,w in zip(range(-r,r+1),k):
            src=[slice(None)]*G.ndim;dst=[slice(None)]*G.ndim
            if i>=0:src[ax]=slice(0,n-i);dst[ax]=slice(i,n)
            else:src[ax]=slice(-i,n);dst[ax]=slice(0,n+i)
            out[tuple(dst)]+=w*G[tuple(src)]
        G=out
    return G
