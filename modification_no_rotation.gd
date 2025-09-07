# modification_no_rotation.gd
@tool
extends SkeletonModification2D
class_name SkeletonModification2DNoRotation

## 使子骨骼继承父骨骼的位置和缩放，但完全不继承其旋转，
## 而是保持自身初始的世界旋转。
@export var parent_bone: NodePath
@export var child_bone: NodePath

var _parent_bone_node: Bone2D
var _child_bone_node: Bone2D
var skeleton: Skeleton2D
var child_bone_idx: int = -1
var parent_bone_idx: int = -1

# 我们需要缓存的【目标世界旋转】
var target_global_rotation: float = 0.0

func _setup_modification(modification_stack: SkeletonModificationStack2D) -> void:
	skeleton = modification_stack.get_skeleton()
	print("789")
	if not is_instance_valid(skeleton):
		set_is_setup(false)
		return

	_parent_bone_node = skeleton.get_node(parent_bone)
	_child_bone_node = skeleton.get_node(child_bone)

	if not is_instance_valid(_parent_bone_node) or not is_instance_valid(_child_bone_node):
		set_is_setup(false)
		return
	
	child_bone_idx = _child_bone_node.get_index_in_skeleton()
	parent_bone_idx = _parent_bone_node.get_index_in_skeleton()

	if child_bone_idx == -1:
		set_is_setup(false)
		return
		
	# 仅在第一次设置时，捕获子骨骼的初始世界旋转。
	# 这就是我们希望它“始终朝向”的方向。
	target_global_rotation = _child_bone_node.global_transform.get_rotation()

	set_is_setup(true)



func _execute(delta: float) -> void:
	if not get_is_setup() or not is_instance_valid(skeleton) or not is_instance_valid(_parent_bone_node):
		return

	# 1. 获取父骨骼当前的世界变换，以及子骨骼的静止(Rest)局部变换
	var parent_animated_global_transform: Transform2D = _parent_bone_node.get_global_transform()
	var child_animated_local_transform: Transform2D = _child_bone_node.rest

	# 2. 【修正】根据【动画后】的数据，计算期望的世界变换
	# a. 期望的世界位置 = 父世界位置 + 经过父世界(旋转+缩放)变换的【子骨骼动画后的局部位置】
	var target_global_position = parent_animated_global_transform.origin + parent_animated_global_transform.basis_xform(child_animated_local_transform.origin)

	# b. 计算目标【世界缩放】
	# b. 期望的世界缩放 = 父世界缩放 * 【子骨骼动画后的局部缩放】
	var target_global_scale = parent_animated_global_transform.get_scale() * child_animated_local_transform.get_scale()
	
	#target_global_rotation = _child_bone_node.global_transform.get_rotation()
	target_global_rotation = child_animated_local_transform.get_rotation()
	# 3. 将计算出的三个部分组合成一个【目标世界变换】
	var target_child_global_transform := Transform2D(
		0.0,
		target_global_position
	).scaled(target_global_scale)
	
	var _rot = _child_bone_node.global_rotation
	var _rot2 = _child_bone_node.rotation
	#_child_bone_node.global_rotation = _child_bone_node.rotation
	_child_bone_node.global_transform = target_child_global_transform
	#print(_child_bone_node.global_rotation - _rot)
	print(_child_bone_node.global_rotation - _rot)
	_child_bone_node.global_rotation = _rot # 不继承旋转关闭

	# 4. 将计算出的【局部】变换提交给骨架系统
	skeleton.set_bone_local_pose_override(child_bone_idx, _child_bone_node.transform, 1.0, true)
	
