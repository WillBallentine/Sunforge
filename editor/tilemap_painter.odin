package main

import eng "../engine"
import ui "./ui"
import "core:fmt"
import "core:path/filepath"
import rl "vendor:raylib"

Tilemap_Painter_State :: struct {
	active_tile:      int,
	active_layer:     i32,
	erase_mode:       bool,
	painting:         bool,
	stroke:           [dynamic]Tile_Cell_Edit,
	visited:          map[[2]i32]bool,
	palette_scroll:   f32,
	layer_visible:    [eng.MAX_TILE_LAYERS]bool,
	entities_visible: bool,
	pick_mode:        bool,
	show_grid:        bool,
	active_rotation:  u8,
}

Tile_Rotation :: enum u8 {
	R0   = 0,
	R90  = 1,
	R180 = 2,
	R270 = 3,
}

tilemap_painter_init :: proc() -> Tilemap_Painter_State {
	tps: Tilemap_Painter_State
	for _, i in tps.layer_visible {
		tps.layer_visible[i] = true
	}
	tps.stroke = make([dynamic]Tile_Cell_Edit, 0)
	tps.visited = make(map[[2]i32]bool)
	tps.entities_visible = true
	tps.pick_mode = false
	tps.show_grid = false
	tps.active_rotation = 0
	return tps
}

