# 3인 협업 규칙 — 파일 위치·이름·Git

2026-10-25 작성(디자인 담당 요청). 코딩 스타일 자체는 [AGENTS.md](../AGENTS.md)가 기준이고, 이 문서는 **세 사람이 같은 저장소를 동시에 고칠 때 부딪히지 않는 방법**만 다룬다.

## 1. 폴더 = 담당

한 폴더는 한 사람이 주로 고친다. 남의 폴더 파일을 고쳐야 하면 먼저 말하고, 커밋 메시지에 그 사람 영역임을 적는다.

| 폴더 | 내용 | 담당 |
|---|---|---|
| `art/` | 펍·캐릭터·다트판 외형, 아트 쇼케이스 | 디자인(김도형) |
| `game/` (`board`, `cards`, `dart`, `match`, `throwing`, `flow_preview` …) | 경기 규칙·투척·카드 | 팀 지정 |
| `app/`, `lobby/`, `network/`, `backend/` | 시작 화면·접속·서버·계정 | 팀 지정 |
| `ui/` | 경기 HUD | 팀 지정 |
| `tests/` | 자동 검사 — 자기 기능의 검사는 자기가 쓴다 | 각자 |
| `docs/`, `작업기록/` | 문서 | 각자(아래 4번) |

"팀 지정" 칸은 팀이 정해서 채운다. 규칙의 **원본은 한 곳**에만 둔다 — 다른 곳은 읽어 쓰기만 한다.

| 규칙 | 한 곳 |
|---|---|
| 과녁 숫자 배치·링 비율·점수 | `game/board/board_layout.gd`, `board_scorer.gd` |
| 손패 7장·카드 4종 | `game/cards/card_hand_rules.gd` |
| 라운드 수·발수·제한 시간 | `game/match/default_match.tres` |
| 충전·속도·중력 | `game/dart/default_dart.tres` |
| 아트 다트판 실제 크기·높이 | `art/board_spec.gd` |

## 2. 이름 짓기

**`res://` 안(코드·씬·리소스·이미지)은 영어 소문자 + 숫자 + `_`만 쓴다.** 한글·공백·대문자 파일명은 쓰지 않는다.
한글 경로는 cmd 인코딩, Git 경로 표시, 씬 리소스 ID, 내보내기에서 문제를 만든 적이 있다. 한글 파일명은 `docs/`, `작업기록/`, 저장소 최상위 실행 파일(`실행_*.cmd`)에만 허용한다.

| 대상 | 규칙 | 예 |
|---|---|---|
| 파일·폴더 | `snake_case` | `card_hand_rules.gd`, `art/pub/` |
| 씬 + 스크립트 | 같은 이름, 같은 폴더 | `showcase.tscn` + `showcase.gd` |
| 생성물 | 앞에 종류 | `chr_spike.tscn` |
| `class_name`, 노드 | `PascalCase` | `CardHandRules`, `ArtShowcase` |
| 함수·변수 | `snake_case`, 내부용은 `_` 시작 | `refill()`, `_pending_category` |
| 상수·enum 값 | `UPPER_SNAKE_CASE` | `HAND_LIMIT`, `Category.OPERATION` |
| bool | `is_` / `has_` / `can_` | `is_bot`, `can_sit` |
| signal | 과거형·`_requested` | `dart_thrown`, `start_requested` |
| 테스트 | `tests/test_<기능>.gd` | `tests/test_art_showcase.gd` |

`class_name`은 프로젝트 전체에서 하나만 있어야 한다. 두 사람이 같은 이름을 만들면 둘 다 실행이 안 된다.
새 `class_name`을 넣기 전에 검색하고, 한 폴더 안에서만 쓰는 스크립트는 `class_name` 없이 `preload`로 부른다(`art/`가 이 방식).

```bash
git grep -n "class_name CardHandRules"
```

## 3. 충돌이 잘 나는 파일

