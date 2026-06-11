<p align="center">
  <img src="sunforge_logo.png" alt="Sunforge logo" width="160">
</p>


# Sunforge

Sunforge is a 2D game engine written in [Odin](https://odin-lang.org/) on top of [raylib](https://www.raylib.com/).

## Status

Sunforge is **pre-v1** and under active development. APIs are unstable and may change without notice. See [Roadmap](#roadmap) for what's planned, and [CONTRIBUTING.md](CONTRIBUTING.md) if you'd like to help.

## Current Features

### Core (`engine/core`)
- **Window**: configurable size/title/target FPS, fullscreen toggle, and runtime resize handling for resizeable windows
- **Clock**: delta-time tracking with a frame-time cap to avoid large time steps after a stall
- **Input**: keyboard and gamepad action bindings, pressed/held/released state tracking, and mouse position/delta/wheel/button state

### Renderer (`engine/renderer`)
- **Render targets**: offscreen targets for compositing layers (e.g. world + UI), blitted together each frame
- **Basic shapes**: rectangle (outline), circle, line, and text drawing primitives
- **Sprites**: sprite-sheet slicing (grid and row layouts) with horizontal/vertical flipping
- **Animation**: frame-based playback with configurable FPS, looping, and pause/resume
- **Camera**: smooth follow, trauma-based screen shake, and world/screen coordinate conversion
- **Shaders**: fragment shader loading, uniform setters (float, vec2, texture), and a post-processing blit path
- **Tilemap**: multi-layer tile grids with viewport-culled rendering and a per-tile collision layer
- **Particles**: fixed 1024-particle pool with configurable velocity range, color gradient, size gradient, lifetime, and gravity per burst

### Example
[main.odin](main.odin) ties these systems together in one scene: a tilemap-based level, a player character with idle/walk/jump-flip animations, jump particle effects, camera follow with shake on jump, and a debug overlay showing live input state.

## Not Yet Implemented

These packages exist as stubs and are planned for upcoming tiers (see [Roadmap](#roadmap)):

- `engine/physics`: collision/physics world
- `engine/audio`: sound and music playback
- `engine/assets`: asset caching and hot-reload
- `engine/ui`: immediate-mode UI system
- Entity/scene management, timers, events, save system, scripting, and more

## Getting Started

Requires the [Odin compiler](https://odin-lang.org/docs/install/) (raylib bindings are bundled via `vendor:raylib`).

```sh
build.bat
game_debug.exe
```

## Project Structure

```
engine/
  core/       window, clock, input, math (foundation)
  renderer/   rendering, camera, sprites, animation, tilemap, particles, shaders
  physics/    (stub, planned)
  audio/      (stub, planned)
  assets/     (stub, planned)
  ui/         (stub, planned)
  engine.odin unified public API re-exporting the packages above
main.odin     example game/scene
resources/    textures, tilesets, shaders
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
