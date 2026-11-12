# 커밋 정리 기록 2026년 11월 12일

사용자가 카드 28종, 중앙 펜스 제거, 협동 시너지, 팔·졸림·NPC 수정과 테스트·공유용 PDF의 커밋 및 푸시를 승인했다. 아래의 미커밋·푸시 보류 표기는 각 작업을 기록하던 당시 상태다. 최종 커밋과 원격 반영 여부는 Git 이력을 기준으로 확인한다. 공유용 요약은 `output/pdf/DARTY_작업정리_2026-11-12.pdf`에 있다.

---

# 최신 작업 — 중앙 펜스 제거·협동 시너지 (2026-11-12)

- 사용자 승인 방식: 서로 다른 사용자가 같은 투척자에게 동일 방해카드 사용 → 2인 1.5배/3인 2배. 최대 3명, 자기 중복은 손패를 소모하지 않는다.
- 방해 16종을 처리하고 셔터·반전·값 카드에는 카드에 맞는 단계 변화를 적용했다. 방장 규칙이 기여자 peer ID와 배율을 확정한다. HUD/피드/비행 중 판정/원격 과녁에 반영한다.
- F5 공용 맵의 로프·기둥·금지판·투명 제한벽 6개 제거. 투척선 앞 다트 홀 전체에서 몸 판정. 바닥 매트·투척선은 유지. F6 시연의 별도 투척 보호 구역은 유지한다.
- `pub_builder.gd -- --game-room-only`로 F5 맵만 생성할 수 있다. `pub_game.tscn` 재생성 완료.
- 실제 4인 시너지 동기화·기본 멀티플레이·154개 스크립트 로드·규칙/아트 검사와 F5 렌더 확인 완료. 최종 run_first_idea의 2/3/4인 5라운드·시간 초과·봇 교체·오류 로그 검사까지 모두 PASS.
- 상세: `작업기록/2026-11-12_중앙펜스제거_협동시너지.md`. 미커밋, 푸시 보류.

---

# 최신 작업 — CARD_PLAN 28종 반영 (2026-11-12)

- 사용자 승인: 미정 네 항목의 기본안, 제안 수치, 연산의 현재 투척자 대상 적용.
- 활성 카드 28종 / 5개 분류. 삭제된 +10·×2·−20은 번호 보존용 비활성 항목만 남기고 지급·사용 제외. 안정 다트는 기존 활성 목록에 없음.
- 점수: 카드 사용 순서대로 계산, 음수·소수 한 자리. 점수판·순위·스냅샷·백엔드까지 전달. 카운트다운은 0.1점 정수 단위로 정확히 0/버스트 계산.
- Z/X로 정밀 조정의 ±5 또는 물리 구역(20칸)을 선택한 뒤 투척 전에 사용. 선택 칸은 과녁에서 금색으로 강조.
- 점수 고정: 82개 물리 구역 중 5~20개, 1~20점 중 한 값, 현재 라운드 전체에 유지. 나머지 과녁 값·움직임은 차례 종료에 복원.
- 재도전: 사용자별 경기당 1회, 자기 차례에만, 현재 차례 바로 뒤 3발 추가. 구역 지목: 성공 +15 / 실패 현재 선택 구역 싱글 점수 감점(미스도 감점).
- 몸 받기: 기본 15점·보상 카드 제거, 카드 없는 피격은 이번 라운드 약한 어지러움. 보상 카드 사용 뒤 피격마다 +30. 투척자는 차례 동안 취기/감도/난시 중 하나와 음성 피치 변조.
- 특수 다트: 30/30/30/10% 패턴, 실제 2~3발 생성·합산. 힘 증가는 속도 ×1.3. 큰 다트는 반지름 0.06 원의 4096개 표본 중 가장 많이 겹친 물리 구역(동률 방장 추첨).
- 최종 run_first_idea·run_multiplayer·run_lounge, 순수 규칙·153개 스크립트 로드·백엔드 4개 검사 모두 PASS.
- 실제 F5 HUD·분리·점수 변경·먹물·다중 다트 렌더 확인: `.godot/card_plan/`. 테스트 및 남은 확인 범위는 `작업기록/2026-11-12_CARD_PLAN_구현.md`.
- 미커밋. 푸시는 사용자 요청대로 보류. 시너지/조합 보상은 추가하지 않음.

---

# 최신 인수인계 — 카드 피드백·손·NPC 종료 (2026-11-11)

- `MatchCards.duplicate_reason`을 방장과 HUD가 같이 사용한다. 중첩되지 않는 6종은 손패를 소모하지 않는다. 봇도 중복 카드를 피하거나 내려놓는다.
- `card_effects.details`에 활성 효과·지속 범위·중첩 횟수를 보낸다. HUD는 비행 중 `다음 한 발`을 `이번 비행`으로 바꿔 표시한다.
- 졸림의 공용 강도는 0.18로 줄였다. HUD의 금색 표시는 조준 오차 예고이며 탄착점 예측이 아니다.
- 1인칭 손은 엄지·검지 끝을 그립 기준으로 쓰고 놓을 때 나머지 손가락까지 편다. `HAND_CHARGE_OFFSET`은 실제 경기/미리보기 공용.
- NPC 시가·서빙의 skeleton_updated 콜백은 트리 이탈 뒤 전역 좌표를 조회하지 않는다.
- 상세: `작업기록/2026-11-11_카드피드백_손연출_NPC종료.md`. 미커밋, 푸시 보류. 1번 카드 조합 판정은 건드리지 않는다.

---

# 최신 인수인계 — F5 졸림 카드 적용 (2026-11-11)

- `CardCatalog.DROWSY_AIM_SPREAD = 0.3`을 F5/F6가 함께 읽는다. 눈꺼풀 가림에 더해 각 발의 조준 오차도 적용한다.
- `MatchController._flight_input`은 `_solve` 전에 초기화하고 `drowsy_offset`을 저장한다. 비행 재계산마다 난수를 다시 뽑으면 안 된다.
- `MatchCards.FLIGHT_KINDS`에 drowsy를 포함해 비행 중 사용도 반영한다. 화면 설정과 상관없이 서버 판정에 적용한다.
- `tests/test_drowsy.gd`와 실제 F5 렌더 확인 완료. 상세: `작업기록/2026-11-11_졸림카드_F5적용.md`. 미커밋, 푸시 보류.

---

# 최신 인수인계 — F5 1인칭 팔 재조정 (2026-11-11)

- `render_fp_arm.gd`는 실제 game.tscn의 카메라·손·다트를 추출한다. tscn의 Transform3D 숫자를 Basis(Vector3, ...)로 베껴 쓰면 행/열이 뒤바뀌므로 복제하지 않는다.
- `first_person_arm.gd`: 4cm 하향 보정 제거, 자루 뒤쪽 쥐기·손목 회전. part_0은 오른팔 뼈 가중치로 면을 걸러 몸통을 제거한다(3인칭 원본 불변).
- F6 `gestures.gd`의 가리키는 손도 같은 리깅 팔을 사용한다. Point_R의 실제 검지 뼈 방향을 앞쪽으로 맞춘다.
- 실제 검증과 남은 범위: `작업기록/2026-11-11_1인칭팔_재수정.md`. 커밋 `05d52da` 완료, 푸시는 사용자 요청으로 보류.

---

# 최신 작업 — 1인칭 팔을 리깅 캐릭터 오른팔로 (2026-11-09)

- 상태: 헤드리스 검사 진행, 1인칭 팔 화면 확인(`tests/render_fp_arm.gd`). 사람이 F5 로 직접 던져 보지는 않았다. **미커밋**.
- 실제 경기에 남아 있던 마지막 옛 프로토타입 아트였다: `character_factory.create_hand()`(구 + 막대 벙어리장갑·소매).
- 이제 선수 몸과 같은 리깅 캐릭터의 오른팔을 쓴다(`art/characters/first_person_arm.gd`).
  스킨드 메시 9조각 중 오른팔 2조각만 켜고, 몸통은 카메라 뒤로 보내 근평면에서 자른다(뼈·메시를 건드리지 않는다).
  자세는 `Dart_Throw` 겨누기 한 장면 고정. 충전·반동 연출(`GameView._animate_hand`)은 그대로다.
- 다트 쥐기는 씬의 `HeldDart.transform` 을 받아 맞춘다(회전 숫자를 베껴 적지 않는다).
- 새 도구 `tests/render_fp_arm.gd`: 1인칭 팔만 몇 초 만에 찍는다(`.godot/fp_arm/`). 경기 전체 렌더는 이 PC 에서 10분 넘게 걸린다.
- **F6 가리키는 손(`card_round/flow/gestures.gd`)은 아직 옛 도형 손이다** — 그 코드가 옛 손 내부 노드를 쓰고 있어 따로 맞춰야 한다.
- 상세: `작업기록/2026-11-09_1인칭팔_리깅교체.md`.

---

# 최신 인수인계 — 바텐더 서빙 · 랜덤 음식 · 시가 · 비스트로 테이블 · 오락실 매점 · 전등 규칙 (2026-11-08 밤 늦게)

- 상세: `작업기록/2026-11-08_펍서빙_시가_오락실매점_전등.md`. 결정: `docs/DECISIONS.md` 2026-11-08(밤 늦게).

## 노드 이름과 실행 중 노드

- **실행 중에 생기는 노드는 안쪽(internal) 자식으로 붙인다** — `add_child(node, false, Node.INTERNAL_MODE_BACK)`.
  - 대상: 서빙 잔·접시, 랜덤 차림, 시가·연기.
  - 방 생성기는 `_ready` 를 돌린 뒤 장면을 저장한다. 그냥 붙이면 그때 생긴 잔·음식이 `pub_game.tscn` 에 같이 굳는다.
