class_name DamageRoll
extends RefCounted

var amount: int = 0
var is_crit: bool = false


func _init(p_amount: int = 0, p_is_crit: bool = false) -> void:
	amount = p_amount
	is_crit = p_is_crit
