package main

import eng "../engine"
import ui "./ui"
import "core:path/filepath"
import "core:strings"
import utils "utils"
import rl "vendor:raylib"

ENTITY_GIZMO_HALF :: f32(12)

Entity_Placement_State :: struct {
	selected:       int,
	dragging:       bool,
	drag_offset:    rl.Vector2,
	drag_start_pos: rl.Vector2,
}

entity_placement_init :: proc() -> Entity_Placement_State {
	return Entity_Placement_State{selected = -1}
}

entity_placement_update :: proc(
	p: ^Entity_Placement_State,
	es: ^Editor_State,
	e: ^eng.Engine,
	panels: Panel_Layout,
) {
	if es.active_tool != .Entity do return

	mouse := e.input.mouse.position
	rt_mouse := rl.Vector2{mouse.x - panels.world.x, mouse.y - panels.world.y}
	world := rl.GetScreenToWorld2D(rt_mouse, es.edit_camera.camera)
	in_world := rl.CheckCollisionPointRec(mouse, panels.world)

	if e.input.mouse.left.pressed && in_world {
		hit := entity_at_world_pos(es, world)
		if hit >= 0 {
			p.selected = hit
			p.dragging = true
			p.drag_offset = world - es.current_scene.entities[hit].position
		} else {
			new_entity := Entity_Data {
				name              = strings.clone("entity"),
				position          = world,
				sprite_sheet_path = strings.clone(""),
				animation         = strings.clone(""),
				tags              = make([]string, 0),
				properties        = make(map[string]string),
			}

			idx := len(es.current_scene.entities)
			new_list := make([]Entity_Data, idx + 1)
			copy(new_list[:idx], es.current_scene.entities)
			new_list[idx] = new_entity
			delete(es.current_scene.entities)
			es.current_scene.entities = new_list
			delete(es.entity_sprites)
			es.entity_sprites = make([]eng.Sprite, len(es.current_scene.entities))

			cmd := make_entity_place_command(&es.current_scene, new_entity, idx)
			history_push(&es.history, cmd)
			p.selected = idx
			scene_save_current(es)
		}
	}

	if p.dragging && e.input.mouse.left.held && p.selected >= 0 {
		es.current_scene.entities[p.selected].position = world - p.drag_offset
	}

	if p.dragging && e.input.mouse.left.released {
		p.dragging = false
		new_pos := es.current_scene.entities[p.selected].position
		if new_pos != p.drag_start_pos {
			cmd := make_entity_move_command(
				&es.current_scene,
				p.selected,
				p.drag_start_pos,
				new_pos,
			)
			history_push(&es.history, cmd)
			scene_save_current(es)
		}
	}

	if p.selected >= 0 && rl.IsKeyPressed(.DELETE) {
		cmd := make_entity_delete_command(&es.current_scene, p.selected)
		history_push(&es.history, cmd)
		p.selected = -1
		delete(es.entity_sprites)
		es.entity_sprites = make([]eng.Sprite, len(es.current_scene.entities))
		scene_save_current(es)
	}
}

entity_at_world_pos :: proc(es: ^Editor_State, world: rl.Vector2) -> int {
	for entity, i in es.current_scene.entities {
		if rl.CheckCollisionPointRec(world, entity_gizmo_rect(entity.position)) {
			return i
		}
	}
	return -1
}

entity_gizmo_rect :: proc(pos: rl.Vector2) -> rl.Rectangle {
	return {
		pos.x - ENTITY_GIZMO_HALF,
		pos.y - ENTITY_GIZMO_HALF,
		ENTITY_GIZMO_HALF * 2,
		ENTITY_GIZMO_HALF * 2,
	}
}

entity_placement_destroy :: proc(p: ^Entity_Placement_State) {

}

