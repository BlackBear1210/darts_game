# poke-through check on character_modular_v01.blend
# variants: A old way (items auto-weighted alone), B copied weights, C copied + armpit-smoothed weights, D = C + hide covered regions
import bpy, sys, json, time, math
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

a = sys.argv[sys.argv.index("--") + 1:]
S, OUT, RDIR = a[0], a[1], a[2]
DO_RENDER = len(a) > 3 and a[3] == "render"
T0 = time.time()
sc = bpy.context.scene
rig = next(o for o in sc.objects if o.type == "ARMATURE")
body = bpy.data.objects["Body"]
ITEMS = ["Hair_01", "Top_01", "Bottom_01", "Shoes_01"]
items = [bpy.data.objects[n] for n in ITEMS]
W = np.load(S + "/weights.npz")
names = list(W["names"])
reg = np.load(S + "/region.npy")
R = json.load(open(OUT + "/regions_v01.json", encoding="utf-8"))
REG = R["regions"]
hide_names = sorted(set(sum(R["hides"].values(), [])))
hidden_face = np.isin(reg, [REG.index(n) for n in hide_names])
V = len(body.data.vertices)
fv = np.array([p.vertices[:] for p in body.data.polygons])
vis_v = np.zeros(V, bool)
for i in range(4):
    vis_v[fv[~hidden_face, i]] = True


def set_weights(o, rows):
    o.vertex_groups.clear()
    vgs = [o.vertex_groups.new(name=n) for n in names]
    for gi in range(len(names)):
        col = rows[:, gi]
        for i in np.flatnonzero(col > 1e-5):
            vgs[gi].add([int(i)], float(col[i]), "REPLACE")


def orig_idx(o):
    v = np.zeros(len(o.data.vertices), np.int32)
    o.data.attributes["orig"].data.foreach_get("value", v)
    return v


def apply_weights(key):
    rows = W[key]
    set_weights(body, rows)
    for o in items:
        set_weights(o, rows[orig_idx(o)])


# auto-weighted copies of the items (variant A)
rig.data.pose_position = "REST"
bpy.context.view_layer.update()
auto = []
for o in items:
    c = o.copy(); c.data = o.data.copy(); c.name = o.name + "_auto"
    for col in o.users_collection:
        col.objects.link(c)
    c.vertex_groups.clear()
    for m in list(c.modifiers):
        c.modifiers.remove(m)
    c.parent = None
    for x in sc.objects:
        x.select_set(False)
    c.select_set(True); rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    c.hide_render = True
    auto.append(c)
print("auto weights done", round(time.time() - T0, 1))

PB = rig.pose.bones
rig.data.pose_position = "POSE"


def reset():
    for pb in PB:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()


def aim(name, target):
    pb = PB["mixamorig:" + name]
    h, t = pb.head.copy(), pb.tail.copy()
    q = (t - h).normalized().rotation_difference(Vector(target).normalized())
    pb.matrix = Matrix.Translation(h) @ q.to_matrix().to_4x4() @ Matrix.Translation(-h) @ pb.matrix
    bpy.context.view_layer.update()


def rot(name, axis, deg):
    pb = PB["mixamorig:" + name]
    h = pb.head.copy()
    Rm = Matrix.Rotation(math.radians(deg), 4, Vector(axis))
    pb.matrix = Matrix.Translation(h) @ Rm @ Matrix.Translation(-h) @ pb.matrix
    bpy.context.view_layer.update()


POSES = {
    "rest": [],
    "armsup": [("aim", "LeftArm", (0.05, -0.35, 1)), ("aim", "RightArm", (0.05, 0.35, 1)), ("aim", "LeftForeArm", (0, -0.2, 1)), ("aim", "RightForeArm", (0, 0.2, 1))],
    "armfwd": [("aim", "LeftArm", (-1, -0.1, 0)), ("aim", "RightArm", (-1, 0.1, 0)), ("aim", "LeftForeArm", (-1, 0, 0)), ("aim", "RightForeArm", (-1, 0, 0))],
    "throw": [("aim", "RightArm", (-1, 0.15, 0.6)), ("aim", "RightForeArm", (0.6, 0, 1))],
    "hug": [("aim", "LeftArm", (-1, 0.15, 0)), ("aim", "RightArm", (-1, -0.15, 0)), ("aim", "LeftForeArm", (-0.2, 1, 0)), ("aim", "RightForeArm", (-0.2, -1, 0.05))],
    "squat": [("aim", "LeftUpLeg", (-1, -0.1, -0.05)), ("aim", "RightUpLeg", (-1, 0.1, -0.05)), ("aim", "LeftLeg", (0.25, 0, -1)), ("aim", "RightLeg", (0.25, 0, -1))],
    "sit": [("aim", "LeftUpLeg", (-1, -0.12, 0)), ("aim", "RightUpLeg", (-1, 0.12, 0)), ("aim", "LeftLeg", (0.05, 0, -1)), ("aim", "RightLeg", (0.05, 0, -1))],
    "bend": [("rot", "Spine", (0, 1, 0), -18), ("rot", "Spine1", (0, 1, 0), -18), ("rot", "Spine2", (0, 1, 0), -15)],
    "twist_look": [("rot", "Spine1", (0, 0, 1), 20), ("rot", "Spine2", (0, 0, 1), 15), ("rot", "Neck", (0, 0, 1), 30), ("rot", "Head", (0, 1, 0), 12)],
}


def pose(n):
    reset()
    for st in POSES[n]:
        if st[0] == "aim":
            aim(st[1], st[2])
        else:
            rot(st[1], st[2], st[3])


