# art/pub/room — F5 경기 방(펍) 모듈 지도

F5 경기 방 `art/pub/pub_game.tscn` 은 **생성물**이다. 코드가 방을 지어 파일로 저장한 것이라, 편집기에서 직접 고치면 다음에 다시 만들 때 덮어써진다.
이 폴더는 그 방을 **구역별로 나눈 생성기 모듈**이다(2026-11-17, 1,800줄 가까이 되던 `game_room_builder.gd` 를 나눔).
나눈 직후 다시 만든 `pub_game.tscn` 은 나누기 전과 바이트까지 같았다. 겉모습은 그대로이고, 찾기만 쉬워졌다.

- 조립표: [`../game_room_builder.gd`](../game_room_builder.gd) — `build()` 가 아래 모듈을 차례로 부르기만 한다(약 140줄).
- 공용 부품함: [`room_kit.gd`](room_kit.gd) — 모든 모듈이 이 파일을 `extends` 한다. 그래서 상수·재질·벽 계산 함수를 이름만으로 부른다.

## 1. 편집기에서 찾는 법 (3가지)

1. **노드 설명 보기**: `art/pub/pub_game.tscn` 을 열고, Scene 독에서 묶음 노드(`Shell`, `Bar` …)에 마우스를 올린다.
   "만든 곳: 파일 함수"가 뜬다. 이 글은 조립표의 `GROUP_SOURCES` 한 곳에서 온다.
2. **FileSystem 독**: `res://art/pub/room/` 폴더를 연다. 파일 이름이 곧 구역 이름이다(아래 표).
3. **이름으로 찾기**: 장면에서 고치고 싶은 노드 이름(예: `WallClock`, `Leg2`)을 복사한다.
   그다음 편집기 `Ctrl+Shift+F`(파일에서 찾기)로 `res://art/pub/room` 을 찾는다. `"WallClock"` 처럼 따옴표째 찾으면 만드는 줄이 바로 나온다.
   - 2026-11-17부터 같은 이름 형제 노드는 `@MeshInstance3D@123` 대신 `Leg2` 처럼 읽히는 이름이 된다(`add_child(node, true)`). 그래서 장면 이름이 코드 이름과 그대로 이어진다.

## 2. 무엇을 고치려면 어디를 여나

| 고치고 싶은 것 | 파일 · 함수 | 장면 안 노드 |
|---|---|---|
| 바닥·천장·벽(징두리·허리 난간·코니스·코브·기둥·칸 아치 틀) | `room_shell.gd` `build_shell` · `_wall_run` · `_wall_piece` | `Shell` |
| 창 구멍(벽을 뚫는 자리) | `room_shell.gd` `_window_hole` | `Shell` |
| 펍 건물 바깥 벽돌 껍데기 | `room_shell.gd` `build_exterior` | `Outside/PubExterior` |
| 오락실에서 창을 막는 회벽 판(펍에서는 숨김) | `room_shell.gd` `build_window_plugs` | `WindowPlugs` |
| 벽 칸 나누기 · 창/문/주크박스 자리 | `room_kit.gd` `_walls` · `_bays` · `_all_fixtures` · `_window_spots` · `_art_spots` | (여러 묶음이 같이 읽는다) |
| 과녁 벽(청록 판넬·큰 아치·칠판 두 장 `ChalkScores`) | `room_board.gd` `build_board_wall` | `BoardWall` |
| 레인 매트·투척선 | `room_board.gd` `build_lane` | `Lane` |
| 럼주통 | `room_board.gd` `build_barrels` | `Barrels` |
| 다트판 양옆 꾸밈(네온 과녁·다트 걸이·벽시계·트로피·거울 간판·깃발 줄) | `room_board_sides.gd` `build_board_sides` (+ `_neon_target` · `_dart_rack` · `_wall_clock` · `_trophy_shelf` · `_pub_mirror` · `_bunting`) | `PubOnly/BoardSideDecor` |
| 카드 테이블 · 의자 · 자리 매트/러그/번호 | `room_seating.gd` `build_table_and_seats` · `club_chair` · `bar_stool` | `TableAndSeats` |
| 바 · 맥주 꼭지 · 뒤 선반 · 냉장고 · 바 스툴 · 바텐더 | `room_bar.gd` `build_bar` · `_back_bar` · `_bar_fridge` | `Bar` |
| 바텐더가 꺼내는 것과 손님 자리 | `room_bar.gd` `build_bar` 의 `sources` · `customers` | `Bar` |
| NPC 구석 자리 · 앉은 손님 · 비스트로 탁자 · 당구대 | `room_guests.gd` `build_npc_corner` · `build_guests` · `build_bistro_tables` · `build_pool_table` | `NpcCorner` · `Guests` · `BistroTables` · `PoolTable` |
| 창틀·커튼·유리 | `room_decor.gd` `_window` | `Windows` |
| 문·간판·화분·벽 포스터 | `room_decor.gd` `build_decor` · `_wall_art` | `Decor` |
| 가구 모델(소파·안락의자·축음기·연습 과녁·옷걸이…) | `room_decor.gd` `build_furnish` (GLB = `room_kit.gd` `_model`) | `Furnishings` |
| 인디 펍 선반 소품(뿔 트로피·엇갈린 화살…) | `room_decor.gd` `_indie_decor` | `PubOnly/IndieDecor` |
| 꾸미기 방 상자(옷방) | `room_fitting.gd` `build_fitting_room` | `PubOnly/FittingRoom` |
| 펜던트 · 벽등 · 과녁 스포트라이트 · 방 환경(안개·SSAO) | `room_lights.gd` `build_lighting` (부품 `_pendant` · `_sconce` = `room_kit.gd`) | `Lights` |
| 창 밖 3D 밤거리 · 하늘 · 달 · 관람차 · 열기구 | `../street_outside.gd` (재질 `../street_night.gdshader`, 움직임 `../street_motion.gd`) | `Outside` |
| 재질 색(월넛·놋쇠·청록·대리석…) | `room_kit.gd` `_walnut` · `_brass` · `_teal` … | (모두) |
| 벽 높이·창 높이·겹침 틈·바 자리·전등 높이 같은 치수 | `room_kit.gd` 맨 위 상수 | (모두) |

