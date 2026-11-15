extends Node3D
class_name NoirCampus

var items: Array[Dictionary] = []
var doors: Dictionary = {}
var lights: Array[OmniLight3D] = []
var lamp_time: float = 0.0
var horror_shadow: Node3D
var made: bool = false
var npc_actors: Dictionary = {}
var _material_cache: Dictionary = {}
var _textured_material_cache: Dictionary = {}

func make_world() -> void:
	if made:
		return
	made = true
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#444845")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#c8c0b2")
	e.ambient_light_energy = 0.42
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color("#343938")
	e.fog_density = 0.0020
	e.glow_enabled = false
	e.glow_intensity = 0.0
	e.ssao_enabled = true
	e.ssao_radius = 0.75
	e.ssao_intensity = 0.85
	env.environment = e
	add_child(env)
	room("ВЕСТИБЮЛЬ", Vector2(0, 0), Vector2(18, 16), {"west": true, "east": true}, Color("#898377"))
	room("БИБЛИОТЕКА", Vector2(-19, 0), Vector2(18, 16), {"east": true}, Color("#807063"))
	room("ЛАБОРАТОРИЯ", Vector2(19, 0), Vector2(18, 16), {"west": true, "north": true}, Color("#888985"))
	room("АРХИВ", Vector2(19, -16), Vector2(18, 16), {"south": true}, Color("#80796e"))
	# short bridges between rooms
	make_box(Vector3(-9.5,-0.12,0), Vector3(1.6,0.25,3.8), "#a59f95", true)
	make_box(Vector3(9.5,-0.12,0), Vector3(1.6,0.25,3.8), "#a59f95", true)
	make_box(Vector3(19,-0.12,-8), Vector3(3.8,0.25,1.1), "#a59f95", true)
	make_door("lab", "Доступ в лабораторию", Vector3(9.55,1.6,0), Vector3(0.38,3.2,2.9))
	make_door("archive", "Засекреченный архив", Vector3(19,1.6,-8), Vector3(2.9,3.2,0.38))
	build_atrium()
	build_library()
	build_lab()
	build_archive()
	build_shadow()
	_create_safety_floor()

# Hidden second physics layer prevents the player dropping into empty space while
# the gameplay failsafe returns them to their last valid location.
func _create_safety_floor() -> void:
	var body := StaticBody3D.new()
	body.name = "Невидимое основание безопасности"
	body.position = Vector3(0,-1.28,0)
	add_child(body)
	var collider := CollisionShape3D.new()
	var block := BoxShape3D.new()
	block.size = Vector3(85,0.25,75)
	collider.shape = block
	body.add_child(collider)

