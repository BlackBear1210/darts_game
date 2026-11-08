extends Node3D
## 테이블에 앉은 손님(NPC) 앞에 접시·음식·음료를 매판 랜덤으로 차린다(2026-11-08 사용자 요청
## "음식들은 랜덤으로 AI 캐릭터들 앞에 접시랑 음식을 놔 줘").
## 자식 Marker3D("FoodSpot_*") 자리마다: 접시째 요리(dish_*) 또는 접시 + 음식 하나, 그 옆에 음료(맥주잔·캔·커피) 하나.
## 몇 자리에는 소금·후추·케첩 같은 양념을 곁들인다. 방이 만들어질 때(_ready) 한 번 차린다 — 실행할 때마다 다르다.
## 정적 묶기(art/static_batch.gd)에서 빠진다(이름 "TableFood"). 만드는 곳: art/pub/game_room_builder.gd(_table_food).
## 차림은 표시 아래 안쪽(internal) 자식 "Dinner" 에 만든다 — 방 생성기가 장면을 저장할 때 같이 저장되지 않아 매번 새로 차린다.

const PubParts = preload("res://art/pub/pub_parts.gd")

## 접시째 요리(RG Poly Restaurant 팩 Dish_N_Ready). 원본이 0.43~0.72m 라 배율로 접시 지름 0.26~0.3m 에 맞춘다.
const DISHES: Array = [["dish_1", 0.45], ["dish_2", 0.62], ["dish_3", 0.4], ["dish_4", 0.5], ["dish_5", 0.52], ["dish_6", 0.62]]
## 접시(plate) 위에 얹는 음식과 배율.
const PLATE_FOODS: Array = [["pizza_plate", 0.6], ["steak", 1.15], ["pancakes", 0.62], ["hotdog", 0.72], ["burger_ready", 0.7],
	["roast_chicken", 0.75], ["eggs_ready", 0.62], ["cake_slice", 0.55], ["croissant", 1.0], ["donut", 0.95], ["bread_egg", 1.2]]
## 음료와 배율(맥주잔 · 캔 5종 · 커피).
const DRINKS: Array = [["mug", 0.6], ["mug", 0.6], ["soda_can_a", 1.1], ["soda_can_b", 1.1], ["soda_can_c", 1.1],
	["soda_can_d", 1.1], ["soda_can_e", 1.1], ["coffee_cup_a", 0.62], ["coffee_cup_b", 0.62]]
const CONDIMENTS: Array = [["salt", 0.55], ["pepper", 0.55], ["ketchup", 0.5], ["mustard", 0.5]]
const PLATE_SCALE := 0.62

## 고정 씨앗(시험이 같은 차림을 보게). 0 이면 매번 다르다.
@export var seed_value: int = 0


func _ready() -> void:
	var random := RandomNumberGenerator.new()
	if seed_value != 0:
		random.seed = seed_value
	else:
		random.randomize()
	for spot in get_children():
		if spot is Marker3D:
			_lay(spot as Marker3D, random)


## 한 자리 차리기. 자리(Marker3D)의 -Z = 손님에게서 테이블 가운데 쪽, +X = 손님 오른손 쪽.
func _lay(spot: Marker3D, random: RandomNumberGenerator) -> void:
	var dinner := Node3D.new()
	dinner.name = "Dinner"
	spot.add_child(dinner, false, Node.INTERNAL_MODE_BACK)
	if random.randf() < 0.45:
		var dish: Array = DISHES[random.randi_range(0, DISHES.size() - 1)]
		PubParts.asset(dinner, str(dish[0]), Vector3.ZERO, random.randf_range(-0.4, 0.4), Vector3.ONE * float(dish[1]))
	else:
		PubParts.asset(dinner, "plate", Vector3.ZERO, 0.0, Vector3.ONE * PLATE_SCALE)
		var food: Array = PLATE_FOODS[random.randi_range(0, PLATE_FOODS.size() - 1)]
		PubParts.asset(dinner, str(food[0]), Vector3(0, 0.022, 0), random.randf_range(-PI, PI), Vector3.ONE * float(food[1]))
	var drink: Array = DRINKS[random.randi_range(0, DRINKS.size() - 1)]
	PubParts.asset(dinner, str(drink[0]), Vector3(0.24, 0, -0.08), random.randf_range(-PI, PI), Vector3.ONE * float(drink[1]))
	if random.randf() < 0.4:
		var sauce: Array = CONDIMENTS[random.randi_range(0, CONDIMENTS.size() - 1)]
		PubParts.asset(dinner, str(sauce[0]), Vector3(-0.22, 0, -0.14), 0.0, Vector3.ONE * float(sauce[1]))
