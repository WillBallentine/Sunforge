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

TAG_NONE :: eng.FRAME_EVENT_TAG_NONE
TAG_JUMP_LAND :: 2

empty_tile :: -1
grass_top :: 6
dirt :: 16
stone :: 13
column_bottom :: 30
column_top :: 19
column_connector :: 92
column_extend :: 91


level_layout := []string {
	"SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS",
	"S......................................S",
	"S...SSSS...............................S",
	"S......................................S",
	"S.............ER.......................S",
	"S..............T.......................S",
	"SGGGGGGGGGGGGGGCGGGGGGGGGGGGGGGGGGGGGGGS",
	"SDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDS",
	"SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS",
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
	sprite:          eng.Sprite,
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
	alger_font:      eng.Font_ID,
	fira_font:       eng.Font_ID,
	test_draw_cmd:   eng.Draw_Command,
	test_draw_cmd_2: eng.Draw_Command,
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

	s.player_position = {635, 201}
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
	s.sprite.texture = rl.LoadTexture("./test.png")
	s.player_facing = .HORIZONTAL

	s.idle_anim = eng.Animation {
		texture           = s.sprite.texture,
		first_frame_index = 0,
		frame_w           = 48,
		frame_h           = 48,
		frame_count       = 5,
		columns           = 7,
		fps               = 8,
		looping           = true,
	}

	s.flip_anim = eng.Animation {
		texture = s.sprite.texture,
		first_frame_index = 24,
		frame_w = 48,
		frame_h = 48,
		frame_count = 3,
		columns = 7,
		fps = 8,
		looping = false,
		frame_events = {0 = {frame = 1, tag = TAG_JUMP_LAND}},
		event_count = 1,
	}

	s.walk_anim = eng.Animation {
		texture           = s.sprite.texture,
		first_frame_index = 7,
		frame_w           = 48,
		frame_h           = 48,
		frame_count       = 6,
		columns           = 7,
		fps               = 8,
		looping           = true,
	}

	s.test_draw_cmd = eng.Draw_Command {
		scale       = 1.5,
		rotation    = 0,
		pivot_point = .CENTER,
		tint        = rl.WHITE,
	}

	s.test_draw_cmd_2 = eng.Draw_Command {
		scale       = 5,
		rotation    = 0,
		pivot_point = .CENTER,
		tint        = rl.WHITE,
	}

	s.anim_state = eng.create_animation_state(&s.idle_anim)
	//s.post_shader = eng.shader_load(&e.renderer.shaders, "resources/shaders/grayscale.glsl")
	s.alger_font = eng.load_font(&e.renderer.fonts, "resources/fonts/ALGER.TTF", 50)
	s.fira_font = eng.load_font(&e.renderer.fonts, "resources/fonts/FiraCodeNerdFont-Bold.ttf", 50)
}

