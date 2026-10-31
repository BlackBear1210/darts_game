extends RefCounted
## RG Poly 에셋(CC0, itch.io Creator Bundle Vol.1 — 다른 작업자가 보낸 묶음) 목록과 색 규칙(2026-10-31 밤).
## 원본 .glb 는 저장소에 넣지 않는다(팩 전체 수백 MB). 쓰는 모델만 rg_poly_baker.gd 로 "구워" meshes/*.res 로 넣는다.
##   굽기 = 모델의 텍스처 색을 면마다 한 색(정점 색)으로 바꾸고, 그 색을 펍 팔레트 쪽으로 옮겨 저장하는 것.
##   → 텍스처 파일·임포트가 필요 없고, 우리 도형 소품(MeshKit)과 같은 "각진 단색 면" 느낌이 된다.
## 새 모델을 쓰려면: used() 에 한 줄 추가 → 굽기 명령(rg_poly_baker.gd 머리말) → docs/ASSET_REGISTER.md 확인.

## 굽기 결과가 들어가는 폴더와 모든 메시가 같이 쓰는 재질(정점 색을 그대로 칠한다).
const MESH_DIR := "res://art/vendor/rg_poly/meshes"
const MATERIAL_PATH := "res://art/vendor/rg_poly/rg_poly_vertex_color.tres"

## 원래 색 → 펍 팔레트(기획 2-6: 녹색 #24483E · 원목 #68442F · 놋쇠 #C4A566 · 크림 #C3B496)를 조금 밝힌 값.
## 색상(hue) 띠마다 하나씩. 원래 밝기 차이는 남겨서 면마다 명암이 살아 있게 한다(pub_color 참고).
const PALETTE := {
	"dark": Color("2b2925"),
	"grey": Color("8a8274"),
	"light": Color("d6c9aa"),
	"red": Color("8e4a3e"),
	"orange": Color("7d5034"),
	"yellow": Color("c4a566"),
	"green": Color("4f7a55"),
	"blue": Color("2f5c52"),
	"purple": Color("6b4656"),
}

