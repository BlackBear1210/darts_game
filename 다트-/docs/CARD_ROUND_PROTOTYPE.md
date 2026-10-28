# 카드 라운드 시연 (2026-10-28 기획 → Godot 적용)

사용자 기획(2026-10-28)의 카드 라운드 흐름을 **실제 펍 장면에서 끝까지 돌려 보고 어색한지 눈으로 확인하려고** 만든 단독 장면이다.
F5 실제 경기(네트워크·`MatchController`)와는 연결하지 않았다. 팀 확정 뒤 옮길 때 규칙 계산(`rules/round_rules.gd`)은 방장 쪽으로 그대로 옮길 수 있게 노드와 분리했다.

- 실행: `game/card_round/card_round.tscn` 열고 **F6**(지금 장면 실행). 에디터 없이: 저장소 최상위 `실행_카드라운드.cmd`.
  **F5 는 팀 경기(`app/main.tscn`)라 카드 라운드가 나오지 않는다.** 에디터에서 장면을 열면 펍·테이블만 보이고, 카드·캐릭터·HUD 는 실행하면 코드가 만든다.
- 흐름도: `docs/2026-10-28_DARTY_카드라운드_흐름도.png` · 행동별 방해 정리·변수: 바탕화면 `DARTY_프로젝트6-10-28_DARTY_게임흐름_프롬프트.md` · 바꾼 파일·오류 찾기: `작업기록/2026-10-28_DARTY_카드라운드_작업프롬프트.md`
- 내 자리 = **2번 ▲ 바가지**(테이블 뒤쪽, 과녁이 정면). 나머지 셋은 봇.
- 자동 검사: `godot --headless --path . --script res://tests/test_card_round.gd -- --play`
- 화면 캡처: `godot --path . --script res://tests/test_card_round.gd -- --render` → 저장소 최상위 `output/card_round/*.png`

## 흐름과 구현

| 기획 | 화면에서 보이는 것 | 파일 |
| --- | --- | --- |
| 테이블 가운데 흐트러진 덱(딜러 없음) | 40장이 펠트 위에 흩어져 있다 | `cards/table_cards.gd` `scatter` |
| 자동 섞기 모션 여러 가지 | 정석 리플 · 마술사(공중 스프링 → 리본 펼침 → 도미노 뒤집기) · 딜러(워시 → 박스 셔플). 설정에서 고르거나 매번 무작위 | `cards/shuffle_motions.gd` |
| 가지런한 덱 | 섞기 끝에 한 더미로 정리 | `cards/shuffle_motions.gd` `_square` |
| 정해진 순서로 위·중간·아래에서 한 장씩, 한 바퀴씩 7장까지 | 덱에서 카드가 빠져 자리 매트 7칸으로 날아간다. 뽑는 곳은 설정 | `rules/round_rules.gd` `deal_plan`·`draw_index`, `cards/table_cards.gd` `deal_card` |
| 모두 앞면으로 공개 | 자리별로 물결치듯 뒤집힌다 | `cards/table_cards.gd` `reveal` |
| 왼손 7장 = 테이블 7칸(같은 카드·같은 순서) | 캐릭터가 왼팔을 들고 부채꼴로 든다. 내 화면에는 왼쪽 아래 1인칭 부채(숫자 키 표시) | `cards/hand_fan.gd`, `art/characters/character_rig.gd` `holding_cards` |
| 테이블로, 또는 걸어가서 상대 왼손 보기 | 테이블 카드는 각자 자리 쪽으로 읽히게 놓인다. 손 부채 앞면은 든 사람 눈 쪽 → 뒤로 돌아가면 보인다 | 같음 |
| 1~7(넘패드 포함)로 꺼내 들기 = 대기 상태 | 손 카드가 위로 빠져 커지고, 테이블 카드도 떠오르며 빛난다. 1.2초 뒤 초록빛 = 사용 가능 | `rules/round_rules.gd` `lift`·`READY_SECONDS` |
| 다른 사람이 보고 무효·방해로 대응(심리전) | 봇도 꺼내 들기·허세로 내려놓기·×0 무효로 막기를 한다. 누가 꺼내 들면 알림이 뜬다 | `rules/bot_brain.gd` |
| 바꾸기·버리기 없음, 소모 강제 | 쓴 카드만 비고, 다음 충전 라운드에 그만큼만 채운다 | `rules/round_rules.gd` |
| 충전 라운드: 자동 착석·점수 발표·7장 확인 | 모두 자리로 걸어가 앉고, 꼴찌부터 순위 발표 → "카드 충전 라운드!" → 덱 보충·섞기·빈 칸만 딜링 → "모두 7장 확인 ✓" | `card_round.gd` `_card_stage` |
| 라운드 표시(롤 아레나 참고, 올려 보기) | 위 가운데 ◆(카드 충전)·●(다트) 칸. 지금 칸이 금빛으로 맥박친다. **Alt** 를 누르고 마우스를 올리면 설명 | `ui/round_tracker.gd` |
| 오른쪽 효과 목록(대상별 계산) | 맨 위 한 줄 `+10 [1번 삐죽이]  −20 [2번 바가지]`, 아래에 카드별 상태(대기·적용 중·끝·무효·만료) | `ui/card_round_hud.gd` `show_effects` |
| 쓴 카드: 손에서 사라짐, 테이블엔 표시 | 빨간 페인트 X(기본) 또는 가장자리가 타 들어가는 그을림. **설정에서 하나만** 고른다 | `cards/card_view.gd` `mark_used` |
| 다시 다트로 | 자리 순서대로 한 사람 3발 | `card_round.gd` `_dart_stage` |

