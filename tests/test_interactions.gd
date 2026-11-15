extends SceneTree

const WorldScript = preload("res://scripts/world_builder.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world = WorldScript.new()
	root.add_child(world)
	world.make_world()
	var expected: Array[String] = ["note","register","message","pass","trace","usb","scanner","audit","security","timeline","final"]
	var passed: int = 0
	for id in expected:
		var item = _find_item(world,id)
		var ok: bool = not item.is_empty() and item.has("visual") and is_instance_valid(item["visual"])
		if ok:
			passed += 1
		print(("PASS " if ok else "FAIL ") + "physical prop " + id)
	var cabinet := _find_item(world,"message")
	var started_closed: bool = not cabinet.is_empty() and str(cabinet["kind"]) == "container"
	world.open_container("message")
	cabinet = _find_item(world,"message")
	var opened: bool = not cabinet.is_empty() and str(cabinet["kind"]) == "evidence"
	print(("PASS" if started_closed and opened else "FAIL") + " two-step cabinet interaction")
	passed += int(started_closed and opened)
	world.set_item_hidden("message")
	cabinet = _find_item(world,"message")
	var collected: bool = not bool(cabinet["visible"]) and bool(cabinet["visual"].visible)
	print(("PASS" if collected else "FAIL") + " persistent cabinet after collection")
	passed += int(collected)
	print("Interaction tests: %d/%d" % [passed, expected.size() + 2])
	quit(0 if passed == expected.size()+2 else 1)

func _find_item(world: Node, wanted: String) -> Dictionary:
	for item in world.items:
		if str(item["id"]) == wanted:
			return item
	return {}
