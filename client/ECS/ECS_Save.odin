
package ECS

import "core:encoding/json"
import "core:os"
import "core:fmt"


// ============================================================
// SAVE CONFIGURATION
// ============================================================

SAVE_VERSION :: u32(1)
SAVE_PATH    :: "saves/world_save.json"


// ============================================================
// SAVE STRUCTURES
// ============================================================

// Shared entity manager data.
// Add persistent Entity_Manager fields here in the future.

Entity_Manager_Save :: struct {
    entity_capacity: int,
    next_entity:     u32,

    entity_state:  [dynamic]u8,
    free_entities: [dynamic]u32,
}


// ECS-specific save data.
// Add new ECS components here.

ECS_Save_Data :: struct {
    Entity: Entity_Manager_Save,

    tags:      [dynamic]u8,
    positions: [dynamic]Position,
    rotations: [dynamic]Rotation,
    velocities: [dynamic]Velocity,
}


// PCS-specific save data.
// Add new particle components here.

PCS_Save_Data :: struct {
    Entity: Entity_Manager_Save,

    tags:      [dynamic]u8,
    positions: [dynamic]Position,
    rotations: [dynamic]Rotation,
    velocities: [dynamic]Velocity,
}


// FCS and LCS are currently only entity managers.

FCS_Save_Data :: struct {
    Entity: Entity_Manager_Save,
}

LCS_Save_Data :: struct {
    Entity: Entity_Manager_Save,
}


// Root save structure.

World_Save_Data :: struct {
    version: u32,

    ECS: ECS_Save_Data,
    PCS: PCS_Save_Data,
    FCS: FCS_Save_Data,
    LCS: LCS_Save_Data,
}


// ============================================================
// TAG CONVERSION
// ============================================================

// Convert Tag_Bits into a u8.
// Each tag uses one bit.

pack_tags :: proc(tags: Tag_Bits) -> u8 {
    result: u8

    for tag in Tag {
        if tag in tags {
            result |= u8(1) << u8(tag)
        }
    }

    return result
}


// Convert a u8 back into Tag_Bits.

unpack_tags :: proc(value: u8) -> Tag_Bits {
    result: Tag_Bits

    for tag in Tag {
        mask := u8(1) << u8(tag)

        if (value & mask) != 0 {
            result += {tag}
        }
    }

    return result
}


// ============================================================
// ENTITY MANAGER: RUNTIME -> SAVE
// ============================================================

entity_manager_to_save :: proc(
    manager: ^Entity_Manager,
) -> Entity_Manager_Save {
    save: Entity_Manager_Save

    save.entity_capacity = manager.entity_capacity
    save.next_entity = u32(manager.next_entity)

    // Entity states.
    for state in manager.entity_state {
        append(&save.entity_state, u8(state))
    }

    // Free entity IDs.
    for entity in manager.free_entities {
        append(&save.free_entities, u32(entity))
    }

    return save
}


// ============================================================
// ENTITY MANAGER: SAVE -> RUNTIME
// ============================================================

entity_manager_from_save :: proc(
    save: ^Entity_Manager_Save,
    manager: ^Entity_Manager,
) -> bool {
    capacity := save.entity_capacity

    // Validate saved data.
    if capacity < 0 {
        return false
    }

    if len(save.entity_state) != capacity {
        return false
    }

    if len(save.free_entities) > capacity {
        return false
    }

    if u64(save.next_entity) > u64(capacity) {
        return false
    }

    // Validate entity states.
    for state in save.entity_state {
        if state > u8(State.Alive) {
            return false
        }
    }

    // Validate free IDs.
    for entity in save.free_entities {
        if entity >= save.next_entity {
            return false
        }

        if save.entity_state[int(entity)] != u8(State.Dead) {
            return false
        }
    }

    // Restore metadata.
    manager.entity_capacity = capacity
    manager.next_entity = EntityID(save.next_entity)

    // Restore entity states.
    err := resize(&manager.entity_state, capacity)
    if err != nil {
        return false
    }

    for i in 0..<capacity {
        manager.entity_state[i] = State(save.entity_state[i])
    }

    // Restore free IDs.
    err = resize(&manager.free_entities, len(save.free_entities))
    if err != nil {
        return false
    }

    for i in 0..<len(save.free_entities) {
        manager.free_entities[i] = EntityID(save.free_entities[i])
    }

    return true
}


// ============================================================
// ECS: RUNTIME -> SAVE
// ============================================================