### 기획 중인 부분(시각 확인용으로 넣음)

| 기획 | 구현 |
| --- | --- |
| 몸으로 다트를 막거나 다른 사람 다트에 맞으면 스턴 | 머리 위에 별 다섯 개가 3초 동안 돈다 + "아야!" + 그동안 못 움직인다 (`fx/stun_stars.gd`) |
| 방해 성공 보상: 점수 또는 라운드 한정 카드 | 설정: 점수 +15 / 라운드 한정 카드(테이블 예약 칸에 금빛 카드, 손 부채 오른쪽 끝, 키 8·9, 라운드가 끝나면 사라짐) / 무작위 |
| 맞힌 사람: 차례가 끝날 때까지 화면 흐림 + 목소리 변조 | 내 화면이면 뿌옇게 흐려진다(`fx/screen_debuff.gd`). 목소리는 아직 음성 채팅이 없어 합성 "웅얼웅얼"을 낮고 찌그러지게 바꿔 들려준다(`fx/voice_fx.gd` — 실제 음성 채팅이 생기면 그 사람 음성 버스만 바꾸면 된다) |
| 끝: 꼴찌는 돌아가는 원판(서커스 칼 던지기), 나머지가 던진다 | 과녁 앞 레인에 원판이 서서 돌고 방향을 바꾼다. 한 사람 2발. 몸에 맞으면 별 (`fx/punishment_wheel.gd`) |
| 승리 후 골드(옷·아바타·닉네임 꾸미기) | 결과 화면에 순위 골드 + 방해 성공 골드, 이번 실행 동안 모은 골드 합계. 상점은 없다 |

### 끝나는 조건(수정 예정이라 설정으로 바꿔 볼 수 있게)

설정 "승리 조건"은 **새 게임부터** 적용된다.

- 7라운드 최고점(기본)
- 300점 먼저
- 500 → 0 딱 맞추기(0 아래로 내려가면 그 차례 점수를 되돌림 = 버스트)
- 끝 라운드가 없는 두 모드도 시연은 10라운드에서 점수 순으로 끝낸다.

## 조작

| 키 | 하는 일 |
| --- | --- |
| 1~7 / 넘패드 1~7 | 카드 꺼내 들기(같은 키 = 내려놓기) |
| 8 · 9 | 방해 보상 카드 꺼내 들기 |
| F | 꺼내 든 카드 쓰기 |
| Tab | 대상 바꾸기(대상 머리 위에 "▼ 내 카드 대상") |
| WASD · 마우스 | 이동 · 시선 |
| E | 앉기 / 일어나기(카드 단계엔 앉아 있다) |
| 왼클릭 길게 → 놓기 | 던지기(오른클릭 = 취소) |
| V | 말하기(목소리 변조 확인용) |
| C | 전체 보기 카메라 |
| Shift(누르는 동안) | 3배 빨리 감기 |
| Alt(누르는 동안) | 마우스 꺼내기(라운드 표시 올려 보기) |
| Esc | 설정(쓴 카드 표시 · 섞기 모션 · 뽑는 곳 · 방해 보상 · 승리 조건 · 속도 · 목소리) |

