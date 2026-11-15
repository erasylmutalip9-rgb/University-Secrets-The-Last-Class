extends SceneTree

# Automated collision probes. Run with Godot 4.6.x:
# godot --headless --path . --script res://tests/test_collision.gd
const WorldScript = preload("res://scripts/world_builder.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world = WorldScript.new()
	root.add_child(world)
	world.make_world()
	world.open_door("lab")
	world.open_door("archive")
	for _frame in range(3):
		await physics_frame
	var probes := [
		["вестибюль", Vector3(0,3,2)],
		["библиотека", Vector3(-19,3,0)],
		["лаборатория", Vector3(19,3,0)],
		["архив", Vector3(19,3,-16)],
		["мост библиотеки", Vector3(-9.5,3,0)],
		["мост лаборатории", Vector3(9.5,3,0)],
		["мост архива", Vector3(19,3,-8)]
	]
	var passed := 0
	for probe in probes:
		var point: Vector3 = probe[1]
		var ray := PhysicsRayQueryParameters3D.create(point,point+Vector3(0,-4,0))
		var hit := root.get_world_3d().direct_space_state.intersect_ray(ray)
		var ok: bool = not hit.is_empty() and float(hit["position"].y) > -0.4
		print(("PASS" if ok else "FAIL") + " collision: " + str(probe[0]))
		if ok: passed += 1
	print("Floor collision test: %d/%d" % [passed,probes.size()])
	quit(0 if passed == probes.size() else 1)
