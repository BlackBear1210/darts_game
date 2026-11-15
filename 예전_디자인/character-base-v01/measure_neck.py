"""v3.1과 P2의 목 단면을 높이별로 재서 자를 위치와 맞출 위치를 찾는다."""
import sys
from pathlib import Path
import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]


def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if path.lower().endswith(".fbx"):
        bpy.ops.wm.fbx_import(filepath=path)
    else:
        bpy.ops.import_scene.gltf(filepath=path)
    obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
    mesh = obj.data
    co = np.empty(len(mesh.vertices) * 3, dtype=np.float64)
    mesh.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    m = np.array(obj.matrix_world)
    world = co @ m[:3, :3].T + m[:3, 3]
    edges = np.empty(len(mesh.edges) * 2, dtype=np.int64)
    mesh.edges.foreach_get("vertices", edges)
    return world, edges.reshape(-1, 2)


def rings(world, edges, z):
    a, b = world[edges[:, 0]], world[edges[:, 1]]
    hit = (a[:, 2] - z) * (b[:, 2] - z) < 0
    t = (z - a[hit, 2]) / (b[hit, 2] - a[hit, 2])
    return a[hit] + (b[hit] - a[hit]) * t[:, None]


for label, path in (("v3.1", args[0]), ("P2", args[1])):
    world, edges = load(path)
    lo, hi = world.min(0), world.max(0)
    h = hi[2] - lo[2]
    print(label, "lo", lo.round(4), "hi", hi.round(4), "center", ((lo + hi) / 2).round(4))
    for pct in (70, 72, 74, 75, 76, 77, 78, 79, 80, 81, 82):
        z = lo[2] + h * pct / 100
        p = rings(world, edges, z)
        near = p[(np.abs(p[:, 1] - (lo[1] + hi[1]) / 2) < 0.12)]
        print(f"  {pct}% 점 {len(p)} 가운데 {len(near)} x[{near[:,0].min():.3f},{near[:,0].max():.3f}] y[{near[:,1].min():.3f},{near[:,1].max():.3f}] 중심 x{(near[:,0].min()+near[:,0].max())/2:.3f} y{(near[:,1].min()+near[:,1].max())/2:.3f}")
