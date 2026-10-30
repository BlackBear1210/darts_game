# 현재 프로젝트 구조

사용자가 2026-10-15에 요청한 이동·착석 DART PARTY 프로토타입을 구현한다.
이전 고정 좌석·카드 계획은 `first_idea_plan.md`에 역사적 참고로 남기며 현재 실행 규칙은 README가 기준이다.

문서 경로는 Godot 루트 `다트-/`를 기준으로 한다. 공통 규칙과 실행 안내는 루트의 `AGENTS.md`와 `README.md`, 설계·기능 안내는 `docs/`, 현재 작업·인수인계·개별 작업 기록은 `작업기록/`에서 관리한다.

| 영역 | 현재 책임 |
| --- | --- |
| `app/main.tscn`, `main.gd` | 지속 연결과 로비/3D 대기실/경기/HUD 조립, 명시적 개발 실행 |
| `network/network_session.gd` | ENet 방 생성·참가·거부 사유·로딩 장벽, 실제 발신자 ID가 붙은 메시지 전달 |
| `lobby/room_state.gd`, `room_player.gd` | 최대 4인 자리/준비/로딩, 사람·봇 공개 신원 |
| `game/game.tscn`, `game.gd` | 로컬 1인칭 시점·이동 입력, 방장 이동 처리 연결, 착석 요청, 다트 환경 레이와 과녁 교차, 확정 비행 표현 |
| `game/player/player.tscn`, `player.gd` | CharacterBody3D 이동·점프·숙이기, 캡슐/방향 표시, 참가자별 렌더 레이어 |
| `game/player/bot_driver.gd` | 봇의 차례 행동 계산(방장 전용): 투척선까지의 조향, 조준 방향, 조준점·충전. 상태를 두지 않는다 |
| `game/table/table.tscn`, `table.gd` | ㄱ자 방·가구·4개 자리·과녁 위치 상수와 충돌 상자(환경 레이어 1·제한 벽 레이어 4), 이동 한계 계산. 보이는 방은 자식 `Pub`(`art/pub/pub_game.tscn`) |
| `game/board/` | 공유 표준 섹터/링 데이터, 순수 채점과 기본 도형 표현 |
| `game/throwing/dart_throw_controller.gd` | 마우스 누르기/충전 상한/놓기/입력 취소와 화면 중앙 조준 |
| `game/dart/` | 설정 Resource, 공통 운동식, 확정된 포물선 재생 |
| `game/match/` | 방장 턴·시계·투척 요청 검증·점수·이탈·경기 종료·재경기, 라운드 전 카드 나눠 주기 |
| `ui/game_hud.gd` | 점수·차례·상태·조작·공동 순위, 같은 월드를 보는 봇 SubViewport와 F1~F4 |
| `game/cards/card_hand_rules.gd` | 손패 7장 채우기·카드 4종(연산/다트/과녁/물리) 순수 규칙. 현재 흐름도 시연에서만 사용 |
| `art/` | 디자인 담당의 펍·캐릭터·다트판 그림·몸짓과 F6 아트 쇼케이스. 2026-10-26부터 F5 경기의 외형을 그린다(충돌·채점은 안 함) |
| `ui/pub_theme.gd` | HUD·대기실 공용 색·테두리(PubTheme) |

Autoload는 없다. `/root/Main/NetworkSession`은 화면 전환 중 유지한다.
RPC는 이 지속 노드에서만 수신하고, Game/MatchController는 로컬 signal 구독으로 자기 책임의 메시지를 받는다.
화면을 없앤 직후 도착한 이동 패킷도 삭제된 Scene 경로를 조회하지 않는다.
`NetworkSession`은 점수·물리·턴 규칙을 계산하지 않는다.

## 2026-10-30 현재 기본 실행 경로

