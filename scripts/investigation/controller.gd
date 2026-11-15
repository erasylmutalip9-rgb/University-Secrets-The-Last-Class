extends "res://scripts/campaign/controller.gd"

var rules = preload("res://scripts/investigation/rules.gd").new()
var selected_sources: Array = []
var deduction_kind: String = "route"
var board_mode: String = "deduction"
var predicate_picker: OptionButton
var justification: TextEdit
var packet_order: Array = []
var inspect_yaw: float = 0
var inspect_zoom: float = 1
var inspect_model: Node3D
var inspect_camera: Camera3D
var inspect_status: Label
var pending_summary_level: int = 0
var intro_progress: float = 0

func _process(delta: float) -> void:
	super._process(delta)
	if actor_mode in ["playing","dialogue","deduction","terminal","inspection","packets"]:
		var m: Dictionary = rules.metrics(state,state.current)
		m.seconds = float(m.seconds)+delta
	if actor_mode == "arrival_scene":
		intro_progress += delta
		if is_instance_valid(cinematic_camera):
			cinematic_camera.position = Vector3(0,2.4,12.5).lerp(Vector3(0,1.8,10.5),minf(1,intro_progress/5))
		if intro_progress >= 5: _finish_arrival()

func _unhandled_input(event: InputEvent) -> void:
	if actor_mode == "arrival_scene" and (event.is_action_pressed("pause") or event.is_action_pressed("interact")):
		_finish_arrival()
		return
	if event.is_action_pressed("pause") and actor_mode in ["deduction","terminal","inspection","packets","level_summary"]:
		_close_overlay()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

func _show_menu() -> void:
	super._show_menu()
	# Version strings are supplied by the inherited menu, amended at the source.

func _begin(mode: String) -> void:
	# Preserve the current campaign state/economy initialization, replace only its briefing.
	super._begin(mode)
	story_flags["l1_intro_seen"] = true
	_start_arrival()
	_save_game()

func _start_arrival() -> void:
	actor_mode = "arrival_scene"
	intro_progress = 0
	var screen: Control = _new_overlay(0.12)
	hud.visible = false
	cinematic_camera = Camera3D.new()
	cinematic_camera.position = Vector3(0,2.4,12.5)
	cinematic_camera.fov = 64
	add_child(cinematic_camera)
	cinematic_camera.look_at(Vector3(0,2,-10))
	cinematic_camera.current = true
	var p: PanelContainer = _panel(screen,Vector2(210,610),Vector2(1180,210),Color("#242a29"))
	var col: VBoxContainer = _column(p,10)
	_make_label(col,"ПОСЛЕ ЗАКРЫТИЯ",34,Color("#eadbc1"))
	_make_label(col,"Вечер следующего дня. Профессор Сеитов погиб. Мира просит Алекса проверить то, что осталось в университете. Охрана не пускает внутрь.\nТелефон — на столике слева от входа. E / Esc — пропустить вступление.",21,Color("#e2ded3"),1090)

func _finish_arrival() -> void:
	if actor_mode != "arrival_scene": return
	if is_instance_valid(cinematic_camera): cinematic_camera.queue_free()
	player.set_camera_mode(player.first_person)
	_start_play()
	_toast("WASD — движение · E — осмотр · P — цели · H — помощь",6)

func _load_level(id: int) -> void:
	super._load_level(id)
	if id == 1:
		world.apply_state(state)
		rules.metrics(state,1)

func _update_navigation() -> void:
	if state.current != 1: super._update_navigation(); return
	nav_label.text = "[P] Этапы расследования  [Tab] Источники  [H] Подсказка  [M] Карта"
	if state.difficulty == "easy": nav_label.text += "\nОхрана — слева · западный терминал — справа · доска — у фасада слева"

