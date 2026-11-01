# Visual Art Handoff — LAST LIGHT

## Brief

Improve the visual quality and cohesion of the existing **2D portrait survival-defense**
prototype. This is an art pass, not a gameplay rewrite. The player is a human survivor
defending Shelter 09 from Hollows on a ruined city street. Keep the current Windows-first
scope; Android work remains deferred.

Use the genre-level ideas of *Last War: Survival Game* only as context. Do not copy its
characters, UI, environments, logos, or distinctive compositions. Create original assets.

## Current project

- Godot **4.7.2**, GDScript, 2D; project: `projects\last-light\project.godot`
- Portrait playfield: **360×640**; pixel-art look with nearest-neighbor filtering.
- Existing art is a basic generated placeholder set, not an approved final style:
  - `projects\last-light\assets\art\player\survivor.png`
  - `projects\last-light\assets\art\enemies\drifter.png`
  - `projects\last-light\assets\art\enemies\skitter.png`
  - `projects\last-light\assets\art\enemies\dasher.png`
  - `projects\last-light\assets\art\enemies\rift_warden.png`
  - `projects\last-light\assets\art\projectiles\player_bullet.png`
- Runtime scene and drawing entry point: `projects\last-light\scenes\gameplay\run.tscn`
  and `projects\last-light\scripts\gameplay\run.gd`.
- Read `docs\ART_DIRECTION.md` for the palette and readability goals, and
  `docs\GDD.md` for the game loop.

## Art priorities

1. Establish one strong, readable visual style using a small representative set first:
   survivor, Drifter, one street/background slice, and Shelter barricade.
2. Show that set in the actual 360×640 gameplay view and get it approved before producing
   the full enemy/FX family.
3. Finish the remaining enemy silhouettes (Skitter, Dasher, Rift Warden), rifle projectile,
   hit/breach/upgrade feedback, and lightweight street details.
4. Polish title/HUD framing only if it can be done without changing layout behavior or
   obscuring gameplay information.

## Visual constraints

- Make the fantasy instantly read as **people defending a street shelter**, not a ship shooter.
- Keep the survivor visibly human, carrying a rifle, and distinct from every enemy silhouette.
- Enemies approach from the top; the survivor and Shelter defenses occupy the lower field.
- Maintain clear contrast at native 360×640 and at the actual on-screen sprite sizes.
- Keep the combat lane and warnings uncluttered; backgrounds should be lower contrast than actors.
- Retain the existing muted ruined-city palette: asphalt `#202722` / `#343A32`,
  structures `#5B513C` / `#465044`, survivor olive/khaki, infected green/rust, and amber
  for Parts/warnings. Small refinements are welcome if readability is preserved.
- Pixel art should use deliberate clusters and consistent outlines/shading; avoid blurry
  resampling, noisy textures, tiny unreadable detail, and unnecessary screen-wide flashes.
- Do not add hunger/crafting/base-building gameplay, new mobile controls, or new story scope.
- Keep all generated/third-party assets original or clearly licensed; record any external
  asset license with the asset.

## Implementation and handoff rules

- Prefer replacing assets in their existing paths so current scene references keep working.
- If changing paths or formats, update every scene/resource reference and verify Godot imports.
- Keep editable source files or reproducible generation steps alongside generated output where
  practical; do not make an opaque generator the only way to maintain the assets.
- Do not change combat values, save schema, input, progression, or scene flow for visual polish.
- Do not remove MCP servers, skills, tooling, or project files unrelated to this art task.
- Keep changes focused and report what is artwork versus any necessary wiring.

## Acceptance checks

- The representative art set reads as a grounded on-foot survival defense scene at 360×640.
- Each enemy is identifiable by silhouette without relying on color alone.
- Player, enemy, projectile, warning, Shelter, Parts and HUD remain distinguishable during play.
- No missing resources, import/parser errors, or broken scene references.
- Run from the repository root:

```powershell
.\scripts\dev.ps1 -Action import
.\scripts\dev.ps1 -Action check
.\scripts\test.ps1
.\scripts\dev.ps1 -Action run
```

Automated tests must remain green. Include an in-game screenshot at the native portrait
resolution (or a clear note if the environment cannot capture one) and list changed assets.

## Ready-to-paste Codex task

> Improve the art in this Godot 4.7.2 game according to `docs/ART_HANDOFF.md` and
> `docs/ART_DIRECTION.md`. First inspect the current scene and assets. Produce one cohesive,
> original visual target (survivor, Drifter, street slice, Shelter barricade) and verify it
> in the real 360×640 gameplay scene before expanding to all enemies and effects. Preserve
> gameplay, input, save/progression, scene flow, Windows-first scope, existing asset references
> where practical, and all MCP/skill tooling. Do not imitate any specific commercial game's
> art/UI. Run import, project check, and automated tests; report changed files and visual
> verification. If you cannot capture a screenshot, say so explicitly.