F5는 `Main/FrontDoor`로 시작한다. `RoomSettings`는 공유 규칙, `PlayerPreferences`는 개인 표시·음향 설정이다. `Main`은 `social_lobby` 방에 연결되는 즉시 `Game`과 `LoungeHUD`를 만들고, 방 단계 LOBBY인 동안 `MatchController`는 WAITING이다. 실제 착석 여부를 확인한 준비가 모두 모이면 기존 LOADING 장벽을 거쳐 경기를 시작한다. 재경기는 맵 대기와 준비 초기화로 돌아간다. Main의 `_lounge_memory`가 경기 장면 재생성 사이의 소품·음악·취기를 이어 준다.

- `lobby/front_door.gd`, `ui/lounge_style.gd`, `ui/dart_cursor.gd`: 새 로비와 공용 UI, 다트 커서. 연결은 NetworkSession으로 위임한다.
- `lobby/room_settings.gd`: 공개 설정 Resource. 비밀번호·개발자 권한은 포함하지 않는다. sanitize/허용 카드 풀/상대 가중치가 여기 있다.
- `network/network_session.gd`: 초대/암호 도전 응답, 정원, 설정 발신자 검증, 준비와 자동 시작. 개발자 값은 local server host+debug 개발 플래그 조건을 별도로 확인한다.
- `ui/settings_panel.gd`, `player_preferences.gd`: ESC 개인 설정과 모니터 방장/개발자 설정. 개인 설정은 ConfigFile, 공유 설정은 server 승인만 사용한다.
- `game/match/match_cards.gd`: 실제 peer ID와 기존 순수 RoundRules 자리 인덱스를 변환한다. 카드 턴·선택·사용·대응·패스 및 카드 효과/승리를 MatchController로 연결한다. 스냅샷은 hand/pending_card/card_effects/card_peer/feed를 포함한다.
- `game/lounge/lounge_world.gd`: 모니터·주크박스·소품과 테마. 방장만 물체 소유권/거리/요청 제한/병 궤적/적중/취기·스턴을 갱신한다. 시계는 남은 시간으로 보내 서로 다른 PC의 단조 시계 차이를 피한다. 과거 match_id 이벤트는 무시한다.
- `game/lounge/youtube_bridge.gd`, `youtube_player.html`: 외부 브라우저 공식 임베드. 루프백에 /player·/state 읽기 전용 경로만 제공하고 헤더 크기·시간·동시 요청 수를 제한한다. 영상·전원·볼륨을 전달하고 파일/명령 실행 엔드포인트는 제공하지 않는다.
- `ui/lounge_hud.gd`: 짧은 효과 피드·준비 인원·카드 키·상호작용·공동 순위. 기존 `GameHUD`는 legacy 예시/서버 검증 경로에 남긴다.

원형 테이블은 `TableView` 원통 충돌과 `GameRoomBuilder` 생성기의 원형 상판을 같이 바꿨다. `pub_game.tscn`은 생성기로 다시 저장했다. 기존 renderer/physics/project.godot/큰 조립 씬 파일은 유지했다. 이후 절의 자동 호스트·카드 배부만 설명은 기존 legacy 실행 경로의 구조이며 새 기본 경로에서는 위 설명이 우선한다.

## 전용 서버

`Main`은 `dedicated_server` feature 또는 `-- --server`로 전용 서버를 시작한다. 같은 Game/MatchController로 물리·턴·투척·채점을 처리하며 서버에는 로컬 선수와 HUD를 생성하지 않는다.

ENet 서버 ID 1과 선수 방장은 별개다. `NetworkSession.is_host()`는 서버 권한, `is_room_host()`는 `RoomState.host_peer_id`와 일치하는 선수 권한이다. 전용 서버의 첫 접속자가 방장을 맡고 이탈하면 남은 첫 사람에게 이전한다. 일반 방 만들기와 기존 개발 모드는 ID 1이 선수 겸 서버인 방식을 유지한다.

방장 클라이언트의 시작·로비 복귀·재경기 요청도 지속 NetworkSession을 거치며 서버가 실제 RPC 발신자를 검증한다. 로딩 장벽은 선수들에게만 적용한다. 전원 이탈하면 서버는 빈 로비로 돌아가 다음 접속을 받는다. 하나의 서버 프로세스가 하나의 방을 소유한다. 익명 모드는 영구 저장하지 않고 계정 모드는 아래의 로컬 백엔드와 연결한다.