func _interact() -> void:
	if state.current != 1: super._interact(); return
	var item: Dictionary = world.nearest_item(player.global_position,2.35)
	if item.is_empty(): return
	match str(item.kind):
		"source","rumour": _read_source(str(item.id))
		"drawer":
			if story_flags.get("l1_drawer_open",false): _read_source("l1_sensor")
			else:
				_sync_to_state()
				var outcome: Dictionary = rules.open_drawer(state)
				if outcome.ok:
					world.animate_drawer()
					_play_sfx("res://assets/audio/door_creak.ogg")
				_show_outcome(outcome,"ЯЩИК ОХРАНЫ")
		"terminal": _show_terminal()
		"deduction": _show_board("final" if story_flags.get("l1_route",false) else "route")
		"inspect": _show_inspector()
		"npc": _show_dialogue("Руслан")
		"gate":
			_sync_to_state()
			if rules.gate(state):
				world.animate_gate()
				_play_sfx("res://assets/audio/door_creak.ogg")
				_save_game()
				_toast("Допуск принят. Дверь открывается; пройди внутрь.",4)
			else: _story("ДВЕРЬ ЗАКРЫТА","Руслан выдаст допуск, когда ты предъявишь обоснованный итог расследования двора.")
		"exit": _advance()

func _read_source(id: String) -> void:
	_sync_to_state()
	var outcome: Dictionary = rules.read_source(state,id)
	_sync_from_state()
	_save_game()
	if outcome.ok: _play_sfx("res://assets/audio/pickup.ogg")
	_show_outcome(outcome,str(state.catalog.clue(id)[0]))

func _collect_evidence(id: String) -> void:
	if state.current == 1:
		_read_source(id)
	else: super._collect_evidence(id)

func _show_outcome(result: Dictionary, title: String = "РЕЗУЛЬТАТ ПРОВЕРКИ") -> void:
	_sync_from_state()
	_save_game()
	_story(title if result.ok else "ВЫВОД НЕ ПОДТВЕРЖДЁН",str(result.message)+("\n\nПосле повторных ошибок доступна поэтапная помощь H. Подсказки также учитываются в рейтинге." if result.get("hint_offer",false) else ""))

func _show_phone() -> void:
	if state.current != 1: super._show_phone(); return
	var col: VBoxContainer = _page("ТЕЛЕФОН / ПОСЛЕ ЗАКРЫТИЯ","phone")
	_make_label(col,"Установи, был ли корпус полностью закрыт. Наблюдение охранника и его вывод могут различаться.",22,Color("#e1d2b9"),1050)
	for stage in rules.spec.stages:
		var done: bool = evidence.has(stage[0]) or story_flags.get(stage[0],false)
		_make_label(col,("✓ " if done else "□ ")+str(stage[1]),19,Color("#a6b3a0") if done else Color("#e0ded3"),1050)
	var m: Dictionary = rules.metrics(state,1)
	_make_label(col,"Неверных выводов: %d · подсказок: %d · секретов: %d/2" % [m.mistakes,m.hints,m.optional.size()],20)
	_btn(col,"ОТКРЫТЬ ЖУРНАЛ ИСТОЧНИКОВ",Callable(self,"_show_journal"),1080)
	_make_label(col,"Необязательно: осмотри скамью и электрощит. Дополнительные находки влияют на оценку, но не запирают выход.",18,Color("#bcb9ac"),1050)

func _show_help() -> void:
	if state.current != 1:
		var m: Dictionary = rules.metrics(state,state.current)
		m.hints = int(m.hints)+1
		super._show_help()
		return
	var puzzle: String = "route"
	if story_flags.get("l1_route",false): puzzle = "clock"
	if story_flags.get("l1_time",false): puzzle = "message"
	if evidence.has("l1_message"): puzzle = "final"
	_sync_to_state()
	var tip: String = rules.hint(state,puzzle)
	_save_game()
	_story("ПОЭТАПНАЯ ПОДСКАЗКА",tip+"\n\nПолный список задач: P. Прочитанные источники: Tab. Подсказки снижают только бонусный рейтинг.")

