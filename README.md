# DARTY 디자인 자료 (design 브랜치)

이 브랜치에는 게임 코드가 없고 캐릭터 디자인 자료만 있다. 게임은 `dev_1` 브랜치에 있다.
이 브랜치는 `dev_1`과 기록이 이어져 있지 않으므로 `dev_1`에 합치지 않는다.

원래 위치는 모두 저장소 최상위 `output/` 폴더였다. 같은 내용이 있는 중복 압축본(`.zip`)과
Blender 자동 백업(`.blend1`, `.blend2`), 내보내기 임시 폴더는 올리지 않았다.

## 현재_캐릭터/ — 지금 다듬는 캐릭터 (기준 디자인)

| 폴더 | 내용 |
|---|---|
| `character_modular_v01` | 옷 갈아입히기용 기본 몸 + 분리 부품(머리카락·상의·하의·신발). 지금 작업 중 |
| `character_texture_fix_20261115_v04` | 얼굴 텍스처 최종본 v04. 기본 몸의 원본 |
| `character_texture_fix_20261113_v01` | 리깅 모델 색 보정 v01. v04를 다시 만들 때 원본으로 쓴다 |
| `character_design_review_20261113` | 리깅된 Tripo 원본 FBX와 점검 자료 |
| `tripo_single_character_20261113_v01` | 리깅 전 고해상도 Tripo 원본(한 명만 남긴 것) |
| `tripo_midpoint_hd_reference_v01` | 이 디자인의 4방향 기준 그림 |
| `character_midpoint_approved` | 이 디자인 승인 기록 |
| `imagegen` | 이 디자인의 얼굴·전신 시안 그림 |

## 예전_디자인/ — 더 이상 쓰지 않는 자료 (로컬에서는 지움)

| 폴더 | 내용 |
|---|---|
| `character-base-v01` | 2026-11-04 예전 디자인 베이스 (부위 24개, 몸통·다리·맨발 추가본) |
| `character-reference` | 위 예전 디자인의 기준 시트 그림 |
| `blender_midpoint_v01`, `blender_midpoint_v02` | 지금 디자인을 Blender로 직접 만들던 초안 (Tripo 버전으로 대체) |
| `character_texture_fix_20261114_v02`, `..._v03` | 얼굴 텍스처 중간 버전 (v04로 대체) |
| `character_modular_review_20261115` | 맨몸 첫 미리보기 (v01로 대체) |

## 팀원_V08/

`character_v08` — 팀원 Blender 캐릭터 V08. `dev_1`의 `output/character_v08/`에도 같은 파일이 있다.

## 게임에 연결된 캐릭터

지금 게임 캐릭터는 이 브랜치가 아니라 `dev_1`에 있다.
`다트-/art/characters/rigged/tripo_character.glb`, 원본은 저장소 최상위 `character_assets/`.
