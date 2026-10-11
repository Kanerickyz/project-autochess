class_name CombatBusLifecycleTest
extends RefCounted


static func run_all() -> bool:
	return _test_stop_combat_tears_down_bus()


static func _test_stop_combat_tears_down_bus() -> bool:
	var arena := CombatArena.new()
	var bus := CombatEventBus.new()
	bus.name = "CombatEventBus"
	arena.event_bus = bus
	arena.add_child(bus)
	if arena.event_bus == null:
		push_error("CombatBusLifecycleTest: bus missing after attach")
		return false
	arena.stop_combat()
	if arena.event_bus != null:
		push_error("CombatBusLifecycleTest: event_bus should be null after stop_combat")
		return false
	return true
