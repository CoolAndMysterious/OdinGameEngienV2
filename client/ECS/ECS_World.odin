package ECS


ECS :: struct {
    entity_state: [dynamic]Entity_State,
    free_entities: [dynamic]Entity,
    next_entity: Entity,
    entity_capacity: int,
    tags: [dynamic]Tag_Bits,

    positions: #soa[dynamic]Position,
    rotations: #soa[dynamic]Rotation,
    velocities: #soa[dynamic]Velocity,

    fused_grids: map[Entity]Fused_Grid,
}

Scene :: struct {
    sdf: [dynamic]Entity,
}


Entity :: distinct u32
Entity_State :: enum {
    Dead,
    Alive,
}
Tag :: enum {
    Player,
    Human,
    AI,
    Monster,
    Particle,
    Cluster,
    FusedCluster,
    Object,
}
Tag_Bits :: bit_set[Tag]

Position :: struct {
    x, y, z: f32,
}
Rotation :: struct {
    x, y, z, w: f32,
}
Velocity :: struct {
    x, y, z: f32,
}
Vector3 :: struct {
    x, y, z: f32,
}

Fused_Grid :: struct {
    dimensions: [3]u32,
    occupancy: [dynamic]u64,
}


Cell_Coord :: struct {
    x, y, z: i32,
}
Cell_Bucket :: struct {
    entities: [dynamic]Entity,
}
Spatial_Index :: struct {
    cell_size: u32,
    cells: map[Cell_Coord]Cell_Bucket,
}