- **같은 부모 아래 같은 이름은 엔진이 `@MeshInstance3D@12` 로 바꾼다.**
  - 이름으로 찾는 부품(예: 오락실이 빼는 `Pendant*`)은 겹치지 않는 묶음 노드 아래 둔다.
  - 펜던트는 `_pendant` 가 `Pendant_<자식 수>` 묶음을 만든다.
  - 남은 겹침: 벽등 `Sconce` 는 아직 `@Node3D@4xx` 로 바뀐다. 이름으로 찾는 곳이 없어 그대로 두었다.

## 뼈와 손 위치

- **뼈 수정기(CharacterPoseLayer: 마시기·가리키기 팔)가 바꾼 손 위치는 `Skeleton3D.skeleton_updated` 신호에서만 맞다.**
  - `_process` 에서 읽으면 수정 전 자세(허리께)다.
  - 시가(`npc_idle._place_cigar`)와 든 물건(`pub_service._on_skeleton_updated`)이 이 신호를 쓴다.

## 테이블 고정 · 서빙 동선

- `GameView._ready` 가 `table.transform = IDENTITY` 로 둔다.
  - 경기 규칙 좌표가 모두 원점 기준이라, 테이블을 옮기려면 TableView 상수를 고친다(씬에서 끌지 말 것).
- 서빙 동선은 `PubService.make(parent, server, lane, serve, lane_z, facing, sources, customers)` 한 곳에 숫자로 있다.
  - 바·조리대·스툴을 옮기면 `game_room_builder.gd` 의 `BAR_*`·`MICROWAVE_Z`·`COFFEE_Z`·`TableView.BAR_STOOLS_Z` 를 같이 본다.
  - 오락실은 `arcade_room.gd` 의 `SHOP_*`·`RACK_*`·`KITCHEN_*` 를 같이 본다.

## 테마별 가구 · 축음기

- 비스트로 테이블 충돌은 meta `pub_only` 상자다. 오락실에서는 `rebuild_pub` 가 `collision_layer = 0` 으로 끈다(`ARCADE_SKIP` 에 `BistroTables`).
- 축음기는 RG Poly `gramophone_classic` 이다.
  - Codex 축음기 GLB(`art/environments/roundhouse/pub/gramophone/`)는 안 쓰지만 남겨 두었다.

## 남은 판단

- NPC 4명·직원 1명 증가와 랜덤 음식(묶기 제외)의 그리기 비용 측정.
- 오락실 카드 테이블 위 놋쇠 등을 네온 등으로 바꿀지.
- 사람이 직접 보는 서빙·연기 느낌.

---

# 최신 인수인계 — 라운드하우스 모델 23종 (2026-11-08 늦은 밤)

- 상세: `작업기록/2026-11-08_라운드하우스_모델23종_통합.md`. 고치는 법: `art/README.md` "라운드하우스 모델(GLB)". 결정: `docs/DECISIONS.md` 2026-11-08(늦은 밤).
- **GLB 는 받은 원본이다** — 고치지 말고 같은 경로·이름으로 통째 교체만 한다.
  - 새 GLB 의 `.glb.import` 도 `gltf/embedded_image_handling=2` 로 둔다.
  - 열린 편집기 옆에서는 스크래치 사본에서 `--import` 한 뒤 `.import` + `.godot/imported/<이름>.glb-*` 만 옮긴다.
- **정적 묶기 제외 조건은 `scene_file_path` 가 `res://art/environments/roundhouse/` 로 시작하는 것**이다(`static_batch.gd` `ROUNDHOUSE_DIR`).
  - 다른 폴더에 텍스처 GLB 를 두면 묶기가 텍스처를 지운다. 이 조건을 넓힐 것.
- **오락실 덮개**: `LoungeWorld._recolor` 가 GLB 메시마다 `set_surface_override_material` 을 쓴다.
  - 펍이면 null 로 지운다.
  - 같은 메시에 다른 이유로 면 덮개를 쓰면 테마 전환 때 지워진다.
  - 대상은 `owner.scene_file_path` 가 roundhouse 인 메시뿐이다.
- 노드 이름으로 개수를 세지 말 것.
  - 같은 부모 아래 같은 이름은 `@Cabinet@2` 처럼 바뀐다.
  - GLB 안 뿌리 노드도 같은 이름이다(`CurtainPair/CurtainPair`).
  - `scene_file_path` 로 센다.
- 오락기 크기가 바뀌면 `CABINET_SIZE`·`CABINETS` 좌표(벽에서 0.04m)·`_fit_sign` 비율을 같이 본다. 진열장 글자는 `SHOWCASE_SIGN_Y`.
- 큐대 홈 높이 0.73 은 "중심 원점 + 반길이 0.71 + 바닥 여유 0.025" 에서 나온 값이다.
- 안 쓰게 된 RG Poly 구운 메시(`sofa`·`armchair`·`side_table`·`gramophone`·`hook` .res)는 남아 있다. 정리할지 팀이 정한다.
- 남은 판단:
  - GLB 105MB → 2026-11-08 밤 늦게 사용자 요청("푸시해")으로 커밋했다
  - 펍 그리기 호출 증가량 측정
  - 오락실 덮개 밝기
  - 선반 위 단 인형이 네온 간판 글자를 가리는 것

---

# 최신 인수인계 — 펍 만화 그림(창 밖 층 · 벽 포스터) (2026-11-08 밤)

- 상세: `작업기록/2026-11-08_만화그림_창밖_포스터.md`. 고치는 법: `art/README.md` "펍 만화 그림 고치기". 결정: `docs/DECISIONS.md` 2026-11-08(밤).
- **그림 원본은 `art/pub/pictures/*.svg`** 다. 같은 이름으로 고쳐 저장하면 방을 다시 만들 필요 없다(`pub_game.tscn` 이 경로로 참조). 새 그림을 더할 때만 `game_room_builder.gd` 의 `WINDOW_PICTURES`·`POSTER_PICTURES` 를 고치고 방을 다시 만든다.
- 창 밖 층의 실제 크기(깊이·폭·높이 m)는 셰이더 `far_size`·`street_size`·`front_size` 다. SVG 크기를 바꾸면 같이 바꾼다. 층 그림은 좌우로 이어 붙으니 양 끝에 걸친 물체를 두지 않는다.
- `.import` 는 `mipmaps/generate=true`·`detect_3d/compress_to=0`(무손실) — 기본값으로 되돌리면 멀리서 깜빡이거나, 편집기가 `.import` 를 혼자 바꾼다.
- 열린 편집기 옆에서 새 그림을 넣을 때: 스크래치 복사본에서 `--import` → `.import` 와 `.godot/imported/<이름>.svg-*` 만 옮긴다(실제 프로젝트에서 `--import` 금지).
- SVG `<text>`·blur 는 Godot(ThorVG)가 못 그린다 — 글자는 선(path), 빛무리는 투명해지는 방사형 그라데이션.
- 남은 판단: 창 밖 밝기(`brightness`, 지금 1.0 — 밤치고 알록달록), 포스터 문구 한글화 여부.

---

# 최신 인수인계 — 인원수만큼 자리 똑같이 나누기 · 앉은 다리 · 발걸이 (2026-11-08 저녁)

- 상세: `작업기록/2026-11-08_자리균등배치_앉은자세_발걸이.md`. 결정: `docs/DECISIONS.md` 2026-11-08(저녁).
- **경기 자리는 `TableView.seat_spot(자리)` 로 읽는다.** `SEATS[자리]` 를 직접 쓰면 3인·2인 방에서 의자와 어긋난다. `SEATS` 는 이제 4인 기본 자리(모두 반지름 1.4m)이고 F6 카드 라운드 시연과 방 생성기만 쓴다.
- 배치는 `GameView.sync_room` 이 방 상태가 올 때마다 `TableView.arrange_seats(room.shown_seats())` 로 정한다(정적 변수 — 방장·손님 모두 같은 방 상태로 같은 계산). 시험에서 배치를 바꿨으면 끝에 `arrange_seats([0,1,2,3])` 로 되돌릴 것.
- `seat_layout` 은 1μm 로 반올림한다. 안 하면 4.4+1.4 같은 float 끝자리 때문에 4인 자리가 `SEATS` 와 `==` 로 안 같아져 `test_prototype` 이 실패한다.
- **의자 옮기기**: `_apply_seats` 가 자리 노드(`SeatMat/SeatRug/SeatStool/SeatLabel_n`)의 생성 때 변환을 메타 `built_transform` 에 한 번 저장하고, 거기서 테이블 가운데 축으로 (새 방향 − 4인 방향)만큼 돌린다. 방을 다시 만들면 메타도 새로 잡힌다. `Seat` 로 시작하는 노드는 정적 묶기에서 빠져 있어야 움직인다.
- **앉은 다리**는 `CharacterPoseLayer._seat_leg` 가 AnimationPlayer 뒤에 허벅지·정강이를 `SEAT_THIGH`·`SEAT_SHIN` 방향으로 돌리고 발은 원래 방향을 지킨다. 세기 `seat_legs` 는 `CharacterMotion` 이 앉기 자세면 1 로(약 0.5초), 처음부터 앉아 있으면 바로 1.
- **발걸이 높이는 다리 각도에서 나온 값**이다: 고리 윗면 = 앉는 면 − `SEATED_SOLE_DROP`(0.378m). `SEAT_THIGH`·`SEAT_SHIN` 이나 캐릭터를 바꾸면 발바닥 높이를 다시 재서 이 값을 고치고 `pub_game.tscn` 만 다시 만든다(`pub_builder.gd` 통째 실행 금지).
- 남은 판단: 직접 앉았다 일어설 때 다리 바뀌는 속도(`SEAT_LEGS_RATE` 5), 3인 첫 자리 방향(`SEAT_START_YAW`), 발걸이 색.

