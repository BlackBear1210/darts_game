extends Resource
## [캐릭터 자료] 인형 머리(민머리 로우폴리)·헤어 부품·옷 조각 — 캐릭터 조립(art/characters/character_looks.gd)이 읽는 모양 자료.
## 생성물이라 손으로 고치지 않는다. 파일: art/characters/character_look_data.res (압축 이진).
## 만드는 법: 저장소 밖 darts_game/character_assets/character_looks_20261127/README.md
##   (승인 모델 머리 정점 뽑기 → hair_geo.py 로 인형·헤어 모양 → convert_geo.gd 로 이 자료).
## class_name 을 만들지 않는다(열린 편집기가 새 class_name 을 못 읽어 파스 오류가 나는 함정) — preload 로 부른다.

## 승인 모델 Body 의 머리 면 번호와 그 면의 정점 수. 정점 수가 다르면(모델을 다시 만들었으면) 인형 머리를 건너뛴다.
@export var head_surface: int = 2
@export var head_vertex_count: int = 0
## 인형 머리(2026-11-28 v3): 캐릭터 키(base·jun·som·on) → 새 각진 로우폴리 머리(민머리 + 눈·코·입·귀·눈썹 조각).
##   {"v": PackedVector3Array 정점(쉬는 자세 m, 면마다 정점 셋 = Godot 앞면 순서), "n": PackedVector3Array 법선,
##    "k": PackedByteArray 색 키(0 피부 · 1 흰자 · 2 눈동자 · 3 입 · 4 눈썹),
##    "seam": PackedInt32Array 목 이음새 정점이면 승인 모델 머리 면의 정점 번호(뼈 가중치·법선을 베낀다), 아니면 −1}
##   v6(2026-11-28 밤, 승인 얼굴 원본 면 + 둥근 인형 두피 — 정점을 나눠 쓴다): 위 키에 더해
##    "i": PackedInt32Array 삼각형 정점 번호(세 개씩, Godot 앞면 순서) · "w": PackedInt32Array 정점마다 뼈 가중치를 베낄 승인 정점 번호.
##    이때 v 는 면마다 셋이 아니라 나눠 쓰는 정점이다.
@export var heads: Dictionary = {}
## 이음새가 아닌 인형 머리 정점이 뼈 가중치를 베끼는 승인 모델 머리 면 정점 번호(정수리 — 머리 뼈 하나에만 붙은 점).
@export var head_rigid_src: int = 0
## 덧붙이는 단단한 조각(한 뼈에 통째로 붙는다). 쉬는 자세 모델 좌표(m), 정면 −Z, 캐릭터 오른쪽 +X.
##   kind "hair"  = 헤어 부품. id = 헤어 키(character_looks.gd HAIRS — wavy·spiky·bob·curls·crew·pony·bun). 닫힌 덩어리.
##   kind "extra" = 캐릭터 조각(소맷단·깃·탭…). id = 캐릭터 키(jun·som·on).
##   {"id": 키, "kind": "hair"|"extra", "color": 색표 키, "bone": 뼈 이름, "shade": 면마다 밝기 흔들기,
##    "v": PackedVector3Array, "t": PackedInt32Array(세 개씩 = 삼각형, Godot 앞면 순서)}
@export var parts: Array[Dictionary] = []
