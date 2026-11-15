# build modular character v01 from v04: Body (bare) + Hair_01/Top_01/Bottom_01/Shoes_01, same armature
import bpy, bmesh, sys, json, time
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

a = sys.argv[sys.argv.index("--") + 1:]
S, OUT = a[0], a[1]
P = json.loads(a[2]) if len(a) > 2 else {}
T0 = time.time()
sc = bpy.context.scene
src = next(o for o in sc.objects if o.type == "MESH")
rig = next(o for o in sc.objects if o.type == "ARMATURE")
rig.data.pose_position = "REST"
bpy.context.view_layer.update()
me = src.data
V, F = len(me.vertices), len(me.polygons)
fo = np.load(S + "/fair_out.npz")
X = fo["co"].astype(np.float64)
bl = fo["blend"].astype(np.float32)
vcl = fo["vcl"]
cls = np.load(S + "/bare_out.npz")["cls"]
skin = json.load(open(S + "/skin.json"))["skin"]
MW = np.array(src.matrix_world)
inv = np.linalg.inv(MW)
co0 = np.array([src.matrix_world @ v.co for v in me.vertices])
fv_all = np.array([p.vertices[:] for p in me.polygons])
hvv = np.load(S + "/hv_vert.npy")
# faces of each item; the hair item also takes the hairline faces, cut by the hairline mask
IF = {"Hair_01": (cls == 4) | ((hvv[fv_all].max(1) > P.get("hair_face_hv", 0.02)) & (cls == 0)),
      "Top_01": cls == 1, "Bottom_01": cls == 2, "Shoes_01": cls == 3}

# ---------- weights (original + armpit-smoothed) ----------
names = [g.name for g in src.vertex_groups]
G = len(names)
Wt = np.zeros((V, G), np.float32)
for v in me.vertices:
    for g in v.groups:
        Wt[v.index, g.group] = g.weight
E = np.array([e.vertices[:] for e in me.edges])
ea, eb = E[:, 0], E[:, 1]
deg = np.bincount(ea, minlength=V) + np.bincount(eb, minlength=V)


def avgnb(A):
    s = np.zeros_like(A)
    np.add.at(s, ea, A[eb])
    np.add.at(s, eb, A[ea])
    return s / np.maximum(deg, 1)[:, None]


Ws = Wt.copy()
f = np.zeros(V)
R = P.get("arm_r", 0.07)
for n in ("LeftArm", "RightArm"):
    h = np.array(rig.matrix_world @ rig.data.bones["mixamorig:" + n].head_local)
    f = np.maximum(f, np.clip(1 - np.linalg.norm(co0 - h, axis=1) / R, 0, 1))
f = f * f * (3 - 2 * f)
for it in range(P.get("arm_it", 25)):
    Ws = Ws + 0.5 * f[:, None] * (avgnb(Ws) - Ws)
Ws /= np.maximum(Ws.sum(1, keepdims=True), 1e-9)
np.savez(S + "/weights.npz", orig=Wt, smooth=Ws, names=np.array(names))
print("weights", G, "smoothed verts", int((f > 0).sum()), round(time.time() - T0, 1))


def set_weights(o, rows):
    o.vertex_groups.clear()
    vgs = [o.vertex_groups.new(name=n) for n in names]
    for gi in range(G):
        col = rows[:, gi]
        for i in np.flatnonzero(col > 1e-5):
            vgs[gi].add([int(i)], float(col[i]), "REPLACE")


def dup(name):
    o = src.copy()
    o.data = src.data.copy()
    o.name = name
    o.data.name = name
    sc.collection.objects.link(o)
    return o


def vnorm(P_):
    n = np.zeros((F, 3))
    for i in range(4):
        n += np.cross(P_[fv_all[:, i]], P_[fv_all[:, (i + 1) % 4]])
    vn = np.zeros((V, 3))
    for i in range(4):
        np.add.at(vn, fv_all[:, i], n)
    return vn / np.maximum(np.linalg.norm(vn, axis=1, keepdims=True), 1e-12)


