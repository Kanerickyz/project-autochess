extends SceneTree

const CombatProfessionRulesTestScript := preload(
	"res://scripts/combat/realtime/combat_profession_rules_test.gd"
)


func _initialize() -> void:
	var ok: bool = CombatProfessionRulesTestScript.run_all()
	quit(0 if ok else 1)