func _show_challenge() -> void:
	if state.current == 1: _show_board("route"); return
	super._show_challenge()

func _answer_challenge(choice: int) -> void:
	if state.current == 1:
		_story("ТРЕБУЕТСЯ ДОКАЗАТЕЛЬСТВО","В этом расследовании нельзя завершить задачу выбором одной кнопки. На доске соедини источники с выводом.")
		return
	var d: Dictionary = state.catalog.level(state.current)
	var correct: int = 0 if state.difficulty == "hard" and question_stage == 1 else int(d.answer)
	if choice != correct:
		_sync_to_state()
		var why: String = "Этот способ проверки игнорирует независимость источников."
		if question_stage == 0 and choice >= 0 and choice < d.get("feedback",[]).size(): why = d.feedback[choice]
		_show_outcome(rules.error(state,state.current,"challenge",why))
		return
	super._answer_challenge(choice)

func _show_dialogue(npc: String) -> void:
	if state.current != 1: super._show_dialogue(npc); return
	current_npc = "Руслан"
	var col: VBoxContainer = _page("РУСЛАН / ПОКАЗАНИЯ И ПРЕДЪЯВЛЕНИЕ","dialogue")
	_make_label(col,"Руслан стоит у открытой будки. На столе неостывший чай; он старательно смотрит мимо здания.",19,Color("#bdbdaf"),1050)
	dialogue_text = _make_label(col,"«Внутрь пока нельзя. Скажи, что ты ищешь». Задай вопрос своими словами или предъяви найденные источники.",23,Color("#e4dccb"),1050)
	dialogue_input = LineEdit.new()
	dialogue_input.placeholder_text = "Например: когда вчера закрыли корпус?"
	dialogue_input.custom_minimum_size = Vector2(1080,48)
	dialogue_input.text_submitted.connect(_ask_npc)
	col.add_child(dialogue_input)
	_btn(col,"СПРОСИТЬ",Callable(self,"_submit_npc"),1080)
	_btn(col,"🎤 ЗАДАТЬ ВОПРОС ГОЛОСОМ",Callable(self,"_voice_question"),1080)
	_btn(col,"ПРЕДЪЯВИТЬ: РЕЖИМ ДРУГОГО ВХОДА",Callable(self,"_show_presentation").bind("drawer"),1080)
	_btn(col,"ПРЕДЪЯВИТЬ: ИТОГ И ЗАПРОСИТЬ ДОПУСК",Callable(self,"_show_presentation").bind("access"),1080)

func _scripted_answer(npc: String, query: String) -> String:
	if state.current != 1: return super._scripted_answer(npc,query)
	var q: String = query.to_lower()
	if "убий" in q or "винов" in q or "данияр" in q:
		return "Я не видел, кто причинил профессору травму. Закрытая дверь не даёт права обвинять человека."
	if "эхо" in q or "проект" in q or "памят" in q:
		return "Профессор говорил, что ЭХО должно помогать памяти. Но вчера он хотел говорить не о достижениях, а о пределах. Сначала установи, как вообще можно было попасть в корпус."
	if "камера" in q:
		return "Сейчас речь о входных дверях. Архив наблюдения хранится внутри; у меня нет подтверждённых данных перед глазами."
	if "час" in q or "время" in q or "когда" in q or "где" in q or "закр" in q or "алиби" in q or "вечер" in q or "двер" in q:
		_sync_to_state()
		var result: Dictionary = rules.witness(state,"statement")
		_sync_from_state()
		return result.message
	if "пропуск" in q or "допуск" in q or "журнал" in q or "улик" in q:
		return "Покажи документы, а не перескажи догадку. Используй предъявление: сначала объясни другой вход, затем запроси журнал."
	return "Я могу рассказать, когда закрыл центральный вход. Спроси о времени или о вчерашней лекции."

