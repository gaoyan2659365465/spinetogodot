extends Node

"""
更新日志
20250808：发现插槽下网格会有隐藏的情况，经过排查，是slots数据中如果插槽含有attachment键，
则显示，否则默认隐藏。
经过再次检查，原因是attachment键会有重名，导致检测bug，不能仅依靠附件名判断，还需要根据插槽名判断

20250808：网格畸形BUG，经过排查发现是因为计算顶点坐标时候父骨骼会参与计算，当骨骼没有父骨骼时网格恢复正常，
并且该网格受到两根骨骼的影响，初步诊断，插槽在骨骼里就会畸变，插槽直接在root中则正常
再次诊断，原因是没有判断一种情况，即顶点权重来自非父骨骼，而是其他同级骨骼
之前陷入了一个误区，spine中插槽不会受到骨骼的影响，仅当骨骼有权重时才会受到变换的影响
当一个骨骼作为插槽父骨骼但没有权重时，移动父骨骼将不会影响网格

20250808：网格畸形BUG,网格顶点计算要考虑多个骨骼影响。目前只实现了单根骨骼
骨骼变换只需要考虑权重骨即可，不需要考虑权重骨的父骨骼

发现BUG，没有权重的网格，会受到骨骼变换影响
20250809：功能缺失：不支持使用连接网格
20250809：核心问题，带权重的网格需不需要继承父层级变换

20250822：拖拽文件直接修改路径
20250825：继承缩放导致骨骼本身缩放被忽略
不继承旋转分情况，有权重和无权重两种情况

20250905:修改网格畸变BUG，每根骨骼的权重需要单独计算
20250905:发现新BUG，不勾选继承旋转后，矩阵计算方式被改变
20250906：使用矩阵彻底解决网格畸变BUG

20250909：发现BUG，root骨骼缩放导致权重网格错误，不支持root缩放的操作

20250910：不继承骨骼的动画部分由RemoteTransform2D节点替代（缺陷：没有考虑不继承缩放和都不继承的情况）
20250911：彻底修复不继承旋转骨骼问题，增加NoRotation

20250913:发现BUG，IK系统如果多个修改器使用同一目标，不能单独设置混合(建议自建IK节点)
20250913：解决动画曲线问题100%还原（缺陷，网格变形轨道无法贝塞尔）
"""


var node_2d: Node2D
var 图片路径 = ""
var res图像路径 = ""
var ext文本 = {}#用于修复场景文件的图片引用路径

var 带权重网格重设父级 = true
var atlas路径 = ""
var 图集数据 = {}
var 图集Image
var 是否浏览 = false

func _ready() -> void:
	pass


func 保存文件(json路径,导出路径):
	是否浏览 = false
	图片路径 = json路径.get_base_dir() + "/"
	node_2d = Node2D.new()
	node_2d.name = "Node2D"
	

	图集数据 = 加载atlas图集(atlas路径)
	
	var json = load(json路径)
	var g = 生成骨骼(json)
	var c = 生成插槽(json,g[0],g[1])
	创建动画(json,g[0],g[1],c)
	
	var scene = PackedScene.new()
	scene.pack(node_2d)
	ResourceSaver.save(scene,导出路径)
	修复依赖路径(导出路径)


func 预览文件(json路径):
	是否浏览 = true
	图片路径 = json路径.get_base_dir() + "/"
	node_2d = Node2D.new()
	node_2d.name = "Node2D"
	

	图集数据 = 加载atlas图集(atlas路径)
	
	var json = load(json路径)
	var g = 生成骨骼(json)
	var c = 生成插槽(json,g[0],g[1])
	创建动画(json,g[0],g[1],c)
	return node_2d


