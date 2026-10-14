# 프로젝트 구조

## 기본 원칙

기능별로 파일을 모으고, 데이터·규칙·입력·표현의 책임을 분리한다.
기능의 실제 구현이 필요할 때 파일을 추가한다. 현재는 승인된 첫 번째 아이디어의 프로토타입을 구현했다.

```text
다트-/
├── project.godot
├── app/
│   ├── main.tscn
│   └── main.gd
├── network/
│   └── network_session.gd
├── lobby/
│   ├── lobby.tscn
│   ├── lobby.gd
│   ├── room_state.gd
│   └── room_player.gd
├── game/
│   ├── game.tscn
│   ├── game.gd
│   ├── board/
│   │   ├── board.tscn / board.gd
│   │   ├── board_layout.gd
│   │   └── board_scorer.gd
│   ├── dart/
│   │   └── dart.tscn / dart.gd
│   ├── table/
│   │   └── table.tscn / table.gd
│   ├── player/
│   │   └── player.tscn / player.gd
│   ├── throwing/
│   │   └── throw_controller.gd
│   ├── match/
│   │   ├── default_match.tres / match_config.gd
│   │   ├── match_state.gd / match_player.gd
│   │   └── match_controller.gd
│   └── cards/
│       ├── card_definition.gd
│       └── card_controller.gd
├── ui/
│   ├── game_hud.tscn
│   ├── game_hud.gd
│   └── board_preview.gd / aim_reticle.gd / emote_overlay.gd
├── tests/
│   ├── network_peer.gd
│   ├── run_multiplayer.py
│   ├── run_first_idea.py / test_rules.gd
│   └── render_first_idea.gd
└── docs/
    ├── architecture.md
    ├── multiplayer.md
    └── first_idea.md / first_idea_plan.md
```

## 책임과 구현 위치

| 영역 | 책임 | 구현 파일 |
| --- | --- | --- |
| `app/` | 메뉴·경기·결과 화면 전환 | `main.gd` |
| `network/` | ENet 연결, RPC 검증, 방 상태 전달 | `network_session.gd` |
| `lobby/` | 참가자·준비·시작 조건, 로비 입력과 표시 | `room_state.gd`, `room_player.gd`, `lobby.gd` |
| `game/` | 경기 요소 조립과 연결 | `game.gd` |
| `game/board/` | 과녁 데이터, 착탄 위치 판정, 과녁 표현 | `board_layout.gd`, `board_scorer.gd`, `board.gd` |
| `game/throwing/` | 조준 입력, 타이밍, 투척 요청 | `throw_controller.gd` |
| `game/dart/` | 다트 비행과 꽂히는 표현 | `dart.gd` |
| `game/match/` | 설정, 점수·차례·단계, 방장 시간 진행·RPC, 종료 | `match_config.gd`, `match_state.gd`, `match_player.gd`, `match_controller.gd` |
| `game/cards/` | 카드 데이터, 비공개 후보, 보유·사용·효과 적용 | `card_definition.gd`, `card_controller.gd` |
| `game/table/`, `game/player/` | 공간·장치·캐릭터·상태 표시 | 기능별 씬과 스크립트 |
| `ui/` | 상태 표시와 사용자 선택 전달 | `game_hud.gd` |

`main`은 세부 점수 계산을 하지 않는다. `game`은 요소를 연결하지만 각 기능의 로직을 직접 구현하지 않는다.
HUD는 상태를 표시하며 점수나 차례를 직접 수정하지 않는다.

## 추상화의 경계

### 데이터

과녁 배치는 `BoardLayout`, 경기 설정은 `MatchConfig` Resource로 정의했다.
기본 설정은 `default_match.tres` 한 곳에 두고 경기마다 복사한다.
과녁의 표현과 점수 판정이 같은 배치 데이터를 읽도록 한다. 점수 배열을 화면과 판정 코드에 각각 복사하지 않는다.
공유되는 설정 Resource와 플레이어별로 바뀌는 경기 상태는 분리한다.

### 규칙

착탄 좌표에서 구역과 점수를 구하는 계산은 Node나 씬 트리에 의존하지 않는 코드로 작성한다.
기본 과녁 판정, 카드에 따른 점수 변경, 모드에 따른 점수 반영은 서로 다른 책임이다.
규칙은 계산 결과를 반환하고, 화면·소리·카메라는 계산 결과를 표현한다.

### 입력과 표현

입력은 투척 요청을 만들고 경기 진행 코드에 전달한다. 다트 표현은 비행·착탄 완료를 알린다.
착탄 방식은 이동·분리 과녁 규칙을 구현할 때 결정한다. 기본 고정 과녁 방식에 모든 변형을 억지로 맞추지 않는다.
여러 구현에서 교체가 실제로 필요해질 때 작은 전략 클래스나 공통 계약을 도입한다.