---

# 최신 인수인계 — 카드 한 장씩 분배 · 앉은 몸 · 웅덩이 Decal · 창밖 셰이더 · 인원수 다시 정하기 · NPC 옷 (2026-11-08)

- 상세: `작업기록/2026-11-08_맵리디자인_롤셔터_NPC_감정표시.md`(오전) · `작업기록/2026-11-08_카드분배_바텐더옷_창풍경_인원수.md`(오후). 결정: `docs/DECISIONS.md` 2026-11-08.
- **손 부채는 덱 연출 뒤에 맞춘다.** `GameView._apply_state` 에서 `deck_show.sync` → `_sync_hand_fan` 순서다. 바꾸면 카드 7장이 한꺼번에 보인다. 아직 안 닿은 칸은 `DeckShow.visible_hand()` 가 -1 로 돌려주고, 한 장 닿을 때마다 `dealt` 신호가 온다. 새로 손패를 보여 주는 곳도 `visible_hand` 를 거칠 것.
- **앉은 몸 돌리기**는 `PlayerView._turn_body_in_chair` 가 `Model` 노드의 `rotation.y` 만 바꾼다(±`SEATED_TURN_LIMIT`). `PlayerView.rotation.y`(시선)는 건드리지 않는다. 모델 루트의 `rotation.y` 를 다른 데서 쓰면 서로 덮으니 주의.
- **창밖 그림 `WindowView`** 는 정적 묶기에서 빠진다(`StaticBatch.NO_BATCH_NAMES`). 묶이면 로컬 좌표(VERTEX)가 사라져 시차가 깨진다. 이름을 바꾸면 목록도 같이 바꿀 것. 원화 그림을 쓰려면 같은 메시에 텍스처 재질을 붙이면 된다.
- **웅덩이는 Decal** 이다(`BurstFx` splash). 바닥 높이 ±0.08m(`PUDDLE_DEPTH` 0.16)만 찍힌다 — 테이블 위처럼 높은 곳에는 안 찍힌다.
- **주크박스 충돌**은 `TableView.decor_blocks()` 의 `JUKEBOX_AT`·`JUKEBOX_SIZE`. `LoungeWorld.JUKEBOX` 는 이 상수를 가리킨다 — 주크박스를 옮기면 table.gd 한 곳만 바꾸고 방을 다시 만든다(`pub_game.tscn` 만, `pub_builder.gd` 통째 실행 금지).
- **인원수 바꾸기**: 대기실에서만 `RoomState.resize(capacity, bot_count)`. 서버 `_accept_settings` 는 방 종류(solo·private·social)는 잠그고 인원·봇 수만 `resize` 로 넣는다. 사람 수보다 적게는 못 줄이고, 넘치는 봇은 번호 큰 봇부터 뺀다. 빈 의자는 `shown_seats()` 가 `seat_order` 로 다시 고른다(2인 = 0·2번 마주 보기).
- **NPC 옷** `art/pub/npc_outfit.gd`: 뼈마다 `BoneAttachment3D "Outfit_<뼈>"` + 자식 `"Rest"`(그 뼈 쉬는 자세의 역변환) 아래에 메시를 둔다 → 옷 좌표는 **뼈대 공간**(서 있는 몸 기준 m)으로 적는다. Tripo 몸 치수는 오후 작업기록 8절. 차림은 `NpcIdle.spawn(..., dress_as)` 와 `@export outfit` 으로 고른다.
  - `MeshKit.own_tree` 는 인스턴스 씬 안으로 안 내려가서 옷 노드는 `pub_game.tscn` 에 저장되지 않는다 — 실행 때 `NpcIdle._ready` 가 입힌다.
  - `NpcIdle.spawn` 은 캐릭터를 홀더에 넣은 **뒤에** 장면에 붙인다(반대면 `_ready` 가 일찍 끝나 T 자세·옷 없음).
- **Tripo 캐릭터(8091f9c)**: 조각 9개 `tripo_part_0~8`, 셔츠 색 칠하기 없음. 자리 구분은 이름표·매트·HUD. 새 GLB·텍스처는 에디터가 다시 훑기 전까지 "invalid UID" 경고가 난다(실행 지장 없음).
- **시험 주의**: 사용자가 게임을 띄워 두면 포트 7000 이 잡혀 `test_prototype`(개발자 시작)이 멈춘다. 그 게임을 끄지 말고 포트를 바꾼 사본으로 돌린다.
- 남은 판단: 창밖을 셰이더 밤거리로 둘지 원화 이미지로 바꿀지, 앉은 몸 한계 55도가 손맛에 맞는지, 바텐더·손님 옷 색.

---

# 최신 인수인계 — 아수라장 다트 머신 · 인원수 좌석 · 오락실 기계 조작 (2026-11-07)

- 상세: `작업기록/2026-11-07_로비배경_인원좌석_다트머신_오락실기계.md`. 결정: `docs/DECISIONS.md` 2026-11-07.
- **과녁 모양은 `game/board/board_chaos.gd` 한 곳에서 계산한다.** 그림(`BoardView.show_chaos`, `DartMachine.show_chaos`)과 방장 점수(`MatchCards.landing_points`)가 같은 `BoardChaos.pose/locate/score` 를 쓴다. 회전·분리·셔터 숫자를 다른 곳에 다시 적지 말 것.
- **과녁 노드 경로가 바뀌었다**: 숫자·칸은 `Board/Face/Spin/SectorGroup0~4` 아래에 있다(불·뒤판은 `Spin` 바로 아래). 이름으로 찾을 때는 `find_child(..., true, false)` 로 재귀 검색.
- 꽂힌 다트는 `BoardView.pin()` 으로 조각에 붙고 `clear_pins()` 로 지운다(`GameView._clear_darts`). 셔터에 맞은 다트는 셔터 앞면(`BoardChaos.SHUTTER_FRONT`)에 박힌다.
- **카드 번호**: `board_spin`·`board_split` 은 `CardCatalog` 맨 뒤다. 새 카드도 맨 뒤에 붙일 것(손패를 종류 번호로 보낸다). `cover`(9번)는 이름만 "셔터".
- F6 카드 라운드 시연(`round_rules.gd`)은 spin/split 을 읽기만 하고 그림이 없다 → 시연에서는 효과 없는 카드다.
- **다트 홀이 1.4m 깊어졌다**(`TableView.DART_HALL` z −12.5). 머신 충돌 상자는 과녁 면 −0.12m ~ 뒷벽. 배치 상수를 바꾸면 방을 다시 만들어야 하는데, `art/pub/pub_builder.gd` 를 통째로 돌리면 다른 작업자가 바꾼 `chr_*.tscn`(7cd1130)까지 덮는다 — `pub_game.tscn` 만 다시 만드는 쪽을 쓸 것.
- **빈자리 숨기기**: `RoomState.shown_seats()` → `TableView.show_seats()`. `Seat` 로 시작하는 노드는 정적 묶기(`StaticBatch.NO_BATCH_PREFIXES`)에서 빠진다 — 새 자리 소품도 `Seat…_n` 이름을 쓰면 같이 숨는다.
- **오락실 인형뽑기 조종**: 방장 `GameView._physics_process` 가 `lounge.steer_machine()` 을 먼저 부르고, true 면 그 사람의 `move`·`jump` 를 0 으로 바꿔 시뮬레이션한다. 새 "몸 대신 무언가를 조종하는" 기능은 같은 자리에 붙일 것. 조종 중 `LoungeWorld.focus()` 는 언제나 인형뽑기를 돌려준다.
- 가챠 캡슐은 굴러 나오는 동안 `locked` + `dropping` 이다(`_capsule_in` 이 건너뜀). 농구 보정은 `ArcadeRules.assist_throw`, 림 튕김은 `ball_moved` 가 true 를 돌려주면 `LoungeWorld` 가 공을 `projectile.rim_at` 에 둔다.
- 새 스크립트 3개의 `.uid` 는 열린 에디터 때문에 `--import` 대신 `ResourceUID` 로 직접 만들었다(내용 형식 같음). 에디터가 다시 훑으면 그대로 읽는다.
- 남은 판단: 집게 속도·조종 시간·농구 보정 세기·회전 속도·분리 주기(모두 시작값), 요청서의 GLB 교체·홀 새 치수·소품 7종, 가챠 받침대를 요청서 좌표로 옮길지(펍 NPC 식탁 충돌과 공용).

---

# 최신 인수인계 — 리깅 캐릭터(v18) 게임 적용 (2026-11-06)

- 상세: `작업기록/2026-11-06_리깅캐릭터_게임적용.md`. 다시 만드는 법은 `art/README.md` "리깅 캐릭터 다시 만들기".
- `PlayerView._rig` 는 이제 `CharacterMotion` 이다. 겉면(`holding_cards`, `pointing`, `cheering`, `drinking`, `animate`, `play_throw`)은 같다.
- **`Model/Body/...` 경로는 없어졌다.** 카드 부채는 `rig.attach_cards(fan)`, 찾을 때는 `find_child("LeftHandCards", true, false)`.
- 에디터에서 볼 때는 `art/characters/rigged/player_character.tscn` 을 연다. 게임도 이 씬을 쓴다(`chr_*.tscn` 은 펍 쇼케이스·NPC 용).
- 캐릭터 정면은 `-Z` 다(예전 `+Z`). `PlayerLook.character()` 를 새로 쓰는 곳은 돌리는 방향에 주의한다.
- 모디파이어로 얹은 팔·머리는 `get_bone_global_pose` 로 안 읽힌다. `BoneAttachment3D`(`hand_L`, `hand_R`, `head`)로 읽는다.
- `CharacterRig` 는 펍 NPC 용으로 남았다. `drink_curve` 와 `HIP_HEIGHT` 는 플레이어 쪽도 아직 쓴다.
- `character_assets/` 는 GLB 를 다시 만드는 데 필요한 파일만 git 에 있다. 전체를 `git add` 하면 700MB 가 올라가니 조심한다.
- 남은 판단: 펍 NPC·1인칭 손 교체, 키 1.85m 와 판정 높이 1.75m 차이, 달리기 클립.

