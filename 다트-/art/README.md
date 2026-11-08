# art/ — 디자인 담당 폴더

디자인 담당(김도형)이 소유하는 폴더다. 아스트라 AI로 만든 펍·캐릭터 예시안을 팀 프로젝트 안으로 옮겼다(2026-10-25).
**2026-10-26부터 F5 실제 경기에 연결되어 있다.** 경기 방(펍)·다트판·캐릭터·다트·HUD 색이 모두 이 폴더의 코드로 그려진다.
아트 기준은 [docs/ART_DIRECTION.md](../docs/ART_DIRECTION.md), 에셋 출처는 [docs/ASSET_REGISTER.md](../docs/ASSET_REGISTER.md).

## 한눈에: F5 경기에서 무엇이 어디서 오나

| 화면에 보이는 것 | 그리는 파일 | 경기 쪽 연결 지점 |
|---|---|---|
| 펍 방 전체(벽·바닥·바·창문·조명·로프·주크박스·바텐더) | `pub/game_room_builder.gd` → 생성물 `pub/pub_game.tscn` | `game/table/table.tscn`의 자식 `Pub` |
| 다트판(칸·숫자·뒤판) | `board_art.gd` | `game/board/board.gd`(BoardView)가 실행 때 그림. 카드로 숫자 순서가 바뀌면 다시 그림 |
| 플레이어·봇 캐릭터(리깅, 셔츠만 자리 색) | `characters/rigged/player_character.tscn` | `player_look.gd` `character()` → `game/player/player.gd`(PlayerView `_dress`) |
| 펍 NPC(손님·바텐더) | `characters/character_factory.gd` → 생성물 `characters/chr_*.tscn` | `pub/game_room_builder.gd` |
| 플레이어·봇 몸짓(서기·걷기·숙이기·점프·앉기·조준·던지기·카드 들기·가리키기·만세·마시기·엿보기·왕머리·깜빡임) | `characters/character_motion.gd` + `characters/character_pose_layer.gd` | PlayerView `_process`, 로비 `lobby_backdrop.gd` |
| 펍 NPC 몸짓 | `characters/character_rig.gd` | `pub/npc_idle.gd` |
| 자리 색·모양(●▲■◆)·캐릭터 이름 | `player_look.gd`(PlayerLook) | 이름표·발밑 매트·스툴·HUD·칠판·다트 깃이 모두 이 표 하나를 봄 |
| 1인칭 손(자리 색 소매) | `characters/character_factory.gd` `create_hand()` | `game/game.gd` `_equip_hand()` |
| 다트(은 촉·금 몸통·자리 색 깃) | `game/dart/dart.tscn` + `paint()` | 꽂힐 때 2.2배로 커짐(과녁이 실제의 2.5배라서) |
| 칠판 점수판(과녁 왼쪽 문) | `pub/game_room_builder.gd`의 `ChalkScores` 글자 | `game/game.gd` `_chalk_text()` → `TableView.set_chalk_scores()` |
| HUD·대기실 색 | `../ui/pub_theme.gd`(PubTheme) | `ui/game_hud.gd`, `lobby/lobby.gd` 첫 줄 |

**충돌(부딪힘)은 디자인 쪽에 없다.** 벽·테이블·바·주크박스·스툴 장애물의 충돌 상자는 `game/table/table.gd`(TableView)가 상수로 만든다.
그래서 사람이 부딪히는 가구를 옮길 때는 TableView 상수(`BAR_BOX`, `JUKEBOX_BOX`, `OBSTACLES` …)를 같이 바꾸고 생성기를 다시 돌린다.

## 리깅 캐릭터 다시 만들기

원본은 `character_assets/reference_character_20261105/` 다. `animated_base_v18/` 은 고치지 않고,
`game_ready_v19/build_game_motions.py` 가 v18 을 열어 게임에 없던 모션을 더한 뒤 GLB 를 내보낸다.

```
blender -b animated_base_v18/character_animated.blend --python game_ready_v19/build_game_motions.py -- <game_ready_v19 절대 경로> <art/characters/rigged/character_library.glb 절대 경로>
```

- 경로는 절대 경로로 넘긴다. 내보낸 뒤 Godot `--headless --import` 로 다시 가져온다.
- `character_library.glb.import` 의 `animation/remove_immutable_tracks=false` 를 유지한다. 켜면 기본 자세와 같은 뼈 트랙이 빠져 모션을 섞을 때 앞 모션 자세가 남는다.
- 옷을 바꾸려면 에디터에서 `player_character.tscn` 을 열어 `Character_Rig/Skeleton3D` 아래 조각의 보이기를 켜고 끈다. 셔츠 자리 색은 실행 때 칠해지므로 에디터에서는 기본 색으로 보인다.
- 모션 미리 보기: 같은 씬에서 `AnimationPlayer` 를 고르면 아래 애니메이션 패널에서 클립을 틀어 볼 수 있다.
- 게임 모션: `Walk`, `Crouch_Idle`, `Crouch_Walk`, `Jump_Air`(높이 이동 제거), `Sit_Stool`·`Seated_Stool`·`Stand_Stool`(스툴 높이 0.6m), `Cheer`, `Point_R`, `Drink_R`, `Wheel_Spread`. v18 그대로 쓰는 것: `Idle`, `Dart_Throw`, `Card_Hold_L`.
- 실제 방에서 확인: `godot --path . --script res://tests/render_characters.gd` → `output/character_motions/`.

