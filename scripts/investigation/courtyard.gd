extends "res://scripts/campaign/map.gd"

var drawer_face: Node3D
var gate_leaf: Node3D
var echo_light: OmniLight3D

func make_world() -> void:
	if made: return
	made = true
	spec = catalog.level(1)
	var env := WorldEnvironment.new()
	var ambience := Environment.new()
	ambience.background_mode = Environment.BG_COLOR
	ambience.background_color = Color("#26323a")
	ambience.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambience.ambient_light_color = Color("#adb3ae")
	ambience.ambient_light_energy = 0.5
	ambience.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	ambience.ssao_enabled = true
	env.environment = ambience
	add_child(env)
	make_box(Vector3(0,-0.19,0),Vector3(36,0.3,28),"#898377").material_override = textured_material("floor_stone",Color("#d4d0c5"))
	# University facade, gatehouse and west service route form distinct investigation areas.
	for x in [-18.0,18.0]: make_box(Vector3(x,1.2,0),Vector3(0.35,2.4,28),"#727568")
	make_box(Vector3(0,1.2,14),Vector3(36,2.4,0.4),"#727568")
	make_box(Vector3(0,4,-14),Vector3(36,8,0.8),"#898982")
	for x in [-13.0,-8.0,8.0,13.0]: make_night_window(Vector3(x,4.6,-13.5),3.0)
	make_label("УНИВЕРСИТЕТ / КОРПУС ЭХО",Vector3(0,5.5,-13.35),Color("#d8c9ac"),35)
	for x in [-9.6,9.6]: make_box(Vector3(x,1.65,-10),Vector3(16.8,3.3,0.3),"#898982")
	make_box(Vector3(0,3.7,-10),Vector3(3.4,1.1,0.3),"#898982")
	gate_leaf = Node3D.new()
	gate_leaf.position = Vector3(-1.5,0,-10)
	add_child(gate_leaf)
	_prop_box(gate_leaf,Vector3(1.5,1.5,0),Vector3(3,3,0.15),"#5d6259")
	var gate_body := StaticBody3D.new()
	var gate_collision := CollisionShape3D.new()
	var gate_shape := BoxShape3D.new()
	gate_shape.size = Vector3(3,3,0.2)
	gate_collision.shape = gate_shape
	gate_collision.position = Vector3(1.5,1.5,0)
	gate_body.add_child(gate_collision)
	gate_leaf.add_child(gate_body)
	make_label("ГОСТЕВОЙ ДОПУСК / ВЕСТИБЮЛЬ",Vector3(0,3.1,-9.7),Color("#e6d5b8"),24)
	# Narrow guard booth with an open front and a real drawer.
	make_box(Vector3(-12,1.5,0),Vector3(6,3,0.2),"#898982")
	make_box(Vector3(-15,1.5,2),Vector3(0.2,3,4),"#898982")
	make_box(Vector3(-12,3.1,2),Vector3(6.3,0.2,4.3),"#756f61",false)
	desk(Vector3(-12,0,1.5),Vector3(3.5,0.76,1.1))
	make_label("ОХРАНА",Vector3(-12,2.6,0.25),Color("#ddd0b9"),30)
	drawer_face = Node3D.new()
	drawer_face.position = Vector3(-12,0.45,2.15)
	add_child(drawer_face)
	_prop_box(drawer_face,Vector3.ZERO,Vector3(0.85,0.45,0.09),"#978974")
	_prop_box(drawer_face,Vector3(0,0,0.07),Vector3(0.24,0.04,0.04),"#c3b6a0")
	place_npc("Руслан",Vector3(-8,0,3),"","")
	# Central planted island forces route choices while preserving clear lanes.
	make_box(Vector3(0,0.35,0.5),Vector3(6.4,0.7,5.4),"#76766b")
	for x in [-2.0,2.0]:
		for z in [-1.0,2.0]: potted_plant(Vector3(x,0.7,z))
	for x in [-6.0,6.0]:
		make_cylinder(Vector3(x,2.3,7.5),0.075,4.6,"#53564e")
		make_light(Vector3(x,4.5,7.5),"#dfc99d",1.2,12)
	make_light(Vector3(-12,2.7,2),"#e8d2a8",0.8,7)
	make_light(Vector3(10,3,-6),"#d6d7c4",1.0,10)
	make_light(Vector3(0,3.8,-9),"#e1d5c2",1.0,9)
	# West corridor and technical equipment.
	make_box(Vector3(12,0.45,-5),Vector3(3,0.9,2.0),"#625f52")
	wall_monitor(Vector3(12,1.65,-5.7),"WEST / LOCAL CLOCK")
	make_label("ЗАПАДНЫЙ ПРОХОД →",Vector3(11,2.7,-9.7),Color("#ddd0b9"),26)
	make_box(Vector3(15,1.35,-8),Vector3(1.4,2.7,0.7),"#697166")
	vent_panel(Vector3(15,1.4,-7.6))
	security_camera(Vector3(14,3,-9.5))
	# Entrance phone and noticeboard.
	desk(Vector3(-6,0,10),Vector3(1.5,0.76,0.9))
	_source("arrival","Телефон: сообщение Миры",Vector3(-6,0.81,10),"source")
	register_item("schedule_prop","Расписание",Vector3(6,0,7),"lore")
	items.pop_back() # Use investigation ID while retaining the physical stand.
	_source("l1_schedule","Стенд: вчерашняя лекция",Vector3(6,1.1,7),"source",false)
	desk(Vector3(15,0,-6.8),Vector3(1.2,0.95,0.65))
	_source("l1_maintenance","Наряд на западный проход",Vector3(15,1.0,-6.8),"source")
	desk(Vector3(10,0,-5),Vector3(0.9,0.89,0.65))
	_source("l1_clock","Акт сверки часов",Vector3(10,0.94,-5),"source")
	_source("l1_drawer_object","Ящик охраны / журнал двери",Vector3(-12,0.6,2.35),"drawer",false)
	_source("l1_terminal","Терминал: часы и повреждённое сообщение",Vector3(12,1.0,-3.8),"terminal",false)
	register_item("l1_board","Доска расследования",Vector3(-5,0,-6),"deduction")
	# Optional hidden objects with plausible physical supports.
	desk(Vector3(-7,0,7),Vector3(2.6,0.45,0.65))
	_source("l1_inspect","Потёртый бейдж на скамье",Vector3(-7,0.5,7),"inspect")
	_source("l1_receipt","Сложенная квитанция под электрощитом",Vector3(16.5,0.03,-7.5),"source")
	desk(Vector3(-3,0,10),Vector3(1,0.76,0.65))
	_source("l1_rumour","Студенческий чат на телефоне",Vector3(-3,0.81,10),"rumour",true)
	_source("l1_gate_object","Приложить гостевой допуск",Vector3(1.1,1.3,-9),"gate",false)
	_source("exit","Пройти в вестибюль",$Exit.position,"exit",false)
	build_shadow()
	horror_shadow.position = Vector3(10,0,-9)
	echo_light = OmniLight3D.new()
	echo_light.position = Vector3(12,2,-5)
	echo_light.light_color = Color("#e0d6bf")
	echo_light.light_energy = 0
	add_child(echo_light)

