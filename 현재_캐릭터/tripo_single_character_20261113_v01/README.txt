오른쪽 캐릭터 제거 완료

사용자가 보낸 Tripo 스크린샷 기준 오른쪽 옆모습 캐릭터를 제거하고,
왼쪽 정면 캐릭터 한 명만 남겼다.

character_left_only.glb   : 텍스처를 포함한 단일 GLB 파일
character_left_only.fbx   : 텍스처를 내장한 FBX 파일
character_left_only.blend : 텍스처를 포함한 Blender 편집 파일
character_left_only.zip  : 위 세 파일과 이 안내를 묶은 ZIP
kept_front.png / kept_three_quarter.png / kept_back.png : 수정 결과 미리보기

보존 내용
- 왼쪽 캐릭터의 정점 좌표, 원래 면, UV, 원본 텍스처를 유지했다.
- 폴리곤 수를 줄이거나 모델을 새로 만들지 않았다.
- 오른쪽 인물과 연결된 면이 없음을 확인한 뒤 공간적으로 분리된 오른쪽 전체만 제거했다.
- 원래 오브젝트의 위치·회전·크기를 유지했다.
- 남은 메시: 479,219 정점 / 958,434 삼각형.

검증
- Blender 파일 재열기, GLB 재가져오기, FBX 재가져오기에서 모두 캐릭터 메시 한 개만 확인했다.
- 세 형식의 남은 면 수와 공간 범위가 일치한다.
- Blender 파일의 정점 좌표, UV, 내장 텍스처는 원래 왼쪽 자료와 해시가 일치한다.
- 원본 다운로드 ZIP과 원본 FBX는 변경하지 않았다.

상세 기록: removal_report.json / verification.json
