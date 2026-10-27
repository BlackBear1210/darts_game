# 현재 작업

- 작업: 디자인 외형(펍·다트판·캐릭터 4명+바텐더·다트·1인칭 손·HUD 색)을 F5 실제 경기에 연결 — 팀 피드백 빌드 (2026-10-26 저녁). 같은 날 테이블 집합·슬로우·한글화, 2026-10-25 아트 통합·카드 7장 규칙·협업 규칙과 함께 **전부 미커밋**.
- 상태: 구현·자동 검증·화면 확인 완료. 사용자 확인 후 `dev_1`에 커밋.
- 실행: Godot 4.6.3 프로젝트 관리자 → "다트"(즐겨찾기) → F5 = 실제 경기(펍 외형 포함), `art/showcase/showcase.tscn` F6 = 디자인 쇼케이스, `game/flow_preview/flow_preview.tscn` F6 = 흐름도 시연. 에디터 없이: 저장소 최상위 `실행_*.cmd`.
- 외형 다시 만들기: `art/pub/pub_builder.gd` 실행 → `test_game_look` → 생성 스크립트와 생성물을 같은 커밋. 배치 숫자 원본은 `game/table/table.gd` 상수. 자세히 `art/README.md`.
- 규칙 값: `game/match/default_match.tres`의 `table_seconds`, `slow_speed_scale`(시연값, 팀 확정 필요). 손패는 `game/cards/card_hand_rules.gd`.
- 협업: `docs/COLLABORATION.md` — 폴더 담당, `res://` 영어 snake_case, `.uid` 함께 커밋, 생성물 직접 편집 금지.
- 상세·검증 결과: `작업기록/2026-10-26_게임통합_디자인.md`, `2026-10-26_테이블집합_슬로우_한글화.md`, `2026-10-25_아트통합_카드규칙.md`.
- 피드백 자료: 저장소 최상위 `output/game_look/`(F5 장면 10장 + `11_throw.gif`).