def item_tris(c_):
    tr = []
    for p in np.flatnonzero(cls == c_):
        q = fv_all[p]
        tr += [(q[0], q[1], q[2]), (q[0], q[2], q[3])]
    return tr


# ---------- body geometry with a minimum gap under the clothes ----------
body = dup("Body")
alltr = []
for c_ in (1, 2, 3, 4):
    alltr += item_tris(c_)
bvh = BVHTree.FromPolygons([Vector(p) for p in co0], alltr)
covered = np.zeros(V, bool)
anyitem = np.zeros(F, bool)
for m_ in IF.values():
    anyitem |= m_
for i in range(4):
    covered[fv_all[anyitem, i]] = True
gap = P.get("gap", 0.0025)


def signed(bv, p):
    # negative = under the clothing surface (inside), positive = outside
    r = bv.find_nearest(Vector(p), 0.05)
    if r[0] is None:
        return None
    return (Vector(p) - r[0]).dot(r[1])


# each covered body vertex has an exact partner on the clothing (same v04 vertex): keep it at least `gap` below it
n0 = vnorm(co0)
# skip the strip next to every item edge: the skin there is seen through the openings and must stay smooth
dist = np.where(covered, 99, 0)
cur = ~covered
for k in range(1, P.get("rim_rings", 5) + 1):
    nb = np.zeros(V, bool); nb[eb[cur[ea]]] = True; nb[ea[cur[eb]]] = True
    nb &= dist == 99; dist[nb] = k; cur = nb
cov_in = covered & (dist == 99)
for rnd in range(P.get("gap_rounds", 3)):
    s = ((X - co0) * n0).sum(1)
    push = np.where(cov_in & (s > -gap), np.minimum(s + gap, P.get("push_cap", 0.02)), 0.0)
    bad = int((push > 0).sum())
    print("gap round", rnd, "violations", bad, "max push", round(float(push.max()), 4))
    if bad == 0:
        break
    sm = push.copy()
    for k in range(P.get("push_dilate", 3)):
        mx = sm.copy()
        np.maximum.at(mx, ea, sm[eb])
        np.maximum.at(mx, eb, sm[ea])
        sm = mx
    for k in range(P.get("push_blur", 25)):
        sm = 0.5 * sm + 0.5 * avgnb(sm[:, None])[:, 0]
    sm = np.maximum(sm, push)
    X = X - n0 * sm[:, None]
s = ((X - co0) * n0).sum(1)
print("gap after: covered verts closer than gap", int((cov_in & (s > -gap + 1e-6)).sum()), "of", int(cov_in.sum()))
np.save(S + "/body_final_co.npy", X)
loc = (np.c_[X, np.ones(V)] @ inv.T)[:, :3].astype(np.float32)
body.data.vertices.foreach_set("co", loc.ravel())
body.data.update()
set_weights(body, Ws)
print("body ready", round(time.time() - T0, 1))

# ---------- body textures (bake) ----------
at = body.data.attributes.new("bare", "FLOAT", "POINT")
at.data.foreach_set("value", bl)
uwv = (((vcl == 1) | (vcl == 2)) & (X[:, 2] > 0.36) & (X[:, 2] < 0.53) & (np.abs(X[:, 1]) < 0.095)).astype(np.float32)
au = body.data.attributes.new("uw", "FLOAT", "POINT")
au.data.foreach_set("value", uwv)
srcmat = me.materials[0]


