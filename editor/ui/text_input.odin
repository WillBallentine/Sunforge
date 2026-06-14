package editorui

import "core:strings"
import "core:unicode/utf8"
import rl "vendor:raylib"


ui_text_input :: proc(rect: rl.Rectangle, value: ^string) {
	hovered := rl.CheckCollisionPointRec(ctx.mouse_pos, rect)

	if ctx.mouse_pressed {
		if hovered {
			ctx.active = rawptr(value)
		} else if ctx.active == rawptr(value) {
			ctx.active = nil
		}
	}

	is_active := ctx.active == rawptr(value)

	if is_active {
		for {
			ch := rl.GetCharPressed()
			if ch == 0 {
				break
			}

			builder := strings.builder_make()
			strings.write_string(&builder, value^)
			strings.write_rune(&builder, ch)
			new_val := strings.clone(strings.to_string(builder))
			strings.builder_destroy(&builder)

			delete(value^)
			value^ = new_val
		}

		if rl.IsKeyPressed(.BACKSPACE) && len(value^) > 0 {
			_, size := utf8.decode_last_rune_in_string(value^)
			new_val := strings.clone(value^[:len(value^) - size])
			delete(value^)
			value^ = new_val
		}
	}

	rl.DrawRectangleRec(rect, BUTTON_BG)
	rl.DrawRectangleLinesEx(rect, 1, BORDER_ACTIVE if (hovered || is_active) else BORDER)

	cstr := strings.clone_to_cstring(value^, context.temp_allocator)
	rl.DrawText(cstr, i32(rect.x) + PADDING, row_text_y(rect), FONT_SIZE, TEXT)

	if is_active {
		text_w := rl.MeasureText(cstr, FONT_SIZE)
		cursor_x := i32(rect.x) + PADDING + text_w + 1
		rl.DrawRectangle(cursor_x, i32(rect.y) + 3, 1, i32(rect.height) - 6, ACCENT)
	}

}