## 실행

- F5 실제 경기: 에디터에서 **F5**(개발 모드 = 사람 1 + 봇 3). 저장소 최상위 `실행_게임.cmd`도 같다.
- 아트 쇼케이스(실제 규격 다트판 데모): `실행_디자인예시.cmd` 또는 `art/showcase/showcase.tscn`을 열고 **F6**.

쇼케이스 조작: 1~4 카메라 · 화면 클릭 후 마우스 시선 · A/D 좌우 · 왼쪽 버튼 꾹→놓기 투척 · 오른쪽 버튼 취소 · Q 카드 ×2 · Space 다음 차례 · R 처음 · M 효과음 · Esc.

## 파일

| 경로 | 역할 | 손으로 고치나? |
|---|---|---|
| `player_look.gd` | 자리별 약속표: 색·모양·캐릭터 씬·이름 | 예 |
| `board_art.gd` | 다트판 그림(쇼케이스·F5 공용). 링 비율은 팀 `BoardLayout` | 예 |
| `board_spec.gd` | 쇼케이스 다트판의 실제 크기(m)·높이·투척 거리 | 예 |
| `mesh_kit.gd` | 상자·원기둥·부채꼴 같은 도형 메시와 재질 캐시 | 예 |
| `static_batch.gd` | 실행 때 움직이지 않는 메시를 묶어 그리기 호출 수를 줄인다(F5 방에도 적용) | 예 |
| `characters/rigged/player_character.tscn` | 플레이어·봇 캐릭터 씬. 아래 GLB 를 상속해 기본 차림만 보이게 둔다. 에디터로 열면 게임과 같은 모습이다 | 예 — 조각 보이기를 켜고 끄면 게임 옷이 바뀐다 |
| `characters/rigged/character_library.glb` | v18 리깅 + 게임 모션. 옷·머리 조각이 모두 들어 있다 | **아니오 — 생성물**. 아래 "리깅 캐릭터 다시 만들기" |
| `characters/character_motion.gd` | 위치·자세·속도로 어떤 모션을 틀지 정한다. 팔 자세 우선순위도 여기 | 예 |
| `characters/character_pose_layer.gd` | 온몸 모션 위에 팔·고개·기울기·왕머리를 얹는 SkeletonModifier3D | 예 |
| `characters/character_factory.gd` | 펍 NPC(3등신) + 1인칭 손. 관절(피벗) 구조 포함 | 예 |
| `characters/character_rig.gd` | 펍 NPC 몸짓. 마시기 박자 `drink_curve` 는 플레이어도 같이 쓴다 | 예 |
| `characters/chr_*.tscn` | 위 스크립트가 만든 결과 | **아니오 — 생성물** |
| `pub/pub_parts.gd` | 스툴·테이블·펜던트·벽등·로프·창문·화분·병 선반 부품 + 공용 재질 | 예 |
| `pub/game_room_builder.gd` | F5 경기 방 조립(TableView 좌표를 읽는다) | 예 |
| `pub/pub_builder.gd` | 생성기 본체: 캐릭터·쇼케이스 펍·경기 방을 전부 저장 | 예 |
| `pub/pub.tscn`, `pub/pub_game.tscn` | 위 도구가 만든 결과 | **아니오 — 생성물** |
| `pub/pictures/*.svg` | 펍 만화 그림: 창 밖 층 4장(`window_*`) + 벽 포스터 3장(`poster_*`) | 예 — 벡터 도구로 바로 고친다(아래) |
| `pub/window_view.gdshader` | 창 밖 그림 층을 깊이별로 붙이고 하늘·별·길바닥을 그린다(시차) | 예 |
| `showcase/*` | 쇼케이스 데모(카메라·투척·카드 예시·효과음) | 예 |

## 펍 만화 그림(창 밖 · 벽 포스터) 고치기

2026-11-08: 창 밖 풍경과 벽 액자를 손으로 그린 만화 그림(SVG)으로 바꿨다. 일러스트레이터·피그마·Inkscape 로 열어 고치고 같은 이름으로 저장하면 된다.

| 파일 | 그림 크기(px) | 게임 속 실제 크기 | 쓰는 곳 |
|---|---|---|---|
| `window_far.svg` | 1920 × 960 | 96m × 48m, 유리 뒤 60m | 스카이라인·대관람차·열기구 |
| `window_street.svg` | 2100 × 800 | 42m × 16m, 유리 뒤 18m | 길 건너 건물 6채 |
| `window_front.svg` | 1400 × 600 | 14m × 6m, 유리 뒤 6.5m | 알전구 줄·가로등 고양이 |
| `window_moon.svg` | 512 × 512 | 하늘 방향(반지름 0.075 라디안) | 다트 꽂힌 달 |
| `poster_bullseye/cheers/lucky.svg` | 640 × 840 | 0.62m × 0.81m 액자 그림 | 벽 액자 3개(`_art_spots` 순서) |