func _ask_npc(query: String) -> void:
	super._ask_npc(query)
	if state.current == 1 and is_instance_valid(dialogue_text):
		story_flags["l1_last_reply"] = dialogue_text.text
		_save_game()

func _show_board(kind: String) -> void:
	deduction_kind = kind
	board_mode = "deduction"
	selected_sources = story_flags.get("l1_draft_"+kind,[]).duplicate()
	_render_board()

func _show_presentation(topic: String) -> void:
	board_mode = topic
	selected_sources = story_flags.get("l1_draft_"+topic,[]).duplicate()
	_render_board()

func _render_board() -> void:
	var is_deduction: bool = board_mode == "deduction"
	var title: String = rules.spec.deductions[deduction_kind].title if is_deduction else ("РУСЛАН: ПРЕДЪЯВИТЬ ДВА ИСТОЧНИКА / "+board_mode.to_upper())
	var col: VBoxContainer = _page(title,"deduction")
	_make_label(col,"Соедини подходящие карточки с выводом. Нажатие на карточку добавляет/убирает связь. Лишние источники не принимаются как доказательство.",18,Color("#c9c2ae"),1050)
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(1080,410)
	col.add_child(canvas)
	var sources: Array = []
	for id in evidence:
		if str(id).begins_with("l1_") or id == "arrival": sources.append(id)
	for i in range(sources.size()):
		var id: String = str(sources[i])
		var pos := Vector2(float(i%2)*350, float(i/2)*62)
		if id in selected_sources:
			var line := Line2D.new()
			line.width = 2
			line.default_color = Color("#cbb891")
			line.points = PackedVector2Array([pos+Vector2(320,26),Vector2(790,200)])
			canvas.add_child(line)
		var button: Button = _btn(canvas,("✓ " if id in selected_sources else "")+str(state.catalog.clue(id)[0]),Callable(self,"_toggle_source").bind(id),320,15)
		button.position = pos
		button.size = Vector2(320,54)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var conclusion: PanelContainer = _panel(canvas,Vector2(790,145),Vector2(275,120),Color("#383c33"))
	_make_label(conclusion,"ИСТОЧНИКИ\n↓\nОБОСНОВАННЫЙ ВЫВОД",19,Color("#e9dabf"),230)
	if is_deduction:
		predicate_picker = OptionButton.new()
		for text_value in ["Корпус точно был полностью закрыт","Существовал доступ через другой вход","Есть основания проверить документы внутри","Это доказывает личность убийцы"]: predicate_picker.add_item(text_value)
		predicate_picker.selected = int(story_flags.get("l1_predicate_"+deduction_kind,0))
		predicate_picker.custom_minimum_size = Vector2(1080,44)
		predicate_picker.item_selected.connect(func(index: int): story_flags["l1_predicate_"+deduction_kind] = index; _save_game())
		col.add_child(predicate_picker)
		justification = TextEdit.new()
		justification.placeholder_text = "Твой комментарий к версии (необязательно). Проверяется связь карточек и утверждения; текст сохраняется в деле."
		justification.text = str(story_flags.get("l1_comment_"+deduction_kind,""))
		justification.custom_minimum_size = Vector2(1080,90)
		justification.text_changed.connect(func(): story_flags["l1_comment_"+deduction_kind] = justification.text.left(600))
		col.add_child(justification)
		_btn(col,"ПРОВЕРИТЬ ОБОСНОВАНИЕ",Callable(self,"_submit_deduction"),1080)
		if deduction_kind == "route" and story_flags.get("l1_route",false): _btn(col,"ПЕРЕЙТИ К ИТОГОВОЙ ВЕРСИИ",Callable(self,"_show_board").bind("final"),1080)
	else:
		_btn(col,"ПРЕДЪЯВИТЬ РУСЛАНУ",Callable(self,"_submit_presentation"),1080)
	_btn(col,"ПРОЧИТАТЬ ИСТОЧНИКИ В ЖУРНАЛЕ",Callable(self,"_show_journal"),1080)

