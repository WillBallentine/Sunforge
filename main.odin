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
	camera:          rl.Camera2D,
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

	eng.input_bind(&e.input, act(.Jump), .ENTER)
	eng.input_bind(&e.input, act(.Back), .SPACE)
	eng.input_bind(&e.input, act(.Move_Left), .A)
	eng.input_bind(&e.input, act(.Move_Right), .D)
	eng.input_bind(&e.input, act(.Move_Up), .W)
	eng.input_bind(&e.input, act(.Move_Down), .S)
	s.world_target = eng.renderer_make_target(&e.renderer)
	s.ui_target = eng.renderer_make_target(&e.renderer)
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

	s.camera = rl.Camera2D {
		offset = {f32(e.renderer.width) / 2, f32(e.renderer.height) / 2},
		target = s.player_position,
		zoom   = 1.0,
	}
}

title_update :: proc(e: ^eng.Engine, data: rawptr, dt: f32) {
	s := cast(^Title_State)data
	s.timer += dt
	s.mouse_pos = e.input.mouse.position

	s.mouse_delta = e.input.mouse.delta
	moving := e.input.mouse.left.held
	if eng.input_held(&e.input, act(.Move_Left)) {
		s.player_facing = .HORIZONTAL
		s.player_position.x -= 10
		moving = true
	}
	if eng.input_held(&e.input, act(.Move_Right)) {
		s.player_facing = .NONE
		s.player_position.x += 10
		moving = true
	}
	if eng.input_held(&e.input, act(.Move_Up)){
		s.player_position.y -= 10
		moving = true
	}
	if eng.input_held(&e.input, act(.Move_Down)){
		s.player_position.y += 10
		moving = true
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

	eng.renderer_begin_target(s.world_target)
	eng.renderer_clear(rl.BLACK)
	eng.renderer_begin_camera(s.camera)
	//eng.renderer_draw_text(cstring("hello world"), i32(50), i32(50), i32(100), rl.BLUE)
	//eng.renderer_draw_circle(rl.Vector2(10), f32(100.00), rl.WHITE)
	//
	// show all sprites on screen
	// start := 7
	// end := 12
	// for i in 7 ..< 13 {
	// 	sprite := eng.get_sprite(s.sprite, 48, 48, i32(i), 7)
	// 	eng.draw_texture(sprite, rl.Vector2{0, 0}, 1.0, s.player_facing, rl.WHITE)
	// 	eng.renderer_clear(rl.BLACK)
	// }

	sprite := eng.get_sprite_for_animation(&s.anim_state)
	eng.draw_texture(sprite, s.player_position, 2.0, s.player_facing, rl.WHITE)

	eng.renderer_end_camera()
	eng.renderer_end_target()

	eng.renderer_begin_target(s.ui_target)
	eng.renderer_clear({0, 0, 0, 0})
	//eng.renderer_draw_text(cstring("hello ui"), i32(690), i32(400), i32(100), rl.GREEN)
	//eng.renderer_draw_rect(rl.Rectangle{f32(150), f32(15), f32(25), f32(25)}, f32(25), rl.GREEN)
	eng.renderer_end_target()

	eng.renderer_blit(&e.renderer, s.world_target)
	eng.renderer_blit(&e.renderer, s.ui_target)
	//debug inputs
	//keyboard
	rl.DrawText(fmt.ctprintf("pressed: %v", e.input.actions[3].pressed), 10, 30, 16, rl.YELLOW)
	rl.DrawText(fmt.ctprintf("held: %v", e.input.actions[3].held), 10, 50, 16, rl.YELLOW)
	rl.DrawText(fmt.ctprintf("released: %v", e.input.actions[3].released), 10, 70, 16, rl.YELLOW)

	//mouse
	rl.DrawText(
		fmt.ctprintf("left mouse pressed: %v", e.input.mouse.left.pressed),
		10,
		200,
		16,
		rl.YELLOW,
	)
	rl.DrawText(
		fmt.ctprintf("left mouse held: %v", e.input.mouse.left.held),
		10,
		220,
		16,
		rl.YELLOW,
	)
	rl.DrawText(
		fmt.ctprintf("left mouse released: %v", e.input.mouse.left.released),
		10,
		240,
		16,
		rl.YELLOW,
	)
	//end debug inputs

	rl.DrawText("Sunforge Testing", 800, 90, 48, rl.GREEN)

	rl.DrawText(fmt.ctprintf("mouse pos: %v", s.mouse_pos), 10, 100, 16, rl.YELLOW)
	rl.DrawText(fmt.ctprintf("mouse delta: %v", s.mouse_delta), 10, 140, 16, rl.YELLOW)
	rl.DrawText(
		fmt.ctprintf("mouse pressed: %v", e.input.mouse.left.pressed),
		10,
		120,
		16,
		rl.YELLOW,
	)
	rl.DrawText(fmt.ctprintf("mouse held: %v", e.input.mouse.left.held), 10, 160, 16, rl.YELLOW)
	rl.DrawText(
		fmt.ctprintf("mouse released: %v", e.input.mouse.left.released),
		10,
		180,
		16,
		rl.YELLOW,
	)
	rl.DrawText(fmt.ctprintf("mouse wheel: %v", e.input.mouse.wheel), 10, 260, 16, rl.YELLOW)
}

title_destroy :: proc(e: ^eng.Engine, data: rawptr) {
	s := cast(^Title_State)data

	eng.renderer_destroy_target(s.world_target)
	eng.renderer_destroy_target(s.ui_target)
	free(data)
}

