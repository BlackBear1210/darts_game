"""clean_colors.json 의 단색 값을 열린 Blender 재질에 넣는다.

실행: python blender_live.py run apply_colors.py
"""
import json

import bpy

PATH = r"C:\Users\아버지\Desktop\다트\output\character-base-v01\clean_colors.json"
NAMES = {"skin": "M_Skin", "hair": "M_Hair", "top": "M_Top", "bottom": "M_Bottom", "shoes": "M_Shoes"}
with open(PATH, encoding="utf-8") as file:
    colors = json.load(file)
for key, name in NAMES.items():
    bsdf = next(n for n in bpy.data.materials[name].node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*colors[key], 1)
    print(name, colors[key])
