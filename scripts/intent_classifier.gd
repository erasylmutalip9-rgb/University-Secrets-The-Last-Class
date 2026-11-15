extends RefCounted
class_name CaseIntentClassifier

# Обучаемый локальный NLP-классификатор. Multinomial Naive Bayes + Laplace.
# Не нуждается в интернете, аккаунте или API ключах.
# Выход модели реально определяет ветвь игрового диалога.

const TRAINING: Dictionary = {
	"алиби": [
		"где вы были во время убийства", "расскажите ваше алиби", "когда вы ушли вечером",
		"в какое время вы покинули корпус", "кто видел вас после занятий",
		"подтвердите где вы находились", "что вы делали вчера ночью",
		"почему ваше алиби не сходится", "где вы находились в девять"
	],
	"доступ": [
		"почему ваш пропуск использовали в лаборатории", "во сколько вы вошли в корпус",
		"кто открыл дверь своим пропуском", "покажите журнал входа",
		"когда ваш ключ зарегистрировали", "вход в лабораторию в двадцать один семнадцать",
		"дверь открыта вашей картой", "вы проходили по этому пропуску",
		"как объясните время доступа"
	],
	"камеры": [
		"почему отключились камеры наблюдения", "кто выключил видеонаблюдение",
		"что произошло с записями охраны", "во сколько исчезло изображение",
		"система камер была обесточена", "камера в коридоре не работала",
		"вы отключали камеры охранник", "сбой записи на мониторе",
		"восстановление видео наблюдения"
	],
	"проект": [
		"расскажите про научный проект эхо", "что изучал профессор",
		"почему результаты исследования изменены", "кто фальсифицировал данные",
		"зачем проводили секретный эксперимент", "что значит протокол эхо",
		"как работает университетский искусственный интеллект", "почему вы спорили с профессором",
		"объясните подмену результатов"
	],
	"улики": [
		"у меня есть доказательства", "посмотрите на флешку",
		"что находится на носителе", "найдена резервная копия",
		"объясните улику", "вот документ с отпечатком",
		"я нашел следы на стеллаже", "почему удалены файлы",
		"прокомментируйте найденную улику", "вот флешка с данными", "что это за флешка с файлами", "расскажите что за флешка с данными"
	]
}

var _word_counts: Dictionary = {}
var _totals: Dictionary = {}
var _doc_counts: Dictionary = {}
var _vocabulary: Dictionary = {}
var _all_documents: int = 0

func _init() -> void:
	for category in TRAINING:
		_word_counts[category] = {}
		_totals[category] = 0
		_doc_counts[category] = 0
		for sentence in TRAINING[category]:
			_doc_counts[category] += 1
			_all_documents += 1
			for token in _tokens(sentence):
				_vocabulary[token] = true
				_word_counts[category][token] = _word_counts[category].get(token,0) + 1
				_totals[category] += 1

func classify(text: String) -> Dictionary:
	var tokens := _tokens(text)
	var matched := 0
	for word in tokens:
		if _vocabulary.has(word):
			matched += 1
	if matched == 0:
		return {"intent":"другое", "confidence":0.0, "matched":0}
	var log_scores: Dictionary = {}
	var best_intent := "другое"
	var best_score := -INF
	var vocab_size: float = float(_vocabulary.size())
	for category in TRAINING:
		var log_score: float = log(float(_doc_counts[category]) / float(_all_documents))
		var denom: float = float(_totals[category]) + vocab_size
		for token in tokens:
			log_score += log(float(_word_counts[category].get(token,0) + 1) / denom)
		log_scores[category] = log_score
		if log_score > best_score:
			best_score = log_score
			best_intent = category
	var total_exp := 0.0
	for category in log_scores:
		total_exp += exp(float(log_scores[category]) - best_score)
	var confidence: float = 1.0 / maxf(total_exp,0.0001)
	# Unknown or contradictory prompts stay in neutral mode.
	if confidence < 0.30:
		return {"intent":"другое", "confidence":confidence, "matched":matched}
	return {"intent":best_intent, "confidence":confidence, "matched":matched}

func _tokens(source: String) -> Array[String]:
	var cleaned := source.to_lower().strip_edges()
	for mark in ["?", "!", ".", ",", ";", ":", "—", "–", "-", "\"", "'", "(", ")", "\n", "\t", "«", "»"]:
		cleaned = cleaned.replace(mark, " ")
	var result: Array[String] = []
	for piece in cleaned.split(" ",false):
		if piece.length() < 3:
			continue
		# A compact deterministic stem; e.g. камеры / камеру => камер.
		var stem: String = piece.substr(0,mini(piece.length(),5))
		result.append(stem)
	return result
