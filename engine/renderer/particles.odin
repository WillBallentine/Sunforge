package renderer

import core "core:math"
import rand "core:math/rand"
import rl "vendor:raylib"

MAX_PARTICLES :: 1024

Particle :: struct {
	position:       rl.Vector2,
	velocity:       rl.Vector2,
	color:          rl.Color,
	color_start:    rl.Color,
	color_end:      rl.Color,
	size:           f32,
	size_start:     f32,
	size_end:       f32,
	lifetime:       f32,
	total_lifetime: f32,
	gravity:        f32,
	active:         bool,
}

Particle_Config :: struct {
	position:     rl.Vector2,
	velocity_min: rl.Vector2,
	velocity_max: rl.Vector2,
	color_start:  rl.Color,
	color_end:    rl.Color,
	size_start:   f32,
	size_end:     f32,
	lifetime:     f32,
	gravity:      f32,
	count:        f32,
}

Particle_System :: struct {
	pool: [MAX_PARTICLES]Particle,
}

find_free_slot :: proc(ps: ^Particle_System) -> int {
	for &p, i in ps.pool {
		if !p.active do return i
	}
	return -1
}

find_oldest :: proc(ps: ^Particle_System) -> int {
	oldest := 0
	for &p, i in ps.pool {
		if p.lifetime < ps.pool[oldest].lifetime {
			oldest = i
		}
	}
	return oldest
}

emit_particles :: proc(ps: ^Particle_System, config: Particle_Config) {
	for _ in 0 ..< config.count {
		idx := find_free_slot(ps)
		if idx < 0 {
			idx = find_oldest(ps)
		}

		ps.pool[idx] = Particle {
			position       = config.position,
			velocity       = {
				rand.float32_range(config.velocity_min.x, config.velocity_max.x),
				rand.float32_range(config.velocity_min.y, config.velocity_max.y),
			},
			color          = config.color_start,
			color_start    = config.color_start,
			color_end      = config.color_end,
			size           = config.size_start,
			size_start     = config.size_start,
			size_end       = config.size_end,
			lifetime       = config.lifetime,
			total_lifetime = config.lifetime,
			gravity        = config.gravity,
			active         = true,
		}
	}
}

update_particle_system :: proc(ps: ^Particle_System, dt: f32) {
	for &p in ps.pool {
		if !p.active do continue

		p.velocity.y += p.gravity * dt
		p.position += p.velocity * dt
		p.lifetime -= dt

		if p.lifetime <= 0 {
			p.active = false
			continue
		}

		t := 1 - (p.lifetime / p.total_lifetime)
		p.size = core.lerp(p.size_start, p.size_end, t)

		p.color = {
			u8(core.lerp(f32(p.color_start.r), f32(p.color_end.r), t) + 0.5),
			u8(core.lerp(f32(p.color_start.g), f32(p.color_end.g), t) + 0.5),
			u8(core.lerp(f32(p.color_start.b), f32(p.color_end.b), t) + 0.5),
			u8(core.lerp(f32(p.color_start.a), f32(p.color_end.a), t) + 0.5),
		}
	}
}

draw_particles :: proc(ps: ^Particle_System) {
	for &p in ps.pool {
		if !p.active do continue

		half := p.size / 2
		top_left := rl.Vector2{p.position.x - half, p.position.y - half}
		rl.DrawRectangleV(top_left, {p.size, p.size}, p.color)
	}
}