def build_bake_mat(emit):
    mat = srcmat.copy()
    nt = mat.node_tree
    N, L = nt.nodes, nt.links
    Pn = next(n for n in N if n.type == "BSDF_PRINCIPLED")
    srcs = Pn.inputs["Base Color"].links[0].from_socket
    an = N.new("ShaderNodeAttribute"); an.attribute_name = "bare"
    a0 = N.new("ShaderNodeAttribute"); a0.attribute_name = "uw"
    geo = N.new("ShaderNodeNewGeometry")
    sep = N.new("ShaderNodeSeparateXYZ"); L.new(geo.outputs["Position"], sep.inputs[0])
    c1 = N.new("ShaderNodeMath"); c1.operation = "GREATER_THAN"; c1.inputs[1].default_value = 0.40; L.new(sep.outputs["Z"], c1.inputs[0])
    c2 = N.new("ShaderNodeMath"); c2.operation = "LESS_THAN"; c2.inputs[1].default_value = 0.497; L.new(sep.outputs["Z"], c2.inputs[0])
    c3 = N.new("ShaderNodeMath"); c3.operation = "MULTIPLY"; L.new(c1.outputs[0], c3.inputs[0]); L.new(c2.outputs[0], c3.inputs[1])
    c4 = N.new("ShaderNodeMath"); c4.operation = "GREATER_THAN"; c4.inputs[1].default_value = 0.5; L.new(a0.outputs["Fac"], c4.inputs[0])
    u_ = N.new("ShaderNodeMath"); u_.operation = "MULTIPLY"; L.new(c3.outputs[0], u_.inputs[0]); L.new(c4.outputs[0], u_.inputs[1])
    m1 = N.new("ShaderNodeMix"); m1.data_type = "RGBA"
    L.new(an.outputs["Fac"], m1.inputs["Factor"]); L.new(srcs, m1.inputs[6]); m1.inputs[7].default_value = (*skin, 1)
    m2 = N.new("ShaderNodeMix"); m2.data_type = "RGBA"
    L.new(u_.outputs[0], m2.inputs["Factor"]); L.new(m1.outputs[2], m2.inputs[6]); m2.inputs[7].default_value = (0.10, 0.11, 0.13, 1)
    out = next(n for n in N if n.type == "OUTPUT_MATERIAL")
    em = N.new("ShaderNodeEmission")
    L.new(m2.outputs[2] if emit == "color" else an.outputs["Fac"], em.inputs["Color"])
    L.new(em.outputs[0], out.inputs["Surface"])
    return mat


def bake(mat, img):
    body.data.materials.clear()
    body.data.materials.append(mat)
    N = mat.node_tree.nodes
    tn = N.new("ShaderNodeTexImage"); tn.image = img; N.active = tn
    for n in N:
        n.select = (n == tn)
    sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 1
    sc.render.bake.margin = 16; sc.render.bake.use_clear = True
    for o in sc.objects:
        o.select_set(False)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.bake(type="EMIT", use_clear=True, margin=16)


imgc = bpy.data.images.new("body_basecolor", 2048, 2048)
bake(build_bake_mat("color"), imgc)
imgc.filepath_raw = OUT + "/body_basecolor_v01.png"; imgc.file_format = "PNG"; imgc.save()
imgb = bpy.data.images.new("bk_bare", 2048, 2048, float_buffer=True); imgb.colorspace_settings.name = "Non-Color"
bake(build_bake_mat("bare"), imgb)
bare_px = np.empty(2048 * 2048 * 4, np.float32); imgb.pixels.foreach_get(bare_px)
bare_px = bare_px.reshape(2048, 2048, 4)[..., 0]
nmn = next(n for n in srcmat.node_tree.nodes if n.type == "NORMAL_MAP")
nimg = nmn.inputs["Color"].links[0].from_node.image
npx = np.empty(2048 * 2048 * 4, np.float32); nimg.pixels.foreach_get(npx); npx = npx.reshape(2048, 2048, 4)
nv = npx[..., :3] * 2 - 1
b_ = np.clip(bare_px, 0, 1)[..., None]
nv = nv * (1 - b_) + np.array([0, 0, 1.0]) * b_
nv /= np.maximum(np.linalg.norm(nv, axis=-1, keepdims=True), 1e-6)
out_ = np.concatenate([nv * 0.5 + 0.5, np.ones((2048, 2048, 1))], -1).astype(np.float32)
imgn = bpy.data.images.new("body_normal", 2048, 2048); imgn.colorspace_settings.name = "Non-Color"
imgn.pixels.foreach_set(out_.ravel())
imgn.filepath_raw = OUT + "/body_normal_v01.png"; imgn.file_format = "PNG"; imgn.save()
mat = srcmat.copy(); mat.name = "M_Body_v01"
nt = mat.node_tree
Pn = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
Pn.inputs["Base Color"].links[0].from_node.image = bpy.data.images.load(OUT + "/body_basecolor_v01.png")
nm2 = next(n for n in nt.nodes if n.type == "NORMAL_MAP")
ni = bpy.data.images.load(OUT + "/body_normal_v01.png"); ni.colorspace_settings.name = "Non-Color"
nm2.inputs["Color"].links[0].from_node.image = ni
body.data.materials.clear(); body.data.materials.append(mat)
for n in ("bare", "uw"):
    body.data.attributes.remove(body.data.attributes[n])
