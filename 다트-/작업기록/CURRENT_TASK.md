# 현재 작업

- 작업: 게임진행흐름도.png 기반의 실행 가능한 게임 진행 청사진.
- 상태: 구현·검증 완료. 로컬 흐름/렌더와 기존 경기 회귀 검증 PASS.
- 범위: 독립적인 F6 시연 씬. 가상 2~4인, 방/설정/집합/카드/순서/3발/라운드 반복/목표 근접 순위.
- 실행: game/flow_preview/flow_preview.tscn을 열고 F6. F5는 기존 3D 경기다.
- 구조: game_flow.gd가 UI 독립 단계 모델, flow_preview.gd가 버튼 UI. 실제 네트워크·물리·백엔드에는 연결하지 않는다.
- 미정: 카드 지급/효과, 순서 결정, 교환 횟수, 종료/동점 규칙은 시연값으로 표시. docs/GAME_FLOW_BLUEPRINT.md에 팀원 후속 연결 위치 정리.
- 검증: tests/test_game_flow.gd의 2·3·4인 완주/분기/수량/순위/초기화 PASS. 실제 D3D12 시작/4인 조준/결과 및 작은 창 렌더 PASS. tests/test_rules.gd PASS.
- 회귀: tests/run_first_idea.py 실제 2·3·4인 5라운드/동일 점수/중복·잘못된 요청 거부/재경기/20초 시간 초과/봇 교체 PASS. 로그 .godot/prototype_tests/1792112100698013800/. Git diff 자체 검토와 diff --check 완료.
- 화면: .godot/flow_preview_render/. 사람의 물리 마우스 조작·실제 경기 연결은 미검증. 알려진 Windows 인증서 저장소/에디터 설정 저장 환경 오류는 남는다.
- 이전 로그인·프로필·전적 구현과 실행 안내: docs/BACKEND_DEV.md, 작업기록/HANDOFF.md의 이전 기록을 참고한다.