## 재고 굽기 후보(모델 측정표 render 용). "팩:파일이름" — rest = KitchenRestaurant, med = Medieval.
const CANDIDATES: Array[String] = [
	"rest:Stool_1_A", "rest:Stool_2_A", "rest:Stool_3B_A", "rest:Stool_4_A", "rest:Chair_1_A", "rest:Chair_2_A",
	"rest:Chair_3_A", "rest:Armchair_1_A", "rest:Sofa_1_A", "rest:Sofa_2_A", "rest:Table_1_A", "rest:Table_2_A",
	"rest:Table_3_A", "rest:Table_4_A", "rest:Table_5_A", "rest:Table_6_A", "rest:StandShelf_1_A", "rest:StandShelf_2_A",
	"rest:HangShelf_1_A", "rest:HangShelf_2_A", "rest:HangShelf_3_A", "rest:StationTable_1_A", "rest:CoffeeMachine_1_A",
	"rest:Gramophone", "rest:Lights_1_A", "rest:Lights_2_A", "rest:Vines_1_1", "rest:Vines_3_1", "rest:Till",
	"rest:CoffeCup_A", "rest:CoffyCup_plate_A", "rest:Plate_1_A", "rest:Bowl_1_A", "rest:Fruit_Bowl_A", "rest:Pizza_Ready",
	"rest:Fries", "rest:FriesBox", "rest:HotDog_Full", "rest:ChessBurger_Ready", "rest:Donat", "rest:Cake_1_A",
	"rest:SodaCan_1_A", "rest:Milk_1_A", "rest:Jar_1_A", "rest:HoneyJar", "rest:Ketchup", "rest:Mustard", "rest:Salami",
	"rest:Garlic_Braid", "rest:Cruassant", "rest:Curtains_Long_1_A_A", "rest:Curtains_Short_1_A_A", "rest:Column_S_1",
	"med:Barrel_1_A", "med:Barrel_2_A", "med:Barrel_3_A", "med:BarrelLid_A", "med:Mug_1_A", "med:Cup_1_A", "med:Cup_2_1",
	"med:Potion_1_1", "med:Potion_2_1", "med:Potion_3_1", "med:Potion_4_1", "med:Bag_1_A", "med:GrainBag_1_A", "med:Box_1_A",
	"med:Bench_1_A", "med:Stool_A", "med:Table_1_A", "med:Sign_1", "med:Sign_2_A", "med:Sign_3_A", "med:Torch_001",
	"med:FirePlace_1_A", "med:FirePlace_2_A", "med:Ladder_1_A", "med:PracticeTarget_1_A", "med:PracticeTarget_2_A",
	"med:Shield_1_A", "med:Shield_2_A", "med:Horn_1_A", "med:Bucket_1_A", "med:Wheel_A", "med:Logs_A", "med:CutedWood_1_A",
	"med:Rope_A_1_1", "med:Rope_A_Knot_1", "med:Hook_1_A", "med:Bread_1_A", "med:Cheese_1", "med:Sausage_1_A", "med:Meat_1_A",
	"med:Apple_1_A", "med:Plate_1_A", "med:Pot_1_1_A", "med:Laundry_A", "med:Trough_1_A", "med:Broom_A", "med:Basin_A",
	# 2026-10-31 늦은 밤 네온 오락실(인형뽑기 가게 + 주스 가게)·펍 보강 후보. city = Cartoon City Massive Pack(RG Poly, CC0).
	"city:Lights_1_A", "city:Lights_2_A", "city:Lights_3_A", "city:Lights_4_A", "city:Lights_5_A", "city:Lights_6_A",
	"city:Lights_7_A", "city:SignHolder_1_A", "city:SignHolder_2_A", "city:SignHolder_3_A", "city:SignHolder_4_A",
	"city:SignHolder_5_A", "city:SignHolder_6_A", "city:Sign_1", "city:Placat_1", "city:Bilboard_1_A",
	"city:Awning_1_A", "city:Awning_2_A", "city:Awning_3_A", "city:CafeBoard_A", "city:CafeSign_5_A", "city:CafeSign_6_A",
	"city:SignBoard_1_A", "city:FoodCart_1_A", "city:Kiosk_1_A", "city:Bench_4_A", "city:Parasol_1_A", "city:Cake_1_A",
	"city:Cookie_1_A", "city:FoodProp_1_A", "city:FoodProp_2_A", "city:Food_1_A", "city:Mug_1_A", "city:Mug_2_A",
	"city:Jar_1_A", "city:Jar_2_A", "city:Plate_1_A", "city:Table_1_A", "city:Chair_1_A", "city:Chair_2_A",
	"city:CoffeeMachine_1_A", "city:Basketball", "city:Basketball_Stand_A", "city:BushPot_1_A", "city:PlantPot_1_A",
	"city:PlantPot_3_A", "city:Duck_1", "city:Trashbin_1_A", "city:StreetLamp_3_A", "city:FlowerPot_5_1_A",
	"rest:Banana_1", "rest:Lemon", "rest:Strawberry", "rest:BlueBerrys", "rest:Waffels_Ready", "rest:Pancake_Ready",
	"rest:Cake_3_Ready", "rest:Donat_1", "rest:StandShelf_1_A", "rest:Owen_A", "rest:Sink_A",
]

## 술병 색(병 선반 4색 · 집어 던지는 병 3색). 띠 "purple"(원래 보라 병 몸통)을 이 색으로 바꿔 굽는다.
const SHELF_BOTTLE_COLORS: Array[String] = ["3c695b", "af7948", "516a77", "7b4641"]
const PROP_BOTTLE_COLORS: Array[String] = ["3f9e5a", "8a5a2b", "4fa3c7"]
## 오락실 주스 가게 음료 캔 색(빨강 · 분홍 · 청록 · 노랑).
const SODA_COLORS: Array[String] = ["e8473f", "ff5aa8", "2fc6b6", "ffd34d"]