print("textures baked", round(time.time() - T0, 1))

# ---------- items: same vertices as v04, weights copied from the body ----------
item_cls = {"Hair_01": 4, "Top_01": 1, "Bottom_01": 2, "Shoes_01": 3}
items = {}
for name, c_ in item_cls.items():
    o = dup(name)
    bm = bmesh.new(); bm.from_mesh(o.data)
    lay = bm.verts.layers.int.new("orig")
    for v in bm.verts:
        v[lay] = v.index
    bm.faces.ensure_lookup_table()
    kill = [fc_ for fc_ in bm.faces if not IF[name][fc_.index]]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.to_mesh(o.data); bm.free()
    orig = np.zeros(len(o.data.vertices), np.int32)
    o.data.attributes["orig"].data.foreach_get("value", orig)
    o.data.materials.clear(); o.data.materials.append(srcmat)
    items[name] = dict(obj=o, orig=orig)

# pants waistband: the part hidden under the shirt was never modelled in v04.
# copy the body's hip faces between the pants top and the waist, just above the skin, flat pants colour.
fcX = X[fv_all].mean(1)
bvp = BVHTree.FromPolygons([Vector(p) for p in co0], item_tris(2))
need = np.array([(cls[i] in (1, 2)) and fcX[i, 2] > 0.395 and fcX[i, 2] < 0.505 and abs(fcX[i, 1]) < 0.1
                 and (signed(bvp, fcX[i]) is None or signed(bvp, fcX[i]) > 0) for i in range(F)])
pants_med = np.array(P.get("pants_rgb", [0.035, 0.03, 0.028]))
bo = items["Bottom_01"]["obj"]
bm = bmesh.new(); bm.from_mesh(bo.data)
lay = bm.verts.layers.int.get("orig")
uvl = bm.loops.layers.uv.active
vnX = vnorm(X)
newv = {}
uvs = body.data.uv_layers.active.data
for fi in np.flatnonzero(need):
    vs = []
    for vi in fv_all[fi]:
        if vi not in newv:
            nv_ = bm.verts.new(Vector(X[vi] + vnX[vi] * P.get("band_off", 0.0012)))
            nv_[lay] = int(vi)
            newv[vi] = nv_
        vs.append(newv[vi])
    try:
        f_ = bm.faces.new(vs)
    except ValueError:
        continue
    f_.material_index = 1
    lp0 = body.data.polygons[int(fi)].loop_start
    for k, lp in enumerate(f_.loops):
        lp[uvl].uv = uvs[lp0 + k].uv
