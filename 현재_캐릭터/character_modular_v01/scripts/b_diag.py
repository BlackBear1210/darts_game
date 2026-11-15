# render the bare Body head in 4 modes: full / colour only / clay / normal only
import bpy, sys, json
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
RDIR, tag, shots = a[0], a[1], json.loads(a[2])
sc = bpy.context.scene
rig = next(o for o in sc.objects if o.type == "ARMATURE")
rig.data.pose_position = "REST"
body = bpy.data.objects["Body"]
for o in sc.objects:
    if o.type == "MESH" and o is not body:
        o.hide_render = True
mat = body.data.materials[0]
nt = mat.node_tree
P = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
base_link = P.inputs["Base Color"].links[0]
base_src = base_link.from_socket
nm = next(n for n in nt.nodes if n.type == "NORMAL_MAP")
for o in list(sc.objects):
    if o.type in ("CAMERA", "LIGHT"):
        bpy.data.objects.remove(o)
sc.render.engine = "BLENDER_EEVEE"; sc.view_settings.view_transform = "Standard"
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs[0].default_value = (0.4, 0.4, 0.42, 1); bg.inputs[1].default_value = 0.6
for d_, e in [((-0.9, -0.4, 0.9), 3.5), ((0.7, 0.5, 0.4), 1.0), ((-0.2, 0.9, 0.3), 1.2)]:
    Ld = bpy.data.lights.new("s", "SUN"); Ld.energy = e
    ob = bpy.data.objects.new("s", Ld); sc.collection.objects.link(ob)
    ob.rotation_euler = (Vector(d_) * -1).to_track_quat("-Z", "Y").to_euler()
cd = bpy.data.cameras.new("c"); cd.type = "ORTHO"
cam = bpy.data.objects.new("c", cd); sc.collection.objects.link(cam); sc.camera = cam
sc.render.resolution_x = 600; sc.render.resolution_y = 600
strength0 = nm.inputs["Strength"].default_value
for mode in ("full", "color", "clay", "normal"):
    for l in list(P.inputs["Base Color"].links):
        nt.links.remove(l)
    if mode in ("full", "color"):
        nt.links.new(base_src, P.inputs["Base Color"])
    else:
        P.inputs["Base Color"].default_value = (0.6, 0.6, 0.6, 1)
    nm.inputs["Strength"].default_value = strength0 if mode in ("full", "normal") else 0.0
    for s_ in shots:
        t = Vector(s_["at"]); dd = Vector(s_["dir"]).normalized()
        cd.ortho_scale = s_["s"]; cam.location = t + dd * 5
        cam.rotation_euler = (-dd).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = f"{RDIR}/{tag}_{mode}_{s_['name']}.png"
        bpy.ops.render.render(write_still=True)
print("DONE")
