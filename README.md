
<p align="center">
  <img src="sunforge_logo.png" alt="Sunforge logo" width="160">
</p>


# Sunforge

Sunforge is a 2D game engine written in [Odin](https://odin-lang.org/) on top of [raylib](https://www.raylib.com/).

## Status

Sunforge is **pre-v1** and under active development. APIs are unstable and may change without notice. See [Roadmap](#roadmap) for what's planned, and [CONTRIBUTING.md](CONTRIBUTING.md) if you'd like to help.

**NOTE**: the visuals of the app are not final. I am currently in the "get it working" pass of the engine and visuals will come in a beautification pass later in development.

## Current Features

### Project System (`project/`)
- **Project System**: a portable project layout (project.json + resources/ + scenes/) independent of the Sunforge source tree. `Project_Data` (name, entry scene, window config, icon path) is created/loaded/saved via `project_create`/`project_open`/`project_save`; `project_apply_icon` applies a project's window icon via `rl.LoadImage`/`rl.SetWindowIcon`.


### Editor (`editor/`)
- **Editor shell**: a separate executable for creating and opening Sunforge projects. Project setup uses a GUI project selector/creator with a recently-opened-projects list persisted to `recent_projects.json` next to the executable. Once a project loads, the editor opens into the editor view with an independent free-fly edit camera (right/middle-mouse drag to pan, scroll wheel to zoom), a world viewport rendered via the render-target/blit pipeline, and a resize-aware panel layout (Tools bar across the top, Palette/Entities left, Inspector right, Assets bottom) built on a custom immediate-mode UI toolkit (`editor/ui/`).
- **New Scene dialog**: create a new scene by entering a name and grid dimensions (width x height in tiles); generates a blank Tiled-format JSON tilemap and saves it into the project's `scenes/` directory, then loads it immediately into the editor.
- **Scene Browser**: lists all `.json` scene files in the project's `scenes/` directory, allows switching the active scene from within the editor, and supports renaming scene files. The active entry scene is persisted back to `project.json` on selection.
- **Tilemap Painter**: left-click to paint tiles onto the active layer, left-click drag for continuous strokes. A scrollable tile palette in the left panel shows all tiles from the active tileset (scaled to fixed thumbnails); clicking a tile selects it. An Erase toggle replaces the selected tile with an empty cell (-1). Painting is applied live during drag; on mouse release the full stroke is committed to the undo/redo history and auto-saved to disk.
- **Multi-layer painting**: the painter supports up to four independent tile layers. Layer selector buttons switch the active paint target. `+` / `-` buttons add or remove layers with full undo/redo support. Per-layer visibility toggles ("hide"/"show") control which layers are drawn in the editor viewport without affecting paint operations. Per-layer z drag floats control each layer's position in the unified render order.
- **Tile grid overlay**: press `G` to toggle a 1px grid drawn over the tilemap in world space, scaled with camera zoom, useful for aligning tiles precisely.
- **Tile eyedropper (pick mode)**: hold `Alt` to enter pick mode (cursor changes to a pointing hand); right-click any painted tile to set it as the active palette selection without leaving the paint workflow.
- **Tile Rotation**: press `R` to change rotation of selected tile before painting to scene
- **Unified z-sort layer ordering**: tile layers and the entity block are sorted and rendered together by z value each frame rather than split by a hardcoded layer index. Default z values (layer 0 = 0.0, entity block = 1.0, layer 1 = 2.0) reproduce the expected background/entity/foreground order out of the box. Layer z values are editable per-layer in the tools panel and are persisted to the Tiled JSON file.
- **Entity Placement tool**: switch to Entity Tool to place entities in world space by clicking. Drag an entity's crosshair gizmo to move it; press `Delete` to remove the selected entity. All operations (place, move, delete) are fully undoable via `Ctrl+Z` / `Ctrl+Y`.
- **Entity Inspector**: selecting an entity reveals its properties in the Inspector panel — name (text input), X/Y position (drag floats), Z depth (drag float), scale (drag float), sprite sheet path (display), and an "Assign Sprite" button that applies the currently selected asset browser entry. All inspector edits are auto-saved on mouse release.
- **Entity list panel**: while in Entity Tool mode the left panel switches from the tile palette to a scrollable list of all placed entities; clicking a row selects it in the viewport.
- **Entity sprite rendering**: entities with an assigned sprite sheet are rendered live in the world viewport using the shared texture cache (`scene_texture`) and the draw buffer, with z depth and scale applied. Entities without a sprite show only their crosshair gizmo.
- **Undo/redo history**: `Ctrl+Z` / `Ctrl+Y` step through a command stack (`Editor_History`). Commands are data-driven (`do_fn` / `undo_fn` / `data`) so any editor operation can be made undoable. Wired for tile stroke operations and all entity operations (place, move, delete).
- **Tilemap auto-save**: after every completed paint stroke or entity operation the tilemap and scene are written to disk automatically.
- **Tilemap boundary indicator**: a white rectangle is drawn in world space at the tilemap's exact pixel extents so you always know where the drawable area ends. Line thickness compensates for camera zoom to stay visually consistent.
- **Asset browser**: finds all files within the project's `resources/` folder and presents them as a selectable list. Texture files show thumbnails; all assets are sortable by type.

### Core (`engine/core`)
- **Window**: configurable size/title/target FPS, fullscreen toggle, and runtime resize handling for resizeable windows
- **Clock**: delta-time tracking with a frame-time cap to avoid large time steps after a stall
- **Input**: keyboard and gamepad action bindings, pressed/held/released state tracking, and mouse position/delta/wheel/button state
- **Math**: small `Vec2`/`Rect` types and `lerp`/`clamp`/`vec2_*`/`rect_contains` helpers

### Renderer (`engine/renderer`)
- **Render targets**: offscreen targets for compositing layers (e.g. world + UI), blitted together each frame
- **Basic shapes**: rectangle (outline), circle, and line drawing primitives
- **Fonts**: TrueType font loading (`rl.LoadFontEx`) through an ID-based registry (`Font_ID`), with load/unload lifecycle tied into the renderer's init/shutdown, plus text drawing and measurement (`draw_font` / `measure_font`)
- **Sprites**: sprite-sheet slicing (grid and row layouts) with horizontal/vertical flipping
- **Animation**: frame-based playback with configurable FPS, looping, pause/resume, and per-frame event tags for triggering gameplay logic
- **Camera**: smooth follow, trauma-based screen shake, and world/screen coordinate conversion
- **Shaders**: fragment shader loading, uniform setters (float, vec2, texture), and a post-processing blit path
- **Tilemap**: multi-layer tile grids with viewport-culled rendering, a per-tile collision layer, `tilemap_load_tiled`/`tilemap_save_tiled` for reading and writing Tiled-format JSON, and `ts_tilecount` tracking the number of tiles in the active tileset
- **Particles**: fixed 1024-particle pool with configurable velocity range, color gradient, size gradient, lifetime, and gravity per burst
- **Draw order / z-sorting**: a per-frame draw command buffer (`Draw_Buffer`, up to 2048 commands). `draw_buffer_push` queues a `Draw_Command`; `draw_buffer_flush` sorts back-to-front by `z` using insertion sort, draws each, then resets the buffer
- **Sprite rotation & pivot**: `renderer_draw_sprite` supports rotation (degrees, clockwise) and a `Pivot_Point` (`CENTER` or `BOTTOM`) controlling the rotation and scale origin

### Example
[main.odin](main.odin) ties these systems together in one scene: a tilemap-based level, a player character with idle/walk/jump-flip animations (landing triggers a particle burst via a frame event) pushed through the z-sorted draw buffer with rotation and pivot, jump particle effects, camera follow with shake on jump, a font-rendered title, and a debug overlay of live input state rendered with a second font.


## Not Yet Implemented

These packages exist as stubs and are planned for upcoming tiers (see [Roadmap](#roadmap)):

- `engine/physics`: collision/physics world
- `engine/audio`: sound and music playback
- `engine/assets`: asset caching and hot-reload
- `engine/ui`: immediate-mode UI system for in-game UI (separate from the editor-only `editor/ui` toolkit)
- Editor: particle editor, animation editor, play-in-editor
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
  project/                      Project_Data manifest, project_create/open/save, icon application
  editor/
    main.odin                   editor entry point (project picker)
    editor_scene.odin           editor shell: edit camera, world viewport, panel layout
    tilemap_painter.odin        tile palette, paint/erase strokes, auto-save
    tile_commands.odin          Tile_Cell_Edit, Tile_Stroke_Data, make_tile_stroke_command
    editor_history.odin         Editor_History, Editor_Command, undo/redo stack
    new_scene_dialog.odin       New Scene dialog: name + grid dims -> Tiled JSON tilemap
    scene_browser_dialog.odin   Scene Browser: list/switch/rename .json scenes
    scene_data.odin             Scene_Data (tilemap_path, entities, camera), scene_load/save
    project_picker_scene.odin   initial screen for selecting/creating projects
    recent_projects.odin        recently opened projects list
    folder_picker_windows.odin  Windows folder picker dialog
    asset_browser.odin          asset panel with texture thumbnails, type sorting
    build_editor.bat
    ui/                         immediate-mode UI toolkit (buttons, sliders, color pickers, etc.)
  core/                         window, clock, input, math (foundation)
  renderer/                     rendering, camera, sprites, animation, tilemap, particles, shaders, fonts
  physics/                      (stub, planned)
  audio/                        (stub, planned)
  assets/                       (stub, planned)
  ui/                           (stub, planned)
  engine.odin                   unified public API re-exporting the packages above
main.odin                       example game/scene
resources/                      textures, tilesets, shaders, fonts
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

