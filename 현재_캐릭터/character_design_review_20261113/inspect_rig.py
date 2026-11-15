from pathlib import Path
import json
base=Path(r"C:/Users/아버지/Desktop/다트/output/character_design_review_20261113")
setup=(base/"review_model.py").read_text(encoding="utf-8").split("for name,z,scale,offset in [")[0]
exec(compile(setup,"review_setup","exec"))
bones=[]
for rig in rigs:
    for bone in rig.data.bones:
        bones.append({"name":bone.name,"parent":bone.parent.name if bone.parent else None,"head":list(rig.matrix_world@bone.head_local),"tail":list(rig.matrix_world@bone.tail_local),"rest_matrix":[list(row) for row in bone.matrix_local]})
(base/"bones.json").write_text(json.dumps(bones,indent=2),encoding="utf-8")
print(json.dumps([{"name":b["name"],"parent":b["parent"],"head":b["head"],"tail":b["tail"]} for b in bones]),flush=True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(base/"diagnostic_setup.blend"))

