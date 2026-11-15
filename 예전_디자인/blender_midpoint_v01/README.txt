DARTY 중간 로우폴리 캐릭터 — Blender 전신 모델링 초안

character_midpoint_v01.blend : 편집 가능한 Blender 파일
character_midpoint_v01.glb   : 다른 3D 도구로 가져올 수 있는 정적 모델
front_and_side.png          : 실제 Blender 정면/측면 렌더
front.png / side.png / three_quarter.png : 개별 전신 렌더
face_detail.png             : 실제 Blender 얼굴 근접 렌더
build_character.py         : 모델 생성 코드
model_report.json / verification.json : 모델 수치 및 재열기 확인 결과

구성
- 얼굴, 눈, 동공, 눈썹, 코, 입, 귀, 머리카락, 목
- 보라색 상의, 양팔과 양손의 다섯 손가락, 바지, 신발
- 약한 거북목과 아주 약한 라운드 숄더를 기본 자세에 반영
- 머리카락은 기존 프로젝트 모델의 실루엣을 중간 시안에 맞게 변형·정리
- 나머지 부위는 별도 메시로 구성. Blender Outliner의 CHARACTER_midpoint에서 편집 가능

기준: output/imagegen/character_midpoint_full_body_front_side_20261112_v02.png
시안 이미지는 Blender 파일에 포함했다. FRONT_AND_SIDE_review 씬에서 비교 렌더 가능.
기본 단위는 미터, 위쪽은 Z, 정면은 -Y. 모델 높이는 약 1.78m.

현재 범위는 외형 모델링 초안이다. 리깅, 스키닝, 애니메이션 및 인게임 교체는 포함하지 않는다.
기존 인게임 모델은 변경하지 않았다. 생성 이미지 시안을 참고해 만든 3D 초안으로,
이미지의 모든 윤곽과 음영이 동일하게 재현된 최종 승인 모델을 의미하지 않는다.
