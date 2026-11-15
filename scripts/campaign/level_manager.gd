extends RefCounted

var active: NoirCampus

func load_map(host: Node3D, id: int) -> NoirCampus:
	var scene: PackedScene = load("res://scenes/levels/Level%02d.tscn" % id)
	if scene == null: return null
	var next: NoirCampus = scene.instantiate()
	if is_instance_valid(active):
		host.remove_child(active)
		active.queue_free()
	host.add_child(next)
	next.make_world()
	active = next
	return active
