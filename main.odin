package main

import eng "./engine"
import "core:fmt"
import rl "vendor:raylib"

Game_Action :: enum u32 {
	Move_Left,
	Move_Right,
	Move_Up,
	Move_Down,
	Jump,
	Confirm,
	Back,
	UP_Arrow,
}

empty_tile :: -1
grass_top :: 6
dirt :: 16
stone :: 13
column_bottom :: 30
column_top :: 19
column_connector :: 92
column_extend :: 91


level_layout := []string {
	"........................................",
	"........................................",
	"....SSSS................................",
	"........................................",
	"..............ER........................",
	"...............T........................",
	"GGGGGGGGGGGGGGGCGGGGGGGGGGGGGGGGGGGGGGGG",
	"DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD",
}

act :: #force_inline proc(a: Game_Action) -> eng.Action_ID {
	return eng.Action_ID(a)
}

main :: proc() {
	eng.run(
		eng.Engine_Config {
			window = eng.Window_Config {
				width = 1280,
				height = 720,
				title = "test",
				target_fps = 60,
				is_resizeable = true,
			},
		},
		title_screen(),
	)
}

Title_State :: struct {
	timer:           f32,
	confirm_pressed: bool,
	player_position: rl.Vector2,
	player_facing:   eng.Flip,
	sprite:          rl.Texture2D,
	idle_anim:       eng.Animation,
	walk_anim:       eng.Animation,
	flip_anim:       eng.Animation,
	anim_state:      eng.Animation_State,
	mouse_pos:       rl.Vector2,
	mouse_delta:     rl.Vector2,
	world_target:    eng.Render_Target,
	ui_target:       eng.Render_Target,
	camera:          eng.Camera_State,
	post_shader:     eng.Shader_ID,
	tileset:         rl.Texture2D,
	tilemap:         eng.Tilemap,
}

title_screen :: proc() -> eng.Scene_Procs {
	state := new(Title_State)
	return eng.Scene_Procs {
		data = state,
		init = title_init,
		update = title_update,
		render = title_render,
		destroy = title_destroy,
	}
}

title_init :: proc(e: ^eng.Engine, data: rawptr) {
	s := cast(^Title_State)data
	//eng.toggle_fullscreen(&e.window)

	eng.camera_init(
		&s.camera,
		offset = {f32(e.renderer.logical_width) / 2, f32(e.renderer.logical_height) / 2},
		follow_speed = 6.0,
		trauma_decay = 1.5,
		shake_max = 12.0,
	)

	s.player_position = {635, 135}
	s.camera.camera.target = s.player_position

	s.tileset = rl.LoadTexture("resources/tilesets/Final/tiles.png")

	s.tilemap = eng.create_tilemap(40, 15, 32, 32, 2, s.tileset, 11)
	build_level(&s.tilemap)
	mark_solid_tiles(&s.tilemap)

	//keyboard bindings
	eng.input_bind_keyboard(&e.input, act(.Jump), .ENTER)
	eng.input_bind_keyboard(&e.input, act(.Back), .J)
	eng.input_bind_keyboard(&e.input, act(.Move_Left), .A)
	eng.input_bind_keyboard(&e.input, act(.Move_Right), .D)
	eng.input_bind_keyboard(&e.input, act(.Move_Up), .W)
	eng.input_bind_keyboard(&e.input, act(.Move_Down), .S)
	eng.input_bind_keyboard(&e.input, act(.UP_Arrow), .SPACE)

	//controller bindings
	eng.input_bind_controller(&e.input, act(.Move_Left), .LEFT_FACE_LEFT)
	eng.input_bind_controller(&e.input, act(.Move_Right), .LEFT_FACE_RIGHT)
	eng.input_bind_controller(&e.input, act(.Move_Down), .LEFT_FACE_DOWN)
	eng.input_bind_controller(&e.input, act(.Move_Up), .LEFT_FACE_UP)
	eng.input_bind_controller(&e.input, act(.Jump), .RIGHT_FACE_RIGHT)

	s.world_target = eng.make_render_target(&e.renderer)
	s.ui_target = eng.make_render_target(&e.renderer)
	s.sprite = rl.LoadTexture("./test.png")
	s.player_facing = .HORIZONTAL

	s.idle_anim = eng.Animation {
		texture           = s.sprite,
		first_frame_index = 0,
		frame_w           = 48,
		frame_h           = 48,
		frame_count       = 5,
		columns           = 7,
		fps               = 8,
		looping           = true,
	}

	s.flip_anim = eng.Animation {
		texture           = s.sprite,
		first_frame_index = 24,
		frame_w           = 48,
		frame_h           = 48,
		frame_count       = 3,
		columns           = 7,
		fps               = 8,
		looping           = false,
	}

	s.walk_anim = eng.Animation {
		texture           = s.sprite,
		first_frame_index = 7,
		frame_w           = 48,
		frame_h           = 48,
		frame_count       = 6,
		columns           = 7,
		fps               = 8,
		looping           = true,
	}

	s.anim_state = eng.create_animation_state(&s.idle_anim)
	//s.post_shader = eng.shader_load(&e.renderer.shaders, "resources/shaders/grayscale.glsl")
}

