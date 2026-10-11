class_name MatchFlowController
extends RefCounted
## Thin phase API over MatchStateMachine. BoardController owns side effects.

var match_state: MatchStateMachine


func _init(state: MatchStateMachine = null) -> void:
	match_state = state if state != null else MatchStateMachine.new()


func get_phase() -> MatchStateMachine.Phase:
	return match_state.phase


func is_shop() -> bool:
	return match_state.phase == MatchStateMachine.Phase.SHOP


func is_prepare() -> bool:
	return match_state.phase == MatchStateMachine.Phase.PREPARE


func is_combat() -> bool:
	return match_state.phase == MatchStateMachine.Phase.COMBAT


func is_resolve() -> bool:
	return match_state.phase == MatchStateMachine.Phase.RESOLVE


func enter_shop() -> void:
	match_state.phase = MatchStateMachine.Phase.SHOP


func enter_prepare() -> void:
	match_state.phase = MatchStateMachine.Phase.PREPARE


func enter_combat() -> void:
	match_state.phase = MatchStateMachine.Phase.COMBAT


func enter_resolve() -> void:
	match_state.phase = MatchStateMachine.Phase.RESOLVE


func reset() -> void:
	match_state.reset()