bm.verts.index_update()
bmesh.ops.remove_doubles(bm, verts=list(newv.values()), dist=1e-7)
bm.to_mesh(bo.data); bm.free()
mp = bpy.data.materials.new("M_Pants_Waistband"); mp.use_nodes = True
next(n for n in mp.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (*pants_med, 1)
bo.data.materials.append(mp)
items["Bottom_01"]["orig"] = np.zeros(len(bo.data.vertices), np.int32)
bo.data.attributes["orig"].data.foreach_get("value", items["Bottom_01"]["orig"])
print("pants waistband faces", int(need.sum()))
# hair material: cut out by the smooth hairline mask from v04
hm = srcmat.copy(); hm.name = "M_Hair_01"
hn = hm.node_tree
Ph = next(n for n in hn.nodes if n.type == "BSDF_PRINCIPLED")
ai = hn.nodes.new("ShaderNodeTexImage")
ai.image = bpy.data.images.load(S + "/hair_alpha.png"); ai.image.colorspace_settings.name = "Non-Color"
uvsrc = Ph.inputs["Base Color"].links[0].from_node
if uvsrc.inputs["Vector"].links:
    hn.links.new(uvsrc.inputs["Vector"].links[0].from_socket, ai.inputs["Vector"])
gt = hn.nodes.new("ShaderNodeMath"); gt.operation = "GREATER_THAN"; gt.inputs[1].default_value = 0.5
hn.links.new(ai.outputs["Color"], gt.inputs[0]); hn.links.new(gt.outputs[0], Ph.inputs["Alpha"])
try:
    hm.surface_render_method = "DITHERED"
except Exception:
    pass
items["Hair_01"]["obj"].data.materials.clear(); items["Hair_01"]["obj"].data.materials.append(hm)
for name, it in items.items():
    set_weights(it["obj"], Ws[it["orig"]])
    print("item", name, len(it["obj"].data.vertices), "verts")

# ---------- body regions that clothes can hide ----------
fcn = co0[fv_all].mean(1)


def segdist(p, h, t):
    h = np.array(h); t = np.array(t); d_ = t - h
    u = np.clip(((p - h) @ d_) / (d_ @ d_), 0, 1)
    return np.linalg.norm(p - (h + u[:, None] * d_), axis=1)


bones = {b.name.replace("mixamorig:", ""): (rig.matrix_world @ b.head_local, rig.matrix_world @ b.tail_local) for b in rig.data.bones}
grp = {"spine": ["Hips", "Spine", "Spine1", "Spine2", "LeftShoulder", "RightShoulder"], "head": ["Neck", "Head", "HeadTop_End"],
       "uarm_L": ["LeftArm"], "uarm_R": ["RightArm"], "farm_L": ["LeftForeArm"], "farm_R": ["RightForeArm"],
       "hand_L": [k for k in bones if k.startswith("LeftHand")], "hand_R": [k for k in bones if k.startswith("RightHand")],
       "thigh_L": ["LeftUpLeg"], "thigh_R": ["RightUpLeg"], "shin_L": ["LeftLeg"], "shin_R": ["RightLeg"],
       "foot_L": ["LeftFoot", "LeftToeBase", "LeftToe_End"], "foot_R": ["RightFoot", "RightToeBase", "RightToe_End"]}
gk = list(grp)
D = np.full((F, len(gk)), 9.0)
for j, k in enumerate(gk):
    for bn in grp[k]:
        if bn in bones:
            D[:, j] = np.minimum(D[:, j], segdist(fcn, bones[bn][0], bones[bn][1]))
near = np.array(gk)[D.argmin(1)]
Zf = fcn[:, 2]
fcb = X[fv_all].mean(1)
# per-face: is this body face under each item? (nearest-surface inside test on the actual item meshes)
covf = {}
for name, it in items.items():
    o = it["obj"]
    pts = [Vector(o.matrix_world @ v.co) for v in o.data.vertices]
    tr = []
    for p in o.data.polygons:
        q = p.vertices
        tr += [(q[0], q[k], q[k + 1]) for k in range(1, len(q) - 1)]
    bv = BVHTree.FromPolygons(pts, tr)
    covf[name] = np.array([(lambda s: s is not None and s < 0)(signed(bv, fcb[i])) for i in range(F)])
# hair only counts where the hairline mask is opaque
covf["Hair_01"] &= hvv[fv_all].min(1) > 0.6
# keep a strip of skin visible just inside every opening (sleeve, collar, hems, hairline)
ek = {}
for p in body.data.polygons:
    for k_ in p.edge_keys:
        ek.setdefault(k_, []).append(p.index)
pairs = np.array([v for v in ek.values() if len(v) == 2])


def erode(mask, k):
    m_ = mask.copy()
    for _ in range(k):
        bad = np.zeros(F, bool)
        bad[pairs[:, 0][~m_[pairs[:, 1]]]] = True
        bad[pairs[:, 1][~m_[pairs[:, 0]]]] = True
        m_ &= ~bad
    return m_


KE = {"Hair_01": P.get("k_hair", 3), "Top_01": P.get("k_top", 4), "Bottom_01": P.get("k_bottom", 3), "Shoes_01": P.get("k_shoes", 3)}
deep = {name: erode(covf[name], KE[name]) for name in covf}
REG = ["FACE", "SCALP", "NECK", "TORSO_UPPER", "TORSO_LOWER", "PELVIS", "UPPERARM_TOP_L", "UPPERARM_TOP_R",
       "UPPERARM_LOW_L", "UPPERARM_LOW_R", "FOREARM_L", "FOREARM_R", "HAND_L", "HAND_R", "THIGH_L", "THIGH_R",
       "SHIN_L", "SHIN_R", "FOOT_L", "FOOT_R", "ANKLE_L", "ANKLE_R"]
reg = np.zeros(F, np.int32)
cH, cT, cB, cS = deep["Hair_01"], deep["Top_01"], deep["Bottom_01"], deep["Shoes_01"]
for i in range(F):
    k, z = near[i], Zf[i]
    if k == "head":
        r = "SCALP" if cH[i] else ("FACE" if z > 0.76 else "NECK")
    elif k == "spine":
        if cB[i] and z < 0.51:
            r = "PELVIS"
        elif cT[i]:
            r = "TORSO_UPPER" if z > 0.56 else "TORSO_LOWER"
        else:
            r = "NECK"
    elif k.startswith("uarm"):
        r = ("UPPERARM_TOP_" if cT[i] else "UPPERARM_LOW_") + k[-1]
    elif k.startswith("farm"):
        r = "FOREARM_" + k[-1]
    elif k.startswith("hand"):
        r = "HAND_" + k[-1]
    elif k.startswith("thigh"):
        r = ("PELVIS" if z > 0.40 else "THIGH_" + k[-1]) if cB[i] else "ANKLE_" + k[-1]
    elif k.startswith("shin"):
        r = ("FOOT_" if cS[i] else ("SHIN_" if cB[i] else "ANKLE_")) + k[-1]
    else:
        r = ("FOOT_" if cS[i] else "ANKLE_") + k[-1]
    if r == "NECK" and z > 0.78:
        r = "FACE"
    reg[i] = REG.index(r)
ra = body.data.attributes.new("region", "INT", "FACE")
ra.data.foreach_set("value", reg)
cover = {name: {rn: round(float(covf[name][reg == ri].mean()), 4) for ri, rn in enumerate(REG) if (reg == ri).sum()} for name in items}
thr = P.get("cover_thr", 0.99)
hides = {name: [rn for rn, v in fr.items() if v >= thr and rn not in ("FACE", "HAND_L", "HAND_R")] for name, fr in cover.items()}
for name, it in items.items():
    it["obj"]["hides_regions"] = json.dumps(hides[name])
json.dump(dict(regions=REG, region_face_counts={rn: int((reg == i).sum()) for i, rn in enumerate(REG)}, coverage=cover, hides=hides),
          open(OUT + "/regions_v01.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
np.save(S + "/region.npy", reg)
print("HIDES", json.dumps(hides))

# ---------- save ----------
bpy.data.objects.remove(src)
col = bpy.data.collections.new("Outfit_01")
sc.collection.children.link(col)
for name, it in items.items():
    for c in list(it["obj"].users_collection):
        c.objects.unlink(it["obj"])
    col.objects.link(it["obj"])
rig.data.pose_position = "POSE"
bpy.ops.wm.save_as_mainfile(filepath=OUT + "/character_modular_v01.blend")
print("SAVED", round(time.time() - T0, 1))
