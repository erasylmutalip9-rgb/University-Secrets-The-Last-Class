extends Node3D
class_name CampusCharacterVisual

# Cohesive human silhouette made with smooth, continuous tapered meshes.
# No disconnected capsule stacks. Can be replaced later by rigged GLB in Blender.
var archetype: String = "alex"
var layer_mask: int = 1
var move_amount: float = 0.0
var sprinting: bool = false
var stressed: bool = false
var listening: bool = false

var _clock: float = 0.0
var _torso: Node3D
var _head_pivot: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _look_data: Dictionary

func _ready() -> void:
	_build()

func _process(delta: float) -> void:
	_clock += delta * (2.4 + move_amount * (8.2 if sprinting else 6.0))
	var stride: float = sin(_clock) * move_amount
	var strength: float = 0.56 if sprinting else 0.40
	_left_leg.rotation.x = lerpf(_left_leg.rotation.x, stride * strength, delta * 9.0)
	_right_leg.rotation.x = lerpf(_right_leg.rotation.x, -stride * strength, delta * 9.0)
	_left_arm.rotation.x = lerpf(_left_arm.rotation.x, -stride * strength * 0.60, delta * 8.0)
	_right_arm.rotation.x = lerpf(_right_arm.rotation.x, stride * strength * 0.60, delta * 8.0)
	_torso.position.y = 0.87 + absf(stride) * 0.025
	_torso.rotation.z = -stride * 0.020
	_head_pivot.rotation.z = sin(_clock * 0.19) * 0.010
	_head_pivot.rotation.x = -0.04 if stressed else (0.03 * sin(_clock * 0.65) if listening else 0.0)
	if listening and move_amount < 0.08:
		_right_arm.rotation.x = 0.08 + sin(_clock * 0.55) * 0.06

