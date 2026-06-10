package renderer

import rl "vendor:raylib"

Sprite :: struct {
	texture: rl.Texture2D,
	src:     rl.Rectangle,
}

Flip :: enum {
	NONE,
	HORIZONTAL,
	VERTICAL,
}

get_sprite :: proc {
	sprite_from_grid_sheet,
	sprite_from_row_sheet,
}

sprite_from_row_sheet :: proc(
	texture: rl.Texture2D,
	frame_w, frame_h, frame_index: i32,
) -> Sprite {
	return Sprite {
		texture = texture,
		src = rl.Rectangle {
			x = f32(frame_index * frame_w),
			y = 0,
			width = f32(frame_w),
			height = f32(frame_h),
		},
	}
}

sprite_from_grid_sheet :: proc(
	texture: rl.Texture2D,
	frame_w, frame_h, frame_index, columns: i32,
) -> Sprite {
	col := frame_index % columns
	row := frame_index / columns
	return Sprite {
		texture = texture,
		src = rl.Rectangle {
			x = f32(col * frame_w),
			y = f32(row * frame_h),
			width = f32(frame_w),
			height = f32(frame_h),
		},
	}
}

renderer_draw_sprite :: proc(
	sprite: Sprite,
	pos: rl.Vector2,
	scale: f32,
	flip: Flip,
	tint: rl.Color,
) {
	src := sprite.src

	#partial switch flip {
	case .HORIZONTAL:
		src.width = -src.width
	case .VERTICAL:
		src.height = -src.height
	}

	dest := rl.Rectangle {
		x      = pos.x,
		y      = pos.y,
		width  = sprite.src.width * scale,
		height = sprite.src.height * scale,
	}

	//center of sprite
	origin := rl.Vector2{dest.width / 2, dest.height / 2}
	//at the "feet"
	//origin := rl.Vector2{dest.width/2, dest.height}

	rl.DrawTexturePro(sprite.texture, src, dest, origin, 0, tint)
}