def evaluated(o):
    dg = bpy.context.evaluated_depsgraph_get()
    oe = o.evaluated_get(dg)
    m = oe.to_mesh()
    co = np.array([oe.matrix_world @ v.co for v in m.vertices])
    m.calc_loop_triangles()
    tris = [tuple(t.vertices) for t in m.loop_triangles]
    oe.to_mesh_clear()
    return co, tris


def normals(co):
    n = np.zeros((len(fv), 3))
    for i in range(4):
        n += np.cross(co[fv[:, i]], co[fv[:, (i + 1) % 4]])
    vn = np.zeros((V, 3))
    for i in range(4):
        np.add.at(vn, fv[:, i], n)
    return vn / np.maximum(np.linalg.norm(vn, axis=1, keepdims=True), 1e-12)


covered_v = np.zeros(V, bool)
for i in range(4):
    covered_v[fv[hidden_face, i]] = True


def pokes(objs):
    bco, _ = evaluated(body)
    bn = normals(bco)
    pts, tris, off = [], [], 0
    for o in objs:
        c, t = evaluated(o)
        pts.append(c); tris += [(x + off, y + off, z + off) for x, y, z in t]; off += len(c)
    bvh = BVHTree.FromPolygons([Vector(p) for p in np.concatenate(pts)], tris)
    out = []
    for i in np.flatnonzero(covered_v):
        p, n = Vector(bco[i]), Vector(bn[i])
        if bvh.ray_cast(p + n * 1e-6, n, 0.04)[0] is not None:
            continue
        if bvh.ray_cast(p - n * 1e-6, -n, 0.04)[0] is not None:
            out.append(i)
    return set(out)


variants = {}
res = {}
for vkey, wkey, objs, use_hide in [("A_old_auto", "orig", auto, False), ("B_copied", "orig", items, False),
                                   ("C_copied_smooth", "smooth", items, False), ("D_final_hide", "smooth", items, True)]:
    apply_weights(wkey)
    base = None
    res[vkey] = {}
    for pn in POSES:
        pose(pn)
        pk = pokes(objs)
        if pn == "rest":
            base = pk
            res[vkey]["rest_visible_pokes"] = len([i for i in pk if vis_v[i]]) if use_hide else len(pk)
        new = pk - base
        if use_hide:
            new = {i for i in new if vis_v[i]}
        res[vkey][pn] = len(new)
    res[vkey]["rest_baseline"] = len(base)
    print("VARIANT", vkey, json.dumps(res[vkey]), round(time.time() - T0, 1))
json.dump(res, open(OUT + "/poke_check_v01.json", "w"), indent=1)

if DO_RENDER:
    for o in list(sc.objects):
        if o.type in ("CAMERA", "LIGHT"):
            bpy.data.objects.remove(o)
    sc.render.engine = "BLENDER_EEVEE"; sc.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.4, 0.4, 0.42, 1); bg.inputs[1].default_value = 0.9
    for d_, e in [((-0.9, -0.4, 0.9), 3.0), ((0.7, 0.5, 0.4), 1.0)]:
        Ld = bpy.data.lights.new("s", "SUN"); Ld.energy = e
        ob = bpy.data.objects.new("s", Ld); sc.collection.objects.link(ob)
        ob.rotation_euler = (Vector(d_) * -1).to_track_quat("-Z", "Y").to_euler()
    cd = bpy.data.cameras.new("c"); cd.type = "ORTHO"
    cam = bpy.data.objects.new("c", cd); sc.collection.objects.link(cam); sc.camera = cam
    sc.render.resolution_x = 600; sc.render.resolution_y = 600
    # hide covered body faces with a mask material slot for variant D renders
    mb = body.data.materials[0]
    inv_mat = bpy.data.materials.new("M_Hidden")
    inv_mat.use_nodes = True
    nt = inv_mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    o_ = nt.nodes.new("ShaderNodeOutputMaterial"); tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    nt.links.new(tr.outputs[0], o_.inputs["Surface"])
    try:
        inv_mat.surface_render_method = "DITHERED"
    except Exception:
        pass
    body.data.materials.append(inv_mat)
    mi = np.zeros(len(fv), np.int32)
    SHOTS = [("armsup", "back", "RightArm", (1, 0.4, 0.1), 0.3), ("armsup", "front", "RightArm", (-1, 0.3, 0.1), 0.3),
             ("throw", "top", "RightArm", (-0.4, 0.6, 1), 0.3), ("hug", "side", "RightArm", (0, 1, 0.2), 0.35),
             ("sit", "side", "RightLeg", (0, 1, 0.1), 0.45), ("squat", "back", "Hips", (1, 0.5, 0.2), 0.4),
             ("bend", "side", "Spine1", (0, 1, 0.1), 0.5)]
    for vkey, wkey, objs, use_hide in [("B_copied", "orig", items, False), ("D_final_hide", "smooth", items, True)]:
        apply_weights(wkey)
        mi[:] = 0
        if use_hide:
            mi[hidden_face] = 1
        body.data.polygons.foreach_set("material_index", mi); body.data.update()
        for o in auto:
            o.hide_render = True
        for o in items:
            o.hide_render = False
        for pn, tag, bn, dr, s in SHOTS:
            pose(pn)
            t = rig.matrix_world @ PB["mixamorig:" + bn].head
            dd = Vector(dr).normalized()
            cd.ortho_scale = s; cam.location = t + dd * 5
            cam.rotation_euler = (-dd).to_track_quat("-Z", "Y").to_euler()
            sc.render.filepath = f"{RDIR}/chk_{pn}_{tag}_{vkey}.png"
            bpy.ops.render.render(write_still=True)
print("DONE", round(time.time() - T0, 1))