---

# 최신 인수인계 — 몸으로 다트 막기 F5 이식 (2026-11-02)

- 상세: `작업기록/2026-11-02_몸으로_막기_F5이식.md`.
- **다트가 이제 사람 몸에 맞는다.** `GameView.solve_dart` 가 벽보다 몸을 먼저 본다. 몸 크기·캡슐 계산은 `game/dart/body_hit.gd` **한 곳**이고 F6 `card_round/rules/dart_solver.gd` 도 이걸 쓴다 — 숫자를 두 군데 두지 말 것.
- **몸막 구역 안에 선 사람만 막는다**(`GameView._dart_bodies`). 던지는 칸에는 여럿이 몰려 서기 때문에 거기까지 세면 서로 끊임없이 막혀 경기가 안 된다 — 네트워크 시험이 잡아낸 것이니 되돌리지 말 것.
- 결과에 `victim`(맞은 사람 peer ID, 0 = 안 맞음)이 생겼다. `MatchState.last_hit` 에 그대로 실려 모든 화면이 본다(새 RPC 없음). 머리 위 별은 각 화면이 그 값을 보고 띄운다(`GameView._show_body_hit`).
- **몸막 구역** `TableView.BLOCK_ZONE`(투척선 0.9~1.6m 앞): 레인 옆벽이 이만큼 끊겨 있다. 숫자를 바꾸려면 **다트가 그 자리에서 지나는 높이를 다시 재야 한다** — 몸 캡슐 윗끝 1.75m, 판정 반지름 0.3m. 더 앞으로 옮기면 서서는 못 막는다(중력 보정 때문에 다트가 앞으로 갈수록 빠르게 높아진다). 바꾼 뒤 `art/pub/pub_builder.gd` 재실행 필수.
- 못 움직이는 판정은 `GameView._frozen` 한 곳에서 본다(소품 스턴 `LoungeWorld.is_stunned` + 몸막 스턴 `_stun_until`). 새 스턴을 넣으면 여기 합칠 것.
- 방해 성공 보상은 `MatchCards.disrupt` → `RoundRules.disrupt`. 경기는 `reward_mode = SCORE` 고정이다(카드 보상은 손패 7칸 구조상 F6 전용).
- 남은 판단: 던진 사람 벌(F6 `turn_effects.penalize`)을 넣을지, 35%·3초·+15점이 적당한지, 맞은 사람이 소품을 떨어뜨릴지.

---

# 최신 인수인계 — 손 카드 밝기 · 포인터 · 과녁 거리 7.2m · 펍 NPC (2026-11-02)

- 상세: `작업기록/2026-11-02_손카드밝기_커서_과녁거리_NPC.md`.
- **투척선과 과녁 사이가 7.2m 가 됐다**(사용자 "두 배는 늘리자"). `THROW_LINE_Z` 는 −3.6 그대로고 **다트 홀을 과녁 쪽으로 3.6m 늘렸다**: `DART_HALL` 깊이 **11.1m**, `BOARD_CENTER.z` **−10.8**. 투척선을 라운지 쪽으로 밀면 던질 칸이 사라지고 F6 방해 구역과 겹쳐서 이렇게 했다.
  - 과녁 벽에 붙어 있던 것만 따라갔다(큰 통 둘·작은 통 하나·연습 과녁). 사람이 서는 곳·봇 길·규칙·라운지·테이블·자리·바는 그대로다.
  - 천장 보 자리는 이제 `game_room_builder.ceiling_beams()` 한 곳에서 나온다 — **오락실(`arcade_room._ceiling_neon`)도 이 함수를 쓴다.** 숫자를 다시 적지 말 것.
  - **다트가 지나는 길(레인) 위에는 펜던트를 달지 않는다.** 홀 조명을 더 넣을 일이 있으면 옆벽 벽등(`PubParts.sconce`)으로 넣는다.
  - 로비 배경(`lobby/lobby_backdrop.gd`)은 이 방을 그대로 띄운다. 과녁을 또 옮기면 시야각이 따라 좁혀진다(`_framed_fov`) — 구도 기준은 `FRAME_DISTANCE`·`FRAME_FOV`.
  - **F6 카드 라운드 시연은 제 좌표(`flow/throw_zone.gd`, 옛 맵 숫자)를 쓰므로 거리가 9.85m 가 됐다.** 점수·시험은 그대로지만 몸으로 막는 간격은 다시 재야 한다.
- 배치 상수를 바꿨으므로 `art/pub/pub_builder.gd` 를 돌려 방을 재생성했다.
- 카드 재질에 **조명 없는 짝**이 생겼다(`CardView.material_for(texture, lit)`). 1인칭 부채만 `lit = false` 다 — 새 부채를 만들 때 이 값을 잊지 말 것.
- 펍 손님 NPC 는 `chr_guest_a~d.tscn`(생성물) + `art/pub/game_room_builder.gd` `_guests()` + `art/pub/npc_idle.gd`(제자리 동작). 캐릭터 씬은 정적 메시 묶기에서 빠지므로 실행 중 움직여도 된다.
- 남은 판단: 7.2m 에 맞춰 마우스 감도·`BOARD_SCALE`·봇 `AIM_SPREAD` 를 손볼지(사람만 어려워졌다 — 과녁 각지름 23° → 11.9°), NPC 반응·오락실 손님을 넣을지, 포인터 연타 고침이 도형의 의도와 맞는지.

---

# 최신 인수인계 — 음성 채팅 · Tab 플레이어 목록 · 싱글 봇 (2026-11-01)

- 상세: [2026-11-01_음성채팅_Tab목록_싱글봇.md](2026-11-01_음성채팅_Tab목록_싱글봇.md).
- `VoiceChat` 은 `NetworkSession` 이 `_ready` 에서 만든다(`session.voice`). `class_name` 이 없으니 쓰는 파일에서 `const VoiceChat = preload("res://network/voice_chat.gd")`.
- 보내기 `_voice_up`(any_peer, unreliable_ordered, 채널 3) → 방장 `_relay` → `_voice_down`(authority). 방장 검사: 같은 방 사람·봇 아님·묶음 ≤ 1280 B·초당 양(`_within_budget`). 새 음성 기능도 이 길을 지나게 한다.
- 마이크는 `project.godot` `[audio] driver/enable_input=true` 가 있어야 열린다. headless 실행은 마이크가 없으니 `VoiceChat.feed(frames, rate)` 로 소리를 넣어 시험한다.
- 머리 옆 스피커: `PlayerView.set_speaking(level)`(음수 = 숨김). `GameView._process` 가 `voice.is_speaking/level` 로 매 프레임 부른다.
- Tab 순서: `GameView._unhandled_input` 에서 감정표현 다음 `player_list.handle`. 무효 대상 고르기 조건은 `LoungeHUD.tab_picks_target()`(LoungeHUD 가 먼저 받는다).
- 봇 어울리기 `BotSocial` 은 싱글(solo) 방장에서만 만든다. 차례 아닌 봇을 `GameView._drive_bot` 이 먼저 `bot_social.drive()` 에 맡긴다. 레인 벽 끝 돌아가기는 `BotDriver._around_lane`.
- 개인 설정 `[voice]` 칸: enabled·mode·key·gain·sensitivity·volume·input/output 장치·people(표시 이름 → [볼륨, 음소거]).

---

# 최신 인수인계 — 카드 섞기 복원 · 방 넓히기 v4 · 네온 오락실 (2026-10-31 늦은 밤)

- 상세: [2026-10-31_카드섞기복원_방넓히기_네온오락실.md](2026-10-31_카드섞기복원_방넓히기_네온오락실.md) · 도면 6장: `docs/MAP_PLAN_2026-10-31.md`.
- 덱 연출 `game/table/deck_show.gd` 는 `GameView._apply_state` 에서 `sync(state)` 로만 움직인다(스냅샷 CARDS 진입 + 키 `match_id:round`). 화면 없는 실행(서버·헤드리스 시험)에는 노드가 없다. 섞기 속도는 `ShuffleMotions` 의 host 메타 `shuffle_speed`(F6 시연은 메타가 없어 1배).
- 매트 카드 숨기기/보이기: `SeatCards.hold(seat, 칸들)` · `release(seat, 칸)` · `release_all()`. 손님 화면 확인: `tests/run_deck_show_remote.py`(`network_probe.gd` 상태에 `deck_show`, 명령 `shot`).
- 방 크기 상수는 `TableView`(`DART_HALL`·`LOUNGE`·`CEILING_HEIGHT`) — 바꾸면 `pub_builder.gd` 를 다시 돌린다. 새 장식 충돌 `BAR_FRIDGE_AT`/`BAR_FRIDGE_SIZE`(바 끝 냉장고).
- 펍 생성물 묶음에 `Windows` 가 생겼다. 오락실은 `ARCADE_SKIP` 에 `Windows` 를 넣어 창 없는 방이 된다. 다트 홀 벽 선반·옷걸이 고리·뒤 구석 화분은 `PubOnly`.
- 오락실 그림 `game/lounge/arcade/arcade_room.gd`: 정적 메시는 `Static` 아래(화면 있을 때 `StaticBatch`), 움직이는 것(진짜 인형뽑기·가챠·농구·오락기 화면·직원)은 자기 아래. 간판은 `_neon_sign`(글자 크기 = 판 크기). `_bear(..., shared)` 의 shared 는 장식용만.
- 에셋 굽기: Cartoon City 는 zip 안의 zip. `v/city/Models/<분류>/*.glb` + `v/city/Textures/` 로 풀어야 한다(glb 가 `../../Textures` 를 본다). `--sheet --only=a,b,c`.