## 데이터 흐름

```text
로컬 입력 → 방장의 요청 검증 → 착탄·점수 계산 → 비행 사건 전송
                                                     ↓
                                          각 화면의 다트 비행
                                                     ↓
                           방장 비행 시간 완료 → 점수 확정·상태 전송
                                                     ↓
                                               HUD와 연출
```

경기 상태 변경은 방장의 `MatchController`가 조율한다. 비행 중 추가 입력과 중복 채점도 여기서 제어한다.
비공개 후보·예약은 `CardController`에만 저장하고 본인에게만 전달한다. 공개 상태에는 후보를 넣지 않는다.
자식은 로컬 signal로 사건을 알리고, 소유하는 상위 씬이 명시적으로 연결한다.
다른 기능의 노드를 긴 상대 경로로 찾아 내부 상태를 수정하지 않는다.

## 좌표 계약

- Godot 3D 좌표의 1단위를 1미터로 사용한다.
- 과녁 로컬 원점은 앞면 중심이다. 앞면은 XY 평면이고 앞쪽 법선은 `+Z`다.
- 과녁 판정에는 과녁 로컬 XY를 `BoardLayout.RADIUS`로 나눈 좌표를 사용한다. 반지름 1 밖은 빗나감이다.
- 다트 로컬 원점은 다트 끝이다. 다트 끝은 `-Z` 방향을 향한다.
- 손과 다트의 시작점은 해당 좌석의 눈높이와 오른손 위치에 맞춰 계산한다.
- 과녁·캐릭터·공간은 기본 도형을 사용한 임시 외형이다. 규칙과 표시가 같은 링·숫자 데이터를 사용한다.
- 고정된 과녁 평면과 좌표로 판정하므로 사용하지 않는 충돌체는 두지 않는다.

## 확장 순서

1. 2~4인 연결, 로비, 준비, 전원 입장. **구현 완료**.
2. 원형 테이블, 개인 시점, 과녁 장치, 과녁 배치와 점수 판정. **구현 완료**.
3. 조준·투척·착탄·HUD를 방장의 판정과 연결. **구현 완료**.
4. 최고점 모드의 차례·시간·종료. 발수와 라운드는 설정 데이터로 관리. **구현 완료**.
5. 대표 카드 3종, 개인 과녁 상태, 얼굴 방해. **구현 완료**.
6. 추가 모드, 캐릭터 이동, 공간 연출, 꾸미기.

현재 연결은 `Main/NetworkSession`에 유지하고, 화면은 `Main`이 생성·제거한다. 전역 Autoload는 사용하지 않는다.
경기 RPC는 `Main/Game/MatchController`에서 처리한다. 전원의 경기 화면 로딩 확인이 끝난 뒤 시작한다.
방 상태와 세부 경기 상태를 분리하며, `NetworkSession`에 투척·카드·점수 로직을 추가하지 않는다.
통신 상태와 로비 규칙의 상세 계약은 [multiplayer.md](multiplayer.md)에 있다.

기획의 2~4인, 카드, 과녁 변형을 수용할 경계를 유지한다.
현재는 사용자가 승인한 공간 구성 1안과 첫 경기 수치를 구현했다. 다른 공간·모드를 위한 빈 구현은 없다.

## 코드 작성

- 파일·함수·변수는 `snake_case`, 클래스·노드는 `PascalCase`, 상수는 `UPPER_SNAKE_CASE`.
- 함수 인자와 반환 타입을 명시하고, 타입이 자명한 지역 변수는 `:=`를 사용할 수 있다.
- 상태 변경과 계산을 구분한다. 계산 함수는 가능한 한 입력을 받아 결과를 반환한다.
- 여러 곳에서 필요한 값은 한 출처로 모은다. 한 곳에서만 쓰는 값은 해당 기능 가까이에 둔다.
- 필요하지 않은 getter/setter, 한 줄 전달용 래퍼, 범용 Manager/Helper 클래스를 만들지 않는다.
- 외부 입력과 파일 로딩 등의 경계는 검증하되, 필수 씬 노드 누락을 조용히 숨기지 않는다.
- 주석은 한국어로 좌표 기준, 규칙의 이유, 설계 의도를 설명한다.

## 검증

씬 구조 변경은 Godot 4.6.3의 headless import와 시작 씬 실행으로 확인한다.
멀티플레이 변경은 `tests/run_multiplayer.py`로 실제 ENet 프로세스들의 동작을 확인한다.
경기 변경은 `tests/run_first_idea.py`로 실제 2·3·4인 완주·동기화·권한·시간 초과를 확인한다.
순수 규칙은 `tests/test_rules.gd`로 중심·링·각도 경계·빗나감·효과·카드 소유권을 확인한다.
공간·화면 변경은 `tests/render_first_idea.gd`로 실제 렌더링 화면을 확인한다.