func _source(id: String, title: String, at: Vector3, kind: String, prop: bool = true) -> void:
	var visual := Node3D.new()
	visual.position = at
	add_child(visual)
	if prop:
		if id == "l1_inspect":
			_prop_box(visual,Vector3.ZERO,Vector3(0.24,0.02,0.36),"#9b9480")
		else: _make_evidence_prop(visual,id)
	items.append({"id":id,"label":title,"pos":at,"kind":kind,"visible":true,"visual":visual})
	if kind == "source" and id != "l1_receipt":
		var marker: Label3D = make_label("◇",at+Vector3(0,0.8,0),Color("#e1cba1"),28)
		marker.set_meta("clue",id)
		guidance.append(marker)

func _make_evidence_prop(parent: Node3D, id: String) -> void:
	if id in ["l1_board","schedule_prop"]:
		super._make_evidence_prop(parent,"challenge")
	else: super._make_evidence_prop(parent,id)

func apply_state(state) -> void:
	if state.flags.get("l1_drawer_open",false): drawer_face.position.z = 2.7
	if state.flags.get("l1_gate",false): gate_leaf.rotation.y = -1.5
	for item in items:
		if item.id == "l1_rumour":
			item.visible = state.difficulty == "hard"
			item.visual.visible = item.visible
	set_guidance(state.difficulty == "easy")

func animate_drawer() -> void:
	create_tween().tween_property(drawer_face,"position:z",2.7,0.5)

func animate_gate() -> void:
	create_tween().tween_property(gate_leaf,"rotation:y",-1.5,0.8)

func echo_event(reduced: bool) -> void:
	if reduced: return
	var tween := create_tween()
	tween.tween_property(echo_light,"light_energy",1.1,0.5)
	tween.tween_interval(0.8)
	tween.tween_property(echo_light,"light_energy",0.0,1.0)