---

# 최신 인수인계 — 경기 UI · 감정표현 · 맵 도면 v3 (2026-10-31 저녁~밤)

- 상세: [2026-10-31_경기UI_감정표현_맵도면v3.md](2026-10-31_경기UI_감정표현_맵도면v3.md) · 도면·에셋 측정표: `docs/MAP_PLAN_2026-10-31.md`.
- F 키 순서(`GameView._unhandled_input`): 꺼내 든 카드가 있고 다트 턴이면 `LoungeHUD.use_lifted_card()` → 아니면 기계·건드리기·착석.
- 봇 손 부채·매트 카드·라운드 표시·감정은 모두 보이기만 하는 노드다(스냅샷의 hand/pending_slot/phase 를 읽음). 감정만 새 RPC 액션 `"emote"`(손님 → 방장)와 이벤트 `"emote"` 를 쓴다.
- 건드리기는 `lounge.request("touch", 번호)` → 방장 `_accept` → `lounge_fx` 이벤트의 `"wobble": 노드 이름`. 자리 목록은 `LoungeWorld.touch_spots()`.
- 에셋 메시는 `art/vendor/rg_poly/meshes/*.res`(원본 `.glb` 는 저장소 밖). 새 모델: `rg_poly_catalog.gd used()` 에 한 줄 → `rg_poly_baker.gd --bake --source=<푼 폴더>` → `game_room_builder.gd` 에서 `PubParts.asset()` → `pub_builder.gd`.
- 새 가구 충돌은 `TableView.decor_blocks()`. 자리 상수를 바꾸면 `pub_builder.gd` 다시 실행. 오락실과 겹치는 가구는 `PubOnly` 묶음(`LoungeWorld.ARCADE_SKIP`).
- 창 모드 시험: `render_match_ui.gd`(포트 17642) · `render_map_tour.gd`(포트 17652). 펍 가구를 보려면 `theme_id = 0`.

---

# 최신 인수인계 — 앉은 시점 · 엿보기 · 무효 한 장 · 마시기 · 유리 파편 (2026-10-31 오후)

- 상세: [2026-10-31_앉은시점_엿보기_마시기_유리파편.md](2026-10-31_앉은시점_엿보기_마시기_유리파편.md).
- 엿보기는 보이기만 하는 것이다: 손패는 원래 모든 스냅샷(`MatchPlayer.hand`)에 있고 `seat_lean` 도 원래 20Hz 로 간다. 규칙·RPC 는 그대로.
- 엿보기 판정은 자리 위치 기준(`SeatCards.peeked_seat`). 눈 위치로 재면 기울였을 때 옆 매트가 정면에 놓여 실패한다.
- 무효 한 장은 `MatchController._draw_card`·`_deal_single_nullify`. 경기마다 컨트롤러를 새로 만들므로 재경기 때 다시 한 장 들어간다. F6 `round_rules.gd` 는 그대로.
- 펍 매트의 크림색 가짜 카드를 `game_room_builder.gd` 에서 지우고 `pub_builder.gd` 로 `pub_game.tscn` 을 다시 만들었다(큰 diff 는 생성물).
- 창 모드 시험 `tests/render_seat_peek.gd` 는 포트 17641 · 화면 `.godot/seat_peek_render/`.

---

# 최신 인수인계 — 다트 턴 카드 사용 (2026-10-31)

- 규칙 연결은 `game/match/match_cards.gd` 한 곳. F6 시연과 함께 쓰는 `round_rules.gd`는 건드리지 않았고, 안쪽 클래스 `MatchRules`가 `valid_targets`만 "지금 던지는 사람"으로 바꾼다.
- 점수는 꽂힐 때 `MatchCards.landing_points`로 다시 센다(섞기·가림판 반영). 비행 중 궤적 카드는 `MatchController.redirect_flight` → `redirect` 게임 이벤트 → `DartView.redirect`로 모든 화면의 다트가 휜다.
- `MatchState.card_peer`(카드 턴 차례)와 방 설정 `RoomSettings.card_seconds`는 지웠다. `MatchConfig.card_seconds`는 개발자 F5 예시 경기용으로 남아 있다.
- 봇 카드: `MatchCards.tick_bots`(방장 매 프레임, 조준·비행 중). 확률 `BOT_USE_CHANCE`·시간 `BOT_THINK_SECONDS`는 시연값. 검사: `tests/test_bot_cards.gd`.
- 키 설정 파일에 예전 E가 저장돼 있으면 불러올 때 F로 바꾼다(`ui/player_preferences.gd`).
- 남이 카드를 꺼내 든 알림이 없어서 사람은 무효 ×0을 쓸 때를 알기 어렵다(봇은 상태를 보고 막는다) — 다음 작업 후보.

---

# 최신 인수인계 — 네온 오락실 · 깨지는 소품 · UI 개편 (2026-10-30 오후)

- 상세: [2026-10-30_오락실_깨지는소품_UI개편.md](2026-10-30_오락실_깨지는소품_UI개편.md).
- 소품 규칙·네트워크: `game/lounge/lounge_world.gd`(방장 판정, 10Hz 공개). 오락기 규칙은 `arcade/arcade_rules.gd`, 그림은 `arcade/arcade_room.gd` — 규칙과 그림을 섞지 말 것.
- 테마를 바꾸면 `TableView.rebuild_pub(skip, trim)` 으로 펍 그림을 다시 만든다(`StaticBatch` 가 메시를 합쳐서 그룹만 숨길 수 없다).
- 디자이너 파일 자리(있으면 자동 사용): `art/fonts/darty_*.ttf`, `art/ui/logo_darty.png`, `art/ui/icons/<이름>.png`, `art/audio/<이름>.ogg`, `art/props/<kind>.tscn`(재질 `M_Variant` = 변형 색), `art/arcade/carpet_blacklight.png`.
- 함정: 킬로그 칸 구분에 제어 글자(U+001F 등)를 쓰지 말 것 — Godot JSON 이 이스케이프하지 않아 네트워크 시험 파이썬이 상태를 못 읽는다. `MatchController.FEED_SEPARATOR`(탭)만 쓴다.
- 창 모드 시험(`render_*.gd`)은 assert 가 실패하면 창이 멈춰 있다 — 시간 제한을 두고 돌린다.

---

# 최신 작업 — F5 로비·라운지·게임 설정 (2026-10-30)

- 상태: 실제 저장소 반영 및 2/3/4인 전체 경기 검증 완료. 에디터와 스크립트 106개 로딩 PASS. 커밋·푸시 없음.
- F5는 로비 → 싱글/멀티 → 3D 대기실 → E 착석/Enter 참여 → 카드/다트 경기로 바뀌었다. 기본 예시 자동 실행을 끄고 `--developer --quick-test`로만 유지한다.
- 상세 변경·검증·미완성 범위: [2026-10-30_로비_라운지_게임설정_고도화.md](2026-10-30_로비_라운지_게임설정_고도화.md). 카드 사용도 F5 서버 경기에 연결했다. 아래 과거 기록의 “카드 사용 불가”는 현재에는 해당하지 않는다.
- 새 책임: `RoomSettings`, `FrontDoor`, `SettingsPanel`, `LoungeHUD`, `MatchCards`, `LoungeWorld`, `YouTubeBridge`. RPC는 기존 `/root/Main/NetworkSession`을 유지한다.
- 검증: 실제 다중 프로세스 기존 2종+새 라운지, 새 규칙/소품/HTTP, 기존 규칙/카드/투척/프로토타입, D3D12 화면 확인. Git 커밋·푸시는 수행하지 않는다.
- 운영 로그인/공개 방 목록·인터넷 중계, 외부 YouTube 실재생/다른 PC, F6 전체 보상·벌칙 연출의 F5 이식, 최종 아트·밸런스는 남아 있다. 자세한 한계는 상세 기록 참조.

---

아래는 당시 상태를 보존한 이전 작업 기록이다.

# 최신 인수인계 — 카드 라운드 시연 단독 장면 (2026-10-28)

- 상세 기록: `작업기록/2026-10-28_카드라운드_시연.md`. 흐름표·조작·시연값: `docs/CARD_ROUND_PROTOTYPE.md`. 결정: `docs/DECISIONS.md` 2026-10-28.
- `game/card_round/` 단독 장면(F6). **F5 경기·네트워크와 연결 안 함.** 규칙 계산은 노드 없는 `round_rules.gd`라 나중에 방장 쪽으로 옮길 수 있다.
- 바깥 변경: `art/characters/character_rig.gd`에 `holding_cards`(기본 꺼짐), `art/cards/*.webp` 밉맵, `darty_launch.cmd cards` + `실행_카드라운드.cmd`.
- 함정: 카드 재질에 발광을 넣으면 펍 글로우에 색이 바랜다. HUD는 앵커 프리셋 대신 고정 위치·`CenterContainer`. `CardFaces.bake`는 `CardView`를 만들기 전에. 펍 생성물의 `CardBack` 자리표시는 `add_child` 전에 지운다(`StaticBatch`가 합치기 전).
- 검증: test_card_round(`--play`) PASS, 기존 test_rules / test_throwing / test_game_flow / test_art_showcase / test_game_look / test_prototype PASS, D3D12 캡처 15장 확인. **사람의 직접 조작은 미검증.**

---

# 최신 인수인계 — F5 실제 경기에 카드 나눠 주기 (2026-10-28)