설정은 `user://card_round_settings.cfg`에 저장된다(자동 검사는 저장하지 않는다).

## 확정 / 시연값 / 미정

- **사용자 확정(10-25·10-28)**: 손 7장 = 테이블 7칸, 바꾸기·버리기 없음, 쓴 만큼만 7장까지 보충, 꺼내 든 카드는 모두가 본다, 사용 표시는 페인트 X(기본)·그을림 중 설정으로 하나.
- **시연값(팀 확정 필요)**: 카드 12종의 효과 수치(`rules/card_catalog.gd`), 대기 1.2초, 덱 40장, 방해 보상 +15점, 골드(1~4위 100/60/40/20, 방해 1회 +10), 스턴 3초, 벌칙 2발, 봇의 막으러 나갈 확률 30%.
- **미정**: 차례 순서 정하는 방법(지금은 자리 순), 원판 위치·크기, 목소리 변조 방식(실제 음성 채팅 연결), 골드 상점, 커스텀 모드(조건·카드·오브젝트 추가).
- 카드 그림: 팀 카드 그림 5장(`art/cards/`, 랜덤 연산·특수 다트·힘 증가·숫자 섞기·졸림)을 쓰고, 나머지 7장은 같은 틀을 코드로 그린다(`cards/card_faces.gd`). 그림이 생기면 `rules/card_catalog.gd`의 `art` 칸에 경로만 넣는다.

## 파일

`game/card_round/` — 한 파일 = 한 가지 일(2026-10-28 정리). 자세한 지도와 신호 연결표는 `작업기록/2026-10-28_DARTY_카드라운드_작업프롬프트.md`.

- `card_round.tscn` / `card_round.gd` — 감독(단계 순서와 부품 연결만). 장면에 펍 `Table`(`game/table/table.tscn`)이 들어 있다.
- `rules/` — 규칙 계산, 노드 없음: `round_rules.gd`(규칙), `card_catalog.gd`(카드 목록), `bot_brain.gd`(봇 판단), `dart_solver.gd`(F5 `solve_dart`와 같은 식 + 사람 몸 판정).
- `cards/` — 카드 보이기: `card_faces.gd`·`card_view.gd`(그림·3D 카드), `table_cards.gd`, `hand_fan.gd`, `shuffle_motions.gd`.
- `fx/` — 연출: `screen_debuff.gd`, `voice_fx.gd`, `stun_stars.gd`, `punishment_wheel.gd`.
- `ui/` — 화면 UI: `card_round_hud.gd`, `round_tracker.gd`.
- `flow/` — 진행 부품: `round_context.gd`(함께 쓰는 상자), `round_settings.gd`, `player_builder.gd`, `seat_mover.gd`, `card_actions.gd`, `dart_actions.gd`, `turn_effects.gd`, `disruption.gd`, `round_camera.gd`, `local_input.gd`, `hud_presenter.gd`, `round_capture.gd`.

바깥에서 바꾼 곳: `art/characters/character_rig.gd`(`holding_cards` 한 칸 추가 — 기본 꺼짐이라 F5·쇼케이스 동작은 같다), 펍 생성기 3곳의 브랜드 글씨 "다티" → "DARTY"(`art/pub/game_room_builder.gd`·`pub_builder.gd`·`pub_parts.gd`, 생성물 `pub.tscn`·`pub_game.tscn` 다시 만듦), `art/showcase/showcase_hud.gd`(로고 DARTY), `tests/test_card_round.gd`(새 검사).
펍 생성물의 자리 매트 "카드 뒷면 자리표시"는 이 장면에서만 지우고 진짜 카드를 같은 칸에 놓는다(`pub_game.tscn`은 그대로).