func _toggle_source(id: String) -> void:
	if id in selected_sources: selected_sources.erase(id)
	else: selected_sources.append(id)
	story_flags["l1_draft_"+(deduction_kind if board_mode == "deduction" else board_mode)] = selected_sources.duplicate()
	_save_game()
	_render_board()

func _submit_deduction() -> void:
	_sync_to_state()
	var predicates: Array = ["closed","alternative","investigate","guilty"]
	var result: Dictionary = rules.deduce(state,deduction_kind,selected_sources,predicates[predicate_picker.selected],justification.text)
	_show_outcome(result,"СВЯЗЬ ДОКАЗАНА")

func _submit_presentation() -> void:
	_sync_to_state()
	_show_outcome(rules.witness(state,board_mode,selected_sources),"РУСЛАН / РЕАКЦИЯ")

func _show_terminal() -> void:
	var col: VBoxContainer = _page("WEST / СВЕРКА ВРЕМЕНИ","terminal")
	_make_label(col,"Журнал использует локальные часы контроллера. Переведи событие в университетское время перед проверкой сообщения.",23,Color("#e4d8c2"),1050)
	for id in ["l1_sensor","l1_clock"]:
		_make_label(col,str(state.catalog.clue(id)[1]) if evidence.has(id) else "Источник ещё не найден: "+str(state.catalog.clue(id)[0]),20,Color("#c9cbbd"),1050)
	var input := LineEdit.new()
	input.placeholder_text = "Университетское время события, ЧЧ:ММ"
	input.text = str(story_flags.get("l1_clock_draft",""))
	input.custom_minimum_size = Vector2(1080,48)
	input.text_changed.connect(func(value: String): story_flags["l1_clock_draft"] = value.left(5))
	input.text_submitted.connect(_submit_clock)
	col.add_child(input)
	_btn(col,"ПРОВЕРИТЬ ПОПРАВКУ",func(): _submit_clock(input.text),1080)
	var next: Button = _btn(col,"ВОССТАНОВИТЬ СООБЩЕНИЕ МИРЫ",Callable(self,"_show_packets"),1080)
	next.disabled = not story_flags.get("l1_time",false)
	if story_flags.get("l1_time",false): _make_label(col,"✓ 20:51 — синхронизация сохранена",21)

func _submit_clock(value: String) -> void:
	_sync_to_state()
	_show_outcome(rules.calibrate(state,value),"СВЕРКА ЧАСОВ")

func _show_packets() -> void:
	packet_order = story_flags.get("l1_packet_draft",[]).duplicate()
	_render_packets()

func _render_packets() -> void:
	var col: VBoxContainer = _page("ВОССТАНОВЛЕНИЕ / ПОДПИСАННЫЕ ПАКЕТЫ","packets")
	_make_label(col,"Собери пять фрагментов: первый начинается после START; поле «далее» должно совпасть с полем «после» следующего. Последний ведёт к END. Нажми фрагменты по порядку. Подпись должна быть действительна.",20,Color("#e3d6bd"),1050)
	_make_label(col,"Черновик: "+(" → ".join(packet_order) if not packet_order.is_empty() else "пусто"),20)
	for packet in rules.spec.packets:
		if not packet.valid and state.difficulty != "hard": continue
		var label: String = "%s · после %s → далее %s · подпись %s\n%s" % [packet.id,packet.prev,packet.next,"OK" if packet.valid else "НЕВЕРНА",packet.text]
		var b: Button = _btn(col,label,Callable(self,"_append_packet").bind(packet.id),1080,17)
		b.disabled = packet.id in packet_order
	_btn(col,"УБРАТЬ ПОСЛЕДНИЙ",Callable(self,"_remove_packet"),1080)
	_btn(col,"ПРОВЕРИТЬ ЦЕПОЧКУ",Callable(self,"_submit_packets"),1080)