모든 요청은 서버로 보내므로 `SceneMultiplayer.server_relay`를 끈다. 참가자 목록은 RoomState 스냅샷으로 전달하며 참가자끼리 직접 RPC를 보내지 않는다. 여러 연결이 같은 poll에서 종료될 때는 이탈 처리 후 방 상태를 한 번 갱신한다.

`export_presets.cfg`는 Windows 서버·플레이어 Release와 검증 전용 Debug 빌드를 정의한다. 검증 preset만 `verification` 시작 Scene override와 테스트 스크립트를 포함한다. 결과물은 `output/builds/`에 생성하고 Git에서 제외한다.

기본 자동 파일 로그는 끄고 콘솔 출력을 유지한다. 4.6.3 엔진의 로그 파일 열기 실패 시 접근 위반을 피하기 위해서다. 파일 저장이 필요하면 쓰기 가능한 경로를 `--log-file`로 명시한다. 서버 시험은 별도 로그 경로로 기본 시작 문제를 우회하지 않는다.

## 로컬 계정과 경기 저장

`backend/server.py`는 loopback HTTP API와 SQLite 계정/전적 저장을 담당한다. `backend/run_local.ps1`이 개발 API·경기 서버·계정 모드 플레이어를 각각 실행한다. 서비스는 `--dev`와 서버 환경 키가 있어야 시작하며 외부 주소로 바인딩하지 않는다.

Main이 `--backend-url`을 받으면 자식 `BackendConnection`을 생성한다. 해당 Node는 HTTPRequest로 로그인·프로필·서버 토큰 검증을 수행하고, 서버의 완료 경기 결과를 디스크 대기 파일과 함께 전송한다. 새로운 Autoload는 없다. API를 지정하지 않으면 기존 익명/개발자 봇 모드를 유지한다.

NetworkSession은 인증 모드에서 실제 발신자의 토큰을 API로 검증한 뒤 계정 ID를 서버 전용 account_ids에 연결한다. 표시 이름은 API에서 확인된 값을 사용한다. 토큰·서버 키·계정 ID 매핑을 공개 로비 스냅샷에 넣지 않는다.

BackendConnection은 MatchController의 변경을 관찰하며 정상 완주 결과만 전송한다. 물리/점수는 계속 MatchController가 확정한다. 재경기마다 새 결과 ID를 만들고, 서버/API 재시작 시에도 같은 대기 결과 ID를 재사용한다. 백엔드는 동일 ID의 중복을 트랜잭션으로 방지하며 프로필 통계를 저장된 결과에서 집계한다.

실행/데이터 경로·완주/승수 정책·남은 범위는 docs/BACKEND_DEV.md를 따른다. Steam 인증과 운영 배포는 아직 없다.

## 사람과 봇

`RoomPlayer.is_bot`, `MatchPlayer.is_bot`으로 구분한다. 양수 ID는 실제 ENet 피어이고 음수 ID는 방 내부의 봇 참가자 식별자다.
봇 ID로 `rpc_id`를 호출하거나 가짜 네트워크 연결을 만들지 않는다.
같은 CharacterBody3D 표현·자리·점수·턴 배열을 사용한다. 호스트만 사람의 입력을 시뮬레이션한다.

봇의 차례 행동도 호스트만 돌린다(`GameView._drive_bot`). 자기 차례(AIMING/FLIGHT/SETTLING)면 자리에서 일어나
`BotDriver.throw_spot()`(투척선 바로 뒤, 레인 한가운데)까지 걸어가고, 도착해 과녁을 보고 서면 `AIM_SECONDS` 간격으로
`MatchController.bot_throw()`를 부른다. 차례가 아니면 자기 자리로 걸어가 앉고, 앉아 있는 봇은 건드리지 않는다.
조작값은 사람이 보내는 것과 같은 모양이라 `PlayerView.simulate`의 같은 이동·충돌·속도 규칙을 지나며,
결과 위치는 기존 이동 스냅샷으로 전달된다. 봇 전용 네트워크 메시지나 가짜 피어는 없다.
`BotDriver`는 테이블에 막히는 길이면 옆으로 비껴 선 지점을 보고 돌아간다(기억하는 경로 없이 매 프레임 다시 계산).
`bot_throw`는 네트워크 발신자가 없으므로 차례·발수·시간·값 범위만 확인하고, 사람 요청과 같은 `_launch`로 비행을 확정한다.
대기실에서 실제 사람이 등록하면 봇 하나를 제거하고 빈 자리를 재사용한다. 진행 중 등록은 거부한다.

