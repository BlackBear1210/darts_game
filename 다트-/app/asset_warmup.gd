extends RefCounted
## 경기에 들어갈 때 읽는 무거운 장면·모델을 타이틀 화면에 있는 동안 뒤에서(백그라운드 스레드) 미리 읽고, 게임을 끌 때까지 붙잡아 둔다.
## 2026-11-17 밤 사용자 "프로젝트를 실행과 플레이 도중에 나가면 렉이 심하게 걸리네".
##
## 잰 값(창 모드, 이 PC — 스크래치 측정 도구):
##  - 경기 들어가기: 펍 2.2~2.4초 · 네온 오락실(방 설정 기본값) 5.4~5.9초 동안 화면이 멈췄다.
##    대부분 소품 모델(art/props) · 오락기 모델(roundhouse/arcade GLB)을 파일에서 읽는 시간이었다.
##  - 경기에서 나가면 그 모델들이 메모리에서 풀려 → 다시 들어갈 때마다 또 읽었다. 나갈 때 푸는 시간도 0.45초.
##  - app/main.gd 가 game.tscn 을 preload 해서, 첫 화면이 뜨기 전에 1.2초를 더 기다렸다.
##  → 여기서 뒤에서 읽어 붙잡아 두면 들어가기 펍 약 0.9초 · 오락실 약 1.2초, 나가기 0.17초.
##
## 쓰는 곳: app/main.gd — _ready 에서 start(), 매 프레임 poll(), 경기 장면은 scene(GAME_SCENE).
## 소품(prop_looks.gd)·오락기(arcade_room.gd)는 원래대로 load(path) 를 부른다 — 이미 읽어 붙잡아 둔 것을 바로 받는다.
## 새 모델을 경기 중에 load 로 읽게 되면 아래 목록에도 더한다(tests/test_asset_warmup.gd 가 두 파일의 목록과 맞는지 본다).

const GAME_SCENE := "res://game/game.tscn"
## 손에 드는 소품(prop_looks.gd make → "res://art/props/%s.tscn"). 펍·오락실 모두 경기 방에 처음부터 놓인다.
const PROP_DIR := "res://art/props/%s.tscn"
const PROP_KINDS: Array[String] = ["bottle", "mug", "ball", "cue", "hoop_ball", "plush", "capsule"]
## 오락실 디자이너 모델(arcade_room.gd ROUNDHOUSE_ARCADE · CABINET_MODELS · DECO_PLUSHES · 벤치 · 경품 진열장).
const ARCADE_DIR := "res://art/environments/roundhouse/arcade/%s/%s.glb"
const ARCADE_MODELS: Array[String] = ["arcade_cabinet_a", "arcade_cabinet_b", "plush_dart", "plush_dice", "plush_card", "arcade_bench", "prize_showcase"]

## 읽기 끝나 붙잡아 둔 것(경로 → 자원)과 아직 읽는 중인 경로.
static var _held: Dictionary = {}
static var _loading: Array[String] = []


## 미리 읽을 경로 전부.
static func paths() -> Array[String]:
	var result: Array[String] = [GAME_SCENE]
	for kind in PROP_KINDS:
		result.append(PROP_DIR % kind)
	for key in ARCADE_MODELS:
		result.append(ARCADE_DIR % [key, key])
	return result


## 뒤에서 읽기 시작한다. 여러 번 불러도 한 번만 읽는다.
static func start() -> void:
	for path in paths():
		if _held.has(path) or _loading.has(path) or not ResourceLoader.exists(path):
			continue
		# 하위 자원도 여러 스레드로 나눠 읽는다(펍 기준 한 스레드 2.5초 → 1.1초).
		if ResourceLoader.load_threaded_request(path, "", true) == OK:
			_loading.append(path)


## 다 읽은 것을 붙잡는다. 아직 읽는 것이 남았으면 true(매 프레임 부른다 — 다 끝나면 그만 불러도 된다).
static func poll() -> bool:
	for path in _loading.duplicate():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		_loading.erase(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_held[path] = ResourceLoader.load_threaded_get(path)
	return not _loading.is_empty()


## path 의 장면. 붙잡아 둔 게 있으면 바로, 읽는 중이면 끝날 때까지 기다려(이 프레임만 멈춤), 아니면 지금 읽는다.
static func scene(path: String) -> PackedScene:
	if not _held.has(path):
		if _loading.has(path):
			_loading.erase(path)
			_held[path] = ResourceLoader.load_threaded_get(path)
		else:
			_held[path] = load(path)
	return _held[path] as PackedScene


## 다 읽어 붙잡아 둔 경로 수(시험·진단용).
static func held_count() -> int:
	return _held.size()
