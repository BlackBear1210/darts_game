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
