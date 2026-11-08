# 에셋 출처·고지 기록

게임 프로젝트(`다트-/`) 안에 들어가는 에셋의 출처를 적는다. **새 외부 에셋(모델·텍스처·폰트·음원·플러그인)을 넣을 때는 이 표에 한 줄을 먼저 추가한다.**
비상업용·출처 불명 에셋은 배포물에 넣지 않는다. 이 문서는 법적 무위험 보증서가 아니다.

## 현재 등록부 (2026-10-25, 10-31 갱신)

| 항목 | 경로 | 출처·제작 방법 | 외부 에셋 | 비고 |
|---|---|---|---|---|
| 펍 환경 | `art/pub/pub.tscn`, `art/pub/pub_builder.gd` | 아스트라 AI 도움으로 작성한 GDScript 도형 조합 | 아니오 | 외부 3D 파일·텍스처·로고 없음 |
| 플레이어·봇 캐릭터 | `art/characters/rigged/character_library.glb` | 팀 캐릭터 시트 기준 Tripo 생성 후 Blender 로 다듬고 리깅(v18). 게임 모션은 `character_assets/.../game_ready_v19/build_game_motions.py` 로 추가 | 아니오 | 텍스처 없이 단색 재질. Tripo 생성물 이용 조건은 팀 확인 필요 |
| 펍 NPC(손님·바텐더) | `art/characters/` | 디자인 문서의 비율로 만든 매개변수 모델 | 아니오 | 참고 이미지 임포트 없음 |
| 다트판(아트) | `art/pub/pub_builder.gd`, `art/board_spec.gd` | 표준 규격 수치 + 팀 `BoardLayout` 비율 | 아니오 | 기존 판 이미지 없음 |
| 쇼케이스 효과음 | `art/showcase/synth_audio.gd` | 사인파·난수 즉석 합성 | 아니오 | 녹음·샘플 없음 |
| 아이콘 | `icon.svg` | 팀 프로젝트 기본 | — | |
| 화면 글꼴 | (엔진 내장 + OS 글꼴 대체) | Godot 기본 글꼴 | 엔진 구성요소 | 한글은 OS 글꼴로 대체 표시됨 — 출시 전 재배포 가능한 한글 글꼴 결정 필요 |
| 캐릭터 V08 원본 | 저장소 `output/character_v08/` | 팀원 블렌더 작업 | 별도 확인 | 게임 리소스 아님(Godot 프로젝트 밖) |
| 엔진 | Godot 4.6.3.stable.official.7d41c59c4 | 공식 배포본 | 예 (MIT + 구성요소) | 아래 고지 참고 |
| 펍 가구 41종 (도면 v3, 2026-10-31) | `art/vendor/rg_poly/meshes/*.res` (굽기: `rg_poly_baker.gd`, 목록: `rg_poly_catalog.gd`) | **RG Poly** — Kitchen & Restaurant Pack · Medieval Megapack (itch.io Creator Bundle Vol.1, 다른 작업자가 전달한 `에셋.zip`) | 예 (**CC0** — 묶음 안내 `plan.txt` 기준. zip 안에는 라이선스 파일이 없어 itch.io 팩 페이지에서 한 번 더 확인할 것) | 원본 `.glb`·텍스처는 저장소에 넣지 않는다. 쓰는 모델만 면마다 한 색(정점 색, 펍 팔레트로 당김)으로 구운 메시만 넣었다. 목록·측정값: `docs/MAP_PLAN_2026-10-31.md` |
| 네온 오락실 소품 21종 + 펍 냉장고 병 (방 넓히기 v4, 2026-10-31 늦은 밤) | `art/vendor/rg_poly/meshes/*.res` (주스 가게·인형뽑기 코너: `game/lounge/arcade/arcade_room.gd`) | **RG Poly** — Cartoon City Massive Pack(차양·다이너 의자·컵·병조림·오리 인형·화분·휴지통) · Kitchen & Restaurant Pack(과일·우유·음료 캔·싱크대·금속 선반·와플·그릇) — 같은 `에셋.zip` | 예 (**CC0** — 위 행과 같은 근거, itch.io 팩 페이지 재확인 필요) | 원본은 저장소 밖. 오락실용은 팔레트 당김 0~0.15(원래 만화 색 유지). 음료 캔 4색은 빨간 몸통만 바꿔 구웠다(`SODA_COLORS`). 상표·실제 제품 모델 없음(캔·우유팩은 무지) |
| 사용자가 고른 RG Poly 모델 47종 (펍 서빙·오락실 매점, 2026-11-08 밤) | `art/vendor/rg_poly/meshes/*.res` (목록: `rg_poly_catalog.gd` 2026-11-08 묶음 · 쓰는 곳: `art/pub/game_room_builder.gd` · `art/pub/pub_service.gd` · `art/pub/npc_table_food.gd` · `art/pub/npc_idle.gd` · `game/lounge/arcade/arcade_room.gd`) | **RG Poly** — Kitchen & Restaurant Pack(축음기 Gramophone · 시가 · 커피 머신 · 토스터 · 전자레인지 2색 · 캔 음료 5색 · 접시 · 음식 13 · 접시째 요리 6 · 음식 봉투 · 커피잔 2 · 소스·양념 4 · 피클 병 · 서랍장 4 · 금속 진열대 2 · 조리대) · Cartoon City Massive Pack(A형 카페 간판) — 같은 `에셋.zip`, 디자인 담당이 에셋 구경판(`DARTY_프로젝트/에셋구경`, `고른_모델.txt`)에서 고름 | 예 (**CC0** — 위 행과 같은 근거) | 원본은 저장소 밖(구운 메시만). 팔레트 당김 0~0.15(구경판에서 본 색 유지), 펍 전자레인지만 0.6(펍 벽돌색·크림). 상표·실제 제품 없음(캔은 무지). 시가 연기·불씨는 코드 입자(`art/pub/cigar_smoke.gd`) |
| 펍 만화 그림 7장 — 창 밖 층 4장 + 벽 포스터 3장 (2026-11-08) | `art/pub/pictures/*.svg` | 디자인 담당 요청으로 Claude 가 도형·선(SVG path)으로 직접 그린 오리지널 그림. 참고 이미지·외부 그림 없음 | 아니오 | 글자("180!", "CHEERS!", "LUCKY!")도 글꼴 없이 선으로 그렸다. 실존 브랜드·캐릭터·로고 없음 |
| 라운드하우스 펍 가구 9종 — 묶음 1 v2 (2026-11-08) | `art/environments/roundhouse/pub/<이름>/<이름>.glb` — sofa · armchair · side_table · gramophone · curtain_pair · plant_small · plant_medium · plant_large · coat_rack | 디자인 담당 요청으로 **OpenAI Codex** 가 만든 스크립트가 모양(결정적 코드)과 PBR 텍스처(시드 고정 절차 생성)를 만들었다. Claude 가 생성기(`art/pub/game_room_builder.gd`)에 연결 | 아니오 (묶음 `asset_rights_manifest.csv`: external_assets=none) | 출처 기록 = 묶음 안 `asset_rights_manifest.csv`(Codex 스크립트가 쓴 AI 사용 기록이다. 법적 보증이 아니다). 원본 묶음은 바탕화면 `DARTY_프로젝트/디자인_2026-11-08_v2/`. 파일 SHA-256 은 `2026-11-08_DARTY_모델통합_파일목록.csv` 와 일치 확인 |
| 라운드하우스 오락실 7종 — 묶음 2 (2026-11-08) | `art/environments/roundhouse/arcade/<이름>/<이름>.glb` — arcade_cabinet_a · arcade_cabinet_b · prize_showcase · arcade_bench · plush_dart · plush_dice · plush_card | 위와 같음(Codex 결정적 스크립트 · 절차 UV/PBR). 연결: `game/lounge/arcade/arcade_room.gd` | 아니오 (manifest external_assets=none) | 원본 묶음 `DARTY_프로젝트/디자인_2026-11-08_묶음2/`. 오락기 화면 글자·간판 글자는 게임이 Label3D 로 얹는다(모델 안에 상표 없음) |
| 라운드하우스 손 소품 7종 — 묶음 3 (2026-11-08) | `art/environments/roundhouse/common/props/<이름>/<이름>.glb` + 래퍼 `art/props/<kind>.tscn` — bottle · mug · ball · cue · hoop_ball · plush · capsule | 위와 같음(Codex 결정적 스크립트 · 외부 입력 없는 절차 PBR. plush 는 묶음 2 인형을 다시 씀). 연결: `game/lounge/prop_looks.gd` | 아니오 (manifest external_assets=none) | 원본 묶음 `DARTY_프로젝트/디자인_2026-11-08_묶음3/`. 병 라벨은 게임이 글자(SODA/PUB)를 얹는다 |

