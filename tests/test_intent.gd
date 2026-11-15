extends SceneTree

# Godot headless test: godot --headless --path . --script res://tests/test_intent.gd
const AI = preload("res://scripts/intent_classifier.gd")
const CASES = [
	["Скажите, где вы были вчера вечером?", "алиби"],
	["У вас есть алиби?", "алиби"],
	["Почему ваш пропуск оказался у лаборатории?", "доступ"],
	["Во сколько вы вошли по карте?", "доступ"],
	["Кто отключил камеры наблюдения?", "камеры"],
	["Почему не работала система видеонаблюдения?", "камеры"],
	["Зачем подделали результаты проекта ЭХО?", "проект"],
	["Что вы знаете о научном исследовании?", "проект"],
	["Можете объяснить найденные доказательства?", "улики"],
	["Что это за флешка с данными?", "улики"],
]

func _initialize() -> void:
	var model = AI.new()
	var passed := 0
	for case in CASES:
		var guess: Dictionary = model.classify(case[0])
		var good: bool = str(guess["intent"]) == str(case[1])
		if good:
			passed += 1
		print(("PASS " if good else "FAIL ") + case[0] + " --> " + str(guess["intent"]))
	print("NLP intent test: %d/%d" % [passed, CASES.size()])
	quit(0 if passed == CASES.size() else 1)