- 상세: `작업기록/2026-10-28_F5_카드_나눠주기.md`. 결정: `docs/DECISIONS.md` 2026-10-28 "F5 실제 경기에서도 …".
- 경기 단계가 **시작 → CARDS → AIMING**, 라운드가 넘어가면 **TABLE → CARDS → AIMING** 이 됐다(`MatchController._begin_cards`).
- `MatchPlayer.hand` 가 옛 `CardDefinition` 배열에서 **카드 종류 번호 배열**(`Array[int]`, `game/card_round/rules/card_catalog.gd` 기준)로 바뀌었다. 스냅샷 키는 그대로 `hand` 다.
- 카드 목록·그림·손 부채는 **카드 라운드 시연 것을 그대로 쓴다**(`card_catalog.gd`·`card_faces.gd`·`hand_fan.gd`). 카드 모양을 두 벌로 만들지 말 것.
- 1인칭 부채는 `GameView._prepare_hand_fan()` 이 카메라에 붙인다. 화면 없는 서버·검사(`--headless`)에서는 만들지 않는다.
- **아직 카드를 쓰지는 못한다.** 나눠 주기까지다.
- 검증: 헤드리스 7종 PASS(`test_prototype` 에 "다트 전에 모두 7장" 검사 추가), 실제 화면으로 손 부채·HUD 확인.

---

# 최신 인수인계 — 카드 라운드에 카드 턴 (2026-10-28)

- 상세: `작업기록/2026-10-28_카드턴_추가.md`. 결정: `docs/DECISIONS.md` 2026-10-28 "카드 라운드에 카드 턴을 둔다".
- 라운드 순서가 **카드 단계 → 카드 턴 → 다트**가 됐다(`card_round.gd` `_run`). 카드 턴은 자리 순서대로 한 명씩 **한 장 또는 패스**(사람 Enter, 봇 자동).
- **다트 중에는 카드를 못 쓴다**(`_dart_stage` 시작에서 `ctx.cards_open = false`).
- 누가 낼 수 있는지는 `card_actions.can_lift()` 한 곳이다: 자기 카드 턴이면 아무 카드, 남의 턴이면 **대응 카드(무효 ×0)만**. 이 예외는 ×0 카드와 1.2초 심리전을 살리려고 넣었다 — 팀 확정 필요.
- 봇 판단 기준이 `darts_phase` → `my_card_turn` 으로 바뀌었다(`bot_brain.decide`).
- `flow/seat_mover.gd` 의 던지는 자리를 `TableView.THROW_LINE_Z + 1.2` 로 바꿨다(옛 맵 좌표 −1.9가 박혀 있었다). 1.2m 는 막는 사람이 앞에 설 자리이고 보호 레인에 들어가지 않는다.
- 검증: `test_card_round.gd`(+`-- --play`) PASS — 새 검사 "카드 턴 단계가 돈다", "다트 중에는 카드를 낼 수 없다". 봇 4명 한 라운드 실행으로 단계 전환도 확인했다. 사람이 직접 낸 조작감은 미검증.

---

# 최신 인수인계 — 맵을 도면의 ㄱ자 방으로 (2026-10-28)

- 상세 기록: `작업기록/2026-10-28_도면_맵_재작성.md`. 결정: `docs/DECISIONS.md` 2026-10-28 "방을 도면의 ㄱ자로".
- 방이 **사각형 하나 → 사각형 둘의 합집합**이 됐다: `TableView.DART_HALL`(x −6~+6, z −7.5~0 · 과녁·투척선·럼주통)과 `TableView.LOUNGE`(x −8.4~+12.1, z 0~+7.5 · 바·플레이어 테이블·NPC 자리·당구대). 도면을 스툴 지름 0.6m 로 환산한 뒤, "좁다"는 피드백으로 **전체를 1.5배**로 넓혔다(가구 크기는 그대로).
- **과녁 앞은 가운데 복도만 막는다**(x ±`LANE_HALF` = ±1.2, 앞·양옆 세 면). 레인 바깥 양옆은 뚫려 있어 과녁 옆까지 걸어가 구경·방해할 수 있다. 그래서 `in_throw_zone` 은 "다트 홀 안 **그리고** 투척선 뒤"다.
- 없어진 상수: `ROOM_HALF`, `TABLE_RADIUS`(테이블이 네모 `TABLE_SIZE` 가 됨), `OBSTACLES`, `JUKEBOX_BOX`. 새 상수: `BARRELS`/`SMALL_BARRELS`, `NPC_TABLE_BOX`/`NPC_STOOLS`, `POOL_TABLE_BOX`, `FRONT_LIMIT_Z`, `BODY_MARGIN`.
- **이동 한계는 이제 `TableView.clamp_floor()`** 다. `clampf` 두 줄로는 ㄱ자를 가둘 수 없다. 자리 생성 위치·일어설 때 밀려나는 거리도 이 함수를 통과시킨다(2번 자리가 뒷벽에 붙어 있다).
- 과녁은 (0, 2.9, −7.2), 투척선 z = −4.05 → **투척 거리 3.15m**(원래 3.6m). 과녁 규격(2.5배·2.9m)은 팀 확정 대기라 그대로다.
- `art/pub/game_room_builder.gd`(김도형 담당 폴더)를 같이 고쳤다(사용자 승인). 배치 상수를 바꾸면 `art/pub/pub_builder.gd` 재실행 필수.
- **라운지에서는 못 던진다**: 방만 바꿔서는 부족했다(입구가 8m라 자리에서도 과녁이 보이고 맞았다). 그래서 투척을 다트 홀 안으로 제한했다 — `TableView.in_throw_zone()`, `MatchController.in_throw_zone`(GameView 가 주입하는 Callable, `check_seated` 와 같은 방식), 로컬 `throw_input.enabled` 잠금, HUD 안내.
- 그래서 **시험 시나리오가 바뀌었다**: `run_first_idea.py` 는 차례마다 테이블을 피해 옆길로 투척선까지 실제로 걸어가 던지고 돌아온다. 시험 집합 시간이 1초(`fast_match`)라 **라운드의 마지막 투척자만 지각**하며, 그 사람만 자동 착석 + 슬로우를 받는지 검사한다.
- 투척 거리가 2m로 짧아 **비행이 약 1초 → 0.3초**가 됐다. 고정 대기로 착탄을 기다리던 시험은 정산까지 끝나 버리므로 조건 대기로 바꿨고(`test_prototype`),
  `run_first_idea.py` 의 "비행 중 중복 요청" 검사는 명령 왕복(~0.2초)이 비행보다 길어 재현이 안 되므로 `test_prototype`(같은 프로세스)에 맡겼다.
- 검증: test_rules / test_throwing / test_game_look / test_prototype / test_game_flow / test_art_showcase / test_card_round PASS, run_multiplayer.py · run_first_idea.py 실제 다중 프로세스 10항목 PASS. 실제 화면으로 평면도·투척선 시야·라운지·자리 시야 확인.
- 미검증: 사람이 직접 걸어 본 동선, 다른 PC·LAN, 전용 서버 재내보내기. `output/game_look/` 의 팀 공유 그림은 아직 옛 방이다(`tests/render_game_look.gd` 재실행 필요).

---

# 최신 인수인계 — 봇이 투척선까지 걸어가 던진다 (2026-10-27)

- 상세 기록: `작업기록/2026-10-27_봇_투척선.md`. 결정: `docs/DECISIONS.md` 2026-10-27.
- 전까지 봇은 **앉은 채 조준 자세만** 하고 20초 뒤 0점이었다(`_accept_throw`가 봇 거부, `simulate`가 봇이면 즉시 반환, 그런데 `aiming`은 켜짐).
- 이제 봇은 자기 차례에 일어나 **투척선(`TableView.THROW_LINE_Z`) 바로 뒤 레인 한가운데**까지 걸어가 3발을 던지고 자리로 돌아가 앉는다. 걸어가는 동안에는 팔을 들지 않는다.
- 새 파일 `game/player/bot_driver.gd`: 상태 없는 계산만 한다(조향·조준 방향·조준점·충전). 호출은 `GameView._drive_bot`(방장 전용). 자리 `(0,0,5.5)`의 봇은 테이블에 정면으로 막히므로 `_steer`가 테이블을 비껴간다.
- `MatchController`: `_accept_throw` 뒷부분을 `_launch`로 분리하고 `bot_throw(aim, charge)`를 더했다. **사람 요청의 발신자 검증·봇 거부는 그대로다.** 봇 전용 RPC·가짜 피어는 없고 위치는 기존 이동 스냅샷으로 전달된다.
- 봇 난이도(`AIM_SPREAD` 0.4 / 충전 0.95~1.0 / `AIM_SECONDS` 1.2초)는 **시연값 — 팀 확정 필요**. z=-0.6 `StandMarker`는 여전히 의미 미정이고 이번에 쓰지 않았다.
- 검증: test_prototype PASS ×2(새 검사: 기립→투척선 도착→3발 투척→자리 복귀, 판정 원점이 투척선), test_rules / test_throwing / test_game_flow / test_art_showcase / test_game_look PASS. 실제 D3D12 화면으로 봇이 테이블을 돌아 선에 서서 던지고 돌아오는 것을 확인했다.
- 미검증: 사람의 직접 플레이, 다른 PC·LAN, 전용 서버 빌드 재내보내기. 봇이 넷 다 같은 자리에 서는 것(캐릭터끼리 충돌 없음)은 아직 정하지 않았다.

---

# 최신 인수인계 — 디자인 외형 F5 연결 · 팀 피드백 빌드 (2026-10-26 저녁)