func _append_packet(id: String) -> void:
	if packet_order.size() < 5 and not id in packet_order: packet_order.append(id)
	story_flags["l1_packet_draft"] = packet_order.duplicate()
	_save_game()
	_render_packets()

func _remove_packet() -> void:
	if not packet_order.is_empty(): packet_order.pop_back()
	story_flags["l1_packet_draft"] = packet_order.duplicate()
	_save_game()
	_render_packets()

func _submit_packets() -> void:
	_sync_to_state()
	var result: Dictionary = rules.restore_message(state,packet_order)
	_show_outcome(result,"СООБЩЕНИЕ ВОССТАНОВЛЕНО")

func _close_overlay() -> void:
	if actor_mode == "dialogue" and voice_active:
		_stop_voice()
	_save_game()
	if state.current == 1 and story_flags.get("l1_echo_pending",false):
		story_flags.erase("l1_echo_pending")
		story_flags["l1_echo_seen"] = true
		world.echo_event(not jumpscares_enabled)
		if jumpscares_enabled: _play_sfx("res://assets/audio/memory_whisper.ogg")
		_save_game()
		_story("ЭХО / НЕИЗВЕСТНЫЙ СЕАНС","Терминал на секунду выводит: «С возвращением, участник 021».\n\nАлекс: я не вводил ни имени, ни номера.\nРуслан, из будки: что у тебя там?\nАлекс закрывает служебное окно. Восстановленное сообщение сохранено; странная строка не доказывает вины ни одного человека.")
		return
	super._close_overlay()

func _advance() -> void:
	_sync_to_state()
	var pending: Array[String] = state.missing(state.current)
	if not pending.is_empty(): _story("РАССЛЕДОВАНИЕ НЕ ЗАВЕРШЕНО","Осталось: "+"; ".join(pending)); return
	if state.current == 20: super._advance(); return
	pending_summary_level = state.current
	var r: Dictionary = rules.report(state,state.current)
	var col: VBoxContainer = _page("ИТОГ УРОВНЯ / ОЦЕНКА "+str(r.grade),"level_summary")
	_make_label(col,"Качество обоснований: %d/100\nНеверные выводы: %d · подсказки: %d\nДополнительные находки: %d\nВремя активного расследования: %d мин %02d сек" % [r.quality,r.mistakes,r.hints,r.optional,int(r.seconds)/60,int(r.seconds)%60],23,Color("#e5d7c1"),1050)
	_make_label(col,"Обязательные источники:",21)
	for id in state.catalog.level(state.current).evidence: _make_label(col,"✓ "+str(state.catalog.clue(id)[0]),18)
	if state.current == 1:
		_make_label(col,"Дополнительно: "+("бейдж найден" if evidence.has("l1_badge") else "бейдж не найден")+"; "+("квитанция найдена" if evidence.has("l1_receipt") else "квитанция не найдена"),19)
		_make_label(col,str(rules.spec.outro),21,Color("#c8c7b6"),1050)
	else: _make_label(col,str(state.catalog.level(state.current).hint),21,Color("#c8c7b6"),1050)
	var payment: int = int(state.catalog.level(state.current).reward)+int(r.bonus)
	_make_label(col,"Награда при завершении: %d монет (база + рейтинг и секреты). Достижения начисляются отдельно." % (0 if state.replay or state.current in state.completed else payment),20,Color("#dfc69d"),1050)
	_btn(col,"ЗАВЕРШИТЬ И ПЕРЕЙТИ ДАЛЬШЕ",Callable(self,"_confirm_level"),1080)
	_make_label(col,"Назад — вернуться за необязательными находками. Награда выдаётся один раз.",17)

func _confirm_level() -> void:
	if state.current != pending_summary_level: return
	super._advance()

