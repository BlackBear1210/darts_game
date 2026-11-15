from pathlib import Path
import json,zipfile,hashlib,struct,shutil
import numpy as np
from PIL import Image
out=Path(__file__).resolve().parent
review=out.parent/"character_design_review_20261113"
source_dir=next((review/"source").glob("*.fbm"))
src_base=source_dir/"tripo_image_954d3209-6b1c-413f-9c5c-acc1b483b08f_0_0.jpg"
a=np.array(Image.open(src_base).convert("RGB")).astype(np.int16)
b=np.array(Image.open(out/"character_basecolor_repaired.png").convert("RGB")).astype(np.int16)
delta=np.abs(a-b).max(2)
stats={"texture_resolution":[2048,2048],"unchanged_pixel_fraction":float(np.mean(delta==0)),"changed_over_3_levels_fraction":float(np.mean(delta>3)),"mean_absolute_channel_difference":float(np.abs(a-b).mean())}
# GLB에 최종 보정 텍스처가 실제로 내장되어 있는지 확인한다.
raw=(out/"character_texture_fixed.glb").read_bytes()
n,kind=struct.unpack_from("<II",raw,12)
doc=json.loads(raw[20:20+n]);binstart=28+n
tex=doc["materials"][0]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
im=doc["images"][doc["textures"][tex]["source"]]
view=doc["bufferViews"][im["bufferView"]]
imgbytes=raw[binstart+view.get("byteOffset",0):binstart+view.get("byteOffset",0)+view["byteLength"]]
stats["glb_contains_exact_final_basecolor_png"]=hashlib.sha256(imgbytes).digest()==hashlib.sha256((out/"character_basecolor_repaired.png").read_bytes()).digest()
assert stats["glb_contains_exact_final_basecolor_png"]
assert len(doc["meshes"])==1 and len(doc["skins"][0]["joints"])==65
assert stats["unchanged_pixel_fraction"]>.98
(out/"texture_verification.json").write_text(json.dumps(stats,indent=2),encoding="utf-8")
for old,new in [("fixed_face_front.png","result_face_front.png"),("fixed_left_underarm.png","result_left_underarm.png")]:
    shutil.copyfile(out/old,out/new)
textures=out/"textures";textures.mkdir(exist_ok=True)
for src,dest in [
    ("left_character_kept_Normal_Bake.jpg","normal.jpg"),
    ("character_left_only리깅추가_glb_roughness.JPEG","roughness.jpg"),
    ("character_left_only리깅추가_glb_metallic.JPEG","metallic.jpg"),
]:
    shutil.copyfile(source_dir/src,textures/dest)
source_zip=Path(r"C:/Users/아버지/Downloads/tripo_convert_954d3209-6b1c-413f-9c5c-acc1b483b08f.zip")
sha=hashlib.sha256(source_zip.read_bytes()).hexdigest()
readme=f"""캐릭터 부분 색칠 보정본 — 2026-11-13 v01

수정한 내용
- 양쪽 눈썹 아래 잘못 칠해진 흰색 띠를 주변 피부색에 맞춰 보정했습니다.
- 양쪽 겨드랑이의 셔츠에 묻은 피부색을 보라색으로 보정했습니다.
- 양쪽 팔 안쪽에 묻은 보라색을 주변 피부색으로 보정했습니다.
- 캐릭터를 다시 생성하거나 전체 텍스처를 다시 칠하지 않았습니다.

보존 확인
- 정점 위치, 면 연결, UV, 뼈대, 리깅 가중치가 원본과 정확히 같습니다.
- 원본 구조: 정점 47,466개 / 면 47,464개 / 삼각형 환산 94,928개 / 뼈 65개.
- 얼굴, 눈·동공 크기, 눈썹 모양, 체형, 머리카락, 거북목과 어깨 형태를 유지했습니다.
- 원본 텍스처 픽셀의 {stats["unchanged_pixel_fraction"]*100:.3f}%가 그대로입니다.
- 기존 노멀·거칠기·금속성 맵은 원본을 유지했습니다.
- GLB와 FBX를 다시 열어 메시 1개, 뼈 65개, 삼각형 수와 크기, 리깅을 확인했습니다.
- GLB에 최종 보정 PNG가 정확히 내장되어 있는지 확인했습니다.
- 사용한 원본 ZIP과 게임에 적용되어 있는 캐릭터 파일은 수정하지 않았습니다.

이번 보정의 범위
- 재질의 색만 수정했습니다.
- 팔을 들었을 때 겨드랑이·소매가 찝히는 형태와 변형은 원래 상태로 남아 있습니다.
- 제공된 원본 리깅 파일에는 애니메이션 클립이 없었으며, 이번에도 추가하지 않았습니다.

파일
character_texture_fixed.blend : 편집용 Blender 파일, 사용 텍스처 내장
character_texture_fixed.glb   : 다른 앱으로 옮기거나 Tripo에 업로드할 모델, 텍스처와 리깅 내장
character_texture_fixed.fbx   : FBX 모델, 텍스처와 리깅 내장
character_basecolor_repaired.png : 보정한 기본 색상 맵
textures/ : 원래 노멀·거칠기·금속성 맵의 사본
preview/ : 실제 수정 모델의 렌더
verification/ : 보존 및 재열기 검사 기록

원본 ZIP
{source_zip}
SHA256: {sha}
"""
(out/"README.txt").write_text(readme,encoding="utf-8-sig")
files=[(out/n,n) for n in ["README.txt","character_texture_fixed.blend","character_texture_fixed.glb","character_texture_fixed.fbx","character_basecolor_repaired.png"]]
files.extend((p,"textures/"+p.name) for p in textures.glob("*.jpg"))
files.extend((out/n,"preview/"+n) for n in ["result_face_front.png","fixed_face_quarter.png","fixed_full_front.png","fixed_arms_raised.png","fixed_right_underarm.png","result_left_underarm.png"])
files.extend((out/n,"verification/"+n) for n in ["repair_verification.json","export_verification.json","texture_verification.json"])
zpath=out/"character_texture_fixed_package.zip"
with zipfile.ZipFile(zpath,"w",compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p,n in files:z.write(p,n)
with zipfile.ZipFile(zpath) as z:
    assert z.testzip() is None
    assert len(z.namelist())==len(files)
print(json.dumps({"zip":str(zpath),"bytes":zpath.stat().st_size,"files":len(files),"texture_checks":stats},ensure_ascii=False),flush=True)