tilemap_painter_update :: proc(
	p: ^Tilemap_Painter_State,
	es: ^Editor_State,
	e: ^eng.Engine,
	panels: Panel_Layout,
) {
	if es.active_tool != .Tilemap do return
	tilemap := &es.scene_tilemap
	if tilemap.cols == 0 || tilemap.rows == 0 {
		return
	}
	if p.active_layer >= tilemap.layers {
		p.active_layer = tilemap.layers - 1
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

	if p.pick_mode {
		if e.input.mouse.right.pressed && in_map {
			tile_idx := tilemap.tiles[p.active_layer][row * tilemap.cols + col]
			if tile_idx >= 0 {
				p.active_tile = int(tile_idx)
				p.erase_mode = false
			}
		}
		return
	}

	if e.input.mouse.left.pressed && in_world {
		p.painting = true
		clear(&p.visited)
		clear(&p.stroke)
	}

	if p.painting && e.input.mouse.left.held && in_map {
		key := [2]i32{col, row}
		if !p.visited[key] {
			p.visited[key] = true
			new_idx: i32 =
				-1 if p.erase_mode else (i32(p.active_rotation) << 16) | i32(p.active_tile)
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
	es: ^Editor_State,
	tm: ^eng.Tilemap,
	rect: rl.Rectangle,
	tools_rect: rl.Rectangle,
	wheel: f32,
) {
	layer_labels := make([]cstring, eng.MAX_TILE_LAYERS)
	for i in 0 ..< eng.MAX_TILE_LAYERS {
		layer_labels[i] = fmt.ctprintf("Layer %d", i)
	}

	layer_y := tools_rect.y + ui.ROW_HEIGHT + ui.PADDING
	btn_size := f32(ui.ROW_HEIGHT)
	controls_w := btn_size * 2 + ui.PADDING
	selector_w := tools_rect.width / 15
	layer_btn_w := (selector_w - ui.PADDING * f32(tm.layers - 1))
	starting_x := tools_rect.x + (ui.PADDING * 3) + (selector_w * 2)
	layer_x := starting_x
	visibility_x := starting_x

	erase_label: cstring = "Erase: ON" if p.erase_mode else "Erase: OFF"
	erase_btn := rl.Rectangle {
		tools_rect.x + (tools_rect.width - layer_btn_w) - ui.PADDING,
		tools_rect.y,
		layer_btn_w,
		ui.ROW_HEIGHT,
	}
	if ui.ui_button(erase_btn, erase_label) {
		p.erase_mode = !p.erase_mode
	}
	if p.erase_mode {
		rl.DrawRectangleLinesEx(erase_btn, 2, ui.ACCENT)
	}

	tileset_add_label: cstring = "Add Tileset"
	tileset_add_btn := rl.Rectangle {
		tools_rect.x + (tools_rect.width - layer_btn_w) - ui.PADDING,
		tools_rect.y,
		layer_btn_w,
		ui.ROW_HEIGHT,
	}
	if ui.ui_button(tileset_add_btn, tileset_add_label) {
		sel := es.asset_browser.selected
		if sel >= 0 && sel < len(es.asset_browser.assets) {
			entry := es.asset_browser.assets[sel]
			if entry.kind == .TEXTURE {
				full_rel, _ := filepath.join({proj.RESOURCES_DIR, entry.rel_path})

				tileset_tex := scene_texture(es, full_rel)
				new_tileset := eng.Tileset_Info {
					texture   = tileset_tex,
					firstgid  = u32(len(tm.tileset) + 1),
					columns   = ,
					tilecount = i32,
					image_rel = full_rel,
				}
				scene_save_current(es)
			}
		}
	}


	for i in 0 ..< tm.layers {
		bx := layer_x + f32(i) * (selector_w + ui.PADDING) + selector_w
		if ui.ui_button({bx, layer_y + ui.PADDING, layer_btn_w, ui.ROW_HEIGHT}, layer_labels[i]) {
			p.active_layer = i
		}
		if p.active_layer == i {
			rl.DrawRectangleLinesEx(
				{bx, layer_y + ui.PADDING, layer_btn_w, ui.ROW_HEIGHT},
				2,
				ui.ACCENT,
			)
		}
		layer_x += layer_btn_w
	}

	for i in 0 ..< tm.layers {
		bx :=
			visibility_x +
			f32(i) * (selector_w + ui.PADDING) +
			selector_w +
			layer_btn_w +
			ui.PADDING
		if ui.ui_button(
			{bx, layer_y + ui.PADDING, layer_btn_w, ui.ROW_HEIGHT},
			"hide" if p.layer_visible[i] == true else "show",
		) {
			p.layer_visible[i] = !p.layer_visible[i]
			rl.DrawRectangleLinesEx(
				{bx, layer_y + ui.PADDING, layer_btn_w, ui.ROW_HEIGHT},
				2,
				ui.ACCENT,
			)
		}
		visibility_x += layer_btn_w
	}

	if ui.ui_button(
		{starting_x + selector_w, tools_rect.y + ui.PADDING, btn_size, ui.ROW_HEIGHT},
		"+",
	) {
		if tm.layers < eng.MAX_TILE_LAYERS {
			cmd := make_layer_add_command(tm)
			history_push(&es.history, cmd)
			p.active_layer = tm.layers - 1
			tilemap_save(es)
		}
	}

	remove_x := starting_x + selector_w + btn_size + ui.PADDING
	if ui.ui_button({remove_x, tools_rect.y + ui.PADDING, btn_size, ui.ROW_HEIGHT}, "-") {
		if tm.layers > 1 {
			cmd := make_layer_remove_command(tm, p.active_layer)
			history_push(&es.history, cmd)
			if p.active_layer >= tm.layers {
				p.active_layer = tm.layers - 1
			}
			tilemap_save(es)
		}
	}

	layer_z_labels := [eng.MAX_TILE_LAYERS]cstring{"Z0", "Z1", "Z2", "Z3"}
	z_row_y := tools_rect.y + ui.PADDING
	z_row_x := remove_x + btn_size + ui.PADDING
	for i in 0 ..< tm.layers {
		bx := z_row_x + f32(i) * (selector_w + ui.PADDING)
		ui.ui_drag_float(
			{bx, z_row_y, layer_btn_w, ui.ROW_HEIGHT},
			layer_z_labels[i],
			&tm.layer_z[i],
			0.1,
		)
		if rl.IsMouseButtonReleased(.LEFT) {
			tilemap_save(es)
		}
	}

	z_show_x := z_row_x + (layer_btn_w * 2) + ui.PADDING + (selector_w / 2)
	if ui.ui_button(
		{z_show_x, z_row_y, layer_btn_w, ui.ROW_HEIGHT},
		"hide" if p.entities_visible == true else "show",
	) {
		p.entities_visible = !p.entities_visible
		rl.DrawRectangleLinesEx(
			{z_show_x, layer_y + ui.PADDING, layer_btn_w, ui.ROW_HEIGHT},
			2,
			ui.ACCENT,
		)
	}

	rotation_labels := [4]cstring{"R0", "R90", "R180", "R270"}
	rl.DrawText(
		fmt.ctprintf("Tile Roatation: %v", rotation_labels[p.active_rotation]),
		i32(z_show_x + (layer_btn_w * 3) + ui.PADDING + (selector_w / 2)),
		i32(tools_rect.y) + ui.PADDING,
		ui.FONT_SIZE,
		ui.ACCENT,
	)


	tile_size: f32 = 48
	tiles_per_row := max(i32(rect.width / tile_size), 1)
	total_content_h: f32 = 0
	for ts in tm.tileset {
		total_rows := (ts.tilecount + tiles_per_row - 1) / tiles_per_row
		total_content_h += f32(total_rows) * tile_size
	}
	y_off := rect.y + (ui.ROW_HEIGHT + ui.PADDING) * 2
	list_y := rect.y + (ui.ROW_HEIGHT + ui.PADDING) * 2
	list_h := rect.height - (ui.ROW_HEIGHT - ui.PADDING) * 2
	max_scroll := max(total_content_h - list_h, 0)

	if wheel != 0 && rl.CheckCollisionPointRec(ui.ctx.mouse_pos, rect) {
		p.palette_scroll -= wheel * 20
	}
	p.palette_scroll = clamp(p.palette_scroll, 0, max_scroll)

	palette_y := list_y
	rl.BeginScissorMode(i32(rect.x), i32(list_y), i32(rect.width), i32(list_h))

	scroll_offset := p.palette_scroll

	for ts in tm.tileset {

		ts_rows_count := ts.tilecount / ts.columns
		if ts.tilecount % ts.columns != 0 {ts_rows_count += 1}

		total_tile_rows := (ts.tilecount + tiles_per_row - 1) / tiles_per_row

		for local_idx in 0 ..< ts.tilecount {
			tile_gid := int(ts.firstgid) + int(local_idx)

			g_col := local_idx % tiles_per_row
			g_row := local_idx / tiles_per_row


			dst := rl.Rectangle {
				rect.x + f32(g_col) * tile_size,
				y_off + f32(g_row) * tile_size - p.palette_scroll,
				tile_size,
				tile_size,
			}

			if dst.y + dst.height < list_y || dst.y > list_y + list_h {
				continue
			}


			src_col := local_idx % ts.columns
			src_row := local_idx / ts.columns

			src := rl.Rectangle {
				f32(src_col * tm.tile_w),
				f32(src_row * tm.tile_h),
				f32(tm.tile_w),
				f32(tm.tile_h),
			}


			rl.DrawTexturePro(ts.texture, src, dst, {0, 0}, 0, rl.WHITE)

			if tile_gid == p.active_tile {
				rl.DrawRectangleLinesEx(dst, 2, ui.ACCENT)
			}
			if rl.CheckCollisionPointRec(ui.ctx.mouse_pos, dst) && ui.ctx.mouse_pressed {
				p.active_tile = tile_gid
				p.erase_mode = false
			}
		}

		palette_y += f32(total_tile_rows) * tile_size
		rl.EndScissorMode()
	}
}

tilemap_save :: proc(s: ^Editor_State) {
	if s.current_scene.tilemap_path == "" {
		return
	}
	if len(s.scene_tilemap.tileset) == 0 do return

	tilemap_abs, _ := filepath.join({s.project_root, s.current_scene.tilemap_path})
	defer delete(tilemap_abs)

	eng.tilemap_save_tiled(tilemap_abs, &s.scene_tilemap)
}

tilemap_painter_on_scene_loaded :: proc(p: ^Tilemap_Painter_State, s: ^Editor_State) {
	p.active_layer = 0
}

tilemap_painter_destroy :: proc(p: ^Tilemap_Painter_State) {
	delete(p.stroke)
	delete(p.visited)
}

