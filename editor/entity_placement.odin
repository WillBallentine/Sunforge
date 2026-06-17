package main

import eng "../engine"
import ui "./ui"
import "core:strings"
import utils "utils"
import rl "vendor:raylib"

ENTITY_GIZMO_HALF :: f32(12)
ENTITY_ROW_H :: f32(22)

Entity_Placement_State :: struct {
	selected:       int,
	dragging:       bool,
	drag_offset:    rl.Vector2,
	drag_start_pos: rl.Vector2,
	list_scroll:    f32,
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
			p.drag_start_pos = es.current_scene.entities[hit].position
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
			cmd := make_entity_place_command(&es.current_scene, new_entity, idx)
			history_push(&es.history, cmd)
			entity_data_destroy(&new_entity)

			p.selected = idx
			rebuild_entity_sprites(es)
			scene_save_current(es)
		}
	}

	if p.dragging && e.input.mouse.left.held && p.selected >= 0 {
		es.current_scene.entities[p.selected].position = world - p.drag_offset
	}

	if p.dragging && e.input.mouse.left.released {
		p.dragging = false
		if p.selected >= 0 {
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
	}

	if p.selected >= 0 && rl.IsKeyPressed(.DELETE) {
		cmd := make_entity_delete_command(&es.current_scene, p.selected)
		history_push(&es.history, cmd)
		p.selected = -1
		rebuild_entity_sprites(es)
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

entity_list_render :: proc(
	p: ^Entity_Placement_State,
	scene: ^Scene_Data,
	rect: rl.Rectangle,
	wheel: f32,
) {
	if len(scene.entities) == 0 {
		rl.DrawText(
			"No Entities Placed",
			i32(rect.x) + ui.PADDING,
			i32(rect.y) + ui.PADDING,
			ui.FONT_SIZE,
			ui.TEXT,
		)
		return
	}

	content_h := f32(len(scene.entities)) * ENTITY_ROW_H
	max_scroll := max(content_h - rect.height, 0)

	if wheel != 0 && rl.CheckCollisionPointRec(ui.ctx.mouse_pos, rect) {
		p.list_scroll -= wheel * 20
	}
	p.list_scroll = clamp(p.list_scroll, 0, max_scroll)

	rl.BeginScissorMode(i32(rect.x), i32(rect.y), i32(rect.width), i32(rect.height))

	for entity, i in scene.entities {
		row := rl.Rectangle {
			rect.x,
			rect.y + f32(i) * ENTITY_ROW_H - p.list_scroll,
			rect.width,
			ENTITY_ROW_H,
		}

		if row.y + row.height < rect.y || row.y > rect.y + rect.height {
			continue
		}

		if_selected := i == p.selected
		hovered := rl.CheckCollisionPointRec(ui.ctx.mouse_pos, row)

		bg := ui.PANEL_BG
		if if_selected {bg = ui.BUTTON_ACTIVE} else if hovered {bg = ui.BUTTON_HOVER}

		rl.DrawRectangleRec(row, bg)
		rl.DrawRectangleLinesEx(row, 1, ui.BORDER)

		label := entity.name if entity.name != "" else "(unnamed)"
		rl.DrawText(
			strings.clone_to_cstring(label, context.temp_allocator),
			i32(row.x) + ui.PADDING,
			i32(row.y) + (i32(row.height) - ui.FONT_SIZE) / 2,
			ui.FONT_SIZE,
			ui.TEXT,
		)

		if hovered && ui.ctx.mouse_pressed {
			p.selected = i
		}
	}

	rl.EndScissorMode()
}

entity_placement_destroy :: proc(p: ^Entity_Placement_State) {

}

