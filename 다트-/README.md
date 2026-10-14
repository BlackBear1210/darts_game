# 다트

Godot 4.6.3으로 만드는 3D 다트 파티게임.

## 실행

Godot에서 이 폴더의 `project.godot`을 열고 F5를 누른다.
시작 씬은 `app/main.tscn`이다.

현재는 **첫 번째 아이디어: 원형 테이블에서 다트를 던지는 2~4인 프로토타입**을 구현했다.
방 생성·접속·준비 후 테이블에 앉아 중앙 과녁에 차례대로 던진다.
최고점 개인전 4라운드, 턴당 2발, 카드 3종과 얼굴 방해, 최종 순위와 로비 복귀를 사용할 수 있다.
캐릭터와 공간은 기본 도형으로 만든 임시 외형이다. 자유 이동·다른 모드·나머지 카드는 후속 범위다.

## 같은 PC에서 확인

1. Godot의 `Debug > Customize Run Instances...`에서 `Enable Multiple Instances`를 켜고 2~4개로 설정한다.
2. F5를 눌러 여러 인스턴스를 실행한다.
3. 한 창에서 이름을 입력하고 **방 만들기**를 누른다.
4. 나머지 창에서 다른 이름을 입력하고 주소 `127.0.0.1`, 포트 `7000`으로 **방 참가**를 누른다.
5. 모든 창에서 **준비**를 켠다. 방장 창에서 **함께 시작**을 누른다.
6. 자기 차례에는 마우스로 조준하고 왼쪽 버튼을 유지하다 게이지 중앙에서 놓는다.
7. 카드 단계에는 후보 1장을 고르고, 사용할 보유 카드와 대상을 선택한 뒤 **사용 예약**을 누른다.

조작과 실제 규칙은 [첫 번째 아이디어 안내](docs/first_idea.md)를 참고한다.

같은 LAN의 다른 PC에서는 `127.0.0.1` 대신 방장의 내부 IP를 사용한다.
다른 인터넷 환경에서의 접속은 UDP 포트 도달성 또는 별도 릴레이 구성이 필요하다.
자세한 접속 조건과 설계는 [멀티플레이 안내](docs/multiplayer.md)에 있다.

## 파일 찾기

| 위치 | 역할 |
| --- | --- |
| `app/main.tscn`, `main.gd` | 시작 지점. 연결 유지와 화면 조립 |
| `network/network_session.gd` | ENet 접속, RPC, 방장 권한, 타임아웃 |
| `lobby/` | 로비 UI와 참가자·방 상태 |
| `game/game.tscn`, `game.gd` | 공간·카메라·입력·경기 표현 연결 |
| `game/table/`, `game/player/` | 중앙 장치와 좌석·캐릭터 표현 |
| `game/board/` | 공유 과녁 배치, 순수 점수 판정, 3D 과녁 |
| `game/match/` | 경기 설정, 상태, 차례·시간·RPC 검증 |
| `game/cards/` | 비공개 후보, 보유 카드, 사용과 효과 적용 |
| `game/throwing/`, `game/dart/` | 조준·타이밍 입력, 다트 비행 표현 |
| `ui/` | HUD, 공개 과녁 미리보기, 카드·결과, 얼굴 방해 |
| `docs/architecture.md` | 현재 파일별 책임과 데이터 흐름 |
| `tests/` | 실제 프로세스를 사용하는 멀티플레이 검증 |

기능별로 씬과 코드를 함께 둔다. 아직 필요한 동작이 없는 씬에는 스크립트를 붙이지 않았다.
에디터가 생성하는 `.godot/`는 수정하지 않는다.

## 자동 검증

Python 3과 Godot 4.6.3 실행 파일을 사용한다.

```powershell
python tests/run_multiplayer.py --godot 'C:\경로\Godot_v4.6.3-stable_win64_console.exe'
python tests/run_first_idea.py --godot 'C:\경로\Godot_v4.6.3-stable_win64_console.exe'
& 'C:\경로\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tests/test_rules.gd --log-file .godot/rules.log
```

2·3·4인 접속, 인원 초과와 시작 후 입장 차단, 준비/방장 권한, 공동 입장,
재시작, 나가기·재접속, 방장 종료, 로딩 장벽과 타임아웃을 검증한다.
경기 검증은 실제 2·3·4인 4라운드 완주, 마우스 입력, 카드·방해, 권한·중복·잘못된 입력,
전원 점수 일치, 무입력 타임아웃을 확인한다. 규칙 검증은 불·링·각도 경계, 효과와 카드 소유권을 확인한다.
검증용 파일과 로그는 `.godot/network_tests/`, `.godot/first_idea_tests/`에 저장한다.
`tests/render_first_idea.gd`는 실제 렌더러로 각 좌석과 카드·결과·관전·방해 화면을 저장하는 검증 도구다.

## 개발 기준

상위 폴더의 `AGENTS.md`에 코드 작성 기준을 기록했다.
승인된 첫 구현 계획은 `docs/first_idea_plan.md`에 보존했다.
경기 수치는 `game/match/default_match.tres`에서 관리하며 코드에 여러 번 복사하지 않는다.
