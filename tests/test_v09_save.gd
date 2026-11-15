extends SceneTree
const State = preload("res://scripts/campaign/state.gd")
func _initialize() -> void:
	var old := {"version":4,"current":2,"completed":[1],"evidence":{"arrival":true},"flags":{"challenge_1":true},"coins":321,"score":500,"difficulty":"normal","purchases":["classic","watch"],"equipped":{"skin":"classic","accessory":"watch"},"achievements":["first_case"],"stats":{"mistakes":2,"hints":1,"questions":4},"settings":{"volume":0.4,"scares":false}}
	var s = State.new()
	var ok: bool = s.write_json("user://v09_fixture.json",old) and s.load_from("user://v09_fixture.json")
	ok = ok and s.current == 2 and s.coins == 321 and s.equipped.accessory == "watch" and s.completed == [1]
	var snapshot: Dictionary = s.pack().duplicate(true)
	ok = ok and s.begin_replay(1) and not s.missing(1).is_empty()
	s.end_replay()
	ok = ok and s.pack() == snapshot
	old.current = 1
	old.completed = []
	s.unpack(old)
	ok = ok and not s.complete_level() and not s.missing(1).is_empty()
	print("V09 SAVE COMPATIBILITY: ","PASS" if ok else "FAIL")
	quit(0 if ok else 1)
