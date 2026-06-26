package main

import eng "../engine"
import proj "../project"
import ui "./ui"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import rl "vendor:raylib"

Animation_Entry :: struct {
	name:        string,
	first_frame: i32,
	frame_count: i32,
	fps:         f32,
	looping:     bool,
}

Sprite_Sheet_Editor_State :: struct {
	tex:            rl.Texture2D,
	tex_path:       string,
	frame_w:        f32,
	frame_h:        f32,
	columns:        f32,
	animations:     [dynamic]Animation_Entry,
	sel_anim:       int,
	is_selecting:   bool,
	select_start:   i32,
	select_end:     i32,
	preview_anim:   eng.Animation,
	preview_state:  eng.Animation_State,
	save_path:      string,
	_display_scale: f32,
	_display_ox:    f32,
	_display_oy:    f32,
}

sprite_sheet_editor_init :: proc() -> Sprite_Sheet_Editor_State {
	s: Sprite_Sheet_Editor_State
	s.animations = make([dynamic]Animation_Entry)
	s.sel_anim = -1
	s.frame_w = 32
	s.frame_h = 32
	s.columns = 4
	return s
}
sprite_sheet_editor_destroy :: proc(s: ^Sprite_Sheet_Editor_State) {
	for &entry in s.animations {
		delete(entry.name)
	}
	delete(s.animations)
	if s.tex.id != 0 do rl.UnloadTexture(s.tex)
	delete(s.tex_path)
	delete(s.save_path)
	s^ = {}
}

sprite_sheet_assign_texture :: proc(s: ^Sprite_Sheet_Editor_State, es: ^Editor_State) {
	sel := es.asset_browser.selected
	if sel < 0 || sel >= len(es.asset_browser.assets) do return

	entry := es.asset_browser.assets[sel]
	if entry.kind != .TEXTURE do return

	abs_path, _ := filepath.join({es.project_root, proj.RESOURCES_DIR, entry.rel_path})
	if s.tex.id != 0 {
		rl.UnloadTexture(s.tex)
	}
	delete(s.tex_path)

	cstr := strings.clone_to_cstring(abs_path, context.temp_allocator)
	s.tex = rl.LoadTexture(cstr)
	s.tex_path = abs_path

	if s.frame_w > 0 {
		s.columns = f32(s.tex.width / i32(s.frame_w))
	}
}

sprite_sheet_editor_render_world :: proc(
	s: ^Sprite_Sheet_Editor_State,
	viewport: rl.Rectangle,
	camera: eng.Camera_State,
) {
	if s.tex.id == 0 do return

	frame_w := i32(s.frame_w)
	frame_h := i32(s.frame_h)
	columns := i32(s.columns)

	pad: f32 = 16
	scale := min(
		(viewport.width - pad * 2) / f32(s.tex.width),
		(viewport.height - pad * 2) / f32(s.tex.height),
	)

	if scale > 1 do scale = 1

	tw := f32(s.tex.width) * scale
	th := f32(s.tex.height) * scale
	ox := viewport.x + (viewport.width - tw) / 2
	oy := viewport.y + (viewport.height - th) / 2

	src := rl.Rectangle{0, 0, f32(s.tex.width), f32(s.tex.height)}
	dest := rl.Rectangle{ox, oy, tw, th}
	rl.DrawTexturePro(s.tex, src, dest, {0, 0}, 0, rl.WHITE)

	if frame_w > 0 && frame_h > 0 && columns > 0 {
		rows := s.tex.height / frame_h

		for row in 0 ..< rows {
			for col in 0 ..< columns {
				cell_x := ox + f32(col * frame_w) * scale
				cell_y := oy + f32(row * frame_h) * scale
				cell_w := f32(frame_w) * scale
				cell_h := f32(frame_h) * scale
				frame_idx := row * columns + col

				cell_rect := rl.Rectangle{cell_x, cell_y, cell_w, cell_h}

				color := rl.Color{255, 255, 255, 40}
				if s.sel_anim >= 0 {
					sel := s.animations[s.sel_anim]
					if frame_idx >= sel.first_frame &&
					   frame_idx < sel.first_frame + sel.frame_count {
						color = rl.Color{100, 200, 255, 80}
					}
				}

				if s.is_selecting && frame_idx >= s.select_start && frame_idx <= s.select_end {
					color = rl.Color{255, 200, 50, 100}
				}

				rl.DrawRectangleRec(cell_rect, color)
				rl.DrawRectangleLinesEx(cell_rect, 1, rl.Color{255, 255, 255, 60})

				if cell_w >= 24 {
					label := fmt.ctprintf("%d", frame_idx)
					rl.DrawText(
						label,
						i32(cell_x) + 2,
						i32(cell_y) + 2,
						8,
						rl.Color{255, 255, 255, 120},
					)
				}
			}
		}
	}

	s._display_scale = scale
	s._display_ox = ox
	s._display_oy = oy
}

