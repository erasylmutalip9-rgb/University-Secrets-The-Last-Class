extends "res://scripts/game.gd"

const CaseState = preload("res://scripts/campaign/state.gd")
const Manager = preload("res://scripts/campaign/level_manager.gd")
var state = CaseState.new()
var levels = Manager.new()
var question_stage: int = 0
var challenge_started: int = 0
var gesture_session: String = ""
var hints_this_level: int = 0
var secret_selected: bool = false
var cosmetics: Node3D
var llm_options: Array[String] = []
var ai_context: String = ""
var shop_return_to_menu: bool = false
var voice_active: bool = false
var voice_process_id: int = -1
var voice_result_path: String = ""
var voice_started_at: int = 0
var voice_for_npc: String = ""
var voice_status: Label
var casework_stage: Array[String] = []
var casework_feedback: Label
var challenge_feedback: Label
var casework_data: Dictionary = {}
var casework_catalog: Dictionary = {}
var camera_frame_http: HTTPRequest
var camera_preview: TextureRect
var camera_preview_elapsed: float = 0.0

func _ready() -> void:
	campaign_mode = true
	super._ready()
	_load_profile()
	_load_level(1)
	camera_frame_http = HTTPRequest.new()
	camera_frame_http.timeout = 2.5
	add_child(camera_frame_http)
	camera_frame_http.request_completed.connect(_camera_frame_received)
	var case_file: FileAccess = FileAccess.open("res://data/casework.json",FileAccess.READ)
	if case_file != null:
		var case_parsed: Variant = JSON.parse_string(case_file.get_as_text())
		if case_parsed is Dictionary: casework_catalog = case_parsed
	_show_menu()

func _register_actions() -> void:
	super._register_actions()
	_bind("level_map",[KEY_M])
	_bind("shop",[KEY_K])
	_bind("phone",[KEY_P])

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and actor_mode in ["map","shop","phone","challenge","casework","difficulty"]:
		if actor_mode == "difficulty": _show_menu()
		else: _close_overlay()
		get_viewport().set_input_as_handled()
		return
	if actor_mode == "playing":
		if event.is_action_pressed("level_map"): _show_map(); return
		if event.is_action_pressed("shop"): _show_shop(); return
		if event.is_action_pressed("phone"): _show_phone(); return
	super._unhandled_input(event)