### 다시 만들 필요 없는 것 (실행 중에만 움직임)

아래는 게임을 켤 때 붙는 스크립트다. 고치고 바로 F5 로 보면 된다.

| 무엇 | 파일 |
|---|---|
| 손님 몸짓(마시기·시가) | `../npc_idle.gd` |
| 손님 앞 랜덤 음식 | `../npc_table_food.gd` |
| 바텐더 서빙 동선 | `../pub_service.gd` |
| 시가 연기 | `../cigar_smoke.gd` |
| 관람차·열기구·차·구름 움직임 | `../street_motion.gd` |

## 3. 고친 뒤 다시 만들기

```bash
"<Godot exe>" --headless --path . --script res://art/pub/pub_builder.gd -- --game-room-only
```

- `--game-room-only` 를 꼭 붙인다. 통째 실행은 다른 작업자의 `chr_*.tscn` 까지 덮어쓴다.
- 같은 코드면 같은 파일이 나온다(무작위 없음).
- 생성 스크립트와 `pub_game.tscn` 을 **같은 커밋**에 넣는다.
- 검사: `tests/test_game_look.gd`(방 서명·묶음 이름).

## 4. 약속 (바꾸면 다른 곳도 고쳐야 한다)

- **충돌은 여기서 안 만든다.** 여기 있는 것은 모두 "보이기만" 한다. 부딪히는 가구를 옮기면 `game/table/table.gd`(TableView)의 충돌 상수(`BAR_BOX`, `FITTING_ROOM_BOX`, `BARRELS` …)도 같이 옮긴다.
- **규칙 좌표는 TableView 에서 읽는다.** 과녁 중심·투척선·테이블 자리 숫자를 여기 따로 적지 않는다.
- **이름을 바꾸면 안 되는 노드**
  - 묶음 이름(`Shell` · `Bar` · `Guests` · `PubOnly` · `Outside` …): 오락실 테마가 이 이름으로 뺀다(`game/lounge/lounge_world.gd` `ARCADE_SKIP`). 시험도 이 이름을 본다.
  - `SeatMat_N` · `SeatRug_N` · `SeatStool_N` · `SeatLabel_N`: 인원수에 따라 `TableView.show_seats` 가 숨긴다.
  - `Bell` · `Keg` · `PracticeTarget` · `Gramophone`: "건드리기"(`LoungeWorld.touch_spots`)가 찾는다.
  - `Pendant*`: 오락실이 이 이름의 펜던트를 모두 뺀다(카드 테이블 등 `TablePendant…` 만 남음, `lounge_world._trim_arcade`).
  - 재질 함수 이름(`_walnut` …): 오락실 색 바꾸기 표와 이어져 있다.
- **펍에만 있는 장식은 `PubOnly` 안에** 둔다. 오락실 테마에서 통째로 빠진다.
- **겹침 깜빡임 막기**: 벽에 겹치는 판은 `WALL_LAYER_GAP`(8mm), 바닥에 까는 판은 `FLOOR_LAYER_GAP`(4mm) 이상 띄운다.
- **class_name 을 새로 만들지 않는다.** 다른 모듈은 `preload` 상수로 부른다(`const RoomSeating = preload(...)`).
  - 부르는 방향은 한쪽으로만 둔다: bar → guests·seating, guests → seating, decor → fitting, 조립표 → 전부. 서로 부르면 불러오기가 돈다.
- **노드를 붙일 때 `add_child(node, true)`**: 같은 이름 형제가 있으면 `Leg2` 처럼 읽히는 이름이 된다(`false` 면 `@MeshInstance3D@123`).

## 5. 새 구역(묶음)을 더하는 법

1. 이 폴더에 `room_<구역>.gd` 를 만든다. 첫 줄은 `extends "res://art/pub/room/room_kit.gd"` 로 둔다.
   머리 주석에는 무엇을 만드는지, 장면 안 묶음 이름, 관련 충돌 상수를 적는다.
2. `static func build_<구역>(p: Node3D) -> void:` 를 만든다. 노드는 `p.add_child(x, true)` 로 붙인다.
3. 조립표 `game_room_builder.gd` 에 세 가지를 더한다.
   - `const Room<구역> = preload(...)` 한 줄
   - `build()` 안에 `Room<구역>.build_<구역>(_group(room, "<묶음>"))` 한 줄
   - `GROUP_SOURCES` 에 `"<묶음>": "설명 — 파일 함수"` 한 줄(노드 설명)
4. 이 README 의 2번 표에 한 줄 더한다.
5. 다시 만들고(3번) 시험을 돌린다. 펍 전용이면 `_group(pub_only, "<묶음>")` 아래에 둔다.
