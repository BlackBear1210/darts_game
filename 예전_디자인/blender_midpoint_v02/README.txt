DARTY 중간 로우폴리 캐릭터 v02 — 얼굴과 어깨 수정

기준 시안: ../imagegen/character_midpoint_full_body_front_side_20261112_v02.png
이전 모델: ../blender_midpoint_v01/character_midpoint_v01.blend (보존)

수정 내용
- 눈의 크기를 줄이고 간격과 동공 비율을 조정했다.
- 눈썹의 ㅅ자 각도와 굵기를 시안에 맞게 조정했다.
- 코를 짧게 하고 입 위치를 올려 얼굴의 세로 비율을 바꿨다.
- 볼의 입체 면을 만들고 아래턱 폭과 측면의 후퇴량을 조정했다.
- 기존 몸통과 원통 소매 접합을 대체하여 목-어깨-소매의 전체 윤곽을 새로 만들었다.
- 어깨 끝을 완만하게 내려 라운드 숄더가 아주 약하게 보이도록 했다.
- 거북목 방향의 자세와 기존 손·바지·신발은 유지했다.

파일
character_midpoint_v02.blend : 수정한 편집 파일 (시안 이미지와 글꼴 포함)
character_midpoint_v02.glb   : 수정한 정적 모델
front_and_side.png          : 실제 Blender 정면/측면 렌더
face_detail.png             : 실제 Blender 얼굴 근접 렌더
face_and_shoulders.png      : 얼굴과 어깨를 크게 본 정면/측면 렌더
front.png / side.png / three_quarter.png : 개별 전신 렌더
build_character.py / verify_model.py     : 생성·확인 코드
repair_saved_model.py       : 저장 후 목둘레의 극소 면 정리 (생성 코드에서 자동 실행)
model_report.json / verification.json   : 모델 수치와 확인 결과

현재 범위는 외형 모델링 수정이다. 리깅, 애니메이션 및 인게임 교체는 포함하지 않는다.
기존 인게임 모델 파일은 변경하지 않았다. 시안을 참고해 비율과 윤곽을 다듬은 3D 초안이다.
