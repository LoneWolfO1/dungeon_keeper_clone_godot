extends Camera2D



@export var speed: float = 600.0
var max_zoom: float = 4
var min_zoom: float = 1
var zoom_step: float = 0.05



func _process(delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var current_speed := speed / zoom.x
	position += direction * current_speed * delta

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom += Vector2(zoom_step, zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom -= Vector2(zoom_step, zoom_step)
		var z := clampf(zoom.x, min_zoom, max_zoom)
		zoom = Vector2(z, z)