## 권한과 통신

- 이동 입력: 실제 RPC 발신자가 자기 캐릭터에만 요청할 수 있다. 유한 값·방향 길이·각도·시퀀스·경기 ID를 검증한다.
- 서버 이동: CharacterBody3D `move_and_slide`, 중력/점프/숙이기, 환경 레이어 1과 제한 벽 레이어 4에 충돌한다.
- 이동은 20Hz `unreliable_ordered` 채널로 전송한다. 서버는 0.35초간 입력이 없으면 정지시킨다.
- 클라이언트는 위치·방향·수직 속도·숙이기·착석 상태를 받는다. 현재 LAN 프로토타입은 위치 예측/보간을 추가하지 않았다.
- 좌석 요청: 자기 자리 1m 이내이고 점프 중이 아니어야 앉는다. 어느 차례에도 일어날 수 있다.
- 투척 요청: 실제 신원·경기 ID·턴 ID·요청 ID·차례·남은 발수·마감 시각·충전/좌표 범위를 방장이 검증한다. 서 있거나 앉아 있는 상태는 투척 조건이 아니다.
- 투척 구역: 2026-10-28부터 **다트 홀 안이면서 투척선 뒤에서만** 던질 수 있다. 라운지(테이블·바)에서도, 레인 옆을 지나 과녁 옆에 서 있을 때도 거부한다.
  판정은 `TableView.in_throw_zone()`이고, `MatchController.in_throw_zone`은 GameView가 주입하는 Callable이다(`check_seated`와 같은 방식 — 컨트롤러는 씬을 모른다).
  로컬 화면도 같은 조건으로 조준·충전을 잠근다. 씬 없는 시험에서는 주입이 없어 위치를 보지 않는다.
- 수락 즉시 AIMING → FLIGHT로 전환하므로 같은 프레임의 중복 투척/시간 초과/F3/F4가 다시 점수를 만들 수 없다.
- 방장이 확정한 비행 시간이 끝날 때 1회 채점한다. 턴당 3발이며 남은 발수와 시간이 있으면 같은 턴의 AIMING으로 돌아간다. 모두 던지거나 시간이 끝나면 SETTLING → 다음 차례로 간다.
- 이탈: 활성 투척자의 미완료 비행은 취소하고 다음 차례로 간다. 마지막 차례 이탈은 라운드를 넘긴다. 종료 상태의 이탈은 경기를 재개하지 않는다.
- 카드 나눠 주기(CARDS): 경기 시작과 매 라운드의 다트 전에 방장이 `MatchPlayer.hand`(카드 종류 번호)를 `CardHandRules.HAND_LIMIT`(7장)까지 채운다.
  쓴 만큼만 채우므로 한 장도 안 썼으면 한 장도 받지 않는다. 카드 목록은 `game/card_round/rules/card_catalog.gd` 하나만 쓴다(시연 장면과 같은 카드).
  손패는 기존 경기 스냅샷에 실려 모든 화면이 같은 값을 본다. 단계 길이는 `MatchConfig.card_seconds`다.
  순서: 시작 → CARDS → AIMING …, 라운드가 넘어가면 TABLE → CARDS → AIMING. 카드를 쓰는 규칙은 아직 없다(나눠 주기까지).
