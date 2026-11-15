extends SceneTree
const Controller = preload("res://scripts/investigation/controller.gd")
const State = preload("res://scripts/campaign/state.gd")
const Route = preload("res://tests/level01_route.gd")
class TestGame extends Controller:
	func _start_music(_path: String) -> void: pass
	func _play_sfx(_path: String) -> void: pass
var total: int = 0
var failures: int = 0
func check(value: bool, message: String) -> void:
	total += 1
	if not value: failures += 1; print("FAIL: "+message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = TestGame.new()
	root.add_child(game)
	await process_frame
	for mode in ["easy","normal","hard"]:
		game.state = State.new()
		game.state.difficulty = mode
		game._load_level(1)
		game._start_play()
		await physics_frame
		check(game.state.missing(1).size() == 13,"13 meaningful required stages")
		game._answer_challenge(0)
		game._collect_evidence("arrival")
		game._advance()
		check(game.state.current == 1 and not game.story_flags.get("challenge_1",false),"legacy two-click path blocked")
		check(not game.rules.read_source(game.state,"l1_sensor").ok,"locked drawer cannot be looted")
		check(not game.rules.restore_message(game.state,["m3","m1","m4","m0","m2"]).ok,"message needs time correction")
		check(not game.rules.gate(game.state),"no guest pass no gate")
		game._show_dialogue("Руслан")
		game._ask_npc("Когда вы закрыли корпус?")
		check(game.evidence.has("l1_guard"),"NLP witness statement")
		game._read_source("l1_schedule")
		game._read_source("l1_maintenance")
		var before: int = int(game.rules.metrics(game.state,1).mistakes)
		var bad: Dictionary = game.rules.deduce(game.state,"route",["l1_guard"],"guilty")
		check(not bad.ok and str(bad.message).contains("личность"),"wrong implication explains scope, not correct answer")
		check(int(game.rules.metrics(game.state,1).mistakes) == before+1,"error counted")
		var rating_before: int = int(game.rules.report(game.state,1).quality)
		game.rules.deduce(game.state,"route",game.rules.expected(game.state,"route"),"closed")
		check(int(game.rules.report(game.state,1).quality) < rating_before,"guessing reduces quality")
		check(not game.rules.deduce(game.state,"route",["l1_guard","l1_guard"],"alternative").ok,"duplicate evidence rejected")
		game._show_board("route")
		game.selected_sources = game.rules.expected(game.state,"route").duplicate()
		game.predicate_picker.selected = 1
		game.justification.text = "Нужны разные входы, не обвинение"
		game._submit_deduction()
		check(game.story_flags.get("l1_route",false),"actual deduction UI callback")
		game._show_presentation("drawer")
		game.selected_sources = ["l1_schedule","l1_maintenance"]
		game._submit_presentation()
		check(game.story_flags.get("l1_drawer",false),"two-source presentation grants drawer")
		var drawer_at: Vector3 = game.world.item_position("l1_drawer_object")
		game.player.set_safe_spawn(drawer_at+Vector3(0,0,0.8))
		game._interact()
		check(game.story_flags.get("l1_drawer_open",false),"physical E opens drawer")
		game._interact()
		check(game.evidence.has("l1_sensor"),"second E reads journal")
		game._read_source("l1_clock")
		game._show_terminal()
		game._submit_clock("21:05")
		check(not game.story_flags.get("l1_time",false),"wrong clock direction rejected")
		game._show_terminal()
		game._submit_clock("20:51")
		check(game.story_flags.get("l1_time",false),"correct clock via UI")
		game._show_packets()
		game._append_packet("m3")
		game._append_packet("m1")
		check(game.state.save_to("user://level01_partial.json"),"partial state saved")
		var loaded = State.new()
		check(loaded.load_from("user://level01_partial.json"),"partial state reload")
		check(loaded.flags.get("l1_packet_draft",[]) == ["m3","m1"] and loaded.flags.get("l1_drawer_open",false),"draft and drawer survive")
		game.state = loaded
		game._load_level(1)
		game._show_packets()
		check(game.packet_order == ["m3","m1"],"packet UI restores draft")
		game._append_packet("m0")
		game._append_packet("m4")
		game._append_packet("m2")
		game._submit_packets()
		check(not game.evidence.has("l1_message"),"wrong packet links rejected")
		game.packet_order = ["m3","m1","m4","m0","m2"]
		game._submit_packets()
		check(game.evidence.has("l1_message"),"message restored")
		game._close_overlay()
		check(game.story_flags.get("l1_echo_seen",false),"echo event triggered once")
		game._show_inspector()
		game.inspect_yaw = 0
		game.inspect_zoom = 1.6
		game._confirm_inspection()
		check(not game.evidence.has("l1_badge"),"front face no hidden clue")
		game.inspect_yaw = 180
		game.inspect_zoom = 1.5
		game._update_inspection()
		game._confirm_inspection()
		check(game.evidence.has("l1_badge"),"rotation and zoom reveal clue")
		game._read_source("l1_receipt")
		check(game.rules.report(game.state,1).optional == 2,"optional findings counted")
		game._show_board("final")
		game.selected_sources = game.rules.expected(game.state,"final").duplicate()
		game.predicate_picker.selected = 2
		game._submit_deduction()
		check(game.story_flags.get("l1_final",false),"final deduction supported")
		game._show_presentation("access")
		game.selected_sources = ["l1_message","l1_sensor"]
		game._submit_presentation()
		check(game.evidence.has("l1_access"),"guest authorization granted")
		game.rules.gate(game.state)
		game.world.apply_state(game.state)
		check(game.state.missing(1).is_empty(),"all required stages done")
		game._advance()
		check(game.actor_mode == "level_summary" and game.state.current == 1,"summary before transition")
		game._confirm_level()
		check(game.state.current == 2 and 1 in game.state.completed,"transition after confirmation")
		check(game.state.flags.has("rating_1"),"rating saved")
		var snapshot: Dictionary = game.state.pack().duplicate(true)
		game._replay_level(1)
		check(not game.evidence.has("l1_badge") and not game.story_flags.get("l1_gate",false),"replay clears L1-specific state")
		Route.solve(game,true)
		game._advance()
		game._confirm_level()
		check(game.state.pack() == snapshot,"replay restores exact main progress")
		var clean = State.new()
		clean.difficulty = mode
		game.state = clean
		game._load_level(1)
		Route.solve(game,true)
		check(game.rules.report(game.state,1).grade == "S","S for clean full investigation")
		for i in range(30): game.rules.error(game.state,1,"test","Не подтверждено")
		check(game.rules.report(game.state,1).grade == "C" and game.state.missing(1).is_empty(),"many mistakes lower rating but never softlock")
		print("LEVEL01 ROUTE: "+mode+" PASS")
	game.queue_free()
	await process_frame
	print("LEVEL01 CHECKS: %d/%d; failures=%d" % [total-failures,total,failures])
	quit(0 if failures == 0 else 1)
