"""Godot가 가져온 메시와 게임 자세의 실제 삼각형 교차를 검사한다(Blender CLI)."""
import bpy,json,sys,time,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import intersect_ray_tri

P=Path(__file__).parent
tag=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'before'
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
shard=int(args[1]) if len(args)>1 else 0
shards=int(args[2]) if len(args)>2 else 1
D=P/tag
header=json.loads((D/'geometry.json').read_text(encoding='utf-8'))
records=json.loads((D/'poses.json').read_text(encoding='utf-8'))
raw=np.fromfile(D/'geometry.bin',dtype='<f4')
poses=np.fromfile(D/'poses.bin',dtype='<f4').reshape((-1,records['bones'],3,4))
assert len(poses)==len(records['samples'])
surfaces={}
for m in header['meshes']:
 arrays=[raw[o//4:o//4+n] for o,n in m['sections']]
 v=arrays[0].reshape((-1,3));bones=arrays[1].astype(np.int32).reshape((len(v),-1));w=arrays[2].reshape(bones.shape);tri=arrays[3].astype(np.int32).reshape((-1,3))
 binds=np.zeros((len(m['binds']),4,4));binds[:,:3,:]=np.array(m['binds']).reshape((-1,3,4));binds[:,3,3]=1
 rest=np.c_[v,np.ones(len(v))]
 weighted=[np.einsum('nij,nj->ni',binds[bones[:,i]],rest)[:,:3]*w[:,i,None] for i in range(bones.shape[1])]
 # 重複座標/同一スキンの描画頂点を計算時だけ共有する。元メッシュは変更しない。
 packed=np.c_[v,bones,w];_,ix,inv=np.unique(packed,axis=0,return_index=True,return_inverse=True)
 rec={'v':v[ix],'tri':inv[tri],'bones':np.array(m['bone_indices'])[bones[ix]],'weights':w[ix], 'weighted':[x[ix] for x in weighted], 'binds':binds,'raw_vertices':len(v)}
 surfaces.setdefault(m['part'],[]).append(rec)
names=['Body','Top_01','Bottom_01','Shoes_01']
pairs=[('Body','Top_01'),('Body','Bottom_01'),('Body','Shoes_01'),('Top_01','Bottom_01'),('Bottom_01','Shoes_01'),('Top_01','Shoes_01')]

def crossing(a,b):
 for tri,other in [(a,b),(b,a)]:
  for p,q in zip(tri,tri[1:]+tri[:1]):
   edge=q-p;length=edge.length
   if length<1e-9:continue
   hit=intersect_ray_tri(*other,edge/length,p,True)
   if hit is not None and 1e-7<(hit-p).length<length-1e-7:return True
 return False

def geometry(mats):
 result={}
 for name in names:
  verts=[];tris=[];offset=0
  for s in surfaces[name]:
   p=np.zeros_like(s['v'],dtype=np.float64)
   for i,weighted in enumerate(s['weighted']):
    mat=mats[s['bones'][:,i]]
    p+=np.einsum('nij,nj->ni',mat[:,:,:3],weighted)+mat[:,:,3]*s['weights'][:,i,None]
   verts.append(p);tris.append(s['tri']+offset);offset+=len(p)
  p=np.concatenate(verts);t=np.concatenate(tris)
  result[name]=(p,t)
 return result

cache={};rows=[];worst={};start=time.time()
for ri,(mat,record) in enumerate(zip(poses,records['samples'])):
 key=hashlib.sha256(np.round(mat,5).tobytes()).digest()
 if int.from_bytes(key[:4],'little')%shards!=shard:continue
 if key not in cache:
  data=geometry(mat);trees={};vects={};ts={}
  for name,(v,t) in data.items():
   if name=='Body':
    # 肌三角形が衣服の全体境界に重ならなければ、交差は起きない。
    cv=np.concatenate([data[n][0] for n in names[1:]]);lo=cv.min(0)-1e-6;hi=cv.max(0)+1e-6
    xyz=v[t];t=t[((xyz.max(1)>=lo)&(xyz.min(1)<=hi)).all(1)]
   vects[name]=[Vector(x) for x in v];ts[name]=t
   trees[name]=BVHTree.FromPolygons(vects[name],t.tolist(),all_triangles=True)
  hits={};examples=[]
  for a,b in pairs:
   count=0
   for i,j in trees[a].overlap(trees[b]):
    av=[vects[a][k] for k in ts[a][i]];bv=[vects[b][k] for k in ts[b][j]]
    if crossing(av,bv):
     count+=1
     if len(examples)<30:examples.append({'pair':a+'_'+b,'a_vertices':ts[a][i].tolist(),'b_vertices':ts[b][j].tolist(),'center':list(sum(bv,Vector())/3)})
   hits[a+'_'+b]=count
  cache[key]={'hits':hits,'examples':examples}
 val=cache[key];case=record['mode']+':'+record['case'];score=sum(val['hits'].values())
 row={**record,'index':ri,'counts':val['hits'],'total':score};rows.append(row)
 if case not in worst or score>worst[case]['total']:worst[case]={**row,'examples':val['examples']}
 if ri%40==0:
  print('CHECK',ri,'/',len(poses),record['case'],record['time'],'hits',score,'unique',len(cache),'seconds',round(time.time()-start,1),flush=True)
  (D/('progress_%d.json'%shard)).write_text(json.dumps({'done':ri,'total':len(poses),'worst':worst}),encoding='utf-8')
report={'fps':records['fps'],'sampled_states':len(rows),'unique_poses':len(cache),'all_sampled_clear':all(r['total']==0 for r in rows),'worst_by_case':worst,'results':rows,'scope':'Imported visible geometry + production CharacterMotion/CharacterPoseLayer at discrete 1/24 s samples. No hidden skin or hypothetical costume. No continuous collision guarantee.'}
(D/('collision_audit.json' if shards==1 else 'collision_shard_%d.json'%shard)).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('COLLISION_DONE',len(rows),'bad cases',[(k,v['total']) for k,v in worst.items() if v['total']],flush=True)