sprite_sheet_editor_update :: proc(
	s: ^Sprite_Sheet_Editor_State,
	e: ^eng.Engine,
	panels: Panel_Layout,
	dt: f32,
) {
	if s.sel_anim >= 0 {
		eng.update_animation_state(&s.preview_state, dt)
	}

	if s.tex.id == 0 || s.sel_anim < 0 do return

	mouse := e.input.mouse.position
	in_viewport := rl.CheckCollisionPointRec(mouse, panels.world)

	if !in_viewport do return

	frame_w := i32(s.frame_w)
	frame_h := i32(s.frame_h)
	if frame_w <= 0 || frame_h <= 0 do return

	local_x := mouse.x - s._display_ox
	local_y := mouse.y - s._display_oy
	if local_x < 0 || local_y < 0 do return

	sheet_x := i32(local_x / s._display_scale)
	sheet_y := i32(local_y / s._display_scale)
	if sheet_x >= s.tex.width || sheet_y >= s.tex.height do return

	columns := i32(s.columns)
	frame_col := sheet_x / frame_w
	frame_row := sheet_y / frame_h
	frame_idx := frame_row * columns + frame_col

	if e.input.mouse.left.pressed {
		s.is_selecting = true
		s.select_start = frame_idx
		s.select_end = frame_idx
	}

	if s.is_selecting && e.input.mouse.left.held {
		s.select_end = frame_idx
		if s.select_end < s.select_start {
			s.select_start, s.select_end = s.select_end, s.select_start
		}
	}

	if s.is_selecting && e.input.mouse.left.released {
		s.is_selecting = false
		entry := &s.animations[s.sel_anim]
		entry.first_frame = s.select_start
		entry.frame_count = s.select_end - s.select_start + 1
		sprite_sheet_rebuild_preview(s)
	}
}

sprite_sheet_editor_render_inspector :: proc(
	s: ^Sprite_Sheet_Editor_State,
	inspector: rl.Rectangle,
	dt: f32,
) {
	x := inspector.x + ui.PADDING
	rw := inspector.width - ui.PADDING * 2
	y := inspector.y + ui.PADDING
	half := (rw - ui.PADDING) / 2

	rl.DrawText("Frame Settings", i32(x), i32(y), ui.FONT_SIZE, ui.ACCENT)
	y += ui.ROW_HEIGHT

	old_fw := s.frame_w
	old_fh := s.frame_h
	old_cols := s.columns

	ui.ui_drag_float({x, y, half, ui.ROW_HEIGHT}, "W", &s.frame_w, 1)
	ui.ui_drag_float({x + half + ui.PADDING, y, half, ui.ROW_HEIGHT}, "H", &s.frame_h, 1)
	y += ui.ROW_HEIGHT + ui.PADDING
	ui.ui_drag_float({x, y, rw, ui.ROW_HEIGHT}, "Columns", &s.columns, 1)
	y += ui.ROW_HEIGHT + ui.PADDING

	s.frame_w = max(s.frame_w, 1)
	s.frame_h = max(s.frame_h, 1)
	s.columns = max(s.columns, 1)

	if s.frame_w != old_fw || s.frame_h != old_fh || s.columns != old_cols {
		sprite_sheet_rebuild_preview(s)
	}

	rl.DrawText("Animations", i32(x), i32(y), ui.FONT_SIZE, ui.ACCENT)
	y += ui.ROW_HEIGHT

	if ui.ui_button({x, y, half, ui.ROW_HEIGHT}, "Add") {
		new_name := fmt.aprintf("anim_%d", len(s.animations))
		append(
			&s.animations,
			Animation_Entry {
				name = new_name,
				first_frame = 0,
				frame_count = 1,
				fps = 8,
				looping = true,
			},
		)
		s.sel_anim = len(s.animations) - 1
		sprite_sheet_rebuild_preview(s)
	}
	if s.sel_anim >= 0 {
		if ui.ui_button({x + half + ui.PADDING, y, half, ui.ROW_HEIGHT}, "Remove") {
			delete(s.animations[s.sel_anim].name)
			ordered_remove(&s.animations, s.sel_anim)
			s.sel_anim = min(s.sel_anim, len(s.animations) - 1)
			sprite_sheet_rebuild_preview(s)
		}
	}

	y += ui.ROW_HEIGHT + ui.PADDING

	for &entry, i in s.animations {
		is_sel := i == s.sel_anim
		bg := ui.BUTTON_ACTIVE if is_sel else ui.BUTTON_BG
		row := rl.Rectangle{x, y, rw, ui.ROW_HEIGHT}
		rl.DrawRectangleRec(row, bg)
		rl.DrawRectangleLinesEx(row, 1, ui.BORDER)
		rl.DrawText(
			strings.clone_to_cstring(entry.name, context.temp_allocator),
			i32(x) + ui.PADDING,
			i32(y) + 3,
			ui.FONT_SIZE,
			ui.TEXT,
		)
		if rl.CheckCollisionPointRec(ui.ctx.mouse_pos, row) && ui.ctx.mouse_pressed {
			s.sel_anim = i
			sprite_sheet_rebuild_preview(s)
		}

		y += ui.ROW_HEIGHT + 2
	}

	y += ui.PADDING

	if s.sel_anim >= 0 && s.sel_anim < len(s.animations) {
		entry := &s.animations[s.sel_anim]

		rl.DrawText("Properties", i32(x), i32(y), ui.FONT_SIZE, ui.ACCENT)
		y += ui.ROW_HEIGHT

		ui.ui_text_input({x, y, rw, ui.ROW_HEIGHT}, &entry.name)
		y += ui.ROW_HEIGHT + ui.PADDING

		rl.DrawText(
			fmt.ctprintf(
				"Frames: %d -> %d (count: %d)",
				entry.first_frame,
				entry.first_frame + entry.frame_count - 1,
				entry.frame_count,
			),
			i32(x),
			i32(y),
			ui.FONT_SIZE,
			ui.TEXT,
		)

		y += ui.ROW_HEIGHT + ui.PADDING

		fps_val := entry.fps
		ui.ui_drag_float({x, y, rw, ui.ROW_HEIGHT}, "FPS", &entry.fps, 0.5)
		y += ui.ROW_HEIGHT + ui.PADDING
		if entry.fps != fps_val do sprite_sheet_rebuild_preview(s)

		ui.ui_checkbox({x, y, rw, ui.ROW_HEIGHT}, "Looping", &entry.looping)
		y += ui.ROW_HEIGHT + ui.PADDING
		if entry.looping != s.preview_anim.looping do sprite_sheet_rebuild_preview(s)

		y += ui.PADDING
		rl.DrawText("Preview", i32(x), i32(y), ui.FONT_SIZE, ui.ACCENT)
		y += ui.ROW_HEIGHT

		preview_size: f32 = min(rw, 123)
		preview_rect := rl.Rectangle{x + (rw - preview_size) / 2, y, preview_size, preview_size}
		rl.DrawRectangleRec(preview_rect, rl.Color{30, 30, 32, 255})
		rl.DrawRectangleLinesEx(preview_rect, 1, ui.BORDER)

		if s.tex.id != 0 && entry.frame_count > 0 {
			sprite := eng.get_sprite_for_animation(&s.preview_state)
			if sprite.texture.id != 0 {
				scale := min(preview_size / sprite.src.width, preview_size / sprite.src.height)
				dw := sprite.src.width * scale
				dh := sprite.src.height * scale
				dx := preview_rect.x + (preview_size - dw) / 2
				dy := preview_rect.y + (preview_size - dh) / 2
				rl.DrawTexturePro(
					sprite.texture,
					sprite.src,
					rl.Rectangle{dx, dy, dw, dh},
					{0, 0},
					0,
					rl.WHITE,
				)
			}
		}
	}
}