ECS_to_save :: proc(world: ^ECS) -> ECS_Save_Data {
    save: ECS_Save_Data

    // Entity manager.
    save.Entity = entity_manager_to_save(&world.Entity)

    // Tags.
    for tag in world.tags {
        append(&save.tags, pack_tags(tag))
    }

    // Positions.
    for position in world.positions {
        append(&save.positions, position)
    }

    // Rotations.
    for rotation in world.rotations {
        append(&save.rotations, rotation)
    }

    // Velocities.
    for velocity in world.velocities {
        append(&save.velocities, velocity)
    }

    return save
}


// ============================================================
// ECS: SAVE -> RUNTIME
// ============================================================

ECS_from_save :: proc(
    save: ^ECS_Save_Data,
    world: ^ECS,
) -> bool {
    if !entity_manager_from_save(&save.Entity, &world.Entity) {
        return false
    }

    capacity := world.Entity.entity_capacity

    // Validate component array lengths.
    if len(save.tags) != capacity ||
       len(save.positions) != capacity ||
       len(save.rotations) != capacity ||
       len(save.velocities) != capacity {
        return false
    }

    // Restore tags.
    err := resize(&world.tags, capacity)
    if err != nil {
        return false
    }

    for i in 0..<capacity {
        world.tags[i] = unpack_tags(save.tags[i])
    }

    // Restore SOA positions.
    err = resize(&world.positions, capacity)
    if err != nil {
        return false
    }

    for i in 0..<capacity {
        world.positions[i] = save.positions[i]
    }

    // Restore SOA rotations.
    err = resize(&world.rotations, capacity)
    if err != nil {
        return false
    }

    for i in 0..<capacity {
        world.rotations[i] = save.rotations[i]
    }

    // Restore SOA velocities.
    err = resize(&world.velocities, capacity)
    if err != nil {
        return false
    }

    for i in 0..<capacity {
        world.velocities[i] = save.velocities[i]
    }

    return true
}


// ============================================================
// PCS: RUNTIME -> SAVE
// ============================================================

PCS_to_save :: proc(world: ^PCS) -> PCS_Save_Data {
    save: PCS_Save_Data

    // Entity manager.
    save.Entity = entity_manager_to_save(&world.Entity)

    // Tags.
    for tag in world.tags {
        append(&save.tags, pack_tags(tag))
    }

    // Positions.
    for position in world.positions {
        append(&save.positions, position)
    }

    // Rotations.
    for rotation in world.rotations {
        append(&save.rotations, rotation)
    }

    // Velocities.
    for velocity in world.velocities {
        append(&save.velocities, velocity)
    }

    return save
}


// ============================================================
// PCS: SAVE -> RUNTIME
// ============================================================

PCS_from_save :: proc(
    save: ^PCS_Save_Data,
    world: ^PCS,
) -> bool {
    if !entity_manager_from_save(&save.Entity, &world.Entity) {
        return false
    }

    capacity := world.Entity.entity_capacity

    // Validate component array lengths.
    if len(save.tags) != capacity ||
       len(save.positions) != capacity ||
       len(save.rotations) != capacity ||
       len(save.velocities) != capacity {
        return false
    }

    // Restore tags.
    err := resize(&world.tags, capacity)
    if err != nil {
        return false
    }

    for i in 0..<capacity {
        world.tags[i] = unpack_tags(save.tags[i])
    }

    // Restore SOA positions.
    err = resize(&world.positions, capacity)
    if err != nil {
        return false
    }

    for i in 0..<capacity {
        world.positions[i] = save.positions[i]
    }

    // Restore SOA rotations.
    err = resize(&world.rotations, capacity)
    if err != nil {
        return false
    }

    for i in 0..<capacity {
        world.rotations[i] = save.rotations[i]
    }

    // Restore SOA velocities.
    err = resize(&world.velocities, capacity)
    if err != nil {
        return false
    }

    for i in 0..<capacity {
        world.velocities[i] = save.velocities[i]
    }

    return true
}


// ============================================================
// SAVE DATA CLEANUP
// ============================================================

delete_entity_manager_save :: proc(save: ^Entity_Manager_Save) {
    delete(save.entity_state)
    delete(save.free_entities)
}

delete_ECS_save :: proc(save: ^ECS_Save_Data) {
    delete_entity_manager_save(&save.Entity)

    delete(save.tags)
    delete(save.positions)
    delete(save.rotations)
    delete(save.velocities)
}

