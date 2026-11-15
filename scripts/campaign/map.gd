extends "res://scripts/world_builder.gd"

const Catalog = preload("res://scripts/campaign/catalog.gd")
@export var level_id: int = 1
var catalog = Catalog.new()
var spec: Dictionary
var guidance: Array[Label3D] = []

func make_world() -> void:
	if made: return
	made = true
	spec = catalog.level(level_id)
	var w: float = spec.size[0]
	var d: float = spec.size[1]
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#242c32")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#c8c0b2")
	e.ambient_light_energy = 0.48
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ssao_enabled = true
	e.ssao_radius = 0.7
	env.environment = e
	add_child(env)
	if level_id == 1:
		make_box(Vector3(0,-0.19,0),Vector3(w,0.3,d),"#898377").material_override = textured_material("floor_stone",Color.WHITE)
		for x in [-w/2,w/2]:
			make_box(Vector3(x,1,0),Vector3(0.4,2,d),"#787b73")
		for z in [-d/2,d/2]: make_box(Vector3(0,1,z),Vector3(w,2,0.4),"#787b73")
		make_box(Vector3(0,4,-d/2-1),Vector3(w,8,2),"#898982")
		make_label("УНИВЕРСИТЕТ / КОРПУС ЭХО",Vector3(0,5,-d/2+0.2),Color("#e4d8c4"),40)
		for x in [-5.0,5.0]:
			make_box(Vector3(x,0.3,0),Vector3(3,0.6,5),"#77786b")
			for z in [-1.5,1.5]: potted_plant(Vector3(x,0.6,z))
			make_cylinder(Vector3(x,2.4,5.5),0.06,4.8,"#4b4b47")
			make_light(Vector3(x,4.6,5.5),"#e2d3bb",1.4,11)
	else:
		var theme: String = "АРХИВ" if level_id in [5,11,17,18] else ("БИБЛИОТЕКА" if level_id in [4,7,13,15,20] else "ЛАБОРАТОРИЯ")
		room(theme,Vector2.ZERO,Vector2(w,d),{},Color("#898377"))
		make_label(str(spec.title).to_upper(),Vector3(0,3.0,-d/2+0.5),Color("#d9c7af"),28)
		for x in [-w*0.26,w*0.26]:
			for z in [-d*0.25,d*0.25]:
				light_strips(Vector3(x,4.4,z),2.2)
				make_light(Vector3(x,3.9,z),"#d8d0bd",0.9,9,level_id in [10,16,18])
		_decorate()
	build_shadow()
	horror_shadow.position = Vector3(2,0,-d/2+2)
	# Dedicated clear peripheral lanes connect spawn, each clue, station, NPC and exit.
	for i in range(spec.evidence.size()):
		var id: String = str(spec.evidence[i])
		# Different search routes on different maps. Keep the central traversal lane free.
		var zone: int = (level_id + i*2) % 4
		var at := Vector3(-w/2+2,0.81,d/2-4)
		match zone:
			0: at = Vector3(-w/2+2,0.81,d/2-4)
			1: at = Vector3(-w/2+2,0.81,-d/2+3.4)
			2: at = Vector3(w/2-2,0.81,-d/2+3.4)
			3: at = Vector3(-w/2+2,0.81,0.7+float(i)*1.1)
		if id == "trace": at.y = 0.0
		if id not in ["message","old_photo","mira_backup","guard_report","security","alex_file","trace"]:
			desk(Vector3(at.x,0,at.z),Vector3(1.5,0.76,0.9))
		register_item(id,str(catalog.clue(id)[0]),at)
		var marker: Label3D = make_label("◇",at+Vector3(0,1.2,0),Color("#e9d2a8"),36)
		marker.set_meta("clue",id)
		guidance.append(marker)
	var station := Vector3(w/2-2,0,d/2-4)
	register_item("challenge","Исследовать рабочую станцию",station,"challenge")
	if level_id > 1:
		var case_position := Vector3(w/2-2,0,d/2-7.3)
		if level_id in [7,13]:
			case_position.x -= 1.8 # Leave the approach to the witness clear.
		register_item("casework","Открыть дело / специальное испытание",case_position,"casework")
		_solid(case_position+Vector3(0,0.40,0),Vector3(1.28,0.8,0.75))
		make_label("ЭКСПЕРТИЗА",case_position+Vector3(0,1.35,0),Color("#d4b88b"),24)
	if not str(spec.npc).is_empty():
		place_npc(spec.npc,Vector3(w/2-2,0,-2),"","")
	if level_id == 20:
		place_npc("Мира",Vector3(-4,0,-d/2+3),"","")
		place_npc("Руслан",Vector3(4,0,-d/2+3),"","")
	if level_id == 19: register_item("timeline","Реконструкция / жесты",Vector3(3,0,-3),"timeline")
	var exit_pos: Vector3 = $Exit.position
	var exit_prop := make_box(exit_pos+Vector3(0,1.35,0),Vector3(1.8,2.7,0.15),"#5e635b",false)
	make_label("ДОСЬЕ" if level_id == 20 else "ДАЛЕЕ →",exit_pos+Vector3(0,2.9,0.2),Color("#e8dfcb"),26)
	items.append({"id":"exit","kind":"exit","label":"Итоговое досье" if level_id == 20 else "Завершить уровень / следующий", "pos":exit_pos,"visible":true,"visual":exit_prop})

