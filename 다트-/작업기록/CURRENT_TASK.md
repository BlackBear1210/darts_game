# 현재 작업

- 작업: 2026-10-28 **카드 라운드 기획을 단독 F6 장면으로 시연** — 흩어진 덱·자동 섞기·딜링 7장·공개·왼손 부채·꺼내 들기/무효 대응·충전 라운드·효과 패널·사용 표시(페인트/그을림)·다트, 그리고 기획 중인 스턴 별·방해 보상·흐림+목소리 변조·승리 조건 3종·벌칙 원판·골드.
- 상태: 구현·자동 검증·화면 캡처 확인 완료, **미커밋**. 사용자가 직접 해 보고 피드백 → 팀 확정 뒤 F5 경기에 옮길지 결정.
- 상세: `작업기록/2026-10-28_카드라운드_시연.md`, 흐름·조작·시연값: `docs/CARD_ROUND_PROTOTYPE.md`. 결정: `docs/DECISIONS.md` 2026-10-28.
- 실행: `game/card_round/card_round.tscn` F6, 또는 저장소 최상위 `실행_카드라운드.cmd`. 캡처: `output/card_round/`(커밋하지 않는 확인용 그림).

---

# 이전 작업 (2026-10-27)

- 작업: 봇이 자기 차례에 자리에서 일어나 **투척선까지 걸어가 3발을 던지고** 자리로 돌아오게 한다 (2026-10-27). 전까지 봇은 앉은 채 조준 자세만 하고 20초 뒤 0점이었다.
- 상태: 구현·자동 검증·화면 확인 완료, **미커밋**. 사용자 확인 후 `dev_1`에 커밋.
- 상세·검증 결과: `작업기록/2026-10-27_봇_투척선.md`. 결정: `docs/DECISIONS.md` 2026-10-27.
- 바뀐 곳: `game/player/bot_driver.gd`(새 파일), `game/game.gd`(`_drive_bot`), `game/match/match_controller.gd`(`bot_throw`/`_launch`), `game/player/player.gd`, `tests/test_prototype.gd`.
- 봇 난이도 값: `game/player/bot_driver.gd`의 `AIM_SPREAD`·`MIN_CHARGE`/`MAX_CHARGE`·`AIM_SECONDS`. **시연값 — 팀 확정 필요.**
- 실행: Godot 4.6.3 프로젝트 관리자 → "다트" → F5 = 실제 경기, `art/showcase/showcase.tscn` F6 = 디자인 쇼케이스, `game/flow_preview/flow_preview.tscn` F6 = 흐름도 시연. 에디터 없이: 저장소 최상위 `실행_*.cmd`.
- 앞 작업(디자인 외형 F5 연결, 테이블 집합·슬로우, 아트 통합·카드 7장)은 커밋 `da54b2a`로 올라가 있다.
- 협업: `docs/COLLABORATION.md` — 폴더 담당, `res://` 영어 snake_case, `.uid` 함께 커밋, 생성물 직접 편집 금지.