func _mat(color: Color, glowing: bool = false, metal: float = 0.1) -> StandardMaterial3D:
	var cache_key: String = color.to_html() + ":" + str(glowing) + ":" + str(metal)
	if _material_cache.has(cache_key):
		return _material_cache[cache_key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.81
	m.emission_enabled = false
	_material_cache[cache_key] = m
	return m

func make_box(pos: Vector3, size: Vector3, hex_color: String, collide: bool = true, emit: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(Color(hex_color), emit)
	if hex_color == "#898982":
		mesh.material_override = textured_material("plaster_neutral", Color("#e5dfd4"))
	if collide:
		var body := StaticBody3D.new()
		body.position = pos
		add_child(body)
		body.add_child(mesh)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		body.add_child(cs)
	else:
		mesh.position = pos
		add_child(mesh)
	return mesh

func make_cylinder(pos: Vector3, radius: float, height: float, hex_color: String, emit: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	mi.mesh = cyl
	mi.material_override = _mat(Color(hex_color), emit, 0.5)
	mi.position = pos
	add_child(mi)
	return mi

func make_light(pos: Vector3, hex_color: String, energy: float = 1.0, range_value: float = 7.0, flicker: bool = false) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = pos
	lamp.light_color = Color("#e8d6bc")
	lamp.light_energy = clampf(energy * 0.94, 0.45, 1.25)
	lamp.omni_range = range_value
	lamp.shadow_enabled = range_value > 9.0
	lamp.set_meta("base_energy", clampf(energy * 0.94, 0.45, 1.25))
	lamp.set_meta("flicker", flicker)
	add_child(lamp)
	lights.append(lamp)
	make_box(pos + Vector3(0,0.12,0), Vector3(0.85,0.09,0.38), hex_color, false, true)

func room(room_name: String, center: Vector2, dimensions: Vector2, doors_here: Dictionary, floor_color: Color) -> void:
	var x := center.x
	var z := center.y
	var half_x: float = dimensions.x * 0.5
	var half_z: float = dimensions.y * 0.5
	var floor_surface := make_box(Vector3(x,-0.19,z), Vector3(dimensions.x,0.3,dimensions.y), ("#" + floor_color.to_html(false)), true)
	var tile_set := "floor_stone"
	if room_name == "БИБЛИОТЕКА":
		tile_set = "floor_library"
	elif room_name == "ЛАБОРАТОРИЯ":
		tile_set = "floor_lab"
	elif room_name == "АРХИВ":
		tile_set = "floor_archive"
	floor_surface.material_override = textured_material(tile_set,Color.WHITE)
	# Floor texture has its own seams; no floating debug grid over the floor.
	make_box(Vector3(x,4.7,z), Vector3(dimensions.x,0.3,dimensions.y), "#918b80", false)
	for side in ["west", "east"]:
		var sx: float = x + (-half_x if side == "west" else half_x)
		if doors_here.has(side):
			for sz in [-1.0,1.0]:
				var length: float = (dimensions.y-3.4)/2
				make_box(Vector3(sx,2.25,z+sz*(1.7+length/2)), Vector3(0.48,4.5,length), "#898982")
			make_box(Vector3(sx,3.96,z), Vector3(0.48,1.1,3.4), "#898982")
		else:
			make_box(Vector3(sx,2.25,z), Vector3(0.48,4.5,dimensions.y), "#898982")
	for side in ["north", "south"]:
		var sz: float = z + (-half_z if side == "north" else half_z)
		if doors_here.has(side):
			for sx in [-1.0,1.0]:
				var length: float = (dimensions.x-3.4)/2
				make_box(Vector3(x+sx*(1.7+length/2),2.25,sz), Vector3(length,4.5,0.48), "#898982")
			make_box(Vector3(x,3.96,sz), Vector3(3.4,1.1,0.48), "#898982")
		else:
			make_box(Vector3(x,2.25,sz), Vector3(dimensions.x,4.5,0.48), "#898982")
	# wall lower bands / atmospheric trim
	for zz in [z-half_z+0.30, z+half_z-0.30]:
		make_box(Vector3(x,0.28,zz), Vector3(dimensions.x-0.5,0.12,0.08), "#a3937f", false)
	make_label(room_name, Vector3(x,3.48,z-half_z+0.38), Color("#514b43"), 29)

func make_label(text_value: String, pos: Vector3, color: Color, font_value: int = 30) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.font_size = font_value
	label.pixel_size = 0.007
	label.modulate = color
	label.outline_size = 3
	label.position = pos
	add_child(label)
	return label

func make_door(key: String, display: String, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Door_" + key
	body.position = pos
	add_child(body)
	var mesh := MeshInstance3D.new()
	var door_mesh := BoxMesh.new()
	door_mesh.size = size
	mesh.mesh = door_mesh
	mesh.material_override = _mat(Color("#5a6671"), false, 0.55)
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	make_box(pos + Vector3(0,1.5,0), Vector3(size.x + 0.1,0.13,size.z+0.1), "#bcac9a", false, true)
	doors[key] = body
	items.append({"id": key, "kind": "door", "label": display, "pos": pos, "visible": true})

func open_door(key: String) -> void:
	if doors.has(key) and is_instance_valid(doors[key]):
		doors[key].queue_free()
		doors.erase(key)
	for item in items:
		if item["id"] == key:
			item["visible"] = false

# All interactive objects are recognizable physical props rather than floating marker boxes.
# Cabinets are two-stage: open first, then pick up the revealed evidence.
func register_item(id: String, label: String, pos: Vector3, kind: String = "evidence", _color: String = "#f7e3cb") -> void:
	var storage_items := ["message", "old_photo", "mira_backup", "guard_report", "security", "alex_file"]
	var stored := id in storage_items
	var prop := Node3D.new()
	prop.name = "Предмет_" + id
	prop.position = pos
	add_child(prop)
	var visual_door: Node3D = null
	var hidden_clue: Node3D = null
	if stored:
		visual_door = _make_storage(prop, id)
		hidden_clue = _paper_card(prop, Vector3(0,0.02,-0.12), "ДОК. / "+id, true)
		hidden_clue.visible = false
	else:
		_make_evidence_prop(prop, id)
	var record := {"id":id,"label": ("Открыть: " + label if stored else label), "pos":pos,"kind": ("container" if stored else kind),"visible":true,"visual":prop,"persistent_prop":stored}
	if stored:
		record["prop_door"] = visual_door
		record["hidden_clue"] = hidden_clue
	items.append(record)

func _prop_box(parent: Node3D, at: Vector3, dimensions: Vector3, color: String, metal: float = 0.04) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mi.mesh = mesh
	mi.material_override = _mat(Color(color), false, metal)
	mi.position = at
	parent.add_child(mi)
	return mi

func _prop_cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mi.mesh = mesh
	mi.material_override = _mat(Color(color))
	mi.position = at
	parent.add_child(mi)
	return mi

func _prop_tag(parent: Node3D, text_value: String, at: Vector3, font_size: int = 35) -> Label3D:
	var l := Label3D.new()
	l.text = text_value
	l.font_size = font_size
	l.pixel_size = 0.0032
	l.modulate = Color("#332b26")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = at
	parent.add_child(l)
	return l

func _paper_card(parent: Node3D, at: Vector3, heading: String, horizontal: bool = true) -> Node3D:
	var document := Node3D.new()
	document.position = at
	parent.add_child(document)
	_prop_box(document, Vector3.ZERO, Vector3(0.38,0.018,0.27), "#f0e5d2")
	_prop_box(document, Vector3(-0.08,0.014,-0.085), Vector3(0.15,0.004,0.015), "#6d7f7a")
	for i in range(4):
		_prop_box(document, Vector3(0.0,0.014,-0.045 + 0.04*float(i)), Vector3(0.27 - i*0.035,0.004,0.009), "#82796e")
	if not horizontal:
		document.rotation.x = -0.35
	return document

func _make_storage(parent: Node3D, id: String) -> Node3D:
	# Floor-mounted filing drawer. The parent's Y is the interaction height.
	# Build downward from that level to Y=0 to prevent floating props.
	var pos_y: float = parent.position.y
	var cabinet_height: float = maxf(0.74, pos_y)
	_prop_box(parent, Vector3(0,-cabinet_height * 0.5,0), Vector3(0.84,cabinet_height,0.58), "#827b70")
	_prop_box(parent, Vector3(0,0.03,0), Vector3(0.90,0.06,0.63), "#aa9b87")
	_prop_box(parent, Vector3(0,-cabinet_height * 0.50,-0.296), Vector3(0.78,cabinet_height - 0.10,0.018), "#595952")
	var hinge := Node3D.new()
	hinge.name = "Шарнир настоящей дверцы"
	hinge.position = Vector3(-0.375,-cabinet_height * 0.50,-0.315)
	parent.add_child(hinge)
	_prop_box(hinge, Vector3(0.375,0,0), Vector3(0.73,cabinet_height - 0.11,0.05), "#948875")
	_prop_box(hinge, Vector3(0.65,0.0,-0.04), Vector3(0.065,0.13,0.035), "#d2c8b6", 0.7)
	for idx in range(3):
		_prop_box(hinge, Vector3(0.39,-cabinet_height * 0.34 + float(idx) * cabinet_height * 0.30,-0.037), Vector3(0.48,0.018,0.014), "#b3aa9a")
	return hinge

func _make_evidence_prop(parent: Node3D, id: String) -> void:
	match id:
		"note", "diary":
			_paper_card(parent,Vector3(0,0.01,0),"ЗАПИСКА" if id == "note" else "ДНЕВНИК")
		"register":
			_prop_box(parent,Vector3.ZERO,Vector3(0.60,0.075,0.43),"#6b604f")
			_prop_box(parent,Vector3(0,0.047,-0.01),Vector3(0.52,0.026,0.36),"#e5dccc")
		"pass", "audit":
			_prop_box(parent,Vector3(0,0.015,0.10),Vector3(0.62,0.045,0.40),"#54595c")
			_prop_box(parent,Vector3(0,0.28,-0.06),Vector3(0.62,0.52,0.065),"#2d3434")
			_prop_box(parent,Vector3(0,0.28,-0.101),Vector3(0.53,0.42,0.008),"#9bb2ae")
		"usb":
			_prop_box(parent,Vector3(0,0.025,0),Vector3(0.12,0.06,0.31),"#3d4549")
			_prop_box(parent,Vector3(0,0.022,-0.21),Vector3(0.086,0.035,0.115),"#c5c1b7",0.7)
		"trace":
			# Damaged rack bolted to the floor, with bent struts and a broken shelf.
			for side in [-0.34, 0.34]:
				_prop_box(parent, Vector3(side,0.83,0), Vector3(0.055,1.66,0.45), "#707b7a", 0.55)
			_prop_box(parent, Vector3(0,0.46,0), Vector3(0.76,0.05,0.45), "#aaa69a", 0.45)
			_prop_box(parent, Vector3(-0.18,1.24,0), Vector3(0.42,0.035,0.42), "#959d9a", 0.5).rotation.z = 0.34
			_prop_box(parent, Vector3(0.16,1.40,-0.05), Vector3(0.22,0.065,0.30), "#b8afa4", 0.5).rotation.z = -0.52
			_prop_box(parent, Vector3(0.12,0.98,0.04), Vector3(0.11,0.055,0.18), "#3f4241")
		"circuit":
			_prop_box(parent,Vector3(0,0,0),Vector3(0.65,0.9,0.15),"#989a8e")
			for i in range(3):
				_prop_box(parent,Vector3(-0.19+i*0.19,0.08,-0.094),Vector3(0.10,0.29,0.07),"#464f4e")
		"scanner":
			_prop_box(parent,Vector3(0,0,0),Vector3(0.85,0.12,0.60),"#555d5c")
			_prop_box(parent,Vector3(0,0.16,-0.08),Vector3(0.63,0.23,0.46),"#d0d6c8")
			_prop_box(parent,Vector3(0,0.29,-0.08),Vector3(0.57,0.012,0.40),"#748d91")
		"timeline", "final":
			# A self-standing investigator's board, not a rectangle hovering at floor level.
			for side in [-0.53, 0.53]:
				_prop_box(parent, Vector3(side,0.85,0.06), Vector3(0.065,1.70,0.095), "#6b6255", 0.15)
				_prop_box(parent, Vector3(side,0.06,0.17), Vector3(0.35,0.11,0.38), "#655b4d")
			_prop_box(parent, Vector3(0,1.31,0.0), Vector3(1.2,1.02,0.10), "#756a58")
			_prop_box(parent, Vector3(0,1.31,-0.067), Vector3(1.10,0.90,0.014), "#d5c9b1")
			for i in range(3):
				_prop_box(parent, Vector3(-0.32+i*0.32,1.33,-0.09), Vector3(0.26,0.46,0.012), "#eee3cf")
		"notice":
			_prop_box(parent,Vector3(0,0,0),Vector3(0.68,0.83,0.035),"#e2d4bf")
		_:
			_paper_card(parent,Vector3(0,0,0),"ДОКУМЕНТ")

func open_container(id: String) -> void:
	for item in items:
		if item["id"] != id or item["kind"] != "container":
			continue
		item["kind"] = "evidence"
		item["label"] = "Взять документ из открытого шкафа"
		var flap: Node3D = item["prop_door"]
		if is_instance_valid(flap):
			create_tween().tween_property(flap,"rotation:y",-1.65,0.48)
		var inside: Node3D = item["hidden_clue"]
		if is_instance_valid(inside):
			inside.visible = true
		return

func item_position(id: String) -> Vector3:
	for item in items:
		if item["id"] == id:
			return item["pos"]
	return Vector3.ZERO

func update_npcs(player_pos: Vector3, delta: float) -> void:
	# Subtle witness attention: characters turn to face Alex when he approaches.
	for who in npc_actors.keys():
		var actor: Node3D = npc_actors[who]
		if not is_instance_valid(actor):
			continue
		var direction: Vector3 = player_pos - actor.global_position
		direction.y = 0.0
		var actor_visual: Node = actor.get_node_or_null("Уникальная 3D-модель")
		if is_instance_valid(actor_visual):
			actor_visual.set("listening", direction.length() <= 3.2)
		if direction.length() <= 5.8 and direction.length() > 0.5:
			var target_angle: float = atan2(-direction.x,-direction.z)
			actor.rotation.y = lerp_angle(actor.rotation.y,target_angle,minf(1.0,delta*2.0))

func place_npc(who: String, pos: Vector3, _skin_color: String, _jacket_color: String) -> void:
	var actor := Node3D.new()
	actor.name = who
	actor.position = pos
	add_child(actor)
	var visual := CampusCharacterVisual.new()
	visual.name = "Уникальная 3D-модель"
	visual.archetype = {"Мира":"mira", "Данияр":"daniyar", "Руслан":"ruslan"}.get(who,"alex")
	visual.layer_mask = 1
	actor.add_child(visual)
	npc_actors[who] = actor
	var marker := make_label(who, pos + Vector3(0,2.36,0), Color("#eedac3"), 27)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	items.append({"id": who.to_lower(), "label": "Поговорить: " + who, "pos": pos, "kind": "npc", "visible": true})

# Reusable environment set dressing: original art, lighting and architectural accents.
func textured_material(texture_name: String, tint: Color, metal: float = 0.0) -> StandardMaterial3D:
	# Important: textured materials must never mutate the global solid-color cache.
	# Otherwise all rooms can silently inherit the last assigned floor texture.
	var key: String = texture_name + ":" + tint.to_html() + ":" + str(metal)
	if _textured_material_cache.has(key):
		return _textured_material_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.metallic = metal
	m.roughness = 0.91
	m.albedo_texture = load("res://assets/textures/" + texture_name + ".png")
	var normal_resource := "res://assets/textures/" + texture_name + "_normal.png"
	if ResourceLoader.exists(normal_resource):
		m.normal_enabled = true
		m.normal_texture = load(normal_resource)
		m.normal_scale = 0.38

	m.uv1_scale = Vector3(8.0,8.0,8.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_textured_material_cache[key] = m
	return m

func make_poster(pos: Vector3, source_name: String, scale_value: Vector2 = Vector2(1.3,1.85)) -> void:
	# PlaneMesh is vertical and slightly offset from its supporting wall.
	var backing := make_box(pos + Vector3(0,0,0.035), Vector3(scale_value.x+0.08,scale_value.y+0.08,0.07), "#455052", false)
	backing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var artwork := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = scale_value
	artwork.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = load("res://assets/textures/" + source_name + ".png")
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	artwork.material_override = mat
	artwork.position = pos + Vector3(0,0,0.086)
	artwork.rotation.x = PI / 2.0
	artwork.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(artwork)

func security_camera(at: Vector3, yaw: float = 0.0) -> void:
	var rig := Node3D.new()
	rig.position = at
	rig.rotation.y = yaw
	add_child(rig)
	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.13
	cyl.bottom_radius = 0.15
	cyl.height = 0.19
	base.mesh = cyl
	base.material_override = _mat(Color("#8ca1a4"))
	rig.add_child(base)
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.27,0.22,0.62)
	body.mesh = box
	body.position = Vector3(0,-0.23,-0.21)
	body.material_override = _mat(Color("#d0d3dc"))
	rig.add_child(body)
	var lens := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.085
	sphere.height = 0.17
	lens.mesh = sphere
	lens.position = Vector3(0,-0.23,-0.52)
	lens.material_override = _mat(Color("#455052"),false,0.6)
	rig.add_child(lens)
	var led := MeshInstance3D.new()
	var spot := SphereMesh.new()
	spot.radius = 0.035
	spot.height = 0.07
	led.mesh = spot
	led.position = Vector3(0.09,-0.15,-0.53)
	led.material_override = _mat(Color("#f7e3cb"),true)
	rig.add_child(led)

func vent_panel(at: Vector3, on_axis: String = "z") -> void:
	var depth: Vector3 = Vector3(0.11,0.64,1.15) if on_axis == "x" else Vector3(1.15,0.64,0.11)
	make_box(at, depth, "#455052", false)
	for i in range(6):
		var shift: Vector3 = Vector3(0, -0.24 + float(i)*0.095, 0)
		var slat: Vector3 = Vector3(0.15,0.025,1.05) if on_axis == "x" else Vector3(1.05,0.025,0.15)
		make_box(at+shift, slat, "#7c999d", false)

func light_strips(at: Vector3, length_value: float = 4.0, tint: String = "#dbc9b4") -> void:
	make_box(at,Vector3(0.18,0.075,length_value),"#455052",false)
	make_box(at+Vector3(0,-0.065,0),Vector3(0.075,0.025,length_value-0.1),tint,false,true)

func wall_monitor(at: Vector3, message: String, tint: String = "#afd0d5") -> void:
	make_box(at,Vector3(1.8,1.1,0.12),"#455052",false)
	make_box(at+Vector3(0,0,0.077),Vector3(1.62,0.87,0.018),"#5e7376",false,true)
	make_label(message,at+Vector3(-0.72,0.10,0.11),Color(tint),16)
	for i in range(7):
		make_box(at+Vector3(-0.60+i*.19,-0.3,0.105),Vector3(0.075,0.017,0.015),tint,false,true)

func make_night_window(at: Vector3, wide: float = 2.2) -> void:
	make_box(at,Vector3(wide,2.35,0.14),"#455052",false)
	make_box(at+Vector3(0,0,0.085),Vector3(wide-0.14,2.19,0.018),"#657c80",false,true)
	make_box(at+Vector3(0,0,0.13),Vector3(0.065,2.25,0.07),"#7c9a9e",false)
	make_box(at+Vector3(0,0,0.13),Vector3(wide,0.065,0.07),"#7c9a9e",false)
	for i in range(5):
		make_box(at+Vector3(-wide*.44 + float(i)*wide*.22,0,0.12),Vector3(0.012,2.18,0.012),"#86a0a4",false,true)

func chair(at: Vector3, yaw: float = 0.0) -> void:
	var pivot := Node3D.new()
	pivot.position = at
	pivot.rotation.y = yaw
	add_child(pivot)
	_prop_box(pivot, Vector3(0,0.54,0), Vector3(0.62,0.10,0.58), "#7a6657")
	_prop_box(pivot, Vector3(0,0.93,0.24), Vector3(0.62,0.72,0.08), "#736051")
	for x in [-0.22,0.22]:
		for z in [-0.18,0.18]:
			_prop_box(pivot, Vector3(x,0.24,z), Vector3(0.05,0.48,0.05), "#5f6870", 0.6)

func desk(at: Vector3, size_value: Vector3 = Vector3(2.2,0.76,1.2), color: String = "#7b6a5b") -> void:
	var barrier := StaticBody3D.new()
	barrier.position = at + Vector3(0,size_value.y*0.5,0)
	var collider := CollisionShape3D.new()
	var solid := BoxShape3D.new()
	solid.size = Vector3(size_value.x, size_value.y, size_value.z)
	collider.shape = solid
	barrier.add_child(collider)
	add_child(barrier)
	var pivot := Node3D.new()
	pivot.position = at
	add_child(pivot)
	_prop_box(pivot, Vector3(0,size_value.y,0), Vector3(size_value.x,0.08,size_value.z), color)
	for x in [-size_value.x*0.42,size_value.x*0.42]:
		for z in [-size_value.z*0.42,size_value.z*0.42]:
			_prop_box(pivot, Vector3(x,size_value.y*0.47,z), Vector3(0.08,size_value.y,0.08), "#5b6066", 0.55)
	_prop_box(pivot, Vector3(0,size_value.y*0.58,-size_value.z*0.45), Vector3(size_value.x-0.14,0.04,0.05), "#55493f")

func reading_table(at: Vector3) -> void:
	desk(at, Vector3(2.1,0.74,1.15), "#816f60")
	_prop_box(self, at + Vector3(-0.4,0.79,0.05), Vector3(0.28,0.03,0.22), "#b2a48f")
	_prop_box(self, at + Vector3(0.36,0.79,-0.08), Vector3(0.32,0.02,0.24), "#d9d1bf")
	_prop_box(self, at + Vector3(0.0,0.83,-0.22), Vector3(0.23,0.07,0.23), "#3f4748")
	_prop_box(self, at + Vector3(-0.42,0.805,0.17), Vector3(0.24,0.007,0.014), "#46484b")
	_prop_box(self, at + Vector3(0.30,0.816,-0.04), Vector3(0.30,0.006,0.22), "#c8bfae")

func potted_plant(at: Vector3, tall: bool = true) -> void:
	var pivot := Node3D.new()
	pivot.position = at
	add_child(pivot)
	_prop_box(pivot, Vector3(0,0.17,0), Vector3(0.42,0.34,0.42), "#7e6b5a")
	_prop_box(pivot, Vector3(0,0.33,0), Vector3(0.30,0.04,0.30), "#54473b")
	var stem_h := 0.95 if tall else 0.55
	_prop_cylinder(pivot, Vector3(0,0.33 + stem_h * 0.5,0), 0.04, stem_h, "#6a825f")
	for i in range(5):
		var leaf := _prop_box(pivot, Vector3(-0.08 + float(i)*0.04,0.50 + float(i%2)*0.06,0.02 if i%2==0 else -0.02), Vector3(0.18,0.03,0.09), "#708a64")
		leaf.rotation.z = -0.8 + float(i) * 0.36
		leaf.rotation.y = float(i) * 0.8
	_prop_box(pivot, Vector3(0,0.35 + stem_h,0), Vector3(0.34,0.14,0.34), "#7ea06f")
	_prop_box(pivot, Vector3(0.14,0.45 + stem_h,0.04), Vector3(0.17,0.08,0.09), "#8caf79")
	_prop_box(pivot, Vector3(-0.12,0.47 + stem_h,-0.06), Vector3(0.16,0.07,0.08), "#7d9f6f")

func reception_desk(at: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = at
	add_child(pivot)
	_prop_box(pivot, Vector3(0,0.68,0), Vector3(4.8,1.35,1.18), "#5c6670")
	_prop_box(pivot, Vector3(0,1.38,0.02), Vector3(5.05,0.09,1.30), "#b09f8d")
	_prop_box(pivot, Vector3(-1.2,1.62,-0.18), Vector3(0.72,0.58,0.06), "#304040")
	_prop_box(pivot, Vector3(1.6,1.52,0.20), Vector3(0.65,0.05,0.34), "#eadfce")
	_prop_box(pivot, Vector3(1.65,1.56,0.21), Vector3(0.20,0.08,0.20), "#404749")
	_prop_tag(pivot, "РЕСЕПШН", Vector3(0,2.12,-0.18), 24)

func library_stack(at: Vector3) -> void:
	var colors := ["#7f6c5c", "#728587", "#b4a28f", "#596a6c"]
	for i in range(4):
		_prop_box(self, at + Vector3(0,float(i)*0.05,0), Vector3(0.34 - float(i)*0.03,0.045,0.24), colors[i])

func locker_bank(at: Vector3, count_value: int = 4) -> void:
	var pivot := Node3D.new()
	pivot.position = at
	add_child(pivot)
	for i in range(count_value):
		var x := (float(i) - float(count_value - 1) * 0.5) * 1.12
		_prop_box(pivot, Vector3(x,1.14,0), Vector3(1.0,2.28,0.64), "#5d6a70")
		_prop_box(pivot, Vector3(x,1.14,-0.31), Vector3(0.88,2.05,0.03), "#738790")
		_prop_box(pivot, Vector3(x+0.30,1.10,-0.34), Vector3(0.05,0.14,0.02), "#c0b49f", 0.7)
		for row in range(3):
			_prop_box(pivot, Vector3(x,0.50 + float(row)*0.54,-0.33), Vector3(0.74,0.02,0.02), "#889ca2")

func archive_cabinet(at: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = at
	add_child(pivot)
	_prop_box(pivot, Vector3(0,1.1,0), Vector3(1.35,2.2,0.72), "#687172")
	for row in range(4):
		var y := 0.36 + float(row)*0.49
		_prop_box(pivot, Vector3(0,y,-0.34), Vector3(1.18,0.40,0.03), "#7b8485")
		_prop_box(pivot, Vector3(0,y,-0.37), Vector3(0.18,0.04,0.02), "#ddd3bf", 0.7)

func lab_machine(at: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = at
	add_child(pivot)
	_prop_box(pivot, Vector3(0,0.95,0), Vector3(1.28,1.9,0.92), "#59676c")
	_prop_box(pivot, Vector3(0,1.47,-0.42), Vector3(1.00,0.75,0.04), "#bcd0cf")
	_prop_box(pivot, Vector3(0,0.54,-0.40), Vector3(0.40,0.22,0.03), "#ccd8cf")
	for i in range(3):
		_prop_box(pivot, Vector3(-0.35 + float(i)*0.35,0.54,-0.40), Vector3(0.10,0.10,0.03), "#7f9da0")

func books_shelf_decor(base_pos: Vector3) -> void:
	# Individual visible book spines, NOT a solid cuboid.
	var colors: Array[String] = ["#a28768", "#647c7a", "#956e5a", "#c7b89e", "#596b80", "#a8a193", "#75846e", "#7e5351"]
	for level in range(4):
		for idx in range(11):
			var col: String = colors[(idx + level * 3) % colors.size()]
			var height: float = 0.28 + float((idx * 7 + level * 3) % 5) * 0.025
			var thickness: float = 0.105 + float((idx + level) % 3) * 0.018
			var z: float = -0.74 + float(idx) * 0.142
			make_box(base_pos + Vector3(0.12,0.40 + float(level) * 0.60 + height * 0.5,z), Vector3(0.19,height,thickness), col, false)
			# thin spine stamping gives an actual book-like appearance at close range
			make_box(base_pos + Vector3(0.223,0.47 + float(level) * 0.60,z), Vector3(0.004,0.014,thickness * 0.70), "#d4c7a9", false)

func build_atrium() -> void:
	reception_desk(Vector3(0,0,-5.6))
	make_box(Vector3(0,1.34,-5.7), Vector3(5.5,0.13,1.36), "#857869", false)
	for i in range(5):
		make_box(Vector3(-6.7 + float(i)*3.35, 3.8, 0.5), Vector3(0.23,0.16,7), "#5f6c78", false)
	for x in [-5.5,5.5]:
		make_light(Vector3(x,3.85,0), "#e1d4bf", 1.0, 8.5, false)
	make_light(Vector3(0,3.9,0), "#f2e0c8", 1.15, 9.5, false)
	make_poster(Vector3(1.5,2.2,-7.61), "poster_echo",Vector2(2.1,3.0))
	make_night_window(Vector3(-3.3,2.28,7.62), 2.8)
	make_night_window(Vector3(3.3,2.28,7.62), 2.8)
	security_camera(Vector3(7.25,4.25,-6.5),-1.4)
	vent_panel(Vector3(-8.65,3.0,2.8),"x")
	light_strips(Vector3(-2.7,4.48,0),5.0)
	light_strips(Vector3(3.4,4.48,0),5.0)
	potted_plant(Vector3(-7.0,0,-6.2), true)
	potted_plant(Vector3(7.0,0,-6.2), true)
	make_box(Vector3(-5.8,1.16,-6.25), Vector3(1.05,1.5,0.035), "#bdad9b", false, true)
	make_label("ПРОЕКТ ЭХО",Vector3(-5.75,2.2,-6.1),Color("#f7e5d0"),25)
	place_npc("Руслан",Vector3(4.4,0,3.6),"#cbb8a6","#5b7073")
	register_item("notice", "Плакат закрытой конференции", Vector3(-6.25,1.3,-7.56), "lore")
	register_item("guard_report", "Неоформленный рапорт охраны", Vector3(2.3,1.09,-4.7), "evidence", "#eeddc3")
	register_item("circuit", "Электрощиток", Vector3(6.65,1.5,-7.55), "puzzle", "#c6ecf1")

func build_library() -> void:
	for x in [-26.25,-13.0]:
		for z in [-5.6,-3.1,3.1,5.6]:
			bookshelf(Vector3(x,0,z))
	for cx in [-20.8,-17.4]:
		for cz in [-4.2,1.6]:
			reading_table(Vector3(cx,0,cz))
			chair(Vector3(cx-0.55,0.0,cz+1.15),0.0)
			chair(Vector3(cx+0.55,0.0,cz+1.15),0.0)
	make_light(Vector3(-20.0,4.0,-1.0),"#f5e2cc",1.6,11)
	make_night_window(Vector3(-20.8,2.4,7.62),3.0)
	make_poster(Vector3(-16.6,2.1,-7.6),"poster_archive",Vector2(1.4,2.05))
	light_strips(Vector3(-19.4,4.43,0),5.2,"#e9d6bf")
	make_light(Vector3(-12.7,3.7,5.5),"#e6ddcf",0.8,7)
	potted_plant(Vector3(-10.9,0,6.1), false)
	potted_plant(Vector3(-27.2,0,-6.0), false)
	library_stack(Vector3(-17.1,0.77,1.1))
	library_stack(Vector3(-20.0,0.77,-4.4))
	register_item("note", "Записка профессора",Vector3(-20.8,0.84,-4.1))
	register_item("register", "Журнал посещений",Vector3(-17.4,0.84,1.6),"evidence","#cbf2f7")
	register_item("message", "Служебная переписка",Vector3(-12.0,1.04,-4.2),"evidence","#f7e2cb")
	register_item("diary", "Дневник Алекса",Vector3(-25.8,1.02,5.2),"lore")
	register_item("old_photo", "Старая фотография участников",Vector3(-25.1,1.02,4.4),"evidence","#dfcdb7")

func bookshelf(pos: Vector3) -> void:
	# A real bookcase: open front, separated side panels, planks, and individual books.
	# Only the collision is a single invisible body; the visible mesh has no large solid block.
	var body := StaticBody3D.new()
	body.name = "Стеллаж — физика"
	body.position = pos + Vector3(0,1.43,0)
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.76,2.86,1.84)
	collision.shape = shape
	body.add_child(collision)
	for x in [-0.34,0.34]:
		make_box(pos + Vector3(x,1.43,0), Vector3(0.06,2.86,1.83), "#806a53", false)
	make_box(pos + Vector3(-0.32,1.43,0), Vector3(0.035,2.86,1.82), "#b19b7e", false)
	make_box(pos + Vector3(0,2.83,0), Vector3(0.77,0.085,1.88), "#79634f", false)
	make_box(pos + Vector3(0,0.065,0), Vector3(0.77,0.13,1.86), "#79634f", false)
	for level in range(4):
		make_box(pos + Vector3(0,0.35 + float(level) * 0.60,0), Vector3(0.73,0.07,1.82), "#9b8063", false)
	books_shelf_decor(pos)

func build_lab() -> void:
	for x in [12.4,25.6]:
		for z in [-5.2,-1.2,3.7]:
			locker_bank(Vector3(x,0,z), 1)
	for x in [17.0,21.0]:
		for z in [-3.7,2.3]:
			desk(Vector3(x,0,z), Vector3(2.2,0.74,1.2), "#64757a")
			_prop_box(self, Vector3(x,1.56,z-0.35), Vector3(0.9,0.60,0.06), "#b8dce1")
	for x in [14.0,24.0]:
		lab_machine(Vector3(x,0,-5.7))
	make_light(Vector3(19,4,-1),"#dfe7dd",1.35,9,false)
	make_poster(Vector3(21.7,2.20,7.62),"poster_warning",Vector2(1.6,2.25))
	make_night_window(Vector3(16,2.4,7.62),2.4)
	security_camera(Vector3(27.5,4.1,5.6),-1.5)
	wall_monitor(Vector3(19,2.75,-7.56),"ECHO // 021", "#dbe7e0")
	light_strips(Vector3(15.3,4.4,-1),5.2,"#d9e2da")
	light_strips(Vector3(23.4,4.4,-1),5.2,"#eedec7")
	make_light(Vector3(26.0,3.8,5.0),"#dfcdb7",0.9,7,false)
	potted_plant(Vector3(11.3,0,6.2), false)
	place_npc("Мира",Vector3(15,0,4.6),"#c9b8a5","#d5d1d8")
	place_npc("Данияр",Vector3(23,0,4.1),"#c0aa9d","#505b66")
	register_item("pass", "Лог пропуска 21:17",Vector3(17.0,0.84,-3.7),"evidence","#c3e9ee")
	register_item("trace", "Повреждённый стеллаж",Vector3(25.0,0.0,-1.2),"evidence","#edd9c2")
	register_item("usb", "Носитель ЭХО",Vector3(21.0,0.84,2.3),"evidence","#f7e3cb")
	register_item("scanner", "Станция анализа улик",Vector3(21.0,0.84,-3.7),"scanner","#bfe9d2")
	register_item("mira_backup", "Резервная копия Миры",Vector3(11.25,1.02,-4.55),"evidence","#cbe2f7")

func build_archive() -> void:
	for x in [12.5,14.9,23.3,26.1]:
		for z in [-21.1,-17.6,-13.6]:
			bookshelf(Vector3(x,0,z))
	archive_cabinet(Vector3(18.0,0,-18.2))
	archive_cabinet(Vector3(20.2,0,-18.2))
	desk(Vector3(19,0,-18.3), Vector3(3.0,0.76,1.5), "#6f7a83")
	_prop_box(self, Vector3(19,1.62,-18.65), Vector3(1.30,0.68,0.08), "#d1c3af")
	make_light(Vector3(19,4,-17),"#e6d9ca",1.4,10,false)
	make_poster(Vector3(19,2.1,-23.6),"poster_archive",Vector2(1.5,2.1))
	security_camera(Vector3(27.45,4.05,-21.0),-1.9)
	light_strips(Vector3(16.5,4.40,-16.1),5.1,"#f4e0c8")
	light_strips(Vector3(22.0,4.40,-16.1),5.1,"#d5dde1")
	make_light(Vector3(25,4,-22),"#cab9a6",0.65,8,false)
	potted_plant(Vector3(11.1,0,-23.0), false)
	register_item("audit", "История правок ЭХО",Vector3(19,0.84,-18.25),"evidence","#cbe2f7")
	register_item("security", "Архивная запись камер",Vector3(12.2,1.05,-20.9),"evidence","#cbf2f7")
	register_item("final", "Стенд обвинения",Vector3(21.6,0.0,-21.0),"final","#f7e3cb")
	register_item("timeline", "Реконструкция хронологии",Vector3(16.2,0.0,-12.6),"timeline","#c5ebf0")
	register_item("alex_file", "Личное дело №021 — Алекс",Vector3(25.8,1.05,-19.45),"evidence","#f7e3cb")
	make_label("ПРАВДА НЕ В ПАМЯТИ. ОНА В ЖУРНАЛАХ.",Vector3(19,3.4,-23.5),Color("#f0dcc5"),22)

func build_shadow() -> void:

	horror_shadow = Node3D.new()
	horror_shadow.position = Vector3(19,0,-21.7)
	horror_shadow.visible = false
	add_child(horror_shadow)
	var mat := _mat(Color("#455052"))
	for part in [
		{ "p": Vector3(0,1.06,0), "s": Vector3(0.72,1.75,0.38)},
		{ "p": Vector3(0,2.04,0), "s": Vector3(0.4,0.42,0.37)},
		{ "p": Vector3(-0.18,0.22,0), "s": Vector3(0.28,0.6,0.30)},
		{ "p": Vector3(0.18,0.22,0), "s": Vector3(0.28,0.6,0.30)}
	]:
		var m := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part["s"]
		m.mesh = box
		m.material_override = mat
		m.position = part["p"]
		horror_shadow.add_child(m)
	for side in [-1.0,1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.047
		eye.mesh = eye_mesh
		eye.material_override = _mat(Color("#f7e3cb"),true)
		eye.position = Vector3(side*0.105,2.06,-0.205)
		horror_shadow.add_child(eye)

func set_item_hidden(id: String) -> void:
	for item in items:
		if item["id"] != id:
			continue
		item["visible"] = false
		if item.get("persistent_prop",false):
			# Keep the opened cabinet; remove only the collectible inside.
			if item.has("hidden_clue") and is_instance_valid(item["hidden_clue"]):
				item["hidden_clue"].visible = false
		else:
			if item.has("visual") and is_instance_valid(item["visual"]):
				item["visual"].visible = false

func nearest_item(player_pos: Vector3, max_distance: float = 2.4) -> Dictionary:
	var closest: Dictionary = {}
	var distance: float = max_distance
	for item in items:
		if not item["visible"]:
			continue
		var delta: Vector3 = item["pos"] - player_pos
		delta.y = 0.0
		if delta.length() < distance:
			distance = delta.length()
			closest = item
	return closest

func update_flicker(delta: float, incident: bool = false) -> void:
	lamp_time += delta
	for i in range(lights.size()):
		var light := lights[i]
		var base: float = light.get_meta("base_energy")
		if light.get_meta("flicker"):
			var disturbance := 0.93 + sin(lamp_time*4.5+float(i)*1.3)*0.045
			if incident:
				disturbance *= (0.45 if sin(lamp_time*19.0) > 0.1 else 1.0)
			light.light_energy = maxf(0.05,base*disturbance)

func reveal_shadow() -> void:
	horror_shadow.visible = true

func hide_shadow() -> void:
	horror_shadow.visible = false
