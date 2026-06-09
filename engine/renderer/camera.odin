package renderer

import rl "vendor:raylib"

Camera_State :: struct {
	camera:       rl.Camera2D,
	follow_speed: f32,
	trauma:       f32,
	trauma_decay: f32,
	shake_max:    f32,
	base_offset:  rl.Vector2,
}

camera_init :: proc(
	camera: ^Camera_State,
	offset: rl.Vector2,
	follow_speed, trauma_decay, shake_max: f32,
) {
	camera.base_offset = offset
	camera.follow_speed = follow_speed
	camera.trauma_decay = trauma_decay
	camera.shake_max = shake_max
	camera.camera.offset = offset
	camera.camera.zoom = 1.0
}

renderer_begin_camera :: proc(camera: Camera_State) {
	rl.BeginMode2D(camera.camera)
}

renderer_end_camera :: proc() {
	rl.EndMode2D()
}

camera_follow :: proc(camera: ^Camera_State, target: rl.Vector2, dt: f32) {
	camera.camera.target += (target - camera.camera.target) * camera.follow_speed * dt
}

add_trauma :: proc(camera: ^Camera_State, amount: f32) {
	camera.trauma = min(camera.trauma + amount, 1.0)
}

update_camera :: proc(camera: ^Camera_State, dt: f32) {
	camera.trauma = max(camera.trauma - camera.trauma_decay * dt, 0)

	shake := camera.trauma * camera.trauma

	if shake > 0 {
		rand_x := f32(rl.GetRandomValue(-100, 100)) / 100.0
		rand_y := f32(rl.GetRandomValue(-100, 100)) / 100.0
		camera.camera.offset =
			camera.base_offset +
			rl.Vector2{rand_x * camera.shake_max * shake, rand_y * camera.shake_max * shake}
	} else {
		camera.camera.offset = camera.base_offset
	}
}

