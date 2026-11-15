extends RefCounted

var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/investigation/level01.json"))

func metrics(state, id: int) -> Dictionary:
	var key: String = "metrics_%d" % id
	if not state.flags.has(key): state.flags[key] = {"mistakes":0,"hints":0,"optional":[],"attempts":{},"seconds":0.0}
	return state.flags[key]

func error(state, id: int, puzzle: String, why: String) -> Dictionary:
	var m: Dictionary = metrics(state,id)
	m.mistakes = int(m.mistakes)+1
	m.attempts[puzzle] = int(m.attempts.get(puzzle,0))+1
	state.stats.mistakes = int(state.stats.get("mistakes",0))+1
	var penalty: int = {"easy":3,"normal":7,"hard":12}.get(state.difficulty,7)
	return {"ok":false,"message":why+"\n\nНеверный вывод записан. Рейтинг: −%d баллов (не ниже C). Попытка остаётся доступной." % penalty,"hint_offer":int(m.attempts[puzzle]) >= 2}

func grant(state, id: String) -> void:
	if state.evidence.has(id): return
	state.evidence[id] = true
	state.score += 50
	if id in spec.optional:
		var m: Dictionary = metrics(state,1)
		if not id in m.optional: m.optional.append(id)

func missing(state) -> Array[String]:
	var result: Array[String] = []
	for stage in spec.stages:
		if not state.evidence.has(stage[0]) and not state.flags.get(stage[0],false): result.append(stage[1])
	return result

func read_source(state, id: String) -> Dictionary:
	if id == "l1_sensor" and not state.flags.get("l1_drawer_open",false):
		return {"ok":false,"message":"Журнал в ящике охраны. Сначала предъяви Руслану противоречие и открой ящик."}
	if not id in ["arrival","l1_schedule","l1_maintenance","l1_clock","l1_sensor","l1_receipt","l1_rumour"]:
		return {"ok":false,"message":"Этот материал нужно получить через соответствующее расследование."}
	grant(state,id)
	return {"ok":true,"message":str(state.catalog.clue(id)[1])}

func witness(state, topic: String, offered: Array = []) -> Dictionary:
	if not state.evidence.has("arrival"):
		return {"ok":false,"message":"Руслан: сначала покажи сообщение, из-за которого ты пришёл. Телефон лежит у входа."}
	if topic == "statement":
		grant(state,"l1_guard")
		return {"ok":true,"message":"Руслан: центральную дверь я вчера закрыл в 20:50. После этого никто не мог попасть в корпус.\nАлекс: ты говоришь о двери или обо всех входах?\nРуслан: о центральной... Но остальные должны были быть закрыты. Проверь расписание у стенда, если сомневаешься."}
	if topic == "drawer":
		if state.flags.get("l1_drawer",false): return {"ok":true,"message":"Руслан: ящик уже разрешил открыть. Журнал там."}
		if state.flags.get("l1_route",false) and _same_set(offered,["l1_maintenance","l1_schedule"]):
			state.flags["l1_drawer"] = true
			return {"ok":true,"message":"Руслан: да, слушатели выходили через западный проход. Я слишком уверенно сказал, что весь корпус закрыт. Возьми журнал из моего ящика. Только проверь часы контроллера: техник оставил акт сверки у западного терминала."}
		return error(state,1,"witness","Предъявленные материалы не связывают позднюю лекцию с режимом другого входа. Сначала сформулируй противоречие на доске, затем предъяви два источника.")
	if topic == "access":
		if state.evidence.has("l1_access"): return {"ok":true,"message":"Руслан: допуск у тебя. Иди к входной двери и приложи его."}
		if state.flags.get("l1_final",false) and _same_set(offered,["l1_sensor","l1_message"]):
			grant(state,"l1_access")
			return {"ok":true,"message":"Руслан: журнал и сообщение согласуются. Я оформлю тебе гостевой допуск до вестибюля. Запись о двери не показывает человека — не превращай её в обвинение. Дальше проверь журнал происшествия."}
		return error(state,1,"access","Допуск требует проверенной итоговой версии, подтверждённой событием двери и сообщением профессора. Одно предположение о маршруте не завершает проверку.")
	return {"ok":false,"message":"Пока нет подтверждённой новой темы."}

func open_drawer(state) -> Dictionary:
	if not state.flags.get("l1_drawer",false): return {"ok":false,"message":"Ящик заперт. Руслан откроет его после предъявления противоречия в режиме входов."}
	state.flags["l1_drawer_open"] = true
	return {"ok":true,"message":"Ящик открыт. Журнал контроллера лежит внутри; нажми E ещё раз, чтобы изучить."}

func expected(state, kind: String) -> Array:
	var d: Dictionary = spec.deductions[kind]
	return d.get(state.difficulty,d.requires)

