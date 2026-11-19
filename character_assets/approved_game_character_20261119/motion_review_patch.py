"""기본 정점/법선/UV를 보존하고 게임 모션과 발목 가중치만 보정한다."""
from pathlib import Path
import json,struct,hashlib,sys
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
ASSET=ROOT/'다트-/art/characters/rigged/approved_character.glb'
DT={5126:'<f4',5123:'<u2',5121:'u1',5125:'<u4'}
SIZE={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
def load(path):
 b=path.read_bytes();n=struct.unpack_from('<I',b,12)[0];j=json.loads(b[20:20+n]);return j,bytearray(b[28+n:])
def array(j,b,idx):
 a=j['accessors'][idx];v=j['bufferViews'][a['bufferView']];dt=np.dtype(DT[a['componentType']]);cols=SIZE[a['type']]
 return np.ndarray((a['count'],cols),dtype=dt,buffer=b,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',cols*dt.itemsize),dt.itemsize))
def save(path,j,b):
 b+=b'\0'*((-len(b))%4);j['buffers'][0]['byteLength']=len(b);data=json.dumps(j,separators=(',',':')).encode();data+=b' '*((-len(data))%4)
 path.write_bytes(b'glTF'+struct.pack('<II',2,28+len(data)+len(b))+struct.pack('<I',len(data))+b'JSON'+data+struct.pack('<I',len(b))+b'BIN\0'+b)
def ankle_weights(path=ASSET):
 j,b=load(path);names=[j['nodes'][i]['name'] for i in j['skins'][0]['joints']];changed={}
 for node in j['nodes']:
  part=node.get('name','')
  if part not in ['Bottom_01','Shoes_01']:continue
  count=0
  for p in j['meshes'][node['mesh']]['primitives']:
   a=p['attributes'];v=array(j,b,a['POSITION']);bones=array(j,b,a['JOINTS_0']);w=array(j,b,a['WEIGHTS_0'])
   for i,pos in enumerate(v):
    height=float(pos[1]);x=float(pos[0]);foot=names.index('foot.'+('R' if x>0 else 'L'))
    amount=1.0 if part=='Shoes_01' else max(0,min(1,(.27-height)/.09))
    amount=amount*amount*(3-2*amount)
    if amount<=0:continue
    d={int(k):float(q)*(1-amount) for k,q in zip(bones[i],w[i]) if q>0};d[foot]=d.get(foot,0)+amount
    pairs=sorted(d.items(),key=lambda z:-z[1])[:4];total=sum(q for k,q in pairs)
    bones[i]=0;w[i]=0
    for k,(bn,q) in enumerate(pairs):bones[i,k]=bn;w[i,k]=q/total
    count+=1
  changed[part]=count
 save(path,j,b);return changed

def quaternion(m):
 # 회전행렬 -> glTF xyzw. 분기별로 가장 큰 대각 성분을 사용한다.
 tr=float(np.trace(m))
 if tr>0:
  s=np.sqrt(tr+1.0)*2;q=np.array([(m[2,1]-m[1,2])/s,(m[0,2]-m[2,0])/s,(m[1,0]-m[0,1])/s,.25*s])
 else:
  i=int(np.argmax(np.diag(m)));n=(i+1)%3;k=(i+2)%3;s=np.sqrt(1+m[i,i]-m[n,n]-m[k,k])*2;q=np.zeros(4);q[i]=.25*s;q[n]=(m[n,i]+m[i,n])/s;q[k]=(m[k,i]+m[i,k])/s;q[3]=(m[k,n]-m[n,k])/s
 return q/np.linalg.norm(q)

def soften_dance_reach(times, rotations, bone_names):
 """몸통 옆에서 앞으로 손이 넘어가는 두 프레임을 양쪽의 안전한 팔 자세로 연결한다."""
 indices = np.flatnonzero((times >= 11.375 - 1e-5) & (times <= 11.5 + 1e-5))
 if len(indices) != 4:
  raise ValueError("Tripo_dance_02 팔 전환 구간의 24fps 키가 달라졌습니다.")
 first, last = indices[0], indices[-1]
 for bone in ("upper_arm.R", "forearm.R", "hand.R"):
  b = bone_names.index(bone)
  start = rotations[first, b].copy()
  end = rotations[last, b].copy()
  if np.dot(start, end) < 0:
   end *= -1
  for frame in indices[1:-1]:
   weight = float((times[frame] - times[first]) / (times[last] - times[first]))
   middle = (1.0 - weight) * start + weight * end
   rotations[frame, b] = middle / np.linalg.norm(middle)

def bake_clips(sample_dir,cache_path):
 D=Path(sample_dir);h=json.loads((D/'geometry.json').read_text());r=json.loads((D/'poses.json').read_text());mats=np.fromfile(D/'poses.bin',dtype='<f4').reshape((-1,r['bones'],3,4)).copy()
 # 보정된 신발 가중치로 실제 접지 높이를 다시 계산한다.
 j,bin_data=load(ASSET);skin=j['skins'][0];names=[j['nodes'][i]['name'] for i in skin['joints']];header_names=[x['name'] for x in h['bones']];mapping=np.array([header_names.index(x) for x in names]);full=array(j,bin_data,skin['inverseBindMatrices']).reshape((-1,4,4)).transpose(0,2,1).copy();shoes=[]
 node=next(n for n in j['nodes'] if n.get('name')=='Shoes_01')
 for primitive in j['meshes'][node['mesh']]['primitives']:
  a=primitive['attributes'];v=array(j,bin_data,a['POSITION']).copy();jn=array(j,bin_data,a['JOINTS_0']).astype(int);w=array(j,bin_data,a['WEIGHTS_0']).copy()
  local=[np.einsum('nij,nj->ni',full[jn[:,i]],np.c_[v,np.ones(len(v))])[:,:3]*w[:,i,None] for i in range(jn.shape[1])]
  shoes.append((mapping[jn],w,local))
 groups={}
 for i,rec in enumerate(r['samples']):
  if rec['mode']=='clip':groups.setdefault(rec['case'],[]).append(i)
 result={};floors={}
 for name,indices in groups.items():
  global_poses=mats[indices].copy();times=np.array([r['samples'][i]['time'] for i in indices],dtype=np.float32)
  corrections=[]
  for mat in global_poses:
   lift=0.0
   if name.startswith('Tripo_') or name.startswith('Crouch_'):
    minimum=1e9
    for joints,w,local in shoes:
     p=np.zeros((len(w),3))
     for k,weighted in enumerate(local):
      ms=mat[joints[:,k]];p+=np.einsum('nij,nj->ni',ms[:,:,:3],weighted)+ms[:,:,3]*w[:,k,None]
     minimum=min(minimum,float(p[:,1].min()))
    lift=max(0,-minimum)
    mat[:,1,3]+=lift
   corrections.append(lift)
  floors[name]=max(corrections)
  poses=np.tile(np.eye(4),(len(indices),len(h['bones']),1,1));poses[:,:,:3]=global_poses
  loc=np.empty((len(indices),len(h['bones']),3),dtype=np.float32);rot=np.empty((len(indices),len(h['bones']),4),dtype=np.float32)
  for bi,bone in enumerate(h['bones']):
   parent=bone['parent'];ls=np.linalg.inv(poses[:,parent])@poses[:,bi] if parent>=0 else poses[:,bi]
   loc[:,bi]=ls[:,:3,3]
   for t,m in enumerate(ls):
    q=quaternion(m[:3,:3]);q=-q if t and np.dot(rot[t-1,bi],q)<0 else q;rot[t,bi]=q
  if name == 'Tripo_dance_02':
   soften_dance_reach(times, rot, header_names)
  result[name+'_time']=times;result[name+'_location']=loc;result[name+'_rotation']=rot
 result['bone_names']=np.array([x['name'] for x in h['bones']]);np.savez_compressed(cache_path,**result)
 return floors

def apply_cached_clips(cache_path,path=ASSET):
 data=np.load(cache_path);j,b=load(path);mapping={n['name']:i for i,n in enumerate(j['nodes'])};bone_names=data['bone_names']
 def accessor(values,kind):
  values=np.asarray(values,dtype='<f4');b.extend(b'\0'*((-len(b))%4));off=len(b);b.extend(values.tobytes());vi=len(j['bufferViews']);j['bufferViews'].append({'buffer':0,'byteOffset':off,'byteLength':values.nbytes});ai=len(j['accessors']);a={'bufferView':vi,'componentType':5126,'count':len(values),'type':kind}
  if kind=='SCALAR':a.update(min=[float(values.min())],max=[float(values.max())])
  j['accessors'].append(a);return ai
 changed=[]
 for anim in j['animations']:
  name=anim['name']
  # 사용자가 확정했던 원본4개 클립은 그대로 보존한다. 게임 별칭/추가 모션만 굽는다.
  if name in ['Walk','Sit_Down','Sit_Idle','Stand_Up']:continue
  times=data[name+'_time'];keep=np.r_[True,np.diff(times)>1e-7];times=times[keep];loc=data[name+'_location'][keep];rot=data[name+'_rotation'][keep];ti=accessor(times,'SCALAR');samplers=[];channels=[]
  for bi,bn in enumerate(bone_names):
   for path_name,values,kind in [('translation',loc[:,bi],'VEC3'),('rotation',rot[:,bi],'VEC4')]:
    si=len(samplers);samplers.append({'input':ti,'output':accessor(values,kind),'interpolation':'LINEAR'});channels.append({'sampler':si,'target':{'node':mapping[str(bn)],'path':path_name}})
  anim['samplers']=samplers;anim['channels']=channels;changed.append(name)
 save(path,j,b);return changed

if __name__=='__main__':
 import argparse
 parser = argparse.ArgumentParser(description="게임에서 검수한 자세를 내보내기용 캐시로 저장한다.")
 parser.add_argument('action', choices=['bake'])
 parser.add_argument('samples', type=Path)
 parser.add_argument('--output', type=Path, default=Path(__file__).with_name('reviewed_clips.npz'))
 args = parser.parse_args()
 print('FLOOR_CORRECTIONS', bake_clips(args.samples, args.output))