- 테이블 집합(TABLE): 라운드가 넘어갈 때(마지막 라운드 제외) MatchController가 `TABLE` 단계를 `table_seconds`(기본 10초) 동안 연다. 집합이 시작되면 모든 `MatchPlayer.speed_scale`을 1.0으로 되돌린다. 사람 전원이 앉으면 즉시, 아니면 시간이 끝날 때 닫는다. 못 앉은 사람은 `force_seat`로 자기 자리에 앉히고 `speed_scale = slow_speed_scale`(기본 0.5)을 걸어 다음 라운드 동안 이동이 느려진다. 봇은 검사하지 않는다.
- MatchController는 씬을 모른다. 착석 확인·강제 착석은 GameView가 주입하는 Callable(`check_seated` = `GameView.is_seated`, `force_seat` = `GameView.force_seat`)로 한다(`solve_throw`와 같은 방식). 주입이 없으면 전원 착석으로 보고 바로 다음 라운드로 간다.
- `speed_scale`은 MatchState 스냅샷에 실려 모든 화면이 같은 값을 본다. 이동 시뮬레이션은 방장만 하므로 실제 속도 적용은 방장 쪽 `PlayerView.simulate`(SPEED × 숙이기 × speed_scale)다.
- `MatchState.Phase.TABLE`은 enum 맨 뒤(7)에 추가했다. 기존 값(2=AIMING, 6=FINISHED)을 쓰는 시험·외부 도구가 바뀌지 않게 하려는 것이다.

## 좌표와 적중

1단위는 1m다. 방은 2026-10-28 도면의 ㄱ자이고 두 사각형의 합집합이다(`TableView.DART_HALL`, `LOUNGE`).
위쪽 **다트 홀** x −6.0~+6.0 · z −7.5~0.0, 아래쪽 **라운지** x −8.4~+12.1 · z 0.0~+7.5 ("좁다"는 요청으로 도면 비율을 유지한 채 1.5배로 넓혔다. 가구 크기는 그대로다).
**보호 레인**: 과녁 앞은 가운데 복도(x ±`LANE_HALF` = ±1.2)만 막는다. 레인 바깥 양옆은 뚫려 있어 걸어 들어가 구경하거나 방해할 수 있다.
네모 카드 테이블 중심은 (0, 0, 4.4)·2.15 × 1.55m, 자리 4개는 TableView.SEATS에 고정한다. 바·NPC 자리·당구대·럼주통도 TableView 상수다.
과녁 중심은 (0, 2.9, −7.2), 실제 반지름은 BoardLayout.RADIUS × 2.5 = 0.75m다. 투척선(z = −4.05)에서 과녁 면까지 3.15m다.
방이 사각형이 아니므로 이동 한계는 `TableView.clamp_floor()`가 두 칸(`walkable_halls()`)의 합집합으로 처리한다.
카메라는 차례와 관계없이 로컬 캐릭터의 눈 위치와 마우스 방향을 따른다. 자기 턴에도 서서 이동·점프·숙이며 조준할 수 있다.
발사 원점은 방장이 소유하는 실제 발신자 캐릭터의 눈 위치다. 로컬 카메라 위치나 고정된 공용 원점을 원격 투척 판정에 사용하지 않는다.
과녁 크기(2.5배)와 높이(2.9m)는 원래 "앉은 자리에서도 던진다"는 규칙 때문이었다. 2026-10-28 도면에서 테이블이 라운지로 멀어졌지만
다트 홀 입구가 넓어 자리에서도 과녁이 보이기는 해서, 라운지 투척을 규칙으로 막았다(위 "권한과 통신").
방을 1.5배로 넓히면서 투척 거리가 2.0m → 3.15m 가 되어 원래 설계값(3.6m)에 가까워졌다. 과녁 규격은 팀 확정 대기라 바꾸지 않았다.
투척 거리가 3.6m → 2.0m로 줄어 과녁이 상당히 크고 높게 보인다. 실제 규격(`art/board_spec.gd` 0.17m·1.73m)으로 바꿀지는 팀이 정한다.
과녁 로컬 앞면은 XY, 법선 +Z, 다트 끝은 -Z다.
다트 루트는 방장이 확정한 궤적을 유지한다. 자식 `Visual`만 손 위치의 오프셋에서 시작해 비행 종료 시 루트에 합류한다.
조준·충전 중에는 카메라의 손/다트를 표시하고, 발사 후에는 비행 다트로 교체한다. 외형 오프셋과 꼬리 날개는 채점에 영향을 주지 않는다.

