# 최신 인수인계 — 게임 진행 청사진 (2026-10-16)

- 사용자 요청: 첨부 흐름도의 단순한 내용만 큰 틀로 구현하고 상세 구현은 팀원이 진행한다.
- `game/flow_preview/flow_preview.tscn`을 열고 F6으로 실행한다. 기존 F5 3D 경기와 별개인 버튼 시연이다. 가상 참가자를 실제 네트워크 클라이언트로 해석하지 않는다.
- `game_flow.gd`는 UI 독립 단계·반복 모델, `flow_preview.gd`는 표시/설정/버튼이다. 방 입장부터 카드 사용/미사용, 매 차례 3발, 페이크/취소, 전원 테이블 복귀, 카드 정비·선택적 2장→1장 교환, 목표 점수 차이 순위까지 연결했다.
- 이동/복귀/카드 효과/방해/투척 물리는 단계 표시와 점수 입력으로 대체한다. 시작 3장·중간 1장, 고정 순서, 교환 각자 1회, 2라운드, 공동 순위는 모두 임시값이다. 이전 카드 구현을 활성화하지 않았다.
- 팀원 분담과 실제 MatchController/NetworkSession/Game/카드/백엔드 연결 위치는 `docs/GAME_FLOW_BLUEPRINT.md`를 읽는다. 실제 경기 권한·네트워크·백엔드 정책 변경은 이번에 하지 않았다.
- `tests/test_game_flow.gd`: 실제 2·3·4인 진행 모델 완주, 카드 양쪽 분기, 취소 발수 유지, 중복/잘못된 점수 거부, 교환 횟수/수량, 빈 손패, 목표 차이 공동 순위와 초기화 PASS. 시연 씬 headless 실행 PASS.
- `-- --render` 실행: 실제 D3D12 시작/4인 조준/결과, 960×540 창 렌더 PASS. `.godot/flow_preview_render/` 이미지를 직접 열어 확인하고 설정 제목 줄바꿈을 보정했다. 화면은 OS 창 크기 보정으로 큰 창의 실제 캡처가 1875×1055다.
- 기존 `tests/test_rules.gd` PASS. Windows 인증서 저장소 읽기와 import의 작업 영역 밖 에디터 설정 저장 오류는 기존 환경 로그다. 사람 수동 조작, LAN/인터넷, 실제 경기와 이 청사진의 통합은 미검증이다.
- 기존 `tests/run_first_idea.py` 전체 PASS: 실제 2·3·4인 이동/착석/입력 소유권/5라운드·각 15발·750점/동일 착탄과 점수/중복·잘못된 요청 거부/재경기/실제 20초 시간 초과/사람 3명의 봇 교체. 로그 `.godot/prototype_tests/1792112100698013800/`. Git diff 자체 검토와 diff --check 완료. 네트워크 코드를 수정하지 않아 별도의 로비/전용 서버/계정 전체 시험은 재실행하지 않았다.
- 기존 실행 파일은 다시 내보내지 않았다. 현재 씬을 Godot 에디터에서 실행한다.

---

# 이전 인수인계 — 로컬 개발 로그인·프로필·전적 (2026-10-16)

## 현재 구현과 실행

