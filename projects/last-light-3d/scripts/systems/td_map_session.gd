class_name TDMapSession
extends RefCounted

## Which map the next run scene should build. Static like the snapshot's
## resume_requested flag: survives change_scene, read exactly once per run.
## Map 1 is the default; the HUD's victory overlay sets the advance token,
## and an owned session snapshot may pin its own map id (free-tower positions
## are meaningless on another layout).

const MIN_MAP_ID: int = 1
## Data maps live in data/maps/map_XX.tres; grow this when a map ships.
const MAX_MAP_ID: int = 2

static var selected_map: int = MIN_MAP_ID


static func select_map(map_id: int) -> void:
	selected_map = clampi(map_id, MIN_MAP_ID, MAX_MAP_ID)


## Victory "next map" handoff: advance one map, capped at the last shipped.
static func advance() -> void:
	select_map(selected_map + 1)


## Back at the title menu the provenance resets (a fresh start means map 1;
## a resuming snapshot re-pins its own map right after).
static func reset() -> void:
	selected_map = MIN_MAP_ID
