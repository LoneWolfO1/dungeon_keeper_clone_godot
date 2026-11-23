class_name Creature
extends Node2D
signal arrived(creature)  

var job: Job
var target: Vector2
var indice: int = 1
enum State{IDLE,WALKING,DIGGING}
var health: int
var speed: float

@export var type: CreatureType
@export var path_array: PackedVector2Array:
			set(value):
				path_array = value
				indice = 1
				#print("value:",value)
				if (path_array.is_empty()):
					state = State.IDLE
				else:
					state = State.WALKING

var state: State = State.IDLE

func _ready() -> void:
	speed = randf_range(type.min_speed, type.max_speed)
	health = type.max_health

func is_idle() -> bool:
	return state == State.IDLE

func _process(delta: float) -> void:
	match state:
		State.WALKING:
			if (!path_array.is_empty() and indice < path_array.size()):
				target = path_array[indice]
				if position.distance_to(target) < 10:
					indice += 1
				else:
					var direction = position.direction_to(target)
					if position.distance_squared_to(target) >= 10.0:
						position += direction * speed * delta
			else:
				state = State.IDLE
				arrived.emit(self) # arrived.emit(self)
		State.DIGGING:
			pass
