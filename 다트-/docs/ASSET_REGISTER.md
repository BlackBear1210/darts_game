# 에셋 출처·고지 기록

게임 프로젝트(`다트-/`) 안에 들어가는 에셋의 출처를 적는다. **새 외부 에셋(모델·텍스처·폰트·음원·플러그인)을 넣을 때는 이 표에 한 줄을 먼저 추가한다.**
비상업용·출처 불명 에셋은 배포물에 넣지 않는다. 이 문서는 법적 무위험 보증서가 아니다.

## 현재 등록부 (2026-10-25, 10-31 갱신)

| 항목 | 경로 | 출처·제작 방법 | 외부 에셋 | 비고 |
|---|---|---|---|---|
| 펍 환경 | `art/pub/pub.tscn`, `art/pub/pub_builder.gd` | 아스트라 AI 도움으로 작성한 GDScript 도형 조합 | 아니오 | 외부 3D 파일·텍스처·로고 없음 |
| 캐릭터 4종 | `art/characters/` | 디자인 문서의 비율로 만든 매개변수 모델 | 아니오 | 참고 이미지 임포트 없음 |
| 다트판(아트) | `art/pub/pub_builder.gd`, `art/board_spec.gd` | 표준 규격 수치 + 팀 `BoardLayout` 비율 | 아니오 | 기존 판 이미지 없음 |
| 쇼케이스 효과음 | `art/showcase/synth_audio.gd` | 사인파·난수 즉석 합성 | 아니오 | 녹음·샘플 없음 |
| 아이콘 | `icon.svg` | 팀 프로젝트 기본 | — | |
| 화면 글꼴 | (엔진 내장 + OS 글꼴 대체) | Godot 기본 글꼴 | 엔진 구성요소 | 한글은 OS 글꼴로 대체 표시됨 — 출시 전 재배포 가능한 한글 글꼴 결정 필요 |
| 캐릭터 V08 원본 | 저장소 `output/character_v08/` | 팀원 블렌더 작업 | 별도 확인 | 게임 리소스 아님(Godot 프로젝트 밖) |
| 엔진 | Godot 4.6.3.stable.official.7d41c59c4 | 공식 배포본 | 예 (MIT + 구성요소) | 아래 고지 참고 |
| 펍 가구 41종 (도면 v3, 2026-10-31) | `art/vendor/rg_poly/meshes/*.res` (굽기: `rg_poly_baker.gd`, 목록: `rg_poly_catalog.gd`) | **RG Poly** — Kitchen & Restaurant Pack · Medieval Megapack (itch.io Creator Bundle Vol.1, 다른 작업자가 전달한 `에셋.zip`) | 예 (**CC0** — 묶음 안내 `plan.txt` 기준. zip 안에는 라이선스 파일이 없어 itch.io 팩 페이지에서 한 번 더 확인할 것) | 원본 `.glb`·텍스처는 저장소에 넣지 않는다. 쓰는 모델만 면마다 한 색(정점 색, 펍 팔레트로 당김)으로 구운 메시만 넣었다. 목록·측정값: `docs/MAP_PLAN_2026-10-31.md` |
| 네온 오락실 소품 21종 + 펍 냉장고 병 (방 넓히기 v4, 2026-10-31 늦은 밤) | `art/vendor/rg_poly/meshes/*.res` (주스 가게·인형뽑기 코너: `game/lounge/arcade/arcade_room.gd`) | **RG Poly** — Cartoon City Massive Pack(차양·다이너 의자·컵·병조림·오리 인형·화분·휴지통) · Kitchen & Restaurant Pack(과일·우유·음료 캔·싱크대·금속 선반·와플·그릇) — 같은 `에셋.zip` | 예 (**CC0** — 위 행과 같은 근거, itch.io 팩 페이지 재확인 필요) | 원본은 저장소 밖. 오락실용은 팔레트 당김 0~0.15(원래 만화 색 유지). 음료 캔 4색은 빨간 몸통만 바꿔 구웠다(`SODA_COLORS`). 상표·실제 제품 모델 없음(캔·우유팩은 무지) |

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
