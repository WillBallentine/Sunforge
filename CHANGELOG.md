
# Changelog

This document summarizes Sunforge's development to date, grouped by engine system. Sunforge does not yet have versioned releases, this document reflects the current state of `main`.

## Project Setup

- Initial Odin project scaffold and engine package layout (`engine/core`, `engine/renderer`, plus stub packages for `physics`, `audio`, `assets`, and `ui`)
- Unified public API re-exported from `engine/engine.odin`, with a `Scene_Procs` (init/update/render/destroy) pattern and a top-level `run`/`tick` loop

## Core

- **Window**: configurable window (size, title, target FPS), fullscreen toggle, and runtime resize handling for resizeable windows
- **Clock**: delta-time tracking with a cap to avoid large time steps after a stall
- **Input**: keyboard and gamepad action bindings (`input_bind_keyboard` / `input_bind_controller`), pressed/held/released state tracking, mouse position/delta/wheel/button state, and basic gamepad/controller support
- **Math**: `Vec2`/`Rect` types plus `lerp`/`clamp`/`vec2_*`/`rect_contains` helpers; `lerp` is used for particle color and size gradient interpolation

## Renderer

- **Render targets**: offscreen render targets for compositing multiple layers (e.g. world + UI), blitted together each frame
- **Basic shapes**: rectangle (outline), circle, and line drawing primitives
- **Fonts**: TrueType font loading via `rl.LoadFontEx`, managed through an ID-based registry (`Font_ID`) with load/unload tied into the renderer's init/shutdown lifecycle; text drawing and measurement via `draw_font` / `measure_font` (replaces the previous `rl.DrawText`-based text primitive)
- **Sprites**: sprite-sheet slicing (grid and row layouts) with horizontal/vertical flip support
- **Animation**: frame-based animation playback with configurable FPS, looping, and pause/resume; per-frame event tags (`Frame_Event`) for triggering gameplay logic on specific animation frames; fixed a possible nil dereference in animation state updates
- **Camera**: smooth follow, trauma-based screen shake, and world/screen coordinate conversion
- **Shaders**: fragment shader loading, uniform setters (float, vec2, texture), and a post-processing blit path
- **Tilemap**: multi-layer tile grids with viewport-culled rendering and a per-tile collision/solid layer
- **Particles**: fixed 1024-particle pool with per-burst configurable velocity range, color gradient, size gradient, lifetime, and gravity, with oldest-particle recycling when the pool is full
- **Draw order / z-sorting**: added `Draw_Buffer` (up to 2048 `Draw_Command`s — sprite, position, scale, rotation, pivot, flip, tint, z) to `Renderer_State`. `draw_buffer_flush` sorts by `z` ascending via insertion sort and draws each command via `renderer_draw_sprite`, then clears the buffer. Re-exported from `engine.odin`; game code now pushes draw commands (`draw_buffer_push`) once per frame instead of calling sprite-draw directly
- **Sprite rotation and pivot**: `renderer_draw_sprite` gained a `rotation` (degrees) parameter and a `Pivot_Point` enum (`CENTER`, `BOTTOM`) for the rotation/scale origin — `CENTER` for a sprite's center, `BOTTOM` for its "feet". `Draw_Command` carries both

## Example / Tooling

- `main.odin` example scene combining the systems above: a tilemap-based level, a player character with idle/walk/jump-flip animations (landing triggers a particle burst via a frame event), jump particle bursts, camera follow with shake on jump, a font-rendered title, and a debug overlay of live input state rendered with a second font
- `build.bat` for building a debug Windows executable via `odin build`

## Looking Ahead

See [README.md](README.md#roadmap) and the [issue tracker](https://github.com/WillBallentine/Sunforge/issues) for planned work across tier-0 through tier-10 and post-v1.
