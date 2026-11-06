class_name PlayerLook
extends RefCounted
## 자리(seat 0~3)마다 정해진 외형 약속표. 디자인 담당 소유.
## F5 실제 경기(PlayerView·자리 매트·다트 깃·HUD)와 펍 생성기(pub_builder.gd)가 모두 이 표 하나를 본다.
## 색이나 캐릭터를 바꾸고 싶으면 여기만 고친다 → 캐릭터 씬을 다시 생성(art/README.md 의 생성 명령).
##
## 디자인 규칙(DARTY 디자인 진행 프롬프트 2-4): 표식 = 색 + 모양(●▲■◆). 색약이어도 구분되게
## 발밑 매트·이름표·다트 깃·점수판에 같은 색과 모양을 같이 쓴다.

## 플레이어 대표색. 펍의 따뜻한 조명 아래에서 고른 값(쇼케이스에서 확인). 순서 = 자리 번호.
const COLORS: Array[Color] = [Color("cf594f"), Color("4e92bd"), Color("ddb548"), Color("9b77b9")]
## 표식 모양. 이름표·점수판 글자 앞에 붙는다.
const SYMBOLS: Array[String] = ["●", "▲", "■", "◆"]
## 발밑 매트를 그릴 때 쓰는 원기둥 면 수(원·삼각·사각·마름모). 마름모는 사각을 45도 돌린다.
const MAT_SIDES: Array[int] = [32, 3, 4, 4]
## 화면에 보이는 캐릭터 이름(기획 2-4).
const CHARACTER_NAMES: Array[String] = ["삐죽이", "바가지", "반짝이", "뽀글이"]
## 플레이어·봇 공용 리깅 캐릭터. character_library.glb 를 상속해 기본 차림 조각만 보이게 둔 씬이다.
## 에디터에서 이 씬을 열면 게임과 같은 모습이 보인다. 옷을 갈아입히려면 조각의 보이기를 켜고 끈다.
## GLB 를 만드는 곳: character_assets/reference_character_20261105/game_ready_v19/build_game_motions.py
const CHARACTER_SCENE: String = "res://art/characters/rigged/player_character.tscn"
## 자리 색으로 칠하는 셔츠 재질 이름. 같은 캐릭터 네 명을 자리 색으로 구분한다.
const SHIRT_MATERIAL: String = "Ref_Shirt_Plum"


## seat 자리의 캐릭터를 새로 만든다. 정면은 -Z 이고, 모션은 CharacterMotion 이 튼다.
static func character(seat: int) -> Node3D:
	var model := (load(CHARACTER_SCENE) as PackedScene).instantiate() as Node3D
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if material != null and material.resource_name == SHIRT_MATERIAL:
				var shirt := material.duplicate() as StandardMaterial3D
				shirt.albedo_color = COLORS[seat % COLORS.size()]
				mesh.set_surface_override_material(surface, shirt)
	return model


## 이름표·점수판용 "● 이름" 글자.
static func tag(seat: int, display_name: String) -> String:
	return "%s %s" % [SYMBOLS[seat % SYMBOLS.size()], display_name]


## 색을 "cf594f" 같은 16진 글자로(MeshKit.material 이 글자 색을 받는다).
static func hex(seat: int) -> String:
	return COLORS[seat % COLORS.size()].to_html(false)
