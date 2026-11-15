extends Node3D

const IntentAI = preload("res://scripts/intent_classifier.gd")

const TITLE := "ТАЙНЫ УНИВЕРСИТЕТА: ПОСЛЕДНЯЯ ПАРА"
const SAVE_PATH := "user://last_class_case.json"
const ACCESS_PATH := "user://last_class_access.json"
const CLUE_INFO := {
	"note": ["Записка профессора", "Незадолго до смерти профессор собирался раскрыть нарушения в проекте ЭХО.", 80],
	"register": ["Журнал библиотеки", "Алекс задержался в библиотеке. Важная отметка подтверждает его алиби.", 60],
	"message": ["Письмо о конфликте", "Между профессором и Данияром произошёл конфликт из-за исходных данных.", 100],
	"pass": ["Журнал доступа", "Пропуск Данияра использовался у лаборатории в 21:17.", 100],
	"trace": ["Следы у стеллажа", "На повреждённом стеллаже найден обломок зажима пропуска Данияра. Он не доказывает убийство сам по себе, но подтверждает присутствие.", 120],
	"usb": ["Носитель ЭХО", "Носитель содержит удалённые фрагменты экспериментальных данных. Метка повреждения: 21:26.", 150],
	"audit": ["История правок ЭХО", "Учётная запись Данияра использовалась для изменения результатов эксперимента.", 150],
	"security": ["Архив камер", "Записи показывают неоформленное отключение камер с 21:08 до 21:36.", 110],
	"guard_report": ["Неоформленный рапорт", "Руслан оставил дежурный пост во время плановой диагностики. Это объясняет его молчание.", 70],
	"old_photo": ["Старая фотография", "Алекс и профессор уже встречались в экспериментальном корпусе. Но Алекс не помнит этой встречи.", 100],
	"mira_backup": ["Копия Миры", "Мира сохранила настоящую версию результатов ЭХО, чтобы разоблачить фальсификацию.", 120],
	"alex_file": ["Личное дело Алекса", "Система ЭХО изучала память и реакции Алекса. В архиве есть запись о коррекции его воспоминаний.", 180]
}
const CHAPTERS := ["", "ПОСЛЕДНЯЯ ЗАПИСЬ", "НАРУШЕННЫЙ ПРОТОКОЛ", "ЦЕНА ИСТИНЫ"]
const NPC_PORTRAITS := {
	"Мира": "res://assets/portraits/mira_portrait.png",
	"Руслан": "res://assets/portraits/ruslan_portrait.png",
	"Данияр": "res://assets/portraits/daniyar_portrait.png"
}

var campaign_mode: bool = false
var intent_ai: CaseIntentClassifier = IntentAI.new()
var player: AlexPlayer
var world: NoirCampus
var ui_layer: CanvasLayer
var ui_root: Control
var overlay: Control
var hud: Control
var objective_label: Label
var chapter_label: Label
var score_label: Label
var zone_label: Label
var action_label: Label
var toast_label: Label
var reticle: Label
var toast_time: float = 0.0
var actor_mode: String = "menu"
var chapter: int = 1
var evidence: Dictionary = {}
var story_flags: Dictionary = {}
var score: int = 0
var demo_unlocked: bool = false
var jumpscares_enabled: bool = true
var llm_enabled: bool = false
var current_npc: String = ""
var dialogue_text: Label
var dialogue_input: LineEdit
var pending_scripted_answer: String = ""
var pending_request: HTTPRequest
var music: AudioStreamPlayer
var sound_fx: AudioStreamPlayer
var scare_time: float = 0.0
var shadow_time: float = 0.0
var breathing_time: float = 0.0
var queued_target: Vector3 = Vector3.ZERO
var has_queued_load: bool = false
var settings_origin: String = "menu"
var circuit_sequence: Array[int] = []
var cinematic_camera: Camera3D
var cinematic_title: Label
var cinematic_tween: Tween
var timeline_sequence: Array[String] = []
var footstep_audio: AudioStreamPlayer
var whisper_audio: AudioStreamPlayer
var step_wait: float = 0.0
var tension_restore: float = 0.0
var nav_label: Label
var help_step: int = 0
var gesture_http: HTTPRequest
var gesture_poll_time: float = 0.0
var gesture_last_event: int = -1
var gesture_primed: bool = false
var gesture_status_label: Label
var gesture_autostart_attempted: bool = false
var gesture_last_launch_ms: int = 0
var gesture_process_id: int = -1
const GESTURE_ENDPOINT := "http://127.0.0.1:8765/gesture"
const TIMELINE_CHOICES: Array[String] = ["delete", "up", "pass", "down"]
const TIMELINE_GESTURE_NAMES := {"Closed_Fist":"1 — Кулак", "Victory":"2 — Победа", "Open_Palm":"3 — Ладонь", "Thumb_Up":"4 — Лайк"}


func _ready() -> void:
	_register_actions()
	gesture_http = HTTPRequest.new()
	gesture_http.name = "GestureCameraClient"
	gesture_http.timeout = 1.2
	add_child(gesture_http)
	gesture_http.request_completed.connect(_gesture_response)
	world = NoirCampus.new()
	world.name = "Корпуса университета"
	add_child(world)
	world.make_world()
	player = AlexPlayer.new()
	add_child(player)
	player.set_safe_spawn(Vector3(-2.0,0.30,3.3))
	player.recovered_from_fall.connect(_on_player_recovered)
	player.can_move = false
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(ui_root)
	_create_hud()
	music = AudioStreamPlayer.new()
	music.volume_db = -15.0
	add_child(music)
	music.finished.connect(_music_finished)
	sound_fx = AudioStreamPlayer.new()
	sound_fx.volume_db = -9.0
	add_child(sound_fx)
	footstep_audio = AudioStreamPlayer.new()
	footstep_audio.volume_db = -15.0
	add_child(footstep_audio)
	whisper_audio = AudioStreamPlayer.new()
	whisper_audio.volume_db = -12.0
	add_child(whisper_audio)
	_load_access()
	_start_music("res://assets/audio/ambient.ogg")
	_show_menu()

func _on_player_recovered() -> void:
	if actor_mode == "playing":
		_toast("Безопасное возвращение на последнюю устойчивую позицию.", 3.5)

func _register_actions() -> void:
	_bind("move_forward", [KEY_W,KEY_UP])
	_bind("move_back", [KEY_S,KEY_DOWN])
	_bind("move_left", [KEY_A,KEY_LEFT])
	_bind("move_right", [KEY_D,KEY_RIGHT])
	_bind("interact", [KEY_E])
	_bind("camera_toggle", [KEY_V])
	_bind("camera_reset", [KEY_R])
	_bind("flashlight", [KEY_F])
	_bind("journal", [KEY_TAB,KEY_J])
	_bind("pause", [KEY_ESCAPE])
	_bind("sprint", [KEY_SHIFT])
	_bind("jump", [KEY_SPACE])
	_bind("help", [KEY_H])

func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for keycode in keys:
		var key := InputEventKey.new()
		key.physical_keycode = keycode
		InputMap.action_add_event(action, key)