- 상세 기록: `작업기록/2026-10-26_게임통합_디자인.md`. 결정: `docs/DECISIONS.md` 2026-10-26 "디자인 외형을 F5 실제 경기에 연결". 파일 지도: `art/README.md` 첫 표.
- F5에 펍 방(`art/pub/pub_game.tscn`, `table.tscn`의 자식 `Pub`)·다트판 그림(`BoardArt`)·자리 캐릭터 + 코드 몸짓(`PlayerLook`, `CharacterRig`)·자리 색 다트/손·칠판 점수·HUD 테마(`PubTheme`)가 들어갔다.
- **TableView는 이제 충돌 상자만 만든다**(메시 없음, 13개). 배치 상수를 바꾸면 `art/pub/pub_builder.gd`로 방을 다시 만들어야 한다 — 안 하면 시작 경고 + `test_game_look` 실패(`layout_signature`).
- 채점·이동 속도·충돌 캡슐·눈높이·네트워크 메시지는 그대로다. 몸짓은 각 화면에서 계산(동기화 안 함).
- 검증: test_rules / test_throwing / test_game_flow / test_prototype / test_art_showcase / test_game_look / render_first_idea / render_game_look / run_multiplayer.py / run_first_idea.py PASS. 사람의 직접 플레이·다른 PC·60fps 측정은 미검증.
- 팀 확인 대기: 테이블 지름 2.1m(기획 2.4m), 관전 구역, 스툴 장애물 3개 위치, 바닥 놋쇠 `StandMarker`(z=-0.6) 의미, 바텐더·주크박스 자리, 팀원 V08 블렌더 캐릭터 채택 여부.

---

# 최신 인수인계 — 테이블 집합·지각 슬로우·충전 취소·한글화 (2026-10-26)

- 상세 기록: `작업기록/2026-10-26_테이블집합_슬로우_한글화.md`. 결정: `docs/DECISIONS.md` 2026-10-26.
- F5 실제 경기: 라운드가 넘어갈 때 `MatchState.Phase.TABLE`(enum 맨 뒤 = 7) 10초. 못 앉은 사람은 자동 착석 + 다음 라운드 `speed_scale` 0.5. MatchController는 `check_seated`/`force_seat` Callable만 안다. 충전 중 오른쪽 버튼 = `charge_cancelled`.
- 쇼케이스(F6): 투척 시점 1인칭 시선·A/D·꾹 충전·오른쪽 취소, 착탄은 F5 `solve_dart`와 같은 식. 한국어 UI·3D 간판(`pub_builder.gd`로 재생성).
- 이 PC 설정(저장소 밖): `%APPDATA%\Godot\projects.cfg`에 `다트-` 추가, GitHub Desktop에 `darts_game` 추가. 다른 팀원 PC는 Godot에서 Import로 `다트-/project.godot`을 고른다.
- 한글은 Godot 기본 글꼴 + 시스템 대체 글꼴로 그린다. 배포 전 한글 글꼴 지정 필요. 사람의 직접 조작은 미검증.

---

# 최신 인수인계 — 아트 통합·카드 7장 규칙·협업 규칙 (2026-10-25)

- 상세 기록: `작업기록/2026-10-25_아트통합_카드규칙.md`. 협업 규칙: `docs/COLLABORATION.md`. 아트: `art/README.md`, `docs/ART_DIRECTION.md`.
- `art/`는 디자인 담당 폴더다. 실제 경기(F5)와 연결하지 않았고 지워도 F5·서버는 동작한다. `art/pub/pub.tscn`, `art/characters/chr_*.tscn`은 `art/pub/pub_builder.gd`로만 다시 만든다(같은 코드 → 같은 파일).
- 쇼케이스 점수는 팀 `BoardScorer`를 쓴다. 아트 다트판은 실제 규격(0.17m, 높이 1.73m), 실제 경기 과녁은 2.5배·높이 2.9m — 바꿔 끼우기 전에 팀 결정.
- 카드: `CardHandRules`(7장 채우기, 안 쓰면 0장, 연산/다트/과녁/물리). 흐름도 시연에 사용·방해(`jam_<번호>`)·합동 라운드(`JOINT_ROUND`) 추가, 교환 단계 제거. 실제 MatchController 연결·효과 수치는 미구현.
- 검증: test_rules / test_throwing / test_prototype / test_game_flow(+render) / test_art_showcase(+render) / run_first_idea.py PASS. 네트워크 코드 미변경으로 run_multiplayer·전용 서버·백엔드 시험은 재실행 안 함. 사람의 직접 조작·다른 PC 실행은 미검증.
- 저장소 최상위 `*.cmd`는 ASCII·CRLF다. 한글을 넣지 않는다.

---

# 최신 인수인계 — 게임 진행 청사진 (2026-10-16)

- 사용자 요청: 첨부 흐름도의 단순한 내용만 큰 틀로 구현하고 상세 구현은 팀원이 진행한다.
- `game/flow_preview/flow_preview.tscn`을 열고 F6으로 실행한다. 기존 F5 3D 경기와 별개인 버튼 시연이다. 가상 참가자를 실제 네트워크 클라이언트로 해석하지 않는다.
- `game_flow.gd`는 UI 독립 단계·반복 모델, `flow_preview.gd`는 표시/설정/버튼이다. 방 입장부터 카드 사용/미사용, 매 차례 3발, 페이크/취소, 전원 테이블 복귀, 카드 정비·선택적 2장→1장 교환, 목표 점수 차이 순위까지 연결했다.
- 이동/복귀/카드 효과/방해/투척 물리는 단계 표시와 점수 입력으로 대체한다. 시작 3장·중간 1장, 고정 순서, 교환 각자 1회, 2라운드, 공동 순위는 모두 임시값이다. 이전 카드 구현을 활성화하지 않았다.
- 팀원 분담과 실제 MatchController/NetworkSession/Game/카드/백엔드 연결 위치는 `docs/GAME_FLOW_BLUEPRINT.md`를 읽는다. 실제 경기 권한·네트워크·백엔드 정책 변경은 이번에 하지 않았다.
- `tests/test_game_flow.gd`: 실제 2·3·4인 진행 모델 완주, 카드 양쪽 분기, 취소 발수 유지, 중복/잘못된 점수 거부, 교환 횟수/수량, 빈 손패, 목표 차이 공동 순위와 초기화 PASS. 시연 씬 headless 실행 PASS.
- `-- --render` 실행: 실제 D3D12 시작/4인 조준/결과, 960×540 창 렌더 PASS. `.godot/flow_preview_render/` 이미지를 직접 열어 확인하고 설정 제목 줄바꿈을 보정했다. 화면은 OS 창 크기 보정으로 큰 창의 실제 캡처가 1875×1055다.
- 기존 `tests/test_rules.gd` PASS. Windows 인증서 저장소 읽기와 import의 작업 영역 밖 에디터 설정 저장 오류는 기존 환경 로그다. 사람 수동 조작, LAN/인터넷, 실제 경기와 이 청사진의 통합은 미검증이다.
- 기존 `tests/run_first_idea.py` 전체 PASS: 실제 2·3·4인 이동/착석/입력 소유권/5라운드·각 15발·750점/동일 착탄과 점수/중복·잘못된 요청 거부/재경기/실제 20초 시간 초과/사람 3명의 봇 교체. 로그 `.godot/prototype_tests/1792112100698013800/`. Git diff 자체 검토와 diff --check 완료. 네트워크 코드를 수정하지 않아 별도의 로비/전용 서버/계정 전체 시험은 재실행하지 않았다.
- 기존 실행 파일은 다시 내보내지 않았다. 현재 씬을 Godot 에디터에서 실행한다.

---

# 이전 인수인계 — 로컬 개발 로그인·프로필·전적 (2026-10-16)

## 현재 구현과 실행

