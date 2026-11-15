extends SceneTree
const Controller = preload("res://scripts/investigation/controller.gd")
class TestGame extends Controller:
	func _start_music(_path: String) -> void: pass
	func _play_sfx(_path: String) -> void: pass

func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = TestGame.new()
	root.add_child(game)
	game._load_game()
	await physics_frame
	var ok: bool = game.state.current == 20 and game.state.completed.size() == 20 and game.state.evidence.has("l1_message") and game.state.difficulty == "hard" and game.state.ending("Данияр") == "correct"
	print("RESTART SAVE: ","PASS" if ok else "FAIL")
	for ap in [game.music,game.sound_fx,game.footstep_audio,game.whisper_audio]: ap.stop(); ap.stream = null
	await create_timer(0.2).timeout
	game.queue_free()
	await process_frame
	quit(0 if ok else 1)