충전은 0~1로 포화한다. 속도는 DartConfig의 최소/최대 속도를 보간한다.
최대 세기는 현재 위치에서 조준한 과녁 좌표에 도착하도록 중력을 보정하며 낮은 세기는 더 아래로 떨어진다.
방장은 해석적 포물선을 1/120초 구간으로 나눠 환경 레이(마스크 1)를 검사하고, 과녁 평면 교차 시각은 해석적으로 계산한다.
캐릭터 레이어 2와 제한 벽 레이어 4는 다트 레이에서 제외한다.
과녁 내 착탄, 벽/바닥, 비행 제한의 시작점·종점·시간을 공유한다. 클라이언트 물리는 채점 근거가 아니다.

BoardScorer는 Node·입력·UI에 의존하지 않는다.
불 경계는 안쪽 불, 더블/트리플 경계는 특수 링, 각도 경계는 시계 방향 다음 섹터다.
Vector2 float32 경계의 반올림에는 정규화 1e-7 허용 오차를 적용한다.

## 개발자 모드와 보조 카메라

Main.developer_mode는 개발 빌드에서만 동작한다. `-- --normal`로 실행 시 자동 호스트·단축키·보조 화면을 끈다.
F3은 기존 시간 초과 함수를, F4는 시간 초과 후 기존 턴 시작 함수를 사용한다. 비행/정산 중 강제 변경은 무시한다.
HUD의 SubViewport는 Game.get_world_3d()를 공유하고 Camera3D만 추가한다.
각 캐릭터는 2~5번 시각 레이어 중 하나를 사용하며, 카메라는 자기 몸 레이어만 cull_mask에서 제외한다.
TextureRect와 안내 Label은 마우스 입력을 무시하고 SubViewport.gui_disable_input을 켠다.
숨길 때는 렌더 갱신도 끈다.

## 흐름도 시연 (2026-10-16)

`game/flow_preview/flow_preview.tscn`은 F6으로 실행하는 독립적인 로컬 청사진이다. `game_flow.gd`가 단계·분기·임시 카드 수량·목표 근접 순위를 소유하고 `flow_preview.gd`가 버튼 UI를 제공한다. 실제 경기·NetworkSession·백엔드에는 연결하지 않는다. 전체 순서와 팀원의 후속 연결 위치는 [GAME_FLOW_BLUEPRINT.md](GAME_FLOW_BLUEPRINT.md)를 따른다.

2026-10-25부터 카드는 `CardHandRules`가 손패를 계산한다. 라운드 시작 전 7장까지 채우고, 쓴 만큼만 받는다. 흐름에 특수 합동 라운드(`JOINT_ROUND`)와 조준 중 다른 참가자의 방해(`jam_<번호>`) 분기가 있다. 카드 효과 수치는 아직 적용하지 않는다.

## 아트 폴더 (2026-10-25)

`art/`는 디자인 담당이 소유한다. `art/pub/pub_builder.gd`가 `mesh_kit.gd`, `board_spec.gd`, `characters/character_factory.gd`로 `art/pub/pub.tscn`과 `art/characters/chr_*.tscn`을 생성한다. 생성물은 직접 편집하지 않는다.
`art/showcase/showcase.tscn`은 펍을 인스턴스로 불러 카메라·조준·3발·연산 카드 예시를 보여 주는 F6 데모다. 점수는 `BoardScorer.score(BoardSpec.to_board_point(오프셋), BoardLayout)`로 팀 채점을 그대로 쓴다. 별도 채점 규칙은 없다.
아트 다트판은 실제 규격(반지름 0.17m, 중심 높이 1.73m, 투척 거리 2.37m)이고 실제 경기 과녁(2.5배, 높이 2.9m)과 다르다. 캐릭터 정면은 +Z다. 상세: `art/README.md`, `docs/ART_DIRECTION.md`.

