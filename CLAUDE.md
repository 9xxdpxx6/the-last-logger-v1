# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"The Last Logger" — solo indie survival sim about a lumberjack, slowly turning
into folk horror. Godot **4.6.3**, GDScript, 3D, first-person. Physics: **Jolt**
(default 3D engine in 4.6). Renderer: Forward+, D3D12 on Windows.

The developer is **not a Godot expert**. When proposing changes, explain *what*
and *why*, and spell out which nodes must be created by hand in the editor and in
what order. Work in small, testable steps — build only what the current request
asks for, not the whole game.

## Commands

Godot executable (Windows): `C:\Users\9xxdp\Desktop\Godot_v4.6.3-stable_win64.exe`

```powershell
# Run the game (main scene = scenes/world.tscn)
& "$env:USERPROFILE\Desktop\Godot_v4.6.3-stable_win64.exe" --path .

# Run a specific scene
& "$env:USERPROFILE\Desktop\Godot_v4.6.3-stable_win64.exe" --path . scenes/world.tscn

# Headless: import assets / check the project parses without opening a window
& "$env:USERPROFILE\Desktop\Godot_v4.6.3-stable_win64.exe" --headless --path . --quit

# Open the editor
& "$env:USERPROFILE\Desktop\Godot_v4.6.3-stable_win64.exe" -e --path .
```

There is no separate build/lint/test toolchain yet. To validate a change, run the
relevant scene and read the console output. The `godot` MCP server (configured in
`.mcp.json`) can launch the project and capture engine errors directly.

## Layout

- `scenes/` — `.tscn` scene files. `world.tscn` is the main/test level; it
  instances `player.tscn`.
- `scripts/` — `.gd` scripts. Keep one script per node type; name it after what it
  drives (`player.gd`).
- `assets/{models,textures,audio}/` — imported art and sound source files.
- `resources/` — `.tres`/`.res` data resources (custom Resource types, configs).

## Assets: download vs. build from scratch

This is a solo project and Claude cannot reliably generate or fetch binary art
itself. Default to **sourcing** finished art and **building** only gameplay
geometry. When art is needed, Claude's job is to recommend a specific CC0 source
and walk through the import — the developer downloads the files.

**Source ready-made (don't hand-build):**
- 3D models — trees, tools, props, structures, characters
- Textures / materials / PBR maps, HDRIs and skyboxes
- Audio — ambience, SFX, foley, music
- Reason: these need a DCC tool (Blender) or recording, not GDScript. For an
  indie shipping target, a good CC0 pack saves days and keeps licensing clean.

**Build from scratch in-engine:**
- Collision shapes, `Area3D` triggers, spawn/marker nodes, gameplay logic
- **Greybox/placeholder** geometry — `BoxMesh`/`CylinderMesh`/`CapsuleMesh`
  primitives to block out a level or prototype a mechanic before real art exists
- Procedural systems, shaders, fog, simple flat materials
- Anything trivial where finding and importing costs more than making it

**Workflow:** greybox first with primitives, keep building gameplay, swap in real
assets later — never block mechanics work on missing art.

**Licensing:** use only **CC0** or explicitly commercial-compatible licenses.
Record source + license for every imported asset (a `CREDITS.md` or note in
`resources/`). Never import assets of unknown/scraped license. Good CC0 starting
points: Kenney (kenney.nl), Quaternius, Poly Haven (HDRIs/textures/models),
ambientCG (textures), Freesound (check per-file license).

## Conventions

- **GDScript:** tab indentation, static typing on declarations and signatures
  (`var x: float`, `func f() -> void`). Tunable values are `@export` vars so they
  can be adjusted in the Inspector without editing code.
- **`.tscn` files are text** and can be hand-authored, but prefer changing scenes
  in the editor when structure is non-trivial — Godot rewrites UIDs and resource
  IDs on save, and manual edits are easy to corrupt.
- **Node-tree contract for the player** (`player.tscn`): `player.gd` expects a
  `CharacterBody3D` root with a child `Camera3D` (look pitch is applied to the
  camera, yaw to the body) and a `CollisionShape3D`. Renaming those children
  breaks the script's `$Camera3D` lookup.

## Input map

Defined in `project.godot` `[input]` via `physical_keycode` (layout-independent):
`move_forward` (W), `move_back` (S), `move_left` (A), `move_right` (D),
`run` (Shift). Look/cursor are handled in code: cursor is captured on start,
`Esc` (`ui_cancel`) releases it, a click re-captures.
