import subprocess,os,json,sys,time
from pathlib import Path
P=Path(__file__).parent;tag=sys.argv[1];count=int(sys.argv[2]) if len(sys.argv)>2 else 6
engine='C:/Program Files/Blender Foundation/Blender 5.2/blender.exe'
env=os.environ.copy();env['OPENBLAS_NUM_THREADS']='1';env['OMP_NUM_THREADS']='1'
processes=[];logs=[]
for i in range(count):
 f=(P/tag/('collision_worker_%d.log'%i)).open('w',encoding='utf-8');logs.append(f)
 processes.append(subprocess.Popen([engine,'--background','--factory-startup','--threads','1','--python',str(P/'check_sampled_geometry.py'),'--',tag,str(i),str(count)],env=env,stdout=f,stderr=subprocess.STDOUT,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0)))
for i,p in enumerate(processes):
 code=p.wait();print('WORKER_DONE',i,code,flush=True);assert code==0
for f in logs:f.close()
results=[];worst={};unique=0
for i in range(count):
 filename='collision_audit.json' if count==1 else 'collision_shard_%d.json'%i
 d=json.loads((P/tag/filename).read_text(encoding='utf-8'));results+=d['results'];unique+=d['unique_poses']
 for k,v in d['worst_by_case'].items():
  if k not in worst or v['total']>worst[k]['total']:worst[k]=v
results.sort(key=lambda r:r['index'])
assert len(results)==len(json.loads((P/tag/'poses.json').read_text())['samples'])
physical=bool(results) and all(r['mode']=='physics' for r in results)
report={'fps':None if physical else d['fps'],'sampled_states':len(results),'unique_poses':unique,'all_sampled_clear':all(r['total']==0 for r in results),'worst_by_case':worst,'results':results,'scope':'Final physics modifier poses at recorded simulation timestamps.' if physical else d['scope']}
(P/tag/'collision_audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('COLLISION_DONE',len(results),'bad cases',[(k,v['total']) for k,v in worst.items() if v['total']],flush=True)
