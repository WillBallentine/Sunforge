package editorui

import engCore "../../engine/core"
import "core:fmt"
import rl "vendor:raylib"


ui_panel :: proc(rect: rl.Rectangle, title: cstring) -> rl.Rectangle {
	rl.DrawRectangleRec(rect, PANEL_BG)

	title_bar := rl.Rectangle{rect.x, rect.y, rect.width, TITLE_HEIGHT}
	rl.DrawRectangleRec(title_bar, PANEL_TITLE_BG)
	rl.DrawText(title, i32(rect.x) + PADDING, i32(rect.y) + 4, FONT_SIZE, TEXT)

	rl.DrawRectangleLinesEx(rect, 1, BORDER)

	return rl.Rectangle{rect.x, rect.y + TITLE_HEIGHT, rect.width, rect.height - TITLE_HEIGHT}
}

ui_button :: proc(rect: rl.Rectangle, label: cstring) -> bool {
	hovered := rl.CheckCollisionPointRec(ctx.mouse_pos, rect)

	color := BUTTON_BG
	if hovered {
		color = BUTTON_ACTIVE if ctx.mouse_held else BUTTON_HOVER
	}
	rl.DrawRectangleRec(rect, color)
	rl.DrawRectangleLinesEx(rect, 1, BORDER)

	draw_centered_text(rect, label)
	return hovered && ctx.mouse_pressed
}

ui_checkbox :: proc(rect: rl.Rectangle, label: cstring, value: ^bool) {
	box := rl.Rectangle{rect.x, rect.y, rect.height, rect.height}
	hovered := rl.CheckCollisionPointRec(ctx.mouse_pos, box)

	if hovered && ctx.mouse_pressed {
		value^ = !value^
	}

	rl.DrawRectangleLinesEx(box, 1, BORDER_ACTIVE if hovered else BORDER)
	if value^ {
		inner := rl.Rectangle{box.x + 3, box.y + 3, box.width - 6, box.height - 6}
		rl.DrawRectangleRec(inner, ACCENT)
	}

	rl.DrawText(label, i32(box.x + box.width) + PADDING, i32(box.y), FONT_SIZE, TEXT)
}

ui_drag_float :: proc(rect: rl.Rectangle, label: cstring, value: ^f32, step: f32) {
	hovered := rl.CheckCollisionPointRec(ctx.mouse_pos, rect)

	if hovered && ctx.mouse_pressed {
		ctx.active = rawptr(value)
	}
	if ctx.active == rawptr(value) {
		if ctx.mouse_held {
			value^ += ctx.mouse_delta.x * step
		} else {
			ctx.active = nil
		}
	}

	is_active := ctx.active == rawptr(value)

	rl.DrawRectangleRec(rect, BUTTON_ACTIVE if is_active else BUTTON_BG)
	rl.DrawRectangleLinesEx(rect, 1, BORDER_ACTIVE if (hovered || is_active) else BORDER)

	rl.DrawText(label, i32(rect.x) + PADDING, row_text_y(rect), FONT_SIZE, TEXT)
	draw_value_right(rect, fmt.ctprintf("%.2f", value^))
}

ui_slider_float :: proc(rect: rl.Rectangle, label: cstring, value: ^f32, lo, hi: f32) {
	hovered := rl.CheckCollisionPointRec(ctx.mouse_pos, rect)

	if hovered && ctx.mouse_pressed {
		ctx.active = rawptr(value)
	}
	if ctx.active == rawptr(value) {
		if ctx.mouse_held {
			t := engCore.clamp((ctx.mouse_pos.x - rect.x) / rect.width, 0, 1)
			value^ = lo + t * (hi - lo)
		} else {
			ctx.active = nil
		}
	}

	is_active := ctx.active == rawptr(value)

	rl.DrawRectangleRec(rect, BUTTON_BG)

	fill_t := engCore.clamp((value^ - lo) / (hi - lo), 0, 1)
	rl.DrawRectangleRec(rl.Rectangle{rect.x, rect.y, rect.width * fill_t, rect.height}, ACCENT)
	rl.DrawRectangleLinesEx(rect, 1, BORDER_ACTIVE if (hovered || is_active) else BORDER)

	rl.DrawText(label, i32(rect.x) + PADDING, row_text_y(rect), FONT_SIZE, TEXT)
	draw_value_right(rect, fmt.ctprintf("%.2f", value^))
}

ui_color_picker :: proc(rect: rl.Rectangle, value: ^rl.Color) {
	row_h := rect.height / 4

	ui_slider_byte(rl.Rectangle{rect.x, rect.y + row_h * 0, rect.width, row_h}, "R", &value.r)
	ui_slider_byte(rl.Rectangle{rect.x, rect.y + row_h * 1, rect.width, row_h}, "G", &value.g)
	ui_slider_byte(rl.Rectangle{rect.x, rect.y + row_h * 2, rect.width, row_h}, "B", &value.b)
	ui_slider_byte(rl.Rectangle{rect.x, rect.y + row_h * 3, rect.width, row_h}, "A", &value.a)
}

