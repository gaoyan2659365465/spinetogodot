@tool
class_name NoRotation extends Node2D

@export var 旋转:bool = true
@export var 缩放:bool = true


func _process(_delta: float) -> void:
	if not 旋转:
		get_parent().global_rotation = rotation
	if not 缩放:
		get_parent().global_scale = scale