- 사용자 확인: 아직 Steam App ID가 없어 로컬 개발 로그인부터 연결했다. Steam 인증을 구현/검증한 것으로 취급하지 않는다.
- docs/BACKEND_DEV.md를 읽는다. backend/run_local.ps1의 api → server → player를 별도 PowerShell 창에서 실행한다. API/서버 키 파일은 최초 실행 시 backend/data/server_key.txt에 생성하고 콘솔에 출력하지 않는다. Python 3.10+ 필요, pip 의존성 없음. 실행 스크립트는 문법 검사만 수행했고 사람의 직접 실행은 미검증이다.
- API는 127.0.0.1:8080의 개발 전용 HTTP/SQLite 서비스다. --dev와 DART_SERVER_KEY(ASCII 32자 이상)가 없으면 시작하지 않는다. DB/키는 backend/data/, 결과 대기 파일은 output/builds/server/data/results/이며 Git 제외다. backend/*는 모든 export preset에서 제외했다.
- Main --backend-url 지정 시 자식 BackendConnection을 생성한다. 로그인/프로필, 서버 토큰 검증, 정상 완주 결과 디스크 대기/전송을 담당하며 게임 물리·점수는 기존 MatchController가 소유한다. API 미지정이면 기존 익명/봇 모드를 유지한다. 계정 모드에서는 전용 서버에 참가한다.
- NetworkSession은 토큰 검증 응답의 계정 ID·이름을 실제 RPC 발신자에 묶는다. 계정 ID 매핑은 서버 전용이고 공개 스냅샷에 키/토큰을 넣지 않는다. 같은 계정 중복 입장은 거부한다. 비밀번호는 salt+PBKDF2-SHA256, 토큰은 SHA256 해시/24시간 만료로 저장한다.
- 전적 정책: 현재 5라운드·턴당 3발의 정상 완주/사람 경기만 집계한다. 중도 이탈/봇/다른 규칙은 제외한다. 최고 점수 공동 승리다. 미구현 목표 점수 근접 모드의 출시 규칙을 확정한 것은 아니다.
- 결과 ID는 경기/재경기마다 새 무작위 128bit다. 파일을 먼저 기록하고 저장 ACK 후 삭제한다. API 장애는 5초 재시도, 서버 재시작 후도 복구한다. 백엔드는 같은 ID·같은 결과를 1회만 반영하며 내용 충돌은 409다. Godot JSON 재로드의 정수→실수 차이를 정규화했다.

## 실제 확인

- tests/test_backend.py: 실제 HTTP/SQLite 로그인 재사용/비밀번호/토큰 해시·만료/서버 권한/점수 경계/동시 중복·충돌·롤백 PASS (.godot/backend_unit.log).
- tests/run_backend_game.py: 내보낸 서버+2개 실제 클라이언트의 로그인→익명·동일 계정 거부→5라운드 각 15발/750점→API 중단→서버/API 재시작→대기 JSON 복구/삭제→동일 계정/중복 없는 전적→Godot 프로필 갱신 PASS. 최종: .godot/backend_tests/1792079791521200600/.
- 기존 실제 2·3·4인 로비/연결·로딩 장벽 PASS: .godot/network_tests/1792079489041638500/. 기본 EXE/콘솔/D3D12 플레이어 시작과 명시적 로그 PASS: .godot/startup_tests/1792079973260617600/.
- tests/render_accounts.gd: 실제 로그인 UI·마스킹/비밀번호 삭제·프로필, 1920×1080와 960×540 PASS. .godot/accounts_render/01_account_profile.png, 02_account_small.png를 열어 확인했다. 작은 창 포트 입력 최소 폭 160 보정.
- GDScript parse/runtime 오류 없음, Git diff self-review·diff --check 완료. 인증서/셰이더 캐시/editor_settings 저장 환경 오류는 남는다. API 장애 시험의 HTTP 0 재시도 로그는 의도한 실패다.

## 이후 범위

- Steam 티켓/보유권 검증, 외부 HTTPS·운영 DB·서버 배정/다중 방·부하 시험은 아직 없다. 현재 계정 API는 localhost 전용이며 개발 계정을 Steam 계정으로 간주하지 않는다.
- 사람이 직접 실행 스크립트/마우스로 조작한 수동 시험, 다른 PC/LAN/외부 인터넷은 미검증이다.
- 기존 기본 파일 로그 비활성화 설정을 유지한다. 새로운 데이터·키를 Git에 추가하거나 이전 인증서/엔진 로그 오류를 게임 코드 오류로 혼동하지 않는다. Git 반영은 사용자의 후속 요청에 따라 dev_1에서 진행한다.

---

아래는 이전 작업 기록이다. 계정/DB/저장 관련 상태는 위 최신 인수인계를 우선한다.

# 최신 수정 — Windows 기본 실행 접근 위반 (2026-10-16)

- 사용자 화면의 메모리 접근 위반과 같은 0xC0000005를 재현했다. 기본 user 로그 파일 열기 실패 뒤 Godot 4.6.3의 RotatedFileLogger가 null FileAccess를 사용한다. 게임 코드 진입 전 문제다. 이전 --log-file 시험으로는 기본 실행을 검증할 수 없었다.
- project.godot에서 자동 파일 로그(기본/PC)를 끄고 콘솔 출력을 유지했다. 서버·플레이어·검증 빌드를 같은 output/builds/ 경로로 다시 내보냈다. AGENTS.md 및 게임/네트워크 코드는 이번 수정에서 바꾸지 않았다.
- 서버 EXE와 console EXE 기본 실행, 실제 D3D12 플레이어 기본 실행, 쓰기 가능한 --log-file 저장 PASS: .godot/startup_tests/1792078467088929800/. 회귀 실행기: tests/check_export_startup.py.
- tests/run_dedicated.py는 이제 서버에 --log-file/--headless를 추가하지 않는다. 콘솔 출력을 server.log에 수집한다. 실제 2인 5라운드·각 15발/750점·재경기·이전·재사용 PASS: .godot/dedicated_tests/1792078394644677000/. 실제 4인 접속/권한/참가 거부/이탈/재접속 PASS: .godot/dedicated_tests/1792078398802200100/.
- GDScript parse/runtime 오류 없음. Git diff self-review 및 diff --check 완료. Windows 인증서와 셰이더 캐시 저장 환경 오류는 남는다. 셰이더 캐시 오류는 정확히 _save_to_cache(shader_rd.cpp) 출처만 환경 항목으로 따로 보고한다.
- 파일 로그가 필요하면 docs/DEDICATED_SERVER.md의 쓰기 가능한 경로 예제를 따른다. --log-file로 쓰기 불가능한 경로를 강제할 때의 엔진 자체 버그는 고치지 않았다.
- 사람이 직접 Explorer에서 더블클릭하는 조작, 다른 PC/LAN/외부 인터넷은 미검증이다. 동일 기본 인자의 별도 프로세스 실행은 검증했다. 다음 Steam/DB 구현은 이 문제 해결 후 별도 단계다.

---

아래는 이전 기록이다. 자동 파일 로그와 기본 실행 검증은 위 최신 수정 내용을 우선한다.

# 최신 인수인계 — 전용 서버 첫 번째 목표 (2026-10-16)

## 구현과 실행

- Godot 루트는 `다트-/`다. 기존 AGENTS.md는 수정하지 않았다. 현재 서버 실행 방법은 `docs/DEDICATED_SERVER.md`를 읽는다.
- `output/builds/server/DartPartyServer.console.exe` 실행, 플레이어는 `output/builds/client/DartParty.exe` 실행 후 서버 IP·UDP 7000으로 **방 참가**. EXE와 같은 이름의 PCK를 함께 둔다.
- `dedicated_server` feature 또는 `-- --server`로 Main이 서버를 부팅한다. 서버는 선수/HUD를 생성하지 않는다. 서버 빌드는 자동 headless다. 소스에서 실행할 때는 `--headless`도 전달한다.
- `NetworkSession.is_host()`는 서버 ID 1 권한, `is_room_host()`는 `RoomState.host_peer_id`와 일치하는 선수 방장 권한이다. 처음 접속한 사람이 방장이고 이탈하면 남은 첫 사람으로 이전한다.
- 서버는 기존 Game/MatchController로 물리·자유 이동·투척·채점·턴을 소유한다. 시작/로비/재경기 요청도 실제 RPC 발신자로 검증한다. 로딩 장벽에 서버 자신을 포함하지 않는다. 전원 이탈하면 빈 로비로 돌아간다.
- 모든 메시지는 서버를 통하므로 SceneMultiplayer.server_relay=false다. 참가자끼리의 직접 RPC나 자동 peer 목록을 사용하지 않고 RoomState 스냅샷을 사용한다. 다중 이탈은 ENet poll 이후 방 상태를 한 번 갱신한다.
- Windows Client/Server는 Release, Windows Verification은 별도 Debug preset이다. 검증 preset만 verification feature로 network_probe.tscn에서 시작한다. 배포본에서는 tests/를 제외한다. export template의 CLI script/Scene override는 지원되지 않으므로 사용하지 않는다.
- tests/network_peer.gd는 에디터 CLI 래퍼다. 실제 공통 검증 로직은 tests/network_probe.gd로 이동했다. tests/run_dedicated.py는 내보낸 실행 파일만 사용하며 --players, --lifecycle-only로 범위를 좁힐 수 있다.

## 실제 검증 결과

- 최종 내보낸 서버 + 실제 2·3·4개 클라이언트: 자기 턴 이동, 턴당 3발, 5라운드 각자 15발·750점·동일 착탄, 비방장 RPC 거부, 재경기, 방장 이전, 전원 이탈·재접속 PASS. 4인 최대 인원·중도 접속 거부 PASS.
- 최종 로그: `.godot/dedicated_tests/1792077521511862500/`. 중간 실행의 닫힌 ENet 채널 오류는 수정 전 로그다. 현재 결과는 이 최종 폴더 기준이다.
- 4인 동시 이탈·재접속 3회 연속 PASS: `.godot/dedicated_lifecycle_stress_final.log`. 고정 0.4초 대기 대신 실제 정지 명령 처리와 전원 위치 수렴을 기다린다.
- 기존 로비 회귀 PASS: `.godot/network_tests/1792077542322216400/`. 기존 실제 2·3·4인 게임 완주 PASS: `.godot/prototype_tests/1792077017663105500/`.
- 규칙·투척·개발 모드 통합·실제 D3D12 1920×1080 렌더링 PASS. `.godot/dedicated_{rules,throwing,prototype,render}.log`. 렌더 이미지를 직접 열어 확인했다. 플레이어 Release 시작과 잘못된 포트의 종료 코드 1도 확인했다.
- GDScript parse/runtime 오류 없음. Git diff self-review와 diff --check 완료. Windows 인증서 저장소 및 에디터 설정 저장 권한 환경 오류는 남는다. 기본 user 로그 경로에서는 저장 오류/엔진 크래시가 발생한 적이 있어 검증 명령에는 작업 영역 안의 --log-file 절대 경로를 지정한다.

## 다음 작업과 범위

- 다른 PC LAN·외부 인터넷·사람의 수동 조작감은 미검증이다. 이번 결과는 로컬 loopback의 실제 별도 프로세스 자동 검증이다.
- Steam 인증·초대·중계·서버 검색, 프로필 API/DB, 다중 방 할당·자동 확장은 아직 구현하지 않았다. 지금은 서버 프로세스 1개 = 방 1개다.
- 빌드는 output/builds/에서 관리하며 Git 제외다. 기존 output/ PDF는 유지했다. 이 작업에서 commit/push하지 않았다.

---

아래는 이전 작업 기록이다. 서버 권한/실행 방식은 위 최신 인수인계를 우선한다.

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
