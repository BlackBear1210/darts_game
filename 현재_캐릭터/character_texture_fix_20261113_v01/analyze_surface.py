from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
out=Path(r"C:/Users/아버지/Desktop/다트/output/character_texture_fix_20261113_v01")
d=np.load(out/"surface_samples.npz")
p=d["coords"][d["loop_indices"]];c=np.clip(d["colors"],0,1)
fig,axes=plt.subplots(2,2,figsize=(14,11))
for ax,mask,i,j,title in [
(axes[0,0],(p[:,2]>.83)&(p[:,2]<.91)&(p[:,0]<-.045),1,2,"Face front: y / z"),
(axes[0,1],(p[:,2]>.83)&(p[:,2]<.91)&(p[:,1]>.015)&(p[:,1]<.075),0,2,"Eye side: x / z"),
(axes[1,0],(p[:,2]>.53)&(p[:,2]<.65)&(p[:,1]>.04)&(p[:,0]<.052),1,2,"Right armpit front half: y / z"),
(axes[1,1],(p[:,2]>.53)&(p[:,2]<.65)&(p[:,1]>.04)&(p[:,0]>=.052),1,2,"Right armpit back half: y / z"),
]:
    ax.scatter(p[mask,i],p[mask,j],s=4,c=c[mask],edgecolors="none");ax.set_title(title);ax.grid(alpha=.3);ax.set_aspect("equal")
fig.tight_layout();fig.savefig(out/"surface_analysis.png",dpi=140);plt.close(fig)
# 3D 영역별 색상·위치를 분석용으로 기록한다.
r,g,b=c.T
white=(np.minimum.reduce([r,g,b])>.48)&(np.maximum.reduce([r,g,b])-np.minimum.reduce([r,g,b])<.20)
for name,m in [
("brow_whites",white&(p[:,2]>.875)&(p[:,2]<.89)),
("skin_on_shirt",(r>g*1.17)&(g>b*1.05)&(r>b*1.5)&(p[:,2]>.55)&(p[:,2]<.62)&(p[:,1]>.04)&(p[:,1]<.09)),
("purple_on_arm",(r>g*1.12)&(b>g*1.10)&(r>b*.85)&(p[:,2]>.54)&(p[:,2]<.60)&(p[:,1]>.075)),
]:
    a=np.unique(np.round(np.column_stack([p[m],c[m]]),4),axis=0)
    np.savetxt(out/(name+".csv"),a,delimiter=",",header="x,y,z,r,g,b")
    print(name,len(a),"bounds",a[:,:3].min(axis=0),a[:,:3].max(axis=0))