ui_combo :: proc(rect: rl.Rectangle, label: cstring, options: []string, selected: ^int) {
	is_open := ctx.active_combo == rawptr(selected)

	hovered := rl.CheckCollisionPointRec(ctx.mouse_pos, rect)
	rl.DrawRectangleRec(rect, BUTTON_BG)
	rl.DrawRectangleLinesEx(rect, 1, BORDER_ACTIVE if (hovered || is_open) else BORDER)

	if selected^ >= 0 && selected^ < len(options) {
		rl.DrawText(
			fmt.ctprintf("%s", options[selected^]),
			i32(rect.x) + PADDING,
			row_text_y(rect),
			FONT_SIZE,
			TEXT,
		)
	}
	rl.DrawText(
		"v",
		i32(rect.x + rect.width) - FONT_SIZE - PADDING,
		row_text_y(rect),
		FONT_SIZE,
		TEXT,
	)

	if hovered && ctx.mouse_pressed {
		if is_open {
			ctx.active_combo = nil
		} else {
			ctx.active_combo = rawptr(selected)
		}
		is_open = !is_open
	}

	if !is_open {
		return
	}

	for opt, i in options {
		row := rl.Rectangle{rect.x, rect.y + rect.height * f32(i + 1), rect.width, rect.height}
		row_hovered := rl.CheckCollisionPointRec(ctx.mouse_pos, row)

		rl.DrawRectangleRec(row, BUTTON_HOVER if row_hovered else PANEL_BG)
		rl.DrawRectangleLinesEx(row, 1, BORDER)
		rl.DrawText(
			fmt.ctprintf("%s", opt),
			i32(row.x) + PADDING,
			row_text_y(row),
			FONT_SIZE,
			TEXT,
		)

		if row_hovered && ctx.mouse_pressed {
			selected^ = i
			ctx.active_combo = nil
		}
	}
}

ui_tree_node :: proc(rect: rl.Rectangle, label: cstring, expanded: ^bool) -> bool {
	hovered := rl.CheckCollisionPointRec(ctx.mouse_pos, rect)
	if hovered && ctx.mouse_pressed {
		expanded^ = !expanded^
	}
	if hovered {
		rl.DrawRectangleRec(rect, BUTTON_HOVER)
	}

	arrow: cstring = "v" if expanded^ else ">"
	rl.DrawText(arrow, i32(rect.x) + PADDING, row_text_y(rect), FONT_SIZE, TEXT)
	rl.DrawText(label, i32(rect.x + rect.height), row_text_y(rect), FONT_SIZE, TEXT)

	return expanded^
}

@(private)
ui_slider_byte :: proc(rect: rl.Rectangle, label: cstring, value: ^u8) {
	hovered := rl.CheckCollisionPointRec(ctx.mouse_pos, rect)

	if hovered && ctx.mouse_pressed {
		ctx.active = rawptr(value)
	}
	if ctx.active == rawptr(value) {
		if ctx.mouse_held {
			t := engCore.clamp((ctx.mouse_pos.x - rect.x) / rect.width, 0, 1)
			value^ = u8(t * 255)
		} else {
			ctx.active = nil
		}
	}

	is_active := ctx.active == rawptr(value)

	rl.DrawRectangleRec(rect, BUTTON_BG)

	fill_t := f32(value^) / 255
	rl.DrawRectangleRec(rl.Rectangle{rect.x, rect.y, rect.width * fill_t, rect.height}, ACCENT)
	rl.DrawRectangleLinesEx(rect, 1, BORDER_ACTIVE if (hovered || is_active) else BORDER)

	rl.DrawText(label, i32(rect.x) + PADDING, row_text_y(rect), FONT_SIZE, TEXT)
	draw_value_right(rect, fmt.ctprintf("%d", value^))
}

@(private)
row_text_y :: proc(rect: rl.Rectangle) -> i32 {
	return i32(rect.y) + (i32(rect.height) - FONT_SIZE) / 2
}

@(private)
draw_centered_text :: proc(rect: rl.Rectangle, text: cstring) {
	w := rl.MeasureText(text, FONT_SIZE)
	x := i32(rect.x + rect.width / 2) - w / 2
	rl.DrawText(text, x, row_text_y(rect), FONT_SIZE, TEXT)
}

@(private)
draw_value_right :: proc(rect: rl.Rectangle, text: cstring) {
	w := rl.MeasureText(text, FONT_SIZE)
	x := i32(rect.x + rect.width) - w - PADDING
	rl.DrawText(text, x, row_text_y(rect), FONT_SIZE, TEXT)
}