func _page(title: String, mode: String) -> VBoxContainer:
	actor_mode = mode
	var screen: Control = _new_overlay(0.20 if mode == "menu" else 0.94)
	if mode == "menu":
		var artwork := TextureRect.new()
		artwork.texture = load("res://assets/ui/menu_art.png")
		artwork.set_anchors_preset(Control.PRESET_FULL_RECT)
		artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(artwork)
		screen.move_child(artwork,0)
	var menu_style: bool = mode == "menu"
	var panel: PanelContainer = _panel(screen,Vector2(65,62) if menu_style else Vector2(190,45),Vector2(880,775) if menu_style else Vector2(1220,810),Color(0.08,0.09,0.095,0.91) if menu_style else Color("#242a29"))
	var box: VBoxContainer = _column(panel,10)
	_make_label(box,title,30,Color("#e5d5bc"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(810,605) if mode == "menu" else Vector2(1150,640)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var content: VBoxContainer = _column(scroll,12)
	content.custom_minimum_size.x = 785 if mode == "menu" else 1125
	_btn(box,"НАЗАД",Callable(self,"_close_overlay"),1120,18)
	return content

func _show_menu() -> void:
	hud.visible = false
	var col: VBoxContainer = _page("ТАЙНЫ УНИВЕРСИТЕТА / ПОСЛЕДНЯЯ ПАРА","menu")
	_make_label(col,"КАМПАНИЯ · v0.11 · 20 уровней расследования",21)
	_make_label(col,"Алекс ищет убийцу профессора Сеитова. Исследуй 20 карт, сравнивай доказательства и проверяй алиби.",18,Color("#ded9cc"),765)
	_btn(col,"НОВАЯ КАМПАНИЯ",Callable(self,"_choose_difficulty"),770)
	_btn(col,"ПРОДОЛЖИТЬ КАМПАНИЮ",Callable(self,"_load_game"),770)
	_btn(col,"МАГАЗИН СКИНОВ И СНАРЯЖЕНИЯ",Callable(self,"_show_shop"),770)
	_btn(col,"НАСТРОЙКИ",Callable(self,"_show_settings"),770)
	_btn(col,"ВЫХОД",Callable(get_tree(),"quit"),770)
	_make_label(col,"20 бесплатных карт · монеты за расследования · M — уровни · P — телефон · K — магазин",16,Color("#c5c3b8"),770)
	# A menu must not expose the generic return-to-play button.
	col.get_parent().get_parent().get_child(2).hide()

func _choose_difficulty() -> void:
	var col: VBoxContainer = _page("НОВАЯ КАМПАНИЯ","difficulty")
	_make_label(col,"Начало новой кампании заменит текущий слот (предыдущая запись останется в .bak). Классическое сохранение не меняется.",20,Color("#d9c7a5"),1050)
	_btn(col,"ЛЕГКО — отметки предметов, подробные подсказки",Callable(self,"_begin").bind("easy"),1080)
	_btn(col,"НОРМАЛЬНО — подсказки по запросу",Callable(self,"_begin").bind("normal"),1080)
	_btn(col,"СЛОЖНО — дополнительная проверка, 3 подсказки на карту",Callable(self,"_begin").bind("hard"),1080)
	_btn(col,"ОТМЕНА",Callable(self,"_show_menu"),1080)
	col.get_parent().get_parent().get_child(2).hide()

func _new_game() -> void:
	_choose_difficulty()

func _begin(mode: String) -> void:
	var prefs: Dictionary = state.settings.duplicate()
	state = CaseState.new()
	state.difficulty = mode
	state.settings = prefs
	_sync_from_state()
	_load_level(1)
	_save_game()
	_save_profile()
	_start_play()
	_story("АЛЕКС / ДЕЛО №021", "Профессор Сеитов погиб. Мира прислала сообщение на телефон. Ты пришёл в университет вечером следующего дня.\n\nWASD — ходить, Shift — бег, Space — прыжок, мышь — осмотр. V — первое/третье лицо, R — выровнять камеру, F — фонарик.\n\nПодойди к телефону слева и нажми E. Исследуй рабочую станцию справа. После выполнения целей выход в конце двора откроет следующую карту. Tab — улики, P — цели, H — помощь, Esc — сохранение.")

func _sync_from_state() -> void:
	evidence = state.evidence
	story_flags = state.flags
	score = state.score
	chapter = mini(3, 1 + (state.current-1)/7)
	jumpscares_enabled = bool(state.settings.get("scares",true))
	demo_unlocked = true
	AudioServer.set_bus_volume_db(0,linear_to_db(float(state.settings.get("volume",0.7))))

func _sync_to_state() -> void:
	state.evidence = evidence
	state.flags = story_flags
	state.score = score

func _load_level(id: int) -> void:
	state.current = id
	_sync_from_state()
	if is_instance_valid(world) and not is_instance_valid(levels.active):
		remove_child(world)
		world.queue_free()
	world = levels.load_map(self,id)
	var d: Dictionary = state.catalog.level(id)
	player.campaign_bounds = Vector2(d.size[0]/2.0,d.size[1]/2.0)
	player.set_safe_spawn(world.get_node("Spawn").position)
	player.rotation = Vector3.ZERO
	player.reset_camera()
	player.set_camera_mode(player.first_person)
	for clue in evidence: world.set_item_hidden(str(clue))
	for key in story_flags.get("opened_cabinets",[]): world.open_container(str(key))
	world.set_guidance(state.difficulty == "easy")
	hints_this_level = int(story_flags.get("hints_%d" % id,0))
	_apply_equipment()
	_update_hud()

func _zone_name() -> String:
	return str(state.catalog.level(state.current).title)

func _update_hud() -> void:
	var d: Dictionary = state.catalog.level(state.current)
	chapter_label.text = "%02d / 20 · %s%s" % [state.current,d.title," · ПОВТОР" if state.replay else ""]
	var pending: Array[String] = state.missing(state.current)
	objective_label.text = "Готово. Пройди к выходу." if pending.is_empty() else "Цель: " + pending[0]
	score_label.text = "%d улик · %d монет" % [evidence.size(),state.coins]

func _update_navigation() -> void:
	nav_label.text = "[P] Телефон / цели   [M] Карты   [K] Магазин   [H] Помощь"
	if state.difficulty == "easy":
		nav_label.text += "\nОсмотри периметр: источники отмечены. Экспертиза и рабочая станция у правой стены."

func _next_target() -> Dictionary:
	return {}

func _show_help() -> void:
	if state.difficulty == "hard" and hints_this_level >= 3:
		_story("ПОДСКАЗКИ ИСЧЕРПАНЫ", "На сложном режиме доступно три подсказки на карту. Задание и найденные документы всегда доступны в телефоне P и журнале Tab. Ошибки не закрывают попытки.")
		return
	hints_this_level += 1
	story_flags["hints_%d" % state.current] = hints_this_level
	state.stats.hints = int(state.stats.get("hints",0))+1
	_save_game()
	_story("ПОМОЩЬ / " + _zone_name(),str(state.catalog.level(state.current).hint)+"\n\nWASD, Shift, Space — движение; E — взаимодействие; V — вид; R — камера; F — свет.\n\nИщи улики по периметру карты, проверь стол «ЭКСПЕРТИЗА», затем рабочую станцию. У закрытого шкафа первый E открывает дверцу, второй E забирает документ. На карте 11 код можно разгадать до флешки.\n\n"+"; ".join(state.missing(state.current)))

func _interact() -> void:
	var item: Dictionary = world.nearest_item(player.global_position,2.35)
	if item.is_empty(): return
	match str(item.kind):
		"exit": _advance()
		"challenge": _show_challenge()
		"casework": _show_casework()
		_: super._interact()

func _collect_evidence(id: String) -> void:
	if evidence.has(id): return
	if state.current == 11 and not story_flags.get("challenge_11",false):
		_toast("Шкаф заперт. Проверь код на рабочей станции справа.",4)
		return
	evidence[id] = true
	score += int(state.catalog.clue(id)[2])
	world.set_item_hidden(id)
	_play_sfx("res://assets/audio/pickup.ogg")
	_save_game()
	_story(str(state.catalog.clue(id)[0]),str(state.catalog.clue(id)[1]))
	if id == "alex_file" and not story_flags.get("campaign_scare",false):
		story_flags["campaign_scare"] = true
		story_flags["memory_scare_pending"] = true

func _check_lab_progress() -> void:
	pass # Campaign progression is exclusively controlled by LevelManager.

func _show_challenge() -> void:
	if state.current > 1 and not story_flags.get("casework_%d" % state.current,false):
		_toast("Сначала проведи отдельную экспертизу на столе «ЭКСПЕРТИЗА».",5)
		return
	question_stage = 0
	challenge_started = Time.get_ticks_msec()
	_render_challenge()

func _render_challenge() -> void:
	var d: Dictionary = state.catalog.level(state.current)
	var col: VBoxContainer = _page("РАБОЧАЯ СТАНЦИЯ / " + str(d.title),"challenge")
	var hard_extra: bool = state.difficulty == "hard" and question_stage == 1
	_make_label(col,"Проверка выполнена — можно повторить без дополнительной награды." if story_flags.get("challenge_%d" % state.current,false) else "Сопоставь найденные материалы. Попытки не ограничены.",18,Color("#c5c3b8"),1050)
	_make_label(col,"Какая проверка защищает от ложного вывода?" if hard_extra else str(d.question),25,Color("#f0e5d1"),1050)
	var options: Array = ["Сверить независимые источники и их время","Принять первое объяснение","Игнорировать противоречие"] if hard_extra else d.options
	for i in range(options.size()): _btn(col,str(options[i]),Callable(self,"_answer_challenge").bind(i),1080,19)
	challenge_feedback = _make_label(col,"Проверяй варианты по найденным уликам.",18,Color("#d4bfa6"),1050)
	if state.difficulty == "easy": _make_label(col,str(d.hint),19,Color("#d3c39c"),1050)
	if state.difficulty == "hard": _make_label(col,"Необязательный бонус: верное решение за 45 секунд. Истечение времени не блокирует уровень.",18,Color("#b5beb4"),1050)

func _answer_challenge(choice: int) -> void:
	var d: Dictionary = state.catalog.level(state.current)
	var correct: int = 0 if state.difficulty == "hard" and question_stage == 1 else int(d.answer)
	if choice != correct:
		state.stats.mistakes = int(state.stats.get("mistakes",0))+1
		_save_game()
		var reasons: Array = d.get("feedback",[])
		var reason: String = str(reasons[choice]) if choice >= 0 and choice < reasons.size() and not str(reasons[choice]).is_empty() else str(d.hint)
		if is_instance_valid(challenge_feedback):
			challenge_feedback.text = "НЕВЕРНО / ОШИБКА №%d. %s" % [int(state.stats.get("mistakes",0)),reason]
		_toast("Неверный вывод: проверь объяснение под вариантами.",4)
		return
	if state.difficulty == "hard" and question_stage == 0:
		question_stage = 1
		_render_challenge()
		return
	story_flags["challenge_%d" % state.current] = true
	if state.current == 8: story_flags["power_fixed"] = true
	if state.current == 12: story_flags["scan_done"] = true
	if state.difficulty == "hard" and Time.get_ticks_msec()-challenge_started < 45000:
		state.award("quick_%d" % state.current,20)
	_save_game()
	_story("ПРОВЕРКА ЗАВЕРШЕНА",str(d.hint)+"\n\n"+("Все цели выполнены. Иди к выходу." if state.missing(state.current).is_empty() else "Осталось: "+"; ".join(state.missing(state.current))))

func _advance() -> void:
	_sync_to_state()
	var pending: Array[String] = state.missing(state.current)
	if not pending.is_empty():
		_story("УРОВЕНЬ ЕЩЁ НЕ ЗАВЕРШЁН","Осталось: "+"; ".join(pending))
		return
	if state.current == 20: _show_final(); return
	if not state.complete_level(): return
	if state.replay:
		_return_from_replay()
		return
	var reward: int = int(state.catalog.level(state.current).reward)
	_load_level(state.current+1)
	_save_game()
	_start_play()
	_toast("Новая карта: "+_zone_name()+" · награда +%d монет" % reward,5)

func _show_map() -> void:
	var col: VBoxContainer = _page("КАРТА РАССЛЕДОВАНИЯ / 20 УРОВНЕЙ","map")
	_make_label(col,"Пройденные карты доступны для повторения. Повтор не меняет основной слот, улики и баланс.",18,Color("#c5c3b8"),1050)
	if state.replay: _btn(col,"ВЕРНУТЬСЯ В ОСНОВНОЕ РАССЛЕДОВАНИЕ",Callable(self,"_return_from_replay"),1080)
	for i in range(1,21):
		var status: String = "ПРОЙДЕНО" if i in state.completed else ("ТЕКУЩИЙ" if i == state.current else "ЗАКРЫТО")
		var b: Button = _btn(col,"%02d · %s · %s" % [i,state.catalog.level(i).title,status],Callable(self,"_replay_level").bind(i),1080,18)
		b.disabled = not i in state.completed or state.replay

func _replay_level(id: int) -> void:
	_sync_to_state()
	if state.begin_replay(id):
		_load_level(id)
		_start_play()
		_toast("Повтор карты. M — вернуться к основному прогрессу.",5)

func _return_from_replay() -> void:
	state.end_replay()
	_load_level(state.current)
	_start_play()
	_toast("Основной прогресс восстановлен.")

func _show_phone() -> void:
	var col: VBoxContainer = _page("ТЕЛЕФОН АЛЕКСА / ДЕЛО 021","phone")
	_make_label(col,_zone_name(),26)
	for task in state.missing(state.current): _make_label(col,"□ "+task,21)
	if state.missing(state.current).is_empty(): _make_label(col,"✓ Цели выполнены. Найди выход.",21)
	_make_label(col,"Предъявление на допросе: пропуск → вопрос «Почему вход в 21:17?»; копия → «Чья копия?»; камеры → «Почему отключены?»; удаление → «Что было в 21:26?».",19,Color("#c5c3b8"),1050)
	_make_label(col,"Статистика: вопросов %d · ошибок %d · подсказок %d" % [int(state.stats.get("questions",0)),int(state.stats.get("mistakes",0)),int(state.stats.get("hints",0))],20)
	_make_label(col,"Достижения: "+str(state.achievements),19,Color("#c5c3b8"),1050)
	_btn(col,"СОПОСТАВИТЬ ДВА ИСТОЧНИКА (необязательно)",Callable(self,"_compare_sources"),1080)
	_btn(col,"КАРТА УРОВНЕЙ",Callable(self,"_show_map"),1080)

func _compare_sources() -> void:
	var col: VBoxContainer = _page("ДОСКА СОПОСТАВЛЕНИЯ","phone")
	_make_label(col,"Какая пара независимо проверяет присутствие в лаборатории?",24,Color.WHITE,1050)
	for pair in [["pass","trace"],["note","old_photo"],["register","arrival"]]:
		var label: String = str(state.catalog.clue(pair[0])[0])+" + "+str(state.catalog.clue(pair[1])[0])
		var b: Button = _btn(col,label,Callable(self,"_compare_answer").bind(pair[0],pair[1]),1080,19)
		b.disabled = not evidence.has(pair[0]) or not evidence.has(pair[1])
	_make_label(col,"Недоступная пара откроется после сбора обоих источников.",18)

func _compare_answer(a: String, b: String) -> void:
	if a == "pass" and b == "trace":
		state.award("corroboration",80)
		story_flags["corroborated"] = true
		_save_game()
		_story("НЕЗАВИСИМОЕ ПОДТВЕРЖДЕНИЕ","Электронный журнал и физический обломок подтверждают присутствие. Одного пропуска было бы недостаточно.")
	else: _toast("Эта пара не проверяет присутствие в лаборатории.",4)

func _show_journal() -> void:
	var col: VBoxContainer = _page("ЖУРНАЛ РАССЛЕДОВАНИЯ","journal")
	if state.equipped.get("journal","") == "journal": col.modulate = Color("#e7cda7")
	_make_label(col,"Найдено %d улик · %d XP" % [evidence.size(),score],20)
	for id in evidence:
		var clue: Array = state.catalog.clue(str(id))
		_make_label(col,str(clue[0]),23,Color("#e2c9a2"))
		_make_label(col,str(clue[1]),19,Color("#deded5"),1050)
	_make_label(col,"История последних допросов",24)
	for entry in story_flags.get("dialogue_log",[]): _make_label(col,str(entry),18,Color("#bfc6ba"),1050)

func _scripted_answer(npc: String, query: String) -> String:
	# Early witnesses cannot reveal late facts just because a player names them.
	if state.current < 6 and ("данияр" in query.to_lower() or "убий" in query.to_lower()):
		return "У меня нет подтверждённых фактов для обвинения. Проверь материалы последней лекции и библиотеку."
	if state.current < 13 and npc == "Мира" and "данияр" in query.to_lower():
		return "Мы спорили о данных. Документы надёжнее моих предположений."
	return super._scripted_answer(npc,query)

func _ask_npc(query: String) -> void:
	if query.strip_edges().is_empty(): return
	super._ask_npc(query)
	story_flags["talk_%d" % state.current] = true
	state.stats.questions = int(state.stats.get("questions",0))+1
	var history: Array = story_flags.get("dialogue_log",[])
	history.append(current_npc+" ← "+query.left(250))
	if history.size() > 16: history.pop_front()
	story_flags["dialogue_log"] = history
	_save_game()

func _generate_ai_reply(npc: String, query: String, canon: String) -> void:
	# Constrained LLM selection: untrusted generated text never becomes a fact.
	pending_scripted_answer = npc+": «"+canon+"»"
	llm_options = [canon, "Я отвечу только за известные мне факты. "+canon]
	ai_context = "%d:%s" % [state.current,npc]
	if is_instance_valid(pending_request): pending_request.queue_free()
	pending_request = HTTPRequest.new()
	pending_request.timeout = 5
	add_child(pending_request)
	pending_request.request_completed.connect(_llm_finished)
	var payload: String = JSON.stringify({"model":"gemma3:4b","stream":false,"format":"json","prompt":"Выбери тон ответа для персонажа. Верни только JSON {\"choice\":0} или {\"choice\":1}. Факты менять нельзя. Вопрос: "+query+". Варианты: "+JSON.stringify(llm_options),"options":{"temperature":0.1,"num_predict":20}})
	var err: int = pending_request.request("http://127.0.0.1:11434/api/generate",["Content-Type: application/json"],HTTPClient.METHOD_POST,payload)
	dialogue_text.text = pending_scripted_answer+"\n[Локальный NLP; Ollama выбирает тон ответа]"
	if err != OK: dialogue_text.text = pending_scripted_answer+"\n[Автономный режим]"

func _llm_finished(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if actor_mode != "dialogue" or not is_instance_valid(dialogue_text) or ai_context != "%d:%s" % [state.current,current_npc]: return
	var index: int = 0
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if code == 200 and data is Dictionary:
		var reply: Variant = JSON.parse_string(str(data.get("response","")))
		if reply is Dictionary and int(reply.get("choice",-1)) in [0,1]: index = int(reply.choice)
	dialogue_text.text = current_npc+": «"+llm_options[index]+"»\n[Канонический ответ; генерация не добавляет фактов]"

func _show_timeline() -> void:
	if state.current != 19: return
	timeline_sequence.clear()
	gesture_last_event = -1
	gesture_primed = false
	gesture_poll_time = 0
	_start_gestures_if_needed()
	_render_timeline()

func _render_timeline() -> void:
	var col: VBoxContainer = _page("РЕКОНСТРУКЦИЯ / ПЯТЬ СОБЫТИЙ","timeline")
	_make_label(col,"Выстрой события по времени. Выбрано %d из 5. После каждого выбора список сокращается." % timeline_sequence.size(),22,Color.WHITE,1050)
	_make_label(col,"Пять жестов: ✊ кулак — 1, ✌ два пальца — 2, ✋ ладонь — 3, 👍 лайк — 4, ☝ указательный палец — 5. Мышь — резервное управление.",18,Color("#c5c3b8"),1050)
	var choices: Array[String] = _remaining_events()
	var names: Dictionary = {"down":"Отключение камер", "pass":"Вход Данияра", "injury":"Конфликт и смертельная травма", "delete":"Попытка удаления данных", "up":"Восстановление наблюдения"}
	for i in range(choices.size()):
		_btn(col,"%d · %s" % [i+1,names[choices[i]]],Callable(self,"_timeline_press").bind(choices[i]),1080,19)
	gesture_status_label = _make_label(col,"Камера: подключение… Первая настройка может требовать интернет; см. camera_diagnostics.txt.",18,Color("#d4bf9e"),1050)
	var frame_row := HBoxContainer.new()
	col.add_child(frame_row)
	camera_preview = TextureRect.new()
	camera_preview.custom_minimum_size = Vector2(292,175)
	camera_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	camera_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame_row.add_child(camera_preview)
	_btn(frame_row,"ПОВТОРНО ПОДКЛЮЧИТЬ AI-КАМЕРУ",Callable(self,"_reconnect_camera"),770,16)

func _remaining_events() -> Array[String]:
	var result: Array[String] = []
	for id in ["delete","down","pass","up","injury"]:
		if not id in timeline_sequence: result.append(id)
	return result

func _timeline_press(event_id: String) -> void:
	if event_id in timeline_sequence: return
	timeline_sequence.append(event_id)
	if timeline_sequence.size() < 5:
		_render_timeline()
		return
	if timeline_sequence == ["down","pass","injury","delete","up"]:
		story_flags["timeline_solved"] = true
		_save_game()
		_story("ХРОНОЛОГИЯ ВОССТАНОВЛЕНА","21:08 — камеры отключены.\n21:17 — вошёл Данияр.\n21:22 — конфликт и смертельная травма.\n21:26 — попытка удаления данных.\n21:36 — наблюдение восстановлено.")
	else:
		state.stats.mistakes = int(state.stats.get("mistakes",0))+1
		_save_game()
		_story("ПРОВЕРЬ ВРЕМЕННЫЕ МЕТКИ","Последовательность не совпадает с журналами. Открой Tab, сверь время и вернись к стенду. Попытки не ограничены.")

func _gesture_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if actor_mode != "timeline" or not is_instance_valid(gesture_status_label): return
	if response_code != 200:
		var report: String = ProjectSettings.globalize_path("res://ai_service/camera_diagnostics.txt")
		if not OS.has_feature("editor"):
			report = OS.get_executable_path().get_base_dir().path_join("ai_service/camera_diagnostics.txt")
		var last_line: String = ""
		if FileAccess.file_exists(report):
			var contents: String = FileAccess.get_file_as_string(report)
			var lines: PackedStringArray = contents.strip_edges().split("\n")
			if lines.size() > 0: last_line = lines[-1].left(170)
		gesture_status_label.text = "Камера: сервис готовится или недоступен. "+last_line+" Мышь доступна."
		if Time.get_ticks_msec() - gesture_last_launch_ms > 120000:
			gesture_autostart_attempted = false
			_start_gestures_if_needed()
		return
	var payload: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not payload is Dictionary: return
	gesture_status_label.text = "Камера: "+str(payload.get("status","нет статуса"))+" · "+str(payload.get("gesture",""))
	if not bool(payload.get("active",false)) or str(payload.get("mode","")) != "webcam": return
	var session: String = str(payload.get("session_id",""))
	if gesture_session != session:
		gesture_session = session
		gesture_primed = false
	var event: int = int(payload.get("event_id",-1))
	if not gesture_primed:
		gesture_primed = true
		gesture_last_event = event # Never consume a stale gesture from before opening the board.
		return
	if event <= gesture_last_event: return
	gesture_last_event = event
	if float(payload.get("confidence",0)) < 0.67: return
	var slot: int = int({"Closed_Fist":0,"Victory":1,"Open_Palm":2,"Thumb_Up":3,"Pointing_Up":4}.get(str(payload.get("gesture","")),-1))
	var remaining: Array[String] = _remaining_events()
	if slot >= 0 and slot < remaining.size(): _timeline_press(remaining[slot])

func _show_final() -> void:
	if state.current != 20 or not state.missing(20).is_empty():
		_story("ДОСЬЕ НЕ ГОТОВО","Заверши цели текущей карты: "+"; ".join(state.missing(state.current)))
		return
	var col: VBoxContainer = _page("ПОСЛЕДНЯЯ ПАРА / ИТОГОВОЕ ДОСЬЕ","final")
	for row in [["Мотив","message","motive"],["Возможность","pass","security"],["Присутствие","trace","injury"],["Сокрытие","audit","usb"]]:
		_make_label(col,"%s: %s + %s" % [row[0],state.catalog.clue(row[1])[0],state.catalog.clue(row[2])[0]],20,Color("#dfd6c4"),1050)
	_make_label(col,"Противоречия: алиби и попытка удаления проверены на допросе. Можно вернуться к свидетелям через «Назад».",19,Color("#c5c3b8"),1050)
	var secret := CheckButton.new()
	secret.text = "Раскрыть также прошлое Алекса (секретный эпилог)"
	secret.button_pressed = secret_selected
	secret.toggled.connect(func(value: bool): secret_selected = value)
	col.add_child(secret)
	for who in ["Мира","Руслан","Данияр","none"]:
		_btn(col,"Оставить дело нераскрытым" if who == "none" else "Обвинить: "+who,Callable(self,"_finish_case").bind(who),1080,19)

func _finish_case(accused: String) -> void:
	if state.current != 20 or not state.missing(20).is_empty(): return
	_sync_to_state()
	var ending: String = state.ending(accused,secret_selected)
	if ending == "insufficient":
		_story("НЕДОСТАТОЧНО ДОКАЗАТЕЛЬСТВ","Проверь мотив, пропуск, след, журнал правок и носитель. Спроси Данияра о пропуске и удалении в 21:26. При импорте старого сохранения пройди новые карты последовательно.")
		return
	story_flags["ending"] = ending
	if not state.complete_level(): return
	state.award("ending_"+ending,100)
	_save_game()
	var text_by_ending: Dictionary = {
		"correct":"ИСТИНА ВОССТАНОВЛЕНА\nДанияр подменял данные, конфликтовал с профессором, оказался у лаборатории и пытался удалить следы. Независимые доказательства и противоречие алиби завершили цепочку.",
		"secret":"ИСТИНА, КОТОРУЮ СТЁРЛИ\nДанияр разоблачён. Дело №021 раскрывает участие Алекса в эксперименте памяти. Расследование гибели профессора завершено, но история ЭХО ещё не окончена.",
		"wrong":"ОШИБОЧНОЕ ОБВИНЕНИЕ\nТайна подозреваемого оказалась не доказательством убийства. Версия не выдержала проверки. Дело можно повторно рассмотреть через карту уровней.",
		"unresolved":"ТАЙНА ОСТАЛАСЬ\nАлекс не предъявил обвинение. Собранные материалы сохранены. Вернуться к делу можно через карту уровней."
	}
	var col: VBoxContainer = _page("ДЕЛО №021 / ИТОГ","ending")
	_make_label(col,str(text_by_ending[ending]),27,Color("#ead9be"),1050)
	_make_label(col,"Улики: %d · XP: %d · монеты: %d" % [evidence.size(),score,state.coins],22)
	_btn(col,"КАРТА УРОВНЕЙ",Callable(self,"_show_map"),1080)
	_btn(col,"ГЛАВНОЕ МЕНЮ",Callable(self,"_show_menu"),1080)

func _show_shop() -> void:
	if actor_mode != "shop":
		shop_return_to_menu = actor_mode == "menu"
		if shop_return_to_menu and FileAccess.file_exists(CaseState.SAVE):
			# Read the current wallet from the save; never reset purchases in the menu.
			state.load_from()
	var col: VBoxContainer = _page("СНАРЯЖЕНИЕ ДЕТЕКТИВА / %d МОНЕТ" % state.coins,"shop")
	_make_label(col,"Монеты за уровни, секреты и точные выводы. Предметы косметические; все 20 карт доступны бесплатно.",18,Color("#c5c3b8"),1080)
	for id in CaseState.SHOP:
		var item: Dictionary = CaseState.SHOP[id]
		var owned: bool = id in state.purchases
		var worn: bool = state.equipped.get(item.slot,"") == id
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation",12)
		col.add_child(line)
		var swatch := ColorRect.new()
		swatch.color = Color(str(item.get("color","#80796b")))
		swatch.custom_minimum_size = Vector2(66,47)
		line.add_child(swatch)
		var b: Button = _btn(line,str(item.name)+( " · НАДЕТО" if worn else (" · НАДЕТЬ" if owned else " · %d монет" % item.price)),Callable(self,"_buy").bind(id),970,17)
		b.disabled = state.replay or worn or (not owned and state.coins < int(item.price))
	_make_label(col,"КОЛЛЕКЦИОННЫЕ ОБРАЗЫ / ПЛАНИРУЕМЫЕ DLC",22,Color("#e5d5bc"))
	_make_label(col,"Ночной следователь — 399 ₸ · Теневой агент ЭХО — 690 ₸ · Легенда университета — 1090 ₸",19,Color("#d3c8b7"),1080)
	_make_label(col,"ДЕМОНСТРАЦИЯ ЦЕН: эти образы не продаются, платежей нет, деньги не списываются. Это концепция будущей монетизации.",17,Color("#cfb88d"),1080)
	if shop_return_to_menu:
		_btn(col,"ВЕРНУТЬСЯ В ГЛАВНОЕ МЕНЮ",Callable(self,"_show_menu"),1080)
		col.get_parent().get_parent().get_child(2).hide()

func _buy(id: String) -> void:
	if state.buy(id):
		_apply_equipment()
		if shop_return_to_menu:
			state.save_to() # Do not overwrite saved evidence from unloaded game world.
		else:
			_save_game()
	_show_shop()

func _apply_equipment() -> void:
	var skin: String = str(state.equipped.get("skin","classic"))
	player.visual.set_coat_color(Color(CaseState.SHOP[skin].color))
	player.flashlight.light_color = Color("#ffce8c") if state.equipped.get("light","") == "warm_light" else Color("#fff1d8")
	if is_instance_valid(cosmetics): cosmetics.free()
	cosmetics = Node3D.new()
	player.visual.add_child(cosmetics)
	var accessory: String = str(state.equipped.get("accessory",""))
	if accessory == "backpack": _cosmetic_box(Vector3(0,1.23,0.26),Vector3(0.43,0.52,0.21),Color("#604f3f"))
	if accessory == "watch": _cosmetic_box(Vector3(-0.41,0.95,-0.05),Vector3(0.11,0.10,0.12),Color("#b9ac8b"))
	player.skate_mode = state.current == 1 and state.equipped.get("transport","") == "skateboard"
	if player.skate_mode:
		_cosmetic_box(Vector3(0,0.05,0),Vector3(0.32,0.06,0.85),Color("#665340"))
		for x in [-0.14,0.14]:
			for z in [-0.3,0.3]: _cosmetic_box(Vector3(x,0.015,z),Vector3(0.09,0.06,0.1),Color("#363a36"))
	if state.equipped.get("board","") == "board":
		for item in world.items:
			if item.id in ["challenge","timeline"] and item.has("visual"): _darken_board(item.visual)

func _cosmetic_box(at: Vector3, size_value: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size_value
	mesh.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh.material_override = material
	mesh.layers = 2
	mesh.position = at
	cosmetics.add_child(mesh)

func _show_pause() -> void:
	var col: VBoxContainer = _page("ПАУЗА / " + _zone_name(),"pause")
	_btn(col,"СОХРАНИТЬ",Callable(self,"_manual_save"),1080)
	_btn(col,"КАРТА УРОВНЕЙ",Callable(self,"_show_map"),1080)
	_btn(col,"ЖУРНАЛ",Callable(self,"_show_journal"),1080)
	_btn(col,"СНАРЯЖЕНИЕ",Callable(self,"_show_shop"),1080)
	_btn(col,"НАСТРОЙКИ",Callable(self,"_show_settings"),1080)
	_btn(col,"ГЛАВНОЕ МЕНЮ",Callable(self,"_show_menu"),1080)

func _show_settings() -> void:
	if actor_mode != "settings": settings_origin = actor_mode
	var col: VBoxContainer = _page("НАСТРОЙКИ","settings")
	_make_label(col,"Громкость",24)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.05
	slider.value = float(state.settings.get("volume",0.7))
	col.add_child(slider)
	slider.value_changed.connect(func(value: float):
		state.settings.volume = value
		AudioServer.set_bus_volume_db(0,linear_to_db(value))
		_save_profile())
	_btn(col,"РЕЗКИЕ ЭФФЕКТЫ: "+("ВКЛ" if jumpscares_enabled else "ВЫКЛ"),Callable(self,"_toggle_scares"),1080)
	_btn(col,"OLLAMA: "+("ВКЛ" if llm_enabled else "ВЫКЛ")+" (необязательный выбор тона)",Callable(self,"_toggle_llm"),1080)
	_make_label(col,"NLP-допросы работают автономно. Сложность кампании: "+state.difficulty+". Меняется при старте новой кампании.",19,Color("#c5c3b8"),1050)
	_btn(col,"ВЕРНУТЬСЯ",Callable(self,"_show_menu") if settings_origin == "menu" else Callable(self,"_show_pause"),1080)
	col.get_parent().get_parent().get_child(2).hide()

func _toggle_scares() -> void:
	jumpscares_enabled = not jumpscares_enabled
	state.settings.scares = jumpscares_enabled
	_save_profile()
	_show_settings()

func _toggle_llm() -> void:
	llm_enabled = not llm_enabled
	_save_profile()
	_show_settings()

func _trigger_horror() -> void:
	if not jumpscares_enabled:
		_toast("В журнале проступило воспоминание о деле №021.",4)
		return
	super._trigger_horror()

func _save_profile() -> void:
	state.write_json(CaseState.PROFILE,{"settings":state.settings,"difficulty":state.difficulty,"llm":llm_enabled})

func _load_profile() -> void:
	if not FileAccess.file_exists(CaseState.PROFILE): return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CaseState.PROFILE))
	if not data is Dictionary: return
	if data.get("settings") is Dictionary: state.settings = data.settings
	llm_enabled = bool(data.get("llm",false))
	_sync_from_state()

func _save_game() -> void:
	_sync_to_state()
	if not state.save_to(): _toast(state.last_error,6)

func _manual_save() -> void:
	_sync_to_state()
	if state.replay:
		_toast("Повтор не перезаписывает основное расследование.",4)
		return
	if state.save_to():
		_close_overlay()
		_toast("Сохранено. Загрузка вернёт к безопасному входу на текущую карту.",4)
	else: _toast(state.last_error,6)

func _load_game() -> void:
	if not state.load_from():
		_toast(state.last_error,6)
		return
	_load_profile()
	_load_level(state.current)
	_start_play()
	_toast("Прогресс загружен. Позиция — безопасный вход текущей карты.",4)

func _import_legacy() -> void:
	var col: VBoxContainer = _page("ИМПОРТ СТАРОГО РАССЛЕДОВАНИЯ","difficulty")
	_make_label(col,"Импорт переносит улики, XP и сюжетные флаги. Новые карты начинаются с двора. Текущий слот кампании заменяется с резервной копией. Старый файл остаётся нетронутым.",22,Color.WHITE,1050)
	_btn(col,"ИМПОРТИРОВАТЬ",Callable(self,"_do_import"),1080)
	_btn(col,"ОТМЕНА",Callable(self,"_show_menu"),1080)
	col.get_parent().get_parent().get_child(2).hide()

func _do_import() -> void:
	if not FileAccess.file_exists(SAVE_PATH): _toast("Старое сохранение не найдено.",5); return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary or not data.get("evidence") is Dictionary or not data.get("story_flags") is Dictionary:
		_toast("Старое сохранение повреждено. Импорт отменён.",5)
		return
	state = CaseState.new()
	state.migrate_legacy(data)
	_load_level(1)
	_save_game()
	_start_play()
	_story("ИМПОРТ ЗАВЕРШЁН","Старые улики сохранены. Пройди новые карты с первой: старые три главы не заменяют задания новой кампании.")

func _darken_board(node: Node) -> void:
	if node is MeshInstance3D and node.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = node.material_override.duplicate()
		if mat.albedo_color.r < 0.7:
			mat.albedo_color = Color("#473a2c")
			node.material_override = mat
	for child in node.get_children(): _darken_board(child)

func _exit_tree() -> void:
	_stop_voice()
	if gesture_process_id > 0: OS.kill(gesture_process_id)
	for ap in [music,sound_fx,footstep_audio,whisper_audio]:
		if is_instance_valid(ap):
			ap.stop()
			ap.stream = null

# Per-map investigation is fully stateful: no silent wrong answers, no game-over traps.
func _show_casework() -> void:
	if state.current <= 1: return
	if story_flags.get("casework_%d" % state.current,false):
		_story("ЭКСПЕРТИЗА ЗАВЕРШЕНА","Эта задача уже выполнена. Вывод занесён в дело; можно перейти к рабочей станции.")
		return
	var id: String = str(state.current)
	if not casework_catalog.has(id):
		_toast("Описание экспертизы отсутствует для этой карты.",5)
		return
	for evidence_id in state.catalog.level(state.current).evidence:
		# Level 11's USB is locked behind the station. Never create a dependency cycle.
		if state.current == 11 and str(evidence_id) == "usb": continue
		if not evidence.has(str(evidence_id)):
			_toast("Для экспертизы сначала найди обязательную улику: "+str(state.catalog.clue(str(evidence_id))[0]),5)
			return
	casework_data = casework_catalog[id]
	casework_stage.clear()
	_render_casework("")

func _render_casework(message: String) -> void:
	var data: Dictionary = casework_data
	var col: VBoxContainer = _page("ЭКСПЕРТИЗА / %s" % str(data.get("title","Дело")),"casework")
	_make_label(col,str(data.get("intro","")),22,Color("#ded8c9"),1080)
	_make_label(col,"ПОДТВЕРЖДЁННЫЕ ИСТОЧНИКИ",19,Color("#d2ba91"))
	for id in state.catalog.level(state.current).evidence:
		_make_label(col,"• "+str(state.catalog.clue(str(id))[0])+" — "+str(state.catalog.clue(str(id))[1]).left(130),16,Color("#b8c9c2"),1050)
	var kind: String = str(data.get("kind","pairs"))
	if kind == "code":
		var input := LineEdit.new()
		input.custom_minimum_size = Vector2(570,55)
		input.placeholder_text = "Введи код из документов без пробелов"
		col.add_child(input)
		input.text_submitted.connect(_casework_code)
		_btn(col,"ПРОВЕРИТЬ КОД",func(): _casework_code(input.text),950,19)
	elif kind == "sequence":
		_make_label(col,"Выбери этапы в правильном порядке (%d/%d)." % [casework_stage.size(),data.correct.size()],19)
		var choices: Array = data.get("options",[])
		for i in range(choices.size()):
			if not str(i) in casework_stage:
				_btn(col,str(choices[i]),Callable(self,"_casework_choice").bind(i),1050,17)
	else:
		for i in range(data.get("options",[]).size()):
			_btn(col,str(data.options[i]),Callable(self,"_casework_choice").bind(i),1050,18)
	casework_feedback = _make_label(col, message if not message.is_empty() else "Ошибки учитываются в рейтинге. Подсказка — клавиша H.",18,Color("#e5c5a2"),1050)

func _casework_code(code: String) -> void:
	if code.strip_edges() == str(casework_data.get("correct","")):
		_casework_success()
	else:
		_casework_wrong()

func _casework_choice(choice: int) -> void:
	var kind: String = str(casework_data.get("kind","pairs"))
	if kind != "sequence":
		if choice == int(casework_data.get("correct",-1)):
			_casework_success()
		else: _casework_wrong()
		return
	var required: Array = casework_data.get("correct",[])
	if casework_stage.size() >= required.size(): return
	if choice != int(required[casework_stage.size()]):
		casework_stage.clear()
		_casework_wrong()
		return
	casework_stage.append(str(choice))
	if casework_stage.size() == required.size():
		_casework_success()
	else: _render_casework("Хорошо: установлен верный этап. Выбери следующий на основании материалов.")

func _casework_wrong() -> void:
	state.stats.mistakes = int(state.stats.get("mistakes",0))+1
	story_flags["casework_errors_%d" % state.current] = int(story_flags.get("casework_errors_%d" % state.current,0))+1
	_save_game()
	if is_instance_valid(casework_feedback):
		casework_feedback.text = "НЕВЕРНО (ошибка %d). %s" % [int(story_flags.get("casework_errors_%d" % state.current,0)),str(casework_data.get("wrong","Проверь материалы."))]
		if int(story_flags.get("casework_errors_%d" % state.current,0)) >= 3:
			casework_feedback.text += "\nПодсказка: "+str(casework_data.get("hint",""))
	_play_sfx("res://assets/audio/door_creak.ogg")

func _casework_success() -> void:
	story_flags["casework_%d" % state.current] = true
	state.award("casework_%d" % state.current,12)
	_save_game()
	_play_sfx("res://assets/audio/pickup.ogg")
	_story("ЭКСПЕРТИЗА ЗАВЕРШЕНА",str(casework_data.get("outcome","Вывод сохранён."))+"\n\nТеперь можно проверить гипотезу на рабочей станции.")

# Actual webcam thumbnails are served locally by MediaPipe. No photos are saved.
func _process(delta: float) -> void:
	super._process(delta)
	if actor_mode == "timeline" and is_instance_valid(camera_preview):
		camera_preview_elapsed -= delta
		if camera_preview_elapsed <= 0.0 and is_instance_valid(camera_frame_http) and camera_frame_http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
			camera_preview_elapsed = 1.0
			camera_frame_http.request("http://127.0.0.1:8765/frame")
	if voice_active:
		if FileAccess.file_exists(voice_result_path):
			_voice_completed()
		elif Time.get_ticks_msec() - voice_started_at > 23000:
			_stop_voice()
			if actor_mode == "dialogue" and is_instance_valid(dialogue_text):
				dialogue_text.text = "Распознавание голоса не ответило. Проверь микрофон и установку Vosk; текстовый ввод доступен."

func _camera_frame_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if actor_mode != "timeline" or not is_instance_valid(camera_preview): return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		camera_preview.texture = null
		return
	var frame := Image.new()
	if frame.load_jpg_from_buffer(body) == OK:
		camera_preview.texture = ImageTexture.create_from_image(frame)

func _reconnect_camera() -> void:
	if gesture_process_id > 0:
		OS.kill(gesture_process_id)
	gesture_process_id = -1
	gesture_autostart_attempted = false
	gesture_primed = false
	gesture_last_event = -1
	_start_gestures_if_needed()
	if is_instance_valid(gesture_status_label): gesture_status_label.text = "Повторное подключение веб-камеры…"

func _voice_question() -> void:
	if voice_active:
		if is_instance_valid(dialogue_text): dialogue_text.text = "Микрофон уже слушает. Произнеси один вопрос."
		return
	if OS.get_name() != "Windows":
		if is_instance_valid(dialogue_text): dialogue_text.text = "Голосовой ввод сейчас поддерживается на Windows; напиши вопрос вручную."
		return
	voice_result_path = OS.get_user_data_dir().path_join("last_voice_question.json")
	if FileAccess.file_exists(voice_result_path): DirAccess.remove_absolute(voice_result_path)
	var script: String = ProjectSettings.globalize_path("res://ai_service/voice_service.py")
	if not OS.has_feature("editor"):
		script = OS.get_executable_path().get_base_dir().path_join("ai_service/voice_service.py")
	if not FileAccess.file_exists(script):
		if is_instance_valid(dialogue_text): dialogue_text.text = "Файл голосового распознавателя не найден."
		return
	voice_for_npc = current_npc
	# Prefer the same interpreter as the Windows setup script.
	var voice_args := PackedStringArray(["-X", "utf8", script, "--output", voice_result_path])
	voice_process_id = OS.create_process("pythonw.exe", voice_args, false)
	if voice_process_id <= 0:
		voice_process_id = OS.create_process("python.exe", voice_args, false)
	if voice_process_id <= 0:
		voice_args.insert(0, "-3")
		voice_process_id = OS.create_process("py.exe", voice_args, false)
	if voice_process_id <= 0:
		if is_instance_valid(dialogue_text): dialogue_text.text = "Не найден Python. Установи Python 3.11 или новее и добавь его в PATH."
		return
	voice_active = true
	voice_started_at = Time.get_ticks_msec()
	if is_instance_valid(dialogue_text): dialogue_text.text = "🎤 Слушаю один вопрос… Говори по-русски. Для автономной модели Vosk запусти SETUP_VOICE_WINDOWS.bat один раз."

func _voice_completed() -> void:
	voice_active = false
	voice_process_id = -1
	var content: String = FileAccess.get_file_as_string(voice_result_path)
	DirAccess.remove_absolute(voice_result_path)
	var parsed: Variant = JSON.parse_string(content)
	if not parsed is Dictionary:
		if is_instance_valid(dialogue_text): dialogue_text.text = "Не удалось прочесть результат распознавания; напиши вопрос."
		return
	if actor_mode != "dialogue" or voice_for_npc != current_npc: return
	if bool(parsed.get("ok",false)) and not str(parsed.get("text","")).strip_edges().is_empty():
		_ask_npc(str(parsed.get("text","")))
	else:
		if is_instance_valid(dialogue_text): dialogue_text.text = "Микрофон: "+str(parsed.get("error","Речь не распознана"))+". Можно написать вопрос вручную."

func _stop_voice() -> void:
	if voice_process_id > 0: OS.kill(voice_process_id)
	voice_process_id = -1
	voice_active = false