func 修复依赖路径(file_path):
	var file = FileAccess.open(file_path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	
	# 替换内容
	content = content.replace("metadata/atlas_path = ", "atlas = ExtResource(")# 精灵图
	content = content.replace("metadata/png_path = ", "texture = ExtResource(")# 网格
	content = content.replace(".png_ExtResource\"", ".png\")")
	var n = content.find("[sub_resource")
	var _ext_text = "[ext_resource type=\"Texture2D\" path=\"{0}\" id=\"{1}\"]".format([res图像路径+图集数据["图集图片名"],图集数据["图集图片名"]])
	content = content.insert(n,_ext_text+"\n")
	
	file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(content)
	file.close()
	

func 加载atlas图集(atlas_path):
	var atlas_dict: Dictionary = {}
	
	var 当前图名 = ''
	
	var file = FileAccess.open(atlas_path, FileAccess.READ)
	while file.get_position() < file.get_length():
		var content = file.get_line()
		if content.find(":") == -1:
			if content != "" and content.find(".png") == -1:
				当前图名 = content
				atlas_dict[当前图名] = {}
			if content.find(".png") != -1:# 说明这一行是图集图片名第一行
				atlas_dict["图集图片名"] = content
				if 是否浏览:
					var path = file.get_path().get_base_dir() + '/' + content
					var img_tex = ImageTexture.new()
					img_tex.set_image(Image.load_from_file(path))
					图集Image = img_tex
		else:
			if 当前图名 == "":
				continue
			if content.find("rotate:") != -1:
				atlas_dict[当前图名]['rotate'] = str_to_var(content.get_slice(": ", 1))
			if content.find("xy:") != -1:
				atlas_dict[当前图名]['xy'] = str_to_var("Vector2("+content.get_slice(": ", 1)+")")
			if content.find("size:") != -1:
				atlas_dict[当前图名]['size'] = str_to_var("Vector2("+content.get_slice(": ", 1)+")")
			if content.find("orig:") != -1:
				atlas_dict[当前图名]['orig'] = str_to_var("Vector2("+content.get_slice(": ", 1)+")")
			if content.find("offset:") != -1:
				atlas_dict[当前图名]['offset'] = str_to_var("Vector2("+content.get_slice(": ", 1)+")")
			if content.find("index:") != -1:
				atlas_dict[当前图名]['index'] = str_to_var(content.get_slice(": ", 1))
	file.close()
	return atlas_dict


func sort_ascending(a, b):
	var _a = 0
	var _b = 0
	if a.has("order"):
		_a = a["order"]
	if b.has("order"):
		_b = b["order"]
	if _a < _b:
		return true
	return false

# 输入A和B的弧度值，返回新的B值，确保新B与原始B等效，且与A的差值绝对值 ≤ π
func adjust_angle(A: float, B: float) -> float:
	#var TAU = 2 * PI  # 2π
	# 计算B相对于A的等效角度（调整到A的±π范围内）
	var relative_B = fmod(B - A + PI, TAU) - PI
	# 处理边界情况：当结果为 -π 时，转换为 π
	if is_equal_approx(relative_B, -PI):
		relative_B = PI
	# 返回调整后的B（等效于原始B）
	return A + relative_B


func 生成骨骼(json):
	var k = Skeleton2D.new()
	k.name = "Skeleton2D"
	node_2d.add_child(k)
	k.owner = node_2d
	
	var s:Dictionary = {}
	for i in json.data["bones"]:
		var b = Bone2D.new()
		b.set_autocalculate_length_and_angle(false)
		b.rest = Transform2D(Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(0, 0))
		s[i['name']] = b
		b.name = i['name']
		
		if i.has('color'):
			b.self_modulate = i['color']
		
		if i.has('parent'):
			s[i['parent']].add_child(b)
		else:
			k.add_child(b)#说明是root骨骼
		
		if i.has('length'):
			b.set_length(i['length'])
		
		if i.has("rotation"):
			b.rotation_degrees = i['rotation']*-1# 此处未处理不继承旋转的骨骼
			if i.has('transform'):
				if i['transform'] == "noRotationOrReflection":
					b.global_rotation_degrees = i['rotation']*-1
				if i['transform'] == "onlyTranslation":
					b.global_rotation_degrees = i['rotation']*-1
		
		var pos = Vector2.ZERO
		if i.has("x"):
			pos.x = i['x']
		if i.has("y"):
			pos.y = i['y']*-1
		b.position = pos
		b.rest = Transform2D(b.rotation, Vector2(b.position.x, b.position.y))
		
		var sca = Vector2.ONE
		if i.has("scaleX"):
			sca.x = i['scaleX']
		if i.has("scaleY"):
			sca.y = i['scaleY']
		b.scale = sca
		b.owner = node_2d
		
		if i.has('transform'):
			var no_rotation = NoRotation.new()
			b.add_child(no_rotation)
			no_rotation.rotation = b.global_rotation
			no_rotation.owner = node_2d
			no_rotation.name = 'NoRotation'
			if i['transform'] == "noRotationOrReflection":
				no_rotation.旋转 = false
			if i['transform'] == "onlyTranslation":
				no_rotation.旋转 = false
				no_rotation.缩放 = false
			if i['transform'] == "noScaleOrReflection":
				no_rotation.缩放 = false
		
	
	# 生成IK
	if json.data.has("ik"):
		if json.data["ik"].size() > 0:
			var msk = SkeletonModificationStack2D.new()
			msk.enabled = true
			k.set_modification_stack(msk)
			var ik列表 = json.data["ik"]
			ik列表.sort_custom(sort_ascending)
			for i in ik列表:
				if i.has('bones'):
					var IK骨骼 = i['bones']
					if IK骨骼.size() == 1:
						var lookat = SkeletonModification2DLookAt.new()
						lookat.bone2d_node = k.get_path_to(s[IK骨骼[0]])
						if i.has('target'):
							var IK目标 = i['target']
							lookat.target_nodepath = k.get_path_to(s[IK目标])
						msk.add_modification(lookat)
					elif IK骨骼.size() == 2:
						# 只导入两根骨骼的ik
						var towik = SkeletonModification2DTwoBoneIK.new()
						
						towik.set_joint_one_bone2d_node(k.get_path_to(s[IK骨骼[0]]))
						towik.set_joint_two_bone2d_node(k.get_path_to(s[IK骨骼[1]]))
						#var IK名 = i['name']# 没啥用
						if i.has('target'):
							var IK目标 = i['target']
							towik.target_nodepath = k.get_path_to(s[IK目标])
						if i.has('bendPositive'):
							var IK正反 = i['bendPositive']
							towik.flip_bend_direction = IK正反
						else:
							towik.flip_bend_direction = true
						msk.add_modification(towik)
			
	
	return [s,k]

func parse_weights(data: Array) -> Array:
	var result = []
	var i = 0

	while i < data.size():
		var num_bones = data[i]  # 当前点参与的骨骼数量
		var bones_and_weights = []
		i += 1  # 移动到骨骼号

		# 遍历每个骨骼号和对应的权重
		for _i in range(num_bones):
			var bone_id = data[i]
			var x = data[i + 1]
			var y = data[i + 2]
			var weight = data[i + 3]
			bones_and_weights.append({"bone_id": bone_id,"x": x,"y": y, "weight": weight})
			i += 4  # 每个骨骼号和权重占用4个位置

		# 将解析后的骨骼和权重加入结果
		result.append(bones_and_weights)
	return result

# 假设 Bone_Data 是你在 JSON 中解析出来的骨骼字典
# 它可以包含 'name', 'parent', 'x', 'y', 'rotation', 'scaleX', 'scaleY', 'transform'
func get_local_transform_matrix(bone_data: Dictionary) -> Transform2D:
	var pos = Vector2.ZERO
	if bone_data.has("x"): pos.x = bone_data["x"]
	if bone_data.has("y"): pos.y = bone_data["y"] # <-- 注意：此处不再乘以 -1
	
	var rot_degrees = 0.0
	if bone_data.has("rotation"): rot_degrees = bone_data["rotation"] # 注意这里不需要 *-1，因为是计算世界变换，最终点Y翻转
	
	var scale = Vector2.ONE
	if bone_data.has("scaleX"): scale.x = bone_data["scaleX"]
	if bone_data.has("scaleY"): scale.y = bone_data["scaleY"]
	
	# 使用 Godot 4 的构造函数创建包含旋转和平移的变换
	var matrix = Transform2D(deg_to_rad(rot_degrees), pos)
	# .scaled() 方法会返回一个新的、经过正确缩放的 Transform2D
	matrix = matrix.scaled(scale)
	return matrix


func calculate_bone_world_matrix(bone_name: String, bone_data_map: Dictionary) -> Transform2D:
	var bone_current_data = bone_data_map[bone_name]
	var local_matrix = get_local_transform_matrix(bone_current_data)
	
	if not bone_current_data.has("parent"):
		# 如果是根骨骼，其世界矩阵就是其局部矩阵
		return local_matrix
	
	var parent_name = bone_current_data["parent"]
	var parent_world_matrix = calculate_bone_world_matrix(parent_name, bone_data_map)
	
	if bone_current_data.has("transform"):
		var transform_mode = bone_current_data["transform"]
		
		# 将局部矩阵的平移、旋转、缩放分量分离出来
		var local_pos = local_matrix.origin
		var local_rot_rad = local_matrix.get_rotation() # 获取弧度
		var local_scale = local_matrix.get_scale()
		
		# 将父世界矩阵的平移、旋转、缩放分量分离出来
		var parent_world_pos = parent_world_matrix.origin
		var parent_world_rot_rad = parent_world_matrix.get_rotation()
		var parent_world_scale = parent_world_matrix.get_scale()

		match transform_mode:
			"noRotationOrReflection":
				# 继承父骨骼的平移和缩放
				var new_pos = parent_world_pos + parent_world_matrix.basis_xform(local_pos)
				var new_scale = parent_world_scale * local_scale
				# 旋转只使用自己的局部旋转
				var new_rot_rad = local_rot_rad
				var final_matrix = Transform2D(new_rot_rad, new_pos)
				return final_matrix.scaled(new_scale)
				
			"onlyTranslation":
				# 只继承父骨骼的平移
				var new_pos = parent_world_pos + parent_world_matrix.basis_xform(local_pos)
				# 旋转和缩放都只使用自己的
				var final_matrix = Transform2D(local_rot_rad, new_pos)
				return final_matrix.scaled(local_scale)
				
			"noScaleOrReflection":
				# 继承父骨骼的缩放和平移
				var new_pos = parent_world_pos + parent_world_matrix.basis_xform(local_pos)
				var new_rot_rad = parent_world_rot_rad + local_rot_rad
				# 缩放只使用自己的局部缩放，忽略父级
				var new_scale = local_scale
				var final_matrix = Transform2D(new_rot_rad, new_pos)
				return final_matrix.scaled(new_scale)
				
			_: # 默认情况（无特殊模式，或者其他未处理的模式）
				# 正常继承所有父级变换
				return parent_world_matrix * local_matrix
	else:
		# 如果没有 transform 模式，正常继承所有父级变换
		return parent_world_matrix * local_matrix



func 生成插槽(json,s,k):
	var c:Dictionary = {}
	var z = 0
	for i in json.data["slots"]:
		var _c = 插槽.new()#用于切换子项
		_c.name = i["name"]
		var p = i["bone"]# 父级
		s[p].add_child(_c)
		_c.owner = node_2d
		_c.z_index = z
		_c.z_as_relative = false#由于层级不同，所以采用全局z顺序
		z+=1# 显示顺序，最大4096
		c[i['name']] = _c
		if i.has("color"):
			_c.modulate = Color(i["color"])
	
	# 判断有没有皮肤
	var 皮肤 = [0]
	if json.data["skins"].size() > 1:
		皮肤 = [0,1]
	
	for _p in 皮肤:
		var attachments = json.data["skins"][_p]["attachments"]
		for i in attachments:# 拿到插槽名字
			var _c = c[i]# 获取刚生成的插槽节点
			for i2 in attachments[i]:# 拿到网格或图片名字
				var a = attachments[i][i2]
				var _item# 网格或图片引用
				
				if a.has("type"):# 如果有类型说明是网格
					if a["type"] == "mesh":
						# 加载图片
						var 图片名 = i2
						if a.has('name'):
							图片名 = a['name']
						if a.has("path"):# 有路径说明改名字了
							图片名 = a["path"]
						var _poly = Polygon2D.new()
						_item = _poly
						#var tex = CompressedTexture2D.new()
						#tex.load(图片路径+ 图片名 +".png")
						
						#print(图片路径+ 图片名 +".png")
						# polygon2D无法用AtlasTexture只能直接放置大图
						var _xy = 图集数据[图片名]["xy"]
						var _size = 图集数据[图片名]["size"]
						var _orig = 图集数据[图片名]["orig"]
						var _offset = 图集数据[图片名]["offset"]
						#tex.region = Rect2(_xy[0], _xy[1], _size[0], _size[1])
						#tex.margin = Rect2(_offset[0], _offset[1], _orig[0]-_size[0], _orig[1]-_size[1])
						_poly.texture_offset = Vector2(_xy[0], _xy[1])
						_poly.set_meta("png_path",图集数据['图集图片名'] +"_ExtResource")
						if 是否浏览:
							# 只有预览的时候需要
							_poly.texture = 图集Image
						
						_poly.name = i2
						_c.add_child(_poly)
						_poly.owner = node_2d
						#_poly.z_index = _c.z_index# 控制显示顺序
						
						
						var uvs:PackedVector2Array = []
						var _uvs = a["uvs"]
						var _uvw = a["width"]
						var _uvh = a["height"]
						for _i in range(0, _uvs.size(), 2):
							uvs.append(Vector2(_uvs[_i]*_uvw,_uvs[_i+1]*_uvh))
						_poly.uv = uvs
						
						
						var _ver = a["vertices"]
						
						var points:PackedVector2Array = []
						# 你可能需要一个字典来方便地通过名称查找骨骼数据
						var bone_data_map = {}
						for bone in json.data["bones"]:
							bone_data_map[bone["name"]] = bone
						
						# 如果UV数据比顶点数据多，说明有权重信息
						if _uvs.size() < _ver.size():
							var parent_bone_name = ''
							for slots_i in json.data["slots"]:
								if slots_i['name'] == i:
									parent_bone_name = slots_i['bone']
									break
							# 1. 获取主父骨骼的世界逆矩阵
							var parent_bone_world_matrix = calculate_bone_world_matrix(parent_bone_name, bone_data_map)
							var parent_bone_world_inverse_matrix = parent_bone_world_matrix.affine_inverse()
							
							var _weights = parse_weights(_ver)
							for _i_vertex_weights in _weights: # _i_vertex_weights 是单个顶点的所有骨骼和权重信息
								# 计算单个顶点的所有骨骼权重
								
								var 最终坐标 = Vector2.ZERO # 这是这个网格顶点最终的世界坐标（在绑定姿势下）
								for bone_weight_info in _i_vertex_weights: # 遍历影响当前顶点的每根骨骼
									var bone_id_index = bone_weight_info["bone_id"] # 这是骨骼在 `json.data["bones"]` 数组中的索引
									
									var bone_name = json.data["bones"][bone_id_index]["name"] # 获取骨骼名称
									var bone_world_matrix = calculate_bone_world_matrix(bone_name, bone_data_map) # 调用新的世界矩阵计算函数
									
									var local_offset_to_bone = Vector2(bone_weight_info["x"], bone_weight_info["y"]) # 顶点相对于该骨骼的局部偏移
									
									# 将局部偏移通过骨骼的世界矩阵转换到世界空间
									var transformed_point = bone_world_matrix * local_offset_to_bone # xform 会应用旋转、缩放、平移
									# 应用权重
									最终坐标 += transformed_point * bone_weight_info["weight"]
									
								# 3. 将世界坐标转换为相对于父骨骼的局部坐标
								var 最终局部坐标 = parent_bone_world_inverse_matrix * 最终坐标

								最终局部坐标.y *= -1 # Godot Y轴向下，Spine Y轴向上（对于顶点）
								points.append(最终局部坐标)
						else:
							for _i in range(0, _ver.size(), 2):
								points.append(Vector2(_ver[_i],_ver[_i+1]*-1))# 网格点Y需要*-1

						_poly.polygon = points
						
						_poly.internal_vertex_count = _uvs.size()/2-a["hull"]
						
						var trianles = []
						var _triangles = a["triangles"]
						for _i in range(0, _triangles.size(), 3):
							var _t = []
							_t.push_back(_triangles[_i])
							_t.push_back(_triangles[_i+1])
							_t.push_back(_triangles[_i+2])
							trianles.push_back(_t)
						_poly.polygons = trianles
						
						# 生成权重数据
						# 如果UV数据比顶点数据多，说明有权重信息
						if _uvs.size() < _ver.size():
							if 带权重网格重设父级:
								_c.owner = null
								_c.reparent(node_2d,true)# 带权重的网格需要放置到外面,不需要担心父骨骼变换
								_c.owner = node_2d# 防止警告
								
								_poly.owner = node_2d# 重新赋予
							_poly.skeleton = _poly.get_path_to(k)# 没有权重不需要骨架
						

							var _weights = parse_weights(_ver)
						
							var new_bones = []
							var _sn = 0
							# 遍历所有骨骼
							for _i in s:
								var new_qz:PackedFloat32Array = []
								for _a in range(_poly.polygon.size()):# _a是遍历的当前点号
									var 权重 = 0.0
									# 找到所有当前骨骼当前点的权重
									for ii in _weights[_a]:
										if ii['bone_id'] == _sn:
											权重 = ii['weight']
									new_qz.append(权重)
								# 判断权重是否部为0，删去
								var _isq = false
								for _q in new_qz:
									if _q != 0:
										_isq = true
								if _isq:
									new_bones.append(k.get_path_to(s[_i]))
									new_bones.append(new_qz)
								_sn += 1
							_poly.bones = new_bones
							# 有权重网格才需要这样
							#var _gp = _poly.global_position
							#var _gr = _poly.global_rotation
							#_poly.top_level = true# 网格本身不能受到骨骼影响，只会受到权重影响
							#_poly.global_position = _gp
							#_poly.global_rotation = _gr
						
						# 隐藏插槽只能显示一个东西
						_poly.visible = false
						for _i in json.data["slots"]:
							if i == _i["name"]:
								if _i.has("attachment"):
									if _i["attachment"] == i2:
										_poly.visible = true
						
						
						
				else:# 如果没有类型说明就是图片
					# 加载图片
					var 图片名 = i2
					if a.has('name'):
						图片名 = a['name']
					if a.has("path"):# 有路径说明改名字了
						图片名 = a["path"]
					var _sprite = Sprite2D.new()
					_item = _sprite
					#_sprite.texture = load(图片路径 + 图片名 + ".png")
					
					print(图片路径+ 图片名 +".png")
					var tex = AtlasTexture.new()
					var _xy = 图集数据[图片名]["xy"]
					var _size = 图集数据[图片名]["size"]
					var _orig = 图集数据[图片名]["orig"]
					var _offset = 图集数据[图片名]["offset"]
					tex.region = Rect2(_xy[0], _xy[1], _size[0], _size[1])
					tex.margin = Rect2(_offset[0], _offset[1], _orig[0]-_size[0], _orig[1]-_size[1])
					if 是否浏览:
						# 只有预览的时候需要
						tex.atlas = 图集Image
					_sprite.texture = tex
					tex.set_meta("atlas_path",图集数据['图集图片名'] +"_ExtResource")
					
					_sprite.name = i2
					_c.add_child(_sprite)
					_sprite.owner = node_2d
					
					if a.has("rotation"):
						_sprite.rotation_degrees = a['rotation']*-1
					
					var pos = Vector2.ZERO
					if a.has("x"):
						pos.x = a['x']
					if a.has("y"):
						pos.y = a['y']*-1
					_sprite.position = pos
					
					var sca = Vector2.ONE
					if a.has("scaleX"):
						sca.x = a['scaleX']
					if a.has("scaleY"):
						sca.y = a['scaleY']
					_sprite.scale = sca
					
					# 隐藏插槽只能显示一个东西
					_sprite.visible = false
					
					for _i in json.data["slots"]:
						if i == _i["name"]:
							if _i.has("attachment"):
								if _i["attachment"] == i2:
									_sprite.visible = true
				
				# 给add模式的网格或图片加上材质
				if _item:
					for _i in json.data["slots"]:
						# 找到与图片对应的插槽，查看渲染混合模式是否为add
						if _i.has("blend"):
							var _add = false
							if _i.has("attachment"):
								if _i["attachment"] == i2:
									_add = true
							if _i['name'] == _item.get_parent().name:# 图片的话插槽信息没有，所以只能判断父层级名字
								_add = true
							if _add:
								if _i["blend"] == "additive":
									var mat = CanvasItemMaterial.new()
									mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
									_item.get_parent().material = mat #给插槽材质
									_item.use_parent_material = true #继承插槽的材质
	return c


# 辅助函数：解析Spine曲线数据，返回[c1,c2,c3,c4]数组
func parse_spine_curve(data: Dictionary) -> Array:
	if not data.has("curve"):
		# 默认线性曲线 (linear)
		return [0.0, 0.0, 1.0, 1.0] 
	
	var curve = data["curve"]
	if str(curve) == "stepped":
		# 阶梯曲线 (stepped)
		# 用贝塞尔模拟一个几乎垂直上升然后水平前进的曲线
		return [100.0, 0.0, 1.0, 1.0]
	elif typeof(curve) == TYPE_ARRAY:
		# 已经是 [c1, c2, c3, c4] 格式
		return curve
	else: 
		# 单个数字格式
		var c1 = curve
		var c2 = data.get("c2", 0.0)
		var c3 = data.get("c3", 1.0)
		var c4 = data.get("c4", 1.0)
		return [c1, c2, c3, c4]


func 创建动画(json,s,_k,c):
	var animplay = AnimationPlayer.new()
	animplay.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	node_2d.add_child(animplay)
	animplay.owner = node_2d
	animplay.name = "AnimationPlayer"
	
	var al = AnimationLibrary.new()
	var lg_anim = json.data['animations']
	for i in lg_anim:
		var animation = Animation.new()
		var 动画名 = i
		var 预估时长 = 0
		if lg_anim[i].has("slots"):
			var 插槽动画数据 = lg_anim[i]["slots"]
			for 插槽名 in 插槽动画数据:
				if 插槽动画数据[插槽名].has("color"):
					var 颜色帧 = 插槽动画数据[插槽名]["color"]
					if 颜色帧.is_empty(): continue

					var 原始颜色 = c[插槽名].modulate
					
					# 关键区别 1: 必须为 r, g, b, a 四个通道分别创建轨道
					for rgba in ['r', 'g', 'b', 'a']:
						var 插槽径 =  str(node_2d.get_path_to(c[插槽名])) + ":modulate:" + rgba
						var track_index = animation.add_track(Animation.TYPE_BEZIER)
						animation.track_set_path(track_index, 插槽径)

						# -----------------------------------------------------------------
						# 步骤 1: 将Spine数据解析成一个干净的Keyframe列表
						# -----------------------------------------------------------------
						var clean_keys = []
						for frame_data in 颜色帧:
							var time = frame_data.get("time", 0.0)
							
							# 关键区别 2: 从 "color" hex 字符串中获取值
							var final_color = 原始颜色
							if frame_data.has("color"):
								# Godot 的 Color() 构造函数可以直接解析 "rrggbbaa" 格式的十六进制字符串
								final_color = Color(frame_data["color"])
							
							# 关键区别 3: 根据当前循环的通道 (r, g, b, a) 提取对应的浮点数值
							var value = final_color[rgba]
							
							var curve_params = parse_spine_curve(frame_data)
							
							clean_keys.append({
								"time": time,
								"value": value,
								"curve": curve_params
							})

						# -----------------------------------------------------------------
						# 步骤 2: 计算绝对控制柄并插入到Godot轨道中 (逻辑完全相同)
						# -----------------------------------------------------------------
						for _i in range(clean_keys.size()):
							var current_key = clean_keys[_i]
							var in_handle = Vector2.ZERO
							var out_handle = Vector2.ZERO

							if _i > 0:
								var prev_key = clean_keys[_i-1]
								var delta_time = current_key.time - prev_key.time
								var delta_value = current_key.value - prev_key.value
								
								var prev_curve = prev_key["curve"]
								var c3 = prev_curve[2]
								var c4 = prev_curve[3]
								
								in_handle.x = (c3 - 1.0) * delta_time
								in_handle.y = (c4 - 1.0) * delta_value

							if _i < clean_keys.size() - 1:
								var next_key = clean_keys[_i+1]
								var delta_time = next_key.time - current_key.time
								var delta_value = next_key.value - current_key.value
								
								var current_curve = current_key["curve"]
								var c1 = current_curve[0]
								var c2 = current_curve[1]

								out_handle.x = c1 * delta_time
								out_handle.y = c2 * delta_value
							
							animation.bezier_track_insert_key(
								track_index,
								current_key.time,
								current_key.value,
								in_handle,
								out_handle
							)
							if 预估时长<current_key.time:
								预估时长 = current_key.time
				
				if 插槽动画数据[插槽名].has("attachment"):
					var 切换帧 = 插槽动画数据[插槽名]["attachment"]
					
					var 插槽径 =  str(node_2d.get_path_to(c[插槽名])) + ":切换名"
					var track_index = animation.add_track(Animation.TYPE_VALUE)# 添加轨道
					animation.track_set_path(track_index, 插槽径)
					# 离散更新模式，保证只切换帧一次，而不是很多次
					animation.value_track_set_update_mode(track_index,Animation.UPDATE_DISCRETE)
					animation.track_set_interpolation_type(track_index,Animation.INTERPOLATION_NEAREST)
					animation.track_insert_key(track_index,0.0, c[插槽名].切换名)# 添加第一帧初始化
					
					for _q in 切换帧:
						var 延迟 = 0
						var 切换值 = ""
						if _q.has("time"):
							延迟 = _q["time"]
							if 预估时长<延迟:
								预估时长 = 延迟
						if _q.has("name"):
							切换值 = str(_q["name"])
						animation.track_insert_key(track_index,延迟, 切换值)
		
		# 导入顶点动画轨道
		if lg_anim[i].has("deform"):
			var 顶点动画数据 = lg_anim[i]["deform"]["default"]
			for 插槽名 in 顶点动画数据:
				for 网格名 in 顶点动画数据[插槽名]:
					var 顶点帧 = 顶点动画数据[插槽名][网格名]
					var _poly = c[插槽名].find_child(网格名)
					var 顶点径 =  str(node_2d.get_path_to(_poly)) + ":polygon"
					var track_index = animation.add_track(Animation.TYPE_VALUE)# 添加轨道
					animation.track_set_path(track_index, 顶点径)
					for _vd in 顶点帧:
						var 延迟 = 0
						var _offset = 0
						# 如果源文件中有曲线，会导致这里报错_poly为null
						var _vertices = _poly.polygon
						if _vd.has('time'):
							延迟 = _vd['time']
							if 预估时长<延迟:
								预估时长 = 延迟
						if _vd.has('offset'):
							_offset = _vd['offset']
						if _vd.has('vertices') and _poly.bones.size() == 0:# 说明这个网格无权重
							var _vds = _vd['vertices']# 拷贝顶点数组
							for _o in range(_offset):
								_vds.push_front(0)# 补全数组，spine的顶点数组不全
							if _vds.size()%2 == 1:# 如果是奇数，在末尾补0
								_vds.push_back(0)
							var _vn = 0
							for _i in range(0, _vds.size(), 2):# 把数组变成vector2数组
								_vertices[_vn] += Vector2(_vds[_i],_vds[_i+1]*-1)# 此时是vector相加
								_vn += 1
						if _vd.has('vertices') and _poly.bones.size() > 0:# 说明这个网格有权重
							var _vds = _vd['vertices']# 拷贝顶点数组
							if int(_offset)%2==1:# 如果是奇数前面加0
								_vds.push_front(0)
								_offset-=1# 说明缺少第一个点的x轴
							if _vds.size()%2==1:# 说明最后一个点缺少y轴
								_vds.push_back(0)
							# 获取该顶点受到几根骨骼影响
							# 这里忽略皮肤
							var 权重网格 = json.data['skins'][0]['attachments'][插槽名][网格名]["vertices"]
							var _weights = parse_weights(权重网格)
							"""
							print("---------------------------")
							print("点数："+str(_weights.size()))
							print("动画名:"+str(动画名))
							print("插槽名:"+str(插槽名))
							print("网格名:"+str(网格名))
							print("poly顶点数组数量："+str(_vertices.size()))
							print("顶点动画数组数量："+str(_vds.size()))
							print("权重网格数量:"+str(_weights.size()))
							"""
							var 点数组 = []# 构造空点数组
							var _wn = 0
							for _w in _weights:
								#print("_wn:"+str(_wn*2)+"   _offset:"+str(_offset))
								if _offset <= _wn*2 and (_wn*2-_offset)+1 < _vds.size():
									#print("---------------:"+str(_wn*2-_offset))
									var 最终坐标 = Vector2(_vds[(_wn*2-_offset)], _vds[(_wn*2-_offset)+1])
									最终坐标.y *= -1
									点数组.append(最终坐标)
								else:
									点数组.append(Vector2(0,0))
								_wn += _w.size()
							# 根据offset将动画数据加入到空点数组中
							
							#print(点数组)
							#print("点数组数量："+str(点数组.size()))
							var _vn = 0
							for _i in 点数组:
								_vertices[_vn] += _i# 受到骨骼权重影响
								_vn += 1
						animation.track_insert_key(track_index,延迟, _vertices)
		
		if lg_anim[i].has("bones"):
			var 骨骼动画数据 = lg_anim[i]["bones"]
			for 骨名 in 骨骼动画数据:
				var bone_node = s[骨名]
				# 查找与该骨骼关联的RemoteTransform2D节点
				var remote_node = bone_node.find_child("NoRotation", false) # false表示非递归查找
				# 默认情况下，动画目标是骨骼本身
				var position_target = bone_node
				var scale_target = bone_node
				# 旋转动画始终应用于骨骼本身
				var rotation_target = bone_node
				if remote_node:
					if not remote_node.旋转:
						rotation_target = remote_node
					if not remote_node.缩放:
						scale_target = remote_node
				
				if 骨骼动画数据[骨名].has("translate"):
					var 变换帧 = 骨骼动画数据[骨名]["translate"]
					if 变换帧.is_empty(): continue

					var 原始变换 = position_target.position
					
					# 分别为 x 和 y 轴创建轨道
					for xy in ['x', 'y']:
						var 骨路径 =  str(node_2d.get_path_to(position_target)) + ":position:" + xy
						var track_index = animation.add_track(Animation.TYPE_BEZIER)
						animation.track_set_path(track_index, 骨路径)

						# -----------------------------------------------------------------
						# 步骤 1: 将Spine数据解析成一个干净的Keyframe列表
						# -----------------------------------------------------------------
						var clean_keys = []

						for frame_data in 变换帧:
							var time = frame_data.get("time", 0.0)
							
							var offset = frame_data.get(xy, 0.0)
							if xy == 'y':
								offset *= -1 # Godot的Y轴是向下的

							var value = 原始变换[xy] + offset
							var curve_params = parse_spine_curve(frame_data)
							
							clean_keys.append({
								"time": time,
								"value": value,
								"curve": curve_params # 定义了从此帧到下一帧的曲线
							})

						# -----------------------------------------------------------------
						# 步骤 2: 计算绝对控制柄并插入到Godot轨道中
						# -----------------------------------------------------------------
						for _i in range(clean_keys.size()):
							var current_key = clean_keys[_i]
							var in_handle = Vector2.ZERO
							var out_handle = Vector2.ZERO

							# 计算 In-Handle (由前一帧的出射曲线决定)
							if _i > 0:
								var prev_key = clean_keys[_i-1]
								var delta_time = current_key.time - prev_key.time
								var delta_value = current_key.value - prev_key.value
								
								var prev_curve = prev_key["curve"]
								var c3 = prev_curve[2]
								var c4 = prev_curve[3]
								
								in_handle.x = (c3 - 1.0) * delta_time
								in_handle.y = (c4 - 1.0) * delta_value

							# 计算 Out-Handle (由此帧的出射曲线和下一帧的位置决定)
							if _i < clean_keys.size() - 1:
								var next_key = clean_keys[_i+1]
								var delta_time = next_key.time - current_key.time
								var delta_value = next_key.value - current_key.value
								
								var current_curve = current_key["curve"]
								var c1 = current_curve[0]
								var c2 = current_curve[1]

								out_handle.x = c1 * delta_time
								out_handle.y = c2 * delta_value
							
							# 插入最终计算好的关键帧
							animation.bezier_track_insert_key(
								track_index,
								current_key.time,
								current_key.value,
								in_handle,
								out_handle
							)
							if 预估时长<current_key.time:
								预估时长 = current_key.time
					
				if 骨骼动画数据[骨名].has("rotate"):
					var 旋转帧 = 骨骼动画数据[骨名]["rotate"]
					if 旋转帧.is_empty(): continue

					# 注意: 旋转动画始终应用于骨骼本身
					var 原始旋转值 = rotation_target.rotation_degrees
					
					# 关键区别 1: 轨道路径是 :rotation (使用弧度)，而不是 :rotation_degrees
					var 骨路径 =  str(node_2d.get_path_to(rotation_target)) + ":rotation"
					var track_index = animation.add_track(Animation.TYPE_BEZIER)
					animation.track_set_path(track_index, 骨路径)

					# -----------------------------------------------------------------
					# 步骤 1: 将Spine数据解析成一个干净的Keyframe列表 (单位: 度)
					# -----------------------------------------------------------------
					var clean_keys = []
					for frame_data in 旋转帧:
						var time = frame_data.get("time", 0.0)
						
						# Spine的角度是偏移量, 且方向与Godot相反
						var offset = frame_data.get("angle", 0.0) * -1.0
						var value = 原始旋转值 + offset
						
						var curve_params = parse_spine_curve(frame_data)
						
						clean_keys.append({ "time": time, "value": value, "curve": curve_params })

					# -----------------------------------------------------------------
					# 步骤 2: "解包"角度值以确保总是走最短路径
					# -----------------------------------------------------------------
					var unwrapped_keys = []
					if not clean_keys.is_empty():
						unwrapped_keys.append(clean_keys[0]) # 第一个key保持不变
						
						for _i in range(1, clean_keys.size()):
							var prev_key = unwrapped_keys[_i-1]
							var current_key = clean_keys[_i]
							
							var diff = current_key.value - prev_key.value
							# 将差值标准化到 -180 到 +180 之间
							diff = fposmod(diff + 180.0, 360.0) - 180.0
							
							var unwrapped_value = prev_key.value + diff
							
							unwrapped_keys.append({
								"time": current_key.time,
								"value": unwrapped_value, # 使用解包后的值
								"curve": current_key.curve
							})
					
					# -----------------------------------------------------------------
					# 步骤 3: 计算绝对控制柄并插入到Godot轨道中 (单位: 弧度)
					# -----------------------------------------------------------------
					for _i in range(unwrapped_keys.size()):
						var current_key = unwrapped_keys[_i]
						var in_handle = Vector2.ZERO
						var out_handle = Vector2.ZERO

						# 计算 In-Handle
						if _i > 0:
							var prev_key = unwrapped_keys[_i-1]
							var delta_time = current_key.time - prev_key.time
							# 关键区别 2: delta_value现在是解包后的差值, 并且要转为弧度
							var delta_value = deg_to_rad(current_key.value - prev_key.value)
							
							var prev_curve = prev_key["curve"]
							var c3 = prev_curve[2]
							var c4 = prev_curve[3]
							
							in_handle.x = (c3 - 1.0) * delta_time
							in_handle.y = (c4 - 1.0) * delta_value

						# 计算 Out-Handle
						if _i < unwrapped_keys.size() - 1:
							var next_key = unwrapped_keys[_i+1]
							var delta_time = next_key.time - current_key.time
							var delta_value = deg_to_rad(next_key.value - current_key.value)
							
							var current_curve = current_key["curve"]
							var c1 = current_curve[0]
							var c2 = current_curve[1]

							out_handle.x = c1 * delta_time
							out_handle.y = c2 * delta_value
						
						# 关键区别 3: 插入轨道的值和控制柄的Y值都必须是弧度
						animation.bezier_track_insert_key(
							track_index,
							current_key.time,
							deg_to_rad(current_key.value),
							in_handle,
							out_handle
						)
						if 预估时长<current_key.time:
							预估时长 = current_key.time
				
				if 骨骼动画数据[骨名].has("scale"):
					var 缩放帧 = 骨骼动画数据[骨名]["scale"]
					if 缩放帧.is_empty(): continue

					# 注意: 此处使用了您要求的 scale_target
					var 原始缩放 = scale_target.scale
					
					# 分别为 x 和 y 轴创建轨道
					for xy in ['x', 'y']:
						var 骨路径 =  str(node_2d.get_path_to(scale_target)) + ":scale:" + xy
						var track_index = animation.add_track(Animation.TYPE_BEZIER)
						animation.track_set_path(track_index, 骨路径)

						# -----------------------------------------------------------------
						# 步骤 1: 将Spine数据解析成一个干净的Keyframe列表
						# -----------------------------------------------------------------
						var clean_keys = []

						for frame_data in 缩放帧:
							var time = frame_data.get("time", 0.0)
							
							# 主要区别：
							# 1. scale的值是直接替换，而不是偏移量
							# 2. 如果帧数据中没有该轴的值，则使用原始缩放值
							# 3. Y轴不需要*-1
							var value = frame_data.get(xy, 原始缩放[xy])
							
							var curve_params = parse_spine_curve(frame_data)
							
							clean_keys.append({
								"time": time,
								"value": value,
								"curve": curve_params
							})

						# -----------------------------------------------------------------
						# 步骤 2: 计算绝对控制柄并插入到Godot轨道中
						# -----------------------------------------------------------------
						# 注意: 此处使用了您要求的循环变量 _i
						for _i in range(clean_keys.size()):
							var current_key = clean_keys[_i]
							var in_handle = Vector2.ZERO
							var out_handle = Vector2.ZERO

							# 计算 In-Handle (由前一帧的出射曲线决定)
							if _i > 0:
								var prev_key = clean_keys[_i-1]
								var delta_time = current_key.time - prev_key.time
								var delta_value = current_key.value - prev_key.value
								
								var prev_curve = prev_key["curve"]
								var c3 = prev_curve[2]
								var c4 = prev_curve[3]
								
								in_handle.x = (c3 - 1.0) * delta_time
								in_handle.y = (c4 - 1.0) * delta_value

							# 计算 Out-Handle (由此帧的出射曲线和下一帧的位置决定)
							if _i < clean_keys.size() - 1:
								var next_key = clean_keys[_i+1]
								var delta_time = next_key.time - current_key.time
								var delta_value = next_key.value - current_key.value
								
								var current_curve = current_key["curve"]
								var c1 = current_curve[0]
								var c2 = current_curve[1]

								out_handle.x = c1 * delta_time
								out_handle.y = c2 * delta_value
							
							# 插入最终计算好的关键帧
							animation.bezier_track_insert_key(
								track_index,
								current_key.time,
								current_key.value,
								in_handle,
								out_handle
							)
							if 预估时长<current_key.time:
								预估时长 = current_key.time
		
		animation.set_length(预估时长)
		
		# 检测动画名是否合法，不能包括“[]”
		动画名 = 动画名.replace("[","_")
		动画名 = 动画名.replace("]","_")
		动画名 = 动画名.replace("/","_")
		al.add_animation(动画名,animation)
		
	var anim_library_name = "animations"
	animplay.add_animation_library(anim_library_name,al)
	
	#region 创建默认初始化姿势
	# 创建默认初始化姿势
	var 全局库 = AnimationLibrary.new()
	animplay.add_animation_library("",全局库)
	var global_library = animplay.get_animation_library("")
	var RESET_anim = Animation.new()
	RESET_anim.set_length(0.001)
	global_library.add_animation("RESET", RESET_anim)
	# 初始化所有插槽
	for i in c:
		var 插槽径 =  str(node_2d.get_path_to(c[i])) + ":切换名"
		var track_index = RESET_anim.add_track(Animation.TYPE_VALUE)# 添加轨道
		RESET_anim.track_set_path(track_index, 插槽径)
		# 离散更新模式，保证只切换帧一次，而不是很多次
		RESET_anim.value_track_set_update_mode(track_index,Animation.UPDATE_DISCRETE)
		RESET_anim.track_set_interpolation_type(track_index,Animation.INTERPOLATION_NEAREST)
		var 子项 = c[i].get_children()
		var 切换名 = ""
		for _i in 子项:
			if _i.visible:
				切换名 = _i.name
		RESET_anim.track_insert_key(track_index,0.0, 切换名)
		
		var 颜色通道 = {'r':c[i].modulate.r,'g':c[i].modulate.g,'b':c[i].modulate.b,'a':c[i].modulate.a}
		for rgba in 颜色通道:
			var 插槽颜色径 =  str(node_2d.get_path_to(c[i])) + ":modulate:"+rgba
			var track_index2 = RESET_anim.add_track(Animation.TYPE_BEZIER)# 添加轨道
			RESET_anim.track_set_path(track_index2, 插槽颜色径)
			RESET_anim.bezier_track_insert_key(track_index2,0.0, 颜色通道[rgba])
		
	# 初始化所有骨骼
	for i in s:
		var 位置通道 = {'x':s[i].position.x,'y':s[i].position.y}
		for xy in 位置通道:
			var 骨骼位置径 =  str(node_2d.get_path_to(s[i])) + ":position:"+xy
			var track_index = RESET_anim.add_track(Animation.TYPE_BEZIER)# 添加轨道
			RESET_anim.track_set_path(track_index, 骨骼位置径)
			RESET_anim.bezier_track_insert_key(track_index,0.0, 位置通道[xy])
		
		var 骨骼旋转径 =  str(node_2d.get_path_to(s[i])) + ":rotation"
		var track_index2 = RESET_anim.add_track(Animation.TYPE_BEZIER)# 添加轨道
		RESET_anim.track_set_path(track_index2, 骨骼旋转径)
		RESET_anim.bezier_track_insert_key(track_index2,0.0, s[i].rotation)
		#RESET_anim.value_track_set_update_mode(track_index2,Animation.UPDATE_DISCRETE)
		# 必须要跟上面所有动画的插值类型一样才不会警告
		#RESET_anim.track_set_interpolation_type(track_index2,Animation.INTERPOLATION_LINEAR_ANGLE)
		
		var 缩放通道 = {'x':s[i].scale.x,'y':s[i].scale.y}
		for xy in 缩放通道:
			var 骨骼缩放径 =  str(node_2d.get_path_to(s[i])) + ":scale:"+xy
			var track_index3 = RESET_anim.add_track(Animation.TYPE_BEZIER)# 添加轨道
			RESET_anim.track_set_path(track_index3, 骨骼缩放径)
			RESET_anim.bezier_track_insert_key(track_index3,0.0, 缩放通道[xy])
	
	# 初始化所有NoRotation
	for i in s:
		var remote_node = s[i].find_child("NoRotation", false) # false表示非递归查找
		if remote_node:
			var 旋转径 =  str(node_2d.get_path_to(remote_node)) + ":rotation"
			var track_index2 = RESET_anim.add_track(Animation.TYPE_BEZIER)# 添加轨道
			RESET_anim.track_set_path(track_index2, 旋转径)
			RESET_anim.bezier_track_insert_key(track_index2,0.0, remote_node.rotation)
			#RESET_anim.value_track_set_update_mode(track_index2,Animation.UPDATE_DISCRETE)
			# 必须要跟上面所有动画的插值类型一样才不会警告
			#RESET_anim.track_set_interpolation_type(track_index2,Animation.INTERPOLATION_LINEAR_ANGLE)
			
			var 缩放通道 = {'x':s[i].scale.x,'y':s[i].scale.y}
			for xy in 缩放通道:
				var 缩放径 =  str(node_2d.get_path_to(remote_node)) + ":scale:"+xy
				var track_index3 = RESET_anim.add_track(Animation.TYPE_BEZIER)# 添加轨道
				RESET_anim.track_set_path(track_index3, 缩放径)
				RESET_anim.bezier_track_insert_key(track_index3,0.0, 缩放通道[xy])
	#endregion
		
