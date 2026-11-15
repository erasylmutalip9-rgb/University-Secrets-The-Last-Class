extends SceneTree
const Controller = preload("res://scripts/investigation/controller.gd")
var failures: int = 0
var probes: int = 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = Controller.new()
	root.add_child(game)
	game.actor_mode = "menu"
	for id in range(1,21):
		game._load_level(id)
		if id == 1:
			game.state.flags["l1_gate"] = true
			game.world.apply_state(game.state)
		await physics_frame
		await physics_frame
		var space: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
		# Capsule occupancy at ground level: realistic standing space, not just ray hits.
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.34
		capsule.height = 1.78
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = capsule
		params.collision_mask = 1
		var points: Array[Vector3] = [game.world.get_node("Spawn").position,game.world.get_node("Exit").position+Vector3(0,0,1.1)]
		for item in game.world.items: points.append(item.pos+Vector3(0,0,1.1))
		for point in points:
			params.transform = Transform3D(Basis.IDENTITY,Vector3(point.x,0.95,point.z))
			probes += 1
			if not space.intersect_shape(params).is_empty():
				failures += 1
				print("FAIL occupied approach level %d at %s"%[id,str(point)])
		# Verify continuous traversable route around the authored furniture on a grid.
		var bounds: Vector2 = game.player.campaign_bounds
		var accessible: Dictionary = {}
		var queue: Array[Vector2i] = [Vector2i(0,int(bounds.y)-2)]
		var visited: Dictionary = {}
		while not queue.is_empty():
			var tile: Vector2i = queue.pop_front()
			if visited.has(tile): continue
			visited[tile] = true
			if abs(tile.x) >= bounds.x-0.6 or abs(tile.y) >= bounds.y-0.6: continue
			params.transform = Transform3D(Basis.IDENTITY,Vector3(tile.x,0.95,tile.y))
			if not space.intersect_shape(params).is_empty(): continue
			accessible[tile] = true
			for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]: queue.append(tile+step)
		for item in game.world.items:
			probes += 1
			var reachable: bool = false
			for tile in accessible:
				if Vector2(tile.x,tile.y).distance_to(Vector2(item.pos.x,item.pos.z)) < 2.2:
					reachable = true
					break
			if not reachable:
				failures += 1
				print("FAIL unreachable level %d item %s"%[id,item.id])
		print("PHYSICS %02d: %d walkable grid cells"%[id,accessible.size()])
	# Drive actual CharacterBody movement and jumping at the courtyard spawn.
	game._load_level(1)
	game._start_play()
	await create_timer(0.5).timeout
	var start: Vector3 = game.player.position
	Input.action_press("move_forward")
	await create_timer(0.5).timeout
	Input.action_release("move_forward")
	probes += 1
	if game.player.position.distance_to(start) < 0.8: failures += 1; print("FAIL WASD motion")
	await create_timer(0.3).timeout
	Input.action_press("jump")
	await create_timer(0.12).timeout
	Input.action_release("jump")
	probes += 1
	if game.player.position.y < 0.15: failures += 1; print("FAIL jump")
	await create_timer(0.7).timeout
	probes += 1
	if not game.player.is_on_floor(): failures += 1; print("FAIL landing")
	for ap in [game.music,game.sound_fx,game.footstep_audio,game.whisper_audio]: ap.stop(); ap.stream = null
	await create_timer(0.2).timeout
	game.queue_free()
	await process_frame
	print("PHYSICS CHECKS: %d/%d; failures=%d"%[probes-failures,probes,failures])
	quit(0 if failures == 0 else 1)