title_update :: proc(e: ^eng.Engine, data: rawptr, dt: f32) {
	s := cast(^Title_State)data
	s.timer += dt
	s.mouse_pos = e.input.mouse.position
	s.mouse_delta = e.input.mouse.delta
	eng.update_particles(&e.renderer.particles, dt)

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

	if int(dt) % 2 > 0 {
		p_config := eng.Particle_Config {
			position     = s.player_position,
			velocity_min = {-220, -220},
			velocity_max = {220, 220},
			color_start  = rl.YELLOW,
			color_end    = {255, 80, 0, 0},
			size_start   = 2,
			size_end     = 1,
			lifetime     = 0.4,
			gravity      = 300,
			count        = 30,
		}
		eng.emit_particles(&e.renderer.particles, p_config)

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
	if s.anim_state.fired_event == TAG_JUMP_LAND {
		p_config := eng.Particle_Config {
			position     = s.player_position,
			velocity_min = {-20, -60},
			velocity_max = {20, -20},
			color_start  = {200, 200, 200, 100},
			color_end    = {200, 200, 200, 0},
			size_start   = 2,
			size_end     = 8,
			lifetime     = 1.5,
			gravity      = -10,
			count        = 80,
		}
		eng.emit_particles(&e.renderer.particles, p_config)
	}

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
	eng.draw_particles(&e.renderer.particles)
	world_mouse := eng.screen_to_world(
		e.renderer.viewport,
		e.renderer.logical_width,
		s.camera,
		e.input.mouse.position,
	)

	eng.draw_font(&e.renderer.fonts, s.alger_font, "Sunforge Testing", {100, -50}, 48, 5, rl.GREEN)
	//setting up 2 sprites to blit to the screen. change the z of each to see them move infront or behind each other
	s.test_draw_cmd.sprite = eng.get_sprite_for_animation(&s.anim_state)
	s.test_draw_cmd.position = s.player_position
	s.test_draw_cmd.flip = s.player_facing
	s.test_draw_cmd.z = 1
	s.test_draw_cmd_2.sprite = eng.get_sprite_for_animation(&s.anim_state)
	s.test_draw_cmd_2.position = s.player_position
	s.test_draw_cmd_2.flip = s.player_facing
	s.test_draw_cmd_2.z = 2
	eng.draw_buffer_push(&e.renderer.draw_buffer, s.test_draw_cmd)
	eng.draw_buffer_push(&e.renderer.draw_buffer, s.test_draw_cmd_2)
	eng.draw_buffer_flush(&e.renderer.draw_buffer)


	eng.end_camera()
	eng.end_render_target()

	eng.begin_render_target(s.ui_target)
	eng.renderer_clear({0, 0, 0, 0})
	//debug inputs
	//keyboard
	//
	eng.draw_font(
		&e.renderer.fonts,
		s.fira_font,
		fmt.ctprintf("Move_Down pressed: %v", e.input.actions[3].pressed),
		{10, 20},
		16,
		5,
		rl.YELLOW,
	)
	eng.draw_font(
		&e.renderer.fonts,
		s.fira_font,
		fmt.ctprintf("Move_Down held: %v", e.input.actions[3].held),
		{10, 40},
		16,
		5,
		rl.YELLOW,
	)
	eng.draw_font(
		&e.renderer.fonts,
		s.fira_font,
		fmt.ctprintf("Move_Up pressed: %v", e.input.actions[2].pressed),
		{10, 60},
		16,
		5,
		rl.YELLOW,
	)
	eng.draw_font(
		&e.renderer.fonts,
		s.fira_font,
		fmt.ctprintf("Move_Up held: %v", e.input.actions[2].held),
		{10, 80},
		16,
		5,
		rl.YELLOW,
	)
	eng.draw_font(
		&e.renderer.fonts,
		s.fira_font,
		fmt.ctprintf("Move_Left pressed: %v", e.input.actions[0].pressed),
		{10, 100},
		16,
		5,
		rl.YELLOW,
	)
	eng.draw_font(
		&e.renderer.fonts,
		s.fira_font,
		fmt.ctprintf("Move_Left held: %v", e.input.actions[0].held),
		{10, 120},
		16,
		5,
		rl.YELLOW,
	)
	eng.draw_font(
		&e.renderer.fonts,
		s.fira_font,
		fmt.ctprintf("Move_Right pressed: %v", e.input.actions[1].pressed),
		{10, 140},
		16,
		5,
		rl.YELLOW,
	)
	eng.draw_font(
		&e.renderer.fonts,
		s.fira_font,
		fmt.ctprintf("Move_Right held: %v", e.input.actions[1].held),
		{10, 160},
		16,
		5,
		rl.YELLOW,
	)
	eng.draw_font(
		&e.renderer.fonts,
		s.fira_font,
		fmt.ctprintf("player pos: %v", s.player_position),
		{10, 180},
		16,
		5,
		rl.YELLOW,
	)

	// //mouse
	eng.draw_font(
		&e.renderer.fonts,
		s.fira_font,
		fmt.ctprintf("left mouse pressed: %v", e.input.mouse.left.pressed),
		{10, 200},
		16,
		5,
		rl.YELLOW,
	)
	eng.draw_font(
		&e.renderer.fonts,
		s.fira_font,
		fmt.ctprintf("left mouse held: %v", e.input.mouse.left.held),
		{10, 220},
		16,
		5,
		rl.YELLOW,
	)
	eng.draw_font(
		&e.renderer.fonts,
		s.fira_font,
		fmt.ctprintf("left mouse released: %v", e.input.mouse.left.released),
		{10, 240},
		16,
		5,
		rl.YELLOW,
	)
	eng.draw_font(
		&e.renderer.fonts,
		s.fira_font,
		fmt.ctprintf("right mouse pressed: %v", e.input.mouse.right.pressed),
		{10, 260},
		16,
		5,
		rl.YELLOW,
	)
	eng.draw_font(
		&e.renderer.fonts,
		s.fira_font,
		fmt.ctprintf("right mouse held: %v", e.input.mouse.right.held),
		{10, 280},
		16,
		5,
		rl.YELLOW,
	)
	eng.draw_font(
		&e.renderer.fonts,
		s.fira_font,
		fmt.ctprintf("right mouse released: %v", e.input.mouse.right.released),
		{10, 300},
		16,
		5,
		rl.YELLOW,
	)
	eng.draw_font(
		&e.renderer.fonts,
		s.fira_font,
		fmt.ctprintf("mouse pos: %v", s.mouse_pos),
		{10, 320},
		16,
		5,
		rl.YELLOW,
	)
	eng.draw_font(
		&e.renderer.fonts,
		s.fira_font,
		fmt.ctprintf("mouse delta: %v", s.mouse_delta),
		{10, 340},
		16,
		5,
		rl.YELLOW,
	)
	eng.draw_font(
		&e.renderer.fonts,
		s.fira_font,
		fmt.ctprintf("mouse wheel: %v", e.input.mouse.wheel),
		{10, 360},
		16,
		5,
		rl.YELLOW,
	)
	//end debug
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