- 창 밖 층: **아래 끝 = 땅**, 투명한 곳으로 뒤 층·하늘이 보인다. 그림 왼쪽 끝과 오른쪽 끝이 이어 붙으므로(창마다 다른 곳이 보임) 양 끝에 걸친 물체는 두지 않는다.
- 그림 크기(px)나 실제 크기를 바꾸면 `window_view.gdshader` 의 `far_size`·`street_size`·`front_size`(깊이, 폭 m, 높이 m)도 같이 고친다. 가로등을 옮기면 `front_lamp_x`.
- SVG 의 `<text>` 글자는 Godot 가 못 그린다 — 글자는 선(path)으로 그린다("180!", "CHEERS!", "LUCKY!" 가 그렇게 되어 있다). 흐림(blur) 필터도 안 된다. 빛무리는 투명해지는 방사형 그라데이션으로.
- 같은 이름으로 저장하면 에디터가 다시 가져오므로 방을 다시 만들 필요가 없다(방 그림은 경로로 읽는다). `.import` 설정(밉맵 켬·3D 압축 감지 끔)은 그대로 둔다.
- 새 그림 파일을 더할 때만 `game_room_builder.gd` 의 `WINDOW_PICTURES`·`POSTER_PICTURES` 를 고치고 `pub_game.tscn` 을 다시 만든다.

## 바꾸고 다시 만들기

`chr_*.tscn`, `pub.tscn`, `pub_game.tscn`은 **에디터에서 직접 고치지 않는다.** 다시 만들면 덮어써진다.
색·치수·배치는 위 "예" 파일을 고친 뒤 생성기를 돌린다.

```bash
"<Godot exe>" --headless --path . --script res://art/pub/pub_builder.gd
```

`ART BUILD COMPLETE`가 나오면 성공. 같은 코드면 같은 파일이 나온다(무작위 없음 — 두 번 돌려 md5 동일 확인함).
그다음 검사를 돌리고, 생성 스크립트와 생성물을 **같은 커밋**에 넣는다.

```bash
"<Godot exe>" --headless --path . --script res://tests/test_game_look.gd      # F5 연결 검사(방 서명·관절·몸짓·레이어·다트판·다트)
"<Godot exe>" --headless --path . --script res://tests/test_art_showcase.gd   # 쇼케이스 검사
"<Godot exe>" --path . --script res://tests/render_game_look.gd               # F5 화면 10장 + 던지기 낱장 → ../output/game_look/
```

`render_game_look.gd`는 약 20초 동안 전체 화면이 되고 마우스를 잡는다.

## 좌표 약속

- 1단위 = 1m. 바닥 y=0.
- **F5 경기 방**: 과녁 중심 (0, 2.9, -6.7)·2.5배, 투척선 z=-3.1, 투명 벽 z=-3.2, 테이블 (0, 0, 3.5) 지름 2.1m — 전부 `TableView` 상수. 방 그림은 이 값을 읽어서 만든다.
  상수를 바꾸면 생성기를 다시 돌린다. 안 돌리면 F5 시작 때 경고 `방 그림(pub_game.tscn)이 TableView 상수와 다릅니다`가 뜨고 `test_game_look`이 실패한다.
- **쇼케이스 펍**: 실제 규격(득점 반지름 0.17m, 중심 1.73m, 투척선 2.37m 앞). 경기 방과 크기가 다른 것은 의도다(경기는 앉은 자리 약 10m에서도 던지므로 과녁이 크다).
- 캐릭터 정면은 **+Z**, 팀 플레이어 노드는 -Z 정면 → PlayerView가 모델(`Model`)만 180° 돌린다.
- 캐릭터 관절: `LegL/LegR`(골반 0.59m) · `Body`(0.59m) · `Body/ArmL, ArmR`(어깨 0.94m) · `Body/Neck`(1.07m). L/R은 캐릭터 본인 기준.
  나중에 블렌더 모델(.glb)로 바꿀 때 이 이름을 지키면 `character_rig.gd`를 그대로 쓸 수 있다(자세한 절차는 바탕화면 `DARTY_프로젝트/DARTY_게임통합_다음작업_가이드.md`).

## 아스트라 원본과 달라진 점

원본은 바탕화면 `DARTY_프로젝트/darty_godot/`에 그대로 두었다(삭제·수정 없음).

- 별도 Godot 프로젝트 → 팀 프로젝트 안 `art/` 폴더. 렌더러는 팀 설정(Forward Plus).
- 원본 `board_rules.gd` 삭제 → 팀 `BoardScorer`/`BoardLayout` 하나로 통일.
- 게임 스크립트 안의 점수 검사 → 팀 `tests/test_rules.gd`가 담당. 쇼케이스 검사는 `tests/test_art_showcase.gd`.
- 주석을 한국어로 다시 달았다.