func _decorate() -> void:
	# Deliberately authored layouts: furniture rows, partitions and silhouettes differ.
	match level_id:
		2:
			reception_desk(Vector3(-2,0,-3))
			make_box(Vector3(-2,0.65,-3),Vector3(4.8,1.3,1.2),"#70695e")
			for x in [-3.0,3.0]: make_cylinder(Vector3(x,2.2,2),0.35,4.4,"#b3aa98")
		3:
			for z in [3.0,0.0,-3.0]:
				for x in [-3.0,1.0]: desk(Vector3(x,0,z)); chair(Vector3(x,0,z+0.9))
			wall_monitor(Vector3(0,2.5,-8.7),"ЭХО / ПОСЛЕДНЯЯ ЛЕКЦИЯ")
		4:
			for z in [-4.0,-1.0,2.0]: bookshelf(Vector3(2,0,z))
			reading_table(Vector3(-2,0,0))
		5:
			for x in [-2.0,2.0]:
				for z in [-4.0,0.0,4.0]: bookshelf(Vector3(x,0,z))
		6:
			for x in [-4.0,0.0,4.0]:
				for z in [-2.0,1.0]:
					desk(Vector3(x,0,z)); wall_monitor(Vector3(x,1.2,z-0.3),"ECHO / MAIL")
		7:
			for x in [-2.0,2.0]:
				make_box(Vector3(x,0.35,-2),Vector3(1.6,0.7,2.8),"#7a7567")
				make_box(Vector3(x,0.78,-2),Vector3(1.6,0.16,2.8),"#aca28d",false)
			reading_table(Vector3(0,0,2)); potted_plant(Vector3(0,0,-5))
		8:
			for x in [-3.0,0.0,3.0]: wall_monitor(Vector3(x,2.1,-5.7),"CAM / NO SIGNAL")
			desk(Vector3(0,0,-2),Vector3(5,0.76,1.2))
		9:
			for z in [-7.0,-3.0,1.0]:
				make_box(Vector3(3.7,1.4,z),Vector3(0.2,2.8,1.6),"#665e53")
				security_camera(Vector3(-4.5,3.6,z))
		10:
			lab_machine(Vector3(1,0,1)); desk(Vector3(3,0,-3))
			make_box(Vector3(-1,0.02,-3),Vector3(3,0.02,2),"#695d50",false)
			make_label("НЕ ПЕРЕМЕЩАТЬ ПРЕДМЕТЫ",Vector3(0,1.5,-4.5),Color("#c4ae83"),25)
		11:
			locker_bank(Vector3(1,0,-4),3)
			archive_cabinet(Vector3(1,0,1))
			make_box(Vector3(-1,1.5,-1),Vector3(0.2,3,5),"#898982")
		12:
			lab_machine(Vector3(-1,0,-3)); lab_machine(Vector3(2,0,1))
			desk(Vector3(-1,0,2)); vent_panel(Vector3(0,3,-7.7))
		13:
			desk(Vector3(0,0,-2)); chair(Vector3(0,0,-3))
			bookshelf(Vector3(2,0,2)); make_night_window(Vector3(0,2.5,-6.7),3)
		14:
			for z in [-5.0,-1.0,3.0]:
				make_box(Vector3(1.8,1.3,z),Vector3(1.1,2.6,1.3),"#68716e")
				vent_panel(Vector3(1.8,1.4,z+0.7))
		15:
			desk(Vector3(1,0,-3),Vector3(3,0.76,1.4)); chair(Vector3(1,0,-4))
			make_box(Vector3(-2,1.5,-1),Vector3(0.2,3,5),"#898982")
			archive_cabinet(Vector3(2,0,2))
		16:
			for x in [-4.0,0.0,4.0]:
				for z in [-4.0,0.0,4.0]:
					make_box(Vector3(x,1.5,z),Vector3(1.3,3,1.6),"#3f4949")
					for y in [0.5,1.2,1.9,2.6]: vent_panel(Vector3(x,y,z+0.85))
		17:
			for x in [-3.0,0.0,3.0]:
				archive_cabinet(Vector3(x,0,-3)); wall_monitor(Vector3(x,2.8,-6.7),"BACKUP / 21:36")
		18:
			make_box(Vector3(0,1.5,0),Vector3(5,3,0.25),"#898982")
			archive_cabinet(Vector3(2,0,-4)); reading_table(Vector3(-2,0,3))
			make_label("ДОПУСК / 021",Vector3(0,2.7,0.2),Color("#d1c0a7"),32)
		19:
			for x in [-3.0,0.0,3.0]:
				make_box(Vector3(x,0.02,1),Vector3(1.7,0.02,2),"#8c8374",false)
			wall_monitor(Vector3(0,2.5,-7.7),"РЕКОНСТРУКЦИЯ / ПЯТЬ СОБЫТИЙ")
		20:
			desk(Vector3(0,0,0),Vector3(5.5,0.76,2))
			for x in [-2.0,0.0,2.0]: chair(Vector3(x,0,1.6))
			for x in [-6.0,6.0]: make_night_window(Vector3(x,2.5,-9.7),3)