## 실제로 쓰는 모델. 이름(meshes/<이름>.res) → [원본, 팔레트 당김(0 = 원래 색, 1 = 팔레트 색), 띠별 바꿀 색].
## 측정표(2026-10-31, docs/MAP_PLAN_2026-10-31.md)로 크기를 확인한 뒤 골랐다. 놓는 자리·배율은 art/pub/game_room_builder.gd 가 정한다.
## 자리 색 스툴처럼 색만 다른 것은 같은 원본을 띠 색만 바꿔 여러 번 굽는다(실행 중 재질을 바꾸지 않아도 된다).
static func used() -> Dictionary:
	var list := {
		# 앉는 것: 바 스툴(바 높이 0.81m) · NPC 의자 · 구경 소파 · 안락의자
		"bar_stool": ["rest:Stool_4_A", 0.7, {}],
		"chair": ["rest:Chair_1_A", 0.75, {}],
		"sofa": ["rest:Sofa_2_A", 0.8, {}],
		"armchair": ["rest:Armchair_1_A", 0.8, {}],
		"side_table": ["rest:Table_1_A", 0.7, {}],
		# 바 뒤: 생맥주 통(받침대에 누운 통) · 뒤 조리대 · 커피 머신 · 병조림
		"keg": ["med:Barrel_3_A", 0.6, {}],
		"back_counter": ["rest:StationTable_1_A", 0.75, {}],
		"coffee_machine": ["rest:CoffeeMachine_1_A", 0.8, {}],
		"jar": ["rest:Jar_1_A", 0.7, {}],
		"honey_jar": ["rest:HoneyJar", 0.5, {}],
		# 다트 홀: 럼주통·뚜껑 · 연습 과녁(장식) · 양동이 · 빗자루 · 벽 선반
		"barrel": ["med:Barrel_1_A", 0.6, {}],
		"barrel_small": ["med:Barrel_2_A", 0.6, {}],
		"barrel_lid": ["med:BarrelLid_A", 0.6, {}],
		"practice_target": ["med:PracticeTarget_2_A", 0.55, {}],
		"bucket": ["med:Bucket_1_A", 0.6, {}],
		"broom": ["med:Broom_A", 0.6, {}],
		"hang_shelf": ["rest:HangShelf_2_A", 0.75, {}],
		# 잔·음식(원래 색을 더 남긴다 — 음식이 초록·회색이 되면 맛없어 보인다)
		"mug": ["med:Mug_1_A", 0.5, {}],
		"goblet": ["med:Cup_2_1", 0.5, {}],
		"pizza": ["rest:Pizza_Ready", 0.3, {}],
		"burger": ["rest:ChessBurger_Ready", 0.3, {}],
		"fries": ["rest:Fries", 0.3, {}],
		"bread": ["med:Bread_1_A", 0.3, {}],
		"cheese": ["med:Cheese_1", 0.3, {}],
		"fruit_bowl": ["rest:Fruit_Bowl_A", 0.4, {}],
		# 문 옆 짐: 나무 상자 · 곡물 자루 · 옷걸이 고리
		"crate": ["med:Box_1_A", 0.6, {}],
		"grain_bag": ["med:GrainBag_1_A", 0.6, {}],
		"hook": ["med:Hook_1_A", 0.6, {}],
		# 축음기(안락의자 곁, 건드리면 나팔이 흔들린다) · 천장 전구 줄
		"gramophone": ["rest:Gramophone", 0.6, {}],
		"string_lights": ["rest:Lights_1_A", 0.4, {}],
	}
	# 네온 오락실(2026-10-31 늦은 밤 사용자 요청 "네온 사인과 인형뽑기 가게 느낌 · 바텐더 대신 주스·음료를 파는 느낌"):
	# 주스 가게(차양·다이너 의자·과일·컵·캔·싱크대·금속 선반)와 인형뽑기 코너(오리 인형). 쓰는 곳 = game/lounge/arcade/arcade_room.gd.
	# 오락실은 펍 팔레트가 아니라 밝은 만화 색이 맞다 → 팔레트 당김을 0~0.15 로 낮춰 원래 색을 거의 남긴다.
	# 원본 = city(Cartoon City Massive Pack) · rest(KitchenRestaurant) — 둘 다 RG Poly(CC0). docs/ASSET_REGISTER.md 참고.
	list.merge({
		"juice_awning": ["city:Awning_1_A", 0.05, {}],
		"juice_awning_red": ["city:Awning_3_A", 0.05, {}],
		"diner_stool": ["city:Chair_2_A", 0.05, {}],
		"juice_cup": ["city:Mug_1_A", 0.05, {}],
		"candy_jar": ["city:Jar_1_A", 0.05, {}],
		"plush_duck": ["city:Duck_1", 0.0, {}],
		"plant_pot": ["city:PlantPot_1_A", 0.1, {}],
		"trash_bin": ["city:Trashbin_1_A", 0.15, {}],
		"banana": ["rest:Banana_1", 0.0, {}],
		"lemon": ["rest:Lemon", 0.0, {}],
		"strawberry": ["rest:Strawberry", 0.0, {}],
		"blueberries": ["rest:BlueBerrys", 0.0, {}],
		"milk": ["rest:Milk_1_A", 0.0, {}],
		"prep_sink": ["rest:Sink_A", 0.0, {}],
		"metal_shelf": ["rest:StandShelf_1_A", 0.1, {}],
		"waffle": ["rest:Waffels_Ready", 0.0, {}],
		"juice_bowl": ["rest:Bowl_1_A", 0.1, {}],
	})
	# 음료 캔: 빨간 몸통(띠 "red")을 네온 색으로 바꿔 4색.
	for i in range(SODA_COLORS.size()):
		list["soda_can_%d" % i] = ["rest:SodaCan_1_A", 0.0, {"red": Color(SODA_COLORS[i])}]
	# 카드 테이블 자리 스툴 4개: 방석(원래 청록 = 띠 "blue")을 자리 색으로.
	for seat in range(4):
		list["seat_stool_%d" % seat] = ["rest:Stool_2_A", 0.75, {"blue": Color(PlayerLook.hex(seat))}]
	# 술병: 보라 몸통을 병 색으로. 선반용 2모양 × 4색, 집어 던지는 병 3색.
	for i in range(SHELF_BOTTLE_COLORS.size()):
		list["shelf_bottle_%d" % i] = ["med:Potion_3_1" if i % 2 == 0 else "med:Potion_4_1", 0.6, {"purple": Color(SHELF_BOTTLE_COLORS[i])}]
	for i in range(PROP_BOTTLE_COLORS.size()):
		list["prop_bottle_%d" % i] = ["med:Potion_4_1", 0.6, {"purple": Color(PROP_BOTTLE_COLORS[i])}]
	return list


