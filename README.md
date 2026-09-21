# Neel Nagar

An original third-person open-world urban action sandbox built in **Godot 4.7.2** with GDScript.
Featuring a Nepal-inspired procedural city, M.A.V.S vehicle physics, missions, police pursuit, and a full HUD.

This project was developed entirely with AI assistance — testing how effectively an AI agent can design,
implement, debug, and polish a complete game from concept to working product.

## How to run

Open the project folder in Godot 4.7.2, or from a terminal:

```powershell
Godot_v4.7.2-stable_win64_console.exe --path "<path-to>/NeelNagar"
```

Press **ENTER** or **Space** to start.

## Controls

| Key | Action |
|-----|--------|
| `W A S D` / Arrows | Move on foot |
| Mouse | Look / orbit camera |
| `Shift` | Sprint |
| `Space` | Jump (on foot) / Handbrake (vehicle) |
| `E` | Enter / exit vehicle |
| `F` | Start mission / interact |
| `W` / `S` | Accelerate / brake (vehicle) |
| `A` / `D` | Steer (vehicle) |
| `Q` / `Z` | Shift up / down (manual gearbox) |
| `1`–`5`, `6` | Select gear (manual gearbox) |
| `L` | Headlights |
| `C` | Change camera |
| `R` | Reset / flip vehicle |
| `Esc` | Pause |

> All movement and vehicle bindings are defined in `project.godot` (InputMap). The player reads
> `move_forward/back/left/right`, `sprint`, and `jump`; the M.A.V.S vehicle reads
> `Acceleration`, `Brake`, `Left`, `Right`, `Hand Brake`, `Nitro`, `Lights`, `Camera Change`,
> `Reset`, `Shift Up`, `Shift Down`, and `Gear 1`–`Gear 5` / `Gear Reverse`.

## Features

- **Nepal-inspired city** — 5x5 block grid with red brick buildings, tiered pagoda roofs, wooden
  floor separators, carved window frames, stupas, pagoda temples, chowks, and prayer flags.
- **M.A.V.S vehicles** — VehicleBody3D-based cars with arcade physics, steering, handbrake, and
  damage. Multiple vehicle types spawned across the city.
- **Custom player controller** — CharacterBody3D with WASD movement, mouse-look third-person
  camera, sprint, jump, and vehicle enter/exit via interaction sphere.
- **Traffic AI** — Lane-following NPC vehicles with obstacle avoidance using M.A.V.S path system.
- **Pedestrians** — 20+ NPCs with wander AI using NavigationAgent3D and navigation regions.
- **Missions** — 3 missions (Cold Run, Heat Sink, Ironworks Score) with yellow cylinder markers,
  objective tracking, cash and health rewards.
- **Police / wanted system** — 4 wanted levels with heat mechanics, police vehicle spawning,
  pursuit AI (chase, circle, brake-check), alternating red/blue lights, and siren audio.
- **Save system** — JSON persistence to `user://neel_nagar_save.json` with auto-save on
  mission completion. Saves player position, health, cash, and completed missions.
- **HUD** — Health, cash, 5-star wanted meter, compass heading, speedometer (km/h), live minimap
  (top-down SubViewport camera following the player), mission arrow with distance, and control hints.
- **Day/night lighting** — Directional sun with shadows, ambient light, fog, and glow.

## Architecture

```
NeelNagar/
  project.godot              physics layers, input map, rendering config
  scenes/
    Main.tscn                root scene, attaches game.gd
    NPC.tscn                 CharacterBody3D + NavigationAgent3D
  scripts/
    game.gd                  boot, city gen, spawning, vehicle enter/exit, HUD, QA
    simple_player.gd         CharacterBody3D player controller
    npc.gd                   wander AI with NavigationAgent3D
    missions.gd              MissionSystem class — 3 missions, markers, rewards
    police.gd                PoliceSystem class — wanted levels, pursuit, lights/siren
    save_game.gd             JSON save/load with auto-save
    player_adapter.gd        vehicle interaction adapter
  addons/
    M.A.V.S/                 VehicleBody3D vehicles + traffic AI (MIT license)
  _assets/                   cloned addon source repos
```

## AI Development Process

This project was built through an iterative AI-assisted development cycle:

1. **Concept & planning** — AI designed the game architecture, systems, and Nepal city theme
2. **Implementation** — AI wrote all GDScript code, procedural city generation, and system integration
3. **Addon integration** — AI researched, cloned, and adapted third-party addons (M.A.V.S vehicle system),
   fixing compatibility issues, path references, and class name conflicts
4. **Debugging** — AI diagnosed and fixed parse errors, type inference issues, missing input actions,
   variant typing, and runtime crashes through automated headless testing
5. **Visual QA** — AI captured and analyzed screenshots using OCR and image analysis tools to verify
   rendering, HUD display, and city aesthetics
6. **Iteration** — Multiple cycles of code → test → screenshot → fix, all driven by AI

The entire codebase — from project structure to individual functions — was generated, tested, and
refined by AI, demonstrating the current capability of AI-assisted game development.

## Verification

- Import and headless run produce **zero** `SCRIPT ERROR`, `Parse Error`, or `Compile Error`
- Visual QA via screenshot confirms: Nepal-style brick buildings with tiered roofs, HUD rendering
  ("NEEL NAGAR", "Health: 100%", "Cash: $0", "Wanted: None"), vehicle and player visible
- All systems (missions, police, save, traffic, NPCs) wired into game loop without runtime errors

## License

Original game code is open-source. Third-party addons (M.A.V.S) retain their original MIT licenses.
This project reproduces no copyrighted characters, maps, logos, dialogue, or branding.