### 에셋 묶음(`에셋.zip`, 2026-10-31) 쓰는 규칙

- **RG Poly 팩(CC0)** 만 게임에 넣는다. CC0 라 출처 표기 의무는 없지만 위 표에 남긴다.
- **EmaceArt 팩**(Food & Packaging, Analog Memory)은 라이선스상 원본 재배포 금지 → 공개 저장소에 넣지 않는다.
- 실존 브랜드·영화 포스터·게임기(Atari·C64·SNES·GameBoy 등) 모양 모델은 쓰지 않는다.
- 묶음에 있는 다른 팩을 새로 쓸 때도 이 표에 한 줄 먼저 추가하고 라이선스 파일을 확인한다.

저장소 밖의 `디자인_레퍼런스/`, `캐릭터_예시안_v1·v2/`, 기획 PDF·PNG·HTML은 런타임 리소스가 아니다. 재배포 권리를 확인한 것으로 간주하지 않는다. **ref1·ref2 원본 이미지는 AI에 첨부하지 않는다.**

## Godot 고지

Godot는 MIT 라이선스로 상업 게임에 쓸 수 있지만, 배포물 안에 엔진과 구성요소의 저작권·라이선스 고지가 있어야 한다.
고지 텍스트는 실행 중인 엔진에서 `Engine.get_license_text()`, `Engine.get_copyright_info()`, `Engine.get_license_info()`로 얻는다.
아트 쇼케이스의 CREDITS 버튼이 이 방식으로 보여 준다. **실제 경기(F5) 화면에는 아직 크레딧이 없다 — 출시 전 추가.**

- [Godot 라이선스](https://godotengine.org/license/) · [라이선스 준수 안내](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html)

## 출시 전에 따로 정할 것

- DARTY / The Social Club 이름과 로고의 상표 사용 가능성(검색·등록 안 함).
- 팀원 작업물·AI 생성 서비스·외부 에셋의 상업 이용·재배포 조건.
- 판매 국가·스토어의 연령 등급(음주 묘사 포함)과 정책.
- 계정·서버가 들어간 뒤의 개인정보·보안 요구사항.