func _show_inspector() -> void:
	var col: VBoxContainer = _page("ОСМОТР / ПОТЁРТЫЙ БЕЙДЖ","inspection")
	_make_label(col,"Перетаскивай предмет мышью или используй ползунок. Колесо / второй ползунок — приближение. Ищи деталь на обратной стороне, затем зафиксируй наблюдение.",19,Color("#c8c5b4"),1050)
	var surface := SubViewportContainer.new()
	surface.custom_minimum_size = Vector2(1060,340)
	surface.stretch = true
	col.add_child(surface)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1060,340)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	surface.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#1c2427")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = 0.8
	environment.environment = env
	scene.add_child(environment)
	var light := OmniLight3D.new()
	light.position = Vector3(1,2,3)
	light.light_energy = 2
	scene.add_child(light)
	inspect_camera = Camera3D.new()
	inspect_camera.position.z = 3
	inspect_camera.current = true
	scene.add_child(inspect_camera)
	inspect_model = Node3D.new()
	scene.add_child(inspect_model)
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = Vector3(0.9,1.35,0.04)
	mesh.mesh = shape
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#a59a7c")
	mat.roughness = 0.85
	mesh.material_override = mat
	inspect_model.add_child(mesh)
	var front := Label3D.new()
	front.text = "УНИВЕРСИТЕТ\nГОСТЬ\n\nимя стёрто"
	front.position = Vector3(0,0.1,0.03)
	front.font_size = 25
	front.pixel_size = 0.005
	front.modulate = Color("#282d2a")
	inspect_model.add_child(front)
	var back := Label3D.new()
	back.text = "ЭХО\nУЧАСТНИК 021\n\nархивный пропуск"
	back.position = Vector3(0,-0.12,-0.03)
	back.rotation.y = PI
	back.font_size = 18
	back.pixel_size = 0.0045
	back.modulate = Color("#30332d")
	inspect_model.add_child(back)
	inspect_yaw = float(story_flags.get("l1_inspect_yaw",0))
	inspect_zoom = float(story_flags.get("l1_inspect_zoom",1))
	var rotate := HSlider.new()
	rotate.min_value = -180
	rotate.max_value = 180
	rotate.step = 1
	rotate.value = inspect_yaw
	rotate.value_changed.connect(func(value: float): inspect_yaw = value; _update_inspection())
	col.add_child(rotate)
	var zoom := HSlider.new()
	zoom.min_value = 0.8
	zoom.max_value = 1.8
	zoom.step = 0.05
	zoom.value = inspect_zoom
	zoom.value_changed.connect(func(value: float): inspect_zoom = value; _update_inspection())
	col.add_child(zoom)
	surface.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			rotate.value = wrapf(rotate.value+event.relative.x,-180,180)
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom.value += 0.1
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom.value -= 0.1)
	inspect_status = _make_label(col,"",19)
	_btn(col,"ЗАФИКСИРОВАТЬ ДЕТАЛЬ",Callable(self,"_confirm_inspection"),1080)
	_update_inspection()

func _update_inspection() -> void:
	if not is_instance_valid(inspect_model): return
	inspect_model.rotation.y = deg_to_rad(inspect_yaw)
	inspect_camera.position.z = 3.0/inspect_zoom
	story_flags["l1_inspect_yaw"] = inspect_yaw
	story_flags["l1_inspect_zoom"] = inspect_zoom
	inspect_status.text = "Поворот: %d° · увеличение %.2f×" % [int(inspect_yaw),inspect_zoom]

func _confirm_inspection() -> void:
	_sync_to_state()
	if rules.inspect_back(state,inspect_yaw,inspect_zoom):
		_show_outcome({"ok":true,"message":state.catalog.clue("l1_badge")[1]},"СКРЫТАЯ ДЕТАЛЬ НАЙДЕНА")
	else:
		inspect_status.text = "Деталь пока не видна достаточно чётко. Осмотри обратную сторону и приблизь. Осмотр не штрафуется."
