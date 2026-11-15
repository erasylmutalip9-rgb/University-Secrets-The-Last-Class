extends RefCounted

const Investigation = preload("res://scripts/investigation/rules.gd")
var investigation = Investigation.new()

const Catalog = preload("res://scripts/campaign/catalog.gd")
const SAVE := "user://campaign_v4.json"
const PROFILE := "user://detective_profile.json"
const SHOP := {
	"classic": {"name":"Университетская одежда", "price":0, "slot":"skin", "color":"#59665a"},
	"detective": {"name":"Тёмная детективная куртка", "price":180, "slot":"skin", "color":"#25292b"},
	"urban": {"name":"Городской костюм", "price":220, "slot":"skin", "color":"#53616d"},
	"vintage": {"name":"Винтажный исследователь", "price":260, "slot":"skin", "color":"#81664c"},
	"echo": {"name":"Коллекционный костюм ЭХО", "price":400, "slot":"skin", "color":"#c4beb0"},
	"backpack": {"name":"Кожаный рюкзак", "price":120, "slot":"accessory"},
	"watch": {"name":"Наручные часы", "price":100, "slot":"accessory"},
	"warm_light": {"name":"Тёплый фонарик", "price":80, "slot":"light"},
	"journal": {"name":"Оформление журнала: сепия", "price":100, "slot":"journal"},
	"board": {"name":"Доска: тёмное дерево", "price":100, "slot":"board"},
	"skateboard": {"name":"Скейтборд: только двор", "price":300, "slot":"transport"}
}
var catalog = Catalog.new()
var current: int = 1
var completed: Array = []
var evidence: Dictionary = {}
var flags: Dictionary = {}
var coins: int = 0
var score: int = 0
var difficulty: String = "normal"
var purchases: Array = ["classic"]
var equipped: Dictionary = {"skin":"classic"}
var achievements: Array = []
var stats: Dictionary = {"mistakes":0, "hints":0, "questions":0}
var settings: Dictionary = {"volume":0.7, "scares":true}
var replay: bool = false
var snapshot: Dictionary = {}
var last_error: String = ""

func pack() -> Dictionary:
	return {"version":4, "current":current, "completed":completed.duplicate(), "evidence":evidence.duplicate(true), "flags":flags.duplicate(true), "coins":coins, "score":score, "difficulty":difficulty, "purchases":purchases.duplicate(), "equipped":equipped.duplicate(), "achievements":achievements.duplicate(), "stats":stats.duplicate(), "settings":settings.duplicate()}

func unpack(data: Dictionary) -> void:
	current = clampi(int(data.get("current",1)),1,20)
	completed = []
	for id in data.get("completed",[]):
		if int(id) in range(1,21) and not int(id) in completed:
			completed.append(int(id))
	evidence = data.get("evidence",{}).duplicate(true)
	flags = data.get("flags",{}).duplicate(true)
	coins = maxi(0,int(data.get("coins",0)))
	score = maxi(0,int(data.get("score",0)))
	difficulty = str(data.get("difficulty","normal"))
	if not difficulty in ["easy","normal","hard"]: difficulty = "normal"
	purchases = ["classic"]
	for id in data.get("purchases",[]):
		if SHOP.has(id) and not id in purchases: purchases.append(id)
	equipped = {"skin":"classic"}
	for slot in data.get("equipped",{}):
		var id: String = str(data.equipped[slot])
		if id in purchases and SHOP[id].slot == slot: equipped[slot] = id
	achievements = data.get("achievements",[]).duplicate()
	stats = data.get("stats",{"mistakes":0,"hints":0,"questions":0}).duplicate()
	settings = data.get("settings",{"volume":0.7,"scares":true}).duplicate()

func missing(id: int) -> Array[String]:
	if id == 1: return investigation.missing(self)
	var d: Dictionary = catalog.level(id)
	var result: Array[String] = []
	for clue in d.evidence:
		if not evidence.has(clue): result.append(str(catalog.clue(clue)[0]))
	if not flags.get("casework_%d" % id,false): result.append("Дополнительное расследование / спецзадание карты")
	if not flags.get("challenge_%d" % id,false): result.append("Проверка на рабочей станции")
	if not str(d.flag).is_empty() and not flags.get(d.flag,false):
		result.append({"timeline_solved":"Реконструкция пяти событий", "danyar_contradiction":"Предъявить Данияру пропуск", "danyar_coverup":"Спросить Данияра об удалении", "mira_truth":"Спросить Миру о копии", "ruslan_truth":"Спросить Руслана о камерах"}.get(d.flag,"Допрос свидетеля"))
	return result

