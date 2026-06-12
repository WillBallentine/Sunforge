package renderer

import rl "vendor:raylib"

MAX_DRAW_COMMANDS :: 2048

Draw_Command :: struct {
	sprite:      Sprite,
	position:    rl.Vector2,
	scale:       f32,
	rotation:    f32,
	pivot_point: Pivot_Point,
	flip:        Flip,
	tint:        rl.Color,
	z:           f32,
}

Draw_Buffer :: struct {
	commands: [MAX_DRAW_COMMANDS]Draw_Command,
	count:    int,
}


draw_buffer_push :: proc(buf: ^Draw_Buffer, cmd: Draw_Command) {
	assert(buf.count < MAX_DRAW_COMMANDS, "Draw_Buffer overflow")
	buf.commands[buf.count] = cmd
	buf.count += 1
}

draw_buffer_flush :: proc(buf: ^Draw_Buffer) {
	draw_buffer_sort(buf)

	for i in 0 ..< buf.count {
		cmd := buf.commands[i]
		renderer_draw_sprite(
			cmd.sprite,
			cmd.position,
			cmd.scale,
			cmd.rotation,
			cmd.pivot_point,
			cmd.flip,
			cmd.tint,
		)
	}

	buf.count = 0
}

draw_buffer_sort :: proc(buf: ^Draw_Buffer) {
	for i in 1 ..< buf.count {
		key := buf.commands[i]
		j := i - 1
		for j >= 0 && buf.commands[j].z > key.z {
			buf.commands[j + 1] = buf.commands[j]
			j -= 1
		}
		buf.commands[j + 1] = key
	}
}

