# Godot AI 개발 규칙

이 파일은 모든 구현·수정·리팩터링의 최우선 프로젝트 기준이다.
작업 전에 기존 코드, Scene 구조와 `docs/ARCHITECTURE.md`를 먼저 읽는다.

## 프로젝트 환경과 공식 문서

- Godot 4.6.3과 GDScript를 사용한다.
- Godot 공식 문서를 최우선으로 참고하고, 공식 GDScript style guide를 따른다.
- 존재하지 않는 API를 추측해서 사용하지 않는다. 사용할 API가 Godot 4.6.3에서 실제로 지원되는지 확인한다.
- 사용자가 변경을 요청하지 않으면 기존 렌더러와 물리 엔진을 유지한다.

## 코딩 원칙

- 변수, 파라미터, 반환값에 가능한 한 명시적 타입을 사용하고 static typing을 우선한다.
- GDScript는 탭으로 들여쓴다. 설명과 주석은 한국어로 작성한다.
- 파일·함수·변수는 `snake_case`, 클래스·노드는 `PascalCase`, 상수는 `UPPER_SNAKE_CASE`를 사용한다.
- 클래스와 스크립트는 single responsibility를 지향하며, inheritance보다 composition을 우선한다.
- 미래를 예상한 speculative abstraction을 만들지 않는다. 실제 필요가 없는 interface, manager, factory, base class, 범용 유틸리티와 빈 메서드를 선제적으로 만들지 않는다.
- public API는 작고 명확하게 유지하고, 긴 함수는 책임 단위로 분리한다.
- 이름만 봐도 역할을 이해할 수 있게 작성한다. magic number는 의미 있는 상수나 Resource 설정으로 이동한다.
- 코드 중복과 과도한 추상화 사이에서는 더 단순하고 읽기 쉬운 쪽을 선택한다.
- 주석은 코드만으로 알기 어려운 이유, 좌표 기준, 규칙을 설명하며 코드 동작을 반복하지 않는다.
- 기존 코드 스타일과 프로젝트 구조를 먼저 파악한다. 변경 이유가 없는 코드는 건드리지 않고, 한 번에 불필요하게 많은 파일을 수정하지 않는다.
- 사람이 Git diff로 리뷰하기 쉬운 구조와 작은 변경을 우선한다.

## Godot Architecture

- scene ownership을 우선하고 각 Scene과 Node가 자신의 책임과 상태를 소유하도록 설계한다.
- Scene과 해당 스크립트는 같은 기능 폴더에 둔다. 공통 폴더는 실제 여러 기능에서 공유하는 코드가 생길 때 만든다.
- Resource는 재사용 가능한 데이터와 configuration에 사용한다.
- Signal은 결합도를 낮춰야 하는 communication에 사용한다. 부모·자식처럼 명확한 직접 관계에서는 불필요하게 남용하지 않는다.
- 소유 노드의 명시적 연결과 로컬 signal을 우선한다. Autoload는 정말 application-wide lifetime이 필요할 때만 사용하고 global state를 최소화한다.
- Scene / Node / Resource / Signal로 해결할 수 있는 문제에 과도한 service layer나 전역 이벤트 버스를 추가하지 않는다.
- 점수 계산과 경기 규칙은 입력, UI, 3D 연출에 의존하지 않도록 작성한다.

## 현재 프로젝트의 계약

- 멀티플레이는 2~4인이다. 참가자·준비·경기 시작 등의 공유 상태는 방장이 확정한다.
- 클라이언트 RPC는 발신자의 실제 peer ID로 검증한다. 클라이언트 UI에서 공유 상태를 직접 수정하지 않는다.
- 연결 노드 `/root/Main/NetworkSession`은 화면 전환 중 유지한다.
- 기획 PDF의 미확정 제안과 예시 수치를 확정 규칙으로 취급하지 않는다.

## 작업 방식

1. 관련 기존 코드와 Scene 구조를 읽고 `작업기록/CURRENT_TASK.md`, `작업기록/HANDOFF.md`를 확인한다.
2. 변경하려는 설계를 짧게 설명한다.
3. 가능한 가장 작은 변경으로 구현한다.
4. 구현 후 스스로 Git diff를 리뷰한다.
5. 불필요한 복잡도와 과도한 추상화가 생겼는지 다시 확인한다.

## 완료 조건과 검증

- 코드 변경에는 GDScript parse 오류가 없어야 한다.
- 변경한 Scene 또는 관련 Scene을 실제 실행하여 runtime error를 확인한다. 가능하면 관련 기능도 직접 재현한다.
- 네트워크 변경은 `tests/run_multiplayer.py`로 실제 다중 프로세스 검증을 실행한다.
- 투척·카드·경기 규칙 변경은 `tests/run_first_idea.py`와 `tests/test_rules.gd`로 검증한다. 규칙과 점수 계산은 경계값을 확인한다.
- 공간·HUD 변경은 실제 렌더링 화면도 확인한다. 관련 도구는 `tests/render_first_idea.gd`다.
- 변경 범위에 맞게 검증하며 단순 구조 변경에는 구현을 복제한 테스트를 추가하지 않는다.
- 문서만 변경한 작업은 문서 내용, 경로, 링크와 Git diff를 확인한다.
- 검증하지 않은 부분을 검증했다고 말하지 않는다. 마지막 보고에서 실제 검증 결과와 검증하지 못한 부분을 구분한다.

## 문서 관리

- `docs/ARCHITECTURE.md`: 현재 프로젝트의 주요 구조와 책임.
- `docs/DECISIONS.md`: 중요한 설계 결정과 이유.
- `작업기록/CURRENT_TASK.md`: 현재 작업의 목적, 범위와 진행 상태.
- `작업기록/HANDOFF.md`: 다른 AI가 이어서 작업할 수 있는 정보.
- 문서 경로는 이 파일이 있는 `다트-/`를 기준으로 작성한다. 날짜별 작업 기록은 `작업기록/`에 둔다.
- 내용이 없는 문서는 최소한의 템플릿만 유지한다. 구조나 실행 방법이 실제로 바뀌면 관련 문서를 함께 수정한다.
- `AGENTS.md`, `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`는 구현을 정당화하기 위해 임의로 수정하지 않는다. 실제 프로젝트 설계가 변경되었을 때만 업데이트하며, 사용자의 명시적인 규칙 변경 요청은 반영한다.