sprite_sheet_rebuild_preview :: proc(s: ^Sprite_Sheet_Editor_State) {
	if s.sel_anim < 0 || s.sel_anim >= len(s.animations) do return

	entry := s.animations[s.sel_anim]
	s.preview_anim = eng.Animation {
		texture           = s.tex,
		first_frame_index = entry.first_frame,
		frame_w           = i32(s.frame_w),
		frame_h           = i32(s.frame_h),
		frame_count       = entry.frame_count,
		columns           = i32(s.columns),
		fps               = entry.fps,
		looping           = entry.looping,
	}

	s.preview_state = eng.create_animation_state(&s.preview_anim)
}

sprite_sheet_editor_save :: proc(s: ^Sprite_Sheet_Editor_State, save_path: string) -> bool {
	if s.tex.id == 0 do return false

	b: strings.Builder
	strings.builder_init(&b)
	defer delete(b.buf)

	json_dir := filepath.dir(save_path)
	defer delete(json_dir)

	image_rel_raw, rel_err := filepath.rel(json_dir, s.tex_path)
	if rel_err != .None do return false
	defer delete(image_rel_raw)

	image_rel, was_alloc := strings.replace_all(image_rel_raw, "\\", "/")
	if was_alloc {defer delete(image_rel)}

	strings.write_string(&b, "{\n")
	fmt.sbprintf(&b, "  \"texture\": \"%s\",\n", image_rel)
	fmt.sbprintf(&b, "  \"frame_w\": %d,\n", i32(s.frame_w))
	fmt.sbprintf(&b, "  \"frame_h\": %d,\n", i32(s.frame_h))
	fmt.sbprintf(&b, "  \"columns\": %d,\n", i32(s.columns))
	strings.write_string(&b, "  \"animations\": [\n")

	for entry, i in s.animations {
		comma: cstring = "," if i < len(s.animations) - 1 else ""
		fmt.sbprintf(
			&b,
			"    { \"name\": \"%s\", \"first_frame\": %d, \"frame_count\": %d, \"fps\": %.2f, \"looping\": %v }%s\n",
			entry.name,
			entry.first_frame,
			entry.frame_count,
			entry.fps,
			entry.looping,
			comma,
		)
	}

	strings.write_string(&b, "  ]\n")
	strings.write_string(&b, "}\n")

	json_str := strings.to_string(b)
	return os.write_entire_file(save_path, transmute([]byte)json_str) == nil
}