title_update :: proc(e: ^eng.Engine, data: rawptr, dt: f32) {
	s := cast(^Title_State)data
	s.timer += dt
	s.mouse_pos = e.input.mouse.position
	s.mouse_delta = e.input.mouse.delta

	eng.camera_follow(&s.camera, s.player_position, dt)
	//eng.shader_set_float(&e.renderer.shaders, s.post_shader, "time", s.timer)
	//eng.shader_set_vec2(
	// 	&e.renderer.shaders,
	// 	s.post_shader,
	// 	"resolution",
	// 	{f32(e.renderer.logical_width), f32(e.renderer.logical_height)},
	// )

	if eng.input_pressed(&e.input, act(.Jump)) {
		eng.add_trauma(&s.camera, 0.5)
	}

	eng.update_camera(&s.camera, dt)

	PLAYER_SPEED :: f32(200)
	move_x: f32
	move_y: f32

	if eng.input_held(&e.input, act(.Move_Left)) do move_x -= 1
	if eng.input_held(&e.input, act(.Move_Right)) do move_x += 1
	if eng.input_held(&e.input, act(.Move_Up)) do move_y -= 1
	if eng.input_held(&e.input, act(.Move_Down)) do move_y += 1

	if move_x == 0 do move_x = e.input.controller.left_stick.x
	if move_y == 0 do move_y = e.input.controller.left_stick.y

	s.player_position.x += move_x * PLAYER_SPEED * dt
	s.player_position.y += move_y * PLAYER_SPEED * dt

	moving := move_x != 0 || move_y != 0

	if move_x < 0 do s.player_facing = .HORIZONTAL
	if move_x > 0 do s.player_facing = .NONE

	if eng.input_pressed(&e.input, act(.UP_Arrow)) {
		new_height := e.window.height + 50
		new_width := e.window.width + 50
		eng.draw_basic_shape(fmt.ctprintf("new height: %s", new_height), 100, 100, 100, rl.WHITE)
		eng.set_window_size(&e.window, new_width, new_height)
	}
	if eng.input_pressed(&e.input, act(.Back)) {
		s.anim_state.paused = !s.anim_state.paused
	}

	flip_triggered := eng.input_pressed(&e.input, act(.Jump))
	currently_flipping := s.anim_state.anim == &s.flip_anim && !s.anim_state.finished
	target_anim: ^eng.Animation
	if currently_flipping {
		target_anim = &s.flip_anim
	} else if flip_triggered {
		target_anim = &s.flip_anim
	} else if moving {
		target_anim = &s.walk_anim
	} else {
		target_anim = &s.idle_anim
	}
	if s.anim_state.anim != target_anim {
		s.anim_state = eng.create_animation_state(target_anim)
	}
	eng.update_animation_state(&s.anim_state, dt)

	if eng.input_pressed(&e.input, act(.Confirm)) {
		s.confirm_pressed = true
	}
}

