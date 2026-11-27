extends Resource
## [캐릭터 3안 자료] 준·솜·온 조립(art/characters/character_looks.gd)이 읽는 모양 자료 — 생성물이라 손으로 고치지 않는다.
## 파일: art/characters/character_look_data.res (압축 이진, 약 0.3MB).
## 만드는 법: 저장소 밖 darts_game/character_assets/character_looks_20261127/README.md
##   (승인 모델 머리 정점 뽑기 → hair_geo.py 로 머리 모양 → convert_geo.gd 로 이 자료).
## class_name 을 만들지 않는다(열린 편집기가 새 class_name 을 못 읽어 파스 오류가 나는 함정) — preload 로 부른다.

## 승인 모델 Body 의 머리 면 번호와 그 면의 정점 수. 정점 수가 다르면(모델을 다시 만들었으면) 옛 머리 눌러 넣기를 건너뛴다.
@export var head_surface: int = 2
@export var head_vertex_count: int = 0
## 옛 곱슬머리(머리 텍스처에 그려진 머리카락) 정점을 두개골 안으로 눌러 넣은 자리. 번호 = 머리 면 정점 번호.
@export var moved_index: PackedInt32Array = PackedInt32Array()
@export var moved_position: PackedVector3Array = PackedVector3Array()
## 덧붙이는 단단한 조각(한 뼈에 통째로 붙는다). 쉬는 자세 모델 좌표(m), 정면 −Z, 캐릭터 오른쪽 +X.
##   {"id": "jun"|"som"|"on", "kind": "hair"|"extra", "color": 색표 키, "bone": 뼈 이름, "shade": 면마다 밝기 흔들기,
##    "v": PackedVector3Array, "t": PackedInt32Array(세 개씩 = 삼각형, Godot 앞면 순서)}
@export var parts: Array[Dictionary] = []