func unlockable(id: int) -> bool:
	return id == 1 or (id - 1) in completed

func complete_level() -> bool:
	if not missing(current).is_empty() or not unlockable(current): return false
	if replay: return true
	if not current in completed:
		completed.append(current)
		coins += int(catalog.level(current).reward)
		var rating: Dictionary = investigation.report(self,current)
		flags["rating_%d" % current] = rating
		coins += int(rating.bonus)
		award("first_case",60)
		if completed.size() >= 5: award("act_one",100)
		if completed.size() >= 15: award("echo",150)
		if completed.size() == 20: award("graduate",200)
	return true

func award(id: String, amount: int) -> void:
	if not replay and not id in achievements:
		achievements.append(id)
		coins += amount

func buy(id: String) -> bool:
	if replay or not SHOP.has(id): return false
	if not id in purchases:
		if coins < int(SHOP[id].price): return false
		coins -= int(SHOP[id].price)
		purchases.append(id)
	equipped[SHOP[id].slot] = id
	return true

func begin_replay(id: int) -> bool:
	if replay or not id in completed: return false
	snapshot = pack().duplicate(true)
	replay = true
	current = id
	flags.erase("metrics_%d" % id)
	flags.erase("rating_%d" % id)
	if id == 1:
		for key in flags.keys():
			if str(key).begins_with("l1_"): flags.erase(key)
		for key in evidence.keys():
			if str(key).begins_with("l1_"): evidence.erase(key)
	for clue in catalog.level(id).evidence: evidence.erase(clue)
	flags.erase("challenge_%d" % id)
	flags.erase("casework_%d" % id)
	var flag: String = str(catalog.level(id).flag)
	if not flag.is_empty(): flags.erase(flag)
	flags.erase("ending")
	return true

func end_replay() -> void:
	if not replay: return
	unpack(snapshot)
	snapshot = {}
	replay = false

func save_to(path: String = SAVE) -> bool:
	if replay: return true # Main slot must remain untouched.
	return write_json(path, pack())

func write_json(path: String, data: Dictionary) -> bool:
	last_error = ""
	var tmp: String = path + ".tmp"
	var file := FileAccess.open(tmp,FileAccess.WRITE)
	if file == null:
		last_error = "Не удалось записать временное сохранение"
		return false
	file.store_string(JSON.stringify(data,"  "))
	file.flush()
	var err: int = file.get_error()
	file.close()
	if err != OK:
		last_error = "Ошибка записи сохранения"
		return false
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		var backup_error: int = DirAccess.copy_absolute(absolute,absolute+".bak")
		if backup_error != OK:
			last_error = "Не удалось сохранить резервную копию"
			return false
	var result: int = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp),absolute)
	if result != OK: last_error = "Не удалось заменить сохранение"
	return result == OK

func load_from(path: String = SAVE) -> bool:
	for candidate in [path,path+".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(candidate)) != OK: continue
		var data: Variant = parser.data
		if valid_save(data):
			unpack(data)
			replay = false
			snapshot = {}
			last_error = "Загружена резервная копия" if candidate != path else ""
			return true
	last_error = "Сохранение отсутствует или повреждено. Новая игра не начата автоматически."
	return false

func valid_save(data: Variant) -> bool:
	if not data is Dictionary or int(data.get("version",0)) != 4: return false
	for key in ["evidence","flags","equipped","stats","settings"]:
		if not data.get(key) is Dictionary: return false
	for key in ["completed","purchases","achievements"]:
		if not data.get(key) is Array: return false
	return true

func migrate_legacy(data: Dictionary) -> void:
	# Return to level 1: old chapter numbers cannot prove completion of new maps.
	current = 1
	evidence = data.get("evidence",{}).duplicate(true)
	flags = data.get("story_flags",{}).duplicate(true)
	for key in ["ending","intro_pending","demo_gate_pending","memory_scare_pending"]: flags.erase(key)
	score = maxi(0,int(data.get("score",0)))
	flags["legacy_imported"] = true

func ending(accused: String, secret: bool = false) -> String:
	if accused == "none": return "unresolved"
	if accused != "Данияр": return "wrong"
	for id in ["message","motive","pass","trace","audit","usb","security","injury"]:
		if not evidence.has(id): return "insufficient"
	for id in ["timeline_solved","danyar_contradiction","danyar_coverup"]:
		if not flags.get(id,false): return "insufficient"
	if secret:
		for id in ["alex_file","old_photo","mira_backup","guard_report"]:
			if not evidence.has(id): return "insufficient"
		return "secret"
	return "correct"