title_render :: proc(e: ^eng.Engine, data: rawptr) {
	s := cast(^Title_State)data

	eng.begin_render_target(s.world_target)
	eng.renderer_clear(rl.BLACK)
	eng.begin_camera(s.camera)
	eng.draw_tilemap(&s.tilemap, s.camera.camera)
	world_mouse := eng.screen_to_world(
		e.renderer.viewport,
		e.renderer.logical_width,
		s.camera,
		e.input.mouse.position,
	)
	//eng.draw_basic_shape(cstring("hello world"), i32(50), i32(50), i32(100), rl.BLUE)
	//eng.draw_basic_shape(rl.Vector2(10), f32(100.00), rl.WHITE)
	//
	// show all sprites on screen
	// start := 7
	// end := 12
	// for i in 7 ..< 13 {
	// 	sprite := eng.get_sprite(s.sprite, 48, 48, i32(i), 7)
	// 	eng.draw_texture(sprite, rl.Vector2{0, 0}, 1.0, s.player_facing, rl.WHITE)
	// 	eng.renderer_clear(rl.BLACK)
	// }

	eng.draw_basic_shape(cstring("Sunforge Testing"), 0, 0, 48, rl.GREEN)
	sprite := eng.get_sprite_for_animation(&s.anim_state)
	eng.draw_texture(sprite, s.player_position, 2.0, s.player_facing, rl.WHITE)


	eng.end_camera()
	eng.end_render_target()

	eng.begin_render_target(s.ui_target)
	eng.renderer_clear({0, 0, 0, 0})
	//eng.draw_basic_shape(cstring("hello ui"), i32(690), i32(400), i32(100), rl.GREEN)
	//eng.renderer_draw_rect(rl.Rectangle{f32(150), f32(15), f32(25), f32(25)}, f32(25), rl.GREEN)
	//debug inputs
	//keyboard
	eng.draw_basic_shape(
		fmt.ctprintf("pressed: %v", e.input.actions[3].pressed),
		10,
		30,
		16,
		rl.YELLOW,
	)
	eng.draw_basic_shape(fmt.ctprintf("held: %v", e.input.actions[3].held), 10, 50, 16, rl.YELLOW)
	eng.draw_basic_shape(
		fmt.ctprintf("released: %v", e.input.actions[3].released),
		10,
		70,
		16,
		rl.YELLOW,
	)
	eng.draw_basic_shape(fmt.ctprintf("player pos: %v", s.player_position), 10, 280, 16, rl.YELLOW)

	//mouse
	eng.draw_basic_shape(
		fmt.ctprintf("left mouse pressed: %v", e.input.mouse.left.pressed),
		10,
		200,
		16,
		rl.YELLOW,
	)
	eng.draw_basic_shape(
		fmt.ctprintf("left mouse held: %v", e.input.mouse.left.held),
		10,
		220,
		16,
		rl.YELLOW,
	)
	eng.draw_basic_shape(
		fmt.ctprintf("left mouse released: %v", e.input.mouse.left.released),
		10,
		240,
		16,
		rl.YELLOW,
	)
	//end debug inputs

	eng.draw_basic_shape(fmt.ctprintf("mouse pos: %v", s.mouse_pos), 10, 100, 16, rl.YELLOW)
	eng.draw_basic_shape(fmt.ctprintf("mouse delta: %v", s.mouse_delta), 10, 140, 16, rl.YELLOW)
	eng.draw_basic_shape(
		fmt.ctprintf("mouse pressed: %v", e.input.mouse.left.pressed),
		10,
		120,
		16,
		rl.YELLOW,
	)
	eng.draw_basic_shape(
		fmt.ctprintf("mouse held: %v", e.input.mouse.left.held),
		10,
		160,
		16,
		rl.YELLOW,
	)
	eng.draw_basic_shape(
		fmt.ctprintf("mouse released: %v", e.input.mouse.left.released),
		10,
		180,
		16,
		rl.YELLOW,
	)
	eng.draw_basic_shape(
		fmt.ctprintf("mouse wheel: %v", e.input.mouse.wheel),
		10,
		260,
		16,
		rl.YELLOW,
	)
	eng.end_render_target()

	//eng.blit_shader(&e.renderer, s.world_target, s.post_shader)
	eng.blit(&e.renderer, s.world_target)
	eng.blit(&e.renderer, s.ui_target)
}

title_destroy :: proc(e: ^eng.Engine, data: rawptr) {
	s := cast(^Title_State)data

	//eng.shader_unload(&e.renderer.shaders, s.post_shader)
	eng.destroy_tilemap(&s.tilemap)
	rl.UnloadTexture(s.tileset)
	eng.destroy_render_target(s.world_target)
	eng.destroy_render_target(s.ui_target)
	free(data)
}


build_level :: proc(tm: ^eng.Tilemap) {
	for row_str, row in level_layout {
		for ch, col in row_str {
			tile_index: i32
			switch ch {
			case '.':
				tile_index = empty_tile
			case 'G':
				tile_index = grass_top
			case 'D':
				tile_index = dirt
			case 'S':
				tile_index = stone
			case 'C':
				tile_index = column_bottom
			case 'E':
				tile_index = column_extend
			case 'R':
				tile_index = column_connector
			case 'T':
				tile_index = column_top
			case:
				tile_index = empty_tile
			}

			if tile_index != empty_tile {
				eng.tilemap_set_tile(tm, 0, i32(col), i32(row), tile_index)
			}
		}
	}
}

mark_solid_tiles :: proc(tm: ^eng.Tilemap) {
	tm.solid[grass_top] = true
	tm.solid[dirt] = true
	tm.solid[stone] = true
}

