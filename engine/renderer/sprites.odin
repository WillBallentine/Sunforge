package renderer

import "core:encoding/json"
import "core:os"
import "core:path/filepath"
import "core:strings"
import rl "vendor:raylib"

Sprite :: struct {
	texture: rl.Texture2D,
	src:     rl.Rectangle,
}

Sprite_Sheet :: struct {
	texture:    rl.Texture2D,
	frame_w:    i32,
	frame_h:    i32,
	columns:    i32,
	animations: map[string]Animation,
}

Sprite_Sheet_Anim_Def :: struct {
	name:        string,
	first_frame: i32,
	frame_count: i32,
	fps:         f32,
	looping:     bool,
}

Sprite_Sheet_Def :: struct {
	texture:    string,
	frame_w:    i32,
	frame_h:    i32,
	columns:    i32,
	animations: []Sprite_Sheet_Anim_Def,
}

Flip :: enum {
	NONE,
	HORIZONTAL,
	VERTICAL,
}

Pivot_Point :: enum {
	CENTER,
	BOTTOM,
}

get_sprite :: proc {
	sprite_from_grid_sheet,
	sprite_from_row_sheet,
}

sprite_sheet_load :: proc(path: string) -> Sprite_Sheet {
	bytes, err := os.read_entire_file(path, context.allocator)
	if err != nil {
		return {}
	}
	defer delete(bytes)

	sprite_def: Sprite_Sheet_Def
	if json.unmarshal(bytes, &sprite_def) != nil {
		return {}
	}

	defer {
		for anim in sprite_def.animations {
			delete(anim.name)
			defer delete(sprite_def.texture)
		}
	}

	sheet_dir := filepath.dir(path)
	defer delete(sheet_dir)

	tex_joined, _ := filepath.join({sheet_dir, sprite_def.texture})
	defer delete(tex_joined)
	tex_abs, _ := filepath.clean(tex_joined)
	defer delete(tex_abs)

	tex_cstr := strings.clone_to_cstring(tex_abs, context.temp_allocator)
	texture := rl.LoadTexture(tex_cstr)

	sheet: Sprite_Sheet
	sheet.texture = texture
	sheet.frame_w = sprite_def.frame_w
	sheet.frame_h = sprite_def.frame_h
	sheet.columns = sprite_def.columns
	sheet.animations = make(map[string]Animation)

	for anim_def in sprite_def.animations {
		sheet.animations[strings.clone(anim_def.name)] = Animation {
			texture           = texture,
			first_frame_index = anim_def.first_frame,
			frame_w           = sprite_def.frame_w,
			frame_h           = sprite_def.frame_h,
			frame_count       = anim_def.frame_count,
			columns           = sprite_def.columns,
			fps               = anim_def.fps,
			looping           = anim_def.looping,
		}
	}

	return sheet
}

sprite_sheet_get_animation :: proc(sheet: ^Sprite_Sheet, name: string) -> ^Animation {
	anim, ok := &sheet.animations[name]
	if !ok do return nil
	return anim
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
	rotation: f32,
	pivot_point: Pivot_Point,
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

	origin: rl.Vector2 = rl.Vector2{}
	switch pivot_point {
	case .CENTER:
		//center of sprite
		origin = rl.Vector2{dest.width / 2, dest.height / 2}
	case .BOTTOM:
		//at the "feet"
		origin = rl.Vector2{dest.width / 2, dest.height}
	case:
		origin = rl.Vector2{dest.width / 2, dest.height / 2}
	}

	rl.DrawTexturePro(sprite.texture, src, dest, origin, rotation, tint)
}

sprite_sheet_destroy :: proc(sheet: ^Sprite_Sheet) {
	rl.UnloadTexture(sheet.texture)
	for key in sheet.animations {delete(key)}
	delete(sheet.animations)
	sheet^ = {}
}

