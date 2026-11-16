package ECS

grow_entity_storage :: proc(ecs: ^ECS) -> bool {
    old_capacity := ecs.entity_capacity

    new_capacity := 1024
    if old_capacity > 0 {
        new_capacity = old_capacity * 2
    }

    // Reserve memory for every array first.
    if reserve(&ecs.entity_state, new_capacity) != nil do return false
    if reserve(&ecs.tags, new_capacity) != nil do return false

    if reserve(&ecs.positions, new_capacity) != nil do return false
    if reserve(&ecs.rotations, new_capacity) != nil do return false
    if reserve(&ecs.velocities, new_capacity) != nil do return false

    // All allocations succeeded. Now resize the arrays.
    _ = resize(&ecs.entity_state, new_capacity)
    _ = resize(&ecs.tags, new_capacity)

    _ = resize(&ecs.positions, new_capacity)
    _ = resize(&ecs.rotations, new_capacity)
    _ = resize(&ecs.velocities, new_capacity)

    ecs.entity_capacity = new_capacity
    return true
}

create_entity :: proc(
    ecs: ^ECS,
    position: Position = {},
    rotation: Rotation = {0, 0, 0, 1},
    velocity: Velocity = {},
) -> (Entity, bool) {

    entity: Entity
    // Reuse a destroyed entity ID first.
    if len(ecs.free_entities) > 0 {
        entity = pop(&ecs.free_entities)
    } else {
        entity = ecs.next_entity
        id := int(entity)

        // Grow storage if necessary.
        if id >= ecs.entity_capacity {
            if !grow_entity_storage(ecs) {
                return {}, false
            }
        }

        ecs.next_entity += 1
    }

    id := int(entity)
    // Initialize entity.
    ecs.entity_state[id] = .Alive
    ecs.tags[id] = {}

    // Initialize component data.
    ecs.positions[id] = position
    ecs.rotations[id] = rotation
    ecs.velocities[id] = velocity
    return entity, true
}

destroy_entity :: proc(ecs: ^ECS, entity: Entity) {
    id := int(entity)

    assert( id >= 0 && id < len(ecs.entity_state), "Invalid entity ID", )
    assert( ecs.entity_state[id] == .Alive, "Entity is already dead", )

    // Mark entity as dead.
    // Remove every tag from this entity.
    // Make the ID available for reuse.
    ecs.entity_state[id] = .Dead
    ecs.tags[id] = {}
    append(&ecs.free_entities, entity)
}

add_tag :: proc(ecs: ^ECS, entity: Entity, tag: Tag) {
    id := int(entity)

    assert( id >= 0 && id < len(ecs.entity_state), "Invalid entity ID", )
    assert( ecs.entity_state[id] == .Alive, "Entity is dead", )

    ecs.tags[id] += {tag}
}

remove_tag :: proc(ecs: ^ECS, entity: Entity, tag: Tag) {
    id := int(entity)

    assert( id >= 0 && id < len(ecs.entity_state), "Invalid entity ID", )
    assert( ecs.entity_state[id] == .Alive, "Entity is dead", )

    ecs.tags[id] -= {tag}
}

has_tag :: proc(ecs: ^ECS, entity: Entity, tag: Tag) -> bool {
    id := int(entity)

    if id < 0 || id >= len(ecs.entity_state) {
        return false
    }
    if ecs.entity_state[id] != .Alive {
        return false
    }

    return tag in ecs.tags[id]
}