| 파일 | 왜 위험한가 | 규칙 |
|---|---|---|
| `project.godot` | 입력 키·Autoload·렌더 설정이 한 파일에 모인다 | 바꾸기 전에 팀에 알리고, 그 커밋에는 다른 변경을 섞지 않는다 |
| `app/main.tscn`, `game/game.tscn` | 모두가 노드를 붙이는 큰 씬 | 같은 날 두 사람이 고치지 않는다. 자기 기능은 **별도 씬으로 만들어 인스턴스로 붙인다** |
| 모든 `.tscn` | 줄 단위 병합이 깨지기 쉽다 | 충돌이 나면 한쪽을 그대로 받고 다른 쪽 변경을 에디터에서 다시 한다. 손으로 섞지 않는다 |
| 생성물(`art/pub/pub.tscn`, `chr_*.tscn`) | 생성기가 덮어쓴다 | 에디터에서 직접 고치지 않는다 → [art/README.md](../art/README.md) |
| `작업기록/CURRENT_TASK.md`, `HANDOFF.md` | 모두가 맨 위에 쓴다 | 자세한 내용은 개인 파일에, 여기엔 몇 줄만 |

### `.uid` · `.import` · `.godot/`

- `*.gd.uid`, `*.import`는 **커밋한다.** 스크립트와 같은 커밋에 넣는다. 씬은 이 UID로 서로를 찾는다.
- `.godot/`는 커밋하지 않는다(이미 `.gitignore`). 각자 PC에서 다시 만들어진다.
- 파일 이동·이름 변경은 **Godot 에디터의 FileSystem 창에서** 한다. 탐색기에서 옮기면 씬 안의 경로·UID가 끊긴다.
- 남이 만든 파일은 이름을 바꾸지 않는다. 바꿔야 하면 담당자가 직접 한다.

### 줄바꿈

`.gitattributes`가 처리한다: 코드·문서는 LF, `.cmd`·`.bat`은 CRLF. cmd 파일 안의 글자는 영어(ASCII)만 쓴다 — 한글을 넣으면 다른 PC에서 깨진다.

## 4. Git 순서 (GitHub Desktop 기준)

지금 원격 브랜치는 `dev_1` 하나다.

1. **작업 시작 전** `Fetch origin` → `Pull origin`.
2. 자기 폴더에서 작업한다. 작게 끊어 자주 커밋한다(하루 한 번 이상).
3. **올리기 전** 다시 `Pull` → 관련 테스트 실행 → `Push origin`.
4. 며칠 걸리거나 공용 파일(`project.godot`, 큰 씬)을 건드리는 작업은 개인 브랜치를 만든다. 이름은 영어로 `<영역>/<내용>`: `art/pub-lighting`, `cards/hand-ui`. 끝나면 GitHub에서 Pull Request로 `dev_1`에 합친다.

커밋 메시지는 기존 형식을 따른다: `feat(art): ...`, `fix(cards): ...`, `docs: ...`, `test: ...`. 괄호 안은 폴더 이름.
테스트·생성물·`.uid`는 해당 코드와 같은 커밋에 넣는다. `output/builds/`, `backend/data/`, 로그, zip은 올리지 않는다.

### 올리기 전 최소 검사

변경한 영역의 검사만 돌린다. 전체 목록은 [README](../README.md#자동-검증).

| 바꾼 곳 | 검사 |
|---|---|
| `game/board/`, `game/match/` | `tests/test_rules.gd`, `tests/run_first_idea.py` |
| `game/throwing/`, `game/dart/` | `tests/test_throwing.gd` |
| `game/cards/`, `game/flow_preview/` | `tests/test_game_flow.gd` |
| `art/` | `tests/test_art_showcase.gd` (+ `-- --render`로 그림 확인) |
| `game/table/`, `art/pub/` | `tests/test_game_look.gd` — 배치 상수를 바꿨으면 `art/pub/pub_builder.gd` 를 먼저 실행한다 |
| `network/`, `lobby/`, `app/` | `tests/run_multiplayer.py` |

## 5. 기록 남기기

- 개인 작업 기록: `작업기록/YYYY-MM-DD_작업명.md` — 사람마다 다른 파일이라 충돌하지 않는다.
- 확정된 규칙·설계 변경: `docs/DECISIONS.md` 맨 아래에 날짜와 함께 추가.
- 아직 미확정인 아이디어는 확정 규칙과 섞지 않고 "미정"이라고 적는다.
