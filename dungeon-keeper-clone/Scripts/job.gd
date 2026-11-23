class_name Job
extends RefCounted

var cell: Vector2i
var max_workers: int = 5
var workers: Array[Creature] = []

func has_free_slot() -> bool:
	return workers.size() < max_workers

func add_worker(creature: Creature):
	workers.append(creature)

func remove_worker(creature: Creature):
	workers.erase(creature)
