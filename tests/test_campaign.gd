extends SceneTree

const State = preload("res://scripts/campaign/state.gd")
const Controller = preload("res://scripts/investigation/controller.gd")
# Bulk logic tests trigger hundreds of pickups in a few frames. Disable playback
# here; actual audio decoding is checked by check_project.py, listening is manual.
class TestGame extends Controller:
	func _start_music(_path: String) -> void: pass
	func _play_sfx(_path: String) -> void: pass

var failures: int = 0
var checks: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var s = State.new()
	check(not s.complete_level(),"fresh level must be blocked")
	check(not s.buy("detective"),"insufficient coins")
	s.coins = 300
	check(s.buy("detective") and s.coins == 120,"purchase deducts once")
	check(s.buy("detective") and s.coins == 120,"owned equip free")
	check(not s.buy("unknown"),"unknown item rejected")
	s.difficulty = "hard"
	s.flags["sentinel"] = true
	check(s.save_to("user://test_campaign.json"),"save writes")
	var t = State.new()
	check(t.load_from("user://test_campaign.json"),"load save")
	check(JSON.parse_string(JSON.stringify(t.pack())) == JSON.parse_string(JSON.stringify(s.pack())),"save/load exact round trip")
	s.coins = 111
	check(s.save_to("user://test_campaign.json"),"second save backup")
	var broken := FileAccess.open("user://test_campaign.json",FileAccess.WRITE)
	broken.store_string("bad json")
	broken.close()
	check(t.load_from("user://test_campaign.json") and t.coins == 120,"corrupt slot recovers backup")
	t.migrate_legacy({"evidence":{"pass":true},"story_flags":{"danyar_contradiction":true,"ending":"old"},"score":500})
	check(t.current == 1 and t.evidence.has("pass") and not t.flags.has("ending"),"legacy import preserves facts, clears ending")
	check(t.flags.has("danyar_contradiction"),"legacy flag retained")
	var game = TestGame.new()
	root.add_child(game)
	await process_frame
	game.state = State.new()
	game._sync_from_state()
	# Avoid user saves; testing is in isolated user-data directory, and no webcam is launched.
	game.gesture_autostart_attempted = true
	for mode in ["easy","normal","hard"]:
		game.state = State.new()
		game.state.difficulty = mode
		for id in range(1,21):
			game._load_level(id)
			game._start_play()
			await physics_frame
			await physics_frame
			check(game.world.level_id == id,"scene loaded %s/%d" % [mode,id])
			check(not game.state.complete_level(),"locked exit %s/%d" % [mode,id])
			var d: Dictionary = game.state.catalog.level(id)
			# Probe ground from above at spawn and along interaction approach lanes.
			var positions: Array[Vector3] = [game.world.get_node("Spawn").position,game.world.get_node("Exit").position+Vector3(0,0,1)]
			for item in game.world.items:
				positions.append(item.pos+Vector3(0,0,1.1))
			for point in positions:
				var ray := PhysicsRayQueryParameters3D.create(Vector3(point.x,3.8,point.z),Vector3(point.x,-0.5,point.z),1)
				var hit: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(ray)
				check(not hit.is_empty() and float(hit.position.y) >= -0.1,"floor near interactable %d %s" % [id,str(point)])
			if id == 1:
				preload("res://tests/level01_route.gd").solve(game)
				check(game.state.missing(1).is_empty(),"level1 new investigation complete")
				game._advance()
				game._confirm_level()
				check(game.state.current == 2,"level1 transition after summary")
				continue
			# The current route unlocks the workstation after the local expertise.
			for clue in d.evidence:
				if id != 11 or clue != "usb": game._collect_evidence(str(clue))
			game._show_casework()
			check(game.actor_mode == "casework","expertise opens %d" % id)
			var task: Dictionary = game.casework_catalog[str(id)]
			match str(task.kind):
				"code":
					game._casework_code("invalid")
					game._casework_code(str(task.correct))
				"sequence":
					game._casework_choice(-1)
					for choice in task.correct: game._casework_choice(int(choice))
				_:
					game._casework_choice(-1)
					game._casework_choice(int(task.correct))
			check(game.story_flags.get("casework_%d" % id,false),"expertise solved %d" % id)
			# Exercise an incorrect response, then correct puzzle (extra stage on hard).
			game._show_challenge()
			game._answer_challenge((int(d.answer)+1)%3)
			check(not game.story_flags.get("challenge_%d"%id,false),"wrong answer stays retryable")
			game._answer_challenge(int(d.answer))
			if mode == "hard":
				check(not game.story_flags.get("challenge_%d"%id,false),"hard requires second check")
				game._answer_challenge(0)
			for clue in d.evidence:
				game._collect_evidence(str(clue))
				check(game.evidence.has(clue),"clue collected %s"%clue)
				for marker in game.world.guidance:
					if marker.get_meta("clue") == clue: check(not marker.visible,"collected clue marker hidden")
			if not str(d.npc).is_empty():
				game._show_dialogue(d.npc)
				game._ask_npc({2:"Что с профессором?",7:"Где вы были вечером?",13:"Чья копия результатов?",14:"Почему отключены камеры?",15:"Почему ваш пропуск вошёл в 21:17?",20:"Вы удаляли данные в 21:26?"}.get(id,"Где вы были?"))
			if id == 19:
				game._show_timeline()
				for event in ["up","pass","injury","delete","down"]: game._timeline_press(event)
				check(not game.story_flags.get("timeline_solved",false),"bad timeline rejected")
				game._show_timeline()
				for event in ["down","pass","injury","delete","up"]: game._timeline_press(event)
			game._sync_to_state()
			check(game.state.missing(id).is_empty(),"goals complete %s/%d: %s" % [mode,id,str(game.state.missing(id))])
			if id < 20:
				game._advance()
				game._confirm_level()
				check(game.state.current == id+1,"actual transition %d"%id)
			else:
				check(game.state.ending("Данияр") == "correct","correct ending")
				check(game.state.ending("Данияр",true) == "secret","secret ending")
				check(game.state.ending("Мира") == "wrong","wrong ending")
				check(game.state.ending("none") == "unresolved","unresolved ending")
				game._finish_case("Данияр")
				check(20 in game.state.completed,"final completion")
			print("PASS route: %s / %02d %s" % [mode,id,d.title])
		var balance: int = game.state.coins
		game.state.complete_level()
		check(game.state.coins == balance,"no duplicate completion reward")
		var before: Dictionary = game.state.pack().duplicate(true)
		check(game.state.begin_replay(4),"replay accepted")
		check(not game.state.buy("urban"),"replay purchase blocked")
		game.state.coins = 99999
		game.state.end_replay()
		check(game.state.pack() == before,"replay fully restores state")
		check(game.state.save_to("user://test_campaign_full.json"),"full progress save")
		var again = State.new()
		check(again.load_from("user://test_campaign_full.json") and JSON.parse_string(JSON.stringify(again.pack())) == JSON.parse_string(JSON.stringify(game.state.pack())),"full progress reload")
	game.player.toggle_camera()
	check(not game.player.first_person,"TPS camera toggle")
	game.player.toggle_camera()
	check(game.player.first_person,"FPS camera toggle")
	game.player.toggle_flashlight()
	check(game.player.flashlight_on,"flashlight toggle")
	game.state.flags.erase("danyar_coverup")
	check(game.state.ending("Данияр") == "insufficient","coverup required for correct accusation")
	for player_audio in [game.music,game.sound_fx,game.footstep_audio,game.whisper_audio]:
		player_audio.stop()
		player_audio.stream = null
	await create_timer(0.2).timeout
	game.queue_free()
	await process_frame
	print("CAMPAIGN CHECKS: %d passed / %d total; failures=%d" % [checks-failures,checks,failures])
	quit(0 if failures == 0 else 1)