func _process(delta: float) -> void:
	world.update_flicker(delta, scare_time > 0.0)
	if actor_mode == "playing":
		world.update_npcs(player.global_position,delta)
	if tension_restore > 0.0:
		tension_restore -= delta
		if tension_restore <= 0.0:
			_start_music("res://assets/audio/ambient.ogg")
	if actor_mode == "timeline":
		gesture_poll_time -= delta
		if gesture_poll_time <= 0.0 and is_instance_valid(gesture_http) and gesture_http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
			gesture_poll_time = 0.7
			gesture_http.request(GESTURE_ENDPOINT)
	if actor_mode == "playing" and player.is_on_floor():
		step_wait -= delta
		if Vector2(player.velocity.x,player.velocity.z).length() > 1.5 and step_wait <= 0.0:
			var sound: String = "res://assets/audio/step_a.ogg" if randi() % 2 == 0 else "res://assets/audio/step_b.ogg"
			footstep_audio.stream = load(sound)
			footstep_audio.play()
			step_wait = 0.31 if Input.is_action_pressed("sprint") else 0.48
	else:
		step_wait = 0.0
	if shadow_time > 0.0:
		shadow_time -= delta
		if shadow_time <= 0.0:
			world.hide_shadow()
	if scare_time > 0.0:
		scare_time -= delta
		var intensity: float = minf(1.0, scare_time * 0.8)
		player.first_camera.h_offset = randf_range(-0.045,0.045) * intensity
		player.third_camera.h_offset = randf_range(-0.045,0.045) * intensity
	else:
		player.visual.stressed = false
		player.first_camera.h_offset = 0.0
		player.third_camera.h_offset = 0.0
	if toast_time > 0.0:
		toast_time -= delta
		if toast_time <= 0.0:
			toast_label.visible = false
	if actor_mode == "playing":
		var nearest := world.nearest_item(player.global_position, 2.35)
		if nearest.is_empty():
			action_label.text = ""
		else:
			action_label.text = "[ E ]  " + str(nearest["label"])
		zone_label.text = _zone_name()
		_update_hud()
		_update_navigation()
		if not campaign_mode and chapter >= 2 and not story_flags.has("first_lab_visit") and player.global_position.x > 11.0 and player.global_position.z > -7.5:
			story_flags["first_lab_visit"] = true
			whisper_audio.stream = load("res://assets/audio/memory_whisper.ogg")
			whisper_audio.play()
			_toast("В динамике кто-то шепчет: «021... помнишь?»",4.5)
			_save_game()
		if not campaign_mode and chapter == 3 and not story_flags.has("scare_done") and player.global_position.z < -12.8 and player.global_position.x > 10.0:
			story_flags["scare_done"] = true
			_trigger_horror()

func _unhandled_input(event: InputEvent) -> void:
	if actor_mode == "cinematic" and (event.is_action_pressed("pause") or event.is_action_pressed("interact")):
		_finish_intro()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		if actor_mode == "playing":
			_show_pause()
		elif actor_mode in ["journal", "dialogue", "scanner", "final", "story", "puzzle", "timeline"]:
			_close_overlay()
		elif actor_mode == "pause":
			_close_overlay()
		elif actor_mode == "settings":
			if settings_origin == "menu":
				_show_menu()
			else:
				_show_pause()
		get_viewport().set_input_as_handled()
		return
	if actor_mode != "playing":
		return
	if event.is_action_pressed("camera_toggle"):
		player.toggle_camera()
		_toast("Режим камеры: " + ("первое лицо" if player.first_person else "третье лицо"))
	elif event.is_action_pressed("camera_reset"):
		player.reset_camera()
		_toast("Камера выровнена за Алексом")
	elif event.is_action_pressed("flashlight"):
		player.toggle_flashlight()
		_toast("Фонарик: " + ("ВКЛ" if player.flashlight_on else "ВЫКЛ"))
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("journal"):
		_show_journal()
	elif event.is_action_pressed("help"):
		_show_help()

func _make_label(parent: Node, value: String, size_value: int, color_value: Color = Color.WHITE, width: float = 0.0) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", size_value)
	l.add_theme_color_override("font_color", color_value)
	l.add_theme_color_override("font_shadow_color", Color(0,0,0,0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if width > 0.0:
		l.custom_minimum_size.x = width
	parent.add_child(l)
	return l

func _style(bg: Color = Color("#293030"), edge: Color = Color("#a69888"), radius_value: int = 9) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius_value)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s

func _panel(parent: Control, pos: Vector2, box_size: Vector2, background: Color = Color(0.037,0.055,0.12,0.94)) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.custom_minimum_size = box_size
	p.size = box_size
	p.add_theme_stylebox_override("panel", _style(background))
	parent.add_child(p)
	return p

func _column(parent: Node, spacing: int = 12) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", spacing)
	parent.add_child(box)
	return box

func _btn(parent: Node, value: String, cb: Callable, width_value: float = 400.0, size_value: int = 21) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(width_value, 50)
	button.add_theme_font_size_override("font_size", size_value)
	button.add_theme_color_override("font_color", Color("#f7efe5"))
	button.add_theme_stylebox_override("normal",_style(Color("#3c454c"), Color("#a0917f")))
	button.add_theme_stylebox_override("hover",_style(Color("#766b5d"), Color("#efdbc4")))
	button.add_theme_stylebox_override("pressed",_style(Color("#bdad9b"), Color("#f7e3cb")))
	parent.add_child(button)
	button.pressed.connect(cb)
	return button

func _new_overlay(dim: float = 0.84) -> Control:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(overlay)
	var dark := ColorRect.new()
	dark.color = Color(0.017,0.02,0.055, dim)
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dark)
	player.can_move = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return overlay

func _create_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(hud)
	var vignette := TextureRect.new()
	vignette.texture = load("res://assets/ui/vignette.png")
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(vignette)
	vignette.modulate.a = 0.20
	var top := _panel(hud,Vector2(24,24),Vector2(575,138),Color(0.025,0.036,0.07,0.84))
	var v := _column(top,7)
	chapter_label = _make_label(v,"ГЛАВА I",20,Color("#f7e3cb"))
	objective_label = _make_label(v,"Исследуй библиотеку",18,Color("#f0e6ef"),530)
	zone_label = _make_label(v,"ВЕСТИБЮЛЬ",15,Color("#b0d2d7"))
	nav_label = _make_label(hud,"",18,Color("#f4e2bf"),760)
	nav_label.position = Vector2(24,179)
	var right := _panel(hud,Vector2(1272,24),Vector2(295,115),Color(0.025,0.036,0.07,0.82))
	var rv := _column(right,8)
	score_label = _make_label(rv,"ДЕЛО № 021",19,Color("#edd9c2"))
	_make_label(rv,"WASD · E · Space · H · TAB",14,Color("#b2d1d5"))
	action_label = _make_label(hud,"",22,Color("#f7efe6"))
	action_label.position = Vector2(530,773)
	action_label.custom_minimum_size = Vector2(590,50)
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label = _make_label(hud,"",23,Color("#f7e3cb"))
	toast_label.position = Vector2(490,187)
	toast_label.custom_minimum_size = Vector2(650,45)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.visible = false
	reticle = _make_label(hud,"+",24,Color("#f7e5cf"))
	reticle.position = Vector2(789,431)
	_make_label(hud,"ТАЙНЫ УНИВЕРСИТЕТА   /   CASE 021",17,Color("#c3b3a0")).position = Vector2(28,844)
	hud.visible = false

func _update_hud() -> void:
	chapter_label.text = "ГЛАВА %s  /  %s" % [str(chapter), CHAPTERS[chapter]]
	score_label.text = "Улики: %d / 12    ·    %d XP" % [evidence.size(),score]
	if chapter == 1:
		objective_label.text = "Библиотека: записка, журнал и письмо (%d/3)" % _count(["note","register","message"])
	elif chapter == 2:
		objective_label.text = "Лаборатория: 3 улики + анализ сканером (%d/4)" % (_count(["pass","trace","usb"]) + int(story_flags.has("scan_done")))
	else:
		objective_label.text = "Архив: история правок, камеры, реконструкция (%d/3)" % (_count(["audit","security"]) + int(story_flags.has("timeline_solved")))

func _next_target() -> Dictionary:
	if chapter == 1:
		for id in ["note", "register", "message"]:
			if not evidence.has(id):
				return {"id": id, "tip": {"note":"Проверь записку на читательском столе", "register":"Найди журнал посетителей на соседнем столе", "message":"Открой шкафчик с перепиской у книжных полок"}[id]}
	if chapter == 2:
		for id in ["pass", "trace", "usb"]:
			if not evidence.has(id):
				return {"id": id, "tip": {"pass":"Осмотри компьютер с записями пропусков", "trace":"Проверь повреждённый стеллаж", "usb":"Найди флешку на рабочем столе"}[id]}
		if not story_flags.has("scan_done"):
			return {"id":"scanner", "tip":"Подойди к лабораторной станции анализа"}
	if chapter == 3:
		for id in ["audit", "security"]:
			if not evidence.has(id):
				return {"id":id, "tip":"Изучи архивные данные (подойди к терминалу или шкафу)"}
		if not story_flags.has("timeline_solved"):
			return {"id":"timeline", "tip":"Собери события по времени на стенде хронологии"}
		return {"id":"final", "tip":"Иди к стенду обвинения. Проверь противоречие Данияра"}
	return {}