delete_PCS_save :: proc(save: ^PCS_Save_Data) {
    delete_entity_manager_save(&save.Entity)

    delete(save.tags)
    delete(save.positions)
    delete(save.rotations)
    delete(save.velocities)
}

delete_world_save :: proc(save: ^World_Save_Data) {
    delete_ECS_save(&save.ECS)
    delete_PCS_save(&save.PCS)

    delete_entity_manager_save(&save.FCS.Entity)
    delete_entity_manager_save(&save.LCS.Entity)
}


// ============================================================
// WORLD: RUNTIME -> SAVE
// ============================================================

world_to_save :: proc(world: ^World) -> World_Save_Data {
    save: World_Save_Data

    save.version = SAVE_VERSION

    // ECS.
    save.ECS = ECS_to_save(&world.ECS)

    // PCS.
    save.PCS = PCS_to_save(&world.PCS)

    // FCS.
    save.FCS.Entity = entity_manager_to_save(&world.FCS.Entity)

    // LCS.
    save.LCS.Entity = entity_manager_to_save(&world.LCS.Entity)

    return save
}


// ============================================================
// WORLD: SAVE -> RUNTIME
// ============================================================

world_from_save :: proc(
    save: ^World_Save_Data,
    world: ^World,
) -> bool {
    if save.version != SAVE_VERSION {
        return false
    }

    // ECS.
    if !ECS_from_save(&save.ECS, &world.ECS) {
        return false
    }

    // PCS.
    if !PCS_from_save(&save.PCS, &world.PCS) {
        return false
    }

    // FCS.
    if !entity_manager_from_save(&save.FCS.Entity, &world.FCS.Entity) {
        return false
    }

    // LCS.
    if !entity_manager_from_save(&save.LCS.Entity, &world.LCS.Entity) {
        return false
    }

    return true
}


// ============================================================
// SAVE WORLD
// ============================================================

save_world :: proc(world: ^World) -> bool {
    fmt.println("[SAVE] Preparing world...")

    // Convert runtime world into ordinary dynamic arrays.
    save := world_to_save(world)
    defer delete_world_save(&save)

    fmt.println("[SAVE] Encoding JSON...")

    bytes, marshal_err := json.marshal(
        save,
        {
            spec = .JSON,
            pretty = true,
            use_spaces = true,
            spaces = 4,
        },
        allocator = context.allocator,
    )

    if marshal_err != nil {
        fmt.eprintfln("[SAVE] JSON encoding failed: %v", marshal_err)
        return false
    }

    defer delete(bytes)

    fmt.println("[SAVE] Writing file...")
    fmt.println("[SAVE] File size:", len(bytes), "bytes")

    write_err := os.write_entire_file_from_bytes(
        SAVE_PATH,
        bytes,
    )

    if write_err != nil {
        fmt.eprintfln("[SAVE] File write failed: %v", write_err)
        return false
    }

    fmt.println("[SAVE] World saved successfully.")

    return true
}


// ============================================================
// LOAD WORLD
// ============================================================

load_world :: proc(world: ^World) -> bool {
    fmt.println("[LOAD] Starting...")

    // Read JSON file.
    fmt.println("[LOAD] Reading save file...")

    bytes, read_err := os.read_entire_file_from_path(
        SAVE_PATH,
        context.allocator,
    )

    if read_err != nil {
        fmt.eprintfln("[LOAD] Could not read save file: %v", read_err)
        return false
    }

    defer delete(bytes)

    // Decode JSON into save structures.
    fmt.println("[LOAD] Decoding JSON...")

    save: World_Save_Data

    unmarshal_err := json.unmarshal(
        bytes,
        &save,
        spec = .JSON,
        allocator = context.allocator,
    )

    // The decoded arrays must be deleted on every exit path.
    defer delete_world_save(&save)

    if unmarshal_err != nil {
        fmt.eprintfln("[LOAD] JSON decoding failed: %v", unmarshal_err)
        return false
    }

    fmt.println("[LOAD] JSON decoded.")

    // Validate version.
    if save.version != SAVE_VERSION {
        fmt.println("[LOAD] Unsupported save version.")
        return false
    }

    // Restore into a temporary world.
    fmt.println("[LOAD] Reconstructing world...")

    loaded: World

    if !world_from_save(&save, &loaded) {
        fmt.println("[LOAD] World reconstruction failed.")
        shutdown(&loaded)
        return false
    }

    // Replace current world only after successful restoration.
    shutdown(world)
    world^ = loaded

    fmt.println("[LOAD] World loaded successfully.")

    return true
}
