# Handoff: Dungeon Keeper clone (Godot / GDScript)

Written 2026-11-22 (evening). The code state below comes from the files José shared at the end of this session. Check his current files before assuming anything.

## Goal

José is building a top-down Dungeon Keeper clone in Godot: a 100x100 grid of `Tile` objects, and imps that pathfind (AStarGrid2D) and dig marked walls.

Long-term vision:
- Dozens of autonomous creatures per side, with states (eat, sleep, train, dig, idle, fight, wander allied territory).
- The player can pick up minions and move them.
- Free, fluid movement with collisions between characters and the map.
- Later: an AI "good" faction (knights, humans) against the player's "evil" faction (imps, monsters). Later still, multiplayer where two players can share a faction.
- Three separate concepts: **owner** (holds cells/rooms/creatures), **faction** (which unit and room types), **controller** (where orders come from: mouse, AI, network).

He wants foundations now, so later work only adds layers instead of rewriting.

**Restructuring roadmap (the guide for every session):**
1. Separate input from the world. **Done** (one small leftover, see below).
2. Base creature (shared body + data resource per type). **Done.**
3. Jobs: per-owner job list, slots, creature picks its own job, cheap job choosing (fixes lag). **In progress.**
4. Wall health: digging takes time and goes faster with more imps on the same wall (each imp's damage adds up until the wall's health reaches zero).
5. Free movement: collisions, diagonals without clipping wall corners, creatures avoiding each other.

Steps 1-3 are the base; 4 and 5 are layers on top.

**How to work with José:**
- Explain the idea and the structure, make him think it through, and let him write the code. Don't hand over finished code; help when he's stuck.
- When he says he's confused, explain directly (what each line does, old vs new) instead of asking more questions, then give one short check question.
- Say which file each code snippet belongs to (e.g. `# world.gd`) at the top of the snippet.
- American English, short replies. He writes in Portuguese; still answer in English.
- Name the specific function when pointing at a large API class.
- He asked for a direct explanation plus a check that he understood, not only questions.

## What happened this session

