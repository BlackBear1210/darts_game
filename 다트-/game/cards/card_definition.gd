class_name CardDefinition
extends RefCounted

enum Kind { BONUS, DOUBLE, SHUFFLE }

var uid: int
var kind: Kind


func _init(card_id: int, card_kind: Kind) -> void:
	uid = card_id
	kind = card_kind


func title() -> String:
	match kind:
		Kind.BONUS: return "+10"
		Kind.DOUBLE: return "×2"
		Kind.SHUFFLE: return "점수 섞기"
	return ""


func description() -> String:
	match kind:
		Kind.BONUS: return "자신의 다음 턴: 맞힌 다트마다 +10점"
		Kind.DOUBLE: return "자신의 다음 턴: 맞힌 다트 점수 ×2"
		Kind.SHUFFLE: return "상대의 다음 턴: 숫자 구역 배치 섞기"
	return ""


func to_snapshot() -> Dictionary:
	return {"uid": uid, "kind": kind}


static func from_snapshot(data: Dictionary) -> CardDefinition:
	return CardDefinition.new(data.uid, data.kind)
