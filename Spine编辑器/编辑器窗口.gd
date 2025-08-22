extends Window


func _on_close_requested() -> void:
	queue_free()  # 销毁窗口
