set -e
V=$1
S="$(cygpath -m "$PWD")"
B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
BL="C:/Users/아버지/Desktop/다트/output/character_texture_fix_20261113_v01/character_texture_fixed.blend"
python -X utf8 repair.py r/tex_$V.png
python -X utf8 normals.py
"$B" -b "$BL" --python b_baketan.py -- "$S" 2>&1 | grep -E "BAKED|Error" || true
python -X utf8 compnm.py r/normal_$V.png
"$B" -b "$BL" --python rend.py -- "$S/r" '[["'$V'_front",[0,0,0.865],0.16,[-4,0,0]],["'$V'_head",[0,0,0.86],0.3,[-4,-2,0.2]],["'$V'_temple",[0,0.06,0.87],0.12,[-2,4,0]],["'$V'_temple2",[0,-0.06,0.87],0.12,[-2,-4,0]],["'$V'_torso",[0,0,0.65],0.25,[-4,0,0]],["'$V'_nape",[0,0,0.8],0.2,[4,-2,0.3]]]' "$S/r/tex_$V.png" "$S/r/normal_$V.png" 2>&1 | grep -iE "error" || true
echo PIPE_DONE
