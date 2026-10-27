extends RefCounted
## 캐릭터 4종(삐죽이·바가지·반짝이·뽀글이)과 바텐더 시안, 1인칭 손의 외형을 코드로 만든다.
## 몸 생성은 pub_builder.gd 가 실행할 때만 쓰인다(게임 실행 중에는 저장된 chr_*.tscn 을 쓴다).
## 단, create_hand() 는 F5 게임이 시작할 때 GameView 가 직접 부른다(자리 색 소매).
##
## 디자인 규칙(DARTY 디자인 진행 프롬프트 v2): 약 3등신(머리 0.52m = 키의 32%), 키 약 1.6m,
## 같은 몸·얼굴 + 머리 실루엣 1개 + 얼굴 수치 1개만 다르게, 부위별 단색 재질 M_Skin/M_Hair/M_Top/M_Bottom/M_Shoes.
## 좌표: 원점 = 두 발 사이 바닥, 정면 = +Z. 팀 플레이어(game/player)는 -Z 정면이라 PlayerView 가 모델만 180도 돌린다.
##
## [관절(피벗) 구조] 2026-10-26 추가 — 뼈대(스켈레톤) 없이도 팔다리를 움직이려고 부위를 "돌리는 점" 아래에 묶었다.
##   SPIKE (루트, 발바닥 가운데)
##   ├─ LegL / LegR      골반 옆(높이 0.59m)에서 다리 전체가 돈다 → 걷기·앉기
##   └─ Body             골반 가운데(0.59m). 위아래로 옮기면 숙이기, 앞으로 기울이면 구부정
##      ├─ ArmL / ArmR   어깨(0.94m)에서 팔 전체가 돈다 → 팔 흔들기·조준·던지기
##      └─ Neck          목(1.07m)에서 머리가 돈다 → 위아래 보기
## 움직이는 코드는 character_rig.gd. 나중에 블렌더 리깅 모델(.glb)로 바꾸면 이 구조 대신 Skeleton3D 를 쓴다.
## 아래 좌표 숫자는 "루트 기준 실제 위치(m)" 그대로 적고 피벗 위치를 빼서 넣는다 → 디자인 수치표와 바로 비교할 수 있다.
##
## 왼쪽/오른쪽(L/R)은 캐릭터 본인 기준이다. 캐릭터가 +Z 를 보므로 본인의 왼쪽 = +X.

const MeshKit = preload("res://art/mesh_kit.gd")

## 씬 파일 이름(chr_<이름 소문자>.tscn)과 루트 노드 이름에 쓰인다. 바꾸면 PlayerLook.CHARACTER_SCENES 도 바꾼다.
const NAMES = ["SPIKE", "BOWL", "GLOSS", "CURL"]
const SKIN_COLORS = ["d5a579", "bf8c68", "e4bd92", "936547"]
## 바텐더 NPC 시안(기획 2-4: 같은 몸 재활용, 민머리 + 콧수염 + 조끼, 플레이어와 확실히 다르게). 팀 확정 전 자리표시.
const BARTENDER_NAME := "BARTENDER"

## 관절 위치(루트 기준, m). x 가 있는 값은 왼쪽(+X) 기준이고 오른쪽은 x 에 -1 을 곱한다.
const HIP := Vector3(0, 0.59, 0)
const LEG_X := 0.105
const SHOULDER := Vector3(0.19, 0.94, 0)
const NECK := Vector3(0, 1.07, 0)


## 플레이어 캐릭터(index 0~3). 색은 PlayerLook(자리 약속표)에서 가져온다.
static func create(index: int) -> Node3D:
	# 얼굴 수치 차이: 바가지는 눈이 작고(0.7) 반짝이는 크다(1.2). 눈썹 높이는 삐죽이 높음, 뽀글이 낮고 八자.
	var eye_scale: float = 0.7 if index == 1 else (1.2 if index == 2 else 1.0)
	var brow_y: float = 1.48 if index == 0 else (1.40 if index == 3 else 1.44)
	return _build(NAMES[index], index, SKIN_COLORS[index], PlayerLook.hex(index), eye_scale, brow_y, 0.3 if index == 3 else 0.0, index)


## 바텐더 시안: 흰 셔츠 + 조끼 + 나비넥타이 + 콧수염, 민머리. 펍 바 뒤에 서 있는 NPC 자리표시.
static func create_bartender() -> Node3D:
	var root := _build(BARTENDER_NAME, 9, "c99a72", "e9e3d6", 0.9, 1.43, 0.0, 4)
	var body := root.get_node("Body") as Node3D
	var vest := MeshKit.material("M_Vest", "3c2a22")
	MeshKit.cylinder(body, "Vest", 0.212, 0.40, Vector3(0, 0.80, 0.004) - HIP, vest, 8, 0.182)
	var tie := MeshKit.material("M_BowTie", "8e2f2b")
	for side in [-1.0, 1.0]:
		var wing := MeshKit.box(body, "BowTie" + _side_name(side), Vector3(0.06, 0.045, 0.02), Vector3(side * 0.03, 1.0, 0.19) - HIP, tie)
		wing.rotation.z = side * 0.35
	return root


