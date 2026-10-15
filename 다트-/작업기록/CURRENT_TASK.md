# 현재 작업

- 작업: 로컬 개발 계정 로그인·프로필·경기 결과 영구 저장 연결.
- 상태: 구현·빌드·자동 검증 완료. 사용자 확인: Steam App ID 없음, 로컬 개발 로그인부터 진행.
- 실행: 프로젝트 루트에서 backend/run_local.ps1 -Role api → 별도 창에서 -Role server → -Role player. 상세: docs/BACKEND_DEV.md.
- 구현: loopback Python 표준 라이브러리 API + SQLite. Main 소유 BackendConnection/HTTPRequest. 서버가 실제 발신자의 사용자 토큰을 API로 검증하고 확인된 계정/이름으로 등록. 익명·같은 계정 중복 입장 거부. 기존 API 미지정 익명/봇 모드는 유지.
- 저장: backend/data/accounts.sqlite3와 server_key.txt (Git/PCK 제외). 정상 5라운드·3발·사람 경기만 집계하고 공동 최고점은 공동 승리. 결과 ID별 트랜잭션/중복 검사. 서버 결과 대기 JSON은 output/builds/server/data/results/에 먼저 기록하고 성공 후 삭제, 재시작 후 복구.
- 검증: tests/test_backend.py의 실제 HTTP/SQLite 비밀번호·만료·권한·점수 경계·동시 중복·충돌·롤백 PASS. tests/run_backend_game.py의 내보낸 서버 + 실제 2인 로그인/익명·중복 계정 거부/5라운드 각 15발 750점/API 중단/서버·API 재시작/디스크 결과 복구/동일 계정/전적 1회/Godot 프로필 갱신 PASS.
- UI: 실제 D3D12 로그인 입력·마스킹/비밀번호 삭제·프로필, 1920×1080/960×540 렌더링 PASS. 저장 이미지를 직접 열어 확인. 작은 화면의 포트 입력 폭 보정.
- 회귀: 기존 실제 2·3·4인 로비/연결·로딩 장벽 PASS. 서버/콘솔/플레이어 기본 실행 및 명시적 로그 저장 PASS. GDScript parse/runtime 오류 없음. Git diff self-review·diff --check 완료.
- 로그: .godot/backend_tests/1792079791521200600/, .godot/backend_unit.log, .godot/network_tests/1792079489041638500/, .godot/startup_tests/1792079973260617600/, .godot/accounts_render.log 및 accounts_render/.
- 남은 범위: 실제 Steam 티켓 인증, HTTPS/외부 배포·운영 DB·여러 방 배정·부하 검증은 아직 없음. API는 의도적으로 localhost 전용. 사람 수동 실행/타 PC/LAN/인터넷은 미검증. 인증서·셰이더 캐시·editor_settings 저장 환경 로그는 남는다.
