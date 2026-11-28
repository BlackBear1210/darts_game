extends RefCounted
## 토큰 지갑(2026-11-23 사용자 요청). 경기 순위로 토큰을 얻고, 라커룸(꾸미기 방)에서 꾸미기 물건을 산다.
##
## [저장] 이 기계에 남는다(user://player_wallet.cfg). 계정 서버는 아직 이 값을 주고받지 않는다 —
## 토큰은 각자 화면에서 각자 계산한다. 방장이 보낸 순위·벌칙 맞은 횟수가 모두에게 같으므로 결과도 같다.
## [빚] 토큰은 음수가 될 수 있다(사용자 요청 "마이너스통장도 가능"). 다만 **살 때는 잔액이 값보다 많아야 한다**.

const PlayerOutfit = preload("res://art/characters/player_outfit.gd")

## 순위 보상(1위부터). 꼴찌는 이 표를 쓰지 않고 벌칙에서 맞은 횟수로 깎는다.
const REWARD_BY_RANK: Array[int] = [10, 5, 0]
## 꼴찌가 벌칙에서 한 대 맞을 때마다 깎이는 토큰.
const PUNISH_COST: int = 3

## 꾸미기 물건 값. 칸 키 → 번호별 값(art/characters/player_outfit.gd SLOTS 와 같은 순서).
## 번호 0("없음" 또는 기본)은 늘 공짜다. 새 물건은 SLOTS 와 같이 **맨 뒤에** 붙인다.
const PRICES: Dictionary = {
	"hat": [0, 15, 10, 10, 30, 15],
	"eyes": [0, 10, 20, 20],
	"mustache": [0, 10, 10],
	"cigar": [0, 25],
	"watch": [0, 40, 25, 15],
	"shirt": [0, 5, 5, 5, 5, 5, 5, 8, 8, 8],
	"pants": [0, 10, 15],
	# 캐릭터 3안(2026-11-27)·헤어 부품(2026-11-28)은 지금 공짜(모두 0) — 값을 매기려면 0 자리에 값을 넣는다.
	"character": [0, 0, 0, 0],
	"hair": [0, 0, 0, 0, 0, 0, 0, 0],
}

static var tokens: int = 0
## 산 물건("칸키:번호"). 번호 0 은 넣지 않는다.
static var owned: Array[String] = []
static var loaded: bool = false


static func load_saved(current_look: Dictionary = {}) -> void:
	if loaded:
		return
	loaded = true
	var file := ConfigFile.new()
	if file.load("user://player_wallet.cfg") == OK:
		tokens = int(file.get_value("wallet", "tokens", 0))
		var saved: Variant = file.get_value("wallet", "owned", PackedStringArray())
		if saved is PackedStringArray or saved is Array:
			owned.assign(Array(saved))
	# 토큰이 없던 시절에 이미 입고 있던 차림은 산 것으로 친다(저장된 차림을 빼앗지 않는다).
	for key: Variant in current_look:
		_mark_owned(str(key), int(current_look[key]))


static func save() -> void:
	var file := ConfigFile.new()
	file.set_value("wallet", "tokens", tokens)
	file.set_value("wallet", "owned", PackedStringArray(owned))
	file.save("user://player_wallet.cfg")


## 칸의 이 번호가 얼마인가. 값표에 없는 칸·번호는 공짜로 본다(아트 쪽에 물건이 먼저 늘어나도 막히지 않게).
static func price(key: String, index: int) -> int:
	if index <= 0 or not PRICES.has(key):
		return 0
	var list: Array = PRICES[key]
	return int(list[index]) if index < list.size() else 0


## 이 물건을 쓸 수 있는가(공짜이거나 이미 샀다).
static func owns(key: String, index: int) -> bool:
	return price(key, index) <= 0 or _tag(key, index) in owned


## 산다. 토큰이 모자라면 아무것도 바꾸지 않고 false.
static func buy(key: String, index: int) -> bool:
	if owns(key, index):
		return true
	var cost: int = price(key, index)
	if tokens < cost:
		return false
	tokens -= cost
	_mark_owned(key, index)
	save()
	return true


## 경기 한 판의 토큰 변화. rank 는 1부터, is_loser 는 벌칙에 묶인 꼴찌인가,
## punish_hits 는 그 벌칙에서 몸에 맞은 횟수다. 꼴찌는 순위 보상 대신 맞은 만큼만 깎인다(한 대도 안 맞으면 0).
static func match_reward(rank: int, is_loser: bool, punish_hits: int) -> int:
	if is_loser:
		return -PUNISH_COST * maxi(punish_hits, 0)
	return REWARD_BY_RANK[clampi(rank - 1, 0, REWARD_BY_RANK.size() - 1)]


static func grant(amount: int) -> void:
	tokens += amount
	save()


## 지금 차림에서 아직 사지 않은 물건을 "없음"(0)으로 되돌린다. 저장된 차림이 남의 기계에서 공짜로 입히지 않게.
static func clamp_look(look: Dictionary) -> Dictionary:
	var clean: Dictionary = PlayerOutfit.sanitize(look)
	for slot: Array in PlayerOutfit.SLOTS:
		var key: String = slot[0]
		if not owns(key, int(clean[key])):
			clean[key] = 0
	return clean


static func _tag(key: String, index: int) -> String:
	return "%s:%d" % [key, index]


static func _mark_owned(key: String, index: int) -> void:
	if index <= 0 or price(key, index) <= 0:
		return
	var tag: String = _tag(key, index)
	if tag not in owned:
		owned.append(tag)
