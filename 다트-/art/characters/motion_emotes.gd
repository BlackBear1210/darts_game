extends RefCounted
## 수신한 Tripo 모션의 순서. 원형 메뉴·게임 요청·애니메이션이 같은 표를 쓴다.

const CLIPS: PackedStringArray = ["Tripo_dance_02", "Tripo_dance_03", "Tripo_dance_05",
	"Tripo_cheer", "Tripo_afraid", "Tripo_freaky", "Tripo_walk"]
const NAMES: PackedStringArray = ["댄스 02", "댄스 03", "댄스 05", "환호", "겁먹기", "코믹 동작", "제자리 걷기"]
const STOP: int = 7
const COUNT: int = 8


static func label(index: int) -> String:
	return "중지" if index == STOP else NAMES[index]
