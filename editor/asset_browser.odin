package main

import proj "../project"
import ui "./ui"
import "core:os"
import "core:path/filepath"
import "core:strings"
import rl "vendor:raylib"

ASSET_ROW_HEIGHT :: 40
ASSET_THUMB_SIZE :: 32
ASSET_FILTER_HEIGHT :: 22
ASSET_SCROLL_SPEED :: 20

Asset_Browser_State :: struct {
	assets:     []Asset_Entry,
	thumbnails: map[string]rl.Texture2D,
	scroll:     f32,
	filter:     Asset_Kind,
	selected:   int,
}

Asset_Entry :: struct {
	name:      string,
	rel_path:  string,
	full_path: string,
	kind:      Asset_Kind,
}

Asset_Kind :: enum {
	ALL,
	OTHER,
	TEXTURE,
	JSON,
	SHADER,
}


asset_browser_init :: proc(project_root: string) -> Asset_Browser_State {
	s: Asset_Browser_State
	s.thumbnails = make(map[string]rl.Texture2D)
	s.filter = .ALL
	s.selected = -1


	resources_root, _ := filepath.join({project_root, proj.RESOURCES_DIR})
	defer delete(resources_root)

	asset_entries := make([dynamic]Asset_Entry, 0)

	resouce_walker := os.walker_create(resources_root)
	defer os.walker_destroy(&resouce_walker)

	for info in os.walker_walk(&resouce_walker) {
		if info.type != .Regular {
			continue
		}

		rel, err := filepath.rel(resources_root, info.fullpath)
		if err != .None {
			continue
		}

		append(
			&asset_entries,
			Asset_Entry {
				name = strings.clone(filepath.base(info.fullpath)),
				rel_path = rel,
				full_path = strings.clone(info.fullpath),
				kind = asset_classify(info.fullpath),
			},
		)
	}

	s.assets = asset_entries[:]
	return s
}


asset_browser_render :: proc(s: ^Asset_Browser_State, rect: rl.Rectangle, wheel: f32) {
	filter_rect := rl.Rectangle{rect.x, rect.y, rect.width, rect.height}
	list_rect := rl.Rectangle {
		rect.x,
		rect.y + ASSET_FILTER_HEIGHT,
		rect.width,
		rect.height - ASSET_FILTER_HEIGHT,
	}

	filters := [4]Asset_Kind{.ALL, .TEXTURE, .JSON, .SHADER}
	labels := [4]cstring{"All", "Texture", "Json", "Shader"}
	button_w := filter_rect.width / 4

	for i in 0 ..< 4 {
		btn := rl.Rectangle {
			filter_rect.x + f32(i) * button_w,
			filter_rect.y,
			button_w,
			ASSET_FILTER_HEIGHT,
		}

		if ui.ui_button(btn, labels[i]) {
			s.filter = filters[i]
			s.scroll = 0
		}
		if s.filter == filters[i] {
			rl.DrawRectangleLinesEx(btn, 2, ui.ACCENT)
		}
	}

	visible := make([dynamic]int, 0, len(s.assets), context.temp_allocator)
	for entry, i in s.assets {
		if s.filter != .ALL && entry.kind != s.filter {
			continue
		}

		append(&visible, i)
	}


	content_h := f32(len(visible)) * ASSET_ROW_HEIGHT
	max_scroll := max(content_h - list_rect.height, 0)
	if wheel != 0 && rl.CheckCollisionPointRec(ui.ctx.mouse_pos, rect) {
		s.scroll -= wheel * ASSET_SCROLL_SPEED
	}
	s.scroll = clamp(s.scroll, 0, max_scroll)

	rl.BeginScissorMode(
		i32(list_rect.x),
		i32(list_rect.y),
		i32(list_rect.width),
		i32(list_rect.height),
	)

	for entry_index, row_i in visible {
		entry := s.assets[entry_index]
		row := rl.Rectangle {
			list_rect.x,
			list_rect.y + f32(row_i) * ASSET_ROW_HEIGHT - s.scroll,
			list_rect.width,
			ASSET_ROW_HEIGHT,
		}

		if row.y + row.height < list_rect.y || row.y > list_rect.y + list_rect.height {
			continue
		}

		hovered := rl.CheckCollisionPointRec(ui.ctx.mouse_pos, row)
		is_selected := entry_index == s.selected

		bg := ui.PANEL_BG
		if is_selected {
			bg = ui.BUTTON_ACTIVE
		} else if hovered {
			bg = ui.BUTTON_HOVER
		}

		rl.DrawRectangleRec(row, bg)
		rl.DrawRectangleLinesEx(row, 1, ui.BORDER)

		text_x := row.x + 4
		if entry.kind == .TEXTURE {
			tex := asset_thumbnail(s, entry)
			thumb := rl.Rectangle {
				row.x + 4,
				row.y + (row.height - ASSET_THUMB_SIZE) / 2,
				ASSET_THUMB_SIZE,
				ASSET_THUMB_SIZE,
			}
			src := rl.Rectangle{0, 0, f32(tex.width), f32(tex.height)}
			rl.DrawTexturePro(tex, src, thumb, {0, 0}, 0, rl.WHITE)
			text_x = thumb.x + ASSET_THUMB_SIZE + 8
		}

		cname := strings.clone_to_cstring(entry.name, context.temp_allocator)
		rl.DrawText(
			cname,
			i32(text_x),
			i32(row.y + row.height / 2) - ui.FONT_SIZE / 2,
			ui.FONT_SIZE,
			ui.TEXT,
		)

		if hovered && ui.ctx.mouse_pressed {
			s.selected = entry_index
		}
	}

	rl.EndScissorMode()

}


asset_browser_destroy :: proc(s: ^Asset_Browser_State) {
	for _, tex in s.thumbnails {
		rl.UnloadTexture(tex)
	}
	delete(s.thumbnails)

	for entry in s.assets {
		delete(entry.name)
		delete(entry.rel_path)
		delete(entry.full_path)
	}

	delete(s.assets)
}


asset_classify :: proc(path: string) -> Asset_Kind {
	ext := strings.to_lower(filepath.ext(path), context.temp_allocator)
	switch ext {
	case ".png", ".jpg", ".jpeg":
		return .TEXTURE
	case ".json":
		return .JSON
	case ".glsl":
		return .SHADER
	case:
		return .OTHER
	}
}


asset_thumbnail :: proc(s: ^Asset_Browser_State, entry: Asset_Entry) -> rl.Texture2D {
	if tex, ok := s.thumbnails[entry.full_path]; ok {
		return tex
	}

	cpath := strings.clone_to_cstring(entry.full_path, context.temp_allocator)
	tex := rl.LoadTexture(cpath)
	s.thumbnails[entry.full_path] = tex
	return tex
}

