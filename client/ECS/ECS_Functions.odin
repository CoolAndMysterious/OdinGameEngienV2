package ECS

shutdown :: proc(world: ^World) {

    // ECS
    delete(world.ECS.Entity.entity_state)
    delete(world.ECS.Entity.free_entities)
    delete(world.ECS.tags)
    delete(world.ECS.positions)
    delete(world.ECS.rotations)
    delete(world.ECS.velocities)

    // PCS
    delete(world.PCS.Entity.entity_state)
    delete(world.PCS.Entity.free_entities)
    delete(world.PCS.tags)
    delete(world.PCS.positions)
    delete(world.PCS.rotations)
    delete(world.PCS.velocities)

    // FCS
    delete(world.FCS.Entity.entity_state)
    delete(world.FCS.Entity.free_entities)

    // LCS
    delete(world.LCS.Entity.entity_state)
    delete(world.LCS.Entity.free_entities)
}

grow_entity_storage :: proc(world: ^World, system: System_Kind) {
    old_capacity: int

    // Get the selected subsystem's current capacity.
    switch system {
    case .ECS:
        old_capacity = world.ECS.Entity.entity_capacity
    case .PCS:
        old_capacity = world.PCS.Entity.entity_capacity
    case .FCS:
        old_capacity = world.FCS.Entity.entity_capacity
    case .LCS:
        old_capacity = world.LCS.Entity.entity_capacity
    }

    // Calculate new capacity.
    new_capacity := 1024
    if old_capacity > 0 {
        new_capacity = old_capacity * 2
    }

    // Resize the selected subsystem's storage.
    switch system {
    case .ECS:
        resize(&world.ECS.Entity.entity_state, new_capacity)
        resize(&world.ECS.tags, new_capacity)
        resize(&world.ECS.positions, new_capacity)
        resize(&world.ECS.rotations, new_capacity)
        resize(&world.ECS.velocities, new_capacity)

        world.ECS.Entity.entity_capacity = new_capacity

    case .PCS:
        resize(&world.PCS.Entity.entity_state, new_capacity)
        resize(&world.PCS.tags, new_capacity)
        resize(&world.PCS.positions, new_capacity)
        resize(&world.PCS.rotations, new_capacity)
        resize(&world.PCS.velocities, new_capacity)

        world.PCS.Entity.entity_capacity = new_capacity

    case .FCS:
        // Implementation later.

    case .LCS:
        // Implementation later.
    }
}
create_entity :: proc(world: ^World, system: System_Kind) -> EntityID {
    entity: EntityID

    manager: ^Entity_Manager

    // Select the entity manager.
    switch system {
    case .ECS:
        manager = &world.ECS.Entity
    case .PCS:
        manager = &world.PCS.Entity
    case .FCS:
        manager = &world.FCS.Entity
    case .LCS:
        manager = &world.LCS.Entity
    }

    // Reuse a destroyed entity ID first.
    if len(manager.free_entities) > 0 {
        entity = pop(&manager.free_entities)
    } else {
        // Create a completely new entity ID.
        entity = manager.next_entity
        manager.next_entity += 1

        id := int(entity)

        // Check whether storage needs to grow.
        if id >= manager.entity_capacity {
            grow_entity_storage(world, system)
        }
    }

    id := int(entity)

    // Mark the entity as alive and initialize its tags.
    switch system {
    case .ECS:
        manager.entity_state[id] = .Alive
        world.ECS.tags[id] = {}

    case .PCS:
        manager.entity_state[id] = .Alive
        world.PCS.tags[id] = {}

    case .FCS, .LCS:
        // Implementation later.
    }

    return entity
}

destroy_entity :: proc(world: ^World, entity: EntityID, system: System_Kind) {
    manager: ^Entity_Manager

    // Select the entity manager.
    switch system {
    case .ECS:
        manager = &world.ECS.Entity
    case .PCS:
        manager = &world.PCS.Entity
    case .FCS:
        manager = &world.FCS.Entity
    case .LCS:
        manager = &world.LCS.Entity
    }

    id := int(entity)

    assert(
        id >= 0 && id < len(manager.entity_state),
        "Invalid entity ID",
    )

    assert(
        manager.entity_state[id] == .Alive,
        "Entity is already dead",
    )

    // Mark entity as dead.
    manager.entity_state[id] = .Dead

    // Remove subsystem-specific tags.
    switch system {
    case .ECS:
        world.ECS.tags[id] = {}

    case .PCS:
        world.PCS.tags[id] = {}

    case .FCS, .LCS:
        // Implementation later.
    }

    // Component data is intentionally left alone.
    // The component slots are unused while this entity is dead.

    // Make the ID available for reuse.
    append(&manager.free_entities, entity)
}


add_tag :: proc(world: ^World, entity: EntityID, tag: Tag, system: System_Kind) {
    manager: ^Entity_Manager

    // Select the entity manager.
    switch system {
    case .ECS:
        manager = &world.ECS.Entity
    case .PCS:
        manager = &world.PCS.Entity
    case .FCS:
        manager = &world.FCS.Entity
    case .LCS:
        manager = &world.LCS.Entity
    }

    id := int(entity)

    assert(
        id >= 0 && id < len(manager.entity_state),
        "Invalid entity ID",
    )

    assert(
        manager.entity_state[id] == .Alive,
        "Entity is dead",
    )

    // Add the tag to the selected subsystem.
    switch system {
    case .ECS:
        world.ECS.tags[id] += {tag}

    case .PCS:
        world.PCS.tags[id] += {tag}

    case .FCS, .LCS:
        // Implementation later.
    }
}
remove_tag :: proc(world: ^World, entity: EntityID, tag: Tag, system: System_Kind) {
    manager: ^Entity_Manager

    // Select the entity manager.
    switch system {
    case .ECS:
        manager = &world.ECS.Entity
    case .PCS:
        manager = &world.PCS.Entity
    case .FCS:
        manager = &world.FCS.Entity
    case .LCS:
        manager = &world.LCS.Entity
    }

    id := int(entity)

    assert(
        id >= 0 && id < len(manager.entity_state),
        "Invalid entity ID",
    )

    assert(
        manager.entity_state[id] == .Alive,
        "Entity is dead",
    )

    // Remove the tag from the selected subsystem.
    switch system {
    case .ECS:
        world.ECS.tags[id] -= {tag}

    case .PCS:
        world.PCS.tags[id] -= {tag}

    case .FCS, .LCS:
        // Implementation later.
    }
}

has_tag :: proc(world: ^World, entity: EntityID, tag: Tag, system: System_Kind) -> bool {
    manager: ^Entity_Manager

    // Select the entity manager.
    switch system {
    case .ECS:
        manager = &world.ECS.Entity
    case .PCS:
        manager = &world.PCS.Entity
    case .FCS:
        manager = &world.FCS.Entity
    case .LCS:
        manager = &world.LCS.Entity
    }

    id := int(entity)

    // Validate entity ID.
    if id < 0 || id >= len(manager.entity_state) {
        return false
    }

    // Check whether entity is alive.
    if manager.entity_state[id] != .Alive {
        return false
    }

    // Check the selected subsystem's tags.
    switch system {
    case .ECS:
        return tag in world.ECS.tags[id]

    case .PCS:
        return tag in world.PCS.tags[id]

    case .FCS, .LCS:
        // Implementation later.
        return false
    }

    return false
}