func _build() -> void:
	_look_data = _palette(archetype)
	var cloth := _mat(_look_data["coat"],0.92)
	var shirt := _mat(_look_data["shirt"],0.93)
	var pants := _mat(_look_data["pants"],0.96)
	var skin := _mat(_look_data["skin"],0.94)
	var hair := _mat(_look_data["hair"],0.94)
	var metal := _mat(Color("#9a9487"),0.50)
	var shoes := _mat(Color("#303538"),0.95)
	_torso = Node3D.new()
	_torso.name = "Силуэт тела"
	_torso.position.y = 0.87
	add_child(_torso)
	# Continuous torso, clothes and neck fit together without exposing gaps.
	_tapered_body(_torso, "Куртка", [0.00,0.17,0.36,0.57,0.67], [0.30,0.29,0.34,0.31,0.20], [0.21,0.22,0.23,0.22,0.16], cloth)
	_add_sphere(_torso, "Горловина",Vector3(0,0.64,0),Vector3(0.15,0.18,0.13),shirt)
	_add_box(_torso,"Воротник слева",Vector3(-0.12,0.55,-0.17),Vector3(0.12,0.22,0.06),cloth).rotation.z=-0.25
	_add_box(_torso,"Воротник справа",Vector3(0.12,0.55,-0.17),Vector3(0.12,0.22,0.06),cloth).rotation.z=0.25
	_add_box(_torso,"Молния",Vector3(0,0.32,-0.222),Vector3(0.012,0.44,0.014),metal)
	_head_pivot = Node3D.new()
	_head_pivot.name = "Голова"
	_head_pivot.position = Vector3(0,0.69,0)
	_torso.add_child(_head_pivot)
	_add_sphere(_head_pivot,"Лицо",Vector3(0,0.10,-0.015),Vector3(0.24,0.28,0.23),skin)
	_add_sphere(_head_pivot,"Подбородок",Vector3(0,-0.08,-0.028),Vector3(0.19,0.12,0.16),skin)
	_add_sphere(_head_pivot,"Нос",Vector3(0,0.075,-0.204),Vector3(0.044,0.075,0.045),skin)
	for s in [-1.0,1.0]:
		_add_sphere(_head_pivot,"Ухо",Vector3(s*0.235,0.07,0.012),Vector3(0.044,0.079,0.043),skin)
		_add_sphere(_head_pivot,"Белок глаза",Vector3(s*0.088,0.125,-0.191),Vector3(0.049,0.021,0.011),_mat(Color("#e8dfcf")))
		_add_sphere(_head_pivot,"Зрачок",Vector3(s*0.088,0.124,-0.200),Vector3(0.019,0.020,0.008),_mat(_look_data["eyes"]))
		_add_box(_head_pivot,"Бровь",Vector3(s*0.087,0.173,-0.189),Vector3(0.090,0.016,0.016),hair)
	_add_box(_head_pivot,"Рот",Vector3(0,-0.067,-0.172),Vector3(0.080,0.008,0.012),_mat(Color("#7e5b55")))
	_add_sphere(_head_pivot,"Волосы",Vector3(0,0.285,0.016),Vector3(0.251,0.137,0.244),hair)
	_add_sphere(_head_pivot,"Затылок",Vector3(0,0.22,0.122),Vector3(0.239,0.190,0.140),hair)
	for i in range(7):
		var frac: float = float(i)/6.0
		var strand := _add_sphere(_head_pivot,"Прядь %d" % i,Vector3(-0.190+frac*0.38,0.235,-0.178),Vector3(0.058,0.070+0.025*frac,0.065),hair)
		strand.rotation.z = -0.22+frac*0.43
	if archetype == "mira":
		for side in [-1.0,1.0]:
			_add_sphere(_head_pivot,"Длинные волосы",Vector3(side*0.19,-0.07,0.060),Vector3(0.07,0.30,0.12),hair)
	elif archetype == "ruslan":
		_add_box(_head_pivot,"Козырёк",Vector3(0,0.30,-0.16),Vector3(0.26,0.035,0.15),cloth)
	_left_arm = _arm(-1.0,cloth,skin)
	_right_arm = _arm(1.0,cloth,skin)
	_left_leg = _leg(-1.0,pants,shoes)
	_right_leg = _leg(1.0,pants,shoes)
	match archetype:
		"alex":
			_add_sphere(_torso,"Рюкзак",Vector3(0,0.32,0.22),Vector3(0.31,0.42,0.20),_mat(Color("#494f4d")))
			for side in [-1.0,1.0]:
				_add_box(_torso,"Лямка",Vector3(side*0.17,0.42,-0.14),Vector3(0.055,0.45,0.06),_mat(Color("#353b3b")))
		"mira":
			_add_box(_torso,"Пропуск",Vector3(0.18,0.48,-0.220),Vector3(0.12,0.17,0.023),_mat(Color("#d8d8ce")))
			_add_box(_torso,"Фото на пропуске",Vector3(0.18,0.52,-0.236),Vector3(0.065,0.073,0.008),_mat(Color("#6c8280")))
		"ruslan":
			_add_box(_torso,"Бейдж",Vector3(-0.19,0.49,-0.221),Vector3(0.13,0.07,0.020),metal)
			_add_box(_torso,"Рация",Vector3(0.26,0.47,-0.07),Vector3(0.12,0.17,0.09),_mat(Color("#33383a")))
		"daniyar":
			_add_sphere(_torso,"Сумка",Vector3(0.22,0.14,0.14),Vector3(0.22,0.18,0.11),_mat(Color("#423e38")))
			_add_box(_torso,"Ремень сумки",Vector3(-0.03,0.41,-0.215),Vector3(0.055,0.56,0.04),_mat(Color("#4d453f"))).rotation.z=0.39

func _arm(side: float, cloth: Material, skin: Material) -> Node3D:
	var joint := Node3D.new()
	joint.name = "Рука"
	joint.position = Vector3(side*0.31,0.56,0)
	_torso.add_child(joint)
	# One sewn sleeve mesh across shoulder, elbow and wrist.
	var path: Array[Vector3] = [Vector3(0,0,0),Vector3(side*0.025,-0.18,0),Vector3(side*0.030,-0.37,-0.01),Vector3(side*0.028,-0.54,-0.025)]
	_tube(joint,"Рукав",path,[0.140,0.128,0.106,0.073],cloth,12)
	_add_sphere(joint,"Кисть",Vector3(side*0.028,-0.605,-0.035),Vector3(0.074,0.112,0.080),skin)
	return joint

func _leg(side: float, pants: Material, shoes: Material) -> Node3D:
	var joint := Node3D.new()
	joint.name = "Нога"
	joint.position = Vector3(side*0.148,0.86,0)
	add_child(joint)
	var path: Array[Vector3] = [Vector3(0,0,0),Vector3(0,-0.18,0),Vector3(0,-0.42,0.005),Vector3(0,-0.69,0.02)]
	_tube(joint,"Брюки",path,[0.175,0.158,0.123,0.097],pants,14)
	_add_sphere(joint,"Кроссовок",Vector3(0,-0.77,-0.07),Vector3(0.137,0.084,0.235),shoes)
	_add_box(joint,"Подошва",Vector3(0,-0.845,-0.067),Vector3(0.20,0.030,0.29),_mat(Color("#bcbab2")))
	return joint

