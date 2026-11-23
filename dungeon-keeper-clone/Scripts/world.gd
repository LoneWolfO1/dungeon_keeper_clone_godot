extends Node2D

# ==================== Variables ====================


var grid: Array = []
var astar := AStarGrid2D.new()
var noise := FastNoiseLite.new()
var jobs: Dictionary = {}

@export var imp_scene: PackedScene
@export var rock: TileType
@export var dug_floor: TileType

@onready var tile_map: TileMapLayer = $TileMapLayer
@onready var mark_layer: TileMapLayer = $MarkLayer


# ================== AUX ==========================

func conv_to_map(pos)-> Vector2i:
	return tile_map.local_to_map(pos)

func conv_to_local(pos) -> Vector2:
	return tile_map.to_local(pos)

# ==================== Start ====================


func _ready() -> void:
	build_grid(100,100,rock)
	generate_terrain()
	build_astar()
	draw_grid()



func _process(_delta: float) -> void:
	restart()


# ==================== Grid ====================


func build_grid(width: int,height: int , rock_type: TileType ) -> void:
	for x in width:
		grid.append([])
		for y in height:
			var tile := Tile.new()
			tile.type = rock_type
			grid[x].append(tile)



func is_inside(cell: Vector2i) -> bool:
		return cell.x >= 0 and cell.x < grid.size() \
		and cell.y >= 0 and cell.y < grid[0].size()


# ==================== Terrain Generation ====================


func generate_terrain() -> void:
	noise.seed = randi()
	noise.frequency = 0.3
	for x in grid.size():
		for y in grid[x].size():
			var value = noise.get_noise_2d(x, y)
			if (value >= 0):
				grid[x][y].type = dug_floor
				grid[x][y].marked = false
			else:
				grid[x][y].type = rock
				grid[x][y].marked = false



func restart():
	if (Input.is_action_just_released("restart")):
		generate_terrain()
		mark_layer.clear()
		build_astar()
		draw_grid()
		jobs.clear()
		for imp in get_tree().get_nodes_in_group("imps"):
			imp.queue_free()


# ==================== Draw ====================


func draw_grid():
	for x in grid.size():           
		for y in grid[x].size():    
			var tile = grid[x][y]
			if (tile.type == rock):
				tile_map.set_cell(Vector2i(x, y), 0, Vector2i(1,0))
			if (tile.type == dug_floor):
				tile_map.set_cell(Vector2i(x, y), 0, Vector2i(0,0))


func update_selected_mark(x: int, y :int):
	var tile = grid[x][y]
	if tile.marked:
		mark_layer.set_cell(Vector2i(x, y), 0, Vector2i(1,1))
	else:
		mark_layer.erase_cell(Vector2i(x,y))


# ==================== ASTAR ====================


func build_astar() -> void:
	astar.region = Rect2i(0, 0, grid.size(), grid.size())
	astar.cell_size = Vector2(16, 16)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	astar.is_dirty()
	for x in grid.size():
		for y in grid[x].size():
			astar.set_point_solid(Vector2i(x, y), not grid[x][y].type.walkable)



# ==================== Select ====================

func mark_area(start: Vector2i,end: Vector2i):
	var range_x = range(min(start.x,end.x),max(end.x,start.x)+1)
	var range_y = range(min(start.y,end.y),max(end.y,start.y)+1)
	for x in range_x:
		for y in range_y:
			cell_select(Vector2i(x, y))
	give_work_to_all()


func cell_select(cell: Vector2i) -> void:
	if (is_inside(cell)):
		var tile = grid[cell.x][cell.y] 
		if (tile.type.diggable and not tile.marked):
			tile.marked = true
			update_selected_mark(cell.x,cell.y)
			var job := Job.new()
			job.cell = cell
			jobs[cell] = job


func cell_deselect(cell: Vector2i):
	if(is_inside(cell)):
		var tile = grid[cell.x][cell.y] 
		jobs.erase(cell)
		mark_layer.erase_cell(cell)
		tile.marked = false 
		for imp in get_tree().get_nodes_in_group("imps"):
			if (not imp.is_idle() and imp.new_target == cell):
				imp.path_array = []
				give_work(imp)


# ==================== Imps ====================


func get_best_path(inicial_pos: Vector2i,selected_pos: Vector2i) -> PackedVector2Array:
	var neighbors: Array[Vector2i] = [Vector2i(selected_pos.x-1,selected_pos.y),
									  Vector2i(selected_pos.x+1,selected_pos.y),
									  Vector2i(selected_pos.x,selected_pos.y-1),
									  Vector2i(selected_pos.x,selected_pos.y+1)]
	var path
	var best: Array = []
	var pts := PackedVector2Array()
	for n in neighbors:
		if (!is_inside(n)):
			continue
		path = astar.get_id_path(inicial_pos,n)
		if (path.is_empty()):
			continue
		if (best.is_empty() or path.size() <= best.size()):
			best = path
	for p in best:
			pts.append(tile_map.map_to_local(p))
	return pts 


func spawn_creature(pos: Vector2) -> void:
	var cell = conv_to_map(pos)
	if is_inside(cell):
		var tile = grid[cell.x][cell.y]
		if tile.type.walkable:
			var imp = imp_scene.instantiate()
			imp.position = pos
			add_child(imp)
			imp.arrived.connect(on_creature_arrived)
			imp.add_to_group("imps")
			give_work(imp)


func give_work(creature: Creature):
	if not creature.is_idle() : return
	var from_cell = conv_to_map(conv_to_local(creature.position))
	var job = find_job(from_cell)
	if job == null : return
	job.add_worker(creature)
	creature.job = job
	creature.path_array = get_best_path(from_cell, job.cell)


func find_job(creature_position: Vector2i ) -> Job:
	var shortest_path: int = 0
	var closest_target: Job 
	for job in jobs.values():
		if(!job.has_free_slot()):
			continue
		var path = get_best_path(creature_position,job.cell)
		if (path.is_empty()):
			continue
		if (shortest_path == 0 or path.size() <= shortest_path):
			shortest_path = path.size()
			closest_target = job
	return closest_target


func on_creature_arrived(target_position: Vector2i) -> void:
	var cell := target_position
	var tile = grid[cell.x][cell.y] 
	tile.type = dug_floor
	tile.marked = false 
	jobs.erase(cell)
	update_selected_mark(cell.x,cell.y)
	tile_map.set_cell(cell, 0, Vector2i(0, 0))
	astar.set_point_solid(cell,false)
	for other in get_tree().get_nodes_in_group("imps"):
		if other.new_target == target_position:
			other.path_array = []
			give_work(other)

func give_work_to_all():
	for imp in get_tree().get_nodes_in_group("imps"):
		give_work(imp)
