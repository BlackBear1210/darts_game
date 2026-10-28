extends RefCounted
## 규칙 상태 → 화면 글자. 화면 UI(ui/card_round_hud.gd)는 규칙을 모르고, 이 파일이 무엇을 쓸지 정해 넘긴다.
## 왼쪽 점수판(자리별 점수·카드 수·걸린 효과), 오른쪽 효과 목록, 위 차례 표시, 아래 안내 줄, 내가 꺼내 든 카드,
## 머리 위 글자("아야!"·맞힌 벌·Zzz·▼ 내 카드 대상), 결과 화면 글.

const Context = preload("res://game/card_round/flow/round_context.gd")
const SeatMover = preload("res://game/card_round/flow/seat_mover.gd")
const CardActions = preload("res://game/card_round/flow/card_actions.gd")
const TurnEffects = preload("res://game/card_round/flow/turn_effects.gd")
const DartActions = preload("res://game/card_round/flow/dart_actions.gd")
const LocalInput = preload("res://game/card_round/flow/local_input.gd")
const Rules = preload("res://game/card_round/rules/round_rules.gd")
const CardCatalog = preload("res://game/card_round/rules/card_catalog.gd")
const CardFaces = preload("res://game/card_round/cards/card_faces.gd")
const Hud = preload("res://game/card_round/ui/card_round_hud.gd")

## 머리 위 글자 높이(m).
const STATUS_HEIGHT: float = 2.32

var _ctx: Context
var _mover: SeatMover
var _cards: CardActions
var _effects: TurnEffects
var _darts: DartActions
var _input: LocalInput
var _status_labels: Array[Label3D] = []


## 감독이 시작할 때 한 번: 화면에 보여 줄 상태를 가진 부품들을 받는다(읽기만 한다).
func setup(ctx: Context, mover: SeatMover, cards: CardActions, effects: TurnEffects, darts: DartActions, input: LocalInput) -> void:
	_ctx = ctx
	_mover = mover
	_cards = cards
	_effects = effects
	_darts = darts
	_input = input


## 캐릭터 머리 위에 상태 글자(빌보드)를 붙인다. 캐릭터를 만들 때 자리마다 한 번.
func attach_status(view: PlayerView) -> void:
	var status := Label3D.new()
	status.name = "Status"
	status.font = CardFaces.bold_font()
	status.font_size = 64
	status.pixel_size = 0.004
	status.outline_size = 14
	status.outline_modulate = Color("122b27")
	status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status.position = Vector3.UP * STATUS_HEIGHT
	view.add_child(status)
	_status_labels.append(status)


## 점수가 바뀌면 캐릭터 이름표(점수 포함)를 다시 쓴다.
func refresh_labels() -> void:
	for seat in range(Context.SEAT_COUNT):
		_ctx.players[seat].score = _ctx.rules.seats[seat].score
		_ctx.actors[seat].show_state(_ctx.players[seat])


## 매 프레임: 머리 위 상태 글자.
func update_status() -> void:
	var rules: Rules = _ctx.rules
	for seat in range(Context.SEAT_COUNT):
		var lines := PackedStringArray()
		var color := Color("f0e6cf")
		if _mover.ouch(seat):
			lines.append("아야!")
			color = Color("ff8a7a")
		if seat == _effects.penalty_seat:
			lines.append("≋ %s · 목소리 변조 ≋" % _effects.penalty_name(seat))
			color = Color("c9a6ff")
		var mods: Dictionary = rules.dart_modifiers(seat)
		if bool(mods.drowsy) and rules.is_turn_of(seat):
			lines.append("Zzz…")
		var mine: Rules.Card = rules.seats[Context.LOCAL_SEAT].pending
		if mine != null and int(_cards.target_choice.get(Context.LOCAL_SEAT, -1)) == seat and seat != Context.LOCAL_SEAT and not _ctx.autoplay:
			lines.append("▼ 내 카드 대상")
			color = Color("ffe3a3")
		_status_labels[seat].text = "\n".join(lines)
		_status_labels[seat].modulate = color


## 매 프레임: 점수판·효과 목록·차례 표시·내 카드·안내 줄.
func update_hud() -> void:
	var rules: Rules = _ctx.rules
	var hud: Hud = _ctx.hud
	var rows: Array = []
	for seat in rules.order:
		rows.append(_score_row(seat))
	hud.set_scores(rules.win_text(), rows)
	hud.show_effects(rules)
	if _ctx.phase == "darts" and rules.active_seat() >= 0:
		var seat: int = rules.active_seat()
		hud.set_turn("%s 차례 · 남은 다트 %s" % [_ctx.name_of(seat), "●".repeat(rules.darts_left) + "○".repeat(Rules.DARTS_PER_TURN - rules.darts_left)])
	var mine: Rules.Card = rules.seats[Context.LOCAL_SEAT].pending
	if mine != null and not _ctx.autoplay:
		var target: int = int(_cards.target_choice.get(Context.LOCAL_SEAT, -1))
		var target_text: String = "대상: 없음" if target < 0 else ("대상: 나" if target == Context.LOCAL_SEAT else "대상: %s  (Tab 바꾸기)" % _ctx.name_of(target))
		hud.show_card(mine.type, rules.ready_ratio(Context.LOCAL_SEAT, _ctx.now), target_text, rules.use_problem(Context.LOCAL_SEAT, target, _ctx.now), mine.temporary)
	else:
		hud.hide_card()
	hud.set_prompt(prompt_text())