func _tapered_body(parent: Node3D, name_str: String, heights: Array, widths: Array, depths: Array, material: Material) -> void:
	var points: Array[Vector3] = []
	for h in heights: points.append(Vector3(0,float(h),0))
	_tube_elliptic(parent,name_str,points,widths,depths,material,20)

func _tube(parent: Node3D, name_str: String, points: Array[Vector3], widths: Array, material: Material, sides: int) -> void:
	_tube_elliptic(parent,name_str,points,widths,widths,material,sides)

func _tube_elliptic(parent: Node3D, name_str: String, points: Array[Vector3], widths: Array, depths: Array, material: Material, sides: int) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()-1):
		for j in range(sides):
			var a: float = TAU*float(j)/float(sides)
			var b: float = TAU*float(j+1)/float(sides)
			var low: Vector3=points[i]
			var high: Vector3=points[i+1]
			var p0:=low + Vector3(cos(a)*float(widths[i]),0,sin(a)*float(depths[i]))
			var p1:=low + Vector3(cos(b)*float(widths[i]),0,sin(b)*float(depths[i]))
			var p2:=high + Vector3(cos(a)*float(widths[i+1]),0,sin(a)*float(depths[i+1]))
			var p3:=high + Vector3(cos(b)*float(widths[i+1]),0,sin(b)*float(depths[i+1]))
			for p in [p0,p2,p1,p1,p2,p3]: surface.add_vertex(p)
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name=name_str
	mesh.mesh=surface.commit()
	mesh.material_override=material
	mesh.layers=layer_mask
	parent.add_child(mesh)

func _add_sphere(parent: Node3D, name_str: String, pos: Vector3, size_value: Vector3, material: Material) -> MeshInstance3D:
	var m:=MeshInstance3D.new()
	m.name=name_str
	var shape:=SphereMesh.new()
	shape.radius=1.0
	shape.height=2.0
	shape.radial_segments=20
	shape.rings=12
	m.mesh=shape
	m.position=pos
	m.scale=size_value
	m.material_override=material
	m.layers=layer_mask
	parent.add_child(m)
	return m

func _add_box(parent: Node3D, name_str: String, pos: Vector3, size_value: Vector3, material: Material) -> MeshInstance3D:
	var m:=MeshInstance3D.new()
	m.name=name_str
	var shape:=BoxMesh.new()
	shape.size=size_value
	m.mesh=shape
	m.position=pos
	m.material_override=material
	m.layers=layer_mask
	parent.add_child(m)
	return m

func _mat(color: Color, roughness_value: float=0.8) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new()
	m.albedo_color=color
	m.roughness=roughness_value
	m.cull_mode=BaseMaterial3D.CULL_DISABLED
	return m

func _palette(who: String) -> Dictionary:
	match who:
		"mira":
			return {"coat":Color("#b0b7ae"),"shirt":Color("#5d615b"),"pants":Color("#4d514e"),"skin":Color("#bb9177"),"hair":Color("#332a25"),"eyes":Color("#453d39")}
		"daniyar":
			return {"coat":Color("#545c55"),"shirt":Color("#ae9a87"),"pants":Color("#484b4b"),"skin":Color("#b38669"),"hair":Color("#252322"),"eyes":Color("#3a4039")}
		"ruslan":
			return {"coat":Color("#3f4b51"),"shirt":Color("#bcb7aa"),"pants":Color("#363b40"),"skin":Color("#ad826c"),"hair":Color("#34302d"),"eyes":Color("#43443e")}
		_:
			return {"coat":Color("#606960"),"shirt":Color("#c7c0b0"),"pants":Color("#444e57"),"skin":Color("#bd9077"),"hair":Color("#272827"),"eyes":Color("#42443d")}

func set_coat_color(color: Color) -> void:
	_recolor_cloth(self, color)

func _recolor_cloth(node: Node, color: Color) -> void:
	if node is MeshInstance3D and ("Куртка" in node.name or "Воротник" in node.name or "Рукав" in node.name):
		var material: StandardMaterial3D = node.material_override.duplicate()
		material.albedo_color = color
		node.material_override = material
	for child in node.get_children(): _recolor_cloth(child, color)