## 1인칭 손(투척 화면 오른쪽 아래). 카메라 자식(Camera/Hand)으로 붙는다: -Z 가 화면 안쪽, 원점 = 손에 든 다트 촉.
## 주먹(피부색)이 다트 몸통을 아래에서 쥐고, 소매(자리 색)는 오른쪽 아래 화면 밖으로 빠진다.
## 소매를 카메라 쪽(+Z)으로 곧게 두면 화면을 크게 가리므로 비스듬히(아래·오른쪽) 뺀다. 그림자는 끈다.
static func create_hand(index: int) -> Node3D:
	var hand := Node3D.new()
	hand.name = "FirstPersonHand"
	var skin := MeshKit.material("M_Skin_" + str(index), SKIN_COLORS[index % SKIN_COLORS.size()])
	var top := MeshKit.material("M_Top_" + str(index), PlayerLook.hex(index))
	var parts: Array[MeshInstance3D] = []
	parts.append(MeshKit.sphere(hand, "Mitten", 0.038, Vector3(0, -0.028, 0.075), skin, Vector3(1.0, 0.9, 1.3)))
	var thumb := MeshKit.sphere(hand, "Thumb", 0.016, Vector3(-0.03, -0.006, 0.05), skin, Vector3(1, 1, 1.6))
	thumb.rotation.y = 0.5
	parts.append(thumb)
	# 손목 → 팔꿈치 방향: 아래(-Y)·오른쪽(+X)·뒤(+Z). 끝이 카메라 화면 아래 모서리 밖에 있다.
	var wrist := Vector3(0.012, -0.045, 0.115)
	var cuff_end := Vector3(0.04, -0.085, 0.17)
	var elbow := Vector3(0.16, -0.30, 0.40)
	parts.append(MeshKit.rod(hand, "Cuff", wrist, cuff_end, 0.042, top))
	parts.append(MeshKit.rod(hand, "Sleeve", cuff_end, elbow, 0.055, top))
	for part in parts:
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return hand