## 구운 메시. 없으면 null(굽기 전이거나 지운 경우) — 부르는 쪽이 도형 소품으로 대신한다.
static func mesh(name: String) -> Mesh:
	var path := MESH_DIR.path_join(name + ".res")
	return load(path) as Mesh if ResourceLoader.exists(path) else null


## 원래 색이 어느 띠인지. 채도가 낮으면 밝기로 dark/grey/light, 아니면 색상으로 나눈다.
static func band_of(color: Color) -> String:
	if color.s < 0.2 or color.v < 0.12:
		if color.v < 0.35: return "dark"
		return "grey" if color.v < 0.72 else "light"
	var h: float = color.h
	if h < 0.035 or h >= 0.94: return "red"
	if h < 0.10: return "orange"
	if h < 0.18: return "yellow"
	if h < 0.47: return "green"
	if h < 0.75: return "blue"
	return "purple"


## 원래 색을 펍 팔레트 쪽으로 옮긴다. pull = 얼마나 당길지(0~1), overrides = 띠 이름 → 대신 쓸 색.
## 밝기는 원래 밝기(v)에 따라 0.62~1.12배로 남긴다 → 같은 띠 안에서도 밝은 면·어두운 면이 구분된다.
static func pub_color(color: Color, pull: float, overrides: Dictionary = {}) -> Color:
	var band: String = band_of(color)
	var target: Color = overrides.get(band, PALETTE[band])
	var k: float = lerpf(0.62, 1.12, color.v)
	var shaded := Color(minf(target.r * k, 1.0), minf(target.g * k, 1.0), minf(target.b * k, 1.0))
	# overrides 로 지정한 띠는 반드시 그 색이 되게 끝까지 당긴다(예: 자리 색 방석).
	return color.lerp(shaded, 1.0 if overrides.has(band) else pull)
