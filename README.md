# Darts Game

Godot 4.6.3으로 만드는 2~4인 멀티플레이 다트 파티게임.

## 처음 받은 팀원은 여기부터

**바깥 폴더는 Git 저장소 전체이고, 안쪽 `다트-/`가 실제 Godot 프로젝트다.** 저장소를 내려받은 폴더 이름은 PC마다 달라도 된다. 이 문서의 경로는 모두 저장소 최상위 기준이다.

1. [프로젝트 README](다트-/README.md)에서 실행 환경·조작법·현재 구현 규칙을 확인한다.
2. Godot 4.6.3에서 [`다트-/project.godot`](다트-/project.godot)을 가져온다. F5는 DARTY 로비를 연다. 싱글/멀티를 고르고 맵에서 착석·참여하면 경기가 시작된다.
3. 코드를 수정하기 전 [개발 규칙](다트-/AGENTS.md), [현재 작업](다트-/작업기록/CURRENT_TASK.md), [인수인계](다트-/작업기록/HANDOFF.md)를 읽는다.
4. 담당 기능의 구조는 [ARCHITECTURE.md](다트-/docs/ARCHITECTURE.md)와 관련 `docs/` 문서에서 확인한다.

흐름도 기반의 버튼 시연은 `다트-/game/flow_preview/flow_preview.tscn`을 열고 F6으로 실행한다. F5의 실제 경기와 별개이며, 상세 범위는 [진행 청사진](다트-/docs/GAME_FLOW_BLUEPRINT.md)을 따른다.

**세 명이 함께 고칠 때의 폴더 담당·파일 이름·Git 순서는 [협업 규칙](다트-/docs/COLLABORATION.md)을 먼저 읽는다.**

## 더블클릭 실행

Godot 4.6.3 exe를 바탕화면이나 다운로드 폴더에 두면 아래 파일로 바로 실행된다. 다른 곳에 두었다면 환경 변수 `GODOT`에 exe 경로를 넣는다. 처음 한 번은 리소스 가져오기 때문에 몇십 초 걸린다.

| 파일 | 여는 것 |
| --- | --- |
| `실행_게임.cmd` | DARTY 로비 → 라운지 → 경기 (에디터 F5와 같음) |
| `실행_흐름도시연.cmd` | 흐름도 버튼 시연 |
| `실행_디자인예시.cmd` | 펍·캐릭터 아트 쇼케이스 |
| `에디터_열기.cmd` | Godot 에디터로 `다트-/project.godot` 열기 |
| `darty_launch.cmd` | 위 네 파일이 부르는 공용 실행기 (직접 쓸 필요 없음) |

## 폴더와 파일의 역할

```text
저장소 최상위/
├─ README.md                 ← 저장소 입구 안내 (현재 문서)
├─ 실행_*.cmd, 에디터_열기.cmd ← 더블클릭 실행 (darty_launch.cmd 사용)
├─ .gitattributes            ← Git의 줄바꿈 등 파일 처리 설정
├─ .gitignore                ← Git에서 제외할 파일 설정
├─ 게임진행흐름도.png         ← 기획 참고 자료
├─ 다트게임기획*.pdf          ← 기존 기획 자료
├─ output/                   ← 캐릭터·공간 시안 등 생성 결과물
├─ tmp/                      ← 임시 작업 공간
└─ 다트-/                    ← 실제 Godot 프로젝트
   ├─ project.godot          ← Godot에서 가져올 프로젝트 파일
   ├─ README.md              ← 실행·조작·현재 구현 규칙·검증 안내
   ├─ AGENTS.md              ← 공통 개발 규칙
   ├─ docs/                  ← 기능 설명·기획·설계 문서
   ├─ 작업기록/              ← 현재 작업·인수인계·개별 작업 기록
   ├─ app/                   ← 시작 화면과 앱 전체 연결
   ├─ art/                   ← 디자인 담당: 펍·캐릭터·아트 쇼케이스
   ├─ game/                  ← 투척·과녁·카드·경기 등 게임 기능
   ├─ lobby/                 ← 대기실 참가자와 준비 상태
   ├─ network/               ← 멀티플레이 연결과 메시지 전달
   ├─ ui/                    ← 게임 화면과 HUD
   ├─ backend/               ← 로컬 개발 계정·프로필·전적 서버
   ├─ tests/                 ← 자동 검증
   ├─ output/                ← 실행 파일 빌드·PDF 등 프로젝트 결과물
   └─ .godot/                ← Godot 자동 생성 캐시와 로컬 검증 자료
```