## 실제 경기 외형 연결 (2026-10-26)

- **방**: `TableView`(`game/table/table.gd`)는 충돌 상자만 만든다(바닥·벽·천장·제한 벽·테이블·바·주크박스·스툴 3개 = StaticBody3D 13개, 메시 없음). 보이는 펍은 `pub_builder.gd` → `art/pub/game_room_builder.gd`가 TableView 상수를 읽어 만든 `art/pub/pub_game.tscn`이고 `table.tscn`의 자식 `Pub`으로 붙는다. 방 루트의 `layout_signature` 메타가 `TableView.layout_signature()`와 다르면 시작 때 경고, `test_game_look` 실패. 화면이 있을 때만 `StaticBatch`로 정적 메시를 묶는다.
- **과녁**: `BoardView`가 `BoardArt.build(Face, layout.numbers, BoardLayout.RADIUS, …)`로 그린다. 카드로 숫자 배치가 바뀌면 `show_layout()`이 다시 그린다. 채점은 그대로 `BoardScorer`.
- **캐릭터**: `PlayerView._dress()`가 `PlayerLook.character(seat)`를 `Model`로 붙이고 180° 돌린다(캐릭터 +Z 정면). `CharacterRig`가 피벗(LegL/LegR/Body/ArmL/ArmR/Neck)을 돌려 서기·걷기·숙이기·앉기·점프·조준·던지기를 만든다. 몸짓은 각 화면에서 위치·자세·속도로 계산하며 네트워크로 보내지 않는다. 충돌 캡슐·눈높이·속도는 바뀌지 않았다.
- **다트·손**: 비행 다트 깃은 던진 사람 색(`Dart.paint`), 꽂힌 뒤 `Visual`만 2.2배(과녁 2.5배와 맞춤, 채점 무관). 1인칭 손은 `CharacterFactory.create_hand(자리 색)`.
- **칠판·HUD**: `GameView._chalk_text()` → `TableView.set_chalk_scores()`가 과녁 왼쪽 칠판에 점수를 쓴다. HUD·대기실은 `PubTheme.build()`를 쓴다.

## 유지한 기존 파일 (실제 경기)

카드/얼굴 효과와 TrajectoryPreview 등 이전 계획의 파일은 남아 있지만 현재 경기에서 활성화하지 않는다.
새 확장 시스템, 외부 에셋, 전역 매니저를 추가하지 않았다.

## 검증

`tests/run_multiplayer.py`: 실제 2·3·4인 로비·시작·로딩·최대 인원·중도 접속·이탈·방장 종료.
`tests/run_first_idea.py`: 실제 이동·입력 소유권·착석·5라운드·동일 채점·중복·재경기·20초 시간 초과·봇 교체.
`tests/test_rules.gd`: 표준 과녁의 정확한 경계·실패·상태 왕복.
`tests/test_throwing.gd`: 충전 포화·입력 취소·운동식·Dart Scene 종점.
`tests/test_prototype.gd`: 실제 자동 입장과 봇/카메라, 개발자 키, 서버 물리/제한 구역, 충돌/실패·시한 경쟁·순위,
봇의 기립→투척선 도착→3발 투척(판정 원점이 투척선)→자리 복귀.
`tests/render_first_idea.gd`: 실제 D3D12 렌더링과 입력 이벤트, 봇 화면 변화·비행·결과·노트북 크기 저장.
`tests/test_game_flow.gd`: 흐름도 시연의 2·3·4인 완주, 손패 7장 보충·카드 사용·방해·합동 라운드.
`tests/test_art_showcase.gd`: 아트 쇼케이스의 투척·채점·카메라·HUD 입력, `-- --render`로 네 시점 렌더.
`tests/test_game_look.gd`: F5 외형 연결 — 방 서명·충돌 없는 방·칠판·관절 몸짓·렌더 레이어·과녁 숫자 재배치·다트 색/크기.
`tests/render_game_look.gd`: 실제 F5 장면 10장 + 던지기 낱장 30장(`output/game_look/`).
