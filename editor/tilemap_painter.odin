package main

import eng "../engine"
import ui "./ui"
import "core:path/filepath"
import rl "vendor:raylib"

Tilemap_Painter_State :: struct {
	active_tile:       int,
	active_layer:      i32,
	erase_mode:        bool,
	painting:          bool,
	stroke:            [dynamic]Tile_Cell_Edit,
	visited:           map[[2]i32]bool,
	palette_scroll:    f32,
	tileset_image_rel: string,
}

tilemap_painter_init :: proc() -> Tilemap_Painter_State {
	return Tilemap_Painter_State {
		stroke = make([dynamic]Tile_Cell_Edit, 0),
		visited = make(map[[2]i32]bool),
	}
}

tilemap_painter_update :: proc(
	p: ^Tilemap_Painter_State,
	es: ^Editor_State,
	e: ^eng.Engine,
	panels: Panel_Layout,
) {
	tilemap := &es.scene_tilemap
	if tilemap.cols == 0 || tilemap.rows == 0 {
		return
	}

	mouse := e.input.mouse.position
	rt_mouse := rl.Vector2{mouse.x - panels.world.x, mouse.y - panels.world.y}
	world := rl.GetScreenToWorld2D(rt_mouse, es.edit_camera.camera)

	col := i32(world.x) / tilemap.tile_w
	row := i32(world.y) / tilemap.tile_h
	in_map :=
		world.x >= 0 &&
		world.y >= 0 &&
		col >= 0 &&
		col < tilemap.cols &&
		row >= 0 &&
		row < tilemap.rows

	in_world := rl.CheckCollisionPointRec(mouse, panels.world)

	if e.input.mouse.left.pressed && in_world {
		p.painting = true
		clear(&p.visited)
		clear(&p.stroke)
	}

	if p.painting && e.input.mouse.left.held && in_map {
		key := [2]i32{col, row}
		if !p.visited[key] {
			p.visited[key] = true
			new_idx: i32 = -1 if p.erase_mode else i32(p.active_tile)
			old_idx := tilemap.tiles[p.active_layer][row * tilemap.cols + col]
			if old_idx != new_idx {
				append(
					&p.stroke,
					Tile_Cell_Edit{col = col, row = row, old_index = old_idx, new_index = new_idx},
				)
				eng.tilemap_set_tile(tilemap, p.active_layer, col, row, new_idx)
			}
		}
	}

	if p.painting && e.input.mouse.left.released {
		p.painting = false
		if len(p.stroke) > 0 {
			cmd := make_tile_stroke_command(tilemap, p.active_layer, p.stroke[:])
			history_push(&es.history, cmd)
			tilemap_save(es)
		}
		clear(&p.stroke)
		clear(&p.visited)
	}
}

tilemap_painter_render_palette :: proc(
	p: ^Tilemap_Painter_State,
	tm: ^eng.Tilemap,
	rect: rl.Rectangle,
	wheel: f32,
) {
	if tm.tileset.width == 0 || tm.ts_tilecount == 0 {
		return
	}

	erase_label: cstring = "Erase: ON" if p.erase_mode else "Erase: OFF"
	erase_btn := rl.Rectangle{rect.x, rect.y, rect.width, ui.ROW_HEIGHT}
	if ui.ui_button(erase_btn, erase_label) {
		p.erase_mode = !p.erase_mode
	}
	if p.erase_mode {
		rl.DrawRectangleLinesEx(erase_btn, 2, ui.ACCENT)
	}

	tile_size: f32 = 48
	tiles_per_row := max(i32(rect.width / tile_size), 1)
	tile_count := tm.ts_tilecount
	total_rows := (tile_count + tiles_per_row - 1) / tiles_per_row
	ts_cols := tm.ts_columns
	ts_rows := tm.tileset.height / tm.tile_h
	y_off := rect.y + ui.ROW_HEIGHT + ui.PADDING
	list_y := rect.y + ui.ROW_HEIGHT + ui.PADDING
	list_h := rect.height - ui.ROW_HEIGHT - ui.PADDING
	content_h := f32(total_rows) * tile_size
	max_scroll := max(content_h - list_h, 0)

	if wheel != 0 && rl.CheckCollisionPointRec(ui.ctx.mouse_pos, rect) {
		p.palette_scroll -= wheel * 20
	}
	p.palette_scroll = clamp(p.palette_scroll, 0, max_scroll)

	rl.BeginScissorMode(i32(rect.x), i32(list_y), i32(rect.width), i32(list_h))

	for i in 0 ..< tile_count {
		g_col := i % tiles_per_row
		g_row := i / tiles_per_row

		dst := rl.Rectangle {
			rect.x + f32(g_col) * tile_size,
			y_off + f32(g_row) * tile_size - p.palette_scroll,
			tile_size,
			tile_size,
		}

		if dst.y + dst.height < list_y || dst.y > list_y + list_h {
			continue
		}

		src := rl.Rectangle {
			f32((i % ts_cols) * tm.tile_w),
			f32((i / ts_cols) * tm.tile_h),
			f32(tm.tile_w),
			f32(tm.tile_h),
		}

		rl.DrawTexturePro(tm.tileset, src, dst, {0, 0}, 0, rl.WHITE)

		if i == i32(p.active_tile) {
			rl.DrawRectangleLinesEx(dst, 2, ui.ACCENT)
		}
		if rl.CheckCollisionPointRec(ui.ctx.mouse_pos, dst) && ui.ctx.mouse_pressed {
			p.active_tile = int(i)
			p.erase_mode = false
		}
	}
	rl.EndScissorMode()
}

tilemap_save :: proc(s: ^Editor_State) {
	if s.current_scene.tilemap_path == "" || s.tilemap_painter.tileset_image_rel == "" {
		return
	}
	tilemap_abs, _ := filepath.join({s.project_root, s.current_scene.tilemap_path})
	defer delete(tilemap_abs)

	eng.tilemap_save_tiled(tilemap_abs, &s.scene_tilemap, s.tilemap_painter.tileset_image_rel)
}

tilemap_painter_on_scene_loaded :: proc(p: ^Tilemap_Painter_State, s: ^Editor_State) {
	delete(p.tileset_image_rel)
	p.tileset_image_rel = ""
	if s.current_scene.tilemap_path == "" {
		return
	}
	tilemap_abs, _ := filepath.join({s.project_root, s.current_scene.tilemap_path})
	defer delete(tilemap_abs)
	if image_rel, ok := eng.tiled_get_tileset_image(tilemap_abs); ok {
		p.tileset_image_rel = image_rel
	}
}


tilemap_painter_destroy :: proc(p: ^Tilemap_Painter_State) {
	delete(p.stroke)
	delete(p.visited)
	delete(p.tileset_image_rel)
}

