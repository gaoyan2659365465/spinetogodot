# ik_constraint_2d.gd
@tool
class_name IKConstraint2D
extends Node2D

## --- 导出变量 (在检查器中显示) ---

# IK 目标节点
@export var target_node_path: NodePath:
	set(value):
		target_node_path = value
		_update_target()

# 影响的骨骼链长度
@export var chain_length: int = 2:
	set(value):
		chain_length = max(1, value)
		_update_bone_chain()

# IK 求解的迭代次数
@export var iterations: int = 10

# IK 影响强度 (0-1)
@export var influence: float = 1.0:
	set(value):
		influence = clamp(value, 0.0, 1.0)

## --- 私有变量 ---

var target: Node2D
var bones: Array[Bone2D] = []
var bone_lengths: Array[float] = []

# 编辑器中绘制 Gizmo
func _draw_gizmo(gizmo: EditorNode3DGizmo):
	if not is_inside_tree() or not get_parent() or not target:
		return

	var parent_bone = get_parent() as Bone2D
	if not parent_bone:
		return

	# 绘制从末端骨骼到目标的虚线
	var from = parent_bone.get_global_transform().origin
	var to = target.get_global_transform().origin
	
	var lines = PackedVector2Array()
	lines.append(from)
	lines.append(to)
	
	var color = Color(1.0, 0.5, 0.2, 0.5)
	gizmo.draw_dashed_line(lines, color, 5.0, true)


func _enter_tree():
	_update_target()
	_update_bone_chain()

func _process(delta):
	if not is_inside_tree() or not Engine.is_editor_hint():
		solve_ik()

func _physics_process(delta):
	solve_ik()

## --- IK 核心逻辑 ---

func solve_ik():
	if not target or bones.size() != chain_length:
		return

	var target_pos = target.get_global_transform().origin
	var bone_positions = []
	for bone in bones:
		bone_positions.append(bone.get_global_transform().origin)

	var root_pos = bone_positions[chain_length - 1]
	
	# FABRIK 算法
	for i in range(iterations):
		# 向前传递 (end -> root)
		bone_positions[0] = target_pos
		for j in range(1, chain_length):
			var direction = (bone_positions[j] - bone_positions[j-1]).normalized()
			bone_positions[j] = bone_positions[j-1] + direction * bone_lengths[j-1]
			
		# 向后传递 (root -> end)
		bone_positions[chain_length - 1] = root_pos
		for j in range(chain_length - 2, -1, -1):
			var direction = (bone_positions[j] - bone_positions[j+1]).normalized()
			bone_positions[j] = bone_positions[j+1] + direction * bone_lengths[j]
	
	# 应用骨骼旋转
	for i in range(chain_length - 1, -1, -1):
		var bone = bones[i]
		var parent_bone = bone.get_parent() as Bone2D if i < chain_length - 1 else null
		
		var parent_transform = bone.get_parent().get_global_transform() if bone.get_parent() else Transform2D.IDENTITY
		
		var new_transform = parent_transform.affine_inverse() * bone.get_global_transform()
		
		var current_pos = bone_positions[i]
		var next_pos = bone_positions[i-1] if i > 0 else target_pos

		var angle = (next_pos - current_pos).angle()
		
		new_transform.rotated(angle)
		
		var original_rotation = bone.get_transform().get_rotation()
		var new_rotation = new_transform.get_rotation()
		
		bone.set_rotation(lerp_angle(original_rotation, new_rotation, influence))


## --- 辅助函数 ---

func _update_target():
	if is_inside_tree() and get_node_or_null(target_node_path):
		target = get_node(target_node_path)
	else:
		target = null

func _update_bone_chain():
	bones.clear()
	bone_lengths.clear()
	
	var current_bone = get_parent() as Bone2D
	for i in range(chain_length):
		if not current_bone or not current_bone is Bone2D:
			bones.clear()
			bone_lengths.clear()
			return
		
		bones.push_front(current_bone)
		bone_lengths.push_front(current_bone.get_length())
		
		current_bone = current_bone.get_parent() as Bone2D
		
	# 纠正骨骼长度数组
	bone_lengths.pop_front()


func _get_configuration_warnings():
	var warnings = []
	if not get_parent() or not get_parent() is Bone2D:
		warnings.append("IKConstraint2D 必须是 Bone2D 的子节点。")
	if not get_node_or_null(target_node_path):
		warnings.append("请指定一个有效的 IK 目标节点。")
		
	return warnings
