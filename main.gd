extends Control


@onready var spine_json: Node = $SpineJson
var json路径 = ""
@onready var 图像路径: LineEdit = $图像路径





func _on_button_2_pressed() -> void:
	var dialog = FileDialog.new()
	add_child(dialog)
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.add_filter("*.json")
	dialog.popup(Rect2i(200, 200, 500, 400))
	dialog.connect("file_selected", on_选择路径_file_selected)
	dialog.set_title("选择Json文件")

func _on_button_pressed() -> void:
	var dialog = FileDialog.new()
	add_child(dialog)
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	#dialog.file_mode = FileDialog.FILE_MODE_OPEN_ANY
	dialog.popup(Rect2i(200, 200, 500, 400))
	dialog.add_filter("*.tscn")
	dialog.connect("file_selected", on_保存文件_file_selected)
	dialog.set_title("保存文件")

func on_选择路径_file_selected(path: String):
	$LineEdit.text = path

func on_保存文件_file_selected(path: String):
	json路径 = $LineEdit.text
	spine_json.res图像路径 = 图像路径.text
	
	spine_json.atlas路径 = %LineEdit_AtlasPath.text
	spine_json.保存文件(json路径,path)


func _on_button_3_pressed() -> void:
	var dialog = FileDialog.new()
	add_child(dialog)
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.popup(Rect2i(200, 200, 500, 400))
	dialog.connect("dir_selected", on_安装脚本_dir_selected)
	dialog.set_title("定位到所需工程目录")

func on_安装脚本_dir_selected(path: String):
	var dir = DirAccess.open(path)
	if not dir.dir_exists("/addons/spine/"):
		dir.make_dir_recursive(path+"/addons/spine/")
	
	# 检查文件是否存在
	if not FileAccess.file_exists(path+"/addons/spine/插槽.gd"):
		var file = FileAccess.open(path+"/addons/spine/插槽.gd", FileAccess.WRITE)
		var default_content = """
@tool
class_name 插槽 extends Node2D

@export var 切换名:String = "":
	set(value):
		切换名 = value
		var c = get_children()
		for i in c:
			i.visible = false
			if i.name == 切换名:
				i.visible = true
		"""
		file.store_string(default_content)
		file.close()


func _on_check_box_toggled(toggled_on: bool) -> void:
	spine_json.带权重网格重设父级 = toggled_on


func _on_check_box_2_toggled(toggled_on: bool) -> void:
	spine_json.使用atlas图集 = toggled_on


func _on_选择atlas_pressed() -> void:
	var dialog = FileDialog.new()
	add_child(dialog)
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.add_filter("*.atlas")
	dialog.popup(Rect2i(200, 200, 500, 400))
	dialog.connect("file_selected", on_选择路径atlas_file_selected)
	dialog.set_title("选择atlas图集文件")

func on_选择路径atlas_file_selected(path: String):
	%LineEdit_AtlasPath.text = path


func _on_批量转换_pressed() -> void:
	spine_json.使用atlas图集 = true
	var path = %"LineEdit_批量路径".text
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var n = 0
		while file_name != "":
			if dir.current_is_dir():
				print("发现目录：" + file_name)
				json路径 = path + file_name + "/" + file_name + ".json"
				spine_json.res图像路径 = "res://" + file_name + "/"
				spine_json.atlas路径 = path + file_name + "/" + file_name + ".atlas"
				var 导出路径 = path + file_name + "/" + file_name + ".tscn"
				spine_json.保存文件(json路径,导出路径)
				print("已完成："+str(n))
				n += 1
			else:
				print("发现文件" + file_name)
			file_name = dir.get_next()
	else:
		print("尝试访问路径时出错。")

	
	#json路径 = $LineEdit.text
	#spine_json.res图像路径 = 图像路径.text
	
	#spine_json.atlas路径 = %LineEdit_AtlasPath.text
	#spine_json.保存文件(json路径,path)