func deduce(state, kind: String, selected: Array, predicate: String, note: String = "") -> Dictionary:
	if not spec.deductions.has(kind): return {"ok":false,"message":"Неизвестная задача."}
	var d: Dictionary = spec.deductions[kind]
	if state.flags.get(d.result,false): return {"ok":true,"message":d.text}
	if kind == "final" and (not state.flags.get("l1_time",false) or not state.evidence.has("l1_message")):
		return {"ok":false,"message":"Для итоговой версии сначала синхронизируй часы и восстанови сообщение на терминале."}
	if selected.is_empty(): return {"ok":false,"message":"Соедини карточки источников с выводом. Пустая версия не оценивается."}
	for source in selected:
		if not state.evidence.has(source): return {"ok":false,"message":"Нельзя предъявить ещё не найденный источник."}
	if predicate == "guilty": return error(state,1,kind,"Эти источники не устанавливают личность человека у двери и не связывают его с травмой. Подозрение не является доказательством убийства.")
	if predicate != d.predicate:
		return error(state,1,kind,"Выбранное утверждение не объясняет различие между центральной дверью и западным проходом. Проверь, к какому входу относится каждый источник.")
	if not _same_set(selected,expected(state,kind)):
		return error(state,1,kind,"В цепочке отсутствует независимое подтверждение либо добавлен материал, не относящийся к выводу. Лишние карточки не усиливают доказательство; сопоставь источник, время и область его действия.")
	state.flags[d.result] = true
	state.flags["l1_note_"+kind] = note.left(600)
	if kind == "final": state.flags["challenge_1"] = true
	return {"ok":true,"message":d.text}

func calibrate(state, value: String) -> Dictionary:
	if state.flags.get("l1_time",false): return {"ok":true,"message":"Университетское время: 20:51. Результат уже сохранён."}
	if not state.evidence.has("l1_clock") or not state.evidence.has("l1_sensor"):
		return {"ok":false,"message":"Нужны журнал контроллера и акт сверки часов. Без них вычисление не оценивается."}
	var clean: String = value.strip_edges().replace(":","")
	if clean.length() != 4 or not clean.is_valid_int(): return {"ok":false,"message":"Введи время в формате ЧЧ:ММ. Это ошибка ввода, рейтинг не снижен."}
	if clean != "2051": return error(state,1,"clock","Указанное время не согласуется с направлением смещения часов. Акт различает часы контроллера и университетское время; применяй поправку к локальной записи, а не к расписанию.")
	state.flags["l1_time"] = true
	return {"ok":true,"message":"20:58 − 7 минут = 20:51 по университетским часам. Событие произошло после закрытия центральной двери; кто воспользовался проходом, ещё неизвестно."}

func restore_message(state, ordered: Array) -> Dictionary:
	if state.evidence.has("l1_message"): return {"ok":true,"message":"Сообщение уже восстановлено и сохранено в журнале."}
	if not state.flags.get("l1_time",false): return {"ok":false,"message":"Терминал требует синхронизации времени перед проверкой пакетов."}
	if ordered.size() != 5: return {"ok":false,"message":"В сообщении пять пакетов. Заполни цепочку; незавершённый черновик не штрафуется."}
	var next: String = "START"
	for id in ordered:
		var packet: Dictionary = {}
		for p in spec.packets:
			if p.id == id: packet = p
		if packet.is_empty() or not packet.valid:
			return error(state,1,"message","В цепочку включён фрагмент без действительной подписи. Отметка подписи важнее правдоподобного текста.")
		if packet.prev != next: return error(state,1,"message","Связь между пакетами разорвана: поле «после» следующего фрагмента не совпадает с полем «далее» предыдущего. Проверь стыки, не угадывай фразу по смыслу.")
		next = packet.next
	if next != "END": return error(state,1,"message","Цепочка не заканчивается маркером END; сообщение неполно.")
	grant(state,"l1_message")
	state.flags["l1_echo_pending"] = true
	return {"ok":true,"message":str(state.catalog.clue("l1_message")[1])}

func inspect_back(state, yaw_degrees: float, zoom: float) -> bool:
	if absf(wrapf(yaw_degrees,-180,180)) >= 135 and zoom >= 1.25:
		grant(state,"l1_badge")
		return true
	return false

func gate(state) -> bool:
	if not state.evidence.has("l1_access"): return false
	state.flags["l1_gate"] = true
	return true

func hint(state, puzzle: String) -> String:
	var m: Dictionary = metrics(state,1)
	var hints: Array = spec.deductions.get(puzzle,{}).get("hints",["Изучи первоисточники в журнале.","Сравни времена и обозначения источников.","Часы спешат — локальная отметка позже университетской. В пакетах соединяй START → совпадающие метки → END."])
	var count: int = int(m.get("hint_"+puzzle,0))
	if state.difficulty == "hard" and int(m.hints) >= 3:
		return "Лимит трёх подсказок на сложном режиме достигнут. Источники, формулировка задания и объяснения ошибок остаются доступны."
	m["hint_"+puzzle] = count+1
	m.hints = int(m.hints)+1
	state.stats.hints = int(state.stats.get("hints",0))+1
	return str(hints[mini(count,hints.size()-1)])

func report(state, id: int) -> Dictionary:
	var m: Dictionary = metrics(state,id)
	var penalty: int = {"easy":3,"normal":7,"hard":12}.get(state.difficulty,7)
	var hint_cost: int = {"easy":2,"normal":4,"hard":6}.get(state.difficulty,4)
	var optional: int = m.optional.size()
	var quality: int = clampi(100-int(m.mistakes)*penalty-int(m.hints)*hint_cost,0,100)
	var grade: String = "C"
	if quality >= 95 and int(m.mistakes) == 0 and (id != 1 or optional == spec.optional.size()): grade = "S"
	elif quality >= 80: grade = "A"
	elif quality >= 60: grade = "B"
	return {"grade":grade,"quality":quality,"mistakes":int(m.mistakes),"hints":int(m.hints),"optional":optional,"seconds":float(m.seconds),"bonus":int({"C":0,"B":15,"A":30,"S":50}[grade])+optional*20}

func _same_set(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	var seen: Dictionary = {}
	for id in a: seen[id] = true
	if seen.size() != b.size(): return false
	for id in b:
		if not seen.has(id): return false
	return true