## 화면 아래 안내 줄: 지금 누를 수 있는 키.
func prompt_text() -> String:
	if _ctx.autoplay:
		return "자동 진행(시연·검사용) · C 전체 보기 · Esc 설정"
	if _ctx.phase == "results":
		return "골드는 옷·아바타·닉네임 꾸미기에 쓸 예정(상점 미구현)"
	if _input.my_throw():
		if _ctx.actors[Context.LOCAL_SEAT].seated:
			return "R 로 일어나서 던지는 칸(바닥 금색 칸)으로 걸어가기"
		if not _input.in_throw_box():
			return "던지는 칸(바닥 금색 칸) 안에서만 던질 수 있다"
		return "왼클릭을 길게 눌렀다 떼서 던지기 · 오른클릭 취소 · 남은 %d발" % (_ctx.rules.darts_left if _ctx.phase == "darts" else _darts.punish_left)
	if _ctx.rules.seats[Context.LOCAL_SEAT].pending != null:
		return "F 쓰기 · Q·E 다른 카드로 넘기기 · Tab 대상 바꾸기"
	if not _ctx.cards_open:
		return "카드를 나눠 주는 중… (위·가운데·밑장 중 어디서 빼는지 보기) · C 전체 보기 · Esc 설정"
	if _ctx.phase == "darts":
		return "카드는 카드 턴에만 쓴다 · 옆으로 돌아 방해선 너머(과녁 쪽)에서 몸으로 막기 · Space 점프로 막기 · R 앉기"
	if _ctx.card_turn_seat == Context.LOCAL_SEAT:
		return "내 카드 턴 · Q·E 넘기기(1~9 바로 꺼내기) → F 쓰기 · Enter 패스"
	if _ctx.card_turn_seat >= 0:
		return "%s 카드 턴 · 무효(×0)로 대응할 수 있다 · T 감정표현 · C 전체 보기" % _ctx.name_of(_ctx.card_turn_seat)
	return "Q·E 카드 넘기기(1~9 바로 꺼내기) · 왼클릭 가리키기 · T 감정표현 · Esc 설정"


## 충전 라운드 점수 발표용 순위 줄(꼴찌부터 보여 준다 — HUD 가 순서를 뒤집는다).
func ranking_rows() -> Array:
	var rows: Array = []
	for seat in _ctx.rules.ranking():
		rows.append({"seat": seat, "name": _ctx.rules.seats[seat].name, "score": _ctx.rules.seats[seat].score, "rank": _ctx.rules.rank_of(seat)})
	return rows


## 결과 화면 글(BBCode): 순위·점수·골드(방해 성공 포함)·벌칙 대상·이번 실행 동안 모은 골드.
func results_text(session_gold: Array[int]) -> String:
	var rules: Rules = _ctx.rules
	var lines := PackedStringArray(["[font_size=46][color=#d7bb7f][b]결과[/b][/color][/font_size]", "[font_size=20][color=#9a958a]%s[/color][/font_size]" % rules.win_text()])
	for seat in rules.ranking():
		var owner: Rules.Seat = rules.seats[seat]
		var color: String = PlayerLook.COLORS[seat].lightened(0.3).to_html(false)
		lines.append("[font_size=32]%d위  [color=#%s][b]%s%d번 %s[/b][/color]   %d점   [color=#ffd27a]+%d 골드[/color][/font_size][font_size=20][color=#9a958a]%s[/color][/font_size]" % [
			rules.rank_of(seat) + 1, color, PlayerLook.SYMBOLS[seat], seat + 1, owner.name, owner.score, owner.gold,
			"   (방해 성공 %d회 +%d)" % [owner.disrupts, owner.disrupts * Rules.GOLD_PER_DISRUPT] if owner.disrupts > 0 else ""])
	lines.append("[font_size=22]벌칙: %s → 돌아가는 원판[/font_size]" % _ctx.name_of(rules.loser()))
	var totals := PackedStringArray()
	for seat in range(Context.SEAT_COUNT):
		totals.append("%s %d" % [PlayerLook.SYMBOLS[seat], session_gold[seat]])
	lines.append("[font_size=22][color=#ffd27a]이번 실행 동안 모은 골드: %s[/color][/font_size]" % "   ".join(totals))
	lines.append("[font_size=18][color=#9a958a]골드 쓰임새(예정): 옷 · 아바타 · 닉네임 꾸미기 — 상점은 아직 없다. 골드 수치는 시연값.[/color][/font_size]")
	return "\n".join(lines)


## 점수판 한 줄: 이름·점수·카드 수와 그 사람에게 걸린 것(대기·적용 중 효과, 맞힌 벌, 스턴, 꺼내 든 카드, 방해 횟수).
func _score_row(seat: int) -> Dictionary:
	var rules: Rules = _ctx.rules
	var chips := PackedStringArray()
	for effect: Rules.Effect in rules.effects:
		if effect.target == seat and effect.state in [Rules.EffectState.QUEUED, Rules.EffectState.ACTIVE] and effect.kind != "nullify":
			chips.append("%s%s" % [CardCatalog.card(effect.card_type).name, "(적용 중)" if effect.state == Rules.EffectState.ACTIVE else ""])
	if seat == _effects.penalty_seat:
		chips.append("벌: %s" % _effects.penalty_name(seat))
	if _mover.stunned(seat):
		chips.append("스턴")
	if rules.seats[seat].pending != null:
		chips.append("꺼내 듦: %s" % CardCatalog.card(rules.seats[seat].pending.type).name)
	if rules.seats[seat].disrupts > 0:
		chips.append("방해 %d회" % rules.seats[seat].disrupts)
	return {"seat": seat, "name": rules.seats[seat].name, "score": rules.seats[seat].score, "hand": rules.hand_count(seat),
		"active": rules.active_seat() == seat, "local": seat == Context.LOCAL_SEAT and not _ctx.autoplay, "chips": chips}
