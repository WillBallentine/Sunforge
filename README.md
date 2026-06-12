
<p align="center">
  <img src="sunforge_logo.png" alt="Sunforge logo" width="160">
</p>


# Sunforge

Sunforge is a 2D game engine written in [Odin](https://odin-lang.org/) on top of [raylib](https://www.raylib.com/).

## Status

Sunforge is **pre-v1** and under active development. APIs are unstable and may change without notice. See [Roadmap](#roadmap) for what's planned, and [CONTRIBUTING.md](CONTRIBUTING.md) if you'd like to help.

## Current Features

### Project System (`project/`)
- **Project System**: a portable project layout (project.json + resources/ + scenes/) independent of the Sunforge source tree. Project_Data (name, entry scene, window config, icon path) is created/loaded/saved via project_create/project_open/project_save; project_apply_icon applies a project's window icon via rl.LoadImage/rl.SetWindowIcon.

### Editor (`editor/`)
- **Editor**: a separate executable (editor/) for creating and opening Sunforge projects. Currently a console-based picker (type a folder path to create or open a project) with a recently-opened-projects list persisted to recent_projects.json next to the executable. Full editor UI/shell is pending

### Core (`engine/core`)
- **Window**: configurable size/title/target FPS, fullscreen toggle, and runtime resize handling for resizeable windows
- **Clock**: delta-time tracking with a frame-time cap to avoid large time steps after a stall
- **Input**: keyboard and gamepad action bindings, pressed/held/released state tracking, and mouse position/delta/wheel/button state
- **Math**: small `Vec2`/`Rect` types and `lerp`/`clamp`/`vec2_*`/`rect_contains` helpers. `lerp` drives particle color/size gradient interpolation; `Vec2`/`Rect` are early utilities pending consolidation with `rl.Vector2`/`rl.Rectangle` that will be enhanced in future updates

### Renderer (`engine/renderer`)
- **Render targets**: offscreen targets for compositing layers (e.g. world + UI), blitted together each frame
- **Basic shapes**: rectangle (outline), circle, and line drawing primitives
- **Fonts**: TrueType font loading (`rl.LoadFontEx`) through an ID-based registry (`Font_ID`), with load/unload lifecycle tied into the renderer's init/shutdown, plus text drawing and measurement (`draw_font` / `measure_font`)
- **Sprites**: sprite-sheet slicing (grid and row layouts) with horizontal/vertical flipping
- **Animation**: frame-based playback with configurable FPS, looping, pause/resume, and per-frame event tags for triggering gameplay logic (e.g. a landing effect on a specific frame)
- **Camera**: smooth follow, trauma-based screen shake, and world/screen coordinate conversion
- **Shaders**: fragment shader loading, uniform setters (float, vec2, texture), and a post-processing blit path
- **Tilemap**: multi-layer tile grids with viewport-culled rendering and a per-tile collision layer
- **Particles**: fixed 1024-particle pool with configurable velocity range, color gradient, size gradient, lifetime, and gravity per burst
- **Draw order / z-sorting**: a per-frame draw command buffer ('Draw_Buffer', up to 2048 commands). 'draw_buffer_push' queues a 'Draw_Command'; 'draw_buffer_flush' sorts the queue back-to-front by a 'z' key using insertion sort (cheap for nearly-sorted per-frame data), draws each via `renderer_draw_sprite`, then resets the buffer, so depth ordering "just works" without manual call order
- **Sprite rotation & pivot**: `renderer_draw_sprite` supports rotation (degrees, clockwise) and a `Pivot_Point` (`CENTER` or `BOTTOM`) controlling the rotation and scale origin (this will be enhanced in future updates)

### Example
[main.odin](main.odin) ties these systems together in one scene: a tilemap-based level, a player character with idle/walk/jump-flip animations (landing triggers a particle burst via a frame event) pushed through the z-sorted draw buffer with rotation and pivot, jump particle effects, camera follow with shake on jump, a font-rendered title, and a debug overlay of live input state rendered with a second font.


## Not Yet Implemented

These packages exist as stubs and are planned for upcoming tiers (see [Roadmap](#roadmap)):

- `engine/physics`: collision/physics world
- `engine/audio`: sound and music playback
- `engine/assets`: asset caching and hot-reload
- `engine/ui`: immediate-mode UI system
- Editor UI/shell, asset browser, scene/tilemap editors
- Entity/scene management, timers, events, save system, scripting, and more

## Getting Started

Requires the [Odin compiler](https://odin-lang.org/docs/install/) (raylib bindings are bundled via `vendor:raylib`).

```sh
build.bat
game_debug.exe
```

Run this from the repo root:
```sh
editor\build_editor.bat
bin\editor_debug.exe
```


## Project Structure

```
engine/
  project/                  Project_Data manifest, project_create/open/save, icon application
  editor/
    main.odin               editor entry point (project picker)
    recent_projects.odin    recently opened project
    build_editor.bat
    
  core/                     window, clock, input, math (foundation)
  renderer/                 rendering, camera, sprites, animation, tilemap, particles, shaders, fonts
  physics/                  (stub, planned)
  audio/                    (stub, planned)
  assets/                   (stub, planned)
  ui/                       (stub, planned)
  engine.odin               unified public API re-exporting the packages above
main.odin                   example game/scene (soon to become a Sunforge project once the editor is more complete)
resources/                  textures, tilesets, shaders, fonts
```

## Roadmap

Sunforge's roadmap is tracked via GitHub issues, organized by label. Browse everything at [github.com/WillBallentine/Sunforge/issues](https://github.com/WillBallentine/Sunforge/issues).

| Tier | Focus | Issues |
|------|-------|--------|
| [tier-0-editor](https://github.com/WillBallentine/Sunforge/issues?q=is%3Aissue+label%3Atier-0-editor) | Visual editor tooling — tilemap painter, entity placement, particle/animation editors, asset browser, undo/redo, play-in-editor. Planned to be built **before** the rest of the v1 roadmap so the engine doesn't require hand-written Odin to build levels. | [view](https://github.com/WillBallentine/Sunforge/issues?q=is%3Aissue+label%3Atier-0-editor) |
| [tier-1-foundation](https://github.com/WillBallentine/Sunforge/issues?q=is%3Aissue+label%3Atier-1-foundation) | Window, Clock, Input enhancements | [view](https://github.com/WillBallentine/Sunforge/issues?q=is%3Aissue+label%3Atier-1-foundation) |
| [tier-2-rendering](https://github.com/WillBallentine/Sunforge/issues?q=is%3Aissue+label%3Atier-2-rendering) | Renderer, Camera, Sprites, Animation, Tilemap, Particles, Shaders, Fonts | [view](https://github.com/WillBallentine/Sunforge/issues?q=is%3Aissue+label%3Atier-2-rendering) |
| [tier-3-physics](https://github.com/WillBallentine/Sunforge/issues?q=is%3Aissue+label%3Atier-3-physics) | Physics world, bodies, triggers, raycasts | [view](https://github.com/WillBallentine/Sunforge/issues?q=is%3Aissue+label%3Atier-3-physics) |
| [tier-4-audio](https://github.com/WillBallentine/Sunforge/issues?q=is%3Aissue+label%3Atier-4-audio) | Audio manager, SFX, music, volume groups | [view](https://github.com/WillBallentine/Sunforge/issues?q=is%3Aissue+label%3Atier-4-audio) |
| [tier-5-assets](https://github.com/WillBallentine/Sunforge/issues?q=is%3Aissue+label%3Atier-5-assets) | Asset cache, hot reload | [view](https://github.com/WillBallentine/Sunforge/issues?q=is%3Aissue+label%3Atier-5-assets) |
| [tier-6-entities](https://github.com/WillBallentine/Sunforge/issues?q=is%3Aissue+label%3Atier-6-entities) | Entity pool, spatial queries | [view](https://github.com/WillBallentine/Sunforge/issues?q=is%3Aissue+label%3Atier-6-entities) |
| [tier-7-scenes](https://github.com/WillBallentine/Sunforge/issues?q=is%3Aissue+label%3Atier-7-scenes) | Scene stack, transitions | [view](https://github.com/WillBallentine/Sunforge/issues?q=is%3Aissue+label%3Atier-7-scenes) |
| [tier-8-ui](https://github.com/WillBallentine/Sunforge/issues?q=is%3Aissue+label%3Atier-8-ui) | Immediate-mode UI, layout | [view](https://github.com/WillBallentine/Sunforge/issues?q=is%3Aissue+label%3Atier-8-ui) |
| [tier-9-utilities](https://github.com/WillBallentine/Sunforge/issues?q=is%3Aissue+label%3Atier-9-utilities) | Math, timers, events, debug draw, save, profiler, console, localization | [view](https://github.com/WillBallentine/Sunforge/issues?q=is%3Aissue+label%3Atier-9-utilities) |
| [tier-10-scripting](https://github.com/WillBallentine/Sunforge/issues?q=is%3Aissue+label%3Atier-10-scripting) | Embeddable scripting for game logic — native Odin hot-reload, Lua, WASM, C# | [view](https://github.com/WillBallentine/Sunforge/issues?q=is%3Aissue+label%3Atier-10-scripting) |
| [post-v1](https://github.com/WillBallentine/Sunforge/issues?q=is%3Aissue+label%3Apost-v1) | Deferred polish/enhancements for already-built systems, picked up after v1 ships | [view](https://github.com/WillBallentine/Sunforge/issues?q=is%3Aissue+label%3Apost-v1) |

## Contributing

Interested in contributing? See [CONTRIBUTING.md](CONTRIBUTING.md) for how to get started.

## License

Sunforge is licensed under the [MIT License](LICENSE).