func _make_evidence_prop(parent: Node3D, id: String) -> void:
	if id == "casework":
		_prop_box(parent,Vector3(0,0.78,0),Vector3(1.28,0.08,0.75),"#776c5c")
		for x in [-0.55,0.55]:
			for z in [-0.28,0.28]:
				_prop_box(parent,Vector3(x,0.39,z),Vector3(0.07,0.78,0.07),"#625b50")
		_prop_box(parent,Vector3(-0.28,0.84,0),Vector3(0.36,0.02,0.28),"#e7dac4")
		_prop_box(parent,Vector3(0.28,0.84,0),Vector3(0.38,0.03,0.29),"#495756")
		_prop_box(parent,Vector3(0.28,0.86,0),Vector3(0.30,0.007,0.20),"#aebdb4")
		return
	if id == "challenge":
		super._make_evidence_prop(parent,"timeline")
		return
	if catalog.data.evidence.has(id):
		match catalog.clue_type(id):
			"digital": super._make_evidence_prop(parent,"audit")
			"phone":
				_prop_box(parent,Vector3(0,0.02,0),Vector3(0.18,0.04,0.34),"#303b3c")
				_prop_box(parent,Vector3(0,0.043,0),Vector3(0.15,0.005,0.29),"#9baba1")
			"audio":
				_prop_box(parent,Vector3(0,0.04,0),Vector3(0.28,0.08,0.42),"#464c4a")
				for x in [-0.07,0.07]: _prop_cylinder(parent,Vector3(x,0.09,0),0.045,0.015,"#b5b09d")
			"trace": _prop_box(parent,Vector3(0,0.02,0),Vector3(0.4,0.04,0.3),"#897463")
			_: super._make_evidence_prop(parent,id)
	else: super._make_evidence_prop(parent,id)

func set_guidance(enabled: bool) -> void:
	for marker in guidance:
		var available: bool = false
		for item in items:
			if item.id == marker.get_meta("clue"): available = item.visible
		marker.visible = enabled and available

# Physical bounds for inherited decorative furniture.
func _solid(at: Vector3, dimensions: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func archive_cabinet(at: Vector3) -> void:
	super.archive_cabinet(at)
	_solid(at+Vector3(0,1.1,0),Vector3(1.35,2.2,0.72))

func locker_bank(at: Vector3, count_value: int = 4) -> void:
	super.locker_bank(at,count_value)
	_solid(at+Vector3(0,1.14,0),Vector3(count_value*1.12,2.28,0.64))

func lab_machine(at: Vector3) -> void:
	super.lab_machine(at)
	_solid(at+Vector3(0,0.95,0),Vector3(1.28,1.9,0.92))

func _make_storage(parent: Node3D, id: String) -> Node3D:
	var door: Node3D = super._make_storage(parent,id)
	_solid(parent.position-Vector3(0,parent.position.y/2,0),Vector3(0.84,parent.position.y,0.58))
	return door

func set_item_hidden(id: String) -> void:
	super.set_item_hidden(id)
	for marker in guidance:
		if marker.get_meta("clue") == id: marker.hide()