- 사용자 확인: 아직 Steam App ID가 없어 로컬 개발 로그인부터 연결했다. Steam 인증을 구현/검증한 것으로 취급하지 않는다.
- docs/BACKEND_DEV.md를 읽는다. backend/run_local.ps1의 api → server → player를 별도 PowerShell 창에서 실행한다. API/서버 키 파일은 최초 실행 시 backend/data/server_key.txt에 생성하고 콘솔에 출력하지 않는다. Python 3.10+ 필요, pip 의존성 없음. 실행 스크립트는 문법 검사만 수행했고 사람의 직접 실행은 미검증이다.
- API는 127.0.0.1:8080의 개발 전용 HTTP/SQLite 서비스다. --dev와 DART_SERVER_KEY(ASCII 32자 이상)가 없으면 시작하지 않는다. DB/키는 backend/data/, 결과 대기 파일은 output/builds/server/data/results/이며 Git 제외다. backend/*는 모든 export preset에서 제외했다.
- Main --backend-url 지정 시 자식 BackendConnection을 생성한다. 로그인/프로필, 서버 토큰 검증, 정상 완주 결과 디스크 대기/전송을 담당하며 게임 물리·점수는 기존 MatchController가 소유한다. API 미지정이면 기존 익명/봇 모드를 유지한다. 계정 모드에서는 전용 서버에 참가한다.
- NetworkSession은 토큰 검증 응답의 계정 ID·이름을 실제 RPC 발신자에 묶는다. 계정 ID 매핑은 서버 전용이고 공개 스냅샷에 키/토큰을 넣지 않는다. 같은 계정 중복 입장은 거부한다. 비밀번호는 salt+PBKDF2-SHA256, 토큰은 SHA256 해시/24시간 만료로 저장한다.
- 전적 정책: 현재 5라운드·턴당 3발의 정상 완주/사람 경기만 집계한다. 중도 이탈/봇/다른 규칙은 제외한다. 최고 점수 공동 승리다. 미구현 목표 점수 근접 모드의 출시 규칙을 확정한 것은 아니다.
- 결과 ID는 경기/재경기마다 새 무작위 128bit다. 파일을 먼저 기록하고 저장 ACK 후 삭제한다. API 장애는 5초 재시도, 서버 재시작 후도 복구한다. 백엔드는 같은 ID·같은 결과를 1회만 반영하며 내용 충돌은 409다. Godot JSON 재로드의 정수→실수 차이를 정규화했다.

## 실제 확인

- tests/test_backend.py: 실제 HTTP/SQLite 로그인 재사용/비밀번호/토큰 해시·만료/서버 권한/점수 경계/동시 중복·충돌·롤백 PASS (.godot/backend_unit.log).
- tests/run_backend_game.py: 내보낸 서버+2개 실제 클라이언트의 로그인→익명·동일 계정 거부→5라운드 각 15발/750점→API 중단→서버/API 재시작→대기 JSON 복구/삭제→동일 계정/중복 없는 전적→Godot 프로필 갱신 PASS. 최종: .godot/backend_tests/1792079791521200600/.
- 기존 실제 2·3·4인 로비/연결·로딩 장벽 PASS: .godot/network_tests/1792079489041638500/. 기본 EXE/콘솔/D3D12 플레이어 시작과 명시적 로그 PASS: .godot/startup_tests/1792079973260617600/.
- tests/render_accounts.gd: 실제 로그인 UI·마스킹/비밀번호 삭제·프로필, 1920×1080와 960×540 PASS. .godot/accounts_render/01_account_profile.png, 02_account_small.png를 열어 확인했다. 작은 창 포트 입력 최소 폭 160 보정.
- GDScript parse/runtime 오류 없음, Git diff self-review·diff --check 완료. 인증서/셰이더 캐시/editor_settings 저장 환경 오류는 남는다. API 장애 시험의 HTTP 0 재시도 로그는 의도한 실패다.

## 이후 범위

- Steam 티켓/보유권 검증, 외부 HTTPS·운영 DB·서버 배정/다중 방·부하 시험은 아직 없다. 현재 계정 API는 localhost 전용이며 개발 계정을 Steam 계정으로 간주하지 않는다.
- 사람이 직접 실행 스크립트/마우스로 조작한 수동 시험, 다른 PC/LAN/외부 인터넷은 미검증이다.
- 기존 기본 파일 로그 비활성화 설정을 유지한다. 새로운 데이터·키를 Git에 추가하거나 이전 인증서/엔진 로그 오류를 게임 코드 오류로 혼동하지 않는다. Git 반영은 사용자의 후속 요청에 따라 dev_1에서 진행한다.

---

아래는 이전 작업 기록이다. 계정/DB/저장 관련 상태는 위 최신 인수인계를 우선한다.

# 최신 수정 — Windows 기본 실행 접근 위반 (2026-10-16)

- 사용자 화면의 메모리 접근 위반과 같은 0xC0000005를 재현했다. 기본 user 로그 파일 열기 실패 뒤 Godot 4.6.3의 RotatedFileLogger가 null FileAccess를 사용한다. 게임 코드 진입 전 문제다. 이전 --log-file 시험으로는 기본 실행을 검증할 수 없었다.
- project.godot에서 자동 파일 로그(기본/PC)를 끄고 콘솔 출력을 유지했다. 서버·플레이어·검증 빌드를 같은 output/builds/ 경로로 다시 내보냈다. AGENTS.md 및 게임/네트워크 코드는 이번 수정에서 바꾸지 않았다.
- 서버 EXE와 console EXE 기본 실행, 실제 D3D12 플레이어 기본 실행, 쓰기 가능한 --log-file 저장 PASS: .godot/startup_tests/1792078467088929800/. 회귀 실행기: tests/check_export_startup.py.
- tests/run_dedicated.py는 이제 서버에 --log-file/--headless를 추가하지 않는다. 콘솔 출력을 server.log에 수집한다. 실제 2인 5라운드·각 15발/750점·재경기·이전·재사용 PASS: .godot/dedicated_tests/1792078394644677000/. 실제 4인 접속/권한/참가 거부/이탈/재접속 PASS: .godot/dedicated_tests/1792078398802200100/.
- GDScript parse/runtime 오류 없음. Git diff self-review 및 diff --check 완료. Windows 인증서와 셰이더 캐시 저장 환경 오류는 남는다. 셰이더 캐시 오류는 정확히 _save_to_cache(shader_rd.cpp) 출처만 환경 항목으로 따로 보고한다.
- 파일 로그가 필요하면 docs/DEDICATED_SERVER.md의 쓰기 가능한 경로 예제를 따른다. --log-file로 쓰기 불가능한 경로를 강제할 때의 엔진 자체 버그는 고치지 않았다.
- 사람이 직접 Explorer에서 더블클릭하는 조작, 다른 PC/LAN/외부 인터넷은 미검증이다. 동일 기본 인자의 별도 프로세스 실행은 검증했다. 다음 Steam/DB 구현은 이 문제 해결 후 별도 단계다.

---

아래는 이전 기록이다. 자동 파일 로그와 기본 실행 검증은 위 최신 수정 내용을 우선한다.

# 최신 인수인계 — 전용 서버 첫 번째 목표 (2026-10-16)

## 구현과 실행

- Godot 루트는 `다트-/`다. 기존 AGENTS.md는 수정하지 않았다. 현재 서버 실행 방법은 `docs/DEDICATED_SERVER.md`를 읽는다.
- `output/builds/server/DartPartyServer.console.exe` 실행, 플레이어는 `output/builds/client/DartParty.exe` 실행 후 서버 IP·UDP 7000으로 **방 참가**. EXE와 같은 이름의 PCK를 함께 둔다.
- `dedicated_server` feature 또는 `-- --server`로 Main이 서버를 부팅한다. 서버는 선수/HUD를 생성하지 않는다. 서버 빌드는 자동 headless다. 소스에서 실행할 때는 `--headless`도 전달한다.
- `NetworkSession.is_host()`는 서버 ID 1 권한, `is_room_host()`는 `RoomState.host_peer_id`와 일치하는 선수 방장 권한이다. 처음 접속한 사람이 방장이고 이탈하면 남은 첫 사람으로 이전한다.
- 서버는 기존 Game/MatchController로 물리·자유 이동·투척·채점·턴을 소유한다. 시작/로비/재경기 요청도 실제 RPC 발신자로 검증한다. 로딩 장벽에 서버 자신을 포함하지 않는다. 전원 이탈하면 빈 로비로 돌아간다.
- 모든 메시지는 서버를 통하므로 SceneMultiplayer.server_relay=false다. 참가자끼리의 직접 RPC나 자동 peer 목록을 사용하지 않고 RoomState 스냅샷을 사용한다. 다중 이탈은 ENet poll 이후 방 상태를 한 번 갱신한다.
- Windows Client/Server는 Release, Windows Verification은 별도 Debug preset이다. 검증 preset만 verification feature로 network_probe.tscn에서 시작한다. 배포본에서는 tests/를 제외한다. export template의 CLI script/Scene override는 지원되지 않으므로 사용하지 않는다.
- tests/network_peer.gd는 에디터 CLI 래퍼다. 실제 공통 검증 로직은 tests/network_probe.gd로 이동했다. tests/run_dedicated.py는 내보낸 실행 파일만 사용하며 --players, --lifecycle-only로 범위를 좁힐 수 있다.

## 실제 검증 결과

- 최종 내보낸 서버 + 실제 2·3·4개 클라이언트: 자기 턴 이동, 턴당 3발, 5라운드 각자 15발·750점·동일 착탄, 비방장 RPC 거부, 재경기, 방장 이전, 전원 이탈·재접속 PASS. 4인 최대 인원·중도 접속 거부 PASS.
- 최종 로그: `.godot/dedicated_tests/1792077521511862500/`. 중간 실행의 닫힌 ENet 채널 오류는 수정 전 로그다. 현재 결과는 이 최종 폴더 기준이다.
- 4인 동시 이탈·재접속 3회 연속 PASS: `.godot/dedicated_lifecycle_stress_final.log`. 고정 0.4초 대기 대신 실제 정지 명령 처리와 전원 위치 수렴을 기다린다.
- 기존 로비 회귀 PASS: `.godot/network_tests/1792077542322216400/`. 기존 실제 2·3·4인 게임 완주 PASS: `.godot/prototype_tests/1792077017663105500/`.
- 규칙·투척·개발 모드 통합·실제 D3D12 1920×1080 렌더링 PASS. `.godot/dedicated_{rules,throwing,prototype,render}.log`. 렌더 이미지를 직접 열어 확인했다. 플레이어 Release 시작과 잘못된 포트의 종료 코드 1도 확인했다.
- GDScript parse/runtime 오류 없음. Git diff self-review와 diff --check 완료. Windows 인증서 저장소 및 에디터 설정 저장 권한 환경 오류는 남는다. 기본 user 로그 경로에서는 저장 오류/엔진 크래시가 발생한 적이 있어 검증 명령에는 작업 영역 안의 --log-file 절대 경로를 지정한다.

## 다음 작업과 범위

- 다른 PC LAN·외부 인터넷·사람의 수동 조작감은 미검증이다. 이번 결과는 로컬 loopback의 실제 별도 프로세스 자동 검증이다.
- Steam 인증·초대·중계·서버 검색, 프로필 API/DB, 다중 방 할당·자동 확장은 아직 구현하지 않았다. 지금은 서버 프로세스 1개 = 방 1개다.
- 빌드는 output/builds/에서 관리하며 Git 제외다. 기존 output/ PDF는 유지했다. 이 작업에서 commit/push하지 않았다.

---

아래는 이전 작업 기록이다. 서버 권한/실행 방식은 위 최신 인수인계를 우선한다.

# 작업 인계 — 이동·착석 DART PARTY

## 최신 변경: 자유 이동 투척·턴당 3발

- 공용 투척 카메라와 THROW_ORIGIN을 제거했다. 자기 턴에도 카메라는 캐릭터의 눈 위치와 마우스 방향을 따르며 WASD/점프/숙이기로 이동한다. 선택적으로 앉으면 기존대로 일어서야 걷는다.
- 방장은 요청 발신자의 실제 캐릭터 눈 위치에서 비행을 계산한다. solve_throw는 aim, charge, sender를 전달하며 Game.solve_dart의 선택적 세 번째 인자는 peer_id다.
- MatchConfig/default_match는 턴당 3발이다. 수락 시 한 발 차감, 착탄 후 발수/20초 제한이 남으면 같은 턴의 AIMING으로 복귀한다. 모두 소모/시간 초과 후에만 정산하고 다음 사람으로 간다. HUD에 남은 발수를 표시한다.
- 실제 2·3·4인 5라운드 각 15발·750점·전원 적중 데이터 일치·중복 거부·재경기 PASS. 로그: .godot/prototype_tests/1792054521183994000/.
- 실제 로비/연결 회귀 PASS: .godot/network_tests/1792054553960218800/.
- free_move_parse.log, free_move_throwing.log, free_move_rules.log, free_move_prototype.log, free_move_render.log PASS. 통합 시험은 원격 캐릭터 발사 원점, 3발 연속·남은 발수·마감 시한 경쟁을 검사한다. 실제 렌더 시험은 자기 차례 WASD 이동 후 카메라가 눈 위치를 따라가는지 확인했다. 저장 이미지도 열어 확인했다.
- Git diff self-review와 diff --check 완료. GDScript parse/runtime 오류 없음. 인증서 저장소 오류는 남아 있다. 사람의 수동 플레이와 LAN/외부 인터넷은 미검증이다.

## 최우선 규칙 정정: 착석과 투척은 독립

- 사용자 확인: 자신의 차례라면 서 있든 앉아 있든 던질 수 있다. 아래 과거 기록의 "E 착석 후 투척" 조건은 폐기한다.
- Game의 투척 입력·카메라 및 HUD 게이지에서 seated 조건을 제거했다. MatchController의 seat_check와 착석 검증도 제거했다.
- 실제 시작 위치에서 서 있는 PLAYER가 E 입력 없이 충전 게이지·손 다트를 표시하고, 마우스 누름/해제로 발사·50점 적중하는 렌더 시험 PASS. 이미지: .godot/prototype_render/00_standing_charged.png, 00_standing_flight.png.
- 서 있는 참가자와 앉은 참가자를 섞은 실제 2·3·4인 5라운드·동일 채점·권한·중복·재경기·20초 무입력·봇 교체 PASS. 로그: .godot/prototype_tests/1792054211065023100/.
- standing_parse.log, standing_throwing.log, standing_rules.log, standing_render.log에서 parse·투척·규칙·실제 화면 확인 PASS. 인증서 저장소 오류는 남아 있다. 수동 플레이·LAN/외부 인터넷은 미검증이다.
- standing_prototype.log 통합 시험 및 실제 2·3·4인 로비/연결 회귀 PASS: .godot/network_tests/1792054262795045400/. Git diff self-review와 diff --check 완료.

## 최신 확인: 다트 발사 가시성

- 기존 마우스 충전·해제와 50점 채점 경로는 동작했지만, 카메라 원점의 6mm 축만 정면으로 보이고 손/다트가 숨겨져 발사 여부를 알기 어려웠다.
- `dart.tscn`의 Visual 아래에 축·팁·주황색 꼬리 날개를 묶었다. `DartView.fly`에 선택적 release_offset 인자를 추가했다. 판정 루트는 유지하며 외형만 손에서 출발해 착탄점에 합류한다.
- Game은 투척 가능할 때 Hand를 표시하고 발사 후 숨긴다. 손 위치는 (0.2, -0.14, -0.55)다.
- HUD에 착석 필요·다른 사람 차례·마우스 복귀·충전·발사 상태를 구분해 표시하고 조준점을 화면 중앙에 맞췄다.
- 실제 Godot 4.6.3 D3D12 렌더링: 누르기/0.8초 충전/놓기 → 비행 → 50점 적중 PASS. 다트를 숨긴 동일 프레임 비교에서 비행 다트 영역의 354픽셀 차이를 확인했다. 손에 든 다트와 발사 다트의 저장 화면도 열어 확인했다.
- 검증: dart_visual_parse.log, dart_visual_throwing.log, dart_visual_rules.log, dart_visual_render.log PASS. 실제 2·3·4인 5라운드·동일 적중/점수·권한·재경기·20초·봇 교체 PASS: .godot/prototype_tests/1792053811401013800/.
- Git diff self-review 및 diff --check 완료. 최종 GDScript parse/runtime 오류 없음. 인증서 저장소 오류는 남아 있다. 물리 마우스를 사람이 조작하는 수동 플레이와 LAN/외부 접속은 미검증이다.
- 기존 실행 인스턴스는 종료하고 F5로 다시 실행해야 새 외형/Scene을 확실히 적용할 수 있다.

## 최신 수정: 발사 입력 복구와 1920×1080

- 규칙 파일은 프로젝트 루트 `AGENTS.md` 하나만 유지한다. 상위 폴더의 안내용 `AGENTS.md`는 사용자의 요청으로 삭제했다.
- 수정 전 재현: 창 포커스 이탈로 마우스가 해제된 뒤 클릭으로 복귀되지 않아 투척 입력이 비활성화된 채 유지됐다. 기존 렌더 시험은 마우스 모드를 직접 설정해 이 경로를 건너뛰었다.
- 수정: 게임 화면 첫 클릭은 마우스만 다시 잡는다. 다음 누름/놓기가 충전/발사다. captured 상태의 왼쪽 버튼은 `_input`에서 한 번 처리하고 GUI 전파를 종료한다. 결과 화면과 마우스 해제 상태의 UI 버튼은 기존 동작을 유지한다.
- 화면: `project.godot`의 viewport·기본 창 크기 1920×1080, `canvas_items`/`keep`. 렌더 시험에서만 전체 화면으로 전환해 Windows의 창 테두리 보정 없이 실제 1920×1080 이미지도 확인한다.
- 실제 검증: `dart_fix_parse.log`, `dart_fix_throwing.log`, `dart_fix_rules.log`에서 parse/투척/규칙 PASS. `dart_fix_render.log`에서 창 전환·클릭 복귀·중앙 GUI 차단·충전·비행·50점 적중·1920×1080·960×540·메뉴 PASS.
- 실제 2·3·4인 5라운드·이동·착석·동일 채점·권한·재경기, 20초 시간 초과와 실제 참가자의 봇 교체 PASS. 로그: `.godot/prototype_tests/1792050125194293800/`.
- `dart_fix_prototype.log`: 실제 시작 Scene, 정지 봇·공유 월드·개발자 키·이동 물리·착석·적중/실패·시한 경쟁·중복·순위·메뉴 통합 시험 PASS. Git diff self-review와 diff --check 완료.
- 최종 GDScript runtime 오류는 발견되지 않았다. Windows root certificate store 읽기 오류는 남아 있다. LAN/외부 인터넷과 사람의 직접 조작감 평가는 이번에도 수행하지 않았다.
- 이번 변경은 `game/game.gd`, `game/throwing/dart_throw_controller.gd`, `project.godot`, 렌더 회귀 시험, README와 작업 기록에 한정했다. 아래는 이전 구현의 인수인계 기록이다.

## 현재 목적과 구현

사용자의 붙여넣은 요구 전체(2~4인 이동·착석·충전 투척·5라운드 + 개발자 봇 모드)를 기존 프로젝트에 구현했다.
실행 엔진은 Godot 4.6.3.stable.official.7d41c59c4, Forward Plus/D3D12, Jolt를 유지한다.
프로젝트 루트는 `다트-/`다. 별도 프로젝트·Autoload·외부 에셋·가짜 봇 클라이언트는 만들지 않았다.

- Main.developer_mode 기본 true: 개발 빌드 F5에서 호스트 + 봇 3명 자동 입장. `-- --normal` 또는 Inspector false로 일반 로비.
- 네모난 방, 원형 테이블, 4개 색 자리, 고정 벽 과녁, 캐릭터 기본 도형과 방향 표시.
- WASD/마우스/Space/Ctrl, 자기 자리 1m 이내 E 착석/일어서기, 투척 시 카메라만 공용 투척 원점으로 변경.
- 방장이 실제 발신자 입력으로 CharacterBody3D 이동·물리를 계산, 20Hz 상태 공유. 위치 예측/보간은 없음.
- 제한 구역은 이동 충돌 레이어 4, 환경은 1, 캐릭터는 2. 캐릭터끼리 밀지 않으며 다트 레이는 레이어 1만 검사.
- 최대 충전 0.8초, 속도/중력/비행 제한 Resource. 방장이 포물선 환경 레이와 과녁 평면 교차를 확정.
- 5라운드·턴당 1발·즉시 20초, 미착석/만료/타인 차례 거부, 비행 중 중복/개발자 종료 방지.
- 점수·공동 순위·재경기·참가자 이탈·호스트 종료 처리.
- 봇 3명은 자기 자리에 정지하고 과녁 방향을 유지한다. 대기실 실제 참가자는 봇을 대체한다.
- 같은 World3D의 SubViewport/Camera3D, 자기 몸 레이어 제외, F1/F2 시야 조작, F3/F4 기존 턴 처리 경로.
- 과녁/투척 시점 중심 높이 2.9m, 테이블은 투척 시점 뒤에 둬 평지 점프 머리(약 2.66m)로 과녁 전체를 가리지 못하게 했다.
- 기존 카드/얼굴 방해/변형 과녁 파일은 현재 경기 경로에서 사용하지 않는다.

## 실제 검증

다음은 실제 Godot 실행 결과이며 봇 관찰을 네트워크 검증으로 간주하지 않는다.

1. Headless editor import 및 실제 시작 씬: 변경 스크립트의 parse 오류 없음.
2. `tests/run_multiplayer.py`: 실제 2·3·4개 ENet 프로세스, 인원/시작 권한/로딩 장벽/재입장/이탈/호스트 종료 통과.
   5번째와 경기 중 신규 접속은 구체적인 이유 문자열까지 확인.
   로그: `.godot/network_tests/1792043043149199500/`.
3. `tests/run_first_idea.py`: 실제 2·3·4개 ENet 프로세스가 각자 입력으로 이동·점프·숙이기, 자기 캐릭터 소유권, 착석을 검증.
   5라운드 각자 5발(중앙 불) 완주, 전원의 적중 데이터/점수 일치, 중복 투척 1회 득점, 타인/오래된 경기 요청 거부, 재경기 통과.
   실제 20초 미착석 시간 초과 → 0점/다음 턴, 실제 3클라이언트가 로비 봇 3명 대체 통과.
   로그: `.godot/prototype_tests/1792043197016279800/`.
4. 서버 없는 포트로 실제 접속: 실패/시간 초과 안내와 시작 화면 유지 확인.
   로그: `.godot/connection_failure/1792043246487344200/`.
5. `tests/test_rules.gd`: 표준 싱글/더블/트리플/불, 링의 정확한 경계·양옆, 각도 양옆, 비유한 값, 상태 스냅샷과 기본 수치 통과.
   float32의 정확한 링 경계가 틀리던 기존 비교를 정규화 1e-7 허용 오차로 수정했다.
6. `tests/test_throwing.gd`: 실제 Dart Scene 비행/정지/제거, 운동식, 충전 포화, 마우스 해제·중복 해제·포커스/비활성 취소 통과.
7. `tests/test_prototype.gd`: 실제 F5 자동 입장, 정지 봇, 월드 공유/시각 레이어, F1~F4, 실제 봇 20초 시간 초과,
   바닥/벽/제한 구역, 멀리서 착석 거부, 바닥/벽/최대 비행시간 실패, 캐릭터 다트 비차단, 마감 시한 경쟁,
   마지막 순서/종료 후 이탈, 중복/비행 잠금, 공동 순위, 시작 화면 복귀 통과.
8. `tests/render_first_idea.gd`: AMD Radeon D3D12 실제 렌더링에서 Input 이벤트 WASD/Space/Ctrl/마우스 회전,
   F1/F2/F4/E, 최대 충전 후 버튼 해제, 화면상 비행, 50점 적중, 결과, 960×600 레이아웃, 일반 메뉴 통과.
   같은 봇 카메라의 이미지가 사람 서기/숙이기에 따라 달라지는지 비교했다.
   실제 저장 이미지를 열어 HUD/봇 시야/결과를 확인하고 화면 밖 안내와 겹친 결과 버튼을 수정했다.
   이미지: `.godot/prototype_render/01_f5_room.png` ~ `13_normal_menu.png`.
9. Git diff self-review 및 diff --check 수행.

마지막 과녁 높이 조정 후에는 렌더링, 개발자/물리 통합 시험과 실제 4인 5라운드를 다시 실행했다.
세부 로그: `.godot/prototype_final_import.log`, `prototype_rules.log`, `prototype_throwing.log`, `prototype_unit.log`, `prototype_render.log`, `prototype_final_four/1792043357788534700/`.

## 환경 로그와 검증 한계

GDScript parse/runtime 오류는 최종 실행에서 발견되지 않았다.
엔진 환경 로그에는 Windows root certificate store 읽기 실패가 남는다.
실제 D3D12 렌더링에는 shader_rd.cpp의 셰이더 캐시 저장 실패가 남는다. import에는 작업 영역 밖 editor_settings 저장 실패가 기록될 수 있다.
이들을 게임 스크립트 오류로 분류하지 않았으며 제거했다고 보고하지 않는다.

실제 LAN 다른 PC, 외부 인터넷, 지연/손실 주입, 사람이 직접 평가한 조작감/산만함은 검증하지 않았다.
봇 3명은 별도 네트워크 클라이언트가 아니다. 실제 4인 자동 검증은 서로 다른 ENet 프로세스의 loopback 시험이다.

## 사람이 확인할 재현 순서

- 혼자: project.godot 열기 → Main Developer Mode true → F5 → 자기 색 자리 근처 E → 0.8초 충전 후 놓기.
- 방해/시야: F2로 관찰할 봇 선택 → F4로 그 봇 차례 → E로 일어나 봇 앞/주변을 WASD/Space/Ctrl로 움직임 → 보조 시야와 조작감 확인.
- 4인 창: Developer Mode false → 실행 인스턴스 4개 → 한 창 방 생성 → 나머지는 127.0.0.1:7000 참가 → 전원 준비 → 방장 시작.
- 직접 복귀: 자리에서 멀리 이동 → 자기 턴에도 자동 이동하지 않는지 → 20초까지 앉지 않으면 0점인지 → 다시 돌아와 E 착석.
- LAN: 두 PC 같은 프로젝트/엔진에서 일반 모드 실행 → 방장 내부 IP와 UDP 포트로 참가 → 독립 키 입력·턴·점수 비교.
- 봇 교체: 개발 모드 F5 → Esc → 대기실/봇 교체 → 다른 일반 창에서 참가 → 봇 감소·4인 유지 확인.
- 재경기/이탈: 종료까지 플레이 → 공동 순위 확인 → 방장 재경기 → 모든 점수/다트 초기화 → 클라이언트 종료/호스트 종료 확인.

## 이어서 수정할 때

- 사용자 요청 이전의 작업 트리에 이미 미커밋 수정이 있었다. 루트 AGENTS.md나 기존 파일 삭제를 이번 작업의 변경으로 오인해 복구하지 않는다.
- NetworkSession의 지속 RPC 수명과 실제 발신자 검증을 유지한다.
- 활성 경기의 규칙은 README와 현재 MatchController 기준이다. 역사적 first_idea_plan의 카드·4라운드·2발·12초를 복원하지 않는다.
- 개발자 시험과 렌더 시험은 기본 포트 7000을 함께 사용하므로 동시에 실행하지 않는다.
- 현재 상수/설정 및 구조 변경 이유는 docs/ARCHITECTURE.md, docs/DECISIONS.md에 반영했다.
