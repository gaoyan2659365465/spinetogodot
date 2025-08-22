extends Node2D

"""
编辑器主视口
"""
@onready var canvas_layer: CanvasLayer = $CanvasLayer



func _ready() -> void:
	add_child(Global.根节点)
	
	
	Global.选择管理器 = preload("res://Spine编辑器/选择管理器.gd").new()
	add_child(Global.选择管理器)
	
	Global.主相机 = preload("res://Spine编辑器/主相机.gd").new()
	add_child(Global.主相机)
	var 棋盘格 = preload("res://Spine编辑器/棋盘格.gd").new()
	add_child(棋盘格)
	var 缩放条控件 = preload("res://Spine编辑器/缩放条控件/缩放条控件.gd").new()
	canvas_layer.add_child(缩放条控件)
	缩放条控件.设置缩放.connect(_on_缩放条控件_设置缩放)
	缩放条控件.初始化缩放条(Global.主相机)
	#Global.绘制控件 = preload("res://绘制控件.gd").new()
	#canvas_layer.add_child(Global.绘制控件)
	Global.绘制控件 = $"CanvasLayer/SplitContainer/绘制控件"
	
	var 工具面板控件 = preload("res://Spine编辑器/按钮组面板控件/工具面板控件.gd").new()
	canvas_layer.add_child(工具面板控件)
	var 变换面板控件 = preload("res://Spine编辑器/按钮组面板控件/变换面板控件.gd").new()
	canvas_layer.add_child(变换面板控件)
	var 轴面板控件 = preload("res://Spine编辑器/按钮组面板控件/轴面板控件.gd").new()
	canvas_layer.add_child(轴面板控件)
	
	
	"""
	
	var 按钮组面板控件3 = preload("res://Spine编辑器/按钮组面板控件/按钮组面板控件.gd").new()
	canvas_layer.add_child(按钮组面板控件3)
	按钮组面板控件3.position = Vector2(549,550)
	按钮组面板控件3.size = Vector2(86,85)
	按钮组面板控件3.设置标题字("Compensate")
	按钮组面板控件3.创建按钮("骨骼")
	按钮组面板控件3.创建按钮("图片")
	
	
	var 按钮组面板控件5 = preload("res://Spine编辑器/按钮组面板控件/按钮组面板控件.gd").new()
	canvas_layer.add_child(按钮组面板控件5)
	按钮组面板控件5.position = Vector2(642,550)
	按钮组面板控件5.size = Vector2(137,85)
	按钮组面板控件5.设置标题字("Options")
	"""
	
	await get_tree().create_timer(0.05).timeout
	加载动画()


func _on_缩放条控件_设置缩放(value):
	Global.主相机.设置缩放(value)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_SPACE:
			Global.选择管理器.设置选中列表([])
		if event.keycode == KEY_DELETE:
			if event.pressed:
				Global.绘制控件.绘制删除弹窗()



func _draw() -> void:
	var points = [Vector2(0,-10000), Vector2(0,10000), Vector2(-10000,0), Vector2(10000,0)]
	draw_multiline(points,Color.BLACK)
	

func 加载动画():
	var anim:AnimationPlayer
	var child = Global.根节点.get_children()
	for i in child:
		if i as AnimationPlayer:
			anim = i
			var _list = anim.get_animation_list()
			for anim_name in _list:
				%OptionButton.add_item(anim_name)

func _on_button_pressed() -> void:
	var anim:AnimationPlayer
	var child = Global.根节点.get_children()
	for i in child:
		if i as AnimationPlayer:
			anim = i
	var id = %OptionButton.get_selected_id()
	var text = %OptionButton.get_item_text(id)
	anim.play(text)
