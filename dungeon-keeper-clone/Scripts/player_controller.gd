# player_controller.gd
extends Node2D

@export var world: Node2D
var start_selection: Vector2
var end_selection: Vector2
var pressed: bool = false

func _draw() -> void:
	if pressed:
		var pos = Vector2(min(start_selection.x, end_selection.x), min(start_selection.y, end_selection.y))
		var size = Vector2(abs(start_selection.x - end_selection.x), abs(start_selection.y - end_selection.y))
		draw_rect(Rect2(pos, size), Color(1, 0.04, 0, 0.3), true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			world.spawn_creature(get_global_mouse_position())
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_selection = get_global_mouse_position()
				end_selection = start_selection
				pressed = true
			else:
				pressed = false
				if not event.shift_pressed:
					world.mark_area(world.conv_to_map(start_selection), world.conv_to_map(end_selection))
				else:
					world.deselect_area(world.conv_to_map(start_selection), world.conv_to_map(end_selection))
			queue_redraw()
	if event is InputEventMouseMotion and pressed:
		end_selection = get_global_mouse_position()
		queue_redraw()