## 몸 전체를 관절 구조로 조립한다. hair_style: 0 삐죽이 · 1 바가지 · 2 반짝이 · 3 뽀글이 · 4 바텐더(콧수염).
static func _build(root_name: String, key: int, skin_hex: String, top_hex: String, eye_scale: float, brow_y: float, brow_tilt: float, hair_style: int) -> Node3D:
	var root := Node3D.new()
	root.name = root_name
	var skin := MeshKit.material("M_Skin_" + str(key), skin_hex)
	var hair := MeshKit.material("M_Hair", "322b29")
	var top := MeshKit.material("M_Top_" + str(key), top_hex)
	# 캐시 key 는 캐릭터마다 다르지만, 블렌더·에디터에서 보이는 재질 이름은 규칙대로 통일한다.
	skin.resource_name = "M_Skin"
	top.resource_name = "M_Top"
	var bottom := MeshKit.material("M_Bottom", "303d43")
	var shoes := MeshKit.material("M_Shoes", "ece1c6")
	var white := MeshKit.material("M_EyeWhite", "fff4de")
	var dark := MeshKit.material("M_Pupil", "171f24")
	var mouth := MeshKit.material("M_Mouth", "563e36")
	var body := _pivot(root, "Body", HIP)
	var neck := _pivot(body, "Neck", NECK - HIP)
	# --- 다리·신발(LegL/LegR) · 팔(ArmL/ArmR) ---
	for side in [-1.0, 1.0]:
		var hip := Vector3(side * LEG_X, HIP.y, 0)
		var leg := _pivot(root, "Leg" + _side_name(side), hip)
		MeshKit.box(leg, "Sole", Vector3(0.15, 0.045, 0.29), Vector3(side * 0.105, 0.03, 0.045) - hip, shoes)
		MeshKit.box(leg, "HighTop", Vector3(0.142, 0.13, 0.25), Vector3(side * 0.105, 0.11, 0.035) - hip, top)
		MeshKit.box(leg, "Toe", Vector3(0.144, 0.075, 0.095), Vector3(side * 0.105, 0.075, 0.16) - hip, shoes)
		MeshKit.cylinder(leg, "Trouser", 0.067, 0.44, Vector3(side * 0.102, 0.37, 0) - hip, bottom, 6)
		var shoulder := Vector3(side * SHOULDER.x, SHOULDER.y, SHOULDER.z)
		var arm := _pivot(body, "Arm" + _side_name(side), shoulder - HIP)
		MeshKit.rod(arm, "Sleeve", Vector3.ZERO, Vector3(side * 0.255, 0.62, 0.025) - shoulder, 0.075, top)
		MeshKit.cylinder(arm, "Cuff", 0.065, 0.07, Vector3(side * 0.255, 0.58, 0.03) - shoulder, top, 6)
		# 손끝은 후드티 밑단(0.58m)보다 약 7cm 아래 — v2 비율 실측값.
		MeshKit.sphere(arm, "Hand", 0.061, Vector3(side * 0.257, 0.52, 0.038) - shoulder, skin, Vector3(0.8, 1.15, 0.8))
	# --- 몸통: 후드티 ---
	MeshKit.cylinder(body, "Hoodie", 0.205, 0.49, Vector3(0, 0.825, 0) - HIP, top, 8, 0.175)
	MeshKit.box(body, "Pocket", Vector3(0.23, 0.12, 0.025), Vector3(0, 0.72, 0.187) - HIP, top)
	MeshKit.sphere(body, "Hood", 0.19, Vector3(0, 1.015, -0.03) - HIP, top, Vector3(1.0, 0.45, 1.0))
	for side in [-1.0, 1.0]:
		MeshKit.rod(body, "Drawstring" + _side_name(side), Vector3(side * 0.065, 1.0, 0.156) - HIP, Vector3(side * 0.065, 0.87, 0.193) - HIP, 0.008, shoes)
	# --- 머리: 8각 원통 0.52m (전체 키의 약 32%) ---
	MeshKit.cylinder(neck, "Head", 0.165, 0.52, Vector3(0, 1.34, 0.018) - NECK, skin, 8)
	for side in [-1.0, 1.0]:
		var s := _side_name(side)
		MeshKit.sphere(neck, "Ear" + s, 0.043, Vector3(side * 0.166, 1.30, 0.015) - NECK, skin)
		MeshKit.sphere(neck, "Eye" + s, 0.048 * eye_scale, Vector3(side * 0.069, 1.34, 0.171) - NECK, white, Vector3(0.85, 1.18, 0.3))
		MeshKit.sphere(neck, "Pupil" + s, 0.014, Vector3(side * 0.079, 1.337, 0.187) - NECK, dark, Vector3(0.8, 1.1, 0.28))
		var brow := MeshKit.box(neck, "Brow" + s, Vector3(0.065, 0.018, 0.018), Vector3(side * 0.069, brow_y, 0.177) - NECK, hair)
		brow.rotation.z = side * brow_tilt
	MeshKit.sphere(neck, "Mouth", 0.027, Vector3(0.013, 1.18, 0.177) - NECK, mouth, Vector3(0.8, 0.8, 0.25))
	MeshKit.box(neck, "Nose", Vector3(0.033, 0.048, 0.035), Vector3(0, 1.278, 0.179) - NECK, skin)
	# --- 머리 실루엣: 캐릭터마다 하나씩만 다르다 ---
	match hair_style:
		0: # 삐죽이 SPIKE — 위로 솟은 5각 뿔 하나
			MeshKit.cylinder(neck, "HairCap", 0.168, 0.08, Vector3(0, 1.58, 0.018) - NECK, hair, 8)
			var tuft := MeshKit.cylinder(neck, "SignatureSpike", 0.075, 0.22, Vector3(0.025, 1.70, 0.012) - NECK, hair, 5, 0.0)
			tuft.rotation.z = -0.23
		1: # 바가지 BOWL — 덮어쓴 바가지 머리
			MeshKit.cylinder(neck, "SignatureBowl", 0.188, 0.19, Vector3(0, 1.535, 0.01) - NECK, hair, 10, 0.17)
		2: # 반짝이 GLOSS — 민머리 + 옆머리만
			for side in [-1.0, 1.0]:
				MeshKit.box(neck, "SideHair" + _side_name(side), Vector3(0.035, 0.18, 0.14), Vector3(side * 0.162, 1.46, -0.005) - NECK, hair)
		3: # 뽀글이 CURL — 둥근 컬 9개 + 정수리
			for i in range(9):
				var a := TAU * i / 9.0
				MeshKit.sphere(neck, "SignatureCurl%d" % (i + 1), 0.09, Vector3(cos(a) * 0.12, 1.59 + (i % 2) * 0.035, sin(a) * 0.12) - NECK, hair)
			MeshKit.sphere(neck, "CurlTop", 0.115, Vector3(0, 1.68, 0) - NECK, hair)
		4: # 바텐더 — 민머리 + 옆머리 + 콧수염
			for side in [-1.0, 1.0]:
				MeshKit.box(neck, "SideHair" + _side_name(side), Vector3(0.035, 0.14, 0.15), Vector3(side * 0.162, 1.42, -0.01) - NECK, hair)
				var moustache := MeshKit.box(neck, "Moustache" + _side_name(side), Vector3(0.07, 0.022, 0.03), Vector3(side * 0.036, 1.225, 0.186) - NECK, hair)
				moustache.rotation.z = side * -0.25
	return root


## 관절(돌리는 점) 노드. 메시 없이 위치만 가진다. 이 노드를 돌리면 아래 부위가 같이 돈다.
static func _pivot(parent: Node3D, pivot_name: String, local_position: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = pivot_name
	node.position = local_position
	parent.add_child(node)
	return node


## +X 쪽이 캐릭터 본인의 왼쪽(L)이다(정면 +Z).
static func _side_name(side: float) -> String:
	return "L" if side > 0 else "R"
