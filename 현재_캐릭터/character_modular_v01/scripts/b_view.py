# render the saved modular file at rest: dressed (covered body regions hidden) and bare
import bpy, sys, json
import numpy as np
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
OUT, RDIR, shots = a[0], a[1], json.loads(a[2])
sc = bpy.context.scene
rig = next(o for o in sc.objects if o.type == "ARMATURE")
rig.data.pose_position = "REST"
body = bpy.data.objects["Body"]
items = [bpy.data.objects[n] for n in ("Hair_01", "Top_01", "Bottom_01", "Shoes_01")]
R = json.load(open(OUT + "/regions_v01.json", encoding="utf-8"))
REG = R["regions"]
hide = sorted(set(sum(R["hides"].values(), [])))
reg = np.zeros(len(body.data.polygons), np.int32)
body.data.attributes["region"].data.foreach_get("value", reg)
inv = bpy.data.materials.new("M_Hidden"); inv.use_nodes = True
nt = inv.node_tree
for n in list(nt.nodes):
    nt.nodes.remove(n)
o_ = nt.nodes.new("ShaderNodeOutputMaterial"); tr = nt.nodes.new("ShaderNodeBsdfTransparent")
nt.links.new(tr.outputs[0], o_.inputs["Surface"])
body.data.materials.append(inv)
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
for mode in ("dressed", "bare"):
    mi = np.zeros(len(reg), np.int32)
    if mode == "dressed":
        mi[np.isin(reg, [REG.index(n) for n in hide])] = 1
    body.data.polygons.foreach_set("material_index", mi); body.data.update()
    for o in items:
        o.hide_render = (mode == "bare")
    for s_ in shots:
        t = Vector(s_["at"]); dd = Vector(s_["dir"]).normalized()
        cd.ortho_scale = s_["s"]; cam.location = t + dd * 5
        cam.rotation_euler = (-dd).to_track_quat("-Z", "Y").to_euler()
        sc.render.resolution_x = s_.get("w", 600); sc.render.resolution_y = s_.get("h", 900)
        sc.render.filepath = f"{RDIR}/mv_{mode}_{s_['name']}.png"
        bpy.ops.render.render(write_still=True)
print("DONE")