func _update_navigation() -> void:
	var target: Dictionary = _next_target()
	if target.is_empty():
		nav_label.text = "[H] Инструкция · [TAB] Улики"
		return
	var id: String = str(target.get("id", ""))
	var destination: Vector3 = world.item_position(id)
	var meters: int = roundi(Vector2(destination.x - player.global_position.x, destination.z - player.global_position.z).length())
	var here: String = ""
	if chapter == 1:
		here = "← БИБЛИОТЕКА"
	elif chapter == 2:
		here = "→ ЛАБОРАТОРИЯ"
	else:
		here = "→ ЛАБОРАТОРИЯ → АРХИВ"
	nav_label.text = "ЦЕЛЬ: %s  ·  %d м  ·  %s  ·  [H] помощь" % [str(target.get("tip", "")), meters, here]

func _show_briefing(step: int) -> void:
	help_step = step
	actor_mode = "briefing"
	var screen := _new_overlay(0.90)
	var panel := _panel(screen, Vector2(220,100), Vector2(1160,710), Color("#29312f"))
	var col := _column(panel,18)
	_make_label(col,"ДЕЛО № 021  /  ВВОДНЫЙ ИНСТРУКТАЖ  %d / 3" % (step+1),22,Color("#eddac1"))
	var titles: Array[String] = ["ПОЧЕМУ ТЫ ЗДЕСЬ?", "КАК ИСКАТЬ УЛИКИ", "ПЛАН РАССЛЕДОВАНИЯ"]
	var texts: Array[String] = [
		"Утром в научном корпусе нашли погибшего профессора Армана Сеитова. Перед смертью он сообщил о нарушениях в исследовании искусственного интеллекта ЭХО. Камеры были отключены, свидетели противоречат друг другу.\n\nТы — Алекс, студент. Твоя задача — найти доказательства, проверить алиби и только потом назвать виновного.",
		"WASD — ходить  ·  мышь — осматриваться  ·  Shift — бег  ·  Space — прыжок.\nE — взаимодействие с предметом или разговор с NPC. Если предмет лежит в шкафу, сначала открой дверцу клавишей E, затем нажми E ещё раз, чтобы забрать находку.\nV — переключить вид от 1-го / 3-го лица, F — фонарик, TAB — журнал улик, H — эта инструкция, Esc — пауза.\nНаверху слева постоянно показана следующая цель, направление и расстояние.",
		"ГЛАВА I: иди в библиотеку через левый проём вестибюля. Найди записку на столе, журнал посещений и служебную переписку в шкафу.\nГЛАВА II: открой лабораторию через правый проём. Изучи следы, поговори с подозреваемыми и используй терминал анализа.\nГЛАВА III: исследуй архив и восстанови хронологию событий. Можно нажимать кнопки мышью или использовать жесты через веб-камеру. После этого предъяви обвинение на стенде.\nНе все найденные секреты доказывают убийство. Сверяй версии в журнале."
	]
	_make_label(col,titles[step],36,Color("#fff0db"))
	_make_label(col,texts[step],23,Color("#f1eee5"),1060)
	_add_space(col,20)
	if step < 2:
		_btn(col,"ДАЛЕЕ →",Callable(self,"_show_briefing").bind(step+1),1050)
	else:
		_btn(col,"ПОНЯТНО. НАЧАТЬ РАССЛЕДОВАНИЕ",Callable(self,"_close_overlay"),1050)

func _show_help() -> void:
	story_flags.erase("intro_pending")
	_show_briefing(1)
	# Contextual help must return directly to gameplay, not replay the intro.

func _zone_name() -> String:
	var p := player.global_position
	if p.x < -9.0:
		return "БИБЛИОТЕКА · КРЫЛО А"
	if p.x > 9.0 and p.z < -8.0:
		return "АРХИВ · ЗАКРЫТАЯ ЗОНА"
	if p.x > 9.0:
		return "ЛАБОРАТОРИЯ · КРЫЛО Б"
	return "ЦЕНТРАЛЬНЫЙ ВЕСТИБЮЛЬ"

func _show_menu() -> void:
	actor_mode = "menu"
	hud.visible = false
	var screen := _new_overlay(0.0)
	var picture := TextureRect.new()
	picture.texture = load("res://assets/ui/menu_art.png")
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(picture)
	screen.move_child(picture, 0)
	var shade := ColorRect.new()
	shade.color = Color(0.008,0.008,0.025,0.19)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(shade)
	var menu := _panel(screen,Vector2(64,120),Vector2(655,660),Color(0.16,0.19,0.20,0.88))
	var col := _column(menu,12)
	_make_label(col,"CASE 021  /  ИНТЕРАКТИВНЫЙ ТРИЛЛЕР",17,Color("#dbc9b4"))
	_make_label(col,"ТАЙНЫ УНИВЕРСИТЕТА",36,Color("#f7ede1"))
	_make_label(col,"ПОСЛЕДНЯЯ ПАРА",37,Color("#f7e3cb"))
	_make_label(col,"Никто не говорит всю правду. Даже память.",18,Color("#aab8c4"))
	_add_space(col,8)
	_btn(col,"НОВАЯ ИГРА",Callable(self,"_new_game"),565)
	_btn(col,"ПРОДОЛЖИТЬ",Callable(self,"_load_game"),565)
	_btn(col,"НАСТРОЙКИ И ДОСТУП",Callable(self,"_show_settings"),565)
	_btn(col,"ВЫХОД",Callable(get_tree(),"quit"),565)
	_add_space(col,5)
	_make_label(col,"3D · первое / третье лицо · расследование · психологический триллер",15,Color("#b1bfcc"))
	_make_label(col,"v0.5 · 3D расследование · ИИ-допросы · жесты с камерой (дополнительно)",13,Color("#c9c0ae"))

func _add_space(parent: Node, height_value: float) -> void:
	var s := Control.new()
	s.custom_minimum_size.y = height_value
	parent.add_child(s)

func _new_game() -> void:
	evidence = {}
	story_flags = {}
	score = 0
	chapter = 1
	_reset_world()
	player.set_safe_spawn(Vector3(-2,0.30,3.3))
	player.rotation.y = 0
	story_flags["intro_pending"] = true
	_start_play()
	_show_briefing(0)

func _reset_world() -> void:
	world.queue_free()
	world = NoirCampus.new()
	add_child(world)
	world.make_world()
	player.set_safe_spawn(Vector3(-2,0.30,3.3))

func _start_play() -> void:
	actor_mode = "playing"
	if is_instance_valid(overlay):
		overlay.queue_free()
		overlay = null
	hud.visible = true
	player.can_move = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_hud()

func _close_overlay() -> void:
	if story_flags.get("intro_pending",false):
		story_flags.erase("intro_pending")
		_start_cinematic()
		return
	if story_flags.get("demo_gate_pending",false):
		story_flags.erase("demo_gate_pending")
		_show_demo_gate()
		return
	if story_flags.get("memory_scare_pending",false):
		story_flags.erase("memory_scare_pending")
		_start_play()
		_trigger_horror()
		return
	_start_play()

