package ECS

World :: struct {
    ECS: ECS,
    PCS: PCS,
    FCS: FCS,
    LCS: LCS,
}
ECS :: struct {
    Entity: Entity_Manager,
    tags: [dynamic]Tag_Bits,

    positions: #soa[dynamic]Position,
    rotations: #soa[dynamic]Rotation,
    velocities: #soa[dynamic]Velocity,
}

PCS :: struct {
    Entity: Entity_Manager,
    tags: [dynamic]Tag_Bits,

    positions: #soa[dynamic]Position,
    rotations: #soa[dynamic]Rotation,
    velocities: #soa[dynamic]Velocity,
}

FCS :: struct {
    Entity: Entity_Manager,
}

LCS :: struct {
    Entity: Entity_Manager,
}

Entity_Manager :: struct {
    entity_state: [dynamic]State,
    free_entities: [dynamic]EntityID,
    next_entity: EntityID,
    entity_capacity: int,
}

EntityID :: distinct u32
State :: enum {
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


System_Kind :: enum {
    ECS,
    PCS,
    FCS,
    LCS,
}


