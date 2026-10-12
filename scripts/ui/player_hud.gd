class_name PlayerHUD
extends Control

@onready var _gold_label: Label = %GoldLabel


func set_gold(amount: int) -> void:
	if _gold_label:
		_gold_label.text = "金 %d" % amount