- Explained how `jobs` works: `cell_select` creates a `Job`, sets `job.cell`, stores it with `jobs[cell] = job`. Keying by cell gives instant lookup (`jobs.has(cell)`, `jobs[cell]`).
- Corrected a misunderstanding: `class_name Job` is what makes `Job` usable from every script. `extends RefCounted` means it's a plain data object (not a Node, not in the scene tree), freed automatically when nothing references it.
- Key idea taught: references, not copies. One `Job` object is pointed at by `jobs[cell]`, by `creature.job` of each worker, and it holds its creatures in `workers`. Removing it from `jobs` does not clear `creature.job`.
- Explained the dispatcher flow: creatures never read `jobs`; the world's `find_job` picks for them, `give_work` links both sides, the creature walks and emits `arrived(self)`, `on_creature_arrived` digs and releases workers.
- **`give_work` rewritten by José and now correct** (null check, `find_job` called once, link on both sides, path to `job.cell`).
- Explained `spawn_creature` line by line, including `imp.arrived.connect(on_creature_arrived)` (the value passed to `emit` becomes the function's parameter).
- Explained the old `on_creature_arrived`: it received a cell and looped over every imp comparing `new_target`. Now the signal sends the creature, so the parameter type no longer matches. New version uses `creature.job.cell` and loops over `job.workers` only.
- **Correction to an earlier hint:** I suggested `creature.target` might be a leftover to delete. It is not: in `creature.gd`, `target` is the **current waypoint** used by `_process` while walking. Keep it. Just don't set it from the world (the world line that did was already removed).

## Current state (from the files)

**Done:**
- `player_controller.gd` now calls `world.spawn_creature` (right-click works).
- `give_work(creature)` in `world.gd`:
  ```gdscript
  # world.gd
  func give_work(creature: Creature):
      if not creature.is_idle() : return
      var from_cell = conv_to_map(conv_to_local(creature.position))
      var job = find_job(from_cell)
      if job == null : return
      job.add_worker(creature)
      creature.job = job
      creature.path_array = get_best_path(from_cell, job.cell)
  ```
- `Job` (`cell`, `max_workers = 5`, `workers: Array[Creature]`, `has_free_slot`, `add_worker`, `remove_worker` using `erase`).
- `Creature`: `signal arrived(creature)`, emits `arrived.emit(self)` when the path ends; the `path_array` setter resets `indice` and sets state to `IDLE` (empty) or `WALKING`. Setting `path_array = []` does **not** emit `arrived`.
- `CreatureType` (`max_health`, `min_speed`, `max_speed`), `TileType` (`walkable`, `diggable`, `max_health = 40.0`), `Tile` (`type`, `marked`, `owner_id`, `gold_amount`; no current health yet).
- `cell_select` already avoids duplicate jobs through the `not tile.marked` check.

**Still broken / leftovers:**
- `on_creature_arrived(target_position: Vector2i)` is the old version: wrong parameter type and uses the removed `new_target`. The game errors when an imp arrives.
- `cell_deselect` still loops over all imps using `new_target` (nothing calls it yet).
- `find_job` still runs `get_best_path` (up to 4 path searches) for every job; that's the lag. The path is also computed again in `give_work`.
- Step 1 leftover: `world.gd` `_process` calls `restart()`, which reads `Input.is_action_just_released("restart")` inside the world. The key should be read in `PlayerController`, which then calls `world.restart()`.
- Minor: `astar.is_dirty()` in `build_astar` does nothing (it only returns a bool). `astar.region` uses `grid.size()` for both sides, which works only because the grid is square.

## Unanswered check questions (ask him at the start)

1. After `jobs.erase(job.cell)`, does `creature.job` still point to a working Job? Why does that mean you must set `creature.job = null` yourself?
2. What happens if the player marks a cell that already has a Job? (Answer: `not tile.marked` already prevents it.)
3. In `on_creature_arrived`, why release all workers and not only the creature that arrived? What would the other imps do otherwise?
4. With 50 imps and 3 working on a wall, how many imps does the old loop check vs the new one?

## Files

- `world.gd`: grid, AStar, `jobs`, marking, spawning, work assignment, arrival handling.
- `player_controller.gd`: mouse input, selection rectangle, orders to the world (`mark_area`, `spawn_creature`).
- `creature.gd` / `creature_type.gd`: body and shared data sheet.
- `job.gd`: a unit of work (a wall to dig).
- `tile.gd` / `tile_type.gd`: per-cell data / shared tile-kind data.
- `camera_2d.gd`: camera movement and zoom (not touched).
- Scene: a Main root with `World` (holds `TileMapLayer` and `MarkLayer`), `PlayerController` (keep at position 0,0 so the rectangle lines up with the mouse; its `world` export points to World) and `Camera2D` as siblings. `imp_scene` on World is a `PackedScene` pointing to `creature.tscn`.

## Failed attempts and pitfalls

- `debug_draw.queue_free()` to hide the rectangle destroyed the node ("previously freed" error). Fix: a `pressed` flag, and redraw.
- `conv_to_map(start)` on its own line threw the result away. It must be assigned.
- Converting to a cell in the controller and again inside `spawn` placed imps in the wrong place.
- Changing `imp_scene` to type `Creature` made the Inspector slot unfillable and `instantiate()` fail. It must stay a `PackedScene`.
- Deleting the `State.IDLE` branch also removed the `else` that emits `arrived`, so imps never dug.
- `find_job` called `has_free_slot()` on `closest_target` instead of the loop's `job`. Fixed.
- `remove_worker` used `pop_front()`. Fixed to `erase`.
- This session: José first called `find_job` twice in `give_work` (once to check null, once to use it). Fixed by storing it once, then `if job == null: return`.
- This session: `give_work` sent the path to `creature.cell` (doesn't exist). Fixed to `job.cell`.
- Diagonal paths stay off (`DIAGONAL_MODE_NEVER`) until step 5, because imps clipped wall corners.
- Lag scales with the number of marked cells, not imps.

## Next step

1. **`on_creature_arrived(creature)`** in `world.gd` (José writes it):
   1. Read `creature.job` into `job`; return if `null`.
   2. Dig `job.cell` (reuse the current dig lines: tile type, `marked = false`, mark layer, tilemap, `astar.set_point_solid(cell, false)`).
   3. `jobs.erase(job.cell)`.
   4. For each worker in `job.workers.duplicate()`: `job = null`, `path_array = []`, `give_work(worker)`.
   5. Clear `job.workers` after the loop.
2. **`cell_deselect`:** use `jobs[cell]` (check `jobs.has(cell)` first) to find the job and release its workers the same way, instead of looping over every imp.
3. **Test:** set `max_workers` to 2, mark one wall, spawn several imps, check that only 2 go to it and the rest go elsewhere or wait.
4. **Lag fix:** `find_job` chooses the nearest job by straight-line distance (cheap), and the real path is computed only for the chosen one. Avoid computing the path twice.
5. Move the restart key read from `world.gd` to `PlayerController`.
6. Then: rename group `"imps"` to `"creatures"` (search and replace across files), then step 4 (wall health: current health in `Tile`, imps' damage adds up), then step 5 (free movement).
- Open design point for later: all jobs are dig jobs for now; which creature type may take which job comes when a second creature type exists.