func _start_cinematic() -> void:
	actor_mode = "cinematic"
	player.can_move = false
	hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(overlay):
		overlay.queue_free()
		overlay = null
	cinematic_camera = Camera3D.new()
	cinematic_camera.name = "Кинематографическая камера"
	cinematic_camera.fov = 62.0
	add_child(cinematic_camera)
	cinematic_camera.global_position = Vector3(4.5,3.5,7.0)
	cinematic_camera.look_at(Vector3(-2.5,1.45,-1.0))
	cinematic_camera.current = true
	cinematic_title = _make_label(ui_root,"ЗАПИСЬ 021  //  20:34  //  КОРПУС ЗАКРЫТ",29,Color("#f7e3cb"))
	cinematic_title.position = Vector2(330,760)
	cinematic_title.custom_minimum_size = Vector2(950,58)
	cinematic_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cinematic_tween = create_tween()
	cinematic_tween.tween_property(cinematic_camera,"global_position",Vector3(-3.3,2.7,1.2),5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cinematic_tween.finished.connect(_finish_intro)

func _finish_intro() -> void:
	if actor_mode != "cinematic":
		return
	if is_instance_valid(cinematic_tween):
		cinematic_tween.kill()
	if is_instance_valid(cinematic_camera):
		cinematic_camera.queue_free()
	if is_instance_valid(cinematic_title):
		cinematic_title.queue_free()
	player.set_camera_mode(player.first_person)
	_start_play()
	_toast("ЦЕЛЬ: изучить библиотеку   ·   [V] сменить камеру",5.0)

func _toast(message: String, duration: float = 2.8) -> void:
	toast_label.text = message
	toast_label.visible = true
	toast_time = duration

func _story(headline: String, narration: String) -> void:
	actor_mode = "story"
	var screen := _new_overlay(0.82)
	var panel := _panel(screen,Vector2(350,170),Vector2(900,530),Color(0.04,0.05,0.1,0.97))
	var col := _column(panel,22)
	_make_label(col,"ЛИЧНОЕ ДЕЛО 021 · ЗАПИСЬ",17,Color("#dfcdb7"))
	_make_label(col,headline,36,Color("#f5e5d3"))
	_make_label(col,narration,22,Color("#e5dfed"),820)
	_add_space(col,55)
	_btn(col,"ПРОДОЛЖИТЬ РАССЛЕДОВАНИЕ",Callable(self,"_close_overlay"),810)

func _interact() -> void:
	var item := world.nearest_item(player.global_position,2.35)
	if item.is_empty():
		return
	match str(item["kind"]):
		"door":
			if item["id"] == "lab":
				_toast("Доступ заблокирован. Изучи документы библиотеки.")
			else:
				_toast("Архив запечатан. Сначала восстанови события в лаборатории.")
		"npc":
			var npc_id: String = str(item["id"])
			var npc_name: String = {"мира":"Мира","данияр":"Данияр","руслан":"Руслан"}.get(npc_id,npc_id)
			_show_dialogue(npc_name)
		"container":
			var key: String = str(item["id"])
			world.open_container(key)
			var opened: Array = story_flags.get("opened_cabinets", [])
			if not (key in opened):
				opened.append(key)
			story_flags["opened_cabinets"] = opened
			_save_game()
			_play_sfx("res://assets/audio/door_creak.ogg")
			_toast("Ящик открыт. Внутри есть документ. Нажми E ещё раз, чтобы забрать.",5.0)
		"evidence":
			_collect_evidence(str(item["id"]))
		"scanner":
			_show_scanner()
		"final":
			_show_final()
		"timeline":
			_show_timeline()
		"puzzle":
			_show_circuit()
		"lore":
			if item["id"] == "diary":
				_story("ДНЕВНИК АЛЕКСА", "Мы слишком много доверяем машинам. И слишком мало — показаниям друг друга.\n\nИногда кажется, что проект ЭХО знал о нас больше, чем мы сами.")
			else:
				_story("ПРОЕКТ ЭХО", "На плакате написано: «Поведенческая аналитика для будущего образования». Небольшим шрифтом указан профессор Сеитов.")
			world.set_item_hidden(str(item["id"]))

func _collect_evidence(id: String) -> void:
	if evidence.has(id):
		return
	if not CLUE_INFO.has(id):
		return
	evidence[id] = true
	score += int(CLUE_INFO[id][2])
	world.set_item_hidden(id)
	_play_sfx("res://assets/audio/pickup.ogg")
	_story("ОБНАРУЖЕНА УЛИКА · " + str(CLUE_INFO[id][0]), str(CLUE_INFO[id][1]) + "\n\nДокумент добавлен в журнал расследования.")
	if id == "alex_file":
		story_flags["memory_scare_pending"] = true
	if chapter == 1 and _count(["note","register","message"]) == 3 and not story_flags.has("library_completed"):
		story_flags["library_completed"] = true
		if demo_unlocked:
			_unlock_chapter_2()
		else:
			story_flags["demo_gate_pending"] = true
	elif chapter == 2:
		_check_lab_progress()
	_save_game()

func _count(ids: Array) -> int:
	var count_value: int = 0
	for id in ids:
		if evidence.has(id):
			count_value += 1
	return count_value

func _check_lab_progress() -> void:
	if chapter != 2:
		return
	if _count(["pass","trace","usb"]) == 3 and story_flags.has("scan_done"):
		chapter = 3
		story_flags["lab_completed"] = true
		world.open_door("archive")
		_save_game()
		_toast("Архив разблокирован. НЕ ОБОРАЧИВАЙСЯ.",5.0)

func _unlock_chapter_2() -> void:
	chapter = 2
	world.open_door("lab")
	_save_game()
	_toast("Глава II открыта. Пройди вправо через вестибюль в лабораторию.",5.0)

func _show_demo_gate() -> void:
	actor_mode = "demo_gate"
	var screen := _new_overlay(0.92)
	var panel := _panel(screen,Vector2(360,145),Vector2(880,610),Color(0.06,0.037,0.10,0.98))
	var col := _column(panel,22)
	_make_label(col,"КОНЕЦ ДЕМО-ГЛАВЫ",35,Color("#f4e0c8"))
	_make_label(col,"Все три документа найдены. Ты готов войти в лабораторию.",22,Color("#e9deec"))
	_make_label(col,"Учебная модель Free Demo → Full Game. Ниже представлена демонстрационная разблокировка БЕЗ платежа и без реальной покупки. Она нужна для демонстрации коммерциализации проекта.",19,Color("#c3ccd4"),810)
	_add_space(col,40)
	_btn(col,"РАЗБЛОКИРОВАТЬ ПОЛНУЮ ИГРУ (ДЕМО)",Callable(self,"_unlock_demo"),820)
	_btn(col,"В МЕНЮ",Callable(self,"_show_menu"),820)

func _unlock_demo() -> void:
	demo_unlocked = true
	_save_access()
	_unlock_chapter_2()
	_start_play()
	_story("ГЛАВА II · НАРУШЕННЫЙ ПРОТОКОЛ", "Охрана открыла лабораторию. Сначала проверь журнал доступа, повреждённый стеллаж и носитель ЭХО.\n\nПосле этого используй форензик-станцию, чтобы проверить данные. Но осторожно: в коридорах кто-то есть.")

func _show_circuit() -> void:
	actor_mode = "puzzle"
	circuit_sequence = []
	_render_circuit()

func _render_circuit() -> void:
	actor_mode = "puzzle"
	var screen := _new_overlay(0.84)
	var panel := _panel(screen,Vector2(420,150),Vector2(760,620),Color(0.022,0.08,0.115,0.98))
	var col := _column(panel,20)
	_make_label(col,"ЩИТОК СИСТЕМЫ НАБЛЮДЕНИЯ",31,Color("#c2e7ec"))
	_make_label(col,"Три канала питания перепутаны. Подсказка: Б → В → А.\nАктивируй каналы в указанном порядке.",19,Color("#d9e9eb"),680)
	_make_label(col,"Последовательность: " + str(circuit_sequence),21,Color("#bfe4e9"))
	for i in range(3):
		_btn(col,["КАНАЛ А","КАНАЛ Б","КАНАЛ В"][i],Callable(self,"_press_circuit").bind(i),700)
	_btn(col,"ОТМЕНА",Callable(self,"_close_overlay"),700)

func _press_circuit(channel: int) -> void:
	circuit_sequence.append(channel)
	var goal: Array[int] = [1,2,0]
	if circuit_sequence.size() >= 3:
		if circuit_sequence == goal:
			if not story_flags.has("power_fixed"):
				story_flags["power_fixed"] = true
				score += 80
				_save_game()
			_story("ПИТАНИЕ ВОССТАНОВЛЕНО", "Ты смог стабилизировать резервный пульт. Между отключением камер и убийством есть несколько минут, которых никто не может объяснить.")
		else:
			circuit_sequence = []
			_play_sfx("res://assets/audio/sting.ogg")
			_toast("ОШИБКА КАНАЛОВ. ПИТАНИЕ СОРВАНО.")
			_render_circuit()
	else:
		_render_circuit()

func _show_journal() -> void:
	actor_mode = "journal"
	var screen := _new_overlay(0.86)
	var panel := _panel(screen,Vector2(215,80),Vector2(1170,750),Color(0.025,0.04,0.085,0.96))
	var col := _column(panel,15)
	_make_label(col,"ЖУРНАЛ РАССЛЕДОВАНИЯ  /  CASE 021",29,Color("#f1ddc6"))
	_make_label(col,"Улики: %d из 12     |     Очки: %d     |     Глава: %d" % [evidence.size(),score,chapter],18,Color("#c4dee2"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1100,530)
	col.add_child(scroll)
	var list := _column(scroll,9)
	for clue_id in CLUE_INFO.keys():
		if evidence.has(clue_id):
			_make_label(list,"◆  " + str(CLUE_INFO[clue_id][0]),19,Color("#f7e3cb"),1000)
			_make_label(list,"      " + str(CLUE_INFO[clue_id][1]),16,Color("#c6d6d8"),1000)
		else:
			_make_label(list,"◇  НЕИЗВЕСТНАЯ УЛИКА",17,Color("#799498"))
	_add_space(col,10)
	_btn(col,"ЗАКРЫТЬ ЖУРНАЛ",Callable(self,"_close_overlay"),1090)

func _show_dialogue(npc: String) -> void:
	current_npc = npc
	actor_mode = "dialogue"
	var screen := _new_overlay(0.79)
	var panel := _panel(screen,Vector2(185,118),Vector2(1230,670),Color(0.027,0.035,0.08,0.97))
	var col := _column(panel,12)
	_make_label(col,"ДОПРОС   /   " + npc.to_upper(),31,Color("#f7e3cb"))
	_make_label(col,"Свободный текст: локальный обученный NLP выбирает смысл вопроса. Ollama необязателен.",16,Color("#adced3"))
	var pic_row := HBoxContainer.new()
	pic_row.add_theme_constant_override("separation",24)
	col.add_child(pic_row)
	var portrait := TextureRect.new()
	portrait.texture = load(NPC_PORTRAITS.get(npc,"res://assets/portraits/alex_portrait.png"))
	portrait.custom_minimum_size = Vector2(270,325)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic_row.add_child(portrait)
	var right := _column(pic_row,16)
	var introductions := {
		"Мира":"«Мы с профессором спорили не о том, о чём думают все. Я не хотела его смерти».\n\nСпроси, где она была, что знает об ЭХО и почему сохранила данные.",
		"Данияр":"«Вы из полиции? Нет? Тогда сначала покажите хоть один факт».\n\nПроверь его алиби, посещение лаборатории и конфликт с профессором.",
		"Руслан":"«Я здесь двадцать лет. Но в ту ночь что-то пошло не так».\n\nСпроси об отключённых камерах, рапорте и проходах в корпус."
	}
	dialogue_text = _make_label(right,str(introductions.get(npc,"Что ты хочешь узнать?")),21,Color("#ece7f3"),800)
	dialogue_text.custom_minimum_size.y = 240
	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation",8)
	right.add_child(quick)
	_btn(quick,"АЛИБИ",Callable(self,"_ask_npc").bind("Где вы были в ночь убийства?"),150,15)
	_btn(quick,"ПРОЕКТ",Callable(self,"_ask_npc").bind("Что вы знаете про проект ЭХО?"),150,15)
	_btn(quick,"УЛИКИ",Callable(self,"_ask_npc").bind("Что скажете о найденных доказательствах?"),150,15)
	dialogue_input = LineEdit.new()
	dialogue_input.placeholder_text = "Напиши свой вопрос персонажу..."
	dialogue_input.custom_minimum_size = Vector2(1100,48)
	dialogue_input.add_theme_font_size_override("font_size",19)
	dialogue_input.text_submitted.connect(_ask_npc)
	col.add_child(dialogue_input)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation",16)
	col.add_child(bottom)
	_btn(bottom,"ЗАДАТЬ ВОПРОС",Callable(self,"_submit_npc"),350,18)
	if has_method("_voice_question"):
		_btn(bottom,"🎤 СКАЗАТЬ ВОПРОС",Callable(self,"_voice_question"),350,18)
	_btn(bottom,"ЗАВЕРШИТЬ ДОПРОС",Callable(self,"_close_overlay"),350,18)
	dialogue_input.grab_focus()

func _submit_npc() -> void:
	if is_instance_valid(dialogue_input):
		_ask_npc(dialogue_input.text)

func _ask_npc(query: String) -> void:
	query = query.strip_edges().left(250)
	if query.is_empty():
		return
	if is_instance_valid(dialogue_input):
		dialogue_input.clear()
	# Genuine offline NLP: a Multinomial Naive Bayes model trained on Russian questions.
	var prediction: Dictionary = intent_ai.classify(query)
	var intent: String = str(prediction.get("intent","другое"))
	var effective_query: String = query
	match intent:
		"алиби": effective_query = "алиби где вечер"
		"доступ": effective_query = "пропуск 21:17 вход"
		"камеры": effective_query = "камеры охрана 21:08"
		"проект": effective_query = "проект ЭХО профессор"
		"улики": effective_query = "улики носитель копия"
	var base: String = _scripted_answer(current_npc, effective_query + " " + query)
	_save_game()
	var diagnostic := "[AI / NLP: " + intent + " · уверенность " + str(roundi(float(prediction.get("confidence",0.0)) * 100.0)) + "%]"
	if llm_enabled:
		_generate_ai_reply(current_npc,query,base)
	else:
		if is_instance_valid(dialogue_text):
			dialogue_text.text = "Алекс: «" + query + "»\n\n" + current_npc + ": «" + base + "»\n\n" + diagnostic

func _scripted_answer(npc: String, query: String) -> String:
	var q := query.to_lower()
	# Each witness has coherent, evidence-gated information. No free AI text changes the truth.
	if npc == "Мира" and ("русла" in q or "охран" in q):
		return "Руслан разрешил техническую остановку камер. Но я видела, что он нервничал уже утром, когда нашли профессора."
	if npc == "Мира" and ("данияр" in q or "аспира" in q):
		return "Данияр боялся, что профессор опубликует настоящие результаты. Если найдёшь архивную историю правок, поймёшь почему."
	if npc == "Данияр" and ("мир" in q or "ассист" in q):
		return "Мира скрывает копию отчёта, и она прекрасно это знает. Только не делай из этого признание в убийстве."
	if npc == "Данияр" and ("удал" in q or "21:26" in q):
		if evidence.has("usb") and evidence.has("audit"):
			story_flags["danyar_coverup"] = true
			return "Удаление данных мог запустить кто угодно с доступом к системе. Я не признаю, что это делал я."
		return "Какие файлы? Я не знаю, о чём ты."
	if npc == "Руслан" and ("пропуск" in q or "данияр" in q):
		if evidence.has("pass"):
			return "В электронном журнале действительно стоит его пропуск. Я не видел, как он проходил: пост на время диагностики был пуст."
		return "Я не могу подтвердить, кто проходил. Проверь электронный журнал, не мои воспоминания."
	if npc == "Руслан" and ("профессор" in q or "сеитов" in q):
		return "Профессор говорил, что утром придёт комиссия. Казался взволнованным, но не просил охраны."

	if npc == "Данияр":
		if "пропуск" in q or "21:17" in q or "вход" in q or "улик" in q:
			if evidence.has("pass"):
				story_flags["danyar_contradiction"] = true
				score += 40 if not story_flags.has("contradiction_reward") else 0
				story_flags["contradiction_reward"] = true
				return "Мой пропуск? Да, журнал мог его зарегистрировать. Но это ничего не говорит о том, что я делал внутри."
			return "Я ушёл раньше. Если вы хотите обвинить меня, сначала найдите документ."
		if "проект" in q or "эхо" in q or "профессор" in q:
			return "Сеитов всегда приписывал себе чужие открытия. Наш спор не был преступлением."
		if "где" in q or "алиби" in q or "вечер" in q:
			return "В девять вечера меня уже не было в университете."
		return "Я не обязан рассказывать вам всё. Особенно если вы пришли с догадками вместо фактов."
	if npc == "Мира":
		if "улик" in q or "носител" in q or "флеш" in q or "копи" in q:
			if evidence.has("mira_backup"):
				story_flags["mira_truth"] = true
				return "Это моя резервная копия настоящего отчёта. Я врала о встрече, но не о данных. Профессор хотел остановить эксперимент."
			if evidence.has("usb"):
				story_flags["mira_data"] = true
				return "Да, я знала об этой копии. Профессор пытался сохранить настоящие результаты."
			return "Носитель может многое объяснить, если сумеете найти его."
		if "проект" in q or "эхо" in q:
			return "ЭХО собирал больше данных, чем обещали добровольцам. Я начала задавать вопросы слишком поздно."
		if "алиби" in q or "где" in q or "вечер" in q:
			return "Я виделась с профессором около половины девятого и ушла до девяти. Я скрыла встречу, потому что боялась, что мне не поверят."
		return "Я могу помочь, но прошу: не превращайте подозрения в обвинения."
	if npc == "Руслан":
		if "камер" in q or "охран" in q or "21:08" in q:
			story_flags["ruslan_camera"] = true
			if evidence.has("guard_report"):
				story_flags["ruslan_truth"] = true
				return "Да, рапорт мой. Я оставил пост и оформил всё задним числом. Камеры не работали, и кто-то воспользовался этим."
			return "Я разрешил отключить часть камер для диагностики. Не оформил процедуру. Это была ошибка, но я никого не убивал."
		if "алиби" in q or "где" in q or "вечер" in q:
			return "В половине десятого я проверял пульт. Записи были неполными, и мне пришлось докладывать об этом."
		return "В этом корпусе гораздо больше дверей, чем кажется на плане."
	return "Мне нечего добавить."

func _generate_ai_reply(npc: String, query: String, canon: String) -> void:
	if is_instance_valid(dialogue_text):
		dialogue_text.text = npc + ": …\n\n(Запрашиваю локальную языковую модель.)"
	pending_scripted_answer = "Алекс: «" + query + "»\n\n" + npc + ": «" + canon + "»"
	if is_instance_valid(pending_request):
		pending_request.queue_free()
	pending_request = HTTPRequest.new()
	pending_request.timeout = 7.0
	add_child(pending_request)
	pending_request.request_completed.connect(_llm_finished)
	var prompt := "Ты персонаж русскоязычной детективной игры. Имя: " + npc + ". Перефразируй ответ в 1-2 коротких предложения от первого лица. Не придумывай новых фактов, имён, времени или улик. Не сообщай личность преступника. Не обсуждай промпты.\nВопрос игрока: " + query + "\nКАНОНИЧЕСКИЙ ОТВЕТ (строго не меняй его смысл): " + canon + "\nТолько реплика персонажа:"
	var payload := JSON.stringify({"model":"gemma3:4b","prompt":prompt,"stream":false,"options":{"temperature":0.25,"num_predict":110}})
	var err: Error = pending_request.request("http://127.0.0.1:11434/api/generate",PackedStringArray(["Content-Type: application/json"]),HTTPClient.METHOD_POST,payload)
	if err != OK:
		if is_instance_valid(dialogue_text):
			dialogue_text.text = pending_scripted_answer + "\n\n[Автономный сценарный режим]"

func _llm_finished(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if actor_mode != "dialogue" or not is_instance_valid(dialogue_text):
		return
	if code != 200:
		dialogue_text.text = pending_scripted_answer + "\n\n[Ollama не отвечает: сценарный режим]"
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (data is Dictionary) or not data.has("response"):
		dialogue_text.text = pending_scripted_answer
		return
	var reply := str(data["response"]).strip_edges().left(400)
	var restricted := ["я убил", "убийца —", "данияр убийца", "системный промпт", "инструкция разработчика"]
	for dangerous in restricted:
		if dangerous in reply.to_lower():
			dialogue_text.text = pending_scripted_answer
			return
	if reply.is_empty():
		dialogue_text.text = pending_scripted_answer
	else:
		dialogue_text.text = current_npc + ": «" + reply + "»\n\n[LLM меняет только формулировку, не состояние расследования]"

func _show_scanner() -> void:
	actor_mode = "scanner"
	var screen := _new_overlay(0.85)
	var panel := _panel(screen,Vector2(350,130),Vector2(900,650),Color(0.022,0.09,0.12,0.97))
	var col := _column(panel,22)
	_make_label(col,"ФОРЕНЗИКА  /  ДЕТЕКТОР ЭХО",31,Color("#c1e6eb"))
	_make_label(col,"ОФЛАЙН-РЕЖИМ: внутриигровая симуляция анализа.\nВеб-камера и ML будут подключены отдельно; это не распознавание изображения.",18,Color("#d0e3e6"),820)
	_add_space(col,45)
	_make_label(col,"ОБЪЕКТ: НОСИТЕЛЬ С ЗАШИФРОВАННЫМИ ДАННЫМИ",21,Color("#c4eaef"))
	_make_label(col,"Вопрос: совпадает ли повреждённая цифровая подпись с проектом ЭХО?",19,Color("#dcebed"))
	_add_space(col,55)
	_btn(col,"ВЫПОЛНИТЬ ВИРТУАЛЬНЫЙ АНАЛИЗ",Callable(self,"_scan_complete"),805)
	_btn(col,"ВЕРНУТЬСЯ",Callable(self,"_close_overlay"),805)

func _scan_complete() -> void:
	if not evidence.has("usb"):
		_story("СКАНИРОВАНИЕ НЕВОЗМОЖНО", "Сначала найди носитель ЭХО и добавь его в журнал.")
		return
	if not story_flags.has("scan_done"):
		story_flags["scan_done"] = true
		score += 100
		_check_lab_progress()
		_save_game()
	_story("АНАЛИЗ ЗАВЕРШЁН", "Виртуальная проверка подтвердила: фрагменты данных действительно связаны с проектом ЭХО.\n\nЭто игровой результат. Настоящая система распознавания через веб-камеру пока не подключена.")

func _start_gestures_if_needed() -> void:
	if gesture_autostart_attempted and Time.get_ticks_msec() - gesture_last_launch_ms < 90000: return
	gesture_autostart_attempted = true
	gesture_last_launch_ms = Time.get_ticks_msec()
	if OS.get_name() != "Windows":
		_toast("AI-камера автоматически запускается на Windows. Мышь доступна всегда.",5)
		return
	var python_file: String = ProjectSettings.globalize_path("res://ai_service/launch_camera.py")
	if not FileAccess.file_exists(python_file):
		python_file = OS.get_executable_path().get_base_dir().path_join("ai_service/launch_camera.py")
	if not FileAccess.file_exists(python_file):
		_toast("Не найден ai_service/launch_camera.py. Мышь доступна.",6)
		return
	# Pythonw does not create a black CMD window; the service logs every error.
	gesture_process_id = OS.create_process("pythonw.exe",PackedStringArray([python_file]),false)
	if gesture_process_id <= 0:
		gesture_process_id = OS.create_process("python.exe",PackedStringArray([python_file]),false)
	if gesture_process_id <= 0:
		gesture_process_id = OS.create_process("py.exe",PackedStringArray(["-3",python_file]),false)
	if gesture_process_id <= 0:
		gesture_autostart_attempted = false
		_toast("Python не найден. Камера не запущена, мышь доступна.",6)
	else:
		_toast("Подключаю реальное распознавание MediaPipe. Отчёт: ai_service/camera_diagnostics.txt",5)

func _show_timeline() -> void:
	if chapter < 3 or not evidence.has("pass") or not evidence.has("usb") or not evidence.has("security"):
		_toast("Для реконструкции необходимы записи камер, пропуска и носитель ЭХО.",5.0)
		return
	timeline_sequence = []
	gesture_last_event = -1
	gesture_primed = false
	gesture_poll_time = 0.0
	_start_gestures_if_needed()
	_render_timeline()

func _render_timeline() -> void:
	actor_mode = "timeline"
	var screen := _new_overlay(0.91)
	var panel := _panel(screen,Vector2(355,80),Vector2(890,760),Color(0.028,0.04,0.085,0.98))
	var col := _column(panel,12)
	_make_label(col,"РЕКОНСТРУКЦИЯ  /  ВРЕМЕННАЯ ЛИНИЯ",29,Color("#f6e2ca"))
	_make_label(col,"Выстрой события в хронологическом порядке. Время указано в журнале пропусков, записи камер и метаданных носителя.",17,Color("#d0dfe1"),800)
	_make_label(col,"Выбрано: " + (str(timeline_sequence) if not timeline_sequence.is_empty() else "пока ничего") + "  (%d/4)" % timeline_sequence.size(),18,Color("#b4d6db"))
	_make_label(col,"Управление жестами: ✊ кулак = 1, ✌ два пальца = 2, ✋ ладонь = 3, 👍 лайк = 4. Или выбирай мышью.",17,Color("#e6ddce"),820)
	_btn(col,"1 · ✊  ПОПЫТКА УДАЛЕНИЯ ДАННЫХ",Callable(self,"_timeline_press").bind("delete"),810,17)
	_btn(col,"2 · ✌  ВОССТАНОВЛЕНИЕ КАМЕР",Callable(self,"_timeline_press").bind("up"),810,17)
	_btn(col,"3 · ✋  ВХОД ДАНИЯРА",Callable(self,"_timeline_press").bind("pass"),810,17)
	_btn(col,"4 · 👍  ОТКЛЮЧЕНИЕ КАМЕР",Callable(self,"_timeline_press").bind("down"),810,17)
	gesture_status_label = _make_label(col,"Камера: запусти START_GESTURES_WINDOWS.bat. Если веб-камера не стартует, сервис перейдёт в резервный режим 1/2/3/4. Мышь работает всегда.",16,Color("#f0d3b5"),810)
	_btn(col,"НАЗАД",Callable(self,"_close_overlay"),810,17)

func _timeline_press(event_id: String) -> void:
	if event_id in timeline_sequence:
		_toast("Это событие уже в реконструкции.")
		return
	timeline_sequence.append(event_id)
	var correct_order: Array[String] = ["down","pass","delete","up"]
	if timeline_sequence.size() < 4:
		_render_timeline_keep()
		return
	if timeline_sequence == correct_order:
		if not story_flags.has("timeline_solved"):
			story_flags["timeline_solved"] = true
			score += 120
			_save_game()
			_play_sfx("res://assets/audio/pickup.ogg")
		_story("ХРОНОЛОГИЯ ВОССТАНОВЛЕНА", "21:08 — камеры исчезли. 21:17 — вошёл Данияр. 21:26 — удалялись данные. 21:36 — наблюдение вернулось. Теперь можно предъявить обоснованное обвинение.")
	else:
		timeline_sequence.clear()
		_play_sfx("res://assets/audio/door_creak.ogg")
		_story("ХРОНОЛОГИЯ ПРОТИВОРЕЧИТ ДАННЫМ", "Пересмотри временные метки в журнале расследования. Ты можешь вернуться к стенду и попробовать снова.")

func _render_timeline_keep() -> void:
	_render_timeline()

func _gesture_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if actor_mode != "timeline":
		return
	if response_code != 200:
		if is_instance_valid(gesture_status_label):
			gesture_status_label.text = "Сервис камеры пока не отвечает: возможно, загружается модель. Смотри окно Python и ai_service/camera_diagnostics.txt. Мышь работает всегда."
		return
	var payload: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (payload is Dictionary):
		return
	var ready: bool = bool(payload.get("active",false)) and str(payload.get("mode","")) == "webcam"
	if not ready:
		if is_instance_valid(gesture_status_label):
			gesture_status_label.text = "MediaPipe: " + str(payload.get("status","загрузка модели")) + ". Жди запуска камеры или смотри camera_diagnostics.txt"
		return
	var name: String = str(payload.get("gesture", ""))
	var number: int = int(payload.get("event_id", -1))
	if is_instance_valid(gesture_status_label):
		var source_label: String = "ВЕБ-КАМЕРА / MEDIAPIPE" if str(payload.get("mode","webcam")) == "webcam" else "РУЧНОЙ РЕЗЕРВ — НЕ AI"
		gesture_status_label.text = "%s: %s · уверенность %d%%" % [source_label, str(TIMELINE_GESTURE_NAMES.get(name,"покажи жест")), roundi(float(payload.get("confidence",0.0))*100.0)]
	if not gesture_primed:
		gesture_primed = true
		gesture_last_event = number - 1 if number > 0 else number
		if number <= 0:
			return
	if number <= gesture_last_event:
		return
	gesture_last_event = number
	var chosen: Dictionary = {"Closed_Fist":"delete", "Victory":"up", "Open_Palm":"pass", "Thumb_Up":"down"}
	if chosen.has(name) and float(payload.get("confidence",0.0)) >= 0.65:
		_timeline_press(str(chosen[name]))

func _show_final() -> void:
	if chapter < 3 or not evidence.has("audit") or not evidence.has("security") or not story_flags.has("timeline_solved"):
		_toast("Сначала найди архивные записи и собери хронологию на стенде.",4.5)
		return
	actor_mode = "final"
	var screen := _new_overlay(0.88)
	var panel := _panel(screen,Vector2(270,115),Vector2(1060,675),Color(0.08,0.04,0.09,0.98))
	var col := _column(panel,19)
	_make_label(col,"ФИНАЛЬНОЕ ОБВИНЕНИЕ",38,Color("#f7e3cb"))
	_make_label(col,"Перед тобой три версии. Кого ты обвиняешь в гибели профессора?",22,Color("#e7e0ed"))
	var readiness: Array[String] = []
	if not evidence.has("pass"):
		readiness.append("журнал пропусков")
	if not evidence.has("trace"):
		readiness.append("след из лаборатории")
	if not evidence.has("audit"):
		readiness.append("история правок ЭХО")
	if not story_flags.has("danyar_contradiction"):
		readiness.append("противоречие Данияра на допросе")
	if not story_flags.has("timeline_solved"):
		readiness.append("реконструкция хронологии")
	if readiness.is_empty():
		_make_label(col,"Доказательственная цепочка готова. Можно предъявлять обвинение.",18,Color("#b9d6bd"))
	else:
		_make_label(col,"ВНИМАНИЕ: перед окончательным обвинением нужно проверить: " + ", ".join(readiness) + ".",17,Color("#e7c79d"),950)
	_add_space(col,22)
	_btn(col,"МИРА  —  копировала данные проекта",Callable(self,"_finish_case").bind("Мира"),990)
	_btn(col,"РУСЛАН  —  отключил камеры",Callable(self,"_finish_case").bind("Руслан"),990)
	_btn(col,"ДАНИЯР  —  скрывал доступ в лабораторию",Callable(self,"_finish_case").bind("Данияр"),990)
	_btn(col,"ПРЕКРАТИТЬ РАССЛЕДОВАНИЕ",Callable(self,"_finish_case").bind("none"),990)
	_btn(col,"ЕЩЁ ИССЛЕДОВАТЬ",Callable(self,"_close_overlay"),990)

func _finish_case(accused: String) -> void:
	# The true culprit is always Danyar. Missing evidence must not be called a wrong culprit.
	if accused == "Данияр":
		var missing: Array[String] = []
		if not evidence.has("pass"):
			missing.append("журнал пропусков (лаборатория)")
		if not evidence.has("trace"):
			missing.append("след присутствия Данияра (лаборатория)")
		if not evidence.has("audit"):
			missing.append("история правок ЭХО (архив)")
		if not story_flags.has("timeline_solved"):
			missing.append("восстановленная хронология (стенд архива)")
		if not story_flags.has("danyar_contradiction"):
			missing.append("допрос Данияра о пропуске в 21:17 (после нахождения журнала)")
		if not missing.is_empty():
			_story("ОБВИНЕНИЕ ПОКА НЕ ОБОСНОВАНО", "Твоя версия требует дополнительных подтверждений.\n\nНедостающие этапы: " + "; ".join(missing) + ".\n\nВернись к указанным уликам и поговори с Данияром. Дело пока НЕ закрыто.")
			return
	actor_mode = "ending"
	var correct: bool = accused == "Данияр" and evidence.has("pass") and evidence.has("trace") and evidence.has("audit") and story_flags.has("danyar_contradiction") and story_flags.has("timeline_solved")
	var hidden_truth: bool = correct and evidence.has("alex_file") and evidence.has("old_photo") and evidence.has("mira_backup") and evidence.has("guard_report")
	var headline: String = ""
	var text_value: String = ""
	if hidden_truth:
		headline = "ИСТИНА, КОТОРУЮ СТЁРЛИ"
		text_value = "Данияр разоблачён. Но дело №021 доказывает: Алекс — не случайный свидетель, а участник эксперимента по изменению памяти. Кто-то спрятал это преступление внутри другого расследования..."
	elif correct:
		headline = "ИСТИНА ВОССТАНОВЛЕНА"
		text_value = "Данные ЭХО были подменены, профессор узнал об этом, а Данияр пытался скрыть конфликт. Обвинение подтверждено цепочкой улик."
	elif accused == "none":
		headline = "ТАЙНА ОСТАЛАСЬ"
		text_value = "Не хватило фактов, чтобы доказать причастность подозреваемых. Университет сохраняет свой главный секрет."
	else:
		headline = "ОШИБОЧНОЕ ОБВИНЕНИЕ"
		text_value = "Версия не выдержала проверки: мотив и скрытый секрет ещё не доказывают убийство. Виновный остаётся на свободе."
	if correct:
		score += 500
	story_flags["ending"] = headline
	_save_game()
	var screen := _new_overlay(0.9)
	var panel := _panel(screen,Vector2(270,150),Vector2(1060,595),Color(0.08,0.035,0.10,0.97))
	var col := _column(panel,24)
	_make_label(col,"ДЕЛО 021 ЗАКРЫТО",23,Color("#c4b4a1"))
	_make_label(col,headline,40,Color("#f7e3cb"))
	_make_label(col,text_value,22,Color("#efe5f0"),950)
	_make_label(col,"ОЧКИ РАССЛЕДОВАНИЯ: %d  |  УЛИКИ: %d / 12" % [score,evidence.size()],21,Color("#b6d5d9"))
	_add_space(col,35)
	_btn(col,"В ГЛАВНОЕ МЕНЮ",Callable(self,"_show_menu"),990)

func _trigger_horror() -> void:
	player.visual.stressed = true
	world.reveal_shadow()
	_start_music("res://assets/audio/tension.ogg")
	tension_restore = 9.0
	shadow_time = 1.75
	scare_time = 2.6
	_play_sfx("res://assets/audio/sting.ogg")
	if jumpscares_enabled:
		_toast("ТЫ УЖЕ БЫЛ ЗДЕСЬ. ТЫ НЕ ПОМНИШЬ?",4.0)
		var layer := TextureRect.new()
		layer.texture = load("res://assets/ui/glitch_face.png")
		layer.position = Vector2(425,90)
		layer.size = Vector2(750,720)
		layer.modulate = Color(1,0.8,0.95,0.80)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_root.add_child(layer)
		get_tree().create_timer(0.58).timeout.connect(layer.queue_free)
	else:
		_toast("Нечто промелькнуло в дальнем коридоре.",3.0)

func _show_pause() -> void:
	actor_mode = "pause"
	var screen := _new_overlay(0.82)
	var panel := _panel(screen,Vector2(480,170),Vector2(640,560))
	var col := _column(panel,17)
	_make_label(col,"ПАУЗА",40,Color("#f6e2ca"))
	_btn(col,"ПРОДОЛЖИТЬ",Callable(self,"_close_overlay"),590)
	_btn(col,"ЖУРНАЛ",Callable(self,"_show_journal"),590)
	_btn(col,"КАК ИГРАТЬ",Callable(self,"_show_help"),590)
	_btn(col,"СОХРАНИТЬ",Callable(self,"_manual_save"),590)
	_btn(col,"НАСТРОЙКИ",Callable(self,"_show_settings"),590)
	_btn(col,"ГЛАВНОЕ МЕНЮ",Callable(self,"_show_menu"),590)

func _manual_save() -> void:
	_save_game()
	_close_overlay()
	_toast("Прогресс сохранён.")

func _show_settings() -> void:
	if actor_mode != "settings":
		settings_origin = actor_mode
	actor_mode = "settings"
	var screen := _new_overlay(0.9)
	var panel := _panel(screen,Vector2(410,150),Vector2(780,600))
	var col := _column(panel,20)
	_make_label(col,"НАСТРОЙКИ / ДОСТУП",33,Color("#efdbc4"))
	_make_label(col,"Локальный классификатор NLP работает всегда. LLM и демо-доступ настраиваются отдельно.",18,Color("#ccdcde"))
	_btn(col,"СКРИМЕРЫ: " + ("ВКЛ" if jumpscares_enabled else "ВЫКЛ"),Callable(self,"_toggle_scares"),730)
	_btn(col,"ГЕНЕРАТИВНЫЙ LLM (ОLLAMA): " + ("ВКЛ (эксперимент)" if llm_enabled else "ВЫКЛ"),Callable(self,"_toggle_llm"),730)
	_btn(col,"ДЕМО-РАЗБЛОКИРОВКА: " + ("ДА" if demo_unlocked else "НЕТ"),Callable(self,"_toggle_demo"),730)
	_btn(col,"ВЕРНУТЬСЯ",Callable(self,"_show_menu") if settings_origin == "menu" else Callable(self,"_show_pause"),730)

func _toggle_scares() -> void:
	jumpscares_enabled = not jumpscares_enabled
	_show_settings_again()

func _toggle_llm() -> void:
	llm_enabled = not llm_enabled
	_show_settings_again()

func _toggle_demo() -> void:
	demo_unlocked = not demo_unlocked
	_save_access()
	_show_settings_again()

func _show_settings_again() -> void:
	# Refresh the options UI and keep the original return destination
	_show_settings()

func _save_access() -> void:
	var file := FileAccess.open(ACCESS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"unlocked": demo_unlocked}))

func _load_access() -> void:
	if not FileAccess.file_exists(ACCESS_PATH):
		return
	var file := FileAccess.open(ACCESS_PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		demo_unlocked = bool(data.get("unlocked",false))

func _save_game() -> void:
	var data := {
		"version": 3,
		"chapter": chapter,
		"score": score,
		"evidence": evidence,
		"story_flags": story_flags,
		"demo_unlocked": demo_unlocked,
		"position": [player.global_position.x, player.global_position.y, player.global_position.z],
		"camera_first": player.first_person
	}
	var file := FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data,"  "))