`output/`, `tmp/`, `.godot/` 같은 로컬 결과물 폴더는 Git 포함 여부에 따라 내려받은 PC에 없을 수 있다. 필요한 결과물은 해당 기능의 안내에 따라 생성한다. 폴더 이름만 보고 전체 결과물을 Git에 추가하지 않는다.

기획 PDF와 흐름도는 최상위에 보관한다. **기존 기획 자료의 제안과 현재 구현 규칙은 다를 수 있다.** 현재 실행 동작은 프로젝트 README를 먼저 확인하고, 아직 논의 중인 기획은 확정 규칙과 구분한다.

## Blender 캐릭터 V08

팀 공유용 캐릭터 원본은 [`output/character_v08/`](output/character_v08/)에 있다. V01~V07 폴더 없이 열 수 있으며 참고 이미지는 원본 파일 안에 포함되어 있다.

- [`character_reference_hair.blend`](output/character_v08/character_reference_hair.blend): 헤어가 있는 편집용 캐릭터.
- [`character_bald.blend`](output/character_v08/character_bald.blend): 같은 캐릭터의 대머리 버전.
- [`turnaround_scene.blend`](output/character_v08/turnaround_scene.blend): 여러 방향을 촬영하도록 구성한 장면.
- [`turnaround.png`](output/character_v08/turnaround.png), [`turnaround_bald.png`](output/character_v08/turnaround_bald.png): Blender를 열지 않고 확인할 미리보기.
- [상세 안내](output/character_v08/README.txt): 모델 상태와 파일 설명. 외형 검토용이며 애니메이션 리깅과 제작용 UV는 아직 없다.

Blender 5.2에서 세 원본의 열기와 외부 의존성을 확인했다. Git 공유에는 원본과 미리보기를 포함하고, 중복 ZIP·자동 백업(`.blend1`, `.blend2`)·작업 로그는 제외한다.

## 아트 쇼케이스 미리보기

[`output/art_showcase/`](output/art_showcase/)에 디자인 예시(펍·캐릭터 4종·다트판)의 네 시점 렌더가 있다. Godot을 열지 않고 볼 수 있다. 설명은 [art/README.md](다트-/art/README.md).

## README가 두 개인 이유

| 문서 | 역할 | 수정하는 경우 |
| --- | --- | --- |
| 최상위 `README.md` | GitHub 첫 화면에서 프로젝트 위치·폴더 역할·읽을 문서를 안내 | 폴더 구조나 팀원 진입 안내가 달라졌을 때 |
| `다트-/README.md` | 게임 실행·조작·접속·현재 구현 규칙·검증 방법 설명 | 실제 게임 사용법이나 구현 동작이 달라졌을 때 |

실행법과 경기 규칙은 안쪽 README에서 관리하고, 바깥 README에는 같은 설명을 반복하지 않는다.

## 작업할 때 문서를 어디에 둘까?

| 내용 | 위치 |
| --- | --- |
| 기능 안내·기획 초안 | `다트-/docs/` — 초안에는 미확정 상태 표시 |
| 확정된 주요 설계 결정과 이유 | [다트-/docs/DECISIONS.md](다트-/docs/DECISIONS.md) |
| 현재 코드의 구조와 책임 | [다트-/docs/ARCHITECTURE.md](다트-/docs/ARCHITECTURE.md) |
| 현재 작업 범위·진행 상태 | [다트-/작업기록/CURRENT_TASK.md](다트-/작업기록/CURRENT_TASK.md) |
| 다음 작업자에게 전달할 정보 | [다트-/작업기록/HANDOFF.md](다트-/작업기록/HANDOFF.md) |
| 개별 작업·검증 기록 | `다트-/작업기록/YYYY-MM-DD_작업명.md` |

코드·개발 규칙·설계 문서·작업 기록에서 사용하는 프로젝트 기준 경로는 `다트-/`다. 작업 기록 작성 방법은 [작업기록 안내](다트-/작업기록/README.md)를 따른다.