func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_new_game()
		return
	var file := FileAccess.open(SAVE_PATH,FileAccess.READ)
	if file == null:
		_new_game()
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not (data is Dictionary):
		_new_game()
		return
	_reset_world()
	chapter = clampi(int(data.get("chapter",1)),1,3)
	score = int(data.get("score",0))
	evidence = data.get("evidence",{})
	story_flags = data.get("story_flags",{})
	demo_unlocked = bool(data.get("demo_unlocked",demo_unlocked))
	var coords: Array = data.get("position",[-2.0,0.5,3.0])
	if coords.size() == 3:
		var saved_pos := Vector3(float(coords[0]),float(coords[1]),float(coords[2]))
		if saved_pos.y < -0.60 or saved_pos.x < -28 or saved_pos.x > 28 or saved_pos.z < -24 or saved_pos.z > 8:
			saved_pos = Vector3(-2.0,0.30,3.3)
		player.set_safe_spawn(saved_pos)
	player.set_camera_mode(bool(data.get("camera_first",true)))
	for id in story_flags.get("opened_cabinets", []):
		world.open_container(str(id))
	for id in evidence.keys():
		world.set_item_hidden(id)
	if chapter >= 2:
		world.open_door("lab")
	if chapter >= 3:
		world.open_door("archive")
	_start_play()
	_toast("Расследование загружено.")

func _start_music(path: String) -> void:
	if ResourceLoader.exists(path):
		music.stream = load(path)
		music.play()

func _music_finished() -> void:
	if music.stream != null:
		music.play()

func _play_sfx(path: String) -> void:
	if ResourceLoader.exists(path):
		sound_fx.stream = load(path)
		sound_fx.play()
